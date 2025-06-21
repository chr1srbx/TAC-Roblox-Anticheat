--[[

								  ooooooooooooo     .o.         .oooooo.
								  8'   888   8     .888.       d8P'  Y8b
								      888         .8"888.      888
								      888        .8' 888.     888
							              888       .88ooo8888.    888
							               888      .8'     888.   88b    ooo
								      o888o    o88o     o8888o  Y8bood8P'

									  Tayia's Anticheat 1.5 [MODULE]
								
						Tips : It's advised to test the anticheat, since if the variables below 
							   nare not correctly set up for your game it may trigger false positives.
								* To disable a check, set the value of that check to false
								* To enable a check, set the value of that check to true
								* Configure the values accordingly after testing.

						
	S = Server
	Any digit = Client Anticheat

	S1 : CFramePositionDetector
		S1G - Ground
		S1S - Seated
		S1H - Airborne
		S1PS - Airborne again, after landing
		
	S2 : Infinte Jump Detection
	
	S3 : Noclip Detection
	
	S4 : Fling Detection
		

Ban Reason
	100 : DexExplorerDetection
    200 : No response from the client anticheat.
]]

local TAC = {}

-- // CONFIGURATION //
TAC.MainSwitch = true
local TPCheater = true 

local DiscordWebhook = true
local WEBHOOK_URL = "WEBHOOK_HERE"

local MAX_VIOLATIONS_BEFORE_KICK = 10

local FlingDetector = true
local FLING_CHECK_INTERVAL = 1
local VELOCITY_THRESHOLD = 150
local MAX_ANGULAR_VELOCITY_THRESHOLD = 60

local JumpHackDetector = true
local NoclipDetector = true

local CFramePositionDetector = true
TAC.MAX_ALLOWED_GROUND_SPEED = 25
local MAX_ALLOWED_AIR_HORIZONTAL_SPEED_FACTOR = 2
local CFRAME_CHECK_INTERVAL = 0.5
local HUMANOID_SITTING_MULTIPLIER = 1

-- // SERVICES //
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

-- // REMOTE EVENTS & RUNTIME DATA //
local ClientCheck = ReplicatedStorage:WaitForChild("Send")

local playerData = {}
local playerFallData = {}
local clientCheckTime = tick()

local function sendDiscordMessage(messageContent, embed)
	TAC.MainSwitch = false
	if not HttpService.HttpEnabled then
		warn("HttpService is not enabled! Cannot send Discord message.")
		TAC.MainSwitch = true
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
		TAC.MainSwitch = true
		return false
	end

	local postSuccess, postResponse = pcall(function()
		HttpService:PostAsync(WEBHOOK_URL, jsonData, Enum.HttpContentType.ApplicationJson)
	end)

	if not postSuccess then
		warn("Failed to send Discord webhook message:", postResponse)
		TAC.MainSwitch = true
		return false
	else
		print("Successfully sent Discord webhook message.")
		TAC.MainSwitch = true
		return true
	end
end

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

local function getPlayerHeight(character)
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		return humanoidRootPart.Position.Y
	end
	return nil
end

local function isGrounded(humanoid)
	return humanoid.FloorMaterial ~= Enum.Material.Air
end

