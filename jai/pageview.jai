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
    strip_control_codes := false;

    main_window_height: s64;
    terminal_size: Terminal_Size_Info;

    //
    // input
    //

    input_mode: enum { NAVIGATE; INPUT_SEARCH_STRING; } = .NAVIGATE;
    input_cursor: s64;
    search_string_buffer: [..] u8;
    search_string: string; // this is always just the search_string_buffer converted to string

    input_buffer: [32] u8;
    input_buffer_count: s64;
    input_received_this_tick: bool;

    //
    // logging
    //

    log_file_name: string;
    log_file: File;
    log_file.handle = null;

    error_log_builder: String_Builder;

    //
    // command
    //

    command: [] string;

    command_run_period_seconds := 1.0;
    time_next_command_run : float64 = -1.0;
    last_command_result: Process_Result;

    main_window_buffer: Window_Buffer;

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
#add_context current_window: *Window_Buffer;

Window_Buffer :: struct {
    raw_text_and_control_codes: string;

    only_text_storage: [..] u8; // allocated separately
    only_text: string; // points into `only_text_storage`

    control_codes: [..] Control_Code_Info; // offsets into `only_text`, data into `raw_text_and_control_codes`
    line_offsets: [..] s64; // offsets into `only_text`

    control_codes_cursor: s64;

    max_line_length: s64;
}

Control_Code_Info :: struct {
    position_in_text: s64;
    data: Ascii_Or_Hex; // points into `raw_text_and_control_codes`
}

