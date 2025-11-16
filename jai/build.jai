JAILS :: #exists(JAILS_DIAGNOSTICS_BUILD);

#run {
    set_build_options_dc(.{do_output = false});

    program := Program.ALL;
    mode := Mode.COMPILE;
    compile_parameters: Compile_Parameters;
    inspect_parameters: Inspect_Parameters;

    cursor := 0;
    options := get_build_options();
    args := options.compile_time_command_line;
    while next_arg := cursor < args.count {
        arg: string;
        take_argument(args, *cursor, *arg);
        if arg == {
            case "debug";       compile_parameters.debug_build = true;
            case "release";     compile_parameters.debug_build = false;
            case "dynamic";     compile_parameters.dynamic_binary = true;

            case "source-info-generate";
                mode = .GENERATE_SOURCE_INFO;


            case "source-info-get";
                mode = .INSPECT_SOURCE_INFO;

                sub_command: string;
                if !take_argument(args, *cursor, *sub_command)
                    die("usage: ...  source-info-get SUBCOMMAND  ...");

                if sub_command == {
                    case "global";
                        inspect_parameters.sub_command = .GLOBAL;
                        if !take_argument(args, *cursor, *inspect_parameters.global_symbol)
                            die("usage: ...  source-info-get global SYMBOL  ...");

                    case "def"; #through;
                    case "definition";
                        inspect_parameters.sub_command = .DEFINITION;
                        usage :: "usage: ...  source-info-get definition FILEPATH LINE [COLUMN] ...";
                        ok := take_file_line_column_from_arguments(args, *cursor, *inspect_parameters.filepath, *inspect_parameters.line, *inspect_parameters.column);
                        if !ok die(usage);

                    case "ref"; #through;
                    case "references";
                        inspect_parameters.sub_command = .REFERENCES;
                        usage :: "usage: ...  source-info-get references FILEPATH LINE [COLUMN] ...";
                        ok := take_file_line_column_from_arguments(args, *cursor, *inspect_parameters.filepath, *inspect_parameters.line, *inspect_parameters.column);
                        if !ok die(usage);

                    case;
                        die("unknown sub command '%'", sub_command);
                }

            case "-l"; #through;
            case "--list";
                programs: [..] string;
                for type_info(Program).values if it != xx Program.ALL {
                    array_add(*programs, get_program_info(xx it).arg_name);
                }
                print("list of programs you may build: %\n", programs);
                exit(0);

            case;
                for type_info(Program).values if it != xx Program.ALL {
                    if arg == get_program_info(xx it).arg_name {
                        program = xx it;
                        continue next_arg;
                    }
                }

                die("unknown argument '%' (run with --list for list of programs)", arg);
        }
    }

    #if OS == .WINDOWS {
        for string.["D:/tools", "C:/tools"] {
            if !file_exists(it) continue;
            windows_tools_directory = it;
            break;
        }
        if !windows_tools_directory {
            windows_tools_directory = #filepath;
        }
    }

    Strategy_Pattern_My_Ass :: (program: Program) #expand {
        if `mode == {
            case .COMPILE;
                info := get_program_info(program, compile_parameters.debug_build);
                if info.os != OS {
                    print("Skipping \x1b[33m%\x1b[0m (it wants OS %)\n", info.exe_name, info.os);
                    return;
                }

                #if !JAILS if program == .PAGEVIEW && !compile_parameters.debug_build {
                    debug_parameters := compile_parameters;
                    debug_parameters.debug_build = true;

                    print("Compiling a debug version...\n");
                    if !build_program(info, debug_parameters) exit(1);

                    using info := get_program_info(program, debug=true);

                    print("\n");
                    command := string.[tprint("%/%", exe_path, exe_name), "--run-tests"];
                    process_result := run_command(..command);

                    if process_result.exit_code != 0 {
                        print("\x1b[31mError: Command % failed (Exit code %)\x1b[0m\n", command, process_result.exit_code);
                    }
                    print("\n");

                }
                if !build_program(info, compile_parameters) exit(1);
            case .GENERATE_SOURCE_INFO; generate_source_info(program);
            case .INSPECT_SOURCE_INFO;  inspect_source_info(program, inspect_parameters);
        }
    }

    #if JAILS program = .ALL;
    if program == .ALL {
        for type_info(Program).values {
            program = xx it;
            if program == .ALL continue;
            Strategy_Pattern_My_Ass(program);
        }
    } else {
        Strategy_Pattern_My_Ass(program);
    }
}

Program :: enum {
    ALL;
    PAGEVIEW;
    PS;
    TMUX_UTIL;
    CONVERT_WSL_PATHS;
    WINDOWS_GET_ENV;
    CLIPBOARD;
    FIND_WINDOWS_DEV_KIT;
    SHELL_ALIASES;
}

Mode :: enum {
    COMPILE;
    GENERATE_SOURCE_INFO;
    INSPECT_SOURCE_INFO;
}

Compile_Parameters :: struct {
    debug_build: bool;
    dynamic_binary: bool;
}

Inspect_Parameters :: struct {
    sub_command: enum { GLOBAL; DEFINITION; REFERENCES; };

    global_symbol: string;

    filepath: string;
    line: int;
    column: int;
}

windows_tools_directory: string;

Program_Info :: struct {
    exe_name: string;
    exe_path: string;
    source: string;
    arg_name: string;
    os: Operating_System_Tag;
}

get_program_info :: (program: Program, debug := false) -> Program_Info {
    using info: Program_Info;
    // Any OS supported if not specified otherwise
    os = OS;

    if #complete program == {

        case .PAGEVIEW;
            source = "pageview.jai";
            os = .LINUX;

        case .PS;
            source = "ps.jai";
            exe_name = "myps";
            arg_name = "ps";
            os = .LINUX;

        case .TMUX_UTIL;
            source = "tmux-util.jai";
            exe_name = "tmux-util-linux";
            exe_path = sprint("%/../tmux/", #filepath);
            arg_name = "tmux-util";
            os = .LINUX;

        case .CONVERT_WSL_PATHS;
            source = "convert_wsl_paths.jai";
            os = .LINUX;

        case .WINDOWS_GET_ENV;
            source = "windows_get_env.jai";
            os = .WINDOWS;

        case .CLIPBOARD;
            source = "clipboard.jai";
            os = .WINDOWS;

        case .SHELL_ALIASES;
            source = "aliases.jai";
            #if OS == .WINDOWS {
                exe_name = "aliases-msys";
            } else {
                exe_name = "aliases-linux";
            }
            arg_name = "aliases";

        case .FIND_WINDOWS_DEV_KIT;
            source = "find_windows_dev_kit.jai";
            os = .WINDOWS;

        case .ALL;
            assert(false, "unreachable");
    }

    if !exe_name then exe_name = path_strip_extension(source);
    if !exe_path {
        #if OS == .LINUX        then exe_path = #filepath;
        else #if OS == .WINDOWS then exe_path = windows_tools_directory;
    }
    if !arg_name then arg_name = exe_name;
    if debug then exe_name = tprint("%-debug", exe_name);

    return info;
}

build_program :: (info: Program_Info, parameters: Compile_Parameters) -> success: bool {
    using info;
    using parameters;

    builder: String_Builder;
    print(*builder, "Compiling \x1b[33m%\x1b[0m", exe_name);
    print(*builder, " (");
    if debug_build    then print(*builder, "debug");    else print(*builder, "release");
    if dynamic_binary then print(*builder, " dynamic"); else print(*builder, " static");
    print(*builder, ")");
    print(*builder, "\n");
    print(*builder, "\n");
    write_builder(*builder);

    workspace := compiler_create_workspace(exe_name);
    options := get_build_options(workspace);
    if !workspace {
        log_error("Failed to create workspace");
        return false;
    }

    #if JAILS options.output_type = .NO_OUTPUT;
    options.output_executable_name = exe_name;
    options.output_path = exe_path;

    mode := Optimization_Type.OPTIMIZED;
    if debug_build then mode = .DEBUG;
    set_optimization(*options, mode, preserve_debug_info = true);
    if debug_build options.backend = .X64;
    options.array_bounds_check = .ON;
    options.cast_bounds_check  = .FATAL;
    options.null_pointer_check = .ON;
    options.arithmetic_overflow_check = .FATAL;

    options.use_custom_link_command = !dynamic_binary;

    set_build_options(options, workspace);

    compiler_begin_intercept(workspace);

    add_build_string(tprint(#string CODE

#add_context EXECUTABLE_NAME :: "%";

    CODE, exe_name), workspace);
    add_build_file(source, workspace);

    // As far as I understand at this point the compiler is compiling my code in
    // parallel to the current program, so it's ok for me to do a bunch of slow
    // and blocking stuff?

    // Run this after starting the compilation because that way we don't block the compiler
    git_hash := get_git_commit_hash();
    git_last_commit_message := get_git_last_commit_message();
    log("git_last_commit_message:");
    log("```");
    log("%", git_last_commit_message);
    log("```");
    log("\n");
    debug_or_release := ifx debug_build then "debug" else "release";
    dynamic_or_static := ifx dynamic_binary then "dynamic" else "static";
    compiler_version := compiler_get_version_info(null);
    today := to_calendar(current_time_consensus(), .LOCAL);

    add_build_string(tprint(#string CODE

#add_context build_info: struct {
    GIT_HASH: string;
    GIT_LAST_COMMIT_MESSAGE: string;
    DEBUG_OR_RELEASE: string;
    DYNAMIC_OR_STATIC: string;
    COMPILER_VERSION: string;
    BUILD_DATE_YEAR: s32;
    BUILD_DATE_MONTH: u8;
    BUILD_DATE_DAY: u8;
} : .{
    GIT_HASH = "%",
    GIT_LAST_COMMIT_MESSAGE = "%",
    DEBUG_OR_RELEASE = "%",
    DYNAMIC_OR_STATIC = "%",
    COMPILER_VERSION = "%",
    BUILD_DATE_YEAR = %,
    BUILD_DATE_MONTH = %,
    BUILD_DATE_DAY = %,
};

        CODE,
        git_hash,
        git_last_commit_message,
        debug_or_release,
        dynamic_or_static,
        compiler_version,
        today.year,
        today.month_starting_at_0,
        today.day_of_month_starting_at_0,
    ), workspace);

    original_print_integer: *Code_Procedure_Body;
    replacement_print_integer: *Code_Procedure_Body;

    compilation_success := false;

    while true {
        base_message := compiler_wait_for_message();
        do_error_checking(null, base_message);

        if base_message.kind == .COMPLETE {
            using message := cast(*Message_Complete) base_message;
            compilation_success = (error_code == .NONE);
            break;
        }

        if base_message.kind == .TYPECHECKED {
            using message := cast(*Message_Typechecked) base_message;
            for code: procedure_bodies {
                body := code.expression;
                if has_note(body.header, "DumpAst")
                    dump_proc_ast(body);

                /* This doesn't work T_T
                filename := body.location.enclosing_load.fully_pathed_filename;
                modified := (body.body_flags & .ALREADY_MODIFIED);
                if body.header.name == "print_integer" && !modified && ends_with(filename, "Basic/Print.jai") {
                    if original_print_integer {
                        compiler_report(body.header, "duplicate Basic.print_integer", .WARNING);
                        compiler_report(original_print_integer.header, "conflicts with this one", .WARNING);
                    }
                    original_print_integer = body;
                    log("found Basic.print_integer %", get_location(original_print_integer.header));
                }
                }
                if has_note(body.header, "Replace:Basic.print_integer") {
                    if replacement_print_integer {
                        compiler_report(body.header, "duplicate replacement for Basic.print_integer", .WARNING);
                        compiler_report(replacement_print_integer.header, "conflicts with this one", .WARNING);
                    }
                    replacement_print_integer = body;
                    log("found % replacement for Basic.print_integer at %", replacement_print_integer.header.name, get_location(replacement_print_integer.header));
                }
                // if original_print_integer && replacement_print_integer {
                //     original_print_integer.block = replacement_print_integer.block;
                //     log("replacing Basic.print_integer at % with % at %", get_location(original_print_integer.header),
                //                                                           replacement_print_integer.header.name,
                //                                                           get_location(replacement_print_integer.header));
                //     compiler_modify_procedure(workspace, original_print_integer);
                // }
                */
            }
            for all if has_note(it.expression, "DumpAst") {
                dump_ast(it.expression);
            }
        }

        // if base_message.kind == .TYPECHECKED {
        //     using message := cast(*Message_Typechecked) base_message;
        //     for declarations dump_declaration(it.expression);
        // }

        if base_message.kind == .PHASE {
            using message := cast(*Message_Phase) base_message;

            if phase == .ALL_TARGET_CODE_BUILT {
                #if JAILS return true;

                if options.output_type != .NO_OUTPUT && options.backend == .LLVM
                    print("Front-end done, passing to LLVM...\n\n");
            }

            if phase == .READY_FOR_CUSTOM_LINK_COMMAND {
                #if OS == .LINUX {
                    ok := run_link_command_on_linux_with_musl(message);
                    if !ok {
                        compilation_success = false;
                        break;
                    }
                }

                #if OS == .WINDOWS {
                    run_link_command_on_windows(message);
                }

                Compiler.compiler_custom_link_command_is_complete(workspace);
            }
        }
    }

    compiler_end_intercept(workspace);

    return compilation_success;
}

