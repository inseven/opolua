//
//  opolua-bridge.h
//  OpoLua
//
//  Created by Tom Sutcliffe on 15/11/2021.
//

#ifndef opolua_bridge_h
#define opolua_bridge_h

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

// Reimplement some things that are macros, so the bridge can see them

#undef lua_pop
static inline void lua_pop(lua_State* L, int n) {
    lua_settop(L, -(n) - 1);
}

#undef lua_call
static inline void lua_call(lua_State* L, int narg, int nrec) {
    lua_callk(L, narg, nrec, 0, NULL);
}

#undef lua_pcall
static inline int lua_pcall(lua_State* L, int narg, int nrec, int errfunc) {
    return lua_pcallk(L, narg, nrec, errfunc, 0, NULL);
}

#undef lua_yield
static inline int lua_yield(lua_State* L, int nresults) {
    return lua_yieldk(L, nresults, 0, NULL);
}

#undef lua_newtable
static inline void lua_newtable(lua_State* L) {
    lua_createtable(L, 0, 0);
}

#undef lua_register
static inline void lua_register(lua_State* L, const char *name, lua_CFunction f) {
    lua_pushcfunction(L, f);
    lua_setglobal(L, name);
}

#undef lua_pushcfunction
static inline void lua_pushcfunction(lua_State* L, lua_CFunction fn) {
    lua_pushcclosure(L, fn, 0);
}

#undef lua_isfunction
static inline int lua_isfunction(lua_State* L, int n) {
    return lua_type(L, n) == LUA_TFUNCTION;
}

#undef lua_istable
static inline int lua_istable(lua_State* L, int idx) {
    return lua_type(L, idx) == LUA_TTABLE;
}

#undef lua_islightuserdata
static inline int lua_islightuserdata(lua_State* L, int idx) {
    return lua_type(L, idx) == LUA_TLIGHTUSERDATA;
}

#undef lua_isnil
static inline int lua_isnil(lua_State* L, int idx) {
    return lua_type(L, idx) == LUA_TNIL;
}

#undef lua_isboolean
static inline int lua_isboolean(lua_State* L, int idx) {
    return lua_type(L, idx) == LUA_TBOOLEAN;
}

#undef lua_isthread
static inline int lua_isthread(lua_State* L, int idx) {
    return lua_type(L, idx) == LUA_TTHREAD;
}

#undef lua_isnone
static inline int lua_isnone(lua_State* L, int idx) {
    return lua_type(L, idx) == LUA_TNONE;
}

#undef lua_isnoneornil
static inline int lua_isnoneornil(lua_State* L, int idx) {
    return lua_type(L, idx) <= 0;
}

#undef lua_pushliteral
static inline void lua_pushliteral(lua_State* L, const char* s) {
    lua_pushstring(L, s);
}

#undef lua_pushglobaltable
static inline void lua_pushglobaltable(lua_State* L) {
    (void)lua_rawgeti(L, LUA_REGISTRYINDEX, LUA_RIDX_GLOBALS);
}

#undef luaL_dofile
static inline int luaL_dofile(lua_State* L, const char *filename) {
    return luaL_loadfile(L, filename) || lua_pcall(L, 0, LUA_MULTRET, 0);
}

#undef lua_tonumber
static inline lua_Number lua_tonumber(lua_State* L, int index) {
    return lua_tonumberx(L, index, NULL);
}

#undef lua_tostring
static inline const char* lua_tostring(lua_State* L, int index) {
    return lua_tolstring(L, index, NULL);
}

#undef lua_insert
static inline void lua_insert(lua_State* L, int index) {
    lua_rotate(L, index, 1);
}

#undef lua_remove
static inline void lua_remove(lua_State* L, int index) {
    lua_rotate(L, index, -1);
    lua_pop(L, 1);
}

#undef lua_replace
static inline void lua_replace(lua_State* L, int index) {
    lua_copy(L, -1, index);
    lua_pop(L, 1);
}

#undef luaL_typename
static inline const char* luaL_typename(lua_State* L, int index) {
    return lua_typename(L, lua_type(L, index));
}

#undef lua_upvalueindex
static inline int lua_upvalueindex(int i) {
    return LUA_REGISTRYINDEX - i;
}

#endif /* opolua_bridge_h */
