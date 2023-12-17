EXE_NAME :: "ruler";
#run {
    set_build_options_dc(.{ output_executable_name = EXE_NAME });

    #if OS == .WINDOWS {
        release := false;
        for get_toplevel_command_line() if it == "-release" then release = true;
        WR :: #import "Windows_Resources";
        if release WR.disable_runtime_console();
    }
}

// TODO:
// - redraw while resizing, see: https://github.com/cmuratori/dtc
// - transparent background
// - render to an upscaled texture and downscale for subpixel rendering
// - customizable DPI

main :: () {
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Create window
    #if OS == .WINDOWS {
        Windows :: #import "Windows";
        Windows.SetProcessDPIAware();
        // Windows is very bad at thread-switching by default unless you do this. Sad.
        Windows.timeBeginPeriod(1);
    }

    window_position: Vector2;
    window_size := Vector2.{ 860, 480 };
    #if OS == .WINDOWS {
        work_area: Windows.RECT;
        ok1 := Windows.SystemParametersInfoW(Windows.SPI_GETWORKAREA, 0, *work_area, 0);
        log("work_area: %", work_area);
        if ok1 {
            work_area_size: Vector2;
            work_area_size.x = xx (work_area.right - work_area.left);
            work_area_size.y = xx (work_area.bottom - work_area.top);
            work_area_start: Vector2;
            work_area_start.x = xx work_area.left;
            work_area_start.y = xx work_area.top;

            window_size = work_area_size / 2;
            window_position = work_area_start + work_area_size / 2 - window_size / 2;
        }
    }

    window := create_window(xx window_size.x, xx window_size.y, EXE_NAME, xx window_position.x, xx window_position.y);
    quit := false;

    Simp.set_render_target(window);

    // GetRect stuff
    GetRect.ui_init();
    get_rect_theme := GetRect.default_theme_procs[GetRect.Default_Themes.Default]();
    GetRect.set_default_theme(get_rect_theme);

    font_data :: #run -> [] u8 {
        data, ok := read_entire_file("OpenSans-BoldItalic.ttf");
        assert(ok);
        return add_global_data(xx data, .READ_ONLY, null);
    };

    my_font := Simp.get_font_at_size(font_data, 28);

    // Init

    system_screen_size: Vector2;
    system_dpi: Vector2;
    #if OS == .WINDOWS {
        user32 :: #system_library "user32";
        SetLayeredWindowAttributes :: (hwnd: Windows.HWND, crKey: u32, bAlpha: u8, dwFlags: Windows.DWORD) -> Windows.BOOL #foreign user32;

        style := Windows.GetWindowLongW(window, Windows.GWL_STYLE);
        // style &= ~cast(s32) Windows.WS_CAPTION;
        Windows.SetWindowLongW(window, Windows.GWL_STYLE, style);
        ex_style := Windows.SetWindowLongW(window, Windows.GWL_EXSTYLE, Windows.WS_EX_LAYERED);

        // Requires win8+
        shcore :: #system_library "Shcore";
        GetDpiForMonitor :: (m: Windows.HMONITOR, t: Windows.MONITOR_DPI_TYPE, dpiX: *u32, dpiY: *u32) -> Windows.HRESULT #foreign shcore;

        dpi_x, dpi_y: u32;
        monitor := Windows.MonitorFromWindow(window, Windows.MONITOR_DEFAULTTONEAREST);
        rc := GetDpiForMonitor(monitor, .MDT_RAW_DPI, *dpi_x, *dpi_y);
        assert(rc == 0);

        system_dpi.x = xx dpi_x;
        system_dpi.y = xx dpi_y;

        info: Windows.MONITORINFO;
        info.cbSize = size_of(type_of(info));
        success := Windows.GetMonitorInfoW(monitor, *info);
        if success {
            system_screen_size.x = xx (info.rcMonitor.right  - info.rcMonitor.left);
            system_screen_size.y = xx (info.rcMonitor.bottom - info.rcMonitor.top);
        }
    }

    mouse_absolute_at_click: Vector2;
    window_position_at_click: Vector2;
    click_handled := false;
    fullscreen := false;
    saved_window_info: Saved_Window_Info;

    time_last_frame_start : f64 = 0.0;
    time_frame_start : f64;

    fg_color := Vector4.{ .8, .8, .8, 1 };
    bg_color := Vector4.{ .1, .1, .1, 1 };
    off_color := Vector4.{ .5, .5, .5, 1 };

    grid_mode : enum { OFF; CENTIMETERS; INCHES; } = .OFF;

    transparent := true;
    {
        #if OS == .WINDOWS {
            alpha : u8 = xx ifx transparent then 0x80 else 0xff;
            ok := SetLayeredWindowAttributes(window, 0, alpha, LWA_ALPHA);
            if !ok {
                code, msg := get_error_value_and_string();
                log_error("[%] %", code, msg);
            }
            assert(xx ok);
        }
    }

    something_changed := true; // Must be true on first iteration

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Game loop
    while !quit {
        // Time
        //
        time_last_frame_start = time_frame_start;
        time_frame_start = get_time();
        dt := cast(f32) min(time_frame_start - time_last_frame_start, 1.0/60);

        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Handle input
        Input.update_window_events();

        defer something_changed = false;

        for Input.get_window_resizes() {
            Simp.update_window(it.window);

            if it.window == window {
                window_size.x = xx it.width;
                window_size.y = xx it.height;

                something_changed = true;
            }
        }

        // Read mouse before checking key presses so that debug_break() is
        // called after we know mouse position.
        mouse : Vector2;
        {
            x, y, ok := get_mouse_pointer_position(window, true);
            if ok {
                mouse.x = xx x;
                mouse.y = xx y;
            }
        }
        #if OS == .WINDOWS {
            rect: Windows.RECT;
            Windows.GetWindowRect(window, *rect);
            window_position := Vector2.{ xx rect.left, xx rect.top };
            window_outer_size := Vector2.{ xx (rect.right - rect.left), xx (rect.bottom - rect.top) };
            mouse_absolute := window_position + .{ mouse.x, -mouse.y };
        }

        click := false;
        mouse_button_left_state := Input.input_button_states[Input.Key_Code.MOUSE_BUTTON_LEFT];
        if mouse_button_left_state {
            something_changed = true;
        }
        if mouse_button_left_state & .END {
            click_handled = false;
        }
        if mouse_button_left_state & .START {
            #if OS == .WINDOWS {
                window_position_at_click = window_position;
                mouse_absolute_at_click = mouse_absolute;
            }
            click = true;
        }

        for Input.events_this_frame {
            if it.type == .QUIT then quit = true;

            GetRect.getrect_handle_event(it);

            if it.type == {
              case .KEYBOARD;
                something_changed = true;

                if it.key_pressed && it.key_code == .ESCAPE {
                    quit = true;
                }

                if it.key_pressed && it.key_code == .F4 {
                    debug_break();
                }

                if it.key_pressed && it.key_code == .F11 {
                    fullscreen = !fullscreen;
                    toggle_fullscreen(window, fullscreen, *saved_window_info);
                }
            }
        }

        if !something_changed {
            frame_budget_secs := 1.0 / 30;
            secs_spent_so_far := get_time() - time_frame_start;
            secs_left := frame_budget_secs - secs_spent_so_far;
            if secs_left > 0 {
                sleep_milliseconds(xx (secs_left * 1000));
            }
            continue;
        }

        GetRect.ui_per_frame_update(window, xx window_size.x, xx window_size.y, time_frame_start);
        sliders_rect := GetRect.get_rect(window_size.x - 240, window_size.y - 30, 200, 20);

        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Update/Draw
        Simp.update_window(window);
        Simp.clear_render_target(bg_color.x, bg_color.y, bg_color.z, bg_color.w);


        width_pixels  := ifx system_screen_size.x then system_screen_size.x else 1960.0;
        height_pixels := ifx system_screen_size.y then system_screen_size.y else 1080.0;
        diagonal_pixels := sqrt(pow(width_pixels, 2) + pow(height_pixels, 2));

        diagonal_inches := 17.3;

        px_per_in_x := ifx system_dpi.x then system_dpi.x else diagonal_pixels / diagonal_inches;
        px_per_in_y := ifx system_dpi.y then system_dpi.y else diagonal_pixels / diagonal_inches;

        in_per_px_x := 1 / px_per_in_x;
        in_per_px_y := 1 / px_per_in_y;

        cm_per_in := 2.54;
        cm_per_px_x := cm_per_in / px_per_in_x;
        cm_per_px_y := cm_per_in / px_per_in_y;
        px_per_cm_x := px_per_in_x / cm_per_in;
        px_per_cm_y := px_per_in_y / cm_per_in;

        if grid_mode != .INCHES
        {
            // Vertical cm ruler
            {
                cm_mark_length := ifx grid_mode == .CENTIMETERS then window_size.x else 10.0;
                cm_mark_width :=  ifx grid_mode == .CENTIMETERS then           2.0 else 3.0;
                mm_mark_length := ifx grid_mode == .CENTIMETERS then window_size.x else 6.0;
                mm_mark_width := 1.0;

                cm_mark_pos := window_size.y;

                Simp.set_shader_for_color();
                while cm_mark_pos >= 0 {
                    x := window_size.x - cm_mark_length;
                    y := cm_mark_pos - cm_mark_width / 2;
                    immediate_rect(x, y, cm_mark_length, cm_mark_width, fg_color);

                    mm_mark_pos := cm_mark_pos;
                    for 1..9 {
                        mm_mark_pos -= .1 * px_per_cm_y;
                        x := window_size.x - mm_mark_length;
                        y := mm_mark_pos - mm_mark_width / 2;
                        immediate_rect(x, y, mm_mark_length, mm_mark_width, fg_color);
                    }

                    cm_mark_pos -= px_per_cm_y;
                }
            }

            // Horizontal cm ruler
            {
                cm_mark_length := ifx grid_mode == .CENTIMETERS then window_size.y else 10.0;
                cm_mark_width :=  ifx grid_mode == .CENTIMETERS then           2.0 else 3.0;
                mm_mark_length := ifx grid_mode == .CENTIMETERS then window_size.y else 6.0;
                mm_mark_width := 1.0;

                cm_mark_pos := 0.0;

                Simp.set_shader_for_color();
                while cm_mark_pos <= window_size.x {
                    x := cm_mark_pos - cm_mark_width / 2;
                    y := 0.0;
                    immediate_rect(x, y, cm_mark_width, cm_mark_length, fg_color);

                    mm_mark_pos := cm_mark_pos;
                    for 1..9 {
                        mm_mark_pos += .1 * px_per_cm_x;
                        x := mm_mark_pos - mm_mark_width / 2;
                        y := 0.0;
                        immediate_rect(x, y, mm_mark_width, mm_mark_length, fg_color);
                    }

                    cm_mark_pos += px_per_cm_x;
                }
            }
        }

        if grid_mode != .CENTIMETERS
        {
            // Vertical inch ruler
            {
                inch_mark_length :=  ifx grid_mode == .INCHES then window_size.x else 10.0;
                inch_mark_width :=   ifx grid_mode == .INCHES then           2.0 else 3.0;
                eigth_mark_length := ifx grid_mode == .INCHES then window_size.x else 6.0;
                eigth_mark_width :=  ifx grid_mode == .INCHES then           1.0 else 2.0;

                inch_mark_pos := window_size.y;

                Simp.set_shader_for_color();
                while inch_mark_pos >= 0 {
                    x := 0.0;
                    y := inch_mark_pos - inch_mark_width / 2;
                    immediate_rect(x, y, inch_mark_length, inch_mark_width, fg_color);

                    eigth_mark_pos := inch_mark_pos;
                    for 1..7 {
                        eigth_mark_pos -= .125 * px_per_in_y;
                        x := 0.0;
                        y := eigth_mark_pos - eigth_mark_width / 2;
                        immediate_rect(x, y, eigth_mark_length, eigth_mark_width, fg_color);
                    }

                    inch_mark_pos -= px_per_in_y;
                }
            }

            // Horizontal inch ruler
            {
                inch_mark_length :=  ifx grid_mode == .INCHES then window_size.y else 10.0;
                inch_mark_width :=   ifx grid_mode == .INCHES then           2.0 else 3.0;
                eigth_mark_length := ifx grid_mode == .INCHES then window_size.y else 6.0;
                eigth_mark_width :=  ifx grid_mode == .INCHES then           1.0 else 2.0;

                inch_mark_pos := 0.0;

                Simp.set_shader_for_color();
                while inch_mark_pos <= window_size.x {
                    x := inch_mark_pos - inch_mark_width / 2;
                    y := window_size.y - inch_mark_length;
                    immediate_rect(x, y, inch_mark_width, inch_mark_length, fg_color);

                    eigth_mark_pos := inch_mark_pos;
                    for 1..7 {
                        eigth_mark_pos += .125 * px_per_in_x;
                        x := eigth_mark_pos - eigth_mark_width / 2;
                        y := window_size.y - eigth_mark_length;
                        immediate_rect(x, y, eigth_mark_width, eigth_mark_length, fg_color);
                    }

                    inch_mark_pos += px_per_in_x;
                }
            }
        }


        outer_margin := 25.0;
        inner_margin := 2.0;
        y_ofs := 34;
        y_pos := window_size.y - y_ofs - outer_margin;

        {
            Simp.set_shader_for_text();

            x, y := 0.0, 0.0;

            px_w := window_size.x;
            px_h := window_size.y;
            px_d := sqrt(pow(px_w, 2) + pow(px_h, 2));
            px_text := tprint("pixels: % x % / %", px_w, px_h, ff(px_d));
            x = outer_margin + inner_margin;
            y = y_pos + inner_margin;
            Simp.draw_text(my_font, xx x, xx y, px_text, fg_color);
            y_pos -= y_ofs;

            in_w := window_size.x * in_per_px_x;
            in_h := window_size.y * in_per_px_y;
            in_d := sqrt(pow(in_w, 2) + pow(in_h, 2));
            in_text := tprint("inches: % x % / %", ff(in_w), ff(in_h), ff(in_d));
            x = outer_margin + inner_margin;
            y = y_pos + inner_margin;
            Simp.draw_text(my_font, xx x, xx y, in_text, fg_color);
            y_pos -= y_ofs;

            cm_w := window_size.x * cm_per_px_x;
            cm_h := window_size.y * cm_per_px_y;
            cm_d := sqrt(pow(cm_w, 2) + pow(cm_h, 2));
            cm_text := tprint("centimeters: % x % / %", ff(cm_w), ff(cm_h), ff(cm_d));
            x = outer_margin + inner_margin;
            y = y_pos + inner_margin;
            Simp.draw_text(my_font, xx x, xx y, cm_text , fg_color);
            y_pos -= y_ofs;
        }

        // Invert color button
        {
            width := 300.0;
            height := 40.0;
            button_inner_margin := 10.0;
            x0 := outer_margin;
            y0 := y_pos + y_ofs - height - button_inner_margin;

            Simp.set_shader_for_color();
            immediate_rect(x0, y0, width, height, fg_color);

            text_width := Simp.prepare_text(my_font, "Invert Color");
            text_height := 22.0;
            text_x := x0 + width / 2 - text_width / 2;
            text_y := y0 + text_height / 2;
            Simp.set_shader_for_text();
            button_text_color := bg_color;
            Simp.draw_prepared_text(my_font, xx text_x, xx text_y, button_text_color);

            if click && mouse.x >= x0 && mouse.x <= x0 + width && mouse.y >= y0 && mouse.y <= y0 + height {
                click_handled = true;
                fg_color, bg_color = bg_color, fg_color;
            }

            y_pos = y0 - y_ofs;
        }

        // Transparency button
        #if OS == .WINDOWS {
            width := 300.0;
            height := 40.0;
            button_inner_margin := 6.0;
            x0 := outer_margin;
            y0 := y_pos + y_ofs - height - button_inner_margin;

            Simp.set_shader_for_color();
            immediate_rect(x0, y0, width, height, fg_color);

            text_width := Simp.prepare_text(my_font, ifx transparent then "Transparent" else "Not transparent");
            text_height := 22.0;
            text_x := x0 + width / 2 - text_width / 2;
            text_y := y0 + text_height / 2;
            Simp.set_shader_for_text();
            button_text_color := bg_color;
            Simp.draw_prepared_text(my_font, xx text_x, xx text_y, button_text_color);

            if click && mouse.x >= x0 && mouse.x <= x0 + width && mouse.y >= y0 && mouse.y <= y0 + height {
                click_handled = true;
                transparent = !transparent;
                alpha : u8 = xx ifx transparent then 0x80 else 0xff;
                ok := SetLayeredWindowAttributes(window, 0, alpha, LWA_ALPHA);
                if !ok {
                    code, msg := get_error_value_and_string();
                    log_error("[%] %", code, msg);
                }
                assert(xx ok);
            }

            y_pos = y0 - y_ofs;
        }

        // Fullscreen toggle button
        {
            width := 300.0;
            height := 40.0;
            button_inner_margin := 6.0;
            x0 := outer_margin;
            y0 := y_pos + y_ofs - height - button_inner_margin;

            Simp.set_shader_for_color();
            immediate_rect(x0, y0, width, height, fg_color);

            text_width := Simp.prepare_text(my_font, ifx fullscreen then "Fullscreen" else "Windowed");
            text_height := 22.0;
            text_x := x0 + width / 2 - text_width / 2;
            text_y := y0 + text_height / 2;
            Simp.set_shader_for_text();
            button_text_color := bg_color;
            Simp.draw_prepared_text(my_font, xx text_x, xx text_y, button_text_color);

            if click && mouse.x >= x0 && mouse.x <= x0 + width && mouse.y >= y0 && mouse.y <= y0 + height {
                click_handled = true;
                fullscreen = !fullscreen;
                toggle_fullscreen(window, fullscreen, *saved_window_info);
            }

            y_pos = y0 - y_ofs;
        }

        // Mode centimeter grid
        {
            width := 300.0;
            height := 40.0;
            button_inner_margin := 6.0;
            x0 := outer_margin;
            y0 := y_pos + y_ofs - height - button_inner_margin;

            button_is_on := grid_mode == .CENTIMETERS;
            Simp.set_shader_for_color();
            button_color := ifx button_is_on then off_color else fg_color;
            immediate_rect(x0, y0, width, height, button_color);

            text_width := Simp.prepare_text(my_font, "Centimeter grid");
            text_height := 22.0;
            text_x := x0 + width / 2 - text_width / 2;
            text_y := y0 + text_height / 2;
            Simp.set_shader_for_text();
            button_text_color := bg_color;
            Simp.draw_prepared_text(my_font, xx text_x, xx text_y, button_text_color);

            if click && mouse.x >= x0 && mouse.x <= x0 + width && mouse.y >= y0 && mouse.y <= y0 + height {
                click_handled = true;
                if grid_mode == {
                    case .CENTIMETERS; grid_mode = .OFF;
                    case;              grid_mode = .CENTIMETERS;
                }
            }

            y_pos = y0 - y_ofs;
        }

        // Mode inches grid
        {
            width := 300.0;
            height := 40.0;
            button_inner_margin := 6.0;
            x0 := outer_margin;
            y0 := y_pos + y_ofs - height - button_inner_margin;

            button_is_on := grid_mode == .INCHES;
            Simp.set_shader_for_color();
            button_color := ifx button_is_on then off_color else fg_color;
            immediate_rect(x0, y0, width, height, button_color);

            text_width := Simp.prepare_text(my_font, "Inches grid");
            text_height := 22.0;
            text_x := x0 + width / 2 - text_width / 2;
            text_y := y0 + text_height / 2;
            Simp.set_shader_for_text();
            button_text_color := bg_color;
            Simp.draw_prepared_text(my_font, xx text_x, xx text_y, button_text_color);

            if click && mouse.x >= x0 && mouse.x <= x0 + width && mouse.y >= y0 && mouse.y <= y0 + height {
                click_handled = true;
                if grid_mode == {
                    case .INCHES; grid_mode = .OFF;
                    case;              grid_mode = .INCHES;
                }
            }

            y_pos = y0 - y_ofs;
        }

        // Move window
        #if OS == .WINDOWS {
            if !fullscreen && !click_handled && mouse_button_left_state == .DOWN {
                position_offset := mouse_absolute - mouse_absolute_at_click;
                new_position := window_position_at_click + position_offset;
                x0 := new_position.x;
                y0 := new_position.y;
                Windows.SetWindowPos(window, Windows.HWND_TOPMOST, xx x0, xx y0, xx window_outer_size.x, xx window_outer_size.y,
                                     Windows.SWP_NOZORDER | Windows.SWP_NOACTIVATE | Windows.SWP_FRAMECHANGED);
            }
        }

        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Main loop end

        Simp.swap_buffers(window);

        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // End of frame
        reset_temporary_storage();

        frame_budget_secs := 1.0 / 60;
        secs_spent_so_far := get_time() - time_frame_start;
        secs_left := frame_budget_secs - secs_spent_so_far;
        if secs_left > 0 {
            // log("going to sleep for %", millis_left_to_sleep, flags = .VERY_VERBOSE_ONLY);
            sleep_milliseconds(xx (secs_left * 1000));
        } else {
            // log("we're running late, not gonna sleep tonight", flags = .VERY_VERBOSE_ONLY);
        }
    }
}

