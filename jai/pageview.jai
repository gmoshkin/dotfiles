#run {
    #import "Compiler";
    set_build_options_dc(.{ output_executable_name = "pageview" });
}

State :: struct {

    //
    // main window state
    //

    row_offset: s64;
    col_offset: s64;
    stick_to_the_bottom := false;

    wrapped_line_offset: s64;
    line_wrapping := false;

    rows_to_display_count: s64;
    terminal_size: Terminal_Size_Info;

    //
    // input
    //

    input_mode: enum { NAVIGATE; INPUT_SEARCH_STRING; } = .NAVIGATE;
    search_string: string;

    input_buffer: [32] u8;
    input_buffer_count: s64;
    input_received_this_tick: bool;

    //
    // logging
    //

    log_file_name: string;
    log_file: File;
    log_file.handle = null;

    //
    // command
    //

    command: [] string;

    command_run_period_seconds := 1.0;
    time_next_command_run : float64 = -1.0;

    last_command_output: string;
    last_command_output_line_count: s64;
    last_command_output_max_line_length: s64;
    last_command_result: Process_Result;

    memory_pool_for_building_a_line: Flat_Pool;

    // Stores pointers into `last_shown_line_buffer_flat_pool`.
    last_shown_line_buffer: [..] string;
    memory_pool_for_last_shown_line_buffer: Flat_Pool;

    //
    // miscellaneous internals
    //

    saved_termios: Termios;

    epoll_fd: s32;
    epoll_events: [1] epoll_event;
}
#add_context state: State;

