#run {
    #if OS == .LINUX {
        set_build_options_dc(.{ output_executable_name = "aliases-linux" });
    } else {
        #assert false, "not implemented";
    }
    #import "Compiler";
}

main :: () {
    ok: bool;
    output: string;

    print(#string END
#
# git aliases
#
    END);
    ok, output = command("git", "config", "--global", "--get-regexp", "^alias.");
    if !ok exit(#run next_exit_code());

    for line: split(output, "\n") {
        ok, def := split_from_left(line, #char " ");
        assert(ok);

        ok=, _, alias := split_from_left(def, #char ".");
        assert(ok);

        print("alias g%1='git %1'\n", alias);
    }

    print(#string END
#
# git commands
#
    END);
    for cmd: file_list("/usr/lib/git-core") {
        if is_directory(cmd) continue;
        fs: stat_t;
        result := stat(temp_c_string(cmd), *fs);
        if result continue;
        if !(fs.st_mode & oct("111")) continue;

        path := parse_path(cmd);
        filename := path.words[path.words.count - 1];
        if starts_with(filename, "git-") advance(*filename, "git-".count);
        print("alias g%1='git %1'\n", filename);
    }

    print(#string END
#
# cargo aliases
#
    END);

    short :: string.[ "build", "clippy", "new", "init", "run", "search", "update", "test" ];
    for short {
        c := slice(it, 0, 1);
        print("alias c%1='cargo %2'\n", c, it);
    }

    long :: string.[
        "add", "bench", "check", "clean", "config", "doc", "expand", "fetch",
        "fix", "fmt", "generate-lockfile", "help", "init", "install", "login",
        "logout", "metadata", "miri", "owner", "package", "pkgid", "publish",
        "read", "remove", "report", "rm", "run", "rustc", "rustdoc", "search",
        "test", "tree", "uninstall", "update", "vendor", "verify", "version",
        "yank",
    ];
    for long {
        print("alias c%1='cargo %1'\n", it);
    }
}

Void : void;

oct :: ($o: string) -> int #expand { return #run string_to_int(o, base=8); }

command :: (args: .. string, cwd := "") -> ok: bool, out: string {
    res, out := run_command(..args, capture_and_return_output = true, working_directory = cwd);
    if res.type != .EXITED || res.exit_code != 0 return false, out;
    return true, trim(out);
}

exit_code : s32 = 1;
next_exit_code :: () -> s32 {
    defer exit_code += 1;
    return exit_code;
}

#import "Basic";
#import "Process";
#import "String";
#import "File_Utilities";
#import "POSIX";
