SANDBOX_GAME_State :: struct {
    // Offset is from game world bottom center to display bottom center
    offset_x: int = 0;
    offset_y: int = 0;

    world_size_x: int = 50;
    world_size_y: int = 50;
    world_cells: [] SANDBOX_GAME_Cell;

    color_scheme: SANDBOX_GAME_Color_Scheme;
    join_to_half := true;

    tick_rate_seconds: float64 = .1;
    next_tick_time: float64 = -1.0;
    debug_one_tick_per_render := false;
    tick: int = 0;
    sleeping := false;
    paused := false;

    can_mutate_after_ticks: int = 10;
    mutate_rate_one_in: u64 = 50;
    mutate_sand := false;
    mutate_gass := false;

    swap_types: [2] SANDBOX_GAME_Cell_Type;
    swap_timer: float64 = FLOAT64_INFINITY;
    next_swap_time: float64 = FLOAT64_INFINITY;

    braille := false;

    brush: SANDBOX_GAME_Cell_Type = .SAND;
    screen_mouse_x: int;
    screen_mouse_y: int;
    enqueued_clicks: [..] struct { x: int; y: int; type: SANDBOX_GAME_Cell_Type; };
    mouse_down := false;
    click_type: SANDBOX_GAME_Cell_Type;

    filepath: string;
}

SANDBOX_GAME_Cell :: struct {
    type: SANDBOX_GAME_Cell_Type;
    tick: u8;
}

SANDBOX_GAME_Cell_Type :: enum {
    BOUNDARY;
    AIR;
    SAND;
    WATER;
    HAZE;
    GASS;
}

SANDBOX_GAME_Color_Scheme :: struct {
    BOUNDARY : Pixel_Value;
    AIR      : Pixel_Value;
    SAND     : Pixel_Value;
    WATER    : Pixel_Value;
    HAZE     : Pixel_Value;
    GASS     : Pixel_Value;
}

make_cell :: inline (type: SANDBOX_GAME_Cell_Type, tick: int) -> SANDBOX_GAME_Cell {
    return .{ type, xx (tick % U8_MAX) };
}

with_tick :: inline (_cell: SANDBOX_GAME_Cell, tick: int) -> SANDBOX_GAME_Cell {
    cell := _cell;
    cell.tick = xx (tick % U8_MAX);
    return cell;
}

get_cell_ptr :: (sandbox: *SANDBOX_GAME_State, screen_x: int, screen_y: int) -> *SANDBOX_GAME_Cell {
    using sandbox;

    state := context.state;

    size_offset_x := world_size_x - state.pixel_window_size.x.(int);
    size_offset_y := world_size_y - state.pixel_window_size.y.(int);

    // Divide size_offset_x by 2 because offset_x origin is in the middle (this
    // makes no sense to me as I write this)
    world_x := screen_x + size_offset_x / 2 - offset_x;
    if world_x < 0 || world_x > world_size_x - 1 return null;

    world_y := screen_y + size_offset_y - offset_y;
    if world_y < 0 || world_y > world_size_y - 1 return null;

    cell_index := world_y * world_size_x + world_x;
    return *world_cells[cell_index];
}

get_cell :: (sandbox: *SANDBOX_GAME_State, screen_x: int, screen_y: int, or: SANDBOX_GAME_Cell) -> SANDBOX_GAME_Cell {
    cell := get_cell_ptr(sandbox, screen_x, screen_y);
    if !cell return or;
    return cell.*;
}

cell_to_pixel_value :: (colors: *SANDBOX_GAME_Color_Scheme, type: SANDBOX_GAME_Cell_Type) -> Pixel_Value {
    if #complete type == {
    case .BOUNDARY; return colors.BOUNDARY;
    case .AIR;      return colors.AIR;
    case .SAND;     return colors.SAND;
    case .WATER;    return colors.WATER;
    case .HAZE;     return colors.HAZE;
    case .GASS;     return colors.GASS;
    }
}

