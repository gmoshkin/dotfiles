//
// A port of libcoro's assembly backend (CORO_ASM) to Jai.
//
// Original C source: tarantool-sys/third_party/coro/{coro.h,coro.c}
//   Copyright (c) 2001-2011 Marc Alexander Lehmann <schmorp@schmorp.de>
//   Dual licensed BSD-2-clause / GPL-2.0-or-later, see the upstream LICENSE file.
//   Modelled after Ralf S. Engelschall's article http://www.gnu.org/software/pth/rse-pmt.ps
//
// Supported platforms: Linux and macOS on x86-64 and ARM64. All of the other libcoro
// backends (ucontext, sjlj, pthread, windows fibers) are intentionally not ported --
// the SysV/AAPCS register save-and-switch is the only thing we need, and it is the same
// code on Linux and macOS because both use the same calling convention per architecture.
//
// Verified by running the tests on Linux/x86-64, macOS/ARM64 and macOS/x86-64, in debug
// and optimized builds, and on both the x64 and the LLVM backend everywhere the x64
// backend is available. Jai does not currently target Linux/ARM64 at all (setting
// cpu_target = .ARM64 with os_target = .LINUX silently gives you x86-64), but nothing in
// the ARM64 path here is macOS-specific, so it should come along for free if that target
// ever appears. The same goes for Android/ARM64.
//
// Deviations from the C original:
//
//   - Both architectures use the "coro_startup" bootstrap (upstream only uses it on ARM).
//     Upstream's x86-64 path passes the entry proc and its argument through thread-local
//     globals and pays two extra coro_transfer calls in coro_create to pick them up. We
//     instead plant them straight into the callee-saved register slots of the initial
//     frame, like the ARM path does, so coro_create never switches stacks at all.
//   - No CFI is emitted (we cannot, from raw bytes), so unwinding out of a coroutine
//     relies on the frame pointer chain being terminated: the initial frame has rbp/x29
//     zeroed and a null return address, which is enough for frame-pointer-based
//     unwinders but not for a pure DWARF one.
//   - coro_stack_alloc does not ask for PROT_EXEC. Upstream tries an executable stack
//     first for the sake of platforms that build trampolines on the stack; this port
//     never does that, and macOS/ARM64 would reject it anyway.
//   - When a coroutine's entry proc returns, we execute a trap instruction (ud2 / brk)
//     rather than calling abort(), to keep the module free of foreign symbols.
//
// The entry proc of a coroutine must never return: transfer back out of it instead.
//
// Coroutines are #c_call, i.e. they start out without a Jai context. Pass the context
// you want along in the argument and push_context it. Note that a Context copied from
// another stack still points at that stack's Stack_Trace_Nodes, so zero out
// .stack_trace unless you want the two stacks' traces spliced together.
//
// Overflowing a coroutine stack faults on the guard pages (see coro_stack_alloc), but
// do not expect a readable crash report out of it: the crash handler has no stack left
// to run on, and on macOS that turns into a second, more confusing signal. Only a
// handler with its own sigaltstack can report these properly.
//

#module_parameters (TEST := false, GUARD_PAGES := 4);

#if OS != .LINUX && OS != .MACOS {
    #assert false, "Coroutine only supports Linux and macOS.";
}

#if CPU != .X64 && CPU != .ARM64 {
    #assert false, "Coroutine only supports x86-64 and ARM64.";
}

//
// A coroutine's saved state. Treat it as opaque; 'sp' must stay at offset 0 because
// the assembly below dereferences the context pointer directly.
//
Coro_Context :: struct {
    sp: **void;
}

Coro_Proc :: #type (arg: *void) #c_call;

