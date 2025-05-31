--[[

									ooooooooooooo     .o.         .oooooo.
									8'   888   8     .888.       d8P'  Y8b
									    888         .8"888.     888
									    888        .8' 888.    888
									    888       .88ooo8888.   888
									    888      .8'     888.  88b    ooo
									    o888o    o88o     o8888o  Y8bood8P'

									  Tayia's Anticheat 1.3 [SERVER]
								
						Tips : It's advised to test the anticheat, since if the variables below 
							   nare not correctly set up for your game it may trigger false positives.
								* To disable a check, set the number of that check to false
								* To enable a check, set the number of that check to true

						
	S = Server
	Any digit = Client Anticheat

	S1 : CFramePositionDetector
		S1G - Ground
		S1S - Seated
		S1H - Airborne
		S1PS - Airborne, after landing
		
	S2 : Infinte Jump Detection
	
	S3 : Noclip Detection
	
	S4 : Fling Detection
		

Ban Reason
	100 : DexExplorerDetection
]]


local MainSwitch = true 

local DiscordWebhook = true
local WEBHOOK_URL = "https://webhook.lewisakura.moe/api/webhooks/1377370131453313074/TGFruQJA6NIITcGsxu4jrcQiYae5IN7Sy4Tbqab_hk6LsJ33gIV95zplIbQYTk-WUn_n"
--Use https://webhook.lewisakura.moe/, normal webhooks wont work.

local MAX_VIOLATIONS_BEFORE_KICK = 10

local SwimFlyDetector = true --Detects if a player is attempting SwimFly

local FlingDetector = true -- Detects if a player is attempting flings
local FLING_CHECK_INTERVAL = 1
local VELOCITY_THRESHOLD = 150
local MAX_ANGULAR_VELOCITY_THRESHOLD = 60 -- Max radians per second for rotational velocity (tune this carefully, test before publishing.)

local JumpHackDetector = true -- Detects if the player has Infinite jump.

local NoclipDetector = true -- Detects noclip attempts. (Rarely can trigger a false positive)

