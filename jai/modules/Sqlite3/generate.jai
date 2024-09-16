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

    // XXX unfortunately Bindings_Generator doesn't allow us to automatically
    // make these enums `enum_flags`, so we have to go and modify the generated
    // code manually
    array_add(*options.generate_enums_from_macros_with_prefixes, "SQLITE_OPEN_");
    // XXX for this one too
    array_add(*options.generate_enums_from_macros_with_prefixes, "SQLITE_IOCAP_");
    array_add(*options.generate_enums_from_macros_with_prefixes, "SQLITE_LOCK_");
    array_add(*options.generate_enums_from_macros_with_prefixes, "SQLITE_SYNC_");
    array_add(*options.generate_enums_from_macros_with_prefixes, "SQLITE_FCNTL_");
    array_add(*options.generate_enums_from_macros_with_prefixes, "SQLITE_ACCESS_");
    array_add(*options.generate_enums_from_macros_with_prefixes, "SQLITE_SHM_");
    array_add(*options.generate_enums_from_macros_with_prefixes, "SQLITE_CONFIG_");
    array_add(*options.generate_enums_from_macros_with_prefixes, "SQLITE_DBCONFIG_");
    array_add(*options.generate_enums_from_macros_with_prefixes, "SQLITE_TRACE_");
    array_add(*options.generate_enums_from_macros_with_prefixes, "SQLITE_LIMIT_");
    array_add(*options.generate_enums_from_macros_with_prefixes, "SQLITE_PREPARE_");
    array_add(*options.generate_enums_from_macros_with_prefixes, "SQLITE_INDEX_");

    builder := String_Builder.{ allocator = temp };
    append(*builder, "SQLITE_RESULT_CODE :: enum {\n");
    for macro: sqlite_result_code_variants {
        assert(slice(macro, 0, 7) == "SQLITE_");
        variant := slice(macro, 7, macro.count-7);
        print(*builder, "    % :: %;\n", variant, macro);
    }
    append(*builder, "}");
    options.header = builder_to_string(*builder,, temp);

    array_add(*options.source_files, tprint("%/sqlite3.h", directory_of_this_file));

    return generate_bindings(options, output_path);
}

