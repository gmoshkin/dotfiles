#run {
    // This is strictly a meta-program, so it doesn't need to be compiled.
    set_build_options_dc(.{do_output = false});

    w := compiler_create_workspace("Dummy workspace");
    if !w {
        println("Workspace creation failed.");
        exit(1);
    }

    opts := get_build_options(w);
    // The mesa-program also doesn't need output,
    // because we'll just be printing data to stdout.
    opts.output_type = .NO_OUTPUT;
    set_build_options(opts, w);

    argv := opts.compile_time_command_line;
    println("args: %", argv);

    argi := 0;
    if argv.count < argi + 1 { println("expected a modename as first argument"); exit(1); }
    mode_str := argv[argi];
    mode : enum {
        GOTO_DEF;
        TYPE_INFO;
    };
    if mode_str == {
    case "goto_def"; mode = .GOTO_DEF;
    case "type_info"; mode = .TYPE_INFO;
    case; println("mode '%' is not supported yet", mode_str); exit(1);
    }

    argi += 1;
    if argv.count < argi + 1 { println("expected a filename as an argument"); exit(1); }
    source_filename := argv[argi];
    if !is_absolute_path(source_filename) {
        cwd := get_working_directory();
        source_filename = tprint("%/%", cwd, source_filename);
    }

    argi += 1;
    if argv.count < argi + 1 { println("expected a line number, after filename"); exit(1); }
    line_str := argv[argi];
    num, ok := string_to_int(line_str, T = s32);
    if !ok { println("expected a line number, got '%'", line_str); exit(1); }
    line := num;

    argi += 1;
    if argv.count < argi + 1 { println("expected a column number, after line number"); exit(1); }
    col_str := argv[argi];
    num, ok = string_to_int(col_str, T = s32);
    if !ok { println("expected a column number, got '%'", col_str); exit(1); }
    col := num;

    argi += 1;
    if argv.count > argi {
        println("WARNING: ignoring the rest of the args: %", array_view(argv, argi));
    }

    compiler_begin_intercept(w);
    // TODO: probably here is where I can break the recursion, when running
    // this meta-program on itself. It's likely super simple to do, but I don't
    // see it yet
    add_build_file(source_filename, w);

    contexts_pushed : [..] Code_Push_Context;
    array_reserve(*contexts_pushed, 16);

    while true {
        msg := compiler_wait_for_message();

        if msg.kind == {

        case .COMPLETE;
            break;

        case .TYPECHECKED; {
            msg_tc := cast(*Message_Typechecked) msg;
            if mode == {
              case .GOTO_DEF; for msg_tc.all for it.subexpressions {
                expr := it;

                // // TODO: #add_context doesn't seem to show up in here
                // if expr.kind == {
                // case .DIRECTIVE_ADD_CONTEXT;
                //     print("add_context:");
                //     exit(1);
                //     print(" type : %", <<expr.type);
                //     println();
                // }

                filename := "(?)";
                if expr.enclosing_load {
                    filename = expr.enclosing_load.fully_pathed_filename;
                }
                if filename != source_filename {
                    continue;
                }
                if !location_contains_line_and_col(expr.location, line, col) {
                    continue;
                }

                goto_def_ident :: (ident: *Code_Ident) -> should_continue := false {
                    decl := ident.resolved_declaration;
                    decl_loc := decl.location;
                    decl_file := "";
                    if decl.enclosing_load
                        decl_file = decl.enclosing_load.fully_pathed_filename;

                    if !decl_file return true;

                    print(":VIM_CMD_START:");
                    print("e % | call setpos('.',[0,%,%,0,0])", decl_file, decl_loc.l0, decl_loc.c0);
                    println(":VIM_CMD_END:");

                    return;
                }

                if expr.kind == {
                case .IDENT;
                    ident := cast(*Code_Ident) expr;
                    should_continue := goto_def_ident(ident);
                    if should_continue continue;

                case .CONTEXT;
                    // TODO: this currently doens't contain any interesting info,
                    // so I don't know how to use. It would be nice if I could
                    // show the user all the places where #add_context was
                    // called, but .DIRECTIVE_ADD_CONTEXT doesn't seem to be
                    // emited at any point, so is this just not supported in the
                    // compiler yet?
                    ctx := cast(*Code_Context) expr;
                    println("context: %", ctx.type);

                case .BLOCK;
                    block := cast(*Code_Block) expr;
                    println("block members:");
                    println("TODO: this is where I walk the tree and visit all .IDENT nodes");
                    // // TODO: walk the tree, visit all .IDENT nodes
                    // for block.members {
                    //     println("  %: %", it.name, it.kind);
                    // }
                }

                loc := enclosing_location(expr);
                print("[%:%,% .. %,%] %",
                    filename, loc.l0, loc.c0, loc.l1, loc.c1,
                    expr.kind,
                );

                if location_contains_line_and_col(loc, line, col) {
                    println(" \e[32mcursor is here\e[0m");
                } else {
                    println();
                }
              }
              case .TYPE_INFO; for msg_tc.all for it.subexpressions {
                expr := it;

                filename := "(?)";
                if expr.enclosing_load {
                    filename = expr.enclosing_load.fully_pathed_filename;
                }
                if filename != source_filename {
                    continue;
                }
                if !location_contains_line_and_col(expr.location, line, col) {
                    continue;
                }

                if expr.kind == {
                case .IDENT;
                    ident := cast(*Code_Ident) expr;
                    if ident.type.type == {
                    case .STRUCT;
                        strukt := cast(*Type_Info_Struct) ident.type;
                        println("struct '%' members:", ident.name, ident);
                        for strukt.members {
                            println("%: %", it.name, <<it.type);
                        }
                    }
                    break;

                case .LITERAL;
                    literal := cast(*Code_Literal) expr;
                    sb : String_Builder;
                    print_literal(*sb, literal);
                    println("literal % : %", builder_to_string(*sb), <<literal.type);
                    break;

                case .DECLARATION;
                    decl := cast(*Code_Scope_Entry) expr;
                    println("decl % : %", decl.name, <<decl.type);
                    break;

                case .CONTEXT;
                    ctx := cast(*Code_Context) expr;
                    println("context : %", <<ctx.type);
                    break;

                // case .SIZE_OR_TYPE_INFO;
                //     soti := cast(*Code_Size_Or_Type_Info) expr;
                //     println("SIZE_OR_TYPE_INFO: %", <<soti);
                //     continue;

                case;
                    // println("matched with %", <<expr);
                    // continue;
                }

                loc := enclosing_location(expr);
                print("[%:%,% .. %,%] %",
                    filename, loc.l0, loc.c0, loc.l1, loc.c1,
                    expr.kind,
                );

                if location_contains_line_and_col(loc, line, col) {
                    println(" \e[32mcursor is here\e[0m");
                } else {
                    println();
                }
              }
            }
        }

        case;
            // println("ignoring msg: %", <<msg);
        }
    }

    // println("args were: % % %", source_filename, line, col);

    compiler_end_intercept(w);
}

