main :: () {
    #if OS == .WINDOWS {
        Crt :: #system_library "msvcrt";
        _isatty :: (fd: s32) -> s32 #foreign Crt;

        piped_input := !_isatty(0);
    } else {
        #import "POSIX";

        #assert STDIN_FILENO == 0;
        piped_input := !isatty(STDIN_FILENO);
    }

    command : enum {
        NONE;
        COPY_ARGUMENTS;
        COPY_STDIN;
        PASTE;
    }

    if piped_input {
        command = .COPY_STDIN;
    }

    args := get_command_line_arguments();

    if !piped_input && args.count < 2 {
        log("usage: % [copy-arguments | copy-stdin | paste] or pipe something on stdin", args[0]);
        exit(1);
    }

    if args.count > 1 if args[1] == {
        case "copy-arguments"; command = .COPY_ARGUMENTS;
        case "copy-stdin";     command = .COPY_STDIN;
        case "paste";          command = .PASTE;
        case;
            log("usage: % [copy-arguments | copy-stdin | paste] or pipe something on stdin", args[0]);
            exit(1);
    }

    if command == {
        case .COPY_ARGUMENTS;
            os_clipboard_set_text(join(..array_view(args, 2), separator=" "));
        case .COPY_STDIN;
            data := file_read_until_eof(file_stdin());
            os_clipboard_set_text(data);
        case .PASTE;
            text := os_clipboard_get_text();
            text = replace(text, "\r\n", "\n");
            for 0..text.count-1 {
                if text[it] == #char "\r" then text[it] = #char "\n";
            }
            write_string(text);
    }
}

file_read_until_eof :: (f: File) -> string {
    sb: String_Builder;
    while true {
        buf := ensure_contiguous_space_and_return_available_range(*sb);
        ok, bytes_read := file_read(f, buf.data, buf.count);
        advance_through_ensured_space(*sb, bytes_read);
        if !ok || bytes_read != buf.count {
            return builder_to_string(*sb);
        }
    }
    return "<unreachable>";
}

file_stdin :: () -> File {
    #if OS == .WINDOWS {
        #import "Windows";

        handle := GetStdHandle(STD_INPUT_HANDLE);
        assert(handle != INVALID_HANDLE_VALUE);

        return File.{ handle };
    } else {
        #import "POSIX";
        libc :: #system_library "libc";
        fdopen :: (fd: s32, mode: *u8) -> *FILE #foreign libc;

        handle := fdopen(STDIN_FILENO, "r");
        assert(handle != null);

        return File.{ handle };
    }
}

#import "Basic";
#import "String";
#import "Clipboard";
#import "File";
