#program_export
my_proc :: () -> s32 #c_call {
    Init_Context();

    Tarantool_API.load();
    using tarantool;

    write_string("*********************\n");
    write_string("schema version is ");
    v := box_schema_version();
    write_nonnegative_number(v);
    write_string("\n");
    write_string("*********************\n");

    L := luaT_state();
    top := lua_gettop(L);
    defer lua_settop(L, top);

    {
        ok, v := tarantool_eval("return 69 + 13", s32);
        if !ok then print("fail\n");
        else        print("got %\n", v);
    }
    {
        ok, v := tarantool_eval("return 69 + 0.105", float);
        if !ok then print("fail\n");
        else        print("got %\n", v);
    }
    {
        ok, v := tarantool_eval("return 'hello, ' .. 'baby'", string);
        if !ok then print("fail\n");
        else        print("got %\n", v);
    }
    {
        ok, v := tarantool_eval("return true", bool);
        if !ok then print("fail\n");
        else        print("got %\n", v);
    }
    {
        ok, v := tarantool_eval("local l, r = ...; return l + r", s32, 420, 69);
        if !ok then print("fail\n");
        else        print("got %\n", v);
    }
    {
        ok, v := tarantool_eval("local a, b, c = ...; return a .. b .. c", s32, "hello", " ", "bro");
        if !ok then print("fail\n");
        else        print("got %\n", v);
    }
    {
        ok := tarantool_eval("print(...)", void, "this", "is", "printed");
        if !ok then print("fail\n");
        else        print("ok\n");
    }

    test_msgpack();

    return 0;
}

