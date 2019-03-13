#include <unistd.h>
#include <cstring>
#include <array>
#include <cstdio>
#include <tuple>

constexpr std::array<char, 3> operator "" _3(const char *s, size_t)
{
    return {s[0], s[1], s[2]};
}

// TODO: write a constexpr converter from (char *)"DDD\0" to (char[3]){'D', 'D', 'D'}
/* char numbers[][3] = { */

constexpr std::array<char, 3>
to_3chars(unsigned int num)
{
    char c1 = '0' + num % 1000 / 100;
    char c2 = '0' + num % 100 / 10;
    char c3 = '0' + num % 10;
    return {c1, c2, c3};
}

template <size_t count = 256>
constexpr std::array<std::array<char, 3>, count>
gen_numbers()
{
    std::array<std::array<char, 3>, count> res {{{0}}};
    for (size_t i = 0; i < count; i++) {
        res[i] = to_3chars(i);
    }
    return res;
}

template <size_t n_chars>
constexpr size_t str_size(const char (&)[n_chars])
{
    return n_chars;
}

template <size_t n_chars>
constexpr std::array<char, n_chars> to_array(const char (&array) [n_chars])
{
    std::array<char, n_chars> res {0};
    for (size_t i = 0; i < n_chars; i++) {
        res[i] = array[i];
    }
    return res;
}

using rgb_t = std::tuple<std::uint8_t, std::uint8_t, std::uint8_t>;
constexpr char pixel_templ[] = "\033[38;2;000;000;000;48;2;000;000;000m▄";
constexpr int fg_r_idx =  7, fg_g_idx = 11, fg_b_idx = 15;
constexpr int bg_r_idx = 24, bg_g_idx = 28, bg_b_idx = 32;

constexpr auto numbers = gen_numbers();

template <size_t size, size_t repl_count = 3>
constexpr std::array<char, size>
repl(const std::array<char, size> arr, size_t ofs,
     const std::array<char, repl_count> repl)
{
    auto res = arr;
    for (size_t i = 0; i < repl_count; i++) {
        res[ofs + i] = repl[i];
    }
    return res;
}

#define NUM "0000"
constexpr char other_pixel_templ[] =
"\033[38;2;0" NUM ";000" NUM ";000" NUM ";48;2;00" NUM ";000" NUM ";000" NUM "m▄";

/*
constexpr auto
operator "" _bytes (unsigned long long num)
{
    return num * 8;
}

template <typename T, typename CharT, size_t count>
constexpr auto
convert_array(const std::array<CharT, count> &src)
{
    static_assert(sizeof(CharT) == 1);
    constexpr auto res_count = count / sizeof(T);
    constexpr int res_remains = count % sizeof(T);
    std::array<T, res_count + bool(res_remains)> res {0};
    for (size_t i = 0; i < res_count; i++) {
        for (int j = sizeof(T) - 1; j >= 0; j--) {
            res[i] = (res[i] << 1_bytes) | src[i * sizeof(T) + j];
        }
    }
    if constexpr (res_remains > 0) {
        for (int j = res_remains - 1; j >= 0; j--) {
            res[res_count] = (res[res_count] << 1_bytes) | src[res_count * sizeof(T) + j];
        }
    }
    return res;
}

template <int first, int ... rest>
constexpr auto first_positive()
{
    if constexpr (first < 0) {
        static_assert (sizeof...(rest) != 0);
        return first_positive<rest ...>();
    } else {
        return first;
    }
}

template <int dst_count = -1, typename T, size_t count>
constexpr auto convert_array(const std::array<T, count> &src)
{
    static_assert(sizeof(T) > 1);
    constexpr size_t res_count = first_positive<dst_count, count * sizeof(T)>();
    std::array<T, res_count> res {0};
    for (auto curr: src) {
        for (size_t j = 0; j < sizeof(T); j++) {
            res[j] = curr & 0xff;
            curr >>= 1_bytes;
        }
    }
    return res;
}

 */

