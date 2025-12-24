// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "oplruntime.h"

#include "filesystem.h"
#include "luasupport.h"
#include "oplkeycode.h"
#include "asynchandle.h"

#include <QCoreApplication>
#include <QDebug>
#include <QEvent>
#include <QJsonDocument>
#include <QJsonValue>
#include <QSysInfo>
#include <QTimer>

#include <time.h>

#ifdef Q_OS_WIN
#define timegm _mkgmtime
#endif

void dumpStack(lua_State *L, const char* where);

#ifdef QT_NO_DEBUG

#define CHECK_STACK_BALANCED(L)
#define CHECK_STACK_ON_RETURN(L, diff)

#else

class StackChecker
{
public:
    StackChecker(lua_State* L, int top) : L(L), top(top) {}
    ~StackChecker() {
        if (lua_gettop(L) != top) {
            qDebug("Expected top: %d actual %d", top, lua_gettop(L));
            dumpStack(L, "StackChecker");
        }
        Q_ASSERT_X(lua_gettop(L) == top, "StackChecker", "Stack top not correct on function exit");
    }

private:
    lua_State *L;
    int top;
};

#define CONCAT_INNER(x, y) x ## y
#define CONCAT(x,y) CONCAT_INNER(x, y)
#define CHECK_STACK_BALANCED(L) StackChecker CONCAT(_stackcheck_, __LINE__) (L, lua_gettop(L))
#define CHECK_STACK_ON_RETURN(L, diff) StackChecker CONCAT(_stackcheck_, __LINE__) (L, lua_gettop(L) diff)

#endif // QT_NO_DEBUG

void dumpStack(lua_State *L, const char* where)
{
    const int n = lua_gettop(L);
    qDebug("%s stack size: %d", where, n);
    for (int i = 1; i <= n; i++) {
        qDebug("%d: %s", i, luaL_tolstring(L, i, nullptr));
        lua_pop(L, 1); // The thing pushed by tolstring
    }
}

bool OplRuntime::Event::isKeyEvent() const
{
    return (code & 0x400) == 0;
}

OplRuntime::OplRuntime(QObject *parent)
    : QObject(parent)
    , mThread(nullptr)
    , mDeviceType(Series5)
    , mIgnoreOpoEra(false)
    , mCallEvent(nullptr)
    , mEventRequest(nullptr)
    , mWaiting(false)
    , mInterrupted(false)
    , mSpeed(Fastest)
    , mInfoWinId(0)
    , mBusyWinId(0)
    , mCursorDrawn(false)
    , mEscapeOn(true)
{
    mFs.reset(new FileSystemIoHandler());
    mStringCodec = QTextCodec::codecForName("Windows-1252");
    mConfig["locale"] = "en_GB";
    mConfig["clockFormat"] = "0";

    L = luaL_newstate();
    luaL_requiref(L, LUA_GNAME, luaopen_base, 1);
    luaL_requiref(L, LUA_LOADLIBNAME, luaopen_package, 1);
    luaL_requiref(L, LUA_TABLIBNAME, luaopen_table, 1);
    luaL_requiref(L, LUA_IOLIBNAME, luaopen_io, 1);
    luaL_requiref(L, LUA_OSLIBNAME, luaopen_os, 1);
    luaL_requiref(L, LUA_STRLIBNAME, luaopen_string, 1);
    luaL_requiref(L, LUA_MATHLIBNAME, luaopen_math, 1);
    luaL_requiref(L, LUA_UTF8LIBNAME, luaopen_utf8, 1);
    luaL_requiref(L, LUA_DBLIBNAME, luaopen_debug, 1);
    lua_settop(L, 0);

    configureLuaResourceSearcher(L);

    ::dofile(L, ":/lua/init.lua");

    lua_pushlightuserdata(L, this);
    lua_pushcclosure(L, printHandler_s, 1);
    lua_setglobal(L, "doprint");

    mLastOpTime.start();
}

void OplRuntime::pushIohandler()
{
    mFs->makeFsIoHandlerBridge(L);

    luaL_Reg funcs[] = {
        IOHANDLER_FN(asyncRequest),
        IOHANDLER_FN(cancelRequest),
        IOHANDLER_FN(checkCompletions),
        IOHANDLER_FN(createBitmap),
        IOHANDLER_FN(createWindow),
        IOHANDLER_FN(draw),
        IOHANDLER_FN(getConfig),
        IOHANDLER_FN(getDeviceInfo),
        IOHANDLER_FN(getTime),
        IOHANDLER_FN(graphicsop),
        IOHANDLER_FN(opsync),
        IOHANDLER_FN(system),
        IOHANDLER_FN(setConfig),
        IOHANDLER_FN(setEra),
        IOHANDLER_FN(testEvent),
        IOHANDLER_FN(textEditor),
        IOHANDLER_FN(utctime),
        IOHANDLER_FN(waitForAnyRequest),
        { nullptr, nullptr }
    };
    lua_pushlightuserdata(L, this);
    luaL_setfuncs(L, funcs, 1);
}

static int searcher(lua_State *L)
{
    QString name = QString(":/lua/") + QString(lua_tostring(L, 1)).replace(".", "/") + ".lua";
    int err = load(L, name);
    if (err == LUA_ERRFILE) {
        lua_pushfstring(L, "no file '%s'", qPrintable(name));
        return 1;
    } else if (err) {
        return lua_error(L);
    }
    return 1;
}

void OplRuntime::configureLuaResourceSearcher(lua_State *L)
{
    lua_getglobal(L, "package");
    lua_getfield(L, -1, "searchers"); // orig searchers
    lua_createtable(L, 1, 0); // newsearchers
    lua_rawgeti(L, -2, 1); // package.searchers[1]
    lua_rawseti(L, -2, 1); // newsearchers[1] = package.searchers[1]

    lua_pushcfunction(L, searcher);
    lua_rawseti(L, -2, 2);

    lua_setfield(L, -3, "searchers");
    lua_pop(L, 2); // orig searchers, package
}

int OplRuntime::dofile(lua_State *L)
{
    auto path = luaL_checkstring(L, 1);
    int err = ::dofile(L, path);
    if (err) {
        return luaL_error(L, "Cannot open %s", path);
    } else {
        return 0;
    }
}

void OplRuntime::setDeviceType(DeviceType type)
{
    mDeviceType = type;
    switch (mDeviceType) {
    case Series7:
        mFs->addMapping('Z', QDir(":/psion-series-7/z"), false);
        break;
    default:
        mFs->addMapping('Z', QDir(":/psion-series-5/z"), false);
        break;
    }
    emit deviceTypeChanged();
}

void OplRuntime::setIgnoreOpoEra(bool flag)
{
    mIgnoreOpoEra = flag;
}

OplRuntime::DeviceType OplRuntime::getDeviceType() const
{
    return mDeviceType;
}

void OplRuntime::setDrive(Drive drive, const QString& path)
{
    if (path.isEmpty()) {
        mFs->removeMapping((char)drive);
    } else {
        // Assume any path that's not a resource should be writable
        QDir dir(path);
        bool writable = !dir.absolutePath().startsWith(":");
        mFs->addMapping((char)drive, dir, writable);
    }
}

void OplRuntime::removeAllDrives()
{
    mFs->removeAllMappings();
}

QString OplRuntime::getNativePath(const QString& devicePath) const
{
    return mFs->getNativePath(devicePath);
}

QSize OplRuntime::screenSize() const
{
    switch (mDeviceType) {
    case Series3:
        return QSize(240, 80);
    case Siena:
        return QSize(240, 160);
    case Series3c:
        return QSize(480, 160);
    case Series5:
        return QSize(640, 240);
    case Revo:
        return QSize(480, 160);
    case Series7:
        return QSize(640, 480);
    case GeofoxOne:
        return QSize(640, 320);
    default:
        Q_UNREACHABLE();
    }
}

OplRuntime::~OplRuntime()
{
    if (mThread && mThread->isRunning()) {
        disconnect(mThread, &QThread::finished, this, &OplRuntime::onThreadExited); // just in case
        interrupt();
        mThread->wait();
        delete mThread;
        mThread = nullptr;
    }
    lua_close(L);
    delete mEventRequest;
}

