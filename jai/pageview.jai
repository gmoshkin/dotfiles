#run {
    #import "Compiler";
    set_build_options_dc(.{ output_executable_name = "pageview" });
}

State :: struct {
    row_offset: s64;
    col_offset: s64;

    terminal_size: Terminal_Size_Info;

    input_buffer: [32] u8;
    input_buffer_count: s64;
    input_received_this_tick: bool;

    command: [] string;

    command_run_period_seconds := 1.0;
    time_next_command_run : float64 = -1.0;

    last_command_output: string;
    last_command_output_line_count: s64;
    last_command_result: Process_Result;

    saved_termios: Termios;

    epoll_fd: s32;
    epoll_events: [1] epoll_event;
}

main :: () {
    args := get_command_line_arguments();
    if args.count == 1 {
        print("Need a command to run\n");
        return;
    }

    state: State;

    state.command.data = args.data + 1;
    state.command.count = args.count - 1;

    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    // Get terminal size
    rc := ioctl(STDIN_FILENO, TIOCGWINSZ, *state.terminal_size);

    // Hide cursor, disable echo, etc.
    {
        write_string("\e[?1049h");

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
        assert(rc != -1);
        input_received_this_tick = false;
        if rc == 1 {
            assert(epoll_events[0].data.fd == STDIN_FILENO);

            input_buffer_count = read(STDIN_FILENO, input_buffer.data, xx input_buffer.count);
            input_received_this_tick = true;
        }

        // Run command if needed
        time := seconds_since_init();
        if time >= time_next_command_run {
            if last_command_output free(last_command_output);
            last_command_result, last_command_output = my_run_command(..command, capture_and_return_output = true);
            time_next_command_run = time + command_run_period_seconds;

            cursor := 0;
            last_command_output_line_count = 0;
            line_end := 0;
            last_empty_lines_count := 0;
            while !should_exit {
                line_end = find_index_from_left(last_command_output, #char "\n", cursor);
                if line_end == -1 break;
                last_command_output_line_count += 1;

                if line_end == cursor then last_empty_lines_count += 1; else last_empty_lines_count = 0;

                cursor = line_end + 1;
            }

            last_command_output_line_count -= last_empty_lines_count;
        }

        // 2 lines already printed
        rows_to_display_count : s64 = terminal_size.rows - 2;

        // Handle input
        if input_received_this_tick {
            for 0..input_buffer_count-1 {
                if input_buffer[it] == {
                    case #char "j"; row_offset += 1;
                    case #char "k"; row_offset -= 1;

                    case #char "d"; row_offset += terminal_size.rows / 2;
                    case #char "u"; row_offset -= terminal_size.rows / 2;

                    case #char "g"; row_offset = 0;
                    case #char "G"; row_offset = last_command_output_line_count - rows_to_display_count;

                    case #char "h"; col_offset -= 1;
                    case #char "l"; col_offset += 1;
                    case #char "q"; should_exit = true;
                }

                row_offset = max(row_offset, -(rows_to_display_count - 1));
                row_offset = min(row_offset, last_command_output_line_count - 1);
            }
        }

        write_strings("\e[H", "\e[0J", "\e[?25l");
        print("% -> %\n", command, last_command_result.exit_code);

        //
        // Status line
        //
        print("row_ofs: %   ", row_offset);
        print("lines: %   ", last_command_output_line_count);

        // Print current input buffer
        write_string("input: ");
        {
            i := 0;
            while i < input_buffer_count {
                end := i;
                while end < input_buffer_count && input_buffer[end] >= #char " " && input_buffer[end] <= #char "~" {
                    end += 1;
                }
                if end > i {
                    // Printable ascii
                    s: string;
                    s.data = input_buffer.data + i;
                    s.count = end - i;
                    write_string(s);
                    i = end;
                }
                if i >= input_buffer_count break;

                print("\\x%", FormatInt.{ value = input_buffer[i], base = 16, minimum_digits = 2 });
                i += 1;
            }
        }
        write_string("\n");

        // * 2 for "\n"
        line_buffer := NewArray(rows_to_display_count * 2, string,, temp);

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
                line_buffer[i] = "";   i += 1;
                line_buffer[i] = "\n"; i += 1;
            }
        }

        //
        // Preprocess lines to be displayed
        //
        if line_buffer.count != 0 while i < line_buffer.count {
            found:, line:, tail = split_from_left(tail, #char "\n");

            actual_characters_count := 0;
            visible_columns_count := 0;
            // Preprocess one line
            while actual_characters_count < line.count {
                char := line[actual_characters_count];
                if char == #char "\e" {
                    actual_characters_count += 1;

                    while actual_characters_count < line.count {
                        char = line[actual_characters_count];
                        if char == {
                            case #char "[";
                                actual_characters_count += 1;
                                while actual_characters_count < line.count {
                                    char = line[actual_characters_count];
                                    actual_characters_count += 1;
                                    if char != #char "m" break;
                                }
                            case; break;
                        }
                    }
                } else {
                    actual_characters_count += 1;
                    visible_columns_count += 1;
                }

                if visible_columns_count >= terminal_size.cols break;
            }
            line.count = actual_characters_count;

            line_buffer[i] = line; i += 1;
            line_buffer[i] = "\e[m\n"; i += 1;

            if !found break; // last line
        }
        // don't print the last "\n"
        line_buffer.count -= 1;
        write_strings(..line_buffer);

        if should_exit break;

        reset_temporary_storage();
    }

    // Restore terminal state
    {
        write_strings("\e[?1049l", "\e[?25h");

        tcsetattr(STDIN_FILENO, TCSADRAIN, *state.saved_termios);
    }

    // Print output one last time
    print("% -> %\n", state.command, state.last_command_result.exit_code);
    print("\n");
    tail := state.last_command_output;
    i := 0;
    while true {
        found:, line:, tail = split_from_left(tail, #char "\n");
        write_strings(line, "\n");

        i += 1;
        if i >= state.terminal_size.rows - 2 break;

        if !found break;
    }

    if should_exit {
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
// string utilities
//

//
// signal handling
//

should_exit := false;
signalled_with_signal := 0;
signal_handler :: (signal: s32) #c_call #no_context {
    should_exit = true;
    signalled_with_signal = signal;
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
System :: #import "System";
