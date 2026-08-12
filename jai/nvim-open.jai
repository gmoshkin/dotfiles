//
// nvim-open -- put a file on screen in the neovim the user already has running.
//
// Discovery never talks to neovim. Panes come from tmux, the process tree from
// Process_Info, and the socket from the pid that owns it. That is the whole
// design: a *busy* neovim -- mid-keystroke with a pending count or operator, or
// sitting in a picker -- answers nothing, so anything that had to ask "are you
// there?" would fail to find exactly the neovim that most needs finding, and
// would hang for its timeout while failing.
//
// The one thing we do ask, once a server has been picked, is to open the file.
// That request has a timeout, and until it comes back nothing has changed.
//
// Targets come from the command line (`file:line:col`), from stdin (which is
// how tmux's copy-mode `copy-pipe` hands us a selection), or, when stdin brings
// nothing, from under the copy-mode cursor itself (`--copy-mode`).
//

main :: () {
    ensure_utf8_locale();

    options := parse_arguments();

    servers := discover_servers(*options);

    targets, ok_targets := collect_targets(*options);
    if !ok_targets  exit(1);

    // Nothing to open is a request to say what we found, same as `--list`
    if options.list || (!targets && !options.where) {
        print_servers(servers, *options);
        exit(ifx servers then 0 else cast(s32) 1);
    }

    if !servers {
        log_error("no neovim found in %; is it running there? if it was started with --listen somewhere unusual, pass --server SOCKET",
                  describe_search_scope(*options));
        exit(1);
    }

    server := pick_server(servers, ifx targets then targets[0].path else "");

    if options.dry_run {
        print("would use % (%) cwd=%\n", server.pane_name, server.socket_path, server.cwd);
        for targets  print("would open %:%:% (%)\n", it.path, it.line, it.column,
                           ifx it_index == 0 then tprint("%", options.open_command) else "edit");
        exit(0);
    }

    nvim, ok := nvim_connect(server.socket_path, options.timeout_seconds);
    if !ok {
        log_error("could not reach the neovim in %: %", server.pane_name, last_error_to_string(.ONLY_MESSAGE));
        exit(1);
    }
    defer nvim_disconnect(*nvim);

    if options.where {
        where, ok= := current_location(*nvim);
        if !ok {
            report_rpc_failure(*server);
            exit(1);
        }
        print("%\n", where);
        exit(0);
    }

    if !open_targets(*nvim, targets, *options) {
        report_rpc_failure(*server);
        exit(1);
    }

    if options.focus     focus_pane(*server);
    if options.activate  activate_terminal(*options);

    //
    // Report what neovim actually ended up showing rather than what we asked
    // for: this line is the confirmation that the file is on screen.
    //
    where, ok= := current_location(*nvim);
    if !ok  where = "(could not confirm)";

    extra := ifx targets.count > 1 then tprint(" (+% more in the buffer list)", targets.count - 1) else "";
    print("neovim in % now shows %%\n", server.pane_name, where, extra);
}

//
// Options
//

Options :: struct {
    targets: [..] string;

    list:    bool;
    where:   bool;
    dry_run: bool;

    // Overrides for discovery
    server:       string;
    pane:         string;
    session:      string;
    all_sessions: bool;

    //
    // The pane we are acting on behalf of, which is not our own: tmux runs a
    // `copy-pipe` command with neither TMUX_PANE nor the pane's directory (its
    // cwd is wherever the tmux server was started). Both are needed -- the
    // session to search, and the directory a relative path in the selection is
    // relative to -- so the binding hands us the pane and we ask tmux for them.
    //
    from_pane: string;

    // Resolve relative targets against this instead of our own cwd
    cwd: string;

    open_command := Nvim_Open_Command.EDIT;

    // Fall back to the copy-mode cursor of this pane (ours if empty) when
    // nothing arrives on stdin
    copy_mode:      bool;
    copy_mode_pane: string;

    focus:    bool;
    activate: bool;
    app := "Alacritty";

    timeout_seconds := DEFAULT_TIMEOUT_SECONDS;

    verbose: bool;
}

USAGE :: #string DONE
usage: nvim-open [options] [FILE[:LINE[:COL]] ...]

