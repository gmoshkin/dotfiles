#module_parameters (TEST := false);

f32 :: float32;
f64 :: float64;

//
// bitwise operation utilities
//

lowest_set_bit :: inline (x: $T) -> T #no_aoc {
    S :: #run to_signed(T);
    return x & xx,no_check -(x.(S, no_check));
}

clear_lowest_set_bit :: inline (x: $T) -> T #no_aoc {
    return x & (x - 1);
}

for_each_bit :: (number: *$T, body: Code, flags: For_Flags) #expand {
    #assert !(flags & .POINTER);
    #assert !(flags & .REVERSE);
    I :: #run -> Type {
        if is_integer(T) return T;
        ok, type := enum_flags_type(type_info(T));
        assert(ok, "must be either integer or a enum_flags, got %", T);
        return type;
    };

    U :: #run to_unsigned(I);

    x := number.*.(U, no_check);

    index := 0;
    while x {
        defer index += 1;

        `it := lowest_set_bit(x).(T);
        `it_index := index;

        #insert body;

        x = clear_lowest_set_bit(x);
    }
}

binary :: (x: $T, min_bits := 1) -> string {
    bits: [size_of(T) * 8] u8;
    cursor := bits.count;

    U :: #run to_unsigned(T);
    n := x.(U, no_check);
    while n {
        cursor -= 1;
        bits[cursor] = xx ifx n & 1 then #char "1" else #char "0";
        n >>= 1;
    }

    leading_zeros := min_bits - (bits.count - cursor);
    if leading_zeros > 0 for 1..leading_zeros {
        cursor -= 1;
        bits[cursor] = xx #char "0";
    }

    return copy_string(xx array_view(bits, cursor));
}

#if TEST
test_for_each_bit :: () {

    pretty_assert(lowest_set_bit(Bin(10101)) == 1);
    pretty_assert(clear_lowest_set_bit(Bin(10101)) == Bin(10100));

    {
        array: [..] u64;
        for :for_each_bit Bin(10101) array_add(*array, it);
        pretty_assert(array_equals(array, u64.[Bin(00001), Bin(00100), Bin(10000)]));
    }

    pretty_assert(array_equals(
        map(Bin(11011011), for_each_bit, u64),
        u64.[
            Bin(00000001),
            Bin(00000010),
            Bin(00001000),
            Bin(00010000),
            Bin(01000000),
            Bin(10000000),
        ]));

    E :: enum_flags { A; B; C; D; E; F; G; H; };

    Check_E :: (e: E) -> [] E {
        array: [..] E;
        for :for_each_bit e array_add(*array, it);
        return array;
    }

    pretty_assert(array_equals(Check_E(0), E.[]));
    pretty_assert(array_equals(Check_E(.F), E.[.F]));
    pretty_assert(array_equals(Check_E(.H | .E), E.[.E, .H]));
    pretty_assert(array_equals(Check_E(.A | .C | .D | .G), E.[.A, .C, .D, .G]));
}

//
// type utilities
//

is_integer :: (T: Type) -> bool {
    return T == s8 || T == s16 || T == s32 || T == s64
        || T == u8 || T == u16 || T == u32 || T == u64;
}

to_unsigned :: inline ($T: Type) -> Type
#modify { return is_integer(T); }
{
    #if T == s8  || T == u8  return u8;
    #if T == s16 || T == u16 return u16;
    #if T == s32 || T == u32 return u32;
    #if T == s64 || T == u64 return u64;
    return void;
}

to_signed :: inline ($T: Type) -> Type
#modify { return is_integer(T); }
{
    #if T == s8  || T == u8  return s8;
    #if T == s16 || T == u16 return s16;
    #if T == s32 || T == u32 return s32;
    #if T == s64 || T == u64 return s64;
    return void;
}

enum_flags_type :: (base_info: *Type_Info) -> bool, Type {
    if base_info.type != .ENUM return false, void;
    info := base_info.(*Type_Info_Enum);
    if !(info.enum_type_flags & .FLAGS) return false, void;
    return true, to_type(info.internal_type);
}

to_type :: (info: *Type_Info_Integer) -> Type {
    if info.runtime_size == {
    case 1; return ifx info.signed then s8  else u8;
    case 2; return ifx info.signed then s16 else u16;
    case 4; return ifx info.signed then s32 else u32;
    case 8; return ifx info.signed then s64 else u64;
    }
    assert(false, "%", info.*);
    return void;
}

//
// random number generator utilities
//

shuffle :: (array: *[] $T) {
    N := array.count.(u64);
    if N <= 1 return;

    for 0..N - 1 {
        j := random_get() % N;
        swap(*array.*[it], *array.*[j]);
    }
}

#if TEST
test_shuffle :: () {
    original_array: [..] int; for 1..10 array_add(*original_array, it);

    shuffled_array := copy_array(original_array);
    shuffle(*shuffled_array);
    pretty_assert(!array_equals(shuffled_array, original_array));
    print("shuffled: %\n", shuffled_array);
    quick_sort(shuffled_array, (x) => x);
    pretty_assert(array_equals(shuffled_array, original_array));
}

pick :: (array: [] $T) -> T, int {
    i := random_get() % xx array.count;
    return array[i], xx i;
}

//
// array utilities
//

copy_array :: (array: [] $T) -> [] T {
    result := NewArray(array.count, T);
    for array result[it_index] = it;
    return result;
}

deep_copy_array :: (array: [] $T) -> [] T {
    result := NewArray(array.count, T);
    for array result[it_index] = deep_copy(it);
    return result;
}

deep_copy :: inline (v: string) -> string {
    return copy_string(v);
}

array_find :: inline (array: *[] $T, $predicate: (*T) -> bool) -> s64 {
    for *array if predicate(it) return it_index;
    return -1;
}

