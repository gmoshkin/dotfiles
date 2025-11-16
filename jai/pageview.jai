/* TODO:
  - FEATURE: dynamic filters a-la fzf/CtrlP
  - FEATURE: merging output from multiple files/input sources + orderring by date and maybe more
    (I'm hoping for log-viewer style usage but also better)

  - FEATURE: do a fucking --help already!!!

  - don't crash if window size is 0

  - set window name on start

  - @BUG @scrollbar slider is wrong at the bottom of the screen!!!

  - IMPROVEMENT: scrollbar @text_search matches use braille or digits or something else to
    show how many matches there are, because screen row granularity sucks :c

  - IMPROVEMENT: git @diff_headers thingy should be more general, I would like to also
    support the "commit", but the code is too hacky at the moment, needs refactoring
  - IMPROVEMENT: git @diff_headers don't work with `git --graph` style output and my `gl` output format

  - FEATURE: @text_search @completion: when parsing the raw buffer input collect
    all the identifiers(words) and do completion based on that
    - also prioritize words currently on screen, for that just scan the current
      screen portion of the buffer, it should be super quick

  - FEATURE: @marks:
    - set manual mark on one of the lines
    - one of the random colors is chosen
        - can also specify a color
    - mark is highlighted on the @scrollbar
    - QUESTION: what happens when text updates?
        - would be cool to detect text changes a-la diff and move the mark
          accordingly if possible
        - super stupid solution: find a line with same text somewhere around and
          move the mark there

  - FIX A BUG in @completion where . is not being added
  - @completion menu scrolling

  - FEATURE: @save the whole @buffer_history
    - could support @autosave if enabled
    - ask to save before closing if @autosave is not enabled

  - FEATURE: command to show @diff between buffer versions (maybe even in split view)
      although I can just use the tmux splits for that....

  - IMPROVEMENT: optimize parsing the input stream. Currently I read the whole buffer in and
    parse it all together, but then I only show a small portion of that, this sucks.
    `git log -p` doesn't work because of that. Potential solutions:
    - parse stream in chunks, don't reparse chunks if they didn't change
    - don't parse further than needed. Although my search command relies on the
      whole input being parsed which sucks, should rework it also

  - FEATURE: option to watch a file/directory for changes and only rerun the command then
    Some use cases for that:
        - lightweight LSP alternative `pageview --watch src/ 'jai src/myprogram.jai'`
        - ?

  - FEATURE: doing simple filters is going to be simple?
        Like having an array of simple filters of kind
          - replace all ' ' with '\n' and stuff
          But I don't wanna be supporting regular expressions though
  - IMPROVEMENT: smarter word selection when clicking on text:
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
    run_tests := false;
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

    input_buffer: [..] u8;
    input_received_this_tick: bool;

    f_repeat_count: s64;

    completion_menu: Completion_Menu;

    //
    // @text_search
    //
    search: Search_Matches;

    //
    // command line history
    //
    history_filepath: string;

    //
    // @status_line
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
    http_server_enabled_explicitly := false;
    http_server_disabled_explicitly := false;
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
        EXTERNAL_COMMAND_WHICH_COMES_FROM_STDIN;
        PIPED_INPUT;
        DRAWING_MODE;
        GAME_OF_LIFE;
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
    command_version: int; // number of times command changed

    external_command_process: Process;
    external_command_started: float64;
    external_command_output_builder: String_Builder;
    external_command_error_builder: String_Builder;

    external_command_finished_count: u64;
    external_command_last_handled_output_version: u64;

    external_command_run_period_seconds := 1.0;
    external_command_backoff_multiplier: float64 = 1.0; // @external_command_exponential_backoff
    external_command_run_period_max: float64 = 10 * 60;
    external_command_backoff_mode: enum_flags {
        OFF :: 0x0;
        ON :: 0x1;
        SMART :: 0x2;
        CHECKING :: 0x4; // in smart mode but not decided yet
    } = .SMART | .CHECKING;
    SMART_BACKOFF_THRESHOLD :: 10;
    time_next_command_run : float64 = -1.0;
    last_command_result: Process_Result;
    last_command_result.exit_code = 0; // by default that would be -1, but I don't want that
    last_command_finish: float64 = -1.0;
    last_command_duration: float64 = -1.0;
    second_to_last_command_finish: float64 = -FLOAT64_INFINITY;

    anti_flicker_period: float64 = 0.2;

    // @external_command_exponential_backoff
    smart_backoff_change_counter: u64;
    smart_backoff_run_counter: u64;
    smart_backoff_no_change_counter: u64;

    //
    // source: DRAWING_MODE
    //
    current_pixel_fg := #run Pixel_Value.rgb(0xe5, 0xe5, 0xe5);
    current_pixel_bg := #run Pixel_Value.rgb(0x33, 0x33, 0x33);
    pixel_buffer: [..] Pixel_Value;
    pixel_window_size: Vector2;
    pixel_size: enum {
        TWO_CHARACTERS;
    };

    //
    // GAME_OF_LIFE
    //
    cell_field_history: [..] Cell_Field;
    current_cell_field_index_in_history: int;

    cell_field_width := 256;
    cell_field_height := 256;

    cell_field_offset_x: int;
    cell_field_offset_y: int;

    cell_field_zoom_area_offset_x: int;
    cell_field_zoom_area_offset_y: int;

    game_of_life_paused: bool;
    game_of_life_tick_needed: bool;
    tick_period := 1.0;
    next_tick_time := 0.0;

    //
    // rendering
    //
    redraw_once := false;
    main_window_buffer_history: [..] Window_Buffer;
    next_window_buffer_source_version: u64 = 1;
    current_shown_buffer_index: s64;
    show_latest_buffer := true;
    main_window_renderred_times := 0;
    main_window_render_requested := false;

    //
    // @scrollbar
    //
    draw_scrollbar := true;
    scrollbar_zoom_ratio: float;
    scrollbar_slider_height: s64;
    scrollbar_slider_top: s64;
    scrollbar_slider_bottom: s64;
    scrollbar_search_matches: Bit_Array; // also @text_search
    scrollbar_resolution: s64;

    selection_cursor := -1;
    last_selected_string: string;

    current_screen_row: s64;
    current_row_left_offset: s64; // XXX: this name sucks
    current_line_number: s64;

    // Stores pointers into `last_shown_line_buffer_flat_pool`.
    last_shown_line_buffer: [..] string;
    last_shown_line_buffer_version: s64;
    last_renderred_line_buffer: [] string;
    target_fps: s32 = 60;
    time_last_shown: float64;
    memory_pool_for_last_shown_line_buffer: Flat_Pool;
    memory_pool_for_last_shown_line_buffer_high_water_mark: s64;

    temporary_storage_memory_pool: Flat_Pool;
    temporary_storage_high_water_mark: s64;

    // Value is how many times control code was seen this run.
    // So if it's 0 than it was loaded from the history file.
    all_unique_control_codes: Table(Small_Bytes, int, get_hash, small_bytes_equals);

    //
    // copy to clipboard (tmux currently)
    //
    children_for_copying_to_clipboard: [..] struct { process: Process; name: string; };

    tmux_env: string;
    tmux_info_ready := false;
    tmux_info_process_started := false;
    tmux_info_process_finished := false;
    tmux_info_command: [..] string;
    tmux_info_process: Process;
    tmux_info_builder: String_Builder;
    tmux_pane_id: string;
    tmux_pane_coordinates: string;

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
#add_context state: *State;

Delayed_Action :: struct {
    type: enum {
        MOUSE_SELECTION_CLICK;
    };
}

Cell_Position :: struct {
    row: s32;
    column: s32;
}

Pixel_Value :: struct {
    type: enum {
        RGB;
        COLOR_8BIT;
    };
    union {
        using _rgb: struct {
            r: u8;
            g: u8;
            b: u8;
        };
        _8bit: Color_8bit;
    };

    rgb :: (r: u8, g: u8, b: u8) -> Pixel_Value {
        res: Pixel_Value;
        res.type = .RGB;
        res.r = r;
        res.g = g;
        res.b = b;

        return res;
    }

    id :: (id: u8) -> Pixel_Value {
        res: Pixel_Value;
        res.type = .COLOR_8BIT;
        res._8bit = xx id;

        return res;
    }
}

print_pixel_value :: (builder: *String_Builder, using v: Pixel_Value, $fg := false) {
    #if fg {
        if type == {
            case .RGB;          print(builder, "\e[38;2;%;%;%m", r, g, b);
            case .COLOR_8BIT;    print(builder, "\e[38;5;%m", cast(u8) _8bit);
        }
    } else {
        if type == {
            case .RGB;          print(builder, "\e[48;2;%;%;%m", r, g, b);
            case .COLOR_8BIT;    print(builder, "\e[48;5;%m", cast(u8) _8bit);
        }
    }
}

get_red :: (using v: Pixel_Value) -> u8 {
    if type == {
        case .RGB;
            return r;

        case .COLOR_8BIT;
            if _8bit == {
                case .RED;          return 0xdd;
                case .BRIGHT_RED;   return 0xff;
                case .GRAY_1;       return 11;
                case .GRAY_2;       return 22;
                case .GRAY_3;       return 33;
                case .GRAY_4;       return 44;
                case .GRAY_5;       return 55;
                case .GRAY_6;       return 67;
                case .GRAY_7;       return 78;
                case .GRAY_8;       return 89;
                case .GRAY_9;       return 100;
                case .GRAY_10;      return 111;
                case .GRAY_11;      return 122;
                case .GRAY_12;      return 133;
                case .GRAY_13;      return 144;
                case .GRAY_14;      return 155;
                case .GRAY_15;      return 166;
                case .GRAY_16;      return 177;
                case .GRAY_17;      return 188;
                case .GRAY_18;      return 200;
                case .GRAY_19;      return 211;
                case .GRAY_20;      return 222;
                case .GRAY_21;      return 233;
                case .GRAY_22;      return 244;
                case .GRAY_23;      return 255;
            }
            if _8bit >= .RGB_1_0_0 && _8bit <= .RGB_1_5_5 return 1 * 0x33;
            if _8bit >= .RGB_2_0_0 && _8bit <= .RGB_2_5_5 return 2 * 0x33;
            if _8bit >= .RGB_3_0_0 && _8bit <= .RGB_3_5_5 return 3 * 0x33;
            if _8bit >= .RGB_4_0_0 && _8bit <= .RGB_4_5_5 return 4 * 0x33;
            if _8bit >= .RGB_5_0_0 && _8bit <= .RGB_5_5_5 return 5 * 0x33;
    }

    return 0;
}

Window_Buffer :: struct {
    index_in_history: s64;
    source_version: u64;
    time_generated: Apollo_Time;
    duration: f64;
    hash: U128;
    source: type_of(State.main_window_source);
    flags: enum_flags {
        DIFF_MARKERS; // @diff_headers
    }

    raw_text_and_control_codes: string;
    last_line_offset_in_raw_text: s64;

    only_text_storage: [..] u8; // allocated separately
    only_text: string; // points into `only_text_storage`

    line_offsets: [..] s64; // offsets into `only_text`
    max_line_length: s64;

    control_codes: [..] Control_Code_Info; // offsets into `only_text`, data into `raw_text_and_control_codes`
    control_codes_cursor: s64;
    unique_control_codes: [..] Small_Bytes;

    diff_markers: [..] Range;
}

memory_usage :: (buffer: *Window_Buffer) -> (raw_text_usage: s64, rest_usage: s64) {
    raw_text_usage, rest_usage: s64;

    raw_text_usage += buffer.raw_text_and_control_codes.count;

    rest_usage += size_of(Window_Buffer);
    rest_usage += buffer.only_text_storage.allocated;
    rest_usage += buffer.control_codes.allocated * size_of(Control_Code_Info);
    rest_usage += buffer.line_offsets.allocated * size_of(s64);
    rest_usage += buffer.unique_control_codes.allocated * size_of(Small_Bytes);
    rest_usage += buffer.diff_markers.allocated * size_of(Range);

    return raw_text_usage, rest_usage;
}

Range :: struct { start, count: s32; }

Control_Code_Info :: struct {
    position_in_text: s64;
    using bytes: Small_Bytes;
}
#assert size_of(Control_Code_Info) == 32;

control_code_string :: inline (using code: *Control_Code_Info) -> string {
    return to_string(*code.bytes);
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

    state_instance: State;
    context.state = *state_instance;
    state := *state_instance;

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
            case "-v"; #through;
            case "--version"; #through;
            case "version";
                show_version_banner();
                exit(0);

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

            case "-I"; #through;
            case "--command-from-stdin";
                state.main_window_source = .EXTERNAL_COMMAND_WHICH_COMES_FROM_STDIN;

            case "-d"; #through;
            case "--draw";
                state.main_window_source = .DRAWING_MODE;

            case "-g"; #through;
            case "--game-of-life";
                state.main_window_source = .GAME_OF_LIFE;

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

            case "--max-time"; #through;
            case "--max-time-before-repeat";
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
                state.external_command_run_period_max = seconds;

            case "--no-backoff"; #through;
            case "--no-exponential-backoff";
                state.external_command_backoff_mode = .OFF;

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
                state.http_server_enabled_explicitly = true;

            case "--no-listen";
                state.http_server_disabled_explicitly = true;

            // TODO: a flag to just watch a file's contents, so I don't have to
            // do `cat filename`

            case "--debug";
                state.debug = true;

            case "--run-tests";
                state.run_tests = true;

            case; break;
        }
        cursor += 1;
    }

    if state.run_tests {
        run_tests();
        return;
    }

    command_size := args.count - cursor;
    array_reserve(*state.command, command_size);
    for 0..command_size-1 {
        array_add(*state.command, copy_string(args[cursor + it]));
    }

    // Preallocate memory
    array_reserve(*state.search.search_string_buffer, 4096);
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
    context.logger_data = context.state;

    builder: String_Builder;
    builder.allocator = temp;
    show_version_banner(*builder);
    log("%", builder_to_string(*builder,, temp));

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

    // Setup tmux
    state.tmux_env = to_string(getenv("TMUX"));
    state.tmux_pane_id = to_string(getenv("TMUX_PANE"));

    // Read history file
    read_history_file();

    gotta_reattach_stdin := false;

    // Choose input source
    if !isatty(STDIN_FILENO) && state.main_window_source != .EXTERNAL_COMMAND_WHICH_COMES_FROM_STDIN {
        state.main_window_source = .PIPED_INPUT;
        gotta_reattach_stdin = true;
        log("main window source is stdin");
    } else if state.main_window_source == .EXTERNAL_COMMAND_WHICH_COMES_FROM_STDIN {
        if isatty(STDIN_FILENO) {
            print("When running with '-I/--command-from-stdin' stdin must be piped in, sorry about that!");
            exit(1);
        }
        log("main window source is external command which comes from stdin");
        gotta_reattach_stdin = true;
    } else if state.main_window_source == .NONE {
        if state.command {
            state.main_window_source = .EXTERNAL_COMMAND;
            log("main window source is external command: %", state.command);
        } else {
            show_version_banner();
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
    if gotta_reattach_stdin {
        using context.state;

        print("Reading input from standard input...\n");
        log("Reading input from standard input...\n");

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

    if state.debug then getchar();

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
        rc := epoll_ctl(epoll_fd, .ADD, STDIN_FILENO, *event);
        assert(rc == 0);

        if main_window_source == .PIPED_INPUT || main_window_source == .EXTERNAL_COMMAND_WHICH_COMES_FROM_STDIN {
            event.events = EPOLLIN;
            event.data.fd = piped_input_fd;
            rc = epoll_ctl(epoll_fd, .ADD, piped_input_fd, *event);
            if rc != 0 {
                code, message := get_error_value_and_string();
                print("epoll_ctl failed: #% %\n", code, message);
                exit(1);
            }
        }
    }

    // Initialize http server (must go after epoll, because we use the epoll_fd)
    if !init_http_server() {
        log_last_error(.WITH_STACK_TRACE);
        if state.http_server_enabled_explicitly {
            builder: String_Builder;
            print_last_error(*builder, .WITH_STACK_TRACE);
            write_builder(*builder);
            exit(1);
        }
    }

    // Get terminal size
    rc := ioctl(STDIN_FILENO, TIOCGWINSZ, *state.terminal_size);
    assert(rc == 0);

    // Completion menu depends on termnal_size
    init_completion_menu();

    // `- 2` for :2_status_lines
    state.main_window_height = state.terminal_size.rows - 2;
    state.scrollbar_resolution = state.main_window_height * 2;

    // Setup terminal mode, after this exitting should be done via term_exit
    init_terminal_settings();

    // Make stdin non blocking
    {
        flags := fcntl(STDIN_FILENO, F_GETFL);
        flags |= O_NONBLOCK;
        rc := fcntl(STDIN_FILENO, F_SETFL, flags);
        assert(rc != -1);
    }

    if state.main_window_source == .GAME_OF_LIFE {
        init_game_of_life();
    }

    // Initialize @status_line
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
                external_command_output_closed ||= cast(bool, it.events & EPOLLHUP);
            } else if it.data.fd == external_command_process.error.handle {
                external_command_ready = true;
                external_command_error_closed ||= cast(bool, it.events & EPOLLHUP);
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
            log("render requested: window size changed");
            main_window_render_requested = true;
            redraw_once = true;

            // Get terminal size
            rc := ioctl(STDIN_FILENO, TIOCGWINSZ, *state.terminal_size);

            // `- 2` for 2 status lines
            state.main_window_height = state.terminal_size.rows - 2;
            state.scrollbar_resolution = state.main_window_height * 2;

            if main_window_source == .DRAWING_MODE resize_pixel_buffer();

            row_offset = max(row_offset, -(main_window_height - 1));

            scrollbar_search_matches_handle_window_resize();
        }

        // Handle input
        state.delayed_actions.count = 0;
        if input_received_this_tick {
            parse_and_handle_input();
            log("render requested: input received");
            main_window_render_requested = true;
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

        game_of_life_ticked := false;
        if main_window_source == .GAME_OF_LIFE {
            if !game_of_life_paused {
                while next_tick_time <= frame_time {
                    next_tick_time += tick_period;
                    tick_game_of_life();
                    game_of_life_ticked = true;
                }
            } else if game_of_life_tick_needed {
                game_of_life_tick_needed = false;
                tick_game_of_life();
                game_of_life_ticked = true;
            }
        }

        Profile();

        // @scrollbar
        update_scollbar_info(main_window_buffer);

        // @text_search
        maybe_update_search_matches(main_window_buffer);
        if search.flags & .UNFINISHED {
            log("render requested: text search unfinished");
            main_window_render_requested = true;
        }

        Profile();

        render_status_line_1();

        Profile();

        //
        // Main window
        //

        min_period := 1.0 / target_fps;
        its_time := frame_time - time_last_shown > min_period;

        if its_time {
            line_buffer: [] string; // temporary storage
            changed := false;
            if #complete main_window_source == {
                case .EXTERNAL_COMMAND_WHICH_COMES_FROM_STDIN; #through;
                    // TODO: read stderr and update it interactively
                case .EXTERNAL_COMMAND; #through;
                case .PIPED_INPUT;
                    if main_window_render_requested || last_shown_line_buffer.count == 0 {
                        log("last_shown_line_buffer.count: %", last_shown_line_buffer.count);
                        line_buffer = build_line_buffer_for_main_window(main_window_buffer);
                        main_window_render_requested = false;
                        changed = true;
                    } else {
                        line_buffer = last_renderred_line_buffer;
                    }

                case .DRAWING_MODE;
                    line_buffer = build_line_buffer_for_pixel_buffer();
                    changed = true;

                case .GAME_OF_LIFE;
                    line_buffer = build_line_buffer_for_game_of_life();
                    changed = true;

                case .NONE;
            }

            if changed {
                changed = !array_equals(line_buffer, last_shown_line_buffer);
            }

            if changed || redraw_once {
                time_last_shown = frame_time;
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
        }

        Profile();

        maybe_render_completion_menu();

        Profile();

        //
        // second @status_line
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
                raw_text_usage, rest_usage := memory_usage(it);
                buffer_history_raw_text_bytes += raw_text_usage;
                buffer_history_the_rest_bytes += rest_usage;
            }

            search_matches_bytes := search.matches.allocated * size_of(Search_Match);
            array_add(*rows, .["search matches: ", tprint("%", cast(Human_Readable_Memory) search_matches_bytes)]);
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
                append_padding(*builder, max_width - count_visible_characters(line));
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

    if state.command_version != 0 {
        print("last external command was:\n");
        builder: String_Builder;
        display_external_command(*builder, state.command);
        print(*builder, "\n");
        write_builder(*builder);
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

    main_window_renderred_times += 1;
    // log("main_window_renderred_times: %", main_window_renderred_times);
    // log("main_window_render_requested: %", main_window_render_requested);

    // `line_buffer` stores pointers into `window_buffer` or temporary storage
    line_buffer: [..] string;
    line_buffer.allocator = temp;
    array_reserve(*line_buffer, main_window_height);

    // starts from 1, `+2` for :2_status_lines
    current_screen_row = 1 + 2;

    // @scrollbar
    do_scrollbar := draw_scrollbar && (scrollbar_slider_height != scrollbar_resolution);

    line_index := 0;
    if row_offset > 0 {
        line_index = row_offset;
    } else if row_offset < 0 {
        builder: String_Builder;
        builder.allocator = temp;

        // Extra blank lines for negative row_offset (for some reason)
        for 1..-row_offset {
            if do_scrollbar // @scrollbar
                draw_scrollbar_piece_in_current_line(*builder);
            else
                append(*builder, "\n");
            array_add(*line_buffer, builder_to_string(*builder,, temp));
            current_screen_row += 1;
        }
    }

    //
    // find closest diff markers (feature @diff_headers)
    //
    last_commit, last_diff, last_hunk: Range;
    second_to_last_diff: Range;
    first_line_index := line_index;
    if first_line_index < line_offsets.count {
        first_seen_line_start := line_offsets[first_line_index];
        second_seen_line_start := ifx first_line_index + 1 < line_offsets.count then line_offsets[first_line_index + 1]
                                                                                else only_text.count;
        if (flags & .DIFF_MARKERS) {
            for diff_markers {
                if it.start > second_seen_line_start break;
                marker_text := slice(only_text, it.start, it.count);
                if starts_with(marker_text, "commit") {
                    last_commit = it;
                }
                else if starts_with(marker_text, "diff") {
                    second_to_last_diff = last_diff;
                    last_diff = it;
                }
                else if starts_with(marker_text, "@@")   then last_hunk = it;
            }

            if last_hunk.start < last_diff.start         then last_hunk = .{};
            if second_seen_line_start == only_text.count then last_hunk = .{};
            if last_diff.start > first_seen_line_start || first_line_index == line_offsets.count {
                last_diff = .{};
                if second_to_last_diff.start < first_seen_line_start {
                    last_diff = second_to_last_diff;
                }
            }
            if !last_diff.count then last_hunk = .{};
        }
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
    search_matches: [..] Pointer_Range; // in current line
    search_matches.allocator = temp;

    // Preprocess lines to be displayed
    while line_buffer.count < main_window_height || (line_wrapping && stick_to_the_bottom) {
        if line_index > line_offsets.count - 1 break;
        line_start := line_offsets[line_index];
        line_end := ifx line_index < line_offsets.count - 1 then line_offsets[line_index + 1] - 1 else only_text.count;
        current_line_number = line_index + 1;

        Setup_Line :: (range: *Range, line_index: int) -> (start: int, count: int, line_number: int) #expand {
            line_start := range.start;
            line_end   := range.start + range.count;

            cursor := line_index;
            while (cursor >= 0) && (`line_offsets[cursor] > line_start) cursor -= 1;
            line_number := cursor + 1;

            range.count = 0;
            return line_start, line_end, line_number;
        }

        // @diff_headers
        // FIXME: this doesn't work because the previous hunk overwrites the
        // next diff. Gotta figure out the `second_to_last_diff` thing, i.e.
        // make it work in the generic case??...
        // if last_commit.count {
        //     line_start, line_end, current_line_number = Setup_Line(*last_commit, row_offset);
        // } else
        if last_diff.count {
            line_start, line_end, current_line_number = Setup_Line(*last_diff, row_offset);
        } else if last_hunk.count {
            line_start, line_end, current_line_number = Setup_Line(*last_hunk, row_offset);
        }

        defer line_index += 1;
        line := substring(xx only_text, line_start, line_end);

        current_row_left_offset = main_window_left_offset;

        // :search_string_highlight
        search_matches.count = 0;
        // TODO: is the line is super fucking long this will be slow, so I
        // could test for that and do something else in that case
        if search.search_string {
            // find all matches in current line
            tail := line;
            while tail {
                found:, head:, tail = split_from_left(tail, search.search_string);
                if !found break;

                start := head.data + head.count;
                end := start + search.search_string.count;
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

            if do_scrollbar {
                // subtract @scrollbar width
                visible_columns_budget -= 1;
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
                if search.search_string {
                    index := find_index_from_left(line, search.search_string);
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
                // Extra spaces if offset is negative (why are we still here? just to suffer?!?!?!??)
                padding := min(-col_offset, visible_columns_budget);
                // FIXME just use a "\e[%;%Hm" control sequence for big perf gain!!!
                append_padding(*builder, padding);
                visible_columns_budget -= padding;
            }

            if visible_columns_budget == 0 {
                visible_slice.count = 0;
            }

            line_overflowed := utf8_count(visible_slice, false) > visible_columns_budget;
            if line_overflowed && (visible_columns_budget > 0) {
                // Leave space for the :line_overflow_character
                visible_slice = utf8_substring(visible_slice, 0, visible_columns_budget - 1);
            }

            codes.count = 0;
            if !strip_control_codes && (visible_slice.count != 0) {
                array_add(*codes, ..find_all_control_codes_in_range(window_buffer, visible_slice));
            }

            // :search_string_highlight
            search_matched_in_hidden := false;
            if search.search_string {
                tail := line;
                while tail && !should_exit {
                    // FIXME: I'm a dumbass, optimizing for searching over
                    // large text segments, while vim just finds all matches
                    // in the file instantly and shows me their count. Just
                    // fucking find all matches when the text or search
                    // string changes, you retard.
                    index := find_index_from_left(tail, search.search_string);
                    if index < 0 break;

                    if visible_slice.count == 0 {
                        search_matched_in_hidden = true;
                        break;
                    }

                    match_start := tail.data + index;
                    match_end := match_start + search.search_string.count;

                    tail = substring(tail, index + search.search_string.count);

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

            if visible_slice {
                // Build the line string
                build_line_with_control_codes(*builder, window_buffer, visible_slice, codes);
            }

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

            if do_scrollbar // @scrollbar
                draw_scrollbar_piece_in_current_line(*builder);

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

                if do_scrollbar {
                    // subtract @scrollbar width
                    visible_columns_budget -= 1;
                }

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

                // FIXME scrollbar slider is wrong in line_wrapping mode because
                // I don't actually calculate the number of virtual lines so the
                // proportions are wrong :c
                if do_scrollbar // @scrollbar
                    draw_scrollbar_piece_in_current_line(*builder);

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

    if do_scrollbar { // @scrollbar
        builder: String_Builder;
        builder.allocator = temp;

        while line_buffer.count < main_window_height {
            // This should only happen when there's not enough lines to fill the screen
            draw_scrollbar_piece_in_current_line(*builder);
            array_add(*line_buffer, builder_to_string(*builder,, temp));
            current_screen_row += 1;
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
    for *pixel_buffer it.* = current_pixel_bg;

    width = xx pixel_window_size.x;
    for 1..22 pixel_buffer[5 * width + (it - 1) * 2] = current_pixel_fg;
    for 1..5 pixel_buffer[6 * width + (it - 1) * 10] = current_pixel_fg;
    for 1..3 pixel_buffer[(it - 1) * 2 * width + 43] = current_pixel_fg;
    pixel_buffer[44] = current_pixel_fg;

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
            print_pixel_value(*builder, pixel);
            append(*builder, "  ");
        }
        append(*builder, "\e[0m");
        append(*builder, "\n");

        array_add(*line_buffer, builder_to_string(*builder,, temp));
    }

    return line_buffer;
}

//
// game of life
//

Cell_Field :: [..] u8;

init_game_of_life :: () {
    using context.state;

    // TODO: need to move the pixel rows based on old cell_field_size
    cell_field_area := cell_field_width * cell_field_height;

    init_cell_field := make_new_cell_field();

    // set_cell(init_cell_field, 0, 0);
    // set_cell(init_cell_field, 0, 1);
    // set_cell(init_cell_field, 1, 0);
    // set_cell(init_cell_field, 1, 1);

/*
    _ # _
    _ _ #
    # # #
*/

    x, y := 2, 2;
    set_cell(init_cell_field, x + 0, y + 2);
    set_cell(init_cell_field, x + 1, y + 0);
    set_cell(init_cell_field, x + 1, y + 2);
    set_cell(init_cell_field, x + 2, y + 1);
    set_cell(init_cell_field, x + 2, y + 2);

