get_all_pids :: (log_errors := false) -> [] Pid, ok: bool {
    bytes := proc_listpids(PROC_ALL_PIDS, 0, null, 0);
    if bytes < 0 {
        if log_errors {
            code, message := get_error_value_and_string();
            log_error("proc_listpids failed: % %", code, message);
        }
        return .[], false;
    }
    assert(bytes % size_of(pid_t) == 0, "%", bytes);

    count := bytes / size_of(pid_t);
    sys_pids := NewArray(count, pid_t,, temp);

    rc := proc_listpids(PROC_ALL_PIDS, 0, sys_pids.data, bytes);
    if rc < 0 {
        if log_errors {
            code, message := get_error_value_and_string();
            log_error("proc_listpids failed: % %", code, message);
        }
        return .[], false;
    }

    pids := NewArray(count, Pid);
    for sys_pids pids[it_index] = xx it;

    return pids, true;
}

get_process_command_line :: (pid: Pid, log_errors := false) -> (ok: bool, command_line: [] string, executable: string) {
    sysctl_args := u32.[CTL_KERN, KERN_PROCARGS2, xx pid];

    ok, size := sysctl(sysctl_args, null);
    if !ok || size == 0 {
        if log_errors {
            code, message := get_error_value_and_string();
            log_error("sysctl(%) failed: #% %", sysctl_args, code, message);
        }
        return false, .[], "";
    }

    buffer := NewArray(xx size, u8, alignment=4,, temp);
    ok = sysctl(sysctl_args, buffer);
    if !ok {
        if log_errors {
            code, message := get_error_value_and_string();
            log_error("sysctl(%) failed: #% %", sysctl_args, code, message);
        }
        return false, .[], "";
    }

    p := buffer.data;
    end := buffer.data + buffer.count;

    // First a 32-bit integer `argc`
    argc := p.(*s32).*;
    p += size_of(s32);

    // Then a full path to the executable
    executable := copy_string(to_string(p));
    p += executable.count;

    // Then some number of padding nul-bytes
    while (p < end) && (p.* == 0)  p += 1;

    // Then a sequence of nul-byte separated `argv`
    result: [..] string;
    array_reserve(*result, argc);
    for 0..argc - 1 {
        arg := to_string(p);
        p += arg.count + 1;
        array_add(*result, copy_string(arg));
    }

    return true, result, executable;
}

get_process_cwd :: (pid: Pid, log_errors := false) -> cwd: string, ok: bool {
    path_info: proc_vnodepathinfo;
    rc := proc_pidinfo(xx pid, PROC_PIDVNODEPATHINFO, 0, *path_info, xx size_of(type_of(path_info)));

    // Returns 0 (with errno set to EPERM) for processes belonging to other users
    if rc <= 0 {
        if log_errors {
            code, message := get_error_value_and_string();
            log_error("proc_pidinfo(PROC_PIDVNODEPATHINFO) failed: #% %", code, message);
        }
        return "", false;
    }

    // The kernel nul-terminates this one, MAXPATHLEN includes the nul-byte
    cwd := to_string(path_info.pvi_cdir.vip_path.data);
    if !cwd return "", false;

    return copy_string(cwd), true;
}

// Direct children of `parent`, via `proc_listchildpids` — no full-system scan
// required.
get_child_pids :: (parent: Pid, log_errors := false) -> ok: bool, children: [] Pid {
    bytes := proc_listchildpids(xx parent, null, 0);
    if bytes < 0 {
        if log_errors {
            code, message := get_error_value_and_string();
            log_error("proc_listchildpids failed: % %", code, message);
        }
        return false, .[];
    }
    if bytes == 0 return true, .[];

    assert(bytes % size_of(pid_t) == 0, "%", bytes);
    count := bytes / size_of(pid_t);
    sys_pids := NewArray(count, pid_t,, temp);

    rc := proc_listchildpids(xx parent, sys_pids.data, bytes);
    if rc < 0 {
        if log_errors {
            code, message := get_error_value_and_string();
            log_error("proc_listchildpids failed: % %", code, message);
        }
        return false, .[];
    }

    pids := NewArray(count, Pid);
    for sys_pids pids[it_index] = xx it;

    return true, pids;
}

