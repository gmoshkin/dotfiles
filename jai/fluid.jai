FLUID_State :: struct {
    // Offset is from game world bottom center to display bottom center
    offset_x: int = 0;
    offset_y: int = 0;

    world_size_x: int = 100; // AKA width
    world_size_y: int = 100; // AKA height

    cell_size: float = 1;

/*
      |      v0   |       v1  |       v2  |
    --+-----*-----+-----*-----+-----*-----+--
      |           |           |           |
      |           |           |           |
      *     0     *     1     *     2     *
      |u0         |u1         |u2         |u3
      |      v3   |       v4  |       v5  |
    --+-----*-----+-----*-----+-----*-----+--
      |           |           |           |
      |           |           |           |
      *     3     *     4     *     5     *
      |u4         |u5         |u6         |u7
      |      v6   |       v7  |       v8  |
    --+-----*-----+-----*-----+-----*-----+--
      |           |           |           |
      |           |           |           |
      *     6     *     7     *     8     *
      |u8         |u9         |u10        |u11
      |      v9   |       v10 |       v11 |
    --+-----*-----+-----*-----+-----*-----+--
      |           |           |           |
*/

    // `speed_x[i]` = `uᵢ` comes in to cell `i` and comes out of cell `i-1`
    speed_x: [/*  (W + 1) x H */] float;
    // `speed_y[i]` = `vᵢ` comes in to cell `i` and comes out of cell `i-W`
    speed_y: [/*  W x (H + 1) */] float;

    boundary: [/* W x H */] bool;
    smoke: [/* W x H */] float;
    smoke_sum: float;
    smoke_mult := 1.00;

    speed_x_next: [] float;
    speed_y_next: [] float;

    smoke_next: [] float;
    fixed_smoke: [..] Position_Value;

    input_speed: [..] Position_Velocity;
    fixed_speed: [..] Position_Velocity;

    gravity := Vector2.{0.0, 0.0};

    // dt = 0.1 -> Move 1/10 of the cell per tick
    delta_time: float = 0.1;
    // claude says I'm doing the Jacobi method, because I don't update value in
    // place. In this case overrelaxation doesn't work, and instead you should
    // do underrelaxation.
    overrelaxation := 0.99;
    divergence_solver_max_steps := 100;

    window_size_x: int = -1;
    window_size_y: int = -1;

    half_scale := true;

    tick_rate_seconds: float64 = .01;
    next_tick_time: float64 = -1.0;
    tick: int = 0;
    sleeping := false;
    paused := false;
    step_once := false;

    mouse_down := false;
    screen_mouse_x: int;
    screen_mouse_y: int;

    filepath: string;

    DEBUG := false;
    debug_scale := 10.0;
    debug_pixels: [] Pixel_Value;
    debug_cursor: Vector2;
    debug_need_redraw := false;
    debug_redraw_count: int;

    debug_divergence := false;
    velocity_propagation := true;
    show_smoke := true;
    color_smoke := false;
    max_smoke := 10.0;

    debug_interpolation := true;

    uW, uH: int;
    debug_us: [] float;
    vW, vH: int;
    debug_vs: [] float;

    debug_text := false;
    debug_grid := false;
    debug_color := true;
}

//
// init / resize
//

init_FLUID :: () {
    using context.state;

    on_window_resize_FLUID();

    if fluid.filepath {
        input, ok := my_read_entire_file(fluid.filepath);
        assert(ok, "failed to open file '%'", fluid.filepath);

        ok=, error := deserialize_FLUID(input, *fluid);
        assert(ok, "%:%", fluid.filepath, error);
    } else {
        W := fluid.world_size_x;
        H := fluid.world_size_y;
        fluid.speed_x        = NewArray((W + 1) * H, float);
        fluid.speed_x_next   = NewArray((W + 1) * H, float);
        fluid.speed_y        = NewArray(W * (H + 1), float);
        fluid.speed_y_next   = NewArray(W * (H + 1), float);

        fluid.boundary = NewArray(W * H, bool);
        for *fluid.boundary it.* = true;

        fluid.smoke      = NewArray(W * H, float);
        fluid.smoke_next = NewArray(W * H, float);

        // x0 := 1.0;
        // y0 := (fluid.world_size_y / 2).(float);
        // array_add(*fluid.fixed_speed, .{.{x0 - 1, y0 - 1}, .{-1.0, -1.0}});
        // array_add(*fluid.fixed_speed, .{.{x0    , y0 - 1}, .{ 0.0, -1.0}});
        // array_add(*fluid.fixed_speed, .{.{x0 + 1, y0 - 1}, .{+1.0, -1.0}});
        // array_add(*fluid.fixed_speed, .{.{x0 - 1, y0    }, .{-1.0,  0.0}});
        // array_add(*fluid.fixed_speed, .{.{x0    , y0    }, .{ 0.0,  0.0}});
        // array_add(*fluid.fixed_speed, .{.{x0 + 1, y0    }, .{+1.0,  0.0}});
        // array_add(*fluid.fixed_speed, .{.{x0 - 1, y0 + 1}, .{-1.0, +1.0}});
        // array_add(*fluid.fixed_speed, .{.{x0    , y0 + 1}, .{ 0.0, +1.0}});
        // array_add(*fluid.fixed_speed, .{.{x0 + 1, y0 + 1}, .{+1.0, +1.0}});

        // array_add(*fluid.input_speed, .{.{(W / 2).(float), (H / 2).(float)}, .{+1.0,  0.0}});
        // array_add(*fluid.input_speed, .{.{0    , 0    }, .{+1.0,  0.0}});
        // array_add(*fluid.input_speed, .{.{W-1.0, 0    }, .{ 0.0, +1.0}});
        // array_add(*fluid.input_speed, .{.{W-1.0, H-1.0}, .{-1.0,  0.0}});
        // array_add(*fluid.input_speed, .{.{0    , H-1.0}, .{ 0.0, -1.0}});


        // Smoke stream left to right
        #if true
        {
            array_add(*fluid.input_speed, .{.{0, xx(H / 2 - 1)}, .{10.0,  0.0}});
            array_add(*fluid.input_speed, .{.{0, xx(H / 2    )}, .{10.0,  0.0}});
            array_add(*fluid.input_speed, .{.{0, xx(H / 2 + 1)}, .{10.0,  0.0}});

            array_add(*fluid.fixed_smoke, .{Vector2.{xx 1, xx (H/2)}, 10.0});
        }

        #if false
        {
            array_add(*fluid.input_speed, .{.{xx(W / 2 - 1), 0}, .{0.0,  10.0}});
            array_add(*fluid.input_speed, .{.{xx(W / 2    ), 0}, .{0.0,  10.0}});
            array_add(*fluid.input_speed, .{.{xx(W / 2 + 1), 0}, .{0.0,  10.0}});

            array_add(*fluid.fixed_smoke, .{Vector2.{xx (W/2), 1}, 10.0});
        }

        #if false
        {
            array_add(*fluid.fixed_smoke, .{Vector2.{xx (W/2), 1}, 10.0});
        }

        for Vector2.[
            // .{0, 0},
            // .{W-1.0, 0},
            // .{W-1.0, H-1.0},
            // .{0, H-1.0},
            .{xx(W/2), 0},
        ] {
            // fluid.smoke[xx (it.x + it.y * W)] = 10.0;
        }

        for x: 1..1 for y: (H/2)..(H/2) {
            // array_add(*fluid.fixed_smoke, .{Vector2.{xx x, xx y}, 10.0});
            // fluid.fixed_smoke[x + y * W] = 10.0;
        }
    }

    apply_speeds(*fluid, fluid.fixed_speed);

    // fluid.color_scheme. ... = Pixel_Value.id(...);

    fluid.next_tick_time = seconds_since_init();

    if fluid.DEBUG init_DEBUG(*fluid);
}