/* constexpr std::array<char, str_size(other_pixel_templ)> */
/* get_other_pixel_str(rgb_t fg, rgb_t bg) */
/* { */
/*     std::array<std::uint32_t, str_size(other_pixel_templ) / 4> res = convert<std::uint32_t>(other_pixel_templ); */
/*     auto [fg_r, fg_g, fg_b] = fg; */
/*     auto [bg_r, bg_g, bg_b] = bg; */
/*     res = repl(res, fg_r_idx, numbers[fg_r]); */
/*     res = repl(res, fg_g_idx, numbers[fg_g]); */
/*     res = repl(res, fg_b_idx, numbers[fg_b]); */
/*     res = repl(res, bg_r_idx, numbers[bg_r]); */
/*     res = repl(res, bg_g_idx, numbers[bg_g]); */
/*     res = repl(res, bg_b_idx, numbers[bg_b]); */
/*     return res; */
/* } */

constexpr std::array<char, str_size(pixel_templ)>
get_pixel_str(rgb_t fg, rgb_t bg)
{
    std::array<char, str_size(pixel_templ)> res = to_array(pixel_templ);
    auto [fg_r, fg_g, fg_b] = fg;
    auto [bg_r, bg_g, bg_b] = bg;
    res = repl(res, fg_r_idx, numbers[fg_r]);
    res = repl(res, fg_g_idx, numbers[fg_g]);
    res = repl(res, fg_b_idx, numbers[fg_b]);
    res = repl(res, bg_r_idx, numbers[bg_r]);
    res = repl(res, bg_g_idx, numbers[bg_g]);
    res = repl(res, bg_b_idx, numbers[bg_b]);
    return res;
}

void put_pixel(rgb_t fg, rgb_t bg)
{
    char pixel_templ[] = "\033[38;2;000;000;000;48;2;000;000;000m▄";
    auto [fgr, fgg, fgb] = fg;
    auto [bgr, bgg, bgb] = bg;
    memcpy(&pixel_templ[fg_r_idx], &numbers[fgr], 3);
    memcpy(&pixel_templ[fg_g_idx], &numbers[fgg], 3);
    memcpy(&pixel_templ[fg_b_idx], &numbers[fgb], 3);
    memcpy(&pixel_templ[bg_r_idx], &numbers[bgr], 3);
    memcpy(&pixel_templ[bg_g_idx], &numbers[bgg], 3);
    memcpy(&pixel_templ[bg_b_idx], &numbers[bgb], 3);
    write(1, pixel_templ, sizeof(pixel_templ));
}

template <size_t n_chars>
void put_text(const char (&text)[n_chars])
{
    write(1, &text, n_chars);
}

template <size_t n_chars>
void put_text(const std::array<char, n_chars> &text)
{
    write(1, &text, n_chars);
}

template <char ... text>
auto operator "" _s ()
{
    return std::array<char, sizeof...(text)> { text ... };
}

int main()
{
    char code_templ[] = "\033[38;2;000;000;000;48;2;000;000;000m";
    auto fr = 128, fg = 200, fb =  10;
    auto br =  10, bg =  52, bb =   5;
    memcpy(&code_templ[fg_r_idx], &numbers[fr], 3);
    memcpy(&code_templ[fg_g_idx], &numbers[fg], 3);
    memcpy(&code_templ[fg_b_idx], &numbers[fb], 3);
    memcpy(&code_templ[bg_r_idx], &numbers[br], 3);
    memcpy(&code_templ[bg_g_idx], &numbers[bg], 3);
    memcpy(&code_templ[bg_b_idx], &numbers[bb], 3);
    write(1, code_templ, sizeof(code_templ));
    write(1, "jopa\033[0m\n", sizeof("jopa\033[0m\n"));
    put_text("jopa\n");
    /* put_pixel({255, 128, 64}, {64, 64, 255}); */
    /* put_pixel({128, 64, 255}, {255, 64, 128}); */
    put_text(get_pixel_str({123, 13, 3}, {3, 7, 9}));
    write(1, "\n", 1);
    {
        long long unsigned int *p = (long long unsigned int *) code_templ;
        printf("%llx %llx %llx %llx %llx\n", p[0], p[1], p[2], p[3], p[4]);
    }
    {
        unsigned int *p = (unsigned int *) code_templ;
        printf("%x %x %x %x %x %x %x %x %x\n", p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8]);
    }
    return 0;
}
