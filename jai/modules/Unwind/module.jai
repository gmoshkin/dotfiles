#if OS == .WINDOWS {
    #run assert(false, "Not supported yet");
}

#if CPU != .X64 {
    #run assert(false, "Not supported yet");
}

Init_Context :: () -> (*unw_context_t, *unw_cursor_t) #expand {
    context_size, context_align, cursor_size, cursor_align := get_layout();

    `context_buffer: [4096] u8;
    context_p := Align_To(context_buffer.data, context_align);
    Assert_No_Context(context_buffer.data + context_buffer.count >= context_p + context_size);

    `cursor_buffer: [4096] u8;
    cursor_p := Align_To(cursor_buffer.data, cursor_align);
    Assert_No_Context(cursor_buffer.data + cursor_buffer.count >= cursor_p + cursor_size);

    rc := _Ux86_64_getcontext(context_p);
    if rc != 0 return null, null;

    rc = _Ux86_64_init_local(cursor_p, context_p);
    if rc != 0 return null, null;

    return context_p, cursor_p;
}

error_type :: (error_code: s32) -> string #no_context {
    p := unwind_wrapper_strerror(ifx error_code >= 0 then error_code else -error_code);
    return to_string(p);
}

print_register_dump :: (cursor: *unw_cursor_t, to_standard_error := true) #no_context {
    registers: Registers_Dump;

    rc := unwind_wrapper_get_registers(cursor, *registers);
    if rc != 0 {
        write_string("ERROR: ", to_standard_error);
        write_string(error_type(rc), to_standard_error);
        write_string("\n", to_standard_error);
    }
    // Assert_No_Context(rc == 0);

    Print_Register :: (name: string, value: u64) #expand {
        write_string(name, to_standard_error);
        write_string(": 0x", to_standard_error);
        write_nonnegative_number(value, base=16, to_standard_error);
        write_string("\n", to_standard_error);
    }

    Print_Register("rip", registers.rip);
    Print_Register("rbp", registers.rbp);
    Print_Register("rsp", registers.rsp);
    Print_Register("rax", registers.rax);
    Print_Register("rbx", registers.rbx);
    Print_Register("rcx", registers.rcx);
    Print_Register("rdx", registers.rdx);
    Print_Register("rsi", registers.rsi);
    Print_Register("rdi", registers.rdi);
    Print_Register("r8", registers.r8);
    Print_Register("r9", registers.r9);
    Print_Register("r10", registers.r10);
    Print_Register("r11", registers.r11);
    Print_Register("r12", registers.r12);
    Print_Register("r13", registers.r13);
    Print_Register("r14", registers.r14);
    Print_Register("r15", registers.r15);
}

print_backtrace :: (cursor: *unw_cursor_t, to_standard_error := true) #no_context {
    buffer: [4096] u8;
    i := 1;

    Print :: (s: ..string) #expand { write_strings(..s, to_standard_error); }
    Print :: (n: u64, base := 10) #expand { write_nonnegative_number(n, base, to_standard_error); }
    Print :: (n: s64, base := 10) #expand { write_number(n, base, to_standard_error); }

    while true {
        ip, offset: u64;
        rc := unwind_wrapper_get_frame_info(cursor, *ip, buffer.data, buffer.count, *offset);

        Print("#");
        Print(i, base=10);
        if i < 10 Print(" ");

        if rc == 0 {
            Print(" 0x");
            Print(ip, base=16);
            Print(" in ", to_string(buffer.data), "+");
            Print(offset, base=10);
        } else {
            Print(" ??? (", error_type(rc), ")");
        }

        Print("\n");

        i += 1;

        if unw_step(cursor) <= 0 break;
    }
}

Align_To :: (p: *void, alignment: u64) -> *void #expand {
    mask := alignment - 1;
    return (p + mask) & ~mask;
}

Assert_No_Context :: (condition: bool) #expand {
    if !condition debug_break();
}

Registers_Dump :: struct {
    rip: u64;
    rbp: u64;
    rsp: u64;
    rax: u64;
    rbx: u64;
    rcx: u64;
    rdx: u64;
    rsi: u64;
    rdi: u64;
    r8: u64;
    r9: u64;
    r10: u64;
    r11: u64;
    r12: u64;
    r13: u64;
    r14: u64;
    r15: u64;
};

get_layout :: inline () -> (context_size: u64, context_align: u64, cursor_size: u64, cursor_align: u64) #no_context {
    context_size, context_align, cursor_size, cursor_align: u64;
    unwind_wrapper_get_layout(*context_size, *context_align, *cursor_size, *cursor_align);
    return context_size, context_align, cursor_size, cursor_align;
}

unw_context_t :: void;
unw_cursor_t :: void;

// Note we're not using #foreign with an explicit library here, because jai will
// try to link against it dynamically and fail, but we explicitly don't wanna
// have a dynamic version of this library, because musl... Or is this just a skill issue?

unwind_wrapper_get_layout :: (context_size: *u64, context_align: *u64, cursor_size: *u64, cursor_align: *u64) #foreign;
unwind_wrapper_strerror :: (error_code: s32) -> *u8 #foreign;

unwind_wrapper_get_registers :: (cursor: *unw_cursor_t, registers_dump: *Registers_Dump) -> s32 #foreign;
unwind_wrapper_get_frame_info :: (cursor: *unw_cursor_t, rip: *u64, buffer: *u8, buffer_size: u64, offset: *u64) -> s32 #foreign;

_Ux86_64_getcontext :: (context_: *unw_context_t) -> s32 #foreign;
_Ux86_64_init_local :: (cursor: *unw_cursor_t, context_: *unw_context_t) -> s32 #foreign;
_Ux86_64_step :: (cursor: *unw_cursor_t) -> s32 #foreign;

unw_getcontext :: _Ux86_64_getcontext;
unw_init_local :: _Ux86_64_init_local;
unw_step :: _Ux86_64_step;

#scope_module

eprint :: inline (s: string) #no_context {
    write_string(s, to_standard_error=true);
}

eprint :: inline (n: u64, base := 10) #no_context {
    write_nonnegative_number(n, base, to_standard_error=true);
}

eprint :: inline (n: s64, base := 10) #no_context {
    write_number(n, base, to_standard_error=true);
}

