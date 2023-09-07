# Rust/LUA/msgpack interop: почему так сложно?

## Введение

Мы разрабатываем пикодату...

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
