main :: () {
    args := get_command_line_arguments();

    if args.count < 2 {
        print("expected a variable name as parameter\n", to_standard_error=true);
        exit(1);
    }

    variable_name := args[1];

    value := getenv(to_c_string(variable_name));
    if !value {
        print("variable '%' is not set\n", variable_name, to_standard_error=true);
        exit(1);
    }

    print("%\n", to_string(value));
}

#import "Basic";
#import "Windows";
