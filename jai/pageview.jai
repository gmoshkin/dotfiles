/* TODO:
  - FIX A BUG in completion where . is not being added
  - completion menu scrolling

  - command to save the current buffer and show diffs (maybe even in split view)
      although I can just use the tmux splits for that....

  - optimize parsing the input stream. Currently I read the whole buffer in and
    parse it all together, but then I only show a small portion of that, this sucks.
    `git log -p` doesn't work because of that. Potential solutions:
    - parse stream in chunks, don't reparse chunks if they didn't change
    - don't parse further than needed. Although my search command relies on the
      whole input being parsed which sucks, should rework it also

  - option to watch a file/directory for changes and only rerun the command then
    Some use cases for that:
        - lightweight LSP alternative `pageview --watch src/ 'jai src/myprogram.jai'`
        - ?

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
    debug := false;
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
    delayed_actions: [..] Delayed_Action;

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
    input_received_this_tick: bool;

    f_repeat_count: s64;

    completion_menu: Completion_Menu;

    //
    // command line history
    //
    history_filepath: string;

    //
    // status lines
    //
    frame_time: float64;
    info_message_color: string;
    info_message_builder: String_Builder;
    info_message_deadline: float64 = -1.0;
    status_scroll_interval_seconds := 0.1;
    next_status_scroll_time : float64 = -1.0;
    before_scroll_time_seconds : float64 = 2.0;
    current_command_string_scroll_offset := 0;

    //
    // http server
    //
    http_server_enabled := false;
    http_server: Http_Server_State;

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
        PIPED_INPUT;
        DRAWING_MODE;
        // TODO: FILE;
    }

    //
    // source: PIPED_INPUT
    //
    piped_input_builder: String_Builder;
    piped_input_fd: s32 = -1;
    parent_process_command_line: [] string;
    started_reading_piped_input: f64;

    //
    // source: EXTERNAL_COMMAND
    //
    command: [..] string;

    external_command_process: Process;
    external_command_started: float64;
    external_command_output_builder: String_Builder;
    external_command_error_builder: String_Builder;

    external_command_finished_count: u64;
    external_command_last_handled_output_version: u64;

    external_command_run_period_seconds := 1.0;
    time_next_command_run : float64 = -1.0;
    last_command_result: Process_Result;
    last_command_finish: float64 = -1.0;
    last_command_duration: float64 = -1.0;
    second_to_last_command_finish: float64 = -FLOAT64_INFINITY;

    anti_flicker_period: float64 = 0.2;

    //
    // source: DRAWING_MODE
    //
    pixel_buffer: [..] Vector4;
    pixel_window_size: Vector2;
    pixel_size: enum {
        TWO_CHARACTERS;
    };

    //
    // rendering
    //
    redraw_once := false;
    main_window_buffer_history: [..] Window_Buffer;
    current_shown_buffer_index: s64;
    show_latest_buffer := true;

    selection_cursor := -1;
    last_selected_string: string;

    current_screen_row: s64;
    current_row_left_offset: s64; // XXX: this name sucks
    current_line_number: s64;

    // Stores pointers into `last_shown_line_buffer_flat_pool`.
    last_shown_line_buffer: [..] string;
    last_shown_line_buffer_version: s64;
    target_fps: s32 = 60;
    time_last_shown: float64;
    memory_pool_for_last_shown_line_buffer: Flat_Pool;
    memory_pool_for_last_shown_line_buffer_high_water_mark: s64;

    temporary_storage_memory_pool: Flat_Pool;
    temporary_storage_high_water_mark: s64;

    //
    // copy to clipboard (tmux currently)
    //
    children_for_copying_to_clipboard: [..] struct { process: Process; name: string; };

    //
    // stupid sexy particles
    //
    party_time: bool;
    party_time_update_period := 0.1;
    party_time_next_update_time: float64;
    Particle_Info :: struct {
        using position: Vector2;
        ansi_color: string;
        animation_offset: u64;
    }
    particles: [..] Particle_Info;
    tick : u64 = 0;
    color_range: [..] string;

    //
    // miscellaneous internals
    //
    default_allocated_high_water_mark : s64;
    tty_name: string;

    epoll_fd: s32;
    epoll_events: [..] epoll_event;
}
#add_context state: State;

Delayed_Action :: struct {
    type: enum {
        MOUSE_SELECTION_CLICK;
    };
}

Cell_Position :: struct {
    row: s32;
    column: s32;
}

Window_Buffer :: struct {
    index_in_history: s64;
    time_generated: Apollo_Time;
    duration: f64;
    hash: U128;
    source: type_of(State.main_window_source);

    raw_text_and_control_codes: string;
    last_line_offset_in_raw_text: s64;

    only_text_storage: [..] u8; // allocated separately
    only_text: string; // points into `only_text_storage`

    line_offsets: [..] s64; // offsets into `only_text`
    max_line_length: s64;

    control_codes: [..] Control_Code_Info; // offsets into `only_text`, data into `raw_text_and_control_codes`
    control_codes_cursor: s64;
    unique_control_codes: [..] Small_Bytes;
}

Control_Code_Info :: struct {
    position_in_text: s64;
    using bytes: Small_Bytes;
}
#assert size_of(Control_Code_Info) == 24;

control_code_string :: inline (using code: *Control_Code_Info) -> string {
    return to_string(code.bytes);
}

make_control_code_info :: inline (position: s64, data: string) -> Control_Code_Info {
    result: Control_Code_Info = ---;
    result.position_in_text = position;
    result.bytes = make_small_bytes(data);
    return result;
}

Completion_Menu :: struct {
    items: [..] string;
    displayed_items: [..] string;
    builder_for_items: String_Builder;
    common_item_prefix: string;

    selected_item: s64;
    // TODO: add the fucking scrollbar already

    is_active: bool;
    completion_insert_offset: s64;

    start_row: s64;
    start_column: s64;
    width: s64;
    height: f32;
}

main :: () {
    // Setup struct_printer
    my_struct_printer_data := New(My_Struct_Printer_Data);
    array_add(*my_struct_printer_data.variant_printers, .{ type_info(Ascii_Or_Hex), ascii_or_hex_printer });
    array_add(*my_struct_printer_data.variant_printers, .{ type_info(Human_Readable_Memory), human_readable_memory_printer });
    array_add(*my_struct_printer_data.variant_printers, .{ type_info(Mem_Dump), mem_dump_printer });
    array_add(*my_struct_printer_data.variant_printers, .{ type_info(Small_Bytes), small_bytes_printer });

    context.print_style.struct_printer = my_struct_printer;
    context.print_style.struct_printer_data = my_struct_printer_data;

    // test_get_next_control_code_in_range();
    // return;

    args := get_command_line_arguments();

    state := *context.state;

    {
        log_file_name := getenv("PAGEVIEW_LOG_FILENAME");
        if log_file_name
            state.log_file_name = copy_string(to_string(log_file_name));

        if getenv("PAGEVIEW_DEBUG") {
            state.debug = true;
        }
    }

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

            case "-d"; #through;
            case "--draw";
                state.main_window_source = .DRAWING_MODE;

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
                state.external_command_run_period_seconds = seconds;

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

            case "--listen";
                cursor += 1;
                if cursor >= args.count {
                    print("Expected a port number after '%'\n", arg);
                    exit(1);
                }
                port, ok, remainder := string_to_int(args[cursor]);
                if !ok || remainder != "" {
                    print("Expected a port number after '%', got '%'\n", arg, args[cursor]);
                    exit(1);
                }
                if port > U16_MAX {
                    print("Port number % is out of range, must not be greater than %\n", port, U16_MAX);
                    exit(1);
                }
                state.http_server.listen_port = xx port;
                state.http_server_enabled = true;

            // TODO: a flag to just watch a file's contents, so I don't have to
            // do `cat filename`

            case "--debug";
                state.debug = true;

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
        using state;
        if command {
            if command.count == 1 && find_index_from_left(command[0], #char " ") != -1 {
                array_insert_at(*command, "/bin/sh", 0);
                array_insert_at(*command, "-c", 1);
            }

            args := NewArray(command.count, *u8);
            for command args[it_index] = to_c_string(it);
            execvp(command[0].data, args.data);
            code, message := get_error_value_and_string();
            print("execvp(%) failed: [%] %\n", command, code, message);
            exit(1);
        }

        print("Why would you redirect the output whithout even specifying a command?\n");
        exit(1);
    }

    // Read history file
    read_history_file();

    // Choose input source
    if !isatty(STDIN_FILENO) {
        state.main_window_source = .PIPED_INPUT;
        log("main window source is stdin");
    } else if state.main_window_source == .NONE {
        if state.command {
            state.main_window_source = .EXTERNAL_COMMAND;
            log("main window source is external command: %", state.command);
        } else {
            print("Specify a command to run or pipe in some text on the stdin\n");
            exit(1);
        }
    }

    // Initialize X11 for the clipboard, which doesn't fucking work, of course it doesn't, why would anything ever work?
    // #if OS == .LINUX {
    //     if getenv("DISPLAY") init_global_display();
    // }

    // Initialize command
    init_commands();

    // Setup signal handlers
    signal(SIGINT, shutdown_signal_handler);
    signal(SIGTERM, shutdown_signal_handler);
    signal(SIGWINCH, window_size_changed_signal_handler);

    // Reconfigure stdin to work properly
    if state.main_window_source == .PIPED_INPUT {
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
        piped_input_fd = dup(STDIN_FILENO);
        assert(piped_input_fd >= 0);
        flags := fcntl(piped_input_fd, F_GETFL);
        flags |= O_NONBLOCK;
        rc := fcntl(piped_input_fd, F_SETFL, flags);
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

    // if debug then getchar();

    // Get terminal size
    rc := ioctl(STDIN_FILENO, TIOCGWINSZ, *state.terminal_size);
    assert(rc == 0);

    // Completion menu depends on termnal_size
    init_completion_menu();

    // `- 2` for :2_status_lines
    state.main_window_height = state.terminal_size.rows - 2;

    // Setup terminal mode, after this exitting should be done via term_exit
    init_terminal_settings();

    // Make stdin non blocking
    {
        flags := fcntl(STDIN_FILENO, F_GETFL);
        flags |= O_NONBLOCK;
        rc := fcntl(STDIN_FILENO, F_SETFL, flags);
        assert(rc != -1);
    }

    // Setup epoll
    {
        using state;
        epoll_fd = epoll_create(1);
        assert(epoll_fd != -1);

        array_reserve(*epoll_events, 16);
        for 1..epoll_events.allocated array_add(*epoll_events, .{});

        event: epoll_event;

        event.events = EPOLLIN;
        event.data.fd = STDIN_FILENO;
        rc = epoll_ctl(epoll_fd, .ADD, STDIN_FILENO, *event);
        assert(rc == 0);

        if main_window_source == .PIPED_INPUT {
            event.events = EPOLLIN;
            event.data.fd = piped_input_fd;
            rc = epoll_ctl(epoll_fd, .ADD, piped_input_fd, *event);
            assert(rc == 0);
        }
    }

    // Initialize http server (must go after epoll, because we use the epoll_fd)
    if state.http_server_enabled {
        if !init_http_server() {
            log_last_error(.WITH_STACK_TRACE);
        }
    }

    // Initialize status lines
    status_line_init();

    // Initialize input
    array_reserve(*state.input_buffer, 4096);

    first_time := true;
    last_frame_time := -FLOAT64_INFINITY;
    profile_t0 = seconds_since_init();
    while !should_exit {
        defer first_time = false;
        using state;
        reset(*error_log_builder);

        // Wait for events
        timeout: s32 = 1000 / target_fps;
        if first_time then timeout = 0;

        Profile();

        // Update main window buffer from the current source
        if state.main_window_source == {
            case .EXTERNAL_COMMAND;
                maybe_spawn_external_command();

            case .DRAWING_MODE;
                if !pixel_buffer resize_pixel_buffer();
        }

        Profile();

        rc := epoll_wait(epoll_fd, epoll_events.data, xx epoll_events.allocated, timeout);
        if rc == -1 {
            code := errno();
            assert(code == EINTR, "%", code);
        }

        profile_t0 = seconds_since_init();
        Profile();

        frame_time = seconds_since_init();
        elapsed_ms := 1000 * (frame_time - last_frame_time);
        // if elapsed_ms < min_period {
        //     sleep_milliseconds(xx (min_period - elapsed_ms));
        // }
        last_frame_time = frame_time;

        Profile();

        epoll_events.count = rc;

        input_received_this_tick = false;

        // Handle IO events
        external_command_ready := false;
        external_command_output_closed := false;
        external_command_error_closed := false;
        for epoll_events {
            if it.data.fd == STDIN_FILENO {
                input_received_this_tick = read_input();
                // TODO: do I wanna do something about EPOLLHUP on stdin?
            } else if it.data.fd == piped_input_fd {
                if it.events & EPOLLIN  read_some_from_piped_input();
                if it.events & EPOLLHUP handle_piped_input_end();
            } else if it.data.fd == external_command_process.output.handle {
                external_command_ready = true;
                external_command_output_closed ||= xx it.events & EPOLLHUP;
            } else if it.data.fd == external_command_process.error.handle {
                external_command_ready = true;
                external_command_error_closed ||= xx it.events & EPOLLHUP;
            } else {
                ok, handled := tcp_server_handle_epoll_event(*http_server, it);
                if !ok  log_last_error(.WITH_STACK_TRACE);
                if !handled
                    log("unknown fd %: %", it.data.fd, cast(Epoll_Events) it.events);
            }
        }

        Profile();

        if external_command_ready {
            read_some_from_external_command(external_command_output_closed, external_command_error_closed);
        }

        Profile();

        // Update main window buffer from the current source
        if state.main_window_source == {
            case .EXTERNAL_COMMAND;
                maybe_handle_external_command_output();
        }

        Profile();

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

            if main_window_source == .DRAWING_MODE resize_pixel_buffer();

            row_offset = max(row_offset, -(main_window_height - 1));
        }

        // Handle input
        state.delayed_actions.count = 0;
        if input_received_this_tick {
            parse_and_handle_input();
        }

        main_window_buffer: *Window_Buffer;
        if main_window_buffer_history {
            main_window_buffer = *main_window_buffer_history[current_shown_buffer_index];
            // FIXME: this doesn't work in line-wrapping mode
            if stick_to_the_bottom {
                row_offset = max(row_offset, main_window_buffer.line_offsets.count - main_window_height);
            }
        }


        Profile();

        render_status_line_1();

        Profile();

        //
        // Main window
        //

        line_buffer: [] string; // temporary storage
        if #complete main_window_source == {
            case .EXTERNAL_COMMAND; #through;
            case .PIPED_INPUT;
                line_buffer = build_line_buffer_for_main_window(main_window_buffer);

            case .DRAWING_MODE;
                line_buffer = build_line_buffer_for_pixel_buffer();

            case .NONE;
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

        now := seconds_since_init();
        min_period := 1.0 / target_fps;
        its_time := now - time_last_shown > min_period;

        if its_time && changed || redraw_once {
            time_last_shown = now;
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
            last_shown_line_buffer_version += 1;
            memory_pool_for_last_shown_line_buffer_high_water_mark = max(memory_pool_for_last_shown_line_buffer_high_water_mark, flat_pool_allocated(*memory_pool_for_last_shown_line_buffer));
        }

        Profile();

        maybe_render_completion_menu();

        Profile();

        //
        // second status line
        //
        render_status_line_2();

        Profile();

        // memory usage window
        if show_memory_usage
        {
            // prepare table rows
            rows: [..] [2] string;
            array_add(*rows, .["temp:", tprint("% [hvm: %]",
                                               cast(Human_Readable_Memory) context.temporary_storage.total_bytes_occupied,
                                               cast(Human_Readable_Memory) temporary_storage_high_water_mark)]);
            array_add(*rows, .["buffer pool:", tprint("% [hvm: %]",
                                                      cast(Human_Readable_Memory) flat_pool_allocated(*memory_pool_for_last_shown_line_buffer),
                                                      cast(Human_Readable_Memory) memory_pool_for_last_shown_line_buffer_high_water_mark)]);

            buffer_history_raw_text_bytes := 0;
            buffer_history_the_rest_bytes := 0;
            for *main_window_buffer_history {
                buffer_history_raw_text_bytes += it.raw_text_and_control_codes.count;
                buffer_history_the_rest_bytes += size_of(Window_Buffer);
                buffer_history_the_rest_bytes += it.only_text_storage.allocated;
                buffer_history_the_rest_bytes += it.control_codes.allocated;
                buffer_history_the_rest_bytes += it.line_offsets.allocated;
            }

            array_add(*rows, .["text history:", tprint("%", cast(Human_Readable_Memory) buffer_history_raw_text_bytes)]);
            array_add(*rows, .["total history:", tprint("%", cast(Human_Readable_Memory) (buffer_history_raw_text_bytes + buffer_history_the_rest_bytes))]);

            // TODO: the builtin Memory_Debugger is too expensive, it seems that
            // it expects to only be called once per program execution (or maybe
            // a few times), but not every frame? Or there's the wire protocol
            // for an external visualizer program which is cool and all, but not
            // my use case. So probably I should do something myself here...

            // default_allocated := 0;
            // for address_table if it.is_live default_allocated += it.size;
            // default_allocated_high_water_mark = max(default_allocated_high_water_mark, default_allocated);

            // array_add(*rows, "default:     % [hvm: %]",
            //                 fmt_mem(default_allocated),
            //                 fmt_mem(default_allocated_high_water_mark));

            // prepare window lines
            builder := String_Builder.{ allocator = temp };

            max_sum_width := 0;
            for rows  max_sum_width = max(max_sum_width, it[0].count + it[1].count);
            for rows {
                append(*builder, "\e[100m"); // background color gray
                append(*builder, it[0]);
                append_padding(*builder, 1 + max_sum_width - (it[0].count + it[1].count));
                append(*builder, it[1]);
                append(*builder, "\n");
            }

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
                // FIXME: not enough padding is added for some reason...
                append_padding(*builder, max_width - line.count);
            }
            append(*builder, "\e[0m");

            total_string := builder_to_string(*builder,, temp);
            write_string(substring(total_string, start));
        }

        Profile();

        // draw particles
        if party_time do_party_mode();

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

        Profile();

        // cleanup child processes
        for *children_for_copying_to_clipboard {
            ok, result := get_process_result(*it.process, timeout_ms = 0);
            if result.type == .STILL_RUNNING continue;

            if result.exit_code != 0 {
                log_error("sub process `%` failed with code: %", it.name, result.exit_code);
            }

            remove it;
        }

        Profile();

        temporary_storage_high_water_mark = max(temporary_storage_high_water_mark, context.temporary_storage.high_water_mark);
        reset_temporary_storage();

        Profile();

    }

    // Restore terminal state
    restore_terminal_settings();

    if signalled_with_signal != -1 {
        print("got signal %\n", signalled_with_signal);
    }
}

//
// build main window line buffer from text
//

build_line_buffer_for_main_window :: (window_buffer: *Window_Buffer) -> [] string {
    using context.state;
    using window_buffer;

    if !window_buffer return .[];
    if main_window_height == 0 return .[];

    // `line_buffer` stores pointers into `window_buffer` or temporary storage
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

    line_number_max_digits := tprint("%", line_offsets.count).count;
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
    while line_buffer.count < main_window_height || (line_wrapping && stick_to_the_bottom) {
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
                hidden_slice := utf8_substring(line, 0, first_visible_column_offset);
                visible_slice = utf8_substring(line, first_visible_column_offset);

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
                    codes := find_all_control_codes_in_range(window_buffer, hidden_slice);
                    for < *codes {
                        // ignore everything before the last mode reset
                        code := control_code_string(it);
                        if is_mode_reset_control_sequence(code) break;
                        append(*builder, code);
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

            line_overflowed := utf8_count(visible_slice, false) > visible_columns_budget;
            if line_overflowed {
                // Leave space for the :line_overflow_character
                visible_slice = utf8_substring(visible_slice, 0, visible_columns_budget - 1);
            }

            codes.count = 0;
            if !strip_control_codes {
                array_add(*codes, ..find_all_control_codes_in_range(window_buffer, visible_slice));
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

                    insert_control_code_range(*codes, window_buffer,
                                              match_start, "\e[7m", // invert color mode
                                              match_end, "\e[27m"); // disable invert color mode
                }
            }

            select_word_delayed(window_buffer, line, *codes);

            // Build the line string
            build_line_with_control_codes(*builder, window_buffer, visible_slice, codes);

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
            piece_index := 0;

            // Iterate over line pieces
            while (piece_index == 0) || line_tail && (stick_to_the_bottom || line_buffer.count < main_window_height) {
                defer piece_index += 1;
                visible_columns_budget : int = terminal_size.cols;
                if line_numberring then visible_columns_budget -= line_number_max_digits + 1;

                current_slice := utf8_substring(line_tail, 0, visible_columns_budget);
                // TODO: maybe not just space but also other punctuation
                if current_slice.count < line_tail.count && current_slice.data[current_slice.count] != #char " " {
                    last_space := find_index_from_right(current_slice, #char " ");
                    if last_space != -1 {
                        current_slice.count = last_space + 1; // `+1` so that space is left on this line
                    }
                }
                current_slice_end := current_slice.data + current_slice.count;
                line_tail = substring(line_tail, current_slice.count);

                if line_index == row_offset && piece_index < wrapped_line_offset {
                    continue;
                }

                codes.count = 0;
                if !strip_control_codes {
                    array_add(*codes, ..find_all_control_codes_in_range(window_buffer, current_slice));
                }

                // :search_string_highlight
                while search_matches_tail {
                    match := *search_matches_tail[0];

                    start_in_range := match.start >= current_slice.data && match.start < current_slice_end;
                    end_in_range := match.end > current_slice.data && match.end <= current_slice_end;
                    if start_in_range || end_in_range {
                        insert_control_code_range(*codes, window_buffer,
                                                  match.start, "\e[7m", // invert color mode
                                                  match.end, "\e[27m"); // disable invert color mode
                    }

                    if !start_in_range || !end_in_range break; // leave that match for the next line piece

                    advance(*search_matches_tail, 1);
                }

                select_word_delayed(window_buffer, line, *codes);

                if line_numberring {
                    if piece_index == 0 {
                        append(*builder, "\e[2;37m"); // color gray (dark white)
                        print(*builder, "% ", fmt(current_line_number, line_number_max_digits, padding=" "));
                        append(*builder, "\e[0m"); // color gray (dark white)
                    } else {
                        append_padding(*builder, line_number_max_digits + 1); // `+ 1` for extra space
                    }
                }

                // Build the line string
                build_line_with_control_codes(*builder, window_buffer, current_slice, codes);

                if stick_to_the_bottom || line_buffer.count != line_buffer.allocated - 1 {
                    append(*builder, "\n");
                } else {
                    // Reset color codes
                    append(*builder, "\e[0m");
                }

                new_line_piece := builder_to_string(*builder,, temp);
                // TODO: probably want to check that line_index == row_offset - 1
                if wrapped_line_offset == -1 {
                    // `wrapped_line_offset == -1` means we're moving up from
                    // the first piece of one line to the last piece of the previous line
                    if !line_tail { // last line piece
                        array_add(*line_buffer, new_line_piece);
                        current_screen_row += 1;
                        wrapped_line_offset = piece_index;
                    }
                } else {
                    array_add(*line_buffer, new_line_piece);
                    current_screen_row += 1;
                }
            }
            pieces_count := piece_index;

            // didn't skip enough pieces, which means we're trying to move down
            // but the current line doesn't have any more pieces. So we move to
            // the next line
            if line_index == row_offset && wrapped_line_offset > 0 && pieces_count <= wrapped_line_offset {
                if row_offset == line_offsets.count - 1 {
                    wrapped_line_offset = pieces_count - 1;
                } else {
                    wrapped_line_offset = 0;
                    row_offset += 1;
                }
            }
        }
    }

    overflow := line_buffer.count - main_window_height;
    if overflow > 0 {
        assert(stick_to_the_bottom, "shouldn't happen otherwise");
        line_buffer.data += overflow;
        line_buffer.count -= overflow;
    }

    return line_buffer;
}

//
// pixel drawing mode
//

resize_pixel_buffer :: () {
    using context.state;

    height, width: s64;
    if #complete pixel_size == {
        case .TWO_CHARACTERS;
            pixel_window_size.x = xx (terminal_size.cols / 2);
            pixel_window_size.y = xx (terminal_size.rows - 2); // :2_status_lines
    }
    // TODO: need to move the pixel rows based on old pixel_window_size
    array_resize(*pixel_buffer, xx (pixel_window_size.x * pixel_window_size.y));

    pixel_buffer.count = xx (pixel_window_size.x * pixel_window_size.y);
    for *pixel_buffer it.* = .{ .2, .2, .2, 1 };

    width = xx pixel_window_size.x;
    for 1..22 pixel_buffer[5 * width + (it - 1) * 2] = .{ .9, .9, .9, 1 };
    for 1..5 pixel_buffer[6 * width + (it - 1) * 10] = .{ .9, .9, .9, 1 };
    for 1..3 pixel_buffer[(it - 1) * 2 * width + 43] = .{ .9, .9, .9, 1 };
    pixel_buffer[44] = .{ .9, .9, .9, 1 };

}

build_line_buffer_for_pixel_buffer :: () -> [] string {
    using context.state;

    line_buffer: [..] string;
    line_buffer.allocator = temp;
    array_reserve(*line_buffer, main_window_height);

    width: int = xx pixel_window_size.x;
    height: int = xx pixel_window_size.y;
    assert(pixel_buffer.count == width * height);
    assert(pixel_size == .TWO_CHARACTERS);
    // for y : 0..9 {
    for y : 0..height - 1 {
        builder: String_Builder;
        builder.allocator = temp;

        for x : 0..width - 1 {
        // for x : 0..9 {
            pixel := pixel_buffer[y * width + x];
            r := cast(u8) (pixel.x * 255);
            g := cast(u8) (pixel.y * 255);
            b := cast(u8) (pixel.z * 255);
            print(*builder, "\e[48;2;%;%;%m  ", r, g, b);
        }
        append(*builder, "\e[0m");
        append(*builder, "\n");

        array_add(*line_buffer, builder_to_string(*builder,, temp));
    }

    return line_buffer;
}

//
// delayed word selection
//

select_word_delayed :: (window_buffer: *Window_Buffer, slice_of_only_text: string, codes: *[..] Control_Code_Info) {
    using context.state;
    using window_buffer;

    assert(is_subslice(outer=only_text, inner=slice_of_only_text));
    slice := slice_of_only_text;

    mouse_selection_click := false;
    for delayed_actions if it.type == .MOUSE_SELECTION_CLICK {
        mouse_selection_click = true;
        break;
    }

    if mouse_selection_click {
        // FIXME: column offset is not taken into account
        if current_screen_row == mouse_position.row {
            log("click at line #%", current_line_number);
            column_in_window := mouse_position.column - 1 - current_row_left_offset;
            s := utf8_substring(slice, 0, column_in_window);
            selection_cursor = slice.data + s.count - only_text.data;
        }
    }

    selection_pointer := only_text.data + selection_cursor;
    if selection_pointer >= slice.data && selection_pointer <= slice.data + slice.count {
        selected_string := select_word_under_cursor(only_text, selection_cursor);
        selected_string_only_visible := only_visible_text(selected_string,, temp);

        if mouse_selection_click {
            free(last_selected_string);
            last_selected_string = copy_string(selected_string_only_visible);
            log("selected string: %", last_selected_string);
            // FIXME: this don't work:
            // os_clipboard_set_text(last_selected_string);

            tmux_copy_to_clipboard(last_selected_string);
        } else if last_selected_string != selected_string_only_visible {
            selection_cursor = -1;
        }

        start := selected_string.data;
        end := start + selected_string.count;
        // FIXME: this conflicts search string highlight
        insert_control_code_range(codes, window_buffer,
                                  start, "\e[7m", // invert color mode
                                  end,   "\e[27m"); // disable invert color mode
    }
}

select_word_under_cursor :: (text: string, cursor: int) -> string {
    if cursor < 0 return "";
    if cursor >= text.count return "";

    if text[cursor] == {
        case #char " "; return .{ data = text.data + cursor, count = 1 };
        case #char ")";
            start := cursor;
            depth := 0;
            while start >= 0 {
                if start == 0 break;
                prev_char := text[start - 1];
                if prev_char == {
                    case #char ")";
                        depth += 1;
                    case #char "(";
                        if depth > 0 then depth -= 1;
                        else { start -= 1; break; }
                }
                start -= 1;
            }
            return substring(text, start, end=cursor+1);
        case #char "(";
            end := cursor + 1;
            depth := 0;
            while end <= text.count {
                if end == text.count break;
                next_char := text[end];
                if next_char == {
                    case #char "("; depth += 1;
                    case #char ")";
                        if depth > 0 then depth -= 1;
                        else { end += 1; break; }
                }
                end += 1;
            }
            return substring(text, cursor, end=end);
    }

    start := cursor;
    while start >= 0 {
        if start == 0 break;
        prev_char := text[start - 1];
        if !is_file_path_char(prev_char) break;
        start -= 1;
    }

    end := cursor + 1;
    while end <= text.count {
        if end == text.count break;
        next_char := text[end];
        if !is_file_path_char(next_char) break;
        // TODO: if next_char == #char ":" break;
        end += 1;
    }

    return substring(text, start, end=end);
}

is_file_path_char :: inline (char: u8) -> bool {
    return is_alpha(char) || is_digit(char)
        || char == #char "-" || char == #char "_" || char == #char "~"
        || char == #char "." || char == #char "/" || char == #char ":";
}

tmux_copy_to_clipboard :: (text: string) {
    using,except.["command"] context.state;

    if !getenv("TMUX") return;

    command := string.["tmux", "set-buffer", text];
    log("running %", command);
    process: Process;
    ok := create_process(*process, ..command, capture_and_return_output = false);
    if !ok {
        code, message := get_error_value_and_string();
        log_error("starting command % failed: #% %", command, code, message);
        return;
    }

    array_add(*children_for_copying_to_clipboard, .{ process, "tmux set-buffer" });
}

//
// text sources
//

//
// text source: EXTERNAL_COMMAND
//

maybe_spawn_external_command :: () {
    using context.state;

    time := seconds_since_init();
    if external_command_process.output.handle != -1 return;
    if external_command_process.error.handle != -1 return;
    if last_command_result.type == .STILL_RUNNING return;
    if time < time_next_command_run return;

    // If the command is a single argument which contains a string,
    // assume it's some shell pipeline & run it in a shell
    temp_command : [] string = xx command;
    if command.count == 1 && find_index_from_left(command[0], #char " ") != -1 {
        temp_command = .["/bin/sh", "-c", command[0]];
    }

    Profile();

    t0 := time;
    process := *external_command_process;
    success := create_process(process, ..temp_command, capture_and_return_output=true);

    Profile();

    if !success {
        last_command_result.type = .FAILED_TO_LAUNCH;
        // FIXME: now the error message keeps flashing and getting erased on next loop iteration...
        time_next_command_run = time + external_command_run_period_seconds;
        return;
    }

    external_command_started = seconds_since_init();
    last_command_result.type = .STILL_RUNNING;

    close(process.input.handle);
    process.input.handle = -1;

    event: epoll_event;
    rc: s32;

    Profile();

    event.events = EPOLLIN;
    event.data.fd = process.output.handle;
    rc = epoll_ctl(epoll_fd, .ADD, process.output.handle, *event);
    assert(rc == 0);

    Profile();

    event.events = EPOLLIN;
    event.data.fd = process.error.handle;
    rc = epoll_ctl(epoll_fd, .ADD, process.error.handle, *event);
    assert(rc == 0);
}

read_some_from_external_command :: (output_closed: bool, error_closed: bool) {
    using context.state;

    process := *external_command_process;
    if process.output.handle != -1 {
        handle := *process.output.handle;
        builder := *external_command_output_builder;
        ok, has_new_data := read_all_available_data(handle.*, builder);
        if !ok {
            code, message := get_error_value_and_string();
            log_error("Failed reading subprocess output: [%] %\n", code, message);

            shutdown_fd(handle);
        }
        if output_closed {
            shutdown_fd(handle);
        }
    }

    Profile();

    if process.error.handle != -1 {
        handle := *external_command_process.error.handle;
        builder := *external_command_error_builder;
        ok, has_new_data := read_all_available_data(handle.*, builder);
        if !ok {
            code, message := get_error_value_and_string();
            log_error("Failed reading subprocess error stream: [%] %\n", code, message);

            shutdown_fd(handle);
        }
        if error_closed {
            shutdown_fd(handle);
        }
    }

    Profile();

    if last_command_result.type == .STILL_RUNNING {
        success:, last_command_result = get_process_result(process, timeout_ms=0);
    }

    Profile();

    if process.output.handle == -1 && process.error.handle == -1 && last_command_result.type != .STILL_RUNNING {
        now := seconds_since_init();
        second_to_last_command_finish = last_command_finish;
        last_command_finish = now;
        last_command_duration = last_command_finish - external_command_started;
        if last_command_duration > .5 {
            log("command finished: elapsed: %", last_command_duration);
        }
        time_next_command_run = now + external_command_run_period_seconds;
        external_command_finished_count += 1;
    }
}

maybe_handle_external_command_output :: () {
    using context.state;

    already_have_piped_input := false;
    already_have_piped_input = (main_window_buffer_history.count > 0) && (main_window_buffer_history[0].source != .EXTERNAL_COMMAND);
    if (already_have_piped_input || (external_command_last_handled_output_version != 0))
        && (external_command_finished_count == external_command_last_handled_output_version)
    {
        return;
    }
    external_command_last_handled_output_version = external_command_finished_count;

    using new_window_buffer: Window_Buffer;
    source = main_window_source;
    time_generated = current_time_consensus();
    duration = last_command_duration;
    raw_text_and_control_codes = prepare_raw_text_and_control_codes_from_external_command();
    hash = Meow_Hash_Compute(xx raw_text_and_control_codes);

    if main_window_buffer_history && hash == main_window_buffer_history[main_window_buffer_history.count - 1].hash {
        free(raw_text_and_control_codes);
        return;
    }

    Profile();
    init_window_buffer(*new_window_buffer, raw_text_and_control_codes);
    Profile();
    separate_control_codes(*new_window_buffer);
    Profile("length: %, lines: %, codes: %", raw_text_and_control_codes.count, line_offsets.count, control_codes.count);

    new_window_buffer.index_in_history = main_window_buffer_history.count;
    // TODO: could do some big-brain compression here for old buffers,
    // currently when doing `ps` 10 times a second on a pytest in picodata I get
    // 20meg memory usage by the end with about 500 buffers which is liveabel
    // for a while...
    array_add(*main_window_buffer_history, new_window_buffer);

    if show_latest_buffer {
        current_shown_buffer_index = new_window_buffer.index_in_history;
    }
}

prepare_raw_text_and_control_codes_from_external_command :: () -> string {
    using context.state;

    if last_command_result.type == .FAILED_TO_LAUNCH
    {
        prefix :: "\e[31m"; // color red
        error_message := builder_to_string(*error_log_builder, extra_bytes_to_prepend=prefix.count);
        memcpy(error_message.data, prefix.data, prefix.count);
        return error_message;
    }

    reset_builders := external_command_finished_count > 0;

    // FIXME: could reuse this memory
    normal_output := builder_to_string(*external_command_output_builder, do_reset=reset_builders);
    error_output := builder_to_string(*external_command_error_builder, do_reset=reset_builders);

    if error_output {
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

        free(normal_output);
        free(error_output);
        return xx buffer;
    }

    return normal_output;
}

//
// text source: PIPED_INPUT
//

read_some_from_piped_input :: () {
    using context.state;
    first_time := (main_window_buffer_history.count == 0);
    if !main_window_buffer_history {
        array_add(*main_window_buffer_history, .{});
        started_reading_piped_input = seconds_since_init();
    }

    if piped_input_fd == -1 return;

    has_new_data := read_all_available_data_from_piped_input();
    if !has_new_data return;

    window_buffer := *main_window_buffer_history[current_shown_buffer_index];
    window_buffer.source = main_window_source;
    window_buffer.time_generated = current_time_consensus();
    window_buffer.duration = seconds_since_init() - started_reading_piped_input;
    free(window_buffer.raw_text_and_control_codes);
    Profile();
    // inspect_builder(*piped_input_builder);
    window_buffer.raw_text_and_control_codes = builder_to_string(*piped_input_builder, do_reset=false);
    Profile("raw_text_and_control_codes.count: %", window_buffer.raw_text_and_control_codes.count);
    window_buffer.hash = Meow_Hash_Compute(xx window_buffer.raw_text_and_control_codes);
    Profile("raw_text_and_control_codes.count: %", window_buffer.raw_text_and_control_codes.count);
    if first_time then init_window_buffer(window_buffer, window_buffer.raw_text_and_control_codes);
    if debug { blocking_getchar(); debug = false; }
    separate_control_codes(window_buffer);
    Profile("raw_text_and_control_codes.count: %", window_buffer.raw_text_and_control_codes.count);
}

inspect_builder :: (builder: *String_Builder) {
    b: String_Builder;
    b.allocator = temp;

    buffer := get_base_buffer(builder);
    while buffer {
        print(*b, "%, ", buffer.allocated);
        buffer = buffer.next;
    }
    log("%", builder_to_string(*b,, temp));
}

handle_piped_input_end :: () {
    using context.state;

    shutdown_fd(*piped_input_fd);

    if !parent_process_command_line return;
    if path_filename(parent_process_command_line[0]) == "git" {
        for command free(it);
        command.count = 0;
        array_reserve(*command, parent_process_command_line.count);
        for parent_process_command_line {
            array_add(*command, copy_string(it));
        }
        time_next_command_run = -1;
        main_window_source = .EXTERNAL_COMMAND;
        log("main window source is now external command: %", command);
    }

    return;
}

read_all_available_data_from_piped_input :: () -> has_new_data: bool {
    using context.state;

    if piped_input_fd == -1 return false;

    ok, has_new_data := read_all_available_data(piped_input_fd, *piped_input_builder);
    if !ok {
        code, message := get_error_value_and_string();
        append(*piped_input_builder, "\e[31m"); // color red
        print(*piped_input_builder, "Failed reading from stdin pipe: (%) %\n", code, message);
        append(*piped_input_builder, "\e[0m");

        shutdown_fd(*piped_input_fd);
    }

    return has_new_data;
}

shutdown_fd :: (fd: *s32) {
    using context.state;

    rc := epoll_ctl(epoll_fd, .DEL, fd.*, null);
    if rc != 0 {
        code, message := get_error_value_and_string();
        log_error("epoll_ctl failed: [%] %", code, message);
    }

    rc = close(fd.*);
    if rc != 0 {
        code, message := get_error_value_and_string();
        log_error("close failed: [%] %", code, message);
    }

    fd.* = -1;
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
        // ⢎⠱ ⢎⡑ ⢎⡡ ⢎⡰ ⢆⡱ ⢌⡱ ⢊⡱ ⠎⡱
        //
        // ⢎⡁ ⢎⡠ ⢆⡰ ⢄⡱ ⢈⡱ ⠊⡱ ⠎⠱ ⢎⠑
        //
        // ⢎⡀ ⢆⡠ ⢄⡰ ⢀⡱ ⠈⡱ ⠊⠱ ⠎⠑ ⢎⠁
        //
        // ⢆⡀ ⢄⡠ ⢀⡰  ⡱ ⠈⠱ ⠊⠑ ⠎⠁ ⢎
        //
        // ⢾⠳ ⢾⡓ ⢾⡥ ⢾⡴ ⢦⡷ ⢬⡷ ⢚⡷ ⠞⡷
        case .EXTERNAL_COMMAND; {
            max_command_string_length : s64 = terminal_size.cols / 2;

            // FIXME: show the command of the current shown buffer
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

            duration := last_command_duration;
            // FIXME: this doesn't work >:c
            if main_window_source == .PIPED_INPUT && main_window_buffer_history {
                duration = main_window_buffer_history[current_shown_buffer_index].duration;
            }
            // TODO: support showing duration of streaming input & duration of
            // partial input from external command
            if main_window_source == .EXTERNAL_COMMAND
                && main_window_buffer_history
                && current_shown_buffer_index != main_window_buffer_history.count - 1
            {
                duration = main_window_buffer_history[current_shown_buffer_index].duration;
            }
            // last command duration
            if duration > 0
            {
                append(*builder, " \e[35m"); // color magenta
                print(*builder, "%s", fmt(duration, digits_after_comma=3, keep_zero=true)); // color magenta
                append(*builder, "\e[0m");
            }

            if last_command_result.type == .STILL_RUNNING || (frame_time - second_to_last_command_finish < anti_flicker_period) {
                append(*builder, "\e[35m"); // color magenta

                widget :: string.["⢎⡀", "⢆⡠", "⢄⡰", "⢀⡱", "⠈⡱", "⠊⠱", "⠎⠑", "⢎⠁"];
                append(*builder, " ");
                t := cast(int) (frame_time * 10);
                append(*builder, widget[t % widget.count]);

                append(*builder, "\e[0m");
            } else if last_command_result.exit_code != 0 {
                append(*builder, "\e[35m"); // color magenta
                append(*builder, " -> ");
                append(*builder, "\e[31m"); // color red
                print(*builder, "%", last_command_result.exit_code);
                append(*builder, "\e[0m");
            } else {
                append(*builder, "   ");
            }

            // command rerun period
            {
                append(*builder, "\e[2;37m"); // color gray (dark + white)
                append(*builder, " T: ");
                // XXX: am I stupid, or is stb_print_float doing something
                // weird when removing zero and when trailing_width is not zero?
                text := tprint("%", fmt(external_command_run_period_seconds, digits_after_comma=1));
                text = trim(text);
                append(*builder, text);
                append(*builder, "s");
                append(*builder, "\e[0m");
            }
        }
        case .PIPED_INPUT; {
            append(*builder, "\e[35m"); // color magenta
            append(*builder, "<stdin>");

            widget :: string.["⢎⡀", "⢆⡠", "⢄⡰", "⢀⡱", "⠈⡱", "⠊⠱", "⠎⠑", "⢎⠁"];
            append(*builder, " ");
            t := cast(int) (frame_time * 10);
            append(*builder, widget[t % widget.count]);

            append(*builder, "\e[0m");
        }
        case .DRAWING_MODE; {
            append(*builder, "\e[36m"); // color cyan
            append(*builder, "drawing mode");
            append(*builder, "\e[0m");

            print(*builder, " %", last_shown_line_buffer_version);

            append(*builder, " ");
            pixels_to_braille(*builder, 0, 0, 21);
            append(*builder, " ");

            t := cast(int) (frame_time * 10);
            // ⢎⠱ ⢎⡑ ⢎⡡ ⢎⡰ ⢆⡱ ⢌⡱ ⢊⡱ ⠎⡱
            {
                widget :: string.["⢎⠱", "⢎⡑", "⢎⡡", "⢎⡰", "⢆⡱", "⢌⡱", "⢊⡱", "⠎⡱"];
                append(*builder, " ");
                append(*builder, widget[t % widget.count]);
            }

            // ⢎⡁ ⢎⡠ ⢆⡰ ⢄⡱ ⢈⡱ ⠊⡱ ⠎⠱ ⢎⠑
            {
                widget :: string.["⢎⡁", "⢎⡠", "⢆⡰", "⢄⡱", "⢈⡱", "⠊⡱", "⠎⠱", "⢎⠑"];
                append(*builder, " ");
                append(*builder, widget[t % widget.count]);
            }

            // ⢎⡀ ⢆⡠ ⢄⡰ ⢀⡱ ⠈⡱ ⠊⠱ ⠎⠑ ⢎⠁
            {
                widget :: string.["⢎⡀", "⢆⡠", "⢄⡰", "⢀⡱", "⠈⡱", "⠊⠱", "⠎⠑", "⢎⠁"];
                append(*builder, " ");
                append(*builder, widget[t % widget.count]);
            }

            // ⢆⡀ ⢄⡠ ⢀⡰  ⡱ ⠈⠱ ⠊⠑ ⠎⠁ ⢎
            {
                widget :: string.["⢆⡀", "⢄⡠", "⢀⡰", "⠀⡱", "⠈⠱", "⠊⠑", "⠎⠁", "⢎⠀"];
                append(*builder, " ");
                append(*builder, widget[t % widget.count]);
            }

            // ⢄⡀ ⢀⡠  ⡰  ⠱ ⠈⠑ ⠊⠁ ⠎  ⢆
            {
                widget :: string.["⢄⡀", "⢀⡠",  "⠀⡰", "⠀⠱", "⠈⠑", "⠊⠁", "⠎⠀", "⢆⠀"];
                append(*builder, " ");
                append(*builder, widget[t % widget.count]);
            }

            // ⢾⠳ ⢾⡓ ⢾⡥ ⢾⡴ ⢦⡷ ⢬⡷ ⢚⡷ ⠞⡷
            {
                widget :: string.["⢾⠳", "⢾⡓", "⢾⡥", "⢾⡴", "⢦⡷", "⢬⡷", "⢚⡷", "⠞⡷"];
                append(*builder, " ");
                append(*builder, widget[t % widget.count]);
            }

            // ⢎⠑⢄⡱ ⠎⠑⢌⡱ ⠊⠑⢎⡱ ⠈⠱⢎⡱ ⡱⢎⡱ ⢀⡰⢎⡱ ⢄⡠⢎⡱ ⢆⡠⢊⡱ ⢎⡠⠊⡱ ⢎⡡⠊⠱ ⢎⡱⠊⠑ ⢎⡱⠎⠁ ⢎⡱⢎ ⢎⡱⢆⡀ ⢎⡱⢄⡠ ⢎⡑⢄⡰
            {
                widget :: string.[
                    "⢎⠑⢄⡱", "⠎⠑⢌⡱", "⠊⠑⢎⡱", "⠈⠱⢎⡱", "⠀⡱⢎⡱", "⢀⡰⢎⡱", "⢄⡠⢎⡱", "⢆⡠⢊⡱",

                    "⢎⡠⠊⡱", "⢎⡡⠊⠱", "⢎⡱⠊⠑", "⢎⡱⠎⠁", "⢎⡱⢎⠀", "⢎⡱⢆⡀", "⢎⡱⢄⡠", "⢎⡑⢄⡰",
                ];
                append(*builder, " ");
                append(*builder, widget[t % widget.count]);
            }

            // ⠊⠑⢄⡀  ⠉⠢⣀⠄ ⠈⠢⣀⠆  ⠢⣈⠆    ⢌⡱   ⠐⣉⠆  ⠔⢉⠆ ⢀⠔⠉⠆  ⢀⡠⠊⠑ ⠠⣀⠔⠉ ⠰⣀⠔⠁ ⠰⣁⠔  ⢎⡡   ⠰⣉⠂  ⠰⡉⠢  ⠰⠉⠢⡀
            {
                widget :: string.[
                    "⠊⠑⢄⡀", "⠈⠑⢄⡠", "⠀⠑⢄⡰", "⠀⠐⢄⡱", "⠀⠀⢌⡱", "⠀⠀⢊⡱", "⠀⠠⠊⡱", "⠀⡠⠊⠱",
                    "⢀⡠⠊⠑", "⢄⡠⠊⠁", "⢆⡠⠊⠀", "⢎⡠⠂⠀", "⢎⡡⠀⠀", "⢎⡑⠀⠀", "⢎⠑⠄⠀", "⠎⠑⢄⠀",
                ];
                append(*builder, " ");
                append(*builder, widget[t % widget.count]);
            }

            {
                widget :: string.[
                    "⠊⠑⠀⠀", "⠈⠑⠄⠀", "⠀⠑⢄⠀", "⠀⠐⢄⡀", "⠀⠀⢄⡠", "⠀⠀⢀⡰", "⠀⠀⠀⡱", "⠀⠀⠈⠱",
                    "⠀⠀⠊⠑", "⠀⠠⠊⠁", "⠀⡠⠊⠀", "⢀⡠⠂⠀", "⢄⡠⠀⠀", "⢆⡀⠀⠀", "⢎⠀⠀⠀", "⠎⠁⠀⠀",
                ];
                append(*builder, " ");
                append(*builder, widget[t % widget.count]);
            }

            {
                widget :: string.[
                    "⠊⣵", "⢨⡵", "⣤⡱", "⢶⡰", "⢟⡠", "⢞⡃", "⢎⠛", "⠎⠷",
                ];
                append(*builder, " ");
                append(*builder, widget[t % widget.count]);
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
        append(*right_side_builder, "\e[2;37m"); // color gray (dark white)
        if current_shown_buffer_index == main_window_buffer_history.count - 1 {
            print(*right_side_builder, "#%", current_shown_buffer_index + 1);
        } else {
            print(*right_side_builder, "#%/%", current_shown_buffer_index + 1, main_window_buffer_history.count);
        }
        append(*right_side_builder, "\e[0m");
        append(*right_side_builder, " ");

        time := current_time_consensus();
        if main_window_source == .EXTERNAL_COMMAND && main_window_buffer_history {
            time = main_window_buffer_history[current_shown_buffer_index].time_generated;
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

pixels_to_braille :: (builder: *String_Builder, x_0_: int, y_0_: int, count: int) {
    using context.state;
    assert(count > 0);

    x_0 := x_0_;
    y_0 := y_0_;
    stride := 2;

    for 0..count-1 {
        braille: u32 = 0x2800;
        is_on :: (x: int, y: int) -> bool #expand {
            return pixel_buffer[y * (cast(int) pixel_window_size.x) + x].x > .6;
        }

        if is_on(x_0 + stride * it + 0, y_0 + 0) braille += 1 << 0;
        if is_on(x_0 + stride * it + 0, y_0 + 1) braille += 1 << 1;
        if is_on(x_0 + stride * it + 0, y_0 + 2) braille += 1 << 2;
        if is_on(x_0 + stride * it + 1, y_0 + 0) braille += 1 << 3;
        if is_on(x_0 + stride * it + 1, y_0 + 1) braille += 1 << 4;
        if is_on(x_0 + stride * it + 1, y_0 + 2) braille += 1 << 5;
        if is_on(x_0 + stride * it + 0, y_0 + 3) braille += 1 << 6;
        if is_on(x_0 + stride * it + 1, y_0 + 3) braille += 1 << 7;

        buf: [4] u8;
        s := cast(string) buf;

        character_utf32_to_utf8(braille, *s);
        append(builder, s);
    }
}

render_status_line_2 :: () {
    using context.state;

    builder: String_Builder;
    builder.allocator = temp;
    buffer := get_base_buffer(*builder);

    cursor_line = -1;
    cursor_column = -1;

    // "\e[H": move cursor to position (row 2, column 1)
    append(*builder, "\e[2;1H");
    append(*builder, "\e[K"); // "\e[K": erase in line
    append(*builder, "\e[2;37m"); // color gray

    if frame_time < info_message_deadline {
        append(*builder, to_string(*info_message_builder));
    } else if main_window_source == .DRAWING_MODE {
        append(*builder, "drawing mode");

        print(*builder, " mouse %, %", mouse_position.column, mouse_position.row);
    } else {
        if input_mode ==  {
            case .NAVIGATE;
                line_count := 0;
                if main_window_buffer_history {
                    main_window_buffer := *main_window_buffer_history[current_shown_buffer_index];
                    line_count = main_window_buffer.line_offsets.count;
                }

                text_start := buffer.count;
                {
                    append(*builder, "offset: ");
                    if !line_wrapping then print(*builder, "%, ", col_offset);
                    print(*builder, "%", row_offset);
                    if line_wrapping then print(*builder, "(+%)", wrapped_line_offset);
                    print(*builder, "/%  ", line_count);
                    if stick_to_the_bottom then append(*builder, "sinking   ");

                    // Print current input buffer
                    append(*builder, "input: ");

                    print_to_builder(*builder, "%", cast(Ascii_Or_Hex) input_buffer);

                    // print(*builder, " mouse %, %", mouse_position.column, mouse_position.row);
                    // print(*builder, "  control codes count %", main_window_buffer.control_codes.count);
                }
                text_length := buffer.count - text_start;
                overflow := text_length - terminal_size.cols;
                if overflow > 0 {
                    buffer.count -= overflow;
                }
            case .INPUT_SEARCH_STRING; #through;
            case .INPUT_COMMAND;
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
    }

    append(*builder, "\e[0m");

    assert(get_current_buffer(*builder) == buffer);
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
    for *codes {
        position_clamped := clamp(it.position_in_text, start, end);

        piece := substring(only_text, cursor, position_clamped);
        if context.state.visualize_control_codes then print(builder, "%", cast(Ascii_Or_Hex) piece);
        else                                          append(builder, piece);

        if it.position_in_text > end return codes.count - it_index;

        code := control_code_string(it);
        if context.state.visualize_control_codes then print(builder, "%", cast(Ascii_Or_Hex) code);
        else                                          append(builder, code);

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

    assert(start_pointer >= only_text.data);
    assert(start_pointer < end_pointer);
    assert(end_pointer <= only_text.data + only_text.count);

    start_position := start_pointer - only_text.data;
    start := make_control_code_info(start_position, start_code);
    end_position := end_pointer - only_text.data;
    end := make_control_code_info(end_position, end_code);

    index := 0;
    while index < codes.count {
        it := *codes.*[index];

        if it.position_in_text > start.position_in_text break;
        if it.position_in_text == start.position_in_text {
            // Put new control code after the mode reset at the same position
            if !is_mode_reset_control_sequence(control_code_string(it)) break;
        }

        index += 1;
    }

    array_insert_at(codes, start, index);

    index += 1;
    while index < codes.count {
        it := *codes.*[index];

        if it.position_in_text > end.position_in_text break;
        // Found mode reset
        if is_mode_reset_control_sequence(control_code_string(it)) {
            // Insert another start after the mode reset, because it just reset our previous start
            another_start := start;
            another_start.position_in_text = it.position_in_text;
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

    return control_code_string(*control_codes[control_codes_cursor]);
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
    while control_codes_cursor < control_codes.count {
        code := current_control_code(window_buffer);
        if !control_code_is_in_range(code, start, end) break;
        total_string_length += code.count;
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
    init_window_buffer(*window_buffer, text);
    separate_control_codes(*window_buffer);

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

init_window_buffer :: (window_buffer: *Window_Buffer, raw_text: string) {
    // `only_text.count <= raw_text_and_control_codes.count` is always true
    window_buffer.raw_text_and_control_codes = raw_text;
    window_buffer.last_line_offset_in_raw_text = 0;

    window_buffer.only_text_storage.count = 0;
    window_buffer.line_offsets.count = 0;
    window_buffer.control_codes.count = 0;

    window_buffer.max_line_length = 0;
}

separate_control_codes :: (using window_buffer: *Window_Buffer) {
    using context.state;

    if line_offsets {
        last_line_offset_in_only_text := last(line_offsets);
        only_text_storage.count = last_line_offset_in_only_text;

        while control_codes {
            if last(control_codes).position_in_text < last_line_offset_in_only_text break;
            control_codes.count -= 1;
        }
    } else {
        // This is kinda retarded, but actually makes sense if you think about it
        array_add(*line_offsets, 0);
    }

    unparsed_tail := advance(raw_text_and_control_codes, last_line_offset_in_raw_text);

    tab_count := count_occurences(unparsed_tail, #char "\t");

    // When doing :automatic_tab_expansion: every tab character is replaced with
    // 8 spaces, so we need to allocate additional memory for that.
    // Mutliply by 7, because each tab character is already counted once and need 7 more bytes.
    extra_space_for_tab_replacements := tab_count * 7;
    new_capacity := only_text_storage.count + unparsed_tail.count + extra_space_for_tab_replacements;
    array_reserve(*only_text_storage, new_capacity);

    last_empty_lines_count := 0;
    tail := unparsed_tail;
    while !should_exit {
        // TODO: it should be pretty simple to stop this process once I know I'm
        // not looking at this. Though search would need to call this function
        // when it determines that there's unparsed text.
        found:, line:, tail = split_from_left(tail, #char "\n");

        max_line_length = max(max_line_length, line.count);

        if line.count == 0 then last_empty_lines_count += 1; else last_empty_lines_count = 0;

        line_tail := line;
        while line_tail {
            head:, visible_count:, line_tail = eat_visible_or_escape_sequence(line_tail);

            if visible_count == 0 {
                add_control_code(window_buffer, only_text_storage.count, head);
            } else {
                // Expand any tab characters with spaces, because fuck tab characters,
                // all my homies use spaces
                visible_tail := head;
                while visible_tail {
                    found_tab:, piece:, visible_tail = split_from_left(visible_tail, #char "\t");

                    index := find_index_from_left(piece, #char "\x08"); // '\b'
                    found_backspace := (index != -1);

                    // XXX: this shit is crazy! man is doing some retarded shit where it outputs
                    // `N\bNA\bAM\bME\bE` to mean `\e[1mNAME\e[0m` (which means
                    // bold). And same shit for underlined text.
                    // And now I have too deal with this....
                    Flush_Highlighted_Piece :: (count: *s64, start_code: string, end_code: string) #expand {
                        if count.* == 0 return;
                        add_control_code(window_buffer, `only_text_storage.count, start_code);
                        start := `piece.data + `cursor - count.* * 3;
                        // @Robustness: here we append every 3rd character, because this
                        // works for both bold (B\bBO\bOL\bLD\bD) and underline
                        // (_\bU_\bN_\bD_\bE_\bR...) the way `man` is using
                        // them, but this may not be enough for some other weirdos
                        for 0..count.*-1 array_add(*`only_text_storage, start[it * 3 + 2]);
                        add_control_code(window_buffer, `only_text_storage.count, end_code);
                        count.* = 0;
                    }
                    Flush_Regular_Piece :: () #expand {
                        if `regular_count == 0 return;
                        start := `piece.data + `cursor - `regular_count;
                        assert(`only_text_storage.count + `regular_count <= `only_text_storage.allocated);
                        memcpy(`only_text_storage.data + `only_text_storage.count, start, `regular_count);
                        `only_text_storage.count += `regular_count;
                        `regular_count = 0;
                    }

                    bold_count := 0;
                    underline_count := 0;
                    regular_count := 0;
                    cursor := 0;
                    if !found_backspace {
                        cursor = piece.count;
                        regular_count = piece.count;
                    } else while cursor < piece.count {
                        // FIXME: should take into account utf8, because some of man pages use utf8 characters...
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

                    if found_tab {
                        expanded_tab :: "        "; // :automatic_tab_expansion:
                        assert(only_text_storage.count + expanded_tab.count <= only_text_storage.allocated);
                        memcpy(only_text_storage.data + only_text_storage.count, expanded_tab.data, expanded_tab.count);
                        only_text_storage.count += expanded_tab.count;
                    }
                }
            }
        }

        if found {
            // At this point it would probably be cleaner to use find_index_from_left instead of split_from_left...
            pointer_to_start_of_next_line := line.data + line.count + 1;
            last_line_offset_in_raw_text = pointer_to_start_of_next_line - raw_text_and_control_codes.data;
            array_add(*line_offsets, only_text_storage.count);
        } else {
            break;
        }
    }

    only_text = xx only_text_storage;
    // @Robustness: This is currently broken in a rare case when parsing a stream repeatedly
    //              if the last piece is only empty lines after some empty lines
    // line_offsets.count -= last_empty_lines_count;
}

add_control_code :: (using window_buffer: *Window_Buffer, position_in_only_text: s64, control_code: string) {
    code := make_control_code_info(position_in_only_text, control_code);
    array_add(*control_codes, code);

    for unique_control_codes if to_string(it) == control_code return;
    array_add(*unique_control_codes, code.bytes);
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
// io stuff
//

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
            code, message := get_error_value_and_string();
            #assert EAGAIN == EWOULDBLOCK;
            if code != EWOULDBLOCK {
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
        } else if sequence == "Z" {
            event.kind = .CHARACTER;
            event.char = #char "\x09"; // CTRL+I or TAB
            event.modifiers = .SHIFT;
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

    event := _event;
    if main_window_source == .DRAWING_MODE {
        assert(pixel_size == .TWO_CHARACTERS);
        width := cast(int) pixel_window_size.x;
        height := cast(int) pixel_window_size.y;
        mouse_x := (mouse_position.column - 1) / 2;
        mouse_y := (mouse_position.row - 1) - 2; // `- 2` for :2_status_lines
        pixel_index := mouse_y * width + mouse_x;

        if input_mode == {
            case .INPUT_COMMAND;
        }
        if event.kind == {
            case .MOUSE_LEFT_DRAG; #through;
            case .MOUSE_LEFT_DOWN;
                if pixel_index >= 0 && pixel_index < pixel_buffer.count {
                    pixel_buffer[pixel_index] = .{ .9, .9, .9, 1 };
                }
            case .MOUSE_RIGHT_DRAG; #through;
            case .MOUSE_RIGHT_DOWN;
                if pixel_index >= 0 && pixel_index < pixel_buffer.count {
                    pixel_buffer[pixel_index] = .{ .2, .2, .2, 1 };
                }
            case .MOUSE_MIDDLE_DOWN;
                builder: String_Builder;
                pixels_to_braille(*builder, 0, 0, count=2);
                tmux_copy_to_clipboard(builder_to_string(*builder,, temp));
        }

        if input_mode == {
            case .INPUT_COMMAND;
                handle_input_event_in_input_command_mode(event);

            case .NAVIGATE;
                if event.kind == .CHARACTER {
                    if event.char == {
                        case #char ";"; switch_to_command_line_mode();
                    }
                }
        }

        // FIXME: ugly hack, also it doesn't work
        if input_mode == .NAVIGATE return;
    }

    main_window_buffer: *Window_Buffer;
    if main_window_buffer_history
        main_window_buffer = *main_window_buffer_history[current_shown_buffer_index];

    if event.kind == {
        case .MOUSE_WHEEL_UP;
            if      event.modifiers & .SHIFT then col_offset += 8;
            else if event.modifiers & .ALT   then col_offset += 8;
                                             else row_offset += 4;
                event.kind = .HANDLED;
        case .MOUSE_WHEEL_DOWN;
            if      event.modifiers & .SHIFT then col_offset -= 8;
            else if event.modifiers & .ALT   then col_offset -= 8;
            else {
                row_offset -= 4;
                stick_to_the_bottom = false;
            }
            event.kind = .HANDLED;
        case .MOUSE_LEFT_DOWN;
            array_add(*delayed_actions, .{ .MOUSE_SELECTION_CLICK });
            // log("delaying mouse selection click @ %", mouse_position);
            event.kind = .HANDLED;
    }

    if input_mode == {
        case .NAVIGATE;
            if (event.kind == .CHARACTER) && (event.char == #char "q") {
                should_exit = true;
            }
            if !main_window_buffer return;
            if event.kind == {
                case .KEY_UP;   navigate_window_up(ifx event.modifiers & .SHIFT then .HALF_SCREEN else .ONE_ROW);
                case .KEY_DOWN; navigate_window_down(ifx event.modifiers & .SHIFT then .HALF_SCREEN else .ONE_ROW);

                case .KEY_LEFT;
                    if !line_wrapping {
                        if event.modifiers & .SHIFT then col_offset -= terminal_size.cols / 2;
                                                    else col_offset -= 4;
                    }
                case .KEY_RIGHT;
                    if !line_wrapping {
                        if event.modifiers & .SHIFT then col_offset += terminal_size.cols / 2;
                                                    else col_offset += 4;
                    }

                case .CHARACTER; if event.char == {
                    case #char "j"; navigate_window_down(.ONE_ROW);
                    case #char "k"; navigate_window_up(.ONE_ROW);

                    case #char "d"; navigate_window_down(.HALF_SCREEN);
                    case #char "u"; navigate_window_up(.HALF_SCREEN);

                    case #char "b";
                        if current_shown_buffer_index > 0 {
                            current_shown_buffer_index -= 1;
                            show_latest_buffer = false;
                        }
                    case #char "B";
                        current_shown_buffer_index = 0;
                        show_latest_buffer = false;

                    case #char "f";
                        f_repeat_count += 1;
                        if current_shown_buffer_index < main_window_buffer_history.count - 1 {
                            current_shown_buffer_index += 1;
                        }
                        if current_shown_buffer_index == main_window_buffer_history.count - 1
                            && f_repeat_count >= 3
                            then show_latest_buffer = true;
                    case #char "F";
                        current_shown_buffer_index = main_window_buffer_history.count - 1;
                        show_latest_buffer = true;

                    case #char "t"; stick_to_the_bottom = !stick_to_the_bottom;

                    case #char "w"; line_wrapping = !line_wrapping;

                    case #char "g"; row_offset = 0; wrapped_line_offset = 0; stick_to_the_bottom = false;
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
                        input_mode = .INPUT_SEARCH_STRING;
                        replace_console_command_line(xx search_string_buffer);
                        history_cursor = -1;
                        // turn off error message instantly
                        info_message_deadline = frame_time - 1;
                    }

                    case #char ";";
                        switch_to_command_line_mode();

                    case #char "n"; jump_to_next_search_match();
                    case #char "N"; jump_to_previous_search_match();

                    case #char "c"; strip_control_codes = !strip_control_codes;
                }

                if event.char != #char "f" {
                    f_repeat_count = 0;
                }
            }

            row_offset = max(row_offset, -(main_window_height - 1));
            row_offset = min(row_offset, max(0, main_window_buffer.line_offsets.count - 1));

            col_offset = max(col_offset, -(cast(int) terminal_size.cols - 1));
            col_offset = min(col_offset, max(0, main_window_buffer.max_line_length - 1));

        case .INPUT_SEARCH_STRING; #through;
        case .INPUT_COMMAND;
            handle_input_event_in_input_command_mode(event);

    }
}

Window_Shift_Kind :: enum { ONE_ROW; HALF_SCREEN; };
navigate_window_down :: (kind: Window_Shift_Kind) {
    using context.state;

    offset := 0;
    if #complete kind == {
        case .ONE_ROW;     offset = 1;
        case .HALF_SCREEN; offset = terminal_size.rows / 2;
    }

    if line_wrapping && row_offset >= 0 {
        wrapped_line_offset += offset;
    } else {
        wrapped_line_offset = 0;
        row_offset += offset;
    }
}

navigate_window_up :: (kind: Window_Shift_Kind) {
    using context.state;

    offset := 0;
    if #complete kind == {
        case .ONE_ROW;     offset = 1;
        case .HALF_SCREEN; offset = terminal_size.rows / 2;
    }
    stick_to_the_bottom = false;

    if line_wrapping && (row_offset > 0 || row_offset == 0 && wrapped_line_offset > 0) {
        wrapped_line_offset -= offset;
        if wrapped_line_offset < 0 {
            wrapped_line_offset = -1;
            row_offset -= 1;
        }
    } else {
        wrapped_line_offset = 0;
        row_offset -= offset;
    }
}

handle_input_event_in_input_command_mode :: (event: Input_Event) {
    using context.state;

    if !(event.modifiers & .ALT) && event.char >= #char " " && event.char <= #char "~" {
        array_insert_at(*command_line, event.char, input_cursor);
        input_cursor += 1;
        deactivate_completion_menu();
    } else if event.char == {
        case #char "\e"; /* ESCAPE */
            if completion_menu.is_active {
                deactivate_completion_menu();
            } else {
                switch_to_navigate_mode();
            }

        case #char "\n"; /* ENTER */
            if completion_menu.is_active {
                replace_console_command_line_from_completion_menu(completion_menu.selected_item);
                deactivate_completion_menu();
            } else {
                maybe_append_command_line_to_history();
                if input_mode == .INPUT_COMMAND {
                    execute_console_command(xx command_line);
                    command_line.count = 0;
                }
                switch_to_navigate_mode();
            }

        case #char "\x02"; /* CTRL+B */ move_command_line_cursor_left();
        case #char "\x06"; /* CTRL+F */ move_command_line_cursor_right();
        case #char "\x01"; /* CTRL+A */ input_cursor = 0;
        case #char "\x05"; /* CTRL+E */ input_cursor = command_line.count;

        case #char "b"; if event.modifiers & .ALT /* ALT+B */ move_command_line_cursor_left_a_word();
        case #char "f"; if event.modifiers & .ALT /* ALT+F */ move_command_line_cursor_right_a_word();

        case #char "\x09"; /* CTRL+I or TAB */
            if input_mode == .INPUT_COMMAND {
                if completion_menu.is_active {
                    if event.modifiers & .SHIFT
                        completion_menu.selected_item = max(completion_menu.selected_item - 1, 0);
                    else
                        completion_menu.selected_item = min(completion_menu.selected_item + 1, completion_menu.items.count - 1);
                } else {
                    complete_console_command();
                }
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
                deactivate_completion_menu();
            } else {
                switch_to_navigate_mode();
            }

        case #char "\x04"; /* CTRL+D */
            if command_line.count > 0 && input_cursor < command_line.count {
                array_ordered_remove_range(*command_line, input_cursor, input_cursor + 1);
                deactivate_completion_menu();
            }

        case #char "\x0b"; /* CTRL+K */
            if command_line.count > 0 && input_cursor < command_line.count {
                array_ordered_remove_range(*command_line, input_cursor, command_line.count);
                deactivate_completion_menu();
            }

        case #char "\x17"; /* CTRL+W */
            delete_word_before_command_line_cursor();
            deactivate_completion_menu();

        case #char "\x15"; /* CTRL+U */ {
            command_line.count = 0;
            input_cursor = 0;
            deactivate_completion_menu();
        }
    }
    if event.modifiers & .CONTROL {
        if event.kind == {
            case .KEY_LEFT;  move_command_line_cursor_left_a_word();
            case .KEY_RIGHT; move_command_line_cursor_right_a_word();
        }
    } else if event.kind == .KEY_UP || event.char == #char "\x10" /* CTRL+P */ {
        if completion_menu.is_active {
            completion_menu.selected_item = max(completion_menu.selected_item - 1, 0);
        } else {
            history_previous();
        }
    } else if event.kind == .KEY_DOWN || event.char == #char "\x0e" /* CTRL+N */ {
        if completion_menu.is_active {
            completion_menu.selected_item = min(completion_menu.selected_item + 1, completion_menu.items.count - 1);
        } else {
            history_next();
        }
    } else {
        if event.kind == {
            case .KEY_LEFT;  move_command_line_cursor_left();
            case .KEY_RIGHT; move_command_line_cursor_right();
        }
    }

    if input_mode == .INPUT_SEARCH_STRING {
        search_string_buffer.count = 0;
        array_add(*search_string_buffer, ..command_line);
        search_string = xx search_string_buffer;
    }
}

