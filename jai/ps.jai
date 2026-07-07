State :: struct {
    tty: string;

    go_up: bool;

    tty_drivers: Table(u8, string);

    tty_number_to_name: Table(s64, string);

    name_part: string;

    maybe_roots: Table(Pid, void);
    parent_to_children: Table(Pid, Pid);
    process_infos: Table(Pid, Extended_Process_Info);
}

Options :: struct {
    for_fzf: bool;
    show_system_info: bool;
}

Extended_Process_Info :: struct {
    #as using base: Process_Info;

    children: [..] Pid;

    depth: s64;
}

Void : void;

main :: () {
    // test_count_visible_characters(); return;

    args := get_command_line_arguments();

    cursor := 1;

    state: State;
    options: Options;

    while cursor < args.count {
        arg := args[cursor];
        if arg == {
            case "-v"; #through;
            case "--version";
                show_version_banner();
                return;

            case "-p"; #through;
            case "--pid";
                cursor += 1;
                if cursor >= args.count {
                    print("Expected a pid after '%'\n", arg);
                    exit(1);
                }
                pid_string := args[cursor];
                pid, ok, tail := string_to_int(pid_string, base=10, T=s64);
                if !ok || tail.count != 0 {
                    print("Expected a pid number, got '%'\n", pid_string);
                    exit(1);
                }
                table_set(*state.maybe_roots, xx pid, Void);
                state.go_up = true;

            case "-n"; #through;
            case "--grep-name";
                cursor += 1;
                if cursor >= args.count {
                    print("Expected an argument after '%'\n", arg);
                    exit(1);
                }
                state.name_part = copy_string(args[cursor]);

            case "-f"; #through;
            case "--full";
                state.go_up = true;

            case "-F"; #through;
            case "--not-full";
                state.go_up = false;

            case "-t"; #through;
            case "--tty";
                cursor += 1;
                if cursor >= args.count {
                    print("Expected a tty name after '%'\n", arg);
                    exit(1);
                }
                state.tty = args[cursor];
                // TODO: always normalize on all platforms
                #if OS == .MACOS if starts_with(state.tty, "/dev/") {
                    state.tty = advance(state.tty, "/dev/".count);
                }

            case "--for-fzf";
                options.for_fzf = true;

            case "--system-info";
                options.show_system_info = true;

            case;
                break;
        }
        cursor += 1;
    }

    system_info = get_system_info();
    if options.show_system_info {
        print("system_info: %\n", system_info);
    }

    // Read tty numbers
    #if OS == .LINUX
    {
        tty_drivers, ok := my_read_entire_file("/proc/tty/drivers", log_errors=false);
        if ok {
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
        } else {
            log_error("Failed to read /proc/tty/drivers");
        }
    }

    //
    // Get process's infos, collect root candidates
    //
    pids := get_all_pids();
    for pid: pids {
        // Either add a new entry, or get an entry which was inserted by this one's child
        info, not_found := find_or_add(*state.process_infos, pid);
        info.pid = pid;

        ok := get_process_info(pid, info, system_info=*system_info, log_errors=false);
        if !ok continue;

        need_command_line := (state.name_part.count != 0);
        if need_command_line {
            command_line, ok := get_process_command_line(info.pid, log_errors=false);
            if !ok continue;
            info.command_line = command_line;
        }

        borrow_checker_my_ass := state.process_infos.entries.data;

        if state.name_part {
            if info.command_line && contains(info.command_line[0], state.name_part) {
                table_set(*state.maybe_roots, pid, Void);
            }
        }

        if info.tty_number != 0 && info.tty_number != -1 {
            tty_name, not_found := find_or_add(*state.tty_number_to_name, info.tty_number);
            if not_found {
                #if OS == .LINUX {
                    driver_number := cast(u8) ((info.tty_number >> 8) & 0xff);
                    // TODO: sometimes there's a index part in higher bits?
                    tty_index := info.tty_number & 0xff;
                    ok, driver_name := table_find(*state.tty_drivers, driver_number);
                    if ok {
                        if driver_name == "/dev/tty" {
                            tty_name.* = sprint("/dev/tty%", tty_index);
                        } else {
                            tty_name.* = sprint("%/%", driver_name, tty_index);
                        }
                    }
                } else {
                    name, ok := get_tty_name(info.tty_number);
                    if ok {
                        // Move ownership
                        tty_name.* = name;
                    }
                }
            }

            // Borrow
            info.tty_name = tty_name.*;

            if state.tty && state.tty == tty_name.* {
                table_set(*state.maybe_roots, pid, Void);
            }
        }

        parent_pid := info.parent_pid;
        assert(borrow_checker_my_ass == state.process_infos.entries.data, "no use after free please");

        // Insert a new parent info if we encountered the child first,
        // or add a child to an existing parent.
        parent_info:, not_found = find_or_add(*state.process_infos, parent_pid);
        array_add(*parent_info.children, pid);
    }

    if state.go_up {
        t: [..] Pid;
        t.allocator = temp;
        for state.maybe_roots {
            array_add(*t, it_index);
        }

        for pid: t {
        }
    }

    roots := get_only_roots(*state);
    if !roots {
        print("nothing found\n");
        exit(1);
    }

    flattened_tree: [..] *Extended_Process_Info;
    flattened_tree.allocator = temp;

    // This is confusing because I'm lazy and don't want to do a correct thing,
    // which would be to mark all the nodes in the tree whether I'm printing
    // them or not. Instead I just go over the list of roots I found and add all
    // of their parents (if state.go_up is true) before adding the subtree
    // starting from the chosen roots. I do this, because I want to know the
    // (grand-)parents of the target process but not any of it's
    // siblings/cousings. But I do want to know all of the descendants...
    max_backwards_depth := 0;
    if state.go_up {
        for roots {
            info := table_find_pointer(*state.process_infos, it);
            if !info continue;

            info = table_find_pointer(*state.process_infos, info.parent_pid);
            add_parents(*state.process_infos, info, *flattened_tree);
            if info {
                max_backwards_depth = max(info.depth + 1, max_backwards_depth);
            }
        }
    }

    for roots {
        depth_first_children(*state.process_infos, it, *flattened_tree, max_backwards_depth);
    }

    current_time := current_time_consensus();
    current_date_time := to_calendar(current_time);

    //
    // Prepare the output table
    //
    Columns :: enum {
        PID; STATE; TTY; START; RAN; CPU; MEM; COMMAND;
    };
    using Columns;
    column_headers :: string.["PID", "S", "TTY", "START", "RAN", "%CPU", "%MEM", "COMMAND"];
    column_widths: [column_headers.count] int;
    for column_headers {
        column_widths[it_index] = it.count + 2; // `+ 2` for separation
    }
    // Hard-code %CPU column to have enough space for "100.0", so that it doesn't jiggle
    column_widths[CPU] = 7;

    table: [..] [column_headers.count] string;
    array_reserve(*table, flattened_tree.count);
    for flattened_tree {
        row : [] string = array_add(*table).*;
        command_line, ok := get_process_command_line(it.pid);
        it.command_line = command_line;

        // PID
        row[PID] = tprint("%", it.pid);

        // STATE
        row[STATE] = tprint("%", cast(string) it.state);

        // TTY
        tty := it.tty_name;
        if tty.count > 5 && substring(tty, count = 5) == "/dev/" {
            tty = substring(tty, start = 5);
        }
        row[TTY] = tty;

        // START TIME
        start_date_time := to_calendar(it.start_time, .LOCAL);
        if is_same_day(start_date_time, current_date_time) {
            row[START] = tprint("%:%", start_date_time.hour,
                                         fmt(start_date_time.minute, 2));
        } else {
            month_short :: string.["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
            row[START] = tprint("% %", month_short[start_date_time.month_starting_at_0], start_date_time.day_of_month_starting_at_0 + 1);
        }

        // RUNNING TIME
        running_time_seconds := it.user_mode_time_seconds + it.kernel_mode_time_seconds;
        {
            seconds := running_time_seconds % 60;
            minutes := (running_time_seconds / 60) % 60;
            hours := running_time_seconds / 60 / 60;
            if hours {
                row[RAN] = tprint("%:%:%", hours, fmt(minutes, 2), fmt(seconds, 2));
            } else {
                row[RAN] = tprint("%:%", minutes, fmt(seconds, 2));
            }
        }

        // CPU PERCENTAGE
        // how long of the total process' lifetime was it actually not sleeping
        {
            process_uptime := to_seconds(current_time - it.start_time);
            if process_uptime {
                percentage_of_time_used_cpu := 100.0 * cast(float64) running_time_seconds / cast(float64) process_uptime;
                row[CPU] = tprint("%", fmt(percentage_of_time_used_cpu, digits_after_comma=1));
            } else {
                row[CPU] = "0.0";
            }
        }

        // MEM USAGE
        {
            rss_bytes := it.resident_set_memory_units * system_info.resident_set_memory_unit_size;
            phys_mem_usage := 100.0 * cast(float64) rss_bytes / cast(float64) system_info.memory_capacity_bytes;
            row[MEM] = tprint("%", fmt(phys_mem_usage, digits_after_comma=1));
        }

        // COMMAND LINE
        builder: String_Builder; builder.allocator = temp;
        if !options.for_fzf && it.depth {
            for 0..it.depth-2 {
                // TODO: add '|' as ps does when there's uncle processes
                append(*builder, "    ");
            }
            append(*builder, " \\_ ");
        }
        if !it.command_line {
            append(*builder, "?");
        } else for it.command_line {
            if it_index == 0 /* && !options.for_fzf */ {
                append(*builder, "\e[32m");
                append(*builder, it);
                append(*builder, "\e[0m");
            } else {
                append(*builder, it);
            }
            append(*builder, " ");
        }
        row[COMMAND] = builder_to_string(*builder,, temp);

        for *column_widths {
            visible_count := count_visible_characters(row[it_index]);
            it.* = max(it.*, visible_count + 2); // `+ 2` for separator
        }
    }

    // Display table header
    builder: String_Builder; builder.allocator = temp;
    if !options.for_fzf {
        for col: column_headers {
            if column_headers[it_index] == "COMMAND" {
                // Last column is left aligned, only needs a signle separator space
                append(*builder, " ");
            } else {
                for 1..(column_widths[it_index] - col.count) append(*builder, " ");
            }
            append(*builder, "\e[2;36m"); // color dark cyan
            append(*builder, col);
            append(*builder, "\e[0m");
        }
        append(*builder, "\n");
    }

    // Display table rows
    for row: table {
        for col: row {
            if column_headers[it_index] == "COMMAND" {
                // Last column is left aligned, only needs a signle separator space
                append(*builder, " ");
            } else {
                for 1..(column_widths[it_index] - col.count) append(*builder, " ");
            }
            append(*builder, col);
        }
        append(*builder, "\n");
    }

    write_builder(*builder);
}

