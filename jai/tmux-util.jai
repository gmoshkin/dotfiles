debug := false;

main :: () {
    args := get_command_line_arguments();
    maybe_show_version_banner_and_exit();

    subcommands :: struct { argument: string; proc: #type (args: [] string) -> (); }.[
        .{ "status-line-left",  status_line_left, },
        .{ "status-line-right", status_line_right, },
        .{ "new-session",       new_session_subcommand, },
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
    res, out := run_command(..args, capture_and_return_output = true, working_directory = cwd);
    if res.type != .EXITED || res.exit_code != 0 return false, out;
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
