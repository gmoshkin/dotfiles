main :: () {
    S :: struct @"Hey, that's pretty good!" @boo { f: int; @"Hey" } @Yo;
    ti := type_info(S);
    log("%", ti.notes);
}

#import "Basic";
