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
    parent_pid: Pid = -1;

    command_line: [] string;

    state: [1] u8;

    started_seconds_since_boot: s64;
    user_mode_time_seconds: u64;
    kernel_mode_time_seconds: u64;

    virtual_memory_kibi_bytes: u64;
    resident_set_pages_count: u64;

    tty: string;
    tty_number: s64;

    children: [..] Pid;

    depth: s64;
}

Void : void;

main :: () {
    // test_count_visible_characters(); return;

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

    clock_ticks_per_second = xx sysconf(_SC_CLK_TCK);
    system_page_size := cast(u64) sysconf(_SC_PAGESIZE);

    // Read tty numbers
    {
        tty_drivers, ok := my_read_entire_file("/proc/tty/drivers", log_errors=false);
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
    {
        // Disable log_error, because this function doesn't take a log_errors parameter
        saved_logger := context.logger;
        defer context.logger = saved_logger;
        context.logger = (_: string, _: *void, _: Log_Info) {};
        ok := visit_files("/proc", recursive=false, user_data=*pids, proc=visitor, visit_files=false, visit_directories=true, follow_symlinks=false);
        assert(ok);
    }

    //
    // Get process's infos, collect root candidates
    //
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

            // Either add a new entry, or get an entry which was inserted by this one's child
            info, not_found := find_or_add(*state.process_infos, pid);
            info.pid = pid;

            borrow_checker_my_ass := state.process_infos.entries.data;

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

                if i == 3 {
                    assert(s.count == 1);
                    info.state[0] = s[0];
                }
                if i == 4 {
                    parent_pid_value:, ok = string_to_int(s, base=10, T=s64);
                    assert(ok);
                    info.parent_pid = xx parent_pid_value;
                }
                if i == 7 {
                    info.tty_number, ok = string_to_int(s, base=10, T=s64);
                    assert(ok);
                }
                if i == 14 {
                    umode:, ok = string_to_int(s, base=10, T=u64);
                    assert(ok);
                    info.user_mode_time_seconds = umode / clock_ticks_per_second;
                }
                if i == 15 {
                    smode:, ok = string_to_int(s, base=10, T=u64);
                    assert(ok);
                    info.kernel_mode_time_seconds = smode / clock_ticks_per_second;
                }
                if i == 22 {
                    starttime:, ok = string_to_int(s, base=10, T=u64);
                    assert(ok);
                    info.started_seconds_since_boot = xx (starttime / clock_ticks_per_second);
                }
                if i == 23 {
                    // XXX: this is some weird value, don't think it's actually usefull
                    info.virtual_memory_kibi_bytes, ok = string_to_int(s, base=10, T=u64);
                    assert(ok);
                }
                if i == 24 {
                    info.resident_set_pages_count, ok = string_to_int(s, base=10, T=u64);
                    assert(ok);
                }
            }

            if info.tty_number != 0 && info.tty_number != -1 {
                tty_name, not_found := find_or_add(*state.tty_number_to_name, info.tty_number);
                if not_found {
                    driver_number := cast(u8) ((info.tty_number >> 8) & 0xff);
                    // TODO: sometimes there's a index part in higher bits?
                    tty_index := info.tty_number & 0xff;
                    driver_name, ok := table_find(*state.tty_drivers, driver_number);
                    if ok {
                        if driver_name == "/dev/tty" {
                            tty_name.* = sprint("/dev/tty%", tty_index);
                        } else {
                            tty_name.* = sprint("%/%", driver_name, tty_index);
                        }
                    }
                }

                info.tty = tty_name.*;

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

            // info.command_line will be set later so as to not read extra files
            // we don't have to
        }
    }

    roots := get_only_roots(*state);
    if !roots {
        print("nothing found\n");
        exit(1);
    }

    flattened_tree: [..] *Process_Info;
    flattened_tree.allocator = temp;
    for roots {
        depth_first_children(*state.process_infos, it, *flattened_tree);
    }

    // Get physical memory capacity
    physical_memory_capacity_bytes: s64;
    {
        meminfo, ok := my_read_entire_file("/proc/meminfo", log_errors=false);
        assert(ok);
        tail := meminfo;
        while tail {
            _, line:, tail = split_from_left(tail, #char "\n");

            prefix := "MemTotal:";
            if !starts_with(line, prefix) continue;

            line = substring(line, start = prefix.count);
            line = trim_left(line);
            value, ok, remainder := string_to_int(line, T=s64, base=10);
            assert(ok);
            assert(remainder == " kB", "'%'", remainder);

            physical_memory_capacity_bytes = value * 1024;
        }
    }

    // Get system uptime
    system_uptime_seconds: s64;
    {
        uptime, ok := my_read_entire_file("/proc/uptime", log_errors=false);
        assert(ok);
        seconds_float:, ok = string_to_float(uptime);
        assert(ok);
        system_uptime_seconds = xx seconds_float;
    }

    current_time := current_time_consensus();
    current_time_seconds := to_seconds(current_time);
    current_date_time := to_calendar(current_time);
    system_boot_time_seconds := current_time_seconds - system_uptime_seconds;

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
    column_widths[CPU] = 6;

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
        tty := it.tty;
        if tty.count > 5 && substring(tty, count = 5) == "/dev/" {
            tty = substring(tty, start = 5);
        }
        row[TTY] = tty;

        // START TIME
        start_time_seconds := system_boot_time_seconds + xx it.started_seconds_since_boot;
        start_time := seconds_to_apollo(start_time_seconds);
        start_date_time := to_calendar(start_time, .LOCAL);
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
            process_uptime := system_uptime_seconds - it.started_seconds_since_boot;
            if process_uptime {
                percentage_of_time_used_cpu := 100.0 * cast(float64) running_time_seconds / cast(float64) process_uptime;
                row[CPU] = tprint("%", fmt(percentage_of_time_used_cpu, digits_after_comma=1));
            } else {
                row[CPU] = "0.0";
            }
        }

        // MEM USAGE
        {
            rss_bytes := it.resident_set_pages_count * system_page_size;
            phys_mem_usage := 100.0 * cast(float64) rss_bytes / cast(float64) physical_memory_capacity_bytes;
            row[MEM] = tprint("%", fmt(phys_mem_usage, digits_after_comma=1));
        }

        // COMMAND LINE
        builder: String_Builder; builder.allocator = temp;
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
        row[COMMAND] = builder_to_string(*builder,, temp);

        for *column_widths {
            visible_count := count_visible_characters(row[it_index]);
            it.* = max(it.*, visible_count + 2); // `+ 2` for separator
        }
    }

    // Display table header
    builder: String_Builder; builder.allocator = temp;
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

depth_first_children :: (tree: *Table(Pid, Process_Info), root: Pid, result: *[..] *Process_Info, depth := 0) {
    info := table_find_pointer(tree, root);
    if !info return;
    info.depth = depth;

    array_add(result, info);
    for info.children {
        depth_first_children(tree, it, result, depth + 1);
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

fmt :: inline (v: Pid, minimum_digits := 1, $padding := "0") -> FormatInt #expand {
    #assert(padding.count == 1);
    return FormatInt.{ value = v, minimum_digits = minimum_digits, padding = padding[0] };
}

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

clock_ticks_per_second: u64;

libc :: #system_library "libc";
sysconf :: (name: s32) -> s64 #foreign libc;

#import "Basic";
#import "Hash_Table";
#import "String";
#import "POSIX";
#import "File";
#import "File_Utilities";
#import "My_Util";
