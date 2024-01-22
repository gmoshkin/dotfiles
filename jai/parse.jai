Node :: struct {
    type: enum {
        Literal;
        Identifier;
        Binary_Operator;
        Procedure_Call;
    };

    some_token: Token;
}

Node_Literal :: struct {
    #as using base: Node;
    base.type = .Literal;

    #place some_token;
    token: Token;

    union {
        string_value: struct { offset_in_global_data: s64; count: s64; };
        i64_value: s64;
    }
}

Node_Identifier :: struct {
    #as using base: Node;
    base.type = .Identifier;

    #place some_token;
    token: Token;
}

Node_Binary_Operator :: struct {
    #as using base: Node;
    base.type = .Binary_Operator;

    #place some_token;
    op: Token;

    lhs: *Node;
    rhs: *Node;
}

Node_Procedure_Call :: struct {
    #as using base: Node;
    base.type = .Procedure_Call;

    #place some_token;
    opening_parenthesis: Token;

    procedure_expression: *Node;
    arguments_list: [] *Node;
}

Token :: struct {
    type: enum {
        Identifier;
        Int_Literal;
        String_Literal;
        Operator;
        Semicolon;
        Comma;
        End_Of_Input;
    };
    union {
        int_value: s64;
        string_value: string;
        identifier: string;
        character: s64;
    };
    // Byte offset starting from 1 (first byte is 1).
    start: s64;
    end: s64;
}

Parser :: struct {
    filename: string;
    text: string;
    position: s64;
    error_reported: bool;

    string_literal_pool: Flat_Pool;
    string_literal_allocator: Allocator;
}

#add_context parser: *Parser;

Op_Code :: enum u8 {
    Push_String;

    Push_Int64;
    Add_Int64;
    Mul_Int64;
    Sub_Int64;
    Div_Int64;
    Mod_Int64;

    Eq_Int64;
    Neq_Int64;
    Gt_Int64;
    Ge_Int64;
    Lt_Int64;
    Le_Int64;

    Push_Builtin_Procedure;
    Call_Builtin_Procedure;
}

Builtin_Procedure :: enum u8 {
    Print_String;
    Print_Int64;
    Add_Int64;
    Mul_Int64;
    Sub_Int64;
    Div_Int64;
    Mod_Int64;
}

Interpreter :: struct {
    bytecode: [..] u8;
    stack: [..] u8;
    global_data: [..] u8;
}

#add_context interpreter: *Interpreter;

peek_token :: inline () -> Token, ok: bool {
    using context.parser;

    // XXX: not sure this is safe
    eat_whitespace();

    // FIXME: this is stupid
    saved_position := position;
    defer position = saved_position;

    result, ok := eat_token();
    return result, ok;
}

eat_token :: () -> Token, ok: bool {
    using context.parser;

    eat_whitespace();
    if position >= text.count return .{ type = .End_Of_Input }, true;

    result: Token = ---;
    result.start = position + 1;
    c := text[position];
    if c == {
        case #char ",";
            result.type = .Comma;
            position += 1; // eat token
        case #char ";";
            result.type = .Semicolon;
            position += 1; // eat token
        case #char "\"";
            opening_quote_position := position;
            literal, ok := parse_string_literal();
            if !ok {
                report("You didn't close this string literal", position=opening_quote_position);
                return .{}, false;
            }
            result.type = .String_Literal;
            result.string_value = literal;
        case;
            if starts_identifier(c) {
                identifier := eat_identifier();
                result.type = .Identifier;
                result.identifier = identifier;
            } else if is_digit(c) {
                value := eat_int_literal();
                result.type = .Int_Literal;
                result.int_value = value;
            } else if is_operator(c) {
                result.type = .Operator;
                result.character = c;
                position += 1; // eat token
            } else {
                return .{}, false;
            }
    }
    result.end = position;
    return result, true;
}

// Only ascii at the moment
eat_whitespace :: inline () {
    using context.parser;

    while true {
        if position >= text.count return;
        c := text[position];
        if c != #char " " && c != #char "\t" && c != #char "\r" && c != #char "\n" then return;
        position += 1;
    }
}

starts_identifier :: inline (c: u8) -> bool {
    return c >= #char "a" && c <= #char "z" || c >= #char "A" && c <= #char "Z" || c == #char "_";
}

is_operator :: inline (c: u8) -> bool {
    return operator_precedence(c) >= 0;
}

