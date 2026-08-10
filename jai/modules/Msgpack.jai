#module_parameters (TEST := false);

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

mp_encode :: (builder: *String_Builder, x: $T) #expand {
    type_tag :: #run type_info(T).type;
    #if type_tag == .ANY {
        mp_encode_any(builder, x);
    } else #if type_tag == .STRING {
        mp_encode_string(builder, x);
    } else #if type_tag == .BOOL {
        mp_encode_bool(builder, x);
    } else #if type_tag == .VOID {
        mp_encode_void(builder);
    } else #if type_tag == .ARRAY {
        mp_encode_array(builder, x);
    } else #if type_tag == .INTEGER {
        #if #run type_info(T).signed {
            mp_encode_s64(builder, x);
        } else {
            mp_encode_u64(builder, x);
        }
    } else #if type_tag == .STRUCT {
        is_hash_table :: #run type_info(T).polymorph_source_struct == cast(*Type_Info_Struct) HT.Table;
        #if is_hash_table {
            mp_encode_hash_table(builder, x);
        } else {
            mp_encode_struct(builder, x);
        }
    } else {
        #assert false, "not implemented";
    }
}

mp_encode_any :: (builder: *String_Builder, x: Any) {
    if x.type.type == {
        case .INTEGER; {
            info := cast(*Type_Info_Integer) x.type;
            if info.signed {
                v: s64 = ---;
                if info.runtime_size == {
                    case 1; v = x.value_pointer.(*s8).*;
                    case 2; v = x.value_pointer.(*s16).*;
                    case 4; v = x.value_pointer.(*s32).*;
                    case 8; v = x.value_pointer.(*s64).*;
                    case; assert(false);
                }
                mp_encode(builder, v);
            } else {
                v: u64 = ---;
                if info.runtime_size == {
                    case 1; v = x.value_pointer.(*u8).*;
                    case 2; v = x.value_pointer.(*u16).*;
                    case 4; v = x.value_pointer.(*u32).*;
                    case 8; v = x.value_pointer.(*u64).*;
                    case; assert(false);
                }
                mp_encode(builder, v);
            }
        }
        case .STRING;
            mp_encode(builder, x.value_pointer.(*string).*);
        case .BOOL;
            mp_encode(builder, x.value_pointer.(*bool).*);
        case .ARRAY;
            info := cast(*Type_Info_Array) x.type;
            if info.element_type.type == {
                case .INTEGER;
                    element_info := cast(*Type_Info_Integer) info.element_type;
                    if element_info.signed if element_info.runtime_size == {
                        case 1; mp_encode(builder, array_view(s8,  x.value_pointer, info));
                        case 2; mp_encode(builder, array_view(s16, x.value_pointer, info));
                        case 4; mp_encode(builder, array_view(s32, x.value_pointer, info));
                        case 8; mp_encode(builder, array_view(s64, x.value_pointer, info));
                        case; assert(false);
                    } else if element_info.runtime_size == {
                        case 1; mp_encode(builder, array_view(u8,  x.value_pointer, info));
                        case 2; mp_encode(builder, array_view(u16, x.value_pointer, info));
                        case 4; mp_encode(builder, array_view(u32, x.value_pointer, info));
                        case 8; mp_encode(builder, array_view(u64, x.value_pointer, info));
                        case; assert(false);
                    }
                case .STRING; mp_encode(builder, array_view(string, x.value_pointer, info));
                case .BOOL;   mp_encode(builder, array_view(bool,   x.value_pointer, info));
                case .ANY;    mp_encode(builder, array_view(Any,    x.value_pointer, info));
            }
    }
}