enclosing_location :: (node: *Code_Node, depth := 0) -> result: Code_Node.Location {
    d := depth;

    indent := repeat_string(" ", 2 * d);

    loc := node.location;
    write_string(indent);
    println("% @%,% .. %,%", node.kind, loc.l0, loc.c0, loc.l1, loc.c1);

    d += 1;
    indent = repeat_string(" ", 2 * d);

    res := loc;

    if node.kind == {
    case .DECLARATION;
        decl := cast(*Code_Declaration) node;

        tail_loc : Code_Node.Location;
        if decl.type_inst {
            println("%type_inst:", indent);
            tail_loc = enclosing_location(decl.type_inst, d);
        }
        if decl.expression {
            println("%expression:", indent);
            tail_loc = enclosing_location(decl.expression, d);
        }

        res.l1 = tail_loc.l1;
        res.c1 = tail_loc.c1;

        return res;

    case .TYPE_INSTANTIATION;
        type := cast(*Code_Type_Instantiation) node;

        found := false;
        if type.type_valued_expression {
            println("%type_valued_expression:", indent);
            child_loc := enclosing_location(type.type_valued_expression, d);
            set_max_end_loc(*res, child_loc);
            found = true;
        }
        if type.pointer_to {
            println("%pointer_to:", indent);
            child_loc := enclosing_location(type.pointer_to, d);
            set_max_end_loc(*res, child_loc);
            found = true;
        }
        if type.type_directive_target {
            println("%type_directive_target:", indent);
            child_loc := enclosing_location(type.type_directive_target, d);
            set_max_end_loc(*res, child_loc);
            found = true;
        }
        if type.array_element_type {
            println("%array_element_type:", indent);
            child_loc := enclosing_location(type.array_element_type, d);
            set_max_end_loc(*res, child_loc);
            found = true;
        }

        if !found {
            compiler_report("lol wut");
            exit(1);
        }

        return res;

    case .STRUCT;
        type := cast(*Code_Struct) node;

        found := false;
        if type.block {
            println("%block:", indent);
            child_loc := enclosing_location(type.block, d);
            set_max_end_loc(*res, child_loc);
            found = true;
        }

        if !found {
            compiler_report("lol wut");
            exit(1);
        }

        return res;

    case .ENUM;
        type := cast(*Code_Enum) node;

        found := false;
        if type.block {
            println("%block:", indent);
            child_loc := enclosing_location(type.block, d);
            set_max_end_loc(*res, child_loc);
            found = true;
        }

        if !found {
            compiler_report("lol wut");
            exit(1);
        }

        return res;

    case .PROCEDURE_HEADER;
        proc := cast(*Code_Procedure_Header) node;

        tail_loc := loc;
        found := false;
        if proc.body_or_null {
            println("%type_inst:", indent);
            tail_loc = enclosing_location(proc.body_or_null, d);
            found = true;
        }

        res.l1 = tail_loc.l1;
        res.c1 = tail_loc.c1;
        return res;

    case .PROCEDURE_BODY;
        proc := cast(*Code_Procedure_Body) node;
        res.l1 = proc.block.location.l1;
        res.c1 = proc.block.location.c1;
        return res;

    case .BLOCK;
        block := cast(*Code_Block) node;
        write_string(indent);
        println("%:", block.block_type);
        return res;

    case;
        return node.location;
    }
}

