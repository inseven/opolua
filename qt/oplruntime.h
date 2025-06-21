// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef OPLRUNTIME_H
#define OPLRUNTIME_H

#include <QDir>
#include <QKeyEvent>
#include <QMutex>
#include <QObject>
#include <QSemaphore>
#include <QTextCodec>
#include <QThread>
#include <QVector>
#include <functional>

#include "oplscreen.h"

class FileSystemIoHandler;
struct lua_State;
class AsyncHandle;

#define DECLARE_IOHANDLER_FN(fn) \
    static int fn ## _s(lua_State* L) { \
        return getSelf(L)->fn(L); \
    } \
    int fn(lua_State* L)

#define IOHANDLER_FN(fn) { #fn, fn ## _s }

enum class Drive : char {
    C = 'C',
    D = 'D',
};

class OplRuntime : public QObject
{
    Q_OBJECT

public:
    enum DeviceType {
        Series3c,
        Series5,
        Revo,
        Series7,
        GeofoxOne,
    };

    explicit OplRuntime(QObject *parent = nullptr);
    ~OplRuntime();
    void setScreen(OplScreen* screen) { mScreen = screen; }
    QSize screenSize() const;
    bool running() const;
    QString runningLauncherCommand() const { return mLauncherCmd; }
    bool writableCDrive() const;
    void setDeviceType(DeviceType type);

    void setDrive(Drive drive, const QString& path);
    void removeAllDrives();

    void run(const QString& devicePath);
    void run(const QDir& cDrive, const QString& devicePath); // convenience
    void runOpo(const QString& path); // convenience, sets up dummy C drive
    void runInstaller(const QString& file, const QString& displayPath);
    void runLauncher();

    void keyEvent(const QKeyEvent& event);
    void mouseEvent(const QMouseEvent& event, int windowId, const QPoint& screenPos);

    void asyncFinished(AsyncHandle* handle, int code);

    void interruptAndRun(std::function<void(void)> runNextFn);

    static void configureLuaResourceSearcher(lua_State *L);
    static int dofile(lua_State *L);

protected:
    bool event(QEvent* ev) override;

public slots:
    void interrupt();
    void restart();
    void pressMenuKey();

signals:
    void startedRunning(const QString& path);
    void titleChanged(const QString& title);
    void runComplete(const QString& errMsg, const QString& errDetail);
    void canRestart(bool flag);

private slots:
    void onThreadExited();
    void hideInfoWindow();
    void drawCursor();

private:
    struct Event {
        int32_t code;
        union {
            struct {
                int32_t timestamp;
                int32_t scancode;
                int32_t modifiers; // Modifiers
                int32_t repeat;
            } keypress;
            struct {
                int32_t timestamp;
                int32_t scancode;
                int32_t modifiers; // Modifiers
            } keyupdown;
            struct {
                int32_t timestamp;
                int32_t windowId;
                int32_t pointerType;
                int32_t modifiers; // TEventModifiers NOT Modifiers
                int32_t x;
                int32_t y;
                int32_t xscreen;
                int32_t yscreen;
            } penevent;
            int32_t pad[15];
        };

        bool isKeyEvent() const;
    };

    struct Completion {
        int ref;
        int code;
    };

    void pushRunParams(const QString& devicePath);
    void pushIohandler();
    void startThread();
    static void threadFn(OplRuntime* self);
    int call(std::function<int(void)> fn);

    void addEvent(const Event& event);
    void unlockAndSignalIfWaiting();
    bool completeAnyRequest_locked(lua_State *L);
    void doCompleteRequest(lua_State* L, int code);
    enum class AsyncEventRequestType {
        none = 0,
        getevent,
        keya,
    };
    void writeEventCompletion(lua_State* L, int ref, const OplRuntime::Event& event, AsyncEventRequestType type);

    static OplRuntime* getSelf(lua_State *L);
    QString tolocalstring(lua_State *L, int index);

    DECLARE_IOHANDLER_FN(asyncRequest);
    DECLARE_IOHANDLER_FN(beep);
    DECLARE_IOHANDLER_FN(cancelRequest);
    DECLARE_IOHANDLER_FN(createBitmap);
    DECLARE_IOHANDLER_FN(createWindow);
    DECLARE_IOHANDLER_FN(displayTaskList);
    DECLARE_IOHANDLER_FN(draw);
    DECLARE_IOHANDLER_FN(getConfig);
    DECLARE_IOHANDLER_FN(getDeviceInfo);
    DECLARE_IOHANDLER_FN(getTime);
    DECLARE_IOHANDLER_FN(graphicsop);
    DECLARE_IOHANDLER_FN(opsync);
    DECLARE_IOHANDLER_FN(runApp);
    DECLARE_IOHANDLER_FN(setAppTitle);
    DECLARE_IOHANDLER_FN(setConfig);
    DECLARE_IOHANDLER_FN(setEra);
    DECLARE_IOHANDLER_FN(testEvent);
    DECLARE_IOHANDLER_FN(textEditor);
    DECLARE_IOHANDLER_FN(utctime);
    DECLARE_IOHANDLER_FN(waitForAnyRequest);

private:
    QThread* mThread;
    std::function<bool(void)> mThreadContinuation;
    QMutex mMutex;
    lua_State* L;
    DeviceType mDeviceType;
    QString mDeviceOpoPath; // Of the current executable (or empty if running a custom launcher)
    QString mLauncherCmd;
    QTextCodec* mStringCodec;
    FileSystemIoHandler* mFs;
    OplScreen* mScreen;
    int mRet;
    QSemaphore mCallSemaphore;
    std::function<int(void)> mCallFn;
    QVector<Event> mEvents;
    AsyncEventRequestType mPendingEventRequestType;
    int mPendingEventRequestRef;
    bool mWaiting;
    bool mInterrupted;
    std::function<void(void)> mRunNextFn;
    QSemaphore mWaitSemaphore;
    QMap<int, AsyncHandle*> mPendingRequests;
    QVector<Completion> mPendingCompletions;

    int mInfoWinId;
    QTimer* mInfoWinHideTimer;

    QVector<OplScreen::DrawCmd> mCursorDrawCmd;
    QTimer* mCursorTimer;

    QMap<QString, QString> mConfig;
};

#endif // OPLRUNTIME_H
