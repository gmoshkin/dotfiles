# Rust/LUA/msgpack interop: почему так сложно?

## Введение

Если слушать главу компании, то мы разрабатываем распределённую субд на расте
(до недавнего времени ещё и сервер приложений, но рынку это оказалось не нужно).
И если очень очень сильно прищуриться, то это действительно так, но всерьёз к
этому маркетинговому лозунгу относиться не стоит. Более точным на мой взгляд
было бы сказать "мы разрабатываем набор расширений для tarantool, которые
позволят делать на нём решения и использовать его как распределённую субд".
Отсюда становится понятно, при чём здесь луа и мсжпак.

Мсжпак это ядро тарантула (буквально, см. src/lib/core/mp_*). Тарантул =
tuple storage, tuple = msgpack. От него мы уже никогда не избавимся.

Луа это де факто язык для расширений и приложений на тарантуле, на нём написаны
управление схемой в тарантуле, модуль шардирования данных vshard, кластер
менеджер cartridge. Поэтому если ты пишешь код под тарантул, тот в любом случае
столкнёшься с луа.

Раст это стрёмная смесь c++ и ml (ocaml, haskel), который набирает популярность
засчёт качественного туллинга (cargo, rust-analyzer) и сказок про бесплатную
эффективность на уровне С одновременно с memory-safety без сборки мусора. На
деле же представляет из себя язык с эффективностью на уровне Go и сборкой мусора
через подсчёт ссылок.

Для кого этот доклад:
   - для людей, которые пишут код на расте и луа и использует msgpack
     (все сотрудники picodata)
   - для людей, которые принимают решения, на чём люди пишут код
     (выбирают технологии)


~~~

Так как тарантул неотрывно связан и с мсжпаком и с луа, мы по крайней мере в
обозримом будущем от них полностью избавиться не сможем. Повторюсь, на луа
написана и часть самого тарантула и значительная часть экосистемы.

А это значит, что если мы хотим создать успешный продукт в таких условиях, мы
должны уметь эффективно пользоваться доступными ресурсами, то есть оперировать
между rust, lua и мсжпаком. Это одна из целей библиотеки tarantool-module.

Но зачем пользователям знать как устроено всё внутри? По-мимо того, что знание =
сила, и что понимание системы на низком уровне даёт много преимуществ? Кроме
этого из-за особенностей наших условий часто возникают ситуации, которые
чисто абстаргировать в библиотеке не получается, из-за которых у пользователей
могут возникуть проблемы с использованием её. А в этом докладе я как раз
расскажу о таких вещах.

Расскажу, почему некоторые вещи получились криво, и почему зачастую сделать
лучше очень сложно.

А также заодно расскажу о нескольких местах, которые можно было сделать лучше,
чтобы вы в будущем не совершали наших ошибок.


~~~

Есть библиотека tlua/tarantool-module, почему она отстой, потому что всё сложно:

Зачем пользователям это знать, и что им с этим делать?

- Зачем:
   - чтобы понимать как работать с библиотекой, и почему она такая кривая
       местами
   - чтобы знать, что делать в местах, где библиотека не помогает
- Что делать:
   - По возможности избегать необходимости в интеропе между луа и растом
   - Всегда выбирать простые решения

## Разница моделей данных rust/lua/msgpack

- lua bool: true/false -- всё просто. На этом простые случаи закончены.
- lua nil: не может быть элементом таблицы
- lua number: double precision floating point number
   - msgpack integer / float
   - rust i8, u8, i16, u16, ..., isize, usize, i128, f32, f64 (NonZeroU64, ..)
- lua string:
   - msgpack string / bytes
   - rust string: String, &str, CString, &CStr, &[u8], OsString, Path, ...
- lua table:
   - sequence (индекс от 1) / hashtable
      - msgpack array / map
      - rust struct, enum, &[T], Vec<T>, HashMap<T>, HashSet<T>
- lua metamethods -> ?
- lua userdata / luajit cdata/ctype