/*
    _ _ #
    # _ #
    _ # #
*/
    x, y = 10, 10;
    set_cell(init_cell_field, x + 2, y + 0);
    set_cell(init_cell_field, x + 0, y + 1);
    set_cell(init_cell_field, x + 2, y + 1);
    set_cell(init_cell_field, x + 1, y + 2);
    set_cell(init_cell_field, x + 2, y + 2);
}

make_new_cell_field :: () -> Cell_Field {
    using context.state;

    new_cell_field := array_add(*cell_field_history);
    current_cell_field_index_in_history = cell_field_history.count - 1;

    cell_field_area := cell_field_width * cell_field_height;
    array_resize(new_cell_field, cell_field_area);
    new_cell_field.count = cell_field_area;

    return new_cell_field.*;
}

current_cell_field :: () -> Cell_Field {
    using context.state;

    return cell_field_history[current_cell_field_index_in_history];
}

set_cell :: inline (field: Cell_Field, x: int, y: int, on := true) {
    using context.state;

    field[cell_field_width * y + x] = xx on;
}

get_cell_checked :: inline (field: Cell_Field, x: int, y: int) -> bool {
    using context.state;

    if x < 0 || x >= cell_field_width  return false;
    if y < 0 || y >= cell_field_height return false;
    return field[cell_field_width * y + x] != 0;
}

get_cell :: inline (field: Cell_Field, x: int, y: int) -> bool {
    using context.state;

    return field[cell_field_width * y + x] != 0;
}

// GAME_OF_LIFE

tick_game_of_life :: () {
    using context.state;

    old_cell_field := last(cell_field_history);
    new_cell_field := make_new_cell_field();

    width := cell_field_width;
    height := cell_field_height;

    Tick_Cell :: (x: int, y: int, num_live_neighbors: int) #expand {
        if num_live_neighbors == 3 {
            set_cell(`new_cell_field, x, y, true);
        } else if num_live_neighbors == 2 {
            set_cell(`new_cell_field, x, y, get_cell(`old_cell_field, x, y));
        } else {
            set_cell(`new_cell_field, x, y, false);
        }
    }

    // top left
    {
        x, y := 0, 0;
        num_live_neighbors := 0;
        num_live_neighbors += xx get_cell(old_cell_field, x,     y + 1);
        num_live_neighbors += xx get_cell(old_cell_field, x + 1, y);
        num_live_neighbors += xx get_cell(old_cell_field, x + 1, y + 1);
        Tick_Cell(x, y, num_live_neighbors);
    }

    // top right
    {
        x, y := width - 1, 0;
        num_live_neighbors := 0;
        num_live_neighbors += xx get_cell(old_cell_field, x,     y + 1);
        num_live_neighbors += xx get_cell(old_cell_field, x - 1, y);
        num_live_neighbors += xx get_cell(old_cell_field, x - 1, y + 1);
        Tick_Cell(x, y, num_live_neighbors);
    }

    // bottom left
    {
        x, y := 0, height - 1;
        num_live_neighbors := 0;
        num_live_neighbors += xx get_cell(old_cell_field, x,     y - 1);
        num_live_neighbors += xx get_cell(old_cell_field, x + 1, y);
        num_live_neighbors += xx get_cell(old_cell_field, x + 1, y - 1);
        Tick_Cell(x, y, num_live_neighbors);
    }

    // bottom right
    {
        x, y := width - 1, height - 1;
        num_live_neighbors := 0;
        num_live_neighbors += xx get_cell(old_cell_field, x,     y - 1);
        num_live_neighbors += xx get_cell(old_cell_field, x - 1, y);
        num_live_neighbors += xx get_cell(old_cell_field, x - 1, y - 1);
        Tick_Cell(x, y, num_live_neighbors);
    }

    // topmost row
    {
        y := 0;
        for x: 1..width-2 {
            num_live_neighbors := 0;
            num_live_neighbors += xx get_cell(old_cell_field, x - 1, y);
            num_live_neighbors += xx get_cell(old_cell_field, x - 1, y + 1);
            num_live_neighbors += xx get_cell(old_cell_field, x,     y + 1);
            num_live_neighbors += xx get_cell(old_cell_field, x + 1, y + 1);
            num_live_neighbors += xx get_cell(old_cell_field, x + 1, y);
            Tick_Cell(x, y, num_live_neighbors);
        }
    }

    // bottommost row
    {
        y := height - 1;
        for x: 1..width-2 {
            num_live_neighbors := 0;
            num_live_neighbors += xx get_cell(old_cell_field, x - 1, y);
            num_live_neighbors += xx get_cell(old_cell_field, x - 1, y - 1);
            num_live_neighbors += xx get_cell(old_cell_field, x,     y - 1);
            num_live_neighbors += xx get_cell(old_cell_field, x + 1, y - 1);
            num_live_neighbors += xx get_cell(old_cell_field, x + 1, y);
            Tick_Cell(x, y, num_live_neighbors);
        }
    }

    // leftmost column
    {
        x := 0;
        for y: 1..height-2 {
            num_live_neighbors := 0;
            num_live_neighbors += xx get_cell(old_cell_field, x,     y - 1);
            num_live_neighbors += xx get_cell(old_cell_field, x + 1, y - 1);
            num_live_neighbors += xx get_cell(old_cell_field, x + 1, y);
            num_live_neighbors += xx get_cell(old_cell_field, x + 1, y + 1);
            num_live_neighbors += xx get_cell(old_cell_field, x,     y + 1);
            Tick_Cell(x, y, num_live_neighbors);
        }
    }

    // rightmost column
    {
        x := width - 1;
        for y: 1..height-2 {
            num_live_neighbors := 0;
            num_live_neighbors += xx get_cell(old_cell_field, x,     y - 1);
            num_live_neighbors += xx get_cell(old_cell_field, x - 1, y - 1);
            num_live_neighbors += xx get_cell(old_cell_field, x - 1, y);
            num_live_neighbors += xx get_cell(old_cell_field, x - 1, y + 1);
            num_live_neighbors += xx get_cell(old_cell_field, x,     y + 1);
            Tick_Cell(x, y, num_live_neighbors);
        }
    }

    for x: 1..cell_field_width-2 {
        for y: 1..cell_field_width-2 {
            num_live_neighbors := 0;
            num_live_neighbors += xx get_cell(old_cell_field, x - 1, y - 1);
            num_live_neighbors += xx get_cell(old_cell_field, x,     y - 1);
            num_live_neighbors += xx get_cell(old_cell_field, x + 1, y - 1);
            num_live_neighbors += xx get_cell(old_cell_field, x + 1, y);
            num_live_neighbors += xx get_cell(old_cell_field, x + 1, y + 1);
            num_live_neighbors += xx get_cell(old_cell_field, x,     y + 1);
            num_live_neighbors += xx get_cell(old_cell_field, x - 1, y + 1);
            num_live_neighbors += xx get_cell(old_cell_field, x - 1, y);
            Tick_Cell(x, y, num_live_neighbors);
        }
    }
}

