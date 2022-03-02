local acc = 0
x = 1
for i = 1, 10000000 do
    if type(x) == "number" then
        acc = acc + 1
    end
end

y = {}
for i = 1, 10000000 do
    if type(y) == "number" then
        acc = acc + 1
    end
end
