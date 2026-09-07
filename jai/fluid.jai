FLUID_State :: struct {
    // Offset is from game world bottom center to display bottom center
    offset_x: int = 0;
    offset_y: int = 0;

    world_size_x: int = 50; // AKA width
    world_size_y: int = 40; // AKA height

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

    speed_x_next: [] float;
    speed_y_next: [] float;

    input_speed: [..] Position_Velocity;
    fixed_speed: [..] Position_Velocity;

    delta_time: float = 0.01;
    overrelaxation := 0.99;
    divergence_solver_max_steps := 100;

    window_size_x: int = -1;
    window_size_y: int = -1;

    half_scale := false;

    tick_rate_seconds: float64 = .1;
    next_tick_time: float64 = -1.0;
    tick: int = 0;
    sleeping := false;
    paused := true;
    step_once := false;

    mouse_down := false;
    screen_mouse_x: int;
    screen_mouse_y: int;

    filepath: string;

    DEBUG := true;
    debug_pixels: [] Pixel_Value;
    debug_cursor: Vector2;
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

        fluid.smoke = NewArray(W * H, float);

        x0 := 1.0;
        y0 := (fluid.world_size_y / 2).(float);
        // array_add(*fluid.fixed_speed, .{.{x0 - 1, y0 - 1}, .{-1.0, -1.0}});
        // array_add(*fluid.fixed_speed, .{.{x0    , y0 - 1}, .{ 0.0, -1.0}});
        // array_add(*fluid.fixed_speed, .{.{x0 + 1, y0 - 1}, .{+1.0, -1.0}});
        // array_add(*fluid.fixed_speed, .{.{x0 - 1, y0    }, .{-1.0,  0.0}});
        // array_add(*fluid.fixed_speed, .{.{x0    , y0    }, .{ 0.0,  0.0}});
        // array_add(*fluid.fixed_speed, .{.{x0 + 1, y0    }, .{+1.0,  0.0}});
        // array_add(*fluid.fixed_speed, .{.{x0 - 1, y0 + 1}, .{-1.0, +1.0}});
        // array_add(*fluid.fixed_speed, .{.{x0    , y0 + 1}, .{ 0.0, +1.0}});
        // array_add(*fluid.fixed_speed, .{.{x0 + 1, y0 + 1}, .{+1.0, +1.0}});

        array_add(*fluid.input_speed, .{.{(W / 2).(float), (H / 2).(float)}, .{+1.0,  0.0}});
        // array_add(*fluid.input_speed, .{.{xx(fluid.world_size_x), xx(fluid.world_size_y - 1)}, .{-1.0,  0.0}});
    }

    apply_speeds(*fluid, fluid.fixed_speed);

    // fluid.color_scheme. ... = Pixel_Value.id(...);

    fluid.next_tick_time = seconds_since_init();

    if fluid.DEBUG init_DEBUG(*fluid);
}

init_DEBUG :: (fluid: *FLUID_State) {
    fluid.debug_pixels = NewArray(fluid.world_size_x * fluid.world_size_y, Pixel_Value);
    fluid.debug_cursor = .{xx (fluid.world_size_x / 2), xx (fluid.world_size_y / 2)};
}