// GAME_OF_LIFE

build_line_buffer_for_game_of_life :: () -> [] string {
    using context.state;

    line_buffer: [..] string;
    line_buffer.allocator = temp;
    array_reserve(*line_buffer, main_window_height);

    cell_field := current_cell_field();

    zoom_area_height := cast(u16, main_window_height);
    zoom_area_pixels := zoom_area_height;
    zoom_area_width := zoom_area_height * 2; // because 2 chars per pixel
    unzoomed_width := terminal_size.cols - zoom_area_width;

    for row: 0..main_window_height - 1 {
        owned_builder: String_Builder;
        builder := *owned_builder;
        builder.allocator = temp;

        for col : 0..unzoomed_width - 1 {
            x := col * 2 - cell_field_offset_x;
            y := row * 4 - cell_field_offset_y;

            braille: Braille_Pixels;
            if get_cell_checked(cell_field, x,     y)     braille |= ._0_0;
            if get_cell_checked(cell_field, x + 1, y)     braille |= ._1_0;
            if get_cell_checked(cell_field, x    , y + 1) braille |= ._0_1;
            if get_cell_checked(cell_field, x + 1, y + 1) braille |= ._1_1;
            if get_cell_checked(cell_field, x    , y + 2) braille |= ._0_2;
            if get_cell_checked(cell_field, x + 1, y + 2) braille |= ._1_2;
            if get_cell_checked(cell_field, x    , y + 3) braille |= ._0_3;
            if get_cell_checked(cell_field, x + 1, y + 3) braille |= ._1_3;

            if braille {
                print_braille(builder, braille);
            } else {
                append(builder, " ");
            }
        }

        for col_ofs: 0..zoom_area_pixels - 1 {
            x := col_ofs - cell_field_zoom_area_offset_x;
            y := row - cell_field_zoom_area_offset_y;

            if get_cell_checked(cell_field, x, y) {
                append(builder, "\e[47m  ");
            } else {
                append(builder, "\e[48;5;232m  ");
            }
        }

        append(builder, "\e[0m");
        append(builder, "\n");

        array_add(*line_buffer, builder_to_string(builder,, temp));
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

//
// tmux
//

http_server_print_tmux_info :: (builder: *String_Builder) {
    using context.state;

    // FIXME: add support for asynchronous tasks, so that we don't send the
    // http response until the external command output is ready
    if !tmux_info_ready {
        if !tmux_env {
            print(builder, "not running in tmux?!?");
            return;
        }

        if !tmux_info_process_started {
            ok := create_tmux_list_panes_process();
            if !ok {
                print(builder, "failed to start tmux process %!\n", tmux_info_command);
                print_last_error(builder, .ONLY_MESSAGE);
                print(builder, "\n");
                return;
            }
            tmux_info_process_started = true;
        }

        if !tmux_info_process_finished {
            ok, result := get_process_result(*tmux_info_process, timeout_ms=0);
            if result.type != .STILL_RUNNING {
                if result.exit_code != 0 {
                    print(builder, "% exited with %", tmux_info_command, result.exit_code);
                }

                tmux_info_process_finished = true;
            }
        }

        result := maybe_read_all_available_data_from_tmux_output();
        if result == .ERROR {
            print(builder, "failed to get tmux info: ");
            print_last_error(builder, .ONLY_MESSAGE);
            print(builder, "\n");

            tmux_info_process_started = false;
            tmux_info_process_finished = false;
            return;
        }

        if result != .CLOSED {
            print(builder, "tmux pane % info not ready yet\n", tmux_pane_id);
            return;
        }

        log("tmux list panes output: '''%'''", to_string(*tmux_info_builder));
        tmux_pane_coordinates = trim(to_string(*tmux_info_builder));
        tmux_info_ready = true;
    }

    print(builder, "tmux pane: %\n", tmux_pane_coordinates);
}

parse_tmux_list_panes_output :: (data: string) {
    using context.state;
}

create_tmux_list_panes_process :: () -> bool {
    using,except.["command"] context.state;

    process := *tmux_info_process;

    if !tmux_info_command {
        array_add(*tmux_info_command, "tmux", "list-panes", "-aF", "#S:#{window_index}.#P", "-f");
        array_add(*tmux_info_command, sprint("#{==:#{pane_id},%}", tmux_pane_id));
    }

    Profile();

    log("running %", tmux_info_command);
    ok := create_process(process, ..tmux_info_command, capture_and_return_output = true);
    if !ok {
        set_last_error_from_system();
        log_error("starting command % failed: #% %", tmux_info_command, context.last_error.code, context.last_error.message);
        return false;
    }

    close(process.input.handle);
    process.input.handle = -1;

    return true;
}

maybe_read_all_available_data_from_tmux_output :: () -> Read_Result {
    using context.state;

    handle := *tmux_info_process.output.handle;
    if handle.* == -1 return .CLOSED;

    builder := *tmux_info_builder;
    result, has_new_data := read_all_available_data(handle.*, builder);
    if result == .ERROR {
        set_last_error_from_system();
        log_error("Failed reading tmux subprocess output stream: [%] %\n", context.last_error.code, context.last_error.message);

        shutdown_fd(handle, epoll=false);
        return .ERROR;
    }

    if result == .CLOSED {
        shutdown_fd(handle, epoll=false);
        return .CLOSED;
    }

    return .OK;
}

tmux_copy_to_clipboard :: (text: string) {
    using,except.["command"] context.state;

    if !tmux_env return;

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

on_new_input_source :: inline () {
    using context.state;

    next_window_buffer_source_version += 1;
    smart_backoff_change_counter = 0;
    smart_backoff_run_counter = 0;
    smart_backoff_no_change_counter = 0;
}

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
        result := read_all_available_data(handle.*, builder);
        if result == .ERROR {
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
        result := read_all_available_data(handle.*, builder);
        if result == .ERROR {
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

        if (external_command_backoff_mode != .OFF) &&
           external_command_backoff_multiplier == 1.0 &&
           last_command_duration > external_command_run_period_seconds
        {
            // @external_command_exponential_backoff
            // External command ran longer than the rerun period. So we update the
            // multiplier based on that ratio.... Now that I think about it I'm not sure what's the best option here (not sure what options are there)
            external_command_backoff_multiplier = last_command_duration / external_command_run_period_seconds;
            clamp_external_command_run_period_multiplier();

            if external_command_backoff_mode == .SMART | .CHECKING {
                // Long running external command -> need backoff
                external_command_backoff_mode = .SMART | .ON;
            }
        }

        time_next_command_run = now + external_command_run_period_seconds * external_command_backoff_multiplier;
        external_command_finished_count += 1;
        smart_backoff_run_counter += 1;
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

    new_main_window_buffer := true;

    if main_window_buffer_history && hash == main_window_buffer_history[main_window_buffer_history.count - 1].hash {
        free(raw_text_and_control_codes);
        do_external_command_backoff(got_change=false);
        return;
    }

    do_external_command_backoff(got_change=true);
    smart_backoff_change_counter += 1;

    if current_shown_buffer_index == main_window_buffer_history.count - 1 {
        // log("render requested: external command output");
        main_window_render_requested = true;
    } else {
        // log("render request skipped: not showing latest buffer");
    }

    Profile();
    init_window_buffer(*new_window_buffer, raw_text_and_control_codes);
    new_window_buffer.source_version = next_window_buffer_source_version;
    Profile();
    parse_raw_text_and_control_codes(*new_window_buffer);
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

display_external_command :: (builder: *String_Builder, command: [] string) {
    append(builder, "\e[32m");
    if path_filename(command[0]) == "git" {
        append(builder, "git");
    } else if contains(command[0], #char "\n") || contains(command[0], #char "\r") {
        head := command[0];
        // @Robustness: I hard coded these escape sequences based on the one above.
        // This will break the second I touch this code again!!!
        head = replace(head, "\n", "\e[0;35m\\n\e[32m",, temp);
        head = replace(head, "\t", "\e[0;35m\\t\e[32m",, temp);
        append(builder, head);
    } else {
        append(builder, command[0]);
    }
    append(builder, "\e[0m");

    for 1..command.count-1 {
        append(builder, " ");
        if find_index_from_left(command[it], #char " ") != -1 {
            append(builder, "\e[33m"); // color yellow
            append(builder, "\"");
            print_ascii_or_hex(builder, command[it]);
            append(builder, "\"");
            append(builder, "\e[0m");
        } else {
            append(builder, command[it]);
        }
    }
}

//
// @external_command_exponential_backoff
//

update_exponential_backoff_multiplier :: (new_multiplier: float64) {
    using context.state;

    external_command_backoff_multiplier = new_multiplier;
    clamp_external_command_run_period_multiplier();
    // Recalculate in case the multiplier changed, which it may not have, in which case this shouldn't change anything
    time_next_command_run = last_command_finish + external_command_run_period_seconds * external_command_backoff_multiplier;
}

clamp_external_command_run_period_multiplier :: inline () { // @external_command_exponential_backoff
    using context.state;

    if external_command_run_period_seconds * external_command_backoff_multiplier < external_command_run_period_max
        return;

    external_command_backoff_multiplier = external_command_run_period_max / external_command_run_period_seconds;
}

do_external_command_backoff :: inline (got_change: bool) {
    using context.state;

    if got_change {
        external_command_backoff_on_change();
    } else {
        external_command_backoff_on_no_change();
    }

    external_command_backoff_smart_mode_check();
}

external_command_backoff_smart_mode_check :: () {
    using context.state;

    // Check if we're in smart mode and we're still checking
    if external_command_backoff_mode != .SMART | .CHECKING return;
    // Check if current external command has finished the appropriate amount of times for the check
    if smart_backoff_run_counter < SMART_BACKOFF_THRESHOLD return;

    if !main_window_buffer_history return;

    if smart_backoff_change_counter > 1 {
        // Command ran the appropriate amount of times and the output changed at least once.
        // Disable backoff because we want to see that shit (very dumb heuristic by the way)
        external_command_backoff_mode = .SMART | .OFF;
    } else {
        // No change in output for first 10 runs -> backoff needed
        external_command_backoff_mode = .SMART | .ON;
    }
}

external_command_backoff_on_no_change :: () {
    using context.state;

    smart_backoff_no_change_counter += 1;

    backoff_mode := external_command_backoff_mode;
    if !(backoff_mode & .ON) return;

    if (backoff_mode & .SMART) && (smart_backoff_no_change_counter < SMART_BACKOFF_THRESHOLD) return;

    // External command output didn't change, increase the multiplier
    update_exponential_backoff_multiplier(external_command_backoff_multiplier * 2);
}

external_command_backoff_on_change :: () {
    using context.state;

    smart_backoff_no_change_counter = 0;

    backoff_mode := external_command_backoff_mode;
    if !(backoff_mode & .ON) return;

    if external_command_backoff_multiplier > 1.0 {
        // External command output changed, reset the multiplier
        update_exponential_backoff_multiplier(max(last_command_duration / external_command_run_period_seconds, 1.0));
    }
}

//
// text source: PIPED_INPUT
//

read_some_from_piped_input :: () {
    using context.state;
    first_time := (main_window_buffer_history.count == 0);
    if !main_window_buffer_history {
        array_add(*main_window_buffer_history, .{});
        main_window_buffer_history[0].source_version = next_window_buffer_source_version;
        on_new_input_source();
        started_reading_piped_input = seconds_since_init();
    }

    if piped_input_fd == -1 return;

    has_new_data := read_all_available_data_from_piped_input();
    if !has_new_data return;

    // log("render requested: piped input");
    main_window_render_requested = true;

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
    parse_raw_text_and_control_codes(window_buffer);
    Profile("raw_text_and_control_codes.count: %", window_buffer.raw_text_and_control_codes.count);

    // log("got new piped input!:\n'''%\n'''", window_buffer.raw_text_and_control_codes);
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
    log("piped input pipe is no longer!");
    using context.state;

    shutdown_fd(*piped_input_fd);

    if main_window_source == .EXTERNAL_COMMAND_WHICH_COMES_FROM_STDIN {
        // @YUCK! embarassing shit right here!!!
        main_window_buffer := *main_window_buffer_history[current_shown_buffer_index];

        for command free(it); // There's no command though!?!?!??
        command.count = 0;

        array_add(*command, copy_string(main_window_buffer.raw_text_and_control_codes));

        time_next_command_run = frame_time;
        // XXX: not sure about this though..
        main_window_source = .EXTERNAL_COMMAND;
        main_window_render_requested = true;
        log("main window source is now external command: %", command);
        return;
    }

    if !parent_process_command_line return;
    if path_filename(parent_process_command_line[0]) == "git" {
        for command free(it);
        command.count = 0;
        array_reserve(*command, parent_process_command_line.count);
        for parent_process_command_line {
            array_add(*command, copy_string(it));
        }

        last_command_finish = frame_time;
        last_command_duration = frame_time - started_reading_piped_input;
        if (external_command_backoff_mode != .OFF) && last_command_duration > external_command_run_period_seconds {
            // Increase backoff multiplier to the ratio
            update_exponential_backoff_multiplier(last_command_duration / external_command_run_period_seconds);
        } else {
            time_next_command_run = frame_time;
        }

        main_window_source = .EXTERNAL_COMMAND;
        main_window_render_requested = true;
        log("main window source is now external command: %", command);
    }

    return;
}

read_all_available_data_from_piped_input :: () -> has_new_data: bool {
    using context.state;

    if piped_input_fd == -1 return false;

    result, has_new_data := read_all_available_data(piped_input_fd, *piped_input_builder);
    if result == .ERROR {
        code, message := get_error_value_and_string();
        append(*piped_input_builder, "\e[31m"); // color red
        print(*piped_input_builder, "Failed reading from stdin pipe: (%) %\n", code, message);
        append(*piped_input_builder, "\e[0m");

        shutdown_fd(*piped_input_fd);
    }

    return has_new_data;
}

shutdown_fd :: (fd: *s32, epoll := true) {
    using context.state;

    if epoll {
        rc := epoll_ctl(epoll_fd, .DEL, fd.*, null);
        if rc != 0 {
            code, message := get_error_value_and_string();
            log_error("epoll_ctl failed: [%] %", code, message);
        }
    }

    rc := close(fd.*);
    if rc != 0 {
        code, message := get_error_value_and_string();
        log_error("close failed: [%] %", code, message);
    }

    fd.* = -1;
}

//
// @status_line-s
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

    // meat
    render_status_line_1_left_side(*builder);
    render_status_line_1_right_side(*builder);

    append(*builder, "\n");

    // second line is drawn at the end
    append(*builder, "\n");

    write_builder(*builder);
}

render_status_line_1_left_side :: (builder: *String_Builder) {
    using context.state;

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
            append(builder, "\e[35m"); // color magenta
            append(builder, "$(");
            append(builder, "\e[0m");

            {
                temp_builder := String_Builder.{ allocator = temp };
                display_external_command(*temp_builder, command);
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
                    scroll_string_with_control_codes(builder, command_string, clamped_offset, max_command_string_length);
                } else {
                    append(builder, command_string);
                }
            }

            append(builder, "\e[35m"); // color magenta
            append(builder, ")");
            append(builder, "\e[0m");

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
                append(builder, " \e[35m"); // color magenta
                print(builder, "%s", fmt(duration, digits_after_comma=3, keep_zero=true)); // color magenta
                append(builder, "\e[0m");
            }

            if last_command_result.type == .STILL_RUNNING || (frame_time - second_to_last_command_finish < anti_flicker_period) {
                append(builder, "\e[35m"); // color magenta

                widget :: string.["⢎⡀", "⢆⡠", "⢄⡰", "⢀⡱", "⠈⡱", "⠊⠱", "⠎⠑", "⢎⠁"];
                append(builder, " ");
                t := cast(int) (frame_time * 10);
                append(builder, widget[t % widget.count]);

                append(builder, "\e[0m");
            } else if last_command_result.exit_code != 0 {
                append(builder, "\e[35m"); // color magenta
                append(builder, " -> ");
                append(builder, "\e[31m"); // color red
                print(builder, "%", last_command_result.exit_code);
                append(builder, "\e[0m");
            } else {
                append(builder, "   ");
            }

            // command rerun period
            {
                append(builder, "\e[2;37m"); // color gray (dark + white)
                append(builder, " T: ");
                // XXX: am I stupid, or is stb_print_float doing something
                // weird when removing zero and when trailing_width is not zero?
                effective_period := external_command_run_period_seconds * external_command_backoff_multiplier;
                text := tprint("%", fmt(effective_period, digits_after_comma=1));
                text = trim(text);
                append(builder, text);
                append(builder, "s");
                if external_command_backoff_mode & .CHECKING {
                    append(builder, "?");
                } else if (external_command_backoff_mode != .OFF) && external_command_backoff_multiplier != 1 { // @external_command_exponential_backoff
                    print(builder, "↑");
                }
                append(builder, "\e[0m");
            }

            // @text_search matches
            {
                if search.matches.count
                    print(builder, " m: %", search.matches.count);
            }
        }
        case .EXTERNAL_COMMAND_WHICH_COMES_FROM_STDIN; #through;
        case .PIPED_INPUT; {
            append(builder, "\e[35m"); // color magenta
            append(builder, "<stdin>");

            widget :: string.["⢎⡀", "⢆⡠", "⢄⡰", "⢀⡱", "⠈⡱", "⠊⠱", "⠎⠑", "⢎⠁"];
            append(builder, " ");
            t := cast(int) (frame_time * 10);
            append(builder, widget[t % widget.count]);

            append(builder, "\e[0m");

            // @text_search matches
            {
                if search.matches.count
                    print(builder, " m: %", search.matches.count);
            }
        }
        case .DRAWING_MODE; {
            append(builder, "\e[36m"); // color cyan
            append(builder, "drawing mode");
            append(builder, "\e[0m");

            append(builder, " ");
            print_pixel_value(builder, current_pixel_fg);
            append(builder, "  \e[0m");
            print_pixel_value(builder, current_pixel_bg);
            append(builder, "  \e[0m");

            print(builder, " %", last_shown_line_buffer_version);

            append(builder, " ");
            pixels_to_braille(builder, 0, 0, 21);
            append(builder, " ");

            t := cast(int) (frame_time * 10);
            // ⢎⠱ ⢎⡑ ⢎⡡ ⢎⡰ ⢆⡱ ⢌⡱ ⢊⡱ ⠎⡱
            {
                widget :: string.["⢎⠱", "⢎⡑", "⢎⡡", "⢎⡰", "⢆⡱", "⢌⡱", "⢊⡱", "⠎⡱"];
                append(builder, " ");
                append(builder, widget[t % widget.count]);
            }

            // ⢎⡁ ⢎⡠ ⢆⡰ ⢄⡱ ⢈⡱ ⠊⡱ ⠎⠱ ⢎⠑
            {
                widget :: string.["⢎⡁", "⢎⡠", "⢆⡰", "⢄⡱", "⢈⡱", "⠊⡱", "⠎⠱", "⢎⠑"];
                append(builder, " ");
                append(builder, widget[t % widget.count]);
            }

            // ⢎⡀ ⢆⡠ ⢄⡰ ⢀⡱ ⠈⡱ ⠊⠱ ⠎⠑ ⢎⠁
            {
                widget :: string.["⢎⡀", "⢆⡠", "⢄⡰", "⢀⡱", "⠈⡱", "⠊⠱", "⠎⠑", "⢎⠁"];
                append(builder, " ");
                append(builder, widget[t % widget.count]);
            }

            // ⢆⡀ ⢄⡠ ⢀⡰  ⡱ ⠈⠱ ⠊⠑ ⠎⠁ ⢎
            {
                widget :: string.["⢆⡀", "⢄⡠", "⢀⡰", "⠀⡱", "⠈⠱", "⠊⠑", "⠎⠁", "⢎⠀"];
                append(builder, " ");
                append(builder, widget[t % widget.count]);
            }

            // ⢄⡀ ⢀⡠  ⡰  ⠱ ⠈⠑ ⠊⠁ ⠎  ⢆
            {
                widget :: string.["⢄⡀", "⢀⡠",  "⠀⡰", "⠀⠱", "⠈⠑", "⠊⠁", "⠎⠀", "⢆⠀"];
                append(builder, " ");
                append(builder, widget[t % widget.count]);
            }

            // ⢾⠳ ⢾⡓ ⢾⡥ ⢾⡴ ⢦⡷ ⢬⡷ ⢚⡷ ⠞⡷
            {
                widget :: string.["⢾⠳", "⢾⡓", "⢾⡥", "⢾⡴", "⢦⡷", "⢬⡷", "⢚⡷", "⠞⡷"];
                append(builder, " ");
                append(builder, widget[t % widget.count]);
            }

            // ⢎⠑⢄⡱ ⠎⠑⢌⡱ ⠊⠑⢎⡱ ⠈⠱⢎⡱ ⡱⢎⡱ ⢀⡰⢎⡱ ⢄⡠⢎⡱ ⢆⡠⢊⡱ ⢎⡠⠊⡱ ⢎⡡⠊⠱ ⢎⡱⠊⠑ ⢎⡱⠎⠁ ⢎⡱⢎ ⢎⡱⢆⡀ ⢎⡱⢄⡠ ⢎⡑⢄⡰
            {
                widget :: string.[
                    "⢎⠑⢄⡱", "⠎⠑⢌⡱", "⠊⠑⢎⡱", "⠈⠱⢎⡱", "⠀⡱⢎⡱", "⢀⡰⢎⡱", "⢄⡠⢎⡱", "⢆⡠⢊⡱",

                    "⢎⡠⠊⡱", "⢎⡡⠊⠱", "⢎⡱⠊⠑", "⢎⡱⠎⠁", "⢎⡱⢎⠀", "⢎⡱⢆⡀", "⢎⡱⢄⡠", "⢎⡑⢄⡰",
                ];
                append(builder, " ");
                append(builder, widget[t % widget.count]);
            }

            // ⠊⠑⢄⡀  ⠉⠢⣀⠄ ⠈⠢⣀⠆  ⠢⣈⠆    ⢌⡱   ⠐⣉⠆  ⠔⢉⠆ ⢀⠔⠉⠆  ⢀⡠⠊⠑ ⠠⣀⠔⠉ ⠰⣀⠔⠁ ⠰⣁⠔  ⢎⡡   ⠰⣉⠂  ⠰⡉⠢  ⠰⠉⠢⡀
            {
                widget :: string.[
                    "⠊⠑⢄⡀", "⠈⠑⢄⡠", "⠀⠑⢄⡰", "⠀⠐⢄⡱", "⠀⠀⢌⡱", "⠀⠀⢊⡱", "⠀⠠⠊⡱", "⠀⡠⠊⠱",
                    "⢀⡠⠊⠑", "⢄⡠⠊⠁", "⢆⡠⠊⠀", "⢎⡠⠂⠀", "⢎⡡⠀⠀", "⢎⡑⠀⠀", "⢎⠑⠄⠀", "⠎⠑⢄⠀",
                ];
                append(builder, " ");
                append(builder, widget[t % widget.count]);
            }

            {
                widget :: string.[
                    "⠊⠑⠀⠀", "⠈⠑⠄⠀", "⠀⠑⢄⠀", "⠀⠐⢄⡀", "⠀⠀⢄⡠", "⠀⠀⢀⡰", "⠀⠀⠀⡱", "⠀⠀⠈⠱",
                    "⠀⠀⠊⠑", "⠀⠠⠊⠁", "⠀⡠⠊⠀", "⢀⡠⠂⠀", "⢄⡠⠀⠀", "⢆⡀⠀⠀", "⢎⠀⠀⠀", "⠎⠁⠀⠀",
                ];
                append(builder, " ");
                append(builder, widget[t % widget.count]);
            }

            {
                widget :: string.[
                    "⠊⣵", "⢨⡵", "⣤⡱", "⢶⡰", "⢟⡠", "⢞⡃", "⢎⠛", "⠎⠷",
                ];
                append(builder, " ");
                append(builder, widget[t % widget.count]);
            }
        }
        case .GAME_OF_LIFE; {
            append(builder, "\e[2;37m"); // color gray (dark white)
            print(builder, "ofs: [% %]", cell_field_offset_x, cell_field_offset_y);
            append(builder, "  ");
            print(builder, "zoomed ofs: [% %]", cell_field_zoom_area_offset_x, cell_field_zoom_area_offset_y);

            append(builder, "    ");
            append(builder, "\e[0m");
            append(builder, "\e[37m"); // color white
            if game_of_life_paused {
                append(builder, "pause");
            } else {
                append(builder, "play");
            }
        }
    }
}

