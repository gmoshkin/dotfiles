#run {
    set_build_options_dc(.{do_output = false});

    debug_build := false;
    dynamic_binary := false;
    program := Program.ALL;

    cursor := 0;
    options := get_build_options();
    args := options.compile_time_command_line;
    while cursor < args.count {
        defer cursor += 1;
        it := args[cursor];
        if it == {
            case "debug";       debug_build = true;
            case "dynamic";     dynamic_binary = true;

            case "pageview";    program = .PAGEVIEW;
            case "ps";          program = .PS;
            case "status-line"; program = .STATUS_LINE;
            case "all";         program = .ALL;

            case; print("\x1b[33mUnknown argument '%'\x1b[0m\n", it);
        }
    }

    if program == .ALL {
        for type_info(Program).values {
            program = xx it;
            if program == .ALL continue;
            build_program(program, debug_build, dynamic_binary);
        }
    } else {
        build_program(program, debug_build, dynamic_binary);
    }
}

Program :: enum {
    ALL;
    PAGEVIEW;
    PS;
    STATUS_LINE;
}

build_program :: (program_name: Program, debug_build: bool, dynamic_binary: bool) {
    directory_of_this_file := path_strip_filename(#file);
    directory_of_this_file = trim_right(directory_of_this_file, "/");

    compiler_path := get_path_of_running_executable();
    compiler_directory := path_strip_filename(compiler_path);
    compiler_directory = trim_right(compiler_directory, "/");
    linker_path := sprint("%/lld-linux", compiler_directory);

    exe_name: string;
    exe_path: string;
    source: string;
    if #complete program_name == {
        case .PAGEVIEW;
            exe_name = "pageview";
            exe_path = directory_of_this_file;
            source = "pageview.jai";
        case .PS;
            exe_name = "myps";
            exe_path = directory_of_this_file;
            source = "ps.jai";
        case .STATUS_LINE;
            exe_name = "status-line-linux";
            exe_path = sprint("%/../tmux/", directory_of_this_file);
            source = sprint("%/../tmux/status-line.jai", directory_of_this_file);
        case .ALL;
            assert(false, "unreachable");
    }

    if debug_build {
        exe_name = sprint("%-debug", exe_name);
    }

    print("Compiling %\n", exe_name);

    workspace := compiler_create_workspace(exe_name);
    options := get_build_options(workspace);
    if !workspace {
        log_error("Failed to create workspace");
        return;
    }

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
    add_build_file(source, workspace);

    while true {
        base_message := compiler_wait_for_message();
        do_error_checking(null, base_message);

        if base_message.kind == .COMPLETE break;

        if base_message.kind == .PHASE {
            using message := cast(*Message_Phase) base_message;

            if phase == .ALL_TARGET_CODE_BUILT {
                if options.backend == .LLVM print("Front-end done, passing to LLVM...\n");
            }

            if phase == .READY_FOR_CUSTOM_LINK_COMMAND {
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

                array_add(*command, sprint("%/modules/crt1.o", directory_of_this_file));
                array_add(*command, sprint("%/modules/libc.a", directory_of_this_file));
                array_add(*command, sprint("%/modules/libexecinfo.a", directory_of_this_file));

                print("Running linker: %\n", get_quoted_command_string(command));
                process_result := run_command(..command);

                if process_result.exit_code != 0 {
                    print("Error: Link step failed! (Exit code %)\n", process_result.exit_code);
                }

                Compiler.compiler_custom_link_command_is_complete(workspace);
            }
        }
    }

    compiler_end_intercept(workspace);
};

last_char :: inline (s: string) -> u8 {
    return s[s.count - 1];
}

#import "Basic";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "Print_Vars";
#import "Process";
#import "System";
#import "String";
#import "Check";
