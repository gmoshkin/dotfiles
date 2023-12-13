//
// This file was auto-generated using the following command:
//
// jai build.jai
//



WINVER :: 0x0501;

LUA_LIBEXT :: ".so";

LUA_MULTILIB :: "lib";

LUA_LMULTILIB :: "lib";

LUA_LROOT :: "/usr/local";
LUA_LUADIR :: "/lua/5.1/";
LUA_LJDIR :: "/luajit-2.1.0-beta3/";

LUA_JROOT :: LUA_LROOT;

LUA_PATH :: "LUA_PATH";
LUA_CPATH :: "LUA_CPATH";
LUA_INIT :: "LUA_INIT";

LUA_DIRSEP :: "/";

LUA_PATHSEP :: ";";
LUA_PATH_MARK :: "?";
LUA_EXECDIR :: "!";
LUA_IGMARK :: "-";

LUAI_MAXSTACK :: 65500;
LUAI_MAXCSTACK :: 8000;
LUAI_GCPAUSE :: 200;
LUAI_GCMUL :: 200;
LUA_MAXCAPTURES :: 32;

LUA_IDSIZE :: 60;

LUA_NUMBER_SCAN :: "%lf";
LUA_NUMBER_FMT :: "%.14g";

LUAI_MAXNUMBER2STR :: 32;
LUA_INTFRMLEN :: "l";

LUA_VERSION :: "Lua 5.1";
LUA_RELEASE :: "Lua 5.1.4";
LUA_VERSION_NUM :: 501;
LUA_COPYRIGHT :: "Copyright (C) 1994-2008 Lua.org, PUC-Rio";
LUA_AUTHORS :: "R. Ierusalimschy, L. H. de Figueiredo & W. Celes";

LUA_SIGNATURE :: "\033Lua";

LUA_MULTRET :: -1;

LUA_REGISTRYINDEX :: -10000;
LUA_ENVIRONINDEX :: -10001;
LUA_GLOBALSINDEX :: -10002;

LUA_OK :: 0;
LUA_YIELD :: 1;
LUA_ERRRUN :: 2;
LUA_ERRSYNTAX :: 3;
LUA_ERRMEM :: 4;
LUA_ERRERR :: 5;

LUA_TNONE :: -1;

LUA_TNIL :: 0;
LUA_TBOOLEAN :: 1;
LUA_TLIGHTUSERDATA :: 2;
LUA_TNUMBER :: 3;
LUA_TSTRING :: 4;
LUA_TTABLE :: 5;
LUA_TFUNCTION :: 6;
LUA_TUSERDATA :: 7;
LUA_TTHREAD :: 8;

LUA_MINSTACK :: 20;

LUA_GCSTOP :: 0;
LUA_GCRESTART :: 1;
LUA_GCCOLLECT :: 2;
LUA_GCCOUNT :: 3;
LUA_GCCOUNTB :: 4;
LUA_GCSTEP :: 5;
LUA_GCSETPAUSE :: 6;
LUA_GCSETSTEPMUL :: 7;
LUA_GCISRUNNING :: 9;

lua_Chunkreader :: lua_Reader;
lua_Chunkwriter :: lua_Writer;

LUA_HOOKCALL :: 0;
LUA_HOOKRET :: 1;
LUA_HOOKLINE :: 2;
LUA_HOOKCOUNT :: 3;
LUA_HOOKTAILRET :: 4;

LUA_MASKCALL :: 1 << LUA_HOOKCALL;
LUA_MASKRET :: 1 << LUA_HOOKRET;
LUA_MASKLINE :: 1 << LUA_HOOKLINE;
LUA_MASKCOUNT :: 1 << LUA_HOOKCOUNT;

lua_State :: struct {}

lua_CFunction :: #type (L: *lua_State) -> s32 #c_call;

/*
** functions that read/write blocks when loading/dumping Lua chunks
*/
lua_Reader :: #type (L: *lua_State, ud: *void, sz: *size_t) -> *u8 #c_call;

lua_Writer :: #type (L: *lua_State, p: *void, sz: size_t, ud: *void) -> s32 #c_call;

/*
** prototype for memory-allocation functions
*/
lua_Alloc :: #type (ud: *void, ptr: *void, osize: size_t, nsize: size_t) -> *void #c_call;