test_msgpack_encode :: () {
    check_mp_encode :: (v: $T, expected: string) {
        builder: String_Builder;
        mp_encode_to_builder(*builder, v);
        s := builder_to_string(*builder);
        defer free(s);

        Setup_Context_To_Print_Bytes_Array();
        assert(s == expected, "expected %, but got %", array_view(expected), array_view(s));
    }

    check_mp_encode(cast(u64) 0                     , "\x00");
    check_mp_encode(cast(u64) 3                     , "\x03");
    check_mp_encode(cast(u64) 33                    , "\x21");
    check_mp_encode(cast(u64) 0x7f                  , "\x7f");
    check_mp_encode(cast(u64) 0x80                  , "\xcc\x80");
    check_mp_encode(cast(u64) 0xee                  , "\xcc\xee");
    check_mp_encode(cast(u64) 0x123                 , "\xcd\x01\x23");
    check_mp_encode(cast(u64) 0xcafe_babe           , "\xce\xca\xfe\xba\xbe");
    check_mp_encode(cast(u64) 0xdead_beef_b00b_bead , "\xcf\xde\xad\xbe\xef\xb0\x0b\xbe\xad");

    check_mp_encode(cast(s64) -1,                    "\xff");
    check_mp_encode(cast(s64) -32,                   "\xe0");
    check_mp_encode(cast(s64) -128,                  "\xd0\x80");
    check_mp_encode(cast(s64) -256,                  "\xd1\xff\x00");
    check_mp_encode(cast(s64) -65353,                "\xd2\xff\xff\x00\xb7");
    check_mp_encode(cast(s64) -0xcafe_babe,          "\xd3\xff\xff\xff\xff\x35\x01\x45\x42");
    check_mp_encode(cast(s64) 0xdead_beef_b00b_bead, "\xd3\xde\xad\xbe\xef\xb0\x0b\xbe\xad");

    check_mp_encode(cast(u8) 33, "\x21");
    check_mp_encode(cast(u8) 0xff, "\xcc\xff");

    check_mp_encode("",                                 "\xa0");
    check_mp_encode("foo",                              "\xa3\x66\x6f\x6f");
    check_mp_encode("0123456789abcdefghijklmnopqrstu",  "\xbf\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6a\x6b\x6c\x6d\x6e\x6f\x70\x71\x72\x73\x74\x75");
    check_mp_encode("0123456789ABCDEFGHIJKLMNOPQRSTUV", "\xd9\x20\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x41\x42\x43\x44\x45\x46\x47\x48\x49\x4a\x4b\x4c\x4d\x4e\x4f\x50\x51\x52\x53\x54\x55\x56");

    check_mp_encode(true, "\xc3");
    check_mp_encode(false, "\xc2");
    check_mp_encode(Void, "\xc0");

    check_mp_encode(cast(Any) 13, "\x0d");
    check_mp_encode(cast(Any) true, "\xc3");
    check_mp_encode(cast(Any) "hello", "\xa5hello");

    check_mp_encode(Any.[42, s32.[1, 2, 3], false, "ok"], "\x94\x2a\x93\x01\x02\x03\xc2\xa2\x6f\x6b");

    {
        t: HT.Table(int, string);
        HT.table_add(*t, 3, "a");
        HT.table_add(*t, 2, "b");
        HT.table_add(*t, 1, "c");
        check_mp_encode(t, "\x83\x02\xa1\x62\x03\xa1\x61\x01\xa1\x63");
    }

    {
        S :: struct(T: Type = u8) @EncodeAsMap {
            a: int;
            b: string;
            c: bool;
            d: [] T = .[1, 2, 3];
            f :: 420;
        };
        context.encode_struct_as_map = false;
        check_mp_encode(S.{ a = 69, b = "nice", c = true }, "\x84\xa1a\x45\xa1b\xa4nice\xa1c\xc3\xa1d\x93\x01\x02\x03");
    }

    {
        S :: struct(T: Type = u8) @EncodeAsArray {
            a: int;
            b: string;
            c: bool;
            d: [] T = .[1, 2, 3];
            f :: 420;
        };
        context.encode_struct_as_map = true;
        check_mp_encode(S.{ a = 13, b = "good", c = false }, "\x94\x0d\xa4good\xc2\x93\x01\x02\x03");
    }

    {
        S :: struct(T: Type = u8) {
            a: int;
            b: string;
            c: bool;
            d: [] T = .[1, 2, 3];
            f :: 420;
        };
        context.encode_struct_as_map = false;
        check_mp_encode(S.{ a = 48, b = "sup", c = false }, "\x94\x30\xa3sup\xc2\x93\x01\x02\x03");
        context.encode_struct_as_map = true;
        check_mp_encode(S.{ a = 48, b = "sup", c = false }, "\x84\xa1a\x30\xa1b\xa3sup\xa1c\xc2\xa1d\x93\x01\x02\x03");
    }

    {
        MP_Bytes_Wrapper :: struct {
            mp: [] u8;
            mp_encode_to_builder :: (builder: *String_Builder, x: MP_Bytes_Wrapper) {
                append(builder, x.mp.data, x.mp.count);
            };
        };
        #assert size_of(MP_Bytes_Wrapper) == 16;
        s : MP_Bytes_Wrapper;
        s.mp = xx "\xc3\x03210";
        check_mp_encode(s, xx s.mp);

        S :: struct {
            bytes: MP_Bytes_Wrapper;
            x, y: int;
            name: string;
        };
        check_mp_encode(S.{ bytes = s, x = 13, y = 37, name = "foo" }, "\x84\xa5bytes\xc3\x03210\xa1x\x0d\xa1y\x25\xa4name\xa3foo");
    }
}