Opens files in the neovim running in the current tmux session. With no file
arguments it reads one from stdin, which is what tmux's copy-pipe gives us.

  --list              show the neovim servers we found and exit
  --dry-run           show which one we would use, and the parsed target
  --where             print what the chosen neovim is currently showing
  --copy-mode [PANE]  with nothing on stdin, take the target from under the
                      copy-mode cursor instead
  --server SOCKET     use this socket instead of searching
  --pane TARGET       only look at this pane (%3, or session:window.pane)
  --session NAME      only look at this session (default: ours)
  --from-pane PANE    act on behalf of this pane: search its session, and
                      resolve relative paths against its directory
  --cwd DIR           resolve relative paths against DIR
  --all-sessions      look at every session, not just ours
  --split             open in a horizontal split
  --vsplit            open in a vertical split
  --tab               open in a new tab
  --focus             move the tmux cursor to the neovim pane
  --activate          bring the terminal application to the front
  --gui               --all-sessions --focus --activate, for launching from a .app
  --app NAME          which application --activate raises (default Alacritty)
  --timeout SECONDS   how long to wait for neovim (default 5)
  --verbose           explain what discovery found
  --help
DONE

parse_arguments :: () -> Options {
    options: Options;

    args := get_command_line_arguments();

    i := 1;
    while i < args.count {
        defer i += 1;
        argument := args[i];

        //
        // The value of a flag that takes one. `--copy-mode`'s pane is optional,
        // so it asks for `optional=true` and gets "" when the next argument is
        // another flag or the end.
        //
        value :: (optional := false) -> string #expand {
            if `i + 1 < `args.count && !starts_with(`args[`i + 1], "--") {
                `i += 1;
                return `args[`i];
            }
            if optional  return "";

            log_error("% needs a value", `argument);
            exit(1);
            return "";
        }

        if argument == {
        case "--list";          options.list = true;
        case "--dry-run";       options.dry_run = true;
        case "--where";         options.where = true;
        case "--server";        options.server = value();
        case "--pane";          options.pane = value();
        case "--session";       options.session = value();
        case "--from-pane";     options.from_pane = value();
        case "--cwd";           options.cwd = value();
        case "--all-sessions";  options.all_sessions = true;
        case "--split";         options.open_command = .SPLIT;
        case "--vsplit";        options.open_command = .VSPLIT;
        case "--tab";           options.open_command = .TABEDIT;
        case "--focus";         options.focus = true;
        case "--activate";      options.activate = true;
        case "--app";           options.app = value();
        case "--verbose";       options.verbose = true;

        case "--copy-mode";
            options.copy_mode = true;
            options.copy_mode_pane = value(optional = true);

        case "--gui";
            // Launched from a .app there is no tmux around us, and the point of
            // the launch is to end up looking at the editor
            options.all_sessions = true;
            options.focus = true;
            options.activate = true;

        case "--timeout";
            seconds, tail := parse_positive_number(value());
            if tail {
                log_error("--timeout wants a whole number of seconds");
                exit(1);
            }
            options.timeout_seconds = seconds;

        case "--help"; #through;
        case "-h";
            print("%", USAGE);
            exit(0);

        case;
            if starts_with(argument, "--") {
                log_error("unknown option '%'\n", argument);
                print("%", USAGE);
                exit(1);
            }
            array_add(*options.targets, argument);
        }
    }

    debug_parsing   = options.verbose;
    verbose_logging = options.verbose;

    resolve_from_pane(*options);

    return options;
}