- rust tuple:
   - msgpack array
   - lua sequence/lua multret
- rust struct Named { a: i32, b: String }
   - msgpack map
   - lua hashtable
- rust struct Unnamed(f32, bool) (для чего это вообще существует???)
   - msgpack array???
   - lua sequence??
- rust enum E { A, B, C }
   - msgpack string
   - lua string
- rust enum Expr { Add { l: L, r: R }, Not { e: E } }
   - msgpack map { tag: 'Add', value: { l: L, r: R } }
   - msgpack map { tag: 'Add', l: L, r: R }
   - msgpack map { l: L, r: R }
   - lua ...
- rust enum Expr { Add(L, R), Not(E) }
   - ?
- rust enum Result<T, E> { Ok(T), Err(E) }
- rust enum Option<T> { Some(T), None }
...


## Особенности tarantool-lua:
- box.NULL
- metamethods __serialize
- расширения cdata/userdata: decimal, fiber, tuple, datetime, ...
- встроенные перегруженные функции
- нет поддержки msgpack bytes
- поэтому большую часть нельзя вынести в tlua либу


## Особенности rust
- Serde: дефакто стандартное решение для сер/дериализации: описание
   - сложность модели: абстрактная модель Serializer/Deserializer
   Формат данных        -> [serde] -> struct, enum, Vec<T> ...
   [json,msgpack,...]
   - Не достаточно гибкости для краевых случаев

- rmp_serde баг с untagged

- Нет интроспекции ни рантайм ни компайлтайм: вместо этого трейты и проц макросы
- Нет специализации для трейтов: нужно явно прописывать реализацию либо
   - для каждого типа по отдельности impl MyTrait for i8; impl MyTrait for u8; impl MyTrait for String; ...
   - не больше одного: impl<T> MyTrait for T

- PartialEq vs Eq / ParitalOrd vs Ord
- Move-semantics/Borrow-checker/Lifetime constraints

## Ошибки проектирования tlua:
- tlua - отдельная библиотека, лучше было внести в tarantool-module
- tlua::Any[Hashable]LuaValue
   - no support for:
      - userdata
      - function
      - cdata
   - lossy:
      - table -> Vec<(Value, Value)>
      - number -> f64/i32
- LuaRead -> WrongType
   - изначально был Option, в случае ошибки получаешь None
   - сейчас не сильно лучше (пример сообщения об ошибке, примеры сообщений из serde_*)
- Параметрический полиморфизм
   - следствие: PushGuard<LuaTable<PushGuard<LuaFunction<PushGuard<...>>>>>
- Push[One][Into] _no_err



## tlua
    - PushGuard isn't flexible enough, cause: Parametric Polymorphism
    - LuaRead doesn't work with LuaTable as function parameters, cause: Parametric Polymorphism + borrow checker
    - trait Push is a mess, cause: type driven compile time checking
    - too many wrapper types, cause: trait system limitations
    - ViaMsgpack, cause: serde sucks + trait system

## msgpack
    - ToTupleBuffer & Encode: trait system limitations
    - RawBytes, RawByteBuf: trait system limitations + overabstraction

## serde





<div style="page-break-after: always;"></div>

- хотел рассказать про то, почему в тарантул модуле так сложно работать с луа,
  почему столько плохо работающих мест, и смог надумать 2 основных вывода:

1. Раст и Луа это максимально несовместимые языки, что сильно усложняет задачу
   интеропа между ними.

- Модели данных и принципы и идеи заложенные в язык практически лежат на разных
  концах спектра.

2. Раст это язык максимально несовместимый с решением сложных задач.

- Идеи, заложенные в основу языка, и которые пропагандируются сообществом
  приводят к неоправданному усложнению процесса разработки и замедляют как
  развитие самого языка, так и любого проекта на нём написанного.

- К таким выводам я пришёл не сразу, и от слушателей в общем-то не ожидаю
  согласия со мной. В этом докладе я попробую максимально продуктивно изложить
  свою точку зрения а главное попробую предложить набор альтернативных подходов
  и принципов, которые на мой взгляд позволят вам более успешно делать свою
  работу, и которые можно применять в общем-то не только в расте.