render_status_line_1_right_side :: (outer_builder: *String_Builder) {
    using context.state;

    left_side := to_string(outer_builder);

    right_side_parts: [..] string;
    right_side_parts.allocator = temp;

    // parts:
    buffer_number_in_history: string;
    date_text: string;
    time_text: string;

    {
        // buffer number in history
        if main_window_source == .GAME_OF_LIFE
        {
            builder: String_Builder;
            builder.allocator = temp;

            append(*builder, "\e[2;37m"); // color gray (dark white)
            curr := current_cell_field_index_in_history + 1;
            max := cell_field_history.count;

            if curr == max {
                print(*builder, "#%", max);
            } else {
                print(*builder, "#%/%", curr, max);
            }
            append(*builder, "\e[0m");
            buffer_number_in_history = builder_to_string(*builder,, temp);
        }
        else
        {
            builder: String_Builder;
            builder.allocator = temp;

            append(*builder, "\e[2;37m"); // color gray (dark white)
            if current_shown_buffer_index == main_window_buffer_history.count - 1 {
                print(*builder, "#%", current_shown_buffer_index + 1);
            } else {
                print(*builder, "#%/%", current_shown_buffer_index + 1, main_window_buffer_history.count);
            }
            append(*builder, "\e[0m");
            buffer_number_in_history = builder_to_string(*builder,, temp);
        }

        time := current_time_consensus();
        if main_window_source == .EXTERNAL_COMMAND && main_window_buffer_history {
            time = main_window_buffer_history[current_shown_buffer_index].time_generated;
        }
        date_time := to_calendar(time, .LOCAL);

        // date
        {
            builder: String_Builder;
            builder.allocator = temp;

            append(*builder, "\e[32m"); // color green
            print_date_for_humans(*builder, date_time);
            append(*builder, "\e[0m");
            date_text = builder_to_string(*builder,, temp);
        }

        // time
        {
            builder: String_Builder;
            builder.allocator = temp;

            append(*builder, "\e[32m"); // color green
            print_time_for_humans(*builder, date_time);
            append(*builder, "\e[0m");
            time_text = builder_to_string(*builder,, temp);
        }
    }

    // TODO @Robustness not handling left side being over terminal width...
    right_side_budget := terminal_size.cols - count_visible_characters(left_side);

    maybe_do_parts :: (builder: *String_Builder, max_length: s64, parts_to_show: [] string) -> bool {
        assert(parts_to_show.count > 0);

        length := 0;
        for part: parts_to_show {
            length += count_visible_characters(part);
        }
        length += parts_to_show.count - 1; // padding

        padding := max_length - length;
        if padding < 0 {
            return false;
        }

        // padding between left side & right side
        append_padding(builder, padding);
        append(builder, parts_to_show[0]);

        i := 1;
        while i < parts_to_show.count {
            append(builder, " ");
            append(builder, parts_to_show[i]);
            i += 1;
        }

        return true;
    }

    done := false;
    if !done then done = maybe_do_parts(outer_builder, right_side_budget, .[buffer_number_in_history, date_text, time_text]);
    if !done then done = maybe_do_parts(outer_builder, right_side_budget, .[buffer_number_in_history, time_text]);
    if !done then done = maybe_do_parts(outer_builder, right_side_budget, .[buffer_number_in_history]);
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
            pixel := pixel_buffer[y * (cast(int) pixel_window_size.x) + x];
            return get_red(pixel) > 0x99;
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

Braille_Pixels :: enum_flags {
    // Corrdinates go from top left to bottom right
    ____ :: 0;
    _0_0 :: 1 << 0;
    _0_1 :: 1 << 1;
    _0_2 :: 1 << 2;
    _1_0 :: 1 << 3;
    _1_1 :: 1 << 4;
    _1_2 :: 1 << 5;
    _0_3 :: 1 << 6;
    _1_3 :: 1 << 7;
}

make_braille :: (pixels: Braille_Pixels) -> u32 {
    res: u32 = 0x2800;
    res += xx pixels;
    return res;
}

print_braille :: inline (builder: *String_Builder, pixels: Braille_Pixels) {
    print_utf8(builder, make_braille(pixels));
}

Braille_Pair :: struct {
    left: Braille_Pixels;
    right: Braille_Pixels;
}

make_binary_representation :: (i: u16) -> Braille_Pair {
    mapping :: Braille_Pair.[
        /* bit  0 */ .{ ._0_0, .____, },
        /* bit  1 */ .{ ._1_0, .____, },
        /* bit  2 */ .{ .____, ._0_0, },
        /* bit  3 */ .{ .____, ._1_0, },
        /* bit  4 */ .{ ._0_1, .____, },
        /* bit  5 */ .{ ._1_1, .____, },
        /* bit  6 */ .{ .____, ._0_1, },
        /* bit  7 */ .{ .____, ._1_1, },
        /* bit  8 */ .{ ._0_2, .____, },
        /* bit  9 */ .{ ._1_2, .____, },
        /* bit 10 */ .{ .____, ._0_2, },
        /* bit 11 */ .{ .____, ._1_2, },
        /* bit 12 */ .{ ._0_3, .____, },
        /* bit 13 */ .{ ._1_3, .____, },
        /* bit 14 */ .{ .____, ._0_3, },
        /* bit 15 */ .{ .____, ._1_3, },
    ];

    res: Braille_Pair;

    x := i;
    for 0..15 {
        bit := x & 1;
        x >>= 1;
        if !bit continue;

        pair := mapping[it];
        res.left |= pair.left;
        res.right |= pair.right;
    }

    return res;
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
        if input_mode == {
            case .NAVIGATE;
                append(*builder, "drawing mode");

                print(*builder, " mouse %, %", mouse_position.column, mouse_position.row);
            case .INPUT_SEARCH_STRING; #through;
            case .INPUT_COMMAND;
                render_status_line_2_command_line(*builder, input_mode);
        }
    } else {
        if input_mode ==  {
            case .NAVIGATE;
                line_count := 0;
                if main_window_buffer_history {
                    main_window_buffer := *main_window_buffer_history[current_shown_buffer_index];
                    line_count = main_window_buffer.line_offsets.count;
                }

                // render counter
                {
                    // values :: string.[
                    //     "  ", " ⢀", " ⣀", "⢀⣀", "⣀⣀", "⣀⣠", "⣀⣤", "⣠⣤",
                    //     "⣤⣤", "⣤⣴", "⣤⣶", "⣴⣶", "⣶⣶", "⣶⣾", "⣶⣿", "⣾⣿",
                    //     "⣿⣿", "⣿⡿", "⣿⠿", "⡿⠿", "⠿⠿", "⠿⠟", "⠿⠛", "⠟⠛",
                    //     "⠛⠛", "⠛⠋", "⠛⠉", "⠋⠉", "⠉⠉", "⠉⠁", "⠉ ", "⠁ ",
                    // ];
                    // i := main_window_renderred_times % values.count;
                    // append(*builder, values[i]);
                    i := main_window_renderred_times % 0x10000; // 2 ^ 16
                    braille_pair := make_binary_representation(xx i);
                    print_braille(*builder, braille_pair.left);
                    print_braille(*builder, braille_pair.right);
                    append(*builder, "  ");
                }

                text_start := buffer.count;
                {
                    print(*builder, "[%", row_offset);
                    if line_wrapping then print(*builder, "(+%)", wrapped_line_offset);
                    print(*builder, "/%", line_count);
                    if !line_wrapping && col_offset then print(*builder, " %", col_offset);
                    append(*builder, "]  ");
                    if stick_to_the_bottom then append(*builder, "sinking   ");

                    // Print current input buffer
                    append(*builder, "input: ");

                    print_to_builder(*builder, "%", cast(Ascii_Or_Hex) input_buffer);
                }

                {
                    // status line debug stuff section
                    // if main_window_buffer_history {
                    //     main_window_buffer := *main_window_buffer_history[current_shown_buffer_index];
                    //     print(*builder, "  % % %", scrollbar_slider_top, scrollbar_slider_bottom, scrollbar_slider_height);
                    // }
                }

                text_length := buffer.count - text_start;
                overflow := text_length - terminal_size.cols;
                if overflow > 0 {
                    buffer.count -= overflow;
                }
            case .INPUT_SEARCH_STRING; #through;
            case .INPUT_COMMAND;
                render_status_line_2_command_line(*builder, input_mode);
        }
    }

    append(*builder, "\e[0m");

    assert(get_current_buffer(*builder) == buffer);
    write_builder(*builder);
}

