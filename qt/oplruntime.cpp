// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "oplruntime.h"

#include "filesystem.h"
#include "luasupport.h"
#include "oplkeycode.h"
#include "asynchandle.h"

#include <QCoreApplication>
#include <QColor>
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

#ifdef QT_NO_DEBUG

#define CHECK_STACK_BALANCED(L)
#define CHECK_STACK_ON_RETURN(L, diff)

#else

class StackChecker
{
public:
    StackChecker(lua_State* L, int top) : L(L), top(top) {}
    ~StackChecker() {
        Q_ASSERT_X(lua_gettop(L) == top, "StackChecker", "Stack top not correct on function exit"); 
    }

private:
    lua_State *L;
    int top;
};

#define CHECK_STACK_BALANCED(L) StackChecker _stackcheck_ ## __FUNCTION__(L, lua_gettop(L))
#define CHECK_STACK_ON_RETURN(L, diff) StackChecker _stackcheck_ ## __FUNCTION__(L, lua_gettop(L) diff)

#endif // QT_NO_DEBUG

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

bool OplRuntime::Event::isKeyEvent() const
{
    return (code & 0x400) == 0;
}

OplRuntime::OplRuntime(QObject *parent)
    : QObject(parent)
    , mThread(nullptr)
    , mDeviceType(Series5)
    , mPendingEventRequestType(AsyncEventRequestType::none)
    , mPendingEventRequestRef(LUA_NOREF)
    , mWaiting(false)
    , mInterrupted(false)
    , mInfoWinId(0)
    , mInfoWinHideTimer(nullptr)
    , mCursorTimer(nullptr)
{
    mFs = new FileSystemIoHandler();
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

QSize OplRuntime::screenSize() const
{
    switch (mDeviceType) {
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
        // Some compilers need this...
        Q_ASSERT(false);
        return QSize();
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
    delete mFs;
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
        // We shouldn't be getting eg raw numbers-as-leave-codes being thrown here

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

void OplRuntime::interrupt()
{
    interruptAndRun(nullptr);
}

void OplRuntime::interruptAndRun(std::function<void(void)> runNextFn)
{
    if (!running()) {
        if (runNextFn) {
            runNextFn();
        }
        return;
    }
    mRunNextFn = runNextFn;
    lua_sethook(L, stop, LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE | LUA_MASKCOUNT, 1);
    mMutex.lock();
    mInterrupted = true;
    unlockAndSignalIfWaiting();
}

void OplRuntime::restart()
{
    Q_ASSERT(!mDeviceOpoPath.isEmpty());

    auto fn = [this]() {
        lua_settop(L, 0);
        require(L, "runtime");
        lua_getfield(L, -1, "runOpo");
        lua_remove(L, -2); // runtime
        pushValue(L, mDeviceOpoPath);
        lua_pushnil(L);
        pushIohandler();
        emit startedRunning(mFs->getNativePath(mDeviceOpoPath));
        startThread();
    };

    if (running()) {
        interruptAndRun(fn);
        // will result in fn() being re-called from onThreadExited
    } else {
        fn();
    }
}

int OplRuntime::getDeviceInfo(lua_State* L)
{
    auto sz = screenSize();
    lua_pushinteger(L, sz.width());
    lua_pushinteger(L, sz.height());
    switch (mDeviceType) {
    case Series3c:
        lua_pushinteger(L, KColorgCreate4GrayMode);
        lua_pushstring(L, "psion-series-3c");
        break;
    case Series5:
        lua_pushinteger(L, KColorgCreate16GrayMode);
        lua_pushstring(L, "psion-series-5");
        break;
    case Revo:
        lua_pushinteger(L, KColorgCreate16GrayMode);
        lua_pushstring(L, "psion-revo");
        break;
    case Series7:
        lua_pushinteger(L, KColorgCreate256ColorMode);
        lua_pushstring(L, "psion-series-7");
        break;
    case GeofoxOne:
        lua_pushinteger(L, KColorgCreate256ColorMode);
        lua_pushstring(L, "geofox-one");
        break;
    }
    return 4;
}

bool OplRuntime::running() const
{
    return mThread != nullptr;
}

bool OplRuntime::writableCDrive() const
{
    return mFs->writableCDrive();
}

void OplRuntime::run(const QDir& cDrive, const QString& devicePath)
{
    mFs->addMapping('C', cDrive, !cDrive.absolutePath().startsWith(":"));
    run(devicePath);
}

void OplRuntime::run(const QString& devicePath)
{
    lua_settop(L, 0);
    pushRunParams(devicePath);
    startThread();
}

void OplRuntime::pushRunParams(const QString& devicePath)
{
    mDeviceOpoPath = devicePath;
    require(L, "runtime");
    lua_getfield(L, -1, "runOpo");
    lua_remove(L, -2); // runtime
    pushValue(L, devicePath);
    lua_pushnil(L); // procName
    pushIohandler();
}

void OplRuntime::pushIohandler()
{
    mFs->makeFsIoHandlerBridge(L);

    luaL_Reg funcs[] = {
        IOHANDLER_FN(asyncRequest),
        IOHANDLER_FN(beep),
        IOHANDLER_FN(cancelRequest),
        IOHANDLER_FN(createBitmap),
        IOHANDLER_FN(createWindow),
        IOHANDLER_FN(displayTaskList),
        IOHANDLER_FN(draw),
        IOHANDLER_FN(getConfig),
        IOHANDLER_FN(getDeviceInfo),
        IOHANDLER_FN(getTime),
        IOHANDLER_FN(graphicsop),
        IOHANDLER_FN(opsync),
        IOHANDLER_FN(runApp),
        IOHANDLER_FN(setAppTitle),
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

void OplRuntime::startThread()
{
    // The stack of L is now set up for threadFn to use

    Q_ASSERT(mThread == nullptr);
    mThread = QThread::create(threadFn, this);
    mThread->setParent(this);
    connect(mThread, &QThread::finished, this, &OplRuntime::onThreadExited);

    mThread->start();
    // L is now owned by mThread

    emit canRestart(!mDeviceOpoPath.isEmpty());
    emit startedRunning(mFs->getNativePath(mDeviceOpoPath));
}

void OplRuntime::runOpo(const QString& path)
{
    lua_settop(L, 0);

    mFs->addSimulatedDrive('C', {path});
    mDeviceOpoPath = QString("C:\\") + QFileInfo(path).fileName();

    require(L, "runtime");
    lua_getfield(L, -1, "runOpo");
    lua_remove(L, -2); // runtime
    pushValue(L, mDeviceOpoPath);
    lua_pushnil(L); // procName
    pushIohandler();
    emit startedRunning(path);
    startThread();
}

// This fn overwrites the filesystem mappings
void OplRuntime::runInstaller(const QString& file, const QString& displayPath)
{
    Q_ASSERT(mThread == nullptr);
    mLauncherCmd = "installSis";
    mFs->addSimulatedDrive('I', {file});
    lua_settop(L, 0);
    require(L, "runtime");
    lua_getfield(L, -1, "runlauncherCmd");
    lua_remove(L, -2); // runtime
    pushIohandler();
    pushValue(L, mLauncherCmd);
    pushValue(L, file);
    pushValue(L, QString("I:\\" + QFileInfo(file).fileName()));
    pushValue(L, displayPath);
    mThreadContinuation = [this]() -> bool {
        mThreadContinuation = nullptr;
        mFs->removeMapping('I');
        if (lua_type(L, -1) != LUA_TTABLE) {
            return false;
        }
        auto launch = to_string(L, -1, "launch");
        if (!launch.isEmpty()) {
            lua_settop(L, 1);
            pushRunParams(launch);
            return true;
        } else {
            return false;
        }
    };
    emit canRestart(false);
    emit startedRunning(QString());
    startThread();
}

void OplRuntime::runLauncher()
{
    Q_ASSERT(mThread == nullptr);
    mLauncherCmd = "launcher";
    mFs->addSimulatedDrive('C', {":/welcome/c/System/Apps/Welcome/icons_color.mbm"});
    lua_settop(L, 0);
    require(L, "runtime");
    lua_getfield(L, -1, "runlauncherCmd");
    lua_remove(L, -2); // runtime
    pushIohandler();
    pushValue(L, mLauncherCmd);
    pushValue(L, QSysInfo::productType());

    mThreadContinuation = [this]() -> bool {
        mThreadContinuation = nullptr;
        return false; // TODO
    };
    emit canRestart(false);
    emit startedRunning(QString());
    startThread();
}

void OplRuntime::threadFn(OplRuntime* self)
{
    auto L = self->L;
    lua_pushcfunction(L, traceHandler);
    lua_insert(L, 1);

    bool shouldContinue;
    do {
        shouldContinue = false;
        // stack should now be:
        // 1: traceHandler
        // 2: function to call
        // 3-top: arguments
        Q_ASSERT(lua_type(L, 1) == LUA_TFUNCTION);
        Q_ASSERT(lua_type(L, 2) == LUA_TFUNCTION);
        self->mRet = lua_pcall(L, lua_gettop(L) - 2, 1, 1);
        if (self->mRet == 0) {
            if (self->mThreadContinuation) {
                shouldContinue = self->mThreadContinuation();
            } else {
                lua_pop(L, 1); // result only relevant for things like runInstaller which sets a continuation
            }
        }
    } while (shouldContinue);
    lua_sethook(L, nullptr, 0, 0); // in case of interrupt()
}

void OplRuntime::onThreadExited()
{
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
    lua_settop(L, 0);
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
    mPendingEventRequestType = AsyncEventRequestType::none;
    mPendingEventRequestRef = LUA_NOREF;

    delete mCursorTimer;
    mCursorTimer = nullptr;

    delete mInfoWinHideTimer;
    mInfoWinHideTimer = nullptr;

    // qDebug() << "runComplete msg=" << errmsg;
    qDebug("Runtime exited with: %s", qPrintable(errdetail));

    mLauncherCmd.clear();

    auto fn = mRunNextFn;
    if (fn) {
        mRunNextFn = nullptr;
        fn();
        return;
    }

    mDeviceOpoPath.clear();
    emit canRestart(false);
    emit runComplete(errmsg, errdetail);
}

class MainThreadEvent : public QEvent {
public:
    MainThreadEvent() : QEvent(QEvent::User) {}
};

int OplRuntime::call(std::function<int(void)> fn)
{
    // Calls fn on the main thread, then blocks until the main thread calls the function
    // qDebug("+call");
    mCallFn = fn;
    QCoreApplication::postEvent(this, new MainThreadEvent());
    mCallSemaphore.acquire();
    // qDebug("-call");
    return mRet;
}

bool OplRuntime::event(QEvent* ev)
{
    if (ev->type() == QEvent::User) {
        auto fn = std::move(mCallFn);
        mCallFn = nullptr;
        mRet = fn();
        mCallSemaphore.release(); // signals mThread blocked in call()
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
    } else if (cmd == "loadfont") {
        return call([this, L] {
            int drawableId = lua_tointeger(L, 2);
            uint32_t uid = (uint32_t)lua_tointeger(L, 3);
            auto uidStr = QString::number(uid, 16).toUpper();
            QString fontPath = QString(":/fonts/%1/%1.json").arg(uidStr);
            // qDebug("loadFont %08X -> %s", uid, qPrintable(fontPath));
            QFile f(fontPath);
            if (!f.open(QFile::ReadOnly)) {
                lua_pushnil(L);
                lua_pushinteger(L, KErrInvalidArgs);
                return 2;
            }
            auto manifest = QJsonDocument::fromJson(f.readAll());
            f.close();

            int err = mScreen->loadPng(drawableId, QString(":/fonts/%1/%1.png").arg(uidStr));
            if (err) {
                lua_pushnil(L);
                lua_pushinteger(L, err);
                return 2;
            } else {
                lua_newtable(L);
                SET_INT(L, "height", manifest["charh"].toInt());
                SET_INT(L, "ascent", manifest["ascent"].toInt());
                SET_INT(L, "descent", manifest["descent"].toInt());
                SET_INT(L, "maxwidth", manifest["maxwidth"].toInt());
                lua_createtable(L, 256, 0);
                for (int i = 0; i < 256; i++) {
                    lua_pushinteger(L, manifest["widths"][i].toInt());
                    lua_rawseti(L, -2, i + 1);
                }
                lua_setfield(L, -2, "widths");
                return 1;
            }
        });
    } else if (cmd == "giprint") {
        return call([this, L] {
            int drawableId = lua_tointeger(L, 2);
            if (drawableId == 0) {
                if (mInfoWinId) {
                    mScreen->showWindow(mInfoWinId, false);
                }
                return 0;
            }

            mInfoWinId = drawableId;
            mScreen->showWindow(mInfoWinId, true);
            delete mInfoWinHideTimer;
            mInfoWinHideTimer = new QTimer(this);
            connect(mInfoWinHideTimer, &QTimer::timeout, this, &OplRuntime::hideInfoWindow);
            mInfoWinHideTimer->setSingleShot(true);
            mInfoWinHideTimer->setTimerType(Qt::PreciseTimer);
            mInfoWinHideTimer->start(2000);
            return 0;
        });
    } else if (cmd == "cursor") {
        return call([this, L] {
            delete mCursorTimer;
            mCursorTimer = nullptr;
            mCursorDrawCmd.clear();
            if (lua_type(L, 2) == LUA_TTABLE) {
                int flags = to_int(L, 2, "flags");
                constexpr int KCursorTypeNotFlashing = 2;
                constexpr int KCursorTypeGrey = 4;
                // The grey cursor color doesn't really work with the invert drawing mode, never mind.
                rawgetfield(L, 2, "rect");
                mCursorDrawCmd.append({
                    .type = OplScreen::fill,
                    .drawableId = to_int(L, 2, "id"),
                    .mode = OplScreen::invert,
                    .origin = QPoint(to_int(L, 3, "x"), to_int(L, 3, "y")),
                    .color = (flags & KCursorTypeGrey) ? 0xFF888888 : 0xFF000000,
                    .bgcolor = 0xFFFFFFFF, // doesn't really matter
                    .penWidth = 1,
                    .fill = {
                        .size = QSize(to_int(L, 3, "w"), to_int(L, 3, "h")),
                    },
                });
                mScreen->drawCommands(mCursorDrawCmd);
                if ((flags & KCursorTypeNotFlashing) == 0) {
                    mCursorTimer = new QTimer(this);
                    connect(mCursorTimer, &QTimer::timeout, this, &OplRuntime::drawCursor);
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
                    .mode = to_int(L, 3, "mode"),
                    .pos = QPoint(to_int(L, 4, "x"), to_int(L, 4, "y")),
                };
                mScreen->clock(drawableId, &info);
            } else {
                mScreen->clock(drawableId, nullptr);
            }
            return 0;
        });
    } else {
        qWarning("Unhandled graphicsop %s", qPrintable(cmd));
        return 0;
    }
}

static QRgb to_rgb(lua_State* L, int idx, const char* name)
{
    rawgetfield(L, idx, name);
    QColor col(to_int(L, -1, "r"), to_int(L, -1, "g"), to_int(L, -1, "b"));
    lua_pop(L, 1);
    return col.rgb();
}

int OplRuntime::draw(lua_State* L)
{
    // qDebug("draw top=%d", lua_gettop(L));
    return call([this, L] {
        QVector<OplScreen::DrawCmd> cmds;
        auto flushCommands = [this, &cmds] {
            if (!cmds.isEmpty()) {
                mScreen->drawCommands(cmds);
                cmds.clear();
            }
        };
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
                .shutUpCompiler = 0,
            };
            if (cmd.penWidth == 0) cmd.penWidth = 1;
            QString type = to_string(L, 2, "type");
            if (type == "fill") {
                cmd.type = OplScreen::fill;
                cmd.fill.size = QSize(to_int(L, 2, "width"), to_int(L, 2, "height"));
            } else if (type == "line") {
                cmd.type = OplScreen::line;
                cmd.line.endPoint = QPoint(to_int(L, 2, "x2"), to_int(L, 2, "y2"));
            } else if (type == "circle") {
                cmd.type = OplScreen::circle;
                cmd.circle.radius = to_int(L, 2, "r");
                cmd.circle.fill = to_bool(L, 2, "fill");
            } else if (type == "box") {
                cmd.type = OplScreen::box;
                cmd.box.size = QSize(to_int(L, 2, "width"), to_int(L, 2, "height"));
            } else if (type == "mcopy") {
                // It's a draw cmd Lua-side, but because it can't fit in a OplScreen::DrawCmd it's a graphicsOp in the
                // Qt implementation. So we have to flush any queued draw commands first.
                flushCommands();
                int srcId = to_int(L, 2, "srcid");
                int destId = cmd.drawableId;
                QVector<QRect> rects;
                QVector<QPoint> points;
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
                    rects.append(QRect(lua_tointeger(L, -6), lua_tointeger(L, -5), lua_tointeger(L, -4), lua_tointeger(L, -3)));
                    points.append(QPoint(lua_tointeger(L, -2), lua_tointeger(L, -1)));
                    lua_pop(L, 6);
                }
                bool invert = cmd.mode == OplScreen::invert;
                mScreen->copyMultiple(srcId, destId, cmd.bgcolor, invert, rects, points);
                lua_pop(L, 1); // cmd
                continue;
            } else if (type == "bitblt") {
                flushCommands();
                rawgetfield(L, 2, "bitmap");
                auto mode = (OplScreen::BitmapMode)to_int(L, -1, "mode");
                int width = to_int(L, -1, "width");
                int height = to_int(L, -1, "height");
                int stride = to_int(L, -1, "stride");
                auto data = to_bytearray(L, -1, "imgData");
                lua_pop(L, 1); // bitmap

                mScreen->bitBlt(cmd.drawableId, mode, width, height, stride, data);
                lua_pop(L, 1); // cmd;
                continue;
            } else if (type == "scroll") {
                cmd.type = OplScreen::scroll;
                cmd.scroll.dx = to_int(L, 2, "dx");
                cmd.scroll.dy = to_int(L, 2, "dy");
                rawgetfield(L, 2, "rect");
                cmd.scroll.rect = QRect(to_int(L, -1, "x"), to_int(L, -1, "y"), to_int(L, -1, "w"), to_int(L, -1, "h"));
                lua_pop(L, 1);
            } else if (type == "border") {
                cmd.type = OplScreen::border;
                cmd.border.borderType = (OplScreen::BorderType)to_int(L, 2, "btype");
                cmd.border.rect = QRect(cmd.origin.x(), cmd.origin.y(), to_int(L, 2, "width"), to_int(L, 2, "height"));
            } else if (type == "copy") {
                cmd.type = OplScreen::copy;
                cmd.copy.srcDrawableId = to_int(L, 2, "srcid");
                cmd.copy.srcRect = QRect(to_int(L, 2, "srcx"), to_int(L, 2, "srcy"), to_int(L, 2, "width"), to_int(L, 2, "height"));
            } else {
                qWarning("Unhandled draw cmd %s", qPrintable(type));
                lua_pop(L, 1); // cmd
                continue;
            }
            cmds.push_back(cmd);
            lua_pop(L, 1); // cmd
        }
        mScreen->drawCommands(cmds);
        return 0;
    });
}

void OplRuntime::drawCursor()
{
    mScreen->drawCommands(mCursorDrawCmd);
}

int OplRuntime::createWindow(lua_State* L)
{
    return call([this, L] {
        int drawableId = lua_tointeger(L, 1);
        QRect rect(lua_tointeger(L, 2), lua_tointeger(L, 3), lua_tointeger(L, 4), lua_tointeger(L, 5));
        // Nothing except OPL likes zero-sized windows/bitmaps...
        if (rect.width() == 0) {
            rect.setWidth(1);
        }
        if (rect.height() == 0) {
            rect.setHeight(1);
        }
        int flags = lua_tointeger(L, 6);
        OplScreen::BitmapMode mode = (OplScreen::BitmapMode)(flags & 0xFF);
        int shadow = 0;
        if ((flags & 0xF0) != 0) {
            shadow = 2 * ((flags & 0xF00) >> 8);
        }
        lua_pushinteger(L, mScreen->createWindow(drawableId, rect, mode, shadow));
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

    int32_t scan = scancodeForKeycode(oplcode);
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
            // CTRL-letter have special codes
            int keypressCode;
            if (modifiers == opl::controlModifier && oplcode >= 'A' && oplcode <= 'Z') {
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

void OplRuntime::mouseEvent(const QMouseEvent& event, int windowId, const QPoint& screenPos)
{
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
                .x = event.x(),
                .y = event.y(),
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
                .x = event.x(),
                .y = event.y(),
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
                .x = event.x(),
                .y = event.y(),
                .xscreen = screenPos.x(),
                .yscreen = screenPos.y(),
            },
        };
        addEvent(e);
    }
}

void OplRuntime::addEvent(const OplRuntime::Event& event)
{
    if (!mThread) {
        // If we're not running anything, don't accumulate events
        return;
    }
    mMutex.lock();
    mEvents.append(event);
    unlockAndSignalIfWaiting();
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
    lua_remove(L, -2); // remove the dup statusVar
    lua_pushvalue(L, 2); // dup requestTable
    lua_rawset(L, LUA_REGISTRYINDEX); // registry[statusVar:uniqueKey()] = requestTable

    QString requestName(lua_tostring(L, 1));
    if (requestName == "getevent") {
        QMutexLocker lock(&mMutex);
        Q_ASSERT(mPendingEventRequestType == AsyncEventRequestType::none);
        mPendingEventRequestType = AsyncEventRequestType::getevent;
        mPendingEventRequestRef = requestHandle;
    } else if (requestName == "keya") {
        QMutexLocker lock(&mMutex);
        Q_ASSERT(mPendingEventRequestType == AsyncEventRequestType::none);
        mPendingEventRequestType = AsyncEventRequestType::keya;
        mPendingEventRequestRef = requestHandle;
    } else if (requestName == "after") {
        return call([this, L, requestHandle]() {
            int interval = to_int(L, 2, "period");
            if (interval < 0) {
                // TODO handle negative num for PAUSE
                interval = -interval;
            }
            auto ev = new AsyncHandle(this, requestHandle);
            mMutex.lock();
            mPendingRequests.insert(requestHandle, ev);
            mMutex.unlock();
            QTimer::singleShot(interval, Qt::PreciseTimer, ev, [this, ev] {
                asyncFinished(ev, KErrNone);
            });
            return 0;
        });
    } else if (requestName == "playsound") {
        return call([this, L, requestHandle]() {
            auto data = to_bytearray(L, 2, "data");
            auto ev = new AsyncHandle(this, requestHandle);
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

    luaL_callmeta(L, -1, "uniqueKey");
    int t = lua_gettable(L, LUA_REGISTRYINDEX); // 2: registry[statusVar:uniqueKey()] -> requestTable
    if (t == LUA_TNIL) {
        // Request must've already been completed by doCompleteRequest
        return 0;
    } else {
        Q_ASSERT(t == LUA_TTABLE); // Unexpected type for registry requestTable
    }
    int ref = to_int(L, 2, "ref");
    mMutex.lock();
    AsyncHandle* h = mPendingRequests.take(ref);
    if (h) {
        delete h; // Cancels any timer (or at least prevents its callback)
    } else if (ref == mPendingEventRequestRef) {
        mPendingEventRequestType = AsyncEventRequestType::none;
        mPendingEventRequestRef = LUA_NOREF;
    } else {
        qWarning("Unknown request being cancelled!");
    }
    mMutex.unlock();
    doCompleteRequest(L, KErrIOCancelled);
    return 0;
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

void OplRuntime::asyncFinished(AsyncHandle* asyncHandle, int code)
{
    mMutex.lock();
    int ref = asyncHandle->ref();
    AsyncHandle* h = mPendingRequests.take(ref);
    Q_ASSERT(h);
    Q_ASSERT(h == asyncHandle);
    delete h;
    mPendingCompletions.append({.ref = ref, .code = code});
    unlockAndSignalIfWaiting();
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
        doCompleteRequest(L, c.code);
        return true;
    }

    if (mPendingEventRequestType == AsyncEventRequestType::getevent && mEvents.count()) {
        auto event = mEvents.takeFirst();
        int ref = mPendingEventRequestRef;
        mPendingEventRequestRef = LUA_NOREF;
        mPendingEventRequestType = AsyncEventRequestType::none;
        mMutex.unlock();
        writeEventCompletion(L, ref, event, AsyncEventRequestType::getevent);
        doCompleteRequest(L, KErrNone);
        return true;
    } else if (mPendingEventRequestType == AsyncEventRequestType::keya) {
        while (mEvents.count()) {
            auto event = mEvents.takeFirst();
            if (event.isKeyEvent()) {
                int ref = mPendingEventRequestRef;
                mPendingEventRequestRef = LUA_NOREF;
                mPendingEventRequestType = AsyncEventRequestType::none;
                mMutex.unlock();
                writeEventCompletion(L, ref, event, AsyncEventRequestType::keya);
                doCompleteRequest(L, KErrNone);
                return true;
            } else {
                // Drop event, look for next
            }
        }
    }
    return false;
}

void OplRuntime::doCompleteRequest(lua_State* L, int code)
{
    // requestTable expected to be on top of stack

    CHECK_STACK_ON_RETURN(L, -1); // pops requestTable

    // Assumes request table is already on top of stack
    lua_getfield(L, -1, "var"); // statusVar
    lua_pushinteger(L, code);
    lua_call(L, 1, 0);

    // Finally, free up requestHandle
    lua_getfield(L, -1, "var");
    luaL_callmeta(L, -1, "uniqueKey");
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
}

void OplRuntime::writeEventCompletion(lua_State* L, int ref, const OplRuntime::Event& event, AsyncEventRequestType type)
{
    CHECK_STACK_ON_RETURN(L, +1); // pushes requestTable

    int t = lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
    Q_ASSERT(t == LUA_TTABLE);

    lua_getfield(L, -1, "ev"); // Pushes eventArray (as an Addr)
    luaL_getmetafield(L, -1, "write"); // Addr:write
    lua_insert(L, -2); // put write below eventArray
    if (type == AsyncEventRequestType::getevent) {
        lua_pushlstring(L, reinterpret_cast<const char*>(&event), sizeof(event)); // ev
    } else {
        Q_ASSERT(type == AsyncEventRequestType::keya);
        Q_ASSERT(event.isKeyEvent());
        int32_t data[2] = {
            charcodeForKeycode(event.code),
            event.keypress.modifiers | (event.keypress.repeat ? 0x100 : 0)
        };
        lua_pushlstring(L, reinterpret_cast<const char*>(data), sizeof(data));
    }
    lua_call(L, 2, 0);
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

void OplRuntime::hideInfoWindow()
{
    // qDebug("OplRuntime::hideInfoWindow");
    delete mInfoWinHideTimer;
    mInfoWinHideTimer = nullptr;
    mScreen->showWindow(mInfoWinId, false);
}

int OplRuntime::setAppTitle(lua_State *L)
{
    return call([this, L] {
        auto name = tolocalstring(L, 1);
        emit titleChanged(name);
        return 0;
    });
}

int OplRuntime::beep(lua_State *L)
{
    double freq = lua_tonumber(L, 1);
    double duration = lua_tonumber(L, 2);
    qDebug("TODO beep %gkHz %gs", freq, duration);
    lua_pushboolean(L, true);
    return 1;
}

int OplRuntime::setEra(lua_State *L)
{
    QString era(lua_tostring(L, 1));
    if (era == "sibo") {
        mStringCodec = QTextCodec::codecForName("IBM 850"); // Is this the right name...?
    } else {
        mStringCodec = QTextCodec::codecForName("Windows-1252");
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
    return 0;
}

int OplRuntime::opsync(lua_State *)
{
    return 0;
}

int OplRuntime::displayTaskList(lua_State *)
{
    return 0;
}

int OplRuntime::textEditor(lua_State *)
{
    return 0;
}

int OplRuntime::runApp(lua_State *)
{
    return 0;
}
