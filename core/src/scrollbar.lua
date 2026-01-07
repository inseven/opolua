--[[

Copyright (c) 2021-2025 Jason Morley, Tom Sutcliffe

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

]]

_ENV = module()

local kChoiceUpArrow = "," -- in KFontEiksym15
local kChoiceDownArrow = "-" -- in KFontEiksym15

Scrollbar = class {}

function Scrollbar:draw()
    local state = runtime:saveGraphicsState()
    local x, y, w, h = self.x, self.y, self.w, self.h
    local widgetHeight = self:widgetHeight()
    gAT(x, y)

    local barOffset = self:barOffset()
    local barAreaHeight = self:barAreaHeight()
    -- printf("x=%d y=%d widgetHeight=%d, barOffset=%d\n", x, y, widgetHeight, barOffset)
    if barOffset > 0 then
        gFILL(w, barOffset, KgModeClear)
        gMOVE(0, barOffset)
    end
    gFILL(w, widgetHeight, KgModeClear)
    gBUTTON("", KButtS5, w, widgetHeight, self.tracking and KButtS5SemiPressed or KButtS5Raised)
    if barOffset + widgetHeight < barAreaHeight then
        gAT(x, y + barOffset + widgetHeight)
        gFILL(w, barAreaHeight - (barOffset + widgetHeight), KgModeClear)
    end

    local kStripeGap = 5
    -- Make sure we don't draw any more strips than fill half the widgetHeight
    local numStripes = math.min(10, (widgetHeight // 2) // kStripeGap)
    local stripeWidth = w // 2
    gAT(x + (w // 4) + 1, y + barOffset + (widgetHeight // 2) - ((numStripes * kStripeGap) // 2))
    for i = 1, numStripes do
        white()
        gLINEBY(stripeWidth, 0)
        gMOVE(-stripeWidth, 1)
        black()
        gLINEBY(stripeWidth, 0)
        gMOVE(-stripeWidth, kStripeGap - 1)
    end

    -- Draw up and down arrows
    black()
    gFONT(KFontEiksym15)
    gAT(x, y + barAreaHeight)
    gBUTTON(kChoiceUpArrow, KButtS5, w, w, 0)
    gMOVE(0, w - 1) -- -1 because the buttons overlap by a pixel so the border between them isn't so heavy
    gBUTTON(kChoiceDownArrow, KButtS5, w, w, 0)
    runtime:restoreGraphicsState(state)
end

function Scrollbar:setContentOffset(offset)
    -- printf("setContentOffset(%d)\n", offset)
    self.contentOffset = math.min(math.max(offset, 0), self:maxContentOffset())
end

function Scrollbar:setContentHeight(h)
    self.contentHeight = h
end

function Scrollbar:handlePointerEvent(x, y, type)
    -- printf("Scrollbar:handlePointerEvent(%d, %d, %d)\n", x, y, type)
    local widgetHeight = self:widgetHeight()
    local barOffset = self:barOffset()
    local barAreaHeight = self:barAreaHeight()
    local yoffset = y - self.y
    local barDelta = 0
    if self.tracking then
        if type == KEvPtrPenUp then
            self.tracking = nil
            self:draw()
            return
        else
            barDelta = y - self.tracking
            self.tracking = y
        end
    elseif yoffset < barOffset then
        -- Scroll up a page
        if type == KEvPtrPenDown then
            barDelta = -widgetHeight
        end
    elseif yoffset < barOffset + widgetHeight then
        -- Start dragging on the scroll widget
        if type == KEvPtrPenDown then
            self.tracking = y
            self:draw() -- To get the pressed effect
        end
    elseif yoffset < barAreaHeight then
        -- Scroll down a page
        if type == KEvPtrPenDown then
            barDelta = widgetHeight
        end
    elseif yoffset < barAreaHeight + self.w then
        -- Up arrow
        if type == KEvPtrPenDown and self.observer then
            self.observer:scrollbarDidScroll(-1)
        end
    elseif yoffset < barAreaHeight + 2 * self.w then
        -- Down arrow
        if type == KEvPtrPenDown and self.observer then
            self.observer:scrollbarDidScroll(1)
        end
    end

    if barDelta ~= 0 then
        local contentDelta = (barDelta * self.contentHeight) // barAreaHeight
        -- printf("barDelta = %d contentDelta = %d\n", barDelta, contentDelta)
        self:setContentOffset(self.contentOffset + contentDelta)
        if self.observer then
            self.observer:scrollbarContentOffsetChanged(self)
        end
    end
end

function Scrollbar:maxContentOffset()
    return self.contentHeight - self.visibleContentHeight
end

function Scrollbar:barOffset()
    local scrollFraction = self.contentOffset / self:maxContentOffset()
    return math.floor((self:barAreaHeight() - self:widgetHeight()) * scrollFraction)
end

-- The space the scrollbar can move in, total height minus the size of the buttons
function Scrollbar:barAreaHeight()
    local buttonsSize = (self.w * 2) - 1 -- The buttons share a common pixel
    return self.h - buttonsSize
end

function Scrollbar:widgetHeight()
    return math.floor((self:barAreaHeight()) * (self.visibleContentHeight / self.contentHeight))
end

function Scrollbar.newVertical(x, y, h, visibleContentHeight, contentHeight)
    local w = 23
    local barAreaHeight = h - (w * 2)
    local scrollbar = Scrollbar {
        x = x,
        y = y,
        w = w,
        h = h,
        visibleContentHeight = visibleContentHeight,
        contentHeight = contentHeight,
        contentOffset = 0,
    }

    return scrollbar
end

return _ENV