run_link_command_on_linux_with_musl :: (using message: *Message_Phase) -> bool {
    assert(phase == .READY_FOR_CUSTOM_LINK_COMMAND, "%", phase);

    compiler_path := get_path_of_running_executable();
    compiler_directory := path_strip_filename(compiler_path);
    compiler_directory = trim_right(compiler_directory, "/");
    linker_path := sprint("%/lld-linux", compiler_directory);

    options := get_build_options(workspace);

    command: [..] string;
    array_add(*command, linker_path);

    // This determines the flags parsing
    array_add(*command, "-flavor", "Gnu");

    output_executable_path := sprint("%/%", options.output_path, options.output_executable_name);
    array_add(*command, "-o", output_executable_path);

    // Frame pointer related?
    array_add(*command, "--eh-frame-hdr");
    // I've seen this one before!
    array_add(*command, "-export-dynamic");

    array_add(*command, ..compiler_generated_object_files);

    // Dynamic libraries are looked up in the directory of running executable
    array_add(*command, "-rpath=$ORIGIN");

    // wget https://git.musl-libc.org/cgit/musl/snapshot/musl-1.2.5.tar.gz & configure --prefix=... & make install
    array_add(*command, sprint("%/modules/crt1.o", #filepath));
    array_add(*command, sprint("%/modules/libc.a", #filepath));
    array_add(*command, sprint("%/modules/libexecinfo.a", #filepath));

    print("Running linker: %\n", get_quoted_command_string(command));
    process_result := run_command(..command);

    if process_result.exit_code != 0 {
        print("Error: Link step failed! (Exit code %)\n", process_result.exit_code);
        return false;
    }

    return true;
}

#if OS == .WINDOWS
run_link_command_on_windows :: (using message: *Message_Phase) {
    assert(phase == .READY_FOR_CUSTOM_LINK_COMMAND, "%", phase);

    // Unfortunately there's no way to get the linker path from the compiler
    // currently, so I would have to reimplement the logic of looking for the
    // link.exe which I currently don't want to do...

    vs_library_path, vs_linker_path := find_visual_studio_in_a_ridiculous_garbage_way();
    link_exe := tprint("%\\link.exe", vs_linker_path);

    windows_kit_root, windows_kit_version := find_windows_kit_root();

    /*
    jai generates this link command line:

"C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Tools\MSVC\14.29.30133\bin\Hostx64\x64\link.exe"
    /nologo
    //wsl.localhost/Ubuntu-20.04/home/gmoshkin/dotfiles/jai/.build/windows_get_env_0_w2.obj
    //wsl.localhost/Ubuntu-20.04/home/gmoshkin/dotfiles/jai/.build/windows_get_env_1_w2.obj
    //wsl.localhost/Ubuntu-20.04/home/gmoshkin/dotfiles/jai/.build/windows_get_env_2_w2.obj
    //wsl.localhost/Ubuntu-20.04/home/gmoshkin/dotfiles/jai/.build/windows_get_env_3_w2.obj
    /OUT://wsl.localhost/Ubuntu-20.04/home/gmoshkin/dotfiles/jai/windows_get_env.exe
    /MACHINE:AMD64 /INCREMENTAL:NO
    /DEBUG
    /IMPLIB://wsl.localhost/Ubuntu-20.04/home/gmoshkin/dotfiles/jai/.build/windows_get_env.lib
    /libpath:"C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Tools\MSVC\14.29.30133\lib\x64"
    /libpath:"C:\Program Files (x86)\Windows Kits\10\Lib\10.0.19041.0\um\x64"
    /libpath:"C:\Program Files (x86)\Windows Kits\10\Lib\10.0.19041.0\ucrt\x64"
    -nodefaultlib libcmt.lib vcruntime.lib ucrt.lib kernel32.lib DbgHelp.lib msvcrt.lib kernel32.lib

    */
    options := get_build_options(workspace);

    command: [..] string;
    array_add(*command, link_exe);

    // No idea
    array_add(*command, "/nologo");

    for compiler_generated_object_files {
        array_add(*command, replace(it, "/", "\\"));
    }

    output_executable_path := tprint("%/%", options.output_path, options.output_executable_name);
    output_executable_path = replace(output_executable_path, "/", "\\");
    // NOTE: there's some retarded WSL behavior where the resulting file will
    // not have execution permissions. AFAIU the problem is that windows doesn't
    // have a concept of permission to execute, so when you run an .exe file
    // located in windows file system from WSL, the windows rules are used
    // (based on the file extension). And even if you copy the file from windows
    // file system to WSL, the permission will be automatically set. But if you
    // create an executable directly in WSL file system (for example like I do
    // it here via link.exe) then the execution permission is not being set. So
    // you have to manually call `chmod +x` on that windows executable in WSL
    // after it first gets created, but at least on recompilation it stays
    // executable... I could explicitly run `wsl.exe -e /bin/sh/ -c chmod +x <exe-path>`
    // after the binary is generated... I guess this is a TODO
    array_add(*command, tprint("/OUT:%.exe", output_executable_path));

    // x64 mode
    array_add(*command, "/MACHINE:AMD64");

    // ?
    array_add(*command, "/INCREMENTAL:NO");

    if options.emit_debug_info
        array_add(*command, "/DEBUG");

    // System library paths
    array_add(*command, tprint("/libpath:%", vs_library_path));
    array_add(*command, tprint("/libpath:%\\um\\x64", windows_kit_root));
    array_add(*command, tprint("/libpath:%\\ucrt\\x64", windows_kit_root));

    // No idea
    array_add(*command, "-nodefaultlib");

    array_add(*command, ..system_libraries);

    print("Running linker: %\n", get_quoted_command_string(command));
    process_result := run_command(..command);

    if process_result.exit_code != 0 {
        print("Error: Link step failed! (Exit code %)\n", process_result.exit_code);
    }
}

get_git_commit_hash :: () -> string {
    command: [..] string;
    array_add(*command, "git", "rev-parse", "--verify", "HEAD"); // I have no idea what --verify does...

    process_result, output, error := run_command(..command, capture_and_return_output=true);

    if process_result.exit_code != 0 {
        print("Error: command % failed (Exit code %)\n", command, process_result.exit_code);
        for split(error, "\n") {
            print("    %\n", it);
        }
        print("\n");
        return "";
    }

    return trim(output);
}

get_git_last_commit_message :: () -> string {
    command: [..] string;
    array_add(*command, "git", "log", "--format=%B", "-n1", "HEAD");

    process_result, output, error := run_command(..command, capture_and_return_output=true);

    if process_result.exit_code != 0 {
        print("Error: command % failed (Exit code %)\n", command, process_result.exit_code);
        for split(error, "\n") {
            print("    %\n", it);
        }
        print("\n");
        return "";
    }

    return trim(output);
}

db_file_path :: () -> string {
    return sprint("%/source_info.db", #filepath);
}

generate_source_info :: (program: Program) {
    using info := get_program_info(program);

    print("Parsing %...\n", source);
    t0 := seconds_since_init();

    workspace := compiler_create_workspace(tprint("%-source-info", exe_name));
    if !workspace {
        log_error("Failed to create workspace");
        return;
    }

    options := get_build_options(workspace);
    options.output_type = .NO_OUTPUT;
    options.write_added_strings = false;
    set_build_options(options, workspace);
    compiler_begin_intercept(workspace);
    add_build_file(source, workspace);

    modules: [..] *Message_Import;
    module_to_files: Table(*Message_Import, [..] *Message_File);
    file_to_declarations: Table(*Message_File, Table(*Code_Declaration, void));
    declarations_to_idents: Table(*Code_Declaration, [..] *Code_Ident);

    files_count := 0;

    while true {
        base_message := compiler_wait_for_message();

        if base_message.kind == {
            case .COMPLETE;
                break;

            case .PHASE;
                using message := cast(*Message_Phase) base_message;

            case .IMPORT;
                using message := cast(*Message_Import) base_message;
                array_add(*modules, message);

            case .FILE;
                files_count += 1;
                using message := cast(*Message_File) base_message;

                files := find_or_add(*module_to_files, enclosing_import);
                array_add(files, message);


            case .TYPECHECKED;
                using message := cast(*Message_Typechecked) base_message;

                Add_Declaration :: (code: *Code_Node) #expand {
                    decl := cast(*Code_Declaration) code;
                    decls := find_or_add(*`file_to_declarations, decl.enclosing_load);
                    table_set(decls, decl, Void);
                }

                Add_Ident :: (code: *Code_Node) #expand {
                    ident := cast(*Code_Ident) code;
                    decl := ident.resolved_declaration;
                    if decl Add_Declaration(decl);
                    idents := find_or_add(*`declarations_to_idents, decl);
                    array_add(idents, ident);
                }

                for expr: all {
                    if expr.expression.kind == {
                        case .DECLARATION; Add_Declaration(expr.expression);
                        case .IDENT;       Add_Ident(expr.expression);
                        case .TYPE_INSTANTIATION; // TODO: walk type_valued_expression and add the idents
                    }
                    for subexpr: expr.subexpressions {
                        if subexpr.kind == {
                            case .DECLARATION; Add_Declaration(subexpr);
                            case .IDENT;       Add_Ident(subexpr);
                            case .TYPE_INSTANTIATION; // TODO: walk type_valued_expression and add the idents
                        }
                    }
                }

                for procedure_bodies {
                    if !has_note(it.expression.header, "DumpAst") continue;
                    print("procedure body for '%':\n", it.expression.header.name);
                    walk_procedure_body(it.expression, level=1);
                }
                for declarations {
                    decl := it.expression;
                    if !has_note(decl, "DumpAst") continue;
                    if decl.expression.kind == .PROCEDURE_HEADER {
                        proc := cast_code_node(.PROCEDURE_HEADER, decl.expression);
                        print("declaration of procedure '%':\n", proc.name);
                        if proc.body_or_null
                            walk_procedure_body(proc.body_or_null, level=1);
                        else
                            print("    no body\n");
                    }
                }
        }
    }
    compiler_end_intercept(workspace);

    parsing_duration := seconds_since_init() - t0;

    db_path := db_file_path();
    print("Saving data to %...\n", db_path);
    t0 = seconds_since_init();
    db := Open_Database(db_path, create=true);

    Execute(db, #string SQL
        DROP TABLE IF EXISTS module;
        DROP TABLE IF EXISTS file;
        DROP TABLE IF EXISTS decl;
        DROP TABLE IF EXISTS ident;

        CREATE TABLE IF NOT EXISTS module (id INT PRIMARY KEY, name TEXT, type TEXT);
        CREATE TABLE IF NOT EXISTS file (id INT PRIMARY KEY, filepath TEXT, module INT, flags INT);
        CREATE TABLE IF NOT EXISTS decl (
            id INT PRIMARY KEY, name TEXT, flags UNSIGNED, type_or_value TEXT,
            start_line INT, start_column INT, end_line INT, end_column INT, file INT
        );
        CREATE TABLE IF NOT EXISTS ident (
            id INT PRIMARY KEY, name TEXT, decl INT,
            start_line INT, start_column INT, end_line INT, end_column INT, file INT
        );
    SQL);

    insert_module := Prepare_Stmt(db, "INSERT INTO module VALUES (?, ?, ?);");
    insert_file := Prepare_Stmt(db, "INSERT INTO file VALUES (?, ?, ?, ?);");
    insert_decl := Prepare_Stmt(db, "INSERT INTO decl VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);");
    insert_ident := Prepare_Stmt(db, "INSERT INTO ident VALUES (?, ?, ?, ?, ?, ?, ?, ?);");

    Execute(db, "BEGIN");

    files_count_check := 0;
    decl_id := 0;
    ident_id := 0;
    for module, module_id: modules {
        ok := sqlite3_put_values(insert_module, module_id, module.module_name, enum_to_string(module.module_type));
        Unwrap(ok);

        ok=, files := table_remove(*module_to_files, module);
        assert(ok);

        for file: files {
            flags: int = ifx file.from_a_string then 1 else 0;
            ok := sqlite3_put_values(insert_file, cast(int) file, file.fully_pathed_filename, module_id, flags);
            Unwrap(ok);

            ok=, decls := table_remove(*file_to_declarations, file);
            if !ok continue;
            for _, decl: decls {
                defer decl_id += 1;

                type_or_value := get_type_or_value_of_declaration(decl);
                ok := sqlite3_put_values(insert_decl, decl_id, decl.name, cast(int) decl.flags, type_or_value, decl.l0, decl.c0, decl.l1, decl.c1, cast(int) file);
                Unwrap(ok);

                ok=, idents := table_remove(*declarations_to_idents, decl);

                if !ok continue;
                for ident: idents {
                    defer ident_id += 1;

                    ok := sqlite3_put_values(insert_ident, ident_id, ident.name,
                                             decl_id, ident.l0, ident.c0, ident.l1, ident.c1,
                                             cast(int) ident.enclosing_load);
                    Unwrap(ok);
                }
            }

        }
    }

    Execute(db, "COMMIT");
    saving_duration := seconds_since_init() - t0;
    // assert(module_to_files.count == 0);
    // assert(file_to_declarations.count == 0);

    // assert(files_count == files_count_check);

    print("Some stats:\n");
    print("    parsing took %s\n", parsing_duration);
    print("    saving data took %s\n", saving_duration);
    print("    number of declarations: %\n", decl_id);
    print("    number of identifiers: %\n", ident_id);
}

inspect_source_info :: (program: Program, parameters: Inspect_Parameters) {
    db_path := db_file_path();
    db := Open_Database(db_path);

    if parameters.sub_command == {
        case .GLOBAL;     inspect_find_global_symbol(db, parameters);
        case .DEFINITION; inspect_find_definition(db, parameters);
        case .REFERENCES; inspect_find_references(db, parameters);
    }
}

inspect_find_global_symbol :: (db: *sqlite3, parameters: Inspect_Parameters) {
    using parameters;
    flags := cast(int) type_of(Code_Declaration.flags).IS_GLOBAL;

    Row :: struct {
        filepath: string;
        start_line: int;
        start_column: int;
        name: string;
        type_or_value: string;
    }
    query := #string SQL
        SELECT file.filepath, decl.start_line, decl.start_column, decl.name, decl.type_or_value
        FROM decl
        JOIN file ON file.id = decl.file
        WHERE decl.name LIKE ? AND decl.flags & ?
    SQL;
    ok, rows := sqlite_execute(db, query, Row,
        global_symbol, flags,, temp);

    if !ok {
        log_last_error(.WITH_STACK_TRACE);
        exit(1);
    }

    print("Here's all global declarations that match '%':\n", global_symbol);
    for rows {
        print("%:%,% \e[34m%\e[0m %\n", it.filepath, it.start_line, it.start_column, it.name, it.type_or_value);
    }
}

inspect_find_definition :: (db: *sqlite3, parameters: Inspect_Parameters) {
    using parameters;
    flags := cast(int) type_of(Code_Declaration.flags).IS_GLOBAL;


    //
    // lookup the identifier first
    //
    Ident_Info :: struct {
        name: string;
        id: int;
    }
    ok: bool; idents: [] Ident_Info;
    if column == -1 {
        query := #string SQL
            SELECT ident.name, ident.id
            FROM ident
            JOIN file AS ident_file ON ident_file.id = ident.file
            WHERE
                ident_file.filepath = ? AND ident.start_line = ?
        SQL;
        ok, idents = sqlite_execute(db, query, Ident_Info, filepath, line,, temp);
    } else {
        query := #string SQL
            SELECT ident.name, ident.id
            FROM ident
            JOIN file AS ident_file ON ident_file.id = ident.file
            WHERE
                ident_file.filepath = ? AND ident.start_line = ?
                AND ident.start_column <= ? AND ident.end_column >= ?
        SQL;
        ok, idents = sqlite_execute(db, query, Ident_Info, filepath, line, column, column,, temp);
    }
    Unwrap(ok);

    if !idents die("no identifer found");

    for idents {
        //
        // lookup the identifier's declaration
        //
        Row :: struct {
            filepath: string;
            start_line: int;
            start_column: int;
            name: string;
            type_or_value: string;
        }
        query := #string SQL
        SELECT decl_file.filepath, decl.start_line, decl.start_column, decl.name, decl.type_or_value
        FROM ident
        JOIN decl ON decl.id = ident.decl
        JOIN file AS decl_file ON decl_file.id = decl.file
        WHERE ident.id = ?
        SQL;

        rows: [] Row;
        ok, rows = sqlite_execute(db, query, Row, it.id,, temp);
        Unwrap(ok);

        print("Here's the declaration for identifier `%`:\n", it.name);
        for rows {
            print("%:%,% \e[34m%\e[0m %\n", it.filepath, it.start_line, it.start_column, it.name, it.type_or_value);
        }
    }
}

inspect_find_references :: (db: *sqlite3, parameters: Inspect_Parameters) {
    using parameters;
    flags := cast(int) type_of(Code_Declaration.flags).IS_GLOBAL;

    Row :: struct {
        filepath: string;
        start_line: int;
        start_column: int;
        name: string;
    }
    ok: bool; rows: [] Row;
    if column == -1 {

        query := #string SQL
            SELECT ident_file.filepath, ident.start_line, ident.start_column, ident.name
            FROM ident
            JOIN file AS ident_file ON ident_file.id = ident.file
            JOIN file AS decl_file ON decl_file.id = decl.file
            JOIN decl ON decl.id = ident.decl
            WHERE
                decl_file.filepath = ? AND decl.start_line = ?
        SQL;

        ok, rows = sqlite_execute(db, query, Row, filepath, line,, temp);

    } else {

        query := #string SQL
            SELECT ident_file.filepath, ident.start_line, ident.start_column, ident.name
            FROM ident
            JOIN file AS ident_file ON ident_file.id = ident.file
            JOIN file AS decl_file ON decl_file.id = decl.file
            JOIN decl ON decl.id = ident.decl
            WHERE
                decl_file.filepath = ? AND decl.start_line = ?
                AND decl.start_column <= ? AND decl.end_column >= ?
        SQL;

        ok, rows = sqlite_execute(db, query, Row,
            filepath, line, column, column
            ,, temp);

    }

    if !ok {
        log_last_error(.WITH_STACK_TRACE);
        exit(1);
    }

    print("Here's all references to that declaration:\n");
    for rows {
        print("%:%,% \e[34m%\e[0m\n", it.filepath, it.start_line, it.start_column, it.name);
    }
}



enum_to_string :: inline (value: $E) -> string {
    #assert type_info(E).type == .ENUM;
    return enum_to_string(xx value, type_info(E));
}

enum_to_string :: (value: int, type: *Type_Info_Enum) -> string {
    for type.values if it == value return type.names[it_index];
    return tprint("<out of range %>", value);
}

Open_Database :: (path: string, create := false) -> *sqlite3 #expand {
    db: *sqlite3;
    `defer sqlite3_close(db);

    flags: SQLITE_OPEN = ifx create then .READWRITE | .CREATE else .READONLY;
    rc := sqlite3_open_v2(path.data, *db, xx flags, null);
    if rc != SQLITE_OK {
        set_last_error_from_sql(db);
        prepend_error_message("failed to open db '%': ", path);
        log_last_error(.WITH_STACK_TRACE);
    }
    assert(rc == SQLITE_OK);

    return db;
}

Execute :: (db: *sqlite3, query: string) {
    error: *u8;
    rc := sqlite3_exec(db, query.data, null, null, *error);
    if rc != SQLITE_OK {
        set_last_error_from_sql(db);
        log_last_error(.WITH_STACK_TRACE);
        exit(1);
    }
}

Prepare_Stmt :: (db: *sqlite3, query: string) -> *sqlite3_stmt #expand {
    stmt: *sqlite3_stmt;
    `defer sqlite3_finalize(stmt);

    rc := sqlite3_prepare_v2(db, query.data, xx query.count, *stmt, null);
    if rc == SQLITE_ERROR {
        set_last_error_from_sql(db);
        log_last_error(.WITH_STACK_TRACE);
        exit(1);
    }
    assert(rc == SQLITE_OK, "%", rc);

    return stmt;
}

Unwrap :: (ok: bool) #expand {
    if !ok {
        log_last_error(.WITH_STACK_TRACE);
        exit(1);
    }
}

show_procedure_type :: (base_type: *Type_Info) {
    assert(base_type.type == .PROCEDURE);
    type := cast(*Type_Info_Procedure) base_type;

    print("procedure %\n", type);
    print("    arguments:\n");
    for type.argument_types {
        print("        %: %\n", it, it.*);
    }

    for type.return_types {
        print("        %: %\n", it, it.*);
    }
}

get_type_or_value_of_declaration :: (decl: *Code_Declaration) -> string {
    logger_saved := context.logger;
    defer context.logger = logger_saved;
    context.logger = (_, _, _) => {};

    print_procedure_bodies = false;
    builder: String_Builder;
    if decl.expression {
        if decl.flags & .IS_CONSTANT print(*builder, ":: ");
        else                         print(*builder, ":= ");

        print_expression(*builder, decl.expression);
    } else if decl.type_inst {
        print(*builder, ": ");
        print_expression(*builder, decl.type_inst);
    } else {
        print(*builder, "?");
    }
    return builder_to_string(*builder);
}

compiler_report :: inline (code: *Code_Node, message: string, mode := Report.ERROR) #compiler {
    filename := code.enclosing_load.fully_pathed_filename;
    line := code.l0;
    column := code.c0;
    compiler_report(filename, line, column, message, mode);
}

get_location :: (code: *Code_Node) -> string {
    builder := String_Builder.{ allocator = temp };
    print_location(*builder, code);
    return builder_to_string(*builder,, temp);
}

print_location :: (builder: *String_Builder, code: *Code_Node) {
    print(builder, "%:%,%", code.enclosing_load.fully_pathed_filename, code.l0, code.c0);
}


walk_procedure_body :: (proc: *Code_Procedure_Body, level := 0) {
    builder := String_Builder.{ allocator = temp };

    block := proc.block;
    print("%\n", Temp_String(#code print_base_code(b, block)));

    walk_block(block, 1);
}

walk_block :: (block: *Code_Block, level := 0) {
    if !block return;
    builder := String_Builder.{ allocator = temp };
    append_padding(*builder, level * 4);
    padding := builder_to_string(*builder,, temp);

    next_level := level + 1;

    for block.statements {
        print("%1%2\n", padding, Temp_String(#code print_base_code(b, it)));
        if it.kind == {
            case .BLOCK;
                walk_block(xx it, next_level);
            case .DEFER;
                code := cast(*Code_Defer) it;
                if code.block {
                    print("%", padding);
                    print_base_code(b, code.block);
                    print("\n");
                    walk_block(code.block, next_level);
                }
            case .IF;
                code := cast(*Code_If) it;
                if code.then_block {
                    print("%", padding);
                    print_base_code(b, code.then_block);
                    print("\n");
                    walk_block(code.then_block, next_level);
                }
                if code.else_block {
                    print("%", padding);
                    print_base_code(b, code.else_block);
                    print("\n");
                    walk_block(code.else_block, next_level);
                }
            case .CASE;
                code := cast(*Code_Case) it;
                if code.then_block {
                    print("%", padding);
                    print_base_code(b, code.then_block);
                    print("\n");
                    walk_block(code.then_block, next_level);
                }
            case .FOR;
                code := cast(*Code_For) it;
                if code.block {
                    print("%", padding);
                    print_base_code(b, code.block);
                    print("\n");
                    walk_block(code.block, next_level);
                }
            case .WHILE;
                code := cast(*Code_While) it;
                if code.block {
                    print("%", padding);
                    print_base_code(b, code.block);
                    print("\n");
                    walk_block(code.block, next_level);
                }
            case .PROCEDURE_CALL;
                code := cast(*Code_Procedure_Call) it;
                if code.macro_expansion_block {
                    print("%", padding);
                    print_base_code(b, code.macro_expansion_block);
                    print("\n");
                    walk_block(code.macro_expansion_block, next_level);
                }
            case;
        }
    }
}


Temp_String :: ($code: Code) -> string #expand {
    builder := String_Builder.{ allocator = temp };
    `b := *builder;
    #insert code;
    return builder_to_string(*builder,, temp);
}

dump_proc_ast :: (proc: *Code_Procedure_Body) {
    format_struct := *context.print_style.default_format_struct;
    format_struct.draw_type_name = true;
    format_struct.use_long_form_if_more_than_this_many_members = -1;
    format_struct.use_newlines_if_long_form = true;
    data: My_Struct_Printer_Data;

    new_context := context;
    new_context.print_style.struct_printer = code_struct_printer;
    new_context.print_style.struct_printer_data = *data;
    push_context,defer_pop new_context;

    print("@DumpAst on procedure %\n", proc.header.name);
    // print("%\n", proc.block.*);
}

dump_ast :: (base_code: *Code_Node) {
    builder := String_Builder.{ allocator = temp };
    print(*builder, "@DumpAst on ");
    print_base_code(*builder, base_code);
    print(*builder, "\n");
    write_builder(*builder);
}

dump_declaration :: (decl: *Code_Declaration) {
    using decl;
    filepath := get_filename(decl);
    filename := get_short_filename(filepath);

    builder: String_Builder;
    print(*builder, "%:%,%: %", filename, location.l0, location.c0, name);
    if type.type == .TYPE {
        print(*builder, " :: ");

        type: *Type_Info;
        if decl.expression.kind == {
            case .TYPE_DEFINITION;
                code := cast(*Code_Type_Definition) decl.expression;
                type = code.info;
            case .TYPE_INSTANTIATION;
                code := cast(*Code_Type_Instantiation) decl.expression;
                if code.result
                    type = code.result;
                else if code.type_directive_target && code.type_directive_target.result {
                    type = code.type_directive_target.result;
                } else
                    print(*builder, "<null>");
            case .IDENT;
                code := cast(*Code_Ident) decl.expression;
                type = code.resolved_declaration.type;
            case .STRUCT;
                code := cast(*Code_Struct) decl.expression;
                type = code.defined_type;
                print(*builder, "struct ");
            case .ENUM;
                code := cast(*Code_Enum) decl.expression;
                type = code.external_type;
                print(*builder, "enum ");
            case;
                print_base_code(*builder, decl.expression);
        }
        if type {
            print_type_to_builder(*builder, type);
            print(*builder, " /* size: % */", type.runtime_size);
        }

    } else {
        char := ifx decl.flags & .IS_CONSTANT then ":" else "=";
        print(*builder, ": ");
        print_type_to_builder(*builder, type);
        if decl.expression {
            if decl.expression.kind == {
                case .LITERAL;
                    code := cast(*Code_Literal) decl.expression;
                    print(*builder, " % ", char);
                    print_literal(*builder, code);
                case .PROCEDURE_HEADER;
                case;
                    print(*builder, " % ", char);
                    print_base_code(*builder, decl.expression);
            }
        }
    }
    print(*builder, "\n");
    write_builder(*builder);
}

print_literal :: (builder: *String_Builder, code: *Code_Literal) {
    if code.value_type == {
        case .UNINITIALIZED;
            print(builder, "<uninit>");
        case .NUMBER;
            if code.value_flags & .FLOAT    print(builder, "%", code.values._float64);
            else                            print(builder, "%", code.values._s64);
        case .STRING;
            print(builder, "'%'", code.values._string);
        case .BOOLEAN;
            if code.values._u64  print(builder, "true");
            else                 print(builder, "false");
        case .ARRAY;
            print(builder, "<array>");
        case .STRUCT;
            print(builder, "<struct>");
        case .POINTER;
            print(builder, "<pointer>");
        case .TYPE_INFO;
            print(builder, "<type_info>");
    }
}

My_Struct_Printer_Data :: struct {
    seen_nodes: Table(*Code_Node, bool);
    skip_next_code: bool;
    skip_next_type: bool;
}

code_struct_printer :: (builder: *String_Builder, any: Any, struct_printer_data: *void) -> bool {
    data := cast(*My_Struct_Printer_Data) struct_printer_data;

    if any.type == type_info(*Type_Info) {
        // if data.skip_next_type {
        //     data.skip_next_type = false;
        //     return false;
        // }
        // data.skip_next_type = true;

        type := << cast(**Type_Info) any.value_pointer;
        if !type return false;
        print_type_to_builder(builder, type);
        return true;
    }

    base_code, ok := cast_to_base_with_dereference(any.type, any.value_pointer, Code_Node);
    if !ok return false;
    if !base_code return false;

    if data.skip_next_code {
        data.skip_next_code = false;
        return false;
    }

    // {
    //     builder: String_Builder;
    //     // print(*builder, "depth: %, ", depth.*);
    //     print(*builder, "%: ", cast(*void) base_code);
    //     print_base_code(*builder, base_code);
    //     append(*builder, "\n");
    //     write_builder(*builder);
    // }

    print(builder, "(%)", cast(*void) base_code);
    if table_find_pointer(*data.seen_nodes, base_code) {
        // print("second time\n");
        // Already did a deep print for this guy
        print_base_code(builder, base_code);
        return true;
    }
    table_add(*data.seen_nodes, base_code, true);

    data.skip_next_code = true;
    if base_code.kind == {
        case .BLOCK;                        print(builder, "%", << cast(*Code_Block) base_code);
        case .USING;                        print(builder, "%", << cast(*Code_Using) base_code);
        case .PROCEDURE_CALL;               print(builder, "%", << cast(*Code_Procedure_Call) base_code);
        case .PROCEDURE_BODY;               print(builder, "%", << cast(*Code_Procedure_Body) base_code);
        case .DECLARATION;                  print(builder, "%", << cast(*Code_Declaration) base_code);
        case .COMPOUND_DECLARATION;         print(builder, "%", << cast(*Code_Compound_Declaration) base_code);
        case .COMMA_SEPARATED_ARGUMENTS;    print(builder, "%", << cast(*Code_Comma_Separated_Arguments) base_code);
        case .TYPE_DEFINITION;              print(builder, "%", << cast(*Code_Type_Definition) base_code);
        case .TYPE_QUERY;                   print(builder, "%", << cast(*Code_Type_Query) base_code);
        case .IF;                           print(builder, "%", << cast(*Code_If) base_code);
        case .FOR;                          print(builder, "%", << cast(*Code_For) base_code);
        case .WHILE;                        print(builder, "%", << cast(*Code_While) base_code);
        case .UNARY_OPERATOR;               print(builder, "%", << cast(*Code_Unary_Operator) base_code);
        case .BINARY_OPERATOR;              print(builder, "%", << cast(*Code_Binary_Operator) base_code);
        case .CONTEXT;                      print(builder, "%", << cast(*Code_Context) base_code);
        case .EXTRACT;                      print(builder, "%", << cast(*Code_Extract) base_code);
        case .TYPE_INSTANTIATION;           print(builder, "%", << cast(*Code_Type_Instantiation) base_code);
        case .IDENT;                        print(builder, "%", << cast(*Code_Ident) base_code);
        case .LITERAL;                      print(builder, "%", << cast(*Code_Literal) base_code);
        case .STRUCT;                       print(builder, "%", << cast(*Code_Struct) base_code);
        case .ENUM;                         print(builder, "%", << cast(*Code_Enum) base_code);
        case .RETURN;                       print(builder, "%", << cast(*Code_Return) base_code);
        case .CAST;                         print(builder, "%", << cast(*Code_Cast) base_code);
        case .MAKE_VARARGS;                 print(builder, "%", << cast(*Code_Make_Varargs) base_code);
        case .DIRECTIVE_PLACE;      // print(builder, "%", << cast(*Code_Directive_Place) base_code);
            print_base_code(builder, base_code);

        case .PROCEDURE_HEADER; // print(builder, "%", << cast(*Code_Procedure_Header) base_code);
            print_base_code(builder, base_code);

        case;
            print(builder, "[**UNHANDLED**]", base_code);
            print_base_code(builder, base_code);
    }
    return true;
}

print_base_code :: (code: *Code_Node) {
    builder := String_Builder.{ allocator = temp };
    print_base_code(*builder, code);
    write_builder(*builder);
}

print_base_code :: (builder: *String_Builder, code: *Code_Node) {
    if !code return;
    using code;
    print_location(builder, code);
    print(builder, " ");
    if serial print(builder, "#% ", serial);
    print(builder, "\e[35m%\e[0m ", kind);
    if node_flags print(builder, "[%] ", node_flags);
    if code.kind == {
        case .DECLARATION;
            print(builder, "%: ", (cast(*Code_Declaration) code).name);
            print_type_to_builder(builder, type);
        case .IDENT;
            print(builder, "%: ", (cast(*Code_Ident) code).name);
            print_type_to_builder(builder, type);
        case .LITERAL;
            print_literal(builder, cast(*Code_Literal) code); print(builder, " ");
        case .BINARY_OPERATOR;
            print_operator_type(builder, (cast(*Code_Binary_Operator) code).operator_type);
            print(builder, " ");
            print_type_to_builder(builder, type);
    }
}

print_operator_type :: (builder: *String_Builder, operator_type: s32) {
    buf: [1] u8;
    if operator_type < 0x7f {
        buf[0] = xx operator_type;
        print(builder, "%", cast(string) buf);
    } else {
        print(builder, "%", operator_to_string(cast(Operator_Type) operator_type));
    }
}

get_short_filename :: (code: *Code_Node) -> string {
    return get_short_filename(get_filename(code));
}

get_short_filename :: (filepath: string) -> string {
    filename := path_filename(filepath);
    if filename == "module.jai" {
        p := filename.data - 2;
        while p >= filepath.data {
            if p[0] == #char "/" break;
            p -= 1;
        }
        p = max(filepath.data, p + 1);
        filename.count += filename.data - p;
        filename.data = p;
    }
    return filename;
}

cast_to_base_with_dereference :: (type_: *Type_Info, value_pointer_: *void, $T: Type) -> *T, ok: bool {
    type := type_;
    value_pointer := value_pointer_;
    i := 1;
    while true {
        defer i += 1;
        // builder: String_Builder;
        // print(*builder, "got type #%: ", i);
        // print_type_to_builder(*builder, type);
        // print(*builder, ", %\n", value_pointer);
        // write_builder(*builder);

        if !value_pointer return null, false;

        if type == type_info(T) return xx value_pointer, true;

        if type.type == {
            case .POINTER;
                type = (cast(*Type_Info_Pointer) type).pointer_to;
                value_pointer = << cast(**void) value_pointer;
                continue;
            case .STRUCT;
                struct_type := cast(*Type_Info_Struct) type;
                if struct_type.members.count == 0 return null, false;
                first_member := struct_type.members[0];
                if !(first_member.flags & .AS) return null, false;

                type = first_member.type;
                value_pointer = xx ((cast(*u8) value_pointer) + first_member.offset_in_bytes);
                continue;
            case;
                return null, false;
        }

    }
    return null, false;
}

cast_with_dereference :: (type_: *Type_Info, value_pointer_: *void, $T: Type) -> *T, found_null: bool {
    type := type_;
    value_pointer := value_pointer_;
    while true {
        if !value_pointer return null, true;

        if type == type_info(T) return xx value_pointer, false;

        if type.type != .POINTER return null, false;

        type = (cast(*Type_Info_Pointer) type).pointer_to;
        value_pointer = << cast(**void) value_pointer;
    }
    return null, true;
}

is_code_node :: (info: *Type_Info) -> bool {
    while true {
        info = unwrap_pointers(info);

        if info.type != .STRUCT return false;
        info_struct := cast(*Type_Info_Struct) info;

        if info_struct == type_info(Code_Node) return true;

        if info_struct.members.count == 0 return false;
        first_member := info_struct.members[0];
        if !(first_member.flags & .AS) return false;

        info = first_member.type;
    }

    return false;
}

unwrap_pointers :: (info: *Type_Info) -> *Type_Info {
    while true {
        if info.type != .POINTER return info;
        info = (cast(*Type_Info_Pointer) info).pointer_to;
    }
    return null;
}

has_note :: (proc: *Code_Procedure_Header, note: string) -> bool {
    for proc.notes {
        if it.text == note return true;
    }
    return false;
}

has_note :: (base_code: *Code_Node, note: string) -> bool {
    notes: [] *Code_Note;
    if base_code.kind == {
        case .COMPOUND_DECLARATION; notes = cast_code_node(.COMPOUND_DECLARATION, base_code).notes;
        case .DECLARATION;          notes = cast_code_node(.DECLARATION,          base_code).notes;
        case .ENUM;                 notes = cast_code_node(.ENUM,                 base_code).notes;
        case .STRUCT;               notes = cast_code_node(.STRUCT,               base_code).notes;
        case .PROCEDURE_HEADER;     notes = cast_code_node(.PROCEDURE_HEADER,     base_code).notes;
    }
    for notes if it.text == note return true;
    return false;
}

cast_code_node :: ($tag: Code_Node.Kind, base: *Code_Node) -> *$R
#modify {
    R = tag_to_type(tag);
    return true;
}
#expand {
    return cast(*R) base;
}

tag_to_type :: (tag: Code_Node.Kind) -> Type {
    if #complete tag == {
        case .UNINITIALIZED;               assert(false, "no type to cast to");
        case .BLOCK;                       return Code_Block;
        case .LITERAL;                     return Code_Literal;
        case .IDENT;                       return Code_Ident;
        case .UNARY_OPERATOR;              return Code_Unary_Operator;
        case .BINARY_OPERATOR;             return Code_Binary_Operator;
        case .PROCEDURE_BODY;              return Code_Procedure_Body;
        case .PROCEDURE_CALL;              return Code_Procedure_Call;
        case .RESOLVED_OVERLOAD;           return Code_Resolved_Overload;
        case .CONTEXT;                     return Code_Context;
        case .WHILE;                       return Code_While;
        case .IF;                          return Code_If;
        case .LOOP_CONTROL;                return Code_Loop_Control;
        case .CASE;                        return Code_Case;
        case .RETURN;                      return Code_Return;
        case .FOR;                         return Code_For;
        case .TYPE_DEFINITION;             return Code_Type_Definition;
        case .TYPE_INSTANTIATION;          return Code_Type_Instantiation;
        case .ENUM;                        return Code_Enum;
        case .PROCEDURE_HEADER;            return Code_Procedure_Header;
        case .STRUCT;                      return Code_Struct;
        case .COMMA_SEPARATED_ARGUMENTS;   return Code_Comma_Separated_Arguments;
        case .EXTRACT;                     return Code_Extract;
        case .DIRECTIVE_BYTES;             return Code_Directive_Bytes;
        case .MAKE_VARARGS;                return Code_Make_Varargs;
        case .DECLARATION;                 return Code_Declaration;
        case .CAST;                        return Code_Cast;
        case .DIRECTIVE_IMPORT;            return Code_Directive_Import;
        case .DIRECTIVE_THIS;              assert(false, "no type to cast to");
        case .DIRECTIVE_THROUGH;           return Code_Directive_Through;
        case .DIRECTIVE_LOAD;              return Code_Directive_Load;
        case .DIRECTIVE_RUN;               return Code_Directive_Run;
        case .DIRECTIVE_CODE;              return Code_Directive_Code;
        case .DIRECTIVE_POKE_NAME;         return Code_Directive_Poke_Name;
        case .DIRECTIVE_CONTEXT_TYPE;      return Code_Directive_Context_Type;
        case .ASM;                         return Code_Asm;
        case .DIRECTIVE_BAKE;              return Code_Directive_Bake;
        case .DIRECTIVE_MODIFY;            return Code_Directive_Modify;
        case .DIRECTIVE_LIBRARY;           return Code_Directive_Library;
        case .EXPRESSION_QUERY;            return Code_Expression_Query;
        case .PUSH_CONTEXT;                return Code_Push_Context;
        case .NOTE;                        return Code_Note;
        case .DIRECTIVE_PLACE;             assert(false, "no type to cast to");
        case .DIRECTIVE_SCOPE;             return Code_Directive_Scope;
        case .TYPE_QUERY;                  return Code_Type_Query;
        case .DIRECTIVE_LOCATION;          return Code_Directive_Location;
        case .DIRECTIVE_MODULE_PARAMETERS; return Code_Directive_Module_Parameters;
        case .DIRECTIVE_ADD_CONTEXT;       assert(false, "no type to cast to");
        case .DIRECTIVE_COMPILE_TIME;      assert(false, "no type to cast to");
        case .COMPOUND_DECLARATION;        return Code_Compound_Declaration;
        case .DEFER;                       return Code_Defer;
        case .USING;                       return Code_Using;
        case .PLACEHOLDER;                 return Code_Placeholder;
        case .DIRECTIVE_INSERT;            return Code_Directive_Insert;
        case .DIRECTIVE_PROCEDURE_NAME;    return Code_Directive_Procedure_Name;
        case .DIRECTIVE_WILDCARD;          return Code_Directive_Wildcard;
        case .DIRECTIVE_EXISTS;            return Code_Directive_Exists;
    }
    assert(false, "unexpected Code_Node.Kind: %", tag);
    return void;
}

last_char :: inline (s: string) -> u8 {
    return s[s.count - 1];
}

take_file_line_column_from_arguments :: (args: [] string, cursor: *int, file: *string, line: *int, column: *int) -> bool {
    ok: bool;
    column.* = -1;

    if !take_argument(args, cursor, file) return false;
    found, f, line_column := split_from_left(<<file, #char ":");
    if found  file.* = f;
    if file.*[0] != #char "/" then file.* = tprint("%/%", #filepath, file.*);

    if !found {
        if !take_argument(args, cursor, line) return false;
        if cursor.* == args.count return true;
        return take_argument(args, cursor, column);
    }

    found=, line_str, column_str := split_from_left(line_column, #char ",");
    line.*, ok = string_to_int(line_str);
    if !ok return false;
    if !found return true;

    value:, ok = string_to_int(column_str);
    if !ok return false;
    column.* = value;

    return true;
}

take_argument :: (args: [] string, cursor: *int, result: *$T) -> bool {
    if args.count <= cursor.* return false;
    defer cursor.* += 1;
    arg := args[cursor.*];

    #if T == string {
        result.* = arg;
        return true;

    } else #if T == int {
        value, ok := string_to_int(arg);
        result.* = value;
        return ok;

    } else {
        #assert false;
    }
}

die :: (format: string, args: .. Any) {
    print("\x1b[31m");
    print(format, ..args);
    print("\x1b[0m\n");
    exit(1);
} @PrintLike

Void: void;

#import "Basic";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "Print_Vars";
#import "Process";
#import "System";
#import "String";
#import "Check";
#import "Hash_Table";
#import "Sqlite3";
#import "Error_Info";
#import "Program_Print";
#import "Program_Print";
#import "My_Util";
#if OS == .WINDOWS {
    #import "Windows_Resources";
}