//
// Fills in whatever --from-pane implies and the caller didn't say outright. One
// tmux call, so a binding can pass just the pane id -- which needs no quoting,
// unlike a session name.
//
resolve_from_pane :: (options: *Options) {
    if !options.from_pane  return;

    // Session name first because it cannot contain a colon; the path can, and
    // being last it keeps whatever it has
    ok, output := tmux("display-message", "-p", "-t", options.from_pane, "#{session_name}:#{pane_current_path}");
    if !ok {
        log_error("could not ask tmux about pane %: %", options.from_pane, output);
        return;
    }

    found, session, directory := split_from_left(trim_right(output, "\n"), #char ":");
    if !found  return;

    if !options.session  options.session = session;
    if !options.cwd      options.cwd     = directory;
}

//
// Discovery
//

Pane :: struct {
    pane_id:   string;  // %135
    pane_pid:  Pid;     // the process tmux started in it, usually a shell
    session:   string;
    pane_name: string;  // dotfiles:1.0

    // How tmux answers "which one is the user actually looking at"
    attached:      s64;  // clients currently attached to this session
    last_attached: s64;  // and when one last was
}

Server :: struct {
    socket_path: string;
    cwd:         string;
    nvim_pid:    Pid;

    // Empty when the server came from --server, where all we have is a socket
    pane_id:   string;
    pane_name: string;
    session:   string;

    attached:      s64;
    last_attached: s64;
}

discover_servers :: (options: *Options) -> [] Server {
    if options.server {
        server: Server;
        server.socket_path = options.server;
        server.pane_name = "(--server)";

        result: [..] Server;
        array_add(*result, server);
        return result;
    }

    panes := list_panes();
    our_session := session_of_pane(panes, our_pane_id(options));

    //
    // Which panes are in scope. Explicit beats implicit: --pane, then --session,
    // then our own session -- and if we are not in tmux at all (launched from a
    // .app, say) then every session is in scope, since we have nothing to
    // prefer.
    //
    in_scope: [..] Pane;
    in_scope.allocator = temp;
    for panes {
        matches := true;
        if options.pane            matches = it.pane_id == options.pane || it.pane_name == options.pane;
        else if options.session    matches = it.session == options.session;
        else if !options.all_sessions && our_session  matches = it.session == our_session;

        if matches  array_add(*in_scope, it);
    }

    if options.verbose {
        log("our pane: '%', our session: '%'", our_pane_id(options), our_session);
        log("% of % panes in scope", in_scope.count, panes.count);
    }

    servers: [..] Server;

    //
    // Walk *up* from each socket rather than down from each pane: the sockets
    // are a handful, the process list is hundreds, and the parent chain from an
    // nvim reaches its pane in three or four hops.
    //
    for socket: list_nvim_sockets() {
        info: Process_Info;
        if !get_process_info(socket.pid, *info, log_errors = false) {
            // A socket left behind by a neovim that has since exited
            if options.verbose  log("socket % has no process", socket.path);
            continue;
        }

        if command_short_string(*info) != "nvim" {
            if options.verbose  log("pid % is '%', not nvim", socket.pid, command_short_string(*info));
            continue;
        }

        pane, found := find_pane_of_process(socket.pid, in_scope, options.verbose);
        if !found {
            if options.verbose  log("nvim % (%) is not in a pane we are looking at", socket.pid, socket.path);
            continue;
        }

        // One server per pane is plenty: the parent nvim and its --embed child
        // both answer to the same editor
        already_have := false;
        for servers  if it.pane_id == pane.pane_id  already_have = true;
        if already_have  continue;

        cwd := get_process_cwd(socket.pid);

        server: Server;
        server.socket_path = socket.path;
        server.cwd         = cwd;
        server.nvim_pid    = socket.pid;
        server.pane_id     = pane.pane_id;
        server.pane_name   = pane.pane_name;
        server.session     = pane.session;
        server.attached      = pane.attached;
        server.last_attached = pane.last_attached;
        array_add(*servers, server);
    }

    return servers;
}

//
// The socket neovim listens on by default is named after the pid of its
// `--embed` child, not the pid you see in the process list, so we take the pid
// from the socket name and check it rather than guessing the name from a pid.
//
// Sockets from an explicit `nvim --listen /some/where/else` are not found this
// way; that is what --server is for.
//
Nvim_Socket :: struct {
    pid:  Pid;
    path: string;
}

list_nvim_sockets :: () -> [] Nvim_Socket {
    result: [..] Nvim_Socket;

    #if OS == .MACOS {
        // $TMPDIR/nvim.$USER/<random>/nvim.<pid>.0 -- one random directory per
        // editor, so the listing has to recurse
        root := tprint("%/nvim.%", trim_right(user_temp_directory(), "/"), user_name());
        files := file_list(root, recursive = true);
    } else {
        // $XDG_RUNTIME_DIR/nvim.<pid>.0
        root := get_env("XDG_RUNTIME_DIR");
        if !root  root = tprint("/run/user/%", getuid());
        files := file_list(root, recursive = false);
    }

    for files {
        pid, ok := pid_from_socket_name(path_filename(it));
        if !ok  continue;

        array_add(*result, .{ pid = pid, path = it });
    }

    return result;
}

