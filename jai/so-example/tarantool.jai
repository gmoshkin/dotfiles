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

PACKAGE_VERSION_MAJOR :: 2;

PACKAGE_VERSION_MINOR :: 11;

PACKAGE_VERSION_PATCH :: 0;

PACKAGE_VERSION :: "2.11.0-0-g247a9a4183";

SYSCONF_DIR :: "etc";

INSTALL_PREFIX :: "/home/gmoshkin/.local";

BUILD_TYPE :: "Debug";

BUILD_INFO :: "Linux-x86_64-Debug";

BUILD_OPTIONS :: "cmake . -DCMAKE_INSTALL_PREFIX=/home/gmoshkin/.local -DENABLE_BACKTRACE=TRUE";

COMPILER_INFO :: "GNU-10.3.0";

TARANTOOL_C_FLAGS :: " -fexceptions -funwind-tables -fasynchronous-unwind-tables -fno-common -fopenmp -msse2 -Wformat -Wformat-security -Werror=format-security -fstack-protector-strong -fPIC -fmacro-prefix-map=/home/gmoshkin/code/pd/tarantool=. -std=c11 -Wall -Wextra -Wno-gnu-alignof-expression -fno-gnu89-inline -Wno-cast-function-type -Werror";

TARANTOOL_CXX_FLAGS :: " -fexceptions -funwind-tables -fasynchronous-unwind-tables -fno-common -fopenmp -msse2 -Wformat -Wformat-security -Werror=format-security -fstack-protector-strong -fPIC -fmacro-prefix-map=/home/gmoshkin/code/pd/tarantool=. -std=c++11 -Wall -Wextra -Wno-invalid-offsetof -Wno-gnu-alignof-expression -Wno-cast-function-type -Werror";

MODULE_LIBDIR :: "/home/gmoshkin/.local/lib/tarantool";

MODULE_LUADIR :: "/home/gmoshkin/.local/share/tarantool";

MODULE_INCLUDEDIR :: "/home/gmoshkin/.local/include/tarantool";

MODULE_LUAPATH :: "/usr/local/share/tarantool/?.lua;/usr/local/share/tarantool/?/init.lua;/home/gmoshkin/.local/share/tarantool/?.lua;/home/gmoshkin/.local/share/tarantool/?/init.lua;/usr/share/tarantool/?.lua;/usr/share/tarantool/?/init.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;/home/gmoshkin/.local/share/lua/5.1/?.lua;/home/gmoshkin/.local/share/lua/5.1/?/init.lua;/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua";

MODULE_LIBPATH :: "/usr/local/lib/x86_64-linux-gnu/tarantool/?.so;/home/gmoshkin/.local/lib/tarantool/?.so;/usr/local/lib/tarantool/?.so;/usr/lib/x86_64-linux-gnu/tarantool/?.so;/usr/local/lib/x86_64-linux-gnu/lua/5.1/?.so;/home/gmoshkin/.local/lib/lua/5.1/?.so;/usr/local/lib/lua/5.1/?.so;/usr/lib/x86_64-linux-gnu/lua/5.1/?.so";

MODULE_LIBSUFFIX :: ".so";

BOX_DECIMAL_STRING_BUFFER_SIZE :: 128;

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