init_DEBUG :: (fluid: *FLUID_State) {
    scaled_W := ceil(fluid.world_size_x * fluid.debug_scale).(int);
    scaled_H := ceil(fluid.world_size_x * fluid.debug_scale).(int);

    fluid.debug_pixels = NewArray(scaled_W * scaled_H, Pixel_Value);
    fluid.debug_cursor = .{xx (scaled_W / 2), xx (scaled_H / 2)};
}

draw_DEBUG :: (fluid: *FLUID_State) {
    if !fluid.debug_need_redraw && !fluid.debug_color return;

    W := ceil(fluid.world_size_x * fluid.debug_scale).(int);
    H := ceil(fluid.world_size_y * fluid.debug_scale).(int);
    W2 := W / 2;
    H2 := H / 2;

    s := fluid.debug_scale;
    s2 := s/2;


    // if !fluid.debug_us
    {
        t := fluid.tick * (TAU / 72);

        uW := fluid.world_size_x;
        uH := fluid.world_size_y + 1;

        free(fluid.debug_us.data);
        fluid.debug_us = copy_array(float.[
            -5 , -6 , -7, -3,
            +4 , -12, -8, +4,
            -7 , +8,  +4, +5,
            -4 , +4,  +7, +6,
            -9 , -5,  -4, -7,
        ]);

        vW := fluid.world_size_x + 1;
        vH := fluid.world_size_y;
        free(fluid.debug_vs.data);
        fluid.debug_vs = copy_array(float.[
            +5 , +10, -7, -6, -3,
            +10, +9 , -3, -5, -6,
            +12, +8 , -5, -4, -8,
            +7 , +7 , -7, -3, -9,
        ]);

        for *fluid.debug_us {
            it.* = xx (cos(t * (1 + (it_index * 137) % 3)) * it.*);
        }
        for *fluid.debug_vs {
            it.* = xx (sin(t * (1 + (it_index * 137) % 3)) * it.*);
        }
    }

    if fluid.debug_color {
        for y: 0..H-1 for x: 0..W-1 {
            u := interpolate_speed_x(fluid, .{xx x     , xx y + .5});
            v := interpolate_speed_y(fluid, .{xx x + .5, xx y     });

            phi := atan2(-v, u);
            hue := fmod_cycling(((phi) / TAU * 360), 360);
            color := hsv_to_rgb(.{hue, 1, 1});
            fluid.debug_pixels[x + y * W] = Pixel_Value.rgb(color.x, color.y, color.z);
        }
    } else {
        for *fluid.debug_pixels it.* = Pixel_Value.id(.GRAY_2);
    }

    if fluid.debug_grid {
        {
            x := 0; while x < W { defer x = xx (x + s2);
                y := 0; while y < H { set_rect(fluid, x, y - 2, 5, 1, .GRAY_3); y = xx (y + s2); }
            }
        }
        {
            y := 0; while y < H { defer y = xx (y + s2);
                x := 0; while x < W { set_rect(fluid, x - 2, y, 1, 5, .GRAY_3); x = xx (x + s2); }
            }
        }
        // {
        //     x := 0; while x < W { defer x = xx (x + s);
        //         y := 0; while y < H { set_rect(fluid, x - 1, y - 1, 3, 3, .BLUE); y += s; }
        //     }
        // }
        // {
        //     x := 0; while x < W { defer x = xx (x + s);
        //         y := 0 - s2; while y < H { set_rect(fluid, x - 1, y - 1, 3, 3, .RED); y += s; }
        //     }
        // }
        // {
        //     x := 0 - s2; while x < W { defer x += s;
        //         y := 0; while y < H { set_rect(fluid, x - 1, y - 1, 3, 3, .GREEN); y += s; }
        //     }
        // }


        // x0, y0 := W2 - s2, H2 - s2;
        // x1, y1 := W2 + s2, H2 + s2;

        cx := fluid.debug_cursor.x.(int);
        cy := fluid.debug_cursor.y.(int);

        x0 := cx / s.(int) * s.(int);
        y0 := cy / s.(int) * s.(int);

        x1 := x0 + s.(int);
        y1 := y0 + s.(int);

        ux0, ux1 := x0, x1;
        uy0, uy1: int;
        if (cy - y0) < (y1 - y0) / 2 { uy0 = y0 - s2.(int); uy1 = y1 - s2.(int); }
        else                         { uy0 = y0 + s2.(int); uy1 = y1 + s2.(int); }

        vx0, vx1: int;
        vy0, vy1 := y0, y1;
        if (cx - x0) < (x1 - x0) / 2 { vx0 = x0 - s2.(int); vx1 = x1 - s2.(int); }
        else                         { vx0 = x0 + s2.(int); vx1 = x1 + s2.(int); }

        set_line(fluid, ux0, uy0, ux0, uy1, Pixel_Value.rgb(.5, .1, .1), step=3);
        set_line(fluid, ux0, uy1, ux1, uy1, Pixel_Value.rgb(.5, .1, .1), step=3);
        set_line(fluid, ux1, uy1, ux1, uy0, Pixel_Value.rgb(.5, .1, .1), step=3);
        set_line(fluid, ux1, uy0, ux0, uy0, Pixel_Value.rgb(.5, .1, .1), step=3);

        set_line(fluid, vx0, vy0, vx0, vy1, Pixel_Value.rgb(.3, .5, .1), step=3);
        set_line(fluid, vx0, vy1, vx1, vy1, Pixel_Value.rgb(.3, .5, .1), step=3);
        set_line(fluid, vx1, vy1, vx1, vy0, Pixel_Value.rgb(.3, .5, .1), step=3);
        set_line(fluid, vx1, vy0, vx0, vy0, Pixel_Value.rgb(.3, .5, .1), step=3);


        for x: 0..fluid.uW-1 for y: 0..fluid.uH-1 {
            u := fluid.debug_us[x + y * fluid.uW];
            ux := s.(int)  + x * s.(int);
            uy := s2.(int) + y * s.(int);
            set_line(fluid, ux, uy, ux + xx u, uy, .RED);
        }

        for x: 0..fluid.vW-1 for y: 0..fluid.vH-1 {
            v := fluid.debug_vs[x + y * fluid.vW];
            vx := s2.(int) + x * s.(int);
            vy := s.(int)  + y * s.(int);
            set_line(fluid, vx, vy, vx, vy + xx v, .GREEN);
        }


        set_rect(fluid, cx - 1, cy - 1, 3, 3, .WHITE);

        // TODO I think the coordinates should be translated into world space
        cu := interpolate_speed_x(fluid, .{xx cx, xx cy});
        cv := interpolate_speed_y(fluid, .{xx cx, xx cy});

        set_line(fluid, cx, cy, cx + xx cu, cy, .RED);
        set_cell(fluid, cx + xx cu, cy, Vector3.{.9, .5, .5});

        set_line(fluid, cx, cy, cx, cy + xx cv, .GREEN);
        set_cell(fluid, cx, cy + xx cv, Vector3.{.5, .9, .2});

        set_line(fluid, cx, cy, cx + xx cu, cy + xx cv, .WHITE);
        set_cell(fluid, cx + xx cu, cy + xx cv, .GRAY_23);

        // set_rect(fluid, x0 - 1, y0 - 1, 3     , 3     , .BLUE);
        // set_line(fluid, x0    , y0    , x0 + 3, y0 + 4, .WHITE);

        // set_rect(fluid, x0 - 1, y1 - 1, 3     , 3     , .BLUE);
        // set_line(fluid, x0    , y1    , x0 + 4, y1 - 3, .WHITE);

        // set_rect(fluid, x1 - 1, y0 - 1, 3     , 3     , .BLUE);
        // set_line(fluid, x1    , y0    , x1 - 3, y0 + 4, .WHITE);

        // set_rect(fluid, x1 - 1, y1 - 1, 3     , 3     , .BLUE);
        // set_line(fluid, x1    , y1    , x1 - 4, y1 - 3, .WHITE);


        // p0 := Vector2.{xx W2, xx H2};
        // phi := fluid.tick * (TAU / 36);
        // ofs := Vector2.{cos(phi), sin(phi)};
        // p1 := p0 + ofs * 20;
        // set_rect(fluid, xx (p0.x - 1), xx (p0.y - 1), 3, 3, .YELLOW);
        // set_rect(fluid, xx (p1.x - 1), xx (p1.y - 1), 3, 3, .YELLOW);
        // set_line(fluid, xx p0.x, xx p0.y, xx p1.x, xx p1.y, .RED);
    }

    fluid.debug_need_redraw = false;
    fluid.debug_redraw_count += 1;
}