static int KStopErr = -999;
static int KColorgCreate4GrayMode = 0x0001;
static int KColorgCreate16GrayMode = 0x0002;
static int KColorgCreate256ColorMode = 0x0005;

static void stop(lua_State *L, lua_Debug *)
{
    qDebug("Stop hook called, exiting interpreter with error(KStopErr)");
    lua_sethook(L, nullptr, 0, 0);
    lua_pushinteger(L, KStopErr);
    lua_error(L);
}

static int traceHandler(lua_State *L)
{
    lua_settop(L, 1);
    if (lua_type(L, 1) != LUA_TTABLE) {
        // Create a table
        lua_newtable(L);
        lua_insert(L, 1);
        // We might get a raw number-as-leave-code if for eg we're running something in launcher.lua
        if (lua_type(L, -1) == LUA_TNUMBER) {
            int err = lua_tointeger(L, -1);
            lua_pop(L, 1);
            lua_pushfstring(L, "Epoc error %d", err);
        } else if (lua_type(L, -1) != LUA_TSTRING) {
            lua_pop(L, 1);
            lua_pushstring(L, "(No error message)");
        }
        lua_setfield(L, 1, "msg");
    }

    // Position 1 is now definitely a table. See if needs a stacktrace.
    if (lua_getfield(L, 1, "luaStack") == LUA_TNIL) {
        luaL_traceback(L, L, nullptr, 1);
        lua_setfield(L, 1, "luaStack");
    }
    lua_pop(L, 1); // luaStack
    return 1;
}

// Lives on the stack of the Lua thread (thus owned by it)
struct MainThreadCall
{
    MainThreadCall(std::function<int(void)> fn)
        : function(fn)
        , ret(0)
    {}

    int wait() {
        semaphore.acquire();
        return ret;
    }
    void callAndSignal() {
        ret = function();
        semaphore.release();
    }
    void interrupt() {
        ret = KStopErr;
        semaphore.release();
    }

private:
    QSemaphore semaphore;
    std::function<int(void)> function;
    int ret;
};

// Owned by the main thread
class MainThreadEvent : public QEvent {
public:
    MainThreadEvent(MainThreadCall* call)
        : QEvent(QEvent::User)
        , call(call)
    {}

    MainThreadCall* call;
};

void OplRuntime::interrupt()
{
    interruptAndRun(nullptr);
}

void OplRuntime::interruptAndRun(std::function<void(void)> runNextFn)
{
    setEscape(true);
    if (!running()) {
        if (runNextFn) {
            runNextFn();
        }
        return;
    }
    mRunNextFn = [this, runNextFn] {
        lua_settop(L, 0);
        if (runNextFn) {
            runNextFn();
        } else {
            emit runComplete(QString(), QString());
        }
    };
    lua_sethook(L, stop, LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE | LUA_MASKCOUNT, 1);
    mMutex.lock();
    mInterrupted = true;
    if (mCallEvent && mCallEvent->call) {
        mCallEvent->call->interrupt();
        mCallEvent->call = nullptr;
    }
    unlockAndSignalIfWaiting();
}

void OplRuntime::restart()
{
    auto prevRunNextFn = mRunNextFn;
    auto fn = [this, prevRunNextFn]() {
        lua_settop(L, 0);
        lua_getfield(L, LUA_REGISTRYINDEX, "restartArgs");
        lua_rawgeti(L, 1, 0);
        int nargs = lua_tointeger(L, -1);
        lua_pop(L, 1);
        for (int i = 1; i <= nargs; i++) {
            lua_rawgeti(L, 1, i);
        }
        lua_remove(L, 1);
        // dumpStack(L, "restart");

        mRunNextFn = prevRunNextFn;
        startThread();
    };

    if (running()) {
        interruptAndRun(fn);
        // will result in fn() being re-called from onThreadExited
    } else {
        fn();
    }
}

QString OplRuntime::deviceTypeToString(DeviceType type)
{
    switch (type) {
    case Series3:
        return "psion-series-3";
    case Series3c:
        return "psion-series-3c";
    case Siena:
        return "psion-siena";
    case Series5:
        return "psion-series-5";
    case Revo:
        return "psion-revo";
    case Series7:
        return "psion-series-7";
    case GeofoxOne:
        return "geofox-one";
    }
}

OplRuntime::DeviceType OplRuntime::toDeviceType(const QString& device)
{
    if (device == "psion-series-3") {
        return Series3;
    } else if (device == "psion-series-3c") {
        return Series3c;
    } else if (device == "psion-siena") {
        return Siena;
    } else if (device == "psion-series-5") {
        return Series5;
    } else if (device == "psion-revo") {
        return Revo;
    } else if (device == "psion-series-7") {
        return Series7;
    } else if (device == "geofox-one") {
        return GeofoxOne;
    } else {
        qWarning("Unknown device type %s", qPrintable(device));
        return Series5;
    }
}

bool OplRuntime::isSiboDeviceType(DeviceType type)
{
    switch (type) {
    case Series3:
    case Series3c:
    case Siena:
        return true;
    case Series5:
    case Revo:
    case Series7:
    case GeofoxOne:
        return false;
    }
}

bool OplRuntime::isSibo() const
{
    return isSiboDeviceType(mDeviceType);
}

int OplRuntime::getDeviceInfo(lua_State* L)
{
    auto sz = screenSize();
    auto typeStr = deviceTypeToString(mDeviceType);
    lua_pushinteger(L, sz.width());
    lua_pushinteger(L, sz.height());
    switch (mDeviceType) {
    case Series3:
    case Series3c:
    case Siena:
        lua_pushinteger(L, KColorgCreate4GrayMode);
        break;
    case Series5:
        lua_pushinteger(L, KColorgCreate16GrayMode);
        break;
    case Revo:
        lua_pushinteger(L, KColorgCreate16GrayMode);
        break;
    case Series7:
        lua_pushinteger(L, KColorgCreate256ColorMode);
        break;
    case GeofoxOne:
        lua_pushinteger(L, KColorgCreate256ColorMode);
        break;
    }
    pushValue(L, typeStr);
    return 4;
}

bool OplRuntime::running() const
{
    return mThread != nullptr;
}

bool OplRuntime::writableCDrive() const
{
    return mFs->isWritable('C') || mFs->isWritable('M');
}

void OplRuntime::setEscape(bool flag) {
    if (flag != mEscapeOn) {
        mEscapeOn = flag;
        emit escapeStateChanged(mEscapeOn);
    }
}

void OplRuntime::run(const QDir& cDrive, const QString& devicePath)
{
    mFs->addMapping('C', cDrive, !cDrive.absolutePath().startsWith(":"));
    run(devicePath);
}

void OplRuntime::run(const QString& devicePath)
{
    mLauncherCmd.clear();
    pushRunParams(devicePath);
    startThread();
}

void OplRuntime::pushRunParams(const QString& devicePath)
{
    lua_settop(L, 0);
    mDeviceOpoPath = devicePath;
    setDeviceType(mDeviceType); // Re-configures Z drive mapping if necessary
    require(L, "runtime");
    lua_getfield(L, -1, "runOpo");
    lua_remove(L, -2); // runtime
    pushValue(L, mDeviceOpoPath);
    lua_pushnil(L); // procName
    pushIohandler();
}

void OplRuntime::startThread()
{
    // The stack of L is now set up for threadFn to use
    // dumpStack(L, "startThread");

    // Set restartArgs
    int nargs = lua_gettop(L);
    lua_newtable(L);
    lua_pushinteger(L, nargs);
    lua_rawseti(L, -2, 0);
    for (int i = 1; i <= nargs; i++) {
        lua_pushvalue(L, i);
        lua_rawseti(L, -2, i);
    }
    lua_setfield(L, LUA_REGISTRYINDEX, "restartArgs");
    Q_ASSERT(lua_gettop(L) == nargs);

    Q_ASSERT(mThread == nullptr);
    mThread = QThread::create(threadFn, this);
    mThread->setParent(this);
    connect(mThread, &QThread::finished, this, &OplRuntime::onThreadExited);

    if (mScreen) {
        mScreen->init();
    }

    // Runtime always starts out escapable
    setEscape(true);

    emit startedRunning(mDeviceOpoPath.isEmpty() ? QString() : mFs->getNativePath(mDeviceOpoPath));

    mThread->start();
    // L is now owned by mThread
}

