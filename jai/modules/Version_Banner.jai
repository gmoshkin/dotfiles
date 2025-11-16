//
// version banner
//

show_version_banner :: () {
    builder: String_Builder;
    builder.allocator = temp;
    show_version_banner(*builder);
    write_builder(*builder,, temp);
}

// Somebody must #add_context EXECUTABLE_NAME & #add_context build_info with
// compatible info.
show_version_banner :: (builder: *String_Builder) {
    using context.build_info;
    MONTHS :: string.["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    build_month := MONTHS[BUILD_DATE_MONTH];
    print(builder, "% % %, built on % % %\n", context.EXECUTABLE_NAME, DEBUG_OR_RELEASE, DYNAMIC_OR_STATIC, BUILD_DATE_DAY + 1, build_month, BUILD_DATE_YEAR);
    git_hash := GIT_HASH;
    git_hash.count = 8;
    print(builder, "git commit: % (%)\n", git_hash, GIT_LAST_COMMIT_MESSAGE);
    print(builder, "compiler version: %\n", COMPILER_VERSION);
}

// This is quick and dirty way to check for the parameter value, may not work in all cases.
command_line_arguments_contain_version_flag :: (arguments: [] string, values := string.["-v", "--version"]) -> bool {
    for arg: arguments {
        for values if it == arg {
            return true;
        }
    }

    return false;
}

maybe_show_version_banner_and_exit :: (values := string.["-v", "--version"], exit_code: s32 = 0) {
    args := get_command_line_arguments();
    if command_line_arguments_contain_version_flag(args) {
        show_version_banner();
        exit(exit_code);
    }
}

#import "Basic";
