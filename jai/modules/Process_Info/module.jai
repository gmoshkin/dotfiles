Pid :: s64;

Process_Info :: struct {
    pid: Pid;
    parent_pid: Pid = -1;

    command_line: [] string;
    executable: string;

    // The executable's name, truncated by the OS: `pbi_comm` from
    // PROC_PIDTASKALLINFO on macos, field 2 of `/proc/<pid>/stat` on linux. Both
    // cap it at 15 characters + a nul-byte (MAXCOMLEN / TASK_COMM_LEN are 16),
    // except for linux kernel workqueue threads, whose names `/proc` expands past
    // that (`kworker/u24:4-events_power_efficient`) and which we truncate.
    //
    // Stored inline rather than as a string so that `get_process_info` doesn't
    // have to allocate; read it with `command_short_string`.
    command_short: [16] u8;

    state: [1] u8;

    start_time: Apollo_Time;
    user_mode_time_seconds: s64;
    kernel_mode_time_seconds: s64;

    virtual_memory_kibi_bytes: s64;
    resident_set_memory_units: s64;

    tty_name: string;
    tty_number: s64;
}

// A view into `info.command_short`, so it lives exactly as long as `info` does
command_short_string :: (info: *Process_Info) -> string {
    result: string;
    result.data = info.command_short.data;
    result.count = info.command_short.count;

    // Not nul-terminated if the name fills the whole buffer
    for info.command_short {
        if it == 0 {
            result.count = it_index;
            break;
        }
    }

    return result;
}

System_Info :: struct {
    system_boot_time: Apollo_Time;
    system_up_time_seconds: s64;
    memory_capacity_bytes: s64;

    #if OS == .MACOS {
        mach_timebase: Mach_Timebase_Info;
    } else {
        clock_ticks_per_second: s64;
    }

    resident_set_memory_unit_size: s64;
    virtual_memory_unit_size: s64;
}

#if OS == .LINUX   #load "linux.jai";
#if OS == .MACOS   #load "macos.jai";
#if OS == .WINDOWS #load "windows.jai";

#import "Basic";
