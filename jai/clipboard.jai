main :: () {
    args := get_command_line_arguments();

    command : enum {
        COPY_ARGUMENTS;
        COPY_STDIN;
        PASTE;
    } = ---;

    if args.count < 2 {
        log("usage: % [%]", args[0], join(..enum_lower_kebab_value_names(type_of(command)), separator="|"));
        exit(1);
    }

    ok:, command = enum_from_lower_kebab_string(args[1], type_of(command));
    if !ok {
        log("usage: % [%]", args[0], join(..enum_lower_kebab_value_names(type_of(command)), separator="|"));
        exit(1);
    }

    if command == {
        case .COPY_ARGUMENTS;
            os_clipboard_set_text(join(..array_view(args, 2), separator=" "));
        case .COPY_STDIN;
            data := file_read_until_eof(file_stdin());
            os_clipboard_set_text(data);
        case .PASTE;
            write_string(os_clipboard_get_text());
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

enum_from_lower_kebab_string :: (s: string, $T: Type) -> ok: bool, res: T {
    ti := type_info(T);
    assert(ti.type == .ENUM);

    res : T = ---;
    for ti.names {
        if s == to_lower_kebab(it) {
            res = xx ti.values[it_index];
            return true, res;
        }
    }
    return false, res;
}

enum_lower_kebab_value_names :: (T: Type, allocator := temporary_allocator) -> [..] string {
    ti := cast(*Type_Info_Enum) T;
    assert(ti.type == .ENUM);

    res : [..] string;
    res.allocator = allocator;
    array_reserve(*res, ti.names.count);

    for ti.names {
        array_add(*res, to_lower_kebab(it, allocator));
    }

    return res;
}

to_lower_kebab :: (s: string, allocator := temporary_allocator) -> string {
    t := alloc_string(s.count, allocator);
    for 0..t.count-1 {
        c := to_lower(s[it]);
        if c == #char "_" then c = #char "-";
        t[it] = c;
    }
    return t;
}

#import "Basic";
#import "String";
#import "Clipboard";
#import "File";
