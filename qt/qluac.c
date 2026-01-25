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

#define MAKE_LIB
#include "onelua.c"

static int filewriter(lua_State *L, const void* p, size_t sz, void* ud);
static int makeManifest(int argc, const char* argv[]);

int main(int argc, const char* argv[])
{
    if (argc > 4 && strcmp(argv[1], "manifest") == 0) {
        return makeManifest(argc, argv);
    }

    if (argc != 3) {
        fprintf(stderr, "Syntax: %s <luafile> <outfile>\n", argv[0]);
        fprintf(stderr, "        %s manifest <outfile> <prefix> <src> <alias> [<src> <alias>...]\n", argv[0]);
        return 1;
    }

    const char* filename = argv[1];
    const char* outfile = argv[2];


    lua_State* L = luaL_newstate();
    int ok = luaL_loadfile(L,filename);
    if (ok != LUA_OK) {
        fprintf(stderr, "%s\n", luaL_tolstring(L, -1, NULL));
        return 1;
    }

    FILE* f = fopen(outfile, "wb");
    if (!f) {
        fprintf(stderr, "qluac: Cannot open %s\n", outfile);
        return 1;
    }

    lua_dump(L, filewriter, f, 0);
    fclose(f);
    lua_close(L);

    return 0;
}

static int filewriter(lua_State *L, const void* p, size_t sz, void* ud)
{
    (void)L;
    int ret = fwrite(p, sz, 1, (FILE*)ud);
    return ret != 1 && sz != 0;
}

static int makeManifest(int argc, const char* argv[])
{
    const char* name = argv[2];
    const char* prefix = argv[3];
    int i = 4;
    FILE* f = fopen(name, "w");
    if (!f) {
        fprintf(stderr, "qluac: Cannot open %s\n", name);
        return 1;
    }
    fprintf(f, "<!DOCTYPE RCC><RCC version=\"1.0\">\n<qresource prefix=\"%s\">\n", prefix);
    while (i + 1 < argc) {
        const char* alias = argv[i++];
        const char* path = argv[i++];
        fprintf(f, "<file alias=\"%s\">%s</file>\n", alias, path);
    }
    fprintf(f, "</qresource>\n</RCC>\n");
    fclose(f);
    return 0;
}