// `nvim.<pid>.<n>`, as opposed to the `fzf-lua.<stuff>.<pid>.<n>` sockets and
// the swap files that share the directory
pid_from_socket_name :: (name: string) -> pid: Pid, ok: bool {
    PREFIX :: "nvim.";
    if !starts_with(name, PREFIX)  return 0, false;

    rest := advance(name, PREFIX.count);
    pid, tail := parse_positive_number(rest, Pid);

    if tail.data == rest.data  return 0, false; // no digits at all
    if !starts_with(tail, ".") return 0, false;

    return pid, true;
}

MAX_PROCESS_TREE_DEPTH :: 64;

find_pane_of_process :: (pid: Pid, panes: [] Pane, verbose: bool) -> (pane: Pane, ok: bool) {
    current := pid;

    for 1..MAX_PROCESS_TREE_DEPTH {
        for panes  if it.pane_pid == current  return it, true;

        info: Process_Info;
        if !get_process_info(current, *info, log_errors = false)  break;

        // Walking past init would only find panes by accident
        if info.parent_pid <= 1  break;

        current = info.parent_pid;
    }

    return .{}, false;
}

//
// tmux
//

//
// Colon-separated, with the one field that can hold anything -- the session
// name -- last, so the split can't be confused by its contents. tmux itself
// rewrites `:` and `.` in a session name to `_`, which is what makes a colon
// safe here where a tab is not (see ensure_utf8_locale).
//
PANE_FORMAT :: "#{pane_id}:#{pane_pid}:#{window_index}:#{pane_index}:#{session_attached}:#{session_last_attached}:#{session_name}";

//
// Asked for more than once, and the answer can't change under us within a run,
// so keep it -- which also means a failure is reported once rather than at every
// call site.
//
cached_panes:  [] Pane;
panes_are_known: bool;

list_panes :: () -> [] Pane {
    if panes_are_known  return cached_panes;
    panes_are_known = true;

    ok, output := tmux("list-panes", "-a", "-F", PANE_FORMAT);
    if verbose_logging  log("list-panes ok=% output=% bytes: '%'", ok, output.count, output);
    if !ok {
        // Not being able to run tmux at all looks exactly like "no panes" from
        // here on, and the two want very different things from the reader
        log_error("could not ask tmux (%) for its panes: %", tmux_command, output);
        return cached_panes;
    }

    panes: [..] Pane;

    for line: split(trim(output), "\n") {
        fields := split(line, ":");
        if fields.count < 7  continue;

        pane: Pane;
        pane.pane_id       = fields[0];
        pane.pane_pid      = parse_positive_number(fields[1], Pid);
        pane.attached      = parse_positive_number(fields[4]);
        pane.last_attached = parse_positive_number(fields[5]);

        // Whatever is left is the session name, rejoined in case tmux ever lets
        // a colon through after all
        pane.session   = join(..array_view(fields, 6), ":",, temp);
        pane.pane_name = tprint("%:%.%", pane.session, fields[2], fields[3]);

        array_add(*panes, pane);
    }

    cached_panes = panes;
    return cached_panes;
}

//
// Our own pane, and only ever from the environment. `tmux display-message`
// looks like a fallback and is a trap: with no pane of our own it answers with
// the *attached client's* active pane, so a tool launched outside tmux -- from
// a .app, a hotkey, a cron job -- would silently scope itself to whichever
// session the user happened to be looking at, and open files in that editor.
//
// Not being in a pane is a real answer: it means no session to prefer, so
// discovery widens to every session and the cwd ranking decides.
//
our_pane_id :: (options: *Options) -> string {
    // The pane we were told to act for stands in for one of our own
    if options.from_pane  return options.from_pane;

    return get_env("TMUX_PANE");
}

session_of_pane :: (panes: [] Pane, pane_id: string) -> string {
    if !pane_id  return "";
    for panes  if it.pane_id == pane_id  return it.session;
    return "";
}

//
// Where tmux is. Launched from a .app, a hotkey or a launchd job we inherit a
// bare PATH -- /usr/bin:/bin:/usr/sbin:/sbin -- which is not where homebrew or
// macports install anything, so a plain `tmux` fails to exec and every lookup
// comes back empty. Finding it ourselves is the difference between "no neovim
// found in any tmux session" and the thing simply working.
//
tmux_command: string;
verbose_logging: bool;