- Такие довольно громкие заявления я попробую обосновать в этом докладе, но у
  меня на самом деле нет цели вас убедить

- как мы сюда попали?

- раст рекламируется как безопасный и производительный язык. Здесь сразу
  всплывает первый подвох: на практике раст это либо безопасный язык и не
  безумно медленный, либо небезопасный и производительный. Это видно по любым
  бенчмаркам, которые занимают топы -- там всегда внутри unsafe код, с сырыми
  указателями и машинными операциями

- что такое unsafe? документация первым же пунктом упоминает разыменование
  "сырых" указателей. Для меня как для человека пришедшего из С/С++ это в
  общем-то довольно забавно, потому по такому определению весь код, который я
  там писал это unsafe. Но это так же значит, что я изначально к этой концепции
  отношусь более спокойно, чем человек, который например в раст пришёл из
  питона. По этому первая идея, которую хочу до вас донести -- unsafe !=
  страшно, это просто значит, что в этом месте нужно быть немного более
  осторожным.

- к тому же в силу особенностей нашей платформы, usnafe у нас неизбежен, так как
  мы взаимодействуем с тарантулом через ffi

- но для этого есть библиотека! Она должна предоставлять безопасные обёртки,
  чтобы пользователи могли не беспокоиться о undefined behavior и писать бизнес
  логику.

- соглашусь, что там, где это возможно, библиотека должна не давать нам
  незаметно для нас сделать ошибку. давайте тогда посмотрим, каким образом раст
  нам предлагает это делать.

- раст это не просто статически типизированный язык. Безопасность через
  статическую типизацию -- это идея, которая сильнее всего повлияла на весь
  язык. Борроу-чекер в расте реализован в виде статической типизации: каждая
  ссылка в программе имеет свой тип, параметризованный областью существования
  объекта, на который мы ссылаемся. Эта идея очень популярна не только в раст
  коммьюнити, но и во многих других языках, которые поддерживают параметрический
  полиморфизм -- с++ шаблоны. Корни растут из ml-подобных языков.

- Тезис: compile-time error checking =/= static type checking.
    - compile-time error checking == good
    - static type checking == good
    - compile-time error checking via static type checking == bad!

- Давайте рассмотрим примеры:

- ToTupleBuffer.

- Задача: ORM / STM struct-tuple mapping.
    - Дано:
        - box_* api принимает msgpack array
        - бизнес логика: rust struct
    - Хочется:
        - box api принимало rust struct
    - Решение:
        - generic code! Space::insert<T>(tuple: T)
    - Ограничение:
        - generic code == trait

    0) box_insert(space_id: u32, tuple: &[u8])

    1) Space::insert(tuple: MyStruct)

    2) Space::insert<T>(tuple: T)

    3) Space::insert<T>(tuple: T)
       where
           T: serde::Serialize,

    Проблема 1:
        my_space.insert(69); // что должно произойти?

    Решение невозможное:
        Space::insert<T>(tuple: T) {
            const if !is_serializable_as_array(T) {
                compile_error!();
            }
            data = serialize_as_array(tuple);

            box_insert(self.id, data);
        }

    Решение неправильное:
        /// Only for types serializable as msgpack array.
        trait EncodeAsTuple {}
        Space::insert<T>(tuple: T)
        where
            T: EncodeAsTuple,
        {
            ...
        }

    Проблема 2:
        let t: box_tuple_t = my_space.get(key);
        other_space.insert(t); // box_tuple_t does not implement serde::Serialize

    Решение невозможное:
        Space::insert<T>(tuple: T) {
            const if T == box_tuple_t {
                data = box_tuple_to_buf(tuple, ...);
            } else const if is_serializable(T) {
                data = serialize_as_array(tuple);
            }

            box_insert(self.id, data);
        }

    Решение неправильное:
        /// Only for types serializable as msgpack array.
        trait AsTuple {}
        impl<T> AsTuple for T
        where
            T: EncodeAsTuple {}

        Space::insert<T>(tuple: T)
        where
            T: AsTuple,
        {
            ...
        }

    Проблема 3:
        data: &[u8] = get_raw_msgpack_data();
        my_space.insert(data); // что тут происходит?

    Решение неправильное:
        struct RawBytes([u8]);
        impl AsTuple for RawBytes {...}


    Решение единственно правильное для всех случаев:
        Space::insert_raw(tuple: &[u8]) {
            box_insert(self.id, tuple) // тарантул проверяет данные
        }

        Space::encode_and_insert<T: Encode>(tuple: T) {
            data = tuple.encode_as_array();
            box_insert(self.id, data) // тарантул проверяет данные
        }

        my_space.encode_and_insert(my_struct);
        my_space.insert_raw(tuple.get_data());

    Наказание:
        Space::insert_raw Space::encode_and_insert
        Space::replace_raw
        Space::encode_and_replace
        ...
        NetBox::call_raw
        NetBox::encode_and_call

