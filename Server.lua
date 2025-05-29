--[[

								ooooooooooooo     .o.         .oooooo.
								8'   888   `8     .888.       d8P'  `Y8b
									888         .8"888.     888
									888        .8' `888.    888
									888       .88ooo8888.   888
									888      .8'     `888.  `88b    ooo
									o888o    o88o     o8888o  `Y8bood8P'

									  Tayia's Anticheat 1.1 [SERVER]
								
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
		

Ban Reason
	100 : DexExplorerDetection
]]

local DiscordWebhook = true
local WEBHOOK_URL = "WEBHOOK HERE"
--Use https://webhook.lewisakura.moe/, normal webhooks wont work.

local MAX_VIOLATIONS_BEFORE_KICK = 10


local JumpHackDetector = true -- Detects if the player has Infinite jump.


local NoclipDetector = true -- Detects noclip attempts. (Rarely can trigger a false positive, VIOLATION_COUNT is increased by 0.5)


local FlyHackDetector = true -- This variable is declared but not used in the provided script segment.
local MAX_FLY_TIME = 1 -- This variable is declared but not used in the provided script segment.

local CFramePositionDetector = true --[[ This option will prevent a cheater from using Speed,Teleportation, FakeLag and similar cheats.
                                    This may bring false positives if the variables below aren't set properly.
                                    Anticheat may trigger if the player's ping is too high, since this is a server check. ]]
local MAX_ALLOWED_GROUND_SPEED = 26 --[[ You will need to change this if a player equips a speed coil or something like a powerup.
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
		return false
	end

	-- Send the POST request
	local postSuccess, postResponse = pcall(function()
		HttpService:PostAsync(WEBHOOK_URL, jsonData, Enum.HttpContentType.ApplicationJson)
	end)

	if not postSuccess then
		warn("Failed to send Discord webhook message:", postResponse)
		return false
	else
		print("Successfully sent Discord webhook message.")
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


---------------------------------------------------------------------------------------------------------
playerFallData = {}
game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)

		local VIOLATION_COUNT = 0
		local humanoid = character:WaitForChild("Humanoid")
		local rootPart = character:WaitForChild("HumanoidRootPart")

		local lastMidAirJumpSetback = 0
		local midAirJumpSetbackCooldown = 0.5

		local function executeKickProcedure(playerToKick, kickReasonCode, diagnosticMessage)
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
						{["name"] = "Kick Reason Code", ["value"] = "`" .. fullKickMessage .. "`", ["inline"] = true},
						{["name"] = "Account Age", ["value"] = playerToKick.AccountAge .. " days", ["inline"] = true},
						{["name"] = "Details", ["value"] = diagnosticMessage, ["inline"] = false}
					},
					["thumbnail"] = {["url"] = playerAvatarUrl},
					["timestamp"] = DateTime.now():ToIsoDate()
				}
				local successSend, errSend = pcall(sendDiscordMessage, "", embedData)
				if not successSend then warn("executeKickProcedure: Failed to send Discord message. Error: " .. tostring(errSend)) end
			end
			warn("Kicking " .. playerToKick.Name .. " (ID: " .. playerToKick.UserId .. "). Reason: " .. fullKickMessage .. ". Details: " .. diagnosticMessage)
			-- Ensure player is still connected before kicking
			if playerToKick and playerToKick.Parent then
				pcall(playerToKick.Kick, playerToKick, fullKickMessage)
			end
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

				while character and character.Parent and rootPart and rootPart.Parent and humanoid and humanoid.Health > 0 and player and player.Parent do
					task.wait()

					if not (character and character.Parent and rootPart and rootPart.Parent and humanoid and humanoid.Health > 0 and player and player.Parent) then
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
						VIOLATION_COUNT = VIOLATION_COUNT + 0.5
						local diagnosticMsg = string.format("Noclip. Hit: %s. Movement: %.2f studs. Violations: %.1f", raycastResult.Instance.Name, movementMagnitude, VIOLATION_COUNT)
						warn(player.Name .. ": " .. diagnosticMsg)

						local currentOrientationY = select(2, rootPart.CFrame:ToOrientation())
						rootPart.CFrame = CFrame.new(oldPosition - (movementVector.Unit * 0.5)) * CFrame.Angles(0, currentOrientationY, 0)
						rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
						rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

						task.wait(0.1)

						if VIOLATION_COUNT >= MAX_VIOLATIONS_BEFORE_KICK then
							if player and player.Parent then
								executeKickProcedure(player, "S3", diagnosticMsg)
							end
							break 
						end
					else
						oldPosition = currentPosition -- Valid movement or no collision
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
				lastLandedTime = 0
			}

			humanoid.StateChanged:Connect(function(oldState, newState)
				if not character or not character.Parent or not humanoid or humanoid.Health <= 0 or not player or not player.Parent then
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
					playerFallData.lastKnownGroundPosition = rootPart.Position
				end

				if oldState == Enum.HumanoidStateType.Freefall and newState == Enum.HumanoidStateType.Jumping then
					if tick() - (playerFallData.lastLandedTime or 0) > 0.25 then 
						if tick() - lastMidAirJumpSetback > midAirJumpSetbackCooldown then
							lastMidAirJumpSetback = tick()
							local diagnostic = "Detected mid-air jump (Jump from Freefall state without recent landing)."
							print(string.format("Player %s: %s. lastLandedTime: %.2f, tick(): %.2f", player.Name, diagnostic, (playerFallData.lastLandedTime or 0), tick()))
							VIOLATION_COUNT = VIOLATION_COUNT + 2

							local targetPositionY = (playerFallData.lastKnownGroundPosition and playerFallData.lastKnownGroundPosition.Y) or (currentHeight - 10)
							local targetPosition = Vector3.new(rootPart.Position.X, targetPositionY, rootPart.Position.Z)

							local currentOrientationY = select(2, rootPart.CFrame:ToOrientation())
							rootPart.CFrame = CFrame.new(targetPosition) * CFrame.Angles(0, currentOrientationY, 0)
							rootPart.AssemblyLinearVelocity = Vector3.new(0, -30, 0)
							rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
							humanoid:ChangeState(Enum.HumanoidStateType.Freefall)

							if VIOLATION_COUNT >= MAX_VIOLATIONS_BEFORE_KICK then
								executeKickProcedure(player, "S2", diagnostic)
							end
							return --
						else
							print(string.format("Player %s: Mid-air jump detected but on cooldown. lastLandedTime: %.2f", player.Name, (playerFallData.lastLandedTime or 0)))
						end
					else
						print(string.format("Player %s: Ignored potential mid-air jump due to very recent landing (tick - lastLandedTime: %.2fs). OS: %s, NS: %s",
							player.Name, tick()-(playerFallData.lastLandedTime or 0), oldState.Name, newState.Name))
					end
				end
			end)			
		end

		if CFramePositionDetector then
			print(player.Name .. ": Initializing CFramePositionDetector") -- Confirming this module starts
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

				while character and character.Parent and rootPart and rootPart.Parent and humanoid and humanoid.Health > 0 and player and player.Parent do
					task.wait(CFRAME_CHECK_INTERVAL)

					if not (character and character.Parent and rootPart and rootPart.Parent and humanoid and humanoid.Health > 0 and player and player.Parent) then
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
						VIOLATION_COUNT = math.max(0, VIOLATION_COUNT - 0.5)
						continue 
					end

					if actualDeltaTime <= 1/1000 then 
						lastPosition = currentPosition -- Update position even if delta is too small to avoid false positive on next valid check
						previousTick = currentTick -- Update tick to ensure next delta isn't huge
						previousHumanoidStateType = currentHumanoidStateType
						continue
					end

					previousTick = currentTick -- Moved this here, so actualDeltaTime is always currentTick - previousTick from last processed frame

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

					if speedToEvaluate > currentMaxAllowedSpeedToUse + 2 then 
						VIOLATION_COUNT = VIOLATION_COUNT + 1
						local diagnosticText = string.format("Speed: %.2f studs/s (Max: %.2f), State: %s. Δt: %.3fs. Violations: %d/%d.",
							speedToEvaluate, currentMaxAllowedSpeedToUse, currentHumanoidStateType.Name, actualDeltaTime, VIOLATION_COUNT, MAX_VIOLATIONS_BEFORE_KICK)
						warn(player.Name .. " violated speed. " .. diagnosticText)


						if VIOLATION_COUNT >= MAX_VIOLATIONS_BEFORE_KICK then
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
						VIOLATION_COUNT = math.max(0, VIOLATION_COUNT - 0.03) 
					end

					lastPosition = currentPosition
					previousHumanoidStateType = currentHumanoidStateType
				end
			end)
		end
	end)
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
			["color"] = 16711680, -- Red
			["fields"] = {
				{
					["name"] = "Kick Reason Code",
					["value"] = "`" .. kickreason .. "`",
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
					["value"] = "`" .. banreason .. "`",
					["inline"] = true
				},
				{
					["name"] = "Account Age",
					["value"] = player.AccountAge .. " days",
					["inline"] = true
				},
			},
			["thumbnail"] = {
				["url"] = playerAvatarUrl or "" -- Ensure URL is string even if nil
			},
			["timestamp"] = DateTime.now():ToIsoDate()
		}
		sendDiscordMessage("", embedData)
	end

	local duration = 99999999999
	local config: BanConfigType = {
		UserIds = { player.UserId },
		Duration = duration,
		DisplayReason = tostring(banreason),
		PrivateReason = tostring(banreason),
		ExcludeAltAccounts = false,
		ApplyToUniverse = true
	}

	local success, err = pcall(function()
		return Players:BanAsync(config)
	end)
	print(success, err)
end)