array_find :: inline (array: [] $T, $predicate: (T) -> bool) -> s64 {
    for array if predicate(it) return it_index;
    return -1;
}

contains :: inline (array: *[] $T, $predicate: (*T) -> bool) -> bool {
    return array_find(array, predicate) != -1;
}

contains :: inline (array: [] $T, $predicate: (T) -> bool) -> bool {
    return array_find(array, predicate) != -1;
}

array_equals :: (lhs: [] $T, rhs: [] T) -> bool {
    if lhs.count != rhs.count return false;

    for 0..lhs.count-1 {
        if lhs[it] != rhs[it] return false;
    }

    return true;
}

dynamic_memory_usage :: (array: [..] $T) -> s64 {
    return array.allocated * size_of(T);
}

advance :: inline (a: [] $T, amount: s64 = 1) -> [] T {
    assert(amount >= 0);
    assert(a.count >= amount);
    return .{ data = a.data + amount, count = a.count - amount };
}

advance :: inline (a: *[] $T, amount: s64 = 1) {
    assert(amount >= 0);
    assert(a.count >= amount);
    a.count -= amount;
    a.data  += amount;
}

last :: inline (array: [] $T) -> T {
    assert(array.count != 0);
    return array[array.count - 1];
}

last :: inline (array: *[] $T) -> *T {
    if array.*.count == 0 return null;
    return *array.*[array.*.count - 1];
}

//
// string utilities
//

NOT_SPECIFIED :: 0x7fff_ffff_ffff_ffff;
substring :: (s: string, start := 0, end := NOT_SPECIFIED, count := NOT_SPECIFIED) -> string {
    _count := count;
    _start := ifx start < 0 then s.count + start else start;
    if end == NOT_SPECIFIED && count == NOT_SPECIFIED {
        _count = s.count - _start;
    } else {
        assert(end == NOT_SPECIFIED || count == NOT_SPECIFIED);
        _end := ifx end < 0 then s.count + end else end;
        if count == NOT_SPECIFIED then _count = _end - _start;
    }
    assert(_start >= 0, "start: %, end: %, count: %", start, end, count);
    assert(_start <= s.count, "start: %, end: %, count: %", start, end, count);
    assert(_count >= 0, "start: %, end: %, count: %", start, end, count);
    assert(_start + _count <= s.count, "start: %, end: %, count: %", start, end, count);

    return string.{ data = s.data + _start, count = _count };
}

last :: inline (s: string) -> u8 {
    return s[s.count - 1];
}

count_matches :: (text: string, c: u8) -> s64 {
    count := 0;
    cursor := 0;
    while true {
        index := find_index_from_left(text, c, cursor);
        if index == -1 return count;
        count += 1;
        cursor = index + 1;
    }
    return 0;
}

contains_pointer :: inline (s: string, p: *u8) -> bool {
    return s.data <= p && p < s.data + s.count;
}

contains_pointer :: inline (a: [] $T, p: *T) -> bool {
    return a.data <= p && p < a.data + a.count;
}

is_subslice :: inline (outer: string, inner: string) -> bool {
    return (outer.data <= inner.data) && (inner.data + inner.count <= outer.data + outer.count);
}

string_range :: inline (s: string, start: int, end: int) -> string {
    return string.{end - start, s.data + start};
}

string_view :: inline (s: string, start: int, count: int) -> string {
    return string.{count, s.data + start};
}

#if TEST
test_string_slices :: () {
    s := "foo bar";
    {
        a := string_range(s, 4, 7);
        pretty_assert(a == "bar");
        assert(is_subslice(s, a));

        b := string_view(s, 4, 3);
        pretty_assert(b == "bar");
        assert(is_subslice(s, b));
    }
    {
        a := string_range(s, 0, 3);
        pretty_assert(a == "foo");
        assert(is_subslice(s, a));

        b := string_view(s, 0, 3);
        pretty_assert(b == "foo");
        assert(is_subslice(s, b));
    }
    {
        a := string_range(s, 2, 3);
        pretty_assert(a == "o");
        assert(is_subslice(s, a));

        b := string_view(s, 2, 1);
        pretty_assert(b == "o");
        assert(is_subslice(s, b));
    }
    {
        a := string_range(s, 2, 5);
        pretty_assert(a == "o b");
        assert(is_subslice(s, a));

        b := string_view(s, 2, 3);
        pretty_assert(b == "o b");
        assert(is_subslice(s, b));
    }
    {
        a := string_range(s, 7, 7);
        pretty_assert(a == "");
        assert(is_subslice(s, a));

        b := string_view(s, 7, 0);
        pretty_assert(b == "");
        assert(is_subslice(s, b));

        // I don'a like `slice`!
        assert(!is_subslice(s, slice(s, 7, 0)));
        //NOTE ^
    }
    {
        a := string_range(s, 0, 0);
        pretty_assert(a == "");
        assert(is_subslice(s, a));

        b := string_view(s, 0, 0);
        pretty_assert(b == "");
        assert(is_subslice(s, b));

        // I don't like `slice`!
        assert( is_subslice(s, slice(s, 0, 0)));
        //NOTE ^
    }
}

to_upper :: (s: string) -> string {
    t := copy_string(s);
    for *t it.* = to_upper(it.*);
    return t;
}

to_lower :: (s: string) -> string {
    t := copy_string(s);
    for *t it.* = to_lower(it.*);
    return t;
}

#if TEST
test_to_upper_to_lower :: () {
    pretty_assert(to_upper("aBcDe") == "ABCDE");
    pretty_assert(to_upper("") == "");
    pretty_assert(to_upper("FOO") == "FOO");
    pretty_assert(to_lower("aBcDe") == "abcde");
    pretty_assert(to_lower("") == "");
    pretty_assert(to_lower("bar") == "bar");
}


