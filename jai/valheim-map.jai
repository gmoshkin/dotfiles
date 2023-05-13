main :: () {
    time_start_work:= get_time();

    args := get_command_line_arguments();
    // filename := args[1];
    // data := read_entire_file(filename);
    dir := args[1];
    all_files := file_list(dir);
    assert(all_files.count == TileSideCount * TileSideCount);

    path := parse_path(dir);
    path.words[path.words.count - 1] = "locations.json";
    path.trailing_slash = false;
    locations_full_filename := path_to_string(path);
    locations_json, ok := read_entire_file(locations_full_filename);

    #if OS == .WINDOWS {
        Windows.SetProcessDPIAware();

        // Windows is very bad at thread-switching by default unless you do this. Sad.
        Windows :: #import "Windows";
        Windows.timeBeginPeriod(1);
    }
    window_width_s32 = 1920 / 2;
    window_height_s32 = 1920 / 2;
    window = create_window(window_width_s32, window_height_s32, "A Window");
    window_width_s32, window_height_s32 = Simp.get_render_dimensions(window);
    window_width = xx window_width_s32;
    window_height = xx window_height_s32;
    Simp.set_render_target(window);
    GetRect.ui_init();
    get_rect_theme := GetRect.default_theme_procs[GetRect.Default_Themes.Default]();
    GetRect.set_default_theme(get_rect_theme);

    min_biome := 0xffff;
    max_biome := 0;

    show_biome := true;

    min_height := FLOAT32_INFINITY;
    max_height := -FLOAT32_INFINITY;

    start_height := -10.0;
    end_height := 150.0;
    ocean_height := 28.9;
    void_height := -100.0;

    show_height := true;

    min_forest := FLOAT32_INFINITY;
    max_forest := -FLOAT32_INFINITY;

    start_forest := 0.0;
    end_forest := 0.0;

    show_forest := false;

    // biomes : Table(u16, s64);

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // Ui settings
    bg_color := Vector4.{ .2, .2, .2, .6 };

    slider_theme := get_rect_theme.slider_theme;
    slider_theme.clamp_text_input_high = false;

    checkbox_theme := get_rect_theme.checkbox_theme;

    scrollable_region_theme :                                       = get_rect_theme.scrollable_region_theme;
    scrollable_region_theme.scrollbar_size                          = 0.02;
    scrollable_region_theme.region_background.color                 = bg_color;
    scrollable_region_theme.region_background.frame_color           = .{ .1, .1, .1, .8 };
    scrollable_region_theme.scrollbar_nib_theme.surface_color       = .{.55, .55, .55, 1};
    scrollable_region_theme.scrollbar_nib_theme.surface_color_over  = .{.70, .70, .70, 1};
    scrollable_region_theme.scrollbar_nib_theme.surface_color_flash = .{.90, .90, .90, 1};
    scrollable_region_theme.scrollbar_nib_theme.surface_color_down  = .{.85, .85, .85, 1};
    scrollable_region_theme.scrollbar_nib_theme.frame_color         = .{.65, .65, .65, 1};
    scrollable_region_theme.scrollbar_nib_theme.frame_color_over    = .{.72, .75, .72, 1};
    scrollable_region_theme.scrollbar_nib_theme.frame_color_flash   = .{.99, .99, .99, 1};
    scrollable_region_theme.scrollbar_nib_theme.frame_color_down    = .{.88, .88, .88, 1};
    scrollable_region_theme.scrollbar_background.frame_color        = .{.30, .30, .30, 1.0};
    scrollable_region_theme.scrollbar_background.color              = .{.17, .17, .17, 1.0};

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // Debug [[
    // state = .DEBUG;

    screen_box.xy = .{ window_width / 2, window_height / 2 };
    screen_box.wh = .{ 600, 400 };
    screen_box.thickness = 2;
    screen_box.color = .{ .8, .7, .1, 1. };

    bitmap_box.xy = .{ window_width / 2 - 100, window_height / 2 - 50 };
    bitmap_box.wh = .{ 400, 400 };
    bitmap_box.thickness = 2;
    bitmap_box.color = .{ .1, .9, .4, 1. };

    // ]] Debug

    state : enum {
        LOADING_FILES;
        GENERATING_BITMAP;
        DONE;
        DEBUG;
    } = .LOADING_FILES;

    current_file_index := 0;
    batch_index := 0;

    map_data := NewArray(elements_per_map, TileElement);
    tile_data := NewArray(tile_file_size, u8);

    init_locations(locations_json);

    while !quit {
        time_start := get_time();
        /////////////////////////////////////////////////////////////////////////////////
        // Read input
        Input.update_window_events();

        for Input.get_window_resizes() {
            Simp.update_window(it.window);

            if it.window == window {
                window_width_s32  = it.width;
                window_height_s32 = it.height;
                window_width = xx window_width_s32;
                window_height = xx window_height_s32;
            }
        }

        for Input.events_this_frame {
            if it.type == .QUIT ||
                (it.type == .KEYBOARD && it.key_pressed && it.key_code == .ESCAPE)
            {
                quit = true;
            }

            GetRect.getrect_handle_event(it);

            if it.type == {
                case .KEYBOARD;
                if it.key_pressed && it.key_code == .F4 {
                    debug_break();
                }
            }
        }

        GetRect.ui_per_frame_update(window, window_width_s32, window_height_s32, time_start);
        Simp.update_window(window);
        Simp.clear_render_target(0.1, 0.1, 0.1, 1);

        w := 300.0;
        lrect := GetRect.get_rect(5, window_height - 25, w, 20);
        h := 40.0;
        w = 400;
        mrect := GetRect.get_rect((window_width - w) / 2, (window_height - h) / 2, w, h);
        w, h = 300, 30.0;
        rrect := GetRect.get_rect(window_width - w - 5, window_height - h - 5, w, h);


        status_message : string;
        /////////////////////////////////////////////////////////////////////////////////
        // Main work
        if state == {

            /////////////////////////////////////////////////////////////////////////////
            case .LOADING_FILES;
                // TODO: load data in a separate thread
                full_path_to_file := all_files[current_file_index];
                path := parse_path(full_path_to_file);
                filename := path.words[path.words.count - 1];

                f, success := file_open(full_path_to_file, log_errors = true);
                assert(success);
                defer file_close(*f);

                ok, bytes_read := file_read(f, tile_data.data, tile_file_size);
                if !ok {
                    error_code, error_string := get_error_value_and_string();
                    log_error("Could not read file \"%\": code %, %", full_path_to_file, error_code, error_string);
                    exit(1);
                }
                assert(bytes_read == tile_file_size);

                tile_row := filename.data[1] - #char "0";
                tile_col := filename.data[4] - #char "0";

        //     0 1  2 3  4 5  6 7
        //   +----+----+----+----+  TileSideCount := 4
        // 0 | . .| . .| . .| . .|  TileRowCount := 2
        // 1 | . .| . .| . .| . .|  elements_per_tile := 2 * 2 = 4
        //   +----+----+----+----+  tiles_per_map := 4 * 4 = 16
        // 2 | . .| . .| . .| . .|  tile_index := 6
        // 3 | . .| . .| * .| . .|  tile_row := 6 / 4 = 1
        //   +----+----+----+----+  tile_col := 6 % 4 = 2
        // 4 | . .| . .| . .| . .|  row := 1
        // 5 | . .| . .| . .| . .|  col := 0
        //   +----+----+----+----+  tile_bitmap_index := 1 * 2 + 0 = 2
        // 6 | . .| . .| . .| . .|  bitmap_index := 1 * (2 * 2 * 4) + 2 * (2) + 1 * (2 * 4) + 0
        // 7 | . .| . .| . .| . .|
        //   +----+----+----+----+

                // for 0..39 {
                for 0..elements_per_tile-1 {
                    row_in_tile := it / TileRowCount;
                    col_in_tile := it % TileRowCount;
                    map_index := (
                        tile_row * elements_per_tile * TileSideCount
                        + tile_col * TileRowCount
                        + row_in_tile * TileRowCount * TileSideCount
                        + col_in_tile
                    );
                    biome  := << cast(*u16) (tile_data.data + it * 10);
                    height := << cast(*float32) (tile_data.data + it * 10 + 2);
                    forest := << cast(*float32) (tile_data.data + it * 10 + 6);

                    // biome_count := table_find_pointer(*biomes, biome);
                    // if !biome_count {
                    //     table_add(*biomes, biome, 1);
                    // } else {
                    //     <<biome_count += 1;
                    // }

                    if biome > max_biome  max_biome = biome;
                    if biome < min_biome  min_biome = biome;

                    if height > max_height  max_height = height;
                    if height < min_height  min_height = height;

                    if forest > max_forest  max_forest = forest;
                    if forest < min_forest  min_forest = forest;

                    map_data[map_index].biome = xx biome;
                    map_data[map_index].height = height;
                    map_data[map_index].forest = forest;
                }

                current_file_index += 1;
                // This messages lags behind by one frame, but who gives a shit?
                status_message = tprint("reading file #%: %", current_file_index, filename);

                if current_file_index == all_files.count {
                    log("biome %..%", min_biome, max_biome);
                    log("height %..%", min_height, max_height);
                    log("forest %..%", min_forest, max_forest);

                    start_forest = 1.15;
                    end_forest = 1.75;

                    // log("biomes:"); for biomes log("  %: %", it_index, it);

                    state = .GENERATING_BITMAP;
                    batch_index = 0;

                    bitmap_data = NewArray(bitmap_size * bitmap_size, RGBA, initialized = false);
                    bitmap = Bitmap.{
                        data = xx bitmap_data,
                        width = bitmap_size,
                        height = bitmap_size,
                        format = .RGBA8,
                    };

                    // Spawn threads.
                    num_threads := get_number_of_processors() - 1;
                    log("spawning % threads", num_threads);

                }

            /////////////////////////////////////////////////////////////////////////////
            case .GENERATING_BITMAP;
                // TODO: generate data in a bunch of threads.
                // You'll have to do a compare exchange of state though to avoid
                // races, or something. Don't think there are any other possible
                // races if the data is parallelized correctly. So seems pretty
                // straightforward to implement. And should be super fun!
                //
                // Here's the plan:
                // Spawn a bunch of threads, give each one a range of the
                // bitmap. Each thread checks if the bitmap_version has changed.
                // If it did, it starts work from beginning. Maybe checks if
                // version changed every N iterations or so (sounds like an
                // optimization). Once it's done generating, it goes to sleep
                // for a bit and periodically checks if bitmap_version has
                // changed. Super simple.
                batch_size := elements_per_tile / 2;
                n_batches := elements_per_map / batch_size;

                if quit exit(0);

                for 0..batch_size-1 {
                    index := batch_index * batch_size + it;
                    using map_data[index];
                    pixel := *bitmap_data[index];

                    <<pixel = #run RGBA_from_hex("#ffffff");

                    if show_biome then <<pixel = biome_RGBA(biome);

                    if show_height {
                        h := clamp(height, start_height, end_height);
                        h = (h - start_height) / (end_height - start_height);
                        // h := (height - min_height) * (max_height - min_height) * 0xff;
                        pixel.r = xx (pixel.r * h);
                        pixel.g = xx (pixel.g * h);
                        pixel.b = xx (pixel.b * h);
                        if height < ocean_height {
                            pixel.b = 0xee;
                        }
                        if height < void_height {
                            << pixel = .{ /* black */ a = 0x00 };
                        }
                    }

                    if show_forest {
                        f := clamp(forest, start_forest, end_forest);
                        f = (f - start_forest) / (end_forest - start_forest);
                        pixel.r = xx (pixel.r * f);
                        pixel.b = xx (pixel.b * f);
                    }

                    // h := cast(float) (biome - min_biome) * (max_biome - min_biome) * 360;
                    // // v := (height - min_height) * (max_height - min_height);
                    // // s := (forest - min_forest) * (max_forest - min_forest);
                    // r, g, b := hsv_to_rgb(h, s, v);
                    // bitmap_data[index] = .{
                    //     r = xx (r * 255),
                    //     g = xx (g * 255),
                    //     b = xx (b * 255),
                    // };

                    // if height < 32
                    //     bitmap_data[index] = .{ g = 0xff };
                    // else
                    //     bitmap_data[index] = .{ b = 0xff };
                }

                batch_index += 1;
                if batch_index == n_batches {
                    state = .DONE;
                }

                Simp.texture_load_from_bitmap(*texture, *bitmap);

                status_message = tprint("generating bitmap, done %1%%", 100 * batch_index / n_batches);

            ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            case .DONE;
                status_message = "done";

            ////////////////////////////////////////////////////////////////////////////////////////////////////////////
            case .DEBUG;
                // immediate_line(line_start, line_end, 2, .{ .8, .2, .1, 1 });

                // {
                //     GetRect.slider(lrect, *line_start.x, 0, xx window_width, prefix = "start x", spinbox_step = .5, theme = *slider_theme);
                //     lrect.y -= 22;
                //     GetRect.slider(lrect, *line_start.y, 0, xx window_height, prefix = "start y", spinbox_step = .5, theme = *slider_theme);
                //     lrect.y -= 22;
                //     GetRect.slider(lrect, *line_end.x, 0, xx window_width, prefix = "end x", spinbox_step = .5, theme = *slider_theme);
                //     lrect.y -= 22;
                //     GetRect.slider(lrect, *line_end.y, 0, xx window_height, prefix = "end y", spinbox_step = .5, theme = *slider_theme);
                //     lrect.y -= 22;
                // }

                {
                    GetRect.slider(lrect, *screen_box.w, 0, xx window_width, prefix = "screen w", spinbox_step = 10, theme = *slider_theme);
                    lrect.y -= 22;
                    GetRect.slider(lrect, *screen_box.h, 0, xx window_height, prefix = "screen h", spinbox_step = 10, theme = *slider_theme);
                    lrect.y -= 22;
                }

                immediate_box(screen_box);
                bitmap_box.w = min(screen_box.w, screen_box.h);
                bitmap_box.h = bitmap_box.w;
                immediate_grid(bitmap_box);

                unscaled_ofs := bitmap_box.xy - screen_box.xy;

                image_scale_log_2 += 0.3 * Input.mouse_delta_z / 120;
                bitmap_box_scale := pow(2, image_scale_log_2);

                scaled_bitmap_box := bitmap_box;
                scaled_bitmap_box.wh *= bitmap_box_scale;
                scaled_bitmap_box.xy = screen_box.xy + unscaled_ofs * bitmap_box_scale;
                scaled_bitmap_box.color = .{ .3, .6, .9, 1 };
                immediate_grid(scaled_bitmap_box);

                immediate_line(screen_box.xy, bitmap_box.xy, 2, .{ .8, .2, .1, 1 });

                if GetRect.ui_get_button_state(.MOUSE_BUTTON_LEFT) == .DOWN {
                    bitmap_box.x += Input.mouse_delta_x / bitmap_box_scale;
                    bitmap_box.y -= Input.mouse_delta_y / bitmap_box_scale;
                }
        }

        /////////////////////////////////////////////////////////////////////////////////
        // Draw bitmap
        if bitmap.width {
            image_scale_log_2 += 0.1 * Input.mouse_delta_z / 120;
            image_scale = pow(2, image_scale_log_2);
            if GetRect.ui_get_button_state(.MOUSE_BUTTON_LEFT) == .DOWN {
                // So as the debug boxes show we need to have an original
                // unscaled offset, multiply it by scale and add the mouse
                // delta. That way zooming will keep the point at mid screen
                // in place. But because in this case I just unscale the mouse
                // delta, add to unscaled offset and than scale it back up, so
                // the result is X_scaled = X_0 * scale + mouse_delta.
                //
                // Also Input.mouse_delta is a tiny bit off, and I really should
                // compute it myself. That's a TODO I guess
                image_ofs_unscaled.x += Input.mouse_delta_x / image_scale;
                image_ofs_unscaled.y -= Input.mouse_delta_y / image_scale;
            }
            image_ofs_screen_space = image_ofs_unscaled * image_scale;

            Simp.set_shader_for_images(*texture);
            Simp.immediate_begin();
            window_size := min(window_height, window_width);
            w := image_scale * window_size;
            o := Vector2.{ xx (window_width / 2), xx (window_height / 2) };
            o += image_ofs_screen_space;
            Simp.immediate_quad(
                o + .{ +w/2, -w/2 },
                o + .{ +w/2, +w/2 },
                o + .{ -w/2, +w/2 },
                o + .{ -w/2, -w/2 },
            );
            Simp.immediate_flush();
        }

        /////////////////////////////////////////////////////////////////////////////////
        // Draw locations

        // TODO: load the locations from the json file and have a filter on
        // location kinds to not show everything all at once.
        // Also will have to figure out colors somehow, maybe random ones?
        // Also feels like looking up locations from a hashmap is going to be
        // slower, but maybe not too slow?
        // Update: it's not slow, but takes up a bunch of CPU (about 7%)
        if state != .LOADING_FILES {
            for l: locations {
                if !l.show continue;
                for l.locs draw_location(it, l.color);
            }
        }

        /////////////////////////////////////////////////////////////////////////////////
        // Draw ui

        // uptime + status
        if state != .DONE && state != .DEBUG {
            text := tprint("uptime: %", formatFloat(get_time() - time_start_work, trailing_width=2));
            GetRect.label(mrect, text, *get_rect_theme.label_theme);
            mrect.y -= 20;

            theme := get_rect_theme.label_theme;
            GetRect.label(mrect, status_message, *theme);
        }

        {
            GetRect.slider(lrect, *image_scale_log_2, -8.0, 16, prefix = "zoom", spinbox_step = .5, theme = *slider_theme);
            lrect.y -= 22;
            // GetRect.slider(lrect, *image_ofs_screen_space.x, xx -window_width, xx window_width, prefix = "ofs x", spinbox_step = .5, theme = *slider_theme);
            // lrect.y -= 22;
            // GetRect.slider(lrect, *image_ofs_screen_space.y, xx -window_height, xx window_height, prefix = "ofs y", spinbox_step = .5, theme = *slider_theme);
            // lrect.y -= 22;
        }

        if state != .DEBUG
        {
            changed := false;

            ////////////////////////////////////////////////////////////////////////////////////////////////////
            // Left side
            {
                cb_rect := lrect;
                cb_rect.w = 70;
                lrect.y -= 22;
                {
                    pressed := GetRect.base_checkbox(cb_rect, "biome", show_biome, theme = *checkbox_theme, 0);
                    show_biome ^= pressed;
                    changed |= pressed;
                    cb_rect.x += cb_rect.w;
                }

                {
                    pressed := GetRect.base_checkbox(cb_rect, "height", show_height, theme = *checkbox_theme, 0);
                    show_height ^= pressed;
                    changed |= pressed;
                    cb_rect.x += cb_rect.w;
                }

                {
                    pressed := GetRect.base_checkbox(cb_rect, "forest", show_forest, theme = *checkbox_theme, 0);
                    show_forest ^= pressed;
                    changed |= pressed;
                }
            }

            if show_height {
                changed |= GetRect.slider(lrect, *start_height, min_height, end_height, prefix = "start height", spinbox_step = 2.5, theme = *slider_theme);
                lrect.y -= 22;
                changed |= GetRect.slider(lrect, *end_height, start_height, max_height, prefix = "end height", spinbox_step = 2.5, theme = *slider_theme);
                lrect.y -= 22;
                changed |= GetRect.slider(lrect, *ocean_height, min_height, max_height, prefix = "ocean height", spinbox_step = 2.5, theme = *slider_theme);
                lrect.y -= 22;
                changed |= GetRect.slider(lrect, *void_height, min_height, max_height, prefix = "void height", spinbox_step = 2.5, theme = *slider_theme);
                lrect.y -= 22;
            }

            if show_forest {
                changed |= GetRect.slider(lrect, *start_forest, 1.0, end_forest, prefix = "start forest", spinbox_step = 0.025, theme = *slider_theme);
                lrect.y -= 22;
                changed |= GetRect.slider(lrect, *end_forest, start_forest, 2.0, prefix = "end forest", spinbox_step = 0.025, theme = *slider_theme);
                lrect.y -= 22;
            }

            {
                pressed := GetRect.base_checkbox(lrect, "color picker", show_color_picker, theme = *checkbox_theme, 0);
                show_color_picker ^= pressed;
                lrect.y -= 22;
            }

            if show_color_picker {
                cp_rect := lrect;
                cp_rect.h = cp_rect.w * 1.2;
                cp_rect.y -= cp_rect.h - 22;
                theme := *get_rect_theme.color_picker_theme;
                GetRect.color_picker(cp_rect, *color_picker_color, theme);
                lrect.y -= cp_rect.h;
            }

            if changed && state != .LOADING_FILES {
                // TODO: this doesn't work
                if state == .DONE time_start_work = 0;

                state = .GENERATING_BITMAP;
                batch_index = 0;
            }

            {
                rect_out := lrect;
                rect_out.h = lrect.h * 10;
                rect_out.y -= rect_out.h - lrect.h;
                region, rect_in := GetRect.begin_scrollable_region(rect_out, *scrollable_region_theme);

                trect := rect_in;
                trect.y += rect_in.h - lrect.h + locations_toggles_scroll;
                trect.h = lrect.h;

                for * l: locations {
                    theme := checkbox_theme;
                    theme.button_color_selected = l.color;
                    pressed := GetRect.base_checkbox(trect, l.name, l.show, theme = *theme, identifier = xx l);
                    // TODO: here I would remove the locations from the array
                    // which actually get's iterated to draw the locations.
                    // This would be an optimization.
                    l.show ^= pressed;
                    trect.y -= trect.h;
                }

                GetRect.end_scrollable_region(region, rect_out.x + rect_out.w, trect.y + trect.h, *locations_toggles_scroll);
            }

            ////////////////////////////////////////////////////////////////////////////////////////////////////
            // Right side
            {
                screen_space_mouse : Vector2;
                x, y, ok := get_mouse_pointer_position(window, true);
                if ok {
                    screen_space_mouse.x = xx x;
                    screen_space_mouse.y = xx y;
                }

                bitmap_space_mouse := screen_space_mouse;
                bitmap_space_mouse -= image_ofs_screen_space;
                bitmap_space_mouse -= Vector2.{ xx (window_width / 2), xx (window_height / 2) };
                bitmap_space_mouse *= WorldWidth;

                window_size := min(window_height, window_width);
                w := image_scale * window_size;
                bitmap_space_mouse /= w;

                bx := bitmap_space_mouse.x;
                by := bitmap_space_mouse.y;

                // immediate_rect(rrect, bg_color);
                // GetRect.label(rrect, tprint("unscaled ofs x: %", formatFloat(image_ofs_unscaled.x, trailing_width=1)), *get_rect_theme.label_theme);
                // rrect.y -= 30;
                // immediate_rect(rrect, bg_color);
                // GetRect.label(rrect, tprint("unscaled ofs y: %", formatFloat(image_ofs_unscaled.y, trailing_width=1)), *get_rect_theme.label_theme);
                // rrect.y -= 30;

                immediate_rect(rrect, bg_color);
                GetRect.label(rrect, tprint("bx: %", formatFloat(bx, trailing_width=1)), *get_rect_theme.label_theme);
                rrect.y -= 30;
                immediate_rect(rrect, bg_color);
                GetRect.label(rrect, tprint("by: %", formatFloat(by, trailing_width=1)), *get_rect_theme.label_theme);
                rrect.y -= 30;

                row := cast(s32) ((bx + WorldWidth / 2) / WorldWidth * elements_per_map_side);
                col := cast(s32) ((by + WorldWidth / 2) / WorldWidth * elements_per_map_side);

                immediate_rect(rrect, bg_color);
                GetRect.label(rrect, tprint("col: %", col), *get_rect_theme.label_theme);
                rrect.y -= 30;
                immediate_rect(rrect, bg_color);
                GetRect.label(rrect, tprint("row: %", row), *get_rect_theme.label_theme);
                rrect.y -= 30;

                if col >= 0 && col < elements_per_map_side && row >= 0 && row < elements_per_map_side {
                    index := row * elements_per_map_side + col;
                    info := map_data[index];
                    immediate_rect(rrect, bg_color);
                    biome_theme := get_rect_theme.label_theme;
                    biome_theme.text_color = biome_rgb(info.biome);
                    GetRect.label(rrect, tprint("biome : %", biome_name(info.biome)), *biome_theme);
                    rrect.y -= 30;

                    if show_color_picker {
                        immediate_rect(rrect, bg_color);
                        GetRect.label(rrect, rgb_to_hex(biome_theme.text_color), *biome_theme);
                        rrect.y -= 30;
                    }

                    immediate_rect(rrect, bg_color);
                    GetRect.label(rrect, tprint("height : %", formatFloat(info.height, trailing_width=1)), *get_rect_theme.label_theme);
                    rrect.y -= 30;

                    immediate_rect(rrect, bg_color);
                    GetRect.label(rrect, tprint("forest : %", formatFloat(info.forest, trailing_width=1)), *get_rect_theme.label_theme);
                    rrect.y -= 30;
                }
                // GetRect.label(rrect, tprint("temple y: %", StartTemple.z), *get_rect_theme.label_theme);
                // rrect.y -= 30;

            }
        }

        Simp.swap_buffers(window);


        time_end := get_time();
        millis_spent_on_frame := 1000 * (time_end - time_start);
        millis_expected_to_spend := 1000 / 60;
        millis_left_to_sleep := millis_expected_to_spend - millis_spent_on_frame;
        if millis_left_to_sleep > 0 {
            // log("going to sleep for %", millis_left_to_sleep, flags = .VERY_VERBOSE_ONLY);
            sleep_milliseconds(xx millis_left_to_sleep);
        } else {
            // log("we're running late, not gonna sleep tonight", flags = .VERY_VERBOSE_ONLY);
        }
        reset_temporary_storage();
    }

    if quit exit(0);

    // image_filename := "foo.png\0";
    // image_filename.count -= 1;
    // ok := stbi_write_png(image_filename.data, bitmap_size, bitmap_size, 4, bitmap_data.data, 4 * bitmap_size);
    // if !ok {
    //     error_code, error_string := get_error_value_and_string();
    //     log_error("Could not save image file \"%\": code %, %", image_filename, error_code, error_string);
    //     exit(1);
    // }
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// Consts [[

