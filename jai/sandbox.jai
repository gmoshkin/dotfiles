SANDBOX_GAME_State :: struct {
    // Offset is from game world bottom center to display bottom center
    offset_x: int = 0;
    offset_y: int = 0;

    tick_rate_seconds: float64 = .1;
    next_tick_time: float64 = -1.0;
    debug_one_tick_per_render := false;
    tick: int = 0;

    brush: type_of(SANDBOX_GAME_Cell.type) = .SAND;

    world_size_x: int = 50;
    world_size_y: int = 50;
    world_cells: [] SANDBOX_GAME_Cell;
    world_cells_2nd_buffer: [] SANDBOX_GAME_Cell;
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

cell_to_pixel_value :: (type: SANDBOX_GAME_Cell_Type) -> Pixel_Value {
    if #complete type == {
    case .BOUNDARY; return Pixel_Value.id(.GRAY_4);
    case .AIR;      return Pixel_Value.id(.TRANSPARENT);
    case .SAND;     return Pixel_Value.id(.YELLOW);
    case .WATER;    return Pixel_Value.id(.BLUE);
    case .HAZE;     return Pixel_Value.id(.RGB_4_1_2);
    }
}

init_SANDBOX_GAME :: () {
    using context.state.sandbox;

    world_cells = NewArray(world_size_x * world_size_y, SANDBOX_GAME_Cell);
    for *world_cells it.* = make_cell(.AIR, 0);
    world_cells_2nd_buffer = NewArray(world_size_x * world_size_y, SANDBOX_GAME_Cell);
    for *world_cells_2nd_buffer it.* = make_cell(.AIR, 0);
    next_tick_time = seconds_since_init();
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

            case #char "s"; sandbox.brush = .SAND;      return;
            case #char "w"; sandbox.brush = .WATER;     return;
            case #char "h"; sandbox.brush = .HAZE;      return;
            case #char "b"; sandbox.brush = .BOUNDARY;  return;

            }
        }
    }

    assert(pixel_size == .TWO_CHARACTERS);
    width := cast(int) pixel_window_size.x;
    height := cast(int) pixel_window_size.y;
    screen_mouse_x := (mouse_position.column - 1) / 2;
    assert(status_line_1_row == 1 && status_line_2_row == -1);
    screen_mouse_y := (mouse_position.row - 1) - 1; // `-1` for @status_line

    cell := get_cell_ptr(*sandbox, screen_mouse_x, screen_mouse_y);
    if !cell return;

    click := false;
    type: SANDBOX_GAME_Cell_Type;
    if event.kind == {
        case .MOUSE_LEFT_DRAG; #through;
        case .MOUSE_LEFT_DOWN;
            type = sandbox.brush;
            click = true;
        case .MOUSE_RIGHT_DRAG; #through;
        case .MOUSE_RIGHT_DOWN;
            type = .AIR;
            click = true;
    }

    if click then cell.* = make_cell(type, sandbox.tick);

    return;
}

