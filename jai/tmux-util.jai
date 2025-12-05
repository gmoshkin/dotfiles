debug := false;

subcommands :: struct { argument: string; proc: #type (args: [] string) -> (bool, string); }.[
    .{ "status-line-left",  status_line_left, },
    .{ "status-line-right", status_line_right, },
    .{ "new-session",       new_session_subcommand, },
    .{ "crawl-locations",   crawl_locations_subcommand, },
    .{ "capture-last-command-output",   capture_last_command_output_subcommand, },
    .{ "temperature",       temperature_subcommand, },
];

main :: () {
    context.logger = my_logger;

    args := get_command_line_arguments();
    maybe_show_version_banner_and_exit();

    cursor := 1;
    while cursor < args.count {
        arg := args[cursor];
        if arg == {
        case "-d"; #through;
        case "--debug";
            debug = true;
            cursor += 1;
        case "-h"; #through;
        case "--help";
            show_usage();
            exit(0);
        case; break;
        }
    }

    if cursor >= args.count {
        show_usage();
        exit(1);
    }

    for subcommands {
        if args[cursor] == it.argument {
            ok, error := it.proc(advance(args, cursor + 1));
            if !ok {
                log_error("%", error);
                command("tmux", "display", error);
                exit(1);
            }
            return;
        }
    }

    log_error("Unknown subcommand '%'", args[1]);
    show_usage();
    exit(1);
}

show_usage :: () {
    args := get_command_line_arguments();

    names: [..] string;
    for subcommands array_add(*names, it.argument);
    log("usage: % [--version|--help|--debug] [%]", args[0], join(..names, "|"));
}

//
// subcommand: status-line-left
//

status_line_left :: (args: [] string) -> (bool, string) {
    segments_raw := Segment.[
        .{
            text = join(
                "#{?client_prefix,#[fg=colour4]☻, } ",
                "#{?pane_in_mode,#{?selection_present,#[fg=colour5]★,#[fg=colour2]★}, }"
            ),
            attr = .{"colour7", "colour235"},
        },
        // .{ proc = segment_current_path },
        .{ text = "#S:#I.#P",   attr = .{"colour233", "colour240"} },
        .{ text = "#H",         attr = .{"colour233", "colour237"} },
        .{ proc = git_branch },
        .{ proc = git_compare_to_upstream },
        .{ proc = git_staged },
        .{ proc = git_unstaged },
        .{ proc = git_untracked },
    ];

    {
        ok, out := command("tmux", "display", "-p", "#{pane_current_path}");
        if ok pane_current_path = out;
    }

    segments : [..] Segment;
    for *segments_raw {
        if it.proc != no_proc {
            it.text, it.attr = it.proc();
        }
        if it.text array_add(*segments, it.*);
    }

    sb : String_Builder;
    for segments {
        print_to_builder(*sb, "#[fg=%,bg=%] % ", it.attr.fg, it.attr.bg, it.text);
    }
    write_builder(*sb);
    print("\n");

    return true, "";
}

//
// subcommand: status-line-right
//

status_line_right :: (args: [] string) -> (bool, string) {
    segments_raw := Segment.[
        // maybe lan/wan address? do I need it even?
        .{ proc = cpu_frequency },
        .{ proc = cpu_temperature },
        .{ proc = battery },
        .{ proc = date_time },
    ];

    {
        ok, out := command("tmux", "display", "-p", "#{pane_current_path}");
        if ok pane_current_path = out;
    }

    segments : [..] Segment;
    for *segments_raw {
        if it.proc != no_proc {
            it.text, it.attr = it.proc();
        }
        if it.text array_add(*segments, it.*);
    }

    sb : String_Builder;

    for segments {
        print_to_builder(*sb, "#[fg=%,bg=%] % ", it.attr.fg, it.attr.bg, it.text);
    }
    write_builder(*sb);
    print("\n");

    return true, "";
}

//
// subcommand: new-session
//

