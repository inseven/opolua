// Have to stub this out to prevent loslib.c from erroring under Catalyst where this API isn't available
// (and nor do we want it)
#define system(cmd) (lua_pushliteral(L, "os.execute() not supported"), lua_error(L), 0)