sqlite_result_code_variants :: string.[
    "SQLITE_OK",
    "SQLITE_ERROR",
    "SQLITE_INTERNAL",
    "SQLITE_PERM",
    "SQLITE_ABORT",
    "SQLITE_BUSY",
    "SQLITE_LOCKED",
    "SQLITE_NOMEM",
    "SQLITE_READONLY",
    "SQLITE_INTERRUPT",
    "SQLITE_IOERR",
    "SQLITE_CORRUPT",
    "SQLITE_NOTFOUND",
    "SQLITE_FULL",
    "SQLITE_CANTOPEN",
    "SQLITE_PROTOCOL",
    "SQLITE_EMPTY",
    "SQLITE_SCHEMA",
    "SQLITE_TOOBIG",
    "SQLITE_CONSTRAINT",
    "SQLITE_MISMATCH",
    "SQLITE_MISUSE",
    "SQLITE_NOLFS",
    "SQLITE_AUTH",
    "SQLITE_FORMAT",
    "SQLITE_RANGE",
    "SQLITE_NOTADB",
    "SQLITE_NOTICE",
    "SQLITE_WARNING",
    "SQLITE_ROW",
    "SQLITE_DONE",
    "SQLITE_ERROR_MISSING_COLLSEQ",
    "SQLITE_ERROR_RETRY",
    "SQLITE_ERROR_SNAPSHOT",
    "SQLITE_IOERR_READ",
    "SQLITE_IOERR_SHORT_READ",
    "SQLITE_IOERR_WRITE",
    "SQLITE_IOERR_FSYNC",
    "SQLITE_IOERR_DIR_FSYNC",
    "SQLITE_IOERR_TRUNCATE",
    "SQLITE_IOERR_FSTAT",
    "SQLITE_IOERR_UNLOCK",
    "SQLITE_IOERR_RDLOCK",
    "SQLITE_IOERR_DELETE",
    "SQLITE_IOERR_BLOCKED",
    "SQLITE_IOERR_NOMEM",
    "SQLITE_IOERR_ACCESS",
    "SQLITE_IOERR_CHECKRESERVEDLOCK",
    "SQLITE_IOERR_LOCK",
    "SQLITE_IOERR_CLOSE",
    "SQLITE_IOERR_DIR_CLOSE",
    "SQLITE_IOERR_SHMOPEN",
    "SQLITE_IOERR_SHMSIZE",
    "SQLITE_IOERR_SHMLOCK",
    "SQLITE_IOERR_SHMMAP",
    "SQLITE_IOERR_SEEK",
    "SQLITE_IOERR_DELETE_NOENT",
    "SQLITE_IOERR_MMAP",
    "SQLITE_IOERR_GETTEMPPATH",
    "SQLITE_IOERR_CONVPATH",
    "SQLITE_IOERR_VNODE",
    "SQLITE_IOERR_AUTH",
    "SQLITE_IOERR_BEGIN_ATOMIC",
    "SQLITE_IOERR_COMMIT_ATOMIC",
    "SQLITE_IOERR_ROLLBACK_ATOMIC",
    "SQLITE_IOERR_DATA",
    "SQLITE_IOERR_CORRUPTFS",
    "SQLITE_IOERR_IN_PAGE",
    "SQLITE_LOCKED_SHAREDCACHE",
    "SQLITE_LOCKED_VTAB",
    "SQLITE_BUSY_RECOVERY",
    "SQLITE_BUSY_SNAPSHOT",
    "SQLITE_BUSY_TIMEOUT",
    "SQLITE_CANTOPEN_NOTEMPDIR",
    "SQLITE_CANTOPEN_ISDIR",
    "SQLITE_CANTOPEN_FULLPATH",
    "SQLITE_CANTOPEN_CONVPATH",
    "SQLITE_CANTOPEN_DIRTYWAL",
    "SQLITE_CANTOPEN_SYMLINK",
    "SQLITE_CORRUPT_VTAB",
    "SQLITE_CORRUPT_SEQUENCE",
    "SQLITE_CORRUPT_INDEX",
    "SQLITE_READONLY_RECOVERY",
    "SQLITE_READONLY_CANTLOCK",
    "SQLITE_READONLY_ROLLBACK",
    "SQLITE_READONLY_DBMOVED",
    "SQLITE_READONLY_CANTINIT",
    "SQLITE_READONLY_DIRECTORY",
    "SQLITE_ABORT_ROLLBACK",
    "SQLITE_CONSTRAINT_CHECK",
    "SQLITE_CONSTRAINT_COMMITHOOK",
    "SQLITE_CONSTRAINT_FOREIGNKEY",
    "SQLITE_CONSTRAINT_FUNCTION",
    "SQLITE_CONSTRAINT_NOTNULL",
    "SQLITE_CONSTRAINT_PRIMARYKEY",
    "SQLITE_CONSTRAINT_TRIGGER",
    "SQLITE_CONSTRAINT_UNIQUE",
    "SQLITE_CONSTRAINT_VTAB",
    "SQLITE_CONSTRAINT_ROWID",
    "SQLITE_CONSTRAINT_PINNED",
    "SQLITE_CONSTRAINT_DATATYPE",
    "SQLITE_NOTICE_RECOVER_WAL",
    "SQLITE_NOTICE_RECOVER_ROLLBACK",
    "SQLITE_NOTICE_RBU",
    "SQLITE_WARNING_AUTOINDEX",
    "SQLITE_AUTH_USER",
    "SQLITE_OK_LOAD_PERMANENTLY",
    "SQLITE_OK_SYMLINK",
];

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
