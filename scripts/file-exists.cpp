#include <sys/stat.h>

inline bool exists(const char *name) {
    struct stat buffer;
    return (stat (name, &buffer) == 0);
}

int main()
{
    for (int i = 0; i < 1'000'000; i++) {
        exists("/tmp/ass");
    }
    return 0;
}