- принципы:
    - runtime error checking > compile-time error checking via static type checking
    - дубликация кода > compile-time error checking via static type checking


aside: фичи языка, которые могли бы помочь, будь они stable (но они не будут):
    - std::any::TypeId::of::<T>()
        - const unstable
        - требует 'static
    - specialization


- фундаментальная проблема: система трейтов слишком ограничивающая.
    - любой дженерик код компилируется до момента специализации,
      то есть с ним можно делать только то, что объявлено в виде trait bounds.
    - это должно было помочь со временем компиляции и читаемостью ошибок, но нет


- давайте теперь посмотрим на lua. Луа изначально позиционируется, как эмбедабл
  язык для того, чтобы использовать его внутри других приложений: например игр
  или субд тарантул. Для этого есть стэковый ffi апи:

- вот пример, как что-то такое реализовать через апи

```lua
        a = f("how", t.x, 14)
```
```rust
unsafe {
    lua_getfield(l, LUA_GLOBALSINDEX, c_ptr!("f")); /* function to be called */
    lua_pushstring(l, c_ptr!("how"));                        /* 1st argument */
    lua_getfield(l, LUA_GLOBALSINDEX, c_ptr!("t"));   /* table to be indexed */
    lua_getfield(l, -1, c_ptr!("x"));        /* push result of t.x (2nd arg) */
    lua_remove(l, -2);                          /* remove 't' from the stack */
    lua_pushinteger(l, 14);                                  /* 3rd argument */
    lua_call(l, 3, 1);             /* call 'f' with 3 arguments and 1 result */
    lua_setfield(l, LUA_GLOBALSINDEX, c_ptr!("a"));        /* set global 'a' */
}
```

- я думаю, что мало кому захочется на таком апи писать каждый день. Давай
  попробуем спроектировать "безопасное" апи поверх этого

