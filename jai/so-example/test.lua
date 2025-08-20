#!/usr/bin/env tarantool

ffi = require 'ffi'
log = require 'log'

ffi.cdef [[
    enum Type_Info_Tag {
        INTEGER              = 0,
        FLOAT                = 1,
        BOOL                 = 2,
        STRING               = 3,
        POINTER              = 4,
        PROCEDURE            = 5,
        VOID                 = 6,
        STRUCT               = 7,
        ARRAY                = 8,
        OVERLOAD_SET         = 9,
        ANY                  = 10,
        ENUM                 = 11,
        POLYMORPHIC_VARIABLE = 12,
        TYPE                 = 13,
        CODE                 = 14,
        UNTYPED_LITERAL      = 15,
        UNTYPED_ENUM         = 16,

        VARIANT              = 18,
    };

    struct Type_Info {
        enum Type_Info_Tag type;
        int64_t runtime_size;
    };

    enum Type_Info_Procedure_Flags {
        IS_ELSEWHERE    = 0x1,
        IS_COMPILE_TIME_ONLY = 0x2,
        IS_POLYMORPHIC  = 0x4,
        HAS_NO_CONTEXT  = 0x8,
        IS_C_CALL       = 0x20,
        IS_INTRINSIC    = 0x80,
        IS_SYMMETRIC    = 0x100,

        IS_CPP_METHOD   = 0x10000000,
        HAS_CPP_NON_POD_RETURN_TYPE = 0x20000000,
    };

    struct Type_Info_Procedure {
        struct Type_Info info;

        int64_t            argument_types_count;
        struct Type_Info **argument_types_data;
        int64_t            return_types_count;
        struct Type_Info **return_types_data;

        enum Type_Info_Procedure_Flags procedure_flags;
    };
]]

type_of_Type_Info = ffi.typeof('struct Type_Info *')

function inspect_Type_Info(type_info)
    if type(type_info) ~= 'cdata' then
        error('argument #1 should be `cdata`')
    end

    if ffi.typeof(type_info) ~= type_of_Type_Info then
        error(('argument #1 should be of type `%s`'):format(type_of_Type_Info))
    end

    log.info('type: %s, runtime_size: %s', type_info.type, type_info.runtime_size)
end

ffi.cdef [[
    int test__int_42;
    int *test__pointer_to_int_42;
    struct Type_Info *type_info__my_proc;
    struct Type_Info *type_info__Context;
]]

lib = ffi.load('/home/gmoshkin/dotfiles/jai/so-example/example.so')

log.info('test__int_42: %s', lib.test__int_42);
log.info('test__pointer_to_int_42: %s', lib.test__pointer_to_int_42);
log.info('test__pointer_to_int_42[0]: %s', lib.test__pointer_to_int_42[0]);
log.info('type_info__my_proc: %s', lib.type_info__my_proc);
log.info('type_info__my_proc[0]: %s', lib.type_info__my_proc[0]);
assert(lib.type_info__my_proc.type == ffi.C.PROCEDURE)

inspect_Type_Info(lib.type_info__my_proc)
inspect_Type_Info(lib.type_info__Context)

type_info__my_proc = ffi.cast('struct Type_Info_Procedure *', lib.type_info__my_proc)

require 'console'.start()
