MP_MARKER :: enum u8 {
    FIXPOSINT :: 0x00;
    FIXMAP    :: 0x80;
    FIXARR    :: 0x90;
    FIXSTR    :: 0xa0;

    NIL    :: 0xc0;
    UNUSED :: 0xc1;
    FALSE  :: 0xc2;
    TRUE   :: 0xc3;

    BIN8  :: 0xc4;
    BIN16 :: 0xc5;
    BIN32 :: 0xc6;

    EXT8  :: 0xc7;
    EXT16 :: 0xc8;
    EXT32 :: 0xc9;

    FLOAT32 :: 0xca;
    FLOAT64 :: 0xcb;

    UINT8  :: 0xcc;
    UINT16 :: 0xcd;
    UINT32 :: 0xce;
    UINT64 :: 0xcf;

    INT8  :: 0xd0;
    INT16 :: 0xd1;
    INT32 :: 0xd2;
    INT64 :: 0xd3;

    FIXEXT1  :: 0xd4;
    FIXEXT2  :: 0xd5;
    FIXEXT4  :: 0xd6;
    FIXEXT8  :: 0xd7;
    FIXEXT16 :: 0xd8;

    STR8  :: 0xd9;
    STR16 :: 0xda;
    STR32 :: 0xdb;

    ARR16 :: 0xdc;
    ARR32 :: 0xdd;

    MAP16 :: 0xde;
    MAP32 :: 0xdf;

    FIXNEGINT :: 0xe0;
};

MP_MARKER_TABLE :: MP_MARKER.[
    // 0x00..0x7f
    .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT,
    .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT,
    .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT,
    .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT,
    .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT,
    .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT,
    .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT,
    .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT,
    .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT,
    .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT,
    .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT,
    .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT,
    .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT,
    .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT,
    .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT,
    .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT, .FIXPOSINT,
    // 0x80..0x8f
    .FIXMAP, .FIXMAP, .FIXMAP, .FIXMAP, .FIXMAP, .FIXMAP, .FIXMAP, .FIXMAP,
    .FIXMAP, .FIXMAP, .FIXMAP, .FIXMAP, .FIXMAP, .FIXMAP, .FIXMAP, .FIXMAP,
    // 0x90..0x9f
    .FIXARR, .FIXARR, .FIXARR, .FIXARR, .FIXARR, .FIXARR, .FIXARR, .FIXARR,
    .FIXARR, .FIXARR, .FIXARR, .FIXARR, .FIXARR, .FIXARR, .FIXARR, .FIXARR,
    // 0xa0..0xbf
    .FIXSTR, .FIXSTR, .FIXSTR, .FIXSTR, .FIXSTR, .FIXSTR, .FIXSTR, .FIXSTR,
    .FIXSTR, .FIXSTR, .FIXSTR, .FIXSTR, .FIXSTR, .FIXSTR, .FIXSTR, .FIXSTR,
    .FIXSTR, .FIXSTR, .FIXSTR, .FIXSTR, .FIXSTR, .FIXSTR, .FIXSTR, .FIXSTR,
    .FIXSTR, .FIXSTR, .FIXSTR, .FIXSTR, .FIXSTR, .FIXSTR, .FIXSTR, .FIXSTR,

    // 0xc0, 0xc1, 0xc2, 0xc3
    .NIL,     .UNUSED,  .FALSE,   .TRUE,

    // 0xc4..0xc9
    .BIN8,    .BIN16,   .BIN32,
    .EXT8,    .EXT16,   .EXT32,

    // 0xca, 0xcb
    .FLOAT32, .FLOAT64,
    // 0xcc..0xcf
    .UINT8,   .UINT16,  .UINT32,  .UINT64,
    // 0xd0..0xd3
    .INT8,    .INT16,   .INT32,   .INT64,

    // 0xd4..0xd8
    .FIXEXT1, .FIXEXT2, .FIXEXT4, .FIXEXT8, .FIXEXT16,
    // 0xd9, 0xda, 0xdb
    .STR8,    .STR16,   .STR32,
    // 0xdc, 0xdd
    .ARR16,   .ARR32,
    // 0xde, 0xdf
    .MAP16,   .MAP32,

    // 0xe0..0xff
    .FIXNEGINT, .FIXNEGINT, .FIXNEGINT, .FIXNEGINT, .FIXNEGINT, .FIXNEGINT, .FIXNEGINT, .FIXNEGINT,
    .FIXNEGINT, .FIXNEGINT, .FIXNEGINT, .FIXNEGINT, .FIXNEGINT, .FIXNEGINT, .FIXNEGINT, .FIXNEGINT,
    .FIXNEGINT, .FIXNEGINT, .FIXNEGINT, .FIXNEGINT, .FIXNEGINT, .FIXNEGINT, .FIXNEGINT, .FIXNEGINT,
    .FIXNEGINT, .FIXNEGINT, .FIXNEGINT, .FIXNEGINT, .FIXNEGINT, .FIXNEGINT, .FIXNEGINT, .FIXNEGINT,
];

