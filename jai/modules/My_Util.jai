#module_parameters (TEST := false);

f32 :: float32;
f64 :: float64;

//
// array utilities
//

array_find :: inline (array: *[] $T, $predicate: (*T) -> bool) -> s64 {
    for *array if predicate(it) return it_index;
    return -1;
}

array_find :: inline (array: [] $T, $predicate: (T) -> bool) -> s64 {
    for array if predicate(it) return it_index;
    return -1;
}

contains :: inline (array: *[] $T, $predicate: (*T) -> bool) -> bool {
    return array_find(array, predicate) != -1;
}

contains :: inline (array: [] $T, $predicate: (T) -> bool) -> bool {
    return array_find(array, predicate) != -1;
}

array_equals :: (lhs: [] $T, rhs: [] T) -> bool {
    if lhs.count != rhs.count return false;

    for 0..lhs.count-1 {
        if lhs[it] != rhs[it] return false;
    }

    return true;
}

advance :: inline (a: [] $T, amount: s64 = 1) -> [] T {
    assert(amount >= 0);
    assert(a.count >= amount);
    return .{ data = a.data + amount, count = a.count - amount };
}

advance :: inline (a: *[] $T, amount: s64 = 1) {
    assert(amount >= 0);
    assert(a.count >= amount);
    a.count -= amount;
    a.data  += amount;
}

last :: inline (array: [] $T) -> T {
    assert(array.count != 0);
    return array[array.count - 1];
}

last :: inline (array: *[] $T) -> *T {
    if array.*.count == 0 return null;
    return *array.*[array.*.count - 1];
}

//
// string utilities
//

NOT_SPECIFIED :: 0x7fff_ffff_ffff_ffff;
substring :: (s: string, start := 0, end := NOT_SPECIFIED, count := NOT_SPECIFIED) -> string {
    _count := count;
    _start := ifx start < 0 then s.count + start else start;
    if end == NOT_SPECIFIED && count == NOT_SPECIFIED {
        _count = s.count - _start;
    } else {
        assert(end == NOT_SPECIFIED || count == NOT_SPECIFIED);
        _end := ifx end < 0 then s.count + end else end;
        if count == NOT_SPECIFIED then _count = _end - _start;
    }
    assert(_start >= 0, "start: %, end: %, count: %", start, end, count);
    assert(_start <= s.count, "start: %, end: %, count: %", start, end, count);
    assert(_count >= 0, "start: %, end: %, count: %", start, end, count);
    assert(_start + _count <= s.count, "start: %, end: %, count: %", start, end, count);

    return string.{ data = s.data + _start, count = _count };
}

last :: inline (s: string) -> u8 {
    return s[s.count - 1];
}

count_matches :: (text: string, c: u8) -> s64 {
    count := 0;
    cursor := 0;
    while true {
        index := find_index_from_left(text, c, cursor);
        if index == -1 return count;
        count += 1;
        cursor = index + 1;
    }
    return 0;
}

contains_pointer :: inline (s: string, p: *u8) -> bool {
    return s.data <= p && p < s.data + s.count;
}

contains_pointer :: inline (a: [] $T, p: *T) -> bool {
    return a.data <= p && p < a.data + a.count;
}

is_subslice :: inline (outer: string, inner: string) -> bool {
    return (outer.data <= inner.data) && (inner.data + inner.count <= outer.data + outer.count);
}

parse_positive_number :: (text: string, $T: Type = int) -> T, tail: string
#modify { return T == u8 || T == u16 || T == u32 || T == u64 || T == s8 || T == s16 || T == s32 || T == s64; }
{
    if !text return 0, text;

    result: T = 0;
    cursor := 0;
    while cursor < text.count {
        d := text[cursor];
        if !inline is_digit(d) break;
        cursor += 1;
        result = result * 10 + (d - #char "0");
    }

    return result, advance(text, cursor);
}

#if TEST
test_parse_positive_number :: () {
    {
        n, tail := parse_positive_number("");
        pretty_assert(n == 0);
        pretty_assert(tail == "");
    }

    {
        n, tail := parse_positive_number("a");
        pretty_assert(n == 0);
        pretty_assert(tail == "a");
    }

    {
        n, tail := parse_positive_number("1");
        pretty_assert(n == 1);
        pretty_assert(tail == "");
    }

    {
        n, tail := parse_positive_number("2b");
        pretty_assert(n == 2);
        pretty_assert(tail == "b");
    }

    {
        n, tail := parse_positive_number("42069");
        pretty_assert(n == 42069);
        pretty_assert(tail == "");
    }
}

//
// lines iterator
//

lines :: (text: *string, body: Code, flags: For_Flags) #expand {
    #assert !(flags & .POINTER);
    #assert !(flags & .REVERSE);

    tail := text.*;
    index := 0;

    while tail {
        found:, line:, tail = split_from_left(tail, #char "\n");

        `it := line;
        `it_index := index;
        index += 1;

        #insert body;
    }
}

reverse_lines :: (text: *string, body: Code, flags: For_Flags) #expand {
    #assert !(flags & .POINTER);
    #assert !(flags & .REVERSE);

    head := text.*;
    if !head return;

    index := 0;
    found := false;
    first := true;

    while head || found {
        found=, head=, line := split_from_right(head, #char "\n");

        if first {
            first = false;
            // Skip first empty line (already checked the input is not empty)
            if !line continue;
        }

        `it := line;
        `it_index := index;
        index += 1;

        #insert body;
    }

    return;
}

words :: (text: *string, body: Code, flags: For_Flags) #expand {
    #assert !(flags & .POINTER);
    #assert !(flags & .REVERSE);

    tail := text.*;
    index := 0;
    while tail {
        found:, line:, tail = split_from_left_by_any(tail, " \t\n\r");
        if !line continue;

        `it := line;
        `it_index := index;
        index += 1;

        #insert body;
    }
}