immediate_rect :: inline (x: float, y: float, width: float, height: float, color: Vector4) {
    Simp.immediate_quad(.{ x,         y },
                        .{ x,         y + height },
                        .{ x + width, y + height },
                        .{ x + width, y },
                        color, color, color, color);
}

ff :: (value: $F/Type.[float, float64], trailing := 1) -> FormatFloat #expand {
    return FormatFloat.{ value = value, trailing_width = trailing, zero_removal = .ONE_ZERO_AFTER_DECIMAL };
}

f64 :: float64;
f32 :: float32;

WSTYLE :: enum_flags u32 {
    WS_OVERLAPPED       :: 0x00000000;
    WS_POPUP            :: 0x80000000;
    WS_CHILD            :: 0x40000000;
    WS_MINIMIZE         :: 0x20000000;
    WS_VISIBLE          :: 0x10000000;
    WS_DISABLED         :: 0x08000000;
    WS_CLIPSIBLINGS     :: 0x04000000;
    WS_CLIPCHILDREN     :: 0x02000000;
    WS_MAXIMIZE         :: 0x01000000;
    WS_CAPTION          :: 0x00C00000; // WS_BORDER | WS_DLGFRAME
    WS_BORDER           :: 0x00800000;
    WS_DLGFRAME         :: 0x00400000;
    WS_VSCROLL          :: 0x00200000;
    WS_HSCROLL          :: 0x00100000;
    WS_SYSMENU          :: 0x00080000;
    WS_THICKFRAME       :: 0x00040000;
    WS_GROUP            :: 0x00020000;
    WS_TABSTOP          :: 0x00010000;
    WS_MINIMIZEBOX      :: 0x00020000;
    WS_MAXIMIZEBOX      :: 0x00010000;
    WS_SIZEBOX          :: WS_THICKFRAME;
    WS_OVERLAPPEDWINDOW :: WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
}

