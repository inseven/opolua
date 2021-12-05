_ENV = module()

local tbTitle, screenWidth, screenHeight, tbWinId
local tbWidth, tbVis -- global vars

function TBarLink(runtime, appLink)
    tbWidth = runtime:declareGlobal("TbWidth%")
    tbWidth(70)
    tbVis = runtime:declareGlobal("TbVis%")
    tbVis(0)
    runtime:callProc(appLink:upper())
end

function TBarInit(runtime, title, scrW, scrH)
    tbTitle = title
    screenWidth = scrW
    screenHeight = scrH
    local w = tbWidth()
    local h = screenHeight
    tbWinId = gCREATE(screenWidth - w, 0, w, h, false)
    gBOX(w, h)
    gAT(w // 2, h - w // 2)
    gCIRCLE(w // 2 - 4)
end

function TBarSetTitle(runtime, name)
    tbTitle = name
end

function TBarButt(runtime, shortcut, pos, text, state, bit, mask, flags)
    --TODO
end

_ENV["TBarOffer%"] = function(runtime, winId, ptrType, ptrX, ptrY)
    --TODO
end

function TBarLatch(runtime, comp)
    --TODO
end

function TBarShow(runtime)
    gVISIBLE(tbWinId, true)
    tbVis(-1)
end

function TBarHide(runtime)
    gVISIBLE(tbWinId, false)
    tbVis(0)
end

return _ENV
