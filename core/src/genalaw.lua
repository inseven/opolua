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

-- From https://en.wikipedia.org/wiki/G.711#A-law
function alaw(val)
    local ix = val ~ (0x0055) -- re-toggle toggled bits

    ix = ix & 0x007F -- remove sign bit
    local iexp = ix >> 4 -- extract exponent
    local mant = ix & 0x000F -- now get mantissa
    if iexp > 0 then
        mant = mant + 16 -- add leading '1', if exponent > 0
    end

    mant = (mant << 4) + (0x0008) -- now mantissa left justified and 1/2 quantization step added
    if iexp > 1 then -- now left shift according exponent
        mant = mant << (iexp - 1)
    end

    return val > 127 and mant or -mant -- invert, if negative sample
end

function printf(fmt, ...)
    io.stdout:write(string.format(fmt, ...))
end

printf("local alawDecompress = {\n")
for j = 0, 32 do
    printf("    ")
    for i = 0, 7 do
        if i > 0 then
            printf(" ")
        end
        printf("%d,", alaw(j*8 + i))
    end
    printf("\n")
end
printf("}\n")