//
// remove non-roots from the set of candidates
//

get_only_roots :: (state: *State) -> [] Pid {
    maybe_roots := NewArray(state.maybe_roots.count, Pid);
    i := 0;
    for state.maybe_roots {
        maybe_roots[i] = it_index;
        i += 1;
    }

    i = 0;
    while outer_loop := (i < maybe_roots.count) {
        current_pid := maybe_roots[i];
        while true {
            info := table_find_pointer(*state.process_infos, current_pid);
            if !info break;

            if table_find_pointer(*state.maybe_roots, info.parent_pid) != null {
                // This candidate is a child of another candidate
                array_unordered_remove_by_index(*maybe_roots, i);
                continue outer_loop;
            }

            if current_pid == info.parent_pid {
                // Shouldn't happen but may
                break;
            }
            current_pid = info.parent_pid;
        }

        i += 1;
    }

    return maybe_roots;
}

//
// tree traversal
//

depth_first_children :: (tree: *Table(Pid, Extended_Process_Info), root: Pid, result: *[..] *Extended_Process_Info, depth := 0) {
    info := table_find_pointer(tree, root);
    if !info return;
    info.depth = depth;

    array_add(result, info);
    for info.children {
        depth_first_children(tree, it, result, depth + 1);
    }
}

add_parents :: (tree: *Table(Pid, Extended_Process_Info), info: *Extended_Process_Info, result: *[..] *Extended_Process_Info) -> depth: s64 {
    if !info return -1;
    // There's no process 0
    if info.pid == 0 return -1;

    parent_info := table_find_pointer(tree, info.parent_pid);
    parent_depth := add_parents(tree, parent_info, result);
    info.depth = parent_depth + 1;

    array_add(result, info);
    return info.depth;
}