operator_precedence :: inline (c: u8) -> s64 {
    if c == {
        case #char "("; return 90;
        case #char ")"; return 90;
        case #char "*"; return 30;
        case #char "/"; return 30;
        case #char "%"; return 30;
        case #char "+"; return 20;
        case #char "-"; return 20;
        case #char "="; return 10;
        case #char "<"; return 10;
        case #char ">"; return 10;
        case;           return -1;
    }
}

eat_identifier :: () -> string, ok: bool {
    using context.parser;

    assert(position < text.count);
    assert(starts_identifier(text[position]));

    result: string = ---;
    result.data = text.data + position;
    result.count = 0;

    while true {
        if position >= text.count return result, true;
        c := text[position];

        if !starts_identifier(c) && !is_digit(c) return result, true;

        position += 1;
        result.count += 1;
    }
    return "", false;
}

eat_int_literal :: () -> s64, ok: bool {
    using context.parser;

    assert(position < text.count);
    assert(is_digit(text[position]));

    result: s64 = 0;

    while true {
        if position >= text.count return result, true;
        c := text[position];

        if !is_digit(c) return result, true;

        result *= 10;
        result += c - #char "0";

        position += 1;
    }
    return 0, false;
}

parse_string_literal :: () -> string, ok: bool {
    using context.parser;

    assert(position < text.count);
    assert(text[position] == #char "\"");
    position += 1;

    builder: String_Builder;
    builder.allocator = temp;

    while true {
        if position >= text.count return "", false; // expected a closing "
        c := text[position];

        if c == #char "\"" {
            position += 1; // eat the " as well
            break;
        }
        if c == #char "\\" {
            // skip next character
            position += 1;

            c = text[position];
            if c == {
                case #char "e"; c = #char "\e";
                case #char "n"; c = #char "\n";
                case #char "r"; c = #char "\r";
                case #char "t"; c = #char "\t";
                case #char "\\"; c = #char "\\";
            }
            // should check if input has ended, but it's going to be checked first thing next iteration anyway, so no biggie
        }

        position += 1;
        append(*builder, c);
    }

    result := builder_to_string(*builder,, string_literal_allocator);
    return result, true;
}

report_invalid_character :: () {
    using context.parser;

    // if error_reported return;
    assert(position < text.count);
    character: string;
    character.data = text.data + position;
    character.count = 1;
    print("%[%]: Unexpected character '%'\n", filename, position + 1, character);
    error_reported = true;
}

report :: (format_string: string, args: .. Any, position := -1, token: *Token = null, internal := false, loc := #caller_location) {
    using,except(position) context.parser;

    // if error_reported return;

    print("%", filename);

    if token == null {
        pos := ifx position != -1 then position else context.parser.position;
        print("[%]", pos + 1);
    } else {
        if token.start == token.end {
            print("[%]", token.start + 1);
        } else {
            print("[%..%]", token.start + 1, token.end + 1);
        }
    }
    if internal {
        print("{%:%}", loc.fully_pathed_filename, loc.line_number);
    }
    print(": ");
    print(format_string, ..args);
    print("\n");
    error_reported = true;
} @PrintLike

parse_expression :: (min_precedence := -1) -> *Node, ok: bool {
    using context.parser;
    token, ok := eat_token();
    if !ok {
        report_invalid_character();
        return null, false;
    }

    left: *Node;
    if token.type == {
        case .Int_Literal; #through;
        case .String_Literal;
            node := New(Node_Literal);
            node.token = token;
            left = node;
        case .Identifier;
            node := New(Node_Identifier);
            node.token = token;
            left = node;
        case;
            report("Expected to parse an expression, but got unexpected token %", token.type);
            return null, false;
    }

    while true {
        node, ok := parse_binary_expression_increasing_precedence(left, min_precedence);
        if !ok return null, false; // @Leak

        if node == left break;

        left = node;
    }

    return left, true;
}

