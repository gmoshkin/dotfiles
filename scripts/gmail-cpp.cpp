// clang++ -O3 -std=c++17 -lcurl -DUSER=$GMUSER -DPWD=$GMPWD gmail-cpp.cpp -o gmail-cpp
#if defined(USER) && defined(PWD)

#include <curl/curl.h>
#include <unistd.h>
#include <cstring>

#define STR(x) DOSTR(x)
#define DOSTR(x) #x

#define PREFIX "✉ "
#define LEN(s) sizeof(s) - 1

#define OPEN_TAG "<fullcount>"
#define CLOSE_TAG "</fullcount>"

#include <iostream>

int main() {
    auto curl = curl_easy_init();
    if (not curl) {
        return 1;
    }
    curl_easy_setopt(curl, CURLOPT_URL, "https://mail.google.com/a/gmail.com/feed/atom");
    curl_easy_setopt(curl, CURLOPT_USERPWD, ( STR(USER) ":" STR(PWD) ));
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, (size_t (*) (void *, size_t, size_t,  void *))
        [] (void *ptr, size_t, size_t, void *) -> size_t
        {
            auto tag_open = strstr((const char *) ptr, OPEN_TAG);
            auto tag_close = strstr(tag_open, CLOSE_TAG);
            auto fullcount = tag_open + LEN(OPEN_TAG);
            auto fullcount_len = tag_close - fullcount;
            if (strncmp(fullcount, "0", fullcount_len)) {
                return write(1, PREFIX, LEN(PREFIX))
                     + write(1, fullcount, fullcount_len);
            } else {
                return 0;
            }
        });
    curl_easy_perform(curl);
    curl_easy_cleanup(curl);
}

#else

#include <cstdio>
int main() {
    puts("you didnt define USER and PWD dummy");
}

#endif