#assert MP_MARKER_TABLE.count == 256;

////////////////////////////////////////////////////////////////////////////////
// msgpack encode
////////////////////////////////////////////////////////////////////////////////

mp_encode_to_builder :: (builder: *String_Builder, x: $T) #expand {
    type_tag :: #run type_info(T).type;
    #if type_tag == .ANY {
        mp_encode_any_to_builder(builder, x);
    } else #if type_tag == .STRING {
        mp_encode_string_to_builder(builder, x);
    } else #if type_tag == .BOOL {
        mp_encode_bool_to_builder(builder, x);
    } else #if type_tag == .VOID {
        mp_encode_void_to_builder(builder);
    } else #if type_tag == .ARRAY {
        mp_encode_array_to_builder(builder, x);
    } else #if type_tag == .INTEGER {
        #if #run type_info(T).signed {
            mp_encode_s64_to_builder(builder, x);
        } else {
            mp_encode_u64_to_builder(builder, x);
        }
    } else #if type_tag == .STRUCT {
        is_hash_table :: #run type_info(T).polymorph_source_struct == cast(*Type_Info_Struct) HT.Table;
        #if is_hash_table {
            mp_encode_hash_table_to_builder(builder, x);
        } else {
            mp_encode_struct_to_builder(builder, x);
        }
    } else {
        #assert false, "not implemented";
    }
}

mp_encode_any_to_builder :: (builder: *String_Builder, x: Any) {
    if x.type.type == {
        case .INTEGER; {
            info := cast(*Type_Info_Integer) x.type;
            if info.signed {
                v: s64 = ---;
                if info.runtime_size == {
                    case 1; v = << cast(*s8)  x.value_pointer;
                    case 2; v = << cast(*s16) x.value_pointer;
                    case 4; v = << cast(*s32) x.value_pointer;
                    case 8; v = << cast(*s64) x.value_pointer;
                    case; assert(false);
                }
                mp_encode_to_builder(builder, v);
            } else {
                v: u64 = ---;
                if info.runtime_size == {
                    case 1; v = << cast(*u8)  x.value_pointer;
                    case 2; v = << cast(*u16) x.value_pointer;
                    case 4; v = << cast(*u32) x.value_pointer;
                    case 8; v = << cast(*u64) x.value_pointer;
                    case; assert(false);
                }
                mp_encode_to_builder(builder, v);
            }
        }
        case .STRING;
            mp_encode_to_builder(builder, << cast(*string) x.value_pointer);
        case .BOOL;
            mp_encode_to_builder(builder, << cast(*bool) x.value_pointer);
        case .ARRAY;
            info := cast(*Type_Info_Array) x.type;
            if info.element_type.type == {
                case .INTEGER;
                    element_info := cast(*Type_Info_Integer) info.element_type;
                    if element_info.signed if element_info.runtime_size == {
                        case 1; mp_encode_to_builder(builder, array_view(s8,  x.value_pointer, info));
                        case 2; mp_encode_to_builder(builder, array_view(s16, x.value_pointer, info));
                        case 4; mp_encode_to_builder(builder, array_view(s32, x.value_pointer, info));
                        case 8; mp_encode_to_builder(builder, array_view(s64, x.value_pointer, info));
                        case; assert(false);
                    } else if element_info.runtime_size == {
                        case 1; mp_encode_to_builder(builder, array_view(u8,  x.value_pointer, info));
                        case 2; mp_encode_to_builder(builder, array_view(u16, x.value_pointer, info));
                        case 4; mp_encode_to_builder(builder, array_view(u32, x.value_pointer, info));
                        case 8; mp_encode_to_builder(builder, array_view(u64, x.value_pointer, info));
                        case; assert(false);
                    }
                case .STRING; mp_encode_to_builder(builder, array_view(string, x.value_pointer, info));
                case .BOOL;   mp_encode_to_builder(builder, array_view(bool,   x.value_pointer, info));
                case .ANY;    mp_encode_to_builder(builder, array_view(Any,    x.value_pointer, info));
            }
    }
}