TileRowCount : s32 : 1024;
TileSize :: 3000.0;
TileSideCount :: 8;
WorldWidth :: 24000.0;
elements_per_tile :: TileRowCount * TileRowCount;
tiles_per_map :: TileSideCount * TileSideCount;
elements_per_map :: tiles_per_map * elements_per_tile;
elements_per_map_side :: TileRowCount * TileSideCount;
#assert(elements_per_map == elements_per_map_side * elements_per_map_side);

tile_element_size_in_bytes :: 10;
tile_file_size :: elements_per_tile * tile_element_size_in_bytes;
bitmap_size :: TileRowCount * TileSideCount;

// ]] Consts

TileElement :: struct {
    biome: Biome;
    height: float32;
    forest: float32;
}


////////////////////////////////////////////////////////////////////////////////////////////////////
// Drawing subroutines [[

immediate_rect :: (rect: GetRect.Rect, color: Vector4) {
    Simp.set_shader_for_color(enable_blend = true);
    Simp.immediate_quad(
        .{ rect.x         , rect.y },
        .{ rect.x + rect.w, rect.y },
        .{ rect.x + rect.w, rect.y + rect.h },
        .{ rect.x         , rect.y + rect.h },
        color,
        color,
        color,
        color,
    );

}

immediate_line :: (from: Vector2, to: Vector2, thickness: float32, color: Vector4) {
    Simp.set_shader_for_color();

    len := distance(from, to);

    dir := to - from;
    rot := atan2(dir.y, dir.x);
    rot_m : Matrix2;
    rot_m.v[0] = .{  sin(rot), cos(rot) };
    rot_m.v[1] = .{ -cos(rot), sin(rot) };

    mid := (to + from) / 2;
    top_l := mid + multiply(rot_m, .{ -thickness / 2, -len / 2 });
    bot_l := mid + multiply(rot_m, .{ -thickness / 2, +len / 2 });
    top_r := mid + multiply(rot_m, .{ +thickness / 2, -len / 2 });
    bot_r := mid + multiply(rot_m, .{ +thickness / 2, +len / 2 });

    Simp.immediate_quad(
        top_l, bot_l, bot_r, top_r, color, color, color, color,
    );
}