set_color :: (colors: *SANDBOX_GAME_Color_Scheme, type: SANDBOX_GAME_Cell_Type, color: Pixel_Value) {
    if #complete type == {
    case .BOUNDARY; colors.BOUNDARY = color;
    case .AIR;      colors.AIR      = color;
    case .SAND;     colors.SAND     = color;
    case .WATER;    colors.WATER    = color;
    case .HAZE;     colors.HAZE     = color;
    case .GASS;     colors.GASS     = color;
    }
}


serialize_cell :: (builder: *String_Builder, type: SANDBOX_GAME_Cell_Type) {
    if #complete type == {
    case .BOUNDARY; append(builder, "B ");
    case .AIR;      append(builder, "  ");
    case .SAND;     append(builder, "S ");
    case .WATER;    append(builder, "W ");
    case .HAZE;     append(builder, "H ");
    case .GASS;     append(builder, "G ");
    }
}

deserialize_cell :: (input: *string) -> bool, SANDBOX_GAME_Cell_Type {
    if input.count < 2 return false, .AIR;

    ok := false;
    result: SANDBOX_GAME_Cell_Type;

    serialized_cell := slice(input.*, 0, 2);
    if serialized_cell[0] == {
    case "B"; ok = true; result = .BOUNDARY;
    case " "; ok = true; result = .AIR;
    case "S"; ok = true; result = .SAND;
    case "W"; ok = true; result = .WATER;
    case "H"; ok = true; result = .HAZE;
    case "G"; ok = true; result = .GASS;
    }

    if ok then advance(input, 2);
    return ok, result;
}

init_SANDBOX_GAME :: () {
    using context.state;

    if sandbox.filepath {
        input, ok := my_read_entire_file(sandbox.filepath);
        assert(ok, "failed to open file '%'", sandbox.filepath);

        ok=, error := deserialize_SANDBOX_GAME(input, *sandbox);
        assert(ok, "%:%", sandbox.filepath, error);
    } else {
        sandbox.world_cells = NewArray(sandbox.world_size_x * sandbox.world_size_y, SANDBOX_GAME_Cell);
        for *sandbox.world_cells it.* = make_cell(.AIR, 0);
    }

    sandbox.color_scheme.BOUNDARY = Pixel_Value.id(.GRAY_4);
    sandbox.color_scheme.AIR      = Pixel_Value.id(.TRANSPARENT);
    sandbox.color_scheme.SAND     = Pixel_Value.id(.YELLOW);
    sandbox.color_scheme.WATER    = Pixel_Value.id(.BLUE);
    sandbox.color_scheme.HAZE     = Pixel_Value.id(.RGB_4_1_2);
    sandbox.color_scheme.GASS     = Pixel_Value.id(.RGB_2_4_2);

    sandbox.next_tick_time = seconds_since_init();
}

on_window_resize_SANDBOX_GAME :: () {
    resize_pixel_buffer();
}

handle_input_event_SANDBOX_GAME :: (event: Input_Event) {
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

        if event.kind == .CHARACTER {
            if event.char == {
            case #char ";";
                switch_to_command_line_mode();
                return;

            case #char " ";
                sandbox.paused = !sandbox.paused;
                if !sandbox.paused sandbox.sleeping = false;
                return;

            case #char "s"; sandbox.brush = .SAND;      return;
            case #char "w"; sandbox.brush = .WATER;     return;
            case #char "h"; sandbox.brush = .HAZE;      return;
            case #char "b"; sandbox.brush = .BOUNDARY;  return;
            case #char "g"; sandbox.brush = .GASS;      return;

            }
        }
    }

    assert(pixel_size == .TWO_CHARACTERS);
    sandbox.screen_mouse_x = (mouse_position.column - 1) / 2;
    assert(status_line_1_row == 1 && status_line_2_row == -1);
    sandbox.screen_mouse_y = (mouse_position.row - 1) - 1; // `-1` for @status_line

    if event.kind == {
        case .MOUSE_LEFT_DOWN; #through;
        case .MOUSE_LEFT_DRAG;
            sandbox.click_type = sandbox.brush;
            sandbox.mouse_down = true;
        case .MOUSE_RIGHT_DOWN; #through;
        case .MOUSE_RIGHT_DRAG;
            sandbox.click_type = .AIR;
            sandbox.mouse_down = true;
        case .MOUSE_ANY_UP;
            sandbox.mouse_down = false;
    }

    if sandbox.mouse_down {
        enqueue_click(*sandbox, sandbox.screen_mouse_x, sandbox.screen_mouse_y, sandbox.click_type);
    }

    return;
}

