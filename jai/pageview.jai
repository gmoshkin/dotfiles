#run {
    #import "Compiler";
    set_build_options_dc(.{ output_executable_name = "pageview", write_added_strings=true });
}

/* TODO:
  - command to save the current buffer and show diffs (maybe even in split view)
      although I can just use the tmux splits for that....
   - implement saving buffer history so that it's easy to cycle back and see if
     there was anything interesting
   - I support running command in shell, so that you can do stuff like
        `pv "cat /proc/123/stat | tr ' ' '\n'"`
        although maybe doing simple filters is going to be simple?
        Like having an array of simple filters of kind
          - replace all ' ' with '\n' and stuff
          But I don't wanna be supporting regular expressions though
   - smarter word selection when clicking on text:
      - currently I just use the spaces to determine word boundaries, but it
      would be nice to also use other delimiters like "()[]|,". And maybe even
      some context sensitive stuff:
          - to select just the path in `path/to/file.txt:123:456`
          - but also select the whole url in `<https://example.com>`
      (notice how `:` is treated both as a delimiter and part of the word depending on the context)
*/
State :: struct {

    //
    // main window state
    //

    row_offset: s64;
    col_offset: s64;
    stick_to_the_bottom := false;

    // TODO: support virtual line offsets like in vim (so that in wrapping mode
    // it doesnt jump over the whole screen if a line is too long)
    wrapped_line_offset: s64;
    line_wrapping := false;
    strip_control_codes := false;
    line_numberring := false;
    show_memory_usage := false;
    // FIXME: this mode doesn't 100% work right now, but may help somewhat
    // sometimes...
    visualize_control_codes := false;

    main_window_height: s64;
    terminal_size: Terminal_Size_Info;

    //
    // input
    //

    input_mode: enum {
        NAVIGATE;
        INPUT_SEARCH_STRING;
        INPUT_COMMAND;
    } = .NAVIGATE;
    input_cursor: s64;
    mouse_position := Cell_Position.{ -1, -1 };
    delayed_action : enum {
        NONE;
        MOUSE_SELECTION_CLICK;
    };

    // I need to render the cursor at the very end, but it's position is
    // determined a bit earlier, so I store it in the state.
    cursor_line: s64; // if -1, the cursor is hidden
    cursor_column: s64; // if -1, the cursor is hidden

    command_line: [..] u8;
    command_line_history: [..] string;
    history_cursor := -1;
    history_stash: string;

    search_string_buffer: [..] u8;
    search_string: string; // this is always just the search_string_buffer converted to string
    search_string_history: [..] string;

    input_buffer: [..] u8;
    input_buffer_count: s64;
    input_received_this_tick: bool;

    //
    // status
    //
    frame_time: float64;
    error_message_builder: String_Builder;
    error_message_deadline: float64 = -1.0;
    status_scroll_interval_seconds := 0.1;
    next_status_scroll_time : float64 = -1.0;
    before_scroll_time_seconds : float64 = 2.0;
    current_command_string_scroll_offset := 0;

    //
    // logging
    //

    log_file_name: string;
    log_file: File;
    log_file.handle = null;

    error_log_builder: String_Builder;

    //
    // sources of text
    //
    main_window_source: enum {
        NONE;
        EXTERNAL_COMMAND;
        STANDARD_INPUT;
        // TODO: FILE;
    }

    //
    // source: STANDARD_INPUT
    //
    input_stream_builder: String_Builder;
    input_stream_fd: s32 = -1;
    parent_process_command_line: [] string;

    //
    // source: EXTERNAL_COMMAND
    //
    command: [..] string;

    command_run_period_seconds := 1.0;
    time_next_command_run : float64 = -1.0;
    last_command_result: Process_Result;

    //
    // rendering
    //
    redraw_once := false;
    main_window_buffers: [..] Window_Buffer;
    current_shown_buffer_index: s64;
    show_latest_buffer := true;

    selection_cursor := -1;
    last_selected_string: string;

    current_screen_row: s64;
    current_row_left_offset: s64; // XXX: this name sucks
    current_line_number: s64;

    // Stores pointers into `last_shown_line_buffer_flat_pool`.
    last_shown_line_buffer: [..] string;
    memory_pool_for_last_shown_line_buffer: Flat_Pool;
    memory_pool_for_last_shown_line_buffer_high_water_mark: s64;

    temporary_storage_memory_pool: Flat_Pool;
    temporary_storage_high_water_mark: s64;

    //
    // miscellaneous internals
    //
    default_allocated_high_water_mark : s64;
    saved_termios: Termios;
    setup_control_codes: [..] string;
    tty_name: string;

    epoll_fd: s32;
    epoll_events: [1] epoll_event;
}
#add_context state: State;

Cell_Position :: struct {
    row: s32;
    column: s32;
}

