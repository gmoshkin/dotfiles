type_of_null :: () {
    print("%\n", type_of(null));

    assert(type_of(null) == *void);

    p : *void = xx 0;
    assert(p == null);

    p = xx 1;

    c : *u8 = p;
    print("%\n", c);
}

bake_polymorph :: () {
    foo :: (v: $T) -> string {
        #if       T == int   return "int";
        else #if T == string return v;
        else                 return "other";
    }

    foo_42 :: #bake_arguments foo(v = 42);
    foo_int :: #procedure_of_call foo(v = 42);
    foo_string :: #bake_constants foo(T = string);

    print("%\n", foo(42));
    print("%\n", foo(4.2));
    print("%\n", foo_42());
    print("%\n", foo_int(420));
    // print("%\n", foo_int("not int"));
    print("%\n", foo("not int"));
    // print("%\n", foo_string(3));
    print("%\n", foo_string("another not int"));
}

global_variable : *void;

Big_Struct :: struct {
    data: [128] u8;
    data[10] = 7;
}
return_big_struct :: () -> Big_Struct {
    result: Big_Struct;
    result.data[11] = 8;
    /// Uncomment any of this, and the return value will stop being constructed
    /// in place on the caller side.
    // global_variable = *result.data;
    // s := "some data";
    // for i: 0..s.count-1 {
    //     result.data[11 + i] = s[i];
    // }
    // memcpy(result.data.data, s.data, s.count);
    return result;
}

check_return_big_struct :: () {
    big_struct := return_big_struct();
    print("%\n", big_struct);
    print("gvar %\n", global_variable);
}

check_uninit_of :: () {
    uninitialized_of :: ($T: Type) -> T #expand {
        uninitialized: T = ---;
        return uninitialized;
    }

    print("%\n", uninitialized_of(int));
    print("%\n", uninitialized_of(u8));
    print("%\n", uninitialized_of(string));
}

Small_String :: struct {
    count: s64; // shifted left by one byte
    data: *u8;

    #place count;
    inline_count: s8; // 0..15 = inlined, -128..-1,16..127 = pointer
    inline_data: [15] u8;
}

#assert size_of(Small_String) == size_of(string);

to_small_string :: (big: string) -> Small_String {
    if !big.count return .{};

    result: Small_String = ---;
    if 0 <= big.count && big.count <= 15 {
        result.inline_count = xx,no_check big.count;
        memcpy(result.inline_data.data, big.data, big.count);
    } else {
        result.count = (big.count << 8) | 0xff; // result.inline_count == -1;
        result.data = big.data;
    }
    return result;
}

small_string_encode :: to_small_string;

to_string :: (small: Small_String) -> string {
    if !small.count return "";

    result: string = ---;

    if small.inline_count == -1 { // big
        result.count = small.count >> 8;
        result.data = small.data;
    } else {
        result.count = small.inline_count & 0x0f;
        result.data = small.inline_data.data;
    }

    return result;
}

small_string_decode :: #procedure_of_call to_string(Small_String.{});

check_small_string :: () {
    s: string;
    ss: Small_String;

    ss.inline_count = 0x10;
    log("% [%, %]: '%'", ss, ss.inline_count, ss.inline_data, to_string(ss));

    ss.count = 16;
    log("% [%, %]: '%'", ss, ss.inline_count, ss.inline_data, to_string(ss));

    ss = to_small_string("");
    log("% [%, %]: '%'", ss, ss.inline_count, ss.inline_data, to_string(ss));

    ss = to_small_string("0123456789abcde");
    log("% [%, %]: '%'", ss, ss.inline_count, ss.inline_data, to_string(ss));

    ss = to_small_string("01");
    log("% [%, %]: '%'", ss, ss.inline_count, ss.inline_data, to_string(ss));

    ss = to_small_string("0123456789abcdef");
    log("% [%, %]: '%'", ss, ss.inline_count, ss.inline_data, to_string(ss));
}

defer_is_not_like_in_go :: (do_early_exit: bool) {
    defer log("in outer scope");
    {
        defer log("in inner scope");
        if do_early_exit return;
    }
    defer log("in outer scope but at the end");
}

main :: () {
    print("\n### type_of_null:\n\n");                   type_of_null();
    print("\n### bake_polymorph:\n\n");                 bake_polymorph();
    print("\n### check_return_big_struct:\n\n");        check_return_big_struct();
    print("\n### check_uninit_of:\n\n");                check_uninit_of();
    print("\n### check_small_string:\n\n");             check_small_string();
    print("\n### defer_is_not_like_in_go(false):\n\n"); defer_is_not_like_in_go(false);
    print("\n### defer_is_not_like_in_go(true):\n\n");  defer_is_not_like_in_go(true);
}

#import "Basic";