enqueue_click :: (sandbox: *SANDBOX_GAME_State, x: int, y: int, type: SANDBOX_GAME_Cell_Type) {
    last_click := last(*sandbox.enqueued_clicks);
    if last_click && (last_click.x == x) && (last_click.y == y) && (last_click.type == type) {
        return;
    }

    array_add(*sandbox.enqueued_clicks, .{ x, y, type });
}

update_SANDBOX_GAME :: () {
    using context.state;

    now := seconds_since_init();

    if sandbox.next_swap_time <= now {
        do_swap_SANDBOX_GAME();
        sandbox.next_swap_time = now + sandbox.swap_timer;
    }

    while sandbox.next_tick_time <= now {
        tick_SANDBOX_GAME();
        sandbox.next_tick_time += sandbox.tick_rate_seconds;

        if sandbox.debug_one_tick_per_render {
            sandbox.next_tick_time = now + sandbox.tick_rate_seconds;
            break;
        }
    }
}

Move_Directions :: enum_flags u16 {
    LEFT;
    RIGHT;
    UP;
    UP_LEFT;
    UP_RIGHT;
    DOWN;
    DOWN_LEFT;
    DOWN_RIGHT;

    ALL :: LEFT | RIGHT | UP | UP_LEFT | UP_RIGHT | DOWN | DOWN_LEFT | DOWN_RIGHT;
}

Offset :: struct { x: int; y: int; }
operator == :: (a: Offset, b: Offset) -> bool { return a.x == b.x && a.y == b.y; }
Move_Offsets :: Offset.[
    .{-1,  0},
    .{+1,  0},
    .{ 0, -1},
    .{-1, -1},
    .{+1, -1},
    .{ 0, +1},
    .{-1, +1},
    .{+1, +1},
];

move_offset :: inline (direction: Move_Directions) -> Offset {
    i := bit_scan_forward(direction);
    return Move_Offsets[i - 1];
}

moves_count :: inline (moves: Move_Directions) -> u32 {
    return xx popcount(moves.(u16));
}

pick_move :: (moves: Move_Directions) -> Move_Directions {
    count := moves_count(moves);
    if count <= 1 return moves;

    k := random_get() % count;

    T :: u16;
    #assert size_of(Move_Directions) <= size_of(T);
    move := moves.(T);

    for 1..k move &= move - 1; // clear k lowest set bits

    move &= xx,no_check -(move.(s16));
    return xx move;
}

test_move_stuff :: () {
    offset_equals :: (a: Offset, b: Offset) -> bool { return a.x == b.x && a.y == b.y; }
    pretty_assert(offset_equals(move_offset(.LEFT      ), Offset.{-1,  0}));
    pretty_assert(offset_equals(move_offset(.RIGHT     ), Offset.{+1,  0}));
    pretty_assert(offset_equals(move_offset(.UP        ), Offset.{ 0, -1}));
    pretty_assert(offset_equals(move_offset(.UP_LEFT   ), Offset.{-1, -1}));
    pretty_assert(offset_equals(move_offset(.UP_RIGHT  ), Offset.{+1, -1}));
    pretty_assert(offset_equals(move_offset(.DOWN      ), Offset.{ 0, +1}));
    pretty_assert(offset_equals(move_offset(.DOWN_LEFT ), Offset.{-1, +1}));
    pretty_assert(offset_equals(move_offset(.DOWN_RIGHT), Offset.{+1, +1}));

    pretty_assert(moves_count(0) == 0);
    pretty_assert(moves_count(.LEFT) == 1);
    pretty_assert(moves_count(.DOWN | .UP) == 2);
    pretty_assert(moves_count(.UP_LEFT | .DOWN_LEFT | .UP_RIGHT) == 3);
    pretty_assert(moves_count(.LEFT | .DOWN | .UP | .RIGHT) == 4);

    for moves: Move_Directions.[
        (.LEFT),
        (.DOWN | .UP),
        (.UP_LEFT | .DOWN_LEFT | .UP_RIGHT),
        (.LEFT | .DOWN | .UP | .RIGHT),
    ] {
        seen: Move_Directions;
        for 1..16 {
            move := pick_move(moves);
            pretty_assert(popcount(move) == 1);
            seen |= move;
        }
        pretty_assert(seen == moves);
    }
}
#run test_move_stuff();