// Resolves fd `fd` of process `pid` to a pipe id (its `pipe_handle`) if it's a
// pipe. `proc_pidfdinfo` doesn't cleanly distinguish "fd isn't a pipe" from
// "error" via its return value alone, so any failure here is reported as
// `is_pipe = false` rather than `ok = false`.
get_pipe_id_for_fd :: (pid: Pid, fd: s32, log_errors := false) -> ok: bool, is_pipe: bool, pipe_id: u64 {
    info: pipe_fdinfo;
    rc := proc_pidfdinfo(xx pid, fd, PROC_PIDFDPIPEINFO, *info, xx size_of(pipe_fdinfo));
    if rc <= 0 {
        if log_errors {
            code, message := get_error_value_and_string();
            log_error("proc_pidfdinfo(PROC_PIDFDPIPEINFO, pid=%, fd=%) failed: #% %", pid, fd, code, message);
        }
        return true, false, 0;
    }

    return true, true, info.pipeinfo.pipe_handle;
}

// Returns the first of `candidates` with an open, write-capable fd on the pipe
// identified by `pipe_id` (matching either `pipe_handle` or `pipe_peerhandle`,
// since a pipe's two ends see the values swapped). The write-capable check
// matters because matching by handle alone can't tell "this candidate is
// writing into our pipe" from "this candidate merely still holds a stale copy
// of the read end" (e.g. an intermediate shell that forked us and hasn't
// closed its inherited copy of our stdin yet) — `fi_openflags` (from
// `proc_fileinfo`, embedded in `pipe_fdinfo`) carries the same O_ACCMODE bits
// as <fcntl.h>. Candidates we can't inspect are silently skipped, not treated
// as a failure of the whole call.
find_process_attached_to_pipe :: (candidates: [] Pid, pipe_id: u64, log_errors := false) -> ok: bool, writer: Pid {
    for candidate: candidates {
        bytes := proc_pidinfo(xx candidate, PROC_PIDLISTFDS, 0, null, 0);
        if bytes <= 0 continue;

        count := bytes / size_of(proc_fdinfo);
        fds := NewArray(count, proc_fdinfo,, temp);

        rc := proc_pidinfo(xx candidate, PROC_PIDLISTFDS, 0, fds.data, bytes);
        if rc <= 0 continue;

        for fd_entry: fds {
            if fd_entry.proc_fdtype != PROX_FDTYPE_PIPE continue;

            info: pipe_fdinfo;
            fd_rc := proc_pidfdinfo(xx candidate, fd_entry.proc_fd, PROC_PIDFDPIPEINFO, *info, xx size_of(pipe_fdinfo));
            if fd_rc <= 0 continue;

            matches_pipe := info.pipeinfo.pipe_handle == pipe_id || info.pipeinfo.pipe_peerhandle == pipe_id;
            if !matches_pipe continue;

            writable := (info.pfi.fi_openflags & O_ACCMODE) != O_RDONLY;
            if writable return true, candidate;
        }
    }

    return false, 0;
}

