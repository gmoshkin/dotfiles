FLUID_State :: struct {
    // Offset is from game world bottom center to display bottom center
    offset_x: int = 0;
    offset_y: int = 0;

    world_size_x: int = 50;
    world_size_y: int = 40;
    world_cells: [] FLUID_Cell;
    // `speed_x[i]` comes in to cell `i` and comes out of cell `i-1`
    speed_x: [] float;
    // `speed_y[i]` comes in to cell `i` and comes out of cell `i-1`
    speed_y: [] float;
    boundary: [] bool;

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
        world_square := fluid.world_size_x * fluid.world_size_y;
        fluid.world_cells    = NewArray(world_square, FLUID_Cell);
        fluid.speed_x        = NewArray(world_square, float);
        fluid.speed_y        = NewArray(world_square, float);
        fluid.speed_x_next   = NewArray(world_square, float);
        fluid.speed_y_next   = NewArray(world_square, float);
        // for *fluid.world_cells it.* = make_cell(.AIR, 0);

        fluid.boundary    = NewArray(world_square, bool);
        for *fluid.boundary it.* = true;

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

        array_add(*fluid.input_speed, .{.{1, 1}, .{+1.0,  0.0}});
        array_add(*fluid.input_speed, .{.{xx(fluid.world_size_x - 1), xx(fluid.world_size_y - 1)}, .{-1.0,  0.0}});
    }

    apply_speeds(*fluid, fluid.fixed_speed);

    // fluid.color_scheme. ... = Pixel_Value.id(...);

    fluid.next_tick_time = seconds_since_init();
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
    for inputs {
        x := it.position.x.(int);
        y := it.position.y.(int);
        index := x + fluid.world_size_x * y;
        fluid.speed_x[index] = it.velocity.x;
        fluid.speed_y[index] = it.velocity.y;
    }
}

tick_FLUID :: (fluid: *FLUID_State) {
    for fluid.speed_x { fluid.speed_x_next[it_index] = it; }
    for fluid.speed_y { fluid.speed_y_next[it_index] = it; }

    minimize_divergence(fluid);
    propagate_velocities(fluid);
}

minimize_divergence :: (fluid: *FLUID_State) {
    width  := fluid.world_size_x;
    height := fluid.world_size_y;
    world_square := width * height;

    overrelaxation := fluid.overrelaxation;
    for 1..fluid.divergence_solver_max_steps {
        converged := true;

        for y: 0..height - 1
        for x: 0..width - 1 {
            index       := cell_index(fluid, x    , y    );
            index_west  := cell_index(fluid, x - 1, y    );
            index_east  := cell_index(fluid, x + 1, y    );
            index_north := cell_index(fluid, x    , y - 1);
            index_south := cell_index(fluid, x    , y + 1);

            has_west  := (x > 0);
            has_east  := (x < width  - 1);
            has_north := (y > 0);
            has_south := (y < height - 1);

            from_west  := ifx has_west  then fluid.speed_x[index];
            to_east    := ifx has_east  then fluid.speed_x[index_east];
            from_north := ifx has_north then fluid.speed_y[index];
            to_south   := ifx has_south then fluid.speed_y[index_south];

            d := overrelaxation * (from_west - to_east + from_north - to_south);

            if abs(d) < 0.00001 continue;
            converged = false;

            s_west  := ifx has_west  then fluid.boundary[index_west ];
            s_east  := ifx has_east  then fluid.boundary[index_east ];
            s_north := ifx has_north then fluid.boundary[index_north];
            s_south := ifx has_south then fluid.boundary[index_south];

            s := s_west.(float) + s_east.(float) + s_north.(float) + s_south.(float);
            if s == 0 continue;

            dd := d / s;

                              fluid.speed_x_next[index]       += -dd;
            if has_south then fluid.speed_x_next[index_east]  +=  dd;
                              fluid.speed_y_next[index]       += -dd;
            if has_south then fluid.speed_y_next[index_south] +=  dd;
        }

        for fluid.speed_x_next { fluid.speed_x[it_index] = it; }
        for fluid.speed_y_next { fluid.speed_y[it_index] = it; }

        if converged break;
    }
}

propagate_velocities :: (fluid: *FLUID_State) {
    for y: 0..fluid.world_size_y - 1
    for x: 0..fluid.world_size_x - 1 {

    }
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

    state := context.state;

    mult := ifx fluid.half_scale then 2 else 1;
    size_offset_x := world_size_x - mult * state.fluid.window_size_x;
    size_offset_y := world_size_y - mult * state.fluid.window_size_y;

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

get_cell_ptr :: (fluid: *FLUID_State, screen_x: int, screen_y: int) -> *FLUID_Cell {
    index, world_x, world_y := screen_to_world(fluid, screen_x, screen_y);
    if index < 0 return null;

    return *fluid.world_cells[index];
}

get_cell_color :: (fluid: *FLUID_State, screen_x: int, screen_y: int) -> Pixel_Value {
    index, world_x, world_y := screen_to_world(fluid, screen_x, screen_y);
    if index < 0 return Pixel_Value.id(.GRAY_1);

    velocity := Vector2.{fluid.speed_x[index],
                         fluid.speed_y[index]};

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
    width := fluid.world_size_x;
    for *fluid.world_cells {
        x := it_index % width;

        serialize_cell(builder, it);
        if x == width - 1
            append(builder, "\n");
    }
}

deserialize_FLUID :: (input: string, fluid: *FLUID_State) -> bool, string {
    if !input return false, "empty input";

    line_length := find_index_from_left(input, #char "\n");
    if line_length < 0 {
        return false, "each line must end with a newline, didn't find a single one";
    }
    if line_length % 2 != 0 {
        return false,
               tprint("each line must have an even number of characters, first line has %", line_length);
    }

    width := line_length / 2;
    height := count_matches(input, #char "\n");

    if input[input.count - 1] != #char "\n" {
        return false, "last line must end with a newline";
    }

    world_cells := NewArray(width * height, FLUID_Cell);

    tail := input;
    for :lines line, y: input {
        row := y + 1;
        if width * 2 != line.count {
            return false, tprint("%: expected line length %, got line: % '%'",
                                 row, width * 2, line.count, line);
        }

        t := line;
        for x: 0..width - 1 {
            col := x * 2;
            cell: FLUID_Cell;
            ok := deserialize_cell(*t, *cell);
            if !ok
                return false, tprint("%:%: failed to deserialize cell '%'",
                                     row, col, slice(t, 0, 2));

            world_cells[x + y * width] = cell;
        }
    }

    fluid.world_cells = world_cells;
    fluid.world_size_x = width;
    fluid.world_size_y = height;

    return true, "";
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