do_swap_SANDBOX_GAME :: () {
    using context.state;

    Already_Changed :: (cell: SANDBOX_GAME_Cell) -> bool #expand {
        return cell.tick == (sandbox.tick % U8_MAX);
    }

    sandbox.tick += 1;
    sandbox.sleeping = false;

    type_a := sandbox.swap_types[0];
    type_b := sandbox.swap_types[1];

    for *sandbox.world_cells {
        if Already_Changed(it.*) continue;
        if it.type == type_a then it.* = make_cell(type_b, sandbox.tick);
        else if it.type == type_b then it.* = make_cell(type_a, sandbox.tick);
    }
}

tick_SANDBOX_GAME :: () {
    using context.state;

    width := sandbox.world_size_x;
    height := sandbox.world_size_y;

    Already_Moved :: (cell: SANDBOX_GAME_Cell) -> bool #expand {
        return cell.tick == (sandbox.tick % U8_MAX);
    }

    Get :: (x: int, y: int) -> SANDBOX_GAME_Cell #expand {
        if x < 0 || x > sandbox.world_size_x - 1 return make_cell(.BOUNDARY, 0);
        if y < 0 || y > sandbox.world_size_y - 1 return make_cell(.BOUNDARY, 0);
        return sandbox.world_cells[x + y * sandbox.world_size_x];
    }

    Get :: (x: int, y: int, move: Move_Directions) -> SANDBOX_GAME_Cell #expand {
        offset := move_offset(move);
        return Get(x + offset.x, y + offset.y);
    }

    Set :: (x: int, y: int, cell: SANDBOX_GAME_Cell) #expand {
        assert(0 <= x && x <= sandbox.world_size_x - 1, "% %", x, y);
        assert(0 <= y && y <= sandbox.world_size_y - 1, "% %", x, y);
        sandbox.world_cells[x + y * sandbox.world_size_x] = with_tick(cell, sandbox.tick);
    }

    Mutate :: (x: int, y: int, type: SANDBOX_GAME_Cell_Type) #expand {
        Set(x, y, make_cell(type, 0));
        sandbox.sleeping = false;
    }

    Swap :: (x1: int, y1: int, x2: int, y2: int) #expand {
        cell1 := Get(x1, y1);
        cell2 := Get(x2, y2);
        Set(x1, y1, cell2);
        Set(x2, y2, cell1);
    }

    Check_Move :: (x: int, y: int, move: Move_Directions, candidate_types: [] SANDBOX_GAME_Cell_Type) -> bool #expand {
        cell := Get(x, y, move);
        if (cell.type != .AIR) && Already_Moved(cell) return false;
        return is_any_of(cell.type, ..candidate_types);
    }

    Check_Moves :: (x: int, y: int, to_check: [] Move_Directions, candidate_types: [] SANDBOX_GAME_Cell_Type) -> Move_Directions #expand {
        for moves_to_check: to_check {
            moves: Move_Directions;
            for :for_each_bit move: moves_to_check {
                if Check_Move(x, y, move, candidate_types) {
                    moves |= move;
                }
            }
            if moves return moves;
        }
        return 0;
    }

    Move :: (x: int, y: int, move: Move_Directions) #expand {
        offset := move_offset(move);
        Swap(x, y, x + offset.x, y + offset.y);
        sandbox.sleeping = false;
    }

    // Keep adding cells every tick while mouse is down
    if sandbox.mouse_down {
        enqueue_click(*sandbox, sandbox.screen_mouse_x, sandbox.screen_mouse_y, sandbox.click_type);
    }

    if !sandbox.enqueued_clicks && sandbox.sleeping return;

    sandbox.tick += 1;
    sandbox.sleeping = true;

    //
    // spawn cells from enqueued clicks
    //

    for sandbox.enqueued_clicks {
        cell := get_cell_ptr(*sandbox, it.x, it.y);
        if cell && (cell.type != it.type) {
            cell.* = make_cell(it.type, sandbox.tick);
        }
    }
    sandbox.enqueued_clicks.count = 0;

    // early exit if paused
    if sandbox.paused return;

    //
    // tick the simulation
    //

    indexes := NewArray(sandbox.world_cells.count, u16,, temp);
    for *indexes it.* = xx it_index;
    shuffle(*indexes);

    for index: indexes {
        cell := sandbox.world_cells[index];
        if cell.type == {
        case .BOUNDARY; #through;
        case .AIR;
            continue;
        }

        if Already_Moved(cell) continue;

        x := index % width;
        y := index / width;
        assert(x + y * width == index, "% % %", index, x, y);

        moves: Move_Directions;
        mutations: [] SANDBOX_GAME_Cell_Type;

        if #complete cell.type == {
        case .BOUNDARY; #through;
        case .AIR;
            Unreachable("already handled");

        case .HAZE;
            moves = Check_Moves(x, y,
                .[(.UP | .UP_LEFT | .UP_RIGHT),
                  (.LEFT | .RIGHT)],
                .[.AIR]);

            if sandbox.mutate_sand
                mutations = .[.WATER, .WATER, .SAND];
            else
                mutations = .[.WATER];

        case .GASS;
            moves = Check_Moves(x, y,
                .[(.UP | .UP_LEFT | .UP_RIGHT),
                  (.LEFT | .RIGHT)],
                .[.AIR, .HAZE]);

            if sandbox.mutate_sand && sandbox.mutate_gass
                mutations = .[.WATER, .WATER, .SAND];
            else if sandbox.mutate_gass
                mutations = .[.WATER];

        case .SAND;
            moves = Check_Moves(x, y,
                .[(.DOWN),
                  (.DOWN_LEFT | .DOWN_RIGHT)],
                .[.AIR, .WATER, .HAZE, .GASS]);

            // if sandbox.mutate_sand && sandbox.mutate_gass
            //     mutations = .[.HAZE, .GASS];
            // else if sandbox.mutate_sand
            //     mutations = .[.HAZE];

            if !moves && sandbox.mutate_sand && Get(x, y, .DOWN).type == .BOUNDARY {
                sand_neighbours := 0;
                all := Move_Directions.ALL & ~.DOWN;
                for :for_each_bit move: all {
                    if Get(x, y, move).type == .SAND then sand_neighbours += 1;
                }

                if sand_neighbours >= 4 {
                    mutations = .[.HAZE];
                }
            }

        case .WATER;
            moves = Check_Moves(x, y,
                .[(.DOWN),
                  (.DOWN_LEFT | .DOWN_RIGHT),
                  (.LEFT | .RIGHT)],
                .[.AIR, .HAZE, .GASS]);

            if sandbox.mutate_gass
                mutations = .[.HAZE, .GASS];
            else
                mutations = .[.HAZE];
        }

        if !moves {
            if mutations && roll_mutation(cell)
                then Mutate(x, y, pick(mutations));
            continue;
        }

        move := pick_move(moves);
        Move(x, y, move);
    }
}