//
// Prepare 'ctx' so that the first coro_transfer into it starts running 'coro' with
// 'arg' on the stack [sptr, sptr + ssize).
//
// As a special case, passing a null 'coro' produces an empty context, which is what
// you want for the "current" side of the very first transfer: the first transfer out
// of it fills it in.
//
// Allocating and freeing the stack is the caller's business; see coro_stack_alloc.
//
coro_create :: (ctx: *Coro_Context, coro: Coro_Proc, arg: *void, sptr: *void, ssize: s64) {
    ctx.sp = null;
    if !coro  return;

    assert(sptr != null, "coro_create needs a stack.");
    assert(ssize >= MINIMUM_STACK_SIZE, "Stack of % bytes is too small (minimum is %).", ssize, MINIMUM_STACK_SIZE);

    // Stacks grow down, so we build the initial frame at the top of the region.
    sp := cast(**void) (cast(*u8) sptr + ssize);
    assert((cast(u64) sp) % 16 == 0, "The top of the stack must be 16-byte aligned.");

    #if CPU == .X64 {
        // Mirrors what coro_transfer left behind when it suspended a running coroutine:
        // NUM_SAVED pushed registers, then the address it will 'pop rcx; jmp rcx' to.
        // The extra null on top is padding so that the 'call' in coro_startup_raw lands
        // on the entry proc with rsp == 8 (mod 16), as the SysV ABI requires.
        sp -= 1;  sp[0] = null;
        sp -= 1;  sp[0] = cast(*void) coro_startup_raw;

        sp -= NUM_SAVED;
        memset(sp, 0, NUM_SAVED * size_of(*void));
        sp[0] = cast(*void) coro;  // r15
        sp[1] = arg;               // r14
    } else #if CPU == .ARM64 {
        // AAPCS returns through the link register, so there is no return address on the
        // stack; coro_transfer's 'ret' picks x30 out of the saved frame instead.
        sp -= NUM_SAVED;
        memset(sp, 0, NUM_SAVED * size_of(*void));
        sp[0]  = cast(*void) coro;                // x19
        sp[1]  = arg;                             // x20
        sp[11] = cast(*void) coro_startup_raw;    // x30 (lr)
    }

    ctx.sp = sp;
}

//
// Suspend the current coroutine into 'prev' and resume 'next'. Control comes back here
// when somebody transfers into 'prev' again.
//
// Both contexts must be live for as long as the coroutines are; 'prev' may be an empty
// context (see coro_create), 'next' may not.
//
coro_transfer :: inline (prev: *Coro_Context, next: *Coro_Context) #no_context {
    // Do not "simplify" this into a direct call of coro_transfer_raw. See the comment on
    // coro_transfer_ptr below: the indirection through a global is what keeps the call
    // indirect, and an indirect call is what keeps the optimizer's hands off it.
    if !coro_transfer_ptr  coro_transfer_ptr = cast(Coro_Transfer_Proc) cast(*void) coro_transfer_raw;
    coro_transfer_ptr(prev, next);
}

//
// Present for parity with the C API; the assembly backend has nothing to release.
// The stack is still yours to free.
//
coro_destroy :: inline (ctx: *Coro_Context) #no_context {
    ctx.sp = null;
}

//
// Stack management.
//

Coro_Stack :: struct {
    sptr:  *void;
    ssize: s64;
}

//
// Allocate a stack, guarded by GUARD_PAGES inaccessible pages at its low end so that
// overflowing it faults instead of quietly eating whatever is mapped below.
//
// Careful: as in the C original, 'size' is counted in pointers, not bytes, so the
// default of 256 * 1024 is a 2 MiB stack on a 64-bit target.
//
coro_stack_alloc :: (stack: *Coro_Stack, size: u32 = 0) -> bool {
    if size == 0  size = 256 * 1024;

    page := get_page_size();

    stack.sptr  = null;
    stack.ssize = (cast(s64) size * size_of(*void) + page - 1) / page * page;

    guard := GUARD_PAGES * page;
    base := mmap(null, cast(u64) (stack.ssize + guard), PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if base == MAP_FAILED {
        stack.ssize = 0;
        return false;
    }

    #if GUARD_PAGES > 0 {
        // If this fails we have a working stack without a guard, which is worth having.
        mprotect(base, cast(u64) guard, PROT_NONE);
    }

    stack.sptr = cast(*u8) base + guard;
    return true;
}

//
// Safe to call on a Coro_Stack whose coro_stack_alloc failed, and on one you have
// zeroed out yourself to say "not mine to free".
//
coro_stack_free :: (stack: *Coro_Stack) {
    if !stack.sptr  return;

    guard := GUARD_PAGES * get_page_size();
    munmap(cast(*u8) stack.sptr - guard, cast(u64) (stack.ssize + guard));

    stack.sptr  = null;
    stack.ssize = 0;
}