void OplRuntime::runOpo(const QString& path)
{
    mFs->addSimulatedDrive('C', {path});
    pushRunParams(QString("C:\\") + QFileInfo(path).fileName());
    startThread();
}

// This fn overwrites the filesystem mappings
void OplRuntime::runInstaller(const QString& file, const QString& displayPath)
{
    doRunInstaller(file, displayPath, QString());
}

void OplRuntime::doRunInstaller(const QString& file, const QString& displayPath, const QString& lang)
{
    Q_ASSERT(mThread == nullptr);
    mLauncherCmd = "installSis";
    mFs->addSimulatedDrive('I', {file});
    lua_settop(L, 0);
    require(L, "runtime");
    lua_getfield(L, -1, "runLauncherCmd");
    lua_remove(L, -2); // runtime
    pushIohandler();
    pushValue(L, mLauncherCmd);
    pushValue(L, file);
    pushValue(L, QString("I:\\" + QFileInfo(file).fileName()));
    pushValue(L, displayPath);
    if (!lang.isEmpty()) {
        pushValue(L, lang);
    }
    mRunNextFn = [this, file, displayPath]() {
        mFs->removeMapping('I');
        if (lua_type(L, -1) != LUA_TTABLE) {
            emit runComplete(QString(), QString());
            return;
        }
        auto launch = to_string(L, -1, "launch");
        auto changeDevice = to_string(L, -1, "setdevice");

        if (!changeDevice.isEmpty()) {
            auto lang = to_string(L, -1, "lang");
            lua_pop(L, 1);
            setDeviceType(toDeviceType(changeDevice));
            doRunInstaller(file, displayPath, lang);
            return;
        }

        lua_pop(L, 1);
        emit installationComplete(file);
        if (!launch.isEmpty()) {
            pushRunParams(launch);
            startThread();
        } else {
            emit runComplete(QString(), QString());
        }
    };
    startThread();
}

void OplRuntime::runLauncher()
{
    Q_ASSERT(mThread == nullptr);
    mLauncherCmd = "launcher";
    mFs->addSimulatedDrive('C', {":/welcome/c/System/Apps/Welcome/icons_color.mbm"});
    lua_settop(L, 0);
    require(L, "runtime");
    lua_getfield(L, -1, "runLauncherCmd");
    lua_remove(L, -2); // runtime
    pushIohandler();
    pushValue(L, mLauncherCmd);
    pushValue(L, QSysInfo::productType());
    startThread();
}

void OplRuntime::runAppSelector()
{
    Q_ASSERT(mThread == nullptr);
    mLauncherCmd = "selectApp";
    lua_settop(L, 0);
    require(L, "runtime");
    lua_getfield(L, -1, "runLauncherCmd");
    lua_remove(L, -2); // runtime
    pushIohandler();
    pushValue(L, mLauncherCmd);
    mRunNextFn = [this]() {
        if (lua_type(L, -1) != LUA_TSTRING) {
            qDebug("No response!");
            return;
        }
        QString path(lua_tostring(L, -1));
        lua_pop(L, 1);
        pushRunParams(path);
        startThread();
    };
    startThread();
}

void OplRuntime::threadFn(OplRuntime* self)
{
    auto L = self->L;

    lua_pushcfunction(L, traceHandler);
    lua_insert(L, 1);
    // stack should now be:
    // 1: traceHandler
    // 2: function to call
    // 3-top: arguments
    // dumpStack(L, "threadFn");
    Q_ASSERT(lua_type(L, 1) == LUA_TFUNCTION);
    Q_ASSERT(lua_type(L, 2) == LUA_TFUNCTION);
    self->mRet = lua_pcall(L, lua_gettop(L) - 2, 1, 1);
    lua_sethook(L, nullptr, 0, 0); // in case of interrupt()
}

void OplRuntime::onThreadExited()
{
    setEscape(true);
    QString errmsg, errdetail;
    if (mRet) {
        lua_getfield(L, -1, "msg");
        errmsg = lua_tostring(L, -1);
        lua_pop(L, 1);
        errdetail = errmsg;
        if (lua_getfield(L, -1, "opoStack") == LUA_TSTRING) {
            errdetail = errdetail + "\n" + lua_tostring(L, -1);
        }
        lua_pop(L, 1);
        if (lua_getfield(L, -1, "luaStack") == LUA_TSTRING) {
            errdetail = errdetail + "\n" + lua_tostring(L, -1);
        }
        lua_pop(L, 1);
    }
    delete mThread;
    mThread = nullptr;

    mPendingCompletions.clear();
    mInterrupted = false;
    for (AsyncHandle* h : mPendingRequests) {
        delete h;
    }
    mPendingRequests.clear();
    mEvents.clear();
    // TODO hmm should really clear the Lua registry of pending requests...
    mEventRequest = nullptr;

    mInfoWinHideTimer.reset();
    mBusyWinShowTimer.reset();
    mCursorTimer.reset();

    qDebug("Runtime exited with: msg='%s' detail='%s'", qPrintable(errmsg), qPrintable(errdetail));

    auto fn = mRunNextFn;
    if (fn) {
        mRunNextFn = nullptr;
        // mScreen->init();
        fn();
    } else {
        lua_settop(L, 0);
        emit runComplete(errmsg, errdetail);
    }
}

int OplRuntime::call(std::function<int(void)> fn)
{
    // Calls fn on the main thread, then blocks until the main thread calls the function
    // qDebug("+call");
    mMutex.lock();
    Q_ASSERT(mCallEvent == nullptr);
    if (mInterrupted) {
        mMutex.unlock();
        lua_pushinteger(L, KStopErr);
        return lua_error(L);
    }

    MainThreadCall call(fn);
    auto m = new MainThreadEvent(&call);
    mCallEvent = m;

    mMutex.unlock();
    QCoreApplication::postEvent(this, m);
    int ret = call.wait();
    mMutex.lock();
    Q_ASSERT(mCallEvent == m);
    mCallEvent = nullptr;
    mMutex.unlock();
    if (ret == KStopErr) {
        // qDebug("-call interrupted!");
        lua_pushinteger(L, KStopErr);
        return lua_error(L);
    } else {
        // qDebug("-call");
        return ret;
    }
}

bool OplRuntime::event(QEvent* ev)
{
    if (ev->type() == QEvent::User) {
        auto m = static_cast<MainThreadEvent*>(ev);
        mMutex.lock();
        if (m->call) {
            // It's not been interrupted
            mMutex.unlock();
            m->call->callAndSignal();
        } else {
            mMutex.unlock();
        }
        // QCoreApplication takes care of deleting m
        return true;
    } else {
        return QObject::event(ev);
    }
}

OplRuntime* OplRuntime::getSelf(lua_State *L)
{
    return reinterpret_cast<OplRuntime*>(lua_touserdata(L, lua_upvalueindex(1)));
}

QString OplRuntime::tolocalstring(lua_State *L, int index)
{
    auto str = lua_tostring(L, index);
    return mStringCodec->toUnicode(str);
}