main :: () {
    args := get_command_line_arguments();
    if args.count == 1 {
        print("Need a command to run\n");
        return;
    }

    state := *context.state;

    cursor := 1;
    while true {
        arg := args[cursor];
        if arg == {
            case "-f"; #through;
            case "--follow";
                state.stick_to_the_bottom = true;

            case "-t"; #through;
            case "--time"; #through;
            case "--time-before-repeate";
                cursor += 1;
                if cursor >= args.count {
                    print("Expected a number of seconds after '%'\n", arg);
                    exit(1);
                }
                seconds, ok := string_to_float(args[cursor]);
                if !ok {
                    print("Expected a number of seconds after '%', got '%'\n", arg, args[cursor]);
                    exit(1);
                }
                state.command_run_period_seconds = seconds;

            case "-w"; #through;
            case "--wrap"; #through;
            case "--wrap-lines";
                state.line_wrapping = true;

            case "-l"; #through;
            case "--log";
                cursor += 1;
                if cursor >= args.count {
                    print("Expected a log file after '%'\n", arg);
                    exit(1);
                }
                state.log_file_name = args[cursor];

            // TODO: a flag to just watch a file's contents, so I don't have to
            // do `cat filename`

            case; break;
        }
        cursor += 1;
    }

    state.command.data = args.data + cursor;
    state.command.count = args.count - cursor;

    // Setup logger
    if state.log_file_name {
        log_file, ok := file_open(state.log_file_name, for_writing = true, keep_existing_content = true);
        assert(ok);
        state.log_file = log_file;
    }
    context.logger = my_logger;
    context.logger_data = *context.state;

    // Setup struct_printer
    context.print_style.struct_printer = ascii_or_hex_printer;

    signal(SIGINT, shutdown_signal_handler);
    signal(SIGTERM, shutdown_signal_handler);
    signal(SIGWINCH, window_size_changed_signal_handler);

    // Get terminal size
    rc := ioctl(STDIN_FILENO, TIOCGWINSZ, *state.terminal_size);

    // `- 2` for 2 status lines
    state.rows_to_display_count = state.terminal_size.rows - 2;

    // Hide cursor, disable echo, etc.
    {
        // "\e[?1049h": enable the alternative buffer
        // "\e[?25l": hide cursor
        write_strings("\e[?1049h", "\e[?25l");

        rc := tcgetattr(STDIN_FILENO, *state.saved_termios);
        assert(rc == 0);

        new_termios := state.saved_termios;

        // Copy-pasted from <https://github.com/antirez/kilo/blob/69c3ce609d1e8df3956cba6db3d296a7cf3af3de/kilo.c#L226-L239>
        /* input modes: no break, no CR to NL, no parity check, no strip char,
         * no start/stop output control. */
        // new_termios.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
        /* output modes - disable post processing */
        // new_termios.c_oflag &= ~(OPOST);
        /* control modes - set 8 bit chars */
        // new_termios.c_cflag |= (CS8);
        /* local modes - choing off, canonical off, no extended functions,
         * no signal chars (^Z,^C) */
        // new_termios.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
        // ~ECHO: don't display characters being typed
        // ~ICANON: not sure what else but also disables input bufferring by line
        new_termios.c_lflag &= ~(ECHO | ICANON);
        /* control chars - set return condition: min number of bytes and timer. */
        new_termios.c_cc[VMIN] = 0; /* Return each byte, or zero for timeout. */
        new_termios.c_cc[VTIME] = 1; /* 100 ms timeout (unit is tens of second). */

        rc = tcsetattr(STDIN_FILENO, TCSADRAIN, *new_termios);
        assert(rc == 0);
    }

    // Make stdin non blocking
    {
        flags := fcntl(STDIN_FILENO, F_GETFL);
        flags |= O_NONBLOCK;
        rc := fcntl(STDIN_FILENO, F_SETFL, flags);
        assert(rc != -1);
    }

    // Setup epoll
    state.epoll_fd = epoll_create(1);
    assert(state.epoll_fd != -1);
    state.epoll_events[0].events = EPOLLIN;
    rc = epoll_ctl(state.epoll_fd, .ADD, STDIN_FILENO, state.epoll_events.data);
    assert(rc == 0);

    while !should_exit {
        using state;

        // Wait for events
        rc := epoll_wait(epoll_fd, epoll_events.data, epoll_events.count, 1000 / 10);
        if rc == -1 {
            assert(errno() == EINTR);
        }

        input_received_this_tick = false;
        if rc == 1 {
            assert(epoll_events[0].data.fd == STDIN_FILENO);

            input_buffer_count = read(STDIN_FILENO, input_buffer.data, xx input_buffer.count);
            input_received_this_tick = true;
        }

        if window_size_changed {
            window_size_changed = false;

            // Get terminal size
            rc := ioctl(STDIN_FILENO, TIOCGWINSZ, *state.terminal_size);

            // `- 2` for 2 status lines
            state.rows_to_display_count = state.terminal_size.rows - 2;
        }

        // Run command if needed
        time := seconds_since_init();
        if time >= time_next_command_run {
            if last_command_output {
                free(last_command_output);
            }
            t0 := time;
            last_command_result, last_command_output = my_run_command(..command, capture_and_return_output = true);
            elapsed := seconds_since_init() - t0;
            // TODO: ps-pane is super slow, investigate
            // TODO: also I don't see these logs, am I stupid??
            log("executing % took % seconds", command, elapsed);
            if elapsed > 0.5 {
                log("executing % took % seconds", command, elapsed);
            }
            time_next_command_run = time + command_run_period_seconds;

            cursor := 0;
            last_command_output_line_count = 0;
            last_command_output_max_line_length = 0;
            line_end := 0;
            last_empty_lines_count := 0;
            tail := last_command_output;
            while !should_exit {
                found:, line:, tail = split_from_left(tail, #char "\n");

                last_command_output_line_count += 1;
                last_command_output_max_line_length = max(last_command_output_max_line_length, line.count);

                if line.count == 0 then last_empty_lines_count += 1; else last_empty_lines_count = 0;

                if !found break;
            }

            last_command_output_line_count -= last_empty_lines_count;
        }

        // Handle input
        if input_received_this_tick {
            for 0..input_buffer_count-1 {
                input_handle_character(input_buffer[it]);
            }
        }

        if stick_to_the_bottom {
            row_offset = max(row_offset, last_command_output_line_count - rows_to_display_count);
        }

        //
        // Status line
        //
        status_lines_builder: String_Builder;
        status_lines_builder.allocator = temp;

        // first line
        {
            // "\e[H": move cursor to "home" position (row 0, column 0)
            append(*status_lines_builder, "\e[H");

            // "\e[0J": erase from cursor to end of screen
            // append(*status_lines_builder, "\e[0J");

            // "\e[K": erase in line
            append(*status_lines_builder, "\e[K");

            append(*status_lines_builder, "\e[35m");
            append(*status_lines_builder, "$(");
            append(*status_lines_builder, "\e[0m");
            for command {
                if it_index == 0 then append(*status_lines_builder, "\e[32m");
                append(*status_lines_builder, it);
                if it_index == 0 then append(*status_lines_builder, "\e[0m");
                if it_index != command.count - 1 then append(*status_lines_builder, " ");
            }
            append(*status_lines_builder, "\e[35m");
            append(*status_lines_builder, ")");
            append(*status_lines_builder, "\e[0m");
            if last_command_result.exit_code != 0 {
                append(*status_lines_builder, " -> %", last_command_result.exit_code);
                // TODO: display stderr also in this case
            }
            append(*status_lines_builder, "\n");
        }

        // second line
        {
            // "\e[K": erase in line
            append(*status_lines_builder, "\e[K");
            append(*status_lines_builder, "\e[2;37m"); // color gray
            print_to_builder(*status_lines_builder, "offset: %, %   ", row_offset, col_offset);
            print_to_builder(*status_lines_builder, "lines: %   ", last_command_output_line_count);
            if stick_to_the_bottom then append(*status_lines_builder, "sinking   ");

            // Print current input buffer
            append(*status_lines_builder, "input: ");

            input_string: string;
            input_string.data = input_buffer.data;
            input_string.count = input_buffer_count;
            print_to_builder(*status_lines_builder, "%", cast(Ascii_Or_Hex) input_string);

            append(*status_lines_builder, "\e[0m");
            append(*status_lines_builder, "\n");
        }

        write_builder(*status_lines_builder,, temp);

        //
        // Main window
        //

        // `line_buffer` stores pointers into `last_command_output` or temporary storage
        line_buffer := NewArray(rows_to_display_count, string,, temp);

        tail := last_command_output;
        i := 0;
        if row_offset > 0 {
            // Skip `row_offset` lines
            for 1..row_offset {
                _, _, tail = split_from_left(tail, #char "\n");
            }
        } else if row_offset < 0 {
            // Extra blank lines for negative row_offset (for some reason)
            for 1..-row_offset {
                line_buffer[i] = "\n";   i += 1;
            }
        }

        // Preprocess lines to be displayed
        // TODO: tabs aren't handled correctly yet,
        // terminal displays them with different widths, but I count them as 1 always
        if line_buffer.count != 0 while i < line_buffer.count {
            found:, line:, tail = split_from_left(tail, #char "\n");

            memory_pool: Allocator;
            memory_pool.proc = flat_pool_allocator_proc;
            memory_pool.data = *memory_pool_for_building_a_line;

            builder: String_Builder;
            builder.allocator = memory_pool;
            ensure_contiguous_space(*builder, line.count);

            if !line_wrapping {
                visible_columns_budget : int = terminal_size.cols;
                line_tail := line;

                if col_offset > 0 {
                    visible_columns_budget -= 1; // :line_overflow_character
                    control_codes_builder: String_Builder;
                    control_codes_builder.allocator = temp;

                    // Skip `col_offset` visible characters `+ 1` for the :line_overflow_character
                    visible_to_skip := col_offset + 1;
                    while line_tail {
                        head:, visible_count:, line_tail = eat_visible_or_escape_sequence(line_tail);

                        if visible_count == 0 {
                            if is_mode_reset_control_sequence(head) {
                                reset(*control_codes_builder);
                            } else {
                                append(*control_codes_builder, head);
                            }
                        }

                        visible_to_skip -= visible_count;
                        if visible_to_skip <= 0 {
                            overflow := -visible_to_skip;
                            line_tail.data -= overflow;
                            line_tail.count += overflow;
                            break;
                        }
                    }

                    started_control_codes := builder_to_string(*control_codes_builder,, memory_pool);

                    // :line_overflow_character
                    append(*builder, "\e[2;37m"); // color gray
                    append(*builder, "<");
                    append(*builder, "\e[0m");

                    append(*builder, started_control_codes);
                } else if col_offset < 0 {
                    // Extra spaces if offset is negative
                    assert(visible_columns_budget > -col_offset);
                    for 1..-col_offset {
                        append(*builder, " ");
                        visible_columns_budget -= 1;
                    }
                }

                line_visible_slice: string;
                line_visible_slice.data = line_tail.data;
                line_visible_slice.count = 0;

                line_overflowed := false;
                // Preprocess one line
                while line_tail {
                    head:, visible_count:, line_tail = eat_visible_or_escape_sequence(line_tail);
                    line_visible_slice.count += head.count;
                    visible_columns_budget -= visible_count;

                    if visible_columns_budget <= 0 {
                        overflow := -visible_columns_budget;
                        line_overflowed = overflow != 0;
                        line_visible_slice.count -= overflow;

                        // Leave space for the :line_overflow_character
                        assert(head.count > overflow + 1);
                        line_visible_slice.count -= 1;
                        break;
                    }

                    // Special case of escape sequence starting on the last
                    // column of the would be row. Skip it here so that the `if`
                    // above works correctly :line_overflow_character
                    if visible_columns_budget == 1 && line_tail.count > 0 {
                        line_overflowed = true;
                        break;
                    }
                }

                // Build the line string
                append(*builder, line_visible_slice);

                // Reset color codes
                append(*builder, "\e[0m");

                // :line_overflow_character
                if line_overflowed {
                    append(*builder, "\e[2;37m"); // color gray
                    append(*builder, ">");
                    append(*builder, "\e[0m");
                }

                if i != line_buffer.count - 1 {
                    append(*builder, "\n");
                }
                line_buffer[i] = builder_to_string(*builder,, temp); i += 1;
            } else {
                // col_offset is ignored

                line_tail := line;
                first := true;

                // Iterate over line pieces
                while line_tail && i < line_buffer.count {
                    defer first = false;
                    visible_columns_budget : int = terminal_size.cols;

                    if !first {
                        prefix :: "";
                        append(*builder, prefix);
                        visible_columns_budget -= prefix.count;
                    } else {
                        first = false;
                    }

                    line_visible_slice: string;
                    line_visible_slice.data = line_tail.data;
                    line_visible_slice.count = 0;

                    // Preprocess one line piece
                    while line_tail {
                        head:, visible_count:, line_tail = eat_visible_or_escape_sequence(line_tail);
                        line_visible_slice.count += head.count;
                        visible_columns_budget -= visible_count;

                        if visible_columns_budget > 0 continue;

                        overflow := -visible_columns_budget;
                        line_visible_slice.count -= overflow;
                        line_tail.data -= overflow;
                        line_tail.count += overflow;

                        break;
                    }

                    // Build the line string
                    append(*builder, line_visible_slice);

                    // Reset color codes
                    append(*builder, "\e[0m");

                    if i != line_buffer.count - 1 {
                        append(*builder, "\n");
                    }
                    line_buffer[i] = builder_to_string(*builder,, temp); i += 1;
                }
            }

            if !found break; // last line
        }

        changed := false;
        if line_buffer.count != last_shown_line_buffer.count {
            changed = true;
        } else {
            for 0..line_buffer.count-1 {
                if last_shown_line_buffer[it] != line_buffer[it] {
                    changed = true;
                    break;
                }
            }
        }
        if changed {
            write_string("\e[0J");
            write_strings(..line_buffer);

            // Save last shown line buffer
            memory_pool_allocator: Allocator;
            memory_pool_allocator.proc = flat_pool_allocator_proc;
            memory_pool_allocator.data = *memory_pool_for_last_shown_line_buffer;

            reset(*memory_pool_for_last_shown_line_buffer);
            last_shown_line_buffer.allocator = memory_pool_allocator;
            array_reset(*last_shown_line_buffer);

            array_reserve(*last_shown_line_buffer, line_buffer.count);
            for line_buffer {
                line := copy_string(it,, memory_pool_allocator);
                array_add(*last_shown_line_buffer, line);
            }
        }

        if should_exit break;

        reset_temporary_storage();
    }

    // Restore terminal state
    {
        // "\e[?1049l": disable the alternative buffer
        // "\e[?25h": unhide cursor
        write_strings("\e[?1049l", "\e[?25h");

        tcsetattr(STDIN_FILENO, TCSADRAIN, *state.saved_termios);
    }

    if signalled_with_signal != -1 {
        print("got signal %\n", signalled_with_signal);
    }
}

//
// my_run_command
//

my_run_command :: (args: .. string, working_directory := "", capture_and_return_output := false, print_captured_output := false, timeout_ms := -1, arg_quoting := Process_Argument_Quoting.QUOTE_IF_NEEDED) -> (process_result: Process_Result, output_string := "", error_string := "", timeout_reached := false) {
    process: Process;
    success := create_process(*process, .. args, working_directory, capture_and_return_output, arg_quoting);

    close(process.input.handle);
    process.input.handle = -1;

    if !success    return .{type = .FAILED_TO_LAUNCH};

    defer deinit(*process);

    output_string: string;
    error_string : string;
    timeout_reached: bool;

    exit_timeout_ms := timeout_ms;
    if capture_and_return_output {
        output_builder: String_Builder;
        init_string_builder(*output_builder);
        error_builder : String_Builder;
        init_string_builder(*error_builder);

        start_time := current_time_monotonic();
        remaining_timeout_ms := timeout_ms;

        while true {
            output_buffer := ensure_contiguous_space_and_return_available_range(*output_builder);
            error_buffer := ensure_contiguous_space_and_return_available_range(*error_builder);
            success, output_bytes, error_bytes := read_from_process(*process, output_buffer, error_buffer, remaining_timeout_ms);

            if output_bytes {
                advance_through_ensured_space(*output_builder, output_bytes);
                if print_captured_output {
                    new_data := to_string(output_buffer.data, output_bytes);
                    write_string(new_data, to_standard_error = false);
                }
            }
            if error_bytes {
                advance_through_ensured_space(*error_builder, error_bytes);
                if print_captured_output {
                    new_data := to_string(error_buffer.data, error_bytes);
                    write_string(new_data, to_standard_error = true);
                }
            }

            if !success {
                log_error("Could not read output of command \"%\"", get_quoted_command_string(args,, temp));
                kill_process(*process);
                break;
            }

            if timeout_ms >= 0 {
                now := current_time_monotonic();
                remaining_timeout_ms = timeout_ms - to_milliseconds(now - start_time);

                if remaining_timeout_ms <= 0 {
                    // We’ve hit a timeout! Time to kill the child. (will be reaped below)
                    timeout_reached = true;
                    success := kill_process(*process);
                    if !success {
                        error_code, error_string := System.get_error_value_and_string();
                        log_error("Could not kill child for command \"%\": % %", get_quoted_command_string(args,, temp), error_code, error_string);
                    }
                    break;
                }
            }

            if process.output.eof && process.error.eof    break;
        }

        output_string = builder_to_string(*output_builder);
        error_string  = builder_to_string(*error_builder);
        exit_timeout_ms = -1;
    }

    process_result: Process_Result;
    exit_code: s32;
    while true {
        success, process_result = get_process_result(*process, exit_timeout_ms);
        if !success {
            error_code, error_string := System.get_error_value_and_string();
            log_error("Could not get process result for command \"%\": % %", get_quoted_command_string(args,, temp), error_code, error_string);
            kill_process(*process);
            process_result = .{type = .EXITED, exit_code = 1};
            break;
        }

        if process_result.type != .STILL_RUNNING     break;

        assert(exit_timeout_ms >= 0);
        exit_timeout_ms = -1;
        timeout_reached = true;
        // Kill process and then try to reap it again
        success = kill_process(*process);
        if !success {
            error_code, error_string := System.get_error_value_and_string();
            log_error("Could not kill child for command \"%\": % %", get_quoted_command_string(args,, temp), error_code, error_string);
            process_result = .{type = .EXITED, exit_code = 1};
            break;
        }
    }

    return process_result, output_string, error_string, timeout_reached;
}

//
// input handling
//

input_handle_character :: (char: u8) {
    using context.state;

    if input_mode == {
        case .NAVIGATE;
            if char == {
                case #char "j"; row_offset += 1;
                case #char "k"; row_offset -= 1; stick_to_the_bottom = false;

                case #char "d"; row_offset += terminal_size.rows / 2;
                case #char "u"; row_offset -= terminal_size.rows / 2; stick_to_the_bottom = false;

                case #char "t"; stick_to_the_bottom = !stick_to_the_bottom;

                case #char "w"; line_wrapping = !line_wrapping;

                case #char "g"; row_offset = 0; stick_to_the_bottom = false;
                case #char "G"; {
                    row_offset = last_command_output_line_count - rows_to_display_count;
                    stick_to_the_bottom = true;
                }

                case #char "0"; col_offset = 0;

                case #char "h"; if !line_wrapping col_offset -= 4;
                case #char "l"; if !line_wrapping col_offset += 4;

                case #char "H"; if !line_wrapping col_offset -= terminal_size.cols / 2;
                case #char "L"; if !line_wrapping col_offset += terminal_size.cols / 2;

                case #char "q"; should_exit = true;
            }

            row_offset = max(row_offset, -(rows_to_display_count - 1));
            row_offset = min(row_offset, last_command_output_line_count - 1);

            col_offset = max(col_offset, -(cast(int) terminal_size.cols - 1));
            col_offset = min(col_offset, last_command_output_max_line_length - 1);
    }
}

//
// logging
//

my_logger :: (message: string, data: *void, info: Log_Info) {
    state := cast(*State) data;
    if !state.log_file.handle return;

    file_write(*state.log_file, message);
    file_write(*state.log_file, "\n");
    fflush(state.log_file.handle);
}
fflush :: (handle: *FILE) -> s32 #foreign libc;

//
// string utilities
//

Ascii_Or_Hex :: #type,distinct string;

ascii_or_hex_printer :: (builder: *String_Builder, any: Any, struct_printer_data: *void) -> bool {
    if any.type != type_info(Ascii_Or_Hex) return false;

    s := << cast(*string) any.value_pointer;
    for 0..s.count - 1 {
        print_ascii_or_hex(builder, s[it]);
    }

    return true;
}

NOT_SPECIFIED :: 0x7fff_ffff_ffff_ffff;
substring :: inline (s: string, start := 0, end := NOT_SPECIFIED, count := NOT_SPECIFIED) -> string {
    _count := count;
    _start := ifx start < 0 then s.count + start else start;
    if end == NOT_SPECIFIED && count == NOT_SPECIFIED {
        _count = s.count - _start;
    } else {
        assert(end == NOT_SPECIFIED || count == NOT_SPECIFIED);
        _end := ifx end < 0 then s.count + end else end;
        if count == NOT_SPECIFIED then _count = _end - _start;
    }
    assert(_start >= 0, "start: %, end: %, count: %", start, end, count);
    assert(_start <= s.count, "start: %, end: %, count: %", start, end, count);
    assert(_count >= 0, "start: %, end: %, count: %", start, end, count);
    assert(_start + _count <= s.count, "start: %, end: %, count: %", start, end, count);

    return string.{ data = s.data + _start, count = _count };
}

is_mode_reset_control_sequence :: inline (s: string) -> bool {
    if substring(s, count=2) != "\e[" return false;
    if substring(s, -1) != "m" return false;
    if s.count == 3 return true;

    for 0..(s.count-1)-3
        if s[2 + it] != #char "0"
            return false;

    return true;
}

eat_visible_or_escape_sequence :: (text: string) -> head: string, visible_count: s64, tail: string {
    if !text return "", 0, "";

    char: u8;
    count := 0;

    while count < text.count {
        char = text[count];
        if char == #char "\e" break;

        count += 1;
    }
    if count > 0 {
        // Visible character sequence
        head := substring(text, 0, count = count);
        tail := substring(text, count);
        return head, count, tail;
    }

    // Escape sequence
    count += 1;

    while count < text.count {
        char = text[count];

        if char == {
            case #char "[";
                count += 1;

                while count < text.count {
                    char = text[count];
                    count += 1;

                    if char == #char "m" break;
                }
            case;
                break;
        }
    }

    head := substring(text, 0, count = count);
    tail := substring(text, count);
    return head, 0, tail;
}

print_ascii_or_hex :: inline (builder: *String_Builder, char: u8) {
    if char >= #char " " && char <= #char "~" {
        if char == #char "\\" || char == #char "\""
            append(builder, "\\");
        append(builder, char);
    } else {
        print_to_builder(builder, "\\x%", FormatInt.{ value = char, base = 16, minimum_digits = 2 });
    }
}

//
// signal handling
//

should_exit := false;
signalled_with_signal := -1;
shutdown_signal_handler :: (signal: s32) #c_call #no_context {
    should_exit = true;
    signalled_with_signal = signal;
}