to_pixel_value :: (id: Color_8bit) -> Pixel_Value #expand { return Pixel_Value.id(id); }
to_pixel_value :: (color: Pixel_Value) -> Pixel_Value #expand { return color; }
to_pixel_value :: (rgb: Vector3) -> Pixel_Value #expand { return Pixel_Value.rgb(rgb.x, rgb.y, rgb.z); }

COLOR_TYPES :: Type.[Pixel_Value, Color_8bit, Vector3];

set_cell :: (fluid: *FLUID_State, x: int, y: int, color: $T/COLOR_TYPES) {
    index := cell_index(fluid, x, y);
    if !(x >= 0 && x < fluid.world_size_x && y >= 0 && y < fluid.world_size_y) return;
    fluid.debug_pixels[index] = to_pixel_value(color);
}

set_rect :: (fluid: *FLUID_State, x0: int, y0: int, w: int, h: int, _color: $T/COLOR_TYPES) {
    color := to_pixel_value(_color);
    for x: x0..x0 + h - 1 for y: y0..y0 + w - 1 {
        inline set_cell(fluid, x, y, color);
    }
}

set_line :: (fluid: *FLUID_State, _x0: int, _y0: int, _x1: int, _y1: int, _color: $T/COLOR_TYPES, step := 1) {
    color := to_pixel_value(_color);
    x0, x1, y0, y1 := _x0, _x1, _y0, _y1;

    dx := abs(x1 - x0);
    dy := abs(y1 - y0);

    if dx > dy {
        if x0 > x1 { swap(*x0, *x1); swap(*y0, *y1); }
        if x0 == x1 {
            if y0 > y1 swap(*y0, *y1);
            y := y0; while y <= y1 { inline set_cell(fluid, x0, y, color); y += step; }
            return;
        }

        x := x0;
        while x <= x1 {
            t := (x - x0).(float) / (x1 - x0);
            y := lerp(y0.(float), y1.(float), t) + .5;
            inline set_cell(fluid, x, xx y, color);
            x += step;
        }
    } else {
        if y0 > y1 { swap(*y0, *y1); swap(*x0, *x1); }
        if y0 == y1 {
            if x0 > x1 swap(*x0, *x1);
            x := x0; while x <= x1 { inline set_cell(fluid, x, y0, color); x += step; }
            return;
        }

        y := y0;
        while y <= y1 {
            t := (y - y0).(float) / (y1 - y0);
            x := lerp(x0.(float), x1.(float), t) + .5;
            inline set_cell(fluid, xx x, y, color);
            y += step;
        }
    }
}