render_status_line_2_command_line :: (builder: *String_Builder, input_mode: type_of(State.input_mode)) {
    using,except.["input_mode"] context.state;

    prefix := "??";
    text := "<unknown mode>";
    if input_mode == .INPUT_SEARCH_STRING { prefix = "/";  text = search.search_string; }
    if input_mode == .INPUT_COMMAND       { prefix = "> "; text = xx command_line; }
    append(builder, prefix);

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
        append(builder, substring(text, slice_start, count=visible_columns_budget - 1));
        // `+ 1` because rows start at 1
        cursor_line = 2;
        cursor_column = input_cursor - slice_start + prefix.count + 1;
    } else {
        append(builder, text);
        // `+ 1` because rows start at 1
        cursor_line = 2;
        cursor_column = input_cursor + prefix.count + 1;
    }
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
    parse_raw_text_and_control_codes(*window_buffer);

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

    window_buffer.diff_markers.count = 0;
}

parse_raw_text_and_control_codes :: (using window_buffer: *Window_Buffer) {
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
            inline array_add(*only_text_storage, #char "\n");

            // At this point it would probably be cleaner to use find_index_from_left instead of split_from_left...
            pointer_to_start_of_next_line := line.data + line.count + 1;
            last_line_offset_in_raw_text = pointer_to_start_of_next_line - raw_text_and_control_codes.data;

            line_start := last(line_offsets);
            array_add(*line_offsets, only_text_storage.count);

            line_length := only_text_storage.count - line_start - 1;
            only_text_line := array_view(only_text_storage, line_start, line_length);
            if starts_with(xx only_text_line, "commit ") { // @diff_headers
                array_add(*diff_markers, .{xx line_start, xx line_length});
            }
            diff_marker := starts_with(xx only_text_line, "diff --git");
            if diff_marker { flags |= .DIFF_MARKERS; }
            if diff_marker {
                array_add(*diff_markers, .{xx line_start, xx line_length});
            }
            if (flags & .DIFF_MARKERS && starts_with(xx only_text_line, "@@ ")) {
                array_add(*diff_markers, .{xx line_start, xx line_length});
            }
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

    count, new := find_or_add(*context.state.all_unique_control_codes, code.bytes);
    count.* += 1;
    if new {
        log("new control code '%'", code.bytes);
        append_line_to_history_file(.SEEN_CONTROL_CODE, control_code);
    }

    for *unique_control_codes if to_string(it) == control_code return;
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
        HOME;
        END;
        PAGE_UP;
        PAGE_DOWN;
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
        } else if try_parse_page_up_or_down(sequence, *event) {
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
        case #char "H"; kind = .HOME;
        case #char "F"; kind = .END;
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
        case #char "7"; event.modifiers = .CONTROL | .ALT;
        case #char "8"; event.modifiers = .CONTROL | .ALT | .SHIFT;
        case;           return false;
    }

    event.kind = kind;
    return true;
}

