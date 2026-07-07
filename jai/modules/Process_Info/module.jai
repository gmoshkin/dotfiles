Pid :: s64;

Process_Info :: struct {
    pid: Pid;
    parent_pid: Pid = -1;

    command_line: [] string;

    state: [1] u8;

    started_seconds_since_boot: s64;
    user_mode_time_seconds: s64;
    kernel_mode_time_seconds: s64;

    virtual_memory_kibi_bytes: s64;
    resident_set_pages_count: s64;

    tty_name: string;
    tty_number: s64;
}

#if OS == .LINUX   #load "linux.jai";
#if OS == .MACOS   #load "macos.jai";
#if OS == .WINDOWS #load "windows.jai";
