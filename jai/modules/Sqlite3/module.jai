#load "bindings.jai";
#if OS != .LINUX {
    #import "Compiler";
    #run compiler_report(tprint("sqlite module doesn't support OS % yet", OS), mode=.WARNING);
}

sqlite_prepare :: (db: *sqlite3, query: string, args: .. Any) -> *sqlite3_stmt {
    stmt: *sqlite3_stmt;

    rc := sqlite3_prepare_v2(db, query.data, xx query.count, *stmt, null);
    if rc == SQLITE_ERROR {
        set_last_error_from_sql(db);
        return null;
    }
    assert(rc == SQLITE_OK, "%", rc);

    if !sqlite3_bind_values(stmt, .. args) return null;

    return stmt;
}

sqlite_get_all :: (stmt: *sqlite3_stmt, $T: Type, options := Sqlite3_Options.{}) -> bool, [] T {
    rows: [..] T;
    rows.allocator = temp;

    while true {
        row: T;
        result := sqlite3_step_and_get_row(stmt, *row, options);
        if result == .ERROR  return false, .[];
        if result == .NO_ROW break;

        array_add(*rows, row);
    }

    return true, rows;
}

sqlite_execute :: (db: *sqlite3, query: string, $T: Type, args: .. Any, options := Sqlite3_Options.{}) -> bool, [] T {
    stmt := sqlite_prepare(db, query, ..args);
    defer sqlite3_finalize(stmt);

    if !stmt return false, .[];

    ok, result := sqlite_get_all(stmt, T, options);
    return ok, result;
}

sqlite3_put_values :: (stmt: *sqlite3_stmt, args: .. Any) -> bool {
    ok := sqlite3_bind_values(stmt, ..args);
    if !ok return false;

    rc := sqlite3_step(stmt);
    if rc != SQLITE_DONE return set_last_error_from_sql(stmt);

    rc = sqlite3_reset(stmt);
    if rc != SQLITE_OK return set_last_error_from_sql(stmt);

    return true;
}

sqlite3_put_struct :: (stmt: *sqlite3_stmt, row: Any) -> bool {
    assert(row.type.type == .STRUCT);
    type := cast(*Type_Info_Struct) row.type;

    args := get_struct_members(row.value_pointer, type,, temp);
    return sqlite3_put_values(stmt, ..args);
}

sqlite3_bind_values :: (stmt: *sqlite3_stmt, args: .. Any) -> bool {
    actual_column_count := args.count;
    expected_column_count := sqlite3_bind_parameter_count(stmt);
    if actual_column_count != expected_column_count {
        return set_last_error("wrong argument count: you provided %, sql expected %", actual_column_count, expected_column_count);
    }

    for args {
        bind_no := it_index + 1;
        ok := sqlite3_bind_any(stmt, xx bind_no, it);
        if !ok {
            prepend_error_message("failed binding parameter #% (1-based): ", bind_no);
            return false;
        }
    }

    return true;
}

sqlite3_bind_any :: (stmt: *sqlite3_stmt, bind_no: s32, value: Any) -> bool {
    base_type := value.type;
    value_pointer := value.value_pointer;
    if base_type.type == {
        case .INTEGER;
        type := cast(*Type_Info_Integer) base_type;

            n := get_value(value_pointer, type);
            rc := sqlite3_bind_int64(stmt, bind_no, n);
            if rc != SQLITE_OK return set_last_error_from_sql(stmt);

        case .FLOAT;
            type := cast(*Type_Info_Float) base_type;

            n := get_value(value_pointer, type);
            rc := sqlite3_bind_double(stmt, bind_no, n);
            if rc != SQLITE_OK return set_last_error_from_sql(stmt);

        case .STRING;
            s := << cast(*string) value_pointer;
            rc := sqlite3_bind_text(stmt, bind_no, s.data, xx s.count, SQLITE_TRANSIENT);
            if rc != SQLITE_OK return set_last_error_from_sql(stmt);

        case .ARRAY;
            type := cast(*Type_Info_Array) base_type;
            if type.element_type != type_info(u8) return set_last_error("values of type % are not supported", base_type.type);

            s := get_array(u8, value_pointer, type);
            rc := sqlite3_bind_blob(stmt, bind_no, s.data, xx s.count, SQLITE_TRANSIENT);
            if rc != SQLITE_OK return set_last_error_from_sql(stmt);

        case; return set_last_error("values of type % are not supported", base_type.type);
    }

    return true;
}

Sqlite3_Get_Result :: enum {
    OK;
    NO_ROW;
    ERROR;
}