get_process_info :: (pid: Pid, info: *Process_Info, system_info: *System_Info = null, log_errors := true) -> bool {
    task_info: proc_taskallinfo;
    rc := proc_pidinfo(xx pid, PROC_PIDTASKALLINFO, 0, *task_info, xx size_of(type_of(task_info)));

    if rc < 0 {
        if log_errors {
            code, message := get_error_value_and_string();
            log_error("proc_pidinfo(PROC_PIDTASKALLINFO) failed: #% %", code, message);
        }
        return false;
    }

    if !system_info {
        system_info = New(System_Info,, temp);
        system_info.* = get_system_info();
    }

    using task_info.pbsd;
    using task_info.ptinfo;

    info.pid = pid;
    info.command_short = pbi_comm;

    state: u8 = "?";
    // XXX: clanker came up with these
    if pbi_status == {
        case SIDL;   state = "I";
        case SRUN;   state = "R";
        case SSLEEP; state = "S";
        case SSTOP;  state = "T";
        case SZOMB;  state = "Z";
    }
    info.state[0] = state;

    info.parent_pid = xx pbi_ppid;

    if e_tdev != -1 {
        info.tty_number = e_tdev.(s32, no_check);
    }

    // These are raw mach_absolute_time ticks
    info.user_mode_time_seconds = mach_ticks_to_seconds(pti_total_user, system_info);
    info.kernel_mode_time_seconds = mach_ticks_to_seconds(pti_total_system, system_info);

    NANOS_PER_MICRO :: 1000;
    start_timespec := timespec.{xx pbi_start_tvsec, xx pbi_start_tvusec * NANOS_PER_MICRO};
    info.start_time = timespec_to_apollo(start_timespec);

    info.virtual_memory_kibi_bytes = xx pti_virtual_size;
    info.resident_set_memory_units = xx pti_resident_size;

    return true;
}

get_system_info :: () -> System_Info, bool {
    using _SC_definitions;

    result: System_Info;

    {
        boot_time: timeval;
        ok := sysctl(.[CTL_KERN, KERN_BOOTTIME], *boot_time);
        assert(ok, "%, %", get_error_value(), get_error_string(get_error_value()));

        MICROS_PER_NANO :: 1000;
        // XXX: this converts `0 at UNIX EPOCH` -> `0 at APOLLO 11 LANDING`
        t := timespec_to_apollo(.{boot_time.tv_sec, boot_time.tv_usec * MICROS_PER_NANO});
        result.system_boot_time = t;
    }

    {
        now := current_time_consensus();
        elapsed := result.system_boot_time - now;
        result.system_up_time_seconds = to_seconds(elapsed);
    }

    {
        memsize: u64;
        ok := sysctl(.[CTL_HW, HW_MEMSIZE], *memsize);
        assert(ok, "%, %", get_error_value(), get_error_string(get_error_value()));

        result.memory_capacity_bytes = xx memsize;
    }

    mach_timebase_info(*result.mach_timebase);

    // On macos both resident & virtual memory seems to be reported in bytes
    result.resident_set_memory_unit_size = 1;
    result.virtual_memory_unit_size = 1;

    return result, true;
}

get_tty_name :: (tty_number: s64) -> string, bool {
    // @Robustness: this function is NOT thread safe
    p := devname(xx tty_number, S_IFCHR);
    if !p return "", false;

    result := copy_string(to_string(p));
    return result, true;
}

#scope_module

//
// stdlib
//

devname :: (dev: dev_t, mode: mode_t) -> *u8 #foreign libc;

libc :: #library,system "libc";

//
// mach_absolute_time conversion
//

mach_ticks_to_seconds :: (ticks: u64, system_info: *System_Info) -> s64 {
    nanoseconds := ticks * system_info.mach_timebase.numer / system_info.mach_timebase.denom;
    return xx (nanoseconds / 1_000_000_000);
}

Mach_Timebase_Info :: struct {
    numer: u32;
    denom: u32;
}

mach_timebase_info :: (info: *Mach_Timebase_Info) -> s32 #foreign libc;

//
// sysctl
//

sysctl :: inline (name: [] u32, old: *$T, new: *$U = null) -> bool, u64 {
    size := size_of(T).(u64);
    rc := sysctl(xx name.data, xx name.count, old, *size, new, xx size_of(U));
    ok := (rc == 0);
    return ok, size;
}

sysctl :: inline (name: [] u32, old: [] $T, new: *$U = null) -> bool, u64 {
    size := old.count.(u64);
    rc := sysctl(xx name.data, xx name.count, old.data, *size, new, xx size_of(U));
    ok := (rc == 0);
    return ok, size;
}

//
// imports
//

#load "macos/bindings/libproc.jai";
#import "System";
#import "POSIX";
#import "Basic";
