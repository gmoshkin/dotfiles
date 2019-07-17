// clang++ -O3 -std=c++17 -lcurl wttr-get.cpp -o wttr-get
#include <curl/curl.h>
#include <string>
#include <cstdio>

int main() {
    auto curl = curl_easy_init();
    if (not curl) {
        return 1;
    }
    curl_easy_setopt(curl, CURLOPT_URL, "https://wttr.in/Moscow?format=1");

    std::string response_string;
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION,
        (size_t (*) (void *, size_t, size_t, std::string *))
        [] (void *ptr, size_t size, size_t count, std::string *resp) -> size_t
        {
            resp->append(reinterpret_cast<char *>(ptr), size * count);
            return size * count;
        });
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response_string);
    curl_easy_perform(curl);

    puts(response_string.c_str());
    curl_easy_cleanup(curl);
}
