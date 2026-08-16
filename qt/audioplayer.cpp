// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "audioplayer.h"
#include "asynchandle.h"
#include "opldefs.h"

#include <QAudioFormat>
#include <QBuffer>

AudioPlayer::AudioPlayer(QObject* parent)
    : QObject(parent)
    , mAudioAsync(nullptr)
    , mAudio(nullptr)
{
}

void AudioPlayer::playSound(AsyncHandle* handle, const QByteArray& data)
{
    Q_ASSERT(mAudioAsync == nullptr);
    mAudioAsync = handle;
    connect(mAudioAsync, &QObject::destroyed, this, &AudioPlayer::audioHandleDeleted);
    mAudioData = data;
    // qDebug("playSound len=%d", (int)data.size());
    Q_ASSERT((data.size() & 1) == 0); // must be 16-bit

    // We keep mAudio around after completing playing a sound so we can reuse it quickly, because there can be some
    // tangible delay involved in setting up a new audio playback object, so reusing it makes sense given we always
    // use the same audio format.
    if (!mAudio) {
        QAudioFormat format;
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
        format.setChannelConfig(QAudioFormat::ChannelConfigMono);
        format.setSampleRate(48000); // See comment below
        format.setSampleFormat(QAudioFormat::Int16);
        mAudio = new QAudioSink(format, this);
        connect(mAudio, &QAudioSink::stateChanged, this, &AudioPlayer::audioStateChanged);
#else
        format.setChannelCount(1);
        format.setSampleRate(8000);
        format.setSampleSize(16);
        format.setCodec("audio/pcm");
        format.setByteOrder(QAudioFormat::LittleEndian);
        format.setSampleType(QAudioFormat::SignedInt);
        mAudio = new QAudioOutput(format, this);
        connect(mAudio, &QAudioOutput::stateChanged, this, &AudioPlayer::audioStateChanged);
#endif
    }
    // mAudio->setVolume(0.5); // Full volume is too much

#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    // Qt 6 (on mac at least?) seems to only support sample rates from 44.1kHz up, which is absolutely bonkers. So
    // we will say 48kHz and manually stretch our sample data out by a factor of 6 (since our input data is always
    // 8kHz). When doing that, we have to also do some interpolation to the next sample so that it doesn't sound
    // square-wave-y. This is not perfect (not sure what the optimal thing to do is) but it sounds a lot better
    // than not doing any interpolation at all.
    QByteArray newData(mAudioData.size() * 6, Qt::Uninitialized);
    auto iptr = reinterpret_cast<const int16_t*>(mAudioData.cbegin());
    auto eptr = reinterpret_cast<const int16_t*>(mAudioData.cend());
    auto optr = reinterpret_cast<int16_t*>(newData.data());
    while (iptr != eptr) {
        auto val = *iptr++;
        int16_t delta = 0;
        if (iptr != eptr) {
            delta = (*iptr - val) / 5;
        }
        *optr++ = val; val += delta;
        *optr++ = val; val += delta;
        *optr++ = val; val += delta;
        *optr++ = val; val += delta;
        *optr++ = val; val += delta;
        *optr++ = val;
    }
    newData.swap(mAudioData);
#endif

    QBuffer* buf = new QBuffer(&mAudioData, handle);
    buf->open(QIODevice::ReadOnly);
    mAudio->start(buf);
    // qDebug("audio started state=%d err=%d", mAudio->state(), mAudio->error());
    if (mAudio->error() != QAudio::NoError) {
        qDebug("audio failed to start err=%d", mAudio->error());
        if (mAudioAsync) {
            mAudioAsync->finished(KErrGenFail);
        }
    }
}

void AudioPlayer::audioStateChanged(QAudio::State state)
{
    if (!mAudio) {
        return;
    }

    // qDebug("audioStateChanged %d", (int)state);

    // Calling asyncFinished will delete mAudioAsync which will call audioHandleDeleted via the QObject::destroyed signal
    switch (state) {
    case QAudio::ActiveState:
        break;
    case QAudio::IdleState:
        // Finished playing (no more data). Note, on Qt 5 calling stop triggers an immediate callback to
        // audioStateChanged which can be problematic, eg causing deadlocks.
        mAudio->stop();
        break;
    case QAudio::StoppedState: {
        int err = KErrNone;
        if (mAudio->error() != QAudio::NoError) {
            qDebug("Audio error %d", (int)mAudio->error());
            err = KErrGenFail;
        }

        if (mAudioAsync) {
            mAudioAsync->finished(err);
            mAudioAsync = nullptr;
        }
        break;
    }
    default:
        qDebug("Unhandled audioStateChanged %d", (int)state);
        break;
    }
}

void AudioPlayer::audioHandleDeleted()
{
    mAudioAsync = nullptr; // Will prevent audioStateChanged trying to make another asyncFinished call as a result of the stop
    if (mAudio->state() == QAudio::ActiveState) {
        mAudio->stop();
    }
    mAudioData.clear();
}

