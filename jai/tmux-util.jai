debug := false;

main :: () {
    args := get_command_line_arguments();
    maybe_show_version_banner_and_exit();

    subcommands :: struct { argument: string; proc: #type (args: [] string) -> (); }.[
        .{ "status-line-left",  status_line_left, },
        .{ "status-line-right", status_line_right, },
        .{ "new-session",       new_session_subcommand, },
        .{ "crawl-locations",   crawl_locations_subcommand, },
    ];

    if args.count < 2 {
        names: [..] string;
        for subcommands array_add(*names, it.argument);
        log("usage: % [--version] [%]", args[0], join(..names, "|"));
        exit(1);
    }

    for subcommands {
        if args[1] == it.argument {
            it.proc(advance(args, 2));
            return;
        }
    }
}

//
// subcommand: status-line-left
//

status_line_left :: (args: [] string) {
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
}

//
// subcommand: status-line-right
//

status_line_right :: (args: [] string) {
    segments_raw := Segment.[
        // maybe lan/wan address? do I need it even?
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
}

//
// subcommand: new-session
//

new_session_subcommand :: (args: [] string) {
    debug = contains(args, (a) => a == "-d" || a == "--debug");

    ok, error := do_new_session();
    if !ok {
        log_error("%", error);
        command("tmux", "display", error);
    }
}

do_new_session :: () -> (ok: bool, error: string) {
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

crawl_locations_subcommand :: (args: [] string) {
    ok, error := do_crawl_locations(args);
    if !ok {
        log_error("%", error);
        command("tmux", "display", error);
        exit(1);
    }
}

do_crawl_locations :: (args: [] string) -> (ok: bool, error: string) {
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
    };
    locations: [..] Source_Location;

    line_count := 0;
    for :reverse_lines line: output {
        // Only look for locations in last command's output.
        // @Incomplete make this more general
        if !crawl_the_whole_history && locations.count > 0 && starts_with(line, "╭(gmoshkin@") break;

        for :words word: line {

            filename, line_no, column_no := parse_source_location(word);
            if !filename continue;
            if need_line && line_no <= 0 continue;

            tail := trim(advance(line, word.count));

            info: string;
            if starts_with_ignoring_case(tail, "error") {
                info = tail;
            } else if starts_with_ignoring_case(tail, "warning") {
                info = tail;
            }

            array_add(*locations, .{ filename, line_no, column_no, info });

            // Only one source location per line
            break;
        }
        line_count += 1;
    }

    builder: String_Builder;

    Print_Location_Fields :: inline (builder: *String_Builder, using location: Source_Location) {
        if line_no <= 0 {
            print(builder, "\"filename\": \"%\"", filename);
        } else if column_no <= 0 {
            print(builder, "\"filename\": \"%\", \"lnum\": %", filename, line_no);
        } else {
            print(builder, "\"filename\": \"%\", \"lnum\": %, \"col\": %", filename, line_no, column_no);
        }
        if info print(builder, ", \"text\": \"%\"", info);
    }

    if output_json {
        append(*builder, "[\n");
        if locations {
            it := locations[0];
            print(*builder, "    {");
            Print_Location_Fields(*builder, it);
            append(*builder, "}");
        }

        for < array_view(locations, 1) {
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

parse_source_location :: (text: string) -> (filename: string, line_no: int, column_no: int) {
    cursor := 0;
    seen_slash := false;
    seen_ext := false;
    seen_other := false;
    while cursor < text.count {
        c := text[cursor];
        if !inline is_file_path_char(c) break;
        cursor += 1;

        if c == #char "/" { seen_slash = true; seen_ext = false; continue; }
        if c == #char "." { seen_ext = true; continue; }
        seen_other = true;
    }

    if !(seen_other && (seen_slash || seen_ext)) return "", 0, 0;

    filename := slice(text, 0, cursor);

    if !seen_slash {
        if filename[filename.count - 1] == #char "." return "", 0, 0;
        if count_matches(filename, #char ".") > 1 return "", 0, 0;
    }

    tail := advance(text, cursor);

    if cursor == text.count return filename, 0, 0;

    assert(tail[0] == #char ":");
    tail = advance(tail, 1);

    if !(inline is_digit(tail[0])) return filename, 0, 0;
    line_no:, tail = parse_positive_number(tail);

    if !(tail && (tail[0] == #char ":" || tail[0] == #char ",")) {
        return filename, line_no, 0;
    }
    tail = advance(tail, 1);

    if !(inline is_digit(tail[0])) return filename, line_no, 0;
    column_no:, tail = parse_positive_number(tail);

    return filename, line_no, column_no;
}

is_file_path_char :: (char: u8) -> bool {
    return (inline is_alpha(char)) || (inline is_digit(char))
        || char == #char "-" || char == #char "_" || char == #char "~"
        || char == #char "." || char == #char "/";
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
    if !file_exists(bat) {
        bat = "/sys/class/power_supply/BAT1";
        if !file_exists(bat) return "", .{};
    }

    // XXX: why reading this file fails? This is the only way I found to be able to read it :(
    ok, text := command("cat", tprint("%/energy_full", bat));
    Check_Ok(ok);
    energy_full:, ok = string_to_int(text);
    Check_Ok(ok);

    ok, text = command("cat", tprint("%/energy_now", bat));
    Check_Ok(ok);
    energy_now:, ok = string_to_int(text);
    Check_Ok(ok);

    ok=, status_text := command("cat", tprint("%/status", bat));
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

f2 :: (v: int) -> FormatInt #expand {
    return FormatInt.{ value = v, minimum_digits = 2 };
}


weekday_short := string.[ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" ];

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
