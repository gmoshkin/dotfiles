MP_MARKER :: enum u8 {
    FIXPOSINT;
    FIXMAP;
    FIXARR;
    FIXSTR;

    NIL;
    UNUSED;
    FALSE;
    TRUE;

    BIN8;
    BIN16;
    BIN32;

    EXT8;
    EXT16;
    EXT32;

    FLOAT32;
    FLOAT64;

    UINT8;
    UINT16;
    UINT32;
    UINT64;

    INT8;
    INT16;
    INT32;
    INT64;

    FIXEXT1;
    FIXEXT2;
    FIXEXT4;
    FIXEXT8;
    FIXEXT16;

    STR8;
    STR16;
    STR32;

    ARR16;
    ARR32;

    MAP16;
    MAP32;

    FIXNEGINT;
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
    mp_encode_array_len_to_builder(builder, a.count);
    for a {
        mp_encode_to_builder(builder, it);
    }
}

mp_encode_hash_table_to_builder :: inline (builder: *String_Builder, t: HT.Table) {
    mp_encode_map_len_to_builder(builder, t.count);
    for t {
        mp_encode_to_builder(builder, it_index);
        mp_encode_to_builder(builder, it);
    }
}

mp_encode_array_len_to_builder :: (builder: *String_Builder, _count: s64) {
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

mp_encode_map_len_to_builder :: (builder: *String_Builder, _count: s64) {
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
                print_to_builder(*builder, "mp_encode_map_len_to_builder(builder, %);\n", field_count);
                for non_const_field_names {
                    print_to_builder(*builder, "mp_encode_to_builder(builder, \"%\");\n", it);
                    print_to_builder(*builder, "mp_encode_to_builder(builder, v.%);\n", it);
                }
            case .ARRAY;
                print_to_builder(*builder, "mp_encode_array_len_to_builder(builder, %);\n", field_count);
                for non_const_field_names {
                    print_to_builder(*builder, "mp_encode_to_builder(builder, v.%);\n", it);
                }
            case .AUTO;
                append(*builder, "if context.encode_struct_as_map {\n");
                print_to_builder(*builder, "    mp_encode_map_len_to_builder(builder, %);\n", field_count);
                for non_const_field_names {
                    print_to_builder(*builder, "    mp_encode_to_builder(builder, \"%\");\n", it);
                    print_to_builder(*builder, "    mp_encode_to_builder(builder, v.%);\n", it);
                }
                append(*builder, "} else {\n");
                print_to_builder(*builder, "    mp_encode_array_len_to_builder(builder, %);\n", field_count);
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
        count : u8 = ---;
        memcpy(*s.*[1], *count, size_of(type_of(count)));
        byte_swap_in_place(*count);
        res.data = s.data + 1 + size_of(type_of(count));
        res.count = count;
        advance(s, count + 1 + size_of(type_of(count)));
        return true, res;
    } else if c == 0xda { // STR16
        count : u16 = ---;
        memcpy(*s.*[1], *count, size_of(type_of(count)));
        byte_swap_in_place(*count);
        res.data = s.data + 1 + size_of(type_of(count));
        res.count = count;
        advance(s, count + 1 + size_of(type_of(count)));
        return true, res;
    } else if c == 0xdb { // STR32
        count : u32 = ---;
        memcpy(*s.*[1], *count, size_of(type_of(count)));
        byte_swap_in_place(*count);
        res.data = s.data + 1 + size_of(type_of(count));
        res.count = count;
        advance(s, count + 1 + size_of(type_of(count)));
        return true, res;
    }
    return false, res;
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