update_SANDBOX_GAME :: () {
    using context.state;

    now := seconds_since_init();

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

    move &= xx,no_check -(move).(s16);
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

tick_SANDBOX_GAME :: () {
    using context.state;

    width := sandbox.world_size_x;
    height := sandbox.world_size_y;

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

    Swap :: (x1: int, y1: int, x2: int, y2: int) #expand {
        cell1 := Get(x1, y1);
        cell2 := Get(x2, y2);
        Set(x1, y1, cell2);
        Set(x2, y2, cell1);
    }

    Move :: (x: int, y: int, move: Move_Directions) #expand {
        offset := move_offset(move);
        Swap(x, y, x + offset.x, y + offset.y);
    }

    sandbox.tick += 1;

    for sandbox.world_cells {
        if it.type == {
        case .BOUNDARY; #through;
        case .AIR;
            continue;
        }

        // Already handled
        if it.tick == (sandbox.tick % U8_MAX) continue;

        x := it_index % width;
        y := it_index / width;
        assert(x + y * width == it_index, "% % %", it_index, x, y);

        moves: Move_Directions;

        if #complete it.type == {
        case .BOUNDARY; #through;
        case .AIR;
            Unreachable("already handled");

        case .HAZE;
            can_move_to :: SANDBOX_GAME_Cell_Type.[.AIR];
            for move: Move_Directions.[.LEFT, .RIGHT, .UP, .UP_LEFT, .UP_RIGHT] {
                if is_any_of(Get(x, y, move).type, ..can_move_to)
                    then moves |= move;
            }

        case .SAND;
            can_move_to :: SANDBOX_GAME_Cell_Type.[.AIR, .WATER, .HAZE];
            move := Move_Directions.DOWN;
            if is_any_of(Get(x, y, move).type, ..can_move_to)
                then moves |= move;

            if !moves for move: Move_Directions.[.DOWN_LEFT, .DOWN_RIGHT] {
                if is_any_of(Get(x, y, move).type, ..can_move_to)
                    then moves |= move;
            }

        case .WATER;
            can_move_to :: SANDBOX_GAME_Cell_Type.[.AIR, .HAZE];
            move := Move_Directions.DOWN;
            if is_any_of(Get(x, y, move).type, ..can_move_to)
                then moves |= move;

            if !moves for move: Move_Directions.[.DOWN_LEFT, .DOWN_RIGHT] {
                if is_any_of(Get(x, y, move).type, ..can_move_to)
                    then moves |= move;
            }

            if !moves for move: Move_Directions.[.LEFT, .RIGHT] {
                if is_any_of(Get(x, y, move).type, ..can_move_to)
                    then moves |= move;
            }
        }

        if !moves continue;

        move := pick_move(moves);
        Move(x, y, move);
    }
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

    width: int = xx pixel_window_size.x;
    height: int = xx pixel_window_size.y;
    assert(pixel_size == .TWO_CHARACTERS);
    for y : 0..height - 1 {
        builder: String_Builder;
        builder.allocator = temp;

        for x : 0..width - 1 {
            cell := get_cell_ptr(*sandbox, x, y);
            if cell {
                pixel := cell_to_pixel_value(cell.type);
                print_pixel_value(*builder, pixel);
            } else {
                print_pixel_value(*builder, Pixel_Value.rgb(0, 0, 0));
            }
            append(*builder, "  ");
        }

        append(*builder, "\e[0m");
        append(*builder, "\n");

        array_add(*line_buffer, builder_to_string(*builder,, temp));
    }

    return line_buffer;
}

set_sandbox_tick_rate :: (seconds: float) -> (ok := true, error_message := "") {
    using context.state;

    sandbox.tick_rate_seconds = seconds;

    if main_window_source != .SANDBOX_GAME return false, "this command is for SANDBOX_GAME";

    return;
}

toggle_debug_one_tick_per_update :: () -> (ok := true, error_message := "") {
    using context.state;

    sandbox.debug_one_tick_per_render = !sandbox.debug_one_tick_per_render;

    if main_window_source != .SANDBOX_GAME return false, "this command is for SANDBOX_GAME";

    return;
}

status_line_1_SANDBOX_GAME :: (builder: *String_Builder, side: Status_Line_Side) {
    using context.state;

    assert(side == .LEFT);

    if #complete side == {
    case .LEFT;
        types := SANDBOX_GAME_Cell_Type.[.SAND, .WATER, .HAZE, .BOUNDARY];
        chars := string                .["s"  , "w"   , "h"  , "b"      ];

        for type: types {
            char := chars[it_index];

            color := cell_to_pixel_value(type);
            print_pixel_value(builder, color, fg=true);
            if sandbox.brush == type then append(builder, "\e[7m"); // invert color mode
            print(builder, "[%] % ", char, type);
            append(builder, "\e[0m");
        }

    case .RIGHT;
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
