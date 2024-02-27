#module_parameters() (TEST := false);
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
        return head, count, tail;
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

                if char == #char "m" break;
            }
        } else {
            // TODO: don't care about other escape codes for now
        }
    }

    head := substring(text, 0, count = count);
    tail := substring(text, count);
    return head, 0, tail;
}

count_visible_characters :: (text: string) -> visible_count: s64 {
    if !text return 0;

    visible_count := 0;
    cursor := 0;
    while cursor < text.count {
        index := find_index_from_left(text, #char "\e", cursor);
        if index < 0 return visible_count + text.count - cursor;

        visible_count += index - cursor;
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

//
// private imports
//

#scope_module

#import "Basic";
#import "String";
