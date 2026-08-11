//
// Talking to a running neovim over its msgpack-rpc unix socket.
//
// Every request is synchronous: we write `[0, msgid, method, params]` and read
// until `[1, msgid, error, result]` comes back, or until the timeout expires.
//
// The timeout is the whole point of doing this by hand. A neovim that is busy
// -- mid-keystroke with a pending count or operator, or sitting in a picker --
// does not service its rpc channel, and a blocking read would hang forever.
//
// Everything here reports failure the Error_Info way: `false`, with the details
// left in `context.last_error`, so `log_last_error()` or `last_error_to_string()`
// gets you the message and where it came from.
//

//
// The code in `context.last_error`, for callers that want to decide rather than
// just report. Which nvim to try next is exactly that sort of decision: TIMED_OUT
// means someone else's neovim was busy, API_ERROR means ours answered and said no.
//
Nvim_Error :: enum {
    OK;
    SOCKET_PATH_TOO_LONG; // sockaddr_un has room for 104 bytes on macos, 108 on linux
    NOT_CONNECTED;
    DISCONNECTED;         // neovim exited, or closed the channel on us
    TIMED_OUT;            // busy neovim; nothing we asked for happened
    API_ERROR;            // neovim answered, and the answer was an error
    PROTOCOL_ERROR;       // neovim said something we don't know how to read
}

//
// The last error's code, when it is one of ours. Failures that came from the
// system -- a refused connect, a broken pipe -- carry an errno under a different
// code type, and the two overlap: errno 5 is EIO, Nvim_Error 5 is TIMED_OUT. So
// switch on the code only when this says you may.
//
nvim_last_error :: () -> (code: Nvim_Error, is_nvim_error: bool) {
    if context.last_error.error_code_type != type_info(Nvim_Error)  return .OK, false;
    return cast(Nvim_Error) context.last_error.code, true;
}

Nvim :: struct {
    fd: s32 = -1;

    socket_path: string;

    // msgpack-rpc lets a peer have several requests in flight, distinguished by
    // this. We only ever have one, but it still has to match on the way back.
    next_msgid: u32 = 1;

    // The request being built, then written to the socket out of these very
    // buffers. Lives here so that it is reused between requests, and so that
    // whoever encodes the parameters appends to the same builder that already
    // holds the envelope.
    request: String_Builder;

    // Set by `nvim_request_begin`, consumed by `nvim_request_send`. The method
    // name is only borrowed, for error messages, and only until the send.
    pending_msgid:  u32;
    pending_method: string;

    // Holds the bytes read so far for the response currently being awaited.
    // Reused between requests, which is why `result` is only valid until the
    // next call.
    read_buffer: [..] u8;

    timeout: Apollo_Time;
}

DEFAULT_TIMEOUT_SECONDS :: 5;

nvim_connect :: (socket_path: string, timeout_seconds := DEFAULT_TIMEOUT_SECONDS) -> (nvim: Nvim, ok: bool) {
    nvim: Nvim;
    nvim.socket_path = copy_string(socket_path);
    nvim.timeout = seconds_to_apollo(timeout_seconds);

    address, ok := make_unix_address(socket_path);
    if !ok {
        set_last_error(Nvim_Error.SOCKET_PATH_TOO_LONG, "socket path is longer than the % bytes sockaddr_un has room for: '%'",
                       address.sun_path.count, socket_path);
        return nvim, false;
    }

    nvim.fd = socket(AF_UNIX, .STREAM, xx 0);
    if nvim.fd < 0 {
        set_last_error_from_system("socket(AF_UNIX) failed: ");
        return nvim, false;
    }

    if connect(nvim.fd, xx *address, size_of(type_of(address))) < 0 {
        set_last_error_from_system(tprint("connect('%') failed: ", socket_path));
        nvim_disconnect(*nvim);
        return nvim, false;
    }

    // If neovim exits between here and our write, we want EPIPE back, not a
    // signal that takes the whole process down. Linux says this per-send with
    // MSG_NOSIGNAL instead, see SEND_FLAGS.
    #if OS == .MACOS {
        on := 1;
        setsockopt(nvim.fd, SOL_SOCKET, SO_NOSIGPIPE, *on, size_of(type_of(on)));
    }

    // So that a busy neovim costs us `timeout_seconds`, not the whole session.
    // The read loop treats a timed-out `recv` as "give up", not "retry".
    timeout: timeval;
    timeout.tv_sec = xx to_seconds(nvim.timeout);
    if setsockopt(nvim.fd, SOL_SOCKET, SO_RCVTIMEO, *timeout, size_of(type_of(timeout))) < 0 {
        set_last_error_from_system("setsockopt(SO_RCVTIMEO) failed: ");
        nvim_disconnect(*nvim);
        return nvim, false;
    }

    return nvim, true;
}