on_window_resize_FLUID :: () {
    using context.state;

    // Assuming the pixel is '██'
    fluid.window_size_x = (terminal_size.cols / 2);
    fluid.window_size_y = (terminal_size.rows - 2); // 2 x @status_line
}

//
// input
//

handle_input_event_FLUID :: (event: Input_Event) {
    using context.state;

    // fluid.debug_need_redraw = true;

    if input_mode == {
    case .INPUT_COMMAND;
        handle_input_event_in_input_command_mode(event);
        return;

    case .NAVIGATE;
        if (event.kind == .CHARACTER) && (event.char == #char "q") {
            should_exit = true;
            return;
        }

        if event.kind == {
        case .CHARACTER;
            if event.char == {
            case ";";
                switch_to_command_line_mode();
                return;

            case " ";
                fluid.paused = !fluid.paused;
                if !fluid.paused fluid.sleeping = false;
                return;

            case ".";
                fluid.step_once = true;
                return;

            case "0"; fluid.offset_x = 0;
                      fluid.offset_y = 0;
                      return;

            case "h"; fluid.debug_cursor.x -= 1;
            case "j"; fluid.debug_cursor.y += 1;
            case "k"; fluid.debug_cursor.y -= 1;
            case "l"; fluid.debug_cursor.x += 1;
            case "H"; fluid.debug_cursor.x -= 10;
            case "J"; fluid.debug_cursor.y += 10;
            case "K"; fluid.debug_cursor.y -= 10;
            case "L"; fluid.debug_cursor.x += 10;

            }
        case .KEY_UP;    fluid.offset_y += ifx event.modifiers & .SHIFT then 10 else 1; return;
        case .KEY_DOWN;  fluid.offset_y -= ifx event.modifiers & .SHIFT then 10 else 1; return;
        case .KEY_LEFT;  fluid.offset_x -= ifx event.modifiers & .SHIFT then 10 else 1; return;
        case .KEY_RIGHT; fluid.offset_x += ifx event.modifiers & .SHIFT then 10 else 1; return;
        }
    }

    assert(pixel_size == .TWO_CHARACTERS);
    mult := ifx fluid.half_scale then 2 else 1;
    fluid.screen_mouse_x = mult * (mouse_position.column - 1) / 2;
    assert(status_line_1_row == 1 && status_line_2_row == -1);
    fluid.screen_mouse_y = mult * (mouse_position.row - 1) - 1; // `-1` for @status_line

    if event.kind == {
        case .MOUSE_LEFT_DOWN; #through;
        case .MOUSE_LEFT_DRAG;
            fluid.mouse_down = true;
        case .MOUSE_RIGHT_DOWN; #through;
        case .MOUSE_RIGHT_DRAG;
            fluid.mouse_down = true;
        case .MOUSE_ANY_UP;
            fluid.mouse_down = false;
    }

    if fluid.mouse_down {
        // enqueue_click(*fluid, fluid.screen_mouse_x, fluid.screen_mouse_y, fluid.click_type);
    }

    return;
}

//
// update / tick
//

update_FLUID :: () {
    using context.state;

    now := seconds_since_init();

    need_step :: () -> bool #expand { return fluid.step_once || fluid.debug_need_redraw; }

    while (fluid.next_tick_time <= now) || need_step() {
        do_tick := !fluid.paused || need_step();

        if do_tick apply_speeds(*fluid, fluid.fixed_speed);

        if fluid.input_speed {
            apply_speeds(*fluid, fluid.input_speed);
            fluid.input_speed.count = 0;
        }

        if do_tick {
            apply_gravity(*fluid, fluid.gravity);
            // t := sin(fluid.tick * fluid.tick_rate_seconds) * .05;
            // apply_gravity(*fluid, .{xx t, 0});
            apply_smoke(*fluid, fluid.fixed_smoke);

            tick_FLUID(*fluid);
        }

        fluid.next_tick_time = min(fluid.next_tick_time, now) + fluid.tick_rate_seconds;
        fluid.step_once = false;
        fluid.debug_need_redraw = false;
    }
}

Position_Velocity :: struct { position: Vector2; velocity: Vector2; };

apply_speeds :: (fluid: *FLUID_State, inputs: [] Position_Velocity) {
    W := fluid.world_size_x;
    for inputs {
        x := it.position.x.(int);
        y := it.position.y.(int);
        fluid.speed_x[x + y * (W + 1)] = it.velocity.x;
        fluid.speed_y[x + y * (W    )] = it.velocity.y;
    }
}

apply_gravity :: (fluid: *FLUID_State, gravity: Vector2) {
    uW := fluid.world_size_x + 1;
    uH := fluid.world_size_y;
    vW := fluid.world_size_x;
    vH := fluid.world_size_y + 1;

    if abs(gravity.x) > 0.00001 {
        // Don't update the boundary!
        for y: 0 .. uH - 1
        for x: 1 .. uW - 2 {
            fluid.speed_x[x + y * uW] += gravity.x;
        }
    }
    if abs(gravity.y) > 0.00001 {
        for y: 1 .. vH - 2
        for x: 0 .. vW - 1 {
            fluid.speed_y[x + y * vW] += gravity.y;
        }
    }
}

Position_Value :: struct { p: Vector2; v: float; }

apply_smoke :: (fluid: *FLUID_State, inputs: [] Position_Value) {
    W := fluid.world_size_x;
    for inputs {
        x, y := it.p.x.(int), it.p.y.(int);
        fluid.smoke[x + y * W] = it.v;
    }
}

tick_FLUID :: (fluid: *FLUID_State) {
    if fluid.DEBUG draw_DEBUG(fluid);

    for fluid.speed_x  fluid.speed_x_next[it_index] = it;
    for fluid.speed_y  fluid.speed_y_next[it_index] = it;

    minimize_divergence(fluid);
    if fluid.velocity_propagation {
        propagate_velocities(fluid);
        propagate_smoke(fluid);
    }

    fluid.tick += 1;
}