main :: () {
    // Setup struct_printer
    context.print_style.struct_printer = ascii_or_hex_printer;

    // test_get_next_control_code_in_range();
    // return;

    args := get_command_line_arguments();
    if args.count == 1 {
        print("Need a command to run\n");
        return;
    }

    state := *context.state;
    context.current_window = *state.main_window_buffer;

    cursor := 1;
    while true {
        arg := args[cursor];
        if arg == {
            case "-f"; #through;
            case "--follow";
                state.stick_to_the_bottom = true;

            case "-t"; #through;
            case "--time"; #through;
            case "--time-before-repeat";
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

    if state.command.count == 0 {
        print("Need a command to run\n");
        exit(1);
    }

    // Setup logger
    state.error_log_builder.allocator = temp;
    if state.log_file_name {
        log_file, ok := file_open(state.log_file_name, for_writing = true, keep_existing_content = true);
        assert(ok);
        state.log_file = log_file;
    }
    context.logger = my_logger;
    context.logger_data = *context.state;

    signal(SIGINT, shutdown_signal_handler);
    signal(SIGTERM, shutdown_signal_handler);
    signal(SIGWINCH, window_size_changed_signal_handler);

    // Get terminal size
    rc := ioctl(STDIN_FILENO, TIOCGWINSZ, *state.terminal_size);

    // `- 2` for 2 status lines
    state.main_window_height = state.terminal_size.rows - 2;

    // Hide cursor, disable echo, etc.
    {
        context.assertion_failed = (loc: Source_Code_Location, message: string) -> bool {
            restore_terminal_settings();
            return runtime_support_assertion_failed(loc, message);
        };

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
        reset(*error_log_builder);

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
            state.main_window_height = state.terminal_size.rows - 2;
        }

        // Run command if needed
        time := seconds_since_init();
        if time >= time_next_command_run {
            using main_window_buffer;

            if raw_text_and_control_codes free(raw_text_and_control_codes);

            t0 := time;
            last_command_result, raw_text_and_control_codes = my_run_command(..command, capture_and_return_output = true);
            elapsed := seconds_since_init() - t0;
            // TODO: also I don't see these logs, am I stupid??
            if elapsed > 0.5 {
                log("executing % took % seconds", command, elapsed);
            }
            time_next_command_run = time + command_run_period_seconds;

            if last_command_result.type == .FAILED_TO_LAUNCH {
                free(raw_text_and_control_codes);
                prefix :: "\e[31m";
                raw_text_and_control_codes = builder_to_string(*error_log_builder, extra_bytes_to_prepend=prefix.count);
                memcpy(raw_text_and_control_codes.data, prefix.data, prefix.count);
            }

            separate_control_codes(raw_text_and_control_codes);
        }

        // Handle input
        if input_received_this_tick {
            for 0..input_buffer_count-1 {
                input_handle_character(input_buffer[it]);
            }
        }

        if stick_to_the_bottom {
            row_offset = max(row_offset, main_window_buffer.line_offsets.count - main_window_height);
        }

        //
        // Status line
        //
        {
            builder: String_Builder;
            builder.allocator = temp;

            // first line
            {
                // hide the cursor, so it doesn't flicker all around the screen
                // while the ui is being drawn
                append(*builder, "\e[?25l");

                // "\e[H": move cursor to "home" position (row 0, column 0)
                append(*builder, "\e[H");

                // "\e[0J": erase from cursor to end of screen
                // append(*builder, "\e[0J");

                // "\e[K": erase in line
                append(*builder, "\e[K");

                append(*builder, "\e[35m");
                append(*builder, "$(");
                append(*builder, "\e[0m");

                append(*builder, "\e[32m");
                append(*builder, command[0]);
                append(*builder, "\e[0m");

                for 1..command.count-1 {
                    append(*builder, " ");
                    append(*builder, command[it]);
                }

                append(*builder, "\e[35m");
                append(*builder, ")");
                append(*builder, "\e[0m");
                if last_command_result.exit_code != 0 {
                    append(*builder, " -> %", last_command_result.exit_code);
                    // TODO: display stderr also in this case
                }
                append(*builder, "\n");
            }

            // second line is drawn at the end
            append(*builder, "\n");

            write_builder(*builder);
        }

        //
        // Main window
        //

        using main_window_buffer;

        // `line_buffer` stores pointers into `main_window_buffer` or temporary storage
        line_buffer: [..] string;
        line_buffer.allocator = temp;
        array_reserve(*line_buffer, main_window_height);

        tail := only_text;
        line_index := 0;
        if row_offset > 0 {
            line_index = row_offset;
        } else if row_offset < 0 {
            // Extra blank lines for negative row_offset (for some reason)
            for 1..-row_offset {
                array_add(*line_buffer, "\n");
            }
        }

        // these are used and reused for each line
        codes: [..] Control_Code_Info;
        codes.allocator = temp;
        search_matches: [..] Pointer_Range;
        search_matches.allocator = temp;

        // Preprocess lines to be displayed
        // TODO: tabs aren't handled correctly yet,
        // terminal displays them with different widths, but I count them as 1 always
        if main_window_height != 0 while line_buffer.count < main_window_height {
            if line_index >= line_offsets.count - 1 break;
            line_start := line_offsets[line_index];
            line_end := ifx line_index < line_offsets.count - 1 then line_offsets[line_index + 1] else only_text.count;
            line_index += 1;
            line := substring(xx only_text, line_start, line_end);

            // :search_string_highlight
            search_matches.count = 0;
            // TODO: is the line is super fucking long this will be slow, so I
            // could test for that and do something else in that case
            if search_string {
                // find all matches in current line
                tail := line;
                while tail {
                    found:, head:, tail = split_from_left(tail, search_string);
                    if !found break;

                    start := head.data + head.count;
                    end := start + search_string.count;
                    array_add(*search_matches, .{ start, end });
                }
            }
            search_matches_tail: [] Pointer_Range = search_matches;

            memory_pool := Allocator.{ flat_pool_allocator_proc, *memory_pool_for_building_a_line };
            builder := String_Builder.{ allocator = memory_pool };
            ensure_contiguous_space(*builder, line.count);

            if !line_wrapping {
                visible_columns_budget : int = terminal_size.cols;
                visible_slice := line;
                truncated_string_match_end := 0; // :search_string_highlight

                if col_offset > 0 {
                    // Skip `col_offset` visible characters `+ 1` for the :line_overflow_character
                    first_visible_column_offset := min(col_offset + 1, line.count);
                    hidden_slice := substring(line, 0, first_visible_column_offset);
                    visible_slice = substring(line, first_visible_column_offset);

                    // :line_overflow_character
                    visible_columns_budget -= 1;
                    // :search_string_highlight
                    search_matched_in_hidden := false;
                    if search_string {
                        index := find_index_from_left(line, search_string);
                        search_matched_in_hidden = index >= 0 && index < first_visible_column_offset;
                    }
                    if search_matched_in_hidden then append(*builder, "\e[7m"); // invert color mode
                                                else append(*builder, "\e[2;37m"); // color gray
                    append(*builder, "<");
                    append(*builder, "\e[0m");

                    // add all control codes from the hidden part of the line
                    if !strip_control_codes {
                        codes := find_all_control_codes_in_range(hidden_slice);
                        for < codes {
                            // ignore everything before the last mode reset
                            if is_mode_reset_control_sequence(it.data) break;
                            append(*builder, it.data);
                        }
                    }
                } else if col_offset < 0 {
                    // Extra spaces if offset is negative
                    assert(visible_columns_budget > -col_offset);
                    for 1..-col_offset {
                        append(*builder, " ");
                        visible_columns_budget -= 1;
                    }
                }

                line_overflowed := visible_slice.count > visible_columns_budget;
                if line_overflowed {
                    // Leave space for the :line_overflow_character
                    visible_slice.count = visible_columns_budget - 1;
                }

                codes.count = 0;
                if !strip_control_codes {
                    array_add(*codes, ..find_all_control_codes_in_range(visible_slice));
                }

                // :search_string_highlight
                search_matched_in_hidden := false;
                if search_string {
                    tail := line;
                    while tail && !should_exit {
                        // FIXME: I'm a dumbass, optimizing for searching over
                        // large text segments, while vim just finds all matches
                        // in the file instantly and shows me their count. Just
                        // fucking find all matches when the text or search
                        // string changes, you retard.
                        index := find_index_from_left(tail, search_string);
                        if index < 0 break;
                        match_start := tail.data + index;
                        match_end := match_start + search_string.count;

                        tail = substring(tail, index + search_string.count);

                        if match_end <= visible_slice.data continue;

                        visible_end := visible_slice.data + visible_slice.count;
                        search_matched_in_hidden = match_end > visible_end;
                        if match_start >= visible_end break;

                        insert_control_code_range(*codes, match_start, "\e[7m", // invert color mode
                                                          match_end, "\e[27m"); // disable invert color mode
                    }
                }

                // Build the line string
                build_line_with_control_codes(*builder, visible_slice, codes);

                // Reset color codes
                append(*builder, "\e[0m");

                // :line_overflow_character
                if line_overflowed {
                    // :search_string_highlight
                    if search_matched_in_hidden {
                        append(*builder, "\e[7m"); // invert color mode
                    } else {
                        append(*builder, "\e[2;37m"); // color gray
                    }
                    append(*builder, ">");
                    append(*builder, "\e[0m");
                }

                if line_buffer.count != line_buffer.allocated - 1 {
                    append(*builder, "\n");
                }
                array_add(*line_buffer, builder_to_string(*builder,, temp));
            } else /* line_wrapping == true */ {
                // col_offset is ignored

                line_tail := line;
                first := true;

                // Iterate over line pieces
                while line_tail && line_buffer.count < main_window_height {
                    defer first = false;
                    visible_columns_budget : int = min(terminal_size.cols, xx line_tail.count);

                    if !first {
                        prefix :: "";
                        append(*builder, prefix);
                        visible_columns_budget -= prefix.count;
                    } else {
                        first = false;
                    }

                    current_slice := substring(line_tail, 0, visible_columns_budget);
                    current_slice_end := current_slice.data + current_slice.count;
                    line_tail = substring(line_tail, visible_columns_budget);

                    codes.count = 0;
                    if !strip_control_codes {
                        array_add(*codes, ..find_all_control_codes_in_range(current_slice));
                    }

                    // :search_string_highlight
                    while search_matches_tail {
                        match := *search_matches_tail[0];

                        start_in_range := match.start >= current_slice.data && match.start < current_slice_end;
                        end_in_range := match.end > current_slice.data && match.end <= current_slice_end;
                        if start_in_range || end_in_range {
                            insert_control_code_range(*codes, match.start, "\e[7m", // invert color mode
                                                              match.end, "\e[27m"); // disable invert color mode
                        }

                        if !start_in_range || !end_in_range break; // leave that match for the next line piece

                        advance(*search_matches_tail, 1);
                    }

                    // Build the line string
                    build_line_with_control_codes(*builder, current_slice, codes);

                    if line_buffer.count != line_buffer.allocated - 1 {
                        append(*builder, "\n");
                    } else {
                        // Reset color codes
                        append(*builder, "\e[0m");
                    }
                    array_add(*line_buffer, builder_to_string(*builder,, temp));
                }
            }
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

        //
        // second status line
        //
        {
            builder: String_Builder;
            builder.allocator = temp;
            buffer := get_base_buffer(*builder);

            // "\e[H": move cursor to position (row 2, column 1)
            append(*builder, "\e[2;1H");
            append(*builder, "\e[K"); // "\e[K": erase in line
            append(*builder, "\e[2;37m"); // color gray

            if input_mode == .NAVIGATE {
                text_start := buffer.count;
                {
                    print_to_builder(*builder, "offset: %, %   ", row_offset, col_offset);
                    print_to_builder(*builder, "lines: %   ", main_window_buffer.line_offsets.count);
                    if stick_to_the_bottom then append(*builder, "sinking   ");

                    // Print current input buffer
                    append(*builder, "input: ");

                    input_string: string;
                    input_string.data = input_buffer.data;
                    input_string.count = input_buffer_count;
                    print_to_builder(*builder, "%", cast(Ascii_Or_Hex) input_string);

                    // print(*builder, "  control codes count %", main_window_buffer.control_codes.count);
                }
                text_length := buffer.count - text_start;
                overflow := text_length - terminal_size.cols;
                if overflow > 0 {
                    buffer.count -= overflow;
                }
            } else if input_mode == .INPUT_SEARCH_STRING {
                append(*builder, "/");

                // `- 1` for the leading `/`
                visible_columns_budget := terminal_size.cols - 1;

                cursor_column := 0;
                overflow := search_string.count - visible_columns_budget;
                // FIXME: I just want the last column to be left for the cursor
                // if the cursor is at the last column, but than be filled with
                // the search string otherwise... but I'm a sleepy head right
                // now :(
                if overflow > 0 {
                    // Add extra space at the end for the cursor
                    overflow += 1;
                    slice_start := clamp(input_cursor - 2, 0, overflow);
                    append(*builder, substring(search_string, slice_start, count=visible_columns_budget - 1));
                    // `+ 1` for the leading "/" & `+ 1` because rows start at 1
                    cursor_column = input_cursor - slice_start + 2;
                } else {
                    append(*builder, search_string);
                    // `+ 1` for the leading "/" & `+ 1` because rows start at 1
                    cursor_column = input_cursor + 2;
                }

                // move the cursor to where the user is editting text
                print(*builder, "\e[2;%H", cursor_column);
                // show the cursor, so user knows they're editing text
                append(*builder, "\e[?25h");
            }

            append(*builder, "\e[0m");

            assert(get_current_buffer(*builder) == buffer);
            write_builder(*builder);
        }

        if should_exit break;

        reset_temporary_storage();
    }

    // Restore terminal state
    restore_terminal_settings();

    if signalled_with_signal != -1 {
        print("got signal %\n", signalled_with_signal);
    }
}

//
// iterating over control codes
//

build_line_with_control_codes :: (builder: *String_Builder, text_slice: string, codes: [] Control_Code_Info) -> (num_codes_left: s64) {
    using context.current_window;

    if !codes.count {
        append(builder, text_slice);
        return 0;
    }

    start := text_slice.data - only_text.data;
    end := start + text_slice.count;

    cursor := start;
    for codes {
        position_clamped := clamp(it.position_in_text, start, end);
        append(builder, substring(only_text, cursor, position_clamped));
        if it.position_in_text > end return codes.count - it_index;

        append(builder, it.data);
        cursor = position_clamped;
    }
    if cursor < end
        append(builder, substring(only_text, cursor, end));

    return 0;
}

// FIXME: linear search. If I keep track of last inserted position and start
// searching from it, this should help with performance.
insert_control_code :: (codes: *[..] Control_Code_Info, pointer_into_only_text: *u8, data: string) {
    using context.current_window;
    assert(pointer_into_only_text > only_text.data);
    assert(pointer_into_only_text <= only_text.data + only_text.count);

    position_in_text := pointer_into_only_text - only_text.data;
    code := Control_Code_Info.{ position_in_text, xx data };

    index := 0;
    for codes.* {
        if it.position_in_text >= code.position_in_text break;

        index += 1;
    }

    array_insert_at(codes, code, index);
}

// FIXME: linear search. If I keep track of last inserted position and start
// searching from it, this should help with performance.
insert_control_code_range :: (codes: *[..] Control_Code_Info,
                              start_pointer: *u8, // points into only_text
                              start_code: string,
                              end_pointer: *u8, // points into only_text
                              end_code: string)
{
    // Empty range will always be invisible
    if start_pointer == end_pointer return;

    using context.current_window;
    assert(start_pointer > only_text.data);
    assert(start_pointer < end_pointer);
    assert(end_pointer <= only_text.data + only_text.count);

    start_position := start_pointer - only_text.data;
    start := Control_Code_Info.{ start_position, xx start_code };
    end_position := end_pointer - only_text.data;
    end := Control_Code_Info.{ end_position, xx end_code };

    index := 0;
    while index < codes.count {
        it := codes.*[index];

        if it.position_in_text > start.position_in_text break;
        if it.position_in_text == start.position_in_text {
            // Put new control code after the mode reset at the same position
            if !is_mode_reset_control_sequence(it.data) break;
        }

        index += 1;
    }

    array_insert_at(codes, start, index);

    index += 1;
    while index < codes.count {
        it := codes.*[index];

        if it.position_in_text > end.position_in_text break;
        // Found mode reset
        if is_mode_reset_control_sequence(it.data) {
            // Insert another start after the mode reset, because it just reset our previous start
            another_start := Control_Code_Info.{it.position_in_text, start.data};
            array_insert_at(codes, another_start, index + 1);
            // Don't need to check this newly inserted code
            index += 1;
        }

        index += 1;
    }

    array_insert_at(codes, end, index);
}

find_first_control_code_in_range :: (start: s64, end: s64) -> string {
    using context.current_window;

    if !control_codes return "";

    if control_codes_cursor > control_codes.count - 1
        control_codes_cursor = control_codes.count - 1;

    while control_codes[control_codes_cursor].position_in_text > start {
        if control_codes_cursor == 0 return "";
        control_codes_cursor -= 1;
    }

    while control_codes[control_codes_cursor].position_in_text < start {
        control_codes_cursor += 1;
        if control_codes_cursor == control_codes.count return "";
    }

    return control_codes[control_codes_cursor].data;
}

find_all_control_codes_in_range :: (start: s64, end: s64) -> ([] Control_Code_Info, total_string_length: s64) {
    using context.current_window;

    assert(start <= end);
    assert(0 <= start && start <= only_text.count);
    assert(0 <= end && end <= only_text.count);

    find_first_control_code_in_range(start, end);

    first := control_codes_cursor;
    total_string_length := 0;
    while true {
        code := current_control_code();
        if !control_code_is_in_range(code, start, end) break;
        total_string_length += code.data.count;
        control_codes_cursor += 1;
    }

    return array_view(control_codes, first, control_codes_cursor - first), total_string_length;
}

find_all_control_codes_in_range :: (range: string) -> ([] Control_Code_Info, total_string_length: s64) {
    using context.current_window;

    start := range.data - only_text.data;
    end := start + range.count;
    codes, total_string_length := inline find_all_control_codes_in_range(start, end);
    return codes, total_string_length;
}

control_code_is_in_range :: inline (code: Control_Code_Info, start: int, end: int) -> bool {
    if !code.data return false;
    if code.position_in_text < start return false;
    if code.position_in_text > end return false;

    return true;
}

current_control_code :: inline () -> Control_Code_Info {
    using context.current_window;

    if control_codes_cursor > control_codes.count - 1 return .{};
    return control_codes[control_codes_cursor];
}

test_get_next_control_code_in_range :: () {
    text := "foo\e[31mbar\e[32mbaz\e[33mboobies\e[0m";

    using window_buffer: Window_Buffer;
    context.current_window = *window_buffer;
    separate_control_codes(text);

    print_vars(raw_text_and_control_codes, only_text, control_codes);

    cursor: int;
    start: int;
    end: int;

    do_test :: (start: int, end: int) #expand {
        using context.current_window;

        builder: String_Builder;

        print("[%..%]:\n", start, end);
        print(*builder, "<", start, end);
        cursor := start;
        for code: find_all_control_codes_in_range(start, end) {
            print("%: %\n", code.position_in_text, cast(Ascii_Or_Hex) code.data);
            print(*builder, "%", substring(only_text, cursor, code.position_in_text));
            print(*builder, "%", code.data);
            cursor = code.position_in_text;
        }
        if cursor < end then print(*builder, "%", substring(only_text, cursor, end));
        print(*builder, "\e[0m>\n");

        write_builder(*builder);
    }

    do_test(0, only_text.count);
    do_test(0, only_text.count-1);
    do_test(2, 7);
    do_test(3, 7);
    do_test(2, 6);
    do_test(3, 6);
    do_test(4, 7);
}

separate_control_codes :: (raw_text: string) {
    using context.current_window;

    // `only_text.count <= raw_text_and_control_codes.count` is always true
    raw_text_and_control_codes = raw_text;

    array_reserve(*only_text_storage, raw_text_and_control_codes.count);
    only_text_storage.count = 0;
    line_offsets.count = 0;
    control_codes.count = 0;

    max_line_length = 0;
    last_empty_lines_count := 0;
    tail := raw_text_and_control_codes;
    while !should_exit {
        found:, line:, tail = split_from_left(tail, #char "\n");

        max_line_length = max(max_line_length, line.count);

        if line.count == 0 then last_empty_lines_count += 1; else last_empty_lines_count = 0;

        array_add(*line_offsets, only_text_storage.count);

        line_tail := line;
        while line_tail {
            head:, visible_count:, line_tail = eat_visible_or_escape_sequence(line_tail);

            if visible_count == 0 {
                array_add(*control_codes, .{ only_text_storage.count, xx head });
            } else {
                memcpy(only_text_storage.data + only_text_storage.count, head.data, head.count);
                only_text_storage.count += head.count;
            }
        }

        if !found break;
    }

    only_text = xx only_text_storage;
    line_offsets.count -= last_empty_lines_count;
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
                    // FIXME: now this is broken somehow
                    row_offset = main_window_buffer.line_offsets.count - main_window_height;
                    stick_to_the_bottom = true;
                }

                case #char "0"; col_offset = 0;

                case #char "h"; if !line_wrapping col_offset -= 4;
                case #char "l"; if !line_wrapping col_offset += 4;

                case #char "H"; if !line_wrapping col_offset -= terminal_size.cols / 2;
                case #char "L"; if !line_wrapping col_offset += terminal_size.cols / 2;

                case #char "/"; {
                    input_mode = .INPUT_SEARCH_STRING;
                    input_cursor = search_string_buffer.count;
                }

                case #char "n"; jump_to_next_search_match();
                case #char "N"; jump_to_previous_search_match();

                case #char "c"; strip_control_codes = !strip_control_codes;

                case #char "q"; should_exit = true;
            }

            row_offset = max(row_offset, -(main_window_height - 1));
            row_offset = min(row_offset, main_window_buffer.line_offsets.count - 1);

            col_offset = max(col_offset, -(cast(int) terminal_size.cols - 1));
            col_offset = min(col_offset, main_window_buffer.max_line_length - 1);
        case .INPUT_SEARCH_STRING;
            if char >= #char " " && char <= #char "~" {
                array_insert_at(*search_string_buffer, char, input_cursor);
                input_cursor += 1;
            } else if char == {
                case #char "\e"; /* ESCAPE */ input_mode = .NAVIGATE;
                case #char "\n"; /* ENTER */ input_mode = .NAVIGATE; // TODO: jump to first match

                case #char "\x02"; /* CTRL+B */ if input_cursor > 0 then input_cursor -= 1;
                case #char "\x06"; /* CTRL+F */ if input_cursor < search_string_buffer.count then input_cursor += 1;
                case #char "\x01"; /* CTRL+A */ input_cursor = 0;
                case #char "\x05"; /* CTRL+E */ input_cursor = search_string_buffer.count;

                case #char "\x08"; /* CTRL+H */ #through;
                case #char "\x7f"; /* BACKSPACE */
                    if search_string_buffer.count > 0 && input_cursor > 0 {
                        array_ordered_remove_range(*search_string_buffer, input_cursor - 1, input_cursor);
                        input_cursor -= 1;
                    }

                case #char "\x04"; /* CTRL+D */
                    if search_string_buffer.count > 0 && input_cursor < search_string_buffer.count {
                        array_ordered_remove_range(*search_string_buffer, input_cursor, input_cursor + 1);
                    }

                case #char "\x0b"; /* CTRL+K */
                    if search_string_buffer.count > 0 && input_cursor < search_string_buffer.count {
                        array_ordered_remove_range(*search_string_buffer, input_cursor, search_string_buffer.count);
                    }

                case #char "\x17"; /* CTRL+W */
                    if search_string_buffer.count > 0 && input_cursor > 0 {
                        string_before_cursor := cast(string) search_string_buffer;
                        string_before_cursor.count = input_cursor;
                        to_delete_from := find_index_from_right(string_before_cursor, #char " ");
                        if to_delete_from == -1 then to_delete_from = 0;
                        array_ordered_remove_range(*search_string_buffer, to_delete_from, input_cursor);
                        input_cursor = to_delete_from;
                    }

                case #char "\x15"; /* CTRL+U */ {
                    search_string_buffer.count = 0;
                    input_cursor = 0;
                }
            }

            search_string = xx search_string_buffer;
    }
}