/* type of numbers in Lua */
lua_Number :: float64;

/* type for integer functions */
lua_Integer :: ptrdiff_t;

/*
** state manipulation
*/
lua_newstate :: (f: lua_Alloc, ud: *void) -> *lua_State #foreign __UnknownLib;
lua_close :: (L: *lua_State) -> void #foreign __UnknownLib;
lua_newthread :: (L: *lua_State) -> *lua_State #foreign __UnknownLib;

lua_atpanic :: (L: *lua_State, panicf: lua_CFunction) -> lua_CFunction #foreign __UnknownLib;

/*
** basic stack manipulation
*/
lua_gettop :: (L: *lua_State) -> s32 #foreign __UnknownLib;
lua_settop :: (L: *lua_State, idx: s32) -> void #foreign __UnknownLib;
lua_pushvalue :: (L: *lua_State, idx: s32) -> void #foreign __UnknownLib;
lua_remove :: (L: *lua_State, idx: s32) -> void #foreign __UnknownLib;
lua_insert :: (L: *lua_State, idx: s32) -> void #foreign __UnknownLib;
lua_replace :: (L: *lua_State, idx: s32) -> void #foreign __UnknownLib;
lua_checkstack :: (L: *lua_State, sz: s32) -> s32 #foreign __UnknownLib;

lua_xmove :: (from: *lua_State, to: *lua_State, n: s32) -> void #foreign __UnknownLib;

/*
** access functions (stack -> C)
*/
lua_isnumber :: (L: *lua_State, idx: s32) -> s32 #foreign __UnknownLib;
lua_isstring :: (L: *lua_State, idx: s32) -> s32 #foreign __UnknownLib;
lua_iscfunction :: (L: *lua_State, idx: s32) -> s32 #foreign __UnknownLib;
lua_isuserdata :: (L: *lua_State, idx: s32) -> s32 #foreign __UnknownLib;
lua_type :: (L: *lua_State, idx: s32) -> s32 #foreign __UnknownLib;
lua_typename :: (L: *lua_State, tp: s32) -> *u8 #foreign __UnknownLib;

lua_equal :: (L: *lua_State, idx1: s32, idx2: s32) -> s32 #foreign __UnknownLib;
lua_rawequal :: (L: *lua_State, idx1: s32, idx2: s32) -> s32 #foreign __UnknownLib;
lua_lessthan :: (L: *lua_State, idx1: s32, idx2: s32) -> s32 #foreign __UnknownLib;

lua_tonumber :: (L: *lua_State, idx: s32) -> lua_Number #foreign __UnknownLib;
lua_tointeger :: (L: *lua_State, idx: s32) -> lua_Integer #foreign __UnknownLib;
lua_toboolean :: (L: *lua_State, idx: s32) -> s32 #foreign __UnknownLib;
lua_tolstring :: (L: *lua_State, idx: s32, len: *size_t) -> *u8 #foreign __UnknownLib;
lua_hashstring :: (L: *lua_State, idx: s32) -> u32 #foreign __UnknownLib;
lua_objlen :: (L: *lua_State, idx: s32) -> size_t #foreign __UnknownLib;
lua_tocfunction :: (L: *lua_State, idx: s32) -> lua_CFunction #foreign __UnknownLib;
lua_touserdata :: (L: *lua_State, idx: s32) -> *void #foreign __UnknownLib;
lua_tothread :: (L: *lua_State, idx: s32) -> *lua_State #foreign __UnknownLib;
lua_topointer :: (L: *lua_State, idx: s32) -> *void #foreign __UnknownLib;

/*
** push functions (C -> stack)
*/
lua_pushnil :: (L: *lua_State) -> void #foreign __UnknownLib;
lua_pushnumber :: (L: *lua_State, n: lua_Number) -> void #foreign __UnknownLib;
lua_pushinteger :: (L: *lua_State, n: lua_Integer) -> void #foreign __UnknownLib;
lua_pushlstring :: (L: *lua_State, s: *u8, l: size_t) -> void #foreign __UnknownLib;
lua_pushstring :: (L: *lua_State, s: *u8) -> void #foreign __UnknownLib;
lua_pushvfstring :: (L: *lua_State, fmt: *u8, argp: va_list) -> *u8 #foreign __UnknownLib;