mp_encode_u64 :: (builder: *String_Builder, _value: u64) {
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

mp_encode_s64 :: (builder: *String_Builder, value: s64) {
    if value >= 0 {
        inline mp_encode(builder, cast,no_check(u64) value);
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

mp_encode_string :: (builder: *String_Builder, s: string) {
    using MP_MARKER;

    header : [5] u8;
    count := s.count;
    if count <= 0 {
        header[0] = 0xa0; // FIXSTR
        append(builder, header.data, 1);
    } else if count <= 0x1f {
        header[0] = xx,no_check (0xa0 + count); // FIXSTR
        append(builder, header.data, 1);
    } else if count <= 0xff {
        header[0] = xx STR8;
        header[1] = xx,no_check count;
        append(builder, header.data, 2);
    } else if count <= 0xffff {
        header[0] = xx STR16;
        byte_swap_in_place(cast(*u16) *count);
        memcpy(*header[1], cast(*u16) *count, size_of(u16));
        append(builder, header.data, 3);
    } else if count <= 0xffff_ffff {
        header[0] = xx STR32;
        byte_swap_in_place(cast(*u32) *count);
        memcpy(*header[1], cast(*u32) *count, size_of(u32));
        append(builder, header.data, 5);
    }
    append(builder, s);
}

mp_encode_array :: inline (builder: *String_Builder, a: [] $T) {
    mp_encode_array_count(builder, a.count);
    for a {
        mp_encode(builder, it);
    }
}

mp_encode_hash_table :: inline (builder: *String_Builder, t: HT.Table) {
    mp_encode_map_count(builder, t.count);
    for t {
        mp_encode(builder, it_index);
        mp_encode(builder, it);
    }
}

mp_encode_array_count :: (builder: *String_Builder, _count: s64) {
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

mp_encode_map_count :: (builder: *String_Builder, _count: s64) {
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

mp_encode_struct :: (builder: *String_Builder, v: $T) {
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
            } else if it.name == "mp_encode" && it.type.type == .PROCEDURE {
                encoding = .CUSTOM;
            }
        }
        field_count := non_const_field_names.count;

        if encoding == {
            case .MAP;
                print(*builder, "mp_encode_map_count(builder, %);\n", field_count);
                for non_const_field_names {
                    print(*builder, "mp_encode(builder, \"%\");\n", it);
                    print(*builder, "mp_encode(builder, v.%);\n", it);
                }
            case .ARRAY;
                print(*builder, "mp_encode_array_count(builder, %);\n", field_count);
                for non_const_field_names {
                    print(*builder, "mp_encode(builder, v.%);\n", it);
                }
            case .AUTO;
                append(*builder, "if context.encode_struct_as_map {\n");
                print(*builder, "    mp_encode_map_count(builder, %);\n", field_count);
                for non_const_field_names {
                    print(*builder, "    mp_encode(builder, \"%\");\n", it);
                    print(*builder, "    mp_encode(builder, v.%);\n", it);
                }
                append(*builder, "} else {\n");
                print(*builder, "    mp_encode_array_count(builder, %);\n", field_count);
                for non_const_field_names {
                    print(*builder, "    mp_encode(builder, v.%);\n", it);
                }
                append(*builder, "}\n");
            case .CUSTOM;
                append(*builder, "inline T.mp_encode(builder, v);\n");
        }
        res := builder_to_string(*builder);
        return res;
    };
}

mp_encode_bool :: inline (builder: *String_Builder, b: bool) {
    v: u8 = xx,no_check ifx b then 0xc3 else 0xc2;
    append(builder, v);
}

mp_encode_void :: inline (builder: *String_Builder) {
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
    if !s.* return false, res;

    c := s.*[0];
    if c != 0xc2 && c != 0xc3 return false, res;

    advance(s, 1);
    return true, res = (c == 0xc3);
}

mp_decode_null :: inline (s: *string) -> ok: bool {
    if !s.* return false;
    if s.*[0] != 0xc0 return false;

    advance(s, 1);
    return true;
}

mp_decode_string :: (s: *string) -> (ok: bool, res: string) {
    res : string = ---;
    if !s.* return false, res;

    using MP_MARKER;

    c := s.*[0];
    header_size: int;
    if c >= 0xa0 && c <= 0xbf { // FIXSTR
        res.count = c - 0xa0;
        header_size = 1;
    } else if c == xx STR8 || c == xx BIN8 {
        ok:, res.count = read_big_endian(advance(s.*), u8);
        if !ok return false, res;
        header_size = 1 + size_of(u8);
    } else if c == xx STR16 || c == xx BIN16 {
        ok:, res.count = read_big_endian(advance(s.*), u16);
        if !ok return false, res;
        header_size = 1 + size_of(u16);
    } else if c == xx STR32 || c == xx BIN32 {
        ok:, res.count = read_big_endian(advance(s.*), u32);
        if !ok return false, res;
        header_size = 1 + size_of(u32);
    } else {
        return false, res;
    }

    advance_count := header_size + res.count;
    if s.count < advance_count return false, res;

    res.data = s.data + header_size;
    advance(s, advance_count);
    return true, res;
}

mp_decode_s64 :: (s: *string) -> (ok: bool, res: s64) {
    res : s64 = ---;
    if !s.* return false, res;

    c := s.*[0];
    if c >= 0xe0 && c <= 0xff { // FIXNEGINT
        advance(s, 1);
        return true, xx 0xffff_ffff_ffff_ff00 | c;
    } else if c == {
        case 0xd0; // INT8
            ok, v := read_big_endian(advance(s.*), s8);
            if !ok return false, res;

            advance(s, 1 + size_of(type_of(v)));
            return true, v;
        case 0xd1; // INT16
            ok, v := read_big_endian(advance(s.*), s16);
            if !ok return false, res;

            advance(s, 1 + size_of(type_of(v)));
            return true, v;
        case 0xd2; // INT32
            ok, v := read_big_endian(advance(s.*), s32);
            if !ok return false, res;

            advance(s, 1 + size_of(type_of(v)));
            return true, v;
        case 0xd3; // INT64
            ok, v := read_big_endian(advance(s.*), s64);
            if !ok return false, res;

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
    if !s.* return false, res;

    c := s.*[0];
    if c <= 0x7f { // FIXPOSINT
        advance(s, 1);
        return true, c;
    } else if c == {
        case 0xcc; // UINT8
            ok, v := read_big_endian(advance(s.*), u8);
            if !ok return false, res;

            advance(s, 1 + size_of(type_of(v)));
            return true, v;
        case 0xcd; // UINT16
            ok, v := read_big_endian(advance(s.*), u16);
            if !ok return false, res;

            advance(s, 1 + size_of(type_of(v)));
            return true, v;
        case 0xce; // UINT32
            ok, v := read_big_endian(advance(s.*), u32);
            if !ok return false, res;

            advance(s, 1 + size_of(type_of(v)));
            return true, v;
        case 0xcf; // UINT64
            ok, v := read_big_endian(advance(s.*), u64);
            if !ok return false, res;

            advance(s, 1 + size_of(type_of(v)));
            return true, v;
    }
    return false, res;
}

mp_decode_ext :: (input: *string) -> (ok: bool, type: u8, data: [] u8) {
    type: u8 = ---;
    data: [] u8 = ---;

    Read_Int :: (input: *string, $T: Type) -> T #expand {
        ok, result := read_big_endian(input, T);
        if !ok `return false, `type, `data;
        return result;
    }

    c := Read_Int(input, MP_MARKER);

    ok: bool;

    if c == {
    case .FIXEXT1;  data.count = 1;
    case .FIXEXT2;  data.count = 2;
    case .FIXEXT4;  data.count = 4;
    case .FIXEXT8;  data.count = 8;
    case .FIXEXT16; data.count = 16;
    case .EXT8;     data.count = Read_Int(input, u8);
    case .EXT16;    data.count = Read_Int(input, u16);
    case .EXT32;    data.count = Read_Int(input, u32);
    }

    type = Read_Int(input, u8);

    if input.count < data.count return false, type, data;

    data.data = input.data;
    advance(input, data.count);
    return true, type, data;
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
                    print(*builder, "    case \"%1\"; ok = mp_decode_into(s, *v.%1);\n", it.name);
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
                print(*builder, "if !mp_decode_into(s, *v.%) return false;\n", it.name);
            }

            return builder_to_string(*builder);
        };
    }
    return true;
}

mp_decode_map_count :: inline (s: *string) -> s64 {
    if !s.* return -1;

    c := s.*[0];
    if c >= 0x80 && c <= 0x8f { // FIXMAP
        advance(s, 1);
        return c - 0x80;
    } else if c == {
        case 0xde; // MAP16
            ok, count := read_big_endian(advance(s.*), u16);
            if !ok return -1;

            advance(s, 1 + size_of(type_of(count)));
            return count;
        case 0xdf; // MAP32
            ok, count := read_big_endian(advance(s.*), u32);
            if !ok return -1;

            advance(s, 1 + size_of(type_of(count)));
            return count;
    }
    return -1;
}

mp_decode_array_count :: inline (s: *string) -> s64 {
    if !s.* return -1;

    c := s.*[0];
    if c >= 0x90 && c <= 0x9f { // FIXARR
        advance(s, 1);
        return c - 0x90;
    } else if c == {
        case 0xdc; // ARR16
            ok, count := read_big_endian(advance(s.*), u16);
            if !ok return -1;

            advance(s, 1 + size_of(type_of(count)));
            return count;
        case 0xdd; // ARR32
            ok, count := read_big_endian(advance(s.*), u32);
            if !ok return -1;

            advance(s, 1 + size_of(type_of(count)));
            return count;
    }
    return -1;
}

//
// Steps over one complete value without interpreting it, so that something of
// unknown shape can be checked for completeness or skipped past. Returns false
// if the value runs off the end of the buffer, in which case `s` is left
// somewhere in the middle of it.
//
mp_skip_value :: (input: *string) -> bool {
    if !input.*  return false;
    c := input.*[0];

    Skip_Ext :: ($T: Type) #expand {
        advance(`input);
        ok, count := read_big_endian(`input, T);
        if !ok `return false;
        if `input.count < 1 + count `return false;
        advance(`input, 1 + count);
        `return true;
    }

    Skip :: ($N: int) #expand {
        if `input.count < N `return false;
        advance(`input, N); `return true;
    }

    if MP_MARKER_TABLE[c] == {
    case .FIXPOSINT; #through;
    case .FIXNEGINT; #through;
    case .NIL; #through;
    case .FALSE; #through;
    case .TRUE; #through;
    case .UNUSED; advance(input); return true;

    case .INT8; #through;
    case .UINT8; Skip(1 + 1);

    case .INT16; #through;
    case .UINT16; Skip(1 + 2);

    case .INT32; #through;
    case .UINT32; #through;
    case .FLOAT32; Skip(1 + 4);

    case .INT64; #through;
    case .UINT64; #through;
    case .FLOAT64; Skip(1 + 8);

    // `1` for the MP header byte + `1` for ext type byte + `n` for ext data
    case .FIXEXT1; Skip(1 + 1 + 1);
    case .FIXEXT2; Skip(1 + 1 + 2);
    case .FIXEXT4; Skip(1 + 1 + 4);
    case .FIXEXT8; Skip(1 + 1 + 8);
    case .FIXEXT16; Skip(1 + 1 + 16);

    case .EXT8; Skip_Ext(u8);
    case .EXT16; Skip_Ext(u16);
    case .EXT32; Skip_Ext(u32);

    case .STR8; #through;
    case .STR16; #through;
    case .STR32; #through;
    case .BIN8; #through;
    case .BIN16; #through;
    case .BIN32; #through;
    case .FIXSTR;
        return mp_decode_string(input);

    case .ARR16; #through;
    case .ARR32; #through;
    case .FIXARR;
        count := mp_decode_array_count(input);
        if count < 0 return false;
        for 1..count if !mp_skip_value(input) return false;
        return true;

    case .MAP16; #through;
    case .MAP32; #through;
    case .FIXMAP;
        count := mp_decode_map_count(input);
        if count < 0 return false;
        // Skip 2 values per item, because key + value
        for 1..count * 2 if !mp_skip_value(input) return false;
        return true;

    }

    assert(false, "unreachable");
    return false;
}

read_big_endian :: inline (s: string, $T: Type) -> bool, T {
    res: T = ---;

    size :: size_of(T);
    if s.count < size return false, res;

    #if size == 1 {
        res = s.data.(*T).*;
    } else {
        memcpy(*res, s.data, size);
        byte_swap_in_place(*res);
    }
    return true, res;
}

read_big_endian :: inline (input: *string, $T: Type) -> bool, T {
    ok, res := read_big_endian(input.*, T);
    if ok advance(input, size_of(T));
    return ok, res;
}

////////////////////////////////////////////////////////////////////////////////
// mp_print
////////////////////////////////////////////////////////////////////////////////

mp_print :: inline (s: *string) {
    builder: String_Builder;
    builder.allocator = temp;
    mp_print(*builder, s);
    write_builder(*builder);
}

mp_sprint :: inline (s: *string) -> string {
    builder: String_Builder;
    builder.allocator = temp;
    mp_print(*builder, s);
    return builder_to_string(*builder);
}

mp_print :: (builder: *String_Builder, s: *string, depth : u8 = 0, is_map_value := false) {
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
                    mp_print(builder, s, depth + 1);
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
                    mp_print(builder, s, depth + 1);
                    append(builder, ": ");
                    mp_print(builder, s, depth + 1, is_map_value = true);
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

    s := any.value_pointer.(*string).*;
    mp_print(builder, *s);
    return true;
}

// Structs without an `@EncodeAsMap` / `@EncodeAsArray` note are encoded
// whichever way this says. Msgpack maps keep the field names, arrays are
// smaller; msgpack-rpc for example wants arrays.
#add_context encode_struct_as_map := false;

#scope_module

array_view :: ($T: Type, p: *void, info: *Type_Info_Array) -> [] T #expand {
    if info.array_type == .FIXED {
        v : [] T = ---;
        v.data = p;
        v.count = info.array_count;
        return v;
    } else {
        return p.(*[] T).*;
    }
}

//
// tests
//

Void: void;

#scope_export

#if TEST
test_msgpack_encode :: () {
    check_mp_encode :: (v: $T, expected: string) {
        builder: String_Builder;
        mp_encode(*builder, v);
        s := builder_to_string(*builder);
        defer free(s);

        Setup_Context_To_Print_Bytes_Array();
        assert(s == expected, "expected %, but got %", expected.([] u8), s.([] u8));
    }

    check_mp_encode(cast(u64) 0                     , "\x00");
    check_mp_encode(cast(u64) 3                     , "\x03");
    check_mp_encode(cast(u64) 33                    , "\x21");
    check_mp_encode(cast(u64) 0x7f                  , "\x7f");
    check_mp_encode(cast(u64) 0x80                  , "\xcc\x80");
    check_mp_encode(cast(u64) 0xee                  , "\xcc\xee");
    check_mp_encode(cast(u64) 0x123                 , "\xcd\x01\x23");
    check_mp_encode(cast(u64) 0xcafe_babe           , "\xce\xca\xfe\xba\xbe");
    check_mp_encode(cast(u64) 0xdead_beef_b00b_bead , "\xcf\xde\xad\xbe\xef\xb0\x0b\xbe\xad");

    check_mp_encode(cast(s64) -1,                    "\xff");
    check_mp_encode(cast(s64) -32,                   "\xe0");
    check_mp_encode(cast(s64) -128,                  "\xd0\x80");
    check_mp_encode(cast(s64) -256,                  "\xd1\xff\x00");
    check_mp_encode(cast(s64) -65353,                "\xd2\xff\xff\x00\xb7");
    check_mp_encode(cast(s64) -0xcafe_babe,          "\xd3\xff\xff\xff\xff\x35\x01\x45\x42");
    check_mp_encode(cast(s64) 0xdead_beef_b00b_bead, "\xd3\xde\xad\xbe\xef\xb0\x0b\xbe\xad");

    check_mp_encode(cast(u8) 33, "\x21");
    check_mp_encode(cast(u8) 0xff, "\xcc\xff");

    check_mp_encode("",                                 "\xa0");
    check_mp_encode("foo",                              "\xa3\x66\x6f\x6f");
    check_mp_encode("0123456789abcdefghijklmnopqrstu",  "\xbf\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6a\x6b\x6c\x6d\x6e\x6f\x70\x71\x72\x73\x74\x75");
    check_mp_encode("0123456789ABCDEFGHIJKLMNOPQRSTUV", "\xd9\x20\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x41\x42\x43\x44\x45\x46\x47\x48\x49\x4a\x4b\x4c\x4d\x4e\x4f\x50\x51\x52\x53\x54\x55\x56");

    check_mp_encode(true, "\xc3");
    check_mp_encode(false, "\xc2");
    check_mp_encode(Void, "\xc0");

    check_mp_encode(cast(Any) 13, "\x0d");
    check_mp_encode(cast(Any) true, "\xc3");
    check_mp_encode(cast(Any) "hello", "\xa5hello");

    check_mp_encode(Any.[42, s32.[1, 2, 3], false, "ok"], "\x94\x2a\x93\x01\x02\x03\xc2\xa2\x6f\x6b");

    {
        t: HT.Table(int, string);
        HT.table_add(*t, 3, "a");
        HT.table_add(*t, 2, "b");
        HT.table_add(*t, 1, "c");
        check_mp_encode(t, "\x83\x02\xa1\x62\x03\xa1\x61\x01\xa1\x63");
    }

    {
        S :: struct(T: Type = u8) @EncodeAsMap {
            a: int;
            b: string;
            c: bool;
            d: [] T = .[1, 2, 3];
            f :: 420;
        };
        context.encode_struct_as_map = false;
        check_mp_encode(S.{ a = 69, b = "nice", c = true }, "\x84\xa1a\x45\xa1b\xa4nice\xa1c\xc3\xa1d\x93\x01\x02\x03");
    }

    {
        S :: struct(T: Type = u8) @EncodeAsArray {
            a: int;
            b: string;
            c: bool;
            d: [] T = .[1, 2, 3];
            f :: 420;
        };
        context.encode_struct_as_map = true;
        check_mp_encode(S.{ a = 13, b = "good", c = false }, "\x94\x0d\xa4good\xc2\x93\x01\x02\x03");
    }

    {
        S :: struct(T: Type = u8) {
            a: int;
            b: string;
            c: bool;
            d: [] T = .[1, 2, 3];
            f :: 420;
        };
        context.encode_struct_as_map = false;
        check_mp_encode(S.{ a = 48, b = "sup", c = false }, "\x94\x30\xa3sup\xc2\x93\x01\x02\x03");
        context.encode_struct_as_map = true;
        check_mp_encode(S.{ a = 48, b = "sup", c = false }, "\x84\xa1a\x30\xa1b\xa3sup\xa1c\xc2\xa1d\x93\x01\x02\x03");
    }

    {
        MP_Bytes_Wrapper :: struct {
            mp: [] u8;
            mp_encode :: (builder: *String_Builder, x: MP_Bytes_Wrapper) {
                append(builder, x.mp.data, x.mp.count);
            };
        };
        #assert size_of(MP_Bytes_Wrapper) == 16;
        s : MP_Bytes_Wrapper;
        s.mp = xx "\xc3\x03210";
        check_mp_encode(s, xx s.mp);

        S :: struct {
            bytes: MP_Bytes_Wrapper;
            x, y: int;
            name: string;
        };
        check_mp_encode(S.{ bytes = s, x = 13, y = 37, name = "foo" }, "\x84\xa5bytes\xc3\x03210\xa1x\x0d\xa1y\x25\xa4name\xa3foo");
    }
}

#if TEST
test_msgpack_decode :: () {
    check_mp_decode :: (mp: string, expected: $T, loc := #caller_location) {
        mp_copy := mp;
        ok, res := mp_decode(*mp_copy, T);
        #if #run type_info(T).type == .ARRAY {
            Setup_Context_To_Print_Bytes_Array();
        }
        Setup_MP_Struct_Printer();
        assert(ok, "\n%:%: failed to decode value of type % from msgpack % (%)", loc.fully_pathed_filename, loc.line_number, T, mp.([] u8), cast(MP_Printable) mp);
        assert(res == expected, "expected %, but got %", expected, res);
    }

    check_mp_decode("\xc3", true);
    check_mp_decode("\xc2", false);

    check_mp_decode("\xa0", "");
    check_mp_decode("\xa3yes", "yes");
    check_mp_decode("\xd9\x048bit", "8bit");
    check_mp_decode("\xda\x00\x0516bit", "16bit");
    check_mp_decode("\xdb\x00\x00\x00\x0532bit", "32bit");

    check_mp_decode("\x00", 0);
    check_mp_decode("\x12", 18);
    check_mp_decode("\x7f", 127);
    check_mp_decode("\xcc\x80", 128);
    check_mp_decode("\xd1\x00\x81", 129);
    check_mp_decode("\xcd\x00\x82", 130);
    check_mp_decode("\xd2\x00\x00\x00\x83", 131);
    check_mp_decode("\xce\x00\x00\x00\x84", 132);
    check_mp_decode("\xd3\x00\x00\x00\x00\x00\x00\x00\x85", 133);
    check_mp_decode("\xcf\x00\x00\x00\x00\x00\x00\x00\x86", 134);
    check_mp_decode("\xff", -1);
    check_mp_decode("\xe0", -32);
    check_mp_decode("\xd0\xdf", -33);
    check_mp_decode("\xd1\xff\xde", -34);
    check_mp_decode("\xd2\xff\xff\xff\xdd", -35);
    check_mp_decode("\xd3\xff\xff\xff\xff\xff\xff\xff\xdc", -36);

    S :: struct {
        name: string;
        x, y: int;
        is_enabled: bool;
    };
    operator == :: inline (l: S, r: S) -> bool {
        return l.name == r.name && l.x == r.x && l.y == r.y && l.is_enabled == r.is_enabled;
    }

    check_mp_decode("\x84\xa4name\xa3dog\xaais_enabled\xc2\xa1y\x20\xa1x\x30", S.{ "dog", 48, 32, false });
    check_mp_decode("\x94\xa3cat\x18\x22\xc3", S.{ "cat", 24, 34, true });

    {
        s: S;
        assert(mp_decode_struct_into(*"\x93\xa3cat\x18\x22", *s) == false);
        // check_mp_decode("\x93\xa3cat\x18\x22", S.{ "cat", 24, 34, true });
        assert(mp_decode_struct_into(*"\x85\xa4name\xa3dog\xaais_enabled\xc2\xa1y\x20\xa1x\x30\xa5flags\x66", *s) == false);
        // check_mp_decode("\x85\xa4name\xa3dog\xaais_enabled\xc2\xa1y\x20\xa1x\x30\xa5flags\x66", S.{ "dog", 48, 32, false });
    }

    //
    // Collection headers. These consume only the header and leave the elements
    // alone, which is how you take apart something whose shape you don't know
    // ahead of time, e.g. a msgpack-rpc envelope.
    //

    {
        check_count :: (mp: string, count: s64, tail: string, expected: s64, expected_tail: s64) {
            Setup_Context_To_Print_Bytes_Array();
            assert(count == expected, "expected a count of %, but got % from %", expected, count, mp.([] u8));
            assert(tail.count == expected_tail, "expected % bytes after the header, but got % from %", expected_tail, tail.count, mp.([] u8));
        }

        check_array_count :: (mp: string, expected: s64, expected_tail: s64) {
            tail := mp;
            check_count(mp, mp_decode_array_count(*tail), tail, expected, expected_tail);
        }

        check_map_count :: (mp: string, expected: s64, expected_tail: s64) {
            tail := mp;
            check_count(mp, mp_decode_map_count(*tail), tail, expected, expected_tail);
        }

        check_array_count("\x90",                          0, 0); // FIXARR, empty
        check_array_count("\x93\x01\x02\x03",              3, 3); // FIXARR
        check_array_count("\xdc\x00\x02\x01\x02",          2, 2); // ARR16
        check_array_count("\xdd\x00\x00\x00\x02\x01\x02",  2, 2); // ARR32
        check_array_count("\xc3",                         -1, 1); // not a collection at all

        check_map_count("\x80",                            0, 0); // FIXMAP, empty
        check_map_count("\x82\xa1a\x01\xa1b\x02",          2, 6); // FIXMAP
        check_map_count("\xde\x00\x01\x01\x02",            1, 2); // MAP16
        check_map_count("\xdf\x00\x00\x00\x01\x01\x02",    1, 2); // MAP32
        check_map_count("\x93",                           -1, 1); // an array is not a map
    }

    //
    // Truncated input. A socket read hands us however many bytes happened to
    // arrive, and msgpack has no length prefix, so the only way to find out
    // whether a whole value is there yet is to try decoding it. That means
    // every proper prefix of a valid value has to fail cleanly rather than read
    // past the end -- decoding is how we detect "not everything has arrived".
    //

    {
        check_every_prefix_fails :: (mp: string, $T: Type) {
            for cut: 0..mp.count - 1 {
                tail: string = ---;
                tail.data = mp.data;
                tail.count = cut;

                ok, res := mp_decode(*tail, T);

                Setup_Context_To_Print_Bytes_Array();
                assert(!ok, "decoding % as % from only % of its % bytes should have failed, but gave %",
                       mp.([] u8), T, cut, mp.count, res);
            }

            // ...and the whole thing still decodes
            tail := mp;
            ok := mp_decode(*tail, T);
            assert(ok, "% should decode as %", mp.([] u8), T);
            assert(tail.count == 0, "% bytes left over after decoding % as %", tail.count, mp.([] u8), T);
        }

        check_every_prefix_fails("\xa3yes",                              string); // FIXSTR
        check_every_prefix_fails("\xd9\x03yes",                          string); // STR8
        check_every_prefix_fails("\xda\x00\x03yes",                      string); // STR16
        check_every_prefix_fails("\xdb\x00\x00\x00\x03yes",              string); // STR32
        check_every_prefix_fails("\xd0\x80",                             s64);    // INT8
        check_every_prefix_fails("\xd1\xff\xde",                         s64);    // INT16
        check_every_prefix_fails("\xd2\xff\xff\xff\xdd",                 s64);    // INT32
        check_every_prefix_fails("\xd3\x00\x00\x00\x00\x00\x00\x00\x85", s64);    // INT64
        check_every_prefix_fails("\xcc\x80",                             u64);    // UINT8
        check_every_prefix_fails("\xcd\x00\x82",                         u64);    // UINT16
        check_every_prefix_fails("\xce\xca\xfe\xba\xbe",                 u64);    // UINT32
        check_every_prefix_fails("\xcf\xde\xad\xbe\xef\xb0\x0b\xbe\xad", u64);    // UINT64
        check_every_prefix_fails("\xc3",                                 bool);
    }

    {
        // The count decoders take a raw byte, so they need the same guard
        check_count_of_nothing :: (mp: string) {
            arr := mp;
            assert(mp_decode_array_count(*arr) == -1, "array count of % bytes should be -1", mp.count);
            map := mp;
            assert(mp_decode_map_count(*map) == -1, "map count of % bytes should be -1", mp.count);
        }

        check_count_of_nothing("");                     // nothing at all
        check_count_of_nothing("\xdc\x00");             // ARR16 header cut in half
        check_count_of_nothing("\xdd\x00\x00\x00");     // ARR32 header cut short
        check_count_of_nothing("\xde\x00");             // MAP16 header cut in half
        check_count_of_nothing("\xdf\x00\x00\x00");     // MAP32 header cut short
    }

    {
        // A whole msgpack-rpc response: [type=1, msgid=42, error=nil, result="ok"]
        env := "\x94\x01\x2a\xc0\xa2ok";
        assert(mp_decode_array_count(*env) == 4);

        ok_type, type_tag := mp_decode(*env, s64);
        ok_msgid, msgid   := mp_decode(*env, s64);
        error_is_nil      := mp_decode_null(*env);
        ok_result, result := mp_decode(*env, string);

        assert(ok_type && type_tag == 1, "type: ok=% %", ok_type, type_tag);
        assert(ok_msgid && msgid == 42, "msgid: ok=% %", ok_msgid, msgid);
        assert(error_is_nil, "the error slot should have decoded as nil");
        assert(ok_result && result == "ok", "result: ok=% '%'", ok_result, result);
        assert(env.count == 0, "% bytes left over", env.count);
    }
}