int OplRuntime::graphicsop(lua_State* L)
{
    auto cmd = QString(lua_tostring(L, 1));
    if (cmd == "close") {
        return call([this, L] {
            mScreen->closeDrawable(lua_tointeger(L, 2));
            return 0;
        });
    } else if (cmd == "show") {
        return call([this, L] {
            lua_pushinteger(L, mScreen->showWindow(lua_tointeger(L, 2), lua_toboolean(L, 3)));
            return 1;
        });
    } else if (cmd == "setwin") {
        return call([this, L] {
            int drawableId = lua_tointeger(L, 2);
            QPoint pos(lua_tointeger(L, 3), lua_tointeger(L, 4));
            QSize size;
            QSize* sizePtr = nullptr;
            if (!lua_isnil(L, 5)) {
                size = QSize(lua_tointeger(L, 5), lua_tointeger(L, 6));
                sizePtr = &size;
            }
            lua_pushinteger(L, mScreen->setWindowRect(drawableId, pos, sizePtr));
            return 1;
        });
    } else if (cmd == "order") {
        int drawableId = lua_tointeger(L, 2);
        int pos = lua_tointeger(L, 3);
        if (mInfoWinId && drawableId != mInfoWinId) {
            // Make sure nothing can sneak in front of the info win (which will always be rank=1)
            pos = qMax(pos, 1) + 1;
            mScreen->setOrder(drawableId, pos);
        }
        return 0;
    } else if (cmd == "rank") {
        int drawableId = lua_tointeger(L, 2);
        int result = mScreen->getRank(drawableId);
        if (mInfoWinId) {
            // The info win is a window from mScreen's point of view, but shouldn't appear in the rankings
            result--;
        }
        lua_pushinteger(L, result);
        return 1;
    } else if (cmd == "loadfont") {
        return call([this, L] {
            int drawableId = lua_tointeger(L, 2);
            uint32_t uid = (uint32_t)lua_tointeger(L, 3);
            OplScreen::FontMetrics metrics{};
            QString pngPath = getFont(uid, metrics);
            if (pngPath.isEmpty()) {
                lua_pushnil(L);
                lua_pushinteger(L, KErrInvalidArgs);
                return 2;
            }

            mScreen->loadPng(drawableId, pngPath);
            lua_newtable(L);
            SET_INT(L, "height", metrics.height);
            SET_INT(L, "ascent", metrics.ascent);
            SET_INT(L, "descent", metrics.descent);
            SET_INT(L, "maxwidth", metrics.maxwidth);
            lua_createtable(L, 256, 0);
            for (int i = 0; i < 256; i++) {
                lua_pushinteger(L, metrics.widths[i]);
                lua_rawseti(L, -2, i + 1);
            }
            lua_setfield(L, -2, "widths");
            return 1;
        });
    } else if (cmd == "giprint") {
        return call([this, L] {
            int drawableId = lua_tointeger(L, 2);
            if (drawableId == 0) {
                if (mInfoWinId) {
                    mScreen->showWindow(mInfoWinId, false);
                }
                mInfoWinHideTimer.reset();
                return 0;
            }

            mInfoWinId = drawableId;
            mScreen->showWindow(mInfoWinId, true);
            mInfoWinHideTimer.reset(new QTimer());
            connect(mInfoWinHideTimer.get(), &QTimer::timeout, this, [this]() {
                mInfoWinHideTimer.reset();
                mScreen->showWindow(mInfoWinId, false);
            });
            mInfoWinHideTimer->setSingleShot(true);
            mInfoWinHideTimer->setTimerType(Qt::PreciseTimer);
            mInfoWinHideTimer->start(2000);
            return 0;
        });
    } else if (cmd == "busy") {
        return call([this, L] {
            int drawableId = lua_tointeger(L, 2);
            int delay = lua_tointeger(L, 3);
            if (drawableId == 0) {
                if (mBusyWinId) {
                    mScreen->showWindow(mBusyWinId, false);
                }
                mBusyWinShowTimer.reset();
                return 0;
            }

            mBusyWinId = drawableId;
            mBusyWinShowTimer.reset(new QTimer(this));
            connect(mBusyWinShowTimer.get(), &QTimer::timeout, this, [this]() {
                mBusyWinShowTimer.reset();
                mScreen->showWindow(mBusyWinId, true);
            });
            mBusyWinShowTimer->setSingleShot(true);
            mBusyWinShowTimer->setTimerType(Qt::PreciseTimer);
            mBusyWinShowTimer->start(delay * 500); // delay is in half-seconds, so convert to milliseconds
            return 0;
        });
    } else if (cmd == "cursor") {
        return call([this, L] {
            mCursorTimer.reset();
            if (mCursorDrawn) {
                // Then clear the old cursor
                drawCursor();
            }
            mCursorDrawCmd = std::nullopt;
            if (lua_type(L, 2) == LUA_TTABLE) {
                int flags = to_int(L, 2, "flags");
                constexpr int KCursorTypeNotFlashing = 2;
                constexpr int KCursorTypeGrey = 4;
                // The grey cursor color doesn't really work with the invert drawing mode, never mind.
                rawgetfield(L, 2, "rect");
                mCursorDrawCmd = {
                    .type = OplScreen::fill,
                    .drawableId = to_int(L, 2, "id"),
                    .mode = OplScreen::invert,
                    .origin = QPoint(to_int(L, 3, "x"), to_int(L, 3, "y")),
                    .color = (flags & KCursorTypeGrey) ? 0xFF888888 : 0xFF000000,
                    .bgcolor = 0xFFFFFFFF, // doesn't really matter
                    .penWidth = 1,
                    .greyMode = OplScreen::drawBlack,
                    .fill = {
                        .size = QSize(to_int(L, 3, "w"), to_int(L, 3, "h")),
                    },
                };
                drawCursor();
                if ((flags & KCursorTypeNotFlashing) == 0) {
                    mCursorTimer.reset(new QTimer());
                    connect(mCursorTimer.get(), &QTimer::timeout, this, &OplRuntime::drawCursor);
                    mCursorTimer->setTimerType(Qt::PreciseTimer);
                    mCursorTimer->start(500);
                }
            }
            return 0;
        });
    } else if (cmd == "clock") {
        return call([this, L] {
            int drawableId = lua_tointeger(L, 2);
            if (lua_type(L, 3) == LUA_TTABLE) {
                rawgetfield(L, 3, "position");
                OplScreen::ClockInfo info = {
                    .mode = (OplScreen::ClockType)to_int(L, 3, "mode"),
                    .systemIsDigital = mConfig["clockFormat"] == "1",
                    .color = mDeviceType >= Series7,
                    .pos = QPoint(to_int(L, 4, "x"), to_int(L, 4, "y")),
                };
                mScreen->clock(drawableId, &info);
            } else {
                mScreen->clock(drawableId, nullptr);
            }
            return 0;
        });
    } else if (cmd == "sprite") {
        return call([this, L] {
            int windowId = lua_tointeger(L, 2);
            int spriteId = lua_tointeger(L, 3);
            if (lua_isnil(L, 4)) {
                mScreen->sprite(windowId, spriteId, nullptr);
                return 0;
            }
            OplScreen::Sprite sprite;
            sprite.origin = to_point(L, 4, "origin");
            rawgetfield(L, 4, "frames");
            for (int i = 1; ; i++) {
                if (lua_rawgeti(L, -1, i) != LUA_TTABLE) {
                    lua_pop(L, 1);
                    break;
                }
                OplScreen::SpriteFrame frame = {
                    .offset = to_point(L, -1, "offset"),
                    .bitmap = to_int(L, -1, "bitmap"),
                    .mask = to_int(L, -1, "mask"),
                    .invertMask = to_bool(L, -1, "invertMask"),
                    .time = (int)(to_double(L, -1, "time") * 1000000), // in microseconds
                };
                sprite.frames.append(frame);
                lua_pop(L, 1); // frame
            }
            lua_pop(L, 1); // frames
            mScreen->sprite(windowId, spriteId, &sprite);
            return 0;
        });
    } else if (cmd == "peekline") {
        return call([this, L] {
            int drawableId = lua_tointeger(L, 2);
            QPoint point(lua_tointeger(L, 3), lua_tointeger(L, 4));
            int numPixels = lua_tointeger(L, 5);
            auto mode = (OplScreen::PeekMode)lua_tointeger(L, 6);
            pushValue(L, mScreen->peekLine(drawableId, point, numPixels, mode));
            return 1;
        });
    } else if (cmd == "getimg") {
        return call([this, L] {
            int drawableId = lua_tointeger(L, 2);
            QRect rect(to_int(L, 3, "x"), to_int(L, 3, "y"), to_int(L, 3, "w"), to_int(L, 3, "h"));
            pushValue(L, mScreen->getImageData(drawableId, rect));
            return 1;
        });
    } else {
        qWarning("Unhandled graphicsop %s", qPrintable(cmd));
        return 0;
    }
}

