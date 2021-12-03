_ENV = module()

function TBarLink(runtime, appLink)
    runtime:callProc(appLink:upper())
end

function TBarInit(runtime, title, scrW, scrH)
    --TODO
end

function TBarSetTitle(runtime, name)
    --TODO
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
    --TODO
end

function TBarHide(runtime)
    --TODO
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
