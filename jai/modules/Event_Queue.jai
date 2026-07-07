#if OS == .WINDOWS {
    #assert false, "Windows is not supported yet";
}

Event_Queue :: struct {
    fd: s32;
    state: enum {
        UNINITIALIZED;
        INITIALIZED;
    };
    specific: Event_Queue_OS_Specific;
    last_error: Error_Info;
}

#if OS == .LINUX {
    Event_Queue_OS_Specific :: struct {
        events: [..] epoll_event;
    }
}

#if OS == .MACOS {
    Event_Queue_OS_Specific :: struct {
        events: [..] Kevent64;
    }
}

Event :: struct {
    fd: s32;
    flags: Event_Flags;
}

Event_Flags :: enum_flags {
    READ;
    WRITE;
    EOF;
}

Event_Operation :: enum {
    ADD;
    REMOVE;
}

event_queue_init :: (queue: *Event_Queue) -> bool {
    if queue.state == .INITIALIZED return true;

    #if OS == .LINUX {
        // Linux requires the argument to be non-zero for backwards compatibility
        queue.fd = epoll_create(1);

        error_prefix :: "epoll_create: ";
    }

    #if OS == .MACOS {
        queue.fd = kqueue();

        error_prefix :: "kqueue: ";
    }

    if queue.fd < 0 {
        set_last_error_from_system();
        copy_error_info(*context.last_error, *queue.last_error);
        return false;
    }

    queue.state = .INITIALIZED;

    return true;
}

event_queue_deinit :: (queue: *Event_Queue) {
    if queue.state != .INITIALIZED return;

    close(queue.fd);
}

event_queue_add :: inline (queue: *Event_Queue, fd: s32, flags: Event_Flags) -> bool {
    log("event_queue_add(%, %)", fd, flags);
    return event_queue_modify(queue, fd, flags, .ADD);
}

event_queue_remove :: inline (queue: *Event_Queue, fd: s32, flags: Event_Flags) -> bool {
    log("event_queue_remove(%, %)", fd, flags);
    return event_queue_modify(queue, fd, flags, .REMOVE);
}

event_queue_modify :: (queue: *Event_Queue, fd: s32, flags: Event_Flags, op: Event_Operation) -> bool {
    #if OS == .LINUX {
        event: epoll_event;
        event.events = event_flags_to_epoll(flags);
        event.data.fd = fd;
        event_op := event_operation_to_epoll(op);

        rc := epoll_ctl(queue.fd, event_op, fd, *event);

        error_prefix :: "epoll_ctl: ";
    }

    #if OS == .MACOS {
        event: Kevent64;
        event.ident = xx fd;
        event.filter = event_flags_to_kqueue(flags);
        event.flags = event_operation_to_kqueue(op);

        rc := kevent64(queue.fd, *event, 1, null, 0, .KEVENT_FLAG_IMMEDIATE, null);

        error_prefix :: "kevent64: ";
    }

    if rc != 0 {
        set_last_error_from_system(error_prefix);
        copy_error_info(*context.last_error, *queue.last_error);
        return false;
    }

    return true;
}

event_queue_wait :: (queue: *Event_Queue, timeout_ms: u64, capacity: s64 = 16) -> bool, [] Event {
    result: [..] Event;

    Return_Error :: (error_prefix: string) #expand {
        code := errno();
        if code == EINTR `return true, .[];

        set_last_error_from_system(error_prefix);
        copy_error_info(*context.last_error, *`queue.last_error);
        `return false, .[];
    }

    #if OS == .LINUX {
        events: [..] epoll_event;
        events.allocator = temp;
        array_reserve(*events, capacity);

        rc := epoll_wait(queue.fd, events.data, xx events.allocated, xx timeout_ms);

        if rc == 0 return true, .[];
        if rc < 0 Return_Error("epoll_wait: ");

        events.count = rc;
        for events {
            flags := event_flags_from_epoll(it.events);
            array_add(*result, .{it.data.fd, flags});
        }
    }

    #if OS == .MACOS {
        events: [..] Kevent64;
        events.allocator = temp;
        array_reserve(*events, capacity);

        timeout := milliseconds_to_timespec(timeout_ms);
        rc := kevent64(queue.fd, null, 0, events.data, xx events.allocated, 0, *timeout);

        if rc == 0 return true, .[];
        if rc < 0 Return_Error("kevent64: ");

        events.count = rc;
        for events {
            event := event_from_kqueue(it);
            array_add(*result, event);
        }
    }

    return true, result;
}

event_flags_from_epoll :: (events: u32) -> Event_Flags {
    result: Event_Flags;
    if events & EPOLLIN  then result |= .READ;
    if events & EPOLLOUT then result |= .WRITE;
    if events & EPOLLHUP then result |= .EOF;
    return result;
}

#if OS == .MACOS
event_from_kqueue :: (event: Kevent64) -> Event {
    result: Event;

    result.fd = xx event.ident;

    if event.flags & .EOF then result.flags |= .EOF;

    if event.filter & .READ  then result.flags |= .READ;
    if event.filter & .WRITE then result.flags |= .WRITE;

    return result;
}

#if OS == .LINUX
event_operation_to_epoll :: (op: Event_Operation) -> Epoll_Ctl {
    if op == {
    case .ADD;    return .ADD;
    case .REMOVE; return .DEL;
    }
    return 0;
}

#if OS == .MACOS
event_operation_to_kqueue :: (op: Event_Operation) -> Kevent_Flags {
    if #complete op == {
    case .ADD;    return .ADD;
    case .REMOVE; return .DELETE;
    }
    return 0;
}

event_flags_to_epoll :: (flags: Event_Flags) -> u32 {
    result: u32;

    if flags & .READ  then result |= EPOLLIN;
    if flags & .WRITE then result |= EPOLLOUT;

    return result;
}

#if OS == .MACOS
event_flags_to_kqueue :: (flags: Event_Flags) -> Kevent_Filter {
    result: Kevent_Filter;

    if flags & .READ  then result |= .READ;
    if flags & .WRITE then result |= .WRITE;

    return result;
}

milliseconds_to_timespec :: inline (milliseconds: u64) -> timespec {
    result: timespec = ---;
    result.tv_sec = xx (milliseconds / 1000);
    result.tv_nsec = xx (milliseconds % 1000) * 1000_000;
    return result;
}

#import "Basic"; // For temporary allocator
#import "POSIX";
#if OS == .LINUX #import "Linux";
#if OS == .MACOS #import "macOS";
#import "Error_Info";
