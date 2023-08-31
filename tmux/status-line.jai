main :: () {
    args := get_command_line_arguments();
    if args.count < 2 {
        print("need argument");
        return;
    }
    if args[1] == {
    case "left";
        status_line_left();
        return;
    case "right";
        status_line_right();
        return;
    }
}

status_line_left :: () {
    segments : [..] Segment;
    array_add(*segments, ...[
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
        // TODO: compare to upstream
        .{ proc = git_staged },
        .{ proc = git_unstaged },
        .{ proc = git_untracked },
    ]);

    {
        ok, out := command("tmux", "display", "-p", "#{pane_current_path}");
        if ok pane_current_path = out;
    }

    for *segments {
        if it.proc != no_proc {
            it.text, it.attr = it.proc();
        }
        if !it.text remove it;
    }

    sb : String_Builder;
    for segments {
        attr_start := it.attr;
        attr_end := Attr.{ fg = attr_start.bg, bg = "colour235" };
        if it_index + 1 < segments.count then attr_end.bg = segments[it_index + 1].attr.bg;

        print_to_builder(*sb,
            "#[fg=%,bg=%] % #[fg=%,bg=%]▄",
            attr_start.fg, attr_start.bg, it.text, attr_end.fg, attr_end.bg);
    }
    write_builder(*sb);
    print("\n");
}

status_line_right :: () {
    segments : [..] Segment;
    array_add(*segments, ...[
        // maybe lan/wan address? do I need it even?
        .{ proc = battery },
        .{ proc = date_time },
    ]);

    {
        ok, out := command("tmux", "display", "-p", "#{pane_current_path}");
        if ok pane_current_path = out;
    }

    for *segments {
        if it.proc != no_proc {
            it.text, it.attr = it.proc();
        }
        if !it.text remove it;
    }

    sb : String_Builder;

    for segments {
        attr_seg := it.attr;
        attr_sep := Attr.{ fg = attr_seg.bg, bg = "colour235" };
        if it_index > 0 then attr_sep.bg = segments[it_index - 1].attr.bg;

        print_to_builder(*sb,
            "#[fg=%,bg=%]▄#[fg=%,bg=%] % ",
            attr_sep.fg, attr_sep.bg, attr_seg.fg, attr_seg.bg, it.text);
    }
    write_builder(*sb);
    print("\n");
}

//
// segments {{{
//

git_branch :: () -> string, Attr {
    Check_Ok(pane_current_path);

    ok, out := command("git", "rev-parse", "--abbrev-ref", "HEAD", cwd = pane_current_path);
    if !ok return "", .{}; // Probably not a git directory

    if out != "HEAD" return tprint(" %", trim(out)), .{"colour15", "colour4"};

    ok, out = command("git", "rev-parse", "--short", "HEAD", cwd = pane_current_path);
    Check_Ok(ok);

    return tprint(" %", trim(out)), .{"colour15", "colour4"};
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

    percentage := 100 * (cast(float) energy_now) / energy_full;
    return tprint("♥ %", cast(int) percentage), .{ "white", "red" };
}

date_time :: () -> string, Attr {
    sb: String_Builder;
    time := to_calendar(current_time_consensus(), .LOCAL);

    print_to_builder(*sb, " % ⠔ %-%-% ⠔ %:%",
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


weekday_short := string.[ "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" ];

//
// }}} segments
//

pane_current_path: string = "";

command :: (args: .. string, cwd := "") -> ok: bool, out: string {
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
