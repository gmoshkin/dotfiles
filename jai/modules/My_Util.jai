#module_parameters() (TEST := false);
//
// string utilities
//

NOT_SPECIFIED :: 0x7fff_ffff_ffff_ffff;
substring :: (s: string, start := 0, end := NOT_SPECIFIED, count := NOT_SPECIFIED) -> string {
    _count := count;
    _start := ifx start < 0 then s.count + start else start;
    if end == NOT_SPECIFIED && count == NOT_SPECIFIED {
        _count = s.count - _start;
    } else {
        assert(end == NOT_SPECIFIED || count == NOT_SPECIFIED);
        _end := ifx end < 0 then s.count + end else end;
        if count == NOT_SPECIFIED then _count = _end - _start;
    }
    assert(_start >= 0, "start: %, end: %, count: %", start, end, count);
    assert(_start <= s.count, "start: %, end: %, count: %", start, end, count);
    assert(_count >= 0, "start: %, end: %, count: %", start, end, count);
    assert(_start + _count <= s.count, "start: %, end: %, count: %", start, end, count);

    return string.{ data = s.data + _start, count = _count };
}

//
// string builder utilities
//

to_string :: inline (buffer: *String_Builder.Buffer) -> string {
    return string.{ data = get_buffer_data(buffer), count = buffer.count };
}

append_padding :: inline (builder: *String_Builder, count: s64, $padding := " ") {
    #assert(padding.count == 1); // TODO: it's pretty easy actually to support other counts
    global_buffer :: #run -> string {
        buffer: [] u8;
        buffer.count = 64;
        buffer.data = alloc(buffer.count);
        for *buffer it.* = padding[0];
        return xx add_global_data(buffer, .READ_ONLY);
    };

    n_repeats := count / global_buffer.count;
    for 1..n_repeats {
        append(builder, global_buffer);
    }

    tail := global_buffer;
    tail.count = count % global_buffer.count;
    append(builder, tail);
}

test_append_padding :: () {
    Check :: ($n: int, $padding: string) #expand {
        builder: String_Builder;
        append_padding(*builder, n, padding);
        s := builder_to_string(*builder);
        assert(s.count == n);
        for cast([] u8) s assert(it == padding[0]);
    }

    Check(3, " ");
    Check(65, " ");
    Check(64 * 7 + 13, " ");
    Check(3, "!");
    Check(65, "2");
    Check(64 * 7 + 13, "@");
}

//
// ascii escape sequence handling
//

eat_visible_or_escape_sequence :: (text: string) -> head: string, visible_count: s64, tail: string {
    if !text return "", 0, "";

    count := find_index_from_left(text, #char "\e");
    if count < 0 then count = text.count;

    if count > 0 {
        // Visible character sequence
        head := substring(text, 0, count = count);
        tail := substring(text, count);
        return head, count, tail;
    }

    // Escape sequence
    count += 1;

    if count < text.count {
        char := text[count];
        if char == #char "[" {
            count += 1;
            while count < text.count {
                char = text[count];
                count += 1;

                if char == #char "m" break;
            }
        } else {
            // TODO: don't care about other escape codes for now
        }
    }

    head := substring(text, 0, count = count);
    tail := substring(text, count);
    return head, 0, tail;
}

count_visible_characters :: (text: string) -> visible_count: s64 {
    if !text return 0;

    visible_count := 0;
    cursor := 0;
    while cursor < text.count {
        index := find_index_from_left(text, #char "\e", cursor);
        if index < 0 return visible_count + text.count - cursor;

        visible_count += index - cursor;
        cursor = index + 1; // `+ 1` to skip the current "\e"

        char := text[cursor];
        if char == #char "[" {
            cursor += 1;
            while cursor < text.count {
                char = text[cursor];
                cursor += 1;

                if char == #char "m" break;
            }
        } else {
            // TODO: don't care about other escape codes for now
        }
    }
    return visible_count;
}

//
// pretty assert
//