my_split :: (s: string, separator := " ") -> [] string {
    result: [..] string;

    tail := s;
    while tail {
        found:, left:, tail = split_from_left(tail, separator);
        if left array_add(*result, left);
    }

    return result;
}

#if TEST
test_my_split :: () {
    pretty_assert(array_equals(my_split("  a bc  def g  h "), string.["a", "bc", "def", "g", "h"]));
    pretty_assert(array_equals(my_split("  "), string.[]));
    pretty_assert(array_equals(my_split("   boo   "), string.["boo"]));
}

string_to_enum :: (s: string, $E: Type, $ignore_case := true) -> bool, E {
    #assert E.(*Type_Info).type == .ENUM;
    #if ignore_case {
        t := to_upper(s,, temp);
    }

    info := type_info(E);
    for info.names {
        #if ignore_case {
            match := (to_upper(it) == t);
        } else {
            match := (it == s);
        }
        if match return true, xx info.values[it_index];
    }

    return false, 0;
}

#if TEST
test_string_to_enum :: () {
    E :: enum { AAA; foo_bar; Baz; }
    {
        ok, e := string_to_enum("AAA", E, ignore_case=false);
        assert(ok);
        pretty_assert(e == E.AAA);
    }
    {
        ok, e := string_to_enum("foo_bar", E, ignore_case=false);
        assert(ok);
        pretty_assert(e == E.foo_bar);
    }
    {
        ok, e := string_to_enum("FOO_BAR", E, ignore_case=false);
        assert(!ok);
    }
    {
        ok, e := string_to_enum("FOO_BAR", E, ignore_case=true);
        assert(ok);
        pretty_assert(e == E.foo_bar);
    }
    {
        ok, e := string_to_enum("baz", E, ignore_case=false);
        assert(!ok);
    }
    {
        ok, e := string_to_enum("baz", E, ignore_case=true);
        assert(ok);
        pretty_assert(e == E.Baz);
    }
    {
        ok, e := string_to_enum("", E, ignore_case=false);
        assert(!ok);
    }
    {
        ok, e := string_to_enum("", E, ignore_case=true);
        assert(!ok);
    }
}

starts_with_ignoring_case :: (text: string, prefix: string) -> bool {
    if text.count < prefix.count return false;

    for prefix {
        if (inline to_lower(text[it_index])) != (inline to_lower(it)) return false;
    }

    return true;
}

parse_positive_number :: (text: string, $T: Type = int) -> T, tail: string
#modify { return T == u8 || T == u16 || T == u32 || T == u64 || T == s8 || T == s16 || T == s32 || T == s64; }
{
    if !text return 0, text;

    result: T = 0;
    cursor := 0;
    while cursor < text.count {
        d := text[cursor];
        if !inline is_digit(d) break;
        cursor += 1;
        result = result * 10 + (d - #char "0");
    }

    return result, advance(text, cursor);
}

#if TEST
test_parse_positive_number :: () {
    {
        n, tail := parse_positive_number("");
        pretty_assert(n == 0);
        pretty_assert(tail == "");
    }

    {
        n, tail := parse_positive_number("a");
        pretty_assert(n == 0);
        pretty_assert(tail == "a");
    }

    {
        n, tail := parse_positive_number("1");
        pretty_assert(n == 1);
        pretty_assert(tail == "");
    }

    {
        n, tail := parse_positive_number("2b");
        pretty_assert(n == 2);
        pretty_assert(tail == "b");
    }

    {
        n, tail := parse_positive_number("42069");
        pretty_assert(n == 42069);
        pretty_assert(tail == "");
    }
}

Bin :: ($n: Code) -> u64 #expand {
    return #run literal_to_integer(n, base=2);
}

Oct :: ($n: Code) -> u64 #expand {
    return #run literal_to_integer(n, base=8);
}

literal_to_integer :: (code: Code, base: u8) -> u64 {
    node := compiler_get_nodes(code);
    assert(node.kind == .LITERAL, "%", node.kind);
    literal := cast(*Code_Literal) node;
    assert(literal.value_type == .NUMBER, "%", literal.value_type);
    assert(!(literal.value_flags & .MINUS_SIGN), "%", literal.value_flags);

    octal, ok := decimal_to_other_base(literal._u64, base=base);
    assert(ok, "Failed to parse '%' as base % number", literal._u64, base);

    return octal;
}

decimal_to_other_base :: (decimal: u64, base: u8) -> (other_base: u64, ok: bool) {
    Max_Power_10: u64 : 10000000000000000000;

    if base > 10 return 0, false;

    out: u64 = 0;
    t := decimal;
    power := Max_Power_10;
    while power {
        d := (t / power) % 10;
        if d >= base return 0, false;

        power /= 10;

        out = out * base + d;
    }

    return out, true;
}

#if TEST
test_Bin :: () {
    pretty_assert(Bin(000) == 0);
    pretty_assert(Bin(001) == 1);
    pretty_assert(Bin(010) == 2);
    pretty_assert(Bin(101) == 5);
    pretty_assert(Bin(111) == 7);
    pretty_assert(Bin(110100101) == 421);
    pretty_assert(Bin(11010111010011000011) == 881859);
}

#if TEST
test_Oct :: () {
    pretty_assert(Oct(000) == 0);
    pretty_assert(Oct(001) == 1);
    pretty_assert(Oct(002) == 2);
    pretty_assert(Oct(010) == 8);
    pretty_assert(Oct(777) == 511);
    pretty_assert(Oct(231461471) == 40264505);
    pretty_assert(Oct(12345670123456701234) == 188231454092395164);
}