/**
* Function, which registers or deletes on_shutdown handler.
* @param[in] arg on_shutdown function's argument.
* @param[in] new_handler New on_shutdown handler, in
*            case this argument is NULL, function finds
*            and destroys old on_shutdown handler.
* @param[in] old_handler Old on_shutdown handler.
* @retval return 0 if success otherwise return -1 and sets
*                  errno. There are three cases when
*                  function fails:
*                  - both old_handler and new_handler are equal to
*                    zero (sets errno to EINVAL).
*                  - old_handler != NULL, but there is no trigger
*                    with such function (sets errno to EINVAL).
*                  - malloc for some internal struct memory allocation
*                    return NULL (errno sets by malloc to ENOMEM).
*/
box_on_shutdown :: (arg: *void, new_handler: #type (unknown0: *void) -> s32 #c_call, old_handler: #type (unknown0: *void) -> s32 #c_call) -> s32 #foreign __UnknownLib;

/** Log levels */
say_level :: enum u32 {
    FATAL    :: 0;
    SYSERROR :: 1;
    ERROR    :: 2;
    CRIT     :: 3;
    WARN     :: 4;
    INFO     :: 5;
    VERBOSE  :: 6;
    DEBUG    :: 7;

    S_FATAL    :: FATAL;
    S_SYSERROR :: SYSERROR;
    S_ERROR    :: ERROR;
    S_CRIT     :: CRIT;
    S_WARN     :: WARN;
    S_INFO     :: INFO;
    S_VERBOSE  :: VERBOSE;
    S_DEBUG    :: DEBUG;
}

/** Log formats */
say_format :: enum u32 {
    SF_PLAIN :: 0;
    SF_JSON  :: 1;
    MAX      :: 2;
    say_format_MAX :: MAX;
}

log_level: s32 #elsewhere __UnknownLib;

/**
* This function is called for every log which log level is not less than
* log_level_flightrec.
*/
log_write_flightrec: #type (level: s32, filename: *u8, line: s32, error: *u8, format: *u8, ap: va_list) -> void #c_call #elsewhere __UnknownLib;

/** \endcond public */
/** \cond public */
sayfunc_t :: #type (unknown0: s32, unknown1: *u8, unknown2: s32, unknown3: *u8, unknown4: *u8, __args: ..Any) -> void #c_call;

/** Internal function used to implement say() macros */
_say: sayfunc_t #elsewhere __UnknownLib;

/**
* Internal function that implements MT-Safe strerror().
* It is used by say_syserror() macro.
*/
_say_strerror :: (errnum: s32) -> *u8 #foreign __UnknownLib;

/**
* Fiber attributes container
*/
fiber_attr :: struct {}

/**
* Create a new fiber attribute container and initialize it
* with default parameters.
* Can be used for many fibers creation, corresponding fibers
* will not take ownership.
*/
fiber_attr_new :: () -> *fiber_attr #foreign __UnknownLib;

/**
* Delete the fiber_attr and free all allocated resources.
* This is safe when fibers created with this attribute still exist.
*
*\param fiber_attr fiber attribute
*/
fiber_attr_delete :: (fiber_attr: *fiber_attr) -> void #foreign __UnknownLib;

/**
* Set stack size for the fiber attribute.
*
* \param fiber_attribute fiber attribute container
* \param stacksize stack size for new fibers
*/
fiber_attr_setstacksize :: (fiber_attr: *fiber_attr, stack_size: size_t) -> s32 #foreign __UnknownLib;

/**
* Get stack size from the fiber attribute.
*
* \param fiber_attribute fiber attribute container or NULL for default
* \retval stack size
*/
fiber_attr_getstacksize :: (fiber_attr: *fiber_attr) -> size_t #foreign __UnknownLib;

fiber :: struct {}

/**
* Fiber - contains information about fiber
*/
fiber_func :: #type (unknown0: va_list) -> s32 #c_call;

/**
* Return the current fiber
*/
fiber_self :: () -> *fiber #foreign __UnknownLib;

/**
* Create a new fiber.
*
* Takes a fiber from fiber cache, if it's not empty.
* Can fail only if there is not enough memory for
* the fiber structure or fiber stack.
*
* The created fiber automatically returns itself
* to the fiber cache when its "main" function
* completes.
*
* \param name       string with fiber name
* \param fiber_func func for run inside fiber
*
* \sa fiber_start
*/
fiber_new :: (name: *u8, f: fiber_func) -> *fiber #foreign __UnknownLib;

/**
* Create a new fiber with defined attributes.
*
* Can fail only if there is not enough memory for
* the fiber structure or fiber stack.
*
* The created fiber automatically returns itself
* to the fiber cache if has default stack size
* when its "main" function completes.
*
* \param name       string with fiber name
* \param fiber_attr fiber attributes
* \param fiber_func func for run inside fiber
*
* \sa fiber_start
*/
fiber_new_ex :: (name: *u8, fiber_attr: *fiber_attr, f: fiber_func) -> *fiber #foreign __UnknownLib;

/**
* Return control to another fiber and wait until it'll be woken.
*
* \sa fiber_wakeup
*/
fiber_yield :: () -> void #foreign __UnknownLib;

/**
* Start execution of created fiber.
*
* \param callee fiber to start
* \param ...    arguments to start the fiber with
*
* \sa fiber_new
*/
fiber_start :: (callee: *fiber, __args: ..Any) -> void #foreign __UnknownLib;

/**
* Set a pointer to context for the fiber. Can be used to avoid calling
* fiber_start which means no yields.
*
* \param f     fiber to set the context for
* \param f_arg context for the fiber function
*/
fiber_set_ctx :: (f: *fiber, f_arg: *void) -> void #foreign __UnknownLib;

/**
* Get the context for the fiber which was set via the fiber_set_ctx
* function. Can be used to avoid calling fiber_start which means no yields.
*
* \retval      context for the fiber function set by fiber_set_ctx function
*
* \sa fiber_set_ctx
*/
fiber_get_ctx :: (f: *fiber) -> *void #foreign __UnknownLib;

/**
* Interrupt a synchronous wait of a fiber. Nop for the currently running fiber.
*
* \param f fiber to be woken up
*/
fiber_wakeup :: (f: *fiber) -> void #foreign __UnknownLib;

/**
* Cancel the subject fiber.
*
* Cancellation is asynchronous. Use fiber_join() to wait for the cancellation
* to complete.
*
* After fiber_cancel() is called, the fiber may or may not check whether it
* was cancelled. If the fiber does not check it, it cannot ever be cancelled.
* However, as long as most of the cooperative code calls fiber_testcancel(),
* most of the fibers are cancellable.
*
* \param f fiber to be cancelled
*/
fiber_cancel :: (f: *fiber) -> void #foreign __UnknownLib;

/**
* Deprecated.
*
* @return true
*/
fiber_set_cancellable :: (yesno: bool) -> bool #foreign __UnknownLib;

/**
* Set fiber to be joinable (false by default).
* \param yesno status to set
*/
fiber_set_joinable :: (fiber: *fiber, yesno: bool) -> void #foreign __UnknownLib;

/**
* Wait until the fiber is dead and then move its execution
* status to the caller.
* The fiber must not be detached (@sa fiber_set_joinable()).
* @pre FIBER_IS_JOINABLE flag is set.
*
* \param f fiber to be woken up
* \return fiber function ret code
*/
fiber_join :: (f: *fiber) -> s32 #foreign __UnknownLib;

/**
* Wait until the fiber is dead or timeout exceeded.
* In case timeout == TIMEOUT_INFINITY, this function
* same as fiber_join function.
* Return fiber execution status to the caller or -1
* if timeout exceeded and set diag.
* The fiber must not be detached (@sa fiber_set_joinable()).
* @pre FIBER_IS_JOINABLE flag is set.
*
* \param f fiber to be woken up
* \param timeout time during which we wait for the fiber completion
* \return fiber function ret code or -1 in case if timeout exceeded
*/
fiber_join_timeout :: (f: *fiber, timeout: float64) -> s32 #foreign __UnknownLib;

/**
* Put the current fiber to sleep for at least 's' seconds.
*
* \param s time to sleep
*
* \note this is a cancellation point (\sa fiber_is_cancelled)
*/
fiber_sleep :: (s: float64) -> void #foreign __UnknownLib;

/**
* Check current fiber for cancellation (it must be checked
* manually).
*/
fiber_is_cancelled :: () -> bool #foreign __UnknownLib;

/**
* Report loop begin time as double (cheap).
* Uses real time clock.
*/
fiber_time :: () -> float64 #foreign __UnknownLib;

/**
* Report loop begin time as 64-bit int.
* Uses real time clock.
*/
fiber_time64 :: () -> s64 #foreign __UnknownLib;

/**
* Report loop begin time as double (cheap).
* Uses monotonic clock.
*/
fiber_clock :: () -> float64 #foreign __UnknownLib;

/**
* Report loop begin time as 64-bit int.
* Uses monotonic clock.
*/
fiber_clock64 :: () -> s64 #foreign __UnknownLib;

/**
* Reschedule fiber to end of event loop cycle.
*/
fiber_reschedule :: () -> void #foreign __UnknownLib;

/**
* Return slab_cache suitable to use with tarantool/small library
*/
slab_cache :: struct {}

cord_slab_cache :: () -> *slab_cache #foreign __UnknownLib;

/** How much memory is used by the box region. */
box_region_used :: () -> size_t #foreign __UnknownLib;

/**
* Allocate size bytes from the box region.
*
* Don't use this function to allocate a memory block for a value
* or array of values of a type with alignment requirements. A
* violation of alignment requirements leads to undefined
* behaviour.
*
* In case of a memory error set a diag and return NULL.
* @sa <box_error_last>().
*/
box_region_alloc :: (size: size_t) -> *void #foreign __UnknownLib;

/**
* Allocate size bytes from the box region with given alignment.
*
* Alignment must be a power of 2.
*
* In case of a memory error set a diag and return NULL.
* @sa <box_error_last>().
*/
box_region_aligned_alloc :: (size: size_t, alignment: size_t) -> *void #foreign __UnknownLib;

/**
* Truncate the box region to the given size.
*/
box_region_truncate :: (size: size_t) -> void #foreign __UnknownLib;

/**
* Conditional variable for cooperative multitasking (fibers).
*
* A cond (short for "condition variable") is a synchronization primitive
* that allow fibers to yield until some predicate is satisfied. Fiber
* conditions have two basic operations - wait() and signal(). wait()
* suspends execution of fiber (i.e. yields) until signal() is called.
* Unlike pthread_cond, fiber_cond doesn't require mutex/latch wrapping.
*
*/
fiber_cond :: struct {}

/**
* Instantiate a new fiber cond object.
*/
fiber_cond_new :: () -> *fiber_cond #foreign __UnknownLib;

/**
* Delete the fiber cond object.
* Behaviour is undefined if there are fiber waiting for the cond.
*/
fiber_cond_delete :: (cond: *fiber_cond) -> void #foreign __UnknownLib;

/**
* Wake one fiber waiting for the cond.
* Does nothing if no one is waiting.
* @param cond condition
*/
fiber_cond_signal :: (cond: *fiber_cond) -> void #foreign __UnknownLib;

/**
* Wake up all fibers waiting for the cond.
* @param cond condition
*/
fiber_cond_broadcast :: (cond: *fiber_cond) -> void #foreign __UnknownLib;

/**
* Suspend the execution of the current fiber (i.e. yield) until
* fiber_cond_signal() is called. Like pthread_cond, fiber_cond can issue
* spurious wake ups caused by explicit fiber_wakeup() or fiber_cancel()
* calls. It is highly recommended to wrap calls to this function into a loop
* and check an actual predicate and fiber_testcancel() on every iteration.
*
* @param cond condition
* @param timeout timeout in seconds
* @retval 0 on fiber_cond_signal() call or a spurious wake up
* @retval -1 on timeout or fiber cancellation, diag is set
*/
fiber_cond_wait_timeout :: (cond: *fiber_cond, timeout: float64) -> s32 #foreign __UnknownLib;

/**
* Shortcut for fiber_cond_wait_timeout().
* @see fiber_cond_wait_timeout()
*/
fiber_cond_wait :: (cond: *fiber_cond) -> s32 #foreign __UnknownLib;

/** \endcond public */
/** \cond public */
COIO :: enum u32 {
    READ  :: 1;

    WRITE :: 2;

    COIO_READ  :: READ;

    COIO_WRITE :: WRITE;
}

/**
* Wait until READ or WRITE event on socket (\a fd). Yields.
* \param fd - non-blocking socket file description
* \param events - requested events to wait.
* Combination of TNT_IO_READ | TNT_IO_WRITE bit flags.
* \param timeout - timeout in seconds.
* \retval 0 - timeout
* \retval >0 - returned events. Combination of TNT_IO_READ | TNT_IO_WRITE
* bit flags.
*/
coio_wait :: (fd: s32, event: s32, timeout: float64) -> s32 #foreign __UnknownLib;

/**
* Close the fd and wake any fiber blocked in
* coio_wait() call on this fd.
*/
coio_close :: (fd: s32) -> s32 #foreign __UnknownLib;

/**
* Create new eio task with specified function and
* arguments. Yield and wait until the task is complete.
*
* This function doesn't throw exceptions to avoid double error
* checking: in most cases it's also necessary to check the return
* value of the called function and perform necessary actions. If
* func sets errno, the errno is preserved across the call.
*
* @retval -1 and errno = ENOMEM if failed to create a task
* @retval the function return (errno is preserved).
*
* @code
*	static ssize_t openfile_cb(va_list ap)
*	{
*	         const char *filename = va_arg(ap);
*	         int flags = va_arg(ap);
*	         return open(filename, flags);
*	}
*
*	if (coio_call(openfile_cb, "/tmp/file", 0) == -1)
*		// handle errors.
*	...
* @endcode
*/
coio_call :: (func: #type (unknown0: va_list) -> ssize_t #c_call, __args: ..Any) -> ssize_t #foreign __UnknownLib;

addrinfo :: struct {}

/**
* Fiber-friendly version of getaddrinfo(3).
*
* @param host host name, i.e. "tarantool.org"
* @param port service name, i.e. "80" or "http"
* @param hints hints, see getaddrinfo(3)
* @param res[out] result, see getaddrinfo(3)
* @param timeout timeout
* @retval  0 on success, please free @a res using freeaddrinfo(3).
* @retval -1 on error, check diag.
*            Please note that the return value is not compatible with
*            getaddrinfo(3).
* @sa getaddrinfo()
*/
coio_getaddrinfo :: (host: *u8, port: *u8, hints: *addrinfo, res: **addrinfo, timeout: float64) -> s32 #foreign __UnknownLib;

ibuf :: struct {}
/** \endcond public */
/** \cond public */
box_ibuf_t :: ibuf;

/**
* Reserve requested amount of bytes in ibuf buffer
* @param ibuf buffer used for allocation
* @param size allocated bytes
* @retval NULL on error, check diag.
*/
box_ibuf_reserve :: (ibuf: *box_ibuf_t, size: size_t) -> *void #foreign __UnknownLib;

/**
* Return pointers to read range pointers used [rpos..wpos)
* @param ibuf ibuf structure
* @param rpos where to place ibuf.rpos address
* @param wpos where to place ibuf.wpos address
*/
box_ibuf_read_range :: (ibuf: *box_ibuf_t, rpos: ***u8, wpos: ***u8) -> void #foreign __UnknownLib;

/**
* Return pointers to write range pointers used [wpos..end)
* @param ibuf ibuf structure
* @param wpos where to place ibuf.rpos address
* @param end where to place ibuf.wpos address
*/
box_ibuf_write_range :: (ibuf: *box_ibuf_t, wpos: ***u8, end: ***u8) -> void #foreign __UnknownLib;

/**
* Checks whether a value on the Lua stack is a cdata.
*
* Unlike <luaL_checkcdata>() this function does not raise an
* error. It is useful to raise a domain specific error.
*
* Lua API and module API don't expose LUA_TCDATA constant.
* We have no guarantee that this constant will remain the same in
* future LuaJIT versions. So this function should be used in
* modules instead of `lua_type(L, idx) == LUA_TCDATA`.
*
* @param L    Lua state.
* @param idx  Acceptable index on the Lua stack.
*
* @retval 1   If the value at the given index is a cdata.
* @retval 0   Otherwise.
*/
luaL_iscdata :: (L: *lua_State, idx: s32) -> s32 #foreign __UnknownLib;

/**
* @brief Push cdata of given \a ctypeid onto the stack.
* CTypeID must be used from FFI at least once. Allocated memory returned
* uninitialized. Only numbers and pointers are supported.
* @param L Lua State
* @param ctypeid FFI's CTypeID of this cdata
* @sa luaL_checkcdata
* @return memory associated with this cdata
*/
luaL_pushcdata :: (L: *lua_State, ctypeid: u32) -> *void #foreign __UnknownLib;

/**
* @brief Checks whether the function argument idx is a cdata
* @param L Lua State
* @param idx stack index
* @param ctypeid FFI's CTypeID of this cdata
* @sa luaL_pushcdata
* @return memory associated with this cdata
*/
luaL_checkcdata :: (L: *lua_State, idx: s32, ctypeid: *u32) -> *void #foreign __UnknownLib;

/**
* @brief Sets finalizer function on a cdata object.
* Equivalent to call ffi.gc(obj, function).
* Finalizer function must be on the top of the stack.
* @param L Lua State
* @param idx object
*/
luaL_setcdatagc :: (L: *lua_State, idx: s32) -> void #foreign __UnknownLib;

/**
* @brief Return CTypeID (FFI) of given СDATA type
* @param L Lua State
* @param ctypename С type name as string (e.g. "struct request" or "uint32_t")
* @sa luaL_pushcdata
* @sa luaL_checkcdata
* @return CTypeID
*/
luaL_ctypeid :: (L: *lua_State, ctypename: *u8) -> u32 #foreign __UnknownLib;

/**
* @brief Declare symbols for FFI
* @param L Lua State
* @param ctypename C definitions, e.g "struct stat"
* @sa ffi.cdef(def)
* @retval 0 on success
* @retval LUA_ERRRUN, LUA_ERRMEM, LUA_ERRERR otherwise
*/
luaL_cdef :: (L: *lua_State, ctypename: *u8) -> s32 #foreign __UnknownLib;

/**
* Push uint64_t onto the stack
*
* @param L is a Lua State
* @param val is a value to push
*/
luaL_pushuint64 :: (L: *lua_State, val: u64) -> void #foreign __UnknownLib;

/**
* Push int64_t onto the stack
*
* @param L is a Lua State
* @param val is a value to push
*/
luaL_pushint64 :: (L: *lua_State, val: s64) -> void #foreign __UnknownLib;

/**
* Checks whether the argument idx is a uint64 or a convertible string and
* returns this number.
* \throws error if the argument can't be converted.
*/
luaL_checkuint64 :: (L: *lua_State, idx: s32) -> u64 #foreign __UnknownLib;

/**
* Checks whether the argument idx is a int64 or a convertible string and
* returns this number.
* \throws error if the argument can't be converted.
*/
luaL_checkint64 :: (L: *lua_State, idx: s32) -> s64 #foreign __UnknownLib;

/**
* Checks whether the argument idx is a uint64 or a convertible string and
* returns this number.
* \return the converted number or 0 of argument can't be converted.
*/
luaL_touint64 :: (L: *lua_State, idx: s32) -> u64 #foreign __UnknownLib;

/**
* Checks whether the argument idx is a int64 or a convertible string and
* returns this number.
* \return the converted number or 0 of argument can't be converted.
*/
luaL_toint64 :: (L: *lua_State, idx: s32) -> s64 #foreign __UnknownLib;

/**
* Like lua_call(), but with the proper support of Tarantool errors.
* \sa lua_call()
*/
luaT_call :: (L: *lua_State, nargs: s32, nreturns: s32) -> s32 #foreign __UnknownLib;

/*
* Like luaL_dostring(), but in case of error sets fiber diag instead
* of putting error on stack.
*/
luaT_dostring :: (L: *lua_State, str: *u8) -> s32 #foreign __UnknownLib;

/**
* Like lua_cpcall(), but with the proper support of Tarantool errors.
* \sa lua_cpcall()
*/
luaT_cpcall :: (L: *lua_State, func: lua_CFunction, ud: *void) -> s32 #foreign __UnknownLib;

/**
* Get global Lua state used by Tarantool
*/
luaT_state :: () -> *lua_State #foreign __UnknownLib;

/**
* Like lua_tolstring, but supports metatables, booleans and nil properly.
*/
luaT_tolstring :: (L: *lua_State, idx: s32, ssize: *size_t) -> *u8 #foreign __UnknownLib;

/**
* Check whether a Lua object is a function or has
* metatable/metatype with a __call field.
*
* Note: It does not check type of __call metatable/metatype
* field.
*/
luaL_iscallable :: (L: *lua_State, idx: s32) -> s32 #foreign __UnknownLib;

/**
* Check if a value on @a L stack by index @a idx is an ibuf
* object. Both 'struct ibuf' and 'struct ibuf *' are accepted.
* Returns NULL, if can't convert - not an ibuf object.
*/
luaT_toibuf :: (L: *lua_State, idx: s32) -> *box_ibuf_t #foreign __UnknownLib;

/** \endcond public */
/** \cond public */
error :: struct {}

/**
* Re-throws the last Tarantool error as a Lua object.
* \sa lua_error()
* \sa box_error_last()
*/
luaT_error :: (L: *lua_State) -> s32 #foreign __UnknownLib;

/**
* Return nil as the first return value and an error as the
* second. The error is received using box_error_last().
*
* @param L Lua stack.
*/
luaT_push_nil_and_error :: (L: *lua_State) -> s32 #foreign __UnknownLib;

luaT_pusherror :: (L: *lua_State, e: *error) -> void #foreign __UnknownLib;

/** \endcond public */
/** \cond public */
/**
* When a transaction calls `commit`, this action can last for some time until
* redo data is written to WAL. While such a `commit` call is in progress we
* call changes of such a transaction as 'committed', and when the process is
* finished - we call the changes as 'confirmed'. One of the main options of
* a transaction is to see or not to see 'committed' changes.
* Note that now there are different terminologies in different places. This
* enum uses new 'committed' and 'confirmed' states of transactions. Meanwhile
* in engined the first state is usually called as 'prepared', and the second
* as 'committed' or 'completed'.
* Warning: this enum is exposed in lua via ffi, and thus any change in items
* must be correspondingly modified on ffi.cdef(), see schema.lua.
*/
txn_isolation_level :: enum u32 {
    TXN_ISOLATION_DEFAULT        :: 0;

    TXN_ISOLATION_READ_COMMITTED :: 1;

    TXN_ISOLATION_READ_CONFIRMED :: 2;

    TXN_ISOLATION_BEST_EFFORT    :: 3;

    TXN_ISOLATION_LINEARIZABLE   :: 4;

    MAX                          :: 5;
    txn_isolation_level_MAX :: MAX;
}

/**
* Transaction id - a non-persistent unique identifier
* of the current transaction. -1 if there is no current
* transaction.
*/
box_txn_id :: () -> s64 #foreign __UnknownLib;

/**
* Get isolation level of current transaction, one of enum txn_isolation_level
* values (but cannot be TXN_ISOLATION_DEFAULT (which is zero) by design).
* -1 if there is no current transaction.
*/
box_txn_isolation :: () -> s32 #foreign __UnknownLib;

/**
* Return true if there is an active transaction.
*/
box_txn :: () -> bool #foreign __UnknownLib;

/**
* Begin a transaction in the current fiber.
*
* A transaction is attached to caller fiber, therefore one fiber can have
* only one active transaction.
*
* @retval 0 - success
* @retval -1 - failed, perhaps a transaction has already been
* started
*/
box_txn_begin :: () -> s32 #foreign __UnknownLib;

/**
* Commit the current transaction.
* @retval 0 - success
* @retval -1 - failed, perhaps a disk write failure.
* started
*/
box_txn_commit :: () -> s32 #foreign __UnknownLib;

/**
* Rollback the current transaction.
* May fail if called from a nested
* statement.
*/
box_txn_rollback :: () -> s32 #foreign __UnknownLib;

/**
* Allocate memory on txn memory pool.
* The memory is automatically deallocated when the transaction
* is committed or rolled back.
*
* @retval NULL out of memory
*/
box_txn_alloc :: (size: size_t) -> *void #foreign __UnknownLib;

/**
* Set @a timeout for transaction, when it expires, transaction
* will be rolled back.
*
* @retval 0 if success
* @retval -1 if timeout is less than or equal to 0, there is
*            no current transaction or rollback timer for
*            current transaction is already started.
*/
box_txn_set_timeout :: (timeout: float64) -> s32 #foreign __UnknownLib;

/**
* Set an isolation @a level for a transaction.
* Must be called before the first DML.
* The level must be of enun txn_isolation_level values.
* @retval 0 if success
* @retval -1 if failed, diag is set.
*
*/
box_txn_set_isolation :: (level: u32) -> s32 #foreign __UnknownLib;

tuple_format :: struct {}
/** \endcond public */
/** \cond public */
box_tuple_format_t :: tuple_format;

/**
* Tuple Format.
*
* Each Tuple has associated format (class). Default format is used to
* create tuples which are not attach to any particular space.
*/
box_tuple_format_default :: () -> *box_tuple_format_t #foreign __UnknownLib;

tuple :: struct {}
/**
* Tuple
*/
box_tuple_t :: tuple;

/**
* Increase the reference counter of tuple.
*
* Tuples are reference counted. All functions that return tuples guarantee
* that the last returned tuple is refcounted internally until the next
* call to API function that yields or returns another tuple.
*
* You should increase the reference counter before taking tuples for long
* processing in your code. Such tuples will not be garbage collected even
* if another fiber remove they from space. After processing please
* decrement the reference counter using box_tuple_unref(), otherwise the
* tuple will leak.
*
* \param tuple a tuple
* \retval 0 always
* \sa box_tuple_unref()
*/
box_tuple_ref :: (tuple: *box_tuple_t) -> s32 #foreign __UnknownLib;

/**
* Decrease the reference counter of tuple.
*
* \param tuple a tuple
* \sa box_tuple_ref()
*/
box_tuple_unref :: (tuple: *box_tuple_t) -> void #foreign __UnknownLib;

/**
* Return the number of fields in tuple (the size of MsgPack Array).
* \param tuple a tuple
*/
box_tuple_field_count :: (tuple: *box_tuple_t) -> u32 #foreign __UnknownLib;

/**
* Return the number of bytes used to store internal tuple data (MsgPack Array).
* \param tuple a tuple
*/
box_tuple_bsize :: (tuple: *box_tuple_t) -> size_t #foreign __UnknownLib;

/**
* Dump raw MsgPack data to the memory buffer \a buf of size \a size.
*
* Store tuple fields in the memory buffer.
* \retval -1 on error.
* \retval number of bytes written on success.
* Upon successful return, the function returns the number of bytes written.
* If buffer size is not enough then the return value is the number of bytes
* which would have been written if enough space had been available.
*/
box_tuple_to_buf :: (tuple: *box_tuple_t, buf: *u8, size: size_t) -> ssize_t #foreign __UnknownLib;

/**
* Return the associated format.
* \param tuple tuple
* \return tuple_format
*/
box_tuple_format :: (tuple: *box_tuple_t) -> *box_tuple_format_t #foreign __UnknownLib;

/**
* Return the raw tuple field in MsgPack format.
*
* The buffer is valid until next call to box_tuple_* functions.
*
* \param tuple a tuple
* \param fieldno zero-based index in MsgPack array.
* \retval NULL if i >= box_tuple_field_count(tuple)
* \retval msgpack otherwise
*/
box_tuple_field :: (tuple: *box_tuple_t, fieldno: u32) -> *u8 #foreign __UnknownLib;

/**
* Return a raw tuple field in the MsgPack format pointed by
* a JSON path.
*
* The JSON path includes the outmost field. For example, "c" in
* ["a", ["b", "c"], "d"] can be accessed using "[2][2]" path (if
* index_base is 1, as in Lua). If index_base is set to 0, the
* same field will be pointed by the "[1][1]" path.
*
* The first JSON path token may be a field name if the tuple
* has associated format with named fields. A field of a nested
* map can be accessed in the same way: "foo.bar" or ".foo.bar".
*
* The return value is valid until the tuple is destroyed, see
* box_tuple_ref().
*
* Return NULL if the field does not exist or if the JSON path is
* malformed or invalid. Multikey JSON path token [*] is treated
* as invalid in this context.
*
* \param tuple a tuple
* \param path a JSON path
* \param path_len a length of @a path
* \param index_base 0 if array element indexes in @a path are
*        zero-based (like in C) or 1 if they're one-based (like
*        in Lua)
* \retval a pointer to a field data if the field exists or NULL
*/
box_tuple_field_by_path :: (tuple: *box_tuple_t, path: *u8, path_len: u32, index_base: s32) -> *u8 #foreign __UnknownLib;

tuple_iterator :: struct {}
/**
* Tuple iterator
*/
box_tuple_iterator_t :: tuple_iterator;

/**
* Allocate and initialize a new tuple iterator. The tuple iterator
* allow to iterate over fields at root level of MsgPack array.
*
* Example:
* \code
* box_tuple_iterator *it = box_tuple_iterator(tuple);
* if (it == NULL) {
*      // error handling using box_error_last()
* }
* const char *field;
* while (field = box_tuple_next(it)) {
*      // process raw MsgPack data
* }
*
* // rewind iterator to first position
* box_tuple_rewind(it);
* assert(box_tuple_position(it) == 0);
*
* // rewind iterator to first position
* field = box_tuple_seek(it, 3);
* assert(box_tuple_position(it) == 4);
*
* box_iterator_free(it);
* \endcode
*
* \post box_tuple_position(it) == 0
*/
box_tuple_iterator :: (tuple: *box_tuple_t) -> *box_tuple_iterator_t #foreign __UnknownLib;

/**
* Destroy and free tuple iterator
*/
box_tuple_iterator_free :: (it: *box_tuple_iterator_t) -> void #foreign __UnknownLib;

/**
* Return zero-based next position in iterator.
* That is, this function return the field id of field that will be
* returned by the next call to box_tuple_next(it). Returned value is zero
* after initialization or rewind and box_tuple_field_count(tuple)
* after the end of iteration.
*
* \param it tuple iterator
* \returns position.
*/
box_tuple_position :: (it: *box_tuple_iterator_t) -> u32 #foreign __UnknownLib;

/**
* Rewind iterator to the initial position.
*
* \param it tuple iterator
* \post box_tuple_position(it) == 0
*/
box_tuple_rewind :: (it: *box_tuple_iterator_t) -> void #foreign __UnknownLib;

/**
* Seek the tuple iterator.
*
* The returned buffer is valid until next call to box_tuple_* API.
* Requested fieldno returned by next call to box_tuple_next(it).
*
* \param it tuple iterator
* \param fieldno - zero-based position in MsgPack array.
* \post box_tuple_position(it) == fieldno if returned value is not NULL
* \post box_tuple_position(it) == box_tuple_field_count(tuple) if returned
* value is NULL.
*/
box_tuple_seek :: (it: *box_tuple_iterator_t, fieldno: u32) -> *u8 #foreign __UnknownLib;

/**
* Return the next tuple field from tuple iterator.
* The returned buffer is valid until next call to box_tuple_* API.
*
* \param it tuple iterator.
* \retval NULL if there are no more fields.
* \retval MsgPack otherwise
* \pre box_tuple_position(it) is zero-based id of returned field
* \post box_tuple_position(it) == box_tuple_field_count(tuple) if returned
* value is NULL.
*/
box_tuple_next :: (it: *box_tuple_iterator_t) -> *u8 #foreign __UnknownLib;

/**
* Allocate and initialize a new tuple from a raw MsgPack Array data.
*
* \param format tuple format.
* Use box_tuple_format_default() to create space-independent tuple.
* \param data tuple data in MsgPack Array format ([field1, field2, ...]).
* \param end the end of \a data
* \retval tuple
* \pre data, end is valid MsgPack Array
* \sa \code box.tuple.new(data) \endcode
*/
box_tuple_new :: (format: *box_tuple_format_t, data: *u8, end: *u8) -> *box_tuple_t #foreign __UnknownLib;

box_tuple_update :: (tuple: *box_tuple_t, expr: *u8, expr_end: *u8) -> *box_tuple_t #foreign __UnknownLib;

box_tuple_upsert :: (tuple: *box_tuple_t, expr: *u8, expr_end: *u8) -> *box_tuple_t #foreign __UnknownLib;

/**
* Check tuple data correspondence to the space format.
* @param tuple  Tuple to validate.
* @param format Format to which the tuple must match.
*
* @retval  0 The tuple is valid.
* @retval -1 The tuple is invalid.
*/
box_tuple_validate :: (tuple: *box_tuple_t, format: *box_tuple_format_t) -> s32 #foreign __UnknownLib;

key_def :: struct {}
/** \endcond public */
/** \cond public */
box_key_def_t :: key_def;

/** Key part definition flags. */
BOX_KEY_PART_DEF :: enum u32 {
    IS_NULLABLE  :: 1;
    EXCLUDE_NULL :: 2;

    BOX_KEY_PART_DEF_IS_NULLABLE  :: IS_NULLABLE;
    BOX_KEY_PART_DEF_EXCLUDE_NULL :: EXCLUDE_NULL;
}

/**
* It is recommended to verify size of <box_key_part_def_t>
* against this constant on the module side at build time.
* Example:
*
* | #if !defined(__cplusplus) && !defined(static_assert)
* | #define static_assert _Static_assert
* | #endif
* |
* | (slash)*
* |  * Verify that <box_key_part_def_t> has the same size when
* |  * compiled within tarantool and within the module.
* |  *
* |  * It is important, because the module allocates an array of key
* |  * parts and passes it to <box_key_def_new_v2>() tarantool
* |  * function.
* |  *(slash)
* | static_assert(sizeof(box_key_part_def_t) == BOX_KEY_PART_DEF_T_SIZE,
* |               "sizeof(box_key_part_def_t)");
*
* This snippet is not part of module.h, because portability of
* static_assert() / _Static_assert() is dubious. It should be
* decision of a module author how portable its code should be.
*/
anon_enum :: enum u32 {
    BOX_KEY_PART_DEF_T_SIZE :: 64;
}

/**
* Public representation of a key part definition.
*
* Usage: Allocate an array of such key parts, initialize each
* key part (call <box_key_part_def_create>() and set necessary
* fields), pass the array into <box_key_def_new_v2>() function.
*
* Important: A module should call <box_key_part_def_create>()
* to initialize the structure with default values. There is no
* guarantee that all future default values for fields and flags
* will be remain the same.
*
* The idea of separation from internal <struct key_part_def> is
* to provide stable API and ABI for modules.
*
* New fields may be added into the end of the structure in later
* tarantool versions. Also new flags may be introduced within
* <flags> field. <collation> cannot be changed to a union (to
* reuse for some other value), because it is verified even for
* a non-string key part by <box_key_def_new_v2>().
*
* Fields that are unknown at given tarantool version are ignored
* in general, but filled with zeros when initialized.
*/
box_key_part_def_t :: union {
    struct {
        /** Index of a tuple field (zero based). */
        fieldno:    u32;

        /** Flags, e.g. nullability. */
        flags:      u32;

        /** Type of the tuple field. */
        field_type: *u8;

        /** Collation name for string comparisons. */
        collation:  *u8;

        /**
        * JSON path to point a nested field.
        *
        * Example:
        *
        * tuple: [1, {"foo": "bar"}]
        * key parts: [
        *     {
        *         "fieldno": 2,
        *         "type": "string",
        *         "path": "foo"
        *     }
        * ]
        *
        * => key: ["bar"]
        *
        * Note: When the path is given, <field_type>
        * means type of the nested field.
        */
        path:       *u8;
    }

    /**
    * Padding to guarantee certain size across different
    * tarantool versions.
    */
    padding: [64] u8;
}

/**
* Create key definition with given field numbers and field types.
*
* May be used for tuple format creation and/or tuple comparison.
*
* \sa <box_key_def_new_v2>().
*
* \param fields array with key field identifiers
* \param types array with key field types (see enum field_type)
* \param part_count the number of key fields
* \returns a new key definition object
*/
box_key_def_new :: (fields: *u32, types: *u32, part_count: u32) -> *box_key_def_t #foreign __UnknownLib;

/**
* Initialize a key part with default values.
*
*  | Field       | Default value   | Details |
*  | ----------- | --------------- | ------- |
*  | fieldno     | 0               |         |
*  | flags       | <default flags> |         |
*  | field_type  | NULL            | [^1]    |
*  | collation   | NULL            |         |
*  | path        | NULL            |         |
*
* Default flag values are the following:
*
*  | Flag                          | Default value |
*  | ----------------------------- | ------------- |
*  | BOX_KEY_PART_DEF_IS_NULLABLE  | 0 (unset)     |
*  | BOX_KEY_PART_DEF_EXCLUDE_NULL | 0 (unset)     |
*
* Default values of fields and flags are permitted to be changed
* in future tarantool versions. However we should be VERY
* conservative here and consider any meaningful usage scenarios,
* when doing so. At least new defaults should be consistent with
* how tarantool itself doing key_def related operations:
* validation, key extraction, comparisons and so on.
*
* All trailing padding bytes are set to zero. The same for
* unknown <flags> bits.
*
* [^1]: <box_key_def_new_v2>() does not accept NULL as a
*       <field_type>, so it should be filled explicitly.
*/
box_key_part_def_create :: (part: *box_key_part_def_t) -> void #foreign __UnknownLib;

/**
* Create a key_def from given key parts.
*
* Unlike <box_key_def_new>() this function allows to define
* nullability, collation and other options for each key part.
*
* <box_key_part_def_t> fields that are unknown at given tarantool
* version are ignored. The same for unknown <flags> bits.
*
* In case of an error set a diag and return NULL.
* @sa <box_error_last>().
*/
box_key_def_new_v2 :: (parts: *box_key_part_def_t, part_count: u32) -> *box_key_def_t #foreign __UnknownLib;

/**
* Duplicate key_def.
* @param key_def Original key_def.
*
* @retval not NULL Duplicate of src.
*/
box_key_def_dup :: (key_def: *box_key_def_t) -> *box_key_def_t #foreign __UnknownLib;

/**
* Delete key definition
*
* \param key_def key definition to delete
*/
box_key_def_delete :: (key_def: *box_key_def_t) -> void #foreign __UnknownLib;

/**
* Dump key part definitions of given key_def.
*
* The function allocates key parts and storage for pointer fields
* (e.g. collation names) on the box region.
* @sa <box_region_truncate>().
*
* <box_key_part_def_t> fields that are unknown at given tarantool
* version are set to zero. The same for unknown <flags> bits.
*
* In case of an error set a diag and return NULL.
* @sa <box_error_last>().
*/
box_key_def_dump_parts :: (key_def: *box_key_def_t, part_count_ptr: *u32) -> *box_key_part_def_t #foreign __UnknownLib;

/**
* Check that tuple fields match with given key definition.
*
* @param key_def  Key definition.
* @param tuple    Tuple to validate.
*
* @retval 0   The tuple is valid.
* @retval -1  The tuple is invalid.
*
* In case of an invalid tuple set a diag and return -1.
* @sa <box_error_last>().
*/
box_key_def_validate_tuple :: (key_def: *box_key_def_t, tuple: *box_tuple_t) -> s32 #foreign __UnknownLib;

/**
* Compare tuples using the key definition.
* @param tuple_a first tuple
* @param tuple_b second tuple
* @param key_def key definition
* @retval 0  if key_fields(tuple_a) == key_fields(tuple_b)
* @retval <0 if key_fields(tuple_a) < key_fields(tuple_b)
* @retval >0 if key_fields(tuple_a) > key_fields(tuple_b)
*/
box_tuple_compare :: (tuple_a: *box_tuple_t, tuple_b: *box_tuple_t, key_def: *box_key_def_t) -> s32 #foreign __UnknownLib;

/**
* @brief Compare tuple with key using the key definition.
* @param tuple tuple
* @param key key with MessagePack array header
* @param key_def key definition
*
* @retval 0  if key_fields(tuple) == parts(key)
* @retval <0 if key_fields(tuple) < parts(key)
* @retval >0 if key_fields(tuple) > parts(key)
*/
box_tuple_compare_with_key :: (tuple_a: *box_tuple_t, key_b: *u8, key_def: *box_key_def_t) -> s32 #foreign __UnknownLib;

/**
* Allocate a new key_def with a set union of key parts from
* first and second key defs.
*
* Parts of the new key_def consist of the first key_def's parts
* and those parts of the second key_def that were not among the
* first parts.
*
* @retval not NULL  Ok.
* @retval NULL      Memory error.
*
* In case of an error set a diag and return NULL.
* @sa <box_error_last>().
*/
box_key_def_merge :: (first: *box_key_def_t, second: *box_key_def_t) -> *box_key_def_t #foreign __UnknownLib;

/**
* Extract key from tuple by given key definition and return
* buffer allocated on the box region with this key.
* @sa <box_region_truncate>().
*
* This function has O(n) complexity, where n is the number of key
* parts.
*
* @param key_def       Definition of key that need to extract.
* @param tuple         Tuple from which need to extract key.
* @param multikey_idx  Multikey index hint or -1.
* @param key_size_ptr  Here will be size of extracted key.
*
* @retval not NULL  Success.
* @retval NULL      Memory allocation error.
*
* In case of an error set a diag and return NULL.
* @sa <box_error_last>().
*/
box_key_def_extract_key :: (key_def: *box_key_def_t, tuple: *box_tuple_t, multikey_idx: s32, key_size_ptr: *u32) -> *u8 #foreign __UnknownLib;

/**
* Check a key against given key definition.
*
* Verifies key parts against given key_def's field types with
* respect to nullability.
*
* A partial key (with less part than defined in @a key_def) is
* verified by given key parts, the omitted tail is not verified
* anyhow.
*
* Note: nil is accepted for nullable fields, but only for them.
*
* @param key_def       Key definition.
* @param key           MessagePack'ed data for matching.
* @param key_size_ptr  Here will be size of the validated key.
*
* @retval 0   The key is valid.
* @retval -1  The key is invalid.
*
* In case of an invalid key set a diag and return -1.
* @sa <box_error_last>().
*/
box_key_def_validate_key :: (key_def: *box_key_def_t, key: *u8, key_size_ptr: *u32) -> s32 #foreign __UnknownLib;

/**
* Check a full key against given key definition.
*
* Verifies key parts against given key_def's field types with
* respect to nullability.
*
* Imposes the same parts count in @a key as in @a key_def.
* Absence of trailing key parts fails the check.
*
* Note: nil is accepted for nullable fields, but only for them.
*
* @param key_def       Key definition.
* @param key           MessagePack'ed data for matching.
* @param key_size_ptr  Here will be size of the validated key.
*
* @retval 0   The key is valid.
* @retval -1  The key is invalid.
*
* In case of an invalid key set a diag and return -1.
* @sa <box_error_last>().
*/
box_key_def_validate_full_key :: (key_def: *box_key_def_t, key: *u8, key_size_ptr: *u32) -> s32 #foreign __UnknownLib;

/*
* Possible field data types. Can't use STRS/ENUM macros for them,
* since there is a mismatch between enum name (STRING) and type
* name literal ("STR"). STR is already used as Objective C type.
*/
field_type :: enum u32 {
    FIELD_TYPE_ANY       :: 0;
    FIELD_TYPE_UNSIGNED  :: 1;
    FIELD_TYPE_STRING    :: 2;
    FIELD_TYPE_NUMBER    :: 3;
    FIELD_TYPE_DOUBLE    :: 4;
    FIELD_TYPE_INTEGER   :: 5;
    FIELD_TYPE_BOOLEAN   :: 6;
    FIELD_TYPE_VARBINARY :: 7;
    FIELD_TYPE_SCALAR    :: 8;
    FIELD_TYPE_DECIMAL   :: 9;
    FIELD_TYPE_UUID      :: 10;
    FIELD_TYPE_DATETIME  :: 11;
    FIELD_TYPE_INTERVAL  :: 12;
    FIELD_TYPE_ARRAY     :: 13;
    FIELD_TYPE_MAP       :: 14;
    MAX                  :: 15;
    field_type_MAX :: MAX;
}

on_conflict_action :: enum u32 {
    ON_CONFLICT_ACTION_NONE     :: 0;
    ON_CONFLICT_ACTION_ROLLBACK :: 1;
    ON_CONFLICT_ACTION_ABORT    :: 2;
    ON_CONFLICT_ACTION_FAIL     :: 3;
    ON_CONFLICT_ACTION_IGNORE   :: 4;
    ON_CONFLICT_ACTION_REPLACE  :: 5;
    ON_CONFLICT_ACTION_DEFAULT  :: 6;
    MAX                         :: 7;
    on_conflict_action_MAX :: MAX;
}

/**
* Return new in-memory tuple format based on passed key definitions.
*
* \param keys array of keys defined for the format
* \key_count count of keys
* \retval new tuple format if success
* \retval NULL for error
*/
box_tuple_format_new :: (keys: **key_def, key_count: u16) -> *box_tuple_format_t #foreign __UnknownLib;

/**
* Increment tuple format ref count.
*
* \param tuple_format the tuple format to ref
*/
box_tuple_format_ref :: (format: *box_tuple_format_t) -> void #foreign __UnknownLib;

/**
* Decrement tuple format ref count.
*
* \param tuple_format the tuple format to unref
*/
box_tuple_format_unref :: (format: *box_tuple_format_t) -> void #foreign __UnknownLib;

/** \endcond public */
/** \cond public */
BOX :: enum u32 {
    SYSTEM_ID_MIN            :: 256;

    VINYL_DEFERRED_DELETE_ID :: 257;

    SCHEMA_ID                :: 272;

    COLLATION_ID             :: 276;

    VCOLLATION_ID            :: 277;

    SPACE_ID                 :: 280;

    VSPACE_ID                :: 281;

    SEQUENCE_ID              :: 284;

    SEQUENCE_DATA_ID         :: 285;

    VSEQUENCE_ID             :: 286;

    INDEX_ID                 :: 288;

    VINDEX_ID                :: 289;

    FUNC_ID                  :: 296;

    VFUNC_ID                 :: 297;

    USER_ID                  :: 304;

    VUSER_ID                 :: 305;

    PRIV_ID                  :: 312;

    VPRIV_ID                 :: 313;

    CLUSTER_ID               :: 320;

    TRIGGER_ID               :: 328;

    TRUNCATE_ID              :: 330;

    SPACE_SEQUENCE_ID        :: 340;

    VSPACE_SEQUENCE_ID       :: 341;

    FK_CONSTRAINT_ID         :: 356;

    CK_CONSTRAINT_ID         :: 364;

    FUNC_INDEX_ID            :: 372;

    SESSION_SETTINGS_ID      :: 380;

    SYSTEM_ID_MAX            :: 511;
    ID_NIL                   :: 2147483647;

    BOX_SYSTEM_ID_MIN            :: SYSTEM_ID_MIN;

    BOX_VINYL_DEFERRED_DELETE_ID :: VINYL_DEFERRED_DELETE_ID;

    BOX_SCHEMA_ID                :: SCHEMA_ID;

    BOX_COLLATION_ID             :: COLLATION_ID;

    BOX_VCOLLATION_ID            :: VCOLLATION_ID;

    BOX_SPACE_ID                 :: SPACE_ID;

    BOX_VSPACE_ID                :: VSPACE_ID;

    BOX_SEQUENCE_ID              :: SEQUENCE_ID;

    BOX_SEQUENCE_DATA_ID         :: SEQUENCE_DATA_ID;

    BOX_VSEQUENCE_ID             :: VSEQUENCE_ID;

    BOX_INDEX_ID                 :: INDEX_ID;

    BOX_VINDEX_ID                :: VINDEX_ID;

    BOX_FUNC_ID                  :: FUNC_ID;

    BOX_VFUNC_ID                 :: VFUNC_ID;

    BOX_USER_ID                  :: USER_ID;

    BOX_VUSER_ID                 :: VUSER_ID;

    BOX_PRIV_ID                  :: PRIV_ID;

    BOX_VPRIV_ID                 :: VPRIV_ID;

    BOX_CLUSTER_ID               :: CLUSTER_ID;

    BOX_TRIGGER_ID               :: TRIGGER_ID;

    BOX_TRUNCATE_ID              :: TRUNCATE_ID;

    BOX_SPACE_SEQUENCE_ID        :: SPACE_SEQUENCE_ID;

    BOX_VSPACE_SEQUENCE_ID       :: VSPACE_SEQUENCE_ID;

    BOX_FK_CONSTRAINT_ID         :: FK_CONSTRAINT_ID;

    BOX_CK_CONSTRAINT_ID         :: CK_CONSTRAINT_ID;

    BOX_FUNC_INDEX_ID            :: FUNC_INDEX_ID;

    BOX_SESSION_SETTINGS_ID      :: SESSION_SETTINGS_ID;

    BOX_SYSTEM_ID_MAX            :: SYSTEM_ID_MAX;
    BOX_ID_NIL                   :: ID_NIL;
}

/**
* Returns the current version of the database schema, an unsigned number
* that goes up when there is a major change in the schema, i.e., on DDL
* operations (\sa IPROTO_SCHEMA_VERSION).
*/
box_schema_version :: () -> u64 #foreign __UnknownLib;

box_function_ctx :: struct {}
/*
* Opaque structure passed to the stored C procedure
*/
box_function_ctx_t :: box_function_ctx;

/**
* Return codes for IPROTO request handlers.
*/
iproto_handler_status :: enum u32 {
    OK       :: 0;

    ERROR    :: 1;

    FALLBACK :: 2;

    IPROTO_HANDLER_OK       :: OK;

    IPROTO_HANDLER_ERROR    :: ERROR;

    IPROTO_HANDLER_FALLBACK :: FALLBACK;
}

/**
* IPROTO request handler signature: receives MsgPack encoded header and body,
* a context provided by box_iproto_override(), and must return one of the
* status codes from iproto_handler_status.
*
* \param header Msgpack encoded header
* \param header_end end of Msgpack encoded header
* \param body Msgpack encoded body
* \param body_end end of Msgpack encoded body
* \param ctx context provided by box_iproto_override()
* \returns a status code
*/
iproto_handler_t :: #type (header: *u8, header_end: *u8, body: *u8, body_end: *u8, ctx: *void) -> iproto_handler_status #c_call;

/**
* IPROTO request handler destructor called when the corresponding handler is
* removed.
*
* \param ctx context provided by box_iproto_override()
*/
iproto_handler_destroy_t :: #type (ctx: *void) -> void #c_call;

/**
* Return a tuple from stored C procedure.
*
* Returned tuple is automatically reference counted by Tarantool.
*
* \param ctx an opaque structure passed to the stored C procedure by
* Tarantool
* \param tuple a tuple to return
* \retval -1 on error (perhaps, out of memory; check box_error_last())
* \retval 0 otherwise
*/
box_return_tuple :: (ctx: *box_function_ctx_t, tuple: *box_tuple_t) -> s32 #foreign __UnknownLib;

/**
* Return MessagePack from a stored C procedure. The MessagePack
* is copied, so it is safe to free/reuse the passed arguments
* after the call.
* MessagePack is not validated, for the sake of speed. It is
* expected to be a single encoded object. An attempt to encode
* and return multiple objects without wrapping them into an
* MP_ARRAY or MP_MAP is undefined behaviour.
*
* \param ctx An opaque structure passed to the stored C procedure
*        by Tarantool.
* \param mp Begin of MessagePack.
* \param mp_end End of MessagePack.
* \retval -1 Error.
* \retval 0 Success.
*/
box_return_mp :: (ctx: *box_function_ctx_t, mp: *u8, mp_end: *u8) -> s32 #foreign __UnknownLib;

/**
* Find space id by name.
*
* This function performs SELECT request to _vspace system space.
* \param name space name
* \param len length of \a name
* \retval BOX_ID_NIL on error or if not found (check box_error_last())
* \retval space_id otherwise
* \sa box_index_id_by_name
*/
box_space_id_by_name :: (name: *u8, len: u32) -> u32 #foreign __UnknownLib;

/**
* Find index id by name.
*
* This function performs SELECT request to _vindex system space.
* \param space_id space identifier
* \param name index name
* \param len length of \a name
* \retval BOX_ID_NIL on error or if not found (check box_error_last())
* \retval index_id otherwise
* \sa box_space_id_by_name
*/
box_index_id_by_name :: (space_id: u32, name: *u8, len: u32) -> u32 #foreign __UnknownLib;

/**
* Execute an INSERT request.
*
* \param space_id space identifier
* \param tuple encoded tuple in MsgPack Array format ([ field1, field2, ...])
* \param tuple_end end of @a tuple
* \param[out] result a new tuple. Can be set to NULL to discard result.
* \retval -1 on error (check box_error_last())
* \retval 0 on success
* \sa \code box.space[space_id]:insert(tuple) \endcode
*/
box_insert :: (space_id: u32, tuple: *u8, tuple_end: *u8, result: **box_tuple_t) -> s32 #foreign __UnknownLib;

/**
* Execute an REPLACE request.
*
* \param space_id space identifier
* \param tuple encoded tuple in MsgPack Array format ([ field1, field2, ...])
* \param tuple_end end of @a tuple
* \param[out] result a new tuple. Can be set to NULL to discard result.
* \retval -1 on error (check box_error_last())
* \retval 0 on success
* \sa \code box.space[space_id]:replace(tuple) \endcode
*/
box_replace :: (space_id: u32, tuple: *u8, tuple_end: *u8, result: **box_tuple_t) -> s32 #foreign __UnknownLib;

/**
* Execute an DELETE request.
*
* \param space_id space identifier
* \param index_id index identifier
* \param key encoded key in MsgPack Array format ([part1, part2, ...]).
* \param key_end the end of encoded \a key.
* \param[out] result an old tuple. Can be set to NULL to discard result.
* \retval -1 on error (check box_error_last())
* \retval 0 on success
* \sa \code box.space[space_id].index[index_id]:delete(key) \endcode
*/
box_delete :: (space_id: u32, index_id: u32, key: *u8, key_end: *u8, result: **box_tuple_t) -> s32 #foreign __UnknownLib;

/**
* Execute an UPDATE request.
*
* \param space_id space identifier
* \param index_id index identifier
* \param key encoded key in MsgPack Array format ([part1, part2, ...]).
* \param key_end the end of encoded \a key.
* \param ops encoded operations in MsgPack Array format, e.g.
* [ [ '=', fieldno,  value ],  ['!', 2, 'xxx'] ]
* \param ops_end the end of encoded \a ops
* \param index_base 0 if fieldnos in update operations are zero-based
* indexed (like C) or 1 if for one-based indexed field ids (like Lua).
* \param[out] result a new tuple. Can be set to NULL to discard result.
* \retval -1 on error (check box_error_last())
* \retval 0 on success
* \sa \code box.space[space_id].index[index_id]:update(key, ops) \endcode
* \sa box_upsert()
*/
box_update :: (space_id: u32, index_id: u32, key: *u8, key_end: *u8, ops: *u8, ops_end: *u8, index_base: s32, result: **box_tuple_t) -> s32 #foreign __UnknownLib;

/**
* Execute an UPSERT request.
*
* \param space_id space identifier
* \param index_id index identifier
* \param ops encoded operations in MsgPack Array format, e.g.
* [ [ '=', fieldno,  value ],  ['!', 2, 'xxx'] ]
* \param ops_end the end of encoded \a ops
* \param tuple encoded tuple in MsgPack Array format ([ field1, field2, ...])
* \param tuple_end end of @a tuple
* \param index_base 0 if fieldnos in update operations are zero-based
* indexed (like C) or 1 if for one-based indexed field ids (like Lua).
* \param[out] result a new tuple. Can be set to NULL to discard result.
* \retval -1 on error (check box_error_last())
* \retval 0 on success
* \sa \code box.space[space_id].index[index_id]:update(key, ops) \endcode
* \sa box_update()
*/
box_upsert :: (space_id: u32, index_id: u32, tuple: *u8, tuple_end: *u8, ops: *u8, ops_end: *u8, index_base: s32, result: **box_tuple_t) -> s32 #foreign __UnknownLib;

/**
* Truncate space.
*
* \param space_id space identifier
*/
box_truncate :: (space_id: u32) -> s32 #foreign __UnknownLib;

/**
* Advance a sequence.
*
* \param seq_id sequence identifier
* \param[out] result pointer to a variable where the next sequence
* value will be stored on success
* \retval -1 on error (check box_error_last())
* \retval 0 on success
*/
box_sequence_next :: (seq_id: u32, result: *s64) -> s32 #foreign __UnknownLib;

/**
* Get the last value returned by a sequence.
*
* \param seq_id sequence identifier
* \param[out] result pointer to a variable where the current sequence
* value will be stored on success
* \retval -1 on error (check box_error_last())
* \retval 0 on success
*/
box_sequence_current :: (seq_id: u32, result: *s64) -> s32 #foreign __UnknownLib;

/**
* Set a sequence value.
*
* \param seq_id sequence identifier
* \param value new sequence value; on success the next call to
* box_sequence_next() will return the value following \a value
* \retval -1 on error (check box_error_last())
* \retval 0 on success
*/
box_sequence_set :: (seq_id: u32, value: s64) -> s32 #foreign __UnknownLib;

/**
* Reset a sequence.
*
* \param seq_id sequence identifier
* \retval -1 on error (check box_error_last())
* \retval 0 on success
*/
box_sequence_reset :: (seq_id: u32) -> s32 #foreign __UnknownLib;

/**
* Push MessagePack data into a session data channel - socket,
* console or whatever is behind the session. Note, that
* successful push does not guarantee delivery in case it was sent
* into the network. Just like with write()/send() system calls.
*
* \param data begin of MessagePack to push
* \param data_end end of MessagePack to push
* \retval -1 on error (check box_error_last())
* \retval 0 on success
*/
box_session_push :: (data: *u8, data_end: *u8) -> s32 #foreign __UnknownLib;

/**
* \return current session's unique monotonic identifier (\sa box.session.id)
*/
box_session_id :: () -> u64 #foreign __UnknownLib;

/**
* Sends a packet with the given header and body over the IPROTO session's
* socket.
*
* NB: yields.
*
* \param sid IPROTO session identifier
* \param header MsgPack encoded header
* \param header_end MsgPack encoded header end
* \param body MsgPack encoded body
* \param body_end MsgPack encoded body end
* \retval -1 on error (check box_error_last())
* \retval 0 on success
*/
box_iproto_send :: (sid: u64, header: *u8, header_end: *u8, body: *u8, body_end: *u8) -> s32 #foreign __UnknownLib;

/**
* Sets an IPROTO request handler with the provided context for the
* given request type.
*
* NB: yields.
*
* \param req_type request type code from iproto_type enumeration
*                 (src/box/iproto_constants.h);
*                 use IPROTO_UNKNOWN for overriding the handler of unknown
*                 request types;
* \param handler IPROTO request handler; passing NULL resets the corresponding
*                handler
* \param destroy IPROTO request handler destructor
* \param ctx context passed to handler
* \retval -1 on error (check box_error_last())
* \retval 0 on success
*/
box_iproto_override :: (req_type: u32, handler: iproto_handler_t, destroy: iproto_handler_destroy_t, ctx: *void) -> s32 #foreign __UnknownLib;

iterator :: struct {}
/** \endcond public */
/** \cond public */
box_iterator_t :: iterator;

/**
* Allocate and initialize iterator for space_id, index_id.
*
* A returned iterator must be destroyed by box_iterator_free().
*
* \param space_id space identifier.
* \param index_id index identifier.
* \param type \link iterator_type iterator type \endlink
* \param key encoded key in MsgPack Array format ([part1, part2, ...]).
* \param key_end the end of encoded \a key
* \retval NULL on error (check box_error_last())
* \retval iterator otherwise
* \sa box_iterator_next()
* \sa box_iterator_free()
*/
box_index_iterator :: (space_id: u32, index_id: u32, type: s32, key: *u8, key_end: *u8) -> *box_iterator_t #foreign __UnknownLib;

/**
* Retrieve the next item from the \a iterator.
*
* \param iterator an iterator returned by box_index_iterator().
* \param[out] result a tuple or NULL if there is no more data.
* \retval -1 on error (check box_error_last() for details)
* \retval 0 on success. The end of data is not an error.
*/
box_iterator_next :: (iterator: *box_iterator_t, result: **box_tuple_t) -> s32 #foreign __UnknownLib;

/**
* Destroy and deallocate iterator.
*
* \param iterator an iterator returned by box_index_iterator()
*/
box_iterator_free :: (iterator: *box_iterator_t) -> void #foreign __UnknownLib;

/**
* Return the number of element in the index.
*
* \param space_id space identifier
* \param index_id index identifier
* \retval -1 on error (check box_error_last())
* \retval >= 0 otherwise
*/
box_index_len :: (space_id: u32, index_id: u32) -> ssize_t #foreign __UnknownLib;

/**
* Return the number of bytes used in memory by the index.
*
* \param space_id space identifier
* \param index_id index identifier
* \retval -1 on error (check box_error_last())
* \retval >= 0 otherwise
*/
box_index_bsize :: (space_id: u32, index_id: u32) -> ssize_t #foreign __UnknownLib;

/**
* Return a random tuple from the index (useful for statistical analysis).
*
* \param space_id space identifier
* \param index_id index identifier
* \param rnd random seed
* \param[out] result a tuple or NULL if index is empty
* \retval -1 on error (check box_error_last())
* \retval 0 on success
* \sa \code box.space[space_id].index[index_id]:random(rnd) \endcode
*/
box_index_random :: (space_id: u32, index_id: u32, rnd: u32, result: **box_tuple_t) -> s32 #foreign __UnknownLib;

/**
* Get a tuple from index by the key.
*
* Please note that this function works much more faster than
* box_select() or box_index_iterator() + box_iterator_next().
*
* \param space_id space identifier
* \param index_id index identifier
* \param key encoded key in MsgPack Array format ([part1, part2, ...]).
* \param key_end the end of encoded \a key
* \param[out] result a tuple or NULL if index is empty
* \retval -1 on error (check box_error_last())
* \retval 0 on success
* \pre key != NULL
* \sa \code box.space[space_id].index[index_id]:get(key) \endcode
*/
box_index_get :: (space_id: u32, index_id: u32, key: *u8, key_end: *u8, result: **box_tuple_t) -> s32 #foreign __UnknownLib;

/**
* Return a first (minimal) tuple matched the provided key.
*
* \param space_id space identifier
* \param index_id index identifier
* \param key encoded key in MsgPack Array format ([part1, part2, ...]).
* \param key_end the end of encoded \a key.
* \param[out] result a tuple or NULL if index is empty
* \retval -1 on error (check box_error_last())
* \retval 0 on success
* \sa \code box.space[space_id].index[index_id]:min(key) \endcode
*/
box_index_min :: (space_id: u32, index_id: u32, key: *u8, key_end: *u8, result: **box_tuple_t) -> s32 #foreign __UnknownLib;

/**
* Return a last (maximal) tuple matched the provided key.
*
* \param space_id space identifier
* \param index_id index identifier
* \param key encoded key in MsgPack Array format ([part1, part2, ...]).
* \param key_end the end of encoded \a key.
* \param[out] result a tuple or NULL if index is empty
* \retval -1 on error (check box_error_last())
* \retval 0 on success
* \sa \code box.space[space_id].index[index_id]:max(key) \endcode
*/
box_index_max :: (space_id: u32, index_id: u32, key: *u8, key_end: *u8, result: **box_tuple_t) -> s32 #foreign __UnknownLib;

/**
* Count the number of tuple matched the provided key.
*
* \param space_id space identifier
* \param index_id index identifier
* \param type iterator type - enum \link iterator_type \endlink
* \param key encoded key in MsgPack Array format ([part1, part2, ...]).
* \param key_end the end of encoded \a key.
* \retval -1 on error (check box_error_last())
* \retval >=0 on success
* \sa \code box.space[space_id].index[index_id]:count(key,
*     { iterator = type }) \endcode
*/
box_index_count :: (space_id: u32, index_id: u32, type: s32, key: *u8, key_end: *u8) -> ssize_t #foreign __UnknownLib;

/**
* Extract key from tuple according to key definition of given
* index. Returned buffer is allocated on box_txn_alloc() with
* this key.
* @param tuple Tuple from which need to extract key.
* @param space_id Space identifier.
* @param index_id Index identifier.
* @retval not NULL Success
* @retval     NULL Memory Allocation error
*/
box_tuple_extract_key :: (tuple: *box_tuple_t, space_id: u32, index_id: u32, key_size: *u32) -> *u8 #foreign __UnknownLib;

/**
* Controls how to iterate over tuples in an index.
* Different index types support different iterator types.
* For example, one can start iteration from a particular value
* (request key) and then retrieve all tuples where keys are
* greater or equal (= GE) to this key.
*
* If iterator type is not supported by the selected index type,
* iterator constructor must fail with ER_UNSUPPORTED. To be
* selectable for primary key, an index must support at least
* ITER_EQ and ITER_GE types.
*
* NULL value of request key corresponds to the first or last
* key in the index, depending on iteration direction.
* (first key for GE and GT types, and last key for LE and LT).
* Therefore, to iterate over all tuples in an index, one can
* use ITER_GE or ITER_LE iteration types with start key equal
* to NULL.
* For ITER_EQ, the key must not be NULL.
*/
iterator_type :: enum u32 {
    ITER_EQ               :: 0;
    ITER_REQ              :: 1;
    ITER_ALL              :: 2;
    ITER_LT               :: 3;
    ITER_LE               :: 4;
    ITER_GE               :: 5;
    ITER_GT               :: 6;
    ITER_BITS_ALL_SET     :: 7;
    ITER_BITS_ANY_SET     :: 8;
    ITER_BITS_ALL_NOT_SET :: 9;
    ITER_OVERLAPS         :: 10;
    ITER_NEIGHBOR         :: 11;
    MAX                   :: 12;
    iterator_type_MAX :: MAX;
}

/**
* Error - contains information about error.
*/
box_error_t :: error;

/**
* Return the error type, e.g. "ClientError", "SocketError", etc.
* \param error
* \return not-null string
*/
box_error_type :: (error: *box_error_t) -> *u8 #foreign __UnknownLib;

/**
* Return IPROTO error code
* \param error error
* \return enum box_error_code
*/
box_error_code :: (error: *box_error_t) -> u32 #foreign __UnknownLib;

/**
* Return the error message
* \param error error
* \return not-null string
*/
box_error_message :: (error: *box_error_t) -> *u8 #foreign __UnknownLib;

/**
* Get the information about the last API call error.
*
* The Tarantool error handling works most like libc's errno. All API calls
* return -1 or NULL in the event of error. An internal pointer to
* box_error_t type is set by API functions to indicate what went wrong.
* This value is only significant if API call failed (returned -1 or NULL).
*
* Successful function can also touch the last error in some
* cases. You don't have to clear the last error before calling
* API functions. The returned object is valid only until next
* call to **any** API function.
*
* You must set the last error using box_error_set() in your stored C
* procedures if you want to return a custom error message.
* You can re-throw the last API error to IPROTO client by keeping
* the current value and returning -1 to Tarantool from your
* stored procedure.
*
* \return last error.
*/
box_error_last :: () -> *box_error_t #foreign __UnknownLib;

/**
* Clear the last error.
*/
box_error_clear :: () -> void #foreign __UnknownLib;

/**
* Set the last error.
*
* \param code IPROTO error code (enum \link box_error_code \endlink)
* \param format (const char * ) - printf()-like format string
* \param ... - format arguments
* \returns -1 for convention use
*
* \sa enum box_error_code
*/
box_error_set_CFormat :: (file: *u8, line: u32, code: u32, format: *u8, __args: ..Any) -> s32 #foreign __UnknownLib "box_error_set";
box_error_set :: (file: *u8, line: u32, code: u32, format: string, __args: ..Any) -> s32 {
    push_allocator(temp);
    formatted_text_builder: String_Builder;
    print_to_builder(*formatted_text_builder, format, ..__args);
    append(*formatted_text_builder, "\0");
    formatted_text := builder_to_string(*formatted_text_builder);
    return box_error_set_CFormat(file, line, code, "%s", formatted_text.data);
} @PrintLike

/**
* Checks whether the argument idx is a tuple and
* returns it.
*
* @param L Lua State
* @param idx the stack index
* @retval non-NULL argument is tuple
* @throws error if the argument is not a tuple.
*/
luaT_checktuple :: (L: *lua_State, idx: s32) -> *box_tuple_t #foreign __UnknownLib;

/**
* Push a tuple onto the stack.
* @param L Lua State
* @sa luaT_istuple
* @throws on OOM
*/
luaT_pushtuple :: (L: *lua_State, tuple: *box_tuple_t) -> void #foreign __UnknownLib;

/**
* Checks whether argument idx is a tuple.
*
* @param L Lua State
* @param idx the stack index
* @retval non-NULL argument is tuple
* @retval NULL argument is not tuple
*/
luaT_istuple :: (L: *lua_State, idx: s32) -> *box_tuple_t #foreign __UnknownLib;

/**
* Encode a table or a tuple on the Lua stack as an MsgPack array.
*
* @param L              Lua state.
* @param idx            Acceptable index on the Lua stack.
* @param tuple_len_ptr  Where to store tuple data size in bytes
*                       (or NULL).
*
* The storage for data is allocated on the box region. A caller
* should call <box_region_truncate>() to release the data.
*
* In case of an error set a diag and return NULL.
*
* @sa luaT_tuple_new()
*/
luaT_tuple_encode :: (L: *lua_State, idx: s32, tuple_len_ptr: *size_t) -> *u8 #foreign __UnknownLib;

/**
* Create a new tuple with specific format from a Lua table or a
* tuple.
*
* The new tuple is referenced in the same way as one created by
* <box_tuple_new>(). There are two possible usage scenarios:
*
* 1. A short living tuple may not be referenced explicitly and
*    will be collected automatically at the next module API call
*    that yields or returns a tuple.
* 2. A long living tuple must be referenced using
*    <box_tuple_ref>() and unreferenced then with
*    <box_tuple_unref>().
*
* @sa box_tuple_ref()
*
* In case of an error set a diag and return NULL.
*/
luaT_tuple_new :: (L: *lua_State, idx: s32, format: *box_tuple_format_t) -> *box_tuple_t #foreign __UnknownLib;

box_latch :: struct {}
/**
* A lock for cooperative multitasking environment
*/
box_latch_t :: box_latch;

/**
* Allocate and initialize the new latch.
* \returns latch
*/
box_latch_new :: () -> *box_latch_t #foreign __UnknownLib;

/**
* Destroy and free the latch.
* \param latch latch
*/
box_latch_delete :: (latch: *box_latch_t) -> void #foreign __UnknownLib;

/**
* Lock a latch. Waits indefinitely until the current fiber can gain access to
* the latch. Locks are acquired in the strict order as they were requested.
*
* \param latch a latch
*/
box_latch_lock :: (latch: *box_latch_t) -> void #foreign __UnknownLib;

/**
* Try to lock a latch. Return immediately if the latch is locked.
* \param latch a latch
* \retval 0 - success
* \retval 1 - the latch is locked.
*/
box_latch_trylock :: (latch: *box_latch_t) -> s32 #foreign __UnknownLib;

/**
* Unlock a latch. The fiber calling this function must
* own the latch.
*
* \param latch a latch
*/
box_latch_unlock :: (latch: *box_latch_t) -> void #foreign __UnknownLib;

/**
* A settable system-wide clock that measures real (i.e.,
* wall-clock) time.
*
* See clock_gettime(2), CLOCK_REALTIME.
*/
clock_realtime :: () -> float64 #foreign __UnknownLib;

/**
* A nonsettable system-wide clock that represents monotonic time.
*
* See clock_gettime(2), CLOCK_MONOTONIC.
*/
clock_monotonic :: () -> float64 #foreign __UnknownLib;

/**
* A clock that measures CPU time consumed by this process (by all
* threads in the process).
*
* See clock_gettime(2), CLOCK_PROCESS_CPUTIME_ID.
*/
clock_process :: () -> float64 #foreign __UnknownLib;

/**
* A clock that measures CPU time consumed by this thread.
*
* See clock_gettime(2), CLOCK_THREAD_CPUTIME_ID.
*/
clock_thread :: () -> float64 #foreign __UnknownLib;

/**
* Same as clock_realtime(), but returns the time as 64 bit
* signed integer.
*/
clock_realtime64 :: () -> s64 #foreign __UnknownLib;

/**
* Same as clock_monotonic(), but returns the time as 64 bit
* signed integer.
*/
clock_monotonic64 :: () -> s64 #foreign __UnknownLib;

/**
* Same as clock_process(), but returns the time as 64 bit
* signed integer.
*/
clock_process64 :: () -> s64 #foreign __UnknownLib;

/**
* Same as clock_thread(), but returns the time as 64 bit
* signed integer.
*/
clock_thread64 :: () -> s64 #foreign __UnknownLib;

/** See @ref box_decimal_t. */
box_decimal :: struct {
    /**
    * Decimal data.
    *
    * The format is unspecified and can be changed.
    *
    * The tail of the array may be in an unallocated memory.
    * Don't access this array directly. Use box_decimal_*()
    * functions instead.
    */
    internal: [8] u64;
}

/**
* Storage for a decimal number.
*
* This type is large enough to hold a decimal value. The primary
* usage is to allocate a decimal on the stack and pass it to a
* box_decimal_*() function.
*
* Take it as opacue structure with ability to allocate a value
* on the stack.
*
* Use box_decimal_copy() to copy the value, don't use memcpy().
* The real data can be smaller than this type. Moreover,
* tarantool may allocate less bytes for @ref box_decimal_t value,
* so direct read/write of the structure may lead to access to an
* unallocated memory.
*
* The alignment of the structure is not less than alignment of
* decimal values allocated by tarantool. It can be larger and it
* is another reason to don't access the structure content
* directly.
*
* Last, but not least: the data format is unspecified and can be
* changed. Modules and applications that aims to be compatible
* with future tarantool versions must not lean on particular data
* representation within the structure.
*/
box_decimal_t :: box_decimal;

/**
* Decimal precision.
*
* It is equivalent to amount of decimal digits in the string
* representation (not counting minus, decimal separator and the
* leading zero in 0.ddd...ddd number, but counting trailing zeros
* if any).
*
* @param dec decimal number
* @return precision
*/
box_decimal_precision :: (dec: *box_decimal_t) -> s32 #foreign __UnknownLib;

/**
* Decimal scale.
*
* It is equivalent to amount of digits after the decimal
* separator.
*
* @param dec decimal number
* @return scale
*/
box_decimal_scale :: (dec: *box_decimal_t) -> s32 #foreign __UnknownLib;

/**
* Whether the fractional part of a decimal number is 0.
*
* @param dec decimal number
* @return true if the fractional part is zero
* @return false otherwise
*/
box_decimal_is_int :: (dec: *box_decimal_t) -> bool #foreign __UnknownLib;

/**
* Whether a decimal number is negative.
*
* @param dec decimal number
* @return true if the decimal is less than zero
* @return false otherwise
*/
box_decimal_is_neg :: (dec: *box_decimal_t) -> bool #foreign __UnknownLib;

/**
* Initialize a zero decimal number.
*
* @param dec where to store the decimal result
* @return the decimal result
*/
box_decimal_zero :: (dec: *box_decimal_t) -> *box_decimal_t #foreign __UnknownLib;

/**
* Initialize a decimal with a value from a string.
*
* The fractional part may be rounded if a maximum precision is
* reached.
*
* @param dec where to store the decimal result
* @param str source string value
* @return NULL if the string is invalid or the number is too big
* @return decimal result
*/
box_decimal_from_string :: (dec: *box_decimal_t, str: *u8) -> *box_decimal_t #foreign __UnknownLib;

/**
* Initialize a decimal from double.
*
* @param dec where to store the decimal result
* @param d source double value
* @return NULL if the double is NaN, Infinity or greater than a
*         maximum precision for decimal values
* @return decimal result
*/
box_decimal_from_double :: (dec: *box_decimal_t, d: float64) -> *box_decimal_t #foreign __UnknownLib;

/**
* Initialize a decimal with a signed integer value.
*
* @param dec where to store the decimal result
* @param num source integer value (signed)
* @return decimal result
*/
box_decimal_from_int64 :: (dec: *box_decimal_t, num: s64) -> *box_decimal_t #foreign __UnknownLib;

/**
* Initialize a decimal with a unsigned integer value.
*
* @param dec where to store the decimal result
* @param num source integer value (unsigned)
* @return decimal result
*/
box_decimal_from_uint64 :: (dec: *box_decimal_t, num: u64) -> *box_decimal_t #foreign __UnknownLib;

/**
* Copy decimal value from one storage to another.
*
* Use this function where you would use memcpy() if the precise
* data size would be known.
*
* The memory areas must not overlap.
*
* @param dest where to store the copy
* @param src from where to copy
* @return the copy (@a dest)
*/
box_decimal_copy :: (dest: *box_decimal_t, src: *box_decimal_t) -> *box_decimal_t #foreign __UnknownLib;

/**
* Write the decimal as a string into the passed buffer.
*
* The buffer must have at least
* @ref BOX_DECIMAL_STRING_BUFFER_SIZE bytes.
*
* @param dec source decimal number
* @param buf where to write @a dec string representation
*/
box_decimal_to_string :: (dec: *box_decimal_t, buf: *u8) -> void #foreign __UnknownLib;

/**
* Convert a given decimal to int64_t.
*
* @param dec source decimal number
* @param num where to store @a dec integer representation
* @return NULL if the value does not fit into int64_t
* @return @a dec
*/
box_decimal_to_int64 :: (dec: *box_decimal_t, num: *s64) -> *box_decimal_t #foreign __UnknownLib;

/**
* Convert a given decimal to uint64_t.
*
* @param dec source decimal number
* @param num where to store @a dec integer representation
* @return NULL if the value does not fit into uint64_t
* @return @a dec
*/
box_decimal_to_uint64 :: (dec: *box_decimal_t, num: *u64) -> *box_decimal_t #foreign __UnknownLib;

/**
* Round to nearest decimal at given @a scale, half goes away from
* zero.
*
* round(-0.66, 1) -> -0.7
* round(-0.65, 1) -> -0.7
* round(-0.64, 1) -> -0.6
*
* round(0.64, 1) -> 0.6
* round(0.65, 1) -> 0.7
* round(0.66, 1) -> 0.7
*
* Resulting decimal number has not more than @a scale digits
* after the decimal point.
*
* If @a scale if greater than current @a dec scale, do nothing.
*
* @param dec decimal number
* @oaram scale target scale
* @return NULL if @a scale is out of supported range
* @return @a dec (changed)
*/
box_decimal_round :: (dec: *box_decimal_t, scale: s32) -> *box_decimal_t #foreign __UnknownLib;

/**
* Apply a floor function to a decimal, i.e. round it towards
* zero to a decimal with given @a scale.
*
* floor(-0.66, 1) -> -0.6
* floor(-0.65, 1) -> -0.6
* floor(-0.64, 1) -> -0.6
*
* floor(0.64, 1) -> 0.6
* floor(0.65, 1) -> 0.6
* floor(0.66, 1) -> 0.6
*
* @sa box_decimal_round
*
* @param dec decimal number
* @oaram scale target scale
* @return NULL if @a scale is out of supported range
* @return @a dec (changed)
*/
box_decimal_floor :: (dec: *box_decimal_t, scale: s32) -> *box_decimal_t #foreign __UnknownLib;

/**
* Remove trailing zeros from the fractional part of a number.
*
* @param dec decimal number
* @return @a dec (changed)
*/
box_decimal_trim :: (dec: *box_decimal_t) -> *box_decimal_t #foreign __UnknownLib;

/**
* Set scale of @a dec to @a scale.
*
* If @a scale is less than scale(@a dec), round the decimal.
* Otherwise append a sufficient amount of trailing fractional
* zeros.
*
* @sa box_decimal_round
* @sa box_decimal_trim
*
* @param dec decimal number
* @oaram scale target scale
* @return NULL if scale is out of supported range (less than zero
*              or too big)
* @return @a dec (changed)
*/
box_decimal_rescale :: (dec: *box_decimal_t, scale: s32) -> *box_decimal_t #foreign __UnknownLib;

/**
* Compare two decimal values.
*
* @param lhs left hand side operand
* @param rhs right hand side operand
* @return -1 if lhs < rhs
* @return 0 if lhs = rhs
* @return 1 if lhs > rhs
*/
box_decimal_compare :: (lhs: *box_decimal_t, rhs: *box_decimal_t) -> s32 #foreign __UnknownLib;

/**
* Get the absolute value of a decimal.
*
* @a res is set to the absolute value of @a dec.
*
* box_decimal_abs(&a, &a) is allowed.
*
* @param res where to store the result
* @param dec decimal operand
* @return @a res
*/
box_decimal_abs :: (res: *box_decimal_t, dec: *box_decimal_t) -> *box_decimal_t #foreign __UnknownLib;

/**
* Perform unary minus operation.
*
* @a res is set to -dec.
*
* @param res where to store the result
* @param dec decimal operand
* @return @a res
*/
box_decimal_minus :: (res: *box_decimal_t, dec: *box_decimal_t) -> *box_decimal_t #foreign __UnknownLib;

/**
* Calculate a sum of two decimal numbers.
*
* @param res where to hold the result
* @param lhs left hand side operand
* @param rhs right hand side operand
* @return NULL on an error (an overflow for example)
* @return decimal result (@res)
*/
box_decimal_add :: (res: *box_decimal_t, lhs: *box_decimal_t, rhs: *box_decimal_t) -> *box_decimal_t #foreign __UnknownLib;

/**
* Subtract one decimal number from another.
*
* @param res where to hold the result
* @param lhs left hand side operand
* @param rhs right hand side operand
* @return NULL on an error (an overflow for example)
* @return decimal result (@res)
*/
box_decimal_sub :: (res: *box_decimal_t, lhs: *box_decimal_t, rhs: *box_decimal_t) -> *box_decimal_t #foreign __UnknownLib;

/**
* Multiply two decimal numbers.
*
* @param res where to hold the result
* @param lhs left hand side operand
* @param rhs right hand side operand
* @return NULL on an error (an overflow for example)
* @return decimal result (@res)
*/
box_decimal_mul :: (res: *box_decimal_t, lhs: *box_decimal_t, rhs: *box_decimal_t) -> *box_decimal_t #foreign __UnknownLib;

/**
* Divide one decimal number on another.
*
* @param res where to hold the result
* @param lhs left hand side operand
* @param rhs right hand side operand
* @return NULL on an error
* @return decimal result (@res)
*/
box_decimal_div :: (res: *box_decimal_t, lhs: *box_decimal_t, rhs: *box_decimal_t) -> *box_decimal_t #foreign __UnknownLib;

/**
* Get the remainder of diviging two decimals.
*
* @a res is set to the remainder of dividing @a lhs by @a rhs.
*
* @param res where to hold the result
* @param lhs left hand side operand
* @param rhs right hand side operand
* @return NULL on an error
* @return decimal result (@res)
*/
box_decimal_remainder :: (res: *box_decimal_t, lhs: *box_decimal_t, rhs: *box_decimal_t) -> *box_decimal_t #foreign __UnknownLib;

/**
* Calculate a common logarithm (base 10).
*
* @param res where to hold the result
* @param dec decimal operand
* @return NULL on an error
* @return decimal result (@res)
*/
box_decimal_log10 :: (res: *box_decimal_t, dec: *box_decimal_t) -> *box_decimal_t #foreign __UnknownLib;

/**
* Calculate a natural logarithm (base e).
*
* @param res where to hold the result
* @param dec decimal operand
* @return NULL on an error
* @return decimal result (@res)
*/
box_decimal_ln :: (res: *box_decimal_t, dec: *box_decimal_t) -> *box_decimal_t #foreign __UnknownLib;

/**
* Calculate @a lhs raised to the power of @a rhs.
*
* @param res where to hold the result
* @param lhs left hand side operand, base
* @param rhs right hand side operand, power
* @return NULL on an error
* @return decimal result (@res)
*/
box_decimal_pow :: (res: *box_decimal_t, lhs: *box_decimal_t, rhs: *box_decimal_t) -> *box_decimal_t #foreign __UnknownLib;

/**
* Calculate exp(@a dec), i.e. pow(e, @a dec).
*
* @param res where to hold the result
* @param dec decimal operand
* @return NULL on an error
* @return decimal result (@res)
*/
box_decimal_exp :: (res: *box_decimal_t, dec: *box_decimal_t) -> *box_decimal_t #foreign __UnknownLib;

/**
* Calculate a square root.
*
* @param res where to hold the result
* @param dec decimal operand
* @return NULL on an error
* @return decimal result (@res)
*/
box_decimal_sqrt :: (res: *box_decimal_t, dec: *box_decimal_t) -> *box_decimal_t #foreign __UnknownLib;

/**
* Calculate exact buffer size needed to store msgpack
* representation of a decimal.
*
* @param dec decimal operand
* @return the buffer size
*/
box_decimal_mp_sizeof :: (dec: *box_decimal_t) -> u32 #foreign __UnknownLib;

/**
* Encode a decimal as msgpack.
*
* @param dec decimal number to encode
* @param data buffer to write the result
* @return @a data + box_decimal_mp_sizeof(@a dec)
*/
box_decimal_mp_encode :: (dec: *box_decimal_t, data: *u8) -> *u8 #foreign __UnknownLib;

/**
* Decode a decimal from msgpack @a data.
*
* @param dec where to store the decoded decimal
* @param data pointer to a buffer with the msgpack data
* @return NULL if the msgpack data does not represent a valid
*         decimal value
* @return the decoded decimal
* @post *data = *data + box_decimal_mp_sizeof(retval)
*/
box_decimal_mp_decode :: (dec: *box_decimal_t, data: **u8) -> *box_decimal_t #foreign __UnknownLib;

/**
* Decode a decimal from msgpack @a data without the msgpack
* extension header.
*
*  | box_decimal_mp_decode_data() must be called for this position
*  |                                        |
*  |                                        v
*  | <msgpack type> <size> <extension type> <data>
*  | ^
*  | |
*  | box_decimal_mp_decode() must be called for this position
*
* This function is suitable to finish decoding after calling
* mp_decode_extl() (from the msgpuck library).
*
* @param dec where to store the decoded decimal
* @param data pointer to a buffer with the msgpack data
* @return NULL if the msgpack data does not represent a valid
*         decimal value
* @return the decoded decimal
* @post *data = *data + @a size
*/
box_decimal_mp_decode_data :: (dec: *box_decimal_t, data: **u8, size: u32) -> *box_decimal_t #foreign __UnknownLib;

/**
* Allocate a new decimal on the Lua stack and return
* a pointer to it.
*/
luaT_newdecimal :: (L: *lua_State) -> *box_decimal_t #foreign __UnknownLib;

/**
* Allocate a new decimal on the Lua stack with copy of given
* decimal and return a pointer to it.
*/
luaT_pushdecimal :: (L: *lua_State, dec: *box_decimal_t) -> *box_decimal_t #foreign __UnknownLib;

/**
* Check whether a value on the Lua stack is a decimal.
*
* Returns a pointer to the decimal on a successful check,
* NULL otherwise.
*/
luaT_isdecimal :: (L: *lua_State, index: s32) -> *box_decimal_t #foreign __UnknownLib;

/** \endcond public */
box_error_code :: enum u32 {
    ER_UNKNOWN                           :: 0;
    ER_ILLEGAL_PARAMS                    :: 1;
    ER_MEMORY_ISSUE                      :: 2;
    ER_TUPLE_FOUND                       :: 3;
    ER_TUPLE_NOT_FOUND                   :: 4;
    ER_UNSUPPORTED                       :: 5;
    ER_NONMASTER                         :: 6;
    ER_READONLY                          :: 7;
    ER_INJECTION                         :: 8;
    ER_CREATE_SPACE                      :: 9;
    ER_SPACE_EXISTS                      :: 10;
    ER_DROP_SPACE                        :: 11;
    ER_ALTER_SPACE                       :: 12;
    ER_INDEX_TYPE                        :: 13;
    ER_MODIFY_INDEX                      :: 14;
    ER_LAST_DROP                         :: 15;
    ER_TUPLE_FORMAT_LIMIT                :: 16;
    ER_DROP_PRIMARY_KEY                  :: 17;
    ER_KEY_PART_TYPE                     :: 18;
    ER_EXACT_MATCH                       :: 19;
    ER_INVALID_MSGPACK                   :: 20;
    ER_PROC_RET                          :: 21;
    ER_TUPLE_NOT_ARRAY                   :: 22;
    ER_FIELD_TYPE                        :: 23;
    ER_INDEX_PART_TYPE_MISMATCH          :: 24;
    ER_UPDATE_SPLICE                     :: 25;
    ER_UPDATE_ARG_TYPE                   :: 26;
    ER_FORMAT_MISMATCH_INDEX_PART        :: 27;
    ER_UNKNOWN_UPDATE_OP                 :: 28;
    ER_UPDATE_FIELD                      :: 29;
    ER_FUNCTION_TX_ACTIVE                :: 30;
    ER_KEY_PART_COUNT                    :: 31;
    ER_PROC_LUA                          :: 32;
    ER_NO_SUCH_PROC                      :: 33;
    ER_NO_SUCH_TRIGGER                   :: 34;
    ER_NO_SUCH_INDEX_ID                  :: 35;
    ER_NO_SUCH_SPACE                     :: 36;
    ER_NO_SUCH_FIELD_NO                  :: 37;
    ER_EXACT_FIELD_COUNT                 :: 38;
    ER_FIELD_MISSING                     :: 39;
    ER_WAL_IO                            :: 40;
    ER_MORE_THAN_ONE_TUPLE               :: 41;
    ER_ACCESS_DENIED                     :: 42;
    ER_CREATE_USER                       :: 43;
    ER_DROP_USER                         :: 44;
    ER_NO_SUCH_USER                      :: 45;
    ER_USER_EXISTS                       :: 46;
    ER_CREDS_MISMATCH                    :: 47;
    ER_UNKNOWN_REQUEST_TYPE              :: 48;
    ER_UNKNOWN_SCHEMA_OBJECT             :: 49;
    ER_CREATE_FUNCTION                   :: 50;
    ER_NO_SUCH_FUNCTION                  :: 51;
    ER_FUNCTION_EXISTS                   :: 52;
    ER_BEFORE_REPLACE_RET                :: 53;
    ER_MULTISTATEMENT_TRANSACTION        :: 54;
    ER_TRIGGER_EXISTS                    :: 55;
    ER_USER_MAX                          :: 56;
    ER_NO_SUCH_ENGINE                    :: 57;
    ER_RELOAD_CFG                        :: 58;
    ER_CFG                               :: 59;
    ER_SAVEPOINT_EMPTY_TX                :: 60;
    ER_NO_SUCH_SAVEPOINT                 :: 61;
    ER_UNKNOWN_REPLICA                   :: 62;
    ER_REPLICASET_UUID_MISMATCH          :: 63;
    ER_INVALID_UUID                      :: 64;
    ER_REPLICASET_UUID_IS_RO             :: 65;
    ER_INSTANCE_UUID_MISMATCH            :: 66;
    ER_REPLICA_ID_IS_RESERVED            :: 67;
    ER_INVALID_ORDER                     :: 68;
    ER_MISSING_REQUEST_FIELD             :: 69;
    ER_IDENTIFIER                        :: 70;
    ER_DROP_FUNCTION                     :: 71;
    ER_ITERATOR_TYPE                     :: 72;
    ER_REPLICA_MAX                       :: 73;
    ER_INVALID_XLOG                      :: 74;
    ER_INVALID_XLOG_NAME                 :: 75;
    ER_INVALID_XLOG_ORDER                :: 76;
    ER_NO_CONNECTION                     :: 77;
    ER_TIMEOUT                           :: 78;
    ER_ACTIVE_TRANSACTION                :: 79;
    ER_CURSOR_NO_TRANSACTION             :: 80;
    ER_CROSS_ENGINE_TRANSACTION          :: 81;
    ER_NO_SUCH_ROLE                      :: 82;
    ER_ROLE_EXISTS                       :: 83;
    ER_CREATE_ROLE                       :: 84;
    ER_INDEX_EXISTS                      :: 85;
    ER_SESSION_CLOSED                    :: 86;
    ER_ROLE_LOOP                         :: 87;
    ER_GRANT                             :: 88;
    ER_PRIV_GRANTED                      :: 89;
    ER_ROLE_GRANTED                      :: 90;
    ER_PRIV_NOT_GRANTED                  :: 91;
    ER_ROLE_NOT_GRANTED                  :: 92;
    ER_MISSING_SNAPSHOT                  :: 93;
    ER_CANT_UPDATE_PRIMARY_KEY           :: 94;
    ER_UPDATE_INTEGER_OVERFLOW           :: 95;
    ER_GUEST_USER_PASSWORD               :: 96;
    ER_TRANSACTION_CONFLICT              :: 97;
    ER_UNSUPPORTED_PRIV                  :: 98;
    ER_LOAD_FUNCTION                     :: 99;
    ER_FUNCTION_LANGUAGE                 :: 100;
    ER_RTREE_RECT                        :: 101;
    ER_PROC_C                            :: 102;
    ER_UNKNOWN_RTREE_INDEX_DISTANCE_TYPE :: 103;
    ER_PROTOCOL                          :: 104;
    ER_UPSERT_UNIQUE_SECONDARY_KEY       :: 105;
    ER_WRONG_INDEX_RECORD                :: 106;
    ER_WRONG_INDEX_PARTS                 :: 107;
    ER_WRONG_INDEX_OPTIONS               :: 108;
    ER_WRONG_SCHEMA_VERSION              :: 109;
    ER_MEMTX_MAX_TUPLE_SIZE              :: 110;
    ER_WRONG_SPACE_OPTIONS               :: 111;
    ER_UNSUPPORTED_INDEX_FEATURE         :: 112;
    ER_VIEW_IS_RO                        :: 113;
    ER_NO_TRANSACTION                    :: 114;
    ER_SYSTEM                            :: 115;
    ER_LOADING                           :: 116;
    ER_CONNECTION_TO_SELF                :: 117;
    ER_KEY_PART_IS_TOO_LONG              :: 118;
    ER_COMPRESSION                       :: 119;
    ER_CHECKPOINT_IN_PROGRESS            :: 120;
    ER_SUB_STMT_MAX                      :: 121;
    ER_COMMIT_IN_SUB_STMT                :: 122;
    ER_ROLLBACK_IN_SUB_STMT              :: 123;
    ER_DECOMPRESSION                     :: 124;
    ER_INVALID_XLOG_TYPE                 :: 125;
    ER_ALREADY_RUNNING                   :: 126;
    ER_INDEX_FIELD_COUNT_LIMIT           :: 127;
    ER_LOCAL_INSTANCE_ID_IS_READ_ONLY    :: 128;
    ER_BACKUP_IN_PROGRESS                :: 129;
    ER_READ_VIEW_ABORTED                 :: 130;
    ER_INVALID_INDEX_FILE                :: 131;
    ER_INVALID_RUN_FILE                  :: 132;
    ER_INVALID_VYLOG_FILE                :: 133;
    ER_CASCADE_ROLLBACK                  :: 134;
    ER_VY_QUOTA_TIMEOUT                  :: 135;
    ER_PARTIAL_KEY                       :: 136;
    ER_TRUNCATE_SYSTEM_SPACE             :: 137;
    ER_LOAD_MODULE                       :: 138;
    ER_VINYL_MAX_TUPLE_SIZE              :: 139;
    ER_WRONG_DD_VERSION                  :: 140;
    ER_WRONG_SPACE_FORMAT                :: 141;
    ER_CREATE_SEQUENCE                   :: 142;
    ER_ALTER_SEQUENCE                    :: 143;
    ER_DROP_SEQUENCE                     :: 144;
    ER_NO_SUCH_SEQUENCE                  :: 145;
    ER_SEQUENCE_EXISTS                   :: 146;
    ER_SEQUENCE_OVERFLOW                 :: 147;
    ER_NO_SUCH_INDEX_NAME                :: 148;
    ER_SPACE_FIELD_IS_DUPLICATE          :: 149;
    ER_CANT_CREATE_COLLATION             :: 150;
    ER_WRONG_COLLATION_OPTIONS           :: 151;
    ER_NULLABLE_PRIMARY                  :: 152;
    ER_NO_SUCH_FIELD_NAME_IN_SPACE       :: 153;
    ER_TRANSACTION_YIELD                 :: 154;
    ER_NO_SUCH_GROUP                     :: 155;
    ER_SQL_BIND_VALUE                    :: 156;
    ER_SQL_BIND_TYPE                     :: 157;
    ER_SQL_BIND_PARAMETER_MAX            :: 158;
    ER_SQL_EXECUTE                       :: 159;
    ER_UPDATE_DECIMAL_OVERFLOW           :: 160;
    ER_SQL_BIND_NOT_FOUND                :: 161;
    ER_ACTION_MISMATCH                   :: 162;
    ER_VIEW_MISSING_SQL                  :: 163;
    ER_FOREIGN_KEY_CONSTRAINT            :: 164;
    ER_NO_SUCH_MODULE                    :: 165;
    ER_NO_SUCH_COLLATION                 :: 166;
    ER_CREATE_FK_CONSTRAINT              :: 167;
    ER_DROP_FK_CONSTRAINT                :: 168;
    ER_NO_SUCH_CONSTRAINT                :: 169;
    ER_CONSTRAINT_EXISTS                 :: 170;
    ER_SQL_TYPE_MISMATCH                 :: 171;
    ER_ROWID_OVERFLOW                    :: 172;
    ER_DROP_COLLATION                    :: 173;
    ER_ILLEGAL_COLLATION_MIX             :: 174;
    ER_SQL_NO_SUCH_PRAGMA                :: 175;
    ER_SQL_CANT_RESOLVE_FIELD            :: 176;
    ER_INDEX_EXISTS_IN_SPACE             :: 177;
    ER_INCONSISTENT_TYPES                :: 178;
    ER_SQL_SYNTAX_WITH_POS               :: 179;
    ER_SQL_STACK_OVERFLOW                :: 180;
    ER_SQL_SELECT_WILDCARD               :: 181;
    ER_SQL_STATEMENT_EMPTY               :: 182;
    ER_SQL_KEYWORD_IS_RESERVED           :: 183;
    ER_SQL_SYNTAX_NEAR_TOKEN             :: 184;
    ER_SQL_UNKNOWN_TOKEN                 :: 185;
    ER_SQL_PARSER_GENERIC                :: 186;
    ER_SQL_ANALYZE_ARGUMENT              :: 187;
    ER_SQL_COLUMN_COUNT_MAX              :: 188;
    ER_HEX_LITERAL_MAX                   :: 189;
    ER_INT_LITERAL_MAX                   :: 190;
    ER_SQL_PARSER_LIMIT                  :: 191;
    ER_INDEX_DEF_UNSUPPORTED             :: 192;
    ER_CK_DEF_UNSUPPORTED                :: 193;
    ER_MULTIKEY_INDEX_MISMATCH           :: 194;
    ER_CREATE_CK_CONSTRAINT              :: 195;
    ER_CK_CONSTRAINT_FAILED              :: 196;
    ER_SQL_COLUMN_COUNT                  :: 197;
    ER_FUNC_INDEX_FUNC                   :: 198;
    ER_FUNC_INDEX_FORMAT                 :: 199;
    ER_FUNC_INDEX_PARTS                  :: 200;
    ER_NO_SUCH_FIELD_NAME                :: 201;
    ER_FUNC_WRONG_ARG_COUNT              :: 202;
    ER_BOOTSTRAP_READONLY                :: 203;
    ER_SQL_FUNC_WRONG_RET_COUNT          :: 204;
    ER_FUNC_INVALID_RETURN_TYPE          :: 205;
    ER_SQL_PARSER_GENERIC_WITH_POS       :: 206;
    ER_REPLICA_NOT_ANON                  :: 207;
    ER_CANNOT_REGISTER                   :: 208;
    ER_SESSION_SETTING_INVALID_VALUE     :: 209;
    ER_SQL_PREPARE                       :: 210;
    ER_WRONG_QUERY_ID                    :: 211;
    ER_SEQUENCE_NOT_STARTED              :: 212;
    ER_NO_SUCH_SESSION_SETTING           :: 213;
    ER_UNCOMMITTED_FOREIGN_SYNC_TXNS     :: 214;
    ER_SYNC_MASTER_MISMATCH              :: 215;
    ER_SYNC_QUORUM_TIMEOUT               :: 216;
    ER_SYNC_ROLLBACK                     :: 217;
    ER_TUPLE_METADATA_IS_TOO_BIG         :: 218;
    ER_XLOG_GAP                          :: 219;
    ER_TOO_EARLY_SUBSCRIBE               :: 220;
    ER_SQL_CANT_ADD_AUTOINC              :: 221;
    ER_QUORUM_WAIT                       :: 222;
    ER_INTERFERING_PROMOTE               :: 223;
    ER_ELECTION_DISABLED                 :: 224;
    ER_TXN_ROLLBACK                      :: 225;
    ER_NOT_LEADER                        :: 226;
    ER_SYNC_QUEUE_UNCLAIMED              :: 227;
    ER_SYNC_QUEUE_FOREIGN                :: 228;
    ER_UNABLE_TO_PROCESS_IN_STREAM       :: 229;
    ER_UNABLE_TO_PROCESS_OUT_OF_STREAM   :: 230;
    ER_TRANSACTION_TIMEOUT               :: 231;
    ER_ACTIVE_TIMER                      :: 232;
    ER_TUPLE_FIELD_COUNT_LIMIT           :: 233;
    ER_CREATE_CONSTRAINT                 :: 234;
    ER_FIELD_CONSTRAINT_FAILED           :: 235;
    ER_TUPLE_CONSTRAINT_FAILED           :: 236;
    ER_CREATE_FOREIGN_KEY                :: 237;
    ER_FOREIGN_KEY_INTEGRITY             :: 238;
    ER_FIELD_FOREIGN_KEY_FAILED          :: 239;
    ER_COMPLEX_FOREIGN_KEY_FAILED        :: 240;
    ER_WRONG_SPACE_UPGRADE_OPTIONS       :: 241;
    ER_NO_ELECTION_QUORUM                :: 242;
    ER_SSL                               :: 243;
    ER_SPLIT_BRAIN                       :: 244;
    ER_OLD_TERM                          :: 245;
    ER_INTERFERING_ELECTIONS             :: 246;
    ER_ITERATOR_POSITION                 :: 247;
    ER_UNUSED                            :: 248;
    ER_UNKNOWN_AUTH_METHOD               :: 249;
    ER_INVALID_AUTH_DATA                 :: 250;
    ER_INVALID_AUTH_REQUEST              :: 251;
    ER_WEAK_PASSWORD                     :: 252;
    ER_OLD_PASSWORD                      :: 253;
    ER_NO_SUCH_SESSION                   :: 254;
    ER_WRONG_SESSION_TYPE                :: 255;
    ER_PASSWORD_EXPIRED                  :: 256;
    ER_AUTH_DELAY                        :: 257;
    ER_AUTH_REQUIRED                     :: 258;
    ER_SQL_SEQ_SCAN                      :: 259;
    ER_NO_SUCH_EVENT                     :: 260;
    ER_BOOTSTRAP_NOT_UNANIMOUS           :: 261;
    ER_CANT_CHECK_BOOTSTRAP_LEADER       :: 262;
    ER_BOOTSTRAP_CONNECTION_NOT_TO_ALL   :: 263;
    ER_NIL_UUID                          :: 264;
    ER_WRONG_FUNCTION_OPTIONS            :: 265;
    ER_MISSING_SYSTEM_SPACES             :: 266;
    MAX                                  :: 267;
    box_error_code_MAX :: MAX;
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

    {
        instance: box_key_part_def_t;
        assert(((cast(*void)(*instance.padding)) - cast(*void)(*instance)) == 0, "box_key_part_def_t.padding has unexpected offset % instead of 0", ((cast(*void)(*instance.padding)) - cast(*void)(*instance)));
        assert(size_of(type_of(box_key_part_def_t.padding)) == 64, "box_key_part_def_t.padding has unexpected size % instead of 64", size_of(type_of(box_key_part_def_t.padding)));
        assert(size_of(box_key_part_def_t) == 64, "box_key_part_def_t has size % instead of 64", size_of(box_key_part_def_t));
    }

    {
        instance: box_decimal;
        assert(((cast(*void)(*instance.internal)) - cast(*void)(*instance)) == 0, "box_decimal.internal has unexpected offset % instead of 0", ((cast(*void)(*instance.internal)) - cast(*void)(*instance)));
        assert(size_of(type_of(box_decimal.internal)) == 64, "box_decimal.internal has unexpected size % instead of 64", size_of(type_of(box_decimal.internal)));
        assert(size_of(box_decimal) == 64, "box_decimal has size % instead of 64", size_of(box_decimal));
    }
}