// Constant structs don't work with compile time constructs yet, so we return
// all fields directly
get_expr_info :: (code: Code) -> kind: Code_Node.Kind, op_type: s32, full_expr: string, proc_expr: string, lhs: Code, rhs: Code {
    #import "Program_Print";

    root := compiler_get_nodes(code);

    builder: String_Builder;
    print_expression(*builder, root);
    full_expr := builder_to_string(*builder);

    if root.kind == {
        case .BINARY_OPERATOR;
            binop := cast(*Code_Binary_Operator) root;
            op_type := binop.operator_type;
            lhs := compiler_get_code(binop.left, code);
            rhs := compiler_get_code(binop.right, code);
            return xx root.kind, op_type, full_expr, "", lhs, rhs;

        case .PROCEDURE_CALL;
            proccall := cast(*Code_Procedure_Call) root;
            if proccall.arguments_sorted.count != 2 {
                dummy : Code = #code null;
                return xx root.kind, -1, full_expr, "", dummy, dummy;
            }

            builder: String_Builder;
            print_expression(*builder, proccall.procedure_expression);
            proc_expr := builder_to_string(*builder);

            lhs := compiler_get_code(proccall.arguments_sorted[0], code);
            rhs := compiler_get_code(proccall.arguments_sorted[1], code);
            return xx root.kind, -1, full_expr, proc_expr, lhs, rhs;

        case;

    }

    dummy : Code = #code null;
    return xx root.kind, -1, full_expr, "", dummy, dummy;
}

pretty_assert :: (code: Code, loc := #caller_location) #expand {
    if #insert code return;

    if context.handling_assertion_failure  return;  // Avoid infinite loops.
    context.handling_assertion_failure = true;

    kind, op_type, full_expr, proc_expr, lhs, rhs :: #run get_expr_info(code);

    message := "";

    #if kind == .BINARY_OPERATOR {
        builder : String_Builder;
        builder.allocator = temporary_allocator;

        print_to_builder(*builder, "(%) = (% ", full_expr, #insert lhs);

        if op_type < 128 {
            append(*builder, cast(u8) op_type);
        } else {
            append(*builder, operator_to_string(xx op_type));
        }

        print_to_builder(*builder, " %) = false", #insert rhs);
        message = builder_to_string(*builder, temporary_allocator);
    } else #if kind == .PROCEDURE_CALL {
        message = tprint("(%) = (%(%, %)) = false", full_expr, proc_expr, #insert lhs, #insert rhs);
    } else {
        message = tprint("(%) = false", full_expr);
    }

    // We provide 'loc' in case _STACK_TRACE is turned off, but assertion_failed may well
    // look at the stack trace if it is available.
    context.assertion_failed(loc, message);
    context.handling_assertion_failure = false;

} @NoProfile

//
// Mem_Dump
//

Setup_Mem_Dump_Printer :: () #expand {
    old_struct_printer := context.print_style.struct_printer;
    `defer context.print_style.struct_printer = old_struct_printer;
    context.print_style.struct_printer = mem_dump_printer;
}

Mem_Dump :: #type,distinct [] u8;
mem_dump_printer :: (builder: *String_Builder, any: Any, data: *void) -> handled: bool {
    if any.type != type_info(Mem_Dump) return false;

    data := << cast(*[] u8) any.value_pointer;
    mem_dump_to_builder(builder, data);
    return true;
}

mem_dump_to_builder :: (builder: *String_Builder, data: [] u8) {
    old_default_format_int := context.print_style.default_format_int;
    defer context.print_style.default_format_int = old_default_format_int;
    context.print_style.default_format_int = FormatInt.{ base = 16, minimum_digits = 2 };

    leading_spaces := cast(s64) (cast(u64) data.data) % 16;
    start_addr := cast(* u8) (cast(u64) data.data) & 0xffff_ffff_ffff_fff0;

    print_to_builder(builder, "%: ", start_addr);
    for 0..(data.count + leading_spaces - 1) {
        if it < leading_spaces then
            append(builder, "  ");
        else
            print_to_builder(builder, "%", data[it - leading_spaces]);

        if (it + 1) % 16 == 0 && it + 1 != data.count + leading_spaces
            print_to_builder(builder, "\n%: ", start_addr + it + 1);
        else if (it + 1) % 4 == 0
            append(builder, " ");
    }
}

//
// flat pool utilities
//

flat_pool_allocated :: (pool: *Flat_Pool) -> s64 {
    return pool.current_point - pool.memory_base;
}

//
// private imports
//

#scope_module

#import "Basic";
#import "String";
#import "Compiler";
#import "Flat_Pool";