switch_to_navigate_mode :: () {
    using context.state;

    history_cursor = -1;
    input_mode = .NAVIGATE;
    command_line.count = 0;
    deactivate_completion_menu();
}

deactivate_completion_menu :: () {
    using context.state;

    if completion_menu.is_active {
        completion_menu.is_active = false;
        completion_menu.completion_insert_offset = 0;
        redraw_once = true;
    }
}

switch_to_command_line_mode :: () {
    using context.state;

    input_mode = .INPUT_COMMAND;
    input_cursor = command_line.count;
    history_cursor = -1;
    // turn off error message instantly
    info_message_deadline = frame_time - 1;
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

    // skip any separator characters before the cursor
    while string_before_cursor.count {
        char := string_before_cursor[string_before_cursor.count - 1];
        if char != #char " " && char != #char "." break;
        string_before_cursor.count -= 1;
    }

    to_delete_from := find_index_of_any_from_right(string_before_cursor, " .");
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

get_history_for_input_mode :: () -> *[..] string, History_File_Entry_Type {
    using context.state;

    if input_mode == {
        case .INPUT_COMMAND;        return *command_line_history, .COMMAND;
        case .INPUT_SEARCH_STRING;  return *search_string_history, .SEARCH;
    }
    return null, .INVALID;
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
        replace_console_command_line(history.*[history_cursor]);
        input_cursor = command_line.count;
    }
}

