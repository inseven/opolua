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

#ifndef OPLRUNTIME_H
#define OPLRUNTIME_H

#include <QDir>
#include <QElapsedTimer>
#include <QKeyEvent>
#include <QMutex>
#include <QObject>
#include <QScopedPointer>
#include <QSemaphore>
#include <QSet>
#include <QTextCodec>
#include <QThread>
#include <QVector>
#include <functional>
#include <optional>

#include "oplscreen.h"
#include "opldebug.h"

#include "opldevicetype.h"
typedef OplDeviceType DeviceType;

class FileSystemIoHandler;
struct lua_State;
class AsyncHandle;
struct Completion;
class MainThreadEvent;

#define DECLARE_IOHANDLER_FN(fn) \
    static int fn ## _s(lua_State* L) { \
        return getSelf(L)->fn(L); \
    } \
    int fn(lua_State* L)

#define IOHANDLER_FN(fn) { #fn, fn ## _s }

enum class Drive : char {
    C = 'C',
    D = 'D',
    M = 'M',
};

class OplRuntime : public QObject, public OplFontProvider
{
    Q_OBJECT

public:
    enum Speed {
        Slowest = 1,
        Slower = 2,
        Slow = 3,
        Tardy = 4,
        DefaultSpeed = 5,
        Snappy = 6,
        Fast = 7,
        Faster = 8,
        Fastest = 9,
    };

    explicit OplRuntime(QObject *parent = nullptr);
    ~OplRuntime();
    void setScreen(OplScreen* screen) { mScreen = screen; }
    QSize screenSize() const;
    bool running() const;
    QString lastLauncherCommand() const { return mLauncherCmd; }
    QString runningLauncherCommand() const { return running() ? mLauncherCmd : QString(); }
    bool writableCDrive() const;
    void setDeviceType(DeviceType type);
    void setIgnoreOpoEra(bool flag);
    DeviceType getDeviceType() const;
    bool isSibo() const;
    static QString deviceTypeToString(DeviceType type);
    static DeviceType toDeviceType(const QString& device);
    static bool isSiboDeviceType(DeviceType type);

    Speed getSpeed() const;
    void setSpeed(Speed speed);

    void setDrive(Drive drive, const QString& path);
    void removeAllDrives();
    QString getNativePath(const QString& devicePath) const;

    void run(const QString& devicePath);
    void run(const QDir& cDrive, const QString& devicePath); // convenience
    void runOpo(const QString& path); // convenience, sets up dummy C drive
    void runInstaller(const QString& file, const QString& displayPath);
    void runLauncher();
    void runAppSelector();

    void keyEvent(const QKeyEvent& event);
    void mouseEvent(const QMouseEvent& event, int windowId);
    void focusEvent(bool focussed);

    void asyncFinished(AsyncHandle* handle, int code);

    void interruptAndRun(std::function<void(void)> runNextFn);

    static void configureLuaResourceSearcher(lua_State *L);
    static int dofile(lua_State *L);

    QString getFont(uint32_t uid, OplScreen::FontMetrics& metrics) override;

public: // Debugging APIs

    bool isPaused() const;
    
    bool breakOnError() const;
    void setBreakOnError(bool flag);

    bool ignoreFocusEvents() const;
    void setIgnoreFocusEvents(bool flag);

    opl::ProgramInfo getDebugInfo();
    void debugSetVariable(const opl::Variable& variable, const QString& value);

    void addBreakpoint(const QString& moduleNativePath, uint32_t addr);
    void removeBreakpoint(const QString& moduleNativePath, uint32_t addr);

    static QString varToStr(const opl::Variable& v, int idx = -1);

    typedef std::pair<uint32_t, QString> Line;
    QVector<Line> decompile(const QString& path);

protected:
    bool event(QEvent* ev) override;

public slots:
    void interrupt();
    void restart();
    void pressMenuKey();
    void pressDiamondKey();
    void runFaster();
    void runSlower();
    void closeEvent();

public slots: // Debugging-related slots
    void printDebugInfo();
    void updateDebugInfoIfStale();
    void pause();
    void unpause();
    void stepIn();
    void stepOut();
    void singleStep();

signals:
    void startedRunning(const QString& path);
    void pauseStateChanged(bool paused);
    void titleChanged(const QString& title);
    void runComplete(const QString& errMsg, const QString& errDetail);
    void installationComplete(const QString& sisPath);
    void systemClockChanged(bool digital);
    void escapeStateChanged(bool on);
    void speedChanged();
    void debugLog(const QString& str);
    void closeEventProcessed();
    void deviceTypeChanged();
    void debugInfoUpdated();

private slots:
    void onThreadExited();
    void drawCursor();
    void updateDebugInfoOnRunComplete();

private:
    struct Event {
        int32_t code;
        union {
            struct {
                int32_t timestamp;
                int32_t scancode;
                uint32_t modifiers; // Modifiers
                int32_t repeat;
            } keypress;
            struct {
                int32_t timestamp;
                int32_t scancode;
                uint32_t modifiers; // Modifiers
            } keyupdown;
            struct {
                int32_t timestamp;
                int32_t windowId;
                int32_t pointerType;
                uint32_t modifiers; // TEventModifiers NOT Modifiers
                int32_t x;
                int32_t y;
                int32_t xscreen;
                int32_t yscreen;
            } penevent;
            struct {
                int32_t timestamp;
                int32_t windowId;
            } pencontact;
            struct {
                int32_t timestamp;
            } focusevent;
            int32_t pad[15];
        };

