#run {
    #import "Compiler";
    set_build_options_dc(.{ output_executable_name = "pageview" });
}

State :: struct {
    row_offset: s64;
    col_offset: s64;

    terminal_size: Terminal_Size_Info;

    command_run_period_seconds := 1.0;
    time_next_command_run : float64 = -1.0;

    last_command_output: string;
    last_command_result: Process_Result;
}

main :: () {
    args := get_command_line_arguments();
    if args.count == 1 {
        print("Need a command to run\n");
        return;
    }

    command: [] string;
    command.data = args.data + 1;
    command.count = args.count - 1;

    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    state: State;

    rc := ioctl(STDIN_FILENO, TIOCGWINSZ, *state.terminal_size);

    while !signalled {
        using state;
        write_string("\e[?1049h");

        // TODO: read input!!!

        time := seconds_since_init();
        if time >= time_next_command_run {
            if last_command_output free(last_command_output);
            last_command_result, last_command_output = run_command(..command, capture_and_return_output = true);
            time_next_command_run = time + command_run_period_seconds;
        }

        write_string("\e[H");
        print("% -> %\n", command, last_command_result.exit_code);
        print("\n");

        // 2 lines already printed
        lines_to_show := terminal_size.rows - 2;
        // * 2 for "\n"
        line_buffer := NewArray(lines_to_show * 2, string,, temp);

        tail := last_command_output;
        i := 0;
        if line_buffer.count != 0 while !signalled {
            found:, line:, tail = split_from_left(tail, #char "\n");

            // {
            //     builder: String_Builder;
            //     builder.allocator = temp;

            //     tail := line;
            //     for char: cast([] u8)line {
            //         if char >= #char " " && char < #char "~" {
            //             append(*builder, char);
            //         } else {
            //             print_to_builder(*builder, "\\x%", FormatInt.{ value = char, base = 16, minimum_digits = 2 });
            //         }
            //     }
            //     line = builder_to_string(*builder);
            // }

            actual_characters_count := 0;
            visible_columns_count := 0;
            while !signalled {
                char := line[actual_characters_count];
                if char == #char "\e" {
                    actual_characters_count += 1;

                    while !signalled {
                        char = line[actual_characters_count];
                        if char == {
                            case #char "[";
                                actual_characters_count += 1;
                                while !signalled {
                                    char = line[actual_characters_count];
                                    actual_characters_count += 1;
                                    if char != #char "m" break;
                                }
                            case; break;
                        }
                    }
                } else {
                    actual_characters_count += 1;
                    visible_columns_count += 1;
                }

                if actual_characters_count >= line.count break;
                if visible_columns_count >= terminal_size.cols break;
            }
            line.count = actual_characters_count;

            line_buffer[i] = line; i += 1;
            line_buffer[i] = "\n"; i += 1;

            if i >= line_buffer.count break;

            if !found break; // last line
        }
        // don't print the last "\n"
        line_buffer.count -= 1;
        write_strings(..line_buffer);

        if signalled break;

        reset_temporary_storage();
        sleep_milliseconds(xx (1000.0 / 10.0));
    }

    // Restore terminal state
    write_string("\e[?1049l");

    // Print output one last time
    print("% -> %\n", command, state.last_command_result.exit_code);
    print("\n");
    tail := state.last_command_output;
    i := 0;
    while true {
        found:, line:, tail = split_from_left(tail, #char "\n");
        write_strings(line, "\n");

        i += 1;
        if i >= state.terminal_size.rows - 2 break;

        if !found break;
    }

    if signalled {
        print("got signal %\n", signalled_with_signal);
    }
}

//
// string utilities
//

count_invisible_characters :: (s: string) -> int {

}

chop_line :: (s: string) -> (found: bool, line: string, tail: string) {
    index := inline find_index_from_left(s, #char "\n");
    if index == -1  return false, s, "";

    return true, slice(s, 0, index + 1), slice(s, index + 1, s.count - index - 1);
}

//
// signal handling
//

signalled := false;
signalled_with_signal := 0;
signal_handler :: (signal: s32) #c_call #no_context {
    signalled = true;
    signalled_with_signal = signal;
}

libc :: #system_library "libc";
Signal_Handler :: #type (s32) -> void #c_call #no_context;
signal :: (signal: s32, handler: Signal_Handler) #foreign libc;

//
// terminfo
//

TIOCGWINSZ :: 0x5413;

Terminal_Size_Info :: struct {
    rows: u16;
    cols: u16;
    xpixel: u16;
    ypixel: u16;
}

#import "Basic";
#import "Process";
#import "String";
#import "POSIX";