local function executeKickProcedure(playerToKick, kickReasonCode, diagnosticMessage, ban)
	TAC.MainSwitch = false
	local currentViolations = (playerData[playerToKick.UserId] and playerData[playerToKick.UserId].violations) or "N/A"
	local fullDiagnosticMessage = string.format("%s (Total Violations at kick: %.1f)", diagnosticMessage, tonumber(currentViolations) or 0)

	local fullKickMessage = "TAC: " .. kickReasonCode
	if DiscordWebhook then
		local playerAvatarUrl = "DEFAULT_AVATAR_URL_IF_ERROR"
		local successAvatar, urlOrErrAvatar = pcall(getPlayerAvatarUrl, playerToKick.UserId)
		if successAvatar and urlOrErrAvatar then playerAvatarUrl = urlOrErrAvatar
		else warn("executeKickProcedure: Failed to get player avatar URL for UserId: " .. playerToKick.UserId .. " - Error: " .. tostring(urlOrErrAvatar)) end
		local embedData = {}
		if ban then
			embedData = {
				["title"] = "Player Banned",
				["description"] = "**" .. playerToKick.Name .. "** (ID: " .. playerToKick.UserId .. ") has been banned by the anti-cheat (client detection).",
				["color"] = 16711680,
				["fields"] = {
					{ ["name"] = "Ban Reason Code", ["value"] = "" .. fullKickMessage .. "", ["inline"] = true },
					{ ["name"] = "Account Age", ["value"] = playerToKick.AccountAge .. " days", ["inline"] = true },
					{["name"] = "Details", ["value"] = fullDiagnosticMessage, ["inline"] = false}	
				},
				["thumbnail"] = { ["url"] = playerAvatarUrl or "" },
				["timestamp"] = DateTime.now():ToIsoDate()
			}
		else
			embedData = {
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
		end
		local successSend, errSend = pcall(sendDiscordMessage, "", embedData)
		if not successSend then warn("executeKickProcedure: Failed to send Discord message. Error: " .. tostring(errSend)) end
	end
	warn("Kicking " .. playerToKick.Name .. " (ID: " .. playerToKick.UserId .. "). Reason: " .. fullKickMessage .. ". Details: " .. fullDiagnosticMessage)
	TAC.MainSwitch = true

	if TPCheater then
		TeleportService:Teleport(5629760647, playerToKick)
	end

	if ban then
		local duration = 99999999
		local success, err = pcall(function()
			Players:BanAsync({
				UserIds = { playerToKick.UserId },
				Duration = duration,
				DisplayReason = tostring(fullKickMessage),
				PrivateReason = tostring(fullDiagnosticMessage),
			})
		end)
		if not success then
			warn("Failed to ban " .. playerToKick.Name .. " (ID: " .. playerToKick.UserId .. "). Error: " .. tostring(err))
		end
	else
		local kickSuccess, kickError = pcall(function()
			if playerToKick and playerToKick.Parent then
				playerToKick:Kick(fullKickMessage)
			end
		end)
		if not kickSuccess then
			warn("Failed to kick player " .. playerToKick.Name .. ": " .. kickError)
		end
	end
end

ClientCheck.OnServerEvent:Connect(function(player, dex)
	if dex == 1 then
		executeKickProcedure(player, "100", "Dex detected.", true)
		return
	else
		clientCheckTime = tick()
	end
end)

local function allEntitiesValid(pCharacter, pHumanoid, pRootPart, pPlayer)
	return pCharacter and pCharacter.Parent and
		pHumanoid and pHumanoid.Parent and pHumanoid.Health > 0 and
		pRootPart and pRootPart.Parent and
		pPlayer and pPlayer.Parent
end

local function incrementAndCheckKick(pPlayer, increment, kickReasonCode, baseDiagnosticDetail)
	if not playerData[pPlayer.UserId] then return false end

	playerData[pPlayer.UserId].violations = playerData[pPlayer.UserId].violations + increment

	if playerData[pPlayer.UserId].violations >= MAX_VIOLATIONS_BEFORE_KICK then
		if pPlayer and pPlayer.Parent and TAC.MainSwitch then
			executeKickProcedure(pPlayer, kickReasonCode, baseDiagnosticDetail)
			return true
		end
	end
	return false
end

function TAC.initialize()
	print("Initializing Tayia's Anticheat Module...")

	ClientCheck.OnServerEvent:Connect(function(player)
		clientCheckTime = tick()
	end)

	local function onPlayerAdded(player)
		playerData[player.UserId] = {
			violations = 0,
			isSeated = false,
		}

		player.CharacterAdded:Connect(function(character)
			if not TAC.MainSwitch then return end

			local humanoid = character:WaitForChild("Humanoid")
			local rootPart = character:WaitForChild("HumanoidRootPart")

			if FlingDetector then
				task.spawn(function()
					local lastPosition = rootPart.Position
					local lastTimeCheck = tick()
					while allEntitiesValid(character, humanoid, rootPart, player) and playerData[player.UserId] do
						if tick() - clientCheckTime > 20 then
							executeKickProcedure(player, "200", "No response from client anticheat.", true)
							clientCheckTime = 9999999999999
							break
						end

						task.wait(FLING_CHECK_INTERVAL)
						if not (allEntitiesValid(character, humanoid, rootPart, player) and playerData[player.UserId]) then break end

						local currentTime = tick()
						local currentPosition = rootPart.Position
						local currentVelocity = rootPart.AssemblyLinearVelocity
						local currentAngularVelocity = rootPart.AssemblyAngularVelocity

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
								local baseDiagnostic = string.format("Fling (High Linear Velocity %.2f > %.2f, Ratio %.2f)", currentVelocity.Magnitude, VELOCITY_THRESHOLD, verticalVelocityRatio)
								warn(string.format("%s flagged: %s. Violations before: %.1f, after potential +3: %.1f", player.Name, baseDiagnostic, playerData[player.UserId].violations, playerData[player.UserId].violations + 3))
								player:LoadCharacter()
								if incrementAndCheckKick(player, 3, "S4", baseDiagnostic) then break end
							end
						end

						if currentAngularVelocity.Magnitude > MAX_ANGULAR_VELOCITY_THRESHOLD then
							local baseDiagnostic = string.format("Fling (High Angular Velocity %.2f > %.2f)", currentAngularVelocity.Magnitude, MAX_ANGULAR_VELOCITY_THRESHOLD)
							warn(string.format("%s flagged: %s. Violations before: %.1f, after potential +3: %.1f", player.Name, baseDiagnostic, playerData[player.UserId].violations, playerData[player.UserId].violations + 3))
							player:LoadCharacter()
							if incrementAndCheckKick(player, 3, "S4", baseDiagnostic) then break end
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

					while allEntitiesValid(character, humanoid, rootPart, player) and playerData[player.UserId] do
						task.wait()
						if not (allEntitiesValid(character, humanoid, rootPart, player) and playerData[player.UserId]) then break end

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
								oldPosition = currentPosition
								continue
							end

							if not raycastCheck:FindFirstChild("Humanoid") then
								local baseDiagnostic = string.format("Noclip suspected (Hit: %s, Movement: %.2f studs)", raycastResult.Instance.Name, movementMagnitude)
								warn(string.format("%s flagged: %s. Violations before: %.1f, after potential +0.5: %.1f", player.Name, baseDiagnostic, playerData[player.UserId].violations, playerData[player.UserId].violations + 0.5))

								local currentOrientationY = select(2, rootPart.CFrame:ToOrientation())
								rootPart.CFrame = CFrame.new(oldPosition - (movementVector.Unit * 0.5)) * CFrame.Angles(0, currentOrientationY, 0)
								rootPart.AssemblyLinearVelocity = Vector3.new(0,0,0); rootPart.AssemblyAngularVelocity = Vector3.new(0,0,0)
								task.wait(0.1)
								oldPosition = rootPart.CFrame.Position

								if incrementAndCheckKick(player, 0.5, "S3", baseDiagnostic) then break end
							else
								oldPosition = currentPosition
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
					isFalling = false, fallStartTime = 0, fallStartHeight = initialCharHeight,
					lastKnownGroundPosition = rootPart.Position, lastLandedTime = 0, recentlyLanded = false
				}
				local lastMidAirJumpSetback = 0
				local midAirJumpSetbackCooldown = 1

				humanoid.StateChanged:Connect(function(oldState, newState)
					if not (allEntitiesValid(character, humanoid, rootPart, player) and playerData[player.UserId] and playerFallData[player.UserId]) then return end

					local currentHeight = getPlayerHeight(character)
					if not currentHeight then
						print(string.format("Player %s: currentHeight is nil. OldState: %s, NewState: %s", player.Name, oldState.Name, newState.Name))
						return
					end

					if newState ~= Enum.HumanoidStateType.Jumping and newState ~= Enum.HumanoidStateType.Freefall and
						newState ~= Enum.HumanoidStateType.Flying and newState ~= Enum.HumanoidStateType.Swimming and
						newState ~= Enum.HumanoidStateType.Seated then
						playerFallData[player.UserId].lastKnownGroundPosition = rootPart.Position
					end

					if newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running or newState == Enum.HumanoidStateType.RunningNoPhysics then
						playerFallData[player.UserId].lastLandedTime = tick()
						playerFallData[player.UserId].recentlyLanded = true
						task.delay(0.25, function() if playerFallData[player.UserId] then playerFallData[player.UserId].recentlyLanded = false end end)
					end

					if isGrounded(humanoid) then
						if not playerFallData[player.UserId].recentlyLanded then
							playerFallData[player.UserId].lastLandedTime = tick()
							playerFallData[player.UserId].recentlyLanded = true
							task.delay(0.25, function() if playerFallData[player.UserId] then playerFallData[player.UserId].recentlyLanded = false end end)
						end
						playerFallData[player.UserId].lastKnownGroundPosition = rootPart.Position
					end

					local landingGracePeriod = 0.25
					if oldState == Enum.HumanoidStateType.Freefall and newState == Enum.HumanoidStateType.Jumping then
						if tick() - (playerFallData[player.UserId].lastLandedTime or 0) > landingGracePeriod then
							if tick() - lastMidAirJumpSetback > midAirJumpSetbackCooldown then
								local verticalVelocity = rootPart.AssemblyLinearVelocity.Y
								if verticalVelocity >= 0.5 and not playerFallData[player.UserId].recentlyLanded then
									lastMidAirJumpSetback = tick()
									local baseDiagnostic = "Mid-air jump (Jump from Freefall without recent landing)"
									warn(string.format("%s flagged: %s. VelY: %.2f. LastLanded: %.2f ago. Violations before: %.1f, after +1: %.1f", player.Name, baseDiagnostic, verticalVelocity, tick()-(playerFallData[player.UserId].lastLandedTime or 0) , playerData[player.UserId].violations, playerData[player.UserId].violations + 1))

									local targetPositionY = (playerFallData[player.UserId].lastKnownGroundPosition and playerFallData[player.UserId].lastKnownGroundPosition.Y) or (currentHeight - 10)
									local targetPosition = Vector3.new(rootPart.Position.X, targetPositionY, rootPart.Position.Z)
									local currentOrientationY = select(2, rootPart.CFrame:ToOrientation())
									rootPart.CFrame = CFrame.new(targetPosition) * CFrame.Angles(0, currentOrientationY, 0)
									rootPart.AssemblyLinearVelocity = Vector3.new(0, -30, 0); rootPart.AssemblyAngularVelocity = Vector3.new(0,0,0)
									humanoid:ChangeState(Enum.HumanoidStateType.Freefall)

									if incrementAndCheckKick(player, 1, "S2", baseDiagnostic) then return end
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

					while allEntitiesValid(character, humanoid, rootPart, player) and playerData[player.UserId] do
						task.wait(CFRAME_CHECK_INTERVAL)
						if not (allEntitiesValid(character, humanoid, rootPart, player) and playerData[player.UserId]) then break end

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
							lastPosition = currentPosition; previousTick = currentTick; previousHumanoidStateType = currentHumanoidStateType
							justLandedGrace = false
							playerData[player.UserId].violations = math.max(0, playerData[player.UserId].violations - 0.5)
							continue
						end

						if actualDeltaTime <= 1/1000 then
							lastPosition = currentPosition ; previousTick = currentTick ; previousHumanoidStateType = currentHumanoidStateType
							continue
						end

						local displacement = currentPosition - lastPosition
						local speedToEvaluate; local currentMaxAllowedSpeedToUse

						if currentHumanoidStateType == Enum.HumanoidStateType.Freefall or currentHumanoidStateType == Enum.HumanoidStateType.Flying then
							local horizontalDisplacement = Vector3.new(displacement.X, 0, displacement.Z)
							speedToEvaluate = horizontalDisplacement.Magnitude / actualDeltaTime
							currentMaxAllowedSpeedToUse = TAC.MAX_ALLOWED_GROUND_SPEED * MAX_ALLOWED_AIR_HORIZONTAL_SPEED_FACTOR
						else
							speedToEvaluate = displacement.Magnitude / actualDeltaTime
							currentMaxAllowedSpeedToUse = TAC.MAX_ALLOWED_GROUND_SPEED
						end

						if playerData[player.UserId] and playerData[player.UserId].isSeated then
							currentMaxAllowedSpeedToUse = currentMaxAllowedSpeedToUse * HUMANOID_SITTING_MULTIPLIER
						end

						previousTick = currentTick

						currentHumanoidStateType = humanoid:GetState()
						if speedToEvaluate > currentMaxAllowedSpeedToUse + 2 and currentHumanoidStateType ~= Enum.HumanoidStateType.Swimming then
							local kickReasonSuffix = ""
							if playerData[player.UserId] and playerData[player.UserId].isSeated then kickReasonSuffix = "S"
							elseif currentHumanoidStateType == Enum.HumanoidStateType.Freefall or currentHumanoidStateType == Enum.HumanoidStateType.Flying then kickReasonSuffix = "H"
							elseif previousHumanoidStateType == Enum.HumanoidStateType.Freefall and currentHumanoidStateType ~= Enum.HumanoidStateType.Freefall then kickReasonSuffix = "PS"
							else kickReasonSuffix = "G" end
							local fullKickCode = "S1" .. kickReasonSuffix

							local baseDiagnostic = string.format("Speed violation (%.2f > %.2f studs/s). State: %s, Δt: %.3fs", speedToEvaluate, currentMaxAllowedSpeedToUse, currentHumanoidStateType.Name, actualDeltaTime)
							warn(string.format("%s flagged: %s. Violations before: %.1f, after +1: %.1f", player.Name, baseDiagnostic, playerData[player.UserId].violations, playerData[player.UserId].violations + 1))

							humanoid.WalkSpeed = 0; task.wait(1); humanoid.WalkSpeed = 16

							if incrementAndCheckKick(player, 1, fullKickCode, baseDiagnostic) then break end

							local currentOrientationY = select(2, rootPart.CFrame:ToOrientation())
							rootPart.CFrame = CFrame.new(lastPosition) * CFrame.Angles(0, currentOrientationY, 0)
							rootPart.AssemblyLinearVelocity = Vector3.new(0,0,0); rootPart.AssemblyAngularVelocity = Vector3.new(0,0,0)
							currentPosition = lastPosition
						else
							playerData[player.UserId].violations = math.max(0, playerData[player.UserId].violations - 0.02)
						end
						lastPosition = currentPosition
						previousHumanoidStateType = currentHumanoidStateType
					end
				end)
			end
		end)
	end

	local function onPlayerRemoving(player)
		if playerData[player.UserId] then
			playerData[player.UserId] = nil
		end
		if playerFallData[player.UserId] then
			playerFallData[player.UserId] = nil
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	RunService.Heartbeat:Connect(function()
		for _, player in ipairs(Players:GetPlayers()) do
			if playerData[player.UserId] and player.Character then
				local data = playerData[player.UserId]
				local humanoid = player.Character:FindFirstChildOfClass("Humanoid")

				if humanoid then
					local isCurrentlySeated = humanoid.SeatPart ~= nil

					if data.isSeated ~= isCurrentlySeated then
						data.isSeated = isCurrentlySeated
					end
				end
			end
		end
	end)

	print("TAC has been initialized and is running.")
end

return TAC
