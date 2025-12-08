init :: (handler: Signal_Handler = signal_handler) {
    // Install our signal handler.
    sa: sigaction_t;
    sa.sa_sigaction = handler;

    sigemptyset(*sa.sa_mask);

    sa.sa_flags = .RESTART | .ONSTACK | .SIGINFO;

    sigaction(.SIGSEGV, *sa, null);
    sigaction(.SIGTRAP, *sa, null);
    sigaction(.SIGFPE,  *sa, null);
    sigaction(.SIGBUS,  *sa, null);
    sigaction(.SIGILL,  *sa, null);
}

signal_handler :: (sig: Signal, info: *siginfo_t, secret: *void) #c_call {
    eprint("\e[31m");

    registers := get_register_dump(secret);

    if sig == SIGSEGV {
        // (Daniel) - August 4, 2023
        // Daniel: Documentation for SEGV_ACCERR
        // https://elixir.bootlin.com/linux/v5.15.8/source/include/uapi/asm-generic/siginfo.h#L231
        // https://www.man7.org/linux/man-pages/man2/sigaction.2.html

        // Linux & macOS:
        SEGV_MAPERR: s32 : 1; // attempt to access an address that doesn't map to anything
        SEGV_ACCERR: s32 : 2; // tried to access an address that you don't have permission to access

        // Linux only:
        SEGV_BNDERR: s32 : 3; // failed address bound checks
        SEGV_PKUERR: s32 : 4; // failed protection key checks

        eprint("Segmentation fault.\n");

        si_code := "";

        if info.si_code == SEGV_MAPERR {
            si_code = "SEGV_MAPERR";
        } else if info.si_code == SEGV_ACCERR {
            si_code = "SEGV_ACCERR";
        } else if info.si_code == SEGV_BNDERR {
            si_code = "SEGV_BNDERR";
        } else if info.si_code == SEGV_PKUERR {
            si_code = "SEGV_PKUERR";
        }

        if si_code {
            eprint("  si_code: ", si_code, "\n");
        } else {
            eprint("  si_code: 0x");
            eprint(info.si_code);
            eprint("\n");
        }

        eprint("  Dereference of 0x");
        eprint(cast(u64) info.si_addr, base=16);
        eprint(", from address 0x");
        eprint(registers.rip, base=16);
        eprint("\n\n");
    } else if sig == SIGTRAP {
        eprint("Breakpoint hit.\n");
    } else if sig == SIGFPE {
        FPE_INTDIV: s32 : 1; // integer divide by zero
        FPE_INTOVF: s32 : 2; // integer overflow
        FPE_FLTDIV: s32 : 3; // floating point divide by zero
        FPE_FLTOVF: s32 : 4; // floating point overflow
        FPE_FLTUND: s32 : 5; // floating point underflow
        FPE_FLTRES: s32 : 6; // floating point inexact result
        FPE_FLTINV: s32 : 7; // floating point invalid operation
        FPE_FLTSUB: s32 : 8; // subscript out of range

        if info.si_code == {
        case FPE_INTDIV; eprint("SIGFPE: The program crashed because of an integer division by zero error.\n");
        case FPE_INTOVF; eprint("SIGFPE: The program crashed because of an integer arithmetic overflow error.\n");
        case FPE_FLTDIV; eprint("SIGFPE: The program crashed because of a floating point division by zero error.\n");
        case FPE_FLTOVF; eprint("SIGFPE: The program crashed because of a floating point overflow error.\n");
        case FPE_FLTUND; eprint("SIGFPE: The program crashed because of a floating point underflow error.\n");
        case FPE_FLTRES; eprint("SIGFPE: The program crashed because of an inexact floating point result error.\n");
        case FPE_FLTINV; eprint("SIGFPE: The program crashed because of an invalid floating point result error.\n");
        case FPE_FLTSUB; eprint("SIGFPE: The program crashed because of a subscript out of range error.\n");
        }
    } else if sig == SIGILL {
        ILL_ILLOPC: s32 : 1; // Illegal opcode.
        ILL_ILLOPN: s32 : 2; // illegal operand
        ILL_ILLADR: s32 : 3; // illegal addressing mode
        ILL_ILLTRP: s32 : 4; // illegal trap
        ILL_PRVOPC: s32 : 5; // privileged opcode
        ILL_PRVREG: s32 : 6; // privileged register
        ILL_COPROC: s32 : 7; // coprocessor error
        ILL_BADSTK: s32 : 8; // internal stack error

        if info.si_code == {
        case ILL_ILLOPC; eprint("SIGILL: The program crashed because the thread tried to execute an illegal opcode.\n");
        case ILL_ILLOPN; eprint("SIGILL: The program crashed because the thread tried to execute an invalid instruction.\n");
        case ILL_ILLADR; eprint("SIGILL: The program crashed because of an illegal addressing mode.\n");
        case ILL_ILLTRP; eprint("SIGILL: The program crashed because of an illegal trap.\n");
        case ILL_PRVOPC; eprint("SIGILL: The program crashed because it tried to execute an unauthorized instruction.\n");
        case ILL_PRVREG; eprint("SIGILL: The program crashed because it tried to use an unauthorized register.\n");
        case ILL_COPROC; eprint("SIGILL: The program crashed because of a coprocessor error.\n");
        case ILL_BADSTK; eprint("SIGILL: The program crashed because of an internal stack error.\n");
        }
    } else if sig == SIGBUS {
        BUS_ADRALN:    s32 : 0; // Invalid address alignment
        BUS_ADRERR:    s32 : 1; // Nonexistend physical address
        BUS_OBJERR:    s32 : 2; // Object-specific HW error
        BUS_MCEERR_AR: s32 : 3;
        BUS_MCEERR_AO: s32 : 4;
        if info.si_code == {
        case BUS_ADRALN; eprint("SIGBUS: The program crashed because of an invalid address alignment.\n");
        case BUS_ADRERR; eprint("SIGBUS: The program crashed because of a nonexistent physical address.\n");
        case BUS_OBJERR; eprint("SIGBUS: The program crashed because of an object-specific hardware error.\n");
        case BUS_MCEERR_AR; eprint("SIGBUS: The program crashed because of a hardware memory error consumed on a machine check.\n");
        case BUS_MCEERR_AO; eprint("SIGBUS: The program crashed because of a hardware memory error detected in process.\n");
        }
    } else {
        eprint("Got signal ");
        eprint(cast(u64) sig);
        eprint("\n");
    }

    eprint("Registers:\n");

    Print_Register :: (name: string, value: u64) #expand {
        eprint("  ", name, " 0x");
        eprint(value, base=16);
        eprint("\n");
    }

    Print_Register("rax    ", registers.rax);
    Print_Register("rbx    ", registers.rbx);
    Print_Register("rcx    ", registers.rcx);
    Print_Register("rdx    ", registers.rdx);
    Print_Register("rdi    ", registers.rdi);
    Print_Register("rsi    ", registers.rsi);
    Print_Register("rsp    ", registers.rsp);
    Print_Register("rbp    ", registers.rbp);
    Print_Register("r8     ", registers.r8);
    Print_Register("r9     ", registers.r9);
    Print_Register("r10    ", registers.r10);
    Print_Register("r11    ", registers.r11);
    Print_Register("r12    ", registers.r12);
    Print_Register("r13    ", registers.r13);
    Print_Register("r14    ", registers.r14);
    Print_Register("r15    ", registers.r15);
    Print_Register("rip    ", registers.rip);
    Print_Register("eflags ", registers.eflags);

    eprint("\n");


    eprint("Stack trace:\n");

    // @Stability: I have no idea if this is "async-signal-safe",
    context_, cursor := Unwind.Init_Context();
    Unwind.print_backtrace(cursor);

    eprint("\e[0m");

    // Terminate the process and set the error exit code.
    // We use _exit() instead of exit() because the latter is not safe to use from a signal handler and can cause the exit code to be incorrect!
    // (I observed exit code being 0 from time to time after calling exit() from C++, at least on macOS.)
    //  -rluba, 2023-02-08
    _exit :: (status: s32) #foreign libc;
    _exit(1);
}

