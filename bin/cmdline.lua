-- Indirect to the real cmdline.lua

local realPath = arg[0]:match("^(.-)[a-z]+%.lua$")..string.gsub("../src/cmdline.lua", "/", package.config:sub(1, 1))
loadfile(realPath, "t")("../src/")