minimize_divergence :: (fluid: *FLUID_State) {
    W := fluid.world_size_x;
    H := fluid.world_size_y;

    overrelaxation := fluid.overrelaxation;
    for 1..fluid.divergence_solver_max_steps {
        converged := true;

        for y: 0..H - 1
        for x: 0..W - 1 {
            if !fluid.boundary[x + y * W] continue;

            i_u0 := (x    ) + (y    ) * (W + 1);
            i_u1 := (x + 1) + (y    ) * (W + 1);
            i_v0 := (x    ) + (y    ) * (W    );
            i_v1 := (x    ) + (y + 1) * (W    );

            u0 := fluid.speed_x[i_u0];
            u1 := fluid.speed_x[i_u1];
            v0 := fluid.speed_y[i_v0];
            v1 := fluid.speed_y[i_v1];

            d := overrelaxation * (u0 - u1 + v0 - v1);

            if abs(d) < 0.00001 continue;
            converged = false;

            s_west  := ifx (x > 0    ) then fluid.boundary[x - 1 + (y    ) * W];
            s_east  := ifx (x < W - 1) then fluid.boundary[x + 1 + (y    ) * W];
            s_north := ifx (y > 0    ) then fluid.boundary[x     + (y - 1) * W];
            s_south := ifx (y < H - 1) then fluid.boundary[x     + (y + 1) * W];

            s := s_west.(float) + s_east.(float) + s_north.(float) + s_south.(float);
            if s == 0 continue;

            dd := d / s;

            if s_west  fluid.speed_x_next[i_u0] += -dd;
            if s_east  fluid.speed_x_next[i_u1] +=  dd;
            if s_north fluid.speed_y_next[i_v0] += -dd;
            if s_south fluid.speed_y_next[i_v1] +=  dd;
        }

        for fluid.speed_x_next  fluid.speed_x[it_index] = it;
        for fluid.speed_y_next  fluid.speed_y[it_index] = it;

        if converged break;
    }
}

divergence :: (fluid: *FLUID_State, x: int, y: int) -> float {
    W := fluid.world_size_x;
    H := fluid.world_size_y;

    i_u0 := (x    ) + (y    ) * (W + 1);
    i_u1 := (x + 1) + (y    ) * (W + 1);
    i_v0 := (x    ) + (y    ) * (W    );
    i_v1 := (x    ) + (y + 1) * (W    );

    u0 := fluid.speed_x[i_u0];
    u1 := fluid.speed_x[i_u1];
    v0 := fluid.speed_y[i_v0];
    v1 := fluid.speed_y[i_v1];

    d := (u0 - u1 + v0 - v1);
    return d;
}

/*
      |      v0   |       v1  |       v2  |
    --+-----*-----+-----*-----+-----*-----+--
      |           |           |           |
      |           |           |           |
      *     0     *     1     *     2     *
      |u0         |u1         |u2         |u3
      |      v3   |       v4  |       v5  |
    --+-----*-----+-----*-----+-----*-----+--
      |           |           |           |
      |           |           |           |
      *     3     *     4     *     5     *
      |u4         |u5         |u6         |u7
      |      v6   |       v7  |       v8  |
    --+-----*-----+-----*-----+-----*-----+--
      |           |           |           |
      |           |           |           |
      *     6     *     7     *     8     *
      |u8         |u9         |u10        |u11
      |      v9   |       v10 |       v11 |
    --+-----*-----+-----*-----+-----*-----+--
      |           |           |           |
 */
propagate_velocities :: (fluid: *FLUID_State) {
    uW := fluid.world_size_x + 1;
    uH := fluid.world_size_y;
    vW := fluid.world_size_x;
    vH := fluid.world_size_y + 1;

    us := fluid.speed_x;
    vs := fluid.speed_y;
    dt := fluid.delta_time;
    us_out := fluid.speed_x_next;
    vs_out := fluid.speed_y_next;

    // speed_x
    for y: 0 .. uH - 1
    for x: 1 .. uW - 2 {
        position := Vector2.{xx x, y + .5};

        v00 := vs[(x - 1) + (y    ) * vW];
        v10 := vs[(x    ) + (y    ) * vW];
        v01 := vs[(x - 1) + (y + 1) * vW];
        v11 := vs[(x    ) + (y + 1) * vW];

        velocity := Vector2.{ us[x + y * uW],
                              (v00 + v10 + v01 + v11) / 4 };

        old_position := position - velocity * dt;
        old_position.y -= .5;

        r := 0.0;
        // r = ((random_get_zero_to_one_new() -.5) / 100).(float);
        us_out[x + y * uW] = r + inline interpolate_speed_x(fluid, old_position);
    }
    for y: 0 .. uH - 1
    // Boundary doesn't change
    for x: int.[0, uW - 1] {
        us_out[x + y * uW] = us[x + y * uW];
    }

    // speed_y
    for y: 1 .. vH - 2
    for x: 0 .. vW - 1 {
        position := Vector2.{x + .5, xx y};

        u00 := us[(x    ) + (y - 1) * uW];
        u10 := us[(x + 1) + (y - 1) * uW];
        u01 := us[(x    ) + (y    ) * uW];
        u11 := us[(x + 1) + (y    ) * uW];

        velocity := Vector2.{ (u00 + u10 + u01 + u11) / 4,
                              vs[x + y * vW] };

        old_position := position - velocity * dt;
        old_position.x -= .5;

        r := 0.0;
        // r = ((random_get_zero_to_one_new() - .5) / 100).(float);
        vs_out[x + y * vW] = r + inline interpolate_speed_y(fluid, old_position);
    }
    for y: int.[0, vH - 1]
    // Boundary doesn't change
    for x: 0 .. vW - 1 {
        vs_out[x + y * vW] = vs[x + y * vW];
    }

    for us_out us[it_index] = it;
    for vs_out vs[it_index] = it;
}