//
// date-time utilities
//

is_same_day :: inline (lhs: Calendar_Time, rhs: Calendar_Time) -> bool {
    return
        lhs.day_of_month_starting_at_0 == rhs.day_of_month_starting_at_0
        && lhs.month_starting_at_0 == rhs.month_starting_at_0
        && lhs.year == rhs.year;
}

//
// formatting utilities
//

fmt :: inline (v: u64, minimum_digits := 1, $padding := "0") -> FormatInt #expand {
    #assert(padding.count == 1);
    return FormatInt.{ value = v, minimum_digits = minimum_digits, padding = padding[0] };
}

fmt :: inline (v: s64, minimum_digits := 1, $padding := "0") -> FormatInt #expand {
    #assert(padding.count == 1);
    return FormatInt.{ value = v, minimum_digits = minimum_digits, padding = padding[0] };
}

fmt :: inline (v: float64, digits_after_comma := -1) -> FormatFloat #expand {
    return FormatFloat.{ value = v, trailing_width = digits_after_comma, zero_removal = .NO };
}

test_count_visible_characters :: () {
    assert(count_visible_characters("foobar") == 6);
    assert(count_visible_characters("foo\e[00mbar") == 6);
    assert(count_visible_characters("foo\e[13;13434;1341;00mbar") == 6);
    assert(count_visible_characters("") == 0);
    assert(count_visible_characters("\e[31231;123123m\e[31323;313321m") == 0);
    assert(count_visible_characters("\e[31231;123123ma\e[31323;313321m") == 1);
    assert(count_visible_characters("\e[31m[31m") == 4);
}

//
// sysconf (unistd.h)
//

system_info: System_Info;

libc :: #system_library "libc";
sysconf :: (name: s32) -> s64 #foreign libc;

#import "Basic";
#import "Hash_Table";
#import "String";
#import "POSIX";
#import "File";
#import "My_File";
#import "My_Util";
#import "Version_Banner";
#import "Process_Info";
