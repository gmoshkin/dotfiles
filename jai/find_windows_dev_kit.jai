main :: () {
    vs_lib_path, vs_bin_path := find_visual_studio_in_a_ridiculous_garbage_way();
    windows_kit_root, windows_kit_version := find_windows_kit_root();

    args := get_command_line_arguments();
    cursor := 1;
    while cursor < args.count {
        arg := args[cursor];
        if arg == {
        case "bin"; log("%", vs_bin_path); return;
        case "lib"; log("%", vs_lib_path); return;
        case; log_error("unknown arguments '%'", arg);
        }

        cursor += 1;
    }

    log("windows kit (version %):", windows_kit_version);
    log("    \"%\"", windows_kit_root);

    log("visual studio (lib & bin):");
    log("    \"%\"", vs_lib_path);
    log("    \"%\"", vs_bin_path);
}

#import "Basic";
#import "Windows_Resources";