#scope_module

//
// The register switching itself.
//
// These are #no_call ("naked") procedures: the bytes below are meant to be the entire
// function, with no prologue, no epilogue and no return, so that we are free to move the
// stack pointer out from under them. (The x64 backend does not fully cooperate; see
// FRAME_FIXUP.) #no_call procedures cannot declare arguments, so we call them through a
// cast function pointer; the arguments arrive in the ABI registers all the same.
//
// The byte sequences were produced with llvm-mc, and the disassembly next to every line
// is not decoration -- it is checkable:
//
//     jai-asm check jai/modules/Coroutine.jai       # disassemble each line, diff vs its comment
//     jai-asm emit --arch aarch64 new_thing.s       # write new lines in this same format
//
// Run the check after touching anything below. (scripts/jai-asm, needs llvm-mc.)
//

Coro_Transfer_Proc :: #type (prev: *Coro_Context, next: *Coro_Context) #c_call;

//
// Why coro_transfer goes through this global instead of just casting and calling.
//
// A #no_call procedure has no return instruction in the IR the compiler hands to LLVM,
// so LLVM concludes it is noreturn. If the call is a direct one -- which it is if you
// cast the procedure constant at the call site, because LLVM happily folds through the
// cast -- then everything after the call is dead code and gets deleted. Which is to say
// the optimized build silently drops the entire rest of whatever procedure called
// coro_transfer. Loading the target out of a global keeps the call indirect, and LLVM
// will not speculate about where an indirect call goes.
//
// A benign race: whichever thread wins, it writes the same address.
//
coro_transfer_ptr: Coro_Transfer_Proc;

