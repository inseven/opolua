#ifndef OPLRUNTIMEGUI_H
#define OPLRUNTIMEGUI_H

#include <QByteArray>
#include <QIcon>
#include <QPixmap>

#include "oplruntime.h"

class OplRuntimeGui : public OplRuntime
{
    Q_OBJECT

public:
    explicit OplRuntimeGui(QObject *parent = nullptr);

    static QPixmap imageFromBitmap(lua_State* L, int index);
    static QPixmap imageFromBitmap(OplScreen::BitmapMode mode, int width, int height, int stride, const QByteArray& data);
    QIcon iconForAif(const QString& devicePath);

};

#endif // OPLRUNTIMEGUI_H