local CFramePositionDetector = true --[[ This option will prevent a cheater from using Speed,Teleportation, FakeLag and similar cheats.
                                    This may bring false positives if the variables below aren't set properly.
                                    Anticheat may trigger if the player's ping is too high (over 600ms), since this is a server check. ]]
local MAX_ALLOWED_GROUND_SPEED = 25 --[[ You will need to change this if a player equips a speed coil or something like a powerup.
										for ex:
										
										you recieve a powerup
										change to 60
										you lose your powerup
										change back to 17
										]]
local MAX_ALLOWED_AIR_HORIZONTAL_SPEED_FACTOR = 1.5 -- Multiplier for ground speed to determine max horizontal air speed (e.g., 1.0 for no extra horizontal speed, 1.5 for 50% more)
local CFRAME_CHECK_INTERVAL = 0.5 -- The lower the more accurate, but more heavy on the server. Recommended to keep between 0.5-1.5 for the best results.
local HUMANOID_SITTING_MULTIPLIER = 1 -- If the humanoid is sitting in a car, etc. If this isn't needed, set it to 1.
---------------------------------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KickEvent = ReplicatedStorage:WaitForChild("update")
local BanEvent = ReplicatedStorage:WaitForChild("sync")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

---------------------------------------------------------------------------------------------------------
local function sendDiscordMessage(messageContent, embed)
	MainSwitch = false
	if not HttpService.HttpEnabled then
		warn("HttpService is not enabled! Cannot send Discord message.")
		return false
	end

	local data = {
		["content"] = messageContent, 
		["embeds"] = embed and {embed} or nil,
		["username"] = "Tayia's Anticheat",
		["avatar_url"] = ""
	}

	local jsonData
	local success, errorMsg = pcall(function()
		jsonData = HttpService:JSONEncode(data)
	end)

	if not success then
		warn("Failed to encode JSON for Discord webhook:", errorMsg)
		MainSwitch = true
		return false
	end

	-- Send the POST request
	local postSuccess, postResponse = pcall(function()
		HttpService:PostAsync(WEBHOOK_URL, jsonData, Enum.HttpContentType.ApplicationJson)
	end)

	if not postSuccess then
		warn("Failed to send Discord webhook message:", postResponse)
		MainSwitch = true
		return false
	else
		print("Successfully sent Discord webhook message.")
		MainSwitch = true
		return true
	end
end

---------------------------------------------------------------------------------------------------------


local function getPlayerAvatarUrl(userId)
	if not userId then
		warn("getPlayerAvatarUrl: UserId is nil.")
		return nil
	end

	local size = "100x100"
	local requestUrl = string.format("https://thumbnails.roproxy.com/v1/users/avatar-headshot?userIds=%d&size=%s&format=Png&isCircular=false", userId, size)

	local success, result = pcall(function()
		local response = HttpService:GetAsync(requestUrl)
		local data = HttpService:JSONDecode(response)
		if data and data.data and #data.data > 0 and data.data[1].imageUrl then
			return data.data[1].imageUrl
		elseif data and data.data and #data.data > 0 and data.data[1].state == "Error" then
			warn("getPlayerAvatarUrl: API returned an error state for UserId " .. userId .. ": " .. (data.data[1].message or "Unknown error"))
			return nil
		else
			warn("getPlayerAvatarUrl: Could not parse imageUrl or unexpected response structure for UserId " .. userId .. ". Response: " .. response)
			return nil 
		end
	end)

	if success and result then
		return result
	else
		warn("getPlayerAvatarUrl: Failed to fetch avatar for UserId " .. userId .. ". Error: " .. tostring(result))
		return nil
	end
end

---------------------------------------------------------------------------------------------------------

local function getPlayerHeight(character)
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		return humanoidRootPart.Position.Y
	end
	return nil
end


---------------------------------------------------------------------------------------------------------

local function isGrounded(humanoid)
	return humanoid.FloorMaterial ~= Enum.Material.Air
end


local function IsPlayerSwimming(character)
	if not character then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid:GetState() == Enum.HumanoidStateType.Swimming
	end
	return false
end


---------------------------------------------------------------------------------------------------------
local playerData = {}
local playerFallData = {}

game.Players.PlayerAdded:Connect(function(player)
	playerData[player.UserId] = {
		violations = 0,
	}

	player.CharacterAdded:Connect(function(character)
		if MainSwitch then 
			local humanoid = character:WaitForChild("Humanoid")
			local rootPart = character:WaitForChild("HumanoidRootPart")

			local lastMidAirJumpSetback = 0
			local midAirJumpSetbackCooldown = 1

			local function executeKickProcedure(playerToKick, kickReasonCode, diagnosticMessage)
				MainSwitch = false
				local currentViolations = (playerData[playerToKick.UserId] and playerData[playerToKick.UserId].violations) or "N/A"
				local fullDiagnosticMessage = string.format("%s (Total Violations: %s)", diagnosticMessage, tostring(currentViolations))

				local fullKickMessage = "TAC: " .. kickReasonCode
				if DiscordWebhook then
					local playerAvatarUrl = "DEFAULT_AVATAR_URL_IF_ERROR" -- Fallback
					local successAvatar, urlOrErrAvatar = pcall(getPlayerAvatarUrl, playerToKick.UserId)
					if successAvatar and urlOrErrAvatar then playerAvatarUrl = urlOrErrAvatar
					else warn("executeKickProcedure: Failed to get player avatar URL for UserId: " .. playerToKick.UserId .. " - Error: " .. tostring(urlOrErrAvatar)) end

					local embedData = {
						["title"] = "Player Kicked",
						["description"] = "**" .. playerToKick.Name .. "** (ID: " .. playerToKick.UserId .. ") has been kicked by the anti-cheat.",
						["color"] = 16711680,
						["fields"] = {
							{["name"] = "Kick Reason Code", ["value"] = "" .. fullKickMessage .. "", ["inline"] = true},
							{["name"] = "Account Age", ["value"] = playerToKick.AccountAge .. " days", ["inline"] = true},
							{["name"] = "Details", ["value"] = fullDiagnosticMessage, ["inline"] = false}
						},
						["thumbnail"] = {["url"] = playerAvatarUrl},
						["timestamp"] = DateTime.now():ToIsoDate()
					}
					local successSend, errSend = pcall(sendDiscordMessage, "", embedData)
					if not successSend then warn("executeKickProcedure: Failed to send Discord message. Error: " .. tostring(errSend)) end
				end
				warn("Kicking " .. playerToKick.Name .. " (ID: " .. playerToKick.UserId .. "). Reason: " .. fullKickMessage .. ". Details: " .. fullDiagnosticMessage)
				if playerToKick and playerToKick.Parent then
					pcall(playerToKick.Kick, playerToKick, fullKickMessage)
				end
				
				MainSwitch = true
			end
		

			if FlingDetector then
				local kickDetail = ""
				local lastPosition = rootPart.Position
				local lastTimeCheck = tick()
				task.spawn(function()
					while character and character.Parent and humanoid and humanoid.Health > 0 and rootPart and rootPart.Parent and player and player.Parent and playerData[player.UserId] do
						task.wait(FLING_CHECK_INTERVAL) 

						if not (character and character.Parent and humanoid and humanoid.Health > 0 and rootPart and rootPart.Parent and player and player.Parent and playerData[player.UserId]) then
							break
						end

						local currentTime = tick()
						local currentPosition = rootPart.Position
						local currentVelocity = rootPart.AssemblyLinearVelocity
						local currentAngularVelocity = rootPart.AssemblyAngularVelocity 

						local displacement = (currentPosition - lastPosition)
						local timeElapsed = currentTime - lastTimeCheck
						if timeElapsed <= 0.001 then 
							timeElapsed = FLING_CHECK_INTERVAL
						end

						if currentVelocity.Magnitude > VELOCITY_THRESHOLD then
							local verticalVelocityRatio = 0
							if currentVelocity.Magnitude > 0 then
								verticalVelocityRatio = math.abs(currentVelocity.Y) / currentVelocity.Magnitude
							end

							if verticalVelocityRatio < 0.85 then 
								playerData[player.UserId].violations = playerData[player.UserId].violations + 3
								kickDetail = string.format("Velocity magnitude: %.2f studs/s (Threshold: %.2f). Violations: %d", currentVelocity.Magnitude, VELOCITY_THRESHOLD, playerData[player.UserId].violations)
								warn(player.Name .. " " .. kickDetail)
								player:LoadCharacter()
							end
						end

						if currentAngularVelocity.Magnitude > MAX_ANGULAR_VELOCITY_THRESHOLD then
							playerData[player.UserId].violations = playerData[player.UserId].violations + 3
							kickDetail = string.format("Angular velocity magnitude: %.2f rad/s (Threshold: %.2f). Violations: %d", currentAngularVelocity.Magnitude, MAX_ANGULAR_VELOCITY_THRESHOLD, playerData[player.UserId].violations)
							warn(player.Name .. " " .. kickDetail)
							player:LoadCharacter()
						end

						if playerData[player.UserId].violations >= MAX_VIOLATIONS_BEFORE_KICK then
							if player and player.Parent and MainSwitch then
								executeKickProcedure(player, "S4", kickDetail)
							end
							break 
						end

						lastPosition = currentPosition
						lastTimeCheck = currentTime
					end
				end)
			end

			if NoclipDetector then
				task.spawn(function()
					if not rootPart or not rootPart.Parent then
						rootPart = character:WaitForChild("HumanoidRootPart", 5)
						if not rootPart or not rootPart.Parent then
							warn("NoclipDetector: HumanoidRootPart not found for " .. player.Name .. ". Aborting noclip check for this character.")
							return
						end
					end

					local oldPosition = rootPart.CFrame.Position

					while character and character.Parent and rootPart and rootPart.Parent and humanoid and humanoid.Health > 0 and player and player.Parent and playerData[player.UserId] do
						task.wait()

						if not (character and character.Parent and rootPart and rootPart.Parent and humanoid and humanoid.Health > 0 and player and player.Parent and playerData[player.UserId]) then
							break
						end

						local currentPosition = rootPart.CFrame.Position
						local movementVector = currentPosition - oldPosition
						local movementMagnitude = movementVector.Magnitude

						if movementMagnitude < 0.01 then
							oldPosition = currentPosition
							continue
						end

						local raycastParams = RaycastParams.new()
						raycastParams.FilterDescendantsInstances = {character}
						raycastParams.FilterType = Enum.RaycastFilterType.Exclude

						local raycastResult = workspace:Raycast(oldPosition, movementVector.Unit * movementMagnitude, raycastParams)


						if raycastResult and raycastResult.Instance and raycastResult.Instance.CanCollide then
							local raycastCheck = raycastResult.Instance.Parent

							if raycastResult.Instance.Name == "Terrain" then
								local position = raycastResult.Position
								local cellX = math.floor(position.X / 4)
								local cellY = math.floor(position.Y / 4)
								local cellZ = math.floor(position.Z / 4)
								local materialEnumAtNoclipHit, _ = workspace.Terrain:GetCell(cellX, cellY, cellZ)

								local isSwimming = IsPlayerSwimming(character)

								if materialEnumAtNoclipHit == Enum.Material.Water or isSwimming then
									oldPosition = currentPosition 
									continue
								end
							end
							
							if not raycastCheck:FindFirstChild("Humanoid") then
								playerData[player.UserId].violations = playerData[player.UserId].violations + 0.5
								local diagnosticMsg = string.format("Noclip. Hit: %s. Movement: %.2f studs. Violations: %.1f", raycastResult.Instance.Name, movementMagnitude, playerData[player.UserId].violations)
								warn(player.Name .. ": " .. diagnosticMsg)

								local currentOrientationY = select(2, rootPart.CFrame:ToOrientation())
								rootPart.CFrame = CFrame.new(oldPosition - (movementVector.Unit * 0.5)) * CFrame.Angles(0, currentOrientationY, 0)
								rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
								rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

								task.wait(0.1)

								oldPosition = rootPart.CFrame.Position

								if playerData[player.UserId].violations >= MAX_VIOLATIONS_BEFORE_KICK then
									if player and player.Parent then
										executeKickProcedure(player, "S3", diagnosticMsg)
									end
									break 
								end
							end
						else
							oldPosition = currentPosition
						end
					end
				end)
			end

			if JumpHackDetector then
				local initialCharHeight = getPlayerHeight(character) or rootPart.Position.Y
				playerFallData[player.UserId] = {
					isFalling = false,
					fallStartTime = 0,
					fallStartHeight = initialCharHeight,
					lastKnownGroundPosition = rootPart.Position,
					lastLandedTime = 0,
					recentlyLanded = false
				}

				humanoid.StateChanged:Connect(function(oldState, newState)
					if not character or not character.Parent or not humanoid or humanoid.Health <= 0 or not player or not player.Parent or not playerData[player.UserId] or not playerFallData[player.UserId] then
						return
					end

					local currentHeight = getPlayerHeight(character)
					if not currentHeight then
						print(string.format("Player %s: currentHeight is nil. OldState: %s, NewState: %s", player.Name, oldState.Name, newState.Name))
						return
					end

					if newState ~= Enum.HumanoidStateType.Jumping and
						newState ~= Enum.HumanoidStateType.Freefall and
						newState ~= Enum.HumanoidStateType.Flying and
						newState ~= Enum.HumanoidStateType.Swimming and
						newState ~= Enum.HumanoidStateType.Seated then
						playerFallData[player.UserId].lastKnownGroundPosition = rootPart.Position
					end

					if newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running or newState == Enum.HumanoidStateType.RunningNoPhysics then
						playerFallData[player.UserId].lastLandedTime = tick()
						playerFallData[player.UserId].recentlyLanded = true 
						task.delay(0.25, function()
							if playerFallData[player.UserId] then  playerFallData[player.UserId].recentlyLanded = false end
						end)
					end

					if isGrounded(humanoid) then 
						if not playerFallData[player.UserId].recentlyLanded then
							playerFallData[player.UserId].lastLandedTime = tick()
							playerFallData[player.UserId].recentlyLanded = true
							task.delay(0.25, function()
								if playerFallData[player.UserId] then  playerFallData[player.UserId].recentlyLanded = false end
							end)
						end
						playerFallData[player.UserId].lastKnownGroundPosition = rootPart.Position
					end

					local landingGracePeriod = 0.25 -- This is effectively handled by 'recentlyLanded' and the cooldown now
					if oldState == Enum.HumanoidStateType.Freefall and newState == Enum.HumanoidStateType.Jumping then
						if tick() - (playerFallData[player.UserId].lastLandedTime or 0) > landingGracePeriod then 
							if tick() - lastMidAirJumpSetback > midAirJumpSetbackCooldown then
								local verticalVelocity = rootPart.AssemblyLinearVelocity.Y
								-- Use the recentlyLanded flag you defined for playerFallData
								if verticalVelocity >= 0.5  and not playerFallData[player.UserId].recentlyLanded then
									lastMidAirJumpSetback = tick()
									local diagnostic = "Detected mid-air jump (Jump from Freefall state without recent landing)."
									print(string.format("Player %s: %s. lastLandedTime: %.2f, tick(): %.2f, Violations: %d", player.Name, diagnostic, (playerFallData[player.UserId].lastLandedTime or 0), tick(), playerData[player.UserId].violations + 1))

									playerData[player.UserId].violations = playerData[player.UserId].violations + 1

									local targetPositionY = (playerFallData[player.UserId].lastKnownGroundPosition and playerFallData[player.UserId].lastKnownGroundPosition.Y) or (currentHeight - 10)
									local targetPosition = Vector3.new(rootPart.Position.X, targetPositionY, rootPart.Position.Z)

									local currentOrientationY = select(2, rootPart.CFrame:ToOrientation())
									rootPart.CFrame = CFrame.new(targetPosition) * CFrame.Angles(0, currentOrientationY, 0)
									rootPart.AssemblyLinearVelocity = Vector3.new(0, -30, 0)
									rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
									humanoid:ChangeState(Enum.HumanoidStateType.Freefall)

									if playerData[player.UserId].violations >= MAX_VIOLATIONS_BEFORE_KICK then
										executeKickProcedure(player, "S2", diagnostic)
									end
									return
								end
							else
								print(string.format("Player %s: Mid-air jump detected but on cooldown. lastLandedTime: %.2f", player.Name, (playerFallData[player.UserId].lastLandedTime or 0)))
							end
						else
							print(string.format("Player %s: Ignored potential mid-air jump due to very recent landing (tick - lastLandedTime: %.2fs). OS: %s, NS: %s",
								player.Name, tick()-(playerFallData[player.UserId].lastLandedTime or 0), oldState.Name, newState.Name))
						end
					end
				end)			
			end

			if CFramePositionDetector then
				print(player.Name .. ": Initializing CFramePositionDetector") 
				task.spawn(function()
					if not rootPart or not rootPart.Parent then
						rootPart = character:WaitForChild("HumanoidRootPart", 5)
						if not rootPart or not rootPart.Parent then
							warn("CFramePositionDetector: HumanoidRootPart not found for " .. player.Name .. ". Aborting CFrame check for this character.")
							return
						end
					end

					local lastPosition = rootPart.CFrame.Position
					local previousTick = tick()
					local previousHumanoidStateType = humanoid:GetState()
					local justLandedGrace = false

					while character and character.Parent and rootPart and rootPart.Parent and humanoid and humanoid.Health > 0 and player and player.Parent and playerData[player.UserId] do
						task.wait(CFRAME_CHECK_INTERVAL)

						if not (character and character.Parent and rootPart and rootPart.Parent and humanoid and humanoid.Health > 0 and player and player.Parent and playerData[player.UserId]) then
							break 
						end

						local currentTick = tick()
						local actualDeltaTime = currentTick - previousTick
						local currentPosition = rootPart.CFrame.Position 
						local currentHumanoidStateType = humanoid:GetState()

						if previousHumanoidStateType == Enum.HumanoidStateType.Freefall and
							currentHumanoidStateType ~= Enum.HumanoidStateType.Freefall and
							currentHumanoidStateType ~= Enum.HumanoidStateType.Swimming and 
							currentHumanoidStateType ~= Enum.HumanoidStateType.Flying then 
							justLandedGrace = true
						end

						if justLandedGrace then
							lastPosition = currentPosition
							previousTick = currentTick
							previousHumanoidStateType = currentHumanoidStateType
							justLandedGrace = false 
							playerData[player.UserId].violations = math.max(0, playerData[player.UserId].violations - 0.5) 
							continue 
						end

						if actualDeltaTime <= 1/1000 then 
							lastPosition = currentPosition 
							previousTick = currentTick 
							previousHumanoidStateType = currentHumanoidStateType
							continue
						end

						local displacement = currentPosition - lastPosition
						local speedToEvaluate
						local currentMaxAllowedSpeedToUse

						if currentHumanoidStateType == Enum.HumanoidStateType.Freefall or currentHumanoidStateType == Enum.HumanoidStateType.Flying then
							local horizontalDisplacement = Vector3.new(displacement.X, 0, displacement.Z)
							speedToEvaluate = horizontalDisplacement.Magnitude / actualDeltaTime
							currentMaxAllowedSpeedToUse = MAX_ALLOWED_GROUND_SPEED * MAX_ALLOWED_AIR_HORIZONTAL_SPEED_FACTOR
						else
							speedToEvaluate = displacement.Magnitude / actualDeltaTime
							currentMaxAllowedSpeedToUse = MAX_ALLOWED_GROUND_SPEED
						end

						if humanoid.Sit then
							currentMaxAllowedSpeedToUse = currentMaxAllowedSpeedToUse * HUMANOID_SITTING_MULTIPLIER
						end

						previousTick = currentTick

						if speedToEvaluate > currentMaxAllowedSpeedToUse + 2 then
							playerData[player.UserId].violations = playerData[player.UserId].violations + 1
							local diagnosticText = string.format("Speed: %.2f studs/s (Max: %.2f), State: %s. Δt: %.3fs. Violations: %d/%d.",
								speedToEvaluate, currentMaxAllowedSpeedToUse, currentHumanoidStateType.Name, actualDeltaTime, playerData[player.UserId].violations, MAX_VIOLATIONS_BEFORE_KICK)
							warn(player.Name .. " violated speed. " .. diagnosticText)
							humanoid.WalkSpeed = 0
							task.wait(1)
							humanoid.WalkSpeed = 16

							if playerData[player.UserId].violations >= MAX_VIOLATIONS_BEFORE_KICK then
								local kickReasonPrefix = "S1"
								local kickReasonSuffix = ""
								if humanoid.Sit then
									kickReasonSuffix = "S" 
								elseif currentHumanoidStateType == Enum.HumanoidStateType.Freefall or currentHumanoidStateType == Enum.HumanoidStateType.Flying then
									kickReasonSuffix = "H"  
								elseif previousHumanoidStateType == Enum.HumanoidStateType.Freefall and currentHumanoidStateType ~= Enum.HumanoidStateType.Freefall then
									kickReasonSuffix = "PS"
								else
									kickReasonSuffix = "G"
								end

								local fullKickCode = kickReasonPrefix .. kickReasonSuffix
								if player and player.Parent then executeKickProcedure(player, fullKickCode, diagnosticText) end
								break 
							else
								local currentOrientationY = select(2, rootPart.CFrame:ToOrientation())
								rootPart.CFrame = CFrame.new(lastPosition) * CFrame.Angles(0, currentOrientationY, 0)
								rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
								rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
								currentPosition = lastPosition 
							end
						else
							playerData[player.UserId].violations = math.max(0, playerData[player.UserId].violations - 0.02) 
						end

						lastPosition = currentPosition
						previousHumanoidStateType = currentHumanoidStateType
					end
				end)
			end
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	if playerData[player.UserId] then
		playerData[player.UserId] = nil
	end
	if playerFallData[player.UserId] then
		playerFallData[player.UserId] = nil
	end
end)

--------------------------------------------------------------------------------------------------------

KickEvent.OnServerEvent:Connect(function(player, kickreason)
	if DiscordWebhook then
		local playerAvatarUrl = nil
		local successAvatar, urlOrErrAvatar = pcall(getPlayerAvatarUrl, player.UserId)
		if successAvatar and urlOrErrAvatar then playerAvatarUrl = urlOrErrAvatar
		else warn("KickEvent: Failed to get player avatar URL for UserId: " .. player.UserId .. " - Error: " .. tostring(urlOrErrAvatar)) end

		local embedData = {
			["title"] = "Player Kicked (Client Request)",
			["description"] = "**" .. player.Name .. "** (ID: " .. player.UserId .. ") has been kicked by the anti-cheat (client detection).",
			["color"] = 16711680,
			["fields"] = {
				{
					["name"] = "Kick Reason Code",
					["value"] = "" .. kickreason .. "",
					["inline"] = true
				},
				{
					["name"] = "Account Age",
					["value"] = player.AccountAge .. " days",
					["inline"] = true
				},
			},
			["thumbnail"] = {
				["url"] = playerAvatarUrl or ""
			},
			["timestamp"] = DateTime.now():ToIsoDate()
		}
		sendDiscordMessage("", embedData)
	end
	if player and player.Parent then
		player:Kick("TAC: " .. tostring(kickreason)) 	
	end
end)

BanEvent.OnServerEvent:Connect(function(player, banreason)
	if DiscordWebhook then
		local playerAvatarUrl = nil
		local successAvatar, urlOrErrAvatar = pcall(getPlayerAvatarUrl, player.UserId)
		if successAvatar and urlOrErrAvatar then playerAvatarUrl = urlOrErrAvatar
		else warn("BanEvent: Failed to get player avatar URL for UserId: " .. player.UserId .. " - Error: " .. tostring(urlOrErrAvatar)) end

		local embedData = {
			["title"] = "Player Banned (Client Request)",
			["description"] = "**" .. player.Name .. "** (ID: " .. player.UserId .. ") has been banned by the anti-cheat (client detection).",
			["color"] = 16711680, -- Red
			["fields"] = {
				{
					["name"] = "Ban Reason Code",
					["value"] = "" .. banreason .. "",
					["inline"] = true
				},
				{
					["name"] = "Account Age",
					["value"] = player.AccountAge .. " days",
					["inline"] = true
				},
			},
			["thumbnail"] = {
				["url"] = playerAvatarUrl or ""
			},
			["timestamp"] = DateTime.now():ToIsoDate()
		}
		sendDiscordMessage("", embedData)
	end

	local config = {
		UserIds = { player.UserId },
		Duration = 99999999999,
		DisplayReason = "TAC: " .. tostring(banreason),
		PrivateReason = "TAC: " .. tostring(banreason) .. " (Client Detection ID: 100)",
		ExcludeAltAccounts = false,
		ApplyToUniverse = true
	}

	-- Use BanAsync with the table directly as per Roblox documentation
	local success, err = pcall(function()
		Players:BanAsync(player.UserId, config.PrivateReason, config.DisplayReason, config.Duration)
		local banOptions = {
			Reason = config.PrivateReason,
			DisplayReason = config.DisplayReason,
			Duration = config.Duration,
		}
		return Players:Ban(player.UserId, banOptions)
	end)

	if success then
		print("Successfully banned " .. player.Name .. " (ID: " .. player.UserId .. ") for reason: " .. banreason)
	else
		warn("Failed to ban " .. player.Name .. " (ID: " .. player.UserId .. "). Error: " .. tostring(err))
	end
end)