Window_Buffer :: struct {
    index_in_history: s64;
    time_generated: Apollo_Time;

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

    state := *context.state;

    cursor := 1;
    while cursor < args.count {
        arg := args[cursor];
        if arg == {
            case "-f"; #through;
            case "--follow";
                state.stick_to_the_bottom = true;

            case "-m"; #through;
            case "--memory"; #through;
            case "--memory-usage";
                state.show_memory_usage = true;

            case "-n"; #through;
            case "--line-number"; #through;
            case "--line-numbers";
                state.line_numberring = true;

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
                state.log_file_name = copy_string(args[cursor]);

            // TODO: a flag to just watch a file's contents, so I don't have to
            // do `cat filename`

            case; break;
        }
        cursor += 1;
    }

    command_size := args.count - cursor;
    array_reserve(*state.command, command_size);
    for 0..command_size-1 {
        array_add(*state.command, copy_string(args[cursor + it]));
    }

    // Preallocate memory
    array_reserve(*state.search_string_buffer, 4096);
    array_reserve(*state.command_line, 4096);
    context.temporary_storage.overflow_allocator.proc = flat_pool_allocator_proc;
    context.temporary_storage.overflow_allocator.data = *state.temporary_storage_memory_pool;

    // Setup logger
    state.error_log_builder.allocator = temp;
    if state.log_file_name {
        log_file, ok := file_open(state.log_file_name, for_writing = true, keep_existing_content = true);
        assert(ok);
        state.log_file = log_file;
    }
    context.logger = my_logger;
    context.logger_data = *context.state;

    if !isatty(STDOUT_FILENO) {
        // TODO: I could just pipe the command in to the out fd.
        // What would be the point though?
        print("Stdout needs to be connected to a terminal.\n");
        exit(1);
    }

    // Choose input source
    if !isatty(STDIN_FILENO) {
        state.main_window_source = .STANDARD_INPUT;
        log("main window source is stdin");
    } else if state.command {
        state.main_window_source = .EXTERNAL_COMMAND;
        log("main window source is external command: %", state.command);
    } else {
        print("Specify a command to run or pipe in some text on the stdin\n");
        exit(1);
    }

    // Initialize X11 for the clipboard, which doesn't fucking work, of course it doesn't, why would anything ever work?
    #if OS == .LINUX {
        if getenv("DISPLAY") init_global_display();
    }

    // Initialize command
    init_commands();

    // Setup signal handlers
    signal(SIGINT, shutdown_signal_handler);
    signal(SIGTERM, shutdown_signal_handler);
    signal(SIGWINCH, window_size_changed_signal_handler);

    // Reconfigure stdin to work properly
    if state.main_window_source == .STANDARD_INPUT {
        using context.state;

        print("Reading input from standard input...\n");

        my_pid := getpid();
        info: Process_Info;
        ok := get_process_info(my_pid, *info, log_errors=false,, temp);
        assert(ok);
        parent_info: Process_Info;
        ok = get_process_info(info.parent_pid, *parent_info,, temp);
        if ok {
            parent_process_command_line = NewArray(parent_info.command_line.count, string);
            for parent_info.command_line {
                parent_process_command_line[it_index] = copy_string(it);
            }
        }

        // Duplicate stdin to a different file descriptor
        input_stream_fd = dup(STDIN_FILENO);
        assert(input_stream_fd >= 0);
        flags := fcntl(input_stream_fd, F_GETFL);
        flags |= O_NONBLOCK;
        rc := fcntl(input_stream_fd, F_SETFL, flags);
        assert(rc != -1);

        // Save tty_name
        tty_name_cstr := ttyname(STDOUT_FILENO);
        assert(tty_name_cstr != null);
        tty_name.count = c_style_strlen(tty_name_cstr);
        tty_name.data = alloc(tty_name.count + 1); // `+ 1` for the nul byte
        memcpy(tty_name.data, tty_name_cstr, tty_name.count + 1);

        // Re attach our stdin to the terminal
        new_stdin_fd := open(tty_name_cstr, O_RDONLY);
        assert(new_stdin_fd >= 0);
        rc = dup2(new_stdin_fd, STDIN_FILENO);
        assert(rc >= 0);
    }

    // Get terminal size
    rc := ioctl(STDIN_FILENO, TIOCGWINSZ, *state.terminal_size);
    assert(rc == 0);

    // `- 2` for :2_status_lines
    state.main_window_height = state.terminal_size.rows - 2;

    // Hide cursor, disable echo, etc.
    {
        context.assertion_failed = (loc: Source_Code_Location, message: string) -> bool {
            restore_terminal_settings();
            return runtime_support_assertion_failed(loc, message);
        };

        array_add(*state.setup_control_codes,
            "\e[?1049h", // enable the alternative buffer
            "\e[?25l", // hide cursor
            "\e[?1002h", // enable mouse events: click, wheel + drag
            "\e[?1006h", // alternate mouse input format
        );
        write_strings(..state.setup_control_codes);

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

    status_line_init();

    // Initialize input
    array_reserve(*state.input_buffer, 4096);

    first_time := true;
    while !should_exit {
        defer first_time = false;
        using state;
        reset(*error_log_builder);

        // Wait for events
        timeout: s32 = 1000 / 10;
        if first_time then timeout = 0;
        rc := epoll_wait(epoll_fd, epoll_events.data, epoll_events.count, timeout);
        if rc == -1 {
            assert(errno() == EINTR);
        }

        // Update main window buffer from the current source
        if state.main_window_source == {
            // TODO: get a stdout fd from the subcommand and jam it into the epoll wait group
            case .EXTERNAL_COMMAND; maybe_get_external_command_output();
            // TODO: jam the dupped stdin fd into the epoll wait group
            case .STANDARD_INPUT; read_some_from_input_stream();
        }

        input_received_this_tick = false;
        for 0..rc-1 {
            if epoll_events[it].data.fd == STDIN_FILENO {
                input_received_this_tick = read_input();
            }
        }

        frame_time = seconds_since_init();

        // FIXME: stupid fucking windows terminal flickers when you redraw a
        // large portion of the screen. I could check per line if something
        // changed and only redraw given lines... This is very very sad...
        if window_size_changed {
            window_size_changed = false;
            redraw_once = true;

            // Get terminal size
            rc := ioctl(STDIN_FILENO, TIOCGWINSZ, *state.terminal_size);

            // `- 2` for 2 status lines
            state.main_window_height = state.terminal_size.rows - 2;
        }

        // Handle input
        state.delayed_action = .NONE;
        if input_received_this_tick {
            parse_and_handle_input();
        }

        main_window_buffer := *main_window_buffers[current_shown_buffer_index];
        // FIXME: this doesn't work in line-wrapping mode
        if stick_to_the_bottom {
            row_offset = max(row_offset, main_window_buffer.line_offsets.count - main_window_height);
        }


        render_status_line_1();

        //
        // Main window
        //

        using main_window_buffer;

        // `line_buffer` stores pointers into `main_window_buffer` or temporary storage
        line_buffer: [..] string;
        line_buffer.allocator = temp;
        array_reserve(*line_buffer, main_window_height);

        // starts from 1, `+2` for :2_status_lines
        current_screen_row = 1 + 2;

        line_index := 0;
        if row_offset > 0 {
            line_index = row_offset;
        } else if row_offset < 0 {
            // Extra blank lines for negative row_offset (for some reason)
            for 1..-row_offset {
                array_add(*line_buffer, "\n");
            }
            current_screen_row += -row_offset;
        }

        line_number_max_digits := tprint("%", main_window_buffer.line_offsets.count).count;
        main_window_left_offset := 0;
        if line_numberring then main_window_left_offset = line_number_max_digits + 1;
        if col_offset < 0 {
            main_window_left_offset += -col_offset;
        }

        // these are used and reused for each line
        codes: [..] Control_Code_Info;
        codes.allocator = temp;
        search_matches: [..] Pointer_Range;
        search_matches.allocator = temp;

        // Preprocess lines to be displayed
        // TODO: tabs aren't handled correctly yet,
        // terminal displays them with different widths, but I count them as 1 always
        if main_window_height != 0 while line_buffer.count < main_window_height || (line_wrapping && stick_to_the_bottom) {
            if line_index > line_offsets.count - 1 break;
            line_start := line_offsets[line_index];
            line_end := ifx line_index < line_offsets.count - 1 then line_offsets[line_index + 1] else only_text.count;
            current_line_number = line_index + 1;
            defer line_index += 1;
            line := substring(xx only_text, line_start, line_end);

            current_row_left_offset = main_window_left_offset;

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

            builder := String_Builder.{ allocator = temp };
            ensure_contiguous_space(*builder, line.count);

            if !line_wrapping {
                visible_columns_budget : int = terminal_size.cols;
                visible_slice := line;

                if line_numberring {
                    append(*builder, "\e[2;37m"); // color gray (dark white)
                    print(*builder, "% ", fmt(current_line_number, line_number_max_digits, padding=" "));
                    append(*builder, "\e[0m"); // color gray (dark white)
                    visible_columns_budget -= line_number_max_digits + 1; // `+ 1` for extra space
                }

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
                    current_row_left_offset += 1;

                    // add all control codes from the hidden part of the line
                    if !strip_control_codes {
                        codes := find_all_control_codes_in_range(main_window_buffer, hidden_slice);
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

                line_overflowed := utf8_count(visible_slice) > visible_columns_budget;
                if line_overflowed {
                    // Leave space for the :line_overflow_character
                    // FIXME: unicode characters are not accounted properly here
                    visible_slice = utf8_substring(visible_slice, visible_columns_budget - 1);
                }

                codes.count = 0;
                if !strip_control_codes {
                    array_add(*codes, ..find_all_control_codes_in_range(main_window_buffer, visible_slice));
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

                        insert_control_code_range(*codes, main_window_buffer,
                                                  match_start, "\e[7m", // invert color mode
                                                  match_end, "\e[27m"); // disable invert color mode
                    }
                }

                select_word_delayed(main_window_buffer, visible_slice, *codes);

                // Build the line string
                build_line_with_control_codes(*builder, main_window_buffer, visible_slice, codes);

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
                current_screen_row += 1;
            } else /* line_wrapping == true */ {
                // col_offset is ignored

                line_tail := line;
                first := true;

                // Iterate over line pieces
                while first || line_tail && (stick_to_the_bottom || line_buffer.count < main_window_height) {
                    defer first = false;
                    visible_columns_budget : int = terminal_size.cols;

                    if first {
                        first = false;
                        if line_numberring {
                            append(*builder, "\e[2;37m"); // color gray (dark white)
                            print(*builder, "% ", fmt(current_line_number, line_number_max_digits, padding=" "));
                            append(*builder, "\e[0m"); // color gray (dark white)
                            visible_columns_budget -= line_number_max_digits + 1; // `+ 1` for extra space
                        }
                    } else {
                        if line_numberring {
                            append_padding(*builder, line_number_max_digits + 1); // `+ 1` for extra space
                            visible_columns_budget -= line_number_max_digits + 1; // `+ 1` for extra space
                        }
                        prefix :: "";
                        append(*builder, prefix);
                        visible_columns_budget -= prefix.count;
                    }

                    current_slice := utf8_substring(line_tail, visible_columns_budget);
                    // TODO: maybe not just space but also other punctuation
                    if current_slice.count < line_tail.count && current_slice.data[current_slice.count] != #char " " {
                        last_space := find_index_from_right(current_slice, #char " ");
                        if last_space != -1 {
                            current_slice.count = last_space + 1; // `+1` so that space is left on this line
                        }
                    }
                    current_slice_end := current_slice.data + current_slice.count;
                    line_tail = substring(line_tail, current_slice.count);

                    codes.count = 0;
                    if !strip_control_codes {
                        array_add(*codes, ..find_all_control_codes_in_range(main_window_buffer, current_slice));
                    }

                    // :search_string_highlight
                    while search_matches_tail {
                        match := *search_matches_tail[0];

                        start_in_range := match.start >= current_slice.data && match.start < current_slice_end;
                        end_in_range := match.end > current_slice.data && match.end <= current_slice_end;
                        if start_in_range || end_in_range {
                            insert_control_code_range(*codes, main_window_buffer,
                                                      match.start, "\e[7m", // invert color mode
                                                      match.end, "\e[27m"); // disable invert color mode
                        }

                        if !start_in_range || !end_in_range break; // leave that match for the next line piece

                        advance(*search_matches_tail, 1);
                    }

                    select_word_delayed(main_window_buffer, current_slice, *codes);

                    // Build the line string
                    build_line_with_control_codes(*builder, main_window_buffer, current_slice, codes);

                    if stick_to_the_bottom || line_buffer.count != line_buffer.allocated - 1 {
                        append(*builder, "\n");
                    } else {
                        // Reset color codes
                        append(*builder, "\e[0m");
                    }
                    array_add(*line_buffer, builder_to_string(*builder,, temp));
                    current_screen_row += 1;
                }
            }
        }

        overflow := line_buffer.count - main_window_height;
        if overflow > 0 {
            assert(stick_to_the_bottom, "shouldn't happen otherwise");
            line_buffer.data += overflow;
            line_buffer.count -= overflow;
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
        if changed || redraw_once {
            redraw_once = false;
            write_string("\e[0J");
            if line_buffer.count > 0 {
                all_but_last_line := line_buffer;
                all_but_last_line.count -= 1;
                write_strings(..all_but_last_line);

                last_line := line_buffer[line_buffer.count - 1];
                if last_line[last_line.count - 1] == #char "\n" last_line.count -= 1;
                write_string(last_line);
            }

            // Save last shown line buffer
            memory_pool_allocator: Allocator;
            memory_pool_allocator.proc = flat_pool_allocator_proc;
            memory_pool_allocator.data = *memory_pool_for_last_shown_line_buffer;

            memory_pool_for_last_shown_line_buffer_high_water_mark = max(memory_pool_for_last_shown_line_buffer_high_water_mark, flat_pool_allocated(*memory_pool_for_last_shown_line_buffer));
            reset(*memory_pool_for_last_shown_line_buffer);
            last_shown_line_buffer.allocator = memory_pool_allocator;
            array_reset(*last_shown_line_buffer);

            array_reserve(*last_shown_line_buffer, line_buffer.count);
            for line_buffer {
                line := copy_string(it,, memory_pool_allocator);
                array_add(*last_shown_line_buffer, line);
            }
            memory_pool_for_last_shown_line_buffer_high_water_mark = max(memory_pool_for_last_shown_line_buffer_high_water_mark, flat_pool_allocated(*memory_pool_for_last_shown_line_buffer));
        }

        //
        // second status line
        //
        {
            builder: String_Builder;
            builder.allocator = temp;
            buffer := get_base_buffer(*builder);

            cursor_line = -1;
            cursor_column = -1;

            // "\e[H": move cursor to position (row 2, column 1)
            append(*builder, "\e[2;1H");
            append(*builder, "\e[K"); // "\e[K": erase in line
            append(*builder, "\e[2;37m"); // color gray

            if frame_time < error_message_deadline {
                append(*builder, "\e[0;31m"); // color red;
                append(*builder, to_string(*error_message_builder));
                append(*builder, "\e[0m");
            } else if input_mode == .NAVIGATE {
                text_start := buffer.count;
                {
                    print_to_builder(*builder, "offset: %, %   ", row_offset, col_offset);
                    print_to_builder(*builder, "lines: %   ", main_window_buffer.line_offsets.count);
                    if stick_to_the_bottom then append(*builder, "sinking   ");

                    // Print current input buffer
                    append(*builder, "input: ");

                    print_to_builder(*builder, "%", cast(Ascii_Or_Hex) input_buffer);

                    print(*builder, " mouse %, %", mouse_position.column, mouse_position.row);
                    // print(*builder, "  control codes count %", main_window_buffer.control_codes.count);
                }
                text_length := buffer.count - text_start;
                overflow := text_length - terminal_size.cols;
                if overflow > 0 {
                    buffer.count -= overflow;
                }
            } else if input_mode == .INPUT_SEARCH_STRING || input_mode == .INPUT_COMMAND {
                prefix := "??";
                text := "<unknown mode>";
                if input_mode == .INPUT_SEARCH_STRING { prefix = "/";  text = search_string; }
                if input_mode == .INPUT_COMMAND       { prefix = "> "; text = xx command_line; }
                append(*builder, prefix);

                visible_columns_budget := terminal_size.cols - prefix.count;

                overflow := text.count - visible_columns_budget;
                // FIXME: I just want the last column to be left for the cursor
                // if the cursor is at the last column, but than be filled with
                // the search string otherwise... but I'm a sleepy head right
                // now :(
                if overflow > 0 {
                    // Add extra space at the end for the cursor
                    overflow += 1;
                    slice_start := clamp(input_cursor - 2, 0, overflow);
                    append(*builder, substring(text, slice_start, count=visible_columns_budget - 1));
                    // `+ 1` because rows start at 1
                    cursor_line = 2;
                    cursor_column = input_cursor - slice_start + prefix.count + 1;
                } else {
                    append(*builder, text);
                    // `+ 1` because rows start at 1
                    cursor_line = 2;
                    cursor_column = input_cursor + prefix.count + 1;
                }
            }

            append(*builder, "\e[0m");

            assert(get_current_buffer(*builder) == buffer);
            write_builder(*builder);
        }

        // memory usage window
        if show_memory_usage
        {
            builder := String_Builder.{ allocator = temp };

            fmt_mem :: inline (value: int) -> FormatInt {
                return FormatInt.{ value=value, minimum_digits=7, padding=#char " " };
            }

            // prepare window lines
            append(*builder, "\e[100m"); // background color gray
            print(*builder, "temp:        % [hvm: %]",
                            fmt_mem(context.temporary_storage.total_bytes_occupied),
                            fmt_mem(temporary_storage_high_water_mark));

            append(*builder, "\n");
            append(*builder, "\e[100m"); // background color gray
            print(*builder, "buffer pool: % [hvm: %]",
                            fmt_mem(flat_pool_allocated(*memory_pool_for_last_shown_line_buffer)),
                            fmt_mem(memory_pool_for_last_shown_line_buffer_high_water_mark));

            // TODO: the builtin Memory_Debugger is too expensive, it seems that
            // it expects to only be called once per program execution (or maybe
            // a few times), but not every frame? Or there's the wire protocol
            // for an external visualizer program which is cool and all, but not
            // my use case. So probably I should do something myself here...

            // default_allocated := 0;
            // for address_table if it.is_live default_allocated += it.size;
            // default_allocated_high_water_mark = max(default_allocated_high_water_mark, default_allocated);

            // append(*builder, "\n");
            // append(*builder, "\e[100m"); // background color gray
            // print(*builder, "default:     % [hvm: %]",
            //                 fmt_mem(default_allocated),
            //                 fmt_mem(default_allocated_high_water_mark));

            lines: [..] string; lines.allocator = temp;
            max_width := 0;
            tail := to_string(*builder);
            while tail {
                found:, line:, tail = split_from_left(tail, #char "\n");
                max_width = max(max_width, count_visible_characters(line));
                array_add(*lines, line);
            }

            window_row_offset := terminal_size.rows - lines.count;
            window_col_offset := terminal_size.cols - max_width;

            // render the window
            start := builder_string_length(*builder);
            for line: lines {
                // "\e[H": move cursor to given position (row, col) (1-based)
                print(*builder, "\e[%;%H", window_row_offset + 1 + it_index, window_col_offset + 1);
                append(*builder, line);
                append_padding(*builder, max_width - line.count);
            }
            append(*builder, "\e[0m");

            total_string := builder_to_string(*builder,, temp);
            write_string(substring(total_string, start));
        }

        // show the cursor at the very end
        if cursor_column != -1 {
            builder := String_Builder.{ allocator = temp };
            // move the cursor to where the user is editting text
            print(*builder, "\e[%;%H", cursor_line, cursor_column);
            // show the cursor, so user knows they're editing text
            append(*builder, "\e[?25h");
            append(*builder, "\e[0m");
            write_builder(*builder);
        }

        if should_exit break;

        temporary_storage_high_water_mark = max(temporary_storage_high_water_mark, context.temporary_storage.high_water_mark);
        reset_temporary_storage();
    }

    // Restore terminal state
    restore_terminal_settings();

    if signalled_with_signal != -1 {
        print("got signal %\n", signalled_with_signal);
    }
}

select_word_delayed :: (window_buffer: *Window_Buffer, slice_of_only_text: string, codes: *[..] Control_Code_Info) {
    using context.state;
    using window_buffer;

    assert(is_subslice(outer=only_text, inner=slice_of_only_text));
    slice := slice_of_only_text;

    if delayed_action == .MOUSE_SELECTION_CLICK {
        if current_screen_row == mouse_position.row {
            log("click at line #%", current_line_number);
            column_in_window := mouse_position.column - 1 - current_row_left_offset;
            s := utf8_substring(slice, column_in_window);
            selection_cursor = slice.data + s.count - only_text.data;
        }
    }

    selection_pointer := only_text.data + selection_cursor;
    if selection_pointer >= slice.data && selection_pointer <= slice.data + slice.count {
        cursor_in_visible_slice := selection_pointer - slice.data;
        before_cursor := slice; before_cursor.count = cursor_in_visible_slice;
        index := find_index_from_right(before_cursor, #char " ");
        start := slice.data; if index != -1 then start += index + 1;

        index = find_index_from_left(slice, #char " ", cursor_in_visible_slice);
        end := slice.data + slice.count;
        if index != -1 then end = slice.data + index;

        if delayed_action == .MOUSE_SELECTION_CLICK {
            last_selected_string = only_visible_text(.{ end - start, start });
            log("selected string: %", last_selected_string);
            // FIXME: this don't work:
            os_clipboard_set_text(last_selected_string);

            tmux_copy_to_clipboard(last_selected_string);
        } else if last_selected_string != only_visible_text(.{ end - start, start }) {
            selection_cursor = -1;
        }

        insert_control_code_range(codes, window_buffer,
                                  start, "\e[7m", // invert color mode
                                  end,   "\e[27m"); // disable invert color mode
    }
}

tmux_copy_to_clipboard :: (text: string) {
    if !getenv("TMUX") return;

    command := string.["tmux", "set-buffer", text];
    log("running %", command);
    res := my_run_command(..command, capture_and_return_output=false);
    if res.type != .EXITED || res.exit_code != 0 {
        log("command % failed: %", command, res);
    }
}

//
// text sources
//

//
// text source: EXTERNAL_COMMAND
//

maybe_get_external_command_output :: () {
    using context.state;

    time := seconds_since_init();
    if time < time_next_command_run return;

    // FIXME: only do this if the command output is not the same the previous one
    // TODO: do the actual buffer history
    // new_window_buffer: Window_Buffer;
    if !main_window_buffers array_add(*main_window_buffers, .{});
    new_window_buffer := *main_window_buffers[main_window_buffers.count - 1];
    using new_window_buffer;
    free(raw_text_and_control_codes);

    // If the command is a single argument which contains a string,
    // assume it's some shell pipeline & run it in a shell
    temp_command : [] string = xx command;
    if command.count == 1 && find_index_from_left(command[0], #char " ") != -1 {
        temp_command = .["/bin/sh", "-c", command[0]];
    }

    t0 := time;
    last_command_result=, normal_output, error_output := my_run_command(..temp_command, capture_and_return_output = true);
    elapsed := seconds_since_init() - t0;
    if elapsed > 0.5 {
        log("executing % took % seconds", temp_command, elapsed);
    }
    time_next_command_run = time + command_run_period_seconds;

    time_generated = current_time_consensus();

    if last_command_result.type == .FAILED_TO_LAUNCH
    {
        prefix :: "\e[31m";
        raw_text_and_control_codes = builder_to_string(*error_log_builder, extra_bytes_to_prepend=prefix.count);
        memcpy(raw_text_and_control_codes.data, prefix.data, prefix.count);
    }
    else if error_output
    {
        error_builder: String_Builder; error_builder.allocator = temp;
        tail := error_output;
        while tail {
            _, line:, tail = split_from_left(tail, #char "\n");
            append(*error_builder, "\e[31m"); // color red
            append(*error_builder, line);
            append(*error_builder, "\n");
        }

        buffer: [..] u8;
        total_size := builder_string_length(*error_builder) + normal_output.count;
        array_reserve(*buffer, total_size);

        builder_buffer := get_base_buffer(*error_builder);
        while builder_buffer {
            array_add(*buffer, ..cast([] u8) to_string(builder_buffer));
            builder_buffer = builder_buffer.next;
        }
        array_add(*buffer, ..cast([] u8) normal_output);

        raw_text_and_control_codes = xx buffer;
        free(normal_output);
        free(error_output);
    }
    else
    {
        raw_text_and_control_codes = normal_output;
    }

    previous_window_buffer := main_window_buffers[main_window_buffers.count - 1];
    // if raw_text_and_control_codes == previous_window_buffer.raw_text_and_control_codes {
    //     // TODO
    // }

    separate_control_codes(new_window_buffer, raw_text_and_control_codes);
    if show_latest_buffer {
        current_shown_buffer_index = new_window_buffer.index_in_history;
    }
}

//
// text source: STANDARD_INPUT
//

read_some_from_input_stream :: () {
    using context.state;

    if input_stream_fd == -1 return;

    has_new_data := read_all_available_data_from_input_stream();
    if !has_new_data {
        if !parent_process_command_line return;

        if path_filename(parent_process_command_line[0]) == "git" {
            for command free(it);
            command.count = 0;
            array_reserve(*command, parent_process_command_line.count);
            for parent_process_command_line {
                array_add(*command, copy_string(it));
            }
            time_next_command_run = frame_time;
            main_window_source = .EXTERNAL_COMMAND;
            maybe_get_external_command_output();
        }

        return;
    }

    if !main_window_buffers array_add(*main_window_buffers, .{});
    window_buffer := *main_window_buffers[current_shown_buffer_index];
    free(window_buffer.raw_text_and_control_codes);
    window_buffer.raw_text_and_control_codes = builder_to_string(*input_stream_builder, do_reset=false);
    separate_control_codes(window_buffer, window_buffer.raw_text_and_control_codes);
}

read_all_available_data_from_input_stream :: () -> has_new_data: bool {
    using context.state;

    if input_stream_fd == -1 return false;

    has_new_data := false;
    while true {
        buffer := ensure_contiguous_space_and_return_available_range(*input_stream_builder);

        read_count := read(input_stream_fd, buffer.data, xx buffer.count);
        if read_count > 0 {
            advance_through_ensured_space(*input_stream_builder, xx read_count);
            has_new_data = true;
            continue;
        }

        if read_count < 0 {
            code, message := System.get_error_value_and_string();
            if code != EAGAIN && code != EWOULDBLOCK {
                append(*input_stream_builder, "\e[31m"); // color red
                print(*input_stream_builder, "Error: (%) %\n", code, message);
                append(*input_stream_builder, "\e[0m");
                close(input_stream_fd);
                input_stream_fd = -1;
            }
        }

        return has_new_data;
    }
}

//
// status lines
//

status_line_init :: () {
    using context.state;

    buffer_zone := cast(int) (before_scroll_time_seconds / status_scroll_interval_seconds);
    current_command_string_scroll_offset = -buffer_zone;
}

render_status_line_1 :: () {
    using context.state;

    builder: String_Builder;
    builder.allocator = temp;

    // hide the cursor, so it doesn't flicker all around the screen
    // while the ui is being drawn
    append(*builder, "\e[?25l");

    // "\e[H": move cursor to "home" position (row 0, column 0)
    append(*builder, "\e[H");

    // "\e[0J": erase from cursor to end of screen
    // append(*builder, "\e[0J");

    // "\e[K": erase in line
    append(*builder, "\e[K");

    //
    // left side
    //
    if main_window_source == {
        case .EXTERNAL_COMMAND; {
            max_command_string_length : s64 = terminal_size.cols / 2;

            append(*builder, "\e[35m"); // color magenta
            append(*builder, "$(");
            append(*builder, "\e[0m");

            {
                temp_builder := String_Builder.{ allocator = temp };
                append(*temp_builder, "\e[32m");
                if path_filename(command[0]) == "git" then append(*temp_builder, "git");
                else                                       append(*temp_builder, command[0]);
                append(*temp_builder, "\e[0m");

                for 1..command.count-1 {
                    append(*temp_builder, " ");
                    if find_index_from_left(command[it], #char " ") != -1 {
                        append(*temp_builder, "\e[33m"); // color yellow
                        append(*temp_builder, "\"");
                        print_ascii_or_hex(*temp_builder, command[it]);
                        append(*temp_builder, "\"");
                        append(*temp_builder, "\e[0m");
                    } else {
                        append(*temp_builder, command[it]);
                    }
                }

                command_string := to_string(*temp_builder);

                command_string_overflow := count_visible_characters(command_string) - max_command_string_length;
                if command_string_overflow > 0 {
                    if frame_time > next_status_scroll_time {
                        next_status_scroll_time = frame_time + status_scroll_interval_seconds;
                        current_command_string_scroll_offset += 1;

                        // buffer_zone is kind of a hack which makes it so the
                        // string doesn't scroll for some time in the left most
                        // and in the rightmost positions
                        buffer_zone := cast(int) (before_scroll_time_seconds / status_scroll_interval_seconds);
                        if current_command_string_scroll_offset > command_string_overflow + buffer_zone {
                            current_command_string_scroll_offset = -buffer_zone;
                        }
                    }
                    clamped_offset := clamp(current_command_string_scroll_offset, 0, command_string_overflow);
                    scroll_string_with_control_codes(*builder, command_string, clamped_offset, max_command_string_length);
                } else {
                    append(*builder, command_string);
                }
            }

            append(*builder, "\e[35m"); // color magenta
            append(*builder, ")");
            append(*builder, "\e[0m");
            if last_command_result.exit_code != 0 {
                append(*builder, "\e[35m"); // color magenta
                append(*builder, " -> ");
                append(*builder, "\e[31m"); // color red
                print(*builder, "%", last_command_result.exit_code);
                append(*builder, "\e[0m");
            }

            // command rerun period
            {
                append(*builder, "\e[2;37m"); // color gray (dark + white)
                append(*builder, " T: ");
                // XXX: am I stupid, or is stb_print_float doing something
                // weird when removing zero and when trailing_width is not zero?
                text := tprint("%", fmt(command_run_period_seconds, digits_after_comma=1));
                text = trim(text);
                append(*builder, text);
                append(*builder, "s");
                append(*builder, "\e[0m");
            }
        }
        case .STANDARD_INPUT; {
            append(*builder, "\e[35m"); // color magenta
            append(*builder, "<stdin>");
            append(*builder, "\e[0m");

            if input_stream_fd != -1 {
                append(*builder, "\e[35m"); // color magenta
                append(*builder, "...");
                append(*builder, "\e[0m");
            }
        }
    }

    left_side := to_string(*builder);

    right_side_builder: String_Builder; right_side_builder.allocator = temp;
    right_side: string;
    //
    // right side
    //
    {
        time: Apollo_Time;
        if main_window_source == {
            case .STANDARD_INPUT;   time = current_time_consensus();
            case .EXTERNAL_COMMAND; time = main_window_buffers[current_shown_buffer_index].time_generated;
        }
        date_time := to_calendar(time, .LOCAL);

        append(*right_side_builder, "\e[32m"); // color green
        print_date_time_for_humans(*right_side_builder, date_time);
        append(*right_side_builder, "\e[0m");
        right_side = to_string(*right_side_builder);
    }

    // padding between left side & right side
    padding := terminal_size.cols - count_visible_characters(left_side) - count_visible_characters(right_side);
    if padding >= 0 {
        append_padding(*builder, padding);
        append(*builder, right_side);
    }

    append(*builder, "\n");

    // second line is drawn at the end
    append(*builder, "\n");

    write_builder(*builder);
}

//
// iterating over control codes
//

build_line_with_control_codes :: (builder: *String_Builder, window_buffer: *Window_Buffer, text_slice: string, codes: [] Control_Code_Info) -> (num_codes_left: s64) {
    using context.state;
    using window_buffer;

    if !codes.count {
        append(builder, text_slice);
        return 0;
    }

    start := text_slice.data - only_text.data;
    end := start + text_slice.count;

    cursor := start;
    for codes {
        position_clamped := clamp(it.position_in_text, start, end);

        piece := substring(only_text, cursor, position_clamped);
        if context.state.visualize_control_codes then print(builder, "%", cast(Ascii_Or_Hex) piece);
        else                                          append(builder, piece);

        if it.position_in_text > end return codes.count - it_index;

        if context.state.visualize_control_codes then print(builder, "%", cast(Ascii_Or_Hex) it.data);
        else                                          append(builder, it.data);

        cursor = position_clamped;
    }
    if cursor < end {
        piece := substring(only_text, cursor, end);
        if context.state.visualize_control_codes then print(builder, "%", cast(Ascii_Or_Hex) piece);
        else                                          append(builder, piece);
    }

    return 0;
}

// FIXME: linear search. If I keep track of last inserted position and start
// searching from it, this should help with performance.
insert_control_code_range :: (codes: *[..] Control_Code_Info,
                              window_buffer: *Window_Buffer,
                              start_pointer: *u8, // points into only_text
                              start_code: string,
                              end_pointer: *u8, // points into only_text
                              end_code: string)
{
    // Empty range will always be invisible
    if start_pointer == end_pointer return;

    using context.state;
    using window_buffer;

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

find_first_control_code_in_range :: (window_buffer: *Window_Buffer, start: s64, end: s64) -> string {
    using context.state;
    using window_buffer;

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

find_all_control_codes_in_range :: (window_buffer: *Window_Buffer, start: s64, end: s64) -> ([] Control_Code_Info, total_string_length: s64) {
    using context.state;
    using window_buffer;

    assert(start <= end);
    assert(0 <= start && start <= only_text.count);
    assert(0 <= end && end <= only_text.count);

    find_first_control_code_in_range(window_buffer, start, end);

    first := control_codes_cursor;
    total_string_length := 0;
    while true {
        code := current_control_code(window_buffer);
        if !control_code_is_in_range(code, start, end) break;
        total_string_length += code.data.count;
        control_codes_cursor += 1;
    }

    return array_view(control_codes, first, control_codes_cursor - first), total_string_length;
}

find_all_control_codes_in_range :: (window_buffer: *Window_Buffer, range: string) -> ([] Control_Code_Info, total_string_length: s64) {
    using context.state;
    using window_buffer;

    start := range.data - only_text.data;
    end := start + range.count;
    codes, total_string_length := inline find_all_control_codes_in_range(window_buffer, start, end);
    return codes, total_string_length;
}

control_code_is_in_range :: inline (code: Control_Code_Info, start: int, end: int) -> bool {
    if !code.data return false;
    if code.position_in_text < start return false;
    if code.position_in_text > end return false;

    return true;
}

current_control_code :: inline (window_buffer: *Window_Buffer) -> Control_Code_Info {
    using context.state;
    using window_buffer;

    if control_codes_cursor > control_codes.count - 1 return .{};
    return control_codes[control_codes_cursor];
}

test_get_next_control_code_in_range :: () {
    text := "foo\e[31mbar\e[32mbaz\e[33mboobies\e[0m";

    using window_buffer: Window_Buffer;
    separate_control_codes(*window_buffer, text);

    print_vars(raw_text_and_control_codes, only_text, control_codes);

    cursor: int;
    start: int;
    end: int;

    do_test :: (start: int, end: int) #expand {
        using context.state;

        builder: String_Builder;

        print("[%..%]:\n", start, end);
        print(*builder, "<", start, end);
        cursor := start;
        for code: find_all_control_codes_in_range(*window_buffer, start, end) {
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

separate_control_codes :: (window_buffer: *Window_Buffer, raw_text: string) {
    using context.state;
    using window_buffer;

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
                // Expand any tab characters with spaces, because fuck tab characters,
                // all my homies use spaces
                t := head;
                while t {
                    found:, piece:, t = split_from_left(t, #char "\t");

                    // XXX: this shit is crazy! man is doing some retarded shit where it outputs
                    // `N\bNA\bAM\bME\bE` to mean `\e[1mNAME\e[0m` (which means
                    // bold). And same shit for underlined text.
                    // And now I have too deal with this....
                    Flush_Highlighted_Piece :: (count: *s64, start_code: string, end_code: string) #expand {
                        if count.* == 0 return;
                        array_add(*`control_codes, .{ `only_text_storage.count, xx start_code });
                        start := `piece.data + `cursor - count.* * 3;
                        // @Robustness: here we append every 3rd character, because this
                        // works for both bold (B\bBO\bOL\bLD\bD) and underline
                        // (_\bU_\bN_\bD_\bE_\bR...) the way `man` is using
                        // them, but this may not be enough for some other weirdos
                        for 0..count.*-1 array_add(*`only_text_storage, start[it * 3 + 2]);
                        array_add(*`control_codes, .{ `only_text_storage.count, xx end_code });
                        count.* = 0;
                    }
                    Flush_Regular_Piece :: () #expand {
                        if `regular_count == 0 return;
                        start := `piece.data + `cursor - `regular_count;
                        memcpy(`only_text_storage.data + `only_text_storage.count, start, `regular_count);
                        `only_text_storage.count += `regular_count;
                        `regular_count = 0;
                    }

                    bold_count := 0;
                    underline_count := 0;
                    regular_count := 0;
                    cursor := 0;
                    while cursor < piece.count {
                        if cursor <= piece.count - 3 && piece[cursor + 1] == #char "\x08" // '\b'
                            && piece[cursor] == piece[cursor + 2]
                        {
                            Flush_Regular_Piece();
                            Flush_Highlighted_Piece(*underline_count, "\e[4m", "\e[24m"); // underline mode
                            bold_count += 1;
                            cursor += 3;
                        } else if cursor <= piece.count - 3 && piece[cursor + 1] == #char "\x08" // '\b'
                            && piece[cursor] == #char "_"
                        {
                            Flush_Regular_Piece();
                            Flush_Highlighted_Piece(*bold_count, "\e[1m", "\e[22m"); // bold mode
                            underline_count += 1;
                            cursor += 3;
                        } else {
                            Flush_Highlighted_Piece(*bold_count, "\e[1m", "\e[22m"); // bold mode
                            Flush_Highlighted_Piece(*underline_count, "\e[4m", "\e[24m"); // underline mode
                            regular_count += 1;
                            cursor += 1;
                        }
                    }
                    Flush_Regular_Piece();
                    Flush_Highlighted_Piece(*bold_count, "\e[1m", "\e[22m"); // bold mode
                    Flush_Highlighted_Piece(*underline_count, "\e[4m", "\e[24m"); // underline mode

                    if found {
                        expanded_tab :: "        ";
                        memcpy(only_text_storage.data + only_text_storage.count, expanded_tab.data, expanded_tab.count);
                        only_text_storage.count += expanded_tab.count;
                    }
                }
            }
        }

        if !found break;
    }

    only_text = xx only_text_storage;
    line_offsets.count -= last_empty_lines_count;
}

scroll_string_with_control_codes :: (builder: *String_Builder, scrolling_text: string, offset: s64, max_width: s64) {
    started_codes: [..] string; started_codes.allocator = temp;

    visible_characters_skipped := 0;
    tail := scrolling_text;
    while tail {
        head:, visible_count:, tail = eat_visible_or_escape_sequence(tail);
        if visible_count == 0 {
            if is_mode_reset_control_sequence(head) {
                started_codes.count = 0;
            } else {
                array_add(*started_codes, head);
            }
        }

        visible_characters_skipped += visible_count;
        if visible_characters_skipped == offset break;

        overflow := visible_characters_skipped - offset;
        if overflow > 0 {
            tail.data -= overflow;
            tail.count += overflow;
            break;
        }
    }
    for started_codes append(builder, it);

    visible_budget := max_width;
    while tail {
        head:, visible_count:, tail = eat_visible_or_escape_sequence(tail);
        visible_budget -= visible_count;
        if visible_budget > 0 {
            append(builder, head);
        } else {
            overflow := -visible_budget;
            head.count -= overflow;
            append(builder, head);
            break;
        }
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

read_input :: () -> bool {
    using context.state;

    input_buffer.count = 0;
    while true {
        rc: = xx read(STDIN_FILENO, input_buffer.data + input_buffer.count,
                                   xx (input_buffer.allocated - input_buffer.count));
        if rc < 0 {
            code, message := System.get_error_value_and_string();
            if code != EAGAIN && code != EWOULDBLOCK {
                log_error("Failed reading from stdin: #% %", code, message);
            }
            return false;
        }

        input_buffer.count += rc;
        if input_buffer.count != input_buffer.allocated {
            return input_buffer.count != 0;
        }
        array_reserve(*input_buffer, input_buffer.allocated * 2);
    }
    return false;
}

Input_Event :: struct {
    char: u8;
    modifiers: enum_flags { ALT; CONTROL; SHIFT; };
    Kind :: enum {
        HANDLED; // -- not an event kind actually...
        CHARACTER;
        KEY_UP;
        KEY_DOWN;
        KEY_LEFT;
        KEY_RIGHT;
        MOUSE_WHEEL_UP;
        MOUSE_WHEEL_DOWN;
        MOUSE_LEFT_DOWN;
        MOUSE_RIGHT_DOWN;
        MOUSE_MIDDLE_DOWN;
        MOUSE_ANY_UP;
        MOUSE_LEFT_DRAG;
        MOUSE_RIGHT_DRAG;
        MOUSE_MIDDLE_DRAG;
        MOUSE_MOVE;
    };
    kind: Kind;
}

parse_and_handle_input :: () {
    using context.state;

    // log("input_buffer: \"%\"", cast(Ascii_Or_Hex) input_buffer);

    // for control codes
    builder: String_Builder; builder.allocator = temp;

    cursor := 0;
    while cursor < input_buffer.count {
        event: Input_Event;
        if (input_buffer[cursor] != #char "\e") || (cursor >= input_buffer.count - 1) {
            event.kind = .CHARACTER;
            event.char = input_buffer[cursor];
            // log("treating `%` as a character -> %", cast(Ascii_Or_Hex) substring(xx input_buffer, cursor, count=1), event);
            cursor += 1;
            handle_input_event(event);
            continue;
        }

        if input_buffer[cursor + 1] != #char "[" {
            // no a control sequence, probably just a ALT+<KEY>
            event.kind = .CHARACTER;
            event.char = input_buffer[cursor + 1];
            event.modifiers = .ALT;
            cursor += 2;
            // log("treating `\\x1b[` as ALT+'%' -> %", cast(Ascii_Or_Hex) substring(xx input_buffer, cursor + 1, count=1), event);
            handle_input_event(event);
            continue;
        }

        /* input_buffer[cursor + 1] == #char "[" */
        cursor += 2;
        // control sequence start (not including the "\x1b[")
        start := cursor;
        while cursor < input_buffer.count && !is_alpha(input_buffer[cursor]) {
            cursor += 1;
        }

        // Add the closing alpha character to the control sequence.
        if cursor < input_buffer.count then cursor += 1;

        if cursor == start {
            pretty_assert(cursor == input_buffer.count);
            // empty sequence means it's not a sequence, this could just be a ALT+'['
            event.kind = .CHARACTER;
            event.char = #char "[";
            event.modifiers = .ALT;
            // log("treating `\\x1b[` as ALT+'[' -> %", event);
            handle_input_event(event);
            continue;
        }

        sequence: string;
        sequence.data = input_buffer.data + start;
        sequence.count = cursor - start;
        if try_parse_sgr_mouse_control_sequence(sequence, *event) {
            // log("parsed a mouse event: `\\x1b[%` -> %", cast(Ascii_Or_Hex) sequence, event);
            // handled
        } else if try_parse_directional_key_sequence(sequence, *event) {
            // log("parsed a direction key event: `\\x1b[%` -> %", cast(Ascii_Or_Hex) sequence, event);
            // handled
        } else {
            // log("unparsed sequence: `\\x1b[%` -> %", cast(Ascii_Or_Hex) sequence, event);
            continue;
        }

        handle_input_event(event);
    }
}

try_parse_sgr_mouse_control_sequence :: (_sequence: string, event: *Input_Event) -> bool {
    using context.state;

    ok: bool;
    sequence := _sequence;
    if sequence[0] != #char "<" return false;
    advance(*sequence, 1);

    kind:, ok, sequence = string_to_int(sequence);
    if !ok return false;

    if sequence[0] != #char ";" return false;
    advance(*sequence, 1);

    column:, ok, sequence = string_to_int(sequence, T=s32);
    if !ok return false;

    if sequence[0] != #char ";" return false;
    advance(*sequence, 1);

    row:, ok, sequence = string_to_int(sequence, T=s32);
    if !ok return false;

    if sequence[0] == {
        case #char "m";
            event.kind = .MOUSE_ANY_UP;
            return true;
        case #char "M";
            // all's well
        case;
            return false;
    }

    // XXX: kind is actually a bit fields where
    // bit 3 is SHIFT, bit 4 is ALT, bit 5 is CONTROL, but
    // bit 6 means dragging,
    // bits 1 & 2 change meaning if bit 7 is set, and i'm not sure if bit 8 has
    // a meaning, so
    if kind == {
        case 0;  event.kind = .MOUSE_LEFT_DOWN;
        case 1;  event.kind = .MOUSE_MIDDLE_DOWN;
        case 2;  event.kind = .MOUSE_RIGHT_DOWN;

        case 8;  event.kind = .MOUSE_LEFT_DOWN;   event.modifiers = .ALT;
        case 9;  event.kind = .MOUSE_MIDDLE_DOWN; event.modifiers = .ALT;
        case 10; event.kind = .MOUSE_RIGHT_DOWN;  event.modifiers = .ALT;

        case 16; event.kind = .MOUSE_LEFT_DOWN;   event.modifiers = .CONTROL;
        case 17; event.kind = .MOUSE_MIDDLE_DOWN; event.modifiers = .CONTROL;
        case 18; event.kind = .MOUSE_RIGHT_DOWN;  event.modifiers = .CONTROL;

        case 32; event.kind = .MOUSE_LEFT_DRAG;
        case 33; event.kind = .MOUSE_MIDDLE_DRAG;
        case 34; event.kind = .MOUSE_RIGHT_DRAG;

        case 36; event.kind = .MOUSE_LEFT_DRAG;   event.modifiers = .SHIFT;
        case 37; event.kind = .MOUSE_MIDDLE_DRAG; event.modifiers = .SHIFT;
        case 38; event.kind = .MOUSE_RIGHT_DRAG;  event.modifiers = .SHIFT;

        case 40; event.kind = .MOUSE_LEFT_DRAG;   event.modifiers = .ALT;
        case 41; event.kind = .MOUSE_MIDDLE_DRAG; event.modifiers = .ALT;
        case 42; event.kind = .MOUSE_RIGHT_DRAG;  event.modifiers = .ALT;

        case 48; event.kind = .MOUSE_LEFT_DRAG;   event.modifiers = .CONTROL;
        case 49; event.kind = .MOUSE_MIDDLE_DRAG; event.modifiers = .CONTROL;
        case 50; event.kind = .MOUSE_RIGHT_DRAG;  event.modifiers = .CONTROL;

        case 64; event.kind = .MOUSE_WHEEL_DOWN;
        case 65; event.kind = .MOUSE_WHEEL_UP;

        case 68; event.kind = .MOUSE_WHEEL_DOWN;  event.modifiers = .SHIFT;
        case 69; event.kind = .MOUSE_WHEEL_UP;    event.modifiers = .SHIFT;

        case 72; event.kind = .MOUSE_WHEEL_DOWN;  event.modifiers = .ALT;
        case 73; event.kind = .MOUSE_WHEEL_UP;    event.modifiers = .ALT;

        case 76; event.kind = .MOUSE_WHEEL_DOWN;  event.modifiers = .ALT | .SHIFT;
        case 77; event.kind = .MOUSE_WHEEL_UP;    event.modifiers = .ALT | .SHIFT;

        case 80; event.kind = .MOUSE_WHEEL_DOWN;  event.modifiers = .CONTROL;
        case 81; event.kind = .MOUSE_WHEEL_UP;    event.modifiers = .CONTROL;

        case 84; event.kind = .MOUSE_WHEEL_DOWN;  event.modifiers = .CONTROL | .SHIFT;
        case 85; event.kind = .MOUSE_WHEEL_UP;    event.modifiers = .CONTROL | .SHIFT;

        case 88; event.kind = .MOUSE_WHEEL_DOWN;  event.modifiers = .ALT | .CONTROL;
        case 89; event.kind = .MOUSE_WHEEL_UP;    event.modifiers = .ALT | .CONTROL;

        case 92; event.kind = .MOUSE_WHEEL_DOWN;  event.modifiers = .ALT | .CONTROL | .SHIFT;
        case 93; event.kind = .MOUSE_WHEEL_UP;    event.modifiers = .ALT | .CONTROL | .SHIFT;

        case; return false;
    }

    mouse_position.row = row;
    mouse_position.column = column;
    return true;
}

try_parse_directional_key_sequence :: (sequence: string, event: *Input_Event) -> bool {
    kind: Input_Event.Kind;
    if sequence[sequence.count - 1] == {
        case #char "A"; kind = .KEY_UP;
        case #char "B"; kind = .KEY_DOWN;
        case #char "C"; kind = .KEY_RIGHT;
        case #char "D"; kind = .KEY_LEFT;
        case; return false;
    }
    if sequence.count == 1 {
        event.kind = kind;
        return true;
    }

    if sequence.count != 4         return false;
    if sequence[0]    != #char "1" return false;
    if sequence[1]    != #char ";" return false;
    if sequence[2] == {
        case #char "2"; event.modifiers = .SHIFT;
        case #char "3"; event.modifiers = .ALT;
        case #char "4"; event.modifiers = .ALT | .SHIFT;
        case #char "5"; event.modifiers = .CONTROL;
        case #char "6"; event.modifiers = .CONTROL | .SHIFT;
        case;           return false;
    }

    event.kind = kind;
    return true;
}

handle_input_event :: (_event: Input_Event) {
    using context.state;

    main_window_buffer := main_window_buffers[current_shown_buffer_index];

    event := _event;
    if event.kind == {
        case .MOUSE_WHEEL_UP;
            if event.modifiers & .SHIFT then col_offset += 8;
                                        else row_offset += 4;
                event.kind = .HANDLED;
        case .MOUSE_WHEEL_DOWN;
            if event.modifiers & .SHIFT then col_offset -= 8;
            else {
                row_offset -= 4;
                stick_to_the_bottom = false;
            }
            event.kind = .HANDLED;
        case .MOUSE_LEFT_DOWN;
            delayed_action = .MOUSE_SELECTION_CLICK;
            // log("delaying mouse selection click @ %", mouse_position);
            event.kind = .HANDLED;
    }

    next_input_mode := input_mode;
    if input_mode == {
        case .NAVIGATE;
            if event.kind == {
                case .CHARACTER; if event.char == {
                    case #char "j"; row_offset += 1;
                    case #char "k"; row_offset -= 1; stick_to_the_bottom = false;

                    case #char "d"; row_offset += terminal_size.rows / 2;
                    case #char "u"; row_offset -= terminal_size.rows / 2; stick_to_the_bottom = false;

                    case #char "t"; stick_to_the_bottom = !stick_to_the_bottom;

                    case #char "w"; line_wrapping = !line_wrapping;

                    case #char "g"; row_offset = 0; stick_to_the_bottom = false;
                    case #char "G"; {
                        row_offset = main_window_buffer.line_offsets.count - main_window_height;
                        stick_to_the_bottom = true;
                    }

                    case #char "0"; col_offset = 0;

                    case #char "h"; if !line_wrapping col_offset -= 4;
                    case #char "l"; if !line_wrapping col_offset += 4;

                    case #char "H"; if !line_wrapping col_offset -= terminal_size.cols / 2;
                    case #char "L"; if !line_wrapping col_offset += terminal_size.cols / 2;

                    case #char "/"; {
                        next_input_mode = .INPUT_SEARCH_STRING;
                        array_replace(*command_line, search_string_buffer);
                        input_cursor = command_line.count;
                        history_cursor = -1;
                        // turn off error message instantly
                        error_message_deadline = frame_time - 1;
                    }

                    case #char ";";
                        next_input_mode = .INPUT_COMMAND;
                        input_cursor = command_line.count;
                        history_cursor = -1;
                        // turn off error message instantly
                        error_message_deadline = frame_time - 1;

                    case #char "n"; jump_to_next_search_match();
                    case #char "N"; jump_to_previous_search_match();

                    case #char "c"; strip_control_codes = !strip_control_codes;

                    case #char "q"; should_exit = true;
                }
            }

            row_offset = max(row_offset, -(main_window_height - 1));
            row_offset = min(row_offset, main_window_buffer.line_offsets.count - 1);

            col_offset = max(col_offset, -(cast(int) terminal_size.cols - 1));
            col_offset = min(col_offset, main_window_buffer.max_line_length - 1);

        case .INPUT_SEARCH_STRING; #through;
        case .INPUT_COMMAND;

            if !(event.modifiers & .ALT) && event.char >= #char " " && event.char <= #char "~" {
                array_insert_at(*command_line, event.char, input_cursor);
                input_cursor += 1;
            } else if event.char == {
                case #char "\e"; /* ESCAPE */
                    history_cursor = -1;
                    next_input_mode = .NAVIGATE;

                case #char "\n"; /* ENTER */
                    history := get_history_for_input_mode();
                    if command_line && (!history.count || cast(string) command_line != history.*[history.count - 1]) {
                        array_add(history, copy_string(xx command_line));
                    }
                    if input_mode == .INPUT_COMMAND {
                        execute_command(xx command_line);
                        command_line.count = 0;
                    }
                    history_cursor = -1;
                    next_input_mode = .NAVIGATE;

                case #char "\x10"; /* CTRL+P */ history_previous();
                case #char "\x0e"; /* CTRL+N */ history_next();

                case #char "\x02"; /* CTRL+B */ move_command_line_cursor_left();
                case #char "\x06"; /* CTRL+F */ move_command_line_cursor_right();
                case #char "\x01"; /* CTRL+A */ input_cursor = 0;
                case #char "\x05"; /* CTRL+E */ input_cursor = command_line.count;

                case #char "b"; if event.modifiers & .ALT /* ALT+B */ move_command_line_cursor_left_a_word();
                case #char "f"; if event.modifiers & .ALT /* ALT+F */ move_command_line_cursor_right_a_word();

                case #char "\x09"; /* CTRL+I or TAB */
                    if input_mode == .INPUT_COMMAND {
                        complete_command();
                    } else if input_mode == .INPUT_SEARCH_STRING {
                        // TODO: complete identifiers in the fucking text yo,
                        // give priority to the ones on the fucking screen.
                        // This would be a fucking geanious feature
                    }

                case #char "\x08"; /* CTRL+H */ #through;
                case #char "\x7f"; /* BACKSPACE */
                    if command_line.count > 0 && input_cursor > 0 {
                        array_ordered_remove_range(*command_line, input_cursor - 1, input_cursor);
                        input_cursor -= 1;
                    } else {
                        next_input_mode = .NAVIGATE;
                    }

                case #char "\x04"; /* CTRL+D */
                    if command_line.count > 0 && input_cursor < command_line.count {
                        array_ordered_remove_range(*command_line, input_cursor, input_cursor + 1);
                    }

                case #char "\x0b"; /* CTRL+K */
                    if command_line.count > 0 && input_cursor < command_line.count {
                        array_ordered_remove_range(*command_line, input_cursor, command_line.count);
                    }

                case #char "\x17"; /* CTRL+W */
                    delete_word_before_command_line_cursor();

                case #char "\x15"; /* CTRL+U */ {
                    command_line.count = 0;
                    input_cursor = 0;
                }
            }
            if event.modifiers & .CONTROL {
                if event.kind == {
                    case .KEY_LEFT;  move_command_line_cursor_left_a_word();
                    case .KEY_RIGHT; move_command_line_cursor_right_a_word();
                }
            } else {
                if event.kind == {
                    case .KEY_LEFT;  move_command_line_cursor_left();
                    case .KEY_RIGHT; move_command_line_cursor_right();
                    case .KEY_UP;    history_previous();
                    case .KEY_DOWN;  history_next();
                }
            }

            if input_mode == .INPUT_SEARCH_STRING {
                search_string_buffer.count = 0;
                array_add(*search_string_buffer, ..command_line);
                search_string = xx search_string_buffer;
            }

            if next_input_mode == .NAVIGATE {
                command_line.count = 0;
            }
    }

    // Set the actual input mode at the end so that it doesn't interfere with other stuff
    input_mode = next_input_mode;
}

move_command_line_cursor_left :: () {
    using context.state;
    if input_cursor > 0 then input_cursor -= 1;
}

move_command_line_cursor_right :: () {
    using context.state;
    if input_cursor < command_line.count then input_cursor += 1;
}

move_command_line_cursor_left_a_word :: () {
    using context.state;

    if !command_line return;
    if input_cursor == 0 return;

    string_before_cursor := cast(string) command_line;
    string_before_cursor.count = input_cursor;
    string_before_cursor = trim_right(string_before_cursor);
    index := find_index_from_right(string_before_cursor, #char " ");
    if index == -1 {
        input_cursor = 0;
        return;
    }
    // Put cursor to the right of the space
    input_cursor = index + 1;
}

move_command_line_cursor_right_a_word :: () {
    using context.state;

    if !command_line return;
    if input_cursor == command_line.count return;

    index := find_index_from_left(xx command_line, #char " ", input_cursor);
    if index == -1 {
        input_cursor = command_line.count;
        return;
    }

    // Skip all spaces
    while command_line[index] == #char " " {
        index += 1;
        if index == command_line.count break;
    }

    input_cursor = index;
}

delete_word_before_command_line_cursor :: () {
    using context.state;

    if !command_line return;
    if input_cursor == 0 return;

    string_before_cursor := cast(string) command_line;
    string_before_cursor.count = input_cursor;

    // skip any whitespace before the cursor
    while string_before_cursor.count && string_before_cursor[string_before_cursor.count - 1] == #char " "
        string_before_cursor.count -= 1;

    to_delete_from := find_index_from_right(string_before_cursor, #char " ");
    if to_delete_from == -1 then to_delete_from = 0;

    // leave the space before the deleted word
    if to_delete_from != 0 && to_delete_from != command_line.count - 1
        to_delete_from += 1;

    array_ordered_remove_range(*command_line, to_delete_from, input_cursor);
    input_cursor = to_delete_from;
}

//
// command line key handling procs
//

get_history_for_input_mode :: () -> *[..] string {
    using context.state;

    if input_mode == {
        case .INPUT_COMMAND;        return *command_line_history;
        case .INPUT_SEARCH_STRING;  return *search_string_history;
    }
    return null;
}

history_previous :: () {
    using context.state;

    history := get_history_for_input_mode();

    if history_cursor == -1 {
        free(history_stash);
        history_stash = copy_string(xx command_line);
        history_cursor = history.count;
    }
    if history_cursor > 0 {
        history_cursor -= 1;
        command_line.count = 0;
        array_replace(*command_line, history.*[history_cursor]);
        input_cursor = command_line.count;
    }
}

history_next :: () {
    using context.state;

    history := get_history_for_input_mode();

    if history_cursor == -1 return;
    if history_cursor < history.count - 1 {
        history_cursor += 1;
        command_line.count = 0;
        array_replace(*command_line, history.*[history_cursor]);
        input_cursor = command_line.count;
    } else {
        history_cursor = -1;
        command_line.count = 0;
        array_replace(*command_line, history_stash);
        input_cursor = command_line.count;
    }
}

//
// navigate mode key handling procs
//

jump_to_next_search_match :: () {
    using context.state;
    using main_window_buffers[current_shown_buffer_index];

    if row_offset == line_offsets.count - 1 return; // no next match possible

    start_offset := ifx row_offset >= 0 then row_offset + 1 else 0;
    search_start := line_offsets[start_offset];

    index := find_index_from_left(only_text, search_string, search_start);
    if index == -1 return; // match not found

    if row_offset < 0 then row_offset = 0;
    while row_offset < line_offsets.count {
        if line_offsets[row_offset] > index { // overshot by 1 line
            if row_offset > 0 row_offset -= 1;
            return;
        }

        row_offset += 1;
    }
}

jump_to_previous_search_match :: () {
    using context.state;
    using main_window_buffers[current_shown_buffer_index];

    if row_offset == 0 return; // no previous match possible

    search_end := line_offsets[ifx row_offset >= 0 then row_offset];

    search_region := substring(only_text, 0, search_end);
    index := find_index_from_right(search_region, search_string);

    if index == -1 return; // match not found

    stick_to_the_bottom = false;

    while row_offset >= 0 {
        if line_offsets[row_offset] < index {
            return;
        }

        row_offset -= 1;
    }
}

//
// commands
//

Command :: struct {
    name: string;
    type: Type_Info_Procedure;
    proc_wrapper: (args: .. Any) -> (bool, string);
}

make_command :: (name: string, $proc: Code) -> Command #expand {
    #insert #run -> string {
        builder: String_Builder;
        defer free_buffers(*builder);

        print(*builder, #string CODE

proc_wrapper :: (args: .. Any) -> (ok: bool, error_message: string) {

        CODE);

        proc_name: string;

        base_code := compiler_get_nodes(proc);
        if base_code.kind == .IDENT {
            code := cast(*Code_Ident) base_code;
            assert(code.type.type == .PROCEDURE);
            proc_name = code.name;
        } else {
            proc_name = "unique_proc_name";
            print(*builder, "% := ", proc_name);
            print_expression(*builder, base_code);
            append(*builder, ";");
        }

        type := cast(*Type_Info_Procedure) base_code.type;
        for type.argument_types {
            print(*builder, #string CODE

    arg_%1 := << cast(* %2) args[%1].value_pointer;

            CODE, it_index, get_type(it));
        }

        print(*builder, "ok, error_message := %(", proc_name);
        for type.argument_types print(*builder, "arg_%, ", it_index);
        print(*builder, ");");

        print(*builder, #string CODE

    return ok, error_message;
}

        CODE);

        return builder_to_string(*builder);
    };

    return Command.{
        name = name,
        type = type_info(type_of(#insert proc)),
        proc_wrapper = proc_wrapper,
    };
}

execute_command :: (command_line: string) {
    using,except.["command_line", "command"] context.state;

    tail := command_line;
    command_name, ok := parse_token(*tail);
    if !ok return;

    command: *Command;
    for *commands {
        if it.name == command_name {
            command = it;
            break;
        }
    }

    if !command {
        set_error_message("unknown command `%`", command_name);
        return;
    }

    argument_types := command.type.argument_types;
    args: [..] Any; args.allocator = temp;
    array_reserve(*args, argument_types.count);

    for argument_types {
        arg := array_add(*args);
        arg.type = it;
        arg.value_pointer = talloc(arg.type.runtime_size);

        tail = trim_left(tail);
        if argument_types.count == 1 && arg.type == type_info(string) {
            (cast(*string) arg.value_pointer).* = tail;
            break;
        }

        value_string := tail;
        // TODO: for strings it requires the thing to be surrounded with double quotes.
        // Instead it should consume any sequence until whitespace
        ok := set_value_from_string(arg.*, *tail);
        value_string.count -= tail.count;

        if !ok {
            value_string = trim(value_string);
            if !value_string then value_string = trim(tail);

            if !value_string {
                set_error_message("expected % arguments, but got only %", argument_types.count, args.count - 1); // `- 1` cause an empty slot was already added
                return;
            }

            set_error_message("'%' is not a valid argument #%, expected a %", value_string, it_index + 1, type_to_string(arg.type));
            return;
        }
    }

    ok=, error_message := command.proc_wrapper(..args);
    if !ok {
        set_error_message("%", error_message);
        return;
    }
}

complete_command :: () {
    using context.state;

    if input_cursor != command_line.count {
        // TODO: could do something smarter here
        return;
    }

    if command_line.count == 0 return;

    // TODO: pressing TAB once starts COMMAND_COMPLETION input mode in which
    // the completion list is diplayed on the screen and pressing ctrl+p/ctrl+n
    // (or even arrows if you're into that) iterates over the list.
    // Pressing any character key exits completion mode into INPUT_COMMAND mode
    // Moving the cursor also exits completion mode
    // Pressing enter runs the command
    for commands {
        if !starts_with(it.name, xx command_line) continue;

        command_line.count = 0;
        array_replace(*command_line, it.name);
        input_cursor = command_line.count;
        return;
    }

    // If it's a `> command ` insert the current external command for editting
    if command_line[command_line.count - 1] == #char " " && trim(xx command_line) == "command" {
        for 0..command.count-2 {
            array_add(*command_line, ..cast([] u8) command[it]);
            array_add(*command_line, #char " ");
        }
        array_add(*command_line, ..cast([] u8) command[command.count - 1]);
        input_cursor = command_line.count;
        return;
    }
}

set_error_message :: (format: string, args: .. Any) {
    using context.state;

    reset(*error_message_builder);
    print(*error_message_builder, format, ..args);
    error_message_deadline = frame_time + 3;
} @PrintLike

//
// command procs
//

commands: [..] Command;
init_commands :: () {
    if !commands {
        array_add(*commands, make_command("period", change_command_rerun_period));
        array_add(*commands, make_command("interval", change_command_rerun_period));
        array_add(*commands, make_command("command", set_external_command));
        array_add(*commands, make_command("log", set_log_file));
        array_add(*commands, make_command("memory_usage", make_toggle("show_memory_usage")));
        array_add(*commands, make_command("strip_control_codes", make_toggle("strip_control_codes")));
        array_add(*commands, make_command("number_lines", make_toggle("line_numberring")));
        array_add(*commands, make_command("line_numberring", make_toggle("line_numberring")));
        array_add(*commands, make_command("wrap_lines", make_toggle("line_wrapping")));
        array_add(*commands, make_command("line_wrapping", make_toggle("line_wrapping")));
        array_add(*commands, make_command("visualize_control_codes", make_toggle("visualize_control_codes")));
    }
}

change_command_rerun_period :: (time: float32) -> (ok: bool, error_msg: string) {
    using context.state;

    if time <= 0.0001 return false, "value must not be less than 0.0001";

    command_run_period_seconds = time;
    return true, "";
}

set_external_command :: (new_command: string) -> (ok: bool, error_message: string) {
    using context.state;

    for command free(it);
    command.count = 0;
    // FIXME: probably want to split the command and do some special character escaping
    array_add(*command, copy_string(new_command));
    time_next_command_run = frame_time;
    main_window_source = .EXTERNAL_COMMAND;
    return true, "";
}

set_log_file :: (new_log_file: string) -> (ok: bool, error_message: string) {
    using context.state;

    if find_index_from_left(new_log_file, #char " ") != -1 {
        return false, "log filename can't contain spaces";
    }

    if log_file_name == new_log_file return false, "nothing changed";

    free(log_file_name);
    log_file_name = new_log_file;

    if log_file.handle file_close(*log_file);

    log_file=, ok := file_open(log_file_name, for_writing = true, keep_existing_content = true, log_errors = false);
    if !ok {
        code, message := System.get_error_value_and_string();
        return false, tprint("open('%'): (%) %", new_log_file, code, message);
    }
    log_file = log_file;
    return true, "";
}

Toggle_Field_Callback :: #type () -> (bool, string);

make_toggle :: ($field: string) -> Toggle_Field_Callback #expand {
    #insert #run -> string {
        builder: String_Builder;
        defer free_buffers(*builder);

        print(*builder, #string CODE

proc :: () -> (bool, string) {
    using context.state;

    %1 = !%1;
    return true, "";
}

        CODE, field);
        return builder_to_string(*builder);
    };

    return proc;
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

    builder: String_Builder;
    print_date_time_for_log(*builder, to_calendar(current_time_consensus(), .LOCAL));
    print(*builder, ": %\n", message);
    file_write(*state.log_file, builder_to_string(*builder,, temp));
    fflush(state.log_file.handle);
}

//
// string utilities
//

Ascii_Or_Hex :: #type,isa string;

ascii_or_hex_printer :: (builder: *String_Builder, any: Any, struct_printer_data: *void) -> bool {
    if any.type != type_info(Ascii_Or_Hex) return false;

    s := << cast(*string) any.value_pointer;
    print_ascii_or_hex(builder, s);

    return true;
}

to_string :: (builder: *String_Builder) -> string {
    buffer := get_base_buffer(builder);
    assert(buffer == get_current_buffer(builder), "should've used builder_to_string this time");
    return to_string(get_buffer_data(buffer), buffer.count);
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

// TODO: come up with a better name
array_replace :: inline (a: *[..] u8, b: string) {
    a.count = 0;
    array_add(a, ..cast([] u8)b);
}

// TODO: come up with a better name
array_replace :: inline (a: *[..] u8, b: [] u8) {
    a.count = 0;
    array_add(a, ..b);
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

//
// terminal settings
//

restore_terminal_settings :: () {
    using context.state;
    // could copy the strings, but don't wanna
    teardown_control_codes: [..] string;
    for setup_control_codes array_add(*teardown_control_codes, copy_string(it));
    for teardown_control_codes {
        last_char := *it[it.count - 1];
        if last_char.* == {
            case #char "l"; last_char.* = #char "h";
            case #char "h"; last_char.* = #char "l";
            case; assert(false, "%: %", it_index, it);
        }
    }
    write_strings(..teardown_control_codes);

    tcsetattr(STDIN_FILENO, TCSADRAIN, *context.state.saved_termios);
}

//
// terminfo
//

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
// formatting utilities
//

fmt :: inline (v: float64, digits_after_comma := -1, keep_zero := false) -> FormatFloat #expand {
    return FormatFloat.{ value = v, trailing_width = digits_after_comma, zero_removal = ifx keep_zero then .NO else .YES };
}

fmt :: inline (v: s64, minimum_digits := 1, $padding := "0") -> FormatInt #expand {
    #assert(padding.count == 1);
    return FormatInt.{ value = v, minimum_digits = minimum_digits, padding = padding[0] };
}

#import "Basic"()(MEMORY_DEBUGGER=true);
#import "Hash_Table";
#import "My_Util";
#import "Process";
#import "String";
#import "POSIX";
#import "Linux";
#import "System";
#import "File";
#import "Flat_Pool";
#import "Print_Vars";
#import "Reflection";
#import "Program_Print";
#if OS == .LINUX #import "X11";
#import "Clipboard";
System :: #import "System";