propagate_smoke :: (fluid: *FLUID_State) {
    W := fluid.world_size_x;
    H := fluid.world_size_y;
    dt := fluid.delta_time;

    smoke      := fluid.smoke;
    smoke_next := fluid.smoke_next;

    // speed_x
    for y: 0 .. H - 1
    for x: 0 .. W - 1 {
        if !fluid.boundary[x + y * W] continue;

        p := Vector2.{x + .5, y + .5};

        velocity := interpolate_speed_mid(fluid, p);
        // velocity := Vector2.{ interpolate_speed_x(fluid, p),
        //                       interpolate_speed_y(fluid, p) };

        old_p := p - velocity * dt;
        // `p` was offset by `+.5`, so `old_p` needs to be offset back by `-.5`
        // Without it the smoke is moving with 0 speeds everywhere
        old_p -= .{.5, .5};

        // Don't forget to do floor, so that negative values are handled correctly
        old_i0, old_j0 := floor(old_p.x).(int), floor(old_p.y).(int);
        old_i1, old_j1 := old_i0 + 1          , old_j0 + 1;

        old_i0_ok := (old_i0 >= 0) && (old_i0 < W);
        old_i1_ok := (old_i1 >= 0) && (old_i1 < W);
        old_j0_ok := (old_j0 >= 0) && (old_j0 < H);
        old_j1_ok := (old_j1 >= 0) && (old_j1 < H);

        s00 := ifx (old_i0_ok && old_j0_ok) smoke[(old_i0) + (old_j0) * W];
        s01 := ifx (old_i0_ok && old_j1_ok) smoke[(old_i0) + (old_j1) * W];
        s10 := ifx (old_i1_ok && old_j0_ok) smoke[(old_i1) + (old_j0) * W];
        s11 := ifx (old_i1_ok && old_j1_ok) smoke[(old_i1) + (old_j1) * W];

        tx := old_p.x - old_i0;
        ty := old_p.y - old_j0;

        s := lerp( lerp(s00, s10, tx),
                   lerp(s01, s11, tx), ty );

        smoke_next[x + y * W] = s * fluid.smoke_mult;
    }

    fluid.smoke_sum = 0;
    for smoke_next {
        smoke[it_index] = it;
        fluid.smoke_sum += it;
    }
}

/*
      |      v0   |       v1  |       v2  |
    --+-----*-----+-----*-----+-----*-----+--
      |           |           |           |
      |           |           |           |
      *     0     *     1     *     2     *
      |u0         |u1         |u2         |u3
      |      v3   |       v4  |       v5  |
    --+-----*-----+-----*-----+-----*-----+--
      |           |           |           |
      |           |           |           |
      *     3     *     4     *     5     *
      |u4         |u5         |u6         |u7
      |      v6   |       v7  |       v8  |
    --+-----*-----+-----*-----+-----*-----+--
      |           |           |           |
      |           |           |           |
      *     6     *     7     *     8     *
      |u8         |u9         |u10        |u11
      |      v9   |       v10 |       v11 |
    --+-----*-----+-----*-----+-----*-----+--
      |           |           |           |
*/
interpolate_speed_x :: (fluid: *FLUID_State, using position: Vector2) -> float {
    uW := fluid.world_size_x + 1;
    uH := fluid.world_size_y;
    us := fluid.speed_x;

    // I don't like how there's no .5 anywhere in here even though the grid is
    // staggered. Them .5's are on the caller side, which makes me a bit anxious.

    ui0, uj0 := floor(x).(int),  floor(y).(int);
    ui1, uj1 := ui0 + 1,         uj0 + 1;

    // TODO: If I store extra rows and columns on the edges,
    // I won't have to do these checks everywhere
    ui0_ok := (ui0 >= 0) && (ui0 < uW);
    ui1_ok := (ui1 >= 0) && (ui1 < uW);
    uj0_ok := (uj0 >= 0) && (uj0 < uH);
    uj1_ok := (uj1 >= 0) && (uj1 < uH);

    u00 := ifx (ui0_ok && uj0_ok) us[ui0 + uj0 * uW];
    u01 := ifx (ui0_ok && uj1_ok) us[ui0 + uj1 * uW];
    u10 := ifx (ui1_ok && uj0_ok) us[ui1 + uj0 * uW];
    u11 := ifx (ui1_ok && uj1_ok) us[ui1 + uj1 * uW];

    tx := x - ui0;
    ty := y - uj0;

    u := lerp( lerp(u00, u10, tx),
               lerp(u01, u11, tx), ty );

    return u;
}

interpolate_speed_y :: (fluid: *FLUID_State, using position: Vector2) -> float {
    vW := fluid.world_size_x;
    vH := fluid.world_size_y + 1;
    vs := fluid.speed_y;

    // I don't like how there's no .5 anywhere in here even though the grid is
    // staggered. Them .5's are on the caller side, which makes me a bit anxious.

    vi0, vj0 := floor(x).(int), floor(y).(int);
    vi1, vj1 := vi0 + 1,        vj0 + 1;

    // TODO: If I store extra rows and columns on the edges,
    // I won't have to do these checks everywhere
    vi0_ok := (vi0 >= 0) && (vi0 < vW);
    vi1_ok := (vi1 >= 0) && (vi1 < vW);
    vj0_ok := (vj0 >= 0) && (vj0 < vH);
    vj1_ok := (vj1 >= 0) && (vj1 < vH);

    v00 := ifx (vi0_ok && vj0_ok) vs[vi0 + vj0 * vW];
    v01 := ifx (vi0_ok && vj1_ok) vs[vi0 + vj1 * vW];
    v10 := ifx (vi1_ok && vj0_ok) vs[vi1 + vj0 * vW];
    v11 := ifx (vi1_ok && vj1_ok) vs[vi1 + vj1 * vW];

    tx := x - vi0;
    ty := y - vj0;

    v := lerp( lerp(v00, v10, tx),
               lerp(v01, v11, tx), ty );

    return v;
}

interpolate_speed_mid :: (fluid: *FLUID_State, position: Vector2) -> Vector2 {
    x, y := position.x.(int), position.y.(int);

    u0 := fluid.speed_x[(x    ) + (y    ) * (fluid.world_size_x + 1)];
    u1 := fluid.speed_x[(x + 1) + (y    ) * (fluid.world_size_x + 1)];
    u := (u0 + u1) / 2;

    v0 := fluid.speed_y[(x    ) + (y    ) * (fluid.world_size_x    )];
    v1 := fluid.speed_y[(x    ) + (y + 1) * (fluid.world_size_x    )];
    v := (v0 + v1) / 2;

    return .{u, v};
}

#run {
    assert(floor(-0.5) == -1.0);
    assert(floor(-1.5) == -2.0);
    assert(floor(-11231312.1) == -11231313.0);
}

