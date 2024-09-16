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

already_generated: Table(string, bool);

get_common_options :: () -> Generate_Bindings_Options {
    options: Generate_Bindings_Options;

    array_add(*options.extra_clang_arguments,
        "-x", "c",
        // Disable some warnings we don’t care about
        "-Wno-nullability-completeness",
        "-Wno-expansion-to-defined",
    );

    /* Here's how you may get this library: (TODO add just do this in this program)
    ```
    wget https://sqlite.org/snapshot/sqlite-snapshot-202408161851.tar.gz
    # untar & cd & mkdir build
    gcc -c ../sqlite3.c -o sqlite3.o -O3 -fPIC
    gcc -shared -o libsqlite3.so sqlite3.o
    ```
    */

    array_add(*options.libnames, "libsqlite3.so");

    options.generate_printf_wrappers            = false;
    options.log_stripped_declarations           = false;
    options.generate_compile_time_struct_checks = false;

    options.log_stripped_declarations = true;
    options.will_print_bindings = track_already_generated;

    return options;
}

generate_bindings :: (args: [] string) -> bool {
    directory_of_this_file := path_strip_filename(#file);
    directory_of_this_file = trim_right(directory_of_this_file, "/");

    output_path := tprint("%/bindings.jai", directory_of_this_file);
    options := get_common_options();

    options.generate_printf_wrappers = false;

    array_add(*options.source_files, tprint("%/sqlite3.h", directory_of_this_file));

    return generate_bindings(options, output_path);
}

#scope_file

track_already_generated :: () {
    push_allocator(context.default_allocator);
    for decl: context.generator.global_scope.members {
        if decl.decl_flags & .OMIT_FROM_OUTPUT continue;
        table_add(*already_generated, copy_string(decl.output_name), true);
    }
}


#import "Toolchains/Android";
#import "Toolchains/macOS";
#import "Basic";
#import "Bindings_Generator";
#import "Compiler";
#import "File";
#import "String";
#import "Hash_Table";