test_msgpack_decode :: () {
    check_mp_decode :: (mp: string, expected: $T) {
        mp_copy := mp;
        ok, res := mp_decode(*mp_copy, T);
        #if #run type_info(T).type == .ARRAY {
            Setup_Context_To_Print_Bytes_Array();
        }
        Setup_MP_Struct_Printer();
        assert(ok, "failed to decode value of type % from msgpack % (%)", T, array_view(mp), cast(MP_Printable) mp);
        assert(res == expected, "expected %, but got %", expected, res);
    }

    check_mp_decode("\xc3", true);
    check_mp_decode("\xc2", false);

    check_mp_decode("\xa0", "");
    check_mp_decode("\xa3yes", "yes");
    check_mp_decode("\xd9\x048bit", "8bit");
    check_mp_decode("\xda\x00\x0516bit", "16bit");
    check_mp_decode("\xdb\x00\x00\x00\x0532bit", "32bit");

    check_mp_decode("\x00", 0);
    check_mp_decode("\x12", 18);
    check_mp_decode("\x7f", 127);
    check_mp_decode("\xcc\x80", 128);
    check_mp_decode("\xd1\x00\x81", 129);
    check_mp_decode("\xcd\x00\x82", 130);
    check_mp_decode("\xd2\x00\x00\x00\x83", 131);
    check_mp_decode("\xce\x00\x00\x00\x84", 132);
    check_mp_decode("\xd3\x00\x00\x00\x00\x00\x00\x00\x85", 133);
    check_mp_decode("\xcf\x00\x00\x00\x00\x00\x00\x00\x86", 134);
    check_mp_decode("\xff", -1);
    check_mp_decode("\xe0", -32);
    check_mp_decode("\xd0\xdf", -33);
    check_mp_decode("\xd1\xff\xde", -34);
    check_mp_decode("\xd2\xff\xff\xff\xdd", -35);
    check_mp_decode("\xd3\xff\xff\xff\xff\xff\xff\xff\xdc", -36);

    S :: struct {
        name: string;
        x, y: int;
        is_enabled: bool;
    };
    operator == :: inline (l: S, r: S) -> bool {
        return l.name == r.name && l.x == r.x && l.y == r.y && l.is_enabled == r.is_enabled;
    }

    check_mp_decode("\x84\xa4name\xa3dog\xaais_enabled\xc2\xa1y\x20\xa1x\x30", S.{ "dog", 48, 32, false });
    check_mp_decode("\x94\xa3cat\x18\x22\xc3", S.{ "cat", 24, 34, true });

    {
        s: S;
        assert(mp_decode_struct_into(*"\x93\xa3cat\x18\x22", *s) == false);
        // check_mp_decode("\x93\xa3cat\x18\x22", S.{ "cat", 24, 34, true });
        assert(mp_decode_struct_into(*"\x85\xa4name\xa3dog\xaais_enabled\xc2\xa1y\x20\xa1x\x30\xa5flags\x66", *s) == false);
        // check_mp_decode("\x85\xa4name\xa3dog\xaais_enabled\xc2\xa1y\x20\xa1x\x30\xa5flags\x66", S.{ "dog", 48, 32, false });
    }
}

test_msgpack :: () {
    test_msgpack_encode();
    test_msgpack_decode();

    // mp_print(*"\x20");
    // print("\n");

    // mp_print(*"\x80");
    // print("\n");

    // mp_print(*"\x81\x01\x02");
    // print("\n");

    // mp_print(*"\x84\xa1a\x01\xa1b\x02\xa1c\x03\xa3arr\x93\xc0\xc2\xc3");
    // print("\n");

    // mp_print(*"\x84\x45\x69\x7f\x90\x93\x01\x02\x03\xa3abc\xa3arr\x93\xc0\xc2\xc3");
    // print("\n");

}

////////////////////////////////////////////////////////////////////////////////
// lua
////////////////////////////////////////////////////////////////////////////////

tarantool_eval :: inline (code: string, $T: Type, args: .. Any) -> ok: bool, res: T {
    L := tarantool.luaT_state();
    ok, res := lua_eval(L, code, T, .. args);
    return ok, res;
}

lua_eval :: (L: *Tarantool_API.lua_State, code: string, $T: Type, args: .. Any) -> ok: bool, res: T {
    using tarantool;

    top := lua_gettop(L);
    need_stack_pop := true;
    defer if need_stack_pop lua_settop(L, top);

    res : T = ---;

    context.lua_string_reader.data = code;
    rc := lua_load(L, Lua_String_Reader.callback, *context, "my_proc.<eval>");
    if rc != 0 then {
        if context.log_errors log_error("lua_load failed");
        return ok = false, res;
    }

    n_args := 0;
    for args {
        ok := lua_push_value(L, it);
        if !ok return ok = false, res;
        n_args += 1;
    }

    rc = lua_pcall(L, xx n_args, -1, 0);
    if rc != 0 {
        if context.log_errors log_error("failed calling lua function");
        return ok = false, res;
    }

    new_top := lua_gettop(L);

    ok := true;

    ok, res = lua_read_values(L, T, top + 1, new_top - top);
    #if T == Multiple_Values_On_Lua_Stack {
        need_stack_pop = false;
    }

    return ok, res;
}

