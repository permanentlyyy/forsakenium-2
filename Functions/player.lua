--// Player tab: character features (God Mode, Invisibility, Silent Footsteps).

local Player = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local Network = require(ReplicatedStorage.Modules.Network.Network)
local CharRep = require(ReplicatedStorage.Systems.Player.Game.CharacterReplication)

local env = (typeof(getgenv) == "function" and getgenv()) or _G

local Running = true
local Connections = {}

local GodState = env.__ForsakenGodState
if not GodState then
	GodState = { Enabled = false }
	env.__ForsakenGodState = GodState
end
GodState.Enabled = false

local LegacyParkState = env.__ForsakenParkState
if LegacyParkState then
	LegacyParkState.Enabled = false
end

local GOD = {
	fakeY = -1000,
	interval = 0,
	stillTime = 0,
	velThreshold = 0.001, -- effectively zero: a resting character reads ~0.0008
	stopCooldown = 0,
	tpPause = 0.25,
	dropShield = 40,
	refreshDist = 12,
	maxDist = 250,
}

local originalFire = (function()
	if not env.__ForsakenOriginalFire then
		env.__ForsakenOriginalFire = Network.FireServerConnection
	end
	return env.__ForsakenOriginalFire
end)()

local godAcc, godStillFor, godMotionCooldown = 0, 0, 0
local godLastPos, godLastSafe, godLastChar = nil, nil, nil
local godExternalUntil, godHoldUntil = 0, 0
local godStill = false

Network.FireServerConnection = function(self, name, typ, ...)
	if GodState.Enabled and name == "UpdateCharacterPosition" then
		return
	end
	return originalFire(self, name, typ, ...)
end

local function godGetParts()
	local ch = LocalPlayer.Character
	if not ch then
		return nil
	end
	local hum = ch:FindFirstChildOfClass("Humanoid")
	local root = ch.PrimaryPart or ch:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then
		return nil
	end
	return ch, hum, root
end

local function godIsStill(hum, root)
	if hum.FloorMaterial == Enum.Material.Air then
		return false
	end
	if hum.MoveDirection.Magnitude > 0.01 then
		return false
	end
	if root.AssemblyLinearVelocity.Magnitude > GOD.velThreshold then
		return false
	end
	return true
end

local function godSendPacket(hum, root)
	if not godIsStill(hum, root) then
		return
	end
	pcall(function()
		local buf = CharRep.Serialize(root.CFrame, root.AssemblyLinearVelocity)
		if typeof(buf) == "buffer" and buffer.len(buf) >= 12 then
			buffer.writef32(buf, 4, GOD.fakeY)
		end
		originalFire(Network, "UpdateCharacterPosition", "UREMOTE_EVENT", buf)
	end)
end

local FootstepsState = { Enabled = false }

local function applyFootstepsMuted(char)
	if not char then
		return
	end
	if FootstepsState.Enabled then
		char:SetAttribute("FootstepsMuted", true)
	else
		char:SetAttribute("FootstepsMuted", nil)
	end
end

local INVIS_ANIMATION_ID = "rbxassetid://75804462760596"

local InvisState = {
	Desired = false,
	Active = false,
	Track = nil,
	Animation = nil,
	Watchdog = nil,
}

local function stopInvisibility()
	if not InvisState.Active then
		return
	end
	InvisState.Active = false

	if InvisState.Track then
		pcall(function()
			InvisState.Track:Stop()
			if InvisState.Track.Destroy then
				InvisState.Track:Destroy()
			end
		end)
		InvisState.Track = nil
	end

	if InvisState.Animation then
		pcall(function()
			InvisState.Animation:Destroy()
		end)
		InvisState.Animation = nil
	end

	if InvisState.Watchdog then
		InvisState.Watchdog:Disconnect()
		InvisState.Watchdog = nil
	end
end

