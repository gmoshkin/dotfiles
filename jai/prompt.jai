#import "Basic";
#import "String";

Color :: struct {
    Reset   :: "[00m";
    Black   :: "[30m";
    Red     :: "[31m";
    Green   :: "[32m";
    Yellow  :: "[33m";
    Blue    :: "[34m";
    Magenta :: "[35m";
    Cyan    :: "[36m";
    White1  :: "[37m";
    Orange  :: "[91m";
    Gray01  :: "[92m";
    Gray02  :: "[93m";
    Gray03  :: "[94m";
    Purple  :: "[95m";
    Gray04  :: "[96m";
    White2  :: "[97m";
}

main :: () {
    args := get_command_line_arguments();
    
    if args.count < 5 {
        print("Usage: prompt <width> <username> <hostname> <pwd> <date...>\n");
        return;
    }
    
    width_str := args[1];
    username := args[2];
    hostname := args[3];
    pwd := args[4];
    
    // Join the remaining arguments for date
    date_builder: String_Builder;
    for i: 5..args.count-1 {
        if i > 5 then append(*date_builder, " ");
        append(*date_builder, args[i]);
    }
    date := builder_to_string(*date_builder);
    defer free(date);
    
    width, success := string_to_int(width_str);
    if !success {
        print("Error: width must be an integer\n");
        return;
    }
    
    sep_color := Color.Reset;
    pwd_color := Color.Blue;
    uname_color := Color.Green;
    hname_color := Color.Yellow;
    date_color := Color.Green;
    colon_color := Color.Reset;
    dollar_color := Color.Reset;
    reset_color := Color.Reset;
    
    // Build left part
    left_builder: String_Builder;
    append(*left_builder, sep_color);
    append(*left_builder, "╭");
    append(*left_builder, "(");
    append(*left_builder, uname_color);
    append(*left_builder, username);
    append(*left_builder, "@");
    append(*left_builder, hname_color);
    append(*left_builder, hostname);
    append(*left_builder, colon_color);
    append(*left_builder, ":");
    append(*left_builder, pwd_color);
    append(*left_builder, pwd);
    append(*left_builder, sep_color);
    append(*left_builder, ")");
    left := builder_to_string(*left_builder);
    defer free(left);
    
    // Build right part
    right_builder: String_Builder;
    append(*right_builder, sep_color);
    append(*right_builder, "(");
    append(*right_builder, date_color);
    append(*right_builder, date);
    append(*right_builder, sep_color);
    append(*right_builder, ")");
    right := builder_to_string(*right_builder);
    defer free(right);
    
    // Calculate filler width
    // In Jai, we need to count UTF-8 characters properly
    left_display_length := utf8_length(left);
    right_display_length := utf8_length(right);
    
    filler_width := width;
    filler_width -= left_display_length;
    filler_width -= right_display_length;
    filler_width += 9 * Color.Reset.count; // Add back ANSI escape sequence length
    
    // Build filler
    filler_builder: String_Builder;
    append(*filler_builder, sep_color);
    for i: 0..filler_width-1 {
        append(*filler_builder, "─");
    }
    filler := builder_to_string(*filler_builder);
    defer free(filler);
    
    // Build prompt
    prompt_builder: String_Builder;
    append(*prompt_builder, sep_color);
    append(*prompt_builder, "╰");
    append(*prompt_builder, dollar_color);
    append(*prompt_builder, "$");
    append(*prompt_builder, reset_color);
    prompt := builder_to_string(*prompt_builder);
    defer free(prompt);
    
    // Build status line
    status_line_builder: String_Builder;
    append(*status_line_builder, left);
    append(*status_line_builder, filler);
    append(*status_line_builder, right);
    status_line := builder_to_string(*status_line_builder);
    defer free(status_line);
    
    // Print output
    print("%\n", status_line);
    print("%\n", prompt);
}

// Helper function to count UTF-8 characters (not bytes)
utf8_length :: (s: string) -> int {
    count := 0;
    i := 0;
    while i < s.count {
        if s[i] & 0x80 == 0 {
            // ASCII character
            i += 1;
        } else if s[i] & 0xe0 == 0xc0 {
            // 2-byte UTF-8 character
            i += 2;
        } else if s[i] & 0xf0 == 0xe0 {
            // 3-byte UTF-8 character
            i += 3;
        } else if s[i] & 0xf8 == 0xf0 {
            // 4-byte UTF-8 character
            i += 4;
        } else {
            // Invalid UTF-8, skip
            i += 1;
        }
        count += 1;
    }
    return count;
}