roll_mutation :: inline (cell: SANDBOX_GAME_Cell) -> bool {
    using context.state;

    if sandbox.can_mutate_after_ticks < 0 return false;

    if ((cell.tick + sandbox.can_mutate_after_ticks) % U8_MAX) > (sandbox.tick % U8_MAX)
        return false;
    return random_get() % sandbox.mutate_rate_one_in == 0;
}

save_to_file_SANDBOX_GAME :: (filepath: string, sandbox: *SANDBOX_GAME_State) -> bool {
    builder: String_Builder;
    builder.allocator = temp;

    serialize_SANDBOX_GAME(*builder, sandbox);

    ok := write_entire_file(filepath, builder_to_string(*builder,, temp));
    return ok;
}

serialize_SANDBOX_GAME :: (builder: *String_Builder, sandbox: *SANDBOX_GAME_State) {
    width := sandbox.world_size_x;
    for sandbox.world_cells {
        x := it_index % width;

        serialize_cell(builder, it.type);
        if x == width - 1
            append(builder, "\n");
    }
}

deserialize_SANDBOX_GAME :: (input: string, sandbox: *SANDBOX_GAME_State) -> bool, string {
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

    world_cells := NewArray(width * height, SANDBOX_GAME_Cell);

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
            ok, cell := deserialize_cell(*t);
            if !ok
                return false, tprint("%:%: failed to deserialize cell '%'",
                                     row, col, slice(t, 0, 2));

            world_cells[x + y * width] = make_cell(cell, 0);
        }
    }

    sandbox.world_cells = world_cells;
    sandbox.world_size_x = width;
    sandbox.world_size_y = height;

    return true, "";
}

