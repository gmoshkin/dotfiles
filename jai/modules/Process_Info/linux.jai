get_all_pids :: (log_errors := false) -> [] Pid, ok: bool {
    pid_strings: [..] string;
    pid_strings.allocator = temp;

    visitor :: (info: *File_Visit_Info, pid_strings: *[..] string) {
        array_add(pid_strings, copy_string(info.short_name,, temp));
    };

    // Disable log_error, because this function doesn't take a log_errors parameter
    saved_logger: type_of(context.logger);
    if !log_errors {
        saved_logger = context.logger;
        context.logger = (_: string, _: *void, _: Log_Info) {};
    }
    defer if !log_errors context.logger = saved_logger;

    // Walk the `/proc/*` directory to find all pids
    ok := visit_files("/proc", recursive=false, user_data=*pid_strings, proc=visitor, visit_files=false, visit_directories=true, visit_symlinks=false);
    if !ok return .[], false;

    pids: [..] Pid;
    array_reserve(*pids, pid_strings.count);

    // Convert pid strings to numbers
    for pid_strings {
        pid_value, ok := string_to_int(it, base=10, T=Pid);
        if !ok continue;

        array_add(*pids, pid_value);
    }

    return pids, true;
}

get_process_command_line :: (pid: Pid, log_errors := false) -> (ok: bool, command_line: [] string, executable: string) {
    cmdline, ok := my_read_entire_file(tprint("/proc/%/cmdline", pid), log_errors=log_errors,, temp);
    if !ok return false, .[], "";

    if !cmdline return true, .[], "";

    result: [..] string;
    result.allocator = context.allocator;

    tail := cmdline;
    while tail {
        found:, arg:, tail = split_from_left(tail, #char "\x00");
        array_add(*result, copy_string(arg));
    }

    executable: string;

    proc_exe := tprint("/proc/%/exe\x00", pid);
    auto_release_temp();
    buffer := alloc_string(4096,, temp);
    rc := readlink(proc_exe.data, buffer.data, xx buffer.count);
    if rc < 0 {
        set_last_error_from_system("readlink: ");
        executable = last_error_to_string(.NONE);
    } else {
        executable = copy_string(slice(buffer, 0, rc));
    }

    return true, result, executable;
}

get_process_info :: (pid: Pid, info: *Process_Info, system_info: *System_Info = null, log_errors := true) -> bool {
    stat, ok := my_read_entire_file(tprint("/proc/%/stat", pid), log_errors=log_errors,, temp);
    if !ok return false;

    if !system_info {
        system_info = New(System_Info,, temp);
        system_info.* = get_system_info();
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
            info.user_mode_time_seconds = umode / system_info.clock_ticks_per_second;
        }
        if i == 15 {
            smode:, ok = string_to_int(s, base=10, T=s64);
            if !ok {
                if log_errors log_error("Expected an integer as column #%", i);
                return false;
            }
            info.kernel_mode_time_seconds = smode / system_info.clock_ticks_per_second;
        }
        if i == 22 {
            starttime:, ok = string_to_int(s, base=10, T=s64);
            if !ok {
                if log_errors log_error("Expected an integer as column #%", i);
                return false;
            }
            info.start_time = system_info.system_boot_time + seconds_to_apollo(starttime / system_info.clock_ticks_per_second);
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
            info.resident_set_memory_units, ok = string_to_int(s, base=10, T=s64);
            if !ok {
                if log_errors log_error("Expected an integer as column #%", i);
                return false;
            }
        }
    }

    // TODO: get tty_name

    return true;
}

get_system_info :: () -> System_Info, bool {
    using _SC_definitions;

    result: System_Info;

    // Get system uptime
    {
        boot_time: timespec;
        rc := clock_gettime(.CLOCK_BOOTTIME, *boot_time);
        assert(rc == 0);

        // Mustn't use `timespec_to_apollo` here, because that one readjusts the
        // origin from UNIX EPOCH to Apollo 11 landing, but `seconds_to_apollo`
        // and friends don't readjust, and we don't want to readjust, because
        // this value is a `Duration` actually in rust's terms, meanings it's
        // relative to system's boot. Jai's Basic would benefit from some sort
        // of `Duration :: #type,isa S128;` type declaration...
        system_uptime := seconds_to_apollo(boot_time.tv_sec) + nanoseconds_to_apollo(boot_time.tv_nsec);
        current_time := current_time_consensus();

        result.system_boot_time = current_time - system_uptime;
        result.system_up_time_seconds = boot_time.tv_sec;
    }

    // Get physical memory capacity
    {
        info: Sysinfo;
        rc := sysinfo(*info);
        assert(rc == 0);

        result.memory_capacity_bytes = xx (info.totalram * info.mem_unit);
    }

    result.clock_ticks_per_second = xx sysconf(_SC_CLK_TCK);
    // On linux resident set size is reported in pages
    result.resident_set_memory_unit_size = xx sysconf(_SC_PAGESIZE);
    // But virtual memory is in kibibytes? I must be wrong about this!
    result.virtual_memory_unit_size = 1024;

    return result, true;
}

get_tty_name :: (tty_number: s64) -> string, bool {
    log("get_tty_name is not implemented on %", OS);
    return "", false;
}

//
// sysinfo
//

#scope_file

// Corresponds to `struct sysinfo` from <sys/sysinfo.h>
Sysinfo :: struct {
    uptime: s64;      // Seconds since boot
    loads: [3] u64;   // 1, 5 and 15 minute load averages
    totalram: u64;    // Total usable main memory size
    freeram: u64;     // Available memory size
    sharedram: u64;   // Amount of shared memory
    bufferram: u64;   // Memory used by buffers
    totalswap: u64;   // Total swap space size
    freeswap: u64;    // Swap space still available
    procs: u16;       // Number of current processes
    pad: u16;
    totalhigh: u64;   // Total high memory size
    freehigh: u64;    // Available high memory size
    mem_unit: u32;    // Memory unit size in bytes
}

sysinfo :: (info: *Sysinfo) -> s32 #foreign libc;

libc :: #library,system "libc";

//
// imports
//

#import "POSIX";
#import "My_File";
#import "Basic";
#import "String";
#import "File_Utilities";
#import "Error_Info";
