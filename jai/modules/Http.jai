Http_Server_State :: struct {
    // Fields settable by user:
    listen_port: u16;
    listen_host := "0.0.0.0";

    flags: Server_Flags = .NON_BLOCKING;

    max_listen_queue_size: s32 = 10;
    max_live_connections := -1;

    // Actual HTTP part
    http_request_handler: (request: *Http_Request, data: *void) -> bool;
    http_request_handler_data: *void;

    // Could abstract this away somehow, but don't need it yet, so no need to
    // overcomplicate things.
    epoll_fd: *s32;

    // Fields managed by module:
    listen_fd: s32 = -1;

    temp_connection: Http_Server_Connection;
    connections: [..] *Http_Server_Connection;

    last_error: Error_Info;

    Server_Flags :: enum_flags {
        NON_BLOCKING;
    }
}

Http_Server_Connection :: struct {
    server: *Http_Server_State;

    id: Http_Connection_Id;

    peer_port: u16;
    peer_host: string;
    peer_host_storage: [16] u8;
    peer_fd: s32;

    sockaddr: sockaddr_in;
    sockaddr_len: u32;

    request_counter: s64;

    input_builder: String_Builder;
    input_read_offset: s64;
    parser: Http_Parser;
    temp_request: Http_Request;

    output_builder: String_Builder;
    // This is the offset from which data should be sent out in the first non
    // empty buffer in the output_builder.
    // This semantics is stupid because I'm using String_Builder as output
    // buffer for non blocking IO, which it's not very good at.
    output_write_offset_in_buffer: s64;

    response_headers_builder: String_Builder;
    response_body_builder: String_Builder;
    response_code: u32;

    last_error: Error_Info;

    http_request_handler: (request: *Http_Request, data: *void) -> bool;
    http_request_handler_data: *void;
}

Http_Request :: struct {
    #as using connection: *Http_Server_Connection;

    method: string;
    uri: string;
    parameters: string;
    protocol: string;
    headers: string;
    body: string;
}

Http_Parser :: struct {
    state := State.METHOD;

    uri_offset := -1;
    protocol_offset := -1;
    headers_offset := -1;
    current_header_offset := -1;

    content_length := 0;
    body_offset := -1;

    error_offset := -1;
    error_message := "";

    State :: enum {
        METHOD;
        URI;
        PROTOCOL;
        HEADERS;
        BODY;
    }
}

Http_Connection_Id :: s32;

init_tcp_server :: (using server: *Http_Server_State) -> bool {
    listen_fd = socket(AF_INET, .SOCK_STREAM, .TCP);
    if listen_fd == INVALID_SOCKET {
        listen_fd = -1;
        set_last_error_from_system(prepend="Failed creating a socket: ");
        copy_last_error_info(server);
        return false;
    }

    // FIXME: close socket on error

    option_value: s32 = 1;
    if setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, xx *option_value, size_of(type_of(option_value))) {
        set_last_error_from_system();
        copy_last_error_info(server);
        return false;
    }

    if flags & .NON_BLOCKING {
        if !set_non_blocking(listen_fd) {
            copy_last_error_info(server);
            return false;
        }
    }

    return true;
}

tcp_server_start_listenning :: (using server: *Http_Server_State) -> bool {
    rc := bind(listen_fd, listen_host, listen_port, AF_INET);
    if rc {
        set_last_error_from_system(prepend=tprint("Failed binding on port %: ", listen_port));
        copy_last_error_info(server);
        return false;
    }

    rc = listen(listen_fd, max_listen_queue_size);
    if rc {
        set_last_error_from_system(prepend="Call to `listen` failed: ");
        copy_last_error_info(server);
        return false;
    }

    if server.epoll_fd {
        if !register_fd_on_epoll(server.epoll_fd.*, listen_fd, .EPOLLIN) {
            copy_last_error_info(server);
            return false;
        }
    }

    return true;
}

