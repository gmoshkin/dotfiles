EXE_NAME :: "window-test";
RELEASE :: false;

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
    window := create_window(xx window_size.x, xx window_size.y, EXE_NAME, xx window_position.x, xx window_position.y,
                            background_color_rgb = .[.1, .1, .1]);
    quit := false;

    Simp.set_render_target(window);

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Game loop
    while !quit {
        // Time
        //
        time_frame_start := seconds_since_init();

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
        mouse_button_left_state := Input.input_button_states[Input.Key_Code.MOUSE_BUTTON_LEFT];
        if mouse_button_left_state {
            something_changed = true;
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

                #if !RELEASE if it.key_pressed && it.key_code == .F4 {
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
            secs_spent_so_far := seconds_since_init() - time_frame_start;
            secs_left := frame_budget_secs - secs_spent_so_far;
            if secs_left > 0 {
                sleep_milliseconds(xx (secs_left * 1000));
            }
            continue;
        }

        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Update/Draw
        Simp.update_window(window);
        Simp.clear_render_target(bg_color.x, bg_color.y, bg_color.z, bg_color.w);


        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Main loop end

        Simp.swap_buffers(window);

        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // End of frame
        reset_temporary_storage();

        frame_budget_secs := 1.0 / 60;
        secs_spent_so_far := seconds_since_init() - time_frame_start;
        secs_left := frame_budget_secs - secs_spent_so_far;
        if secs_left > 0 {
            // log("going to sleep for %", millis_left_to_sleep, flags = .VERY_VERBOSE_ONLY);
            sleep_milliseconds(xx (secs_left * 1000));
        } else {
            // log("we're running late, not gonna sleep tonight", flags = .VERY_VERBOSE_ONLY);
        }
    }
}

bg_color := Vector4.{ .1, .1, .1, 1 };
fullscreen := false;
saved_window_info: Saved_Window_Info;

#import "Math";
#import "Basic";
#import "Compiler";
#import "Window_Creation";
#import "File";
#import "System";
Input :: #import "Input";
Simp :: #import "Simp";
GetRect :: #import "GetRect";