//
// tmux rewrites anything it thinks the client can't display into `_`, and with
// no locale at all it thinks that of every byte outside ascii -- and of tabs.
// Launched from a .app there *is* no locale, so a format like "a\tb" comes back
// as "a_b" and a path with an accent in it comes back mangled.
//
// Only fills in a locale that isn't there; someone who deliberately runs under
// LANG=C keeps it, which is why the formats below avoid tabs as well.
//
ensure_utf8_locale :: () {
    if get_env("LC_ALL") || get_env("LC_CTYPE") || get_env("LANG")  return;

    #if OS == .MACOS  locale := "UTF-8";
    else              locale := "C.UTF-8";

    setenv("LC_CTYPE", locale.data, 1);
}

find_tmux :: () -> string {
    // Whatever the caller's own PATH says, when there is one worth reading
    for directory: split(get_env("PATH"), ":") {
        if !directory  continue;

        candidate := tprint("%/tmux", trim_right(directory, "/"));
        if is_executable(candidate)  return candidate;
    }

    // ... and failing that, where it actually tends to live
    for candidate: string.["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux", "/opt/local/bin/tmux", "/usr/bin/tmux"] {
        if is_executable(candidate)  return candidate;
    }

    // Nothing found; let it fail by name so the error mentions tmux
    return "tmux";
}

is_executable :: (path: string) -> bool {
    X_OK :: 1; // modules/POSIX has access() but not the mode flags
    return access(temp_c_string(path), X_OK) == 0;
}

tmux :: (args: .. string) -> (ok: bool, output: string) {
    if !tmux_command {
        tmux_command = find_tmux();
        if verbose_logging  log("tmux is '%'", tmux_command);
    }

    command: [..] string;
    command.allocator = temp;

    array_add(*command, tmux_command);
    for args  array_add(*command, it);

    result, output, error_output := run_command(..command, capture_and_return_output = true);

    if result.type != .EXITED || result.exit_code != 0 {
        return false, trim(tprint("%1%2", output, error_output));
    }

    return true, output;
}

//
// Targets
//

Target :: struct {
    path:   string; // absolute
    line:   s64;    // 0 when the target didn't name one
    column: s64;
}

//
// `ok` is false when something *was* handed to us and none of it named a file.
// Being given nothing at all is not a failure -- it means "tell me what you
// found" -- but a selection we couldn't read is, and the exit status is all a
// tmux binding can report.
//
collect_targets :: (options: *Options) -> targets: [] Target, ok: bool {
    targets: [..] Target;

    for options.targets {
        target, ok := parse_target(it, options.cwd);
        if !ok {
            if looks_like_a_url(it) {
                log_error("'%' is a URL, not a file -- nvim-open cannot open it. If a link brought you here, something has made NvimOpen.app your default browser: run `swift dotfiles/macos/nvim-open-app/file-types.swift query ~/Applications/NvimOpen.app` to see what it holds.", it);
            } else {
                log_error("'%' does not look like a file", it);
            }
            exit(1);
        }

        // Not fatal -- opening a file that isn't there yet is a real thing to
        // want -- but it is usually a typo, so say so
        if !file_exists(target.path)  log_error("warning: % does not exist", target.path);

        array_add(*targets, target);
    }

    if targets  return targets, true;

    //
    // A selection piped in by tmux's `copy-pipe`, or anything else on stdin.
    // Being a terminal means nobody is piping us anything and we should not sit
    // there waiting for a human to type a filename.
    //
    if !isatty(STDIN_FILENO) {
        text := read_all_of_stdin();
        target, ok := find_target_in_text(text, -1, options.cwd);

        if ok {
            array_add(*targets, target);
            return targets, true;
        }

        //
        // A selection that named nothing is a failure even with --copy-mode to
        // fall back on: you selected that text on purpose, and quietly opening
        // whatever the cursor happened to be over instead would be worse than
        // saying so.
        //
        if trim(text) {
            log_error("no file location in '%'", trim(text));
            return targets, false;
        }
    }

    //
    // Nothing was piped to us. Under the C-g binding that means copy mode with
    // no selection -- the common case, where you have just moved the cursor
    // onto a path and want that -- because `copy-pipe` runs its command either
    // way and simply gives it an empty stdin when there is nothing selected.
    //
    if options.copy_mode {
        target, ok := target_from_copy_mode(options);
        if !ok  return targets, false;

        array_add(*targets, target);
        return targets, true;
    }

    return targets, true;
}

