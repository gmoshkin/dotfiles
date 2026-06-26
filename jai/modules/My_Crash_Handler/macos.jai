init :: (handler: Signal_Handler = signal_handler) {
    // Install our signal handler.
    sa: sigaction_t;
    sa.sa_sigaction = handler;

    sigemptyset(*sa.sa_mask);

    sa.sa_flags = SA_RESTART_ONSTACK_SIGINFO;

    sigaction(.SIGSEGV, *sa, null);
    sigaction(.SIGTRAP, *sa, null);
    sigaction(.SIGFPE,  *sa, null);
    sigaction(.SIGBUS,  *sa, null);
    sigaction(.SIGILL,  *sa, null);
    sigaction(.SIGABRT, *sa, null);
}

signal_handler :: (sig: Signal, info: *siginfo_t, secret: *void) #c_call {
    inline Runtime_Support_Crash_Handler.handle_signal(xx sig, xx info, secret);
}

Signal_Handler :: #type (sig: Signal, info: *siginfo_t, secret: *void) #c_call;

using Signal;
// These come from $SDKROOT/usr/include/sys/signal.h
Signal :: enum s32 {
    SIGHUP    :: 1;       /* hangup */
    SIGINT    :: 2;       /* interrupt */
    SIGQUIT   :: 3;       /* quit */
    SIGILL    :: 4;       /* illegal instruction (not reset when caught) */
    SIGTRAP   :: 5;       /* trace trap (not reset when caught) */
    SIGABRT   :: 6;       /* abort() */
    SIGIOT    :: SIGABRT; /* compatibility */
    SIGEMT    :: 7;       /* EMT instruction */
    SIGFPE    :: 8;       /* floating point exception */
    SIGKILL   :: 9;       /* kill (cannot be caught or ignored) */
    SIGBUS    :: 10;      /* bus error */
    SIGSEGV   :: 11;      /* segmentation violation */
    SIGSYS    :: 12;      /* bad argument to system call */
    SIGPIPE   :: 13;      /* write on a pipe with no one to read it */
    SIGALRM   :: 14;      /* alarm clock */
    SIGTERM   :: 15;      /* software termination signal from kill */
    SIGURG    :: 16;      /* urgent condition on IO channel */
    SIGSTOP   :: 17;      /* sendable stop signal not from tty */
    SIGTSTP   :: 18;      /* stop signal from tty */
    SIGCONT   :: 19;      /* continue a stopped process */
    SIGCHLD   :: 20;      /* to parent on child stop or exit */
    SIGTTIN   :: 21;      /* to readers pgrp upon background tty read */
    SIGTTOU   :: 22;      /* like TTIN for output if (tp->t_local&LTOSTOP) */
    SIGIO     :: 23;      /* input/output possible signal */
    SIGXCPU   :: 24;      /* exceeded CPU time limit */
    SIGXFSZ   :: 25;      /* exceeded file size limit */
    SIGVTALRM :: 26;    /* virtual time alarm */
    SIGPROF   :: 27;      /* profiling time alarm */
    SIGWINCH  :: 28;     /* window size changes */
    SIGINFO   :: 29;      /* information request */
    SIGUSR1   :: 30;      /* user defined signal 1 */
    SIGUSR2   :: 31;      /* user defined signal 2 */
}

#scope_module

SA_RESTART_ONSTACK_SIGINFO   :: 0x0043;

sigset_t :: u32;
stack_t :: struct {
    ss_sp:   *void; // signal stack base
    ss_size:  u64;  // signal stack length
    ss_flags: s32;  // SA_DISABLE and/or SA_ONSTACK
}

// @ToDo: Auto-generate stubbed versions of these structs that contain only the fields necessary for the crash handler, but at the right offsets.
x64_exception_state64_t_STUB :: [16] u8;
x64_thread_state64_t_STUB :: struct {
    gregs: [21] s64;
}
x64_float_state64_t_STUB :: [524] u8;

mcontext_t :: struct {
    __es: x64_exception_state64_t_STUB;
    __ss: x64_thread_state64_t_STUB;
    __fs: x64_float_state64_t_STUB;
    padding: [4] u8; // Make up for the fact that our stub for __fs has different aligment rules than the original.
}

ucontext_t :: struct {
    uc_onstack: s32;
    uc_sigmask: sigset_t;     // Signal mask used by this context.
    uc_stack: stack_t;        // Stack used by this context.
    uc_link: *ucontext_t;     // Pointer to resuming context.
    uc_mcsize: u64;           // Size of the machine context passed in.
    uc_mcontext: *mcontext_t; // Pointer to machine specific context.
}

siginfo_t :: struct { // This is not the correct size, but we don't instantiate it, so it's fine.
    si_signo:  s32;
    si_errno:  s32;
    si_code:   s32;
    si_pid:    s32;
    si_uid:    u32;
    si_status: s32;
    si_addr:   *void;
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
    sa_flags: s32;     // See signal options below.

    #if OS == .LINUX then sa_restorer: () #c_call;
}

sigemptyset :: (set: *sigset_t) -> s32 #foreign libc;
sigaction :: (signum: Signal, act: *sigaction_t, oldact: *void) -> s32 #foreign libc;

Runtime_Support_Crash_Handler :: #import "Runtime_Support_Crash_Handler";
