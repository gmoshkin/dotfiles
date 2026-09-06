FLUID_State :: struct {
    // Offset is from game world bottom center to display bottom center
    offset_x: int = 0;
    offset_y: int = 0;

    world_size_x: int = 50;
    world_size_y: int = 50;
    world_cells: [] FLUID_Cell;

    window_size_x: int = -1;
    window_size_y: int = -1;

    half_scale := false;

    tick_rate_seconds: float64 = .1;
    next_tick_time: float64 = -1.0;
    tick: int = 0;
    sleeping := false;
    paused := false;

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
        fluid.world_cells = NewArray(fluid.world_size_x * fluid.world_size_y, FLUID_Cell);
        // for *fluid.world_cells it.* = make_cell(.AIR, 0);
    }

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
            case #char ";";
                switch_to_command_line_mode();
                return;

            case #char " ";
                fluid.paused = !fluid.paused;
                if !fluid.paused fluid.sleeping = false;
                return;

            case #char "0"; fluid.offset_x = 0;
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

    while fluid.next_tick_time <= now {
        tick_FLUID();
        fluid.next_tick_time += fluid.tick_rate_seconds;
    }
}

tick_FLUID :: () {
    using context.state;

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

    for x: 0..width - 1 {
        cell := get_cell_ptr(*fluid, x, y);

        pixel := Pixel_Value.id(.GRAY_4);
        if cell {
            pixel = cell_to_pixel_value(cell);
        }

        pixel = get_cell_color(*fluid, x, y);

        print_pixel_value(builder, pixel);
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

screen_to_world :: (fluid: *FLUID_State, screen_x: int, screen_y: int) -> bool, int, int {
    using fluid;

    state := context.state;

    mult := ifx fluid.half_scale then 2 else 1;
    size_offset_x := world_size_x - mult * state.fluid.window_size_x;
    size_offset_y := world_size_y - mult * state.fluid.window_size_y;

    // Divide size_offset_x by 2 because offset_x origin is in the middle (this
    // makes no sense to me as I write this)
    world_x := screen_x + size_offset_x / 2 + offset_x;
    world_y := screen_y + size_offset_y     - offset_y;

    in_bounds := (world_x >= 0 && world_x < world_size_x)
              && (world_y >= 0 && world_y < world_size_y);

    return in_bounds, world_x, world_y;
}

get_cell_ptr :: (fluid: *FLUID_State, screen_x: int, screen_y: int) -> *FLUID_Cell {
    in_bounds, world_x, world_y := screen_to_world(fluid, screen_x, screen_y);

    if !in_bounds return null;

    cell_index := world_y * fluid.world_size_x + world_x;
    return *fluid.world_cells[cell_index];
}

get_cell_color :: (fluid: *FLUID_State, screen_x: int, screen_y: int) -> Pixel_Value {
    in_bounds, world_x, world_y := screen_to_world(fluid, screen_x, screen_y);

    if !in_bounds return Pixel_Value.id(.GRAY_4);

    return Pixel_Value.rgb(
        world_x.(float) / (fluid.world_size_x - 1),
        world_y.(float) / (fluid.world_size_y - 1),
        0,
    );
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
            append(builder, " ");
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