Signal_Handler :: #type (sig: Signal, info: *siginfo_t, secret: *void) #c_call;

siginfo_t :: struct { // This is not the correct size, but we don't instantiate it, so it's fine.
    si_signo: s32;
    si_errno: s32;
    si_code: s32;
    __pad0: s32;
    si_addr: *void;
}

#scope_module

Register_Dump :: struct {
    r8: u64;
    r9: u64;
    r10: u64;
    r11: u64;
    r12: u64;
    r13: u64;
    r14: u64;
    r15: u64;
    rdi: u64;
    rsi: u64;
    rbp: u64;
    rbx: u64;
    rdx: u64;
    rax: u64;
    rcx: u64;
    rsp: u64;
    rip: u64;
    eflags: u64;
}

// I checked with gdb on machine this is correct
get_register_dump :: (secret: *void) -> Register_Dump #expand {
    ctx := cast(*ucontext_t) secret;

    result: Register_Dump = ---;
    #assert size_of(Register_Dump) <= size_of(type_of(ctx.gregs));
    memcpy(*result, ctx.gregs.data, size_of(Register_Dump));
    return result;
}

caller_address :: (secret: *void) -> *void #expand {
    // These only supports CPU_X86_64. See nvtt/src/nvcore/cpp for more platforms.
    ucp := cast(*ucontext_t) secret;
    return xx ucp.gregs[16]; // RIP register.
}

eprint :: inline (s: .. string) #no_context {
    write_strings(..s, to_standard_error=true);
}

