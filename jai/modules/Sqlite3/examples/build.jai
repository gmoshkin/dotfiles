#run {
    set_build_options_dc(.{ do_output = false });

    workspace := compiler_create_workspace("sqlite3-example");
    options := get_build_options(workspace);
    if !workspace {
        log_error("Failed to create workspace");
        return;
    }

    path := #file;
    path = parent_path_or_self(path);
    path = parent_path_or_self(path);
    path = parent_path_or_self(path);
    modules_dir := path;

    import_path: [..] string;
    array_add(*import_path, modules_dir);
    array_add(*import_path, ..options.import_path);
    options.import_path = import_path;
    options.output_executable_name = "sqlite3-example";
    set_build_options(options, workspace);

    compiler_begin_intercept(workspace);
    add_build_file("main.jai", workspace);

    while true {
        base_message := compiler_wait_for_message();
        do_error_checking(null, base_message);

        if base_message.kind == .COMPLETE break;
    }

    compiler_end_intercept(workspace);
}

parent_path_or_self :: (path: string) -> string {
    found, parent, child := split_from_right_by_any(path, "\\/");
    if found return parent;

    return path;
}

#import "Basic";
#import "Compiler";
#import "String";
#import "Check";