nvim_disconnect :: (nvim: *Nvim) {
    if nvim.fd >= 0 {
        close(nvim.fd);
        nvim.fd = -1;
    }
    array_reset(*nvim.read_buffer);
    reset(*nvim.request);
    free(nvim.socket_path);
    nvim.socket_path = "";
}

//
// Calls a remote procedure whose arguments are all things `Any` can carry:
// integers, strings, bools and arrays of those. Anything shaped like a map --
// `nvim_cmd`'s argument, for one -- has to go through begin/send below, because
// msgpack's `Any` encoder has no struct case.
//
nvim_request :: (nvim: *Nvim, method: string, args: .. Any) -> (ok: bool, result: string) {
    request := nvim_request_begin(nvim, method, args.count);
    for args  mp_encode(request, it);

    ok, result := nvim_request_send(nvim);
    return ok, result;
}

//
// Starts the envelope -- `[0, msgid, method, params]` -- and hands back the
// builder holding it, so the caller can encode the `param_count` parameters
// straight into the buffers that will be written to the socket. Finish with
// `nvim_request_send`.
//
nvim_request_begin :: (nvim: *Nvim, method: string, param_count: s64) -> *String_Builder {
    reset(*nvim.request);

    nvim.pending_msgid  = nvim.next_msgid;
    nvim.pending_method = method;
    nvim.next_msgid += 1;

    mp_encode_array_count(*nvim.request, 4);
    mp_encode(*nvim.request, MSG_TYPE_REQUEST);
    mp_encode(*nvim.request, cast(u64) nvim.pending_msgid);
    mp_encode(*nvim.request, method);
    mp_encode_array_count(*nvim.request, param_count);

    return *nvim.request;
}

//
// The returned `result` is raw msgpack pointing into `nvim.read_buffer`, so it
// stays valid only until the next request on this connection. Decode it (or
// copy it) before calling again.
//
nvim_request_send :: (nvim: *Nvim) -> (ok: bool, result: string) {
    if nvim.fd < 0 {
        set_last_error(Nvim_Error.NOT_CONNECTED, "not connected");
        return false, "";
    }

    if !write_builder(nvim.fd, *nvim.request) {
        prepend_error_message("sending % failed: ", nvim.pending_method);
        return false, "";
    }

    ok, result := read_response(nvim, nvim.pending_method, nvim.pending_msgid);
    return ok, result;
}

//
// The calls nvim-open actually makes, so that opening a file doesn't require
// knowing anything about msgpack.
//

//
// Opens a file, taking the path as structured data rather than pasting it into
// an ex command, so nothing has to be escaped -- no `fnameescape`, no worrying
// about spaces, `%`, `#` or `|` in the path.
//
Nvim_Open_Command :: enum {
    EDIT;
    SPLIT;
    VSPLIT;
    TABEDIT;
}

nvim_edit_file :: (nvim: *Nvim, path: string, how := Nvim_Open_Command.EDIT) -> bool {
    command: string;
    if how == {
    case .EDIT;    command = "edit";
    case .SPLIT;   command = "split";
    case .VSPLIT;  command = "vsplit";
    case .TABEDIT; command = "tabedit";
    }

    Cmd :: struct @EncodeAsMap {
        cmd:  string;
        args: [] string;
    }

    request := nvim_request_begin(nvim, "nvim_cmd", 2);
    mp_encode(request, Cmd.{ cmd = command, args = .[path] });
    mp_encode_map_count(request, 0); // no opts

    ok := nvim_request_send(nvim);
    return ok;
}