map :: (text: string, $cb: #type (*string, Code, For_Flags), $T: Type) -> [] T {
    items: [..] T;

    for :cb text {
        array_add(*items, it);
    }

    return items;
}


#if TEST
test_line_iterator :: () {
    check_for_lines :: (s: string, $reverse := false) -> [] string, [] int {
        items: [..] string;
        items.allocator = temp;

        indexes: [..] int;
        indexes.allocator = temp;

        #if !reverse
            for :lines s {
                array_add(*items, it);
                array_add(*indexes, it_index);
            }
        else
            for :reverse_lines s {
                array_add(*items, it);
                array_add(*indexes, it_index);
            }

        return items, indexes;
    }

    items: [] string;
    indexes: [] int;

    items, indexes = check_for_lines("");
    pretty_assert(array_equals(items, string.[]));
    pretty_assert(array_equals(indexes, int.[]));

    items, indexes = check_for_lines("line1");
    pretty_assert(array_equals(items, string.["line1"]));
    pretty_assert(array_equals(indexes, int.[0]));

    items, indexes = check_for_lines("\n");
    pretty_assert(array_equals(items, string.[""]));
    pretty_assert(array_equals(indexes, int.[0]));

    items, indexes = check_for_lines("\n\n");
    pretty_assert(array_equals(items, string.["", ""]));
    pretty_assert(array_equals(indexes, int.[0, 1]));

    items, indexes = check_for_lines("line1\nline2\nline3\n");
    pretty_assert(array_equals(items, string.["line1", "line2", "line3"]));
    pretty_assert(array_equals(indexes, int.[0, 1, 2]));

    items, indexes = check_for_lines("\n\nline1\nline2\n\nline3\n\n");
    pretty_assert(array_equals(items, string.["", "", "line1", "line2", "", "line3", ""]));
    pretty_assert(array_equals(indexes, int.[0, 1, 2, 3, 4, 5, 6]));

    //
    // reverese
    //

    items, indexes = check_for_lines("", reverse=true);
    pretty_assert(array_equals(items, string.[]));
    pretty_assert(array_equals(indexes, int.[]));

    items, indexes = check_for_lines("line1", reverse=true);
    pretty_assert(array_equals(items, string.["line1"]));
    pretty_assert(array_equals(indexes, int.[0]));

    items, indexes = check_for_lines("\n", reverse=true);
    pretty_assert(array_equals(items, string.[""]));
    pretty_assert(array_equals(indexes, int.[0]));

    items, indexes = check_for_lines("\n\n", reverse=true);
    pretty_assert(array_equals(items, string.["", ""]));
    pretty_assert(array_equals(indexes, int.[0, 1]));

    items, indexes = check_for_lines("line1\nline2\nline3\n", reverse=true);
    pretty_assert(array_equals(items, string.["line3", "line2", "line1"]));
    pretty_assert(array_equals(indexes, int.[0, 1, 2]));

    items, indexes = check_for_lines("\n\nline1\nline2\n\nline3\n\n", reverse=true);
    pretty_assert(array_equals(items, string.["", "line3", "", "line2", "line1", "", ""]));
    pretty_assert(array_equals(indexes, int.[0, 1, 2, 3, 4, 5, 6]));

    check_for_words :: (s: string) -> [] string, [] int {
        items: [..] string;
        items.allocator = temp;

        indexes: [..] int;
        indexes.allocator = temp;

        for :words s {
            array_add(*items, it);
            array_add(*indexes, it_index);
        }

        return items, indexes;
    }

    items, indexes = check_for_words("");
    pretty_assert(array_equals(items, string.[]));
    pretty_assert(array_equals(indexes, int.[]));

    items, indexes = check_for_words("word1");
    pretty_assert(array_equals(items, string.["word1"]));
    pretty_assert(array_equals(indexes, int.[0]));

    items, indexes = check_for_words("\t ");
    pretty_assert(array_equals(items, string.[]));
    pretty_assert(array_equals(indexes, int.[]));

    items, indexes = check_for_words(" \n ");
    pretty_assert(array_equals(items, string.[]));
    pretty_assert(array_equals(indexes, int.[]));

    items, indexes = check_for_words("word1 word2 word3");
    pretty_assert(array_equals(items, string.["word1", "word2", "word3"]));
    pretty_assert(array_equals(indexes, int.[0, 1, 2]));

    items, indexes = check_for_words("  word1\tword2 \n word3  \n\r");
    pretty_assert(array_equals(items, string.["word1", "word2", "word3"]));
    pretty_assert(array_equals(indexes, int.[0, 1, 2]));

    items, indexes = check_for_words("  word1 ");
    pretty_assert(array_equals(items, string.["word1"]));
    pretty_assert(array_equals(indexes, int.[0]));

    pretty_assert(array_equals(map("foo\n\nbar", lines, string), string.["foo", "", "bar"]));
    pretty_assert(array_equals(map("foo\n\nbar", words, string), string.["foo", "bar"]));

}