is_any_of :: (v: $T, xs: .. T) -> bool {
    for xs if v == it return true;
    return false;
}

build_line_buffer_for_\ SANDBOX_GAME :: () -> [] string {
    using context.state;

    line_buffer: [..] string;
    line_buffer.allocator = temp;
    array_reserve(*line_buffer, main_window_height);

    height: int = xx pixel_window_size.y;
    assert(pixel_size == .TWO_CHARACTERS);
    for y : 0..height - 1 {
        builder: String_Builder;
        builder.allocator = temp;

        if sandbox.join_to_half {
            build_line_buffer_for_SANDBOX_GAME_join_to_half(*builder, y);
        } else {
            build_line_buffer_for_SANDBOX_GAME(*builder, y);
        }

        append(*builder, "\e[0m");
        append(*builder, "\n");

        array_add(*line_buffer, builder_to_string(*builder,, temp));
    }

    return line_buffer;
}

build_line_buffer_for_SANDBOX_GAME :: (builder: *String_Builder, y: int) {
    using context.state;

    width: int = xx pixel_window_size.x;

    for x: 0..width - 1 {
        cell := get_cell_ptr(*sandbox, x, y);
        cell_type := ifx cell then cell.type else .BOUNDARY;
        pixel := cell_to_pixel_value(*sandbox.color_scheme, cell_type);
        print_pixel_value(builder, pixel);

        if sandbox.braille && cell_type != .AIR {
            braille_pair := make_binary_representation(xx cell.tick);
            append(builder, "\e[30m");
            print_braille(builder, braille_pair.left);
            print_braille(builder, braille_pair.right);
        } else {
            append(builder, "  ");
        }
    }
}

build_line_buffer_for_SANDBOX_GAME_join_to_half :: (builder: *String_Builder, y: int) {
    using context.state;

    width: int = xx pixel_window_size.x;

    x := 0;
    cell := get_cell_ptr(*sandbox, x, y);
    while x < width {
        x += 1;

        cell_type := ifx cell then cell.type else .BOUNDARY;

        next_cell := ifx x < width then get_cell_ptr(*sandbox, x, y);

        join := false;
        if cell && next_cell
            && ((cell.type == .AIR && is_any_of(next_cell.type, .HAZE, .WATER)) ||
                (is_any_of(cell.type, .HAZE, .WATER) && next_cell.type == .AIR))
        {
            type := ifx cell.type != .AIR then cell.type else next_cell.type;

            if type == .WATER {
                below_cell      := get_cell_ptr(*sandbox, x - 1, y + 1);
                below_next_cell := get_cell_ptr(*sandbox, x, y + 1);

                if (!below_cell || (below_cell.type != .AIR)) &&
                    (!below_next_cell || (below_next_cell.type != .AIR))
                {
                    cell_type = type;
                    join = true;
                }
            } else {
                above_cell      := get_cell_ptr(*sandbox, x - 1, y - 1);
                above_next_cell := get_cell_ptr(*sandbox, x, y - 1);

                if (!above_cell || (above_cell.type != .AIR)) &&
                    (!above_next_cell || (above_next_cell.type != .AIR))
                {
                    cell_type = type;
                    join = true;
                }
            }
        }

        pixel := cell_to_pixel_value(*sandbox.color_scheme, cell_type);

        if !join {
            print_pixel_value(builder, pixel, fg=false);
            append(builder, "  ");
        } else if cell_type == .WATER {
            append(builder, "\e[40m");
            print_pixel_value(builder, pixel, fg=true);
            append(builder, "▄▄▄▄");
        } else {
            append(builder, "\e[40m");
            print_pixel_value(builder, pixel, fg=true);
            append(builder, "▀▀▀▀");
        }

        if !join {
            // Handled this cell, going to handle next_cell next
            cell = next_cell;
        } else {
            // Already handled both cell and next_cell
            x += 1;
            cell = get_cell_ptr(*sandbox, x, y);
        }
    }
}

