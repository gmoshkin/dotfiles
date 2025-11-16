main :: () {
    args := get_command_line_arguments();

    to_dos := false;
    remove_line_breaks := false;
    add_quotes: enum { IF_NEEDED; ALWAYS; NEVER; } = .IF_NEEDED;

    cursor := 1;
    while cursor < args.count {
        arg := args[cursor];
        if arg == "-to-dos" {
            to_dos = true;
        } else if arg == "-to-wsl" {
            to_dos = false;
        } else if arg == "-remove-line-breaks" {
            remove_line_breaks = true;
        } else if arg == "-dont-remove-line-breaks" {
            remove_line_breaks = false;
        } else if arg == "-add-quotes" {
            add_quotes = .ALWAYS;
        } else if arg == "-dont-add-quotes" {
            add_quotes = .NEVER;
        } else if arg == "-maybe-add-quotes" {
            add_quotes = .IF_NEEDED;
        } else if arg == "-v" || arg == "--version" {
            show_version_banner();
            return;
        } else if starts_with(arg, "-") {
            known_options :: string.[
                "-to-dos", "-to-wsl", "-remove-line-breaks", "-dont-remove-line-breaks", "-add-quotes", "-dont-add-quotes", "-maybe-add-quotes",
            ];
            print("unknown option '%', expected one of %\n", arg, known_options, to_standard_error=true);
            exit(1);
        } else {
            break;
        }

        cursor += 1;
    }

    value: string;
    if cursor < args.count {
        value = args[cursor];
    } else if !isatty(STDIN_FILENO) {
        builder: String_Builder;
        ok := read_all_available_data(STDIN_FILENO, *builder);
        if !ok {
            code, message := get_error_value_and_string();
            log_error("failed reading stdandard input: [%] %\n", code, message);
            exit(1);
        }
        value = builder_to_string(*builder);
    } else {
        print("please provide a value as an argument or piped into standard input\n", to_standard_error=true);
        exit(1);
    }

    result: string;
    if to_dos {
        result = convert_wsl_path_to_windows(value);
    } else {
        result = convert_windows_path_to_wsl(value);
    }

    if remove_line_breaks {
        result = replace(result, "\n", "");
    }

    // 1 trailing newline is always removed
    if result && result[result.count - 1] == #char "\n" && !contains(slice(result, 0, result.count - 1), #char "\n") {
        result = slice(result, 0, result.count - 1);
    }

    need_quotes := false;
    if add_quotes == {
    case .IF_NEEDED;
        need_quotes = contains(result, #char " ") && isatty(STDOUT_FILENO);
    case .ALWAYS;
        need_quotes = true;
    case .NEVER;
        need_quotes = false;
    }
    if need_quotes {
        print("\"%\"\n", result);
    } else {
        print("%\n", result);
    }
}

convert_windows_path_to_wsl :: (path: string) -> string {
    builder: String_Builder;
    builder.allocator = temp;

    tail := path;
    if tail.count > 1 && tail[1] == #char ":" {
        append(*builder, "/mnt/");
        append(*builder, to_lower(tail[0]));

        tail = advance(tail, 2);
    }

    while tail {
        found:, head:, tail = split_from_left(tail, #char "\\");
        append(*builder, head);
        if found then append(*builder, #char "/");
    }

    return builder_to_string(*builder);
}

convert_wsl_path_to_windows :: (path: string) -> string {
    builder: String_Builder;
    builder.allocator = temp;

    tail := path;
    PREFIX :: "/mnt/";
    if starts_with(tail, PREFIX) && tail.count > PREFIX.count {
        append(*builder, to_upper(tail[PREFIX.count]));
        append(*builder, #char ":");

        tail = advance(tail, PREFIX.count + 1);
    }

    while tail {
        found:, head:, tail = split_from_left(tail, #char "/");
        append(*builder, head);
        if found then append(*builder, #char "\\");
    }

    return builder_to_string(*builder);
}

is_capital_letter :: inline (c: u8) -> bool {
    return c >= #char "A" && c <= #char "Z";
}

get_error_value_and_string :: () -> u32, string {
    code := System.get_error_value();
    message := to_string(strerror(xx code));
    return xx code, copy_temporary_string(message);
}

read_all_available_data :: (fd: s32, builder: *String_Builder) -> (success: bool, has_new_data: bool) {
    has_new_data := false;
    i := 0;
    while true {
        buffer := ensure_contiguous_space_and_return_available_range(builder);
        i += 1;

        read_count := read(fd, buffer.data, xx buffer.count);
        if read_count < 0 {
            code := System.get_error_value();
            if code == EINTR continue;
            #assert EAGAIN == EWOULDBLOCK;
            if code == EWOULDBLOCK return true, has_new_data;

            return false, has_new_data;
        }

        if read_count > 0 {
            advance_through_ensured_space(builder, xx read_count);
            has_new_data = true;

            continue;
        }

        return true, has_new_data;
    }
}

strerror :: (code: u32) -> *u8 #foreign libc;

libc :: #system_library "libc";

#import "Basic";
#import "POSIX";
#import "String";
System :: #import "System";
#import "My_Util";
#import "Version_Banner";
