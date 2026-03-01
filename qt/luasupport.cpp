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

#include "luasupport.h"
#include <QVariant>
#include <QFile>
#include <QDebug>

int rawgetfield(lua_State* L, int index, const char* k)
{
    index = lua_absindex(L, index);
    if (lua_type(L, index) != LUA_TTABLE) {
        lua_pushnil(L);
        return LUA_TNIL;
    }
    lua_pushstring(L, k);
    return lua_rawget(L, index);
}

int to_int(lua_State* L, int idx, const char* name)
{
    rawgetfield(L, idx, name);
    int result = (int)lua_tointeger(L, -1);
    lua_pop(L, 1);
    return result;
}

double to_double(lua_State* L, int idx, const char* name)
{
    rawgetfield(L, idx, name);
    double result = (double)lua_tonumber(L, -1);
    lua_pop(L, 1);
    return result;
}

QString to_string(lua_State* L, int idx, const char* name)
{
    rawgetfield(L, idx, name);
    size_t len = 0;
    auto str = lua_tolstring(L, -1, &len);
    lua_pop(L, 1);
    return str ? QString::fromLatin1(str, len) : QString();
}

QByteArray to_bytearray(lua_State* L, int idx, const char* name)
{
    rawgetfield(L, idx, name);
    size_t len = 0;
    auto str = lua_tolstring(L, -1, &len);
    lua_pop(L, 1);
    return str ? QByteArray(str, len) : QByteArray();
}

bool to_bool(lua_State* L, int idx, const char* name)
{
    rawgetfield(L, idx, name);
    int result = (bool)lua_toboolean(L, -1);
    lua_pop(L, 1);
    return result;
}

QPoint to_point(lua_State* L, int idx, const char* name)
{
    QPoint result;
    if (rawgetfield(L, idx, name) == LUA_TTABLE) {
        result = QPoint(to_int(L, -1, "x"), to_int(L, -1, "y"));
    }
    lua_pop(L, 1);
    return result;
}

void pushValue(lua_State* L, bool v)
{
    lua_pushboolean(L, v);
}

void pushValue(lua_State* L, int v)
{
    lua_pushinteger(L, v);
}

void pushValue(lua_State* L, unsigned int v)
{
    lua_pushinteger(L, v);
}

void pushValue(lua_State* L, int64_t v)
{
    lua_pushinteger(L, v);
}

void pushValue(lua_State* L, uint64_t v)
{
    if (v <= LUA_MAXINTEGER) {
        lua_pushinteger(L, (lua_Integer)v);
    } else {
        lua_pushnumber(L, (lua_Number)v);
    }
}

void pushValue(lua_State* L, lua_CFunction v)
{
    lua_pushcfunction(L, v);
}

void pushValue(lua_State* L, double v)
{
    lua_pushnumber(L, v);
}

void pushValue(lua_State* L, const QByteArray& str)
{
    lua_pushlstring(L, str.data(), str.size());
}

void pushValue(lua_State* L, const QString& str)
{
    pushValue(L, str.toUtf8());
}

void pushValue(lua_State* L, const wchar_t* value)
{
    pushValue(L, QString::fromWCharArray(value));
}

void pushValue(lua_State* L, const QVariant& value)
{
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    auto t = value.metaType().id();
#else
    auto t = (QMetaType::Type)value.type();
#endif
    switch (t) {
    case QMetaType::Bool:
        pushValue(L, value.toBool());
        break;
    case QMetaType::Int:
        pushValue(L, value.toInt());
        break;
    case QMetaType::UInt:
        pushValue(L, value.toUInt());
        break;
    case QMetaType::LongLong:
        // The cast here only seems to be needed on linux, I'm not sure why overload resolution doesn't work there
        // because qlonglong really should be the same as int64_t...
        pushValue(L, (int64_t)value.toLongLong());
        break;
    case QMetaType::ULongLong:
        // As above comment
        pushValue(L, (uint64_t)value.toULongLong());
        break;
    case QMetaType::Double:
        pushValue(L, value.toDouble());
        break;
    case QMetaType::QString:
        pushValue(L, value.toString());
        break;
    case QMetaType::QByteArray:
        pushValue(L, value.toByteArray());
        break;
    default:
        qWarning("Unhandled QVariant type %d", t);
        lua_pushnil(L);
    }
}

int load(lua_State* L, const QString& path)
{
    // Read file ourselves with QFile, rather than just using luaL_loadfile, so
    // as to support loading files from Qt's resource system.
    QFile f(path);
    if (!f.open(QFile::ReadOnly)) {
        // qDebug() << "Couldn't find file" << path;
        lua_pushfstring(L, "Couldn't find file '%s'", qPrintable(path));
        return LUA_ERRFILE;
    }
    auto data = f.readAll();
    f.close();

    if (data.startsWith("#!")) {
        // Skip #! line
        int eol = data.indexOf('\n');
        if (eol != -1) {
            int cr = data.lastIndexOf('\r');
            if (cr != -1 && cr < eol) {
                eol = cr;
            }
        }
        data = data.mid(eol);
    }

    QString ctx;
    if (path.startsWith(":/lua/")) {
        ctx = QString("@") + path.mid(6);
    } else {
        ctx = QString("@") + path;
    }
    int err = luaL_loadbuffer(L, data.data(), data.size(), ctx.toUtf8().data());
    return err;
}

int dofile(lua_State* L, const QString& path)
{
    int err = load(L, path);
    if (err) {
        qDebug() << "Error loading file " << err << luaL_tolstring(L, -1, nullptr);
        lua_pop(L, 1);
    } else {
        err = lua_pcall(L, 0, 0, 0);
        if (err) {
            const char* err_str = lua_tostring(L, -1);
            if (!err_str) {
                err_str = "(No error string returned)";
            }
            qWarning() << "Error:" << err_str;
            lua_pop(L, 1); // err_str
        }
    }
    return err;
}

void require(lua_State *L, const char* str)
{
    lua_getglobal(L, "require");
    lua_pushstring(L, str);
    int err = lua_pcall(L, 1, 1, 0);
    if (err) {
        qWarning("%s", lua_tostring(L, -1));
        lua_pop(L, 1);
        throw std::runtime_error("Missing Lua module");
    }
}