//
// @console commands
//

console_commands_SANDBOX_GAME :: (console_commands: *[..] Command) {
    array_add(console_commands, make_command("tick_rate", console_set_sandbox_tick_rate));
    array_add(console_commands, make_command("can_mutate_after_ticks", console_set_can_mutate_after_ticks));
    array_add(console_commands, make_command("mutate_rate_one_in", console_set_mutate_rate_one_in));
    array_add(console_commands, make_command("mutate_sand", console_toggle_mutate_sand));
    array_add(console_commands, make_command("mutate_gass", console_toggle_mutate_gass));
    array_add(console_commands, make_command("join_to_half", console_toggle_join_to_half));
    array_add(console_commands, make_command("debug_tick_rate", console_toggle_debug_one_tick_per_update));
    array_add(console_commands, make_command("swap", console_swap_cell_types));
    array_add(console_commands, make_command("clear", console_sandbox_clear));
    array_add(console_commands, make_command("save", console_sandbox_save));
    array_add(console_commands, make_command("braille", console_toggle_braille));
    array_add(console_commands, make_command("set_color", console_sandbox_set_color));
}

console_set_sandbox_tick_rate :: (seconds: float) -> (ok := true, error_message := "") {
    using context.state;

    sandbox.tick_rate_seconds = seconds;

    return;
}

console_set_can_mutate_after_ticks :: (ticks: int) -> (ok := true, error_message := "") {
    using context.state;

    sandbox.can_mutate_after_ticks = ticks;

    return;
}

console_set_mutate_rate_one_in :: (rate: u64) -> (ok := true, error_message := "") {
    using context.state;

    sandbox.mutate_rate_one_in = rate;

    return;
}

console_toggle_debug_one_tick_per_update :: () -> (ok := true, error_message := "") {
    using context.state;

    sandbox.debug_one_tick_per_render = !sandbox.debug_one_tick_per_render;

    return;
}

console_toggle_braille :: () -> (ok := true, error_message := "") {
    using context.state;

    sandbox.braille = !sandbox.braille;
    sandbox.sleeping = false;

    return;
}

console_toggle_mutate_sand :: () -> (ok := true, error_message := "") {
    using context.state;

    sandbox.mutate_sand = !sandbox.mutate_sand;
    sandbox.sleeping = false;

    return;
}

console_toggle_mutate_gass :: () -> (ok := true, error_message := "") {
    using context.state;

    sandbox.mutate_gass = !sandbox.mutate_gass;
    sandbox.sleeping = false;

    return;
}

console_toggle_join_to_half :: () -> (ok := true, error_message := "") {
    using context.state;

    sandbox.join_to_half = !sandbox.join_to_half;
    sandbox.sleeping = false;

    return;
}

console_sandbox_set_color :: (arguments_string: string) -> (ok := true, error_message := "") {
    using context.state;

    arguments := my_split(arguments_string);

    if arguments.count < 2 return false, tprint("expected at least 2 arguments, got %", arguments);

    ok, type := parse_cell_type(arguments[0]);
    if !ok return false, tprint("argument #1: expected one of %, got '%'",
                                enum_names(SANDBOX_GAME_Cell_Type),
                                arguments[0]);

    color: Pixel_Value;

    if arguments.count == 2 {
        color_string := arguments[1];
        id, ok := string_to_int(color_string, T=u8);
        if ok {
            color = Pixel_Value.id(xx id);
        } else {
            ok=, color_8bit := string_to_enum(color_string, Color_8bit);
            color = Pixel_Value.id(color_8bit);
        }
        if !ok return false, tprint("argument #2: expected a u8 or a Pixel_Value, got %", color);
    } else if arguments.count == 4 {
        r_text := arguments[1];
        g_text := arguments[2];
        b_text := arguments[3];

        r:, ok = string_to_int(r_text, T=u8);
        if !ok return false, tprint("argument #2: expected a u8, got %", r_text);
        g:, ok = string_to_int(g_text, T=u8);
        if !ok return false, tprint("argument #3: expected a u8, got %", g_text);
        b:, ok = string_to_int(b_text, T=u8);
        if !ok return false, tprint("argument #4: expected a u8, got %", b_text);

        color = Pixel_Value.rgb(r, g, b);
    } else {
        return false, tprint("color arguments must be 1 or 3 values, got %", array_view(arguments, 1));
    }

    set_color(*sandbox.color_scheme, type, color);

    return;
}

