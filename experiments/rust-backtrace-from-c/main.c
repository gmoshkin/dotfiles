#include <stdio.h>
#include <unistd.h>

void rb_dump_backtrace(int fd);

void call_rb_dump_backtrace() {
    rb_dump_backtrace(STDERR_FILENO);
}

void baz() { call_rb_dump_backtrace(); }
void bar() { baz(); }
void foo() { bar(); }

int main() {
    foo();

    return 0;
}
