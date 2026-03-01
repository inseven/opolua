/*
 * Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#ifndef LUASUPPORT_H
#define LUASUPPORT_H

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include <QByteArray>
#include <QPoint>
#include <QString>
#include <QVector>
#include <QVariant>

#define SET_INT(L, name, val) lua_pushinteger(L, val); lua_setfield(L, -2, name)
#define SET_FN(L, name, val) lua_pushcfunction(L, val); lua_setfield(L, -2, name)
#define SET_BOOL(L, name, val) lua_pushboolean(L, val); lua_setfield(L, -2, name)

int rawgetfield(lua_State* L, int index, const char* k);
bool to_bool(lua_State* L, int idx, const char* name);
int to_int(lua_State* L, int idx, const char* name);
double to_double(lua_State* L, int idx, const char* name);
QString to_string(lua_State* L, int idx, const char* name);
QByteArray to_bytearray(lua_State* L, int idx, const char* name);
QPoint to_point(lua_State* L, int idx, const char* name);

template <typename T>
T to_intt(lua_State* L, int idx, const char* name)
{
    rawgetfield(L, idx, name);
    T result = static_cast<T>(lua_tointeger(L, -1));
    lua_pop(L, 1);
    return result;
}

template <typename T>
T to_enum(lua_State* L, int idx, const char* name, const QVector<QString>& opts, T defaultValue)
{
    QString opt = to_string(L, idx, name);
    if (opt.isEmpty()) {
        return defaultValue;
    }

    for (int i = 0; i < opts.count(); i++) {
        if (opt == opts[i]) {
            return static_cast<T>(i);
        }
    }
    return defaultValue; 
}

void pushValue(lua_State* L, bool v);
void pushValue(lua_State* L, int v);
void pushValue(lua_State* L, unsigned int v);
void pushValue(lua_State* L, int64_t v);
void pushValue(lua_State* L, uint64_t v);
void pushValue(lua_State* L, lua_CFunction v);
void pushValue(lua_State* L, double v);
void pushValue(lua_State* L, const QByteArray& str);
void pushValue(lua_State* L, const QString& str);
void pushValue(lua_State* L, const wchar_t* value);
void pushValue(lua_State* L, const QVariant& value);

template <typename T>
void pushValue(lua_State* L, const QVector<T>& value)
{
    const int n = value.count();
    lua_createtable(L, n, 0);
    for (int i = 0; i < n; i++) {
        pushValue(L, value[i]);
        lua_rawseti(L, -2, i + 1);
    }
}

#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
template <typename T>
void pushValue(lua_State* L, const QList<T>& value)
{
    const int n = value.count();
    lua_createtable(L, n, 0);
    for (int i = 0; i < n; i++) {
        pushValue(L, value[i]);
        lua_rawseti(L, -2, i + 1);
    }
}
#endif

template<typename T>
T* makeUserData(lua_State* L, T data, const char* type_name)
{
    T* ptr = static_cast<T*>(lua_newuserdata(L, sizeof(T)));

    // We do this instead of just `*ptr = data` in case T is a non-POD type, where the simple assignment might result
    // in a destructor being called with the memory still uninitialised.
    new(ptr) T(data);

    // We want to create a metatable for this if it doesn't already exist
    luaL_newmetatable(L, type_name);
    lua_setmetatable(L, -2);
    return ptr;
}

template <typename T>
T& checkUserData(lua_State* L, int index, const char* type_name)
{
    return *static_cast<T*>(luaL_checkudata(L, index, type_name));
}

template <typename T>
T* testUserData(lua_State* L, int index, const char* type_name) {
    void* udata = luaL_checkudata(L, index, type_name);
    if (udata) {
        return static_cast<T*>(udata);
    } else {
        return nullptr;
    }
}

template <typename T>
void setValue(lua_State *L, const char* k, const T& v)
{
    pushValue(L, v);
    lua_setfield(L, -2, k);
}

int load(lua_State* L, const QString& path);
int dofile(lua_State* L, const QString& path);
void require(lua_State *L, const char* str);

#endif // LUASUPPORT_H