accept_tcp_connection :: (using server: *Http_Server_State) -> bool, *Http_Server_Connection {
    // Yuck! Should do at least a resizable array with a free list, but the list
    // will have to be remade each time the array is reallocated, so I don't
    // want to be doing this right now. And what if that idea is not even the
    // best one? Let's just do the simple thing then!
    conn := *temp_connection;
    conn.server = server;

    defer if conn.peer_fd != -1 then shutdown_fd_on_epoll(null, *conn.peer_fd);

    conn.sockaddr_len = size_of(type_of(conn.sockaddr));
    conn.peer_fd = accept(listen_fd, xx *conn.sockaddr, *conn.sockaddr_len);
    if conn.peer_fd == -1 {
        set_last_error_from_system("Failed accepting a new connection: ");
        copy_last_error_info(server);
        return false, null;
    }

    if flags & .NON_BLOCKING {
        if !set_non_blocking(conn.peer_fd) {
            copy_last_error_info(server);
            return false, null;
        }
    }

    if !inet_ntop(AF_INET, *conn.sockaddr.sin_addr, conn.peer_host_storage.data, conn.peer_host_storage.count) {
        set_last_error_from_system("Failed accepting a new connection: ");
        copy_last_error_info(server);
        return false, null;
    }

    if epoll_fd {
        if !register_fd_on_epoll(epoll_fd.*, conn.peer_fd, .EPOLLIN) {
            copy_last_error_info(server);
            return false, null;
        }
    }

    tcp_server_cleanup_connections(server);

    init_tcp_server_connection(conn);

    new_connection := New(Http_Server_Connection);
    new_connection.* = conn.*;
    array_add(*connections, new_connection);
    temp_connection.peer_fd = -1;

    return true, new_connection;
}

// XXX: this function sucks, it has a bunch of non-obvious precodintions...
init_tcp_server_connection :: (connection: *Http_Server_Connection) {
    server := connection.server;

    connection.id = xx server.connections.count;
    connection.peer_port = connection.sockaddr.sin_port;
    connection.peer_host = to_string(connection.peer_host_storage.data);

    connection.http_request_handler = server.http_request_handler;
    connection.http_request_handler_data = server.http_request_handler_data;
    connection.request_counter = 0;
    reset(*connection.input_builder);
    reset(*connection.output_builder);
}

tcp_server_cleanup_connections :: (using server: *Http_Server_State) {
    for connections {
        if it.peer_fd == -1 {
            free(it);
            remove it;
        }
    }
}

tcp_server_handle_epoll_event :: (using server: *Http_Server_State, event: epoll_event) -> (ok: bool, handled: bool) {
    if event.data.fd == listen_fd {
        ok, connection := accept_tcp_connection(server);
        if !ok return false, false;
        // log("YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY");
        log("New tcp connection: #% from %:%", connection.id, connection.peer_host, connection.peer_port);
        return true, true;
    }

    for connections {
        if it.peer_fd == -1 { free(it); remove it; continue; }
        if event.data.fd != it.peer_fd continue;

        events := event.events;
        if events & EPOLLIN  { if !tcp_server_connection_on_input(it)   return false, false; events &= ~EPOLLIN; }
        if events & EPOLLOUT { if !tcp_server_connection_on_output(it)  return false, false; events &= ~EPOLLOUT; }
        if events & EPOLLHUP { if !tcp_server_connection_on_hang_up(it) return false, false; events &= ~EPOLLHUP; }
        if events   log("connection #% unhandled events: %", it.id, cast(Epoll_Events) events);

        return true, true;
    }

    return true, false;
}

tcp_server_connection_on_input :: (using connection: *Http_Server_Connection) -> bool {
    ok, has_new_data := read_all_available_data(peer_fd, *input_builder);
    if !ok {
        set_last_error_from_system(prepend=tprint("Failed reading from fd %: ", peer_fd));
        copy_last_error_info(connection);
        return false;
    }

    should_close_connection := false;
    if has_new_data {
        if !http_server_on_input(connection)
            should_close_connection = true;
    } else {
        should_close_connection = true;
    }

    if should_close_connection {
        // epoll doesn't report EPOLLHUP for sockets which closed on the other
        // side for some reason. Maybe you need to write into it first? Idk I didn't check yet...
        // Anyway, read returning 0 always means the fd is closed, however stupid this may sound
        if !tcp_server_connection_on_hang_up(connection) {
            prepend_error_message("failed shutting down connection #%: ", id);
            log_last_error(.WITH_STACK_TRACE);
        }
    }

    return true;
}