// This is intended to be layout-compatible with QRgb, ie it sets the top byte to opaque alpha 0xFF
static uint32_t to_rgb(lua_State* L, int idx, const char* name)
{
    rawgetfield(L, idx, name);
    uint32_t result = 0xFF000000 | (to_int(L, -1, "r") << 16) | (to_int(L, -1, "g") << 8) | to_int(L, -1, "b");
    lua_pop(L, 1);
    return result;
}

int OplRuntime::draw(lua_State* L)
{
    // qDebug("draw top=%d", lua_gettop(L));
    int pixelsWritten = 0;
    return call([this, L, &pixelsWritten] {
        mScreen->beginBatchDraw();
        for (int i = 0; ; i++) {
            // qDebug("draw[mainthread] i=%d top=%d", i, lua_gettop(L));
            int t = lua_rawgeti(L, 1, i + 1);
            // qDebug("draw %d t=%d", i, t);
            if (t != LUA_TTABLE) {
                break;
            }
            OplScreen::DrawCmd cmd = {
                .type = OplScreen::fill, // Just to shut up compiler warning
                .drawableId = to_int(L, 2, "id"),
                .mode = (OplScreen::DrawCmdMode)to_int(L, 2, "mode"),
                .origin = QPoint(to_int(L, 2, "x"), to_int(L, 2, "y")),
                .color = to_rgb(L, 2, "color"),
                .bgcolor = to_rgb(L, 2, "bgcolor"),
                .penWidth = to_int(L, 2, "penwidth"),
                .greyMode = (OplScreen::GreyMode)to_int(L, 2, "greyMode"),
                .shutUpCompiler = 0,
            };
            if (cmd.penWidth == 0) cmd.penWidth = 1;
            QString type = to_string(L, 2, "type");
            if (type == "fill") {
                cmd.type = OplScreen::fill;
                cmd.fill.size = QSize(to_int(L, 2, "width"), to_int(L, 2, "height"));
                pixelsWritten += cmd.fill.size.width() * cmd.fill.size.height();
            } else if (type == "line") {
                cmd.type = OplScreen::line;
                cmd.line.endPoint = QPoint(to_int(L, 2, "x2"), to_int(L, 2, "y2"));
                // Manhattan approximation
                pixelsWritten += qAbs(cmd.origin.x() - cmd.line.endPoint.x()) + qAbs(cmd.origin.y() - cmd.line.endPoint.y());
            } else if (type == "circle") {
                cmd.type = OplScreen::circle;
                cmd.circle.radius = to_int(L, 2, "r");
                cmd.circle.fill = to_bool(L, 2, "fill");
                pixelsWritten += 6 * cmd.circle.radius; // Close enough to 2 * pi * r
            } else if (type == "box") {
                cmd.type = OplScreen::box;
                cmd.box.size = QSize(to_int(L, 2, "width"), to_int(L, 2, "height"));
                pixelsWritten += 2 * cmd.box.size.width() + 2 * cmd.box.size.height();
            } else if (type == "mcopy") {
                OplScreen::CopyMultipleCmd cpycmd = {
                    .srcId = to_int(L, 2, "srcid"),
                    .destId = cmd.drawableId,
                    .color = cmd.bgcolor,
                    .invert = cmd.mode == OplScreen::invert,
                    .greyMode = cmd.greyMode,
                };
                QVector<QRect> rects;
                QVector<QPoint> points;
                int numPixels = 0;
                for (int i = 1; ; i += 6) {
                    lua_rawgeti(L, 2, i);
                    lua_rawgeti(L, 2, i+1);
                    lua_rawgeti(L, 2, i+2);
                    lua_rawgeti(L, 2, i+3);
                    lua_rawgeti(L, 2, i+4);
                    if (lua_rawgeti(L, 2, i+5) != LUA_TNUMBER) {
                        lua_pop(L, 6);
                        break;
                    }
                    QRect r(lua_tointeger(L, -6), lua_tointeger(L, -5), lua_tointeger(L, -4), lua_tointeger(L, -3));
                    numPixels += r.width() * r.height();
                    rects.append(r);
                    points.append(QPoint(lua_tointeger(L, -2), lua_tointeger(L, -1)));
                    lua_pop(L, 6);
                }
                pixelsWritten += numPixels;
                mScreen->copyMultiple(cpycmd, rects, points);
                lua_pop(L, 1); // cmd
                continue;
            } else if (type == "bitblt") {
                rawgetfield(L, 2, "bitmap");
                int width = to_int(L, -1, "width");
                int height = to_int(L, -1, "height");
                bool color = to_bool(L, -1, "isColor");
                auto data = to_bytearray(L, -1, "normalizedImgData");
                lua_pop(L, 1); // bitmap

                mScreen->bitBlt(cmd.drawableId, color, width, height, data);
                pixelsWritten += width * height;
                lua_pop(L, 1); // cmd
                continue;
            } else if (type == "scroll") {
                cmd.type = OplScreen::scroll;
                cmd.scroll.dx = to_int(L, 2, "dx");
                cmd.scroll.dy = to_int(L, 2, "dy");
                rawgetfield(L, 2, "rect");
                cmd.scroll.rect = QRect(to_int(L, -1, "x"), to_int(L, -1, "y"), to_int(L, -1, "w"), to_int(L, -1, "h"));
                pixelsWritten += cmd.scroll.rect.width() * cmd.scroll.rect.height(); // Close enough?
                lua_pop(L, 1);
            } else if (type == "border") {
                cmd.type = OplScreen::border;
                cmd.border.borderType = to_int(L, 2, "btype");
                cmd.border.rect = QRect(cmd.origin.x(), cmd.origin.y(), to_int(L, 2, "width"), to_int(L, 2, "height"));
                // TODO pixelsWritten
            } else if (type == "copy") {
                cmd.type = OplScreen::copy;
                cmd.copy.srcDrawableId = to_int(L, 2, "srcid");
                cmd.copy.maskDrawableId = to_int(L, 2, "mask");
                cmd.copy.srcRect = QRect(to_int(L, 2, "srcx"), to_int(L, 2, "srcy"), to_int(L, 2, "width"), to_int(L, 2, "height"));
                pixelsWritten += cmd.copy.srcRect.width() * cmd.copy.srcRect.height(); // Doesn't account for clipping, close enough
            } else if (type == "patt") {
                cmd.type = OplScreen::pattern;
                cmd.pattern.srcDrawableId = to_int(L, 2, "srcid");
                cmd.pattern.size = QSize(to_int(L, 2, "width"), to_int(L, 2, "height"));
                pixelsWritten += cmd.pattern.size.width() * cmd.pattern.size.height();
            } else if (type == "invert") {
                cmd.type = OplScreen::cmdInvert;
                cmd.invert.size = QSize(to_int(L, 2, "width"), to_int(L, 2, "height"));
                pixelsWritten += cmd.invert.size.width() * cmd.invert.size.height();
            } else {
                qWarning("Unhandled draw cmd %s", qPrintable(type));
                lua_pop(L, 1); // cmd
                continue;
            }
            mScreen->draw(cmd);
            lua_pop(L, 1); // cmd
        }
        mScreen->endBatchDraw();
        didWritePixels(pixelsWritten);
        return 0;
    });
}

int OplRuntime::createWindow(lua_State* L)
{
    return call([this, L] {
        int drawableId = lua_tointeger(L, 1);
        QRect rect(lua_tointeger(L, 2), lua_tointeger(L, 3), lua_tointeger(L, 4), lua_tointeger(L, 5));
        int flags = lua_tointeger(L, 6);
        OplScreen::BitmapMode mode = (OplScreen::BitmapMode)(flags & 0xFF);
        if (mode == OplScreen::gray4 && isSibo()) {
            // On SIBO flags was actually a boolean for use grey plane, so mode=1 actually means monochromeWithGreyPlane
            mode = OplScreen::monochromeWithGreyPlane;
        }
        int shadow = 0;
        if ((flags & 0xF0) != 0) {
            shadow = 2 * ((flags & 0xF00) >> 8);
        }
        lua_pushinteger(L, mScreen->createWindow(drawableId, rect, mode, shadow));
        if (mInfoWinId) {
            // Keep info win on top
            mScreen->setOrder(mInfoWinId, 1);
        }

        return 1;
    });
}