#if CPU == .X64 {

    // rbp, rbx, r12, r13, r14, r15.
    NUM_SAVED :: 6;

    //
    // Only the LLVM backend honours #no_call. The x64 backend emits its usual frame
    // regardless, which would leave the stack pointer somewhere below where we think it
    // is. That frame is always rbp-based ("push rbp; mov rbp, rsp; sub N, rsp", possibly
    // with more pushes after the mov), so we can undo it in two instructions and carry
    // on as if we really were naked. Arguments are untouched by it -- a #no_call
    // procedure has no declared parameters to spill.
    //
    // Note the same fixup is what coro_startup_raw needs, even though it is reached by a
    // jump rather than a call: the frame it pushes gets thrown away just the same.
    //
    UNDO_FRAME :: #run -> bool {
        #import "Compiler";
        return get_build_options().backend == .X64;
    };

    #if UNDO_FRAME {
        FRAME_FIXUP :: u8.[
            0x48, 0x89, 0xec,        // mov  rsp, rbp
            0x5d,                    // pop  rbp
        ];
    } else {
        FRAME_FIXUP :: u8.[];
    }

    // (prev: rdi, next: rsi)
    coro_transfer_raw :: () #no_call {
        #bytes FRAME_FIXUP;
        #bytes .[
            0x55,                    // push rbp
            0x53,                    // push rbx
            0x41, 0x54,              // push r12
            0x41, 0x55,              // push r13
            0x41, 0x56,              // push r14
            0x41, 0x57,              // push r15
            0x48, 0x89, 0x27,        // mov  qword ptr [rdi], rsp
            0x48, 0x8b, 0x26,        // mov  rsp, qword ptr [rsi]
            0x41, 0x5f,              // pop  r15
            0x41, 0x5e,              // pop  r14
            0x41, 0x5d,              // pop  r13
            0x41, 0x5c,              // pop  r12
            0x5b,                    // pop  rbx
            0x5d,                    // pop  rbp
            0x59,                    // pop  rcx
            0xff, 0xe1,              // jmp  rcx
        ];
    }

    // Entered by the 'jmp rcx' above, with the entry proc in r15 and its argument in r14
    // (coro_create put them in those slots). rbp is already zero, but clear it anyway to
    // keep the ABI happy if this is ever reached some other way. The pushed zero is both
    // the stack alignment padding and a null return address, so a frame-pointer walk out
    // of the coroutine terminates here.
    coro_startup_raw :: () #no_call {
        #bytes FRAME_FIXUP;
        #bytes .[
            0x48, 0x31, 0xed,        // xor  rbp, rbp
            0x4c, 0x89, 0xf7,        // mov  rdi, r14
            0x6a, 0x00,              // push 0
            0x41, 0xff, 0xd7,        // call r15
            0x0f, 0x0b,              // ud2
        ];
    }

} else #if CPU == .ARM64 {

    // x19-x28, x29 (fp), x30 (lr), d8-d15.
    NUM_SAVED :: 20;

    // (prev: x0, next: x1)
    coro_transfer_raw :: () #no_call {
        #bytes .[
            0xff, 0x83, 0x02, 0xd1,  // sub  sp, sp, #160
            0xe2, 0x03, 0x00, 0x91,  // mov  x2, sp
            0x53, 0x50, 0x00, 0xa9,  // stp  x19, x20, [x2]
            0x55, 0x58, 0x01, 0xa9,  // stp  x21, x22, [x2, #16]
            0x57, 0x60, 0x02, 0xa9,  // stp  x23, x24, [x2, #32]
            0x59, 0x68, 0x03, 0xa9,  // stp  x25, x26, [x2, #48]
            0x5b, 0x70, 0x04, 0xa9,  // stp  x27, x28, [x2, #64]
            0x5d, 0x78, 0x05, 0xa9,  // stp  x29, x30, [x2, #80]
            0x48, 0x24, 0x06, 0x6d,  // stp  d8,  d9,  [x2, #96]
            0x4a, 0x2c, 0x07, 0x6d,  // stp  d10, d11, [x2, #112]
            0x4c, 0x34, 0x08, 0x6d,  // stp  d12, d13, [x2, #128]
            0x4e, 0x3c, 0x09, 0x6d,  // stp  d14, d15, [x2, #144]
            0x02, 0x00, 0x00, 0xf9,  // str  x2, [x0]
            0x23, 0x00, 0x40, 0xf9,  // ldr  x3, [x1]
            0x73, 0x50, 0x40, 0xa9,  // ldp  x19, x20, [x3]
            0x75, 0x58, 0x41, 0xa9,  // ldp  x21, x22, [x3, #16]
            0x77, 0x60, 0x42, 0xa9,  // ldp  x23, x24, [x3, #32]
            0x79, 0x68, 0x43, 0xa9,  // ldp  x25, x26, [x3, #48]
            0x7b, 0x70, 0x44, 0xa9,  // ldp  x27, x28, [x3, #64]
            0x7d, 0x78, 0x45, 0xa9,  // ldp  x29, x30, [x3, #80]
            0x68, 0x24, 0x46, 0x6d,  // ldp  d8,  d9,  [x3, #96]
            0x6a, 0x2c, 0x47, 0x6d,  // ldp  d10, d11, [x3, #112]
            0x6c, 0x34, 0x48, 0x6d,  // ldp  d12, d13, [x3, #128]
            0x6e, 0x3c, 0x49, 0x6d,  // ldp  d14, d15, [x3, #144]
            0x7f, 0x80, 0x02, 0x91,  // add  sp, x3, #160
            0xc0, 0x03, 0x5f, 0xd6,  // ret
        ];
    }

    // Entered by the 'ret' above, with the entry proc in x19 and its argument in x20.
    // x29 is zero (coro_create zeroed the frame), which terminates a frame-pointer walk.
    coro_startup_raw :: () #no_call {
        #bytes .[
            0xe0, 0x03, 0x14, 0xaa,  // mov  x0, x20
            0x60, 0x02, 0x3f, 0xd6,  // blr  x19
            0x00, 0x00, 0x20, 0xd4,  // brk  #0
        ];
    }

}

#scope_export

#if TEST {