immediate_box :: (box: Box_Info) {
    mid := box.xy;
    immediate_line(mid + .{ -box.w / 2,  box.h / 2 }, mid + .{  box.w / 2,  box.h / 2 }, box.thickness, box.color);
    immediate_line(mid + .{  box.w / 2,  box.h / 2 }, mid + .{  box.w / 2, -box.h / 2 }, box.thickness, box.color);
    immediate_line(mid + .{  box.w / 2, -box.h / 2 }, mid + .{ -box.w / 2, -box.h / 2 }, box.thickness, box.color);
    immediate_line(mid + .{ -box.w / 2, -box.h / 2 }, mid + .{ -box.w / 2,  box.h / 2 }, box.thickness, box.color);
}

immediate_grid :: (box: Box_Info) {
    mid := box.xy;
    immediate_line(mid + .{ -box.w / 2,  box.h / 2 }, mid + .{  box.w / 2,  box.h / 2 }, box.thickness, box.color);
    immediate_line(mid + .{  box.w / 2,  box.h / 2 }, mid + .{  box.w / 2, -box.h / 2 }, box.thickness, box.color);
    immediate_line(mid + .{  box.w / 2, -box.h / 2 }, mid + .{ -box.w / 2, -box.h / 2 }, box.thickness, box.color);
    immediate_line(mid + .{ -box.w / 2, -box.h / 2 }, mid + .{ -box.w / 2,  box.h / 2 }, box.thickness, box.color);

    immediate_line(mid + .{ -box.w / 4,  box.h / 2 }, mid + .{ -box.w / 4, -box.h / 2 }, box.thickness, box.color);
    immediate_line(mid + .{          0,  box.h / 2 }, mid + .{          0, -box.h / 2 }, box.thickness, box.color);
    immediate_line(mid + .{  box.w / 4,  box.h / 2 }, mid + .{  box.w / 4, -box.h / 2 }, box.thickness, box.color);

    immediate_line(mid + .{ -box.w / 2, -box.h / 4 }, mid + .{  box.w / 2, -box.h / 4 }, box.thickness, box.color);
    immediate_line(mid + .{ -box.w / 2,          0 }, mid + .{  box.w / 2,          0 }, box.thickness, box.color);
    immediate_line(mid + .{ -box.w / 2,  box.h / 4 }, mid + .{  box.w / 2,  box.h / 4 }, box.thickness, box.color);
}

// ]] Drawing subroutines

////////////////////////////////////////////////////////////////////////////////////////////////////
// Biome [[

Biome :: enum u16 {
    Meadow    :: 1;
    Swamp     :: 2;
    Mountain  :: 4;
    Black_Forest :: 8;
    Plains    :: 16;
    Far_South :: 32;
    Far_North :: 64;
    WTF       :: 128;
    Ocean     :: 256;
    Mistlands :: 512;
}

biome_name :: (biome_index: Biome) -> string {
    if biome_index == {
        case .Meadow       ; return "meadow"       ;
        case .Swamp        ; return "swamp"        ;
        case .Mountain     ; return "mountain"     ;
        case .Black_Forest ; return "black forest" ;
        case .Plains       ; return "plains"       ;
        case .Far_South    ; return "far south"    ;
        case .Far_North    ; return "far north"    ;
        case .WTF          ; return "huh?"         ;
        case .Ocean        ; return "ocean"        ;
        case .Mistlands    ; return "mistlands"    ;

        case; return "unknown";
    }
}

biome_RGBA :: inline (biome: Biome) -> RGBA {
    if biome == {
        case .Meadow       ; return #run RGBA_from_hex("#40ff40") ;
        case .Swamp        ; return #run RGBA_from_hex("#607020") ;
        case .Mountain     ; return #run RGBA_from_hex("#ffffff") ;
        case .Black_Forest ; return #run RGBA_from_hex("#0a5000") ;
        case .Plains       ; return #run RGBA_from_hex("#aaaa44") ;
        case .Far_South    ; return #run RGBA_from_hex("#881111") ;
        case .Far_North    ; return #run RGBA_from_hex("#3377cc") ;
        case .WTF          ; return #run RGBA_from_hex("#ff00ff") ;
        case .Ocean        ; return #run RGBA_from_hex("#8aeed5") ;
        case .Mistlands    ; return #run RGBA_from_hex("#662266") ;
        case               ; return #run RGBA_from_hex("#ffff00") ;
    }
}

biome_rgb :: inline (biome: Biome) -> Vector4 {
    return RGBA_to_vec4(biome_RGBA(biome));
}

// ]] Biome

window : Window_Type;
window_width_s32 : s32;
window_height_s32 : s32;
window_width : float;
window_height : float;
texture : Simp.Texture;
bitmap_data : [] RGBA;
bitmap : Simp.Bitmap;
quit := false;

image_ofs_screen_space : Vector2;
image_ofs_unscaled : Vector2;
image_scale_log_2 : float = 0.0;
image_scale : float = 0.0;

////////////////////////////////////////////////////////////////////////////////////////////////////
// Color [[

color_picker_color := Vector3.{ 1, 1, 1 };
show_color_picker := false;