#if TEST
test_mp_print :: () {
    pretty_assert(mp_sprint(*"\x20") == "FIXPOSINT(32)");
    pretty_assert(mp_sprint(*"\x80") == "FIXMAP{}");
    pretty_assert(mp_sprint(*"\x81\x01\x02") == trim(#string END
FIXMAP{
  FIXPOSINT(1): FIXPOSINT(2),
}
END));
    pretty_assert(mp_sprint(*"\x84\xa1a\x01\xa1b\x02\xa1c\x03\xa3arr\x93\xc0\xc2\xc3") == trim(#string END
FIXMAP{
  FIXSTR<a>: FIXPOSINT(1),
  FIXSTR<b>: FIXPOSINT(2),
  FIXSTR<c>: FIXPOSINT(3),
  FIXSTR<arr>: FIXARR[
    nil,
    false,
    true,
  ],
}
END));
    pretty_assert(mp_sprint(*"\x84\x45\x69\x7f\x90\x93\x01\x02\x03\xa3abc\xa3arr\x93\xc0\xc2\xc3") == trim(#string END
FIXMAP{
  FIXPOSINT(69): FIXPOSINT(105),
  FIXPOSINT(127): FIXARR[],
  FIXARR[
    FIXPOSINT(1),
    FIXPOSINT(2),
    FIXPOSINT(3),
  ]: FIXSTR<abc>,
  FIXSTR<arr>: FIXARR[
    nil,
    false,
    true,
  ],
}
END));
}