parse_binary_expression_increasing_precedence :: (left: *Node, min_precedence: int) -> *Node, ok: bool {
    token := peek_token();

    if token.type != .Operator return left, true;

    if cast(u8) token.character == #char ")" return left, true;

    if cast(u8) token.character == #char "(" {
        opening_parenthesis, ok := eat_token();
        assert(ok);

        arguments_list : [..] *Node;

        while true {
            argument, ok := parse_expression();
            if !ok return null, false;

            array_add(*arguments_list, argument);

            token = peek_token();

            if token.type == .Comma {
                _, ok := eat_token();
                assert(ok);
                continue;
            }

            if token.type == .Operator && cast(u8) token.character == #char ")" {
                _, ok := eat_token();
                assert(ok);

                node := New(Node_Procedure_Call);
                node.opening_parenthesis = opening_parenthesis;
                node.procedure_expression = left;
                node.arguments_list = arguments_list;
                return node, true;
            }

            report("Was parsing a procedure call and expected this parenthesis to be closed, but instead got `%`", token_text(token), position=opening_parenthesis.start);
            return null, false; // @Leak
        }

        return null, false; // @Unreachable
    } else {
        next_precedence := operator_precedence(xx token.character);

        if next_precedence <= min_precedence {
            return left, true;
        }

        _, ok := eat_token();
        assert(ok);

        right:, ok = parse_expression(next_precedence);
        if !ok return null, false;

        node := New(Node_Binary_Operator);
        node.lhs = left;
        node.rhs = right;
        node.op = token;
        return node, true;
    }
}

parse_parameter_list :: () -> [] *Node, ok: bool {

    return .[], false;
}

starts_expression :: inline (token: *Token) -> bool {
    if token.type == {
        case .Int_Literal; #through;
        case .String_Literal; #through;
        case .Identifier;
            return true;
        case;
            return false;
    }
}

inspect_token :: inline (builder: *String_Builder, token: Token) {
    print_to_builder(builder, "%", token.type);
    if token.type == {
        case .Int_Literal;    print_to_builder(builder, "<\e[36m%\e[0m>", token.int_value);
        case .String_Literal; print_to_builder(builder, "<\e[36m'%'\e[0m>", token.string_value);
        case .Identifier;     print_to_builder(builder, "<\e[32m%\e[0m>", token.identifier);
        case .Operator;       print_to_builder(builder, "<\e[35m%\e[0m>", operator_text(token));
        case;
    }
    if token.start == token.end
        print_to_builder(builder, "[%]", token.start);
    else
        print_to_builder(builder, "[%..%]", token.start, token.end);
}

inspect_token :: (token: Token) {
    builder: String_Builder;
    inspect_token(*builder, token);
    print("%", builder_to_string(*builder));
}

token_text :: inline (token: Token) -> string {
    result: string;
    result.data = context.parser.text.data + token.start - 1;
    result.count = token.end - token.start + 1;
    return result;
}

operator_text :: inline (token: Token) -> string {
    assert(token.type == .Operator);
    return .{ data = xx *token.character, count = 1 };
}

inspect_node :: (builder: *String_Builder, node_base: *Node, offset := 0, end_line := "\n") {
    print_prefix :: (builder: *String_Builder, offset: int) {
        for _: 0..offset-1 print_to_builder(builder, "  ");
    }
    if #complete node_base.type == {
        case .Literal;
            node := cast(*Node_Literal) node_base;
            print_prefix(builder, offset);
            inspect_token(builder, node.token);
            print_to_builder(builder, "%", end_line);
        case .Identifier;
            node := cast(*Node_Identifier) node_base;
            print_prefix(builder, offset);
            inspect_token(builder, node.token);
            print_to_builder(builder, "%", end_line);
        case .Binary_Operator;
            node := cast(*Node_Binary_Operator) node_base;
            print_prefix(builder, offset);
            print_to_builder(builder, "Binary_Operator(\n");

            inspect_node(builder, node.lhs, offset = offset + 1, end_line = ",\n");

            print_prefix(builder, offset + 1);
            inspect_token(builder, node.op);
            print_to_builder(builder, ",\n");

            inspect_node(builder, node.rhs, offset = offset + 1, end_line = ",\n");

            print_prefix(builder, offset);
            print_to_builder(builder, ")%", end_line);
        case .Procedure_Call;
            node := cast(*Node_Procedure_Call) node_base;
            print_prefix(builder, offset);
            print_to_builder(builder, "Procedure_Call(\n");

            inspect_node(builder, node.procedure_expression, offset = offset + 1, end_line = ",\n");

            for node.arguments_list
                inspect_node(builder, it, offset = offset + 1, end_line = ",\n");

            print_prefix(builder, offset);
            print_to_builder(builder, ")%", end_line);
    }
}

inspect_node :: (node: *Node, offset := 0) {
    builder: String_Builder;
    inspect_node(*builder, node, offset = offset);
    print("%", builder_to_string(*builder));
}

