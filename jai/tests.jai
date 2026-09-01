main :: () {
    t0 := seconds_since_init();
    log("\e[32mRunning tests...\e[0m");

    Log_Header :: (test: string) #expand {
        log("\n# \e[35m%\e[0m\n\n", test);
    }

    Log_Header("test_Bin");                                test_Bin();
    Log_Header("test_Oct");                                test_Oct();
    Log_Header("test_line_iterator");                      test_line_iterator();
    Log_Header("test_append_padding");                     test_append_padding();
    Log_Header("test_utf8_iterator");                      test_utf8_iterator();
    Log_Header("test_parse_positive_number");              test_parse_positive_number();
    Log_Header("test_string_slices");                      test_string_slices();
    Log_Header("test_escape_as_json_string");              test_escape_as_json_string();
    Log_Header("test_msgpack_encode");                     test_msgpack_encode();
    Log_Header("test_msgpack_decode");                     test_msgpack_decode();
    Log_Header("test_mp_print");                           test_mp_print();
    Log_Header("test_mp_skip_value");                      test_mp_skip_value();
    Log_Header("test_coro_stack_alloc");                   test_coro_stack_alloc();
    Log_Header("test_coroutine");                          test_coroutine();
    Log_Header("test_bit_scan_forward");                   test_bit_scan_forward();
    Log_Header("test_binary_stuff");                       test_binary_stuff();
    Log_Header("test_for_each_bit");                       test_for_each_bit();
    Log_Header("test_shuffle");                            test_shuffle();
    Log_Header("test_my_split");                           test_my_split();
    Log_Header("test_to_upper_to_lower");                  test_to_upper_to_lower();
    Log_Header("test_string_to_enum");                     test_string_to_enum();
    Log_Header("test_print_utf32");                        test_print_utf32();

    elapsed := seconds_since_init() - t0;
    log("\e[32mall tests passed!\e[0m elapsed: %", fmt(elapsed, 6));
}

test_bit_scan_forward :: () {
    numbers := int.[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19];
    indexes := int.[0, 1, 2, 1, 3, 1, 2, 1, 4, 1,  2,  1,  3,  1,  2,  1,  5,  1,  2,  1];

    for number: numbers {
        index := bit_scan_forward(number);
        pretty_assert(index == indexes[it_index]);
    }
}

test_binary_stuff :: () {
    bin :: #bake_arguments binary(min_bits = 8);
    Inspect :: (x: $T) #expand {
        print("x & (x - 1) = % & % = %\n", bin(x), bin(x - 1), bin(x & (x - 1)));
    }

    for 1..16 Inspect(it.(u8));

    Inspect2 :: (x: $T) #expand {
        S :: #run to_signed(T);
        print("x & -x = % & % = %\n", bin(x), bin(-(x.(S, no_check))), bin(x & xx,no_check -(x.(S, no_check))));
    }

    for 1..16 Inspect2(it.(u8));
}

fmt :: inline (v: float64, digits_after_comma := -1, keep_zero := false) -> FormatFloat #expand {
    return FormatFloat.{ value = v, trailing_width = digits_after_comma, zero_removal = ifx keep_zero then .NO else .YES };
}

#import "Basic";
#import "Bit_Operations";
#import "Compiler";
#import "My_Util"(TEST=true);
#import "Msgpack"(TEST=true);
#import "Coroutine"(TEST=true);
