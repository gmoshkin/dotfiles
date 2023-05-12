main :: () {
    time_start_main := get_time();

    args := get_command_line_arguments();
    // filename := args[1];
    // data := read_entire_file(filename);
    dir := args[1];
    all_files := file_list(dir);
    assert(all_files.count == TileSideCount * TileSideCount);

    #if OS == .WINDOWS {
        Windows.SetProcessDPIAware();

        // Windows is very bad at thread-switching by default unless you do this. Sad.
        Windows :: #import "Windows";
        Windows.timeBeginPeriod(1);
    }
    window_width = 1920 / 2;
    window_height = 1920 / 2;
    window = create_window(window_width, window_height, "A Window");
    window_width, window_height = Simp.get_render_dimensions(window);
    Simp.set_render_target(window);
    GetRect.ui_init();
    get_rect_theme := GetRect.default_theme_procs[GetRect.Default_Themes.Default]();
    GetRect.set_default_theme(get_rect_theme);

    TileRowCount : s32 : 1024;
    TileSize :: 3000.0;
    TileSideCount :: 8;
    WorldWidth :: 24000.0;
    elements_per_tile :: TileRowCount * TileRowCount;
    tiles_per_map :: TileSideCount * TileSideCount;
    elements_per_map :: tiles_per_map * elements_per_tile;

    tile_element_size_in_bytes :: 10;
    tile_file_size :: elements_per_tile * tile_element_size_in_bytes;
    bitmap_size :: TileRowCount * TileSideCount;

    min_biome := 0xffff;
    max_biome := 0;

    show_biome := true;

    min_height := FLOAT32_INFINITY;
    max_height := -FLOAT32_INFINITY;

    start_height := 0.0;
    end_height := 0.0;

    show_height := true;

    min_forest := FLOAT32_INFINITY;
    max_forest := -FLOAT32_INFINITY;

    start_forest := 0.0;
    end_forest := 0.0;

    show_forest := false;

    // biomes : Table(u16, s64);

    TileElement :: struct {
        biome: u16;
        height: float32;
        forest: float32;
    }

    slider_theme := get_rect_theme.slider_theme;
    slider_theme.clamp_text_input_high = false;
    checkbox_theme := get_rect_theme.checkbox_theme;

    state : enum {
        LOADING_FILES;
        GENERATING_BITMAP;
        DONE;
    } = .LOADING_FILES;

    current_file_index := 0;
    batch_index := 0;

    map_data := NewArray(elements_per_map, TileElement);
    tile_data := NewArray(tile_file_size, u8);

    while !quit {
        time_start := get_time();
        /////////////////////////////////////////////////////////////////////////////////
        // Read input
        Input.update_window_events();

        for Input.get_window_resizes() {
            Simp.update_window(it.window);

            if it.window == window {
                window_width  = it.width;
                window_height = it.height;
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

        GetRect.ui_per_frame_update(window, window_width, window_height, time_start);
        Simp.update_window(window);
        Simp.clear_render_target(0.1, 0.1, 0.1, 1);

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

                    map_data[map_index].biome = biome;
                    map_data[map_index].height = height;
                    map_data[map_index].forest = forest;
                }

                current_file_index += 1;
                if current_file_index == all_files.count {
                    log("biome %..%", min_biome, max_biome);
                    log("height %..%", min_height, max_height);
                    log("forest %..%", min_forest, max_forest);

                    start_height = 30;
                    end_height = 100;

                    start_forest = 1.15;
                    end_forest = 1.75;

                    // log("biomes:"); for biomes log("  %: %", it_index, it);

                    state = .GENERATING_BITMAP;
                    batch_index = 0;

                    bitmap_data = NewArray(bitmap_size * bitmap_size, RGBA, initialized = true);
                    bitmap = Bitmap.{
                        data = xx bitmap_data,
                        width = bitmap_size,
                        height = bitmap_size,
                        format = .RGBA8,
                    };
                }

                status_message = tprint("reading file #%: %", current_file_index, filename);

            /////////////////////////////////////////////////////////////////////////////
            case .GENERATING_BITMAP;
                batch_size := elements_per_tile / 2;
                n_batches := elements_per_map / batch_size;

                if quit exit(0);
                reset_temporary_storage();

                for 0..batch_size-1 {
                    index := batch_index * batch_size + it;
                    using map_data[index];
                    pixel := *bitmap_data[index];

                    <<pixel = .{ r = 0xff, g = 0xff, b = 0xff };

                    if show_biome if biome == {
                        // meadow
                        case 1; <<pixel = .{ r = 0x40, g = 0xff, b = 0x40 };
                        // swamp
                        case 2; <<pixel = .{ r = 0x40, g = 0x30, b = 0x10 };
                        // mountain
                        case 4; <<pixel = .{ r = 0xff, g = 0xff, b = 0xff };
                        // dark wood
                        case 8; <<pixel = .{ r = 0x00, g = 0x40, b = 0x00 };
                        // plains
                        case 16; <<pixel = .{ r = 0xaa, g = 0xaa, b = 0x44 };
                        // void?
                        case 32; <<pixel = .{ r = 0x00, g = 0x00, b = 0x00 };
                        // north pole?
                        case 64; <<pixel = .{ r = 0x33, g = 0x77, b = 0xcc };
                        // nothing?
                        case 128; <<pixel = .{ r = 0xff, g = 0x00, b = 0xff };
                        // ocean
                        case 256; <<pixel = .{ r = 0x8a, g = 0xee, b = 0xd5 };
                        // mistlands
                        case 512; <<pixel = .{ r = 0x44, g = 0x11, b = 0x44 };
                    }

                    if show_height {
                        h := clamp(height, start_height, end_height);
                        h = (h - start_height) / (end_height - start_height);
                        // h := (height - min_height) * (max_height - min_height) * 0xff;
                        pixel.r = xx (pixel.r * h);
                        pixel.g = xx (pixel.g * h);
                        pixel.b = xx (pixel.b * h);
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

            /////////////////////////////////////////////////////////////////////////////
            case .DONE;
                status_message = "done";
        }

        scale := pow(2, image_scale_log_2);

        /////////////////////////////////////////////////////////////////////////////////
        // Draw bitmap
        if bitmap.width {
            if GetRect.ui_get_button_state(.MOUSE_BUTTON_LEFT) == .DOWN {
                image_ofs.x += Input.mouse_delta_x;
                image_ofs.y -= Input.mouse_delta_y;
            }
            image_scale_log_2 += 0.1 * Input.mouse_delta_z / 120;
            // if image_scale_log_2 < 0.0 image_scale_log_2 = 0.0;

            Simp.set_shader_for_images(*texture);
            Simp.immediate_begin();
            w := scale * min(window_height, window_width);
            o := Vector2.{ xx (window_width / 2), xx (window_height / 2) };
            o += image_ofs;
            Simp.immediate_quad(
                o + .{ +w/2, -w/2 },
                o + .{ +w/2, +w/2 },
                o + .{ -w/2, +w/2 },
                o + .{ -w/2, -w/2 },
            );
            Simp.immediate_flush();
        }

        /////////////////////////////////////////////////////////////////////////////////
        // Draw ui
        w := 400.0;
        h := 40.0;
        rect := GetRect.get_rect(xx ((window_width - w) / 2), xx ((window_height - h) / 2), w, h);
        {
            text := tprint("uptime: %", get_time() - time_start_main);
            GetRect.label(rect, text, *get_rect_theme.label_theme);
            rect.y -= 20;
        }

        {
            theme := get_rect_theme.label_theme;
            GetRect.label(rect, status_message, *theme);
        }

        rect = GetRect.get_rect(xx 10, xx (window_height - 20), 400, 20);
        {
            GetRect.slider(rect, *image_scale_log_2, -8.0, 16, spinbox_step = .5, theme = *slider_theme);
            rect.y -= 22;
        }

        {
            changed := false;
            changed |= GetRect.slider(rect, *start_height, 0, end_height, spinbox_step = 2.5, theme = *slider_theme);
            rect.y -= 22;
            changed |= GetRect.slider(rect, *end_height, start_height, 100, spinbox_step = 2.5, theme = *slider_theme);
            rect.y -= 22;

            changed |= GetRect.slider(rect, *start_forest, 1.0, end_forest, spinbox_step = 0.025, theme = *slider_theme);
            rect.y -= 22;
            changed |= GetRect.slider(rect, *end_forest, start_forest, 2.0, spinbox_step = 0.025, theme = *slider_theme);
            rect.y -= 22;

            {
                pressed := GetRect.base_checkbox(rect, "biome", show_biome, theme = *checkbox_theme, 0);
                show_biome ^= pressed;
                changed |= pressed;
                rect.y -= 22;
            }

            {
                pressed := GetRect.base_checkbox(rect, "height", show_height, theme = *checkbox_theme, 0);
                show_height ^= pressed;
                changed |= pressed;
                rect.y -= 22;
            }

            {
                pressed := GetRect.base_checkbox(rect, "forest", show_forest, theme = *checkbox_theme, 0);
                show_forest ^= pressed;
                changed |= pressed;
                rect.y -= 22;
            }

            if changed && state != .LOADING_FILES {
                state = .GENERATING_BITMAP;
                batch_index = 0;
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

window : Window_Type;
window_width : s32;
window_height : s32;
texture : Simp.Texture;
bitmap_data : [] RGBA;
bitmap : Simp.Bitmap;
quit := false;

image_ofs : Vector2;
image_scale : float = 1.0;
image_scale_log_2 : float = 0.0;

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

#import "Basic";
#import "File";
#import "File_Utilities";
#import "stb_image_write";
#import "Math";
#import "System";
#import "Window_Creation";
Simp :: #import "Simp";
Bitmap :: Simp.Bitmap;
GetRect :: #import "GetRect";
Input :: #import "Input";
#import "Hash_Table";