get_speed_indexes :: inline (fluid: *FLUID_State, x: int, y: int) -> (i_u0: int, i_u1: int, i_v0: int, i_v1: int) {
    W := fluid.world_size_x;
    H := fluid.world_size_y;

    i_u0 := (x    ) + (y    ) * (W + 1);
    i_u1 := (x + 1) + (y    ) * (W + 1);
    i_v0 := (x    ) + (y    ) * (W    );
    i_v1 := (x    ) + (y + 1) * (W    );

    return i_u0, i_u1, i_v0, i_v1;
}

//
// render
//

build_line_buffer_for_FLUID :: () -> [] string {
    using context.state;

    line_buffer: [..] string;
    line_buffer.allocator = temp;
    array_reserve(*line_buffer, main_window_height);

    height := fluid.window_size_y;
    assert(pixel_size == .TWO_CHARACTERS);
    for y : 0..height - 1 {
        builder: String_Builder;
        builder.allocator = temp;

        if fluid.half_scale then build_line_for_FLUID_half_scale(*builder, y);
        else                     build_line_for_FLUID           (*builder, y);

        append(*builder, "\e[0m");
        append(*builder, "\n");

        array_add(*line_buffer, builder_to_string(*builder,, temp));
    }

    return line_buffer;
}

build_line_for_FLUID :: (builder: *String_Builder, y: int) {
    using context.state;

    width := fluid.window_size_x;

    last_color: Pixel_Value;
    for x: 0..width - 1 {
        pixel := get_cell_color(*fluid, x, y);

        if x == 0 || pixel != last_color {
            print_pixel_value(builder, pixel);
            last_color = pixel;
        }
        append(builder, "  ");
    }
}

build_line_for_FLUID_half_scale :: (builder: *String_Builder, _y: int) {
    using context.state;

    width := 2 * fluid.window_size_x;
    y := 2 * _y;

    text :: "all work and no play makes jack a dull boy";

    last_top, last_bottom: Pixel_Value;
    for x: 0..width - 1 {
        pixel_top    := get_cell_color(*fluid, x, y);
        pixel_bottom := get_cell_color(*fluid, x, y + 1);

        changed := x == 0 || (pixel_top != last_top) || (pixel_bottom != last_bottom);
        if changed {
            if pixel_top != pixel_bottom {
                inline print_pixel_value(builder, pixel_top, fg=true);
            }
            inline print_pixel_value(builder, pixel_bottom, fg=false);

            last_top, last_bottom = pixel_top, pixel_bottom;
        }

        if pixel_top == pixel_bottom {
            append(builder, " ");
        } else if fluid.debug_text {
            append(builder, text[x % text.count]);
        } else {
            append(builder, "▀");
        }
    }
}

//
// FLUID_Cell
//

FLUID_Cell :: struct {

}

cell_to_pixel_value :: (cell: *FLUID_Cell) -> Pixel_Value {
    return Pixel_Value.rgb(1, 0, 1);
}

serialize_cell :: (builder: *String_Builder, cell: *FLUID_Cell) {
    assert(false, "not implemented");
}

deserialize_cell :: (builder: *string, cell: *FLUID_Cell) -> bool {
    assert(false, "not implemented");
    return false;
}

screen_to_world :: (fluid: *FLUID_State, screen_x: int, screen_y: int) -> (index: int, x: int, y: int) {
    using fluid;

    mult := ifx half_scale then 2 else 1;
    size_offset_x := world_size_x - mult * window_size_x;
    size_offset_y := world_size_y - mult * window_size_y;

    // Divide size_offset_x by 2 because offset_x origin is in the middle (this
    // makes no sense to me as I write this)
    world_x := screen_x + size_offset_x / 2 + offset_x;
    world_y := screen_y + size_offset_y / 2 - offset_y;

    in_bounds := (world_x >= 0 && world_x < world_size_x)
              && (world_y >= 0 && world_y < world_size_y);
    if !in_bounds return -1, world_x, world_y;

    return cell_index(fluid, world_x, world_y), world_x, world_y;
}

cell_index :: inline (fluid: *FLUID_State, world_x: int, world_y: int) -> int {
    return world_y * fluid.world_size_x + world_x;
}

get_cell_color :: (fluid: *FLUID_State, screen_x: int, screen_y: int) -> Pixel_Value {
    W := fluid.world_size_x;
    index, world_x, world_y := screen_to_world(fluid, screen_x, screen_y);
    if index < 0 return Pixel_Value.id(.GRAY_1);

    if fluid.DEBUG return fluid.debug_pixels[index];

    if !fluid.boundary[index] return Pixel_Value.id(.GRAY_2);

    if fluid.debug_divergence {
        d := divergence(fluid, world_x, world_y);
        v := 1 / (1 + exp(-d));
        color := hsv_to_rgb(.{0, 0, v});
        return Pixel_Value.rgb(color.x, color.y, color.z);
    }

    if fluid.color_smoke {
        W := fluid.world_size_x;
        s := fluid.smoke[world_x + world_y * W];
        v := s / fluid.max_smoke;
        return color_from_velocity(fluid, world_x, world_y, v);
    }
    if fluid.show_smoke {
        return color_from_smoke(fluid, world_x, world_y);
    } else {
        return color_from_velocity(fluid, world_x, world_y, 1);
    }
}

color_from_velocity :: (fluid: *FLUID_State, world_x: int, world_y: int, v: float) -> Pixel_Value {
    velocity: Vector2 = ---;
    if !fluid.debug_interpolation {
        velocity = interpolate_speed_mid(fluid, .{xx world_x + .5, xx world_y + .5});
    } else {
        velocity.x = interpolate_speed_x(fluid, .{xx world_x     , xx world_y + .5});
        velocity.y = interpolate_speed_y(fluid, .{xx world_x + .5, xx world_y     });
    }

    // velocity := Vector2.{fluid.speed_x[(world_x    ) + (world_y    ) * (W + 1)] +
    //                      fluid.speed_x[(world_x + 1) + (world_y    ) * (W + 1)],
    //                      fluid.speed_y[(world_x    ) + (world_y    ) * (W    )] +
    //                      fluid.speed_y[(world_x    ) + (world_y + 1) * (W    )]};

    value := length(velocity);
    if value == 0 return Pixel_Value.id(.GRAY_4);

    is_nan, is_inf := is_nan_is_inf(value);
    if is_nan || is_inf return Pixel_Value.id(.BLACK);

    direction := velocity / value;
    // My y goes from top to bottom, so I have to reverse it here
    phi := atan2(-direction.y, direction.x);
    hue := fmod_cycling(((phi) / TAU * 360), 360);
    color := hsv_to_rgb(.{hue, 1, v});
    return Pixel_Value.rgb(color.x, color.y, color.z);
}