hsv_to_rgb :: (cx: float, cy: float, cz: float) -> (r: float, g: float, b: float) {
    cx /= 360.0;
    p: Vector3;
    p.x = abs(fract(cx + 1)     * 6 - 3) - 1;
    p.y = abs(fract(cx + 2/3.0) * 6 - 3) - 1;
    p.z = abs(fract(cx + 1/3.0) * 6 - 3) - 1;

    Clamp(*p.x, 0, 1);
    Clamp(*p.y, 0, 1);
    Clamp(*p.z, 0, 1);

    p.x = lerp(1, p.x, cy);
    p.y = lerp(1, p.y, cy);
    p.z = lerp(1, p.z, cy);

    return cz * p.x, cz * p.y, cz * p.z;
}

fract :: inline (x: float) -> float { return x - floor(x); }

RGBA :: struct { r, g, b : u8; a : u8 = 0xff; };

RGBA_to_vec4 :: inline (rgba: RGBA) -> Vector4 {
    return .{
        x = cast(float) rgba.r / 0xff,
        y = cast(float) rgba.g / 0xff,
        z = cast(float) rgba.b / 0xff,
        w = cast(float) rgba.a / 0xff,
    };
}

RGBA_from_vec4 :: inline (rgba: Vector4) -> RGBA {
    return .{
        r = xx (rgba.x * 0xff),
        g = xx (rgba.y * 0xff),
        b = xx (rgba.z * 0xff),
        a = xx (rgba.w * 0xff),
    };
}

rgb_from_hex :: inline (_hex: string) -> Vector4 { return RGBA_to_vec4(RGBA_from_hex(_hex)); }

rgb_to_hex :: inline (v: Vector3) -> string { return RGBA_to_hex(RGBA_from_vec4(.{ xyz = v })); }
rgb_to_hex :: inline (v: Vector4) -> string { return RGBA_to_hex(RGBA_from_vec4(v)); }

RGBA_from_hex :: inline (_hex: string) -> RGBA {
    hex := _hex;
    if hex.data[0] == #char "#"  {
        hex.data += 1;
        hex.count -= 1;
    }

    if hex.count < 6 return .{};

    res : RGBA;

    hex.count = 2; res.r = string_to_int(hex, base=16, u8);
    hex.data += 2; res.g = string_to_int(hex, base=16, u8);
    hex.data += 2; res.b = string_to_int(hex, base=16, u8);

    if hex.count < 8 return res;

    hex.data += 2; res.a = string_to_int(hex, base=16, u8);

    return res;
}

RGBA_to_hex :: inline (rgba: RGBA) -> string {
    return tprint("#%1%2%3",
        formatInt(rgba.r, base=16, minimum_digits=2),
        formatInt(rgba.g, base=16, minimum_digits=2),
        formatInt(rgba.b, base=16, minimum_digits=2),
    );
}

// ]] Color

////////////////////////////////////////////////////////////////////////////////////////////////////
// Debug [[
line_start := Vector2.{ 10, 10 };
line_end := Vector2.{ 300, 300 };

Box_Info :: struct {
    // Mid point
    x, y: float;
    w, h: float;

    #place x;
    xy: Vector2;

    #place w;
    wh: Vector2;

    thickness: float;
    color: Vector4;
};
screen_box : Box_Info;
bitmap_box : Box_Info;
bitmap_box_scale_log_2 : float = 0;
// ]] Debug

////////////////////////////////////////////////////////////////////////////////////////////////////
// Locations

draw_location :: inline (loc: Vector3, color: Vector4) {
    window_size := min(window_height, window_width);
    w := image_scale * window_size;

    x := loc.x / WorldWidth * w;
    z := loc.z / WorldWidth * w;
    o := Vector2.{ xx (window_width / 2), xx (window_height / 2) };
    o += image_ofs_screen_space;
    o += .{ x, z };

    Simp.set_shader_for_color();
    // TODO: compute the equalatoral triangle with a given radius
    Simp.immediate_triangle(
        .{ xy = o + .{ -11, -6 } },
        .{ xy = o + .{ +11, -6 } },
        .{ xy = o + .{  0, +9.0 } },
        .{ 0x00, 0x00, 0x00, 0xff },
        .{ 0x00, 0x00, 0x00, 0xff },
        .{ 0x00, 0x00, 0x00, 0xff },
    );
    Simp.immediate_triangle(
        .{ xy = o + .{ -8, -4 } },
        .{ xy = o + .{ +8, -4 } },
        .{ xy = o + .{  0, +6 } },
        color,
        color,
        color,
    );
}

locations : [..] Locations_Info;
Locations_Info :: struct {
    name: string;
    show: bool;
    color: Vector4;
    locs: [..] Vector3;
};

locations_toggles_scroll : float;

