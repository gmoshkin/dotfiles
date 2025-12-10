use std::io::Write;

#[no_mangle]
pub fn rb_dump_backtrace(fd: i32) {
    let backtrace = std::backtrace::Backtrace::force_capture();
    let mut fd: std::fs::File = unsafe { std::os::fd::FromRawFd::from_raw_fd(fd) };
    write!(&mut fd, "{}", backtrace).unwrap();
}