Sqlite3_Options :: struct {
    copy_data := true;
}

sqlite3_step_and_get_row :: (stmt: *sqlite3_stmt, result: *$T, options := Sqlite3_Options.{}) -> Sqlite3_Get_Result {
    rc := sqlite3_step(stmt);
    if rc == SQLITE_DONE return .NO_ROW;
    if rc != SQLITE_ROW {
        set_last_error_from_sql(stmt);
        return .ERROR;
    }

    ok := sqlite3_get_row(stmt, result, options);
    return ifx ok then .OK else .ERROR;
}

sqlite3_get_row :: inline (stmt: *sqlite3_stmt, result: *$T, options := Sqlite3_Options.{}) -> bool {
    tag :: type_info(T).type;
    #if tag == .STRUCT
        return sqlite3_get_row_struct(stmt, result, type_info(T), options);
    else #if tag == .INTEGER || tag == .FLOAT
        return sqlite3_get_row_single_column(stmt, result, type_info(T), options);
    else
        #assert false, "% not supported", tag;
    // TODO: add support for getting an array, in case all columns have same type, wouldn't that be cool?
}

sqlite3_get_row_struct :: (stmt: *sqlite3_stmt, result: *void, type: *Type_Info_Struct, options := Sqlite3_Options.{}) -> bool {
    expected_column_count := type.members.count;
    actual_column_count := sqlite3_column_count(stmt);
    if actual_column_count != expected_column_count {
        set_last_error("wrong column count: expected %, got %", expected_column_count, actual_column_count);
        return false;
    }

    p := cast(*u8) result;
    for type.members {
        column_no := it_index;

        field_pointer := p + it.offset_in_bytes;
        sql_value := sqlite3_column_value(stmt, xx column_no);
        ok := set_from_sqlite3_value(field_pointer, it.type, sql_value, copy_data = options.copy_data);
        if !ok {
            prepend_error_message("failed reading column % (0-based): ", column_no);
            return false;
        }
    }

    return true;
}

sqlite3_get_row_single_column :: (stmt: *sqlite3_stmt, result: *void, type: *Type_Info, options := Sqlite3_Options.{}) -> bool {
    assert(type.type == .INTEGER || type.type == .FLOAT, "%", type.type);

    actual_column_count := sqlite3_column_count(stmt);
    if actual_column_count != 1 {
        set_last_error("wrong column count: expected 1, got %", actual_column_count);
        return false;
    }

    column_no := 0;
    sql_value := sqlite3_column_value(stmt, xx column_no);
    ok := set_from_sqlite3_value(result, type, sql_value, copy_data = options.copy_data);
    if !ok {
        prepend_error_message("failed reading column % (0-based): ", column_no);
        return false;
    }

    return true;
}

set_from_sqlite3_value :: (value_pointer: *void, base_type: *Type_Info, sql_value: *sqlite3_value, copy_data := false) -> bool {
    sql_type := sqlite3_value_type(sql_value);
    if base_type.type == {
        case .INTEGER;
            type := cast(*Type_Info_Integer) base_type;

            if sql_type != SQLITE_INTEGER return set_last_error("expected %, got %", type_name(type), sql_type_name(sql_type));

            n := sqlite3_value_int64(sql_value);
            ok := range_check_and_store(n, type, value_pointer);
            if !ok return set_last_error("% is out of range for %", n, type_name(type));

        case .FLOAT;
            type := cast(*Type_Info_Float) base_type;

            if sql_type != SQLITE_FLOAT return set_last_error("expected %, got %", type_name(type), sql_type_name(sql_type));

            n := sqlite3_value_double(sql_value);
            if type.runtime_size == {
                case 4; << cast(*float32) value_pointer = xx n;
                case 8; << cast(*float64) value_pointer = n;
                case; assert(false);
            }

        case .STRING;
            if sql_type != SQLITE_TEXT && sql_type != SQLITE_BLOB return set_last_error("expected string, got %", sql_type_name(sql_type));

            result: string;
            result.count = sqlite3_value_bytes(sql_value);
            if sql_type == {
                case SQLITE_TEXT; result.data = sqlite3_value_text(sql_value);
                case SQLITE_BLOB; result.data = sqlite3_value_blob(sql_value);
            }
            if copy_data  result = copy_string(result);
            << cast(*string) value_pointer = result;

        case .ARRAY;
            type := cast(*Type_Info_Array) base_type;
            if type.element_type != type_info(u8) return set_last_error("values of type % are not supported", base_type.type);
            if sql_type != SQLITE_TEXT && sql_type != SQLITE_BLOB return set_last_error("expected blob, got %", sql_type_name(sql_type));

            result: [] u8;
            result.count = sqlite3_value_bytes(sql_value);
            if type.array_count >= 0 && result.count != type.array_count {
                return set_last_error("not enough data in sql value: expected %, got %", type.array_count, result.count);
            }

            if sql_type == {
                case SQLITE_TEXT; result.data = sqlite3_value_text(sql_value);
                case SQLITE_BLOB; result.data = sqlite3_value_blob(sql_value);
            }

            set_array(value_pointer, type, result, copy_data);

        case; return set_last_error("values of type % are not supported", base_type.type);
    }

    return true;
}

