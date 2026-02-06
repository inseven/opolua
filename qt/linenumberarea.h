// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef LINENUMBERAREA_H
#define LINENUMBERAREA_H

#include <QWidget>
class CodeView;

class LineNumberArea : public QWidget
{
    Q_OBJECT
public:
    explicit LineNumberArea(CodeView *parent = nullptr);

    QSize sizeHint() const override;

protected:
    void paintEvent(QPaintEvent* event) override;

private:
    CodeView* mCodeView;
};

#endif // LINENUMBERAREA_H
