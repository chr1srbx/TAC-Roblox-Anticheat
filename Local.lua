--[[

							ooooooooooooo     .o.         .oooooo.
							8'   888   `8     .888.       d8P'  `Y8b
								888         .8"888.     888
								888        .8' `888.    888
								888       .88ooo8888.   888
								888      .8'     `888.  `88b    ooo
								o888o    o88o     o8888o  `Y8bood8P'

								 Tayia's Anticheat 1.1 [CLIENT]

TIP : Rename this script, move it somewhere or just add it into something like your shooting script for example, 
	  as its easy to find and delete via a DEX script. (same goes for remotes)
]]



if not game:IsLoaded() then
	game.Loaded:Wait()
end

--------------------------------------------------------------------------------------------------------------------


local DexExplorerDetection = true --This won't detect every explorer script.


--------------------------------------------------------------------------------------------------------------------

local name = tostring(math.random())
local Chat = game:GetService("Chat")
Instance.new("BoolValue", Chat).Name = name 
local t = setmetatable({}, {__mode="v"})

while task.wait() do
	if DexExplorerDetection then
		t[1] = {}
		t[2] = Chat:FindFirstChild(name)
		while t[1] ~= nil do
			t[3] = string.rep("ab", 1024*2)
			t[3] = nil
			task.wait()
		end
		if t[2] ~= nil then
			game.ReplicatedStorage.sync:FireServer(100)
			task.wait(2)
				while true do
				end
		end
	end
end