//
// unicode utilities
//

utf8_count :: (utf8: string, $do_assert := true) -> s64, bool {
    count := 0;
    cursor := 0;
    while cursor < utf8.count {
        ofs := trailing_bytes_for_utf8[utf8[cursor]];
        cursor += ofs + 1;
        count += 1;
    }
    #if do_assert assert(cursor == utf8.count, "cursor: %, utf8:\n%", cursor, cast(Mem_Dump) utf8);

    return count, cursor == utf8.count;
}

utf8_substring :: (utf8: string, start: s64, count: s64 = -1, $do_assert := true) -> (string, utf8_count: s64) {
    assert(start >= 0);
    assert(count >= 0 || count == -1, "%", count);

    cursor := 0;
    for 1..start {
        if cursor >= utf8.count break;
        ofs := trailing_bytes_for_utf8[utf8[cursor]];
        cursor += ofs + 1;
    }

    start_cursor := cursor;
    utf8_count := 0;
    if count == -1 {
        cursor = utf8.count;
    } else while cursor < utf8.count && utf8_count < count {
        ofs := trailing_bytes_for_utf8[utf8[cursor]];
        cursor += ofs + 1;
        utf8_count += 1;
    }
    #if do_assert assert(cursor <= utf8.count, "cursor: %, utf8: '%'", cursor, utf8);

    result: string = ---;
    result.data = utf8.data + start_cursor;
    result.count = cursor - start_cursor;

    return result, utf8_count;
}

// Yoinked from modules/Unicode.jai
trailing_bytes_for_utf8 :: u8.[
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
	2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, 3,3,3,3,3,3,3,3,4,4,4,4,5,5,5,5
];

utf8 :: (utf8: *string, body: Code, flags: For_Flags) #expand {
    #assert !(flags & .POINTER);
    #assert !(flags & .REVERSE);

    text := utf8.*;

    count := 0;
    cursor := 0;
    while cursor < utf8.count {
        trail := trailing_bytes_for_utf8[text[cursor]];
        if cursor + trail >= utf8.count break;

        `it := slice(text, cursor, trail + 1);
        cursor += trail + 1;
        `it_index := count;
        count += 1;

        #insert body;
    }
}

first_byte_mask_for_utf8 :: u8.[ 0x7F, 0x1F, 0x0F, 0x07, 0x03, 0x01 ];

utf8_chars :: (utf8: *string, body: Code, flags: For_Flags) #expand {
    #assert !(flags & .POINTER);
    #assert !(flags & .REVERSE);

    text := utf8.*;

    count := 0;
    cursor := 0;
    char: s64;
    while cursor < utf8.count {
        trail := trailing_bytes_for_utf8[text[cursor]];
        if cursor + trail >= utf8.count break;

        char = text[cursor] & first_byte_mask_for_utf8[trail];
        cursor += 1;

        for 1..trail {
            char <<= 6;
            // TODO: should probably add error checking
            char |= text[cursor] & 0x3f;
            cursor += 1;
        }

        `it_index := count;
        `it := char;
        count += 1;

        #insert body;
    }
}