window_size_changed := false;
window_size_changed_signal_handler :: (signal: s32) #c_call #no_context {
    window_size_changed = true;
}

libc :: #system_library "libc";
Signal_Handler :: #type (s32) -> void #c_call #no_context;
signal :: (signal: s32, handler: Signal_Handler) #foreign libc;

//
// terminfo
//

TIOCGWINSZ :: 0x5413;

Terminal_Size_Info :: struct {
    rows: u16;
    cols: u16;
    xpixel: u16;
    ypixel: u16;
}

//
// termios
//

Termios :: struct {
    c_iflag: u32;
    c_oflag: u32;
    c_cflag: u32;
    c_lflag: u32;
    c_line: u8;
    c_cc: [32] u8;
    c_ispeed: u32;
    c_ospeed: u32;
    // Just in case there's more stuff I don't know about
    padding: [64] u8;
}

TCSANOW :: 0;
TCSADRAIN :: 1;
TCSAFLUSH :: 2;

BRKINT : u32 : 0x00000002;
INPCK  : u32 : 0x00000010;
ISTRIP : u32 : 0x00000020;
ICRNL  : u32 : 0x00000100;
OPOST  : u32 : 0x1;
ECHO   : u32 : 0x00000008;
IXON   : u32 : 0x00000400;
CS8    : u32 : 0x00000030;
ISIG   : u32 : 0x00000001;
ICANON : u32 : 0x00000002;
IEXTEN : u32 : 0x00008000;
VTIME  : u32 : 5;
VMIN   : u32 : 6;

tcgetattr :: (fd: s32, termios: *Termios) -> s32 #foreign libc;
tcsetattr :: (fd: s32, optional_actions: s32, termios: *Termios) -> s32 #foreign libc;

#import "Basic";
#import "Process";
#import "String";
#import "POSIX";
#import "File";
#import "Flat_Pool";
System :: #import "System";