//
// `line` is 1-based and `column` is 1-based, like the numbers in a compiler
// diagnostic; the api's 0-based column is dealt with here.
//
nvim_set_cursor :: (nvim: *Nvim, line: s64, column: s64) -> bool {
    position := s64.[max(line, 1), max(column, 1) - 1];

    ok := nvim_request(nvim, "nvim_win_set_cursor", 0, position);
    return ok;
}

nvim_command :: (nvim: *Nvim, command: string) -> bool {
    ok := nvim_request(nvim, "nvim_command", command);
    return ok;
}

//
// Evaluates a vimscript expression that produces a string, e.g.
// `expand('%:p') . ':' . line('.')` to find out what the user is looking at.
//
nvim_eval_string :: (nvim: *Nvim, expression: string) -> (ok: bool, value: string) {
    ok, result := nvim_request(nvim, "nvim_eval", expression);
    if !ok  return false, "";

    ok_string, value := mp_decode(*result, string);
    if !ok_string {
        set_last_error(Nvim_Error.PROTOCOL_ERROR, "expected % to produce a string", expression);
        return false, "";
    }

    // `result` points into the read buffer, which the next request reuses
    return true, copy_string(value);
}

#scope_module

MSG_TYPE_REQUEST      :: 0;
MSG_TYPE_RESPONSE     :: 1;
MSG_TYPE_NOTIFICATION :: 2;

read_response :: (nvim: *Nvim, method: string, msgid: u32) -> (ok: bool, result: string) {
    nvim.read_buffer.count = 0;

    start := current_time_monotonic();

    while true {
        //
        // Try to decode what we have. Since msgpack carries no length prefix,
        // attempting the decode *is* how we find out whether the whole response
        // has arrived -- which is why every decoder has to survive a partial
        // buffer. A failure here means "not yet", so we go read some more.
        //
        response: string;
        response.data = nvim.read_buffer.data;
        response.count = nvim.read_buffer.count;

        ok, result, complete := parse_response(*response, msgid);
        if complete  return ok, result;

        if current_time_monotonic() - start > nvim.timeout {
            set_last_error(Nvim_Error.TIMED_OUT, "% did not respond within % seconds; it is busy -- sitting at a prompt, or mid-keystroke -- and does not service its rpc channel until that finishes. Nothing was changed.",
                           method, to_seconds(nvim.timeout));
            return false, "";
        }

        if !read_more(nvim)  return false, "";
    }

    return false, "";
}

//
// Returns `complete=false` when the buffer holds only part of a message, which
// is the signal to read more. Note that a *malformed* message is indistinguisha-
// ble from an incomplete one here, so garbage on the socket shows up as a
// timeout rather than a parse error. In practice the peer is neovim, so the
// bytes are either right or absent.
//
parse_response :: (response: *string, msgid: u32) -> (ok: bool, result: string, complete: bool) {
    count := mp_decode_array_count(response);
    if count == -1  return false, "", false;

    if count != 4 {
        set_last_error(Nvim_Error.PROTOCOL_ERROR, "expected a 4 element response, got % elements", count);
        return false, "", true;
    }

    ok_type, msg_type := mp_decode(response, s64);
    if !ok_type  return false, "", false;

    if msg_type != MSG_TYPE_RESPONSE {
        // A notification would have to be skipped over to resynchronise the
        // stream, and we never ask for any, so treat it as fatal instead of
        // silently losing our place.
        set_last_error(Nvim_Error.PROTOCOL_ERROR, "expected a response (type %), got a message of type %", MSG_TYPE_RESPONSE, msg_type);
        return false, "", true;
    }

    ok_msgid, got_msgid := mp_decode(response, u64);
    if !ok_msgid  return false, "", false;

    if got_msgid != msgid {
        set_last_error(Nvim_Error.PROTOCOL_ERROR, "expected a response to request #%, got one to #%", msgid, got_msgid);
        return false, "", true;
    }

    //
    // The error slot is either nil or `[code, message]`
    //
    if !mp_decode_null(response) {
        error_count := mp_decode_array_count(response);
        if error_count == -1  return false, "", false;

        if error_count != 2 {
            set_last_error(Nvim_Error.PROTOCOL_ERROR, "expected a 2 element error, got % elements", error_count);
            return false, "", true;
        }

        ok_code, code := mp_decode(response, s64);
        if !ok_code  return false, "", false;

        ok_message, message := mp_decode(response, string);
        if !ok_message  return false, "", false;

        // The code is neovim's own -- see `:help api-error-types` -- so it stays
        // in the message rather than pretending to be one of ours
        set_last_error(Nvim_Error.API_ERROR, "%: %", code, message);
        return false, "", true;
    }

    //
    // Whatever is left is the result. We don't know its type, so hand back the
    // raw msgpack and let the caller decode what it expects -- but we do have to
    // walk it to be sure all of it arrived.
    //
    result := response.*;
    if !mp_skip_value(response)  return false, "", false;

    result.count -= response.count;
    return true, result, true;
}