lua_pushfstring_CFormat :: (L: *lua_State, fmt: *u8, __args: ..Any) -> *u8 #foreign __UnknownLib "lua_pushfstring";
lua_pushfstring :: (L: *lua_State, fmt: string, __args: ..Any) -> *u8 {
    push_allocator(temp);
    formatted_text_builder: String_Builder;
    print_to_builder(*formatted_text_builder, fmt, ..__args);
    append(*formatted_text_builder, "\0");
    formatted_text := builder_to_string(*formatted_text_builder);
    return lua_pushfstring_CFormat(L, "%s", formatted_text.data);
} @PrintLike
lua_pushcclosure :: (L: *lua_State, fn: lua_CFunction, n: s32) -> void #foreign __UnknownLib;
lua_pushboolean :: (L: *lua_State, b: s32) -> void #foreign __UnknownLib;
lua_pushlightuserdata :: (L: *lua_State, p: *void) -> void #foreign __UnknownLib;
lua_pushthread :: (L: *lua_State) -> s32 #foreign __UnknownLib;

/*
** get functions (Lua -> stack)
*/
lua_gettable :: (L: *lua_State, idx: s32) -> void #foreign __UnknownLib;
lua_getfield :: (L: *lua_State, idx: s32, k: *u8) -> void #foreign __UnknownLib;
lua_rawget :: (L: *lua_State, idx: s32) -> void #foreign __UnknownLib;
lua_rawgeti :: (L: *lua_State, idx: s32, n: s32) -> void #foreign __UnknownLib;
lua_createtable :: (L: *lua_State, narr: s32, nrec: s32) -> void #foreign __UnknownLib;
lua_newuserdata :: (L: *lua_State, sz: size_t) -> *void #foreign __UnknownLib;
lua_getmetatable :: (L: *lua_State, objindex: s32) -> s32 #foreign __UnknownLib;
lua_getfenv :: (L: *lua_State, idx: s32) -> void #foreign __UnknownLib;

/*
** set functions (stack -> Lua)
*/
lua_settable :: (L: *lua_State, idx: s32) -> void #foreign __UnknownLib;
lua_setfield :: (L: *lua_State, idx: s32, k: *u8) -> void #foreign __UnknownLib;
lua_rawset :: (L: *lua_State, idx: s32) -> void #foreign __UnknownLib;
lua_rawseti :: (L: *lua_State, idx: s32, n: s32) -> void #foreign __UnknownLib;
lua_setmetatable :: (L: *lua_State, objindex: s32) -> s32 #foreign __UnknownLib;
lua_setfenv :: (L: *lua_State, idx: s32) -> s32 #foreign __UnknownLib;

/*
** `load' and `call' functions (load and run Lua code)
*/
lua_call :: (L: *lua_State, nargs: s32, nresults: s32) -> void #foreign __UnknownLib;
lua_pcall :: (L: *lua_State, nargs: s32, nresults: s32, errfunc: s32) -> s32 #foreign __UnknownLib;
lua_cpcall :: (L: *lua_State, func: lua_CFunction, ud: *void) -> s32 #foreign __UnknownLib;
lua_load :: (L: *lua_State, reader: lua_Reader, dt: *void, chunkname: *u8) -> s32 #foreign __UnknownLib;

lua_dump :: (L: *lua_State, writer: lua_Writer, data: *void) -> s32 #foreign __UnknownLib;

/*
** coroutine functions
*/
lua_yield :: (L: *lua_State, nresults: s32) -> s32 #foreign __UnknownLib;
lua_resume :: (L: *lua_State, narg: s32) -> s32 #foreign __UnknownLib;
lua_status :: (L: *lua_State) -> s32 #foreign __UnknownLib;

lua_gc :: (L: *lua_State, what: s32, data: s32) -> s32 #foreign __UnknownLib;

/*
** miscellaneous functions
*/
lua_error :: (L: *lua_State) -> s32 #foreign __UnknownLib;

lua_next :: (L: *lua_State, idx: s32) -> s32 #foreign __UnknownLib;

lua_concat :: (L: *lua_State, n: s32) -> void #foreign __UnknownLib;