int OplRuntime::createBitmap(lua_State* L)
{
    return call([this, L] {
        int drawableId = lua_tointeger(L, 1);
        QSize size(lua_tointeger(L, 2), lua_tointeger(L, 3));
        // Nothing except OPL likes zero-sized windows/bitmaps...
        if (size.width() == 0) {
            size.setWidth(1);
        }
        if (size.height() == 0) {
            size.setHeight(1);
        }
        OplScreen::BitmapMode mode = (OplScreen::BitmapMode)lua_tointeger(L, 4);
        lua_pushinteger(L, mScreen->createBitmap(drawableId, size, mode));
        return 1;
    });
}

void OplRuntime::pressMenuKey()
{
    keyEvent(QKeyEvent(QEvent::KeyPress, Qt::Key_F1, Qt::NoModifier));
    keyEvent(QKeyEvent(QEvent::KeyRelease, Qt::Key_F1, Qt::NoModifier));
}

void OplRuntime::pressDiamondKey()
{
    Q_ASSERT(isSiboDeviceType(mDeviceType));
    keyEvent(QKeyEvent(QEvent::KeyPress, Qt::Key_F2, Qt::NoModifier));
    keyEvent(QKeyEvent(QEvent::KeyRelease, Qt::Key_F2, Qt::NoModifier));
}

void OplRuntime::keyEvent(const QKeyEvent& event)
{
    // qDebug("keyEvent %d type=%d repeat=%d", event.key(), event.type(), event.isAutoRepeat());

    if (event.type() == QEvent::KeyRelease && event.isAutoRepeat()) {
        // Linux and Windows send:
        // Key press autorepeat=0
        // Key release autorepeat=1
        // Key press autorepeat=1
        // Key release autorepeat=1
        // ...
        // Key release autorepeat=0
        //
        // Whereas mac does what seems far more sensible and sends
        // Key press autorepeat=0
        // Key press autorepeat=1
        // Key press autorepeat=1
        // Key press autorepeat=1
        // ...
        // Key release autorepeat=0
        //
        // No idea why this isn't abstracted by Qt or why the platforms behave differently. We want something closer to
        // the mac model, so ignore any key releases where autorepeat is set.
        return;
    }
    int32_t oplcode = 0;
    opl::Modifiers modifiers = getOplModifiers(event.modifiers());
    if (event.text().size() == 1) {
        auto ch = event.text()[0].unicode();
        if (ch >= 0x20 && ch <= 0x7E && ch != 0x60) {
            // All the printable ascii block except backtick have the same codes in OPL
            oplcode = ch;
            if (ch >= 'A' && ch <= 'Z' && (modifiers & opl::shiftModifier) == 0) {
                // Presumably caps lock is set?
                modifiers |= opl::capsLockModifier;
            }
        }
    }
    if (!oplcode) {
        oplcode = qtKeyToOpl(event.key());
    }
    if (!oplcode) return;

    int32_t scan = isSibo() ? siboScancodeForKeycode(oplcode) : scancodeForKeycode(oplcode);
    // -1 means invalid, because in SIBO 0 is a valid scan code (for enter)
    if (scan < 0) {
        // Possible if eg the user presses a sibo-specific key on a non-sibo device
        return;
    }
    int32_t timestamp = (int32_t)((uint32_t)event.timestamp() * 1000);

    if (event.type() == QEvent::KeyPress) {
        if (!event.isAutoRepeat()) {
            // Calling addEvent({ ... }) as one statement crashes some GCC versions :(
            Event e = {
                .code = opl::keydown,
                .keyupdown = {
                    .timestamp = timestamp,
                    .scancode = scan,
                    .modifiers = (int32_t)modifiers,
                }
            };
            addEvent(e);
        }
        // If it doesn't have a charcode, we shouldn't generate a keypress for it
        if (charcodeForKeycode(oplcode)) {
            // CTRL-[shift-]letter have special codes
            int keypressCode;
            if ((modifiers & opl::controlModifier) && oplcode >= 'A' && oplcode <= 'Z') {
                keypressCode = oplcode - 'A' + 1;
            } else {
                keypressCode = oplcode;
            }
            Event e = {
                .code = keypressCode,
                .keypress = {
                    .timestamp = timestamp,
                    .scancode = scan,
                    .modifiers = (int32_t)modifiers,
                    .repeat = event.isAutoRepeat() ? 1 : 0
                }
            };
            addEvent(e);
        }
    } else if (event.type() == QEvent::KeyRelease) {
        Event e = {
            .code = opl::keyup,
            .keyupdown = {
                .timestamp = timestamp,
                .scancode = scan,
                .modifiers = (int32_t)modifiers,
            }
        };
        addEvent(e);
    }
}

void OplRuntime::mouseEvent(const QMouseEvent& event, int windowId)
{
    if (isSibo()) {
        return;
    }

#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    QPoint screenPos = event.globalPosition().toPoint();
#else
    QPoint screenPos = event.globalPos();
#endif

    int32_t timestamp = (int32_t)((uint32_t)event.timestamp() * 1000);
    opl::Modifiers modifiers = getOplModifiers(event.modifiers());
    if (event.type() == QEvent::MouseButtonPress) {
        Event e = {
            .code = opl::pen,
            .penevent = {
                .timestamp = timestamp,
                .windowId = windowId,
                .pointerType = opl::pointerDown,
                .modifiers = (int32_t)modifiers,
                .x = event.pos().x(),
                .y = event.pos().y(),
                .xscreen = screenPos.x(),
                .yscreen = screenPos.y(),
            },
        };
        addEvent(e);
    } else if (event.type() == QEvent::MouseButtonRelease) {
        Event e = {
            .code = opl::pen,
            .penevent = {
                .timestamp = timestamp,
                .windowId = windowId,
                .pointerType = opl::pointerUp,
                .modifiers = (int32_t)modifiers,
                .x = event.pos().x(),
                .y = event.pos().y(),
                .xscreen = screenPos.x(),
                .yscreen = screenPos.y(),
            },
        };
        addEvent(e);
    } else if (event.type() == QEvent::MouseMove) {
        Event e = {
            .code = opl::pen,
            .penevent = {
                .timestamp = timestamp,
                .windowId = windowId,
                .pointerType = opl::pointerDrag,
                .modifiers = (int32_t)modifiers,
                .x = event.pos().x(),
                .y = event.pos().y(),
                .xscreen = screenPos.x(),
                .yscreen = screenPos.y(),
            },
        };
        addEvent(e);
    }
}

void OplRuntime::focusEvent(bool focussed)
{
    Event e = {
        .code = focussed ? opl::foregrounded : opl::backgrounded,
        .focusevent = {
            .timestamp = 0, // No clue how to generate a compatible timestamp given we're using QInputEvent::timestamp elsewhere...
        },
    };
    addEvent(e);
}

void OplRuntime::closeEvent()
{
    Event e = {
        .code = opl::command,
        .pad = {},
    };
    mGetCmd = "X";
    addEvent(e);
}

void OplRuntime::addEvent(const OplRuntime::Event& event)
{
    if (!mThread) {
        // If we're not running anything, don't accumulate events
        return;
    }
    mMutex.lock();
    mEvents.append(event);
    if (checkEventRequest_locked()) {
        unlockAndSignalIfWaiting();
    } else {
        mMutex.unlock();
    }
}