#if TEST
test_mp_skip_value :: () {
    check_skip :: (mp: string, expected_leftover: s64) {
        tail := mp;
        ok := mp_skip_value(*tail);

        Setup_Context_To_Print_Bytes_Array();
        assert(ok, "should have skipped over %", mp.([] u8));
        assert(tail.count == expected_leftover, "expected % bytes after skipping %, but got %",
               expected_leftover, mp.([] u8), tail.count);
    }

    check_skip_fails :: (mp: string) {
        tail := mp;
        ok := mp_skip_value(*tail);

        Setup_Context_To_Print_Bytes_Array();
        assert(!ok, "should not have skipped over the incomplete %", mp.([] u8));
    }

    // Scalars, with a trailing byte to prove we stop in the right place
    check_skip("\xc0!",                     1); // nil
    check_skip("\xc3!",                     1); // true
    check_skip("\x7f!",                     1); // FIXPOSINT
    check_skip("\xff!",                     1); // FIXNEGINT
    check_skip("\xd0\x80!",                 1); // INT8
    check_skip("\xd3\x00\x00\x00\x00\x00\x00\x00\x85!", 1); // INT64
    check_skip("\xcc\x80!",                 1); // UINT8
    check_skip("\xcf\xde\xad\xbe\xef\xb0\x0b\xbe\xad!", 1); // UINT64
    check_skip("\xa3yes!",                  1); // FIXSTR
    check_skip("\xd9\x03yes!",              1); // STR8

    // Collections, including nested ones
    check_skip("\x90!",                     1); // empty array
    check_skip("\x93\x01\x02\x03!",         1); // [1, 2, 3]
    check_skip("\x80!",                     1); // empty map
    check_skip("\x82\xa1a\x01\xa1b\x02!",   1); // {a: 1, b: 2}
    check_skip("\x92\x93\x01\x02\x03\x82\xa1a\xc3\xa1b\xa3yes!", 1); // [[1,2,3], {a: true, b: "yes"}]

    // Every proper prefix of a value is incomplete, which is what tells the read
    // loop to go back for more bytes
    for mp: string.["\x93\x01\x02\x03", "\x82\xa1a\x01\xa1b\x02", "\xd9\x03yes", "\xd3\x00\x00\x00\x00\x00\x00\x00\x85"] {
        for cut: 0..mp.count - 1 {
            prefix: string = ---;
            prefix.data = mp.data;
            prefix.count = cut;
            check_skip_fails(prefix);
        }
    }
}

#scope_module

Setup_Context_To_Print_Bytes_Array :: () #expand {
    old_default_format_int := context.print_style.default_format_int;
    `defer context.print_style.default_format_int = old_default_format_int;

    old_default_format_array := context.print_style.default_format_array;
    `defer context.print_style.default_format_array = old_default_format_array;

    context.print_style.default_format_int = FormatInt.{ base = 16, minimum_digits = 2 };
    context.print_style.default_format_array = FormatArray.{
        separator = "\\x",
        begin_string = "b'\\x",
        end_string = "'",
    };
}

Setup_MP_Struct_Printer :: () #expand {
    old_struct_printer := context.print_style.struct_printer;
    `defer context.print_style.struct_printer = old_struct_printer;
    context.print_style.struct_printer = mp_struct_printer;
}

//
// footer
//

#import "Basic";
HT :: #import "Hash_Table";
using,only(for_expansion) HT;
#import "Bit_Operations";
#if TEST #import "My_Util";
#if TEST #import "String";
