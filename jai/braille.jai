main :: () {
    builder: String_Builder;
    builder.allocator = temp;

    append(*builder, "'");

    for Braille_Matrix.[
        .{false, true ,
          true , false,
          true , false,
          false, true ,},

        .{true , false,
          false, true,
          false, true,
          true , false,},
    ] {
        buf: [4] u8;
        s := cast(string) buf;
        ch := braille_char(it);
        character_utf32_to_utf8(ch, *s);
        append(*builder, s);
    }

    append(*builder, "'");

    print("%\n", builder_to_string(*builder));
}

Braille_Matrix :: struct {
    _11, _12: bool;
    _21, _22: bool;
    _31, _32: bool;
    _41, _42: bool;
}

braille_char :: (matrix: Braille_Matrix) -> u32 {
    result: u32 = 0x2800;
    if matrix._11 result += 1 << 0;
    if matrix._21 result += 1 << 1;
    if matrix._31 result += 1 << 2;
    if matrix._12 result += 1 << 3;
    if matrix._22 result += 1 << 4;
    if matrix._32 result += 1 << 5;
    if matrix._41 result += 1 << 6;
    if matrix._42 result += 1 << 7;

    return result;
}

#import "Basic";
#import "Unicode";