try_parse_page_up_or_down :: (sequence: string, event: *Input_Event) -> bool {
    kind: Input_Event.Kind;
    if sequence[sequence.count - 1] != #char "~" return false;

    if sequence[0] == {
        case #char "1"; kind = .HOME;
        case #char "4"; kind = .END;
        case #char "5"; kind = .PAGE_UP;
        case #char "6"; kind = .PAGE_DOWN;
        case; return false;
    }
    if sequence.count == 2 {
        event.kind = kind;
        return true;
    }

    if sequence.count != 4         return false;
    if sequence[1]    != #char ";" return false;
    if sequence[2] == {
        case #char "2"; event.modifiers = .SHIFT;
        case #char "3"; event.modifiers = .ALT;
        case #char "4"; event.modifiers = .ALT | .SHIFT;
        case #char "5"; event.modifiers = .CONTROL;
        case #char "6"; event.modifiers = .CONTROL | .SHIFT;
        case #char "7"; event.modifiers = .CONTROL | .ALT;
        case #char "8"; event.modifiers = .CONTROL | .ALT | .SHIFT;
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

        if event.kind == {
            case .MOUSE_LEFT_DRAG; #through;
            case .MOUSE_LEFT_DOWN;
                if pixel_index >= 0 && pixel_index < pixel_buffer.count {
                    pixel_buffer[pixel_index] = current_pixel_fg;
                }
            case .MOUSE_RIGHT_DRAG; #through;
            case .MOUSE_RIGHT_DOWN;
                if pixel_index >= 0 && pixel_index < pixel_buffer.count {
                    pixel_buffer[pixel_index] = current_pixel_bg;
                }
            case .MOUSE_MIDDLE_DOWN;
                builder: String_Builder;
                pixels_to_braille(*builder, 0, 0, count=21); //
                text := builder_to_string(*builder,, temp);
                tmux_copy_to_clipboard(trim_crap(text));
        }

        if input_mode == {
            case .INPUT_COMMAND;
                handle_input_event_in_input_command_mode(event);

            case .NAVIGATE;
                if (event.kind == .CHARACTER) && (event.char == #char "q") {
                    should_exit = true;
                }

                if event.kind == .CHARACTER {
                    if event.char == {
                        case #char ";"; switch_to_command_line_mode();
                    }
                }
        }

        return;
    }

    if main_window_source == .GAME_OF_LIFE { // @input
        width := cell_field_width;
        height := cell_field_height;
        // WRONG: mouse_x := (mouse_position.column - 1) / 2;
        mouse_y := (mouse_position.row - 1) - 2; // `- 2` for :2_status_lines

        // TODO: this is wrong :(
        // if event.kind == {
        //     case .MOUSE_LEFT_DRAG; #through;
        //     case .MOUSE_LEFT_DOWN;
        //         field := current_cell_field();
        //         if mouse_x >= 0 && mouse_x < cell_field_width {
        //             set_cell
        //         }
        //         if pixel_index >= 0 && pixel_index < pixel_buffer.count {
        //             pixel_buffer[pixel_index] = current_pixel_fg;
        //         }
        // }

        if input_mode == {
            case .INPUT_COMMAND;
                handle_input_event_in_input_command_mode(event);

            case .NAVIGATE;
                if (event.kind == .CHARACTER) && (event.char == #char "q") {
                    should_exit = true;
                }

                if event.kind == .CHARACTER {
                    if event.char == {
                        case #char ";"; switch_to_command_line_mode();

                        case #char "f";
                            if current_cell_field_index_in_history < cell_field_history.count - 1 {
                                current_cell_field_index_in_history += 1;
                            } else {
                                game_of_life_tick_needed = true;
                            }
                        case #char "b";
                            if current_cell_field_index_in_history > 0 {
                                game_of_life_paused = true;
                                current_cell_field_index_in_history -= 1;
                            }

                        case #char "p";
                            game_of_life_paused = !game_of_life_paused;
                            if !game_of_life_paused {
                                next_tick_time = xx (frame_time + tick_period);
                            }
                    }
                }

                if event.kind == {
                    case .KEY_LEFT;  if event.modifiers & .CONTROL then cell_field_zoom_area_offset_x -= 1;
                                                                   else cell_field_offset_x -= 1;

                    case .KEY_RIGHT; if event.modifiers & .CONTROL then cell_field_zoom_area_offset_x += 1;
                                                                   else cell_field_offset_x += 1;

                    case .KEY_UP;    if event.modifiers & .CONTROL then cell_field_zoom_area_offset_y -= 1;
                                                                   else cell_field_offset_y -= 1;

                    case .KEY_DOWN;  if event.modifiers & .CONTROL then cell_field_zoom_area_offset_y += 1;
                                                                   else cell_field_offset_y += 1;
                }
        }

        return;
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

                case .PAGE_UP;   if event.modifiers & .ALT then navigate_window_to_top();
                                                           else navigate_window_up(.HALF_SCREEN);
                case .PAGE_DOWN; if event.modifiers & .ALT then navigate_window_to_bottom();
                                                           else navigate_window_down(.HALF_SCREEN);

                case .HOME; if event.modifiers & .SHIFT then navigate_window_to_top();
                                                        else col_offset = 0;

                case .END;  if event.modifiers & .SHIFT then navigate_window_to_bottom();

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

                    case #char "g"; navigate_window_to_top();
                    case #char "G"; navigate_window_to_bottom();

                    case #char "0"; col_offset = 0;

                    case #char "h"; if !line_wrapping col_offset -= 4;
                    case #char "l"; if !line_wrapping col_offset += 4;

                    case #char "H"; if !line_wrapping col_offset -= terminal_size.cols / 2;
                    case #char "L"; if !line_wrapping col_offset += terminal_size.cols / 2;

                    case #char "/"; {
                        input_mode = .INPUT_SEARCH_STRING;
                        replace_console_command_line(xx search.search_string_buffer);
                        history_cursor = -1;
                        // turn off error message instantly
                        info_message_deadline = frame_time - 1;
                    }

                    case #char ";";
                        switch_to_command_line_mode();

                    case #char "n"; jump_to_next_search_match();
                    case #char "N"; jump_to_previous_search_match();

                    case #char "c"; strip_control_codes = !strip_control_codes;

                    // FIXME: it's actually better if I can just write this:
                    // case #char "r"; if event.modifiers & .CONTROL
                    case #char "\x12"; // CTRL+R
                        command_rerun_external_command_now();
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

navigate_window_to_top :: () {
    using context.state;

    row_offset = 0;
    wrapped_line_offset = 0;
    stick_to_the_bottom = false;
}

navigate_window_to_bottom :: () {
    using context.state;

    if !main_window_buffer_history return;
    main_window_buffer := *main_window_buffer_history[current_shown_buffer_index];

    row_offset = main_window_buffer.line_offsets.count - main_window_height;
    stick_to_the_bottom = true;
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

        case #char "\r"; #through; /* CTRL+M or ENTER when terminal setup is broken */
                                   // FIXME: should probably figure out the
                                   // terminal setting so that this shit doesn't
                                   // get broken unexpectedly
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
        old_search_string := copy_string(search.search_string,, temp);
        search.search_string_buffer.count = 0;
        array_add(*search.search_string_buffer, ..command_line);
        search.search_string = xx search.search_string_buffer;
        if old_search_string != search.search_string {
            search.flags |= .NEW_SEARCH_STRING;
        }
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
        case .INPUT_SEARCH_STRING;  return *search.search_string_history, .SEARCH;
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

    // @HACK: doing this -------------------------------------V because of the @diff_headers stuff I recently added
    start_offset := ifx row_offset >= 0 then min(row_offset + 3, line_offsets.count - 1) else 0;
    search_start := line_offsets[start_offset];

    index := find_index_from_left(only_text, search.search_string, search_start);
    if index == -1 return; // match not found

    if row_offset < 0 then row_offset = 0;
    while row_offset < line_offsets.count {
        if line_offsets[row_offset] > index { // overshot by 1 line
            // @HACK: doing this ---------V because of the @diff_headers stuff I recently added
            row_offset = max(row_offset - 3, 0);
            return;
        }

        row_offset += 1;
    }
}

jump_to_previous_search_match :: () {
    using context.state;
    using main_window_buffer_history[current_shown_buffer_index];

    if row_offset == 0 return; // no previous match possible

    // @HACK: doing this ----------V  because of the @diff_headers stuff I recently added
    end_offset := max(row_offset - 2, 0);
    search_end := line_offsets[end_offset];

    search_region := substring(only_text, 0, search_end);
    index := find_index_from_right(search_region, search.search_string);

    if index == -1 return; // match not found

    stick_to_the_bottom = false;

    while row_offset >= 0 {
        if line_offsets[row_offset] < index {
            // @HACK: doing this because of the @diff_headers stuff I recently added
            row_offset = max(row_offset - 2, 0);
            return;
        }

        row_offset -= 1;
    }
}

//
// text search @text_search (text search)
//

Search_Matches :: struct {
    flags: enum_flags {
        NEW_SEARCH_STRING;
        UNFINISHED;
    }

    matches: [..] Search_Match;
    window_buffer_line_cursor: s32;

    search_string_buffer: [..] u8;
    search_string: string; // this is always just the search_string_buffer converted to string
    search_string_history: [..] string;

    window_buffer_hash: U128;
}

Search_Match :: struct {
    line_index: s32;
    offset_in_line: s16;
    some_garbage_at_the_end: u16;
}

maybe_update_search_matches :: (window_buffer: *Window_Buffer) {
    using context.state;

    if !search.search_string {
        search.matches.count = 0;
        scrollbar_search_matches.count = 0;
        return;
    }

    if !window_buffer return;

    do_update := false;

    if search.flags & .NEW_SEARCH_STRING {
        search.matches.count = 0;
        search.flags = 0;
        search.window_buffer_line_cursor = 0;
        clear_all_bits(*scrollbar_search_matches); // @scrollbar
        do_update = true;
    }

    if search.window_buffer_hash != window_buffer.hash {
        // Window buffer changed => reset the matches
        // FIXME this is breaking the case of .PIPED_INPUT source when input is huge,
        // but that case is currently cursed anyway, so...
        search.matches.count = 0;
        search.flags = 0;
        search.window_buffer_hash = window_buffer.hash;
        search.window_buffer_line_cursor = 0;
        clear_all_bits(*scrollbar_search_matches); // @scrollbar
        do_update = true;
    }

    line_index: s32 = 0;
    if search.flags & .UNFINISHED {
        // We already tried finding all matches, but didn't have time => continue where we ended last time
        line_index = search.window_buffer_line_cursor;
        do_update = true;
    }

    // Update not needed
    if !do_update return;

    // @scrollbar
    if scrollbar_search_matches.count == 0 then init_bit_array(*scrollbar_search_matches, scrollbar_resolution);

    start := current_time_monotonic();
    while line_index < window_buffer.line_offsets.count {
        if line_index % 1024 == 0 {
            elapsed := current_time_monotonic() - start;
            if to_milliseconds(elapsed) > 5 {
                // Don't want to block the application loop for too long
                search.flags |= .UNFINISHED;
                search.window_buffer_line_cursor = xx line_index;
                break;
            }
        }
        defer line_index += 1;

        // TODO: factor this out into a procedure
        line_start := window_buffer.line_offsets[line_index];
        line_end: s64;
        if line_index < window_buffer.line_offsets.count - 1 {
            line_end = window_buffer.line_offsets[line_index + 1] - 1;
        } else {
            line_end = window_buffer.only_text.count;
        }
        line := substring(xx window_buffer.only_text, line_start, line_end);

        // TODO: case-insensitive matching
        offset_in_line := find_index_from_left(line, search.search_string);
        if offset_in_line == -1 continue;
        offset_in_line = min(offset_in_line, S16_MAX);
        array_add(*search.matches, .{ line_index, xx offset_in_line, 0 });

        scrollbar_y := line_index_to_scrollbar_element(line_index);
        set_bit(*scrollbar_search_matches, scrollbar_y); // @scrollbar
    }

    if line_index >= window_buffer.line_offsets.count {
        search.flags &= ~.UNFINISHED;
        search.window_buffer_line_cursor = 0;
    }
}

update_just_the_scrollbar_search_matches :: () {
    using context.state;

}

//
// console_commands @console
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

    // @BROKEN this is broken for some reason!!!
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
// command procs @console
//

console_commands: [..] Command;
init_commands :: () {
    if !console_commands {
        array_add(*console_commands, make_command("period", change_external_command_rerun_period));
        array_add(*console_commands, make_command("interval", change_external_command_rerun_period));
        array_add(*console_commands, make_command("max_period", change_external_command_max_rerun_period));
        array_add(*console_commands, make_command("backoff_on", set_external_command_backoff_on));
        array_add(*console_commands, make_command("backoff_off", set_external_command_backoff_off));
        array_add(*console_commands, make_command("backoff_smart", set_external_command_backoff_smart));
        array_add(*console_commands, make_command("rerun_now", rerun_external_command_now));
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
        array_add(*console_commands, make_command("scrollbar", make_toggle("draw_scrollbar")));
        array_add(*console_commands, make_command("fg_rgb", set_current_pixel_fg_rgb));
        array_add(*console_commands, make_command("fg_256", set_current_pixel_fg_256));
        array_add(*console_commands, make_command("bg_rgb", set_current_pixel_bg_rgb));
        array_add(*console_commands, make_command("bg_256", set_current_pixel_bg_256));
    }
}

change_external_command_rerun_period :: (new_period: float32) -> (ok: bool, error_msg: string) {
    using context.state;

    if new_period <= 0.0001 return false, "value must not be less than 0.0001";

    old_period := external_command_run_period_seconds;
    external_command_run_period_seconds = new_period;
    external_command_backoff_multiplier = 1.0;

    old_tick_period := new_period;
    tick_period = new_period;
    next_tick_time += new_period - old_tick_period;

    time_next_command_run += new_period - old_period;

    if external_command_backoff_mode & .SMART {
        smart_backoff_change_counter = 0;
        smart_backoff_run_counter = 0;
        smart_backoff_no_change_counter = 0;
    }

    return true, "";
}

change_external_command_max_rerun_period :: (new_max_period: float32) -> (ok: bool, error_msg: string) {
    using context.state;

    if new_max_period <= 0.0001 return false, "value must not be less than 0.0001";
    if new_max_period < external_command_run_period_seconds
        return false, tprint("max value cannot be less than base value (currently %)", external_command_run_period_seconds);

    external_command_run_period_max = new_max_period;
    // Update based on the new max value
    update_exponential_backoff_multiplier(external_command_backoff_multiplier);

    return true, "";
}

set_external_command_backoff_on :: () -> (ok: bool, error_msg: string) { // @external_command_exponential_backoff
    using context.state;

    // Forced ON mode
    external_command_backoff_mode = .ON;

    return true, "";
}

set_external_command_backoff_off :: () -> (ok: bool, error_msg: string) { // @external_command_exponential_backoff
    using context.state;

    // Forced OFF mode
    external_command_backoff_mode = .OFF;

    update_exponential_backoff_multiplier(1.0);

    return true, "";
}

set_external_command_backoff_smart :: () -> (ok: bool, error_msg: string) { // @external_command_exponential_backoff
    using context.state;

    // Start SMART backoff mode
    external_command_backoff_mode = .SMART | .CHECKING;
    smart_backoff_change_counter = 0;
    smart_backoff_run_counter = 0;
    smart_backoff_no_change_counter = 0;

    return true, "";
}

rerun_external_command_now :: () -> (ok: bool, error_message: string) {
    command_rerun_external_command_now();

    return true, "";
}

command_rerun_external_command_now :: () {
    using context.state;

    time_next_command_run = frame_time;
    if external_command_backoff_mode & .SMART {
        smart_backoff_change_counter = 0;
        smart_backoff_run_counter = 0;
        smart_backoff_no_change_counter = 0;
    }
}

set_external_command :: (new_command: string) -> (ok: bool, error_message: string) {
    using context.state;

    if command.count == 1 && command[0] == new_command return true, "";

    for command free(it);
    command.count = 0;
    // FIXME: probably want to split the command and do some special character escaping
    array_add(*command, copy_string(new_command));
    time_next_command_run = frame_time;
    external_command_backoff_multiplier = 1.0;
    if external_command_backoff_mode & .SMART {
        external_command_backoff_mode = .SMART | .CHECKING;
    }
    main_window_source = .EXTERNAL_COMMAND;

    command_version += 1;
    on_new_input_source();
    log("external command changed to '%'", new_command);

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

set_current_pixel_fg_rgb :: (r: u8, g: u8, b: u8) -> (ok := true, error_message := "") {
    using context.state;

    current_pixel_fg.type = .RGB;
    current_pixel_fg.r = r;
    current_pixel_fg.g = g;
    current_pixel_fg.b = b;

    return;
}

set_current_pixel_fg_256 :: (number: u8) -> (ok := true, error_message := "") {
    using context.state;

    current_pixel_fg.type = .COLOR_8BIT;
    current_pixel_fg._8bit = xx number;

    return;
}

set_current_pixel_bg_rgb :: (r: u8, g: u8, b: u8) -> (ok := true, error_message := "") {
    using context.state;

    current_pixel_bg.type = .RGB;
    current_pixel_bg.r = r;
    current_pixel_bg.g = g;
    current_pixel_bg.b = b;

    return;
}

set_current_pixel_bg_256 :: (number: u8) -> (ok := true, error_message := "") {
    using context.state;

    current_pixel_bg.type = .COLOR_8BIT;
    current_pixel_bg._8bit = xx number;

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
    state := context.state;
    if state.http_server_disabled_explicitly return true;

    server := *context.state.http_server;
    server.epoll_fd = *state.epoll_fd;
    server.http_request_handler = http_request_handler;

    if !state.http_server_enabled_explicitly {
        server.listen_port = 42069;
    }

    if !init_tcp_server(server) return false;
    if !tcp_server_start_listenning(server) return false;
    log("http server is listenning on 0.0.0.0:%", server.listen_port);

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
    using context.state;

    if !starts_with(request.uri, "/api") {
        return http_serve_resource(request, data);
    }

    builder := get_response_body_builder(request);

    if starts_with(request.uri, "/api/text") {
        main_window_buffer := *main_window_buffer_history[current_shown_buffer_index];
        append(builder, main_window_buffer.raw_text_and_control_codes);
        return true;
    }

    print(builder, "Hello!\n");

    print(builder, "Date/time: ");
    date_time := to_calendar(current_time_consensus(), .LOCAL);
    print_date_time_for_log(builder, date_time);
    print(builder, "\n");

    http_server_print_tmux_info(builder);

    print(builder, "mode: %\n", main_window_source);
    if main_window_source == .EXTERNAL_COMMAND {
        print(builder, "external command: %\n", command);
    }
    if parent_process_command_line {
        print(builder, "parent process: %\n", parent_process_command_line);
    }

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
    line_no := 1;
    while tail {
        defer line_no += 1;
        found:, line:, tail = split_from_left(tail, #char "\n");
        if !line continue;

        first := line[0];

        if first == {
            case #char ":"; array_add(*command_line_history,  advance(line));
            case #char "/"; array_add(*search.search_string_history, advance(line));
            case #char "\\";
                control_code, ok := parse_ascii_or_hex(line);
                assert(ok, "%: '%' is not a valid escape sequence", line_no, line);
                bytes := make_small_bytes(control_code);
                table_add(*all_unique_control_codes, bytes, 0);

            case; log_error("garbage in history file: '%'", line);
        }
    }
}

History_File_Entry_Type :: enum {
    INVALID;
    SEARCH;
    SEEN_CONTROL_CODE;
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
        case .SEARCH;            append(*builder, "/");         append(*builder, text);
        case .COMMAND;           append(*builder, ":");         append(*builder, text);
        case .INVALID;           append(*builder, "<INVALID>"); append(*builder, text);
        case .SEEN_CONTROL_CODE;
            print_ascii_or_hex(*builder, text);
            assert(to_string(*builder)[0] == #char "\\");
    }
    append(*builder, "\n");

    data := builder_to_string(*builder,, temp);
    file_write(*file, data.data, data.count);
}

//
// @scrollbar stuff
//

update_scollbar_info :: (window_buffer: *Window_Buffer) {
    using context.state;

    if !window_buffer return;

    /* big brain time:
    B - number of line in the text buffer          let's say 100
    W - number of rows in the window               let's say 20
    s - number of rows in the scrollbar slider     should be 4?

          W / B = s / W   (or am I retarded?)
            => s = (W * W) / B
    */
    scrollbar_zoom_ratio = scrollbar_resolution / cast(float) window_buffer.line_offsets.count;
    slider_effective_size := scrollbar_resolution * scrollbar_zoom_ratio;
    slider_size := min(scrollbar_resolution, xx ceil(slider_effective_size));

    scrollbar_slider_height = slider_size;

    /*

    B - number of line in the text buffer          let's say 100
    W - number of rows in the window               let's say 20
    O - row offset of window                       let's say 30
    o - scrollbar slide offset in window           should be 6?

          O / B = o / W  =>  o = (W * O) / B

    +------+ ---      ---
    |      |  |        |
    |      |  |- O     |
    |      |  |        |
    |      |  |        |
    |+----+| ---       |
    ||    ||  |- W     |
    |+----+| ---       |- B
    |      |           |
    |      |           |
    |      |           |
    |      |           |
    |      |           |
    +------+          ---

    */

    slider_top_y := row_offset * scrollbar_zoom_ratio;
    slider_top_row := cast(s64) floor(slider_top_y);
    slider_bottom_row := slider_top_row + slider_size;

    scrollbar_slider_top = slider_top_row;
    scrollbar_slider_bottom = slider_bottom_row;
}

// Uses the last window_buffer provided to `update_scollbar_info`!!!
line_index_to_scrollbar_element :: inline (line_index: s64) -> s64 {
    using context.state;

    // XXX Not sure if I need floor or ceil or what???
    return xx floor(line_index * scrollbar_zoom_ratio);
}

draw_scrollbar_piece_in_current_line :: (builder: *String_Builder) {
    using context.state;

    // "\e[H": move cursor to given position (row, col) (1-based)
    print(builder, "\e[%;%H", current_screen_row, terminal_size.cols);

    // current_screen_row starts at 3 (1-based and skips the :2_status_lines)
    y_screen := current_screen_row - 3;

    y_scrollbar_top := y_screen * 2;
    y_scrollbar_bottom := y_scrollbar_top + 1;

    top_is_slider := (y_scrollbar_top >= scrollbar_slider_top) && (y_scrollbar_top < scrollbar_slider_bottom);
    top_is_search_match := ifx (y_scrollbar_top >= 0) && (y_scrollbar_top < scrollbar_search_matches.count)
                           then scrollbar_search_matches[y_scrollbar_top];

    bottom_is_slider := (y_scrollbar_bottom >= scrollbar_slider_top) && (y_scrollbar_bottom < scrollbar_slider_bottom);
    bottom_is_search_match := ifx (y_scrollbar_bottom >= 0) && (y_scrollbar_bottom < scrollbar_search_matches.count)
                              then scrollbar_search_matches[y_scrollbar_bottom];

    i := cast(u8, top_is_slider) + cast(u8, top_is_search_match) * 2 +
         cast(u8, bottom_is_slider) * 4 + cast(u8, bottom_is_search_match) * 8;
    cases :: string.[
        "\e[0m ",            //
        "\e[90m▀",           // top slider
        "\e[37m▀",           // top match
        "\e[38;5;143m▀",     // top both
        "\e[90m▄",           //             bottom slider
        "\e[100m ",          // top slider  bottom slider
        "\e[37;100m▀",       // top match   bottom slider
        "\e[38;5;143;100m▀", // top both    bottom slider
        "\e[37m▄",           //             bottom match
        "\e[47;90m▀",        // top slider  bottom match
        "\e[47m ",           // top match   bottom match
        "\e[38;5;143;47m▀",  // top both    bottom match
        "\e[90;38;5;143m▄",  //             bottom both
        "\e[90;48;5;143m▀",  // top slider  bottom both
        "\e[37;48;5;143m▀",  // top match   bottom both
        "\e[48;5;143m ",     // top both    bottom both
    ];

    append(builder, cases[i]);
    append(builder, "\e[0m");
}

scrollbar_search_matches_handle_window_resize :: () {
    using context.state;

    deinit(*scrollbar_search_matches);
    scrollbar_search_matches.count = 0;

    if !search.matches return;

    assert(main_window_buffer_history.count != 0);
    main_window_buffer := *main_window_buffer_history[current_shown_buffer_index];
    update_scollbar_info(main_window_buffer);

    init_bit_array(*scrollbar_search_matches, scrollbar_resolution);

    for search.matches { // @text_search
        scrollbar_y := line_index_to_scrollbar_element(it.line_index);
        set_bit(*scrollbar_search_matches, scrollbar_y); // @scrollbar
    }
}

//
// @style and ansi escape sequences
//

Attribute_Info :: struct {
    type: Attribute_Type;
    union {
        small_style: Small_Style;
        color_24bit: Color_24bit;
        char: u8;
    }
}

Attribute_Type :: enum u8 {
    UNKNOWN;
    SMALL_STYLE;
    COLOR_24BIT;
    NON_PRINTABLE_CHAR;
    TAB;
}

Small_Style :: struct {
    fg_color: Color_8bit;
    bg_color: Color_8bit;
    attributes: Style_Attributes;
}
#assert size_of(Small_Style) == 3;

Color_24bit :: struct {
    r: u8;
    g: u8;
    b: u8;
    flags: enum u8 {
        BACKGROUND :: 0;
        FOREGROUND :: 1;
    }
}
#assert size_of(Color_24bit) == 4;

Style :: struct {
    union {
        fg_8bit: Color_8bit;
        fg_24bit: Color_24bit;
    }
    union {
        bg_8bit: Color_8bit;
        bg_24bit: Color_24bit;
    }
    flags: Flags;
    attributes: Style_Attributes;

    Flags :: enum_flags u8 {
        FG_24BIT    :: 1 << 0;
        FG_DEFAULT  :: 1 << 1;
        FG_NOT_8BIT :: FG_24BIT | FG_DEFAULT;
        BG_24BIT    :: 1 << 2;
        BG_DEFAULT  :: 1 << 3;
        BG_NOT_8BIT :: BG_24BIT | BG_DEFAULT;
    };
}
#assert size_of(Style) == 10;

is_default :: inline (using style: Style) -> bool {
    return (flags & .FG_DEFAULT) && (flags & .BG_DEFAULT) && (attributes == 0);
}

equals :: inline (a: Style, b: Style) -> bool {
    if a.attributes != b.attributes return false;

    if a.flags & .FG_DEFAULT {
        if !(b.flags & .FG_DEFAULT) return false;
    } else if a.flags & .FG_24BIT {
        if !(b.flags & .FG_24BIT) return false;
        assert(!(b.flags & .FG_DEFAULT));
        if a.fg_24bit.r != b.fg_24bit.r return false;
        if a.fg_24bit.g != b.fg_24bit.g return false;
        if a.fg_24bit.b != b.fg_24bit.b return false;
    } else /* a fg 8bit */ {
        if b.flags & .FG_NOT_8BIT return false;
        if a.fg_8bit != b.fg_8bit return false;
    }

    if a.flags & .BG_DEFAULT {
        if !(b.flags & .BG_DEFAULT) return false;
    } else if a.flags & .BG_24BIT {
        if !(b.flags & .BG_24BIT) return false;
        assert(!(b.flags & .BG_DEFAULT));
        if a.bg_24bit.r != b.bg_24bit.r return false;
        if a.bg_24bit.g != b.bg_24bit.g return false;
        if a.bg_24bit.b != b.bg_24bit.b return false;
    } else /* a bg 8bit */ {
        if b.flags & .BG_NOT_8BIT return false;
        if a.bg_8bit != b.bg_8bit return false;
    }

    return true;
}

normalize :: inline (flags: Style.Flags) -> Style.Flags {
    if !(flags & .FG_24BIT) && !(flags & .BG_24BIT) return flags;
    result := flags;
    if flags & .FG_DEFAULT then result &= ~.FG_24BIT;
    if flags & .BG_DEFAULT then result &= ~.BG_24BIT;
    return result;
}

Style_Attributes :: enum_flags u8 { BOLD; FAINT; ITALIC; UNDERLINE; BLINKING; INVERSE; HIDDEN; STRIKETHROUGH; };


Small_Escape_Sequence :: struct {
    command_letter: u8;
    argument_count: u8;
    arguments: [6] u8;
}
#assert size_of(Small_Escape_Sequence) == 8;

make_small_escape_sequence :: inline (command: u8, arguments: .. u8) -> Small_Escape_Sequence {
    assert(arguments.count <= 6, "%", arguments);
    result: Small_Escape_Sequence;
    result.command_letter = command;
    result.argument_count = xx arguments.count;
    memcpy(result.arguments.data, arguments.data, arguments.count);
    return result;
}

make_small_escape_sequence :: inline ($command: string, arguments: .. u8) -> Small_Escape_Sequence {
    #assert command.count == 1;
    return make_small_escape_sequence(command[0], ..arguments);
}

print :: (builder: *String_Builder, sequence: Small_Escape_Sequence) {
    append(builder, sequence.command_letter);
    append(builder, "(");
    count := cast(int) sequence.argument_count;
    for 0..count - 2
        print(builder, "%, ", cast(Ansi_Style_Command) sequence.arguments[it]);
    if sequence.argument_count
        print(builder, "%", cast(Ansi_Style_Command) sequence.arguments[sequence.argument_count - 1]);
    append(builder, ")");
}

evaluate_style_sequence :: (using sequence: Small_Escape_Sequence, style: Style) -> Style {
    if command_letter != #char "m" return style;
    res := style;

    cursor := 0;
    while cursor < argument_count {
        command := cast(Ansi_Style_Command) arguments[cursor];
        cursor += 1;
        if command == {
            case .RESET_ALL;
                res.flags = .FG_DEFAULT | .BG_DEFAULT;
                res.attributes = 0;
            case .BOLD_ON;          res.attributes |= .BOLD;
            case .FAINT_ON;         res.attributes |= .FAINT;
            case .ITALIC_ON;        res.attributes |= .ITALIC;
            case .UNDERLINE_ON;     res.attributes |= .UNDERLINE;
            case .BLINKING_ON;      res.attributes |= .BLINKING;
            case .INVERSE_ON;       res.attributes |= .INVERSE;
            case .HIDDEN_ON;        res.attributes |= .HIDDEN;
            case .STRIKETHROUGH_ON; res.attributes |= .STRIKETHROUGH;

            case .BOLD_FAINT_OFF;    res.attributes &= ~(.BOLD | .FAINT);
            case .ITALIC_OFF;        res.attributes &= ~.ITALIC;
            case .UNDERLINE_OFF;     res.attributes &= ~.UNDERLINE;
            case .BLINKING_OFF;      res.attributes &= ~.BLINKING;
            case .INVERSE_OFF;       res.attributes &= ~.INVERSE;
            case .HIDDEN_OFF;        res.attributes &= ~.HIDDEN;
            case .STRIKETHROUGH_OFF; res.attributes &= ~.STRIKETHROUGH;

            case .FG_BLACK;   res.fg_8bit = .TRANSPARENT;   res.flags &= ~(.FG_DEFAULT | .FG_24BIT);
            case .FG_RED;     res.fg_8bit = .RED;           res.flags &= ~(.FG_DEFAULT | .FG_24BIT);
            case .FG_GREEN;   res.fg_8bit = .GREEN;         res.flags &= ~(.FG_DEFAULT | .FG_24BIT);
            case .FG_YELLOW;  res.fg_8bit = .YELLOW;        res.flags &= ~(.FG_DEFAULT | .FG_24BIT);
            case .FG_BLUE;    res.fg_8bit = .BLUE;          res.flags &= ~(.FG_DEFAULT | .FG_24BIT);
            case .FG_MAGENTA; res.fg_8bit = .MAGENTA;       res.flags &= ~(.FG_DEFAULT | .FG_24BIT);
            case .FG_CYAN;    res.fg_8bit = .CYAN;          res.flags &= ~(.FG_DEFAULT | .FG_24BIT);
            case .FG_WHITE;   res.fg_8bit = .WHITE;         res.flags &= ~(.FG_DEFAULT | .FG_24BIT);
            case .FG_COLOR;
                if cursor == argument_count break;
                variant := arguments[cursor];
                if variant == {
                case 2;
                    if cursor + 3 >= argument_count break;
                    res.fg_24bit.r = arguments[cursor + 1];
                    res.fg_24bit.g = arguments[cursor + 2];
                    res.fg_24bit.b = arguments[cursor + 3];
                    res.flags &= ~.FG_DEFAULT;
                    res.flags |= .FG_24BIT;
                    cursor += 4;
                case 5;
                    if cursor + 1 >= argument_count break;
                    res.fg_8bit = xx arguments[cursor + 1];
                    res.flags &= ~(.FG_DEFAULT | .FG_24BIT);
                    cursor += 2;
                case;
                    continue;
                }
            case .FG_DEFAULT; res.flags |= .FG_DEFAULT; res.flags &= ~(.FG_24BIT);

            case .BG_BLACK;   res.bg_8bit = .TRANSPARENT;   res.flags &= ~(.BG_DEFAULT | .BG_24BIT);
            case .BG_RED;     res.bg_8bit = .RED;           res.flags &= ~(.BG_DEFAULT | .BG_24BIT);
            case .BG_GREEN;   res.bg_8bit = .GREEN;         res.flags &= ~(.BG_DEFAULT | .BG_24BIT);
            case .BG_YELLOW;  res.bg_8bit = .YELLOW;        res.flags &= ~(.BG_DEFAULT | .BG_24BIT);
            case .BG_BLUE;    res.bg_8bit = .BLUE;          res.flags &= ~(.BG_DEFAULT | .BG_24BIT);
            case .BG_MAGENTA; res.bg_8bit = .MAGENTA;       res.flags &= ~(.BG_DEFAULT | .BG_24BIT);
            case .BG_CYAN;    res.bg_8bit = .CYAN;          res.flags &= ~(.BG_DEFAULT | .BG_24BIT);
            case .BG_WHITE;   res.bg_8bit = .WHITE;         res.flags &= ~(.BG_DEFAULT | .BG_24BIT);
            case .BG_COLOR;
                if cursor == argument_count break;
                variant := arguments[cursor];
                if variant == {
                case 2;
                    if cursor + 3 >= argument_count break;
                    res.bg_24bit.r = arguments[cursor + 1];
                    res.bg_24bit.g = arguments[cursor + 2];
                    res.bg_24bit.b = arguments[cursor + 3];
                    res.flags &= ~.BG_DEFAULT;
                    res.flags |= .BG_24BIT;
                    cursor += 4;
                case 5;
                    if cursor + 1 >= argument_count break;
                    res.fg_8bit = xx arguments[cursor + 1];
                    res.flags &= ~(.FG_DEFAULT | .FG_24BIT);
                    cursor += 2;
                case;
                    continue;
                }
            case .BG_DEFAULT; res.flags |= .BG_DEFAULT; res.flags &= ~(.BG_24BIT);

            case .FG_BRIGHT_BLACK;   res.fg_8bit = .BRIGHT_BLACK;     res.flags &= ~(.FG_DEFAULT | .FG_24BIT);
            case .FG_BRIGHT_RED;     res.fg_8bit = .BRIGHT_RED;       res.flags &= ~(.FG_DEFAULT | .FG_24BIT);
            case .FG_BRIGHT_GREEN;   res.fg_8bit = .BRIGHT_GREEN;     res.flags &= ~(.FG_DEFAULT | .FG_24BIT);
            case .FG_BRIGHT_YELLOW;  res.fg_8bit = .BRIGHT_YELLOW;    res.flags &= ~(.FG_DEFAULT | .FG_24BIT);
            case .FG_BRIGHT_BLUE;    res.fg_8bit = .BRIGHT_BLUE;      res.flags &= ~(.FG_DEFAULT | .FG_24BIT);
            case .FG_BRIGHT_MAGENTA; res.fg_8bit = .BRIGHT_MAGENTA;   res.flags &= ~(.FG_DEFAULT | .FG_24BIT);
            case .FG_BRIGHT_CYAN;    res.fg_8bit = .BRIGHT_CYAN;      res.flags &= ~(.FG_DEFAULT | .FG_24BIT);
            case .FG_BRIGHT_WHITE;   res.fg_8bit = .BRIGHT_WHITE;     res.flags &= ~(.FG_DEFAULT | .FG_24BIT);

            case .BG_BRIGHT_BLACK;   res.bg_8bit = .BRIGHT_BLACK;     res.flags &= ~(.BG_DEFAULT | .BG_24BIT);
            case .BG_BRIGHT_RED;     res.bg_8bit = .BRIGHT_RED;       res.flags &= ~(.BG_DEFAULT | .BG_24BIT);
            case .BG_BRIGHT_GREEN;   res.bg_8bit = .BRIGHT_GREEN;     res.flags &= ~(.BG_DEFAULT | .BG_24BIT);
            case .BG_BRIGHT_YELLOW;  res.bg_8bit = .BRIGHT_YELLOW;    res.flags &= ~(.BG_DEFAULT | .BG_24BIT);
            case .BG_BRIGHT_BLUE;    res.bg_8bit = .BRIGHT_BLUE;      res.flags &= ~(.BG_DEFAULT | .BG_24BIT);
            case .BG_BRIGHT_MAGENTA; res.bg_8bit = .BRIGHT_MAGENTA;   res.flags &= ~(.BG_DEFAULT | .BG_24BIT);
            case .BG_BRIGHT_CYAN;    res.bg_8bit = .BRIGHT_CYAN;      res.flags &= ~(.BG_DEFAULT | .BG_24BIT);
            case .BG_BRIGHT_WHITE;   res.bg_8bit = .BRIGHT_WHITE;     res.flags &= ~(.BG_DEFAULT | .BG_24BIT);

            case; log_error("unknown command: %", command);
        }
    }

    return res;
}

parse_escape_sequence :: (s: string) -> Small_Escape_Sequence, bool, offset: int {
    if s.count < 3 return .{}, false, 0;
    if s[0] != #char "\e" return .{}, false, 0;
    if s[1] != #char "[" return .{}, false, 0;

    result: Small_Escape_Sequence;
    cursor := 2;
    parsing_number := false;
    while cursor < s.count {
        c := s[cursor];
        cursor += 1;

        if inline is_alpha(c) {
            if parsing_number then result.argument_count += 1;
            result.command_letter = c;
            break;
        } else if inline is_digit(c) {
            arg := *result.arguments[result.argument_count];
            arg.* = arg.* * 10 + c - #char "0";
            parsing_number = true;
        } else if c == #char ";" {
            if parsing_number {
                result.argument_count += 1;
                parsing_number = false;
            }
        }
    }

    assert(result.command_letter != 0);
    return result, true, cursor;
}

// The first number after `\e[` in a sequence ending with `m`
Ansi_Style_Command :: enum {
    RESET_ALL :: 0;

    BOLD_ON           :: 1;
    FAINT_ON          :: 2;
    ITALIC_ON         :: 3;
    UNDERLINE_ON      :: 4;
    BLINKING_ON       :: 5;
    INVERSE_ON        :: 7;
    HIDDEN_ON         :: 8;
    STRIKETHROUGH_ON  :: 9;

    BOLD_FAINT_OFF    :: 22;
    ITALIC_OFF        :: 23;
    UNDERLINE_OFF     :: 24;
    BLINKING_OFF      :: 25;
    INVERSE_OFF       :: 27;
    HIDDEN_OFF        :: 28;
    STRIKETHROUGH_OFF :: 29;

    FG_BLACK   :: 30;
    FG_RED     :: 31;
    FG_GREEN   :: 32;
    FG_YELLOW  :: 33;
    FG_BLUE    :: 34;
    FG_MAGENTA :: 35;
    FG_CYAN    :: 36;
    FG_WHITE   :: 37;

    FG_COLOR   :: 38;

    FG_DEFAULT :: 39;

    BG_BLACK   :: 40;
    BG_RED     :: 41;
    BG_GREEN   :: 42;
    BG_YELLOW  :: 43;
    BG_BLUE    :: 44;
    BG_MAGENTA :: 45;
    BG_CYAN    :: 46;
    BG_WHITE   :: 47;

    BG_COLOR   :: 48;

    BG_DEFAULT :: 49;

    FG_BRIGHT_BLACK   :: 90;
    FG_BRIGHT_RED     :: 91;
    FG_BRIGHT_GREEN   :: 92;
    FG_BRIGHT_YELLOW  :: 93;
    FG_BRIGHT_BLUE    :: 94;
    FG_BRIGHT_MAGENTA :: 95;
    FG_BRIGHT_CYAN    :: 96;
    FG_BRIGHT_WHITE   :: 97;

    BG_BRIGHT_BLACK   :: 100;
    BG_BRIGHT_RED     :: 101;
    BG_BRIGHT_GREEN   :: 102;
    BG_BRIGHT_YELLOW  :: 103;
    BG_BRIGHT_BLUE    :: 104;
    BG_BRIGHT_MAGENTA :: 105;
    BG_BRIGHT_CYAN    :: 106;
    BG_BRIGHT_WHITE   :: 107;
}

// These are used in `\e[38;5;{Color_8bit}` command
Color_8bit :: enum u8 {

    TRANSPARENT    :: 0;
    RED            :: 1;
    GREEN          :: 2;
    YELLOW         :: 3;
    BLUE           :: 4;
    MAGENTA        :: 5;
    CYAN           :: 6;
    WHITE          :: 7;
    BRIGHT_BLACK   :: 8;
    BRIGHT_RED     :: 9;
    BRIGHT_GREEN   :: 10;
    BRIGHT_YELLOW  :: 11;
    BRIGHT_BLUE    :: 12;
    BRIGHT_MAGENTA :: 13;
    BRIGHT_CYAN    :: 14;
    BRIGHT_WHITE   :: 15;

    // The formula for these is `16 + r * 36 + g * 6 + b` where r, g & b are in 0..5 inclusively
    RGB_0_0_0 ::  16; RGB_0_0_1 ::  17; RGB_0_0_2 ::  18; RGB_0_0_3 ::  19; RGB_0_0_4 ::  20; RGB_0_0_5 ::  21;
    RGB_0_1_0 ::  22; RGB_0_1_1 ::  23; RGB_0_1_2 ::  24; RGB_0_1_3 ::  25; RGB_0_1_4 ::  26; RGB_0_1_5 ::  27;
    RGB_0_2_0 ::  28; RGB_0_2_1 ::  29; RGB_0_2_2 ::  30; RGB_0_2_3 ::  31; RGB_0_2_4 ::  32; RGB_0_2_5 ::  33;
    RGB_0_3_0 ::  34; RGB_0_3_1 ::  35; RGB_0_3_2 ::  36; RGB_0_3_3 ::  37; RGB_0_3_4 ::  38; RGB_0_3_5 ::  39;
    RGB_0_4_0 ::  40; RGB_0_4_1 ::  41; RGB_0_4_2 ::  42; RGB_0_4_3 ::  43; RGB_0_4_4 ::  44; RGB_0_4_5 ::  45;
    RGB_0_5_0 ::  46; RGB_0_5_1 ::  47; RGB_0_5_2 ::  48; RGB_0_5_3 ::  49; RGB_0_5_4 ::  50; RGB_0_5_5 ::  51;

    RGB_1_0_0 ::  52; RGB_1_0_1 ::  53; RGB_1_0_2 ::  54; RGB_1_0_3 ::  55; RGB_1_0_4 ::  56; RGB_1_0_5 ::  57;
    RGB_1_1_0 ::  58; RGB_1_1_1 ::  59; RGB_1_1_2 ::  60; RGB_1_1_3 ::  61; RGB_1_1_4 ::  62; RGB_1_1_5 ::  63;
    RGB_1_2_0 ::  64; RGB_1_2_1 ::  65; RGB_1_2_2 ::  66; RGB_1_2_3 ::  67; RGB_1_2_4 ::  68; RGB_1_2_5 ::  69;
    RGB_1_3_0 ::  70; RGB_1_3_1 ::  71; RGB_1_3_2 ::  72; RGB_1_3_3 ::  73; RGB_1_3_4 ::  74; RGB_1_3_5 ::  75;
    RGB_1_4_0 ::  76; RGB_1_4_1 ::  77; RGB_1_4_2 ::  78; RGB_1_4_3 ::  79; RGB_1_4_4 ::  80; RGB_1_4_5 ::  81;
    RGB_1_5_0 ::  82; RGB_1_5_1 ::  83; RGB_1_5_2 ::  84; RGB_1_5_3 ::  85; RGB_1_5_4 ::  86; RGB_1_5_5 ::  87;

    RGB_2_0_0 ::  88; RGB_2_0_1 ::  89; RGB_2_0_2 ::  90; RGB_2_0_3 ::  91; RGB_2_0_4 ::  92; RGB_2_0_5 ::  93;
    RGB_2_1_0 ::  94; RGB_2_1_1 ::  95; RGB_2_1_2 ::  96; RGB_2_1_3 ::  97; RGB_2_1_4 ::  98; RGB_2_1_5 ::  99;
    RGB_2_2_0 :: 100; RGB_2_2_1 :: 101; RGB_2_2_2 :: 102; RGB_2_2_3 :: 103; RGB_2_2_4 :: 104; RGB_2_2_5 :: 105;
    RGB_2_3_0 :: 106; RGB_2_3_1 :: 107; RGB_2_3_2 :: 108; RGB_2_3_3 :: 109; RGB_2_3_4 :: 110; RGB_2_3_5 :: 111;
    RGB_2_4_0 :: 112; RGB_2_4_1 :: 113; RGB_2_4_2 :: 114; RGB_2_4_3 :: 115; RGB_2_4_4 :: 116; RGB_2_4_5 :: 117;
    RGB_2_5_0 :: 118; RGB_2_5_1 :: 119; RGB_2_5_2 :: 120; RGB_2_5_3 :: 121; RGB_2_5_4 :: 122; RGB_2_5_5 :: 123;

    RGB_3_0_0 :: 124; RGB_3_0_1 :: 125; RGB_3_0_2 :: 126; RGB_3_0_3 :: 127; RGB_3_0_4 :: 128; RGB_3_0_5 :: 129;
    RGB_3_1_0 :: 130; RGB_3_1_1 :: 131; RGB_3_1_2 :: 132; RGB_3_1_3 :: 133; RGB_3_1_4 :: 134; RGB_3_1_5 :: 135;
    RGB_3_2_0 :: 136; RGB_3_2_1 :: 137; RGB_3_2_2 :: 138; RGB_3_2_3 :: 139; RGB_3_2_4 :: 140; RGB_3_2_5 :: 141;
    RGB_3_3_0 :: 142; RGB_3_3_1 :: 143; RGB_3_3_2 :: 144; RGB_3_3_3 :: 145; RGB_3_3_4 :: 146; RGB_3_3_5 :: 147;
    RGB_3_4_0 :: 148; RGB_3_4_1 :: 149; RGB_3_4_2 :: 150; RGB_3_4_3 :: 151; RGB_3_4_4 :: 152; RGB_3_4_5 :: 153;
    RGB_3_5_0 :: 154; RGB_3_5_1 :: 155; RGB_3_5_2 :: 156; RGB_3_5_3 :: 157; RGB_3_5_4 :: 158; RGB_3_5_5 :: 159;

    RGB_4_0_0 :: 160; RGB_4_0_1 :: 161; RGB_4_0_2 :: 162; RGB_4_0_3 :: 163; RGB_4_0_4 :: 164; RGB_4_0_5 :: 165;
    RGB_4_1_0 :: 166; RGB_4_1_1 :: 167; RGB_4_1_2 :: 168; RGB_4_1_3 :: 169; RGB_4_1_4 :: 170; RGB_4_1_5 :: 171;
    RGB_4_2_0 :: 172; RGB_4_2_1 :: 173; RGB_4_2_2 :: 174; RGB_4_2_3 :: 175; RGB_4_2_4 :: 176; RGB_4_2_5 :: 177;
    RGB_4_3_0 :: 178; RGB_4_3_1 :: 179; RGB_4_3_2 :: 180; RGB_4_3_3 :: 181; RGB_4_3_4 :: 182; RGB_4_3_5 :: 183;
    RGB_4_4_0 :: 184; RGB_4_4_1 :: 185; RGB_4_4_2 :: 186; RGB_4_4_3 :: 187; RGB_4_4_4 :: 188; RGB_4_4_5 :: 189;
    RGB_4_5_0 :: 190; RGB_4_5_1 :: 191; RGB_4_5_2 :: 192; RGB_4_5_3 :: 193; RGB_4_5_4 :: 194; RGB_4_5_5 :: 195;

    RGB_5_0_0 :: 196; RGB_5_0_1 :: 197; RGB_5_0_2 :: 198; RGB_5_0_3 :: 199; RGB_5_0_4 :: 200; RGB_5_0_5 :: 201;
    RGB_5_1_0 :: 202; RGB_5_1_1 :: 203; RGB_5_1_2 :: 204; RGB_5_1_3 :: 205; RGB_5_1_4 :: 206; RGB_5_1_5 :: 207;
    RGB_5_2_0 :: 208; RGB_5_2_1 :: 209; RGB_5_2_2 :: 210; RGB_5_2_3 :: 211; RGB_5_2_4 :: 212; RGB_5_2_5 :: 213;
    RGB_5_3_0 :: 214; RGB_5_3_1 :: 215; RGB_5_3_2 :: 216; RGB_5_3_3 :: 217; RGB_5_3_4 :: 218; RGB_5_3_5 :: 219;
    RGB_5_4_0 :: 220; RGB_5_4_1 :: 221; RGB_5_4_2 :: 222; RGB_5_4_3 :: 223; RGB_5_4_4 :: 224; RGB_5_4_5 :: 225;
    RGB_5_5_0 :: 226; RGB_5_5_1 :: 227; RGB_5_5_2 :: 228; RGB_5_5_3 :: 229; RGB_5_5_4 :: 230; RGB_5_5_5 :: 231;

    // 0 is black, 23 is white
    GRAY_0  :: 232; GRAY_1  :: 233; GRAY_2  :: 234; GRAY_3  :: 235; GRAY_4  :: 236; GRAY_5  :: 237;
    GRAY_6  :: 238; GRAY_7  :: 239; GRAY_8  :: 240; GRAY_9  :: 241; GRAY_10 :: 242; GRAY_11 :: 243;
    GRAY_12 :: 244; GRAY_13 :: 245; GRAY_14 :: 246; GRAY_15 :: 247; GRAY_16 :: 248; GRAY_17 :: 249;
    GRAY_18 :: 250; GRAY_19 :: 251; GRAY_20 :: 252; GRAY_21 :: 253; GRAY_22 :: 254; GRAY_23 :: 255;
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
    data: [23] u8;
}
#assert size_of(Small_Bytes) == 24;

operator == :: inline (a: Small_Bytes, b: Small_Bytes) -> bool {
    if a.count != b.count return false;
    return memcmp(a.data.data, b.data.data, a.count) == 0;
}
small_bytes_equals :: #procedure_of_call operator == (Small_Bytes.{}, Small_Bytes.{});

get_hash :: inline (b: Small_Bytes) -> u32 {
    return Hash.get_hash(to_string(*b));
}

to_string :: inline (using bytes: *Small_Bytes) -> string {
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
    print_ascii_or_hex(builder, to_string(*bytes));
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

trim_crap :: (s: string, crap := "⠀" /* \u2800 */) -> string {
    new_s := s;
    while starts_with(new_s, crap) {
        new_s.data += crap.count;
        new_s.count -= crap.count;
    }

    while ends_with(new_s, crap) {
        new_s.count -= crap.count;
    }

    return new_s;
}

print_utf8 :: (builder: *String_Builder, u: u32) {
    data := ensure_contiguous_space(builder, 4);
    buffer: string;
    buffer.data = data;
    buffer.count = 4;
    character_utf32_to_utf8(u, *buffer);
    advance_through_ensured_space(builder, buffer.count);
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
    // ~ISIG: disable special characters generating signals (cltr+c, ctrl+\, and others?)
    new_termios.c_lflag &= ~(ECHO | ICANON | ISIG);
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

//
// footer
//

test_parse_ascii_or_hex :: () {
    in, out: string;
    ok: bool;

    in = "\\x00";
    out, ok = parse_ascii_or_hex(in); assert(ok, "%", in);
    assert(out == "\x00", "%", cast(Ascii_Or_Hex) out);

    in = "\\x1b[1;31m";
    out, ok = parse_ascii_or_hex(in); assert(ok, "%", in);
    assert(out == "\e[1;31m", "%", cast(Ascii_Or_Hex) out);

    in = "[\\e\\n\\r\\t\\\\\\x00\\x13\\\"\\xbA]";
    out, ok = parse_ascii_or_hex(in); assert(ok, "%", in);
    assert(out == "[\e\n\r\t\\\x00\x13\"\xbA]", "%", cast(Ascii_Or_Hex) out);

}

test_print_pixel_value :: () {
    pixel: Pixel_Value;

    owned_builder: String_Builder;
    builder := *owned_builder;

    pixel = Pixel_Value.id(1);

    append(builder, " ");
    print_pixel_value(builder, pixel);
    append(builder, "  \e[0m");

    pixel = Pixel_Value.rgb(13, 37, 69);
    print_pixel_value(builder, pixel);
    append(builder, "  \e[0m");

    s := builder_to_string(builder);
    assert(s == " \e[48;5;1m  \e[0m\e[48;2;13;37;69m  \e[0m", "%", cast(Ascii_Or_Hex) s);

    print("%\n", s);
}

test_print_braille :: () {
    owned_builder: String_Builder;
    builder := *owned_builder;

    print_braille(builder, ._0_0 | ._1_1 | ._1_2 | ._0_3);
    print_braille(builder, ._1_0 | ._0_1 | ._0_2 | ._1_3);
    s := builder_to_string(builder);
    assert(s == "⡱⢎", "%", s);

    print("%\n", s);
}

test_parse_shit :: () {
    log("cwd: %\n", get_working_directory());
    data, ok := my_read_entire_file("test.data");
    if !ok {
        code, message := get_error_value_and_string();
        log("FAIL: % %", code, message);
        assert(ok);
    }

    parser: Parse_State;
    parser.raw_text = data;
    parse_text_with_control_codes(*parser);

    assert(data.count == 1, "%", data.count);
}

Parse_State :: struct {
    raw_text: string;
    only_text_storage: [..] u8;
    parsed_up_to: int;

    flags: enum { DIFF_MARKERS; };

    line_offsets: [..] u32;
    attribute_ranges: [..] Attribute_Range;

    diff_markers: [..] Range;
}

Attribute_Range :: struct {
    offset_in_only_text: u32;
    range_count: u32;
    union {
        small_style: Small_Style;
        color_24bit: Color_24bit;
        index_in_storage: u32;
    };
    type: enum { SMALL_STYLE; COLOR_24BIT; IN_STORAGE; };
}

parse_text_with_control_codes :: (parser: *Parse_State) {
    using parser;

    unparsed_tail := raw_text;

    if parsed_up_to == 0 {
        // This is kinda retarded, but actually makes sense if you think about it
        array_add(*line_offsets, 0);
    } else {
        unparsed_tail = advance(raw_text, parsed_up_to);
    }

    array_reserve(*only_text_storage, raw_text.count);

    current_style: Style;

    while !should_exit {
        found:, line:, unparsed_tail = split_from_left(unparsed_tail, #char "\n");

        auto_release_temp();

        escape_sequences_in_line: [..] Small_Escape_Sequence_In_Text;
        escape_sequences_in_line.allocator = temp;

        current_backspace_sequence: Ansi_Style_Command;

        cursor := 0;
        while cursor < line.count {
            c := line[cursor];
            // Continue or start a new stupid fucking backspace sequence conversion
            if c == #char "\x08" {
                cursor += 1; // consume the '\x08'
                if !only_text_storage {
                    continue;
                }
                if cursor == line.count {
                    break;
                }

                // Here we're handling the ancient hacks from back in the day
                // when consoles would print on actual paper. The hack was to
                // output something like `B\bBO\bOL\bLD\bD` which would result
                // in `BOLD` being printed in bold-ish style, because the
                // carriage would physically stamp the same letter twice. And
                // also `_\bU_\bN_\bD_\bE_\bR` would become underlined `UNDER`.
                // So basically `man` is still using these hacks instead of
                // using the corresponding ANSI sequences `\e[1mBOLD` &
                // `\e[4mUNDER`, so now I have to deal with this...

                prev := only_text_storage[only_text_storage.count - 1];
                next := line[cursor];
                only_text_storage[only_text_storage.count - 1] = next;
                cursor += 1; // consume the character after the '\x08'

                if prev == next || prev == #char "_" {
                    style: Ansi_Style_Command = ifx prev == next then .BOLD_ON else .UNDERLINE_ON;
                    if current_backspace_sequence == style {
                        // continue the current sequence
                    } else {
                        assert(!current_backspace_sequence);
                        info := array_add(*escape_sequences_in_line);
                        info.offset = xx (only_text_storage.count - 1);
                        info.base = make_small_escape_sequence("m", xx style);
                    }
                }

                continue;
            }

            // Finalize the stupid fucking backspace sequence conversion
            if current_backspace_sequence {
                info := array_add(*escape_sequences_in_line);
                info.offset = xx only_text_storage.count;
                off: Ansi_Style_Command = ifx current_backspace_sequence == .BOLD_ON then .BOLD_FAINT_OFF
                                                                                     else .UNDERLINE_OFF;
                info.base = make_small_escape_sequence("m", xx off);
                current_backspace_sequence = .RESET_ALL;
            }

            if c == #char "\e" {
                sequence, ok, offset := parse_escape_sequence(line);
                if ok {
                    array_add(*escape_sequences_in_line, .{sequence, xx only_text_storage.count});
                    cursor += offset;
                    continue;
                }
                // @Incomplete FIXME \e actually makes the following character non-printable
                cursor += 1; // consume the '\e'
                continue;
            }

            // Handle the fucking tab character
            if c == #char "\t" {
                // TODO keep the tab character and do the fucking tabularization
                array_add(*only_text_storage, ..cast([] u8, "        ")); // :automatic_tab_expansion:

                cursor += 1; // consume the '\t'
                continue;
            }

            // Regular old character
            inline array_add(*only_text_storage, c);
            cursor += 1; // consume the character
        }

        line_start := last(line_offsets);
        line_end := only_text_storage.count;

        handle_attribute_escape_sequences(parser, escape_sequences_in_line, line_start, xx line_end);

        if !found break;

        inline array_add(*only_text_storage, #char "\n");

        array_add(*line_offsets, xx only_text_storage.count);

        line_length := only_text_storage.count - line_start - 1;
        only_text_line := array_view(only_text_storage, line_start, line_length);
        if starts_with(xx only_text_line, "commit ") { // @diff_headers
            array_add(*diff_markers, .{xx line_start, xx line_length});
        }
        diff_marker := starts_with(xx only_text_line, "diff --git");
        if diff_marker { flags |= .DIFF_MARKERS; }
        if diff_marker {
            array_add(*diff_markers, .{xx line_start, xx line_length});
        }
        if (flags & .DIFF_MARKERS && starts_with(xx only_text_line, "@@ ")) {
            array_add(*diff_markers, .{xx line_start, xx line_length});
        }
    }
}

Small_Escape_Sequence_In_Text :: struct {
    #as using base: Small_Escape_Sequence;
    offset: u32;
}

handle_attribute_escape_sequences :: (using parser: *Parse_State, escape_sequences_in_line: [] Small_Escape_Sequence_In_Text, line_start: u32, line_end: u32) {
    curr_range_start := line_start;

    current_style: Style; // FIXME no idea about this, had to add this to make the code compile months after the original code was written....

    if escape_sequences_in_line {
        sequence := last(escape_sequences_in_line);
        new_style := evaluate_style_sequence(sequence, current_style);
        if (sequence.offset > curr_range_start)
            && !is_default(current_style)
            && !equals(new_style, current_style)
        {
            // @WRONG
            // Close the continuing style from previous line
            range := array_add(*attribute_ranges);
            range.offset_in_only_text = curr_range_start;
            range.range_count = sequence.offset - curr_range_start;
            compress_style_attribute(parser, range, current_style);
            curr_range_start = sequence.offset;
        }
    }
    /*

<RED>foo <RESET>bar<BLUE>bizz buzz<RESET>hey ho\n

    */

    for sequence: escape_sequences_in_line {
        new_style := evaluate_style_sequence(sequence, current_style);
        if equals(new_style, current_style) continue;
        defer current_style = new_style;

        if sequence.offset == curr_range_start {
            // FIXME @WRONG
            range := last(*attribute_ranges);
            compress_style_attribute(parser, range, current_style);
            continue;
        }

        assert(sequence.offset > curr_range_start, "% %", sequence.offset, curr_range_start);
        if !is_default(current_style) {
            // @WRONG
            range := array_add(*attribute_ranges);
            range.offset_in_only_text = curr_range_start;
            range.range_count = sequence.offset - curr_range_start;
            compress_style_attribute(parser, range, current_style);
        }
        curr_range_start = sequence.offset;
    }

/* FIXME
    if (curr_range_start != line_end) && is_default() {

    }
    */
}

compress_style_attribute :: (parser: *Parse_State, range: *Attribute_Range, style: Style) {
    fg_24bit := (style.flags & .FG_24BIT);
    bg_24bit := (style.flags & .BG_24BIT);
    if !(fg_24bit && bg_24bit) {
        range.small_style.fg_color = style.fg_8bit;
        range.small_style.bg_color = style.bg_8bit;
        range.small_style.attributes = style.attributes;
        range.type = .SMALL_STYLE;
        return;
    }

    if fg_24bit && (style.flags & .BG_DEFAULT) && !style.attributes {
        range.color_24bit = style.fg_24bit;
        range.color_24bit.flags = .FOREGROUND;
        range.type = .COLOR_24BIT;
        return;
    }

    if bg_24bit && (style.flags & .FG_DEFAULT) && !style.attributes {
        range.color_24bit = style.bg_24bit;
        range.color_24bit.flags = .BACKGROUND;
        range.type = .COLOR_24BIT;
        return;
    }

    assert(false, "TODO %", style);

    // TODO if not that's a TODO
}

run_tests :: () {
    t0 := seconds_since_init();
    log("running tests...");

    log("test_get_next_control_code_in_range");     test_get_next_control_code_in_range();
    log("test_get_subfield_by_path");               test_get_subfield_by_path();
    log("test_array_ordered_remove_range");         test_array_ordered_remove_range();
    log("test_parse_ascii_or_hex");                 test_parse_ascii_or_hex();
    log("test_print_pixel_value");                  test_print_pixel_value();
    log("test_print_braille");                      test_print_braille();
    log("test_parse_shit");                         test_parse_shit();

    elapsed := seconds_since_init() - t0;
    log("\e[32mall tests passed!\e[0m elapsed: %", fmt(elapsed, 6));
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
#import "Bit_Array";
Meow_Hash :: #import "meow_hash";
// #if OS == .LINUX #import "X11";
// #import "Clipboard";
System :: #import "System";
Hash :: #import "Hash";
#import "Version_Banner";
