




         rust / lua / msgpack interop: почему так сложно?





                                                 @gmoshkin Егор Мошкин



<div style="page-break-after: always;"></div>


            Кто я?

    - бэкграунд: МГУ ВМиК, С/С++, Python
    - здесь уже > 2 года
    - разрабатываю tarantool-module
    - разрабатываю picodata
    - патчи в форк



<div style="page-break-after: always;"></div>


            О чём доклад?

      rust <-> lua <-> msgpack <-> rust

    почему до сих пор нет нормального решения?


<div style="page-break-after: always;"></div>


            Ответ 1.

    rust и lua максимально несовместимы

          задача очень сложная


<div style="page-break-after: always;"></div>


            Ответ 2.

    rust максимально несовместим
      с решением сложных задач



<div style="page-break-after: always;"></div>


            А что делать?

    - не унывать

    - не слушать пропаганду

    - не усложнять себе жизнь


<div style="page-break-after: always;"></div>


            Как мы сюда попали?

    мы разрабатываем кластерную субд и (уже не) сервер приложений на раст


<div style="page-break-after: always;"></div>


    - почему rust?

        > безопасный и быстрый язык. такого сочетания раньше не было.


<div style="page-break-after: always;"></div>


    на самом деле:

    - либо безопасный и не безумно медленный
    - либо НЕбезопасный и быстрый


<div style="page-break-after: always;"></div>


            Вывод 1.

    - unsafe не надо бояться

    - unsafe надо понимать


<div style="page-break-after: always;"></div>


    > Библиотека должна прятать unsafe!


<div style="page-break-after: always;"></div>


        Библиотека tarantool-module:

    - tlua
    - box_* api: space, index, ...
    - iproto
    ...


<div style="page-break-after: always;"></div>


        Пример 1.

    ORM = struct tuple mapping:


<div style="page-break-after: always;"></div>


```rust

    extern "C" fn box_insert(
        space_id: u32,
        start: *const u8,
        end: *const u8,
        out: *mut box_tuple_t,
    ) -> i32;

```


<div style="page-break-after: always;"></div>


```rust

    fn box_insert(
        space_id: u32,
        data: &[u8],
    ) -> Option<Tuple>;

```


<div style="page-break-after: always;"></div>


```rust

    my_space.insert(&MyStruct { a, b, c });

```


<div style="page-break-after: always;"></div>


```rust

    что выбрать?

    fn Space::insert(&self, ...)

    fn Space::insert(&mut self, ...)

```


<div style="page-break-after: always;"></div>


```rust

    fn Space::insert(&self, ...) // правильный выбор

```


<div style="page-break-after: always;"></div>


        Вывод 2.

    - &mut self - зло

    - interior mutability - добро

    - Cell > UnsafeCell > RefCell


<div style="page-break-after: always;"></div>


```rust

    fn Space::insert(&self, data: &T)

```


<div style="page-break-after: always;"></div>


```rust

    fn Space::insert<T>(&self, data: &T)

```


<div style="page-break-after: always;"></div>


```rust

    fn Space::insert<T>(&self, data: &T)
    where
        T: serde::Serialize,

```


<div style="page-break-after: always;"></div>


```rust

    fn Space::insert<T>(&self, data: &T)
    where
        T: serde::Serialize, // за это мы ещё заплатим!

```


<div style="page-break-after: always;"></div>


```rust

    fn Space::insert<T>(&self, data: &T)
    where
        T: serde::Serialize,
    {
        box_insert(self.id, data.serialize_as_array())
    }

```


<div style="page-break-after: always;"></div>


```rust

    my_space.insert(&MyData { a, b, c });
    my_space.insert(&( 1, 2, 3 ));
    my_space.insert(&[ 4, 5, 6 ]);
    my_space.insert(&420);
    my_space.insert(&hash_map!{ 69: "nice" });

```


<div style="page-break-after: always;"></div>


```rust

    my_space.insert(&MyData { a, b, c });
    my_space.insert(&( 1, 2, 3 ));
    my_space.insert(&[ 4, 5, 6 ]);
    my_space.insert(&420); // что должно произойти?
    my_space.insert(&hash_map!{ 69: "nice" }); // что должно произойти?

```


<div style="page-break-after: always;"></div>


    Ответ неправильный:

```rust

    trait EncodeAsTuple: serde::Serialize {}
    impl EncodeAsTuple for [T; N] {}
    // not for i32, ...

```


<div style="page-break-after: always;"></div>


        Вывод 3.

    - compile time error checking = good

    - static type checking = good

    - compile time error checking via static type checking = BAD!!!

    - runtime time error checking = good


<div style="page-break-after: always;"></div>


    Правильный ответ:

```rust

    assert!(my_space.insert(&420) == Err(InvalidData));

```


<div style="page-break-after: always;"></div>


```rust

    fn Space::insert<T>(&self, data: &T)
    where
        T: EncodeAsTuple,
    {
        box_insert(self.id, data.serialize_as_array())
    }


```


<div style="page-break-after: always;"></div>


```rust

    fn Space::insert<T>(&self, data: &T) -> Option<Tuple>
    where
        T: EncodeAsTuple,
    {
        box_insert(self.id, data.serialize_as_array())
    }

```


<div style="page-break-after: always;"></div>


```rust

    let tuple = my_space.get(&key)?;
    other_space.insert(&tuple);

    let data: &[u8] = get_raw_msgpack_data();
    other_space.insert(&data);


```


<div style="page-break-after: always;"></div>


```rust

    trait EncodeAsTuple: serde::Serialize {}

    Tuple: !serde::Serialize

    &[u8]: serde::Serialize // wrong encoding

    что делать?

```


