read_entire_file_to_builder :: inline (builder: *String_Builder, name: string) -> bool {
    f, success := file_open(name, log_errors = false);
    if !success return false;

    defer file_close(*f);

    return read_entire_file_to_builder(builder, f);
}

read_entire_file_to_builder :: (builder: *String_Builder, f: File) -> bool {
    length, success := my_file_length(f);
    if !success return false;

    if !builder.initialized init_string_builder(builder);

    saved := builder.subsequent_buffer_size;
    defer builder.subsequent_buffer_size = saved;
    if length > builder.subsequent_buffer_size {
        builder.subsequent_buffer_size = length;
    }

    prev_buffer: *String_Builder.Buffer;
    buffer := get_current_buffer(builder);
    if buffer.allocated - buffer.count < length {
        expand(builder);
        prev_buffer = buffer;
        buffer = get_current_buffer(builder);
    }
    buffer_data := get_buffer_data(buffer);
    assert(buffer.allocated >= length);

    total_read_count := 0;
    while total_read_count != length {
        remaining_to_read := length - total_read_count;
        read_count := fread(buffer_data + total_read_count, 1, xx remaining_to_read, f.handle);
        if read_count == 0 break;
        if read_count < 0 {
            if prev_buffer.next == buffer {
                prev_buffer.next == null;
                builder.current_buffer = prev_buffer;
                free(buffer);
            }
            return false;
        }
        total_read_count += xx read_count;
    }
    assert(total_read_count == length);
    buffer.count = length;

    return true;
}

my_read_entire_file :: (name: string, log_errors := true) -> string, bool {
    s: string;
    f, success := file_open(name, log_errors = log_errors);
    if !success return s, false;

    defer file_close(*f);

    s, success = my_read_entire_file(f);

    if log_errors && !success {
        // If we put this error report at a lower level, we could
        // indicate how far into the file the error occurred, etc.
        code, s := System.get_error_value_and_string();
        log_error("Read of '%' failed: code %, '%'.\n", name, code, s);
    }

    return s, success;
}

my_read_entire_file :: (f: File, zero_terminated := false, log_errors := true) -> string, bool {
    length, success := my_file_length(f);

    if !success || length == 0 {
        // Maybe special linux "file"
        builder: String_Builder;
        builder.allocator = context.allocator;

        while true {
            buffer := ensure_contiguous_space_and_return_available_range(*builder);
            read_count := fread(buffer.data, 1, xx buffer.count, f.handle);
            if read_count == 0 break;
            assert(read_count > 0);

            advance_through_ensured_space(*builder, xx read_count);
        }

        return builder_to_string(*builder), true;
    }

    length_with_zero_termination := length + cast(s32) zero_terminated;
    data := cast(*u8) alloc(length_with_zero_termination);
    if data == null {
        if log_errors log_error("failed to allocate % bytes", length_with_zero_termination);
        return "", false;
    }

    // documentation seems to suggest that fread gaurantees size*count is fully read back otherwise error
    rc := fread(data, 1, cast (u64) length, f.handle);
    if rc < 0 {
        free(data);
        return "", false;
    }
    // This assertion fails when you try /sys/class/thermal/thermal_zone*/type
    // assert(rc == xx length);
    assert(rc <= xx length);
    length = xx rc;

    s: string;
    s.count = length;
    s.data  = data;

    if zero_terminated s.data[length] = 0;

    return s, true;
}

// Copy-pasted version of file_length which replaces ftello64 with ftello
my_file_length :: (file: File) -> (length: s64, success: bool) {
    position_current := ftello(file.handle);
    if (position_current == -1) || (position_current == DUMB_LINUX_FAILURE_NUMBER) return 0, false;

    fseek(file.handle, 0, SEEK_END);
    len := ftello(file.handle);
    if (len == -1) || (len == DUMB_LINUX_FAILURE_NUMBER) return 0, false;

    fseek(file.handle, position_current, SEEK_SET);
    return len, true;
}

my_file_length :: (fd: s32) -> (length: s64, success: bool) {
    old_offset := lseek(fd, 0, SEEK_CUR);
    if (old_offset == -1)  return 0, false;

    length := lseek(fd, 0, SEEK_END);
    if (length == -1)  return 0, false;

    lseek(fd, old_offset, SEEK_SET);
    return length, true;
}

file_stdin :: () -> File {
    #if OS == .WINDOWS {
        #import "Windows";

        handle := GetStdHandle(STD_INPUT_HANDLE);
        assert(handle != INVALID_HANDLE_VALUE);

        return File.{ handle };
    } else {
        #import "POSIX";
        libc :: #library,system "libc";
        fdopen :: (fd: s32, mode: *u8) -> *FILE #foreign libc;

        handle := fdopen(STDIN_FILENO, "r");
        assert(handle != null);

        return File.{ handle };
    }
}

#scope_file

#import "Basic";
#import "File";
#import "POSIX";
System :: #import "System";