new_session_subcommand :: (args: [] string) -> (ok: bool, error: string) {
    debug = contains(args, (a) => a == "-d" || a == "--debug");

    // Read path from stdin
    data, ok := my_read_entire_file(file_stdin());
    if !ok {
        return false, "failed to read stdin";
    }

    data = trim(data);
    if !data {
        return false, "empty file path";
    }

    // Get filename from path
    full_path := data;
    filename := path_filename(full_path);
    if !filename {
        return false, "empty file path";
    }

    // Get current tmux sessions and their paths
    sessions, ok=, err := get_tmux_sessions();
    if !ok {
        return false, err;
    }

    session := filename;
    found, path := table_find(*sessions, session);
    if !found {
        ok, err = command("tmux", "new-session", "-d", "-s", session, "-c", full_path);
        if !ok return false, err;
        ok, err = command("tmux", "switch-client", "-t", session);
        if !ok return false, err;
    } else if path == full_path {
        ok, err = command("tmux", "switch-client", "-t", session);
        if !ok return false, err;
    } else {
        return false, tprint("% != %", path, full_path);
    }

    return true, "";
}

get_tmux_sessions :: () -> (Table(string, string), bool, string) {
    result: Table(string, string);
    init(*result);

    ok, output := command("tmux", "display", "-p", "#{S:#{P:#{?#{==:#P,0},#S:#{pane_current_path};,}}}");
    if !ok {
        return result, false, output;
    }

    tail := output;
    while tail {
        found:, line:, tail = split_from_left(tail, #char ";");
        if !line continue;

        found=, session, path := split_from_left(line, #char ":");
        if !found continue;

        table_add(*result, session, path);
    }

    return result, true, "";
}

//
// subcommand: crawl-locations
//

crawl_locations_subcommand :: (args: [] string) -> (ok: bool, error: string) {
    if !args.count {
        return false, "expected a target pane specifier as first argument";
    }

    output_json := false;
    crawl_the_whole_history := false;
    need_line := false;

    target_pane: string;

    cursor := 0;
    while cursor < args.count {
        arg := args[cursor];
        cursor += 1;
        if arg == {
        case "--json"; output_json = true;
        case "--all"; crawl_the_whole_history = true;
        case "--need-line"; need_line = true;
        case "--debug"; debug = true;
        case "-d";      debug = true;
        case;
            if starts_with(arg, "-") return false, tprint("Unexpected argument: `%`", arg);
            target_pane = arg;
            break;
        }
    }

    ok, output := command("tmux", "capture-pane", "-pJS-", "-t", target_pane);
    if !ok {
        return false, tprint("error: %", output);
    }

    Source_Location :: struct {
        filename: string;
        line_no: int;
        column_no: int;
        info: string;
        info_type: u8;
    };
    locations: [..] Source_Location;

    Same_Location :: (l: *Source_Location, r: *Source_Location) -> bool {
        return l.filename == r.filename && l.line_no == r.line_no && l.column_no == r.column_no;
    }

    // Remeber, we're going in reverese line order, so next line is the one we've seen previously
    next_line_is_rust_location := false;
    line_count := 0;
    for :reverse_lines line: output {
        // Only look for locations in last command's output.
        // @Incomplete make this more general
        if !crawl_the_whole_history && locations.count > 0 && starts_with(line, "╭(gmoshkin@") break;

        if next_line_is_rust_location {
            next_line_is_rust_location = false;

            location := last(*locations);
            location.info = line;
            if starts_with(line, "error") {
                location.info_type = #char "E";
            } else if starts_with(line, "warning") {
                location.info_type = #char "W";
            } else if starts_with(line, "note") {
                location.info_type = #char "N";
            }
            continue;
        }

        cursor := 0;

        // TODO: maybe I only want locations at start of line???
        while cursor < line.count {
            while cursor < line.count && (inline is_space(line[cursor])) cursor += 1;
            if cursor >= line.count continue;

            tail := advance(line, cursor);
            cursor_offset, filename, line_no, column_no := parse_source_location(tail, cursor == 0);

            if debug log("parse_source_location('%') -> '%', %, %", tail, filename, line_no, column_no);
            if !filename || need_line && line_no <= 0 {
                cursor += cursor_offset;
                while cursor < line.count && (!inline is_file_path_char(line[cursor])) cursor += 1;
                continue;
            }

            info: string;
            prefix := trim(slice(line, 0, cursor));
            postfix := trim(advance(line, cursor + cursor_offset));
            if prefix && postfix {
                info = sprint("%1 ... %2", prefix, postfix);
            } else if prefix {
                info = sprint("% ...", prefix);
            } else {
                info = postfix;
            }

            location := Source_Location.{ filename, line_no, column_no, info, 0 };

            prev_location := last(*locations);
            if prev_location && Same_Location(prev_location, *location) {
                // Remeber we're going in reverse line order
                prev_location.info = sprint("%\\n%", info, prev_location.info);
            } else {
                array_add(*locations, location);
            }

            if ends_with(trim_right(prefix), "-->") then next_line_is_rust_location = true;

            // Only one source location per line
            break;
        }
        line_count += 1;
    }

    builder: String_Builder;

    Print_Location_Fields :: inline (builder: *String_Builder, using location: Source_Location) {
        append(builder, "\"filename\": \"");

        if OS == .LINUX && is_windows_path(filename) {
            convert_windows_path_to_wsl(builder, filename);
        } else {
            append(builder, filename);
        }
        append(builder, "\"");

        if line_no > 0 then   print(builder, ", \"lnum\": %", line_no);
        if column_no > 0 then print(builder, ", \"col\": %", column_no);

        if info {
            append(builder, ", \"text\": \"");
            print_ascii_or_hex(builder, info);
            append(builder, "\"");
        }

        type: [1] u8 = .[info_type];
        if info_type print(builder, ", \"type\": \"%\"", cast(string, type));
    }

    if output_json {
        append(*builder, "[\n");
        if locations {
            it := last(locations);
            print(*builder, "    {");
            Print_Location_Fields(*builder, it);
            append(*builder, "}");
        }

        if locations.count > 1 for < array_view(locations, 0, locations.count - 1) {
            using it;
            print(*builder, ",\n    {");
            Print_Location_Fields(*builder, it);
            append(*builder, "}");
        }

        append(*builder, "\n]\n");
    } else {
        for < locations {
            using it;
            if line_no <= 0 {
                print(*builder, "'%'", filename);
            } else if column_no <= 0 {
                print(*builder, "'%:%'", filename, line_no);
            } else {
                print(*builder, "'%:%:%'", filename, line_no, column_no);
            }

            if it.info print(*builder, ": %", it.info);

            append(*builder, "\n");
        }
    }

    write_builder(*builder);

    return true, "";
}

parse_source_location :: (text: string, line_start: bool) -> (cursor: int, filename: string, line_no: int, column_no: int) {
    cursor := 0;
    seen_slash := false;
    dot_count := 0;
    digit_count := 0;
    other_count := 0;

    // @Incomplete support other stuff as well?
    // if text[cursor] == #char "[" cursor += 1;

    filename_start := cursor;

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
        if debug log("other_count: %, seen_slash: %, dot_count: %", other_count, seen_slash, dot_count);
        return cursor, "", 0, 0;
    }
    if line_start && (digit_count > 0) && (dot_count > 1) && (other_count == 0) {
        if debug log("line_start: %, digit_count: %, dot_count: %, other_count: %", line_start, digit_count, dot_count, other_count);
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


//
// subcommand: capture-last-command-output
//

capture_last_command_output_subcommand :: (args: [] string) -> (ok: bool, error: string) {
    target_pane: string;

    num_matches_to_skip := 1;

    cursor := 0;
    while cursor < args.count {
        arg := args[cursor];
        cursor += 1;
        if arg == {
        case "-t";
            if cursor >= args.count return false, sprint("expected argument after `%`", arg);
            target_pane = args[cursor];
            cursor += 1;
        case "--skip";
            if cursor >= args.count return false, sprint("expected argument after `%`", arg);
            value := args[cursor];
            cursor += 1;

            num_matches_to_skip=, tail := parse_positive_number(value);
            if tail == value || trim(tail) != "" return false, sprint("expected a positive number after `%`, got `%`", arg, value);
        }
    }

    cmd: [..] string;
    cmd.allocator = temp;
    array_add(*cmd, "tmux", "capture-pane", "-epJS-");
    if target_pane then array_add(*cmd, "-t", target_pane);

    ok, output := command(..cmd);
    if !ok {
        return false, sprint("error: %", output);
    }

    t0 := seconds_since_init();

    matches := 0;
    last_seen_line: string;
    for :reverse_lines line: output {
        defer last_seen_line = line;

        auto_release_temp();

        if !contains(line, #char "@") continue;
        if !contains(line, "gmoshkin") continue;

        only_text := only_visible_text(line);
        if starts_with(only_text, "╭(gmoshkin@") {
            matches += 1;
            if matches > num_matches_to_skip break;
        }
    }

    elapsed := seconds_since_init() - t0;

    result := advance(output, last_seen_line.data - output.data);
    write_string(result);

    return true, "";
}

//
// subcommand: temperature
//

temperature_subcommand :: (args: [] string) -> (ok: bool, error: string) {
    info := get_temperature();

    max_name_length := 0;
    for info max_name_length = max(max_name_length, it.zone_name.count);

    builder: String_Builder;
    for info {
        using it;

        append(*builder, zone_name);
        append(*builder, ":");
        append_padding(*builder, max_name_length - zone_name.count + 3);

        degree := millidegree / 1000;
        append(*builder, color_from_degrees(degree));
        print(*builder, "%°\e[0m\n", f2(degree));
    }
    write_builder(*builder);

    return true, "";
}

f1 :: (v: int) -> FormatInt #expand {
    return FormatInt.{ value = v, minimum_digits = 1 };
}

color_from_degrees :: (degree: int, $ansii := true) -> string {

    #if ansii {
        if      degree >= 75  return "\e[31m";
        else if degree >= 45  return "\e[33m";
        else if degree >= 35  return "\e[32m";
        else                  return "\e[34m";
    } else {
        if      degree >= 75  return "red";
        else if degree >= 45  return "yellow";
        else if degree >= 35  return "green";
        else                  return "blue";
    }
}

Thermal_Info :: struct {
    zone_name: string;
    millidegree: int;
}

get_temperature :: (looking_for_name: string = "") -> [] Thermal_Info {
    thermal_zones: [..] string;
    visitor :: (info: *File_Visit_Info, thermal_zones: *[..] string) {
        if starts_with(info.short_name, "thermal_zone") {
            array_add(thermal_zones, copy_string(info.short_name));
        }
    };
    {
        // Disable log_error, because this function doesn't take a log_errors parameter
        saved_logger := context.logger;
        defer context.logger = saved_logger;
        context.logger = (_: string, _: *void, _: Log_Info) {};
        ok := visit_files("/sys/class/thermal", recursive=false, user_data=*thermal_zones, proc=visitor, visit_files=false, visit_directories=true, visit_symlinks=true);
        assert(ok);
    }

    info: [..] Thermal_Info;

    for zone: thermal_zones {
        name, ok := my_read_entire_file(tprint("/sys/class/thermal/%/type", zone));
        if !ok continue;

        name = trim(name);
        if looking_for_name && name != looking_for_name continue;

        temp:, ok = my_read_entire_file(tprint("/sys/class/thermal/%/temp", zone));
        if !ok continue;

        temp = trim(temp);
        millidegree:, ok = parse_int(*temp);
        if !ok continue;

        array_add(*info, .{ name, millidegree });
    }

    quick_sort(info, (l, r) => compare_strings(l.zone_name, r.zone_name));

    return info;
}

is_wsl_global: enum { DONT_KNOW_YET; DEFINITELY_NOT; DEFINITELY_YES; } = .DONT_KNOW_YET;

is_wsl :: () -> bool {
    if is_wsl_global == .DONT_KNOW_YET {
        ok, out := command("uname", "-r");
        assert(ok);

        if contains(out, "WSL") || contains(out, "wsl") {
            is_wsl_global = .DEFINITELY_YES;
        } else {
            is_wsl_global = .DEFINITELY_NOT;
        }
    }

    return is_wsl_global == .DEFINITELY_YES;
}

//
// segments {{{
//

git_branch :: () -> string, Attr {
    Check_Ok(pane_current_path);

    ok, out := command("git", "rev-parse", "--abbrev-ref", "HEAD", cwd = pane_current_path);
    if !ok return "", .{}; // Probably not a git directory

    if out != "HEAD" return tprint("⎇ %", trim(out)), .{"colour15", "colour4"};

    ok, out = command("git", "rev-parse", "--short", "HEAD", cwd = pane_current_path);
    Check_Ok(ok);

    return tprint(" %", trim(out)), .{"colour15", "colour4"};
}

git_compare_to_upstream :: () -> string, Attr {
    Check_Ok(pane_current_path);

    ok, out := command("git", "--no-optional-locks", "status", "-sb", cwd = pane_current_path);
    if !ok return "", .{}; // Probably not a git directory

    my_line: string;
    for split(out, cast(u8) #char "\n")
        if starts_with(it, "##") {
            my_line = it;
            break;
        }
    if !my_line return "", .{};

    i := find_index_from_right(my_line, #char "[");
    if i < 0 return "", .{};

    ahead_behind := slice(my_line, i, 0xffff); // get rest of line
    sb: String_Builder;
    Return :: () #expand { `return builder_to_string(*sb), .{"colour15", "colour5"}; }
    while true {
        token :: #bake_arguments parse_token(delimiters = "[,]");

        t, ok := token(*ahead_behind);
        if !ok Return();

        if t == {
        case "ahead";
            t, ok := token(*ahead_behind);
            if !ok Return();

            print_to_builder(*sb, " ↑ %", t);
        case "behind";
            t, ok := token(*ahead_behind);
            if !ok Return();

            print_to_builder(*sb, " ↓ %", t);
        case;
            // skip
        }
    }

    // unreachable tho
    return "", .{};
}

git_staged :: () -> string, Attr {
    sb: String_Builder;
    Check_Ok(pane_current_path);

    ok, staged := command("git", "diff", "--staged", "--name-status", cwd = pane_current_path);
    if !ok return "", .{}; // Probably not a git directory

    staged_count := line_count(staged);
    if staged_count return tprint("+. %", staged_count), .{"colour15", "green"};

    return "", .{};
}

git_unstaged :: () -> string, Attr {
    sb: String_Builder;
    Check_Ok(pane_current_path);

    ok, unstaged := command("git", "diff", "--name-status", cwd = pane_current_path);
    if !ok return "", .{}; // Probably not a git directory

    unstaged_count := line_count(unstaged);
    if unstaged_count return tprint("+ %", unstaged_count), .{"colour15", "red"};

    return "", .{};
}

git_untracked :: () -> string, Attr {
    sb: String_Builder;
    Check_Ok(pane_current_path);

    ok, untracked := command("git", "ls-files", "--others", "--exclude-standard", cwd = pane_current_path);
    if !ok return "", .{}; // Probably not a git directory

    untracked_count := line_count(untracked);
    if untracked_count return tprint("⋯ %", untracked_count), .{"black", "colour8"};

    return "", .{};
}

segment_current_path :: () -> string, Attr {
    Check_Ok(pane_current_path);

    return pane_current_path, .{ "white", "black" };
}

battery :: () -> string, Attr {
    bat := "/sys/class/power_supply/BAT0";
    exists := file_exists(bat);
    if !exists {
        bat = "/sys/class/power_supply/BAT1";
        exists = file_exists(bat);
    }

    if !exists && is_wsl() {
        ok, out := command("windows_battery.exe");
        if !ok return out, .{ "red", "white" };

        return out, .{"white", "red"};
    }

    text, ok := my_read_entire_file(tprint("%/energy_full", bat));
    Check_Ok(ok);
    energy_full:, ok = string_to_int(text);
    Check_Ok(ok);

    text, ok = my_read_entire_file(tprint("%/energy_now", bat));
    Check_Ok(ok);
    energy_now:, ok = string_to_int(text);
    Check_Ok(ok);

    status_text:, ok = my_read_entire_file(tprint("%/status", bat));
    Check_Ok(ok);

    status := "";
    if status_text == {
        case "Charging";    status = " ↑";
        case "Discharging"; status = " ↓";
    }

    percentage := 100 * (cast(float) energy_now) / energy_full;
    return tprint("♥ %1%2", cast(int) percentage, status), .{ "white", "red" };
}

date_time :: () -> string, Attr {
    sb: String_Builder;
    time := to_calendar(current_time_consensus(), .LOCAL);

    print_to_builder(*sb, " % | %-%-% | %:%",
        weekday_short[time.day_of_week_starting_at_0],
        time.year,
        f2(time.month_starting_at_0 + 1),
        f2(time.day_of_month_starting_at_0 + 1),
        f2(time.hour),
        f2(time.minute),
    );
    return builder_to_string(*sb), .{ "colour15", "colour240" };
}

weekday_short :: string.[ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" ];

f2 :: (v: int) -> FormatInt #expand {
    return FormatInt.{ value = v, minimum_digits = 2 };
}

cpu_temperature :: () -> string, Attr {
    // @Incomplete this only works on my machine
    info := get_temperature("x86_pkg_temp");
    if !info return "", .{ "black", "black" };

    degree := info[0].millidegree / 1000;
    return tprint("%°", f2(degree)), .{ color_from_degrees(degree, false), "black" };
}

cpu_frequency :: () -> string, Attr {
    cpuinfo, ok := my_read_entire_file("/proc/cpuinfo");
    if !ok return "", .{ "black", "black" };

    sum: float;
    count: int;

    for :lines cpuinfo {
        if !starts_with(it, "cpu MHz") continue;
        ok, left, right := split_from_right(it, #char ":");
        if !ok continue;

        right = trim(right);
        value:, ok = parse_float(*right);
        if !ok continue;

        sum += value;
        count += 1;
    }

    avg_MHz := sum / count;
    avg_GHz := avg_MHz / 1000;

    t := tprint("%", fmt(avg_GHz, 2));
    return tprint("%GHz", trim(t)), .{ "colour240", "default" };
}

fmt :: inline (v: float, digits_after_comma := -1, keep_zero := false) -> FormatFloat #expand {
    return FormatFloat.{ value = v, trailing_width = digits_after_comma, zero_removal = ifx keep_zero then .NO else .YES };
}

//
// }}} segments
//

pane_current_path: string = "";

command :: (args: .. string, cwd := "") -> ok: bool, out: string {
    if debug log("run_command(%, cwd='%')", args, cwd);
    res, out, err := run_command(..args, capture_and_return_output = true, working_directory = cwd);
    if res.type != .EXITED || res.exit_code != 0
        return false, tprint("command `%` failed: %2%3", join(..args, " ",, temp), out, err);
    return true, trim(out);
}

line_count :: (text: string) -> s64 {
    if !text return 0;
    start := 0;
    count := 0;
    while true {
        next := find_index_from_left(text, cast(u8) #char "\n", start);
        if next == -1 return count + 1;
        count += 1;
        start = next + 1;
    }
    return 0;
}

Check_Ok :: (ok: $T, loc := #caller_location) #expand {
    if !ok `return tprint("ERROR %", loc.line_number), .{"white", "red"};
}

Segment :: struct {
    text: string = "";
    proc: () -> (string, Attr) = no_proc;
    attr: Attr;
}

no_proc :: () -> (string, Attr) { return "", .{}; }

Attr :: struct {
    fg, bg: string;
}

#import "Basic";
#import "String";
#import "Process";
#import "File";
#import "File_Utilities";
#import "System";
#import "Hash_Table";
#import "My_Util";
#import "Version_Banner";
#import "My_Logger";
#import "Sort";
