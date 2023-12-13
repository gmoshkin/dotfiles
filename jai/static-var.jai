#import "Basic";
#import "Compiler";

Static_Variable :: ($T: Type, $initial_value: T) -> *T #expand {
    return #run -> *T {
        v: T = initial_value;
        data := add_global_data(as_bytes(*v), .WRITABLE_NO_RESET);
        log("added global data: % (at %)", data, data.data);
        return xx data.data;
    };
}

Static_Variable :: ($initial_value: $T) -> *T #expand {
    return Static_Variable(T, initial_value);
}

as_bytes :: inline (v: *$T) -> [] u8 {
    bytes: [] u8 = ---;
    bytes.data = xx v;
    bytes.count = size_of(T);
    return bytes;
}

main :: () {
    use_static_variable();
    use_static_variable();
    use_static_variable();
    use_another_static_variable();
    use_another_static_variable();
    use_another_static_variable();
}

use_another_static_variable :: () {
    y := Static_Variable(s8, 0);
    z := Static_Variable(s8, -126);
    w := Static_Variable(s64, 314);
    y.* -= 1;
    z.* -= 1;
    w.* += 1;
    print("y is % (at %)\n", y.*, y);
    print("z is % (at %)\n", z.*, z);
    print("w is % (at %)\n", w.*, w);
}

use_static_variable :: () {
    x := Static_Variable(int, 0);
    x.* += 1;
    print("x is % (at %)\n", x.*, x);
}