mp_encode_u64_to_builder :: (builder: *String_Builder, _value: u64) {
    data : [9] u8;
    value := _value;
    if value <= 0x7f { // FIXPOSINT
        data[0] = xx,no_check value;
        append(builder, data.data, 1);
    } else if value <= 0xff {
        data[0] = 0xcc; // UINT8
        data[1] = xx,no_check value;
        append(builder, data.data, 2);
    } else if value <= 0xffff {
        data[0] = 0xcd; // UINT16
        byte_swap_in_place(cast(*u16) *value);
        memcpy(*data[1], cast(*u16) *value, size_of(u16));
        append(builder, data.data, 3);
    } else if value <= 0xffff_ffff {
        data[0] = 0xce; // UINT32
        byte_swap_in_place(cast(*u32) *value);
        memcpy(*data[1], cast(*u32) *value, size_of(u32));
        append(builder, data.data, 5);
    } else if value <= 0xffff_ffff_ffff_ffff {
        data[0] = 0xcf; // UINT64
        byte_swap_in_place(cast(*u64) *value);
        memcpy(*data[1], cast(*u64) *value, size_of(u64));
        append(builder, data.data, 9);
    }
}

mp_encode_s64_to_builder :: (builder: *String_Builder, value: s64) {
    if value >= 0 {
        inline mp_encode_to_builder(builder, cast,no_check(u64) value);
        return;
    }
    data : [9] u8;
    value_bytes := cast,no_check(u64) value;

    if value >= 0xffff_ffff_ffff_ffe0 { // FIXNEGINT
        data[0] = xx,no_check 0xff & value;
        append(builder, data.data, 1);
    } else if value >= 0xffff_ffff_ffff_ff80 {
        data[0] = 0xd0; // INT8
        data[1] = xx,no_check value;
        append(builder, data.data, 2);
    } else if value >= 0xffff_ffff_ffff_8000 {
        data[0] = 0xd1; // INT16
        byte_swap_in_place(cast(*s16) *value);
        memcpy(*data[1], cast(*s16) *value, size_of(s16));
        append(builder, data.data, 3);
    } else if value >= 0xffff_ffff_8000_0000 {
        data[0] = 0xd2; // INT32
        byte_swap_in_place(cast(*s32) *value);
        memcpy(*data[1], cast(*s32) *value, size_of(s32));
        append(builder, data.data, 5);
    } else if value >= 0x8000_0000_0000_0000 {
        data[0] = 0xd3; // INT64
        byte_swap_in_place(cast(*s64) *value);
        memcpy(*data[1], cast(*s64) *value, size_of(s64));
        append(builder, data.data, 9);
    }
}

mp_encode_string_to_builder :: (builder: *String_Builder, s: string) {
    header : [5] u8;
    count := s.count;
    if count <= 0 {
        header[0] = 0xa0; // FIXSTR
        append(builder, header.data, 1);
    } else if count <= 0x1f {
        header[0] = xx,no_check (0xa0 + count); // FIXSTR
        append(builder, header.data, 1);
    } else if count <= 0xff {
        header[0] = 0xd9; // STR8
        header[1] = xx,no_check count;
        append(builder, header.data, 2);
    } else if count <= 0xffff {
        header[0] = 0xda; // STR16
        byte_swap_in_place(cast(*u16) *count);
        memcpy(*header[1], cast(*u16) *count, size_of(u16));
        append(builder, header.data, 3);
    } else if count <= 0xffff_ffff {
        header[0] = 0xdb; // STR32
        byte_swap_in_place(cast(*u32) *count);
        memcpy(*header[1], cast(*u32) *count, size_of(u32));
        append(builder, header.data, 5);
    }
    append(builder, s);
}