#if TEST
test_utf8_iterator :: () {
    strings: [] string;
    chars: [] s64;

    strings = map("Здравствуй, Мир!", utf8, string);
    pretty_assert(array_equals(strings, string.["З", "д", "р", "а", "в", "с", "т", "в", "у", "й", ",", " ", "М", "и", "р", "!"]));

    chars = map("Здравствуй, Мир!", utf8_chars, s64);
    pretty_assert(array_equals(chars, s64.[1047, 1076, 1088, 1072, 1074, 1089, 1090, 1074, 1091, 1081, 44, 32, 1052, 1080, 1088, 33]));


    strings = map("╭⢾▄⡓╮", utf8, string);
    pretty_assert(array_equals(strings, string.["╭", "⢾", "▄", "⡓", "╮"]));

    chars = map("╭⢾▄⡓╮", utf8_chars, s64);
    pretty_assert(array_equals(chars, s64.[9581, 10430, 9604, 10323, 9582]));


    strings = map("🝏🞅Πツ", utf8, string);
    pretty_assert(array_equals(strings, string.["🝏", "🞅", "Π", "ツ"]));

    chars = map("🝏🞅Πツ", utf8_chars, s64);
    pretty_assert(array_equals(chars, s64.[128847, 128901, 928, 12484]));

}

//
// string builder utilities
//

to_string :: inline (buffer: *String_Builder.Buffer) -> string {
    return string.{ data = get_buffer_data(buffer), count = buffer.count };
}

append_padding :: inline (builder: *String_Builder, count: s64, $padding := " ") {
    assert(count >= 0, "%", count);
    #assert(padding.count == 1); // TODO: it's pretty easy actually to support other counts
    global_buffer :: #run -> string {
        buffer: [] u8;
        buffer.count = 64;
        buffer.data = alloc(buffer.count);
        for *buffer it.* = padding[0];
        return xx add_global_data(buffer, .READ_ONLY);
    };

    n_repeats := count / global_buffer.count;
    for 1..n_repeats {
        append(builder, global_buffer);
    }

    tail := global_buffer;
    tail.count = count % global_buffer.count;
    append(builder, tail);
}

#if TEST
test_append_padding :: () {
    Check :: ($n: int, $padding: string) #expand {
        builder: String_Builder;
        append_padding(*builder, n, padding);
        s := builder_to_string(*builder);
        assert(s.count == n);
        for cast([] u8) s assert(it == padding[0]);
    }

    Check(3, " ");
    Check(65, " ");
    Check(64 * 7 + 13, " ");
    Check(3, "!");
    Check(65, "2");
    Check(64 * 7 + 13, "@");
}

print_ascii_or_hex :: (builder: *String_Builder, s: string) {
    for 0..s.count-1 {
        char := s[it];
        if char >= #char " " && char <= #char "~" {
            if char == #char "\\" || char == #char "\""
                append(builder, "\\");
            append(builder, char);
        } else {
            print_to_builder(builder, "\\x%", FormatInt.{ value = char, base = 16, minimum_digits = 2 });
        }
    }
}

print_ascii_or_hex :: inline (builder: *String_Builder, char: u8) {
    s: [1] u8 = .[char];
    print_ascii_or_hex(builder, cast(string) s);
}

parse_ascii_or_hex :: (input: string) -> string, ok: bool {
    result: string;
    result.data = alloc(input.count);
    result.count = input.count;

    success := false;
    defer if !success free(result);

    write_cursor := 0;
    defer result.count = write_cursor;

    read_cursor := 0;
    while read_cursor < input.count {
        back_slash := find_index_from_left(input, #char "\\", read_cursor);
        if back_slash == -1 then back_slash = input.count;

        n_to_copy := back_slash - read_cursor;
        memcpy(result.data + write_cursor, input.data + read_cursor, n_to_copy);
        write_cursor += n_to_copy;

        if back_slash == input.count break;

        read_cursor = back_slash + 1;
        if read_cursor >= input.count { return "", false; }

        c := input[read_cursor]; read_cursor += 1;
        if c == #char "\\" || c == #char "\"" {
            result[write_cursor] = c; write_cursor += 1; continue;
        }

        if c == {
            case #char "e"; result[write_cursor] = #char "\e"; write_cursor += 1; continue;
            case #char "n"; result[write_cursor] = #char "\n"; write_cursor += 1; continue;
            case #char "r"; result[write_cursor] = #char "\r"; write_cursor += 1; continue;
            case #char "t"; result[write_cursor] = #char "\t"; write_cursor += 1; continue;
        }

        if c == #char "x" {
            if read_cursor > input.count - 2 { return "", false; }
            l := input[read_cursor]; read_cursor += 1;
            h := input[read_cursor]; read_cursor += 1;

            l = inline hex_digit(l); if l > 0xf return "", false;
            h = inline hex_digit(h); if h > 0xf return "", false;

            result[write_cursor] = (l << 4) + h;
            write_cursor += 1;
            continue;
        }

        return "", false;

    }

    result.count = write_cursor;
    success = true;
    return result, true;
}

