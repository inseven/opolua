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

int luaswift_loadfile(lua_State *L, const char *filename,
                      const char *displayname,
                      const char *mode);

static int compile(int argc, const char* argv[]);
static int filewriter(lua_State *L, const void* p, size_t sz, void* ud);
static int makeManifest(int argc, const char* argv[]);

int main(int argc, const char* argv[])
{
    if (argc > 4 && strcmp(argv[1], "manifest") == 0) {
        return makeManifest(argc, argv);
    } else if (argc >= 4 && strcmp(argv[1], "compile") == 0) {
        return compile(argc, argv);
    } else {
        fprintf(stderr, "Syntax: %s compile <luafile> <outfile> [<prefixRewrite>=<newPrefix>, ...]\n", argv[0]);
        fprintf(stderr, "        %s manifest <outfile> <prefix> <src> <alias> [<src> <alias>...]\n", argv[0]);
        return 1;
    }
}

static int compile(int argc, const char* argv[])
{
    // for (int i = 0; i < argc; i++) {
    //     fprintf(stderr, "QLUAC: argv[%d] = %s\n", i, argv[i]);
    // }
    const char* filename = argv[2];
    const size_t filenameLen = strlen(filename);
    const char* outfile = argv[3];
    char* displayName = NULL;

    for (int i = 4; !displayName && i < argc; i++) {
        char* prefix = strdup(argv[i]);
        char* eq = strchr(prefix, '=');
        if (!eq) {
            fprintf(stderr, "Prefix rewrites must be of the form PREFIX=NEWPREFIX\n");
            return 1;
        }
        *eq = 0; // prefix is now null terminated
        size_t prefixLen = eq - prefix;
        // The logic here is a bit weird because og how qluac is invoked, via QMAKE_EXTRA_COMPILERS, which prevents us
        // from controlling the exact format of the <filename> argument. It will have any number of path components
        // prior to the prefix depending on where the build directory is. So we will treat prefix as having an implicit
        // "*" at the front (or however you want to consider it).
        const char* found = strstr(filename, prefix);
        if (found) {
            const char* newPrefix = eq + 1;
            size_t newPrefixLen = strlen(newPrefix);
            size_t filenamePrefixLen = found + prefixLen - filename;
            displayName = malloc(filenameLen - filenamePrefixLen + newPrefixLen + 1);
            memcpy(displayName, newPrefix, newPrefixLen);
            memcpy(displayName + newPrefixLen, filename + filenamePrefixLen, filenameLen - filenamePrefixLen + 1);
            // fprintf(stderr, "Using displayName %s for %s\n", displayName, filename);
        }
        free(prefix);
    }

    lua_State* L = luaL_newstate();
    // luaL_loadfilex() doesn't let us customise the name that ends up in the debug info (and thus in stacktraces)
    // fortunately LuaSwift already has a C function that does.
    int ok = luaswift_loadfile(L, filename, displayName ? displayName : filename, "t");
    free(displayName);
    if (ok != LUA_OK) {
        // In theory we just print the error on the top of the stack and call it a day. That however has the
        // potentially-rewritten displayName rather than the actual filesystem path, which is much more useful here.
        // So reload the file with the original name if it was rewritten.
        if (displayName) {
            lua_pop(L, 1);
            luaswift_loadfile(L, filename, filename, "t");
        }

        fprintf(stderr, "%s\n", luaL_tolstring(L, -1, NULL));
        lua_close(L);
        return 1;
    }

    FILE* f = fopen(outfile, "wb");
    if (!f) {
        fprintf(stderr, "qluac: Cannot open %s\n", outfile);
        lua_close(L);
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
