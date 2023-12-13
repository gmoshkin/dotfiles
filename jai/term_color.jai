main :: () {
    ROWS, COLS = get_terminal_size();
    COLS /= 2;

    buffer := NewArray(template.count * COLS * 2 * ROWS, u8);

    for 0..buffer.count / template.count - 1 {
        memcpy(buffer.data + it * template.count, template.data, template.count);
    }

    for row: 0..ROWS-1 for col: 0..COLS-1 {
        red := cast(float) row / (ROWS - 1);
        blu := cast(float) col / (COLS - 1);
        put_color(buffer, row, col, .{ red, 0, blu, 0 });
    }

    flush(buffer);
}

template :: "\e[38;2;000;000;000m█";
r_ofs :: 7;
g_ofs :: 11;
b_ofs :: 15;
COLS := 40;
ROWS := 20;

put_color :: inline (buffer: [] u8, row: int, col: int, color: Vector4) {
    assert(buffer.count >= 2 * (col + 1 + COLS * row) * template.count);

    cell_start := buffer.data + (2 * col + 2 * COLS * row) * template.count;
    write_number(cell_start + r_ofs, xx (color.x * 255));
    write_number(cell_start + g_ofs, xx (color.y * 255));
    write_number(cell_start + b_ofs, xx (color.z * 255));

    cell_start = buffer.data + (2 * col + 1 + 2 * COLS * row) * template.count;
    write_number(cell_start + r_ofs, xx (color.x * 255));
    write_number(cell_start + g_ofs, xx (color.y * 255));
    write_number(cell_start + b_ofs, xx (color.z * 255));

}

// put_color :: inline (buffer: [] u8, i: int, color: IVec3) {
//     assert(buffer.count >= (i + 1) * template.count);
//     cell_start := buffer.data + i * template.count;
//     write_number(cell_start + r_ofs, xx color.x);
//     write_number(cell_start + g_ofs, xx color.y);
//     write_number(cell_start + b_ofs, xx color.z);
// }

write_number :: inline (p: *u8, n: u8) {
    p[0] = #char "0" + n / 100;
    p[1] = #char "0" + (n % 100) / 10;
    p[2] = #char "0" + n % 10;
}

flush :: inline (buffer: [] u8) {
    assert(buffer.count >= template.count * COLS * 2 * ROWS);
    for 0..ROWS-1 {
        s := array_view(buffer, it * COLS * 2 * template.count, COLS * 2 * template.count);
        write_string(xx s);
        write_string("\e[0m\n");
    }
}

IVec3 :: struct {
    x, y, z: s32;
}

//
// terminal size {{{
//

get_terminal_size :: () -> (lines: s32, columns: s32) {
    #import "POSIX";
    TIOCGWINSZ :: 0x5413;
    winsize :: struct {
        ws_row: u16;
        ws_col: u16;
        ws_xpixel: u16;
        ws_ypixel: u16;
    };

    ws: winsize;
    ioctl(STDIN_FILENO, TIOCGWINSZ, *ws);

    return ws.ws_row, ws.ws_col;
}

//
// }}} terminal size
//


#import "Basic";
#import "Math";
