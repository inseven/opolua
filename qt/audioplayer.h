// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include <QtGlobal>
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
#include <QAudioSink>
#else
#include <QAudioOutput>
#endif
#include <QByteArray>

class AsyncHandle;

class AudioPlayer : public QObject
{
    Q_OBJECT

public:
    AudioPlayer(QObject* parent=nullptr);
    void playSound(AsyncHandle* handle, const QByteArray& data);

private slots:
    void audioStateChanged(QAudio::State state);
    void audioHandleDeleted();

private:
    AsyncHandle* mAudioAsync;
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    QAudioSink* mAudio;
#else
    QAudioOutput* mAudio;
#endif
    QByteArray mAudioData;
};