<div style="page-break-after: always;"></div>


    Ответ неправильный:

```rust

    trait ToTupleBuffer { fn get_data(&self) -> &[u8]; }

    impl ToTupleBuffer for Tuple {...}

    impl<T> ToTupleBuffer for T
    where
        T: EncodeAsTuple,
    { ... }

```


<div style="page-break-after: always;"></div>


    Ответ неправильный:

```rust

    fn Space::insert<T>(&self, data: &T)
    where
        T: ToTupleBuffer,
    {
        box_insert(self.id, data.get_data())
    }

```


<div style="page-break-after: always;"></div>


    Ответ неправильный:

```rust

    impl<T> ToTupleBuffer for T
    where
        T: EncodeAsTuple,
    { ... }

    &[u8]: EncodeAsTuple // wrong encoding


```


<div style="page-break-after: always;"></div>


    Ответ неправильный:

```rust

    struct RawBytes<'a>(&'a [u8]);
    impl ToTupleBuffer for RawBytes { ... }

    struct RawByteBuf(Vec<u8>);
    impl ToTupleBuffer for RawByteBuf { ... }

```


<div style="page-break-after: always;"></div>


    Ответ неправильный:

```rust

    trait serde::Serialize;
    trait EncodeAsTuple;
    trait ToTupleBuffer;

    struct RawBytes;
    struct RawByteBuf;

    #[derive(serde::Serialize)]
    struct MyStruct {..}
    impl EncodeAsTuple for MyStruct {}

```


<div style="page-break-after: always;"></div>


    Плохой пример: трейты из std::iter::*

```rust

    Iterator	        A trait for dealing with iterators.
    DoubleEndedIterator	An iterator able to yield elements from both ends.
    ExactSizeIterator	An iterator that knows its exact length.
    FusedIterator	    An iterator that always continues to yield None when exhausted.

    Extend	            Extend a collection with the contents of an iterator.
    FromIterator	    Conversion from an Iterator.

    IntoIterator	    Conversion into an Iterator.

    Product	            Trait to represent types that can be created by multiplying elements of an iterator.
    Sum	                Trait to represent types that can be created by summing up an iterator.

```


<div style="page-break-after: always;"></div>


    Правильный ответ:

```rust

    fn Space::insert_raw(&self, tuple: &[u8]) {
        box_insert(self.id, tuple) // тарантул проверяет данные
    }

    fn Space::encode_and_insert<T>(tuple: &T)
    where
        T: Encode,
    {
        data = tuple.encode_as_array();
        box_insert(self.id, data)
    }

    my_space.encode_and_insert(&my_struct);
    my_space.insert_raw(tuple.get_data());

```


<div style="page-break-after: always;"></div>

    Наказание:

```rust

    Space::insert_raw
    Space::encode_and_insert
    Space::replace_raw
    Space::encode_and_replace
    ...
    NetBox::call_raw
    NetBox::encode_and_call

```


<div style="page-break-after: always;"></div>


    Вывод 4.

```rust

    - дублирование простого кода > мета-программирование на типах

```


<div style="page-break-after: always;"></div>


        Пример 2.

    lua api


<div style="page-break-after: always;"></div>


```lua
    some_func(1337)
```
```rust
    lua_getfield(l, LUA_GLOBALSINDEX, c_ptr!("some_func"));
    lua_pushinteger(l, 1337);
    lua_call(l, 1, 0);
```


<div style="page-break-after: always;"></div>


```lua
    some_func(1337)
```
```rust
    let lua = lua_state();
    lua.call_func("some_func", 1337);
```


<div style="page-break-after: always;"></div>


```lua
    some_func(1337)
```
```rust
    fn Lua::call_func(&self, name: &str, integer: i32) {
        lua_getfield(self.l, LUA_GLOBALSINDEX, name);
        lua_pushinteger(self.l, integer);
        lua_call(self.l, 1, 0);
    }
```


<div style="page-break-after: always;"></div>


```lua
    some_func(any_value)
```
```rust
    fn Lua::call_func<T>(&self, name: &str, value: T)
    where
        T: LuaPush,
    {
        lua_getfield(self.l, LUA_GLOBALSINDEX, name);
        LuaPush::push(self.l, value);
        lua_call(self.l, 1, 0);
    }
```


<div style="page-break-after: always;"></div>


```lua
    some_func(a, b, c)
```
```rust
    let lua = lua_state();
    lua.call_func("some_func", a, b, c); // так нельзя!
```


<div style="page-break-after: always;"></div>


```rust
    fn Lua::call_func<T>(&self, name: &str, value: &?T) // &T или T ?
    where
        T: LuaPush,
    {
        lua_getfield(self.l, LUA_GLOBALSINDEX, name);
        LuaPush::push(self.l, value);
        lua_call(self.l, 1, 0);
    }
```


<div style="page-break-after: always;"></div>


    by reference `&T`?

    - что если данные должны move'аться на луа стэк?

    - userdata/cdata
    - cfunction: FnOnce/FnMut


<div style="page-break-after: always;"></div>


    by value `T`?

    - что если данные ещё пригодятся?

    - клонировать при каждом вызове? `Vec<BigData>`


<div style="page-break-after: always;"></div>


```rust
    fn LuaPush::push(self) {}

    impl LuaPush for i32 {}
    impl LuaPush for &i32 {}
    ...
    impl LuaPush for MyStruct {}
    impl LuaPush for &MyStruct {}
```


<div style="page-break-after: always;"></div>


    Bonus meme

```rust

    // Что должно произойти?
    let x: i32 = lua.eval("return 3.14").unwrap();

```