copy_string_with_nul :: (s: string) -> string {
    result := alloc_string(s.count + 1);
    memcpy(result.data, s.data, s.count);
    result[result.count - 1] = 0;
    result.count -= 1;
    return result;
}

copy_string_with_nul :: (p: *u8) -> string {
    s := to_string(p);
    result := alloc_string(s.count + 1);
    memcpy(result.data, s.data, s.count + 1);
    result.count -= 1;
    return result;
}

//
// lines iterator
//

lines :: (text: *string, body: Code, flags: For_Flags) #expand {
    #assert !(flags & .POINTER);
    #assert !(flags & .REVERSE);

    tail := text.*;
    index := 0;

    while tail {
        found:, line:, tail = split_from_left(tail, #char "\n");

        `it := line;
        `it_index := index;
        index += 1;

        #insert body;
    }
}

reverse_lines :: (text: *string, body: Code, flags: For_Flags) #expand {
    #assert !(flags & .POINTER);
    #assert !(flags & .REVERSE);

    head := text.*;
    if !head return;

    index := 0;
    found := false;
    first := true;

    while head || found {
        found=, head=, line := split_from_right(head, #char "\n");

        if first {
            first = false;
            // Skip first empty line (already checked the input is not empty)
            if !line continue;
        }

        `it := line;
        `it_index := index;
        index += 1;

        #insert body;
    }

    return;
}

words :: (text: *string, body: Code, flags: For_Flags) #expand {
    #assert !(flags & .POINTER);
    #assert !(flags & .REVERSE);

    tail := text.*;
    index := 0;
    while tail {
        found:, line:, tail = split_from_left_by_any(tail, " \t\n\r");
        if !line continue;

        `it := line;
        `it_index := index;
        index += 1;

        #insert body;
    }
}

map :: (text: string, $cb: #type (*string, Code, For_Flags), $T: Type) -> [] T {
    items: [..] T;

    for :cb text {
        array_add(*items, it);
    }

    return items;
}

map :: (text: u64, $cb: #type (*u64, Code, For_Flags), $T: Type) -> [] T {
    items: [..] T;

    for :cb text {
        array_add(*items, it);
    }

    return items;
}

#if TEST
test_line_iterator :: () {
    check_for_lines :: (s: string, $reverse := false) -> [] string, [] int {
        items: [..] string;
        items.allocator = temp;

        indexes: [..] int;
        indexes.allocator = temp;

        #if !reverse
            for :lines s {
                array_add(*items, it);
                array_add(*indexes, it_index);
            }
        else
            for :reverse_lines s {
                array_add(*items, it);
                array_add(*indexes, it_index);
            }

        return items, indexes;
    }

    items: [] string;
    indexes: [] int;

    items, indexes = check_for_lines("");
    pretty_assert(array_equals(items, string.[]));
    pretty_assert(array_equals(indexes, int.[]));

    items, indexes = check_for_lines("line1");
    pretty_assert(array_equals(items, string.["line1"]));
    pretty_assert(array_equals(indexes, int.[0]));

    items, indexes = check_for_lines("\n");
    pretty_assert(array_equals(items, string.[""]));
    pretty_assert(array_equals(indexes, int.[0]));

    items, indexes = check_for_lines("\n\n");
    pretty_assert(array_equals(items, string.["", ""]));
    pretty_assert(array_equals(indexes, int.[0, 1]));

    items, indexes = check_for_lines("line1\nline2\nline3\n");
    pretty_assert(array_equals(items, string.["line1", "line2", "line3"]));
    pretty_assert(array_equals(indexes, int.[0, 1, 2]));

    items, indexes = check_for_lines("\n\nline1\nline2\n\nline3\n\n");
    pretty_assert(array_equals(items, string.["", "", "line1", "line2", "", "line3", ""]));
    pretty_assert(array_equals(indexes, int.[0, 1, 2, 3, 4, 5, 6]));

    //
    // reverese
    //

    items, indexes = check_for_lines("", reverse=true);
    pretty_assert(array_equals(items, string.[]));
    pretty_assert(array_equals(indexes, int.[]));

    items, indexes = check_for_lines("line1", reverse=true);
    pretty_assert(array_equals(items, string.["line1"]));
    pretty_assert(array_equals(indexes, int.[0]));

    items, indexes = check_for_lines("\n", reverse=true);
    pretty_assert(array_equals(items, string.[""]));
    pretty_assert(array_equals(indexes, int.[0]));

    items, indexes = check_for_lines("\n\n", reverse=true);
    pretty_assert(array_equals(items, string.["", ""]));
    pretty_assert(array_equals(indexes, int.[0, 1]));

    items, indexes = check_for_lines("line1\nline2\nline3\n", reverse=true);
    pretty_assert(array_equals(items, string.["line3", "line2", "line1"]));
    pretty_assert(array_equals(indexes, int.[0, 1, 2]));

    items, indexes = check_for_lines("\n\nline1\nline2\n\nline3\n\n", reverse=true);
    pretty_assert(array_equals(items, string.["", "line3", "", "line2", "line1", "", ""]));
    pretty_assert(array_equals(indexes, int.[0, 1, 2, 3, 4, 5, 6]));

    check_for_words :: (s: string) -> [] string, [] int {
        items: [..] string;
        items.allocator = temp;

        indexes: [..] int;
        indexes.allocator = temp;

        for :words s {
            array_add(*items, it);
            array_add(*indexes, it_index);
        }

        return items, indexes;
    }

    items, indexes = check_for_words("");
    pretty_assert(array_equals(items, string.[]));
    pretty_assert(array_equals(indexes, int.[]));

    items, indexes = check_for_words("word1");
    pretty_assert(array_equals(items, string.["word1"]));
    pretty_assert(array_equals(indexes, int.[0]));

    items, indexes = check_for_words("\t ");
    pretty_assert(array_equals(items, string.[]));
    pretty_assert(array_equals(indexes, int.[]));

    items, indexes = check_for_words(" \n ");
    pretty_assert(array_equals(items, string.[]));
    pretty_assert(array_equals(indexes, int.[]));

    items, indexes = check_for_words("word1 word2 word3");
    pretty_assert(array_equals(items, string.["word1", "word2", "word3"]));
    pretty_assert(array_equals(indexes, int.[0, 1, 2]));

    items, indexes = check_for_words("  word1\tword2 \n word3  \n\r");
    pretty_assert(array_equals(items, string.["word1", "word2", "word3"]));
    pretty_assert(array_equals(indexes, int.[0, 1, 2]));

    items, indexes = check_for_words("  word1 ");
    pretty_assert(array_equals(items, string.["word1"]));
    pretty_assert(array_equals(indexes, int.[0]));

    pretty_assert(array_equals(map("foo\n\nbar", lines, string), string.["foo", "", "bar"]));
    pretty_assert(array_equals(map("foo\n\nbar", words, string), string.["foo", "bar"]));

}

