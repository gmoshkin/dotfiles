Http_Server_State :: struct {
    // Fields settable by user:
    listen_port: u16;
    listen_host := "0.0.0.0";

    flags: Server_Flags = .NON_BLOCKING;

    max_listen_queue_size: s32 = 10;
    max_live_connections := -1;

    // Could abstract this away somehow, but don't need it yet, so no need to
    // overcomplicate things.
    epoll_fd: *s32;

    // Fields managed by module:
    listen_fd: s32 = -1;

    temp_connection: Http_Server_Connection;
    connections: [..] *Http_Server_Connection;

    last_error: Error_Info;

    // TODO: report a compiler bug: If this enum is here then type info for it
    // is corrupted when accessing it from the show_state_field command
    // Server_Flags :: enum_flags {
    //     NON_BLOCKING;
    // }
}

Server_Flags :: enum_flags {
    NON_BLOCKING;
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

    input_builder: String_Builder;
    output_builder: String_Builder;

    last_error: Error_Info;
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

    conn.id = xx connections.count;
    conn.peer_port = conn.sockaddr.sin_port;
    conn.peer_host = to_string(conn.peer_host_storage.data);

    new_connection := New(Http_Server_Connection);
    new_connection.* = conn.*;
    array_add(*connections, new_connection);
    conn.peer_fd = -1;

    return true, new_connection;
}

tcp_server_cleanup_connections :: (using server: *Http_Server_State) {
    for connections {
        if it.peer_fd == -1 {
            free(it);
            remove it;
        }
    }
}

tcp_server_handle_epoll_event :: (using server: *Http_Server_State, event: epoll_event) -> ok: bool, handled: bool {
    if event.data.fd == listen_fd {
        ok, connection := accept_tcp_connection(server);
        if !ok return false, false;
        log("new tcp connection: #% from %:%", connection.id, connection.peer_host, connection.peer_port);
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

    builder := String_Builder.{ allocator = temp };
    print(*builder, "new data from connection #%: \"", id);
    print_ascii_or_hex(*builder, builder_to_string(*input_builder,, temp));
    print(*builder, "\"");
    log("%", builder_to_string(*builder,, temp));

    if !has_new_data {
        if !tcp_server_connection_on_hang_up(connection) return false;
    }

    return true;
}

tcp_server_connection_on_output :: (using connection: *Http_Server_Connection) -> bool {
    return true;
}

read_all_available_data :: (fd: s32, builder: *String_Builder) -> (success: bool, has_new_data: bool) {
    has_new_data := false;
    i := 0;
    while true {
        buffer := ensure_contiguous_space_and_return_available_range(builder);
        i += 1;

        read_count := read(fd, buffer.data, xx buffer.count);
        if read_count < 0 {
            code := get_error_value();
            #assert EAGAIN == EWOULDBLOCK;
            if code == EINTR continue;
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

tcp_server_connection_on_hang_up :: (using connection: *Http_Server_Connection) -> bool {
    log("connection #% closed", id);
    if !shutdown_fd_on_epoll(server.epoll_fd, *peer_fd) {
        copy_last_error_info(connection);
        return false;
    }

    return true;
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

#import "Basic";
#import "Error_Info";
#import "Socket";
#import "System";
#import "Linux";
#import "POSIX";