Location :: Code_Node.Location;

set_max_end_loc :: (dest: *Location, candidate: Location) {
    if candidate.l1 > dest.l1 ||
       candidate.l1 == dest.l1 && candidate.c1 > dest.c1
    {
        dest.l1 = candidate.l1;
        dest.c1 = candidate.c1;
    }
}

repeat_string :: (s: string, count: int) -> string {
    sb : String_Builder;
    for 1..count append(*sb, s);
    return builder_to_string(*sb);
}

location_contains_line_and_col :: (using loc: Code_Node.Location, line: s32, col: s32) -> bool {
    if line < l0 || line > l1 { return false; }
    if line == l0 && col < c0 { return false; }
    if line == l1 && col > c1 { return false; }
    return true;
}

is_absolute_path :: (path: string) -> bool {
    if !path return false;

    if path[0] == #char "/"   return true;
    if path[0] == #char "\\"  return true;
    #if OS == .WINDOWS {
        if path.count > 2 && path[1] == #char ":"  return true;
    }

    return false;
}

println :: () #expand {
    print("\n");
}


println :: (
    fmt: string,
    args: .. Any,
    color : enum { NONE; GREEN; RED; YELLOW; BLUE; CYAN; MAGENTA; } = .NONE
) #expand {
    if color == {
    case .GREEN;    print("\e[32m");
    case .RED;      print("\e[31m");
    case .BLUE;     print("\e[34m");
    case .CYAN;     print("\e[35m");
    case .YELLOW;   print("\e[33m");
    case .MAGENTA;  print("\e[36m");
    }
    print(fmt, ..args);
    if color != .NONE {
        print("\e[0m\n");
    } else {
        print("\n");
    }
}



#import "Program_Print";
#import "Basic";
#import "File";
#import "Compiler";