        bool isKeyEvent() const;
    };

    void pushRunParams(const QString& devicePath);
    void pushIohandler();
    void startThread();
    static void threadFn(OplRuntime* self);
    int call(std::function<int(void)> fn);
    void didWritePixels(int numPixels);

    void addEvent(const Event& event);
    bool checkEventRequest_locked();
    void unlockAndSignalIfWaiting();
    bool completeAnyRequest_locked(lua_State *L);
    void asyncFinished_locked(AsyncHandle* asyncHandle, int code);

    static OplRuntime* getSelf(lua_State *L);
    QString tolocalstring(lua_State *L, int index);
    void setEscape(bool flag);
    void doRunInstaller(const QString& file, const QString& displayPath, const QString& lang);
    bool debugInfoStale() const;
    void updateDebugInfo(lua_State* L, bool errOnStack = false);

    DECLARE_IOHANDLER_FN(asyncRequest);
    DECLARE_IOHANDLER_FN(cancelRequest);
    DECLARE_IOHANDLER_FN(checkCompletions);
    DECLARE_IOHANDLER_FN(createBitmap);
    DECLARE_IOHANDLER_FN(createWindow);
    DECLARE_IOHANDLER_FN(draw);
    DECLARE_IOHANDLER_FN(debugEvent);
    DECLARE_IOHANDLER_FN(getConfig);
    DECLARE_IOHANDLER_FN(getDeviceInfo);
    DECLARE_IOHANDLER_FN(getTime);
    DECLARE_IOHANDLER_FN(graphicsop);
    DECLARE_IOHANDLER_FN(keysDown);
    DECLARE_IOHANDLER_FN(opsync);
    DECLARE_IOHANDLER_FN(setConfig);
    DECLARE_IOHANDLER_FN(setEra);
    DECLARE_IOHANDLER_FN(system);
    DECLARE_IOHANDLER_FN(testEvent);
    DECLARE_IOHANDLER_FN(textEditor);
    DECLARE_IOHANDLER_FN(utctime);
    DECLARE_IOHANDLER_FN(waitForAnyRequest);

    // Not actually part of iohandler, but behaves similarly
    DECLARE_IOHANDLER_FN(printHandler);
    DECLARE_IOHANDLER_FN(runOpoHelper);

protected:
    lua_State* L;
    QScopedPointer<FileSystemIoHandler> mFs;
    QString mDeviceOpoPath; // Of the current executable (or empty if running a custom launcher)
private:
    QThread* mThread;
    mutable QMutex mMutex;
    DeviceType mDeviceType;
    bool mIgnoreOpoEra;
    QString mLauncherCmd;
    QTextCodec* mStringCodec;
    OplScreen* mScreen;
    int mRet;
    //// BEGIN protected by mMutex
    MainThreadEvent* mCallEvent;
    QVector<Event> mEvents;
    AsyncHandle* mEventRequest;
    bool mWaiting;
    bool mInterrupted;
    bool mPaused;
    bool mDebugging;
    bool mBreakOnErr;
    enum {
        None,
        NextReturn,
        NextOp,
        NextPushFrame
    } mBreakOnNext;
    uint8_t mSpeed;
    QMap<int, AsyncHandle*> mPendingRequests;
    QVector<Completion> mPendingCompletions;
    QSet<int> mKeysDown; // set of scancodes, used for SIBO HwGetScanCodes only
    opl::ProgramInfo mDebugInfo;

    //// END protected by mMutex
    QElapsedTimer mLastOpTime;
    QElapsedTimer mLastDebugInfoTime;
    int mRuntimeRef;
    std::function<void(void)> mRunNextFn;
    QSemaphore mWaitSemaphore;

    int mInfoWinId;
    QScopedPointer<QTimer> mInfoWinHideTimer;

    int mBusyWinId;
    QScopedPointer<QTimer> mBusyWinShowTimer;

    std::optional<OplScreen::DrawCmd> mCursorDrawCmd;
    QScopedPointer<QTimer> mCursorTimer;
    bool mCursorDrawn;

    QMap<QString, QString> mConfig;
    QString mGetCmd;

    bool mEscapeOn;
    bool mIgnoreFocusEvents;
};

#endif // OPLRUNTIME_H