// asyncRequest(requestName, requestTable)
// asyncRequest("getevent", { var = ..., ev = ... })
// asyncRequest("keya", { var = ..., k = ... })
// asyncRequest("after", { var = ..., period = ... })
// asyncRequest("at", { var = ..., time = ...})
// asyncRequest("playsound", { var = ..., data = ... })
int OplRuntime::asyncRequest(lua_State* L)
{
    lua_settop(L, 2);
    lua_pushvalue(L, 1);
    lua_setfield(L, 2, "type"); // requestTable.type = requestName
    lua_pushvalue(L, 2); // dup requestTable
    int requestHandle = luaL_ref(L, LUA_REGISTRYINDEX); // pop dup, registry[requestHandle] = requestTable

    lua_pushinteger(L, requestHandle);
    lua_setfield(L, 2, "ref"); // requestTable.ref = requestHandle

    lua_getfield(L, 2, "var"); // statusVar
    luaL_callmeta(L, -1, "uniqueKey");
    // qDebug("asyncRequest %s %s", lua_tostring(L, 1), lua_tostring(L, -1));

    lua_remove(L, -2); // remove the dup statusVar
    lua_pushvalue(L, 2); // dup requestTable
    lua_rawset(L, LUA_REGISTRYINDEX); // registry[statusVar:uniqueKey()] = requestTable

    QString requestName(lua_tostring(L, 1));
    if (requestName == "getevent" || requestName == "keya") {
        QMutexLocker lock(&mMutex);
        Q_ASSERT(mEventRequest == nullptr);
        AsyncHandle::Type type = (requestName == "getevent") ? AsyncHandle::getevent : AsyncHandle::keya;
        mEventRequest = new AsyncHandle(nullptr, requestHandle, type);
        mPendingRequests.insert(requestHandle, mEventRequest);
        checkEventRequest_locked();
    } else if (requestName == "after") {
        return call([this, L, requestHandle]() {
            int interval = to_int(L, 2, "period");
            if (interval < 0) {
                // TODO handle negative num for PAUSE
                interval = -interval;
            }
            // qDebug("asyncRequest after %d", interval);
            auto ev = new AsyncHandle(this, requestHandle, AsyncHandle::after);
            mMutex.lock();
            mPendingRequests.insert(requestHandle, ev);
            mMutex.unlock();
            QTimer::singleShot(interval, Qt::PreciseTimer, ev, [this, ev] {
                // qDebug("asyncRequest after finished");
                asyncFinished(ev, KErrNone);
            });
            return 0;
        });
    } else if (requestName == "playsound") {
        return call([this, L, requestHandle]() {
            auto data = to_bytearray(L, 2, "data");
            auto ev = new AsyncHandle(this, requestHandle, AsyncHandle::playsound);
            mMutex.lock();
            mPendingRequests.insert(requestHandle, ev);
            mMutex.unlock();
            mScreen->playSound(ev, data);
            return 0;
        });
    } else {
        return luaL_error(L, "TODO asyncRequest %s", lua_tostring(L, 1));
    }
    return 0;
}

int OplRuntime::cancelRequest(lua_State* L)
{
    return call([this, L]() {
        luaL_callmeta(L, -1, "uniqueKey");
        // qDebug("cancelRequest %s", lua_tostring(L, -1));
        int t = lua_gettable(L, LUA_REGISTRYINDEX); // 2: registry[statusVar:uniqueKey()] -> requestTable
        if (t == LUA_TNIL) {
            // Request must've already been completed by completeAnyRequest_locked
            // qDebug("cancelRequest: Already completed");
            return 0;
        } else {
            Q_ASSERT(t == LUA_TTABLE); // Unexpected type for registry requestTable
        }
        int ref = to_int(L, 2, "ref");
        mMutex.lock();
        AsyncHandle* h = mPendingRequests.value(ref, nullptr);
        if (h) {
            asyncFinished_locked(h, KErrIOCancelled);
            if (h == mEventRequest) {
                mEventRequest = nullptr;
            }
        }
        mMutex.unlock();
        delete h;
        return 0;
    });
}

void OplRuntime::unlockAndSignalIfWaiting()
{
    bool waitingForEvent = mWaiting;
    // clearing mWaiting indicates that a subsequent addEvent etc shouldn't re-signal mWaitSemaphore (until/unless it waits again)
    mWaiting = false;
    mMutex.unlock();
    if (waitingForEvent) {
        mWaitSemaphore.release();
    }
}

// Public fn, call from main thread (signals Lua thread). We make sure not to delete asyncHandle while locked, because
// that could have side-effects due to QObject parenting leading to deadlocks (Qt 5's QAudioOutput, looking at you).
void OplRuntime::asyncFinished(AsyncHandle* asyncHandle, int code)
{
    mMutex.lock();
    asyncFinished_locked(asyncHandle, code);
    unlockAndSignalIfWaiting();
    delete asyncHandle;
}

// Private fn, callable from any thread depending on the type of async event. Does not signal. Removes asyncHandle from
// mPendingRequests but does not delete it.
void OplRuntime::asyncFinished_locked(AsyncHandle* asyncHandle, int code)
{
    int ref = asyncHandle->ref();
    AsyncHandle* h = mPendingRequests.take(ref);
    Q_ASSERT(h);
    Q_ASSERT(h == asyncHandle);
    Completion completion = h->getCompletion(code);
    mPendingCompletions.append(completion);
}

// Must be locked on entry, unlocks when returning true
bool OplRuntime::completeAnyRequest_locked(lua_State *L)
{
    CHECK_STACK_BALANCED(L);

    if (mPendingCompletions.count()) {
        Completion c = mPendingCompletions.takeFirst();
        mMutex.unlock();
        int t = lua_rawgeti(L, LUA_REGISTRYINDEX, c.ref);
        Q_ASSERT(t == LUA_TTABLE);

        if (c.code == KErrNone && (c.type == AsyncHandle::getevent || c.type == AsyncHandle::keya)) {
            lua_getfield(L, -1, "ev"); // Pushes eventArray (as an Addr)
            t = luaL_getmetafield(L, -1, "write"); // Addr:write
            Q_ASSERT(t == LUA_TFUNCTION);
            lua_insert(L, -2); // put write below eventArray
            pushValue(L, c.data);
            lua_call(L, 2, 0);
        } else {
            // There aren't (currently) any other async event types that have completion data, nor is there ever a
            // situation where an erroring event should be writing data.
            Q_ASSERT(c.data.isEmpty());
        }

        lua_getfield(L, -1, "var"); // statusVar
        lua_pushinteger(L, c.code);
        lua_call(L, 1, 0);

        // Finally, free up requestHandle
        lua_getfield(L, -1, "var");
        luaL_callmeta(L, -1, "uniqueKey");
        // qDebug("Completed request %s", lua_tostring(L, -1));
        lua_pushnil(L);
        lua_settable(L, LUA_REGISTRYINDEX); // registry[statusVar:uniqueKey()] = nil
        lua_pop(L, 1); // var
        lua_getfield(L, -1, "ref");
        int ref = lua_tointeger(L, -1);
        luaL_unref(L, LUA_REGISTRYINDEX, ref); // registry[requestHandle] = nil
        lua_pop(L, 1); // ref

        // And if the caller specified a custom completion fn, call that once everything else has been done
        if (lua_getfield(L, -1, "completion") == LUA_TFUNCTION) {
            lua_call(L, 0, 0);
        } else {
            lua_pop(L, 1);
        }

        lua_pop(L, 1); // requestTable
        return true;
    }
    return false;
}

bool OplRuntime::checkEventRequest_locked()
{
    if (!mEventRequest) {
        return false;
    }

    bool foundEvent = false;

    if (mEventRequest->type() == AsyncHandle::getevent) {
        if (mEvents.count()) {
            auto event = mEvents.takeFirst();
            mEventRequest->setCompletionData(event);
            asyncFinished_locked(mEventRequest, KErrNone);
            foundEvent = true;
        }
    } else if (mEventRequest->type() == AsyncHandle::keya) {
        while (mEvents.count() && !foundEvent) {
            auto event = mEvents.takeFirst();
            if (event.isKeyEvent()) {
                int16_t data[2];
                data[0] = (int16_t)charcodeForKeycode(event.code);
                data[1] = (int16_t)event.keypress.modifiers | (event.keypress.repeat ? 0x100 : 0);
                mEventRequest->setCompletionData(data);
                asyncFinished_locked(mEventRequest, KErrNone);
                foundEvent = true;
            }
        }
    } else {
        Q_ASSERT(false);
    }

    if (foundEvent) {
        delete mEventRequest;
        mEventRequest = nullptr;
    }

    return foundEvent;
}

