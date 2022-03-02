local acc = 0
x = 1
for i = 1, 10000000 do
    if ~x then
        acc = acc + 1
    end
end

y = setmetatable({}, { __bnot = function() return false end })
for i = 1, 10000000 do
    if ~y then
        acc = acc + 1
    end
end
