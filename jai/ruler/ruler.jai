EXE_NAME :: "ruler";
#run {
    set_build_options_dc(.{ output_executable_name = EXE_NAME });
    #if OS == .WINDOWS {
        WR :: #import "Windows_Resources";
        WR.disable_runtime_console();
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

    window_size := Vector2.{ 480, 860 };
    window := create_window(xx window_size.x, xx window_size.y, EXE_NAME);
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

    system_screen_width, system_screen_height: float;
    system_dpi_x, system_dpi_y: float;
    #if OS == .WINDOWS {
        // Requires win8+
        shcore :: #system_library "Shcore";
        GetDpiForMonitor :: (m: Windows.HMONITOR, t: Windows.MONITOR_DPI_TYPE, dpiX: *u32, dpiY: *u32) -> Windows.HRESULT #foreign shcore;

        dpi_x, dpi_y: u32;
        monitor := Windows.MonitorFromWindow(window, Windows.MONITOR_DEFAULTTONEAREST);
        ok := GetDpiForMonitor(monitor, .MDT_RAW_DPI, *dpi_x, *dpi_y);
        assert(ok == 0);

        system_dpi_x = cast(float) dpi_x;
        system_dpi_y = cast(float) dpi_y;

        info: Windows.MONITORINFO;
        info.cbSize = size_of(type_of(info));
        success := Windows.GetMonitorInfoW(monitor, *info);
        if success {
            system_screen_width  = xx (info.rcMonitor.right  - info.rcMonitor.left);
            system_screen_height = xx (info.rcMonitor.bottom - info.rcMonitor.top);
        }
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Game loop
    time_last_frame_start : f64 = 0.0;
    time_frame_start : f64;

    fg_color := Vector4.{ .1, .1, .1, 1 };
    bg_color := Vector4.{ .8, .8, .8, 1 };

    while !quit {
        //
        // Time
        //
        time_last_frame_start = time_frame_start;
        time_frame_start = get_time();
        dt := cast(f32) min(time_frame_start - time_last_frame_start, 1.0/60);

        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Handle input
        Input.update_window_events();

        something_changed := false;

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
        click := false;

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

                if it.key_pressed && it.key_code == .MOUSE_BUTTON_LEFT {
                    click = true;
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


        width_pixels  := ifx system_screen_width  then system_screen_width  else 1960.0;
        height_pixels := ifx system_screen_height then system_screen_height else 1080.0;
        diagonal_pixels := sqrt(pow(width_pixels, 2) + pow(height_pixels, 2));

        diagonal_inches := 17.3;

        px_per_in_x := ifx system_dpi_x then system_dpi_x else diagonal_pixels / diagonal_inches;
        px_per_in_y := ifx system_dpi_y then system_dpi_y else diagonal_pixels / diagonal_inches;

        in_per_px_x := 1 / px_per_in_x;
        in_per_px_y := 1 / px_per_in_y;

        cm_per_in := 2.54;
        cm_per_px_x := cm_per_in / px_per_in_x;
        cm_per_px_y := cm_per_in / px_per_in_y;
        px_per_cm_x := px_per_in_x / cm_per_in;
        px_per_cm_y := px_per_in_y / cm_per_in;

        {
            cm_mark_length := 10.0;
            cm_mark_width := 3.0;
            mm_mark_length := 6.0;
            mm_mark_width := 1.0;

            // Vertical cm ruler
            {
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

        {
            inch_mark_length := 10.0;
            inch_mark_width := 3.0;
            eigth_mark_length := 6.0;
            eigth_mark_width := 2.0;

            // Vertical inch ruler
            {
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
        y_ofs := 28;
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
            width := 200.0;
            height := 40.0;
            button_inner_margin := 4.0;
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
                fg_color, bg_color = bg_color, fg_color;
            }

            y_pos = y0 - y_ofs;
        }

        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Main loop end

        Simp.swap_buffers(window);

        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // End of frame
        reset_temporary_storage();

        frame_budget_secs := 1.0 / 30;
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

#import "Math";
#import "Basic";
#import "Compiler";
#import "Window_Creation";
#import "File";
Input :: #import "Input";
Simp :: #import "Simp";
GetRect :: #import "GetRect";