int OplRuntime::waitForAnyRequest(lua_State* L)
{
    // qDebug("+waitForAnyRequest");
    while (true) {
        mMutex.lock();
        if (mInterrupted) {
            mMutex.unlock();
            lua_pushinteger(L, KStopErr);
            return lua_error(L);
        }
        mWaiting = false;
        if (completeAnyRequest_locked(L)) {
            lua_pushboolean(L, true);
            // qDebug("-waitForAnyRequest");
            return 1;
        } else {
            // still locked
            mWaiting = true;
            mMutex.unlock();
            // Wait for something else to happen
            // qDebug("waitForAnyRequest waiting for signal...");
            mWaitSemaphore.acquire();
            // qDebug("waitForAnyRequest got signal from mainthread");
        }
    }
}

int OplRuntime::testEvent(lua_State *L)
{
    mMutex.lock();
    bool gotEvents = !mEvents.isEmpty();
    mMutex.unlock();
    lua_pushboolean(L, gotEvents);
    return 1;
}

int OplRuntime::checkCompletions(lua_State *L)
{
    int result = 0;
    mMutex.lock();
    while (true) {
        bool found = completeAnyRequest_locked(L);
        if (found) {
            result++;
            mMutex.lock();
            // And go round again
        } else {
            break;
        }
    }
    mMutex.unlock();
    lua_pushinteger(L, result);
    return 1;
}

int OplRuntime::getTime(lua_State *L)
{
    qint64 now = QDateTime::currentMSecsSinceEpoch();
    lua_pushnumber(L, (double)now / 1000.0);
    return 1;
}

int OplRuntime::utctime(lua_State *L)
{
    // Really annoying Lua can't/won't use timegm...
    tm ts {};
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_settop(L, 1); /* make sure table is at the top */
    ts.tm_sec = to_int(L, -1, "sec");
    ts.tm_min = to_int(L, -1, "min");
    ts.tm_hour = to_int(L, -1, "hour");
    int day = to_int(L, -1, "day");
    int mon = to_int(L, -1, "month");
    int year = to_int(L, -1, "year");
    if (!day || !mon || !year) {
        lua_pushnil(L);
        lua_pushstring(L, "missing field!");
        return 2;
    }
    ts.tm_mday = day;
    ts.tm_mon = mon - 1;
    ts.tm_year = year - 1900;
    time_t t = timegm(&ts);
    if (t == -1) {
        lua_pushnil(L);
        lua_pushstring(L, "time result cannot be represented");
        return 2;
    }
    lua_pushinteger(L, t);
    return 1;
}

int OplRuntime::setEra(lua_State *L)
{
    QString era(lua_tostring(L, 1));
    bool eraIsSibo = era == "sibo";
    if (eraIsSibo) {
        mStringCodec = QTextCodec::codecForName("IBM 850"); // Is this the right name...?
    } else {
        mStringCodec = QTextCodec::codecForName("Windows-1252");
    }

    if (eraIsSibo != isSibo() && !mIgnoreOpoEra) {
        setDeviceType(eraIsSibo ? Series3c : Series5);
    }
    return 0;
}

int OplRuntime::getConfig(lua_State *L)
{
    pushValue(L, mConfig.value(lua_tostring(L, 1)));
    return 1;
}

int OplRuntime::setConfig(lua_State *L)
{
    QString k = lua_tostring(L, 1);
    QString v = lua_tostring(L, 2);
    qDebug("setConfig %s %s", qPrintable(k), qPrintable(v));
    mConfig[k] = v;
    if (k == "clockFormat") {
        bool digital = v == "1";
        emit systemClockChanged(digital);
    }
    return 0;
}

void OplRuntime::setSpeed(OplRuntime::Speed speed)
{
    QMutexLocker locker(&mMutex);
    if (speed != mSpeed) {
        mSpeed = speed;
        locker.unlock();
        emit speedChanged();
    }
}

OplRuntime::Speed OplRuntime::getSpeed() const
{
    QMutexLocker locker(&mMutex);
    return (Speed)mSpeed;
}

void OplRuntime::runFaster()
{
    QMutexLocker locker(&mMutex);
    if (mSpeed != Fastest) {
        mSpeed++;
        locker.unlock();
        emit speedChanged();
    }
}

void OplRuntime::runSlower()
{
    QMutexLocker locker(&mMutex);
    if (mSpeed != Slowest) {
        mSpeed--;
        locker.unlock();
        emit speedChanged();
    }
}

const int64_t kOpTime = 3500; // in nanoseconds
const int64_t kSiboMultiplier = 10;

int OplRuntime::opsync(lua_State *)
{
    auto speed = getSpeed();
    auto optime = kOpTime * (isSibo() ? kSiboMultiplier : 1);
    if (speed != Fastest) {
        auto elapsed = mLastOpTime.nsecsElapsed();
        if (elapsed < optime) {
            struct timespec t;
            t.tv_sec = 0;
            t.tv_nsec = optime - elapsed;
            nanosleep(&t, NULL);
        }
        mLastOpTime.start();
    }
    return 0;
}

constexpr int64_t kDelayPerPixel = 100; // In nanoseconds. Total guess.
void OplRuntime::didWritePixels(int numPixels)
{
    // qDebug("didWritePixels(%d)", numPixels);
    QMutexLocker lock(&mMutex);
    int64_t delay_ns = (9 - mSpeed) * numPixels * kDelayPerPixel * (isSibo() ? kSiboMultiplier : 1);
    lock.unlock();

    struct timespec t;
    t.tv_sec = 0;
    t.tv_nsec = delay_ns;
    nanosleep(&t, NULL);
}

int OplRuntime::system(lua_State *L)
{
    return call([this, L] {
        QString cmd(lua_tostring(L, 1));
        if (cmd == "setAppTitle") {
            auto name = tolocalstring(L, 2);
            emit titleChanged(name);
        } else if (cmd == "displayTaskList" || cmd == "runApp" || cmd == "setBackground" || cmd == "setForeground") {
            // Ignore these
        } else if (cmd == "escape") {
            setEscape(lua_toboolean(L, 2));
        } else if (cmd == "getCmd") {
            pushValue(L, mGetCmd);
            bool isCloseEvent = mGetCmd == "X";
            mGetCmd.clear();
            if (isCloseEvent) {
                emit closeEventProcessed();
            }
            return 1;
        } else {
            qDebug("Bad args to system!");
        }
        return 0;
    });
}

int OplRuntime::textEditor(lua_State *)
{
    return 0;
}

QString OplRuntime::getFont(uint32_t uid, OplScreen::FontMetrics& metrics)
{
    auto uidStr = QString::number(uid, 16).toUpper();
    QString fontPath = QString(":/fonts/%1/%1.json").arg(uidStr);
    QFile f(fontPath);
    if (!f.open(QFile::ReadOnly)) {
        return QString();
    }
    auto manifest = QJsonDocument::fromJson(f.readAll());
    f.close();

    metrics.height = manifest["charh"].toInt();
    metrics.ascent = manifest["ascent"].toInt();
    metrics.descent = manifest["descent"].toInt();
    metrics.maxwidth = manifest["maxwidth"].toInt();
    for (int i = 0; i < 256; i++) {
        metrics.widths[i] = manifest["widths"][i].toInt();
    }

    return QString(":/fonts/%1/%1.png").arg(uidStr);
}

int OplRuntime::printHandler(lua_State* L)
{
    size_t l = 0;
    auto s = lua_tolstring(L, 1, &l);
    fwrite(s, 1, l, stdout);
    emit debugLog(QString::fromLatin1(s, l));
    return 0;
}

void OplRuntime::drawCursor()
{
    if (mCursorDrawCmd.has_value()) {
        mScreen->beginBatchDraw();
        mScreen->draw(*mCursorDrawCmd);
        mScreen->endBatchDraw();
        mCursorDrawn = !mCursorDrawn;
    }
}