lua_push_value :: (L: *Tarantool_API.lua_State, v: Any) -> ok: bool {
    using tarantool;
    ti := cast(*Type_Info) v.type;
    if ti.type == {
        case .INTEGER;
            value: s64;
            info := cast(*Type_Info_Integer) ti;
            size := info.runtime_size;
            if info.signed if size == {
                case 1; value = << cast(*s8)  v.value_pointer;
                case 2; value = << cast(*s16) v.value_pointer;
                case 4; value = << cast(*s32) v.value_pointer;
                case 8; value = << cast(*s64) v.value_pointer;
                case; assert(false);
            } else if size == {
                case 1; value = << cast(*u8)  v.value_pointer;
                case 2; value = << cast(*u16) v.value_pointer;
                case 4; value = << cast(*u32) v.value_pointer;
                case 8;
                    t := << cast(*u64) v.value_pointer;
                    if t > xx,no_check 0x7fff_ffff_ffff_ffff {
                        if context.log_errors log_error("attempt to convert % to s64 would result in overflow", t);
                        return ok = false;
                    }
                    value = xx,no_check t;
                case; assert(false);
            }
            lua_pushinteger(L, value);
            return ok = true;
        case .STRING;
            s := << cast(*string) v.value_pointer;
            lua_pushlstring(L, s.data, xx s.count);
            return ok = true;
        case;
            if context.log_errors log_error("lua_push_value for % is not implemented yet", v.type);
            return ok = false;
    }
}

lua_read_values :: inline (L: *Tarantool_API.lua_State, $T: Type, start_index: s32, count: s32) -> ok: bool, res: T {
    using tarantool;
    res : T = ---;

    #if T == void {
        // Is always ok
        return true, res;
    }

    if !count {
        if context.log_errors log_error("failed reading value of type % from lua stack, because there are no values", T);
        return false, res;
    }

    ok := true;

    ti_type :: #run type_info(T).type;
    #if T == Multiple_Values_On_Lua_Stack {
        res = Multiple_Values_On_Lua_Stack.{ L, start_index, count };
    } else #if ti_type == .INTEGER {
        res = xx lua_tointeger(L, start_index);
    } else #if ti_type == .FLOAT {
        res = xx lua_tonumber(L, start_index);
    } else #if ti_type == .STRING {
        res.data = lua_tolstring(L, start_index, xx *res.count);
    } else #if ti_type == .BOOL {
        res = xx lua_toboolean(L, start_index);
    } else {
        ok = false;
    }
    return ok, res;
}

Multiple_Values_On_Lua_Stack :: struct {
    L : *Tarantool_API.lua_State;
    start_index : s32;
    count : s32;
}

////////////////////////////////////////////////////////////////////////////////
//
////////////////////////////////////////////////////////////////////////////////

Multiple_Values :: struct(value_types: .. Type) {
    #insert #run -> string {
        builder: String_Builder;
        for value_types {
            print_to_builder(*builder, "field_% : %;", it_index, it);
        }
        return builder_to_string(*builder);
    };
}

Lua_String_Reader :: struct {
    data: string;

    callback : Tarantool_API.lua_Reader : (L: *Tarantool_API.lua_State, ud: *void, sz: *u64) -> *u8 #c_call {
        new_context := cast(*Context) ud;
        push_context,defer_pop new_context.*;

        // log("lua_reader is called");

        using context.lua_string_reader;
        sz.* = xx data.count;
        data.count = 0;

        return data.data;
    };
};

#add_context lua_string_reader : Lua_String_Reader;
#add_context log_errors : bool = true;
#add_context encode_struct_as_map : bool = false;