local function setupInvisibility(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = INVIS_ANIMATION_ID

	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		return
	end

	track.Looped = true
	track.Priority = Enum.AnimationPriority.Action4
	track:Play()
	track:AdjustSpeed(0)

	InvisState.Track = track
	InvisState.Animation = animation
	InvisState.Active = true

	InvisState.Watchdog = RunService.Heartbeat:Connect(function()
		if InvisState.Track and not InvisState.Track.IsPlaying then
			InvisState.Track:Play()
			InvisState.Track:AdjustSpeed(0)
		end
	end)
end

local function isInRound()
	local char = LocalPlayer.Character
	local parent = char and char.Parent
	if not parent then
		return false
	end
	local name = parent.Name
	return name == "Survivors" or name == "Killers"
end

function Player:SetGodMode(enabled)
	GodState.Enabled = enabled

	if enabled then
		-- Start from a clean slate. Previously these only reset when the character changed,
		-- so enabling while already standing still could be held back by stale state from
		-- earlier movement (the jump/tp pause and the send hold-off).
		godLastChar, godLastPos, godLastSafe = nil, nil, nil
		godStillFor, godAcc = 0, 0
		godMotionCooldown = 0
		godExternalUntil, godHoldUntil = 0, 0
		godStill = false
	end
end

function Player:SetInvisibility(enabled)
	InvisState.Desired = enabled

	if not enabled then
		stopInvisibility()
		return
	end

	if isInRound() then
		local char = LocalPlayer.Character
		if char then
			setupInvisibility(char)
		end
	end
end

function Player:SetSilentFootsteps(enabled)
	if FootstepsState.Enabled == enabled then
		return
	end
	FootstepsState.Enabled = enabled
	applyFootstepsMuted(LocalPlayer.Character)
end

table.insert(Connections, RunService.Heartbeat:Connect(function(dt)
	if GodState.Enabled then
		pcall(function()
			local ch, hum, root = godGetParts()
			if not ch then
				return
			end

			if ch ~= godLastChar then
				godLastChar = ch
				godLastPos, godLastSafe = nil, nil
				godStillFor, godAcc = 0, 0
				godMotionCooldown = GOD.stopCooldown
			end

			local pos = root.Position
			if godLastPos and (pos - godLastPos).Magnitude > 4 then
				godExternalUntil = os.clock() + GOD.tpPause
			end
			godLastPos = pos

			local paused = root.Anchored or os.clock() < godExternalUntil

			if godLastSafe and godStill and not paused and (godLastSafe.Y - pos.Y) > GOD.dropShield then
				root.AssemblyLinearVelocity = Vector3.zero
				root.CFrame = CFrame.new(godLastSafe) * (root.CFrame - root.CFrame.Position)
				pos = godLastSafe
			end
			if not paused then
				godLastSafe = pos
			end

			local movingInput = hum.MoveDirection.Magnitude > 0.01
			godMotionCooldown = movingInput and GOD.stopCooldown or (godMotionCooldown - dt)

			if not paused and ch:HasTag("Replicating") and not movingInput and godMotionCooldown <= 0 then
				if godIsStill(hum, root) then
					godStillFor += dt
				else
					godStillFor = 0
				end
				godStill = godStillFor >= GOD.stillTime

				if godStillFor >= GOD.stillTime and os.clock() >= godHoldUntil then
					local qh = ch:FindFirstChild("QueryHitbox")
					local needs = true
					if qh then
						local qpos = qh.Position
						needs = (qpos - pos).Magnitude <= GOD.maxDist
							and (math.abs(qpos.Y - GOD.fakeY) > 2
								or (Vector3.new(qpos.X, 0, qpos.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude > GOD.refreshDist)
					end
					if needs then
						godAcc += dt
						if godAcc >= GOD.interval then
							godAcc = 0
							godSendPacket(hum, root)
							godHoldUntil = os.clock() + 0.3
						end
					else
						godAcc = 0
					end
				else
					godAcc = 0
				end
			else
				godStillFor = 0
				godStill = false
				godAcc = 0
			end
		end)
	end
end))

table.insert(Connections, LocalPlayer.CharacterAdded:Connect(function(char)
	task.delay(0.1, applyFootstepsMuted, char)
end))

task.spawn(function()
	while Running do
		task.wait(0.25)
		pcall(function()
			local inRound = isInRound()

			if InvisState.Desired and inRound and not InvisState.Active then
				local char = LocalPlayer.Character
				if char then
					setupInvisibility(char)
				end
			elseif (not InvisState.Desired or not inRound) and InvisState.Active then
				stopInvisibility()
			end
		end)
	end
end)

function Player:Unload()
	Running = false
	GodState.Enabled = false
	FootstepsState.Enabled = false
	stopInvisibility()
	applyFootstepsMuted(LocalPlayer.Character)

	Network.FireServerConnection = originalFire

	for _, conn in ipairs(Connections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	table.clear(Connections)
end

function Player.Build(Tab, ctx)
	Tab:Section({ Title = "Character", Icon = "user-round", TextSize = 15 })

	Tab:Toggle({
		Title = "God Mode",
		Desc = "Block position replication while standing still.",
		Value = false,
		Callback = function(value)
			Player:SetGodMode(value)
		end,
	})

	Tab:Toggle({
		Title = "Invisibility",
		Desc = "Freeze a hidden animation to go invisible during a round.",
		Value = false,
		Callback = function(value)
			Player:SetInvisibility(value)
		end,
	})

	Tab:Toggle({
		Title = "Silent Footsteps",
		Desc = "Mute your character's footstep sounds.",
		Value = false,
		Callback = function(value)
			Player:SetSilentFootsteps(value)
		end,
	})
end

return Player
