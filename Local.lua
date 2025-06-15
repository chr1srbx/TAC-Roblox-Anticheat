--[[

							    ooooooooooooo     .o.         .oooooo.
							    8'   888   `8     .888.       d8P'  `Y8b
								888         .8"888.     888
							       888        .8' `888.    888
							       888       .88ooo8888.   888
								888      .8'     `888.  `88b    ooo
								o888o    o88o     o8888o  `Y8bood8P'

								 	Tayia's Anticheat 1.2 [CLIENT]

TIP : Rename this script, move it somewhere or just add it into something like your shooting script for example, 
	  as its easy to find and delete via a DEX script. (same goes for remotes), sanity check is present, but 
	  don't rely too much on it, as it can be hooked/tampered with.
]]




if not game[(("Is" .. "Loaded"))](game) then
	game[(string.reverse("dedaol"))]:Wait()
end

local _s = true --This will detect mostly every explorer script. (Works on : Wave, AWP etc. | Doesn't work : Xeno) (dexdetection)

local o = tostring(math.random())
local w = game:GetService(string.char(67,104,97,116))
Instance.new((string.char(66,111,111,108,86,97,108,117,101)), w).Name = o

local z = setmetatable({}, {__mode = "\118"})

local function zz()
	local a = "se".."nd"
	return game.ReplicatedStorage[a]
end

local function ee()
	return game.ReplicatedStorage[(string.reverse("cnyS"))]
end

while (function() return task.wait() end)() do
	zz():FireServer()
	if (_s == not false) then
		z[1] = (function(...) return {} end)()
		z[2] = w:FindFirstChild(o)
		while (not not z[1]) do
			z[3] = ("a".."b"):rep(bit32.lshift(1024, 1))
			z[3] = nil
			for _ = 1,1 do task["wait"]() end
		end
		if z[2] then
			ee():FireServer(0x64)
		end
	end
end