//
// unicode utilities
//

utf8_count :: (utf8: string, $do_assert := true) -> s64, bool {
    count := 0;
    cursor := 0;
    while cursor < utf8.count {
        ofs := trailing_bytes_for_utf8[utf8[cursor]];
        cursor += ofs + 1;
        count += 1;
    }
    #if do_assert assert(cursor == utf8.count, "cursor: %, utf8:\n%", cursor, cast(Mem_Dump) utf8);

    return count, cursor == utf8.count;
}

utf8_substring :: (utf8: string, start: s64, count: s64 = -1, $do_assert := true) -> (string, utf8_count: s64) {
    assert(start >= 0);
    assert(count >= 0 || count == -1, "%", count);

    cursor := 0;
    for 1..start {
        if cursor >= utf8.count break;
        ofs := trailing_bytes_for_utf8[utf8[cursor]];
        cursor += ofs + 1;
    }

    start_cursor := cursor;
    utf8_count := 0;
    if count == -1 {
        cursor = utf8.count;
    } else while cursor < utf8.count && utf8_count < count {
        ofs := trailing_bytes_for_utf8[utf8[cursor]];
        cursor += ofs + 1;
        utf8_count += 1;
    }
    #if do_assert assert(cursor <= utf8.count, "cursor: %, utf8: '%'", cursor, utf8);

    result: string = ---;
    result.data = utf8.data + start_cursor;
    result.count = cursor - start_cursor;

    return result, utf8_count;
}

// Yoinked from modules/Unicode.jai
trailing_bytes_for_utf8 :: u8.[
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
	2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, 3,3,3,3,3,3,3,3,4,4,4,4,5,5,5,5
];

utf8 :: (utf8: *string, body: Code, flags: For_Flags) #expand {
    #assert !(flags & .POINTER);
    #assert !(flags & .REVERSE);

    text := utf8.*;

    count := 0;
    cursor := 0;
    while cursor < utf8.count {
        trail := trailing_bytes_for_utf8[text[cursor]];
        if cursor + trail >= utf8.count break;

        `it := slice(text, cursor, trail + 1);
        cursor += trail + 1;
        `it_index := count;
        count += 1;

        #insert body;
    }
}

first_byte_mask_for_utf8 :: u8.[ 0x7F, 0x1F, 0x0F, 0x07, 0x03, 0x01 ];

utf8_chars :: (utf8: *string, body: Code, flags: For_Flags) #expand {
    #assert !(flags & .POINTER);
    #assert !(flags & .REVERSE);

    text := utf8.*;

    count := 0;
    cursor := 0;
    char: s64;
    while cursor < utf8.count {
        trail := trailing_bytes_for_utf8[text[cursor]];
        if cursor + trail >= utf8.count break;

        char = text[cursor] & first_byte_mask_for_utf8[trail];
        cursor += 1;

        for 1..trail {
            char <<= 6;
            // TODO: should probably add error checking
            char |= text[cursor] & 0x3f;
            cursor += 1;
        }

        `it_index := count;
        `it := char;
        count += 1;

        #insert body;
    }
}

#if TEST
test_utf8_iterator :: () {
    strings: [] string;
    chars: [] s64;

    strings = map("Здравствуй, Мир!", utf8, string);
    pretty_assert(array_equals(strings, string.["З", "д", "р", "а", "в", "с", "т", "в", "у", "й", ",", " ", "М", "и", "р", "!"]));

    chars = map("Здравствуй, Мир!", utf8_chars, s64);
    pretty_assert(array_equals(chars, s64.[1047, 1076, 1088, 1072, 1074, 1089, 1090, 1074, 1091, 1081, 44, 32, 1052, 1080, 1088, 33]));


    strings = map("╭⢾▄⡓╮", utf8, string);
    pretty_assert(array_equals(strings, string.["╭", "⢾", "▄", "⡓", "╮"]));

    chars = map("╭⢾▄⡓╮", utf8_chars, s64);
    pretty_assert(array_equals(chars, s64.[9581, 10430, 9604, 10323, 9582]));


    strings = map("🝏🞅Πツ", utf8, string);
    pretty_assert(array_equals(strings, string.["🝏", "🞅", "Π", "ツ"]));

    chars = map("🝏🞅Πツ", utf8_chars, s64);
    pretty_assert(array_equals(chars, s64.[128847, 128901, 928, 12484]));

}

//
// string builder utilities
//

to_string :: inline (buffer: *String_Builder.Buffer) -> string {
    return string.{ data = get_buffer_data(buffer), count = buffer.count };
}