color_from_smoke :: (fluid: *FLUID_State, world_x: int, world_y: int) -> Pixel_Value {
    W := fluid.world_size_x;
    s := fluid.smoke[world_x + world_y * W];

    color := hsv_to_rgb(.{0, 0, min(s / fluid.max_smoke, 1.0)});
    return Pixel_Value.rgb(color.x, color.y, color.z);
}

//
// serialize / deserialize
//

save_to_file_FLUID :: (filepath: string, fluid: *FLUID_State) -> bool {
    builder: String_Builder;
    builder.allocator = temp;

    serialize_FLUID(*builder, fluid);

    ok := write_entire_file(filepath, builder_to_string(*builder,, temp));
    return ok;
}

serialize_FLUID :: (builder: *String_Builder, fluid: *FLUID_State) {
}

deserialize_FLUID :: (input: string, fluid: *FLUID_State) -> bool, string {
    return false, "not implemented";
}

//
// @status_line
//

status_line_1_FLUID :: (builder: *String_Builder, side: Status_Line_Side) {
    using context.state;

    assert(side == .LEFT);

    if #complete side == {
    case .LEFT;
        print(builder, "smoke: %", fmt(fluid.smoke_sum, 1));

        if fluid.paused {
            append(builder, " ");
            append(builder, "\e[31m");
            append(builder, "PAUSED");
            append(builder, "\e[0m");
        }

    case .RIGHT; assert(false);
    }
}

status_line_1_buffer_number_FLUID :: () -> string {
    using context.state;

    builder: String_Builder;
    builder.allocator = temp;

    append(*builder, "\e[2;37m"); // color gray (dark white)
    print(*builder, "#%", fluid.tick);
    append(*builder, "\e[0m");
    return builder_to_string(*builder,, temp);
}


status_line_2_render_counter_FLUID :: () -> int {
    using context.state;

    return fluid.debug_redraw_count;
}


//
// @console
//

console_commands_FLUID :: (console_commands: *[..] Command) {
    array_add(console_commands, make_command("debug_color",          #bake_arguments console_toggle_fluid(field="debug_color")));
    array_add(console_commands, make_command("debug_text",           #bake_arguments console_toggle_fluid(field="debug_text")));
    array_add(console_commands, make_command("debug_grid",           #bake_arguments console_toggle_fluid(field="debug_grid")));
    array_add(console_commands, make_command("debug_interpolation",  #bake_arguments console_toggle_fluid(field="debug_interpolation")));
    array_add(console_commands, make_command("show_smoke",           #bake_arguments console_toggle_fluid(field="show_smoke")));
    array_add(console_commands, make_command("color_smoke",          #bake_arguments console_toggle_fluid(field="color_smoke")));
    array_add(console_commands, make_command("max_smoke",            #bake_arguments console_set_fluid(field="max_smoke", T=float)));
    array_add(console_commands, make_command("delta_time",           #bake_arguments console_set_fluid(field="delta_time", T=float)));
    array_add(console_commands, make_command("overrelaxation",       #bake_arguments console_set_fluid(field="overrelaxation", T=float)));
    array_add(console_commands, make_command("gravity",              #bake_arguments console_set_fluid(field="gravity", T=Vector2)));
    array_add(console_commands, make_command("smoke_mult",           #bake_arguments console_set_fluid(field="smoke_mult", T=float)));
}

console_toggle_fluid :: (field: string) -> bool, string {
    field_pointer := get_field_pointer(*context.state.fluid, field, bool);
    assert(field_pointer != null, "%", field);

    field_pointer.* = !field_pointer.*;

    // context.state.fluid.debug_need_redraw = true;
    // context.state.fluid.sleeping = false;

    return true, "";
}

console_set_fluid :: (field: string, $T: Type, value: T) -> bool, string {
    field_pointer := get_field_pointer(*context.state.fluid, field, T);
    assert(field_pointer != null, "%", field);

    field_pointer.* = value;

    // context.state.fluid.debug_need_redraw = true;
    // context.state.fluid.sleeping = false;

    return true, "";
}

get_field_pointer :: (s: *$S, field: string, $F: Type) -> *F
#modify { return S.(*Type_Info).type == .STRUCT; }
{
    info := type_info(S);

    for info.members if it.name == field {
        assert(it.type == type_info(F), "% %", field, it.type);
        p := s.(*u8) + it.offset_in_bytes;
        return xx p;
    }

    return null;
}

//
// miscellaneous
//

Int_Vector2 :: struct { x: int; y: int; }

operator + :: inline (v: Int_Vector2, a: int) -> Int_Vector2 { return .{v.x + a, v.y + a}; }
operator - :: inline (v: Int_Vector2, a: int) -> Int_Vector2 { return .{v.x - a, v.y - a}; }
operator * :: inline (v: Int_Vector2, a: int) -> Int_Vector2 { return .{v.x * a, v.y * a}; }
operator / :: inline (v: Int_Vector2, a: int) -> Int_Vector2 { return .{v.x / a, v.y / a}; }

operator + :: inline (a: Int_Vector2, b: Int_Vector2) -> Int_Vector2 { return .{a.x + b.x, a.y + b.y}; }
operator - :: inline (a: Int_Vector2, b: Int_Vector2) -> Int_Vector2 { return .{a.x - b.x, a.y - b.y}; }
operator * :: inline (a: Int_Vector2, b: Int_Vector2) -> Int_Vector2 { return .{a.x * b.x, a.y * b.y}; }
operator / :: inline (a: Int_Vector2, b: Int_Vector2) -> Int_Vector2 { return .{a.x / b.x, a.y / b.y}; }

dot :: inline (a: Int_Vector2, b: Int_Vector2) -> int {
    return a.x * b.x + a.y * b.y;
}

#import "Math";
#import "Color_Interpolation";