WSTYLE_EX :: enum_flags u32 {
    WS_EX_DLGMODALFRAME     :: 0x00000001;
    WS_EX_NOPARENTNOTIFY    :: 0x00000004;
    WS_EX_TOPMOST           :: 0x00000008;
    WS_EX_ACCEPTFILES       :: 0x00000010;
    WS_EX_TRANSPARENT       :: 0x00000020;
    WS_EX_MDICHILD          :: 0x00000040;
    WS_EX_TOOLWINDOW        :: 0x00000080;
    WS_EX_WINDOWEDGE        :: 0x00000100;
    WS_EX_CLIENTEDGE        :: 0x00000200;
    WS_EX_CONTEXTHELP       :: 0x00000400;
    WS_EX_RIGHT             :: 0x00001000;
    WS_EX_LEFT              :: 0x00000000;
    WS_EX_RTLREADING        :: 0x00002000;
    WS_EX_LTRREADING        :: 0x00000000;
    WS_EX_LEFTSCROLLBAR     :: 0x00004000;
    WS_EX_RIGHTSCROLLBAR    :: 0x00000000;
    WS_EX_CONTROLPARENT     :: 0x00010000;
    WS_EX_STATICEDGE        :: 0x00020000;
    WS_EX_APPWINDOW         :: 0x00040000;
    WS_EX_OVERLAPPEDWINDOW  :: (WS_EX_WINDOWEDGE | WS_EX_CLIENTEDGE);
    WS_EX_PALETTEWINDOW     :: (WS_EX_WINDOWEDGE | WS_EX_TOOLWINDOW | WS_EX_TOPMOST);
    WS_EX_LAYERED           :: 0x00080000;
    WS_EX_NOINHERITLAYOUT   :: 0x00100000; // Disable inheritence of mirroring by children
    WS_EX_NOREDIRECTIONBITMAP :: 0x00200000;
    WS_EX_LAYOUTRTL         :: 0x00400000; // Right to left mirroring
    WS_EX_COMPOSITED        :: 0x02000000;
    WS_EX_NOACTIVATE        :: 0x08000000;
}

LWA_ALPHA :: 0x2;

#import "Math";
#import "Basic";
#import "Compiler";
#import "Window_Creation";
#import "File";
#import "System";
Input :: #import "Input";
Simp :: #import "Simp";
GetRect :: #import "GetRect";