console_swap_cell_types :: (a: string) -> (ok := true, error_message := "") {
    using context.state;

    ok: bool;

    ok=, left, right := split_from_left(a, " ");
    if !ok return false, tprint("expected at least 2 arguments, got '%'", a);

    ok=, right=, swap_time := split_from_left(right, " ");
    if ok {
        time:, ok = string_to_float64(swap_time);
        if !ok return false, tprint("argument #3: expected number, got '%'", swap_time);

        sandbox.swap_timer = ifx time < 0 then FLOAT64_INFINITY else time;
    }

    ok=, type_a := parse_cell_type(left);
    if !ok return false, tprint("argument #1: expected one of %, got '%'",
                                enum_names(SANDBOX_GAME_Cell_Type),
                                left);

    ok=, type_b := parse_cell_type(right);
    if !ok return false, tprint("argument #2: expected one of %, got '%'",
                                enum_names(SANDBOX_GAME_Cell_Type),
                                right);

    sandbox.swap_types[0] = type_a;
    sandbox.swap_types[1] = type_b;
    sandbox.next_swap_time = seconds_since_init();

    return;
}

parse_cell_type :: #bake_arguments string_to_enum(E=SANDBOX_GAME_Cell_Type);

console_sandbox_clear :: () -> (ok := true, error_message := "") {
    using context.state;

    for *sandbox.world_cells it.* = make_cell(.AIR, sandbox.tick);

    return;
}

console_sandbox_save :: (filename_argument: string) -> (ok := true, error_message := "") {
    using context.state;

    filepath: string;

    if filename_argument {
        filepath = filename_argument;
    } else if sandbox.filepath {
        filepath = sandbox.filepath;
    } else {
        return false, "don't know where to save";
    }

    ok := save_to_file_SANDBOX_GAME(filepath, *sandbox);

    if !ok {
        log_error("saving to '%' failed", filepath);
        return false, tprint("saving to '%' failed", filepath);
    }

    log("saved sandbox game to \e[33m%\e[0m", filepath);

    return;
}

//
// status lines
//

status_line_1_SANDBOX_GAME :: (builder: *String_Builder, side: Status_Line_Side) {
    using context.state;

    assert(side == .LEFT);

    if #complete side == {
    case .LEFT;
        types := SANDBOX_GAME_Cell_Type.[.SAND, .WATER, .HAZE, .BOUNDARY];
        chars := string                .["s"  , "w"   , "h"  , "b"      ];

        for type: types {
            char := chars[it_index];

            color := cell_to_pixel_value(*sandbox.color_scheme, type);
            print_pixel_value(builder, color, fg=true);
            if sandbox.brush == type then append(builder, "\e[7m"); // invert color mode
            print(builder, "[%] % ", char, type);
            append(builder, "\e[0m");
        }

        if sandbox.paused {
            append(builder, " ");
            append(builder, "\e[31m");
            append(builder, "PAUSED");
            append(builder, "\e[0m");
        }

    case .RIGHT; assert(false);
    }
}

status_line_1_buffer_number_SANDBOX_GAME :: () -> string {
    using context.state;

    builder: String_Builder;
    builder.allocator = temp;

    append(*builder, "\e[2;37m"); // color gray (dark white)
    print(*builder, "#%", last_shown_line_buffer_version);
    append(*builder, "\e[0m");
    return builder_to_string(*builder,, temp);
}

status_line_2_render_counter_SANDBOX_GAME :: () -> int {
    using context.state;

    return sandbox.tick;
}

Unreachable :: (message := "") #expand {
    assert(false, message);
}

#import "Bit_Operations";