sql_type_name :: (type: s32) -> string {
    if type == {
        case SQLITE_INTEGER; return "INTEGER";
        case SQLITE_FLOAT;   return "FLOAT";
        case SQLITE_TEXT;    return "TEXT";
        case SQLITE_BLOB;    return "BLOB";
        case SQLITE_NULL;    return "NULL";
    }
    return tprint("<unknown %>", type);
}

set_last_error_from_sql :: inline (stmt: *sqlite3_stmt) -> bool {
    return set_last_error_from_sql(sqlite3_db_handle(stmt));
}

set_last_error_from_sql :: inline (db: *sqlite3) -> bool {
    return set_last_error(cast(SQLITE_RESULT_CODE) sqlite3_errcode(db), "%", to_string(sqlite3_errmsg(db)));
}

Sqlite3_Logger :: struct {
    proc: Logger;
    data: *void;
}

log_trampoline :: (data: *void, code: s32, message: *u8) #c_call {
    logger := cast(*Sqlite3_Logger) data;
    ctx: Context;
    ctx.logger = logger.proc;
    ctx.logger_data = logger.data;
    push_context ctx {
        log("[%] %", cast(SQLITE_RESULT_CODE) code, to_string(message));
    }
}

#scope_file

get_struct_members :: (value_pointer: *void, type: *Type_Info_Struct) -> [] Any {
    result: [..] Any;
    array_reserve(*result, type.members.count);

    base := cast(*u8) value_pointer;
    for type.members {
        slot := array_add(*result);
        slot.value_pointer = base + it.offset_in_bytes;
        slot.type = it.type;
    }

    return result;
}

get_array :: ($T: Type, value_pointer: *void, type: *Type_Info_Array) -> [] T {
    result: [] T = ---;
    if type.array_type == .FIXED {
        result.data = value_pointer;
        result.count = type.array_count;
    } else {
        result = << cast(*[] T) value_pointer;
    }
    return result;
}

set_array :: (value_pointer: *void, type: *Type_Info_Array, source: [] $T, copy_view := false) {
    element_type := type.element_type;
    if type.array_type == {
        case .FIXED;
            assert(type.array_count == source.count);
            memcpy(value_pointer, source.data, element_type.runtime_size * source.count);
        case .VIEW;
            << cast(* [] T) value_pointer = ifx copy_view array_copy(source) else source;
        case .RESIZABLE;
            array := << cast(* [..] T) value_pointer;
            array.count = 0;
            array_add(*array, ..source);
    }
}

get_value :: (value_pointer: *void, type: *Type_Info_Integer) -> s64 {
    if type.runtime_size == {
        case 1; return xx,no_check << cast(*s8) value_pointer;
        case 2; return xx,no_check << cast(*s16) value_pointer;
        case 4; return xx,no_check << cast(*s32) value_pointer;
        case 8; return xx,no_check << cast(*s64) value_pointer;
    }
    assert(false);
    return -1;
}

get_value :: (value_pointer: *void, type: *Type_Info_Float) -> float64 {
    if type.runtime_size == {
        case 4; return xx,no_check << cast(*float32) value_pointer;
        case 8; return xx,no_check << cast(*float64) value_pointer;
    }
    assert(false);
    return 0h7FF7FFFF_FFFFFFFF;
}

type_name :: (type: *Type_Info_Integer) -> string {
    if type.runtime_size == {
        case 1; return ifx type.signed then  "s8" else  "u8";
        case 2; return ifx type.signed then "s16" else "u16";
        case 4; return ifx type.signed then "s32" else "u32";
        case 8; return ifx type.signed then "s64" else "u64";
    }
    assert(false);
    return "";
}

type_name :: (type: *Type_Info_Float) -> string {
    if type.runtime_size == {
        case 4; return "float32";
        case 8; return "float64";
    }
    assert(false);
    return "";
}

#scope_file

#import "Basic";
#import "Error_Info";
#import "Reflection";