lua_getallocf :: (L: *lua_State, ud: **void) -> lua_Alloc #foreign __UnknownLib;
lua_setallocf :: (L: *lua_State, f: lua_Alloc, ud: *void) -> void #foreign __UnknownLib;

/*
** Calculate a hash for a specified string. Hash is the same as
** for luajit string objects (see lj_str_new()).
*/
lua_hash :: (str: *u8, len: u32) -> u32 #foreign __UnknownLib;

/* hack */
lua_setlevel :: (from: *lua_State, to: *lua_State) -> void #foreign __UnknownLib;

/* Functions to be called by the debuger in specific events */
lua_Hook :: #type (L: *lua_State, ar: *lua_Debug) -> void #c_call;

lua_getstack :: (L: *lua_State, level: s32, ar: *lua_Debug) -> s32 #foreign __UnknownLib;
lua_getinfo :: (L: *lua_State, what: *u8, ar: *lua_Debug) -> s32 #foreign __UnknownLib;
lua_getlocal :: (L: *lua_State, ar: *lua_Debug, n: s32) -> *u8 #foreign __UnknownLib;
lua_setlocal :: (L: *lua_State, ar: *lua_Debug, n: s32) -> *u8 #foreign __UnknownLib;
lua_getupvalue :: (L: *lua_State, funcindex: s32, n: s32) -> *u8 #foreign __UnknownLib;
lua_setupvalue :: (L: *lua_State, funcindex: s32, n: s32) -> *u8 #foreign __UnknownLib;
lua_sethook :: (L: *lua_State, func: lua_Hook, mask: s32, count: s32) -> s32 #foreign __UnknownLib;
lua_gethook :: (L: *lua_State) -> lua_Hook #foreign __UnknownLib;
lua_gethookmask :: (L: *lua_State) -> s32 #foreign __UnknownLib;
lua_gethookcount :: (L: *lua_State) -> s32 #foreign __UnknownLib;

/* From Lua 5.2. */
lua_upvalueid :: (L: *lua_State, idx: s32, n: s32) -> *void #foreign __UnknownLib;
lua_upvaluejoin :: (L: *lua_State, idx1: s32, n1: s32, idx2: s32, n2: s32) -> void #foreign __UnknownLib;
lua_loadx :: (L: *lua_State, reader: lua_Reader, dt: *void, chunkname: *u8, mode: *u8) -> s32 #foreign __UnknownLib;

lua_version :: (L: *lua_State) -> *lua_Number #foreign __UnknownLib;
lua_copy :: (L: *lua_State, fromidx: s32, toidx: s32) -> void #foreign __UnknownLib;
lua_tonumberx :: (L: *lua_State, idx: s32, isnum: *s32) -> lua_Number #foreign __UnknownLib;
lua_tointegerx :: (L: *lua_State, idx: s32, isnum: *s32) -> lua_Integer #foreign __UnknownLib;

/* From Lua 5.3. */
lua_isyieldable :: (L: *lua_State) -> s32 #foreign __UnknownLib;

lua_Debug :: struct {
    event:           s32;
    name:            *u8; /* (n) */
    namewhat:        *u8; /* (n) `global', `local', `field', `method' */
    what:            *u8; /* (S) `Lua', `C', `main', `tail' */
    source:          *u8; /* (S) */
    currentline:     s32; /* (l) */
    nups:            s32; /* (u) number of upvalues */
    linedefined:     s32; /* (S) */
    lastlinedefined: s32; /* (S) */
    short_src:       [60] u8; /* (S) */

    i_ci:            s32; /* active function */
}

#scope_file

#import "Basic"; // For assert