update_global_data :: (expr: *Node) -> ok: bool {
    using context.interpreter;

    children := depth_first_nodes(expr);
    for children {
        if it.type == {
            case .Literal;
                node := cast(*Node_Literal) it;
                if node.token.type == {
                    case .Int_Literal;
                        node.i64_value = node.token.int_value;

                    case .String_Literal;
                        string_value := node.token.string_value;
                        node.string_value.offset_in_global_data = global_data.count;
                        node.string_value.count = string_value.count;
                        array_add(*global_data, ..cast([] u8)string_value);

                    case;
                        report("Unreachable code!!!", token = *node.token, internal = true);
                        return false;
                }
        }
    }

    return true;
}

compile_expression_to_bytecode :: (expr: *Node) -> ok: bool {
    using context.interpreter;

    print("depth first:\n");
    children := depth_first_nodes(expr);
    for children {
        print("  #%: ", it_index);
        inspect_token(it.some_token);
        print("\n");

        if #complete it.type == {
            case .Literal;
                node := cast(*Node_Literal) it;
                if node.token.type == {
                    case .Int_Literal;
                        array_add(*bytecode, xx Op_Code.Push_Int64);
                        array_add(*bytecode, ..as_bytes(*node.i64_value));

                    case .String_Literal;
                        array_add(*bytecode, xx Op_Code.Push_String);
                        array_add(*bytecode, ..as_bytes(*node.string_value.count));
                        array_add(*bytecode, ..as_bytes(*node.string_value.offset_in_global_data));

                    case;
                        report("Unreachable code!!!", token = *node.token, internal = true);
                        return false;
                }

            case .Identifier;
                node := cast(*Node_Identifier) it;
                identifier := token_text(node.token);
                if identifier == {
                    case "print_str"; array_add(*bytecode, cast(u8) Op_Code.Push_Builtin_Procedure, cast(u8) Builtin_Procedure.Print_String);
                    case "print_i64"; array_add(*bytecode, cast(u8) Op_Code.Push_Builtin_Procedure, cast(u8) Builtin_Procedure.Print_Int64);
                    case "add";       array_add(*bytecode, cast(u8) Op_Code.Push_Builtin_Procedure, cast(u8) Builtin_Procedure.Add_Int64);
                    case "mul";       array_add(*bytecode, cast(u8) Op_Code.Push_Builtin_Procedure, cast(u8) Builtin_Procedure.Mul_Int64);
                    case "sub";       array_add(*bytecode, cast(u8) Op_Code.Push_Builtin_Procedure, cast(u8) Builtin_Procedure.Sub_Int64);
                    case "div";       array_add(*bytecode, cast(u8) Op_Code.Push_Builtin_Procedure, cast(u8) Builtin_Procedure.Div_Int64);
                    case "mod";       array_add(*bytecode, cast(u8) Op_Code.Push_Builtin_Procedure, cast(u8) Builtin_Procedure.Mod_Int64);
                    case;
                        report("Unsupported builtin procedure `%`", identifier, position = node.token.start);
                        return false;
                }

            case .Binary_Operator;
                node := cast(*Node_Binary_Operator) it;
                if cast(u8) node.op.character == {
                    case #char "+"; array_add(*bytecode, xx Op_Code.Add_Int64);
                    case #char "*"; array_add(*bytecode, xx Op_Code.Mul_Int64);
                    case #char "-"; array_add(*bytecode, xx Op_Code.Sub_Int64);
                    case #char "/"; array_add(*bytecode, xx Op_Code.Div_Int64);
                    case #char "%"; array_add(*bytecode, xx Op_Code.Mod_Int64);
                    case #char "="; array_add(*bytecode, xx Op_Code.Eq_Int64);
                    case #char ">"; array_add(*bytecode, xx Op_Code.Gt_Int64);
                    case #char "<"; array_add(*bytecode, xx Op_Code.Lt_Int64);
                }

            case .Procedure_Call;
                node := cast(*Node_Procedure_Call) it;
                array_add(*bytecode, xx Op_Code.Call_Builtin_Procedure);
        }
    }

    return true;
}

depth_first_nodes :: (expr: *Node, _result: *[..] *Node = null) -> [] *Node {
    result_slot: [..] *Node;
    result_slot.allocator = temp;
    result := ifx _result then _result else *result_slot;

    if #complete expr.type == {
        case .Literal;
            array_add(result, expr);
        case .Identifier;
            array_add(result, expr);
        case .Binary_Operator;
            node := cast(*Node_Binary_Operator) expr;
            depth_first_nodes(node.lhs, result);
            depth_first_nodes(node.rhs, result);
            array_add(result, node);
        case .Procedure_Call;
            node := cast(*Node_Procedure_Call) expr;
            for node.arguments_list depth_first_nodes(it, result);
            depth_first_nodes(node.procedure_expression, result);
            array_add(result, node);
    }

    return result.*;
}

