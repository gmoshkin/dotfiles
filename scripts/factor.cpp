#include <iostream>
#include <sstream>
#include <string>

class PrimeDecomp
{
public:
    static std::string factors(int n) {
        int cur_n = n, cur_f = 2, cur_p = 0;
        std::ostringstream res_s;
        auto add_factor = [&res_s, &cur_f, &cur_p] {
            res_s << '(' << cur_f;
            if (cur_p > 1) {
                res_s << "**" << cur_p;
            }
            res_s << ')';
        };
        while (cur_n > 1) {
            if (cur_n % cur_f == 0) {
                cur_p++;
                cur_n /= cur_f;
            }
            else {
                if (cur_p) {
                    add_factor();
                    cur_p = 0;
                }
                cur_f++;
            }
        }
        add_factor();
        return res_s.str();
    }
};

void testequal(const std::string &actual, const std::string &expected) {
    if (actual != expected) {
        std::cerr << "expected:\n'"
            << expected << "'\nbut got:\n'" << actual << "'\n";
    }
}

int main(int argc, char *argv[])
{
    testequal(PrimeDecomp::factors(7775460), "(2**2)(3**3)(5)(7)(11**2)(17)");
    testequal(PrimeDecomp::factors(7919), "(7919)");
    if (argc > 1) {
        auto num = std::stoi(argv[1]);
        std::cout << num << ": " << PrimeDecomp::factors(num) << '\n';
    }
    return 0;
};