jump_to_next_search_match :: () {
    using context.state;
    using context.state.main_window_buffer;

    if row_offset == line_offsets.count - 1 return; // no next match possible

    search_start := line_offsets[row_offset + 1];

    index := find_index_from_left(only_text, search_string, search_start);
    if index == -1 return; // match not found

    while row_offset < line_offsets.count {
        if line_offsets[row_offset] > index { // overshot by 1 line
            row_offset -= 1;
            return;
        }

        row_offset += 1;
    }
}

jump_to_previous_search_match :: () {
    using context.state;
    using context.state.main_window_buffer;

    if row_offset == 0 return; // no previous match possible

    search_end := line_offsets[row_offset];

    search_region := substring(only_text, 0, search_end);
    index := find_index_from_right(search_region, search_string);

    if index == -1 return; // match not found

    while row_offset >= 0 {
        if line_offsets[row_offset] < index {
            return;
        }

        row_offset -= 1;
    }
}

//
// logging
//

my_logger :: (message: string, data: *void, info: Log_Info) {
    state := cast(*State) data;

    if info.common_flags & .ERROR {
        append(*state.error_log_builder, message);
        append(*state.error_log_builder, "\n");
    }

    if !state.log_file.handle return;

    file_write(*state.log_file, message);
    file_write(*state.log_file, "\n");
    fflush(state.log_file.handle);
}
fflush :: (handle: *FILE) -> s32 #foreign libc;

