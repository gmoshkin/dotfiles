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
    stack_trace: [] Stack_Trace_Node;
    error_code_type: *Type_Info = type_info(Error_Code);
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
set_last_error :: (code: $T, format: string, args: .. Any) -> bool {
    info := *context.last_error;
    info.code = xx code;
    info.error_code_type = type_info(T);
    free(info.message);
    info.message = sprint(format, .. args);
    info.stack_trace = get_stack_trace();
    return false;
} @PrintLike

// Returns `false` for convenience so that you can do `return set_last_error(...);`
set_last_error_from_system :: () -> bool {
    code, message := System.get_error_value_and_string();
    return inline set_last_error(code, "%", message);
}

Error_Info_Log_Mode :: enum  {
    ONLY_MESSAGE;
    WITH_SOURCE_LOCATION;
    WITH_STACK_TRACE;
}
log_last_error :: (mode := Error_Info_Log_Mode.WITH_SOURCE_LOCATION) {
    builder: String_Builder;
    builder.allocator = temp;

    info := *context.last_error;
    if mode == {
        case .ONLY_MESSAGE;
            print_message_with_code(*builder, info);
        case .WITH_SOURCE_LOCATION;
            node := info.stack_trace[0];
            print(*builder, "%:%: ", node.info.location.fully_pathed_filename, node.line_number);
            print_message_with_code(*builder, info);
        case .WITH_STACK_TRACE;
            print_message_with_code(*builder, info);
            append(*builder, "\n");
            for node: info.stack_trace {
                if node.info
                    print(*builder, "    %:%: in '%'\n", node.info.location.fully_pathed_filename, node.line_number, node.info.name);
                else
                    print(*builder, "    ?:%: in ?\n", node.line_number);
            }
    }

    log_error("%", builder_to_string(*builder,, temp));
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

get_stack_trace :: (skip := 1) -> [] Stack_Trace_Node {
    result: [..] Stack_Trace_Node;
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

    array_reserve(*result, node_count);
    node = head;
    while node {
        array_add(*result, << node);
        node = node.next;
    }

    // Fix up the 'next' pointers so you can use them normally.
    for * result {
        if it.next   // The one that was already null, at the end, leave it null. Otherwise:
        it.next = it + 1;  // Set 'next' to point at the subsequent element in the array.
    }

    return result;
}

#scope_file

#import "Basic";
