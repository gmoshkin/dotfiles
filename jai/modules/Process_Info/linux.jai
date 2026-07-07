get_process_command_line :: (pid: Pid, log_errors := false) -> [] string, ok: bool {
    cmdline, ok := my_read_entire_file(tprint("/proc/%/cmdline", pid), log_errors=log_errors,, temp);
    if !ok return .[], false;

    if !cmdline return .[], true;

    result: [..] string;
    result.allocator = context.allocator;

    tail := cmdline;
    while tail {
        found:, arg:, tail = split_from_left(tail, #char "\x00");
        array_add(*result, copy_string(arg));
    }
    return result, true;
}

get_process_info :: (pid: Pid, info: *Process_Info, clock_ticks_per_second := -1, get_command_line := true, log_errors := true) -> bool {
    stat, ok := my_read_entire_file(tprint("/proc/%/stat", pid), log_errors=log_errors,, temp);
    if !ok return false;

    if clock_ticks_per_second == -1 {
        #if OS == .LINUX {
            clock_ticks_per_second = xx sysconf(_SC_CLK_TCK);
        } else {
            assert(false, "only linux for now");
        }
    }

    info.pid = pid;

    tail := stat;
    i := 1;

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
            if !ok {
                if log_errors log_error("Expected an integer as column #%", i);
                return false;
            }
            info.parent_pid = xx parent_pid_value;
        }
        if i == 7 {
            info.tty_number, ok = string_to_int(s, base=10, T=s64);
            if !ok {
                if log_errors log_error("Expected an integer as column #%", i);
                return false;
            }
        }
        if i == 14 {
            umode:, ok = string_to_int(s, base=10, T=s64);
            if !ok {
                if log_errors log_error("Expected an integer as column #%", i);
                return false;
            }
            info.user_mode_time_seconds = umode / clock_ticks_per_second;
        }
        if i == 15 {
            smode:, ok = string_to_int(s, base=10, T=s64);
            if !ok {
                if log_errors log_error("Expected an integer as column #%", i);
                return false;
            }
            info.kernel_mode_time_seconds = smode / clock_ticks_per_second;
        }
        if i == 22 {
            starttime:, ok = string_to_int(s, base=10, T=s64);
            if !ok {
                if log_errors log_error("Expected an integer as column #%", i);
                return false;
            }
            info.started_seconds_since_boot = xx (starttime / clock_ticks_per_second);
        }
        if i == 23 {
            // XXX: this is some weird value, don't think it's actually usefull
            info.virtual_memory_kibi_bytes, ok = string_to_int(s, base=10, T=s64);
            if !ok {
                if log_errors log_error("Expected an integer as column #%", i);
                return false;
            }
        }
        if i == 24 {
            info.resident_set_pages_count, ok = string_to_int(s, base=10, T=s64);
            if !ok {
                if log_errors log_error("Expected an integer as column #%", i);
                return false;
            }
        }
    }

    // TODO: get tty_name

    if get_command_line {
        command_line, ok := get_process_command_line(info.pid, log_errors=log_errors);
        if !ok return false;
        info.command_line = command_line;
    }

    return true;
}

#import "POSIX";
#import "My_File";
#import "Basic";
#import "String";
