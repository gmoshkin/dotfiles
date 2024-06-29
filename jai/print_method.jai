main :: () {
    ti := type_info(My_Struct);
    for ti.members {
        if !(it.flags & .CONSTANT) continue;
        assert(it.type.runtime_size == 8);
        data : **void = xx (ti.constant_storage.data + it.offset_into_constant_storage);
        print("%: %\n", it.name, data.*);
    }

    print("%\n", My_Struct.print);

    context.print_style.struct_printer = struct_printer_which_repsects_the_print_method;

    ms := My_Struct.{ 13, 37, "boo" };
    print("%\n", ms);

    print("%\n", type_info(**My_Struct));
}

struct_printer_which_repsects_the_print_method :: (builder: *String_Builder, any: Any, struct_printer_data: *void) -> bool {
    print(">>> any.type.type: %<<<", any.type.type);
    if any.type == type_info(*Type_Info) {
        type := << cast(**Type_Info) any.value_pointer;
        print_type_to_builder(builder, type);
        return true;
    }

    if any.type.type == .STRUCT {
        type_info_struct := cast(*Type_Info_Struct) any.type;
        for type_info_struct.members {
            if !(it.flags & .CONSTANT) continue;
            assert(it.offset_into_constant_storage >= 0, "must be so, if this is a constant");

            if it.type.type != .PROCEDURE continue;
            it_type := cast(*Type_Info_Procedure) it.type;
            assert(it_type.runtime_size == 8, "proc is a proc pointer");

            if it.name != "print" continue;

            pointer_to_pointer : **void = xx (type_info_struct.constant_storage.data + it.offset_into_constant_storage);

            ok, proc := check_and_cast(it_type, pointer_to_pointer.*);
            if !ok continue;

            proc(builder, any);
            return true;
        }
    }

    return false;
}

Printer_Proc :: #type (builder: *String_Builder, any: Any);

check_and_cast :: (type: *Type_Info_Procedure, pointer: *void) -> (ok: bool, Printer_Proc) {
    result: Printer_Proc = ---;

    target_type := type_info(Printer_Proc);

    if type.argument_types.count != target_type.argument_types.count return false, result;
    for target_type.argument_types {
        if type.argument_types[it_index] != it return false, result;
    }

    if type.return_types.count != target_type.return_types.count return false, result;
    for target_type.return_types {
        if type.return_types[it_index] != it return false, result;
    }

    assert(type == type_info(Printer_Proc));

    result = xx pointer;
    return true, result;
}

My_Struct :: struct {
    x: int;
    y: int;
    name: string;


    print :: () {};
    print : Printer_Proc : (builder: *String_Builder, any: Any) {
        if any.type != type_info(My_Struct) {
            builder: String_Builder;
            print_type_to_builder(*builder, any.type);
            assert(any.type == type_info(*My_Struct), "%", builder_to_string(*builder,, temp));
        }
        using this := << cast(*My_Struct) any.value_pointer;

        print(builder, "%@(%, %)", name, x, y);
    };
}

#import "Basic";