read_more :: (nvim: *Nvim) -> bool {
    MIN_CHUNK :: 4096;

    used := nvim.read_buffer.count;

    //
    // Grow geometrically instead of a chunk at a time, so a large response
    // doesn't cost a realloc-and-copy per 4k -- the same trick
    // `my_ensure_contiguous_space_and_return_available_range` plays in
    // My_File.jai, except that this buffer has to stay contiguous: msgpack
    // carries no length prefix, so we re-decode after every read, and a value
    // straddling two buffers would have to be flattened first.
    //
    if nvim.read_buffer.allocated - used < MIN_CHUNK {
        array_reserve(*nvim.read_buffer, max(used + MIN_CHUNK, nvim.read_buffer.allocated * 2));
    }

    space := nvim.read_buffer.allocated - used;
    received := recv(nvim.fd, nvim.read_buffer.data + used, xx space, xx 0);

    if received < 0 {
        nvim.read_buffer.count = used;

        code := errno();
        if code == EAGAIN || code == EWOULDBLOCK {
            // SO_RCVTIMEO expired. The caller's own deadline check produces the
            // nicer message, so just report no progress.
            return true;
        }
        if code == EINTR  return true;

        return set_last_error_from_system("recv failed: ");
    }

    if received == 0 {
        nvim.read_buffer.count = used;
        return set_last_error(Nvim_Error.DISCONNECTED, "neovim closed the connection");
    }

    nvim.read_buffer.count = used + received;
    return true;
}

//
// Sends what the builder holds straight out of its own buffers, so the request
// is never flattened into a string first. The walk is the one from
// `write_as_much_output_as_possible` in Http.jai, without the non-blocking part:
// this socket blocks, so a short write only means "go round again", and we are
// done when the chain runs out.
//
write_builder :: (fd: s32, builder: *String_Builder) -> bool {
    buffer := get_base_buffer(builder);
    while buffer {
        data := get_buffer_data(buffer);

        sent := 0;
        while sent < buffer.count {
            n := send(fd, data + sent, xx (buffer.count - sent), SEND_FLAGS);
            if n < 0 {
                code := errno();
                if code == EINTR  continue;
                return set_last_error_from_system();
            }
            if n == 0  return set_last_error(Nvim_Error.DISCONNECTED, "neovim closed the connection");

            sent += n;
        }

        buffer = buffer.next;
    }
    return true;
}

// See the SO_NOSIGPIPE in nvim_connect for the other half of this
#if OS == .LINUX  SEND_FLAGS :: MSG.NOSIGNAL;
else              SEND_FLAGS :: cast(MSG) 0;

//
// `sockaddr_un` isn't in modules/Socket, and its shape differs between the two
// platforms: the BSDs put a length byte in front of an 8-bit family, linux has
// a 16-bit family and no length.
//
#if OS == .MACOS {
    sockaddr_un :: struct {
        sun_len:    u8;
        sun_family: u8;
        sun_path:   [104] u8;
    }
} else {
    sockaddr_un :: struct {
        sun_family: u16;
        sun_path:   [108] u8;
    }
}

make_unix_address :: (socket_path: string) -> address: sockaddr_un, ok: bool {
    address: sockaddr_un;
    address.sun_family = AF_UNIX;
    #if OS == .MACOS  address.sun_len = size_of(sockaddr_un);

    // Leave room for the terminating nul-byte
    if socket_path.count >= address.sun_path.count  return address, false;

    memcpy(address.sun_path.data, socket_path.data, socket_path.count);
    return address, true;
}

#import "Basic";
#import "POSIX";
#import "Socket";
#import "Error_Info";
#import "Msgpack";