tarantool : Tarantool_API;
Tarantool_API :: struct {
    box_schema_version : () -> u64 #c_call;

    luaT_state : () -> *lua_State #c_call;
    lua_load : (L: *lua_State, reader: lua_Reader, dt: *void, chunkname: *u8) -> s32 #c_call;
    lua_call : (L: *lua_State, nargs: s32, nresults: s32) -> void #c_call;
    lua_pcall : (L: *lua_State, nargs: s32, nresults: s32, errfunc: s32) -> s32 #c_call;
    lua_tonumber : (L: *lua_State, idx: s32) -> float64 #c_call;
    lua_tointeger : (L: *lua_State, idx: s32) -> s64 #c_call;
    lua_toboolean : (L: *lua_State, idx: s32) -> s32 #c_call;
    lua_tolstring : (L: *lua_State, idx: s32, len: *size_t) -> *u8 #c_call;
    lua_gettop : (L: *lua_State) -> s32 #c_call;
    lua_settop : (L: *lua_State, idx: s32) -> void #c_call;

    lua_pushnil : (L: *lua_State) -> void #c_call;
    lua_pushnumber : (L: *lua_State, n: lua_Number) -> void #c_call;
    lua_pushinteger : (L: *lua_State, n: lua_Integer) -> void #c_call;
    lua_pushlstring : (L: *lua_State, s: *u8, l: size_t) -> void #c_call;
    lua_pushstring : (L: *lua_State, s: *u8) -> void #c_call;

    lua_State :: struct {};
    lua_Reader :: #type (L: *lua_State, ud: *void, sz: *u64) -> *u8 #c_call;
    lua_Number :: float64;
    lua_Integer :: s64;

    load :: () -> Tarantool_API #expand {
        lib := dlopen(null, RTLD_LAZY | RTLD_LOCAL);

        result : Tarantool_API;
        #insert #run -> string {
            builder: String_Builder;

            ti := type_info(Tarantool_API);
            for member: ti.members {
                if member.type.type != .PROCEDURE continue;
                ti_proc := cast(*Type_Info_Procedure) member.type;
                if !(ti_proc.procedure_flags & .IS_C_CALL) {
                    continue;
                }

                print_to_builder(*builder, "result.%1 = dlsym(lib, \"%1\");\n", member.name);
            }

            return builder_to_string(*builder);
        };

        tarantool = result;
        return result;
    };
}

print_mp :: (v: $T) {
    builder: String_Builder;
    mp_encode_to_builder(*builder, v);
    s := builder_to_string(*builder);
    defer free(s);
    print_bytes(s);
}

print_bytes :: (s: string, add_newline := true) {
    Setup_Context_To_Print_Bytes_Array();
    print("%", array_view(s));
    if add_newline write_string("\n");
}

array_view :: inline (s: string) -> [] u8 {
    a : [] u8 = ---;
    a.data = s.data;
    a.count = s.count;
    return a;
}

Setup_Context_To_Print_Bytes_Array :: () #expand {
    old_default_format_int := context.print_style.default_format_int;
    `defer context.print_style.default_format_int = old_default_format_int;

    old_default_format_array := context.print_style.default_format_array;
    `defer context.print_style.default_format_array = old_default_format_array;

    context.print_style.default_format_int = FormatInt.{ base = 16, minimum_digits = 2 };
    context.print_style.default_format_array = FormatArray.{
        separator = "\\x",
        begin_string = "b'\\x",
        end_string = "'",
    };
}

Setup_MP_Struct_Printer :: () #expand {
    old_struct_printer := context.print_style.struct_printer;
    `defer context.print_style.struct_printer = old_struct_printer;
    context.print_style.struct_printer = mp_struct_printer;
}

print_hex :: (v: u64, add_newline := true) {
    new_context := context;
    new_context.print_style.default_format_int = FormatInt.{ base = 16, minimum_digits = 8 };
    push_context new_context {
        print("%", v);
        if add_newline write_string("\n");
    }
}

print_hex :: inline (v: s64, add_newline := true) {
    print_hex(cast,no_check(u64) v, add_newline);
}

// lol
Void :: #run -> void {
    res : void = ---;
    return res;
};

Init_Context :: () #expand {
    new_context : Context;
    `push_context,defer_pop new_context;
}

#import "POSIX";
#import "Basic";
HT :: #import "Hash_Table";
#import,file "../msgpack.jai";