disassemble_bytecode :: () {
    using context.interpreter;

    ip := 0;
    while true {
        if ip >= bytecode.count break;

        op := cast(Op_Code) bytecode[ip];
        ip += 1;
        if #complete op == {
            case .Push_String;
                count := << from_bytes(.{ data = bytecode.data + ip, count = size_of(s64) }, s64);
                ip += size_of(s64);
                data := << from_bytes(.{ data = bytecode.data + ip, count = size_of(s64) }, s64);
                ip += size_of(s64);
                print("push_str %, %\n", count, data);

            case .Push_Int64;
                immediate := << from_bytes(.{ data = bytecode.data + ip, count = size_of(s64) }, s64);
                ip += size_of(s64);
                print("push %\n", immediate);

            case .Add_Int64; print("add\n");
            case .Mul_Int64; print("mul\n");
            case .Sub_Int64; print("sub\n");
            case .Div_Int64; print("div\n");
            case .Mod_Int64; print("mod\n");
            case .Eq_Int64; print("eq\n");
            case .Neq_Int64; print("neq\n");
            case .Gt_Int64; print("gt\n");
            case .Ge_Int64; print("ge\n");
            case .Lt_Int64; print("lt\n");
            case .Le_Int64; print("le\n");

            case .Push_Builtin_Procedure;
                #assert(size_of(Builtin_Procedure) == 1);
                builtin_procedure := cast(Builtin_Procedure) bytecode[ip];
                ip += 1;
                print("push %\n", builtin_procedure);

            case .Call_Builtin_Procedure;
                print("call\n");

            case;
                report("Unimplemented %", op, internal = true);
        }
    }
}

interpret_bytecode :: () -> ok: bool {
    using context.interpreter;

    ip := 0;
    while true {
        if ip >= bytecode.count break;

        op := cast(Op_Code) bytecode[ip];
        ip += 1;
        if #complete op == {
            case .Push_String;
                count_bytes : [] u8 = .{ data = bytecode.data + ip, count = size_of(s64) };
                ip += size_of(s64);
                array_add(*stack, ..count_bytes);

                data_bytes : [] u8 = .{ data = bytecode.data + ip, count = size_of(s64) };
                ip += size_of(s64);
                array_add(*stack, ..data_bytes);

            case .Push_Int64;
                immediate_bytes : [] u8 = .{ data = bytecode.data + ip, count = size_of(s64) };
                ip += size_of(s64);
                array_add(*stack, ..immediate_bytes);

            case .Add_Int64; #through;
            case .Mul_Int64; #through;
            case .Sub_Int64; #through;
            case .Div_Int64; #through;
            case .Mod_Int64; #through;
            case .Eq_Int64; #through;
            case .Neq_Int64; #through;
            case .Gt_Int64; #through;
            case .Ge_Int64; #through;
            case .Lt_Int64; #through;
            case .Le_Int64;
                rhs := << from_bytes(pop_slice(*stack, size_of(s64)), s64);
                lhs := << from_bytes(pop_slice(*stack, size_of(s64)), s64);
                res : s64 = ---;

                if op == {
                    case .Add_Int64; res = lhs + rhs;
                    case .Mul_Int64; res = lhs * rhs;
                    case .Sub_Int64; res = lhs - rhs;
                    case .Div_Int64; res = lhs / rhs;
                    case .Mod_Int64; res = lhs % rhs;
                    case .Eq_Int64;  res = xx (lhs == rhs);
                    case .Neq_Int64; res = xx (lhs != rhs);
                    case .Gt_Int64;  res = xx (lhs > rhs);
                    case .Ge_Int64;  res = xx (lhs >= rhs);
                    case .Lt_Int64;  res = xx (lhs < rhs);
                    case .Le_Int64;  res = xx (lhs <= rhs);
                }

                array_add(*stack, ..as_bytes(*res));

            case .Push_Builtin_Procedure;
                proc := bytecode[ip];
                ip += 1;
                array_add(*stack, proc);

            case .Call_Builtin_Procedure;
                p := pop(*stack);
                if p > type_info(Builtin_Procedure).values.count - 1 {
                    // FIXME: this should be on a stage before bytecode generation
                    report("Unsupported builtin procedure #%, ip = %", p, ip - 1, internal=true);
                    return false;
                }

                proc := cast(Builtin_Procedure) p;
                if #complete proc == {
                    case .Print_String;
                        offset := << from_bytes(pop_slice(*stack, size_of(s64)), s64);
                        count := << from_bytes(pop_slice(*stack, size_of(s64)), s64);

                        s : string = ---;
                        s.data = global_data.data + offset;
                        s.count = count;

                        write_string(s);

                    case .Print_Int64;
                        arg := << from_bytes(pop_slice(*stack, size_of(s64)), s64);
                        if arg < 0 {
                            arg = -arg; // @Incomplete: check for overflow
                            write_string("-");
                        }
                        write_nonnegative_number(xx arg);

                    case .Add_Int64; #through;
                    case .Mul_Int64; #through;
                    case .Sub_Int64; #through;
                    case .Div_Int64; #through;
                    case .Mod_Int64;
                        rhs := << from_bytes(pop_slice(*stack, size_of(s64)), s64);
                        lhs := << from_bytes(pop_slice(*stack, size_of(s64)), s64);
                        res : s64 = ---;

                        if proc == {
                            case .Add_Int64; res = lhs + rhs;
                            case .Mul_Int64; res = lhs * rhs;
                            case .Sub_Int64; res = lhs - rhs;
                            case .Div_Int64; res = lhs / rhs;
                            case .Mod_Int64; res = lhs % rhs;
                        }

                        array_add(*stack, ..as_bytes(*res));
                }
        }
    }

    return true;
}