- упростим пример, пусть нам надо сделать аналог вот такого
    -
        some_func(420)

    - в идеале мы бы хотели иметь вызов
        lua.call_func("some_func", 420)

        Lua::call_func(&self, name: &str, arg: i32) {
            lua_getfield(self.l, LUA_GLOBALSINDEX, name);
            lua_pushinteger(self.l, arg);
            lua_call(self.l, 1, 0);
        }

    - или
        lua.call_func("some_func", "foobar")

        Lua::call_func(&self, name: &str, arg: &str) {
            lua_getfield(self.l, LUA_GLOBALSINDEX, name);
            lua_pushstring(self.l, arg);
            lua_call(self.l, 1, 0);
        }

    - или
        lua.call_func("some_func", my_variable)

        Lua::call_func<T>(&self, name: &str, arg: &T)
        where
            T: LuaPush,
        {
            lua_getfield(self.l, LUA_GLOBALSINDEX, name);
            LuaPush::push(self.l, arg);
            lua_call(self.l, 1, 0);
        }

    - вопрос: что принимает LuaPush::push: &self или self?

    - если &self: что делать с
        - userdata/cdata
        - cfunction: FnOnce/FnMut

    - если self: что если данные мне ещё нужны?
        - clone на каждый вызов функции, чтобы просто дропнуть значения при выходе

    - как поддержать оба варианта?
        ???

        Lua::call_func<T>(&self, name: &str, arg: T) // T by value

        impl LuaPush for i32 {}
        impl LuaPush for &i32 {}
        impl LuaPush for String {}
        impl LuaPush for &str {}
        impl LuaPush for MyStruct {}
        impl LuaPush for &MyStruct {}


    - что если несколько аргументов?
        lua.call_func("some_func", a, b, c) // compile error

    - (A, B, C) == несколько значений на стеке
        lua.call_func("some_func", (a, b, c))

        Lua::call_func<T>(&self, name: &str, arg: &T)
        where
            T: LuaPush,
        {
            lua_getfield(self.l, LUA_GLOBALSINDEX, name);
            LuaPush::push(self.l, arg);
            lua_call(self.l, ?, 0);
        }

        Lua::call_func<T>(&self, name: &str, arg: &T)
        where
            T: LuaPush,
        {
            lua_getfield(self.l, LUA_GLOBALSINDEX, name);
            n = LuaPush::push(self.l, arg);
            lua_call(self.l, n, 0);
        }

        - btw serde_rmp: (A, B, C) == [A, B, C]

        - struct MyStruct { a: i32, b: (f32, f32, f32), }

        - что делать в других случаях?
            value = lua_table.get(key);

            // а что если?
            value = lua_table.get((a, b, c)); // что произойдёт?

        - правильный ответ
            res = lua_table.get((a, b, c));
            res == Err(PushedTooManyValues);

        - неправильный ответ
            trait LuaPushOne: LuaPush {}

    - 



- раст и луа это фундаментально несовместимые языки
    - луа -- максимально динамический:
        - максимально нестрогая минималистичная типизация:
            - автопреобразование числовых типов
            - смысл таблиц меняется в зависимости от контекста
            - не поддерживает юникод
        - стэковый api: любая операция мутирует общее состояние
    - раст -- максимально статический:
        - наказывает за переиспользование типов
            - enum заставляет дублировать поля
            - traitы заставляют плодить новые типы
            - &str, String, CStr, &[u8], Path, ...
        - наказывает за нестрогость
            - проверка ошибок обязательна в каждом месте использования
        - наказывает за мутирование
            - иметь две &mut на один и тот же объект незаконно
        - наказывает за ссылки
            - вездесущий борроу чекер
            - любой код с ссылками -- дженерик код
    - невозможно построить хорошую прослойку
        - либо она не будет полноценно укладываться в парадигму раста
            - unsafe
        - либо она будет ужасна в использовании
        - на выглаживание корнер кейсов уйдёт вечность
    - что же тогда делать?
        - сокращать площадь соприкосновения раста и луа в своих проектах
        - не ныть и чинить корнер кейсы руками

- мсжпак -- не (самая большая) проблема, проблема в serde
    - serde слишком дженерик и при этом недостаточно гибкий
        - раст [Serialize] <-(модель данных serde)-> [Serializer] формат
        - ожидание: абстрактный сериализатор, данные могут быть чем угодно,
          хоть строкой, хоть луа стеком
        - реальность: очень сложно разобраться в такой системе
        - нельзя делать частичную десериализацию
        - нельзя настроить as_map/as_array
        - проблемы со сборкой
    - что делать?
        - serde не использовать
            - мы начали разработку своего трейта, на это нужно время
        - не создавать лишних абстракций

- почему LuaRead/Push <=/=> rmp_serde
    - msgpack array == (A, B, C) == lua multiret != msgpack array
    - enum это геморой

- абстракции -- плохо, мета-программирование на типах -- плохо
    - используйте const if, если возможно
    - делайте проверки в рантайме
        - assert > Err
    - дубликация кода > overabstraction
    - пишите простой код
