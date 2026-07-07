// **WARNING** bindings.jai file is dirty!
AT_COMPILE_TIME :: true;

ENABLE_GNU_SOURCE :: true; // Enable this and re-run the generator to get Linux’ _GNU_SOURCE extensions to POSIX.

#if AT_COMPILE_TIME {
    #run,stallable {
        set_build_options_dc(.{do_output=false});
        options := get_build_options();
        args := options.compile_time_command_line;
        if !generate_bindings(args) {
            compiler_set_workspace_status(.FAILED);
        }
    }
} else {
    #import "System";

    main :: () {
        set_working_directory(path_strip_filename(get_path_of_running_executable()));
        args := get_command_line_arguments();
        if !generate_bindings(args) {
            exit(1);
        }
    }
}

get_common_options :: () -> Generate_Bindings_Options {
    options: Generate_Bindings_Options;

    array_add(*options.extra_clang_arguments,
        "-x", "c",
        // Disable some warnings we don’t care about
        "-Wno-nullability-completeness",
        "-Wno-expansion-to-defined",
    );

    array_add(*options.libraries, .{"libproc", ""});

    options.generate_printf_wrappers            = false;
    options.log_stripped_declarations           = false;
    options.generate_compile_time_struct_checks = false;

    options.log_stripped_declarations = true;

    return options;
}

generate_bindings :: (args: [] string) -> bool {
    directory_of_this_file := path_strip_filename(#file);
    directory_of_this_file = trim_right(directory_of_this_file, "/");

    output_path := tprint("%/bindings/libproc.jai", directory_of_this_file);
    options := get_common_options();

    sdk_path, ok := get_macos_sdk_path();
    if !ok {
        log_error("get_macos_sdk_path failed");
        return false;
    }

    // I got this list by first generating without it then trying to compile and
    // seeing which symbols were reported as undefined
    array_add(*options.system_types_to_include,
        "audit_token_t",
        "sockaddr_un",
        "in_addr",
        "in6_addr",
        "cpu_subtype_t",
        "cpu_type_t",
        "fsid",
        "fsid_t",
        "in_addr_t",
        "sa_family_t",
        "vnode",
    );

    array_add(*options.source_files, tprint("%/usr/include/sys/proc.h", sdk_path));
    array_add(*options.source_files, tprint("%/usr/include/sys/proc_info.h", sdk_path));
    array_add(*options.source_files, tprint("%/usr/include/libproc.h", sdk_path));

    // Took these from modules/POSIX/generate.jai > generate_sysctl_bindings
    options.visitor_with_data = (decl: *Declaration, parent_decl: *Declaration, user_data: *void) -> Declaration_Visit_Result {
        declarations_to_omit := string.["extern_proc", "P_TRACED", "pgrp", "session", "proc", "vmspace"];

        if array_find(declarations_to_omit, decl.name) {
            decl.decl_flags |= .OMIT_FROM_OUTPUT;
            // log("Omitting % from output", decl.name);
            return .STOP;
        }

        return .RECURSE;
    };

    return generate_bindings(options, output_path);
}

#scope_file

#import "macOS/Toolchain";
#import "Basic";
#import "Bindings_Generator";
#import "Compiler";
#import "File";
#import "String";