//
// string utilities
//

Ascii_Or_Hex :: #type,isa string;

ascii_or_hex_printer :: (builder: *String_Builder, any: Any, struct_printer_data: *void) -> bool {
    if any.type != type_info(Ascii_Or_Hex) return false;

    s := << cast(*string) any.value_pointer;
    for 0..s.count - 1 {
        print_ascii_or_hex(builder, s[it]);
    }

    return true;
}

NOT_SPECIFIED :: 0x7fff_ffff_ffff_ffff;
substring :: (s: string, start := 0, end := NOT_SPECIFIED, count := NOT_SPECIFIED) -> string {
    _count := count;
    _start := ifx start < 0 then s.count + start else start;
    if end == NOT_SPECIFIED && count == NOT_SPECIFIED {
        _count = s.count - _start;
    } else {
        assert(end == NOT_SPECIFIED || count == NOT_SPECIFIED);
        _end := ifx end < 0 then s.count + end else end;
        if count == NOT_SPECIFIED then _count = _end - _start;
    }
    assert(_start >= 0,                 "s.count: %, start: %, end: %, count: %", s.count, start, end, count);
    assert(_start <= s.count,           "s.count: %, start: %, end: %, count: %", s.count, start, end, count);
    assert(_count >= 0,                 "s.count: %, start: %, end: %, count: %", s.count, start, end, count);
    assert(_start + _count <= s.count,  "s.count: %, start: %, end: %, count: %", s.count, start, end, count);

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

    count := find_index_from_left(text, #char "\e");
    if count < 0 then count = text.count;

    if count > 0 {
        // Visible character sequence
        head := substring(text, 0, count = count);
        tail := substring(text, count);
        return head, count, tail;
    }

    // Escape sequence
    count += 1;

    while count < text.count {
        char := text[count];

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
// array utilities
//

array_ordered_remove_range :: inline (array_pointer: *[] $T, start: s64, end: s64) {
    assert(0 <= start, "start: %", start);
    assert(start < array_pointer.count, "start: %, array_poniter.count: %", start, array_pointer.count);
    assert(start <= end, "start: %, end: %", start, end);
    assert(end <= array_pointer.count, "end: %, array_poniter.count: %", end, array_pointer.count);

    if start == end return;

    array := <<array_pointer;
    count := end - start;

    for i : start..array.count-count-1
        array[i] = array[i+count];

    array_pointer.count -= count;
}

array_equals :: (lhs: [] $T, rhs: [] T) -> bool {
    if lhs.count != rhs.count return false;

    for 0..lhs.count-1 {
        if lhs[it] != rhs[it] return false;
    }

    return true;
}

test_array_ordered_remove_range :: () {
    array: [..] int;

    array_add(*array, .. .[1, 2, 3, 4, 5, 6]);
    array_ordered_remove_range(*array, 2, 4);
    pretty_assert(array_equals(array, int.[1, 2, 5, 6]));
    array_reset(*array);

    array_add(*array, .. .[1, 2, 3, 4, 5, 6]);
    array_ordered_remove_range(*array, 2, 6);
    pretty_assert(array_equals(array, int.[1, 2]));
    array_reset(*array);

    array_add(*array, .. .[1, 2, 3, 4, 5, 6]);
    array_ordered_remove_range(*array, 0, 6);
    pretty_assert(array_equals(array, int.[]));
    array_reset(*array);

    array_add(*array, .. .[1, 2, 3, 4, 5, 6]);
    array_ordered_remove_range(*array, 0, 5);
    pretty_assert(array_equals(array, int.[6]));
    array_reset(*array);
}

advance :: inline (a: *[] $T, amount: s64 = 1) {
    assert(amount >= 0);
    assert(a.count >= amount);
    a.count -= amount;
    a.data  += amount;
}

//
// miscellaneous utilities
//

Pointer_Range :: struct {
    start, end: *u8;
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
// terminal settings
//

restore_terminal_settings :: () {
    // "\e[?1049l": disable the alternative buffer
    // "\e[?25h": unhide cursor
    write_strings("\e[?1049l", "\e[?25h");

    tcsetattr(STDIN_FILENO, TCSADRAIN, *context.state.saved_termios);
}

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

//
// pretty assert
//

// Constant structs don't work with compile time constructs yet, so we return
// all fields directly
get_expr_info :: (code: Code) -> kind: Code_Node.Kind, op_type: s32, full_expr: string, proc_expr: string, lhs: Code, rhs: Code {
    #import "Program_Print";

    root := compiler_get_nodes(code);

    builder: String_Builder;
    print_expression(*builder, root);
    full_expr := builder_to_string(*builder);

    if root.kind == {
        case .BINARY_OPERATOR;
            binop := cast(*Code_Binary_Operator) root;
            op_type := binop.operator_type;
            lhs := compiler_get_code(binop.left, code);
            rhs := compiler_get_code(binop.right, code);
            return xx root.kind, op_type, full_expr, "", lhs, rhs;

        case .PROCEDURE_CALL;
            proccall := cast(*Code_Procedure_Call) root;
            if proccall.arguments_sorted.count != 2 {
                dummy : Code = #code null;
                return xx root.kind, -1, full_expr, "", dummy, dummy;
            }

            builder: String_Builder;
            print_expression(*builder, proccall.procedure_expression);
            proc_expr := builder_to_string(*builder);

            lhs := compiler_get_code(proccall.arguments_sorted[0], code);
            rhs := compiler_get_code(proccall.arguments_sorted[1], code);
            return xx root.kind, -1, full_expr, proc_expr, lhs, rhs;

        case;

    }

    dummy : Code = #code null;
    return xx root.kind, -1, full_expr, "", dummy, dummy;
}

pretty_assert :: (code: Code, loc := #caller_location) #expand {
    if #insert code return;

    if context.handling_assertion_failure  return;  // Avoid infinite loops.
    context.handling_assertion_failure = true;

    kind, op_type, full_expr, proc_expr, lhs, rhs :: #run get_expr_info(code);

    message := "";

    #if kind == .BINARY_OPERATOR {
        builder : String_Builder;
        builder.allocator = temporary_allocator;

        print_to_builder(*builder, "(%) = (% ", full_expr, #insert lhs);

        if op_type < 128 {
            append(*builder, cast(u8) op_type);
        } else {
            append(*builder, operator_to_string(xx op_type));
        }

        print_to_builder(*builder, " %) = false", #insert rhs);
        message = builder_to_string(*builder, temporary_allocator);
    } else #if kind == .PROCEDURE_CALL {
        message = tprint("(%) = (%(%, %)) = false", full_expr, proc_expr, #insert lhs, #insert rhs);
    } else {
        message = tprint("(%) = false", full_expr);
    }

    // We provide 'loc' in case _STACK_TRACE is turned off, but assertion_failed may well
    // look at the stack trace if it is available.
    context.assertion_failed(loc, message);
    context.handling_assertion_failure = false;

} @NoProfile


#import "Basic";
#import "Process";
#import "String";
#import "POSIX";
#import "System";
#import "File";
#import "Flat_Pool";
#import "Print_Vars";
System :: #import "System";
