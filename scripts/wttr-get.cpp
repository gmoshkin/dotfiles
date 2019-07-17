// clang++ -O3 -std=c++17 -lcurl wttr-get.cpp -o wttr-get
#include <curl/curl.h>
#include <unistd.h>

int main() {
    auto curl = curl_easy_init();
    if (not curl) {
        return 1;
    }
    curl_easy_setopt(curl, CURLOPT_URL, "https://wttr.in/Moscow?format=1");

    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, (size_t (*) (void *, size_t, size_t,  void *))
        [] (void *ptr, size_t size, size_t count, void *) -> size_t
        {
            return write(1, ptr, size * count);
        });
    curl_easy_perform(curl);
    curl_easy_cleanup(curl);
}