hex_digit :: inline (c: u8) -> u8 {
    if c >= #char "0" && c <= #char "9" return c - #char "0";
    if c >= #char "a" && c <= #char "f" return c - #char "a" + 10;
    if c >= #char "A" && c <= #char "F" return c - #char "A" + 10;
    return 0xff;
}

//
// ascii escape sequence handling
//

eat_visible_or_escape_sequence :: (text: string) -> head: string, visible_count: s64, tail: string {
    if !text return "", 0, "";

    count := find_index_from_left(text, #char "\e");
    if count < 0 then count = text.count;

    if count > 0 {
        // Visible character sequence
        head := substring(text, 0, count = count);
        tail := substring(text, count);

        // FIXME: this is a temporary solution probably...
        backspaces_count := count_matches(head, #char "\x08"); // '\b' in C

        return head, count - backspaces_count * 2, tail;
    }

    // Escape sequence
    count += 1;

    if count < text.count {
        char := text[count];
        if char == #char "[" {
            count += 1;
            while count < text.count {
                char = text[count];
                count += 1;

                if inline is_alpha(char) break;
            }
        } else {
            // TODO: don't care about other escape codes for now
        }
    }

    head := slice(text, 0, count);
    tail := advance(text, count);
    return head, 0, tail;
}

// FIXME: support utf8 code points
count_visible_characters :: (text: string) -> visible_count: s64 {
    if !text return 0;

    visible_count := 0;
    cursor := 0;
    while cursor < text.count {
        index := find_index_from_left(text, #char "\e", cursor);
        if index < 0 return visible_count + utf8_count(substring(text, cursor));

        visible_count += utf8_count(substring(text, cursor, index));
        cursor = index + 1; // `+ 1` to skip the current "\e"

        char := text[cursor];
        if char == #char "[" {
            cursor += 1;
            while cursor < text.count {
                char = text[cursor];
                cursor += 1;

                if char == #char "m" break;
            }
        } else {
            // TODO: don't care about other escape codes for now
        }
    }
    return visible_count;
}

only_visible_text :: (text_with_control_codes: string) -> string {
    builder: String_Builder;
    builder.allocator = temp;

    tail := text_with_control_codes;
    while tail {
        head:, visible_count:, tail = eat_visible_or_escape_sequence(tail);
        if visible_count append(*builder, head);
    }

    return builder_to_string(*builder);
}

//
// date & time utilities
//

print_date_time_for_humans :: (date_time: Calendar_Time) {
    builder: String_Builder;
    builder.allocator = temp;
    print_date_time_for_humans(*builder, date_time);
    write_builder(*builder);
}

print_date_for_humans :: (builder: *String_Builder, date_time: Calendar_Time) {
    month_short :: string.["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    print(builder, "% %", month_short[date_time.month_starting_at_0],
                          date_time.day_of_month_starting_at_0 + 1);
}

print_time_for_humans :: (builder: *String_Builder, date_time: Calendar_Time) {
    print(builder, "%:%:%", FormatInt.{value = date_time.hour,   minimum_digits = 2},
                            FormatInt.{value = date_time.minute, minimum_digits = 2},
                            FormatInt.{value = date_time.second, minimum_digits = 2});
}

print_date_time_for_humans :: (builder: *String_Builder, date_time: Calendar_Time) {
    inline print_date_for_humans(builder, date_time);
    append(builder, " ");
    inline print_time_for_humans(builder, date_time);
}

print_date_time_for_log :: (builder: *String_Builder, date_time: Calendar_Time) {
    using date_time;
    print(builder, "%-%-% %:%:%.%", year,
                                    FormatInt.{value = month_starting_at_0 + 1,        minimum_digits = 2},
                                    FormatInt.{value = day_of_month_starting_at_0 + 1, minimum_digits = 2},
                                    FormatInt.{value = hour,                           minimum_digits = 2},
                                    FormatInt.{value = minute,                         minimum_digits = 2},
                                    FormatInt.{value = second,                         minimum_digits = 2},
                                    FormatInt.{value = millisecond,                    minimum_digits = 3});
}

//
// pretty assert
//

// Constant structs don't work with compile time constructs yet, so we return
// all fields directly
get_expr_info :: (code: Code) -> kind: Code_Node.Kind, op_type: s32, full_expr: string, proc_expr: string, lhs: Code, rhs: Code {
    #import "Program_Print";

    root := compiler_get_nodes(code);

    builder: String_Builder;
    print_expression(*builder, root);
    full_expr := builder_to_string(*builder);

    if root.kind == {
        case .BINARY_OPERATOR;
            binop := cast(*Code_Binary_Operator) root;
            op_type := binop.operator_type;
            lhs := compiler_get_code(binop.left, code);
            rhs := compiler_get_code(binop.right, code);
            return xx root.kind, op_type, full_expr, "", lhs, rhs;

        case .PROCEDURE_CALL;
            proccall := cast(*Code_Procedure_Call) root;
            if proccall.arguments_sorted.count != 2 {
                dummy : Code = #code null;
                return xx root.kind, -1, full_expr, "", dummy, dummy;
            }

            builder: String_Builder;
            print_expression(*builder, proccall.procedure_expression);
            proc_expr := builder_to_string(*builder);

            lhs := compiler_get_code(proccall.arguments_sorted[0], code);
            rhs := compiler_get_code(proccall.arguments_sorted[1], code);
            return xx root.kind, -1, full_expr, proc_expr, lhs, rhs;

        case;

    }

    dummy : Code = #code null;
    return xx root.kind, -1, full_expr, "", dummy, dummy;
}

pretty_assert :: (code: Code, loc := #caller_location) #expand {
    if #insert code return;

    if context.handling_assertion_failure  return;  // Avoid infinite loops.
    context.handling_assertion_failure = true;

    kind, op_type, full_expr, proc_expr, lhs, rhs :: #run get_expr_info(code);

    message := "";

    #if kind == .BINARY_OPERATOR {
        builder : String_Builder;
        builder.allocator = temporary_allocator;

        print_to_builder(*builder, "(%) = (% ", full_expr, #insert lhs);

        if op_type < 128 {
            append(*builder, cast(u8) op_type);
        } else {
            append(*builder, operator_to_string(xx op_type));
        }

        print_to_builder(*builder, " %) = false", #insert rhs);
        message = builder_to_string(*builder,, temporary_allocator);
    } else #if kind == .PROCEDURE_CALL {
        l := tprint("%", #insert lhs);
        r := tprint("%", #insert rhs);
        if l.count > 40 {
            message = tprint("(\n    %\n) = (\n    %(\n        %,\n        %\n    )\n) = false", full_expr, proc_expr, #insert lhs, #insert rhs);
        } else {
            message = tprint("(%) = (%(%, %)) = false", full_expr, proc_expr, #insert lhs, #insert rhs);
        }
    } else {
        message = tprint("(%) = false", full_expr);
    }

    // We provide 'loc' in case _STACK_TRACE is turned off, but assertion_failed may well
    // look at the stack trace if it is available.
    context.assertion_failed(loc, message);
    debug_break();
    context.handling_assertion_failure = false;

} @NoProfile

//
// Mem_Dump
//

Setup_Mem_Dump_Printer :: () #expand {
    old_struct_printer := context.print_style.struct_printer;
    `defer context.print_style.struct_printer = old_struct_printer;
    context.print_style.struct_printer = mem_dump_printer;
}

Mem_Dump :: #type,distinct [] u8;
mem_dump_printer :: (builder: *String_Builder, any: Any, data: *void) -> handled: bool {
    if any.type != type_info(Mem_Dump) return false;

    data := << cast(*[] u8) any.value_pointer;
    mem_dump_to_builder(builder, data);
    return true;
}

mem_dump_to_builder :: (builder: *String_Builder, data: [] u8) {
    old_default_format_int := context.print_style.default_format_int;
    defer context.print_style.default_format_int = old_default_format_int;
    context.print_style.default_format_int = FormatInt.{ base = 16, minimum_digits = 2 };

    leading_spaces := cast(s64) (cast(u64) data.data) % 16;
    start_addr := cast(* u8) (cast(u64) data.data) & 0xffff_ffff_ffff_fff0;

    print_to_builder(builder, "%: ", start_addr);
    for 0..(data.count + leading_spaces - 1) {
        if it < leading_spaces then
            append(builder, "  ");
        else
            print_to_builder(builder, "%", data[it - leading_spaces]);

        if (it + 1) % 16 == 0 && it + 1 != data.count + leading_spaces
            print_to_builder(builder, "\n%: ", start_addr + it + 1);
        else if (it + 1) % 4 == 0
            append(builder, " ");
    }
}

//
// flat pool utilities
//

flat_pool_allocated :: (pool: *Flat_Pool) -> s64 {
    return pool.current_point - pool.memory_base;
}

//
// process info
//

#if OS == .LINUX {
    #import "POSIX";

    Pid :: s64;

    Process_Info :: struct {
        pid: Pid;
        parent_pid: Pid = -1;

        command_line: [] string;

        state: [1] u8;

        started_seconds_since_boot: s64;
        user_mode_time_seconds: s64;
        kernel_mode_time_seconds: s64;

        virtual_memory_kibi_bytes: s64;
        resident_set_pages_count: s64;

        tty_name: string;
        tty_number: s64;
    }


    get_process_command_line :: (pid: Pid, log_errors := false) -> [] string, ok: bool {
        cmdline, ok := my_read_entire_file(tprint("/proc/%/cmdline", pid), log_errors=log_errors,, temp);
        if !ok return .[], false;

        if !cmdline return .[], true;

        result: [..] string;
        result.allocator = context.allocator;

        tail := cmdline;
        while tail {
            found:, arg:, tail = split_from_left(tail, #char "\x00");
            array_add(*result, copy_string(arg));
        }
        return result, true;
    }

    get_process_info :: (pid: Pid, info: *Process_Info, clock_ticks_per_second := -1, get_command_line := true, log_errors := true) -> bool {
        stat, ok := my_read_entire_file(tprint("/proc/%/stat", pid), log_errors=log_errors,, temp);
        if !ok return false;

        if clock_ticks_per_second == -1 {
            #if OS == .LINUX {
                clock_ticks_per_second = xx sysconf(_SC_CLK_TCK);
            } else {
                assert(false, "only linux for now");
            }
        }

        info.pid = pid;

        tail := stat;
        i := 1;

        while tail {
            defer i += 1;
            found:, s:, tail = split_from_left(tail, #char " ");

            if s[0] == #char "(" && find_index_from_left(s, #char ")") == -1 {
                count := find_index_from_left(tail, #char ")");
                assert(count > 0);
                // Skip ')' & ' ' right after it
                advance(*tail, count + 2);
                s.count += count + 2;
                continue;
            }

            if i == 3 {
                assert(s.count == 1);
                info.state[0] = s[0];
            }
            if i == 4 {
                parent_pid_value:, ok = string_to_int(s, base=10, T=s64);
                if !ok {
                    if log_errors log_error("Expected an integer as column #%", i);
                    return false;
                }
                info.parent_pid = xx parent_pid_value;
            }
            if i == 7 {
                info.tty_number, ok = string_to_int(s, base=10, T=s64);
                if !ok {
                    if log_errors log_error("Expected an integer as column #%", i);
                    return false;
                }
            }
            if i == 14 {
                umode:, ok = string_to_int(s, base=10, T=s64);
                if !ok {
                    if log_errors log_error("Expected an integer as column #%", i);
                    return false;
                }
                info.user_mode_time_seconds = umode / clock_ticks_per_second;
            }
            if i == 15 {
                smode:, ok = string_to_int(s, base=10, T=s64);
                if !ok {
                    if log_errors log_error("Expected an integer as column #%", i);
                    return false;
                }
                info.kernel_mode_time_seconds = smode / clock_ticks_per_second;
            }
            if i == 22 {
                starttime:, ok = string_to_int(s, base=10, T=s64);
                if !ok {
                    if log_errors log_error("Expected an integer as column #%", i);
                    return false;
                }
                info.started_seconds_since_boot = xx (starttime / clock_ticks_per_second);
            }
            if i == 23 {
                // XXX: this is some weird value, don't think it's actually usefull
                info.virtual_memory_kibi_bytes, ok = string_to_int(s, base=10, T=s64);
                if !ok {
                    if log_errors log_error("Expected an integer as column #%", i);
                    return false;
                }
            }
            if i == 24 {
                info.resident_set_pages_count, ok = string_to_int(s, base=10, T=s64);
                if !ok {
                    if log_errors log_error("Expected an integer as column #%", i);
                    return false;
                }
            }
        }

        // TODO: get tty_name

        if get_command_line {
            command_line, ok := get_process_command_line(info.pid, log_errors=log_errors);
            if !ok return false;
            info.command_line = command_line;
        }

        return true;
    }
}

//
// file utilities
//

read_entire_file_to_builder :: inline (builder: *String_Builder, name: string) -> bool {
    f, success := file_open(name, log_errors = false);
    if !success return false;

    defer file_close(*f);

    return read_entire_file_to_builder(builder, f);
}

read_entire_file_to_builder :: (builder: *String_Builder, f: File) -> bool {
    length, success := my_file_length(f);
    if !success return false;

    if !builder.initialized init_string_builder(builder);

    saved := builder.subsequent_buffer_size;
    defer builder.subsequent_buffer_size = saved;
    if length > builder.subsequent_buffer_size {
        builder.subsequent_buffer_size = length;
    }

    prev_buffer: *String_Builder.Buffer;
    buffer := get_current_buffer(builder);
    if buffer.allocated - buffer.count < length {
        expand(builder);
        prev_buffer = buffer;
        buffer = get_current_buffer(builder);
    }
    buffer_data := get_buffer_data(buffer);
    assert(buffer.allocated >= length);

    total_read_count := 0;
    while total_read_count != length {
        remaining_to_read := length - total_read_count;
        read_count := fread(buffer_data + total_read_count, 1, xx remaining_to_read, f.handle);
        if read_count == 0 break;
        if read_count < 0 {
            if prev_buffer.next == buffer {
                prev_buffer.next == null;
                builder.current_buffer = prev_buffer;
                free(buffer);
            }
            return false;
        }
        total_read_count += xx read_count;
    }
    assert(total_read_count == length);
    buffer.count = length;

    return true;
}

my_read_entire_file :: (name: string, log_errors := true) -> string, bool {
    s: string;
    f, success := file_open(name, log_errors = log_errors);
    if !success return s, false;

    defer file_close(*f);

    s, success = my_read_entire_file(f);

    if log_errors && !success {
        // If we put this error report at a lower level, we could
        // indicate how far into the file the error occurred, etc.
        code, s := System.get_error_value_and_string();
        log_error("Read of '%' failed: code %, '%'.\n", name, code, s);
    }

    return s, success;
}

my_read_entire_file :: (f: File, zero_terminated := false, log_errors := true) -> string, bool {
    length, success := my_file_length(f);

    if !success || length == 0 {
        // Maybe special linux "file"
        builder: String_Builder;
        builder.allocator = context.allocator;

        while true {
            buffer := ensure_contiguous_space_and_return_available_range(*builder);
            read_count := fread(buffer.data, 1, xx buffer.count, f.handle);
            if read_count == 0 break;
            assert(read_count > 0);

            advance_through_ensured_space(*builder, xx read_count);
        }

        return builder_to_string(*builder), true;
    }

    length_with_zero_termination := length + cast(s32) zero_terminated;
    data := cast(*u8) alloc(length_with_zero_termination);
    if data == null {
        if log_errors log_error("failed to allocate % bytes", length_with_zero_termination);
        return "", false;
    }

    // documentation seems to suggest that fread gaurantees size*count is fully read back otherwise error
    rc := fread(data, 1, cast (u64) length, f.handle);
    if rc < 0 {
        free(data);
        return "", false;
    }
    assert(rc == xx length);

    s: string;
    s.count = length;
    s.data  = data;

    if zero_terminated s.data[length] = 0;

    return s, true;
}

// Copy-pasted version of file_length which replaces ftello64 with ftello
my_file_length :: (file: File) -> (length: s64, success: bool) {
    position_current := ftello(file.handle);
    if (position_current == -1) || (position_current == DUMB_LINUX_FAILURE_NUMBER) return 0, false;

    fseek(file.handle, 0, SEEK_END);
    len := ftello(file.handle);
    if (len == -1) || (len == DUMB_LINUX_FAILURE_NUMBER) return 0, false;

    fseek(file.handle, position_current, SEEK_SET);
    return len, true;
}

my_file_length :: (fd: s32) -> (length: s64, success: bool) {
    old_offset := lseek(fd, 0, SEEK_CUR);
    if (old_offset == -1)  return 0, false;

    length := lseek(fd, 0, SEEK_END);
    if (length == -1)  return 0, false;

    lseek(fd, old_offset, SEEK_SET);
    return length, true;
}

file_stdin :: () -> File {
    #if OS == .WINDOWS {
        #import "Windows";

        handle := GetStdHandle(STD_INPUT_HANDLE);
        assert(handle != INVALID_HANDLE_VALUE);

        return File.{ handle };
    } else {
        #import "POSIX";
        libc :: #system_library "libc";
        fdopen :: (fd: s32, mode: *u8) -> *FILE #foreign libc;

        handle := fdopen(STDIN_FILENO, "r");
        assert(handle != null);

        return File.{ handle };
    }
}

//
// color
//

// stolen from modules/GetRect/module.jai
rgb_to_hsv :: (r: float, g: float, b: float) -> (h: float, s: float, v: float) {
    rgb_min := min(r, g, b);
    rgb_max := max(r, g, b);

    if rgb_max == 0  return 0, 0, 0;

    v := rgb_max;

    delta := rgb_max - rgb_min;

    s := delta / rgb_max;
    if s == 0 {  // This covers the case when rgb_max == rgb_min, so we don't worry about dividing by 0 below.
        return 0, 0, v;
    }

    h: float = ---;
    K :: (43/255.0);
    if rgb_max == r
        h = 0 + K * (g - b) / delta;
    else if rgb_max == g
        h = (85/255.0) + K * (b - r) / delta;
    else
        h = (171/255.0) + K * (r - g) / delta;

    return h*360, s, v;
}

//
// private imports
//

#scope_module

#if OS == .LINUX {
    libc :: #system_library "libc";
    sysconf :: (name: s32) -> s64 #foreign libc;
}

#import "Basic";
#import "String";
#import "Compiler";
#import "Flat_Pool";
#import "File";
System :: #import "System";