append_padding :: inline (builder: *String_Builder, count: s64, $padding := " ") {
    assert(count >= 0, "%", count);
    #assert(padding.count == 1); // TODO: it's pretty easy actually to support other counts
    global_buffer :: #run -> string {
        buffer: [] u8;
        buffer.count = 64;
        buffer.data = alloc(buffer.count);
        for *buffer it.* = padding[0];
        return xx add_global_data(buffer, .READ_ONLY);
    };

    n_repeats := count / global_buffer.count;
    for 1..n_repeats {
        append(builder, global_buffer);
    }

    tail := global_buffer;
    tail.count = count % global_buffer.count;
    append(builder, tail);
}

#if OS == .LINUX || OS == .MACOS
write_builder :: (fd: s32, using builder: *String_Builder, do_reset := true) -> s64 {
    buffer  := get_base_buffer(builder);
    written := 0;
    while buffer {
        s: string = ---;
        s.data  = get_buffer_data(buffer);
        s.count = buffer.count;

        while true {
            rc := write(fd, s.data, xx s.count);
            if rc < 0 {
                code := System.get_error_value();
                if code == EINTR continue;

                return rc;
            }

            written += rc;
            advance(*s, rc);

            if s.count == 0 break;
        }

        buffer = buffer.next;
    }

    if do_reset reset(builder);

    return written;
}

#if TEST
test_append_padding :: () {
    Check :: ($n: int, $padding: string) #expand {
        builder: String_Builder;
        append_padding(*builder, n, padding);
        s := builder_to_string(*builder);
        assert(s.count == n);
        for cast([] u8) s assert(it == padding[0]);
    }

    Check(3, " ");
    Check(65, " ");
    Check(64 * 7 + 13, " ");
    Check(3, "!");
    Check(65, "2");
    Check(64 * 7 + 13, "@");
}

//
// Appends the contents of a json string -- what goes between the quotes, which
// the caller writes itself.
//
// Not to be confused with print_ascii_or_hex below, which is a byte dump for
// looking at with your eyes: it writes anything unprintable as `\xe2`, and json
// has no such escape, so a single em dash in the output is enough to make the
// whole document unparseable for whoever we hand it to. A json string is utf8,
// so a character above ascii is written as itself.
//
escape_as_json_string :: (builder: *String_Builder, s: string) {
    cursor := 0;
    while cursor < s.count {
        char := s[cursor];

        if char == #char "\"" || char == #char "\\" {
            append(builder, #char "\\");
            append(builder, char);
            cursor += 1;
            continue;
        }

        if char < 0x20 {
            // The three worth being able to recognise on sight. Json spells \b
            // and \f the same way, but nobody reads those, so they can go
            // through the numeric escape that covers every control character.
            if char == {
                case #char "\n"; append(builder, "\\n");
                case #char "\t"; append(builder, "\\t");
                case #char "\r"; append(builder, "\\r");
                case;
                    print_to_builder(builder, "\\u%", FormatInt.{ value = char, base = 16, minimum_digits = 4 });
            }
            cursor += 1;
            continue;
        }

        if char < 0x80 {
            append(builder, char);
            cursor += 1;
            continue;
        }

        //
        // The text is not guaranteed to be well-formed utf8 -- a terminal line
        // caught halfway through being redrawn, a binary file cat'ed by mistake
        // -- and a single stray byte passed on would make the document
        // undecodable again, which is the whole failure this is here to avoid.
        // So anything that is not a character becomes the replacement one,
        // written as an escape so that the output stays ascii either way.
        //
        trailing := trailing_bytes_for_utf8[char];
        valid := trailing > 0 && cursor + trailing < s.count;
        if valid {
            for 1..trailing {
                if (s[cursor + it] & 0xc0) != 0x80 { valid = false; break; }
            }
        }

        if !valid {
            append(builder, "\\ufffd");
            cursor += 1;
            continue;
        }

        append(builder, slice(s, cursor, trailing + 1));
        cursor += trailing + 1;
    }
}

#if TEST
test_escape_as_json_string :: () {
    Check :: (input: string, expected: string) {
        builder: String_Builder;
        escape_as_json_string(*builder, input);
        result := builder_to_string(*builder);
        pretty_assert(result == expected);
    }

    Check("", "");
    Check("plain text", "plain text");

    // The two characters json spells with a backslash
    Check("say \"hi\"", "say \\\"hi\\\"");
    Check("C:\\Program Files", "C:\\\\Program Files");

    // Control characters: the three we spell out, and the rest
    Check("tab\there", "tab\\there");
    Check("two\nlines", "two\\nlines");
    Check("cr\rlf\n", "cr\\rlf\\n");
    Check("bell\x07 and \x1b[0m", "bell\\u0007 and \\u001b[0m");

    // Characters above ascii go through untouched, one, two, three and four
    // bytes wide
    Check("em dash — here", "em dash — here");
    Check("naïve Ω 😀", "naïve Ω 😀");

    // ... and anything that isn't a character does not
    Check("\x80", "\\ufffd");                     // a continuation byte on its own
    Check("bad \xff byte", "bad \\ufffd byte");   // never valid utf8 anywhere
    Check("cut \xe2\x80", "cut \\ufffd\\ufffd");  // a sequence the text ends in the middle of
    Check("\xe2(\xa1", "\\ufffd(\\ufffd");        // a lead byte whose continuations aren't
}

print_ascii_or_hex :: (builder: *String_Builder, s: string) {
    for 0..s.count-1 {
        char := s[it];
        if char >= #char " " && char <= #char "~" {
            if char == #char "\\" || char == #char "\""
                append(builder, "\\");
            append(builder, char);
        } else {
            print_to_builder(builder, "\\x%", FormatInt.{ value = char, base = 16, minimum_digits = 2 });
        }
    }
}

