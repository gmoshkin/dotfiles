//
// Parsing `<file>:<line>:<col>` style source locations out of arbitrary text,
// e.g. compiler diagnostics scrolled back in a tmux pane.
//
// Shared by `tmux-util` (crawl-locations) and `nvim-open`.
//

// Set to have `parse_source_location` log why it rejected a candidate. Named
// differently from `tmux-util`'s own `debug` so that importing this module
// doesn't make that identifier ambiguous.
debug_parsing := false;

parse_source_location :: (text: string, line_start: bool) -> (cursor: int, filename: string, line_no: int, column_no: int) {
    cursor := 0;
    seen_slash := false;
    dot_count := 0;
    digit_count := 0;
    other_count := 0;

    // @Incomplete support other stuff as well?
    // if text[cursor] == #char "[" cursor += 1;

    // A path quoted in prose or in a diagnostic often comes wrapped in
    // parentheses -- `(jai/pageview.jai)`. Parentheses are path characters
    // because of MSVC's `filename.ext(123)` and Windows' `Program Files (x86)`,
    // so they cannot simply be dropped: instead a parenthesis we start on is
    // taken to be somebody else's, and the loop below stops at a `)` that closes
    // nothing we opened ourselves.
    //
    // Skipping the one we start on is also what keeps this from consuming
    // nothing at all. Callers walk a line by advancing over whatever we report,
    // and a `)` is a path character, so returning 0 for one leaves them standing
    // on it forever.
    if cursor < text.count && (text[cursor] == #char "(" || text[cursor] == #char ")") cursor += 1;

    filename_start := cursor;
    open_parens := 0;

    //
    // optional windows style drive prefix
    //

    is_windows := is_windows_path(advance(text, cursor));
    if cursor <= text.count && is_windows {
        // Windows style filepath, skip the drive prefix so that the colon
        // doesn't break the loop below
        cursor += 2;
    }

    //
    // filename
    //

    while cursor < text.count {
        c := text[cursor];
        if (!inline is_file_path_char(c)) && !(is_windows && c == #char " ") break;

        if c == #char ")" && open_parens == 0 break;
        if c == #char "(" open_parens += 1;
        if c == #char ")" open_parens -= 1;

        cursor += 1;

        if c == #char "/" || c == #char "\\" {
            seen_slash = true;
            // These only count in filename (not path)
            dot_count = 0;
            digit_count = 0;
            other_count = 0;
            continue;
        }

        if c == #char "." { dot_count += 1; continue; }
        if inline is_digit(c) { digit_count += 1; continue; }
        other_count += 1;
    }

    //
    // filename heuristics
    //

    if !((other_count > 0) && (seen_slash || dot_count > 0)) {
        if debug_parsing log("other_count: %, seen_slash: %, dot_count: %", other_count, seen_slash, dot_count);
        return cursor, "", 0, 0;
    }
    if line_start && (digit_count > 0) && (dot_count > 1) && (other_count == 0) {
        if debug_parsing log("line_start: %, digit_count: %, dot_count: %, other_count: %", line_start, digit_count, dot_count, other_count);
        // Looks like something weird (probably ip address) ignore it
        return cursor, "", 0, 0;
    }

    filename := slice(text, filename_start, cursor - filename_start);

    if !seen_slash {
        if filename[filename.count - 1] == #char "." return cursor, "", 0, 0;
        if count_matches(filename, #char ".") > 1 return cursor, "", 0, 0;
    }

    // Stupid MSVC uses `C:\Program Files (x86)\Path to filename.ext(123):` format
    // We have stopped here --------------------------------------------^
    // So now we have to walk back over `(123)`
    if filename[filename.count - 1] == #char ")" {
        p := filename.count - 2;
        seen_digit := false;
        while p > 0 {
            if !(inline is_digit(filename[p])) break;
            seen_digit = true;
            p -= 1;
        }
        if seen_digit && p > 0 && filename[p] == #char "(" {
            filename.count -= (cursor - p);
            cursor = p;
        }
    }

    tail := advance(text, cursor);
    if !tail return cursor, filename, 0, 0;

    c := tail[0];
    // MSVC uses `C:\path\to\filename.ext(123):`
    if c != #char ":" && c != #char "(" return cursor, filename, 0, 0;

    tail = advance(tail, 1);
    cursor += 1;
    if !tail return cursor, filename, 0, 0;

    //
    // line number
    //

    if !(inline is_digit(tail[0])) return cursor, filename, 0, 0;

    line_no:, tail = parse_positive_number(tail);
    cursor = ifx tail then tail.data - text.data else text.count;

    if !(tail && (tail[0] == #char ":" || tail[0] == #char ",")) {
        return cursor, filename, line_no, 0;
    }

    tail = advance(tail, 1);
    cursor += 1;
    if !tail return cursor, filename, line_no, 0;

    //
    // column number
    //

    if !(inline is_digit(tail[0])) return cursor, filename, line_no, 0;

    column_no:, tail = parse_positive_number(tail);
    cursor = ifx tail then tail.data - text.data else text.count;

    return cursor, filename, line_no, column_no;
}

is_file_path_char :: (char: u8) -> bool {
    return (inline is_alpha(char)) || (inline is_digit(char))
        || char == #char "-" || char == #char "_" || char == #char "~" || char == #char "(" || char == #char ")"
        || char == #char "." || char == #char "/" || char == #char "\\";
}

is_windows_path :: (path: string) -> bool {
    if path.count < 2 return false;
    c := path[0];
    return (c >= #char "A") && (c <= #char "Z") && (path[1] == #char ":");
}

convert_windows_path_to_wsl :: (builder: *String_Builder, path: string) {
    tail := path;
    if tail.count > 1 && tail[1] == #char ":" {
        append(builder, "/mnt/");
        append(builder, to_lower(tail[0]));

        tail = advance(tail, 2);
    }

    while tail {
        found:, head:, tail = split_from_left(tail, #char "\\");
        append(builder, head);
        if found then append(builder, #char "/");
    }
}

#import "Basic";
#import "String";
#import "My_Util";
