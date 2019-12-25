#!/usr/bin/env perl6
use JSON::Fast;

react {
    whenever IO::Socket::Async.listen('localhost', 3333) -> $vim {
        say "vim: {$vim.gist}";
        whenever $vim.Supply.lines -> $line {
            say "vim: $line";
            my ($i, $msg) = (try $line.&from-json) // $line;
            given $msg {
                when 'quit' {
                    $vim.print: [$i, 'byebye'].&to-json;
                    $vim.close;
                    done;
                }
                default {
                    $vim.print: [$i, $msg.uc].&to-json;
                }
            }
        }
        whenever IO::Socket::Async.listen('localhost', 1337) -> $client {
            say "client: {$client.gist}";
            whenever $client.Supply.lines -> $line {
                say "client: $line";
                my $msg = (try $line.&from-json) // $line;
                given to-json([0, $msg]):!pretty -> $msg {
                    $vim.print: $msg;
                    say "sending: $msg";
                }
            }
        }
    }
    CATCH {
        default {
            say .^name, ': ', .Str;
            say "handled in $?LINE";
        }
    }
}