print_ascii_or_hex :: inline (builder: *String_Builder, char: u8) {
    s: [1] u8 = .[char];
    print_ascii_or_hex(builder, cast(string) s);
}

parse_ascii_or_hex :: (input: string) -> string, ok: bool {
    result: string;
    result.data = alloc(input.count);
    result.count = input.count;

    success := false;
    defer if !success free(result);

    write_cursor := 0;
    defer result.count = write_cursor;

    read_cursor := 0;
    while read_cursor < input.count {
        back_slash := find_index_from_left(input, #char "\\", read_cursor);
        if back_slash == -1 then back_slash = input.count;

        n_to_copy := back_slash - read_cursor;
        memcpy(result.data + write_cursor, input.data + read_cursor, n_to_copy);
        write_cursor += n_to_copy;

        if back_slash == input.count break;

        read_cursor = back_slash + 1;
        if read_cursor >= input.count { return "", false; }

        c := input[read_cursor]; read_cursor += 1;
        if c == #char "\\" || c == #char "\"" {
            result[write_cursor] = c; write_cursor += 1; continue;
        }

        if c == {
            case #char "e"; result[write_cursor] = #char "\e"; write_cursor += 1; continue;
            case #char "n"; result[write_cursor] = #char "\n"; write_cursor += 1; continue;
            case #char "r"; result[write_cursor] = #char "\r"; write_cursor += 1; continue;
            case #char "t"; result[write_cursor] = #char "\t"; write_cursor += 1; continue;
        }

        if c == #char "x" {
            if read_cursor > input.count - 2 { return "", false; }
            l := input[read_cursor]; read_cursor += 1;
            h := input[read_cursor]; read_cursor += 1;

            l = inline hex_digit(l); if l > 0xf return "", false;
            h = inline hex_digit(h); if h > 0xf return "", false;

            result[write_cursor] = (l << 4) + h;
            write_cursor += 1;
            continue;
        }

        return "", false;

    }

    result.count = write_cursor;
    success = true;
    return result, true;
}

hex_digit :: inline (c: u8) -> u8 {
    if c >= #char "0" && c <= #char "9" return c - #char "0";
    if c >= #char "a" && c <= #char "f" return c - #char "a" + 10;
    if c >= #char "A" && c <= #char "F" return c - #char "A" + 10;
    return 0xff;
}

//
// ascii escape sequence handling
//