test_coroutine :: () {
    State :: struct {
        ctx:     #Context;
        main:    Coro_Context;
        co:      [WORKERS] Coro_Context;
        stacks:  [WORKERS] Coro_Stack;
        order:   [..] int;
    }

    WORKERS :: 4;
    ROUNDS  :: 4;

    // Everything a worker needs, since a #c_call closes over nothing.
    Arg :: struct {
        state: *State;
        index: int;
    }

    state: State;
    args:  [WORKERS] Arg;

    worker :: (arg: *void) #c_call {
        using a := cast(*Arg) arg;
        s := a.state;

        c := s.ctx;
        c.stack_trace = null;   // Those nodes live on somebody else's stack.
        push_context c {
            // Sums that the compiler will want to keep in callee-saved registers, so
            // that a transfer that fails to preserve them shows up as a wrong answer.
            acc  := 0;
            facc := cast(float64) 0;

            for round: 1..ROUNDS {
                acc  += index * round;
                facc += cast(float64) index * 0.25;
                array_add(*s.order, index * 100 + round);

                // Hand off straight to the next worker rather than back through main,
                // except on the very last hop.
                if round == ROUNDS && index == WORKERS - 1 {
                    coro_transfer(*s.co[index], *s.main);
                } else {
                    coro_transfer(*s.co[index], *s.co[(index + 1) % WORKERS]);
                }
            }

            assert(acc == index * 10, "callee-saved gpr clobbered: acc = %, expected %", acc, index * 10);
            assert(facc == cast(float64) index, "callee-saved fpr clobbered: facc = %, expected %", facc, index);
            array_add(*s.order, -1 - index);

            while true  coro_transfer(*s.co[index], *s.main);
        }
    }

    state.ctx = context;
    coro_create(*state.main, null, null, null, 0);

    for index: 0..WORKERS-1 {
        args[index] = .{*state, index};
        // 16k pointers, i.e. 128 KiB.
        assert(coro_stack_alloc(*state.stacks[index], 16 * 1024), "coro_stack_alloc failed");
        coro_create(*state.co[index], worker, *args[index], state.stacks[index].sptr, state.stacks[index].ssize);
    }
    defer for index: 0..WORKERS-1  coro_stack_free(*state.stacks[index]);

    // One kick sets the whole round-robin going; it comes back when the last worker
    // finishes its last round.
    coro_transfer(*state.main, *state.co[0]);

    expected: [..] int;
    defer array_free(expected);
    for round: 1..ROUNDS  for index: 0..WORKERS-1  array_add(*expected, index * 100 + round);

    assert(state.order.count == expected.count, "got % entries, expected %: %", state.order.count, expected.count, state.order);
    for state.order  assert(it == expected[it_index], "order[%] = %, expected %", it_index, it, expected[it_index]);

    // Let every worker run past its transfer loop so its own asserts get a chance.
    for index: 0..WORKERS-1 {
        coro_transfer(*state.main, *state.co[index]);
        assert(state.order[expected.count + index] == -1 - index, "worker % did not finish", index);
    }

    for index: 0..WORKERS-1  coro_destroy(*state.co[index]);
    coro_destroy(*state.main);
    array_free(state.order);

    log("% coroutines x % rounds of direct hand-off: ok", WORKERS, ROUNDS);
}

test_coro_stack_alloc :: () {
    stack: Coro_Stack;
    assert(coro_stack_alloc(*stack, 4096), "coro_stack_alloc failed");

    page := get_page_size();
    assert(stack.ssize == 4096 * size_of(*void), "ssize = %", stack.ssize);
    assert(stack.ssize % page == 0, "ssize % is not a multiple of the page size %", stack.ssize, page);
    assert((cast(u64) stack.sptr) % cast(u64) page == 0, "sptr % is not page aligned", stack.sptr);

    // Both ends of the region are usable; the guard below it is checked by hand, since
    // touching it takes the process down.
    lo := cast(*u8) stack.sptr;
    hi := lo + stack.ssize;
    lo.* = 0x42;
    (hi - 1).* = 0x43;
    assert(lo.* == 0x42 && (hi - 1).* == 0x43);

    coro_stack_free(*stack);
    assert(stack.sptr == null && stack.ssize == 0, "coro_stack_free did not clear the stack");

    // Freeing a zeroed / failed stack is a no-op.
    empty: Coro_Stack;
    coro_stack_free(*empty);

    log("stack of % bytes with % guard pages of % bytes: ok", 4096 * size_of(*void), GUARD_PAGES, page);
}

}

#scope_file

// Enough room for the initial frame plus something for the coroutine to actually do.
MINIMUM_STACK_SIZE :: 4096;

get_page_size :: () -> s64 {
    // Benign race: every thread computes the same answer.
    if !cached_page_size  cached_page_size = getpagesize();
    return cached_page_size;
}

cached_page_size: s64;

#import "Basic";
#import "POSIX";
