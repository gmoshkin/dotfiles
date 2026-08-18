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

get_process_cwd :: (pid: Pid, log_errors := false) -> cwd: string, ok: bool {
    proc_cwd := tprint("/proc/%/cwd\x00", pid);

    auto_release_temp();
    buffer := alloc_string(4096,, temp);

    // `/proc/<pid>/cwd` is a symlink to the working directory, but only
    // readable for processes we own
    rc := readlink(proc_cwd.data, buffer.data, xx buffer.count);
    if rc < 0 {
        if log_errors {
            set_last_error_from_system("readlink: ");
            log_error("readlink(/proc/%/cwd) failed: %", pid, last_error_to_string(.NONE));
        }
        return "", false;
    }

    return copy_string(slice(buffer, 0, rc)), true;
}

// Immediate children of `parent`'s main thread, from `/proc/<pid>/task/<pid>/children`
// (a Linux-since-3.5 procfs file, see `man 5 proc`). Space-separated pid list, no
// full-system scan required.
get_child_pids :: (parent: Pid, log_errors := false) -> ok: bool, children: [] Pid {
    contents, ok := my_read_entire_file(tprint("/proc/%/task/%/children", parent, parent), log_errors=log_errors,, temp);
    if !ok return false, .[];

    result: [..] Pid;
    tail := contents;
    while tail {
        found:, s:, tail = split_from_left(tail, #char " ");
        s = trim(s);
        if !s continue;

        pid_value, parse_ok := string_to_int(s, base=10, T=Pid);
        if parse_ok array_add(*result, pid_value);
    }
    return true, result;
}

// Resolves `/proc/<pid>/fd/<fd>` and, if it's a pipe (`pipe:[<inode>]`), returns the
// inode number as an opaque id that's shared by both ends of the pipe.
get_pipe_id_for_fd :: (pid: Pid, fd: s32, log_errors := false) -> ok: bool, is_pipe: bool, pipe_id: u64 {
    proc_fd := tprint("/proc/%/fd/%\x00", pid, fd);

    auto_release_temp();
    buffer := alloc_string(4096,, temp);
    rc := readlink(proc_fd.data, buffer.data, xx buffer.count);
    if rc < 0 {
        if log_errors {
            set_last_error_from_system("readlink: ");
            log_error("readlink(%) failed: %", proc_fd, last_error_to_string(.NONE));
        }
        return false, false, 0;
    }

    target := slice(buffer, 0, rc);

    PREFIX :: "pipe:[";
    if !begins_with(target, PREFIX) || !ends_with(target, "]") {
        return true, false, 0; // not a pipe, but we did successfully determine that
    }

    inode_string := slice(target, PREFIX.count, target.count - PREFIX.count - 1);
    inode, parse_ok := string_to_int(inode_string, base=10, T=u64);
    if !parse_ok return false, false, 0;

    return true, true, inode;
}

// A pipe's two ends share the same inode, so matching by inode alone can't tell
// "this candidate is writing into our pipe" from "this candidate merely still
// holds a stale copy of the read end" (e.g. an intermediate shell that forked us
// and hasn't closed its inherited copy of our stdin yet). `/proc/<pid>/fdinfo/<fd>`'s
// `flags:` line (octal, low 2 bits are the access mode, matching <fcntl.h>'s
// O_ACCMODE) lets us additionally require the fd to be write-capable.
is_fd_writable :: (pid: Pid, fd: s32, log_errors := false) -> ok: bool, writable: bool {
    contents, ok := my_read_entire_file(tprint("/proc/%/fdinfo/%", pid, fd), log_errors=log_errors,, temp);
    if !ok return false, false;

    tail := contents;
    while tail {
        found:, line:, tail = split_from_left(tail, #char "\n");
        if !begins_with(line, "flags:") continue;

        value := trim(slice(line, "flags:".count, line.count - "flags:".count));
        flags, parse_ok := string_to_int(value, base=8, T=s32);
        if !parse_ok return false, false;

        return true, (flags & O_ACCMODE) != O_RDONLY;
    }
    return false, false;
}

// Returns the first of `candidates` that has an open, write-capable fd on the
// pipe identified by `pipe_id`. Candidates we can't inspect (permission denied,
// already exited) are silently skipped, not treated as a failure of the whole call.
find_process_attached_to_pipe :: (candidates: [] Pid, pipe_id: u64, log_errors := false) -> ok: bool, writer: Pid {
    for candidates {
        fd_names: [..] string;
        fd_names.allocator = temp;

        visitor :: (info: *File_Visit_Info, fd_names: *[..] string) {
            array_add(fd_names, copy_string(info.short_name,, temp));
        };

        saved_logger: type_of(context.logger);
        if !log_errors {
            saved_logger = context.logger;
            context.logger = (_: string, _: *void, _: Log_Info) {};
        }
        // `/proc/<pid>/fd/*` entries are symlinks to non-directories (pipes,
        // sockets, regular files, ...), so they're only visited when
        // `visit_files` is set — `visit_symlinks` alone just narrows which of
        // the visited entries are symlinks, it doesn't select them on its own.
        dir_ok := visit_files(tprint("/proc/%/fd", it), recursive=false, user_data=*fd_names, proc=visitor,
                               visit_files=true, visit_directories=false, visit_symlinks=true);
        if !log_errors context.logger = saved_logger;
        if !dir_ok continue;

        for fd_name: fd_names {
            fd, parse_ok := string_to_int(fd_name, base=10, T=s32);
            if !parse_ok continue;

            candidate_ok, candidate_is_pipe, candidate_pipe_id := get_pipe_id_for_fd(it, fd, log_errors=false);
            if !candidate_ok || !candidate_is_pipe || candidate_pipe_id != pipe_id continue;

            writable_ok, writable := is_fd_writable(it, fd, log_errors=false);
            if writable_ok && writable return true, it;
        }
    }

    return false, 0;
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
    i: int;

    {
        i = 1;
        // First one is always the pid, but we already know it
        found:, pid_string:, tail = split_from_left(tail, #char " ");
        if !found {
            if log_errors log_error("Expected a space somewhere in /proc/%/stat", pid);
            return false;
        }
    }

    {
        i = 2;
        // Second is the short process name
        command_short: string;

        closing := find_index_from_right(tail, #char ")");
        if tail[0] == "(" && closing != -1 {
            command_short = slice(tail, 1, closing - 1);
            // `+ 2` for ')' and ' ' after it
            advance(*tail, closing + 2);
        } else {
            // unreachable, but I'm paranoid
            _, s:, tail = split_from_left(tail, #char " ");
            command_short = s;
        }

        // Longer names (kernel workqueue threads) get truncated
        count := min(command_short.count, info.command_short.count);
        memcpy(info.command_short.data, command_short.data, count);
    }

    while tail {
        i += 1;
        found:, s:, tail = split_from_left(tail, #char " ");

        // Column numbers are the ones from `man 5 proc`, which counts from 1
        if i == {
        case 3;
            assert(s.count == 1);
            info.state[0] = s[0];
        case 4;
            parent_pid_value:, ok = string_to_int(s, base=10, T=s64);
            if !ok {
                if log_errors log_error("Expected an integer as column #%", i);
                return false;
            }
            info.parent_pid = xx parent_pid_value;
        case 5; // pgrp: process group id
        case 6; // session: session id
        case 7;
            info.tty_number, ok = string_to_int(s, base=10, T=s64);
            if !ok {
                if log_errors log_error("Expected an integer as column #%", i);
                return false;
            }
        case 8;  // tpgid: foreground process group of the controlling terminal
        case 9;  // flags: kernel PF_* flags word
        case 10; // minflt: minor faults, the ones not requiring a page load
        case 11; // cminflt: minor faults of all waited-for children
        case 12; // majflt: major faults, the ones requiring a page load
        case 13; // cmajflt: major faults of all waited-for children
        case 14;
            umode:, ok = string_to_int(s, base=10, T=s64);
            if !ok {
                if log_errors log_error("Expected an integer as column #%", i);
                return false;
            }
            info.user_mode_time_seconds = umode / system_info.clock_ticks_per_second;
        case 15;
            smode:, ok = string_to_int(s, base=10, T=s64);
            if !ok {
                if log_errors log_error("Expected an integer as column #%", i);
                return false;
            }
            info.kernel_mode_time_seconds = smode / system_info.clock_ticks_per_second;
        case 16; // cutime: user mode time of all waited-for children, in ticks
        case 17; // cstime: kernel mode time of all waited-for children, in ticks
        case 18; // priority: negated scheduling priority - 1 for realtime processes, otherwise the nice value
        case 19; // nice: from 19 (nicest) to -20 (least nice)
        case 20; // num_threads
        case 21; // itrealvalue: obsolete, always 0
        case 22;
            starttime:, ok = string_to_int(s, base=10, T=s64);
            if !ok {
                if log_errors log_error("Expected an integer as column #%", i);
                return false;
            }
            info.start_time = system_info.system_boot_time + seconds_to_apollo(starttime / system_info.clock_ticks_per_second);
        case 23;
            // XXX: this is some weird value, don't think it's actually usefull
            // NOTE: `man 5 proc` documents vsize as being in bytes, but we store
            // it in a field named `_kibi_bytes` and `get_system_info` reports a
            // `virtual_memory_unit_size` of 1024, so one of the two is wrong
            info.virtual_memory_kibi_bytes, ok = string_to_int(s, base=10, T=s64);
            if !ok {
                if log_errors log_error("Expected an integer as column #%", i);
                return false;
            }
        case 24;
            // In pages, hence `resident_set_memory_unit_size` being the page size
            info.resident_set_memory_units, ok = string_to_int(s, base=10, T=s64);
            if !ok {
                if log_errors log_error("Expected an integer as column #%", i);
                return false;
            }
        case 25; // rsslim: current soft limit on the resident set size, in bytes
            break; // Don't care about the rest for now
        case 26; // startcode: address above which program text can run
        case 27; // endcode: address below which program text can run
        case 28; // startstack: address of the start (bottom) of the stack
        case 29; // kstkesp: current stack pointer, zeroed out unless we're root
        case 30; // kstkeip: current instruction pointer, zeroed out unless we're root
        case 31; // signal: obsolete bitmap of pending signals, use /proc/<pid>/status
        case 32; // blocked: obsolete bitmap of blocked signals, use /proc/<pid>/status
        case 33; // sigignore: obsolete bitmap of ignored signals, use /proc/<pid>/status
        case 34; // sigcatch: obsolete bitmap of caught signals, use /proc/<pid>/status
        case 35; // wchan: address of the kernel function the process is sleeping in
        case 36; // nswap: pages swapped, not maintained by the kernel
        case 37; // cnswap: pages swapped by children, not maintained by the kernel
        case 38; // exit_signal: the signal sent to the parent when we die
        case 39; // processor: the cpu this process last ran on
        case 40; // rt_priority: realtime scheduling priority, 0 for non-realtime
        case 41; // policy: scheduling policy, one of the SCHED_* constants
        case 42; // delayacct_blkio_ticks: aggregated block I/O delays, in ticks
        case 43; // guest_time: time spent running a virtual cpu, in ticks
        case 44; // cguest_time: guest time of all waited-for children, in ticks
        case 45; // start_data: address above which initialized & uninitialized data are placed
        case 46; // end_data: address below which initialized & uninitialized data are placed
        case 47; // start_brk: address above which the heap can be expanded
        case 48; // arg_start: address above which the command line arguments are placed
        case 49; // arg_end: address below which the command line arguments are placed
        case 50; // env_start: address above which the environment is placed
        case 51; // env_end: address below which the environment is placed
        case 52; // exit_code: the status the process was reported with by waitpid
        }
    }

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