eat_visible_or_escape_sequence :: (text: string) -> head: string, visible_count: s64, tail: string {
    if !text return "", 0, "";

    count := find_index_from_left(text, #char "\e");
    if count < 0 then count = text.count;

    if count > 0 {
        // Visible character sequence
        head := substring(text, 0, count = count);
        tail := substring(text, count);

        // FIXME: this is a temporary solution probably...
        backspaces_count := count_matches(head, #char "\x08"); // '\b' in C

        return head, count - backspaces_count * 2, tail;
    }

    // Escape sequence
    count += 1;

    if count < text.count {
        char := text[count];
        if char == #char "[" {
            count += 1;
            while count < text.count {
                char = text[count];
                count += 1;

                if inline is_alpha(char) break;
            }
        } else {
            // TODO: don't care about other escape codes for now
        }
    }

    head := slice(text, 0, count);
    tail := advance(text, count);
    return head, 0, tail;
}

// FIXME: support utf8 code points
count_visible_characters :: (text: string) -> visible_count: s64 {
    if !text return 0;

    visible_count := 0;
    cursor := 0;
    while cursor < text.count {
        index := find_index_from_left(text, #char "\e", cursor);
        if index < 0 return visible_count + utf8_count(substring(text, cursor));

        visible_count += utf8_count(substring(text, cursor, index));
        cursor = index + 1; // `+ 1` to skip the current "\e"

        char := text[cursor];
        if char == #char "[" {
            cursor += 1;
            while cursor < text.count {
                char = text[cursor];
                cursor += 1;

                if char == #char "m" break;
            }
        } else {
            // TODO: don't care about other escape codes for now
        }
    }
    return visible_count;
}

only_visible_text :: (text_with_control_codes: string) -> string {
    builder: String_Builder;
    builder.allocator = temp;

    tail := text_with_control_codes;
    while tail {
        head:, visible_count:, tail = eat_visible_or_escape_sequence(tail);
        if visible_count append(*builder, head);
    }

    return builder_to_string(*builder);
}

//
// date & time utilities
//

print_date_time_for_humans :: (date_time: Calendar_Time) {
    builder: String_Builder;
    builder.allocator = temp;
    print_date_time_for_humans(*builder, date_time);
    write_builder(*builder);
}

print_date_for_humans :: (builder: *String_Builder, date_time: Calendar_Time) {
    month_short :: string.["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    print(builder, "% %", month_short[date_time.month_starting_at_0],
                          date_time.day_of_month_starting_at_0 + 1);
}

print_time_for_humans :: (builder: *String_Builder, date_time: Calendar_Time) {
    print(builder, "%:%:%", FormatInt.{value = date_time.hour,   minimum_digits = 2},
                            FormatInt.{value = date_time.minute, minimum_digits = 2},
                            FormatInt.{value = date_time.second, minimum_digits = 2});
}

print_date_time_for_humans :: (builder: *String_Builder, date_time: Calendar_Time) {
    inline print_date_for_humans(builder, date_time);
    append(builder, " ");
    inline print_time_for_humans(builder, date_time);
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

//
// pretty assert
//

// Constant structs don't work with compile time constructs yet, so we return
// all fields directly
get_expr_info :: (code: Code) -> kind: Code_Node.Kind, op_type: Operator_Type, full_expr: string, proc_expr: string, lhs: Code, rhs: Code {
    #import "Program_Print";

    root := compiler_get_nodes(code);

    builder: String_Builder;
    print_expression(*builder, root);
    full_expr := builder_to_string(*builder);

    if root.kind == {
        case .BINARY_OPERATOR;
            binop := cast(*Code_Binary_Operator) root;
            op_type := binop.operator_type;
            lhs := compiler_get_code(binop.left, code);
            rhs := compiler_get_code(binop.right, code);
            return xx root.kind, op_type, full_expr, "", lhs, rhs;

        case .PROCEDURE_CALL;
            proccall := cast(*Code_Procedure_Call) root;
            if proccall.arguments_sorted.count != 2 {
                dummy : Code = #code null;
                return xx root.kind, -1, full_expr, "", dummy, dummy;
            }

            builder: String_Builder;
            print_expression(*builder, proccall.procedure_expression);
            proc_expr := builder_to_string(*builder);

            lhs := compiler_get_code(proccall.arguments_sorted[0], code);
            rhs := compiler_get_code(proccall.arguments_sorted[1], code);
            return xx root.kind, -1, full_expr, proc_expr, lhs, rhs;

        case;

    }

    dummy : Code = #code null;
    return xx root.kind, -1, full_expr, "", dummy, dummy;
}

pretty_assert :: (code: Code, loc := #caller_location) #expand {
    if #insert code return;

    if context.handling_assertion_failure  return;  // Avoid infinite loops.
    context.handling_assertion_failure = true;

    kind, op_type, full_expr, proc_expr, lhs, rhs :: #run get_expr_info(code);

    message := "";

    #if kind == .BINARY_OPERATOR {
        builder : String_Builder;
        builder.allocator = temporary_allocator;

        print_to_builder(*builder, "(%) :: (% ", full_expr, #insert lhs);

        if op_type < 128 {
            append(*builder, cast(u8) op_type);
        } else {
            append(*builder, operator_to_string(xx op_type));
        }

        print_to_builder(*builder, " %) :: false", #insert rhs);
        message = builder_to_string(*builder,, temporary_allocator);
    } else #if kind == .PROCEDURE_CALL {
        l := tprint("%", #insert lhs);
        r := tprint("%", #insert rhs);
        if l.count > 40 {
            message = tprint("(\n    %\n) :: (\n    %(\n        %,\n        %\n    )\n) :: false", full_expr, proc_expr, #insert lhs, #insert rhs);
        } else {
            message = tprint("(%) :: (%(%, %)) :: false", full_expr, proc_expr, #insert lhs, #insert rhs);
        }
    } else {
        message = tprint("(%) = false", full_expr);
    }

    // We provide 'loc' in case _STACK_TRACE is turned off, but assertion_failed may well
    // look at the stack trace if it is available.
    context.assertion_failed(loc, message);
    debug_break();
    context.handling_assertion_failure = false;

} @NoProfile

//
// Mem_Dump
//

Setup_Mem_Dump_Printer :: () #expand {
    old_struct_printer := context.print_style.struct_printer;
    `defer context.print_style.struct_printer = old_struct_printer;
    context.print_style.struct_printer = mem_dump_printer;
}

Mem_Dump :: #type,distinct [] u8;
mem_dump_printer :: (builder: *String_Builder, any: Any, data: *void) -> handled: bool {
    if any.type != type_info(Mem_Dump) return false;

    data := cast(*[] u8, any.value_pointer).*;
    mem_dump_to_builder(builder, data);
    return true;
}

mem_dump_to_builder :: (builder: *String_Builder, data: [] u8) {
    old_default_format_int := context.print_style.default_format_int;
    defer context.print_style.default_format_int = old_default_format_int;
    context.print_style.default_format_int = FormatInt.{ base = 16, minimum_digits = 2 };

    leading_spaces := cast(s64) (cast(u64) data.data) % 16;
    start_addr := cast(* u8) (cast(u64) data.data) & 0xffff_ffff_ffff_fff0;

    print_to_builder(builder, "%: ", start_addr);
    for 0..(data.count + leading_spaces - 1) {
        if it < leading_spaces then
            append(builder, "  ");
        else
            print_to_builder(builder, "%", data[it - leading_spaces]);

        if (it + 1) % 16 == 0 && it + 1 != data.count + leading_spaces
            print_to_builder(builder, "\n%: ", start_addr + it + 1);
        else if (it + 1) % 4 == 0
            append(builder, " ");
    }
}

//
// flat pool utilities
//

flat_pool_allocated :: (pool: *Flat_Pool) -> s64 {
    return pool.current_point - pool.memory_base;
}

//
// color
//

// stolen from modules/GetRect/module.jai
rgb_to_hsv :: (r: float, g: float, b: float) -> (h: float, s: float, v: float) {
    rgb_min := min(r, g, b);
    rgb_max := max(r, g, b);

    if rgb_max == 0  return 0, 0, 0;

    v := rgb_max;

    delta := rgb_max - rgb_min;

    s := delta / rgb_max;
    if s == 0 {  // This covers the case when rgb_max == rgb_min, so we don't worry about dividing by 0 below.
        return 0, 0, v;
    }

    h: float = ---;
    K :: (43/255.0);
    if rgb_max == r
        h = 0 + K * (g - b) / delta;
    else if rgb_max == g
        h = (85/255.0) + K * (b - r) / delta;
    else
        h = (171/255.0) + K * (r - g) / delta;

    return h*360, s, v;
}

//
// private imports
//

#scope_module

#if OS == .LINUX {
    libc :: #library,system "libc";
    sysconf :: (name: s32) -> s64 #foreign libc;
}

#import "Basic";
#import "String";
#import "Compiler";
#import "Flat_Pool";
#import "My_File";
#import "Random";
#import "Sort";
System :: #import "System";
#if OS == .LINUX || OS == .MACOS #import "POSIX";
