main :: () {
    vs_lib_path, vs_bin_path := find_visual_studio_in_a_ridiculous_garbage_way();
    windows_kit_root, windows_kit_version := find_windows_kit_root();
    vcvars_directory := get_vcvars_directory(vs_lib_path);

    args := get_command_line_arguments();
    cursor := 1;
    while cursor < args.count {
        arg := args[cursor];
        if arg == {
        case "bin"; log("%", vs_bin_path); return;
        case "lib"; log("%", vs_lib_path); return;

        case "vcvars32";  log("%\\vcvars32.bat", vcvars_directory);  return;
        case "vcvars64";  log("%\\vcvars64.bat", vcvars_directory);  return;
        case "vcvarsall"; log("%\\vcvarsall.bat", vcvars_directory); return;

        case; log_error("unknown arguments '%'", arg);
        }

        cursor += 1;
    }

    log("windows kit (version %):", windows_kit_version);
    log("    \"%\"", windows_kit_root);

    log("visual studio (lib & bin):");
    log("    \"%\"", vs_lib_path);
    log("    \"%\"", vs_bin_path);

    log("visual studio build:");
    log("    \"%\"", vcvars_directory);
}

get_vcvars_directory :: (vs_lib_path: string) -> string {
    path := vs_lib_path;
    while true {
        if path && (path[path.count - 1] == #char "/" || path[path.count - 1] == #char "\\")
            path.count -= 1;

        if path_filename(path) == "VC" break;
        path = path_strip_filename(path);
    }

    return sprint("%\\Auxiliary\\Build", path);
}

#import "String";
#import "Basic";
#import "Windows_Resources";
