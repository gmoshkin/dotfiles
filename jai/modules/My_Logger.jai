//
// logging
//

my_logger :: (message: string, data: *void, info: Log_Info) {
    builder: String_Builder;
    builder.allocator = temp;

    if info.common_flags & .ERROR   print(*builder, "\e[31m");
    if info.common_flags & .WARNING print(*builder, "\e[33m");

    print_time_for_log(*builder, to_calendar(current_time_consensus(), .LOCAL));
    append(*builder, " ");
    // print(*builder, "% ", frame_counter);
    if #compile_time print(*builder, "#compile_time ");

    if info.location.fully_pathed_filename {
        filename := path_filename(info.location.fully_pathed_filename);
        print(*builder, "[%:%] %\n", filename, info.location.line_number, message);
    } else {
        print(*builder, "%\n", message);
    }

    if info.common_flags & (.ERROR | .WARNING) print(*builder, "\e[0m");

    write_builder(*builder);
}

print_time_for_log :: (builder: *String_Builder, date_time: Calendar_Time) {
    using date_time;
    print(builder, "%:%:%.%", FormatInt.{value = hour,        minimum_digits = 2},
                              FormatInt.{value = minute,      minimum_digits = 2},
                              FormatInt.{value = second,      minimum_digits = 2},
                              FormatInt.{value = millisecond, minimum_digits = 3});
}

print_date_time_for_log :: (builder: *String_Builder, date_time: Calendar_Time) {
    using date_time;
    print(builder, "%-%-% %:%:%.%", year,
                                    FormatInt.{value = month_starting_at_0 + 1,        minimum_digits = 2},
                                    FormatInt.{value = day_of_month_starting_at_0 + 1, minimum_digits = 2},
                                    FormatInt.{value = hour,                           minimum_digits = 2},
                                    FormatInt.{value = minute,                         minimum_digits = 2},
                                    FormatInt.{value = second,                         minimum_digits = 2},
                                    FormatInt.{value = millisecond,                    minimum_digits = 3});
}

#import "Basic";
#import "String";