eprint :: inline (n: u64, base := 10) #no_context {
    write_nonnegative_number(n, base, to_standard_error=true);
}

eprint :: inline (n: s64, base := 10) #no_context {
    write_number(n, base, to_standard_error=true);
}

// These come from /usr/include/x86_64-linux-gnu/bits/sigaction.h
SA_FLAGS :: enum_flags s32 {
    NOCLDSTOP :: 1; /* Don't send SIGCHLD when children stop.  */
    NOCLDWAIT :: 2; /* Don't create zombie on child death.  */
    SIGINFO   :: 4; /* Invoke signal-catching function with three arguments instead of one.  */
    ONSTACK   :: 0x08000000; /* Use signal stack by using `sa_restorer'. */
    RESTART   :: 0x10000000; /* Restart syscall on signal return.  */
    NODEFER   :: 0x40000000; /* Don't automatically block the signal when its handler is being executed.  */
    RESETHAND :: 0x80000000; /* Reset to SIG_DFL on entry to handler.  */
}

using Signal;
Signal :: enum s32 {
    // These come from /usr/include/x86_64-linux-gnu/bits/signum.h, they
    // override the ones bellow
    SIGBUS   ::  7;
    SIGUSR1  :: 10;
    SIGUSR2  :: 12;
    SIGCHLD  :: 17;
    SIGCONT  :: 18;
    SIGSTOP  :: 19;
    SIGTSTP  :: 20;
    SIGURG   :: 23;
    SIGPOLL  :: 29;
    SIGSYS   :: 31;

    // The rest come from /usr/include/x86_64-linux-gnu/bits/signum-generic.h
    /* ISO C99 signals.  */
    SIGINT   :: 2;   /* Interactive attention signal.  */
    SIGILL   :: 4;   /* Illegal instruction.  */
    SIGABRT  :: 6;   /* Abnormal termination.  */
    SIGFPE   :: 8;   /* Erroneous arithmetic operation.  */
    SIGSEGV  :: 11;  /* Invalid access to storage.  */
    SIGTERM  :: 15;  /* Termination request.  */

    /* Historical signals specified by POSIX. */
    SIGHUP   :: 1;   /* Hangup.  */
    SIGQUIT  :: 3;   /* Quit.  */
    SIGTRAP  :: 5;   /* Trace/breakpoint trap.  */
    SIGKILL  :: 9;   /* Killed.  */
    // SIGBUS   :: 10;  /* Bus error.  */
    // SIGSYS   :: 12;  /* Bad system call.  */
    SIGPIPE  :: 13;  /* Broken pipe.  */
    SIGALRM  :: 14;  /* Alarm clock.  */

    /* New(er) POSIX signals (1003.1-2008, 1003.1-2013).  */
    // SIGURG    :: 16;  /* Urgent data is available at a socket.  */
    // SIGSTOP   :: 17;  /* Stop, unblockable.  */
    // SIGTSTP   :: 18;  /* Keyboard stop.  */
    // SIGCONT   :: 19;  /* Continue.  */
    // SIGCHLD   :: 20;  /* Child terminated or stopped.  */
    SIGTTIN   :: 21;  /* Background read from control terminal.  */
    SIGTTOU   :: 22;  /* Background write to control terminal.  */
    // SIGPOLL   :: 23;  /* Pollable event occurred (System V).  */
    SIGXCPU   :: 24;  /* CPU time limit exceeded.  */
    SIGXFSZ   :: 25;  /* File size limit exceeded.  */
    SIGVTALRM :: 26;  /* Virtual timer expired.  */
    SIGPROF   :: 27;  /* Profiling timer expired.  */
    // SIGUSR1   :: 30;  /* User-defined signal 1.  */
    // SIGUSR2   :: 31;  /* User-defined signal 2.  */

    /* Nonstandard signals found in all modern POSIX systems
    (including both BSD and Linux).  */
    SIGWINCH  :: 28;    /* Window size change (4.3 BSD, Sun).  */
}

sigset_t :: struct { __val: [16] u64; }

ucontext_t :: struct { // Not the correct size.
    uc_flags: u64;
    uc_link: *ucontext_t;
    ss_sp:   *void;  // stack_t
    ss_flags: s32;
    ss_size:  size_t;
    gregs: [23] s64;
}

size_t   :: u64;

sigval_t :: union {
    sival_int: s32;
    sival_ptr: *void;
}

clock_t   :: s64;
sigaction_t :: struct {
    sa_sigaction: Signal_Handler;
    sa_mask:  sigset_t; // Signal mask to apply.
    sa_flags: SA_FLAGS;

    #if OS == .LINUX then sa_restorer: () #c_call;
}

sigemptyset :: (set: *sigset_t) -> s32 #foreign libc;
sigaction :: (signum: Signal, act: *sigaction_t, oldact: *void) -> s32 #foreign libc;

libc :: #library,system "libc";

Unwind :: #import "Unwind";
