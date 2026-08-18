get_all_pids :: (log_errors := false) -> [] Pid, ok: bool {
    log_error("`get_all_pids` is not implemented on % yet", OS);
    return .[], false;
}

get_process_command_line :: (pid: Pid, log_errors := false) -> (ok: bool, command_line: [] string, executable: string) {
    log_error("`get_process_command_line` is not implemented on % yet", OS);
    return false, .[], "";
}

get_process_cwd :: (pid: Pid, log_errors := false) -> cwd: string, ok: bool {
    log_error("`get_process_cwd` is not implemented on % yet", OS);
    return "", false;
}

get_child_pids :: (parent: Pid, log_errors := false) -> ok: bool, children: [] Pid {
    log_error("`get_child_pids` is not implemented on % yet", OS);
    return false, .[];
}

get_pipe_id_for_fd :: (pid: Pid, fd: s32, log_errors := false) -> ok: bool, is_pipe: bool, pipe_id: u64 {
    log_error("`get_pipe_id_for_fd` is not implemented on % yet", OS);
    return false, false, 0;
}

find_process_attached_to_pipe :: (candidates: [] Pid, pipe_id: u64, log_errors := false) -> ok: bool, writer: Pid {
    log_error("`find_process_attached_to_pipe` is not implemented on % yet", OS);
    return false, 0;
}

get_process_info :: (pid: Pid, info: *Process_Info, system_info: *System_Info = null, log_errors := true) -> bool {
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
