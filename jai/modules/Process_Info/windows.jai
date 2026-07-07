get_process_command_line :: (pid: Pid, log_errors := false) -> [] string, ok: bool {
    log_error("`get_process_command_line` is not implemented on % yet", OS);
    return .[], false;
}

get_process_info :: (pid: Pid, info: *Process_Info, clock_ticks_per_second := -1, get_command_line := true, log_errors := true) -> bool {
    log_error("`get_process_info` is not implemented on % yet", OS);
    return false;
}
