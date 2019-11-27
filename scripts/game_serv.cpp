#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>

#include <iostream>
#include <chrono>
#include <thread>
#include <vector>
#include <algorithm>

using namespace std::chrono_literals;

sockaddr_in sockaddr_in_from_port(std::uint32_t port)
{
    sockaddr_in ip_addr;
    ip_addr.sin_family = AF_INET;
    ip_addr.sin_port = htonl(port);
    ip_addr.sin_addr.s_addr = INADDR_ANY;
    return ip_addr;
}

int main()
{
    auto sock_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (sock_fd < 0) {
        std::cerr << "oopsie no socket\n";
    }
    auto ip_addr = sockaddr_in_from_port(18080);
    if (bind(sock_fd, reinterpret_cast<sockaddr *>(&ip_addr), sizeof(ip_addr)) < 0) {
        std::cerr << "oopsie no bind\n";
    }
    if (listen(sock_fd, 0x10) < 0) {
        std::cerr << "oopsie no listen\n";
    }
    while (true) {
        fd_set read_fds;
        auto max_fd = sock_fd;
        FD_ZERO(&read_fds);
        FD_SET(sock_fd, &read_fds);

        std::vector<int> client_fds;
        for (auto fd: client_fds) {
            FD_SET(fd, &read_fds);
            max_fd = std::max(fd, max_fd);
        }

        if (select(max_fd + 1, &read_fds, nullptr, nullptr, nullptr) < 0) {
            std::cerr << "oopsie no select\n";
        }

        if (FD_ISSET(sock_fd, &read_fds)) {
            if (auto new_fd = accept(sock_fd, nullptr, nullptr); new_fd >= 0) {
                client_fds.push_back(new_fd);
            }
            else {
                std::cerr << "oopsie no accept\n";
            }
        }

        for (auto fd: client_fds) {
            if (FD_ISSET(fd, &read_fds)) {
                auto n_read = read(fd, )
            }
        }
    }
    return 0;
}