#run {
    {
        instance: lua_Debug;
        assert(((cast(*void)(*instance.event)) - cast(*void)(*instance)) == 0, "lua_Debug.event has unexpected offset % instead of 0", ((cast(*void)(*instance.event)) - cast(*void)(*instance)));
        assert(size_of(type_of(lua_Debug.event)) == 4, "lua_Debug.event has unexpected size % instead of 4", size_of(type_of(lua_Debug.event)));
        assert(((cast(*void)(*instance.name)) - cast(*void)(*instance)) == 8, "lua_Debug.name has unexpected offset % instead of 8", ((cast(*void)(*instance.name)) - cast(*void)(*instance)));
        assert(size_of(type_of(lua_Debug.name)) == 8, "lua_Debug.name has unexpected size % instead of 8", size_of(type_of(lua_Debug.name)));
        assert(((cast(*void)(*instance.namewhat)) - cast(*void)(*instance)) == 16, "lua_Debug.namewhat has unexpected offset % instead of 16", ((cast(*void)(*instance.namewhat)) - cast(*void)(*instance)));
        assert(size_of(type_of(lua_Debug.namewhat)) == 8, "lua_Debug.namewhat has unexpected size % instead of 8", size_of(type_of(lua_Debug.namewhat)));
        assert(((cast(*void)(*instance.what)) - cast(*void)(*instance)) == 24, "lua_Debug.what has unexpected offset % instead of 24", ((cast(*void)(*instance.what)) - cast(*void)(*instance)));
        assert(size_of(type_of(lua_Debug.what)) == 8, "lua_Debug.what has unexpected size % instead of 8", size_of(type_of(lua_Debug.what)));
        assert(((cast(*void)(*instance.source)) - cast(*void)(*instance)) == 32, "lua_Debug.source has unexpected offset % instead of 32", ((cast(*void)(*instance.source)) - cast(*void)(*instance)));
        assert(size_of(type_of(lua_Debug.source)) == 8, "lua_Debug.source has unexpected size % instead of 8", size_of(type_of(lua_Debug.source)));
        assert(((cast(*void)(*instance.currentline)) - cast(*void)(*instance)) == 40, "lua_Debug.currentline has unexpected offset % instead of 40", ((cast(*void)(*instance.currentline)) - cast(*void)(*instance)));
        assert(size_of(type_of(lua_Debug.currentline)) == 4, "lua_Debug.currentline has unexpected size % instead of 4", size_of(type_of(lua_Debug.currentline)));
        assert(((cast(*void)(*instance.nups)) - cast(*void)(*instance)) == 44, "lua_Debug.nups has unexpected offset % instead of 44", ((cast(*void)(*instance.nups)) - cast(*void)(*instance)));
        assert(size_of(type_of(lua_Debug.nups)) == 4, "lua_Debug.nups has unexpected size % instead of 4", size_of(type_of(lua_Debug.nups)));
        assert(((cast(*void)(*instance.linedefined)) - cast(*void)(*instance)) == 48, "lua_Debug.linedefined has unexpected offset % instead of 48", ((cast(*void)(*instance.linedefined)) - cast(*void)(*instance)));
        assert(size_of(type_of(lua_Debug.linedefined)) == 4, "lua_Debug.linedefined has unexpected size % instead of 4", size_of(type_of(lua_Debug.linedefined)));
        assert(((cast(*void)(*instance.lastlinedefined)) - cast(*void)(*instance)) == 52, "lua_Debug.lastlinedefined has unexpected offset % instead of 52", ((cast(*void)(*instance.lastlinedefined)) - cast(*void)(*instance)));
        assert(size_of(type_of(lua_Debug.lastlinedefined)) == 4, "lua_Debug.lastlinedefined has unexpected size % instead of 4", size_of(type_of(lua_Debug.lastlinedefined)));
        assert(((cast(*void)(*instance.short_src)) - cast(*void)(*instance)) == 56, "lua_Debug.short_src has unexpected offset % instead of 56", ((cast(*void)(*instance.short_src)) - cast(*void)(*instance)));
        assert(size_of(type_of(lua_Debug.short_src)) == 60, "lua_Debug.short_src has unexpected size % instead of 60", size_of(type_of(lua_Debug.short_src)));
        assert(((cast(*void)(*instance.i_ci)) - cast(*void)(*instance)) == 116, "lua_Debug.i_ci has unexpected offset % instead of 116", ((cast(*void)(*instance.i_ci)) - cast(*void)(*instance)));
        assert(size_of(type_of(lua_Debug.i_ci)) == 4, "lua_Debug.i_ci has unexpected size % instead of 4", size_of(type_of(lua_Debug.i_ci)));
        assert(size_of(lua_Debug) == 120, "lua_Debug has size % instead of 120", size_of(lua_Debug));
    }
}