history_next :: () {
    using context.state;

    history := get_history_for_input_mode();

    if history_cursor == -1 return;
    if history_cursor < history.count - 1 {
        history_cursor += 1;
        replace_console_command_line(history.*[history_cursor]);
    } else {
        history_cursor = -1;
        replace_console_command_line(history_stash);
    }
}

//
// navigate mode key handling procs
//

jump_to_next_search_match :: () {
    using context.state;
    using main_window_buffer_history[current_shown_buffer_index];

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
    using main_window_buffer_history[current_shown_buffer_index];

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
// console_commands
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

        #import "Compiler";
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

execute_console_command :: (command_line: string) {
    using,except.["command_line", "command"] context.state;

    tail := command_line;
    command_name, ok := parse_token(*tail);
    if !ok return;

    command: *Command;
    for *console_commands {
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

complete_console_command :: () {
    using context.state;

    if input_cursor != command_line.count {
        // TODO: could do something smarter here
        return;
    }

    if completion_menu.is_active return;

    // if command_line.count == 0 return;

    // TODO: pressing TAB once starts COMMAND_COMPLETION input mode in which
    // the completion list is diplayed on the screen and pressing ctrl+p/ctrl+n
    // (or even arrows if you're into that) iterates over the list.
    // Pressing any character key exits completion mode into INPUT_COMMAND mode
    // Moving the cursor also exits completion mode
    // Pressing enter runs the command
    reset_completion_menu();
    for console_commands {
        if !starts_with(it.name, xx command_line) continue;

        completion_menu.completion_insert_offset = 0;
        add_completion_menu_item_simple(it.name);
    }

    if completion_menu_activate_or_pick_sole_item() return;

    // If it's a `> command ` insert the current external command for editting
    if command_line[command_line.count - 1] == #char " " && trim(xx command_line) == "command" {
        if command.count {
            array_add(*command_line, ..cast([] u8) command[0]);
            for 1..command.count-1 {
                array_add(*command_line, #char " ");
                array_add(*command_line, ..cast([] u8) command[it]);
            }
        }
        input_cursor = command_line.count;
        return;
    }

    if starts_with(xx command_line, "show_state_field ") {
        found, _, path := split_from_left(xx command_line, " ");
        assert(found);
        ok, field, field_prefix := get_subfield_by_path(*context.state, path, allow_partial=true);
        if !ok return;

        if field.type.type == {
            case .STRUCT;
                for (cast(*Type_Info_Struct) field.type).members {
                    if !starts_with(it.name, field_prefix) continue;
                    if it.flags & .CONSTANT continue;

                    completion_menu.completion_insert_offset = command_line.count - field_prefix.count;

                    field_value: Any;
                    field_value.value_pointer = field.value_pointer + it.offset_in_bytes;
                    field_value.type = it.type;
                    print_completion_menu_item("%: %", it.name, field_value, actual_item = it.name);
                }
            case .ARRAY; #through;
            case .STRING;
                completion_menu.completion_insert_offset = command_line.count - field_prefix.count;
                for property: string.["count", "data"] {
                    ok, value := get_array_or_string_property_as_any(field, property);
                    assert(ok);
                    print_completion_menu_item("%: %", property, value, actual_item = property);
                }
                if field.type.type == .ARRAY {
                    type := cast(*Type_Info_Array) field.type;
                    array_view := array_view_from_any(field.value_pointer, type);

                    element: Any;
                    element.type = type.element_type;
                    element.value_pointer = array_view.data;

                    for 0..array_view.count {
                        item := tprint("[%]: %", it, element);
                        i := find_index_from_left(item, #char "]");
                        if item.count > completion_menu_builder_remaining_capacity() break;
                        add_completion_menu_item(item, "", actual_item_is_prefix = i + 1);
                        element.value_pointer += element.type.runtime_size;
                    }
                }
            case;
                return;
        }

        if completion_menu_activate_or_pick_sole_item() return;
    }
}

completion_menu_activate_or_pick_sole_item :: () -> bool {
    using context.state;

    if !completion_menu.items return false;

    if completion_menu.items.count == 1 {
        replace_console_command_line_from_completion_menu(0);
        return true;
    }

    if completion_menu.items.count > 1 {
        completion_menu.is_active = true;
        completion_menu.selected_item = 0;

        if completion_menu.common_item_prefix {
            replace_console_command_line_from_completion_menu(completion_menu.common_item_prefix);
        }

        return true;
    }

    return false;
}

replace_console_command_line_from_completion_menu :: inline (item_index: s64) {
    using context.state;

    replace_console_command_line_from_completion_menu(completion_menu.items[item_index]);
}

replace_console_command_line_from_completion_menu :: (replacement: string) {
    using context.state;

    command_line.count = completion_menu.completion_insert_offset;
    array_add(*command_line, ..cast([] u8) replacement);
    input_cursor = command_line.count;
}

replace_console_command_line :: (replacement: string) {
    using context.state;

    command_line.count = 0;
    array_add(*command_line, ..cast([] u8) replacement);
    input_cursor = command_line.count;
}

set_error_message :: (format: string, args: .. Any) {
    using context.state;

    reset(*info_message_builder);
    print(*info_message_builder, "\e[0;31m"); // color red
    print(*info_message_builder, format, ..args);
    print(*info_message_builder, "\e[0m");
    info_message_deadline = frame_time + 3;
} @PrintLike

set_info_message :: (format: string, args: .. Any, timeout := 3.0) {
    using context.state;

    reset(*info_message_builder);
    print(*info_message_builder, format, ..args);
    info_message_deadline = frame_time + timeout;
} @PrintLike

test_proc :: () {
    defer {
        "block"; "inside"; "defer";
    }

    T1 :: struct { f1: int; f2: int; };
    T2 :: struct { f3: T1; };
    using v1: T1;
    v2 := 123;
    // v3 := 321 + v2;
    // v4 := v2 + v3;
    // {
    //     v4 = v2 * v3;
    // }
    // v4 /= v2;
    // f1 = v4;
    // f2 = xx (v3 + f1);
    v5: T1;
    v5.f1 = f1 + v2;
    v5.f2 = f2 + v5.f2;
    v6 := T2.{ f3 = v5 };
    v6.f3.f2 = f2;
    if v2 > 100 {
        v6.f3 = v1;
    } else v6.f3 = v5;

    if v2 == {
        case 1;
        case 2;
        case 3;
    }

    { { "coupla bloks in"; } }

    for u8.[1,2,3] { "for"; }

    while true { break; }

    Macro :: () #expand {
        `decl: int;
    }
    Macro();

    // print("%, %, %, %, %", v2, v3, v4, f1, f2);
} @DumpAst

//
// completion menu
//

init_completion_menu :: () {
    reset_completion_menu();
}

reset_completion_menu :: () {
    using context.state;

    completion_menu.items.count = 0;
    completion_menu.displayed_items.count = 0;
    get_base_buffer(*completion_menu.builder_for_items).count = 0;
    completion_menu.width = xx (terminal_size.cols * 0.66);
    completion_menu.common_item_prefix = "";
}

add_completion_menu_item_simple :: (item: string, displayed_item := "") {
    using context.state.completion_menu;

    if !items then common_item_prefix = item;

    array_add(*items, item);
    array_add(*displayed_items, ifx displayed_item then displayed_item else item);

    if common_item_prefix {
        common_length := 0;
        max_prefix_length := min(item.count, common_item_prefix.count);
        for 0..max_prefix_length-1 {
            if item[it] != common_item_prefix[it] break;
            common_length += 1;
        }
        common_item_prefix = slice(common_item_prefix, 0, common_length);
    }
}

print_completion_menu_item :: (format: string, args: .. Any, actual_item: string = "", actual_item_is_prefix := -1) {
    temp_string := tprint(format, ..args);
    add_completion_menu_item(temp_string, actual_item=actual_item, actual_item_is_prefix=actual_item_is_prefix);
} @PrintLike

add_completion_menu_item :: (displayed_item_: string, actual_item: string, actual_item_is_prefix := -1) {
    using context.state;

    temp_string := displayed_item_;
    padding := 2; // 1 space on each side
    max_count := completion_menu.width - padding;
    if temp_string.count > max_count  temp_string.count = max_count;

    buffer := get_base_buffer(*completion_menu.builder_for_items);
    item_start := buffer.count;
    append(*completion_menu.builder_for_items, temp_string);
    assert(get_base_buffer(*completion_menu.builder_for_items) == buffer);

    displayed_item: string;
    displayed_item.data = get_buffer_data(buffer) + item_start;
    displayed_item.count = buffer.count - item_start;

    real_item := actual_item;
    if actual_item_is_prefix > 0 {
        count := min(actual_item_is_prefix, displayed_item.count);
        real_item = slice(displayed_item, 0, count);
    }
    assert(real_item.count > 0);

    add_completion_menu_item_simple(real_item, displayed_item);
}

maybe_render_completion_menu :: () {
    using context.state;

    if !completion_menu.is_active return;

    builder: String_Builder;
    builder.allocator = temp;

    max_width := 0;
    for completion_menu.displayed_items  max_width = max(max_width, it.count);

    for completion_menu.displayed_items {
        row := 3 + it_index;
        if row > terminal_size.rows break;

        print(*builder, "\e[%;%H", row, 1);
        if completion_menu.selected_item == it_index append(*builder, "\e[7m"); // invert color mode
        append(*builder, "\e[100m"); // background color gray
        print(*builder, " % ", it);
        append_padding(*builder, max_width - it.count);
        append(*builder, "\e[0m");
    }

    write_builder(*builder);
}

completion_menu_builder_remaining_capacity :: () -> s64 {
    using context.state;

    buffer := get_base_buffer(*completion_menu.builder_for_items);
    return buffer.allocated - buffer.count;
}

//
// command procs
//

console_commands: [..] Command;
init_commands :: () {
    if !console_commands {
        array_add(*console_commands, make_command("period", change_external_command_rerun_period));
        array_add(*console_commands, make_command("interval", change_external_command_rerun_period));
        array_add(*console_commands, make_command("command", set_external_command));
        array_add(*console_commands, make_command("log", set_log_file));
        array_add(*console_commands, make_command("memory_usage", make_toggle("show_memory_usage")));
        array_add(*console_commands, make_command("strip_control_codes", make_toggle("strip_control_codes")));
        array_add(*console_commands, make_command("number_lines", make_toggle("line_numberring")));
        array_add(*console_commands, make_command("line_numberring", make_toggle("line_numberring")));
        array_add(*console_commands, make_command("wrap_lines", make_toggle("line_wrapping")));
        array_add(*console_commands, make_command("line_wrapping", make_toggle("line_wrapping")));
        array_add(*console_commands, make_command("visualize_control_codes", make_toggle("visualize_control_codes")));
        array_add(*console_commands, make_command("party_time", make_toggle("party_time")));
        array_add(*console_commands, make_command("current_shown_buffer_number", set_current_shown_buffer_index));
        array_add(*console_commands, make_command("clear_buffer_history_up_to", clear_buffer_history_up_to));
        array_add(*console_commands, make_command("save_current_buffer", save_current_buffer));
        array_add(*console_commands, make_command("anti_flicker_period", set_anti_flicker_period));
        array_add(*console_commands, make_command("show_state_field", show_state_field));
        array_add(*console_commands, make_command("debug_break", do_debug_break));
        array_add(*console_commands, make_command("party_time_update_period", set_party_time_update_period));
    }
}

change_external_command_rerun_period :: (new_period: float32) -> (ok: bool, error_msg: string) {
    using context.state;

    if new_period <= 0.0001 return false, "value must not be less than 0.0001";

    old_period := external_command_run_period_seconds;
    external_command_run_period_seconds = new_period;

    time_next_command_run += new_period - old_period;

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
    log_file_name = copy_string(new_log_file);

    if log_file.handle file_close(*log_file);

    log_file=, ok := file_open(log_file_name, for_writing = true, keep_existing_content = true, log_errors = false);
    if !ok {
        code, message := get_error_value_and_string();
        return false, tprint("open('%'): (%) %", new_log_file, code, message);
    }
    log("start logging");
    return true, "";
}

set_current_shown_buffer_index :: (number: s64) -> (ok: bool, error_message: string) {
    using context.state;

    index: s64;
    if number < 0  index = main_window_buffer_history.count + number;
    else           index = number - 1;
    index = clamp(index, 0, main_window_buffer_history.count - 1);

    show_latest_buffer = (index == main_window_buffer_history.count - 1);
    current_shown_buffer_index = index;

    return true, "";
}

set_anti_flicker_period :: (number: float64) -> (ok: bool, error_message: string) {
    using context.state;

    anti_flicker_period = number;

    return true, "";
}

set_party_time_update_period :: (number: float64) -> (ok: bool, error_message: string) {
    using context.state;

    party_time_update_period = xx number;

    return true, "";
}

clear_buffer_history_up_to :: (leading_count_to_delete: s64) -> (ok: bool, error_message: string) {
    using context.state;

    if leading_count_to_delete < 0 {
        return false, "number must be positive";
    }

    // Never remove the latest buffer
    count := min(leading_count_to_delete, main_window_buffer_history.count - 1);
    for 0..count-1 {
        using main_window_buffer_history[it];
        free(raw_text_and_control_codes);
        array_free(only_text_storage);
        array_free(control_codes);
        array_free(line_offsets);
    }
    array_ordered_remove_range(*main_window_buffer_history, 0, count);

    current_shown_buffer_index = main_window_buffer_history.count - 1;
    show_latest_buffer = true;

    return true, "";
}

save_current_buffer :: (filename: string) -> (ok := true, error_message := "") {
    using context.state;

    if current_shown_buffer_index < 0 || !main_window_buffer_history {
        return false, "current buffer is empty, nothing to save";
    }

    file, ok := file_open(filename, log_errors=false);
    if ok {
        file_close(*file);
        return false, tprint("file '%' already exists, overwriting isn't supported yet", filename);
    }

    file, ok = file_open(filename, for_writing=true, log_errors=false);
    if !ok {
        code, message := get_error_value_and_string();
        return false, tprint("failed creating file '%': #% %", filename, code, message);
    }
    defer file_close(*file);

    using main_window_buffer_history[current_shown_buffer_index];
    ok = file_write(*file, raw_text_and_control_codes);

    if !ok {
        code, message := get_error_value_and_string();
        return false, tprint("failed writing to file '%': #% %", filename, code, message);
    }

    return;
}

show_state_field :: (path: string) -> (ok := true, error_message := "") {
    using context.state;

    ok, field, field_prefix := get_subfield_by_path(*context.state, path);
    if !ok {
        return false, context.last_error.message;
    }

    set_info_message("%", field);
    return;
}

do_debug_break :: () -> (ok := true, error_message := "") {
    debug_break();
    return;
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
    redraw_once = true;

    return true, "";
}

        CODE, field);
        return builder_to_string(*builder);
    };

    return proc;
}

//
// party mode
//

do_party_mode :: () {
    using context.state;

    now := seconds_since_init();
    if party_time_next_update_time > now then return;
    party_time_next_update_time = now + party_time_update_period;

    width  := cast(float) terminal_size.cols;
    height := cast(float) terminal_size.rows;

    tick += 1;
    if particles.count == 0 || tick % 4 == 0 {
        colors :: string.[
            "\e[38;2;255;0;0m",
            "\e[38;2;0;255;0m",
            "\e[38;2;255;255;0m",
            "\e[38;2;0;0;255m",
            "\e[38;2;255;0;255m",
            "\e[38;2;0;255;255m",
        ];
        // spawn up to 3 particles
        n_to_spawn := 1 + random_get() % 3;
        for 1..n_to_spawn {
            x := (width - 1) * random_get_zero_to_one();
            r := random_get();
            color := colors[r % colors.count];
            array_add(*particles, .{
                position = .{ x, 0 },
                ansi_color = color,
                animation_offset = r,
            });
        }
    }

    // Patch up the previous locations of particles with actual text
    for particles {
        x := cast(int) it.position.x;
        y := cast(int) it.position.y;
        if x < 0 || x >= terminal_size.cols continue;
        if y < 0 || y >= terminal_size.rows continue;

        col := x;
        row := y - 2; // :2_status_lines
        if row < 0 continue;

        get_text_patch :: (col: int, row: int, count: int) -> string {
            using context.state;

            if row >= last_shown_line_buffer.count {
                way_too_many_spaces :: "                                ";
                assert(count <= way_too_many_spaces.count);
                result := cast(string) way_too_many_spaces;
                result.count = count;
                return result;
            }

            line := last_shown_line_buffer[row];
            while line && line[line.count - 1] == #char "\n"
                line.count -= 1;

            count_to_skip := col;
            expected_length := count;
            tail := line;
            builder: String_Builder;
            while tail {
                head:, visible_count:, tail = eat_visible_or_escape_sequence(tail);
                if visible_count == 0 {
                    didnt_add_any_visible_text_yet := expected_length == count;
                    if didnt_add_any_visible_text_yet && is_mode_reset_control_sequence(head) {
                        reset(*builder);
                    } else {
                        append(*builder, head);
                    }
                    continue;
                }

                c, ok := utf8_count(head, false);
                // assert(ok, "col: %, row: %, count_to_skip: %, line:\n`%`\nhead:\n`%`\n", col, row, count_to_skip, cast(Ascii_Or_Hex)line, cast(Ascii_Or_Hex)head);
                if c <= count_to_skip {
                    count_to_skip -= c;
                    continue;
                }

                char, utf8_chars := utf8_substring(head, count_to_skip, expected_length, false);
                append(*builder, char);
                assert(utf8_chars <= expected_length);
                count_to_skip = 0;
                expected_length -= utf8_chars;
                if expected_length == 0 {
                    break;
                }
            }
            append_padding(*builder, expected_length);
            append(*builder, "\e[0m");
            return builder_to_string(*builder,, temp);
        }

        count := 2;
        if x == terminal_size.cols - 1 then count = 1;
        patch := get_text_patch(col, row, count);

        print("\e[%;%H%", y + 1, x + 1, patch); // `+ 1` because cursor positions start at 1
    }

    for *particles {
        it.x += (random_get_zero_to_one() - 0.5) * 2;
        if it.x > width - 1 then it.x -= width;
        if it.x < 0         then it.x += width;

        it.y += random_get_zero_to_one();
        if it.y < 0      then remove it;
        if it.y > height then remove it;
    }

    for particles {
        x := cast(int) it.x;
        y := cast(int) it.y;
        if x < 0 || x >= terminal_size.cols continue;
        if y < 0 || y >= terminal_size.rows continue;

        chars :: string.[
            "⠊⣵", "⢨⡵", "⣤⡱", "⢶⡰", "⢟⡠", "⢞⡃", "⢎⠛", "⠎⠷",
        ];
        s := chars[(tick + it.animation_offset) % chars.count];

        // TODO: color interpolation
        // color1 :: u8.[ 255, 0, 255 ];
        // color2 :: u8.[ 227, 71, 43 ];
        // N :: 32;
        // if !color_range {
        //     c1 := rgb_to_hsv()
        //     array_reserve(*color_range, N);
        //     for 1..N {

        //         array_add(*color_range, sprint(""))
        //     }
        // }

        color := it.ansi_color;
        if x == terminal_size.cols - 1 then s.count /= 2;
        print("\e[%1;%2H%3%4", y + 1, x + 1, color, s); // `+ 1` because cursor positions start at 1
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

    builder: String_Builder;
    print_date_time_for_log(*builder, to_calendar(current_time_consensus(), .LOCAL));
    filename := path_filename(info.location.fully_pathed_filename);
    print(*builder, ": [%:%] %\n", filename, info.location.line_number, message);
    file_write(*state.log_file, builder_to_string(*builder,, temp));
    fflush(state.log_file.handle);
}

//
// reflection/introspection utilities
//

get_subfield_by_path :: inline (value: *$T, path: string, allow_partial := false) -> bool, Any, string {
    found, result, remainder := get_subfield_by_path(value, type_info(T), path, allow_partial);
    return found, result, remainder;
}

// TODO: support getting a partial result to help with auto completion
get_subfield_by_path :: (value_pointer: *void, type: *Type_Info, path_: string, allow_partial := false) -> bool, Any, remainder := "" {
    result: Any;
    result.value_pointer = value_pointer;
    result.type = type;

    path := trim(path_);
    if path == "" {
        return true, result;
    }

    head := path;
    cursor := 0;
    head_end := -1;
    while true {
        if cursor == path.count return true, result;

        search_start := cursor;
        first := path[search_start];
        if (first == #char ".") || (first == #char "[")  search_start += 1;
        tail := trim_left(advance(path, search_start));

        head_count := find_index_of_any_from_left(tail, ".[");
        if head_count < 0 {
            head_end = path.count;
        } else {
            head_end = search_start + head_count;
        }
        head_count = head_end - cursor;
        defer cursor = head_end;

        head = trim_right(slice(path, cursor, head_count));
        if !head return true, result; // reached end and no errors were found, so it's good probably..

        if head[0] == #char "[" {
            if (result.type.type != .ARRAY) && (result.type.type != .STRING) {
                return set_last_error("`%` is not an array, can't index into it", slice(path, 0, cursor)), result;
            }

            ok, new_result := get_array_element_as_any(result, head);
            if !ok {
                prepend_error_message("failed indexing into `%`: ", slice(path, 0, cursor));
                return false, result;
            }

            result = new_result;
            continue;
        }

        if head[0] == #char "." advance(*head, 1);

        // head is not an index expression
        if result.type.type == {
            case .ARRAY; #through;
            case .STRING;
                ok, new_result := get_array_or_string_property_as_any(result, head);
                if ok {
                    result = new_result;
                    continue;
                }
                if !head && allow_partial {
                    return true, result, head;
                }
        }

        if result.type.type != .STRUCT {
            return set_last_error("`%` is not a struct, can't get field `%` from it", slice(path, 0, cursor), head), result;
        }

        member: *Type_Info_Struct_Member;
        for *(cast(*Type_Info_Struct) result.type).members if it.name == head {
            member = it;
            break;
        }
        if !member {
            if allow_partial {
                return true, result, head;
            } else {
                return set_last_error("no such field `%` in `%`", head, slice(path, 0, cursor)), result;
            }
        }

        result.value_pointer += member.offset_in_bytes;
        result.type = member.type;
    }

    assert(false, "unreachable");
    return false, result;
}

get_array_or_string_property_as_any :: (array_or_string: Any, property: string) -> (bool, Any) {
    result: Any;
    type := array_or_string.type;
    value_pointer := array_or_string.value_pointer;
    assert(type.type == .ARRAY || type.type == .STRING);

    if property == {
        case "count";
            if type.type == {
                case .ARRAY;
                    result.type = type_info(s64);
                    array_type := cast(*Type_Info_Array) type;
                    if array_type.array_type == .FIXED {
                        result.value_pointer = *array_type.array_count;
                    } else {
                        array := cast(*Array_View_64) value_pointer;
                        result.value_pointer = *array.count;
                    }
                case .STRING;
                    result.type = type_info(s64);
                    string_ := cast(*string) value_pointer;
                    result.value_pointer = *string_.count;
            }
            return true, result;

        case "data";
            if type.type == {
                case .ARRAY;
                    array_type := cast(*Type_Info_Array) type;
                    pointer_to_element_type := New(Type_Info_Pointer,, temp);
                    pointer_to_element_type.type = .POINTER;
                    pointer_to_element_type.runtime_size = size_of(*void);
                    pointer_to_element_type.pointer_to = array_type.element_type;
                    result.type = pointer_to_element_type;

                    if array_type.array_type == .FIXED {
                        result.value_pointer = value_pointer;
                    } else {
                        array := cast(*Array_View_64) value_pointer;
                        result.value_pointer = *array.data;
                    }
                case .STRING;
                    result.type = type_info(*u8);
                    string_ := cast(*string) value_pointer;
                    result.value_pointer = *string_.data;
            }
            return true, result;

    }

    return false, result;
}

get_array_element_as_any :: (array: Any, index_expression: string) -> (bool, Any) {
    result: Any;

    if array.type.type != .ARRAY return set_last_error("value is not an array"), result;

    expression := trim_left(index_expression);
    if !expression || expression[0] != #char "[" return set_last_error("expected a `[` at the beginning"), result;
    advance(*expression, 1);

    expression = trim_left(expression);
    index:, ok:, expression = string_to_int(expression);
    if !ok return set_last_error("expected an integer after `[`, got %", expression), result;

    expression = trim_left(expression);
    if !expression || expression[0] != #char "]" return set_last_error("expected a closing `]`"), result;
    advance(*expression, 1);

    expression = trim_left(expression);
    if expression.count > 0 return set_last_error("unexpected text at the end: '%'", expression), result;

    array_type := cast(*Type_Info_Array) array.type;
    array_view := array_view_from_any(array.value_pointer, array_type);

    // FIXME: this is just a modulo operation
    while index < 0  index += array_view.count;

    if index >= array_view.count return set_last_error("index % is out of range (array count: %)", index, array_view.count), result;

    result.type = array_type.element_type;
    result.value_pointer = array_view.data + array_type.element_type.runtime_size * index;
    return true, result;
}

array_view_from_any :: (value_pointer: *void, type: *Type_Info_Array) -> Array_View_64 {
    array_view: Array_View_64;
    if type.array_type == .FIXED {
        array_view.data = value_pointer;
        array_view.count = type.array_count;
    } else {
        array_view = << cast(*Array_View_64) value_pointer;
    }
    return array_view;
}

type_supports_subfields :: (type: *Type_Info) -> bool {
    return type.type == .STRUCT || type.type == .ARRAY || type.type == .STRING;
}

test_get_subfield_by_path :: () {
    MyStruct :: struct {
        num: int = 420;
        nested: struct {
            str: string = "yooo";
            nested: [3] struct {
                array: [3] u8 = .[ 3, 2, 1 ];
            };
        };
    }

    s: MyStruct;

    paths: [] string = string.[
        "num", "nested", "nested.str", "nested.nested",
        "nested.nested[1].array",
        "nested.nested[2].array[0]",
        "nested.nested[-1].array[-1]",
    ];
    for path: paths {
        print("-------- get_subfield_by_path('%')\n", path);
        ok, field := get_subfield_by_path(*s, path);
        assert(ok);
        print("OK: %: %\n", path, field);
    }

    paths = string.[
        "nu", "nes.ted.str", "nested..nested",
        "nested.nested[100].array",
        "nested.nested[2][0].array[0]",
    ];
    for path: paths {
        print("-------- get_subfield_by_path('%')\n", path);
        ok, field := get_subfield_by_path(*s, path);
        assert(!ok);
        builder: String_Builder;
        print_last_error(*builder, .ONLY_MESSAGE);
        print("ERROR: %\n", builder_to_string(*builder));
    }
}

//
// http server
//

init_http_server :: () -> bool {
    state := *context.state;
    server := *context.state.http_server;
    server.epoll_fd = *state.epoll_fd;
    server.http_request_handler = http_request_handler;

    if !init_tcp_server(server) return false;
    if !tcp_server_start_listenning(server) return false;

    return true;
}

http_serve_resource :: (request: *Http_Request, data: *void) -> bool {
    builder := get_response_body_builder(request);

    file := request.uri;
    if file == "/" then file = "/index.html";

    resource_path := tprint("%1server%2", #filepath, file);
    ok := read_entire_file_to_builder(builder, resource_path);
    if !ok {
        set_last_error_from_system();
        prepend_error_message("failed reading file '%': ", resource_path);
        log_last_error(.WITH_STACK_TRACE);

        request.response_code = 404;
        return false;
    }

    extension:, ok = path_extension(file);
    if ok if extension == {
        case "wasm"; // This one is mandatory, the others seem to be optional
            print_response_header(request, "Content-Type", "application/wasm");
        case "js";
            print_response_header(request, "Content-Type", "text/javascript");
        case "html";
            print_response_header(request, "Content-Type", "text/html");
    }

    return true;
}

http_request_handler :: (request: *Http_Request, data: *void) -> bool {
    if !starts_with(request.uri, "/api") {
        return http_serve_resource(request, data);
    }

    builder := get_response_body_builder(request);

    print(builder, "Hello!\n");

    print(builder, "Date/time: ");
    date_time := to_calendar(current_time_consensus(), .LOCAL);
    print_date_time_for_log(builder, date_time);
    print(builder, "\n");

    if request.parameters {
        print(builder, "Parameters were: '%'\n", request.parameters);
    }

    print(builder, "Your address is %:%\n", request.connection.peer_host, request.connection.peer_port);

    return true;
}

//
// history file
//

HISTORY_FILE_NAME :: ".pageview_command_line_history";

read_history_file :: () {
    using context.state;

    exe_path := System.get_path_of_running_executable();
    exe_dir := path_strip_filename(exe_path);
    assert(last(exe_dir) == #char "/");

    history_filepath = sprint("%1%2", exe_dir, HISTORY_FILE_NAME);

    data, ok := my_read_entire_file(history_filepath, log_errors=true);
    if !ok return;

    tail := data;
    while tail {
        found:, line:, tail = split_from_left(tail, #char "\n");
        if !line continue;

        first := line[0];
        command_line := advance(line);

        if first == {
            case #char ":"; array_add(*command_line_history,  command_line);
            case #char "/"; array_add(*search_string_history, command_line);
            case; log_error("garbage in history file: '%'", line);
        }
    }
}

History_File_Entry_Type :: enum {
    INVALID;
    SEARCH;
    COMMAND;
}

maybe_append_command_line_to_history :: () {
    using context.state;

    history, kind := get_history_for_input_mode();
    if command_line && (!history.count || cast(string) command_line != history.*[history.count - 1]) {
        array_add(history, copy_string(xx command_line));
        append_line_to_history_file(kind, xx command_line);
    }
}

append_line_to_history_file :: (kind: History_File_Entry_Type, text: string) {
    using context.state;

    file, ok := file_open(history_filepath, for_writing=true, keep_existing_content=true);
    if !ok return;
    defer file_close(*file);

    builder: String_Builder;
    builder.allocator = temp;

    if #complete kind == {
        case .SEARCH;  append(*builder, "/");
        case .COMMAND; append(*builder, ":");
        case .INVALID; append(*builder, "<INVALID>");
    }
    append(*builder, text);
    append(*builder, "\n");

    data := builder_to_string(*builder,, temp);
    file_write(*file, data.data, data.count);
}

//
// print utilities
//


My_Struct_Printer_Data :: struct {
    variant_printers: [..] struct {
        type: *Type_Info;
        printer: (builder: *String_Builder, any: Any, struct_printer_data: *void) -> bool;
    };
}

my_struct_printer :: (builder: *String_Builder, any: Any, struct_printer_data: *void) -> bool {
    using my_struct_printer_data := cast(*My_Struct_Printer_Data) struct_printer_data;

    for variant_printers {
        if it.type == any.type {
            if it.printer(builder, any, struct_printer_data) return true;
        }
    }

    return false;
}

//
// small bytes
//

Small_Bytes :: struct {
    count: u8;
    first: u8;
    #place first;
    data: [15] u8;
}
#assert size_of(Small_Bytes) == 16;

to_string :: inline (using bytes: Small_Bytes) -> string {
    return string.{ count, data.data };
}

make_small_bytes :: inline (data: string) -> Small_Bytes {
    result: Small_Bytes = ---;
    assert(data.count <= result.data.count, "'%' (%)", cast(Ascii_Or_Hex) data, data.count);

    result.count = xx data.count;
    memcpy(result.data.data, data.data, data.count);
    return result;
}

small_bytes_printer :: (builder: *String_Builder, any: Any, struct_printer_data: *void) -> bool {
    if any.type != type_info(Small_Bytes) return false;

    s := << cast(*Small_Bytes) any.value_pointer;
    print_small_bytes(builder, s);

    return true;
}

print_small_bytes :: inline (builder: *String_Builder, bytes: Small_Bytes) {
    append(builder, #char "\"");
    print_ascii_or_hex(builder, to_string(bytes));
    append(builder, #char "\"");
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
    if slice(s, 0, 2) != "\e[" return false;
    if last(s) != #char "m" return false;
    if s.count == 3 return true;

    for 0..(s.count-1)-3
        if s[2 + it] != #char "0"
            return false;

    return true;
}

count_occurences :: (text: string, byte: u8) -> s64 {
    count := 0;

    cursor := 0;
    while true {
        cursor = inline find_index_from_left(text, byte, cursor);
        if cursor < 0 break;
        cursor += 1;
        count += 1;
    }

    return count;
}

//
// human readable memory sizes
//

Human_Readable_Memory :: #type,isa s64;

human_readable_memory_printer :: (builder: *String_Builder, any: Any, struct_printer_data: *void) -> bool {
    if any.type != type_info(Human_Readable_Memory) return false;

    s := << cast(*s64) any.value_pointer;
    print_human_readable_memory_size(builder, s);

    return true;
}

print_human_readable_memory_size :: (builder: *String_Builder, size_in_bytes: s64) {
    if size_in_bytes < 1024 {
        print(builder, "%", size_in_bytes);
        return;
    }

    if size_in_bytes < 1024 * 1024 {
        kilos := (cast(f64) size_in_bytes) / 1024;
        print(builder, "%K", FormatFloat.{ value = kilos, trailing_width = 3 });
        return;
    }

    if size_in_bytes < 1024 * 1024 * 1024 {
        megs := (cast(f64) size_in_bytes) / 1024 / 1024;
        print(builder, "%M", FormatFloat.{ value = megs, trailing_width = 3 });
        return;
    }

    if size_in_bytes < 1024 * 1024 * 1024 * 1024 {
        gigs := (cast(f64) size_in_bytes) / 1024 / 1024 / 1024;
        print(builder, "%G", FormatFloat.{ value = gigs, trailing_width = 3 });
        return;
    }

    teras := (cast(f64) size_in_bytes) / 1024 / 1024 / 1024 / 1024;
    print(builder, "%T", FormatFloat.{ value = teras, trailing_width = 3 });
    return;
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

last :: inline (array: [] $T) -> T {
    assert(array.count != 0);
    return array[array.count - 1];
}

last :: inline (s: string) -> u8 {
    return s[s.count - 1];
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

strerror :: (code: u32) -> *u8 #foreign libc;

//
// terminal settings
//

// Hide cursor, disable echo, etc.
init_terminal_settings :: () {
    using context.state;

    context.assertion_failed = (loc: Source_Code_Location, message: string) -> bool {
        restore_terminal_settings();
        return runtime_support_assertion_failed(loc, message);
    };

    //
    // special control codes
    //
    setup_control_codes: [..] string;
    array_add(*setup_control_codes,
        "\e[?1049h", // enable the alternative buffer
        "\e[?25l", // hide cursor
        "\e[?1002h", // enable mouse events: click, wheel + drag
        "\e[?1006h", // alternate mouse input format
    );
    write_strings(..setup_control_codes);

    for *setup_control_codes {
        it.* = copy_string(it.*);
        last_char := *it.*[it.count - 1];
        if last_char.* == {
            case #char "l"; last_char.* = #char "h";
            case #char "h"; last_char.* = #char "l";
            case; assert(false, "%: %", it_index, it.*);
        }
    }
    global_teardown_control_codes = setup_control_codes;

    //
    // termios attributes
    //
    if tcgetattr(STDIN_FILENO, *global_saved_termios) {
        set_last_error_from_system();
        log_last_error(.WITH_SOURCE_LOCATION);
        assert(false, "%", context.last_error.message);
    }

    new_termios := global_saved_termios;

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

    if tcsetattr(STDIN_FILENO, TCSADRAIN, *new_termios) {
        set_last_error_from_system();
        log_last_error(.WITH_SOURCE_LOCATION);
        assert(false, "%", context.last_error.message);
    }
}

global_teardown_control_codes: [] string;
global_saved_termios: Termios;
restore_terminal_settings :: () #c_call #no_context {
    write_strings(..global_teardown_control_codes);
    tcsetattr(STDIN_FILENO, TCSADRAIN, *global_saved_termios);
}

term_exit :: (status: s32) {
    restore_terminal_settings();
    exit(status);
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

SYS_pidfd_open :: 434;

profile_t0: f64 = 0.0;
Profile :: (format: string = "", args: ..Any, loc := #caller_location) #expand {
    t1 := seconds_since_init();
    elapsed := t1 - `profile_t0;
    if elapsed > .1 {
        msg := tprint(format, ..args);
        log("[elapsed: %]: %", elapsed, msg, loc=loc);
    }
    `profile_t0 = t1;
} @PrintLike

debug_log :: ($args: .. Code) #expand {
    builder: String_Builder;
    builder.allocator = temp;
    print_vars_helper(*builder, .{}, args);
    s := builder_to_string(*builder,, temp);
    log("%", trim_right(s));
}

get_error_value_and_string :: () -> u32, string {
    code := System.get_error_value();
    message := to_string(strerror(xx code));
    return xx code, copy_temporary_string(message);
}

blocking_getchar :: () {
    while getchar() == -1 {
        if errno() != EWOULDBLOCK return;
        sleep_milliseconds(1);
    }
}

//
// meow hash wrapper with normal spelling
//

Meow_Hash_State :: Meow_Hash.meow_state;
Meow_Hash_Default_Seed :: #run -> [128] u8 { return Meow_Hash.MeowDefaultSeed; }

Meow_Hash_Init :: (state: *Meow_Hash_State, seed: [128] u8 = Meow_Hash_Default_Seed) #expand {
    Meow_Hash.MeowBegin(state, seed);
}

Meow_Hash_Consume :: (state: *Meow_Hash_State, data: *void, count: s64) #expand {
    Meow_Hash.MeowAbsorb(state, count, data);
}

Meow_Hash_Consume :: (state: *Meow_Hash_State, bytes: [] u8) #expand {
    Meow_Hash.MeowAbsorb(state, xx bytes.count, bytes.data);
}

Meow_Hash_Finalize :: (state: *Meow_Hash_State) -> U128 #expand {
    #asm { hash: vec; };
    Meow_Hash.MeowEnd(state, hash);
    result: U128 = ---;
    result.low = Meow_Hash.MeowU64From(hash, 0);
    result.high = Meow_Hash.MeowU64From(hash, 1);
    return result;
}

Meow_Hash_Compute :: (bytes: [] u8, seed: [128] u8 = Meow_Hash_Default_Seed) -> U128 {
    state: Meow_Hash_State;
    Meow_Hash_Init(*state, seed);
    Meow_Hash_Consume(*state, bytes);

    return inline Meow_Hash_Finalize(*state);
}

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
#import "File";
#import "Flat_Pool";
#import "Print_Vars";
#import "Reflection";
#import "Program_Print";
#import "Math";
#import "Unicode";
#import "Random";
#import "Error_Info";
#import "Http";
Meow_Hash :: #import "meow_hash";
// #if OS == .LINUX #import "X11";
// #import "Clipboard";
System :: #import "System";
