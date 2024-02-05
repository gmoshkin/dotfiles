#run {
    #import "Compiler";
    set_build_options_dc(.{ output_executable_name = "ps" });
}

Pid :: #type,distinct s64;

State :: struct {
    tty: string;

    tty_drivers: Table(u8, string);

    tty_number_to_name: Table(s64, string);

    maybe_roots: Table(Pid, void);
    parent_to_children: Table(Pid, Pid);
    process_infos: Table(Pid, Process_Info);
}

Process_Info :: struct {
    pid: Pid;
    parent_pid: Pid;

    command_line: [] string;

    tty: string;
    children: [..] Pid;

    depth: s64;
}

Void : void;

main :: () {
    args := get_command_line_arguments();

    cursor := 1;

    state: State;

    while cursor < args.count {
        arg := args[cursor];
        if arg == {
            case "-t"; #through;
            case "--tty";
                cursor += 1;
                if cursor >= args.count {
                    print("Expected a tty name after '%'\n", arg);
                    exit(1);
                }
                state.tty = args[cursor];
                cursor += 1;

            case;
                break;
        }
    }

    // Read tty numbers
    {
        tty_drivers, ok := my_read_entire_file("/proc/tty/drivers", log_errors=false,, temp);
        assert(ok);

        tail := tty_drivers;
        while tail {
            found:, line:, tail = split_from_left(tail, #char "\n");

            _, ok := parse_token(*line, delimiters="");
            assert(ok);

            driver_name:, ok = parse_token(*line, delimiters="");
            assert(ok);

            driver_number_str:, ok = parse_token(*line, delimiters="");
            assert(ok);

            driver_number:, ok = string_to_int(driver_number_str, base=10, T=u8);
            assert(ok);

            table_set(*state.tty_drivers, driver_number, driver_name);
        }
    }

    pids: [..] string;
    visitor :: (info: *File_Visit_Info, pids: *[..] string) {
        array_add(pids, copy_string(info.short_name));
    };
    ok := visit_files("/proc", recursive=false, user_data=*pids, proc=visitor, visit_files=false, visit_directories=true, follow_symlinks=false);
    assert(ok);

    for pids {
        defer reset_temporary_storage();

        pid_value, ok := string_to_int(it, base=10, T=s64);
        if !ok continue;
        pid : Pid = xx pid_value;

        // Read tty
        stat:, ok = my_read_entire_file(tprint("/proc/%/stat", it), log_errors=false,, temp);
        if !ok continue;

        {
            tail := stat;
            i := 1;
            tty_number: s64 = -1;
            parent_pid: Pid = -1;
            while tail {
                defer i += 1;
                found:, s:, tail = split_from_left(tail, #char " ");

                if s[0] == #char "(" && find_index_from_left(s, #char ")") == -1 {
                    count := find_index_from_left(tail, #char ")");
                    assert(count > 0);
                    // Skip ')' & ' ' right after it
                    advance(*tail, count + 2);
                    s.count += count + 2;
                    continue;
                }

                if i == 4 {
                    parent_pid_value:, ok = string_to_int(s, base=10, T=s64);
                    assert(ok);
                    parent_pid = xx parent_pid_value;
                }
                if i == 7 {
                    tty_number, ok = string_to_int(s, base=10, T=s64);
                    assert(ok);
                    break;
                }
            }

            info, not_found := find_or_add(*state.process_infos, pid);
            // don't really care if not_found or not
            info.pid = pid;
            info.parent_pid = parent_pid;

            parent_info:, not_found = find_or_add(*state.process_infos, parent_pid);
            // don't really care if not_found or not
            array_add(*parent_info.children, pid);

            if tty_number != 0 && tty_number != -1 {
                tty_name, not_found := find_or_add(*state.tty_number_to_name, tty_number);
                if not_found {
                    driver_number := cast(u8) ((tty_number >> 8) & 0xff);
                    // TODO: sometimes there's a index part in higher bits?
                    tty_index := tty_number & 0xff;
                    driver_name, ok := table_find(*state.tty_drivers, driver_number);
                    if !ok continue;

                    if driver_name == "/dev/tty" {
                        tty_name.* = sprint("/dev/tty%", tty_index);
                    } else {
                        tty_name.* = sprint("%/%", driver_name, tty_index);
                    }
                }

                info.tty = tty_name.*;

                if state.tty && state.tty == tty_name.* {
                    table_set(*state.maybe_roots, pid, Void);
                }
            }

            // info.command_line will be set later so as to not read extra files
            // we don't have to
        }
    }

    maybe_roots := NewArray(state.maybe_roots.count, Pid);
    i := 0;
    for state.maybe_roots {
        maybe_roots[i] = it_index;
        i += 1;
    }

    roots: [] Pid;

    if maybe_roots.count == 0 {
        print("nothing found\n");
        return;
    }
    if maybe_roots.count > 1 {
        // removing the children from maybe_roots
        check_which_are_reachable :: (tree: *Table(Pid, Process_Info), root: Pid, seen_these: *Table(Pid, bool)) {
            info := table_find_pointer(tree, root);
            if !info return;
            seen := table_find_pointer(seen_these, info.pid);
            if seen != null then seen.* = true;

            for info.children {
                check_which_are_reachable(tree, it, seen_these);
            }
        }

        seen_these_from_root: [..] Table(Pid, bool);
        for maybe_roots {
            seen_these := array_add(*seen_these_from_root);
            for maybe_roots table_set(seen_these, it, false);

            check_which_are_reachable(*state.process_infos, it, seen_these);
        }

        compare_same_keys :: (lhs: *Table(Pid, bool), rhs: *Table(Pid, bool)) -> Set_Comparison {
            left_score := 0;
            right_score := 0;
            for l: lhs.* {
                r, ok := table_find(rhs, it_index);
                assert(ok);
                if l && !r {
                    left_score += 1;
                } else if !l && r {
                    right_score += 1;
                }

                if (left_score != 0) && (right_score != 0) return .NON_COMPARABLE;
            }
            if left_score return .LEFT_IS_BIGGER;
            if right_score return .RIGHT_IS_BIGGER;
            return .EQUAL;
        }

        assert(maybe_roots.count == seen_these_from_root.count);
        comparing_this_one_to_the_rest := 0;
        comparing_to_this_one_at_the_moment := 1;
        while outer := comparing_this_one_to_the_rest < maybe_roots.count {
            lhs := *seen_these_from_root[comparing_this_one_to_the_rest];

            comparing_to_this_one_at_the_moment := comparing_this_one_to_the_rest + 1;
            while comparing_to_this_one_at_the_moment < maybe_roots.count {
                rhs := *seen_these_from_root[comparing_to_this_one_at_the_moment];
                res := compare_same_keys(lhs, rhs);
                if res == {
                    case .NON_COMPARABLE; comparing_to_this_one_at_the_moment += 1;
                    case .EQUAL; #through;
                    case .LEFT_IS_BIGGER;
                        array_unordered_remove_by_index(*seen_these_from_root, comparing_to_this_one_at_the_moment);
                        array_unordered_remove_by_index(*maybe_roots, comparing_to_this_one_at_the_moment);
                    case .RIGHT_IS_BIGGER;
                        array_unordered_remove_by_index(*seen_these_from_root, comparing_this_one_to_the_rest);
                        array_unordered_remove_by_index(*maybe_roots, comparing_this_one_to_the_rest);
                        continue outer;
                }
            }
            comparing_this_one_to_the_rest += 1;
        }
    }
    roots = maybe_roots;

    depth_first_children :: (tree: *Table(Pid, Process_Info), root: Pid, result: *[..] *Process_Info, depth := 0) {
        info := table_find_pointer(tree, root);
        if !info return;
        info.depth = depth;

        array_add(result, info);
        for info.children {
            depth_first_children(tree, it, result, depth + 1);
        }
    }

    flattened_tree: [..] *Process_Info;
    flattened_tree.allocator = temp;
    for roots {
        depth_first_children(*state.process_infos, it, *flattened_tree);
    }

    for flattened_tree {
        command_line, ok := get_process_command_line(it.pid);
        it.command_line = command_line;

        builder: String_Builder;
        builder.allocator = temp;

        // PID
        print_to_builder(*builder, "% ", FormatInt.{ value = it.pid, minimum_digits = 7, padding = #char " " });

        // TTY
        tty := it.tty;
        if tty.count > 5 && substring(tty, count = 5) == "/dev/" {
            tty = substring(tty, start = 5);
        }
        // padding
        for 1..8 - tty.count {
            append(*builder, " ");
        }
        print_to_builder(*builder, "% ", tty);

        // COMMAND LINE
        if it.depth {
            for 0..it.depth-2 {
                // TODO: add '|' as ps does when there's uncle processes
                append(*builder, "    ");
            }
            append(*builder, " \\_ ");
        }
        if !it.command_line {
            append(*builder, "?");
        } else for it.command_line {
            if it_index == 0 {
                append(*builder, "\e[32m");
                append(*builder, it);
                append(*builder, "\e[0m");
            } else {
                append(*builder, it);
            }
            append(*builder, " ");
        }

        append(*builder, "\n");
        write_builder(*builder);
    }
}

//
// set comparison
//

test_min_max_coverage :: () {
    things_storage := u16.[
        0x0000,
        0x1010,
        0x0101,
        0x0110,
        0x0111,
    ];
    things: [] u16 = things_storage;

    print_style := context.print_style;
    print_style.default_format_int.base = 16;
    print_style.default_format_int.minimum_digits = 4;
    print("%\n", things,, print_style=print_style);

    compare :: (lp: *u16, rp: *u16) -> Set_Comparison {
        l := lp.*;
        r := rp.*;
        if r == l return .EQUAL;
        if (r | l) == r return .RIGHT_IS_BIGGER;
        if (r | l) == l return .LEFT_IS_BIGGER;
        return .NON_COMPARABLE;
    }

    min_max_coverage(*things, compare);

    print("%\n", things,, print_style=print_style);
}

Set_Comparison :: enum { NON_COMPARABLE; LEFT_IS_BIGGER; RIGHT_IS_BIGGER; EQUAL; };
min_max_coverage :: (things: *[] $T, compare: (lhs: *T, rhs: *T) -> Set_Comparison)
{
    comparing_this_one_to_the_rest := 0;
    comparing_to_this_one_at_the_moment := 1;
    while outer := comparing_this_one_to_the_rest < things.count {
        lhs := *(things.*)[comparing_this_one_to_the_rest];

        comparing_to_this_one_at_the_moment := comparing_this_one_to_the_rest + 1;
        while comparing_to_this_one_at_the_moment < things.count {
            rhs := *(things.*)[comparing_to_this_one_at_the_moment];
            res := compare(lhs, rhs);
            if res == {
                case .NON_COMPARABLE;
                    log("keep both #%: % & #%: %",
                        comparing_this_one_to_the_rest,      FormatInt.{ value = lhs.*, base = 16, minimum_digits=4 },
                        comparing_to_this_one_at_the_moment, FormatInt.{ value = rhs.*, base = 16, minimum_digits=4 },
                    );
                    comparing_to_this_one_at_the_moment += 1;
                case .EQUAL; #through;
                case .LEFT_IS_BIGGER;
                    log("remove #%: %", comparing_to_this_one_at_the_moment, FormatInt.{ value = rhs.*, base = 16, minimum_digits=4 });
                    array_unordered_remove_by_index(things, comparing_to_this_one_at_the_moment);
                    // array_unordered_remove_by_index(*maybe_roots, comparing_to_this_one_at_the_moment);
                case .RIGHT_IS_BIGGER;
                    log("remove #%: %", comparing_this_one_to_the_rest, FormatInt.{ value = lhs.*, base = 16, minimum_digits=4 });
                    array_unordered_remove_by_index(things, comparing_this_one_to_the_rest);
                    // array_unordered_remove_by_index(*maybe_roots, comparing_this_one_to_the_rest);
                    continue outer;
            }
        }
        comparing_this_one_to_the_rest += 1;
    }
}

//
// process info utilities
//

get_process_command_line :: (pid: Pid) -> [] string, ok: bool {
    cmdline, ok := my_read_entire_file(tprint("/proc/%/cmdline", pid), log_errors=false,, temp);
    if !ok return .[], false;

    if !cmdline return .[], true;

    result: [..] string;
    result.allocator = context.allocator;

    tail := cmdline;
    while tail {
        found:, arg:, tail = split_from_left(tail, #char "\x00");
        array_add(*result, arg);
    }
    return result, true;
}

//
// file utilities
//

my_read_entire_file :: (name: string, log_errors := true) -> string, bool {
    s: string;
    f, success := file_open(name, log_errors = log_errors);
    if !success return s, false;

    defer file_close(*f);

    s, success = my_read_entire_file(f);

    if log_errors && !success {
        System :: #import "System";

        // If we put this error report at a lower level, we could
        // indicate how far into the file the error occurred, etc.
        code, s := System.get_error_value_and_string();
        log("Read of '%' failed: code %, '%'.\n", name, code, s);
    }

    return s, success;
}

my_read_entire_file :: (f: File, log_errors := true) -> string, bool {
    length, success := file_length(f);
    if !success  return "", false;

    assert(length >= 0);
    if length > 0 {
        data, ok := read_entire_file(f);
        return data, ok;
    }

    // Maybe special linux "file"
    builder: String_Builder;
    builder.allocator = context.allocator;

    while true {
        buffer := ensure_contiguous_space_and_return_available_range(*builder);
        read_count := fread(buffer.data, 1, xx buffer.count, f.handle);
        if read_count == 0 break;
        assert(read_count > 0);

        advance_through_ensured_space(*builder, xx read_count);
    }

    return builder_to_string(*builder), true;
}

//
// string utilities
//

NOT_SPECIFIED :: 0x7fff_ffff_ffff_ffff;
substring :: inline (s: string, start := 0, end := NOT_SPECIFIED, count := NOT_SPECIFIED) -> string {
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

#import "Basic";
#import "Hash_Table";
#import "String";
#import "POSIX";
#import "File";
#import "File_Utilities";
