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
    tbWinId = runtime:iohandler().createWindow(screenWidth - w, 0, w, h, 0)
    runtime:newGraphicsContext(tbWinId, w, h, true)
    runtime:drawCmd("box", { width = w, height = h })
    runtime:getGraphics().current.pos = { x = w // 2, y = h - w // 2 }
    runtime:drawCmd("circle", { r = w // 2 - 4 })
end

function TBarSetTitle(runtime, name)
    tbTitle = name
end

function TBarButt(runtime, shortcut, pos, text, state, bit, mask, flags)
    --TODO
end

function TBarOffer(runtime, winId, ptrType, ptrX, ptrY)
    --TODO
end

function TBarLatch(runtime, comp)
    --TODO
end

function TBarShow(runtime)
    runtime:iohandler().graphicsop("show", tbWinId, true)
end

function TBarHide(runtime)
    runtime:iohandler().graphicsop("show", tbWinId, false)
end

return {
    TBarLink = TBarLink,
    TBarInit = TBarInit,
    TBarSetTitle = TBarSetTitle,
    TBarButt = TBarButt,
    ["TBarOffer%"] = TBarOffer,
    TBarLatch = TBarLatch,
    TBarShow = TBarShow,
    TBarHide = TBarHide,
}
