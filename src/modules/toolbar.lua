_ENV = module()

local KTbWidth = 70
local KTbBtTop = 24
local KTbBtH = 37
local KTbClockSize = 70
local KTbNumButtons = 4
local KTbNumComps = 6
-- local KTbMarginX = 0
local KTbFont = KFontSquashed
local KTbTitleFont = KFontArialNormal11

local tbWinId
local visibleVar -- global vars

function TBarLink(runtime, appLink)
    local tbWidthVar = runtime:declareGlobal("TbWidth%")
    tbWidthVar(KTbWidth)
    visibleVar = runtime:declareGlobal("TbVis%")
    visibleVar(0)
    runtime:callProc(appLink:upper())
end

function TBarInit(runtime, title, screenWidth, screenHeight)
    local w = KTbWidth
    local h = screenHeight
    tbWinId = gCREATE(screenWidth - w, 0, w, h, false)
    gBOX(w, h)
    gAT(w // 2, h - w // 2)
    gCIRCLE(w // 2 - 4)
    TBarSetTitle(runtime, title)
end

function TBarSetTitle(runtime, name)
    local prevId = gIDENTITY()
    gUSE(tbWinId)
    gAT(1, KTbBtTop - 8)
    gFONT(KTbTitleFont)
    local align = Align.Center
    if gTWIDTH(name) > KTbWidth - 2 then
        align = Align.Left
    end
    gPRINTB(name, KTbWidth - 2, align, 6, 6)
    gUSE(prevId)
end

function TBarButt(runtime, shortcut, pos, text, state, bit, mask, flags)
    local prevId = gIDENTITY()
    gUSE(tbWinId)
    gFONT(KFontSquashed)
    gAT(0, KTbBtTop + (pos - 1) * KTbBtH)
    gBUTTON(text, 1, KTbWidth, KTbBtH)
    gUSE(prevId)
end

_ENV["TBarOffer%"] = function(runtime, winId, ptrType, ptrX, ptrY)
    --TODO
end

function TBarLatch(runtime, comp)
    --TODO
end

function TBarShow(runtime)
    gVISIBLE(tbWinId, true)
    visibleVar(-1)
end

function TBarHide(runtime)
    gVISIBLE(tbWinId, false)
    visibleVar(0)
end

return _ENV
