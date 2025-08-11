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
    #if OS == .LINUX {
        git_core := "/usr/lib/git-core";
    } else {
        git_core := "C:/msys64/usr/lib/git-core";
    }
    for cmd: file_list(git_core) {
        if is_directory(cmd) continue;
        if !file_is_executable(cmd) continue;

        path := parse_path(cmd);
        filename := path.words[path.words.count - 1];
        if starts_with(filename, "git-") advance(*filename, "git-".count);
        filename = path_strip_extension(filename);
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
        "logout", "metadata", "miri", "new", "owner", "package", "pkgid", "publish",
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
    res, out, err := run_command(..args, capture_and_return_output = true, working_directory = cwd);
    if res.type != .EXITED || res.exit_code != 0 {
        log_error("%, '%', '%'", res, out, err);
        ec, em := get_error_value_and_string();
        log_error("[%] %", ec, em);
        return false, out;
    }
    return true, trim(out);
}

exit_code : s32 = 1;
next_exit_code :: () -> s32 {
    defer exit_code += 1;
    return exit_code;
}

file_is_executable :: (full_path: string) -> bool {
    #if OS == .LINUX {
        #import "POSIX";
        fs: stat_t;
        result := stat(temp_c_string(full_path), *fs);
        if result return false;
        is_executable := fs.st_mode & oct("111");
        return xx is_executable;
    } else {
        #import "Windows";
        shell32 :: #system_library "shell32";
        SHFILEINFOA :: struct {
            hIcon: HICON;
            iIcon: s32;
            dwAttributes: DWORD;
            szDisplayName: [MAX_PATH] s8;
            szTypeName: [80] s8;
        };
        SHGFI :: enum_flags u32 {
            EXETYPE :: 0x000002000;
        }
        SHGetFileInfoA :: (
            pszPath: LPCSTR,
            dwFileAttributes: DWORD,
            psfi: *SHFILEINFOA,
            cbFileInfo: u32,
            uFlags: SHGFI
        ) -> *DWORD #foreign shell32;

        sh_file_info: SHFILEINFOA;
        result := SHGetFileInfoA(temp_c_string(full_path), 0, *sh_file_info, size_of(SHFILEINFOA), .EXETYPE);

        return result != null;
    }
}

#import "Basic";
#import "Process";
#import "String";
#import "File_Utilities";
#import "System";