mp_encode_array_to_builder :: inline (builder: *String_Builder, a: [] $T) {
    mp_encode_array_count_to_builder(builder, a.count);
    for a {
        mp_encode_to_builder(builder, it);
    }
}

mp_encode_hash_table_to_builder :: inline (builder: *String_Builder, t: HT.Table) {
    mp_encode_map_count_to_builder(builder, t.count);
    for t {
        mp_encode_to_builder(builder, it_index);
        mp_encode_to_builder(builder, it);
    }
}

mp_encode_array_count_to_builder :: (builder: *String_Builder, _count: s64) {
    header : [5] u8;
    count := _count;
    if count <= 0 {
        header[0] = 0x90; // FIXARR
        append(builder, header.data, 1);
    } else if count <= 0xf {
        header[0] = xx,no_check (0x90 + count); // FIXARR
        append(builder, header.data, 1);
    } else if count <= 0xffff {
        header[0] = 0xdc; // ARR16
        byte_swap_in_place(cast(*u16) *count);
        memcpy(*header[1], cast(*u16) *count, size_of(u16));
        append(builder, header.data, 3);
    } else if count <= 0xffff_ffff {
        header[0] = 0xdd; // ARR32
        byte_swap_in_place(cast(*u32) *count);
        memcpy(*header[1], cast(*u32) *count, size_of(u32));
        append(builder, header.data, 5);
    }
}

mp_encode_map_count_to_builder :: (builder: *String_Builder, _count: s64) {
    header : [5] u8;
    count := _count;
    if count <= 0 {
        header[0] = 0x80; // FIXMAP
        append(builder, header.data, 1);
    } else if count <= 0xf {
        header[0] = xx,no_check (0x80 + count); // FIXMAP
        append(builder, header.data, 1);
    } else if count <= 0xffff {
        header[0] = 0xde; // MAP16
        byte_swap_in_place(cast(*u16) *count);
        memcpy(*header[1], cast(*u16) *count, size_of(u16));
        append(builder, header.data, 3);
    } else if count <= 0xffff_ffff {
        header[0] = 0xdf; // MAP32
        byte_swap_in_place(cast(*u32) *count);
        memcpy(*header[1], cast(*u32) *count, size_of(u32));
        append(builder, header.data, 5);
    }
}

mp_encode_struct_to_builder :: (builder: *String_Builder, v: $T) {
    #insert #run -> string {
        builder: String_Builder;

        info := cast(*Type_Info_Struct) type_info(T);

        encoding : enum { AUTO; MAP; ARRAY; CUSTOM; } = .AUTO;
        for info.notes {
            if it == "EncodeAsMap"   { encoding = .MAP;   break; }
            if it == "EncodeAsArray" { encoding = .ARRAY; break; }
        }

        non_const_field_names : [..] string;
        defer array_reset(*non_const_field_names);
        for info.members {
            if !(it.flags & .CONSTANT) {
                array_add(*non_const_field_names, it.name);
            } else if it.name == "mp_encode_to_builder" && it.type.type == .PROCEDURE {
                encoding = .CUSTOM;
            }
        }
        field_count := non_const_field_names.count;

        if encoding == {
            case .MAP;
                print_to_builder(*builder, "mp_encode_map_count_to_builder(builder, %);\n", field_count);
                for non_const_field_names {
                    print_to_builder(*builder, "mp_encode_to_builder(builder, \"%\");\n", it);
                    print_to_builder(*builder, "mp_encode_to_builder(builder, v.%);\n", it);
                }
            case .ARRAY;
                print_to_builder(*builder, "mp_encode_array_count_to_builder(builder, %);\n", field_count);
                for non_const_field_names {
                    print_to_builder(*builder, "mp_encode_to_builder(builder, v.%);\n", it);
                }
            case .AUTO;
                append(*builder, "if context.encode_struct_as_map {\n");
                print_to_builder(*builder, "    mp_encode_map_count_to_builder(builder, %);\n", field_count);
                for non_const_field_names {
                    print_to_builder(*builder, "    mp_encode_to_builder(builder, \"%\");\n", it);
                    print_to_builder(*builder, "    mp_encode_to_builder(builder, v.%);\n", it);
                }
                append(*builder, "} else {\n");
                print_to_builder(*builder, "    mp_encode_array_count_to_builder(builder, %);\n", field_count);
                for non_const_field_names {
                    print_to_builder(*builder, "    mp_encode_to_builder(builder, v.%);\n", it);
                }
                append(*builder, "}\n");
            case .CUSTOM;
                append(*builder, "inline T.mp_encode_to_builder(builder, v);\n");
        }
        res := builder_to_string(*builder);
        return res;
    };
}

