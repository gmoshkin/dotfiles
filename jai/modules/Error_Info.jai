#module_parameters(LOG_ERRORS_ON_CREATION := Error_Info_Log_Mode.NONE) {
    Error_Info_Log_Mode :: enum  {
        NONE; // Only used in module parameters
        ONLY_MESSAGE;
        WITH_SOURCE_LOCATION;
        WITH_STACK_TRACE;
    }
}

Error_Code :: enum {
    OK;
    UNCATEGORIZED;
    WRONG_TYPE;
    UNIMPLEMENTED;
    // TODO: add more codes
    // TODO: add module parameter to splice in more custom codes
    // TODO: add module some way to work with error codes from other modules
}

#add_context last_error: Error_Info;
Error_Info :: struct {
    code: s64;
    message: string;
    stack_trace: [..] Stack_Trace_Node;
    error_code_type: *Type_Info = type_info(Error_Code);
}

copy_error_info :: (from: *Error_Info, to: *Error_Info) {
    to.code = from.code;
    to.error_code_type = from.error_code_type;
    to.message = copy_string(from.message);
    to.stack_trace.count = 0;
    array_add(*to.stack_trace, ..from.stack_trace);
}

prepend_error_message :: (format: string, args: .. Any) {
    builder: String_Builder;
    builder.allocator = temp;
    print(*builder, format, .. args);
    append(*builder, context.last_error.message);
    free(context.last_error.message);
    context.last_error.message = builder_to_string(*builder);
}

// Returns `false` for convenience so that you can do `return set_last_error(...);`
set_last_error :: (format: string, args: .. Any) -> bool {
    return inline set_last_error(Error_Code.UNCATEGORIZED, format, .. args);
}

// Returns `false` for convenience so that you can do `return set_last_error(...);`
set_last_error :: (code: $T, format: string, args: .. Any, skip_stack_frames := 1) -> bool {
    info := *context.last_error;
    info.code = xx code;
    info.error_code_type = type_info(T);
    free(info.message);
    info.message = sprint(format, .. args);
    get_stack_trace(*info.stack_trace, skip=skip_stack_frames);

    #if LOG_ERRORS_ON_CREATION != .NONE {
        log_last_error(LOG_ERRORS_ON_CREATION);
    }

    return false;
} @PrintLike

// Returns `false` for convenience so that you can do `return set_last_error(...);`
set_last_error_from_system :: (prepend: string = "") -> bool {
    code, message := my_get_error_value_and_string();
    return inline set_last_error(code, "%1%2", prepend, message, skip_stack_frames=2);
}

print_last_error :: (builder: *String_Builder, mode := Error_Info_Log_Mode.WITH_SOURCE_LOCATION) {
    info := *context.last_error;
    if #complete mode == {
        case .NONE; #through;
        case .ONLY_MESSAGE;
            print_message_with_code(builder, info);
        case .WITH_SOURCE_LOCATION;
            if info.stack_trace {
                node := info.stack_trace[0];
                print(builder, "%:%: ", node.info.location.fully_pathed_filename, node.line_number);
            }
            print_message_with_code(builder, info);
        case .WITH_STACK_TRACE;
            print_message_with_code(builder, info);
            append(builder, "\n");
            for node: info.stack_trace {
                if node.info
                    print(builder, "    %:%: in '%'\n", node.info.location.fully_pathed_filename, node.line_number, node.info.name);
                else
                    print(builder, "    ?:%: in ?\n", node.line_number);
            }
    }
}

last_error_to_string :: (mode := Error_Info_Log_Mode.WITH_SOURCE_LOCATION) -> string {
    builder: String_Builder;
    print_last_error(*builder, mode);
    return builder_to_string(*builder);
}

log_last_error :: (mode := Error_Info_Log_Mode.WITH_SOURCE_LOCATION, loc := #caller_location) {
    builder: String_Builder;
    builder.allocator = temp;

    print_last_error(*builder, mode);

    log_error("%", builder_to_string(*builder,, temp), loc=loc);
}

log_system_error :: (loc := #caller_location) {
    set_last_error_from_system();
    log_last_error(.ONLY_MESSAGE, loc=loc);
}

print_message_with_code :: inline (builder: *String_Builder, info: *Error_Info) {
    if info.error_code_type.type == .ENUM {
        type := cast(*Type_Info_Enum) info.error_code_type;
        error_type: string;
        for type.values {
            if it != info.code continue;
            error_type := type.names[it_index];
            print(builder, "%: %", error_type, info.message);
            return;
        }
    }
    print(builder, "[#%] %", cast(s64) info.code, info.message);
}

get_stack_trace :: inline (skip := 1) -> [] Stack_Trace_Node {
    result: [..] Stack_Trace_Node;
    return get_stack_trace(*result, skip=skip);
}

get_stack_trace :: (result: *[..] Stack_Trace_Node, skip := 1) {
    result.count = 0;
    head := context.stack_trace;

    skip_copy := skip;
    while skip_copy && head {
        skip_copy -= 1;
        head = head.next;
    }

    node_count := 0;
    node := head;
    while node {
        node_count += 1;
        node = node.next;
    }

    array_reserve(result, node_count);
    node = head;
    while node {
        array_add(result, << node);
        node = node.next;
    }

    // Fix up the 'next' pointers so you can use them normally.
    for * result.* {
        if it.next   // The one that was already null, at the end, leave it null. Otherwise:
        it.next = it + 1;  // Set 'next' to point at the subsequent element in the array.
    }
}

#scope_file

#if OS == .LINUX {
    #import "POSIX";

    my_get_error_string :: (error_code: OS_Error_Code) -> string {
        error_buffer: [1024] u8;

        libc :: #system_library "libc";
        #if OS == .LINUX {
            // GLIBC uses special preprocessor macros to switch to this so-called XSI-compliant implementation.
            // The man pages say that this version of strerror_r is preferred for portable applications,
            // and it works on both modern-ish glibc and musl.
            strerror_r :: (errnum: s32, buf: *u8, buflen: s32) -> s32 #foreign libc "__xpg_strerror_r";
        } else {
            strerror_r :: (errnum: s32, buf: *u8, buflen: s32) -> int #foreign libc;
        }

        result := strerror_r(error_code, error_buffer.data, error_buffer.count);
        if result != 0 {
            // This also sets errno to a new error on Linux; ignore for now?
            return Basic.sprint("OS did not return us a valid string for error %. Returned error was %", error_code, result);
        }

        s := to_string(error_buffer.data);
        return Basic.copy_temporary_string(s);
    }

    my_get_error_value_and_string :: () -> (error_code: OS_Error_Code, description: string) { // 'description' is in temporary storage, or a static string.
        error_code := errno();
        description := my_get_error_string(error_code);
        return error_code, description;
    }
} else {
    my_get_error_string :: System.get_error_string;
    my_get_error_value_and_string :: System.get_error_value_and_string;
}

using Basic :: #import "Basic";
System :: #import "System";
