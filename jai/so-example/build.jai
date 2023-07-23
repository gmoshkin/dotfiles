#run {
    set_build_options_dc(.{do_output=false});

    // if !generate_bindings() {
    //     compiler_set_workspace_status(.FAILED);
    //     return;
    // }

    {
        w := compiler_create_workspace();
        options := get_build_options();
        options.output_executable_name = "example";
        options.output_type            = .DYNAMIC_LIBRARY;
        // set_optimization(*options, .OPTIMIZED);
        set_build_options(options, w);

        compiler_begin_intercept(w);

        add_build_file("lib.jai", w);

        while true {
            m := compiler_wait_for_message();
            if !m break;
            if m.kind == .COMPLETE {
                mc := cast(*Message_Complete) m;
                if mc.error_code != .NONE {
                    print("dynamic library compilation failed");
                    return;
                }

                break;
            }
        }

        compiler_end_intercept(w);
    }
    {
        w := compiler_create_workspace();
        options := get_build_options();
        options.output_executable_name = "example";
        options.output_type            = .EXECUTABLE;
        // set_optimization(*options, .OPTIMIZED);
        set_build_options(options, w);

        compiler_begin_intercept(w);

        add_build_file("main.jai", w);

        while true {
            m := compiler_wait_for_message();
            if !m break;
            if m.kind == .COMPLETE {
                mc := cast(*Message_Complete) m;
                if mc.error_code != .NONE {
                    print("executable compilation failed");
                    return;
                }

                break;
            }
        }

        compiler_end_intercept(w);
    }
}

generate_bindings :: () -> bool {
    {
        output_filename := "tarantool.jai";
        opts: Generate_Bindings_Options;
        opts.strip_flags = .INLINED_FUNCTIONS;
        array_add(*opts.system_include_paths, GENERATOR_DEFAULT_SYSTEM_INCLUDE_PATH);
        array_add(*opts.system_include_paths, "/home/gmoshkin/.local/include/tarantool");
        array_add(*opts.source_files, "/home/gmoshkin/.local/include/tarantool/module.h");
        if !generate_bindings(opts, output_filename) return false;
    }

    {
        output_filename := "lua.jai";
        opts: Generate_Bindings_Options;
        opts.strip_flags = .INLINED_FUNCTIONS;
        array_add(*opts.system_include_paths, GENERATOR_DEFAULT_SYSTEM_INCLUDE_PATH);
        array_add(*opts.system_include_paths, "/home/gmoshkin/.local/include/tarantool");
        array_add(*opts.source_files, "/home/gmoshkin/.local/include/tarantool/lua.h");
        if !generate_bindings(opts, output_filename) return false;
    }

    return true;
}

#import "Basic";
#import "Compiler";
#import "Bindings_Generator";
