get_all_pids :: (log_errors := false) -> [] Pid, ok: bool {
    log_error("`get_all_pids` is not implemented on % yet", OS);
    return .[], false;
}

get_process_command_line :: (pid: Pid, log_errors := false) -> (ok: bool, command_line: [] string, executable: string) {
    log_error("`get_process_command_line` is not implemented on % yet", OS);
    return false, .[], "";
}

get_process_info :: (pid: Pid, info: *Process_Info, clock_ticks_per_second := -1, get_command_line := true, log_errors := true) -> bool {
    log_error("`get_process_info` is not implemented on % yet", OS);
    return false;
}

get_system_info :: () -> System_Info, bool {
    log_error("`get_system_info` is not implemented on % yet", OS);
    return .{}, false;
}

get_tty_name :: (tty_number: s64) -> string, bool {
    log_error("`get_tty_name` is not implemented on % yet", OS);
    return "", false;
}