//
// `path`, `path:line`, `path:line:col`, with a trailing colon tolerated because
// compilers print them that way. Anything else is taken to be a plain filename,
// so that a file whose name really does end in digits still opens.
//
//
// A URL is not a file, and telling them apart matters because we can be handed
// one: on macos, whoever is the default application for public.html is also the
// default *browser*, so one wrong entry in the app's file-type list sends every
// clicked link in every app here. Left alone, `https://x.com` parses as a
// perfectly good relative path and neovim opens an empty buffer named after it,
// which looks exactly like the link doing nothing at all.
//
looks_like_a_url :: (spec: string) -> bool {
    found, scheme := split_from_left(spec, "://");
    if !found || !scheme  return false;

    // Deliberately not a general URL check: only enough to be sure this is a
    // scheme and not a path that happens to contain a colon.
    for scheme {
        if is_alpha(it) || is_digit(it) || it == #char "+" || it == #char "-" || it == #char "."  continue;
        return false;
    }
    return true;
}

parse_target :: (spec: string, base_directory := "") -> Target, bool {
    target: Target;

    if looks_like_a_url(spec)  return target, false;

    path := spec;
    if ends_with(path, ":")  path.count -= 1;

    numbers: [2] s64;
    number_count := 0;

    while number_count < numbers.count {
        found, head, tail := split_from_right(path, #char ":");
        if !found || !tail  break;

        number, rest := parse_positive_number(tail);
        if rest.data == tail.data || rest  break; // not all digits

        numbers[number_count] = number;
        number_count += 1;
        path = head;
    }

    if !path  return target, false;

    // Collected right to left: `file:12:7` gives [7, 12]
    if number_count == 1  target.line = numbers[0];
    if number_count == 2 { target.line = numbers[1]; target.column = numbers[0]; }

    target.path = absolute_path(path, base_directory);
    return target, true;
}

//
// tmux gives us both the text of the line the copy-mode cursor sits on and the
// column it sits at, so we can pick the location *under* the cursor rather than
// the first one on the line.
//
target_from_copy_mode :: (options: *Options) -> Target, bool {
    pane := options.copy_mode_pane;
    if !pane  pane = our_pane_id(options);

    //
    // The cursor line is asked for on its own: it is a line of someone's
    // terminal, so it can hold any character we might have used to separate it
    // from anything else -- including the tabs this used to use.
    //
    // The pane's directory comes along with the column, and comes last, because
    // a path may contain a colon while a column number may not.
    //
    ok, output := tmux("display-message", "-p", "-t", pane, "#{copy_cursor_x}:#{pane_current_path}");
    if !ok {
        log_error("could not ask tmux about pane %: %", pane, output);
        return .{}, false;
    }

    found, column_text, directory := split_from_left(trim_right(output, "\n"), #char ":");
    if !found {
        log_error("could not read the copy-mode cursor of pane %", pane);
        return .{}, false;
    }

    ok=, line := tmux("display-message", "-p", "-t", pane, "#{copy_cursor_line}");
    line = trim_right(line, "\n");
    if !ok || !line {
        log_error("pane % is not in copy mode", pane);
        return .{}, false;
    }

    column := parse_positive_number(column_text);

    base_directory := options.cwd;
    if !base_directory  base_directory = directory;

    target, ok= := find_target_in_text(line, column, base_directory);
    if !ok  log_error("no file location under the cursor in '%'", line);

    return target, ok;
}

//
// Scans arbitrary text -- a copied selection, a line of compiler output -- for
// something shaped like a source location. When `column` is not -1 the location
// covering it wins, which is what makes `--copy-mode` land on the path the
// cursor is actually on rather than the first path on the line.
//
find_target_in_text :: (text: string, column: s64, base_directory := "") -> Target, bool {
    best: Target;
    found_any := false;

    for line: split(text, "\n") {
        cursor := 0;
        while cursor < line.count {
            while cursor < line.count && (inline is_space(line[cursor]))  cursor += 1;
            if cursor >= line.count  break;

            tail := advance(line, cursor);
            length, filename, line_no, column_no := parse_source_location(tail, cursor == 0);

            if filename {
                target: Target;
                target.path   = absolute_path(filename, base_directory);
                target.line   = line_no;
                target.column = column_no;

                covers_cursor := column >= cursor && column < cursor + length;
                if covers_cursor  return target, true;

                if !found_any {
                    best = target;
                    found_any = true;

                    // Without a cursor to satisfy, the first location wins
                    if column == -1  return best, true;
                }
            }

            cursor += max(length, 1);
            while cursor < line.count && !(inline is_file_path_char(line[cursor]))  cursor += 1;
        }
    }

    return best, found_any;
}

//
// Ranking
//

//
// The editor already sitting in the right project wins, and among those the one
// with the most specific working directory: with nested checkouts open, the
// innermost is the one that meant the file.
//
// When *nothing* holds the file -- a path from Finder, most likely -- the
// question stops being about projects and becomes "which editor is the user
// actually looking at". tmux knows: the attached session, or failing that the
// one attached most recently. Picking by directory length there would send the
// file to whichever editor happens to sit deepest in the filesystem, which is
// how a file ends up opening in a detached session where nobody can see it.
//
pick_server :: (servers: [] Server, path: string) -> Server {
    best := servers[0];

    for servers {
        if it_index == 0  continue;
        if is_better_server(it, best, path)  best = it;
    }

    return best;
}

is_better_server :: (candidate: Server, incumbent: Server, path: string) -> bool {
    candidate_holds := is_inside(candidate.cwd, path);
    incumbent_holds := is_inside(incumbent.cwd, path);

    if candidate_holds != incumbent_holds  return candidate_holds;

    // Both hold it: the more specific checkout is the one that meant it
    if candidate_holds && candidate.cwd.count != incumbent.cwd.count
        return candidate.cwd.count > incumbent.cwd.count;

    // Neither does: go where the user is
    if candidate.attached != incumbent.attached
        return candidate.attached > incumbent.attached;

    if candidate.last_attached != incumbent.last_attached
        return candidate.last_attached > incumbent.last_attached;

    return candidate.cwd.count > incumbent.cwd.count;
}

is_inside :: (directory: string, path: string) -> bool {
    if !directory || !path  return false;
    if !starts_with(path, directory)  return false;

    // So that /home/me/dot doesn't look like a parent of /home/me/dotfiles
    if path.count == directory.count  return true;
    if ends_with(directory, "/")       return true;

    return path[directory.count] == #char "/";
}

//
// Opening
//

open_targets :: (nvim: *Nvim, targets: [] Target, options: *Options) -> bool {
    // So the user doesn't end up typing into the buffer we just opened
    if !nvim_command(nvim, "stopinsert")  return false;

    //
    // Backwards, so that the first target is edited last and is the one left on
    // screen; the rest land in the buffer list with their cursors already
    // placed. Only that last one honours --split and friends, since splitting
    // once per file would carve up the window.
    //
    for < targets {
        how := ifx it_index == 0 then options.open_command else Nvim_Open_Command.EDIT;

        if !nvim_edit_file(nvim, it.path, how)  return false;

        if it.line {
            if !nvim_set_cursor(nvim, it.line, max(it.column, 1))  return false;

            // Open any fold the line is buried in, then centre it
            if !nvim_command(nvim, "normal! zvzz")  return false;
        }
    }

    return nvim_command(nvim, "redraw!");
}

current_location :: (nvim: *Nvim) -> string, bool {
    ok, where := nvim_eval_string(nvim, "expand('%:p') . ':' . line('.')");
    return where, ok;
}

focus_pane :: (server: *Server) {
    if !server.pane_id  return;

    //
    // If the client is looking at another session, selecting a window and a
    // pane inside this one changes nothing anyone can see -- the file opens
    // correctly and appears not to have opened at all. Move the client first.
    //
    if server.session && !server.attached  tmux("switch-client", "-t", server.session);

    tmux("select-window", "-t", server.pane_id);
    tmux("select-pane",   "-t", server.pane_id);
}

activate_terminal :: (options: *Options) {
    #if OS == .MACOS {
        run_command("open", "-a", options.app, capture_and_return_output = true);
    } else {
        // X11/wayland window activation is a different problem on every desktop;
        // the tmux side of --focus has already happened.
        if options.verbose  log("--activate does nothing on this platform");
    }
}

//
// Reporting
//

print_servers :: (servers: [] Server, options: *Options) {
    print("tmux session: %\n", describe_search_scope(options));

    if !servers {
        print("no neovim servers found\n");
        return;
    }

    for servers {
        print("  %  %  cwd=%\n", pad_right(it.pane_name, 20), it.socket_path, it.cwd);
    }
}

describe_search_scope :: (options: *Options) -> string {
    if options.pane          return tprint("pane %", options.pane);
    if options.session       return tprint("session '%'", options.session);
    if options.all_sessions  return "any tmux session";

    session := session_of_pane(list_panes(), our_pane_id(options));
    if !session  return "any tmux session (we are not in tmux)";

    return tprint("'%'", session);
}

//
// A neovim that doesn't answer is the interesting failure: the user's editor is
// mid-keystroke and nothing we asked for has happened. Say which, because the
// two need different things from the user.
//
report_rpc_failure :: (server: *Server) {
    code, is_ours := nvim_last_error();

    if is_ours && code == .TIMED_OUT {
        log_error("the neovim in % did not answer in time. It is busy -- waiting at a prompt, or mid-keystroke -- so nothing was changed. Press <Esc> there and try again.",
                  server.pane_name);
        return;
    }

    message := last_error_to_string(.ONLY_MESSAGE);

    // The one vim error worth translating: it means the buffer on screen has
    // unsaved changes, and `edit` refuses to replace it
    hint := ifx contains(message, "E37") then " -- the buffer there has unsaved changes; --split or --vsplit opens without replacing it" else "";

    log_error("the neovim in % refused: %%", server.pane_name, message, hint);
}

//
// Odds and ends
//

//
// Resolved rather than merely absolute, because ranking compares this against a
// process's working directory: on macos /tmp is a symlink to /private/tmp, and
// the two spellings never match as strings.
//
absolute_path :: (path: string, base_directory := "") -> string {
    expanded := path;

    if starts_with(expanded, "~/") {
        home := get_env("HOME");
        if home  expanded = tprint("%/%", home, advance(expanded, 2));
    }

    if !starts_with(expanded, "/") {
        base := base_directory;
        if !base  base = get_working_directory();

        expanded = tprint("%/%", trim_right(base, "/"), expanded);
    }

    // get_absolute_path is realpath, which fails -- loudly -- on a path that
    // doesn't exist, so only offer it ones that do
    if file_exists(expanded) {
        absolute, ok := get_absolute_path(expanded);
        if ok  return absolute;
    }

    //
    // A file that doesn't exist yet is not a reason to refuse: neovim is happy
    // to open a new one. Resolve the directory it would live in, so it still
    // ranks against the right editor.
    //
    directory := path_strip_filename(expanded);
    if directory && file_exists(directory) {
        absolute, ok := get_absolute_path(directory);
        if ok  return tprint("%/%", trim_right(absolute, "/"), path_filename(expanded));
    }

    return expanded;
}

read_all_of_stdin :: () -> string {
    builder: String_Builder;
    read_all_available_data(STDIN_FILENO, *builder);
    return builder_to_string(*builder);
}

get_env :: (name: string) -> string {
    value := getenv(name.data);
    if !value  return "";
    return to_string(value);
}

//
// These two build the path neovim puts its socket in, and neither may be in our
// environment: a process started by launchd -- our .app, a hotkey, an agent --
// gets very little of one. Ask the system instead of insisting on $TMPDIR and
// $USER, so we arrive at the same directory neovim did.
//
user_temp_directory :: () -> string {
    from_environment := get_env("TMPDIR");
    if from_environment  return from_environment;

    #if OS == .MACOS {
        // The very thing launchd puts in TMPDIR: /var/folders/<...>/T/
        buffer: [1024] u8;
        count := confstr(_CS_DARWIN_USER_TEMP_DIR, buffer.data, buffer.count);
        if count > 0 && count <= cast(u64) buffer.count  return copy_string(to_string(buffer.data));
    }

    return "/tmp";
}

user_name :: () -> string {
    from_environment := get_env("USER");
    if from_environment  return from_environment;

    entry := getpwuid(getuid());
    if entry && entry.pw_name  return to_string(entry.pw_name);

    return "";
}

pad_right :: (text: string, width: s64) -> string {
    if text.count >= width  return text;

    builder: String_Builder;
    builder.allocator = temp;
    append(*builder, text);
    append_padding(*builder, width - text.count);

    return builder_to_string(*builder,, temp);
}

#import "Basic";
#import "String";
#import "File";
#import "File_Utilities";
#import "POSIX";
#import "Process";
#import "Error_Info";
#import "My_Util";
#import "My_File";
#import "Source_Location";
#import "Process_Info";
#import "Nvim_Rpc";
