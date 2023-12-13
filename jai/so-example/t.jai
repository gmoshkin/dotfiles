get_my_favourite_value :: ($T: Type) -> T {
    // ti :: #run type_info(T);
    // if ti_t.type == {
    //     case .INTEGER;
    //         return 69;
    //     case .STRING;
    //         return "nice";
    // }
// }

// get_my_favourite_value :: ($T: Type) -> T {
    ti_type :: #run type_info(T).type;
    #if ti_type == .INTEGER {
        return 69;
    } else #if ti_type == .STRING {
        return "nice";
    }
}

main :: () {
    log("my favorite int is %", get_my_favourite_value(int));
    log("my favorite string is %", get_my_favourite_value(string));

    log("%", FormatInt.{ value = cast(u8) 0x7f, base = 2, minimum_digits = 8 });
    log("%", FormatInt.{ value = cast,no_check(u8) -0x7f, base = 2, minimum_digits = 8 });
    log("%", FormatInt.{ value = cast,no_check(u8) -2, base = 2, minimum_digits = 8  });
}

#import "Basic";