dump_global_data :: () {
    using context.interpreter;

    builder: String_Builder;

    mem_dump_to_builder(*builder, global_data);
    write_builder(*builder);
    print("\n");
}

dump_stack :: () {
    using context.interpreter;

    builder: String_Builder;

    mem_dump_to_builder(*builder, stack);
    write_builder(*builder);
    print("\n");
}

main :: () {
    args := get_command_line_arguments();

    if args.count < 2 {
        print("Need filename\n");
        exit(1);
    }

    filename := args[1];
    data, ok := read_entire_file(filename);
    if !ok {
        exit(1);
    }

    // old_struct_printer := context.print_style.struct_printer;
    // context.print_style.struct_printer = (builder: *String_Builder, any: Any, data: *void) -> handled: bool {
    //     if any.type != type_info(Token) return false;
    //     // TODO
    //     return true;
    // }

    parser_slot := Parser.{
        filename = filename,
        text = data,
    };
    parser_slot.string_literal_allocator = .{
        proc = flat_pool_allocator_proc,
        data = *parser_slot.string_literal_pool,
    };
    context.parser = *parser_slot;

    interpreter_slot: Interpreter;
    context.interpreter = *interpreter_slot;
    array_reserve(*context.interpreter.bytecode, 4096);
    array_reserve(*context.interpreter.stack, 4096);
    array_reserve(*context.interpreter.global_data, 4096);

    while true {
        token, ok := peek_token();
        if !ok {
            report_invalid_character();
            exit(1);
        }

        if token.type == .Semicolon || token.type == .Comma {
            _, ok := eat_token();
            assert(ok);
            continue;
        }

        if token.type == .End_Of_Input break;

        if starts_expression(*token) {
            expr, ok := parse_expression();
            if !ok exit(1);

            print("=== AST ===\n");
            inspect_node(expr, offset = 1);

            ok = update_global_data(expr);
            assert(ok);

            print("=== Compiling Bytecode ===\n");
            ok = compile_expression_to_bytecode(expr);
            if !ok context.parser.error_reported = false;
            continue;
        }

        report("Unexpected token `%`", token_text(token));
        exit(1);
    }

    print("=== Bytecode disassembly ===\n");
    disassemble_bytecode();

    print("=== global data: ===\n");
    dump_global_data();

    print("=== stack before: ===\n");
    dump_stack();
    print("=== running program: ===\n");
    interpret_bytecode();
    print("=== stack after: ===\n");
    dump_stack();

}

as_bytes :: inline (p: *$T) -> [] u8 {
    return .{ data = xx p, count = size_of(T) };
}

from_bytes :: inline (bytes: [] u8, $T: Type) -> *T {
    assert(bytes.count == size_of(T));
    return xx bytes.data;
}

pop_slice :: inline (array: *[] $T, count: s64) -> [] T {
    assert(array.count >= count);
    array.count -= count;
    return .{ data = array.data + array.count, count = count };
}

array_reserve_additional :: inline (array: *[..] $T, additional: s64) {
    if array.allocated >= array.count + additional return;

    array_reserve(array, array.allocated * 2);
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

#import "Basic";
#import "File";
#import "Flat_Pool";