http_server_on_input :: (using connection: *Http_Server_Connection) -> bool {
    // builder := String_Builder.{ allocator = temp };
    // print(*builder, "new data from connection #%: \"", id);
    // print_ascii_or_hex(*builder, builder_to_string(*input_builder,, temp), do_reset=false);
    // print(*builder, "\"");
    // log("%", builder_to_string(*builder,, temp));

    while true {
        if parser.state == {
            case .METHOD;
                offset_in_buffer, buffer_offset := find_offset_from_left(*input_builder, #char " ");
                if offset_in_buffer == -1 return true;

                parser.uri_offset = offset_in_buffer + buffer_offset + 1;
                parser.state = .URI;

            case .URI;
                start_offset := parser.uri_offset;
                offset_in_buffer, buffer_offset := find_offset_from_left(*input_builder, #char " ", start_offset);
                if offset_in_buffer == -1 return true;

                parser.protocol_offset = offset_in_buffer + buffer_offset + 1;
                parser.state = .PROTOCOL;

            case .PROTOCOL;
                ok, offset := parse_past_cr_lf(connection, parser.protocol_offset);
                if !ok return false;
                if offset == -1 return true;

                parser.headers_offset = offset;
                parser.current_header_offset = parser.headers_offset;
                parser.state = .HEADERS;

            case .HEADERS;
                start_offset := parser.current_header_offset;
                ok, offset := parse_past_cr_lf(connection, start_offset);
                if !ok return false;
                if offset == -1 return true;

                if offset == parser.current_header_offset + 2 {
                    // CRLF CRLF
                    parser.body_offset = offset;
                    parser.state = .BODY;
                    continue;
                }
                parser.current_header_offset = offset;

                header_buffer: [64] u8;
                count := copy_from_builder(*input_builder, start_offset, header_buffer);
                assert(count > 0, "(%) already know there's data after this", count);

                header := cast(string) array_view(header_buffer, 0, count);
                if !starts_with(header, "Content-Length: ") continue;

                key_length := "Content-Length: ".count;
                value := advance(header, key_length);
                content_length, ok= := string_to_int(value);
                if !ok {
                    parser.error_offset = start_offset + key_length;
                    parser.error_message = "expected a number";
                    return set_last_error("http protocol error: % at %", parser.error_message, parser.error_offset);
                }

                parser.content_length = content_length;

            case .BODY;
                offset_of_last_character_in_body := parser.body_offset + parser.content_length - 1;
                buffer := get_buffer_at_offset(*input_builder, offset_of_last_character_in_body);
                if !buffer return true;

                break;
        }
    }

    request_string_length := parser.body_offset + parser.content_length;

    // String_Builder is sub optimal for input bufferring as it doesn't do a
    // good job of allowing for reuse of already allocated buffers
    input_buffer := builder_to_string(*input_builder, do_reset=true,, temp);

    unparsed_count := input_buffer.count - request_string_length;
    if unparsed_count > 0 {
        append(*input_builder, advance(input_buffer, request_string_length));
    }

    method_length := parser.uri_offset - 1;
    temp_request.method = slice(input_buffer, 0, method_length);

    uri_length := parser.protocol_offset - parser.uri_offset - 1;
    temp_request.uri = slice(input_buffer, parser.uri_offset, uri_length);

    found:, temp_request.uri, temp_request.parameters = split_from_left(temp_request.uri, #char "?");

    protocol_length := parser.headers_offset - parser.protocol_offset - 1;
    temp_request.protocol = slice(input_buffer, parser.protocol_offset, protocol_length);

    headers_length := parser.body_offset - parser.headers_offset - 1;
    temp_request.headers = slice(input_buffer, parser.headers_offset, headers_length);

    body_length := parser.content_length;
    temp_request.body = slice(input_buffer, parser.body_offset, body_length);

    request_line := slice(input_buffer, 0, parser.headers_offset - 2);
    additional_info: string;
    if parser.content_length
        additional_info = tprint(" (content length: %)", parser.content_length);
    #if true
        log("Connection #%1 request #%2: %3%4", connection.id, connection.request_counter, request_line, additional_info);
    else {
        full_request := slice(input_buffer, 0, parser.body_offset + body_length);
        log("Connection #%1 request #%2: %3", connection.id, connection.request_counter, full_request);
    }

    reset_http_parser(*parser);

    temp_request.connection = connection;
    connection.response_code = 0;

    if http_request_handler {
        ok := http_request_handler(*temp_request, http_request_handler_data);
        if connection.response_code == 0 {
            connection.response_code = xx ifx ok then 200 else 500;
        }
    } else {
        connection.response_code = 404;
    }
    prepare_http_response(connection);
    connection.request_counter += 1;
    tcp_server_connection_on_output(connection);

    return true;
}

reset_http_parser :: (parser: *Http_Parser) {
    parser.* = .{};
}

// Return:
// - `(true, offset_of_LF + 1)` if there's a CR LF somewhere in the `input_builder`.
// - `(true, -1)` if there's no CR in the `input_builder` (probably want to read more from the socket).
// - `(false, -1)` if there's a CR but it's not followed by LF (sets `connection.parser.error_*` fields).
parse_past_cr_lf :: (using connection: *Http_Server_Connection, start_offset: s64) -> (no_error: bool, offset: s64) {
    offset_in_buffer, buffer_offset, buffer := find_offset_from_left(*input_builder, #char "\r", start_offset);
    if offset_in_buffer == -1 return true, -1;

    found, lf := buffer_char_at(buffer, offset_in_buffer + 1);
    if !found return true, -1;
    if lf != #char "\n" {
        parser.error_offset = offset_in_buffer + buffer_offset + 1;
        parser.error_message = "expected a '\n' after '\r'";
        return set_last_error("http protocol error: % at %", parser.error_message, parser.error_offset), -1;
    }

    return true, offset_in_buffer + buffer_offset + 2;
}

buffer_char_at :: (buffer: *String_Builder.Buffer, offset: s64) -> bool, u8 {
    ofs := offset;
    buf := buffer;
    while buf {
        if offset < buf.count return true, get_buffer_data(buf)[ofs];

        ofs -= buf.count;
        buf = buf.next;
    }

    return false, 0xff;
}

find_offset_from_left :: (builder: *String_Builder, byte: u8, start_offset := 0) -> (offset_in_buffer: s32, buffer_offset: s32, buffer: *String_Builder.Buffer) {
    buffer, buffer_offset := get_buffer_at_offset(builder, start_offset);
    offset_in_buffer := start_offset - buffer_offset;

    while buffer {
        slice := get_buffer_slice(buffer);

        index := find_index_from_left(slice, byte, offset_in_buffer);
        if index != -1 return xx index, buffer_offset, buffer;

        // Offset in buffer only matters for the first builder,
        // other buffers are by definition farther then start_offset.
        offset_in_buffer = 0;

        buffer_offset += xx buffer.count;
        buffer = buffer.next;
    }

    return -1, -1, null;
}

copy_from_builder :: (builder: *String_Builder, offset: s64, destination: [] u8) -> s64 {
    buffer, buffer_offset := get_buffer_at_offset(builder, offset);
    if !buffer return -1;

    slice := get_buffer_slice(buffer);
    offset_in_buffer := offset - buffer_offset;
    slice = advance(slice, offset_in_buffer);

    copied_count := 0;
    while true {
        count := min(slice.count, destination.count - copied_count);
        memcpy(destination.data + copied_count, slice.data, count);
        copied_count += count;
        if copied_count == destination.count return copied_count;

        buffer = buffer.next;
        if !buffer break;
        slice = get_buffer_slice(buffer);
    }

    return copied_count;
}

get_buffer_at_offset :: (builder: *String_Builder, offset: s64) -> (buffer: *String_Builder.Buffer, buffer_offset: s32) {
    buffer_offset: s32 = 0;
    buffer := get_base_buffer(builder);
    while buffer {
        if buffer_offset + buffer.count > offset return buffer, buffer_offset;

        buffer_offset += xx buffer.count;
        buffer = buffer.next;
    }

    return null, -1;
}

get_buffer_slice :: inline (buffer: *String_Builder.Buffer) -> string {
    data := get_buffer_data(buffer);
    return string.{ data = data, count = buffer.count };
}

read_all_available_data :: (fd: s32, builder: *String_Builder) -> (success: bool, has_new_data: bool) {
    has_new_data := false;
    i := 0;
    while true {
        buffer := my_ensure_contiguous_space_and_return_available_range(builder);
        i += 1;

        read_count := read(fd, buffer.data, xx buffer.count);
        if read_count < 0 {
            code := get_error_value();
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

// Copy-pasted ensure_contiguous_space_and_return_available_range but capacity
// is multiplied by 8 with each new allocated buffer
my_ensure_contiguous_space_and_return_available_range :: (using builder: *String_Builder, minimum_bytes := 1) -> [] u8 {
    if !initialized init_string_builder(builder);

    buffer := get_current_buffer(builder);
    available := buffer.allocated - buffer.count;

    if available < minimum_bytes {

        saved := builder.subsequent_buffer_size;
        defer builder.subsequent_buffer_size = saved;
        next_capacity := buffer.allocated * 8;
        next_capacity = max(next_capacity, minimum_bytes);
        next_capacity = max(next_capacity, saved);
        builder.subsequent_buffer_size = next_capacity;

        success := expand(builder);
        if !success then return .[];
        buffer = get_current_buffer(builder);
    }

    #if BUILDER_ENABLE_ASSERT buffer.ensured_count = buffer.allocated;

    result: [] u8;
    result.data = get_buffer_data(buffer) + buffer.count;
    result.count = buffer.allocated - buffer.count;
    return result;
}

BUILDER_ENABLE_ASSERT :: #run -> bool {
    info := type_info(String_Builder.Buffer);
    for info.members if it.name == "ensured_count" return true;
    return false;
}

tcp_server_connection_on_output :: (using connection: *Http_Server_Connection) -> bool {
    if !write_as_much_output_as_possible(connection) {
        if !tcp_server_connection_on_hang_up(connection) {
            prepend_error_message("failed shutting down connection #%: ", id);
            log_last_error(.WITH_STACK_TRACE);
        }
    }
    return true;
}

write_as_much_output_as_possible :: (using connection: *Http_Server_Connection) -> bool {
    base_buffer := get_base_buffer(*output_builder);

    buffer := base_buffer;
    while buffer && buffer.count == 0  buffer = buffer.next;

    wrote_bytes := 0;
    write_attempts := 0;

    if buffer then assert(output_write_offset_in_buffer < buffer.count);
    while buffer {
        write_attempts += 1;

        remains_to_send := buffer.count - output_write_offset_in_buffer;
        if !remains_to_send break;

        buffer_data := get_buffer_data(buffer);
        rc := write(peer_fd, buffer_data + output_write_offset_in_buffer, xx remains_to_send);
        if rc < 0 {
            code := get_error_value();
            if code == EINTR continue;
            #assert EAGAIN == EWOULDBLOCK;
            if code == EWOULDBLOCK break;

            return set_last_error_from_system();
        }

        // XXX: I don't know if this is actually correct...
        if rc == 0 break;

        assert(rc <= remains_to_send);
        // log("write attempt #%, count: %", write_attempts, rc);
        wrote_bytes += rc;
        output_write_offset_in_buffer += rc;
        if output_write_offset_in_buffer != buffer.count continue;

        // The current buffer is empty, free it (this is lame, I should come up
        // with a buffer scheme that reuses the buffers, maybe just a simple
        // free list?)
        next_buffer := buffer.next;
        if buffer != base_buffer then free(buffer,, output_builder.allocator);
        if buffer == output_builder.current_buffer then output_builder.current_buffer = null;
        base_buffer.next = next_buffer;

        buffer = next_buffer;
        output_write_offset_in_buffer = 0;
    }

    if buffer != base_buffer {
        base_buffer.count = 0;
    }

    if server.epoll_fd {
        new_events := Epoll_Events.EPOLLIN;
        // Still have data to send
        if buffer then new_events |= .EPOLLOUT;
        modify_fd_on_epoll(server.epoll_fd.*, peer_fd, new_events);
    }

    // log("wrote bytes: %", wrote_bytes);
    // log("output_write_offset_in_buffer: %", output_write_offset_in_buffer);
    // log("current_buffer: %", output_builder.current_buffer);

    return true;
}

// TODO: rename
tcp_server_connection_on_hang_up :: (using connection: *Http_Server_Connection) -> bool {
    if !shutdown_fd_on_epoll(server.epoll_fd, *peer_fd) {
        copy_last_error_info(connection);
        return false;
    }
    log("Connection #% closed", id);
    // log("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA");

    return true;
}

get_response_body_builder :: (using connection: *Http_Server_Connection) -> *String_Builder {
    return *connection.response_body_builder;
}

print_response_header :: (using connection: *Http_Server_Connection, name: string, value: Any) {
    print(*response_headers_builder, "%: %\r\n", name, value);
}

prepare_http_response :: (using connection: *Http_Server_Connection) {
    builder := *output_builder;

    code := response_code;
    print(builder, "HTTP/1.1 % %\r\n", code, http_reason_phrase(code));

    content_length := builder_string_length(*response_body_builder);
    log("Connection #% response #%: % % (Content-Length: %)", id, request_counter, code, http_reason_phrase(code), content_length);

    print(builder, "Content-Length: %\r\n", content_length);

    if builder_string_length(*response_headers_builder)
        my_append_and_steal_buffers(builder, *response_headers_builder);
    else
        print(builder, "Content-Type: text/plain\r\n");

    print(builder, "\r\n");
    if content_length {
        my_append_and_steal_buffers(builder, *response_body_builder);
    }
}

http_reason_phrase :: (code: u32) -> string {
    if code == {
        case 100; return "Continue";
        case 101; return "Switching Protocols";
        case 200; return "OK";
        case 201; return "Created";
        case 202; return "Accepted";
        case 203; return "Non-Authoritative Information";
        case 204; return "No Content";
        case 205; return "Reset Content";
        case 206; return "Partial Content";
        case 300; return "Multiple Choices";
        case 301; return "Moved Permanently";
        case 302; return "Found";
        case 303; return "See Other";
        case 304; return "Not Modified";
        case 305; return "Use Proxy";
        case 307; return "Temporary Redirect";
        case 400; return "Bad Request";
        case 401; return "Unauthorized";
        case 402; return "Payment Required";
        case 403; return "Forbidden";
        case 404; return "Not Found";
        case 405; return "Method Not Allowed";
        case 406; return "Not Acceptable";
        case 407; return "Proxy Authentication Required";
        case 408; return "Request Time-out";
        case 409; return "Conflict";
        case 410; return "Gone";
        case 411; return "Length Required";
        case 412; return "Precondition Failed";
        case 413; return "Request Entity Too Large";
        case 414; return "Request-URI Too Large";
        case 415; return "Unsupported Media Type";
        case 416; return "Requested range not satisfiable";
        case 417; return "Expectation Failed";
        case 500; return "Internal Server Error";
        case 501; return "Not Implemented";
        case 502; return "Bad Gateway";
        case 503; return "Service Unavailable";
        case 504; return "Gateway Time-out";
        case 505; return "HTTP Version not supported";
    }

    return "UNKNOWN";
}

register_fd_on_epoll :: (epoll_fd: s32, fd: s32, events := Epoll_Events.EPOLLIN) -> bool {
    event: epoll_event;
    event.events = xx events;
    event.data.fd = fd;
    rc := epoll_ctl(epoll_fd, .ADD, fd, *event);
    if rc {
        return set_last_error_from_system(prepend="epoll_ctl failed: ");
    }

    return true;
}

modify_fd_on_epoll :: (epoll_fd: s32, fd: s32, events: Epoll_Events) -> bool {
    event: epoll_event;
    event.events = xx events;
    event.data.fd = fd;
    rc := epoll_ctl(epoll_fd, .MOD, fd, *event);
    if rc {
        return set_last_error_from_system(prepend="epoll_ctl failed: ");
    }

    return true;
}

shutdown_fd_on_epoll :: (epoll_fd: *s32, fd: *s32) -> bool {
    if epoll_fd {
        if epoll_ctl(epoll_fd.*, .DEL, fd.*, null) return set_last_error_from_system("epoll_ctl failed: ");
    }

    if close(fd.*) return set_last_error_from_system("close failed: ");

    fd.* = -1;
    return true;
}

set_non_blocking :: (fd: s32) -> bool {
    flags := fcntl(fd, F_GETFL);
    flags |= O_NONBLOCK;

    rc := fcntl(fd, F_SETFL, flags);
    if rc == -1 {
        return set_last_error_from_system("Failed making fd non-blocking: ");
    }

    return true;
}

copy_last_error_info :: inline (server: *Http_Server_State) {
    copy_error_info(to=*server.last_error, from=*context.last_error);
}

copy_last_error_info :: inline (connection: *Http_Server_Connection) {
    copy_error_info(to=*connection.last_error, from=*context.last_error);
}

Epoll_Events :: enum_flags {
    EPOLLIN          :: 0x0001;
    EPOLLPRI         :: 0x0002;
    EPOLLOUT         :: 0x0004;
    EPOLLERR         :: 0x0008;
    EPOLLHUP         :: 0x0010;
    EPOLLNVAL        :: 0x0020;
    EPOLLRDNORM      :: 0x0040;
    EPOLLRDBAND      :: 0x0080;
    EPOLLWRNORM      :: 0x0100;
    EPOLLWRBAND      :: 0x0200;
    EPOLLMSG         :: 0x0400;
    EPOLLRDHUP       :: 0x2000;
    EPOLL_URING_WAKE :: 1 << 27;
    EPOLLEXCLUSIVE   :: 1 << 28;
    EPOLLWAKEUP      :: 1 << 29;
    EPOLLONESHOT     :: 1 << 30;
    EPOLLET          :: 1 << 31;
}

#scope_file

print_ascii_or_hex :: (builder: *String_Builder, s: string) {
    for 0..s.count-1 {
        char := s[it];
        if char >= #char " " && char <= #char "~" {
            if char == #char "\\" || char == #char "\""
                append(builder, "\\");
            append(builder, char);
        } else {
            print_to_builder(builder, "\\x%", FormatInt.{ value = char, base = 16, minimum_digits = 2 });
        }
    }
}

// Copy-pasted version of append_and_steal_buffers which doesn't ignore the rest
// of the buffer if first buffer's count is 0.
my_append_and_steal_buffers :: (builder: *String_Builder, steal_from: *String_Builder) {
    buffer := get_base_buffer(steal_from);

    // We need to copy the base buffer because it’s part of the other builder’s struct
    // so we can’t take ownership of it:
    append(builder, get_buffer_data(buffer), buffer.count);

    buffer.count = 0;
    if !buffer.next return;

    assert(builder.allocator.proc == steal_from.allocator.proc);
    assert(builder.allocator.data == steal_from.allocator.data);

    // Take ownership of the rest of the buffer chain:
    our_end := get_current_buffer(builder);
    our_end.next = buffer.next;
    // Reset the victim’s base buffer
    buffer.next = null;
    if steal_from.current_buffer {
        builder.current_buffer = steal_from.current_buffer; // Use the victim’s final buffer as our current buffer.
        steal_from.current_buffer = null; // Reset the victim to use the base buffer again
    }
}

#import "Basic";
#import "String";
#import "Error_Info";
#import "Socket";
#import "System";
#import "Linux";
#import "POSIX";
