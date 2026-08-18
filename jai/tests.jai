main :: () {
    t0 := seconds_since_init();
    log("\e[32mRunning tests...\e[0m");

    Log_Header :: (test: string) #expand {
        log("\n# \e[35m%\e[0m\n\n", test);
    }

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

    elapsed := seconds_since_init() - t0;
    log("\e[32mall tests passed!\e[0m elapsed: %", fmt(elapsed, 6));
}

fmt :: inline (v: float64, digits_after_comma := -1, keep_zero := false) -> FormatFloat #expand {
    return FormatFloat.{ value = v, trailing_width = digits_after_comma, zero_removal = ifx keep_zero then .NO else .YES };
}

#import "Basic";
#import "My_Util"(TEST=true);
#import "Msgpack"(TEST=true);