init_locations :: (_json: string) {
    json := _json;
    Location_Json :: struct {
        PrefabName: string;
        Position: string;
    };

    auto_release_temp();

    allocator_save := context.allocator;
    context.allocator = temporary_allocator;
    ok, parsed_locations := json_parse_string(json, [..] Location_Json);
    context.allocator = allocator_save;

    if !ok {
        log("couldn't read locations.json, falling back to statics");

        l : Locations_Info;

        l = .{ name = "spawn", show = true, color = #run rgb_from_hex("#ff00ff") };
        array_add(*l.locs, .{ -64.3, 46.8, -1.9 });
        array_add(*locations, l);

        l = .{ name = "infested mine 1", show = true, color = #run rgb_from_hex("#ffff00") };
        for DvergrTownEntrances1 array_add(*l.locs, it);
        array_add(*locations, l);

        l = .{ name = "infested mine 2", show = true, color = #run rgb_from_hex("#ffffff") };
        for DvergrTownEntrances2 array_add(*l.locs, it);
        array_add(*locations, l);

        l = .{ name = "meteorite", show = true, color = #run rgb_from_hex("#f06f05") };
        for Meteorites array_add(*l.locs, it);
        array_add(*locations, l);

        return;
    }

    default_colors :: Vector4.[
        #run rgb_from_hex("#ff0000"),
        #run rgb_from_hex("#00ff00"),
        #run rgb_from_hex("#1746d4"),
        #run rgb_from_hex("#ffff00"),
        #run rgb_from_hex("#00ffff"),
        #run rgb_from_hex("#ff00ff"),
        #run rgb_from_hex("#ed6205"),
        #run rgb_from_hex("#8c05ed"),
        #run rgb_from_hex("#8b868f"),
        #run rgb_from_hex("#381908"),
    ];

    color_idx := 0;

    for pl, i: parsed_locations {
        found := false;
        for * l : locations {
            if l.name != pl.PrefabName continue;
            else found = true;
            pos := parse_position(pl.Position);
            array_add(*l.locs, pos);
        }
        if !found {
            l : Locations_Info;
            l.name = copy_string(pl.PrefabName);
            l.show = false;
            l.color = default_colors[color_idx];
            color_idx = (color_idx + 1) % default_colors.count;
            array_add(*locations, l);
        }
    }

    quick_sort(locations, (l, r) => compare(l.name, r.name));
}

parse_position :: (_s: string) -> Vector3 {
    s := _s;
    assert(s.data[0] == #char "(");
    s.data += 1; s.count -= 1;

    res : Vector3;

    ok: bool;

    res.x, ok, s = string_to_float(s);
    assert(ok);
    assert(s.data[0] == #char ",");
    s.data += 1; s.count -= 1;

    res.y, ok, s = string_to_float(s);
    assert(ok);
    assert(s.data[0] == #char ",");
    s.data += 1; s.count -= 1;

    res.z, ok, s = string_to_float(s);
    assert(ok);
    assert(s.data[0] == #char ")");

    return res;
}

Meteorites :: Vector3.[
    .{ 2701.8  , 72.7  , -8844.5 } ,
    .{ 639.0   , 58.6  , -8885.5 } ,
    .{ 5386.2  , 37.8  , -7543.5 } ,
    .{ -1747.9 , 37.0  , -8443.6 } ,
    .{ -7607.7 , 55.5  , -5877.1 } ,
    .{ -2867.3 , 34.2  , -8209.8 } ,
    .{ -9.5    , 35.6  , -9703.7 } ,
    .{ -2179.2 , 37.4  , -7783.9 } ,
    .{ 195.8   , 46.6  , -9417.6 } ,
    .{ -8039.7 , 33.5  , -5545.9 } ,
    .{ -2390.1 , 31.4  , -8742.5 } ,
    .{ 2354.3  , 57.2  , -8921.2 } ,
    .{ 7163.1  , 64.3  , -6739.5 } ,
    .{ 2164.4  , 111.0 , -8016.9 } ,
    .{ 7654.1  , 92.2  , -6264.7 } ,
    .{ 2060.3  , 89.4  , -8821.0 } ,
    .{ 6535.7  , 38.5  , -7253.7 } ,
    .{ -2106.1 , 100.6 , -8915.4 } ,
    .{ -4404.5 , 32.4  , -7896.1 } ,
    .{ -2250.6 , 32.5  , -7893.4 } ,
    .{ -5527.2 , 31.3  , -7400.8 } ,
    .{ 5588.0  , 109.6 , -8045.0 } ,
    .{ -5333.3 , 33.8  , -7497.2 } ,
    .{ -6072.9 , 110.1 , -7847.4 } ,
    .{ 2840.7  , 42.3  , -8279.4 } ,
    .{ 5637.3  , 31.5  , -7083.3 } ,
    .{ -383.4  , 33.1  , -8081.1 } ,
    .{ -174.2  , 39.7  , -8330.8 } ,
    .{ 6654.2  , 45.9  , -7114.8 } ,
    .{ 8465.7  , 44.7  , -4982.2 } ,
    .{ 3580.1  , 122.5 , -8010.5 } ,
    .{ -4421.8 , 31.9  , -8558.7 } ,
    .{ -1466.0 , 63.4  , -9448.9 } ,
    .{ -6502.9 , 90.6  , -6713.7 } ,
    .{ -5977.0 , 68.6  , -7087.6 } ,
    .{ -2646.7 , 48.6  , -8440.8 } ,
    .{ 2867.6  , 69.8  , -9108.7 } ,
    .{ -316.5  , 31.1  , -8531.7 } ,
    .{ 2198.0  , 132.6 , -7877.5 } ,
    .{ -8474.8 , 32.5  , -5093.3 } ,
    .{ 3827.3  , 74.2  , -7442.3 } ,
    .{ -1262.4 , 32.2  , -8583.6 } ,
    .{ 8880.0  , 32.1  , -4270.9 } ,
    .{ 438.8   , 55.0  , -8208.1 } ,
    .{ -6551.6 , 64.6  , -7304.9 } ,
    .{ -7120.8 , 52.1  , -5958.1 } ,
    .{ 1717.0  , 69.4  , -9465.2 } ,
    .{ -2287.8 , 33.0  , -7986.1 } ,
    .{ 3416.9  , 68.4  , -7513.5 } ,
    .{ 6146.4  , 36.3  , -6956.4 } ,
    .{ -5209.9 , 34.1  , -8294.4 } ,
    .{ -1934.6 , 37.8  , -7868.8 } ,
    .{ 9110.3  , 33.3  , -4016.0 } ,
    .{ -3953.4 , 94.1  , -7950.9 } ,
    .{ 381.6   , 39.8  , -8269.2 } ,
    .{ 6637.7  , 49.8  , -7044.1 } ,
    .{ -4653.4 , 31.9  , -8722.6 } ,
    .{ 905.6   , 51.2  , -8340.4 } ,
    .{ -6547.3 , 87.4  , -6980.9 } ,
    .{ -6980.8 , 38.7  , -5896.0 } ,
    .{ -8045.5 , 33.2  , -5498.2 } ,
    .{ 2061.8  , 56.5  , -9385.4 } ,
    .{ 4856.0  , 31.7  , -8507.0 } ,
    .{ 5692.1  , 77.5  , -7938.4 } ,
    .{ -464.1  , 32.8  , -8714.0 } ,
    .{ 6524.6  , 32.7  , -6488.0 } ,
    .{ 152.0   , 31.2  , -8337.3 } ,
    .{ -3539.0 , 42.0  , -7578.7 } ,
    .{ -6328.8 , 56.9  , -7039.5 } ,
    .{ -6079.8 , 45.6  , -6581.4 } ,
    .{ -5832.4 , 36.0  , -7205.2 } ,
    .{ 2252.4  , 67.4  , -8402.2 } ,
    .{ -145.0  , 31.0  , -9003.1 } ,
    .{ 5.9     , 56.4  , -8764.9 } ,
    .{ 5545.9  , 42.7  , -7598.9 } ,
    .{ 2323.7  , 108.4 , -9611.5 } ,
    .{ 8399.0  , 35.9  , -5416.3 } ,
    .{ -1201.7 , 32.5  , -8127.1 } ,
    .{ 2726.5  , 158.8 , -9573.4 } ,
    .{ 5321.2  , 31.0  , -7620.0 } ,
    .{ -6469.3 , 38.0  , -6461.0 } ,
    .{ -323.7  , 31.9  , -8575.5 } ,
    .{ 7813.6  , 31.9  , -5031.8 } ,
    .{ 6999.1  , 52.4  , -6565.4 } ,
    .{ 7492.2  , 31.7  , -5413.4 } ,
    .{ -3226.2 , 97.7  , -9304.2 } ,
    .{ -655.8  , 35.7  , -9412.1 } ,
    .{ 8118.4  , 33.9  , -4984.2 } ,
    .{ -4117.5 , 36.0  , -7343.0 } ,
    .{ 4375.0  , 63.9  , -8975.3 } ,
    .{ -5906.4 , 80.4  , -6981.1 } ,
    .{ 8108.6  , 33.1  , -4935.7 } ,
    .{ -9156.8 , 45.8  , -3815.4 } ,
    .{ 1967.2  , 86.6  , -8879.2 } ,
    .{ 3470.6  , 31.7  , -8567.9 } ,
    .{ -2815.6 , 80.6  , -8662.5 } ,
    .{ -765.7  , 31.2  , -8714.1 } ,
    .{ -6967.3 , 47.6  , -5958.0 } ,
    .{ 4007.5  , 106.1 , -8520.2 } ,
    .{ -6524.0 , 32.3  , -6057.4 } ,
    .{ -8709.7 , 33.5  , -4393.1 } ,
    .{ 5949.3  , 33.0  , -7490.0 } ,
    .{ -5809.2 , 79.6  , -7809.4 } ,
    .{ -5551.8 , 42.3  , -7600.0 } ,
    .{ 463.6   , 70.2  , -9492.6 } ,
    .{ -7498.6 , 72.4  , -5745.0 } ,
    .{ 4330.8  , 35.1  , -8635.1 } ,
    .{ 3758.5  , 31.9  , -9069.3 } ,
    .{ 8010.2  , 31.1  , -5759.2 } ,
    .{ 649.7   , 71.1  , -9356.6 } ,
    .{ -3430.2 , 39.3  , -9342.0 } ,
    .{ -6117.5 , 34.9  , -6776.3 } ,
    .{ -7490.8 , 43.1  , -5928.0 } ,
    .{ -4736.9 , 31.5  , -7511.0 } ,
    .{ 5685.1  , 86.4  , -7978.8 } ,
    .{ 834.4   , 59.3  , -8407.5 } ,
    .{ 650.5   , 55.7  , -8572.0 } ,
    .{ -216.4  , 43.8  , -8258.1 } ,
    .{ -1910.0 , 170.9 , -9042.7 } ,
    .{ -4362.3 , 31.7  , -7891.2 } ,
    .{ 7949.4  , 32.2  , -4859.6 } ,
    .{ -3501.7 , 54.7  , -8727.9 } ,
    .{ 1972.1  , 68.8  , -9038.9 } ,
    .{ -855.2  , 32.6  , -8690.3 } ,
    .{ 2121.1  , 92.3  , -8496.8 } ,
    .{ 4966.1  , 51.8  , -8083.4 } ,
    .{ 2250.0  , 74.6  , -8557.1 } ,
    .{ -4292.8 , 31.5  , -8149.0 } ,
    .{ 2609.8  , 55.4  , -9129.6 } ,
    .{ 4330.4  , 31.5  , -8556.9 } ,
    .{ 3513.6  , 32.3  , -8969.6 } ,
    .{ -7205.3 , 51.6  , -5741.0 } ,
    .{ -7706.7 , 35.3  , -5360.6 } ,
    .{ -3702.8 , 72.3  , -7681.8 } ,
    .{ 14.0    , 31.6  , -9831.4 } ,
    .{ 7668.1  , 32.6  , -5814.9 } ,
    .{ 2878.3  , 89.9  , -8655.4 } ,
    .{ 855.5   , 51.0  , -8811.9 } ,
    .{ 5867.5  , 37.7  , -6571.3 } ,
    .{ 6701.8  , 87.5  , -6891.6 } ,
    .{ -2521.5 , 32.4  , -7813.9 } ,
    .{ 8326.3  , 59.2  , -5241.0 } ,
    .{ 4325.3  , 45.1  , -7761.7 } ,
    .{ 7809.8  , 33.8  , -4992.3 } ,
    .{ 3410.4  , 61.7  , -8009.6 } ,
    .{ -4853.3 , 31.4  , -7413.1 } ,
    .{ 6635.1  , 34.5  , -6268.7 } ,
    .{ 4159.2  , 96.5  , -8409.3 } ,
    .{ 6842.2  , 56.4  , -6590.1 } ,
    .{ -2537.7 , 33.0  , -9167.7 } ,
    .{ 7092.1  , 67.9  , -6700.5 } ,
    .{ -8553.0 , 31.2  , -4606.3 } ,
    .{ -1593.2 , 32.7  , -7980.9 } ,
    .{ 5130.9  , 51.7  , -8580.1 } ,
    .{ 6804.6  , 92.1  , -6898.1 } ,
    .{ -6994.4 , 31.3  , -5824.2 } ,
    .{ -2225.8 , 31.5  , -9241.0 } ,
    .{ 2710.4  , 176.0 , -9623.4 } ,
    .{ -2352.7 , 33.9  , -9464.4 } ,
    .{ 2879.2  , 78.4  , -8717.4 } ,
    .{ 278.9   , 76.6  , -8774.5 } ,
    .{ -6281.9 , 32.5  , -6700.3 } ,
    .{ -2098.7 , 41.8  , -8078.3 } ,
    .{ -5037.6 , 44.4  , -8378.6 } ,
    .{ 1166.3  , 46.3  , -9485.5 } ,
    .{ 3238.9  , 56.5  , -7662.4 } ,
    .{ -3595.7 , 113.0 , -8534.2 } ,
    .{ -4475.2 , 39.9  , -8722.8 } ,
    .{ -6425.9 , 32.4  , -6485.5 } ,
    .{ 679.8   , 60.2  , -9512.4 } ,
    .{ 3480.2  , 71.2  , -8168.9 } ,
    .{ -2237.4 , 31.9  , -7981.0 } ,
    .{ -2873.1 , 67.6  , -9140.8 } ,
    .{ -683.7  , 31.6  , -9654.7 } ,
    .{ -6502.4 , 34.2  , -6134.9 } ,
    .{ -579.6  , 34.1  , -8619.9 } ,
    .{ -1716.0 , 43.8  , -8122.6 } ,
    .{ 6694.7  , 73.5  , -6949.4 } ,
    .{ -7120.8 , 75.0  , -6201.1 } ,
    .{ 7.9     , 33.4  , -9794.2 } ,
    .{ -760.0  , 35.6  , -9544.6 } ,
    .{ -3519.5 , 114.5 , -8427.8 } ,
    .{ -5458.1 , 40.0  , -7677.4 } ,
    .{ 755.6   , 66.3  , -8782.2 } ,
    .{ -2948.3 , 78.5  , -8438.1 } ,
    .{ -4071.6 , 46.8  , -7572.7 } ,
    .{ 3647.3  , 97.8  , -8314.0 } ,
    .{ 3925.3  , 113.3 , -8103.8 } ,
    .{ -320.0  , 32.3  , -9430.4 } ,
    .{ -7668.5 , 35.9  , -6032.1 } ,
    .{ 278.5   , 38.8  , -8302.9 } ,
    .{ 1662.5  , 68.4  , -8118.7 } ,
    .{ 2100.0  , 87.9  , -8816.2 } ,
    .{ 2415.8  , 32.1  , -8366.7 } ,
    .{ -9001.0 , 37.8  , -4010.3 } ,
    .{ -2242.9 , 32.3  , -8178.9 } ,
    .{ -4264.1 , 32.1  , -7625.3 } ,
    .{ 1797.4  , 90.4  , -8062.3 } ,
    .{ 3132.4  , 35.4  , -7493.6 } ,
    .{ 8142.7  , 31.6  , -5607.3 } ,
    .{ 1613.9  , 71.4  , -7976.5 } ,
    .{ -649.2  , 37.1  , -9265.1 } ,
    .{ -3570.6 , 114.5 , -8044.3 } ,
    .{ 4277.7  , 88.3  , -8165.4 } ,
    .{ 2414.2  , 121.3 , -9593.4 } ,
    .{ 1306.0  , 33.1  , -8935.7 } ,
    .{ -150.6  , 50.7  , -8080.9 } ,
    .{ -4155.4 , 39.3  , -7498.9 } ,
    .{ 3112.6  , 88.9  , -9278.8 } ,
    .{ 4478.1  , 31.7  , -8694.2 } ,
    .{ 7788.9  , 74.9  , -6081.3 } ,
    .{ -3155.4 , 54.5  , -8963.3 } ,
    .{ -5584.3 , 61.3  , -7985.6 } ,
    .{ -2474.6 , 31.1  , -9384.3 } ,
    .{ 2413.3  , 32.8  , -8431.1 } ,
    .{ 5653.9  , 38.7  , -7418.5 } ,
    .{ -2281.2 , 34.7  , -8529.7 } ,
    .{ -1683.4 , 156.1 , -8999.8 } ,
    .{ 7593.9  , 96.4  , -6185.0 } ,
    .{ 5526.0  , 31.6  , -7409.0 } ,
    .{ -6866.8 , 45.2  , -6542.1 } ,
    .{ 4039.7  , 116.5 , -8472.9 } ,
    .{ -6381.3 , 34.0  , -6315.1 } ,
    .{ -4289.7 , 46.6  , -8629.5 } ,
    .{ -8148.7 , 33.4  , -4969.2 } ,
    .{ -4779.1 , 31.2  , -8167.0 } ,
    .{ 1087.1  , 90.5  , -8623.3 } ,
    .{ -1485.2 , 46.4  , -8757.3 } ,
    .{ -6066.3 , 51.2  , -6677.7 } ,
    .{ 345.1   , 32.4  , -9842.5 } ,
    .{ -1548.7 , 32.3  , -8503.7 } ,
    .{ 240.4   , 58.5  , -9555.3 } ,
    .{ -4249.9 , 40.3  , -7974.7 } ,
    .{ -3004.9 , 52.8  , -8973.0 } ,
    .{ 6100.9  , 34.4  , -7512.7 } ,
    .{ -2707.6 , 47.3  , -8945.7 } ,
    .{ 7281.8  , 34.3  , -6380.3 } ,
    .{ -1150.6 , 31.3  , -9484.5 } ,
    .{ -3311.1 , 71.2  , -9398.0 } ,
    .{ 909.5   , 31.9  , -8047.0 } ,
    .{ 441.9   , 129.4 , -9293.0 } ,
    .{ 6503.3  , 36.2  , -6249.4 } ,
    .{ 3532.8  , 92.8  , -7854.8 } ,
    .{ -6004.9 , 64.1  , -6523.1 } ,
    .{ 26.4    , 33.4  , -9358.2 } ,
    .{ -7784.0 , 31.3  , -6023.2 } ,
    .{ 6389.6  , 39.7  , -7033.1 } ,
    .{ -7189.9 , 63.7  , -5892.9 } ,
    .{ -6400.0 , 69.5  , -6709.1 } ,
    .{ -5568.1 , 34.4  , -7441.2 } ,
    .{ 447.9   , 32.5  , -7924.8 } ,
    .{ -7596.6 , 58.4  , -6284.1 } ,
    .{ 309.8   , 98.5  , -9014.2 } ,
    .{ -1899.0 , 73.5  , -9581.1 } ,
    .{ -108.0  , 36.4  , -9936.8 } ,
    .{ -7542.8 , 54.6  , -6392.0 } ,
    .{ 7254.9  , 32.9  , -5773.9 } ,
    .{ -7250.1 , 31.4  , -6648.7 } ,
    .{ -3639.0 , 117.8 , -8498.3 } ,
    .{ 4845.0  , 33.2  , -7082.5 } ,
    .{ 5439.6  , 133.5 , -8389.8 } ,
    .{ -6610.4 , 43.9  , -6514.1 } ,
    .{ 1021.0  , 33.1  , -9495.4 } ,
    .{ -1944.6 , 37.4  , -8308.7 } ,
    .{ 1218.4  , 96.1  , -8613.3 } ,
    .{ -2644.5 , 33.8  , -8181.3 } ,
    .{ 6895.6  , 39.0  , -6379.5 } ,
    .{ -6192.4 , 31.4  , -7470.1 } ,
    .{ 1285.7  , 50.0  , -8264.6 } ,
    .{ 2238.6  , 85.1  , -8700.9 } ,
    .{ 1711.2  , 67.2  , -9256.3 } ,
    .{ -1934.4 , 51.5  , -9739.1 } ,
    .{ 958.5   , 35.4  , -9282.0 } ,
    .{ -6090.9 , 35.7  , -7552.1 } ,
    .{ -1298.6 , 46.1  , -9025.3 } ,
    .{ 5741.8  , 102.2 , -8069.9 } ,
    .{ -3846.3 , 50.8  , -7672.1 } ,
    .{ 2063.6  , 101.6 , -8746.8 } ,
    .{ -752.3  , 32.4  , -9425.3 } ,
    .{ -1343.8 , 31.6  , -8887.5 } ,
    .{ -2416.1 , 31.4  , -8999.5 } ,
    .{ 7946.5  , 57.6  , -6039.9 } ,
    .{ -338.1  , 43.8  , -8077.3 } ,
    .{ -7013.2 , 32.6  , -6765.2 } ,
    .{ -3983.9 , 35.4  , -9100.1 } ,
    .{ -3386.0 , 69.4  , -8313.3 } ,
    .{ 3516.6  , 43.0  , -9277.5 } ,
    .{ -9277.6 , 35.7  , -3644.2 } ,
    .{ 6402.7  , 36.5  , -7159.3 } ,
    .{ 7758.7  , 36.1  , -5461.2 } ,
    .{ 1453.5  , 43.7  , -8905.4 } ,
    .{ -3245.8 , 65.3  , -8638.7 } ,
    .{ -1674.0 , 135.7 , -8946.2 } ,
    .{ -1829.7 , 38.4  , -8358.3 } ,
    .{ -4375.5 , 33.5  , -7787.4 } ,
    .{ 144.2   , 34.1  , -8105.2 } ,
    .{ -1795.1 , 52.3  , -9797.7 } ,
    .{ -6167.5 , 35.6  , -7488.0 } ,
    .{ -6859.4 , 58.9  , -6858.1 } ,
    .{ -7435.7 , 62.3  , -6090.7 } ,
    .{ -370.5  , 42.9  , -9768.9 } ,
    .{ 363.7   , 58.8  , -8634.3 } ,
    .{ -4263.4 , 31.0  , -7236.9 } ,
    .{ 7996.3  , 35.4  , -5207.6 } ,
    .{ -4909.7 , 33.2  , -7246.0 } ,
    .{ 3949.5  , 79.8  , -8711.1 } ,
    .{ 3545.4  , 38.7  , -8506.1 } ,
    .{ -982.0  , 38.1  , -9867.8 } ,
    .{ 4458.2  , 34.2  , -7686.1 } ,
    .{ -629.9  , 31.3  , -9715.4 } ,
    .{ 5046.8  , 31.5  , -7112.9 } ,
    .{ 4474.8  , 31.2  , -8072.0 } ,
    .{ -4480.0 , 34.9  , -8585.5 } ,
    .{ -2090.9 , 37.4  , -8213.8 } ,
    .{ 8955.5  , 34.4  , -4220.3 } ,
    .{ -7039.9 , 52.8  , -5928.9 } ,
    .{ -3326.0 , 62.1  , -9128.2 } ,
    .{ 3000.1  , 96.9  , -9258.0 } ,
    .{ 7404.5  , 31.5  , -5798.3 } ,
    .{ -1916.8 , 107.7 , -8793.3 } ,
    .{ 6648.6  , 34.8  , -6475.5 } ,
    .{ -5971.1 , 50.5  , -7237.0 } ,
    .{ 4838.9  , 31.5  , -7148.9 } ,
    .{ 6391.3  , 33.0  , -6247.3 } ,
    .{ 6718.6  , 63.7  , -7042.2 } ,
    .{ -662.4  , 46.4  , -9903.1 } ,
    .{ 1283.5  , 58.9  , -9405.6 } ,
    .{ -4878.8 , 32.5  , -7015.9 } ,
    .{ 3369.7  , 34.1  , -8518.2 } ,
    .{ 7292.1  , 32.0  , -6001.7 } ,
    .{ -4091.6 , 35.9  , -7236.0 } ,
    .{ -1725.8 , 61.3  , -9650.0 } ,
    .{ -314.5  , 41.4  , -8126.9 } ,
    .{ 1723.7  , 89.3  , -9741.4 } ,
    .{ -2805.0 , 56.7  , -9077.8 } ,
    .{ -5903.6 , 88.6  , -7783.2 } ,
    .{ -2048.7 , 116.6 , -8907.7 } ,
    .{ -1943.5 , 152.3 , -8959.5 } ,
    .{ -7093.1 , 31.8  , -6067.0 } ,
    .{ -7105.0 , 68.2  , -6273.7 } ,
    .{ 4974.4  , 33.1  , -7506.4 } ,
    .{ 216.5   , 86.2  , -9344.5 } ,
    .{ -3965.8 , 65.3  , -7356.8 } ,
    .{ 2507.6  , 51.4  , -8777.1 } ,
    .{ -4266.6 , 34.0  , -7365.9 } ,
    .{ -8981.3 , 60.6  , -3821.8 } ,
    .{ -1573.8 , 122.1 , -9001.0 } ,
    .{ 1303.5  , 103.1 , -9676.5 } ,
    .{ -6615.3 , 43.4  , -6485.6 } ,
    .{ 1421.1  , 61.4  , -8730.7 } ,
    .{ 2933.7  , 78.7  , -9000.2 } ,
    .{ 8409.9  , 55.6  , -5175.3 } ,
    .{ -1294.7 , 39.4  , -9341.7 } ,
    .{ -4589.4 , 33.7  , -8695.8 } ,
    .{ -2571.7 , 33.2  , -9662.5 } ,
    .{ 102.2   , 61.2  , -9007.1 } ,
    .{ -6356.3 , 68.1  , -6998.7 } ,
    .{ 3068.2  , 39.6  , -8494.2 } ,
    .{ 1170.6  , 104.9 , -8628.4 } ,
    .{ -296.6  , 32.7  , -8436.3 } ,
    .{ -4227.7 , 53.6  , -8230.5 } ,
    .{ -7890.7 , 31.0  , -5815.3 } ,
    .{ 7420.9  , 65.2  , -6357.4 } ,
    .{ 1156.4  , 62.9  , -8077.4 } ,
    .{ 1067.2  , 31.3  , -8955.5 } ,
    .{ -5113.1 , 49.0  , -8506.5 } ,
    .{ 5140.4  , 31.3  , -7630.9 } ,
    .{ 2183.2  , 109.2 , -9364.4 } ,
    .{ 4933.1  , 35.3  , -6975.3 } ,
    .{ 5053.5  , 69.2  , -8200.8 } ,
    .{ 1287.2  , 76.6  , -7954.5 } ,
    .{ -6169.0 , 104.2 , -7697.8 } ,
    .{ -2858.1 , 60.5  , -8319.9 } ,
    .{ 2254.8  , 75.7  , -8614.3 } ,
    .{ -7549.1 , 53.6  , -6070.0 } ,
    .{ 8619.0  , 31.2  , -4722.4 } ,
    .{ -4276.9 , 32.3  , -7894.5 } ,
    .{ -1958.9 , 36.0  , -7941.0 } ,
    .{ -2007.8 , 44.4  , -8165.8 } ,
    .{ -3791.9 , 86.6  , -8513.5 } ,
    .{ 7444.4  , 31.3  , -6613.7 } ,
    .{ 1012.1  , 35.3  , -9714.9 } ,
    .{ -5750.5 , 68.4  , -7911.7 } ,
    .{ 2500.0  , 39.5  , -8971.4 } ,
    .{ 2744.5  , 51.2  , -9048.7 } ,
    .{ -5753.9 , 35.6  , -7095.0 } ,
    .{ -9144.8 , 46.1  , -3718.5 } ,
    .{ 2962.0  , 31.3  , -8019.0 } ,
    .{ 105.8   , 37.9  , -8437.9 } ,
    .{ -1071.4 , 33.5  , -9651.9 } ,
    .{ 4505.6  , 37.7  , -7869.9 } ,
    .{ -8446.2 , 33.5  , -5255.7 } ,
    .{ -5812.4 , 45.5  , -8117.6 } ,
    .{ 5892.2  , 81.9  , -7927.7 } ,
    .{ -4490.4 , 35.8  , -8805.8 } ,
    .{ -3493.2 , 34.5  , -9093.3 } ,
    .{ 2903.2  , 34.8  , -8370.8 } ,
    .{ -3850.8 , 61.6  , -8537.1 } ,
    .{ 2941.8  , 40.4  , -8134.2 } ,
    .{ -4661.0 , 49.2  , -6992.7 } ,
    .{ -4813.2 , 47.5  , -7340.2 } ,
    .{ -5844.2 , 64.8  , -7936.0 } ,
    .{ 3461.6  , 47.6  , -9072.6 } ,
    .{ -4670.5 , 43.0  , -7084.4 } ,
    .{ 6979.0  , 86.8  , -6912.7 } ,
    .{ -8180.9 , 31.5  , -5413.6 } ,
    .{ -6461.6 , 45.5  , -7178.4 } ,
    .{ -5944.1 , 70.8  , -6550.5 } ,
    .{ -529.5  , 32.5  , -9463.5 } ,
    .{ 1048.6  , 32.8  , -8890.7 } ,
    .{ -1962.0 , 36.6  , -7977.9 } ,
    .{ 46.1    , 58.7  , -8722.0 } ,
    .{ -3753.6 , 34.9  , -8984.3 } ,
    .{ -3017.3 , 85.3  , -9222.0 } ,
    .{ 1963.9  , 85.9  , -8304.3 } ,
    .{ 6508.1  , 65.4  , -6709.5 } ,
    .{ 8811.2  , 31.0  , -4342.3 } ,
    .{ -7980.1 , 31.8  , -5756.6 } ,
    .{ 3982.5  , 44.0  , -7401.3 } ,
    .{ -495.3  , 31.7  , -9529.7 } ,
    .{ -4215.1 , 44.2  , -8789.6 } ,
    .{ 6535.8  , 34.8  , -6506.7 } ,
    .{ 3406.0  , 90.3  , -7560.2 } ,
    .{ 4746.9  , 31.4  , -7805.3 } ,
    .{ -1218.2 , 33.0  , -9872.2 } ,
    .{ 2245.0  , 83.4  , -9607.6 } ,
    .{ -786.7  , 36.2  , -9707.8 } ,
    .{ -6701.2 , 78.2  , -7378.4 } ,
    .{ -1399.1 , 58.4  , -9108.5 } ,
    .{ 3142.3  , 38.9  , -7726.3 } ,
    .{ -4348.2 , 35.2  , -8400.3 } ,
    .{ -4330.9 , 31.0  , -8081.9 } ,
    .{ 7864.8  , 32.4  , -5136.2 } ,
    .{ 1681.2  , 79.1  , -9467.7 } ,
    .{ -6071.8 , 103.5 , -7914.2 } ,
    .{ -1450.1 , 63.0  , -9305.6 } ,
    .{ -1668.8 , 132.3 , -9208.6 } ,
    .{ 2612.5  , 37.7  , -8306.6 } ,
    .{ -2475.9 , 32.1  , -9333.1 } ,
    .{ 7298.6  , 32.8  , -6354.9 } ,
    .{ -2998.2 , 45.5  , -8773.2 } ,
    .{ -4041.0 , 101.4 , -8280.7 } ,
    .{ 3412.6  , 63.7  , -9171.5 } ,
    .{ 198.9   , 91.2  , -9037.3 } ,
    .{ 4110.2  , 45.4  , -8794.7 } ,
    .{ 2742.7  , 63.8  , -8574.5 } ,
    .{ 1064.7  , 31.1  , -9177.6 } ,
    .{ 1731.9  , 86.5  , -9773.4 } ,
    .{ -6633.7 , 70.0  , -7431.5 } ,
    .{ 6805.7  , 60.2  , -7305.0 } ,
    .{ -1875.7 , 49.0  , -8201.3 } ,
    .{ -2603.5 , 33.6  , -8770.8 } ,
    .{ -2568.5 , 33.9  , -8889.3 } ,
    .{ 5399.1  , 43.1  , -7815.5 } ,
    .{ -1352.2 , 56.6  , -9077.9 } ,
    .{ 178.7   , 80.8  , -8657.3 } ,
    .{ -1422.8 , 55.3  , -8894.8 } ,
    .{ 5332.5  , 44.8  , -6783.5 } ,
    .{ 5077.7  , 65.2  , -8372.2 } ,
    .{ 1680.5  , 100.1 , -9881.5 } ,
    .{ -7744.4 , 32.7  , -5658.6 } ,
    .{ -8503.9 , 32.8  , -5016.0 } ,
    .{ -720.2  , 36.3  , -9803.9 } ,
    .{ -3565.0 , 65.3  , -8723.5 } ,
    .{ 2617.1  , 161.7 , -9593.4 } ,
    .{ -6073.9 , 43.5  , -6981.9 } ,
    .{ 6133.1  , 37.8  , -6933.5 } ,
    .{ 47.4    , 31.4  , -9915.1 } ,
    .{ -9007.7 , 49.7  , -3900.6 } ,
    .{ -5693.5 , 58.3  , -7943.5 } ,
    .{ 1965.2  , 64.1  , -9066.3 } ,
    .{ -461.2  , 38.6  , -9618.1 } ,
    .{ -7886.7 , 31.5  , -5209.6 } ,
    .{ 4411.6  , 33.9  , -8907.9 } ,
    .{ -713.3  , 32.8  , -8934.3 } ,
    .{ -2686.8 , 35.3  , -9526.6 } ,
    .{ 1351.2  , 72.5  , -7953.3 } ,
    .{ -2237.5 , 45.4  , -7737.4 } ,
    .{ -4504.0 , 31.2  , -7641.7 } ,
    .{ -3386.1 , 72.0  , -8116.8 } ,
    .{ 2450.5  , 37.7  , -9103.5 } ,
    .{ -7230.5 , 41.3  , -6802.0 } ,
    .{ 3111.5  , 38.8  , -7658.8 } ,
    .{ -269.3  , 31.7  , -9228.4 } ,
    .{ 2254.4  , 50.1  , -9142.6 } ,
    .{ -5286.9 , 43.6  , -7622.0 } ,
    .{ 2985.3  , 32.8  , -8137.8 } ,
    .{ -2941.9 , 77.5  , -8527.0 } ,
    .{ 6418.5  , 41.7  , -7246.2 } ,
    .{ 6031.9  , 31.3  , -6547.8 } ,
    .{ 1620.1  , 92.5  , -9470.4 } ,
    .{ 1225.4  , 82.3  , -7991.1 } ,
    .{ -4175.9 , 40.8  , -7414.8 } ,
    .{ -327.1  , 32.1  , -8921.5 } ,
    .{ 3773.1  , 49.8  , -8656.2 } ,
    .{ 1605.1  , 120.7 , -9728.4 } ,
    .{ -6400.2 , 35.4  , -7354.5 } ,
    .{ 1012.4  , 54.7  , -7976.6 } ,
    .{ -1985.7 , 129.4 , -8899.3 } ,
    .{ 3206.4  , 45.5  , -8562.1 } ,
];

DvergrTownEntrances1 :: Vector3.[
    .{ 4992.0  , 51.0  , 5440.0  } ,
    .{ 9088.0  , 43.0  , 3392.0  } ,
    .{ 6272.0  , 43.0  , -5952.0 } ,
    .{ -7616.0 , 65.0  , -4736.0 } ,
    .{ 9728.0  , 69.0  , 1856.0  } ,
    .{ -5824.0 , 48.5  , 4160.0  } ,
    .{ 3328.0  , 46.5  , -6528.0 } ,
    .{ -6464.0 , 49.0  , 3712.0  } ,
    .{ -6080.0 , 50.5  , 5760.0  } ,
    .{ -4224.0 , 51.9  , -5568.0 } ,
    .{ 2048.0  , 42.6  , -6464.0 } ,
    .{ 1728.0  , 55.5  , 7616.0  } ,
    .{ 8896.0  , 46.0  , 3584.0  } ,
    .{ 7872.0  , 53.0  , 128.0   } ,
    .{ -5376.0 , 88.5  , -5568.0 } ,
    .{ -6080.0 , 43.5  , 4032.0  } ,
    .{ -7296.0 , 74.5  , -2880.0 } ,
    .{ -6080.0 , 45.0  , -1600.0 } ,
    .{ -7616.0 , 60.0  , 1344.0  } ,
    .{ -6464.0 , 62.5  , -2176.0 } ,
    .{ -6464.0 , 43.0  , -192.0  } ,
    .{ -3840.0 , 43.4  , -6080.0 } ,
    .{ 7296.0  , 66.5  , 1472.0  } ,
    .{ -7360.0 , 55.0  , 3072.0  } ,
    .{ 6400.0  , 102.5 , -5696.0 } ,
    .{ -5504.0 , 59.5  , -6592.0 } ,
    .{ 4864.0  , 68.5  , -5056.0 } ,
    .{ -8576.0 , 64.0  , -1280.0 } ,
    .{ -9088.0 , 50.0  , -3456.0 } ,
    .{ 2176.0  , 44.5  , -7040.0 } ,
    .{ 256.0   , 56.5  , -6656.0 } ,
    .{ 9280.0  , 42.0  , 0.0     } ,
    .{ -5120.0 , 52.1  , 6464.0  } ,
    .{ -6528.0 , 61.0  , 128.0   } ,
    .{ 5888.0  , 57.0  , -4928.0 } ,
    .{ -2048.0 , 43.4  , 7360.0  } ,
    .{ 4800.0  , 44.0  , 4096.0  } ,
    .{ 2688.0  , 65.0  , -6016.0 } ,
    .{ 8384.0  , 62.0  , 4352.0  } ,
    .{ -9216.0 , 52.0  , 3008.0  } ,
    .{ 8640.0  , 44.0  , 2368.0  } ,
    .{ -6080.0 , 49.3  , 6144.0  } ,
    .{ 9536.0  , 42.5  , 128.0   } ,
    .{ -6720.0 , 75.0  , 5440.0  } ,
    .{ 7488.0  , 70.9  , 0.0     } ,
    .{ 8768.0  , 87.5  , 3328.0  } ,
    .{ -1024.0 , 45.5  , 6208.0  } ,
    .{ -3392.0 , 50.5  , 5504.0  } ,
    .{ 7296.0  , 47.5  , 3456.0  } ,
    .{ 8896.0  , 86.5  , 2560.0  } ,
    .{ 1984.0  , 60.5  , 6528.0  } ,
    .{ 8448.0  , 80.0  , 1088.0  } ,
    .{ -7616.0 , 54.0  , 4352.0  } ,
    .{ 8192.0  , 54.0  , -3968.0 } ,
    .{ 5952.0  , 53.0  , -5504.0 } ,
    .{ 5760.0  , 82.0  , -3520.0 } ,
    .{ 5504.0  , 51.5  , 4480.0  } ,
    .{ 9664.0  , 78.5  , -192.0  } ,
    .{ -7680.0 , 48.0  , 768.0   } ,
    .{ 7040.0  , 49.4  , 3840.0  } ,
    .{ -6912.0 , 56.0  , -3072.0 } ,
    .{ 8768.0  , 66.0  , -1152.0 } ,
    .{ 5760.0  , 66.5  , -4224.0 } ,
    .{ -192.0  , 62.9  , -7744.0 } ,
    .{ -9280.0 , 58.9  , -3072.0 } ,
    .{ 4928.0  , 63.5  , -5312.0 } ,
    .{ -2368.0 , 71.5  , 6464.0  } ,
    .{ 4992.0  , 50.5  , -5568.0 } ,
    .{ -4672.0 , 47.5  , -4672.0 } ,
    .{ 768.0   , 48.0  , -7616.0 } ,
    .{ -8832.0 , 54.0  , 3200.0  } ,
    .{ -960.0  , 56.5  , 7552.0  } ,
    .{ 6656.0  , 56.0  , -4864.0 } ,
    .{ -3136.0 , 55.0  , 6528.0  } ,
    .{ -6080.0 , 54.5  , 4288.0  } ,
    .{ -4608.0 , 47.5  , -5760.0 } ,
    .{ -3072.0 , 59.4  , 6912.0  } ,
    .{ 2496.0  , 98.0  , -6208.0 } ,
    .{ 6272.0  , 50.6  , -4864.0 } ,
    .{ 4032.0  , 67.5  , -6016.0 } ,
    .{ -5056.0 , 43.0  , -5824.0 } ,
    .{ 6720.0  , 47.0  , 5504.0  } ,
    .{ -6848.0 , 52.0  , 640.0   } ,
    .{ 6464.0  , 49.5  , 1344.0  } ,
    .{ -5952.0 , 50.5  , 2368.0  } ,
    .{ -7168.0 , 47.1  , -3200.0 } ,
    .{ -2304.0 , 47.0  , -7232.0 } ,
    .{ 2816.0  , 61.0  , 5440.0  } ,
    .{ 1408.0  , 70.6  , 5888.0  } ,
    .{ -832.0  , 87.5  , 7168.0  } ,
    .{ -5760.0 , 60.5  , -2432.0 } ,
    .{ -6976.0 , 50.4  , -1856.0 } ,
    .{ 8896.0  , 44.5  , -320.0  } ,
    .{ -7808.0 , 48.9  , 4096.0  } ,
    .{ 5504.0  , 57.3  , -5696.0 } ,
    .{ -6848.0 , 61.5  , 384.0   } ,
    .{ 5632.0  , 42.0  , -5952.0 } ,
    .{ 1792.0  , 72.5  , 6144.0  } ,
    .{ -7360.0 , 51.0  , 640.0   } ,
    .{ -704.0  , 56.5  , 6208.0  } ,
    .{ -7744.0 , 88.0  , 2944.0  } ,
    .{ -6656.0 , 54.0  , -3456.0 } ,
    .{ -6528.0 , 61.0  , 576.0   } ,
    .{ 1024.0  , 50.7  , -7360.0 } ,
    .{ -2240.0 , 45.5  , 6208.0  } ,
    .{ -768.0  , 56.0  , -7744.0 } ,
    .{ -5056.0 , 42.5  , -4416.0 } ,
    .{ -448.0  , 53.0  , 6336.0  } ,
    .{ -5824.0 , 59.4  , -3200.0 } ,
    .{ 9536.0  , 76.5  , 2176.0  } ,
    .{ -1792.0 , 48.0  , 7552.0  } ,
    .{ 2304.0  , 47.0  , 7360.0  } ,
    .{ -9472.0 , 46.5  , 2880.0  } ,
    .{ -1216.0 , 47.0  , 6400.0  } ,
    .{ 4608.0  , 46.0  , -4736.0 } ,
    .{ 8320.0  , 66.0  , 1408.0  } ,
    .{ -7424.0 , 58.5  , -4544.0 } ,
    .{ -8128.0 , 72.0  , 192.0   } ,
    .{ 6720.0  , 53.0  , 512.0   } ,
    .{ -2944.0 , 58.9  , 7232.0  } ,
];

DvergrTownEntrances2 :: Vector3.[
    .{ 1984.0  , 32.2 , -6080.0 } ,
    .{ -8448.0 , 44.5 , 2048.0  } ,
    .{ 7040.0  , 39.0 , -1728.0 } ,
    .{ -6784.0 , 31.4 , -128.0  } ,
    .{ 7616.0  , 41.5 , 960.0   } ,
    .{ 2432.0  , 32.5 , -5696.0 } ,
    .{ -4096.0 , 37.0 , -6336.0 } ,
    .{ 7616.0  , 36.5 , 576.0   } ,
    .{ 5248.0  , 37.4 , 3840.0  } ,
    .{ 5696.0  , 47.0 , 3968.0  } ,
    .{ 4416.0  , 43.1 , -5888.0 } ,
    .{ -2624.0 , 34.8 , -7552.0 } ,
    .{ -7168.0 , 36.5 , -4544.0 } ,
    .{ 7616.0  , 32.5 , 2240.0  } ,
    .{ -5824.0 , 35.5 , 5568.0  } ,
    .{ 6464.0  , 41.5 , 5568.0  } ,
    .{ -7808.0 , 41.0 , 2624.0  } ,
    .{ 7296.0  , 38.3 , 3776.0  } ,
    .{ 5312.0  , 41.0 , 5376.0  } ,
    .{ 7104.0  , 40.5 , 768.0   } ,
    .{ -6016.0 , 36.5 , 4544.0  } ,
    .{ 8640.0  , 44.5 , -512.0  } ,
    .{ 1856.0  , 44.5 , 7232.0  } ,
    .{ 8576.0  , 35.0 , -3968.0 } ,
    .{ -9408.0 , 38.0 , 512.0   } ,
    .{ -1216.0 , 41.5 , -7104.0 } ,
    .{ -5120.0 , 45.5 , -5568.0 } ,
    .{ 8960.0  , 48.5 , -896.0  } ,
    .{ -9664.0 , 31.5 , -64.0   } ,
    .{ 3200.0  , 33.5 , -5952.0 } ,
    .{ -6592.0 , 38.5 , 1792.0  } ,
    .{ -8832.0 , 31.0 , 3776.0  } ,
    .{ -6144.0 , 49.5 , -320.0  } ,
    .{ -7936.0 , 32.0 , -1408.0 } ,
    .{ -7808.0 , 33.5 , -896.0  } ,
    .{ 7360.0  , 41.5 , 704.0   } ,
    .{ -1792.0 , 48.7 , 7168.0  } ,
    .{ 7232.0  , 34.0 , -3520.0 } ,
    .{ -3712.0 , 43.0 , -6656.0 } ,
    .{ -7104.0 , 40.4 , 576.0   } ,
    .{ -6976.0 , 32.5 , -4928.0 } ,
    .{ 4480.0  , 38.0 , -4992.0 } ,
    .{ -5056.0 , 38.0 , 4160.0  } ,
    .{ 8640.0  , 38.5 , 1280.0  } ,
    .{ 4608.0  , 35.5 , -6080.0 } ,
    .{ 8832.0  , 34.5 , 2880.0  } ,
    .{ 7872.0  , 36.0 , -3968.0 } ,
    .{ 6144.0  , 34.5 , 1216.0  } ,
    .{ -6400.0 , 45.0 , -1920.0 } ,
    .{ 6464.0  , 45.0 , 320.0   } ,
    .{ -7296.0 , 31.6 , -2496.0 } ,
    .{ 8576.0  , 41.0 , -960.0  } ,
    .{ 2560.0  , 32.5 , -7360.0 } ,
    .{ -5952.0 , 36.5 , 4864.0  } ,
    .{ 768.0   , 43.0 , 6144.0  } ,
    .{ 7680.0  , 32.0 , 4928.0  } ,
    .{ -6336.0 , 33.5 , 1664.0  } ,
    .{ -6144.0 , 33.4 , -640.0  } ,
    .{ -6272.0 , 43.0 , 2112.0  } ,
    .{ 8256.0  , 32.5 , -2496.0 } ,
    .{ -704.0  , 41.0 , 6464.0  } ,
    .{ 7296.0  , 43.5 , -1728.0 } ,
    .{ 7360.0  , 45.5 , 5056.0  } ,
    .{ -7232.0 , 46.9 , 5440.0  } ,
    .{ -4800.0 , 43.5 , 4224.0  } ,
    .{ 9024.0  , 36.5 , -64.0   } ,
    .{ -7872.0 , 45.0 , 1152.0  } ,
    .{ 8128.0  , 43.5 , 4672.0  } ,
    .{ 7168.0  , 31.5 , 1728.0  } ,
    .{ -576.0  , 33.0 , -7936.0 } ,
    .{ -6400.0 , 35.1 , 2368.0  } ,
    .{ -7360.0 , 39.4 , 3328.0  } ,
    .{ -7680.0 , 45.5 , 3392.0  } ,
    .{ -4544.0 , 31.5 , 6720.0  } ,
    .{ -4288.0 , 36.5 , 5248.0  } ,
    .{ 6912.0  , 45.0 , -768.0  } ,
    .{ 512.0   , 32.6 , -6976.0 } ,
    .{ 6400.0  , 38.5 , 2880.0  } ,
    .{ -4864.0 , 33.0 , 6464.0  } ,
    .{ 7232.0  , 40.0 , 1088.0  } ,
    .{ 2368.0  , 31.0 , 6976.0  } ,
    .{ 9408.0  , 38.5 , 448.0   } ,
    .{ 512.0   , 44.0 , -7488.0 } ,
    .{ 6464.0  , 45.0 , -2688.0 } ,
    .{ 4928.0  , 42.5 , -4416.0 } ,
    .{ -4352.0 , 33.9 , -6144.0 } ,
    .{ 5888.0  , 31.5 , 1984.0  } ,
    .{ 5632.0  , 49.5 , 2112.0  } ,
    .{ -7552.0 , 34.7 , 2560.0  } ,
    .{ -7552.0 , 49.0 , -3392.0 } ,
    .{ 6720.0  , 31.0 , 3136.0  } ,
    .{ 9216.0  , 35.5 , -384.0  } ,
    .{ -9600.0 , 35.5 , -384.0  } ,
    .{ 7168.0  , 43.0 , 0.0     } ,
    .{ 3008.0  , 48.4 , -6464.0 } ,
    .{ 6144.0  , 41.5 , -3392.0 } ,
    .{ 6848.0  , 33.5 , 2752.0  } ,
    .{ 3264.0  , 31.6 , -6784.0 } ,
    .{ 9728.0  , 33.0 , 1344.0  } ,
    .{ -8320.0 , 41.5 , -1088.0 } ,
    .{ -7872.0 , 32.0 , -3392.0 } ,
    .{ 7040.0  , 40.0 , 4096.0  } ,
    .{ -3840.0 , 50.0 , 5952.0  } ,
    .{ 1920.0  , 39.5 , -6912.0 } ,
    .{ -4800.0 , 38.5 , -5952.0 } ,
    .{ -6208.0 , 38.0 , -2304.0 } ,
    .{ 9408.0  , 34.0 , 3008.0  } ,
    .{ 3584.0  , 32.5 , -6784.0 } ,
    .{ -8704.0 , 37.0 , -2560.0 } ,
    .{ 1024.0  , 32.4 , -6592.0 } ,
    .{ 7232.0  , 37.0 , -3776.0 } ,
    .{ 1152.0  , 41.0 , -7808.0 } ,
    .{ -8896.0 , 40.4 , -1024.0 } ,
    .{ 8320.0  , 33.5 , -2816.0 } ,
    .{ -6656.0 , 42.5 , 4736.0  } ,
    .{ 9728.0  , 37.1 , -1792.0 } ,
    .{ -2176.0 , 32.5 , -6272.0 } ,
    .{ 8768.0  , 38.5 , 3904.0  } ,
    .{ -2048.0 , 41.0 , 6400.0  } ,
    .{ 4160.0  , 45.5 , 4800.0  } ,
];

#import "Basic";
#import "File";
#import "File_Utilities";
#import "String";
#import "stb_image_write";
#import "Math";
#import "System";
#import "Window_Creation";
Simp :: #import "Simp";
Bitmap :: Simp.Bitmap;
GetRect :: #import "GetRect";
Input :: #import "Input";
#import "Hash_Table";
#import "jason";
#import "Sort";