mp_encode_bool_to_builder :: inline (builder: *String_Builder, b: bool) {
    v: u8 = xx,no_check ifx b then 0xc3 else 0xc2;
    append(builder, v);
}

mp_encode_void_to_builder :: inline (builder: *String_Builder) {
    append(builder, cast,no_check(u8) 0xc0);
}

////////////////////////////////////////////////////////////////////////////////
// decode
////////////////////////////////////////////////////////////////////////////////

mp_decode_into :: inline (s: *string, _res: *$T) -> ok: bool {
    handle_result :: (code: Code) #expand {
        ok, res := #insert code;
        _res.* = res;
        `return ok;
    }

    type_tag :: #run type_info(T).type;
    #if type_tag == .BOOL {
        handle_result(mp_decode_bool(s));
    } else #if type_tag == .STRING {
        handle_result(mp_decode_string(s));
    } else #if type_tag == .INTEGER {
        #if #run type_info(T).signed {
            handle_result(mp_decode_s64(s));
        } else {
            handle_result(mp_decode_u64(s));
        }
    } else #if type_tag == .STRUCT {
        return mp_decode_struct_into(s, _res);
    } else {
        return false;
    }
}

mp_decode :: inline (s: *string, $T: Type) -> (ok: bool, res: T) {
    res : T = ---;
    ok := mp_decode_into(s, *res);
    return ok, res;
}

mp_decode_bool :: inline (s: *string) -> ok: bool, res: bool {
    res : bool = ---;
    c := s.*[0];
    if c == 0xc2 || c == 0xc3 {
        advance(s, 1);
        return true, res = (c == 0xc3);
    }
    return false, res;
}

mp_decode_null :: inline (s: *string) -> ok: bool {
    if s.*[0] == 0xc0 {
        advance(s, 1);
        return true;
    }
    return false;
}

mp_decode_string :: inline (s: *string) -> ok: bool, res: string {
    res : string = ---;
    c := s.*[0];
    if c >= 0xa0 && c <= 0xbf { // FIXSTR
        count := c - 0xa0;
        res.data = s.data + 1;
        res.count = count;
        advance(s, count + 1);
        return true, res;
    } else if c == 0xd9 { // STR8
        count := read_big_endian(s.data + 1, u8);
        res.data = s.data + 1 + size_of(type_of(count));
        res.count = count;
        advance(s, count + 1 + size_of(type_of(count)));
        return true, res;
    } else if c == 0xda { // STR16
        count := read_big_endian(s.data + 1, u16);
        res.data = s.data + 1 + size_of(type_of(count));
        res.count = count;
        advance(s, count + 1 + size_of(type_of(count)));
        return true, res;
    } else if c == 0xdb { // STR32
        count := read_big_endian(s.data + 1, u32);
        res.data = s.data + 1 + size_of(type_of(count));
        res.count = count;
        advance(s, count + 1 + size_of(type_of(count)));
        return true, res;
    }
    return false, res;
}

mp_decode_s64 :: (s: *string) -> (ok: bool, res: s64) {
    res : s64 = ---;
    c := s.*[0];
    if c >= 0xe0 && c <= 0xff { // FIXNEGINT
        advance(s, 1);
        return true, xx 0xffff_ffff_ffff_ff00 | c;
    } else if c == {
        case 0xd0; // INT8
            v := read_big_endian(s.data + 1, s8);
            advance(s, 1 + size_of(type_of(v)));
            return true, v;
        case 0xd1; // INT16
            v := read_big_endian(s.data + 1, s16);
            advance(s, 1 + size_of(type_of(v)));
            return true, v;
        case 0xd2; // INT32
            v := read_big_endian(s.data + 1, s32);
            advance(s, 1 + size_of(type_of(v)));
            return true, v;
        case 0xd3; // INT64
            v := read_big_endian(s.data + 1, s64);
            advance(s, 1 + size_of(type_of(v)));
            return true, v;
    }

    ok, res_u64 := mp_decode_u64(s);
    if ok && res_u64 < 0x8000_0000_0000_0000 {
        return ok, xx,no_check res_u64;
    }

    return false, res;
}

mp_decode_u64 :: (s: *string) -> (ok: bool, res: u64) {
    res : u64 = ---;
    c := s.*[0];
    if c <= 0x7f { // FIXPOSINT
        advance(s, 1);
        return true, c;
    } else if c == {
        case 0xcc; // UINT8
            v := read_big_endian(s.data + 1, u8);
            advance(s, 1 + size_of(type_of(v)));
            return true, v;
        case 0xcd; // UINT16
            v := read_big_endian(s.data + 1, u16);
            advance(s, 1 + size_of(type_of(v)));
            return true, v;
        case 0xce; // UINT32
            v := read_big_endian(s.data + 1, u32);
            advance(s, 1 + size_of(type_of(v)));
            return true, v;
        case 0xcf; // UINT64
            v := read_big_endian(s.data + 1, u64);
            advance(s, 1 + size_of(type_of(v)));
            return true, v;
    }
    return false, res;
}

// If `false` is returned, both `s` and `v` can be partially changed.
mp_decode_struct_into :: (s: *string, v: *$T) -> (ok: bool) {
    #assert type_info(T).type == .STRUCT;

    field_count :: #run -> s64 {
        res : s64 = 0;
        info := cast(*Type_Info_Struct) T;
        for info.members {
            if it.flags & .CONSTANT continue;
            res += 1;
        }
        return res;
    };

    count := mp_decode_map_count(s);
    is_map := true;
    if count < 0 {
        count = mp_decode_array_count(s);
        is_map = false;
    }
    if count < 0 return false;
    if count != field_count return false;

    if count == 0 {
        // String was advanced already so we consumed all there was for this struct
        return true;
    }

    if is_map {
        for 1..count {
            ok, field_name := mp_decode_string(s);
            if !ok return false;

            // TODO: implement checking that all fields are unique
            #insert #run -> string {
                builder : String_Builder;

                append(*builder, "if field_name == {\n");
                info := cast(*Type_Info_Struct) T;
                for info.members {
                    if it.flags & .CONSTANT continue;
                    print_to_builder(*builder, "    case \"%1\"; ok = mp_decode_into(s, *v.%1);\n", it.name);
                }
                append(*builder, "    case; ok = false;\n");
                append(*builder, "}\n");

                return builder_to_string(*builder);
            };
            if !ok return false;
        }
    } else {
        #insert #run -> string {
            builder : String_Builder;

            info := cast(*Type_Info_Struct) T;
            for info.members {
                if it.flags & .CONSTANT continue;
                print_to_builder(*builder, "if !mp_decode_into(s, *v.%) return false;\n", it.name);
            }

            return builder_to_string(*builder);
        };
    }
    return true;
}

mp_decode_map_count :: inline (s: *string) -> s64 {
    c := s.*[0];
    if c >= 0x80 && c <= 0x8f { // FIXMAP
        advance(s, 1);
        return c - 0x80;
    } else if c == {
        case 0xde; // MAP16
            count := read_big_endian(s.data + 1, u16);
            advance(s, 1 + size_of(type_of(count)));
            return count;
        case 0xdf; // MAP32
            count := read_big_endian(s.data + 1, u32);
            advance(s, 1 + size_of(type_of(count)));
            return count;
    }
    return -1;
}

mp_decode_array_count :: inline (s: *string) -> s64 {
    c := s.*[0];
    if c >= 0x90 && c <= 0x9f { // FIXARR
        advance(s, 1);
        return c - 0x90;
    } else if c == {
        case 0xdc; // ARR16
            count := read_big_endian(s.data + 1, u16);
            advance(s, 1 + size_of(type_of(count)));
            return count;
        case 0xdd; // ARR32
            count := read_big_endian(s.data + 1, u32);
            advance(s, 1 + size_of(type_of(count)));
            return count;
    }
    return -1;
}

read_big_endian :: (p: *void, $T: Type) -> T {
    size :: size_of(T);
    res : T = ---;
    memcpy(*res, p, size);
    byte_swap_in_place(*res);
    return res;
}

////////////////////////////////////////////////////////////////////////////////
// mp_print
////////////////////////////////////////////////////////////////////////////////

mp_print :: inline (s: *string) {
    builder : String_Builder;
    mp_print_to_builder(*builder, s);
    write_builder(*builder);
}

mp_print_to_builder :: (builder: *String_Builder, s: *string, depth : u8 = 0, is_map_value := false) {
    print_indent :: (depth: u8) #expand {
        for 1..depth append(builder, "  ");
    }

    c := s.*[0];
    marker := MP_MARKER_TABLE[c];
    if marker == {

        case .FIXPOSINT;
            advance(s, 1);
            if !is_map_value print_indent(depth);
            append(builder, "FIXPOSINT(");
            print_integer(builder, .{ value = c });
            append(builder, ")");

        case .NIL;
            advance(s, 1);
            if !is_map_value print_indent(depth);
            append(builder, "nil");

        case .UNUSED;
            advance(s, 1);
            if !is_map_value print_indent(depth);
            append(builder, "unused");

        case .FALSE;
            advance(s, 1);
            if !is_map_value print_indent(depth);
            append(builder, "false");

        case .TRUE;
            advance(s, 1);
            if !is_map_value print_indent(depth);
            append(builder, "true");

        case .UINT8;
            advance(s, 1);
            if !is_map_value print_indent(depth);
            v : u8;
            memcpy(*v, s.data, size_of(type_of(v)));
            // byte_swap_in_place(*v); // calling this would be silly
            write_nonnegative_number(v);

        case .UINT16;
            advance(s, 1);
            if !is_map_value print_indent(depth);
            v : u16;
            memcpy(*v, s.data, size_of(type_of(v)));
            byte_swap_in_place(*v);
            write_nonnegative_number(v);

        case .UINT32;
            advance(s, 1);
            if !is_map_value print_indent(depth);
            v : u32;
            memcpy(*v, s.data, size_of(type_of(v)));
            byte_swap_in_place(*v);
            write_nonnegative_number(v);

        case .UINT64;
            advance(s, 1);
            if !is_map_value print_indent(depth);
            v : u64;
            memcpy(*v, s.data, size_of(type_of(v)));
            byte_swap_in_place(*v);
            write_nonnegative_number(v);

        case; {
            if marker >= 0xa0 && marker <= 0xbf { // FIXSTR
                count := c - 0xa0;
                if !is_map_value print_indent(depth);
                append(builder, "FIXSTR<");
                fixstr : string = ---;
                fixstr.data = s.data + 1;
                fixstr.count = count;
                append(builder, fixstr);
                append(builder, ">");
                advance(s, 1 + count);
            } else if marker >= 0x90 && marker <= 0x9f { // FIXARR
                count := c - 0x90;
                advance(s, 1);
                if !is_map_value print_indent(depth);
                append(builder, "FIXARR[");
                for 1..count {
                    append(builder, "\n");
                    mp_print_to_builder(builder, s, depth + 1);
                    append(builder, ",");
                }
                if count {
                    append(builder, "\n");
                    print_indent(depth);
                }
                append(builder, "]");
            } else if marker >= 0x80 && marker <= 0x8f { // FIXMAP
                count := c - 0x80;
                advance(s, 1);
                print_indent(depth);
                append(builder, "FIXMAP{");
                for 1..count {
                    append(builder, "\n");
                    mp_print_to_builder(builder, s, depth + 1);
                    append(builder, ": ");
                    mp_print_to_builder(builder, s, depth + 1, is_map_value = true);
                    append(builder, ",");
                }
                if count {
                    append(builder, "\n");
                    print_indent(depth);
                }
                append(builder, "}");
            }
        }
    }
}

MP_Printable :: #type,distinct string;

mp_struct_printer :: (builder: *String_Builder, any: Any, data: *void) -> handled: bool {
    if any.type != type_info(MP_Printable) return false;

    s := << cast(*string) any.value_pointer;
    mp_print_to_builder(builder, *s);
    return true;
}

#scope_file

array_view :: ($T: Type, p: *void, info: *Type_Info_Array) -> [] T #expand {
    if info.array_type == .FIXED {
        v : [] T = ---;
        v.data = p;
        v.count = info.array_count;
        return v;
    } else {
        return << cast(*[] T) p;
    }
}

#import "Basic";
HT :: #import "Hash_Table";
using,only(for_expansion) HT;
#import "Bit_Operations";