draw_DEBUG :: (fluid: *FLUID_State) {
    for *fluid.debug_pixels it.* = Pixel_Value.id(.GRAY_2);

    W := fluid.world_size_x;
    H := fluid.world_size_y;
    W2 := W / 2;
    H2 := H / 2;

    s := 48;
    s2 := s/2;

    ox := W2 - s2 - s * (W / s / 2);
    oy := H2 - s2 - s * (H / s / 2);

    { x := ox;
      while x < W { y := oy;
                    while y < H { set_rect(fluid, x, y - 2, 5, 1, .GRAY_3); y += s2; } x += s2; } }
    { y := oy;
      while y < H { x := ox;
                    while x < W { set_rect(fluid, x - 2, y, 1, 5, .GRAY_3); x += s2; } y += s2; } }
    { x := ox;
      while x < W { y := oy;
                    while y < H { set_rect(fluid, x - 1, y - 1, 3, 3, .BLUE); y += s; } x += s; } }
    { x := ox;
      while x < W { y := oy - s2;
                    while y < H { set_rect(fluid, x - 1, y - 1, 3, 3, .RED); y += s; } x += s; } }
    { x := ox - s2;
      while x < W { y := oy;
                    while y < H { set_rect(fluid, x - 1, y - 1, 3, 3, .GREEN); y += s; } x += s; } }


    // x0, y0 := W2 - s2, H2 - s2;
    // x1, y1 := W2 + s2, H2 + s2;

    cx := fluid.debug_cursor.x.(int);
    cy := fluid.debug_cursor.y.(int);

    x0 := ox + (cx - ox) / s * s;
    y0 := oy + (cy - oy) / s * s;

    x1 := x0 + s;
    y1 := y0 + s;

    ux0, ux1 := x0, x1;
    uy0, uy1: int;
    if (cy - y0) < (y1 - y0) / 2 { uy0 = y0 - s2; uy1 = y1 - s2; }
    else                         { uy0 = y0 + s2; uy1 = y1 + s2; }

    vx0, vx1: int;
    vy0, vy1 := y0, y1;
    if (cx - x0) < (x1 - x0) / 2 { vx0 = x0 - s2; vx1 = x1 - s2; }
    else                         { vx0 = x0 + s2; vx1 = x1 + s2; }

    set_line(fluid, ux0, uy0, ux0, uy1, Pixel_Value.rgb(.5, .1, .1), step=3);
    set_line(fluid, ux0, uy1, ux1, uy1, Pixel_Value.rgb(.5, .1, .1), step=3);
    set_line(fluid, ux1, uy1, ux1, uy0, Pixel_Value.rgb(.5, .1, .1), step=3);
    set_line(fluid, ux1, uy0, ux0, uy0, Pixel_Value.rgb(.5, .1, .1), step=3);

    set_line(fluid, vx0, vy0, vx0, vy1, Pixel_Value.rgb(.3, .5, .1), step=3);
    set_line(fluid, vx0, vy1, vx1, vy1, Pixel_Value.rgb(.3, .5, .1), step=3);
    set_line(fluid, vx1, vy1, vx1, vy0, Pixel_Value.rgb(.3, .5, .1), step=3);
    set_line(fluid, vx1, vy0, vx0, vy0, Pixel_Value.rgb(.3, .5, .1), step=3);


    us := float.[-5 , -6,
                 +4 , -12,
                 -7 , +8];

    vs := float.[+5 , +10, -7,
                 +10, +9 , -3];

    for x: 0..1 for y: 0..2 {
        u := us[x + y * 2];
        ux := W2 - s2 + x * s;
        uy := H2 - s  + y * s;
        set_line(fluid, ux, uy, ux + xx u, uy, .RED);
    }

    for x: 0..2 for y: 0..1 {
        v := vs[x + y * 3];
        vx := W2 - s  + x * s;
        vy := H2 - s2 + y * s;
        set_line(fluid, vx, vy, vx, vy + xx v, .GREEN);
    }


    set_rect(fluid, cx - 1, cy - 1, 3, 3, .WHITE);

    cu: float;
    {
        ui0, uj0 := ux0 / s, uy0 / s;
        ui1, uj1 := ux1 / s, uy1 / s;
        in_bounds :: (i: int, j: int) -> bool #expand {
            return (i >= 0) && (i <= 1) && (j >= 0) && (j <= 2);
        }
        u00 := ifx in_bounds(ui0, uj0) us[ui0 + uj0 * 2];
        u01 := ifx in_bounds(ui0, uj1) us[ui0 + uj1 * 2];
        u10 := ifx in_bounds(ui1, uj0) us[ui1 + uj0 * 2];
        u11 := ifx in_bounds(ui1, uj1) us[ui1 + uj1 * 2];
        tx := (cx - ux0).(float) / (ux1 - ux0);
        ty := (cy - uy0).(float) / (uy1 - uy0);
        cu = lerp(
            lerp(u00, u10, tx),
            lerp(u01, u11, tx),
            ty,
        );
        if cu < 0 then cu -= .5; else cu += .5;
    }

    set_line(fluid, cx, cy, cx + xx cu, cy, .RED);
    set_cell(fluid, cx + xx cu, cy, Vector3.{.9, .5, .5});

    cv: float;
    {
        vi0, vj0 := vx0 / s, vy0 / s;
        vi1, vj1 := vx1 / s, vy1 / s;
        in_bounds :: (i: int, j: int) -> bool #expand {
            return (i >= 0) && (i <= 2) && (j >= 0) && (j <= 1);
        }
        v00 := ifx in_bounds(vi0, vj0) vs[vi0 + vj0 * 3];
        v01 := ifx in_bounds(vi0, vj1) vs[vi0 + vj1 * 3];
        v10 := ifx in_bounds(vi1, vj0) vs[vi1 + vj0 * 3];
        v11 := ifx in_bounds(vi1, vj1) vs[vi1 + vj1 * 3];
        tx := (cx - vx0).(float) / (vx1 - vx0);
        ty := (cy - vy0).(float) / (vy1 - vy0);
        cv = lerp(
            lerp(v00, v10, tx),
            lerp(v01, v11, tx),
            ty,
        );
        if cv < 0 then cv -= .5; else cv += .5;
    }

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

    while (fluid.next_tick_time <= now) || fluid.step_once {
        do_tick := !fluid.paused || fluid.step_once;

        if do_tick apply_speeds(*fluid, fluid.fixed_speed);

        if fluid.input_speed {
            apply_speeds(*fluid, fluid.input_speed);
            fluid.input_speed.count = 0;
        }

        if do_tick tick_FLUID(*fluid);

        fluid.next_tick_time += fluid.tick_rate_seconds;
        fluid.step_once = false;
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

tick_FLUID :: (fluid: *FLUID_State) {
    if fluid.DEBUG draw_DEBUG(fluid);

    for fluid.speed_x  fluid.speed_x_next[it_index] = it;
    for fluid.speed_y  fluid.speed_y_next[it_index] = it;

    minimize_divergence(fluid);
    propagate_velocities(fluid);

    fluid.tick += 1;
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
minimize_divergence :: (fluid: *FLUID_State) {
    W := fluid.world_size_x;
    H := fluid.world_size_y;

    overrelaxation := fluid.overrelaxation;
    for 1..fluid.divergence_solver_max_steps {
        converged := true;

        for y: 0..H - 1
        for x: 0..W - 1 {
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

            if (x > 0    ) fluid.speed_x_next[i_u0] += -dd;
            if (x < W - 1) fluid.speed_x_next[i_u1] +=  dd;
            if (y > 0    ) fluid.speed_y_next[i_v0] += -dd;
            if (y < H - 1) fluid.speed_y_next[i_v1] +=  dd;
        }

        for fluid.speed_x_next  fluid.speed_x[it_index] = it;
        for fluid.speed_y_next  fluid.speed_y[it_index] = it;

        if converged break;
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
propagate_velocities :: (fluid: *FLUID_State) {
    return;

    W := fluid.world_size_x;
    H := fluid.world_size_y;
    us := fluid.speed_x;
    vs := fluid.speed_y;
    dt := fluid.delta_time;
    us_out := fluid.speed_x_next;
    vs_out := fluid.speed_y_next;

    // speed_x
    for y: 0..H - 1
    for x: 1..W - 1 {
        position := Vector2.{xx x, y + .5};

        v00 := ifx (x > 0) vs[(x - 1) + (y    ) * W];
        v10 :=             vs[(x    ) + (y    ) * W];
        v01 := ifx (x > 0) vs[(x - 1) + (y + 1) * W];
        v11 :=             vs[(x    ) + (y + 1) * W];

        velocity: Vector2 = ---;
        velocity.x = us[x + y * (W + 1)];
        velocity.y = (v00 + v10 + v01 + v11) / 4;

        old_position := position - velocity * dt;

        us_out[x + y * (W + 1)] = get_velocity(fluid, old_position).x;
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
get_velocity :: inline (fluid: *FLUID_State, position: Vector2) -> velocity: Vector2 {
    W := fluid.world_size_x;
    H := fluid.world_size_y;
    us := fluid.speed_x;
    vs := fluid.speed_y;

    if position.x < -1   || position.y < -1   return .{};
    if position.x > xx W || position.y > xx H return .{};

    x  := floor(position.x).(int);
    dx := position.x - x;
    y  := floor(position.y).(int);
    dy := position.y - y;

    velocity: Vector2;

    u00 := ifx (x > 0) && (y > 0    ) then us[(x    ) + (y    ) * W];
    u10 := ifx (x < W) && (y > 0    ) then us[(x + 1) + (y    ) * W];
    u01 := ifx (x > 0) && (y < H - 1) then us[(x    ) + (y + 1) * W];
    u11 := ifx (x < W) && (y < H - 1) then us[(x + 1) + (y + 1) * W];

    velocity.x = lerp(lerp(u00, u10, dx),
                      lerp(u01, u11, dx), dy);

    v00 := ifx (x > 0    ) && (y > 0) then vs[(x    ) + (y    ) * W];
    v10 := ifx (x < W - 1) && (y > 0) then vs[(x + 1) + (y    ) * W];
    v01 := ifx (x > 0    ) && (y < H) then vs[(x    ) + (y + 1) * W];
    v11 := ifx (x < W - 1) && (y < H) then vs[(x + 1) + (y + 1) * W];

    return velocity;
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

    for x: 0..width - 1 {
        pixel_top    := get_cell_color(*fluid, x, y);
        pixel_bottom := get_cell_color(*fluid, x, y + 1);

        inline print_pixel_value(builder, pixel_top,    fg=true);
        inline print_pixel_value(builder, pixel_bottom, fg=false);

        append(builder, "▀");
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

    velocity := Vector2.{fluid.speed_x[(world_x    ) + (world_y    ) * (W + 1)] +
                         fluid.speed_x[(world_x + 1) + (world_y    ) * (W + 1)],
                         fluid.speed_y[(world_x    ) + (world_y    ) * (W    )] +
                         fluid.speed_y[(world_x    ) + (world_y + 1) * (W    )]};

    value := length(velocity);
    if value == 0 return Pixel_Value.id(.GRAY_4);

    is_nan, is_inf := is_nan_is_inf(value);
    if is_nan || is_inf return Pixel_Value.id(.BLACK);

    direction := velocity / value;
    // My y goes from top to bottom, so I have to reverse it here
    phi := atan2(-direction.y, direction.x);

    Hue_CYAN   :: #run rgb_to_hsv(Vector3.{0, 1, 1}).x;
    Hue_RED    :: #run rgb_to_hsv(Vector3.{1, 0, 0}).x;

    PI_2 :: PI / 2;

    hue: float;
    // -π   ..  0
    if phi < 0 { t := (phi+PI) / PI; hue = lerp(Hue_CYAN, Hue_RED , t); }
    //  0   ..  π
    else       { t :=  phi     / PI; hue = lerp(Hue_RED , Hue_CYAN, t); }

    hue = fmod_cycling(((phi) / TAU * 360), 360);
    color := hsv_to_rgb(.{hue, 1, 1});
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
        if fluid.paused {
            append(builder, "\e[31m");
            append(builder, "PAUSED");
            append(builder, "\e[0m");
        }

    case .RIGHT; assert(false);
    }
}

//
// @console
//

console_toggle_half_scale_FLUID :: () -> (ok := true, error_message := "") {
    using context.state;

    fluid.half_scale = !fluid.half_scale;
    fluid.sleeping = false;

    return;
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
