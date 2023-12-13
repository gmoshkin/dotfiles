#[cfg(any(target_arch = "x86", target_arch = "x86_64"))]
#[macro_export]
macro_rules! rdtsc {
    () => {{
        let rax: i64;

        #[allow(unused_unsafe)]
        unsafe {
            ::std::arch::asm! {
                "rdtsc",
                "shl edx, 32",
                "or rax, rdx",
                out("rax") rax,
                options(nomem, nostack),
            }
        };

        rax
    }}
}
