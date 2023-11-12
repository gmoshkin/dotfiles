//
// recursive struct printer {{{
//

#import "Hash_Table";
#import "Basic";
Pointer_Cache :: Table(*void, void);

recursive_struct_printer :: (builder: *String_Builder, any: Any, struct_printer_data: *void) -> bool {
    already_seen := cast(*Pointer_Cache) struct_printer_data;

    if any.type.type == {
        case .STRUCT; return false;
        case .POINTER; {

            pointer := << cast(**void) any.value_pointer;
            u64_val := cast(u64) pointer;
            if u64_val {
                default := context.print_style.default_format_absolute_pointer;
                default.value = u64_val;
                print_integer(builder, default);
            } else {
                append(builder, "null");
                return true;
            }

            if table_contains(already_seen, pointer) {
                print_to_builder(builder, " = <ALREADY PRINTED>");
                return true;
            } else {
                Void : void;
                table_set(already_seen, pointer, Void);

                pointee_any : Any;
                pointee_any.value_pointer = pointer;
                pt := cast(*Type_Info_Pointer)(any.type);
                pointee_any.type = pt.pointer_to;
                print_to_builder(builder, " = *%", pointee_any);

                return true;
            }
        }
    }
    print_to_builder(builder, "%", any.type.type);
    return true;
}

Setup_Recursive_Struct_Printer :: () #expand {
    temp_context := context;

    temp_context.print_style.default_format_struct.draw_type_name = true;
    temp_context.print_style.default_format_struct.use_long_form_if_more_than_this_many_members = -1;
    temp_context.print_style.default_format_struct.use_newlines_if_long_form = true;
    temp_context.print_style.struct_printer = recursive_struct_printer;

    already_seen: Pointer_Cache;
    `defer deinit(*already_seen);

    temp_context.print_style.struct_printer_data = *already_seen;

    `push_context,defer_pop temp_context;
}

//
// }}}
//

main :: () {
    Node :: struct {
        next: *Node;
        value: int;
    }

    node_storage: [64]Node;
    root := *node_storage[0];
    root.value = 1;
    root.next = *node_storage[1];
    root.next.value = 2;
    root.next.next = *node_storage[2];
    root.next.next.value = 3;
    root.next.next.next = *node_storage[3];
    root.next.next.next.value = 4;
    root.next.next.next.next = *node_storage[1];

    print("=== RECURSIVE ===\n");
    {
        Setup_Recursive_Struct_Printer();
        print("%\n", root);
    }
    print("=== NON RECURSIVE ===\n");
    print("%\n", root);
}
