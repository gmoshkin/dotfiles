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

baked_proc :: () {
    // This proc is baked, it's not called via pointer!
    takes_proc :: ($cb: #type (int) -> string) {
        for 1..3 {
            res := cb(it);
            print("cb(%) = %\n", it, res);
        }
    }

    takes_proc((i: int) -> string {
        if i == {
            case 1; return "one";
            case 2; return "two";
            case 3; return "three";
            case;   return "idk";
        }
    });
}

null_any_test :: () {
    default_any: Any;
    print("default_any: value_pointer: %, type: %\n", default_any.value_pointer, default_any.type);

    any_set_to_null: Any = null;
    print("any_set_to_null: value_pointer: %, type: %\n", any_set_to_null.value_pointer, any_set_to_null.type);

    any_set_to_default_any: Any = Any.{};
    print("any_set_to_default_any: value_pointer: %, type: %\n", any_set_to_default_any.value_pointer, any_set_to_default_any.type);

    assert(default_any.value_pointer == any_set_to_default_any.value_pointer);
    assert(default_any.type == any_set_to_default_any.type);
}

div_mod_precedence :: () {
    expr :: "123 / 10 % 10;";
    print("% = %\n", expr, #insert expr);
}

#no_reset procs: [..] #type ();
no_reset_global_array :: () {
    // This doesn't actually work, the pointers in procs are left invalid
    print("doesn't work :(\n");
    // for procs it();

    #run { array_add(*procs, f1); }
    #run { array_add(*procs, f2); }
    #run { array_add(*procs, f3); }
}

f1 :: () { print("f1\n"); }
f2 :: () { print("bar\n"); }
f3 :: () { print("f3\n"); }

Stack_Or_Temporary_Storage :: struct (total_size_on_stack := 4096) {
    Metadata :: struct {
        stack_allocated: s64;
    }
    #as using metadata: Metadata;

    stack_buffer_size :: total_size_on_stack - size_of(Metadata);
    stack_buffer: [stack_buffer_size] u8;
}

stack_or_temporary_allocator_proc :: (mode: Allocator_Mode, requested_size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void {
    if !allocator_data {
        return temporary_allocator_proc(mode, requested_size, old_size, old_memory, allocator_data);
    }

    allocator := cast(*Stack_Or_Temporary_Storage) allocator_data;
    using allocator;

    if #complete mode == {
      case .FREE;
        return null;
      case .RESIZE;
        if (old_memory >= stack_buffer.data) && (old_memory < stack_buffer.data + stack_buffer.count) {
            if old_memory == stack_buffer.data + stack_allocated - old_size {
                // This is the latest stack allocation, just resize it
                if old_memory + requested_size <= stack_buffer.data + stack_buffer.count {
                    stack_allocated += requested_size - old_size;
                    return old_memory;
                }
            }
        }
        #through;
      case .ALLOCATE;
        if requested_size > stack_buffer.count - stack_allocated {
            return temporary_allocator_proc(mode, requested_size, old_size, old_memory, allocator_data);
        }

        result := stack_buffer.data + stack_allocated;
        if mode == .RESIZE then memcpy(result, old_memory, min(old_size, requested_size));
        stack_allocated += requested_size;
        return result;

      case .STARTUP;      #through;
      case .SHUTDOWN;
        return null;

      case .THREAD_START; #through;
      case .THREAD_STOP;
        assert(false, "Multithreaded access is not supported by stack_or_temporary_allocator_proc.\n");
        return null;

      case .CREATE_HEAP; #through;
      case .DESTROY_HEAP;
        assert(false, "Create/Destroy heap are not supported by stack_or_temporary_allocator_proc.\n");
        return null;

      case .IS_THIS_YOURS;
        if (old_memory >= stack_buffer.data) && (old_memory < stack_buffer.data + stack_buffer.count) return cast(*void) true;
        return temporary_allocator_proc(mode, requested_size, old_size, old_memory, allocator_data);

      case .CAPS;
        if old_memory { <<cast(*string)old_memory = "stack_or_temporary_allocator_proc"; }
        return cast(*void)(Allocator_Caps.HINT_I_AM_PER_FRAME_TEMPORARY_STORAGE);
    }
}

Stack_Or_Temporary_Allocator :: (total_size_on_stack := 4096) -> Allocator #expand {
    `allocator: Stack_Or_Temporary_Storage(total_size_on_stack = total_size_on_stack);
    return Allocator.{ stack_or_temporary_allocator_proc, *allocator };
}

type_info_void :: () {
    #run print("################################################################################\n");
    #run print("%\n", type_info(void).*);
    #run print("%\n", type_info(string).*);
    polymorphic_proc :: (v: $T = 1) -> s64 {
        return type_info(T).runtime_size;
    }

    #run {
        info := type_info(type_of(polymorphic_proc));

        print("%\n", info.*);
        for info.argument_types {
            print("%\n", it.*);
        }
    }

    overloaded_proc :: (v := 1) -> s64 { return v; }
    overloaded_proc :: (v: string) -> s64 { return v.count; }

    #run {
        info := type_info(type_of(#procedure_of_call overloaded_proc()));

        print("%\n", info.*);
        for info.argument_types {
            print("%\n", it.*);
        }

        #import "Compiler";
        code := compiler_get_nodes(overloaded_proc);
        print("%\n", code.*);
    }
}

stack_or_temporary_allocator :: () {
    print("size_of(Stack_Or_Temporary_Storage): %\n", size_of(Stack_Or_Temporary_Storage));
    print("Stack_Or_Temporary_Storage.stack_buffer.count: %\n", Stack_Or_Temporary_Storage(4096).stack_buffer.count);

    stack_or_temporary_allocator_data: Stack_Or_Temporary_Storage;
    using stack_or_temporary_allocator_data;
    stack_or_temp := Allocator.{ stack_or_temporary_allocator_proc, *stack_or_temporary_allocator_data };

    p1_size := 10;
    p1 := alloc(p1_size,, stack_or_temp);
    assert(p1 == stack_buffer.data);
    assert(stack_allocated == p1_size);

    p2_size := 20;
    p2 := realloc(p1, p2_size, p1_size,, stack_or_temp);
    assert(p2 == p1, "% == % failed!", p2, p1);
    assert(stack_allocated == p2_size);

    p3_size := 30;
    p3 := alloc(p3_size,, stack_or_temp);
    assert(p3 == p2 + p2_size);
    assert(stack_allocated == p2_size + p3_size);

    p4_size := 30;
    p4 := realloc(p2, p4_size, p2_size,, stack_or_temp);
    assert(p4 == p3 + p3_size);
    assert(stack_allocated == p2_size + p3_size + p4_size);

    array: [..] u8;
    array.allocator = stack_or_temp;
    array_add(*array, ..cast([]u8) "abcdef");
    array_data_1 := array.data;
    array_add(*array, ..cast([]u8) "ghi");
    array_add(*array, ..cast([]u8) "jklmnop");
    array_add(*array, ..cast([]u8) "qr");
    array_add(*array, ..cast([]u8) "s");
    array_add(*array, ..cast([]u8) "t");
    array_add(*array, ..cast([]u8) "uvwxyz");
    assert(array_data_1 == array.data, "% == % failed!", array_data_1, array.data);

    s1 := sprint("hello %", "world",, Stack_Or_Temporary_Allocator());
    // this won't compile and it's a good thing, cause you shouldn't be using this macro often anyways
    // s2 := sprint("here's an array: %", u8.[1,2,3],, Stack_Or_Temporary_Allocator());
}

visit_macro :: () {
    Visit :: (base: $T, $branches: .. Code) #expand {
        base_type :: #run type_info(T);

        #insert #run -> string {
            builder: String_Builder;
            defer reset(*builder);

            target_tag := base_type.type;
            print(*builder, #string JAI
if get_tag_for_dispatch(base) == {
                  JAI);

            for branches {
                base_code := compiler_get_nodes(it);

                assert(base_code.kind == .PROCEDURE_HEADER);
                code := cast(*Code_Procedure_Header) base_code;
                assert(code.arguments.count == 1);
                argument := code.arguments[0];
                argument_type := argument.type_inst.result;

                type_tag := get_tag_from_argument_type(argument_type);
                type_string := type_to_string(argument_type);
                print(*builder, #string JAI
    case .%;
        callback :: #insert branches[%];
        callback(do_downcast(base, %));
                                        JAI, type_tag, it_index, type_string);
            }

            print(*builder, #string JAI
}
                  JAI);
            return builder_to_string(*builder);
        };
    }

    captured_data := string.["here's", "some", "data"];

    types := (*Type_Info).[
        type_info(s64),
        type_info(string),
        type_info(float32),
        type_info(u8),
        type_info(*void),
        type_info(*Type_Info),
    ];
    for types {
        Visit(it,
            (type: *Type_Info_Integer) {
                print("got int: signed: %, size: %\n", type.signed, type.runtime_size);
            },
            (type: *Type_Info_String) #expand {
                print("type info string is boring, here's some captured data instead: %\n", captured_data);
            },
            (type: *Type_Info_Float) {
                print("got float%\n", ifx type.runtime_size == 4 then "32" else "64");
            },
            (type: *Type_Info_Pointer) {
                print("got pointer\n");
            },
        );
    }
}

//
// Setup Visit for Type_Info
//
get_tag_for_dispatch :: (type: *Type_Info) -> Type_Info_Tag {
    return type.type;
}

do_downcast :: (source: *Type_Info, $T: Type) -> T {
    return cast(T) source;
}

get_tag_from_argument_type :: (base_type: *Type_Info) -> Type_Info_Tag {
    assert(base_type.type == .POINTER);
    type := cast(*Type_Info_Pointer) base_type;
    assert(type.pointer_to.type == .STRUCT);
    pointee := cast(*Type_Info_Struct) type.pointer_to;
    if pointee.name == {
        case "Type_Info_Integer";   return .INTEGER;
        case "Type_Info_Float";     return .FLOAT;
        case "Type_Info_String";    return .STRING;
        case "Type_Info_Pointer";   return .POINTER;
        case "Type_Info_Procedure"; return .PROCEDURE;
        case "Type_Info_Struct";    return .STRUCT;
        case "Type_Info_Array";     return .ARRAY;
        case "Type_Info_Enum";      return .ENUM;
        case "Type_Info_Variant";   return .VARIANT;
    }

    assert(false, "unknown struct '%'", pointee.name);
    return xx,no_check -1;
}

main :: () {
    print("\n### type_of_null:\n\n");                   type_of_null();
    print("\n### bake_polymorph:\n\n");                 bake_polymorph();
    print("\n### check_return_big_struct:\n\n");        check_return_big_struct();
    print("\n### check_uninit_of:\n\n");                check_uninit_of();
    print("\n### check_small_string:\n\n");             check_small_string();
    print("\n### defer_is_not_like_in_go(false):\n\n"); defer_is_not_like_in_go(false);
    print("\n### defer_is_not_like_in_go(true):\n\n");  defer_is_not_like_in_go(true);
    print("\n### baked_proc:\n\n");                     baked_proc();
    print("\n### null_any_test:\n\n");                  null_any_test();
    print("\n### div_mod_precedence:\n\n");             div_mod_precedence();
    print("\n### no_reset_global_array:\n\n");          no_reset_global_array();
    print("\n### test_append_padding:\n\n");            test_append_padding();
    print("\n### stack_or_temporary_allocator:\n\n");   stack_or_temporary_allocator();
    print("\n### visit_macro:\n\n");                    visit_macro();
}

#import "Basic";
#import "Print_Vars";
#import "My_Util";
