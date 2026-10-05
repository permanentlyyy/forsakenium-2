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
	fakeY = -1000, -- Y every spoofed position is written to
	interval = 0.1, -- resend the spoofed position this often, in seconds
	respawnDelay = 0.35, -- let a fresh character come up before spoofing again
}

local originalFire = (function()
	if not env.__ForsakenOriginalFire then
		env.__ForsakenOriginalFire = Network.FireServerConnection
	end
	return env.__ForsakenOriginalFire
end)()

local godClock = 0

Network.FireServerConnection = function(self, name, typ, ...)
	if GodState.Enabled and name == "UpdateCharacterPosition" then
		-- While God Mode is on the real position never goes out; only our spoofed
		-- packet below is sent.
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

-- Send the current position with Y forced to GOD.fakeY. X/Z stay real, so the server still
-- has a rough idea where we are but every hit resolves ~1000 studs below the map.
local function godSendPacket(root)
	pcall(function()
		local buf = CharRep.Serialize(root.CFrame, root.AssemblyLinearVelocity)
		if typeof(buf) == "buffer" and buffer.len(buf) >= 12 then
			buffer.writef32(buf, 4, GOD.fakeY)
		end
		originalFire(Network, "UpdateCharacterPosition", "UREMOTE_EVENT", buf)
	end)
end

local function godSpoofNow()
	pcall(function()
		local ch, hum, root = godGetParts()
		if root then
			godSendPacket(root)
		end
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
	godClock = 0

	if enabled then
		-- Spoof straight away instead of waiting for the next tick.
		godSpoofNow()
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
	if not GodState.Enabled then
		return
	end

	godClock += dt
	if godClock < GOD.interval then
		return
	end
	godClock = 0

	pcall(function()
		local ch, hum, root = godGetParts()
		if root then
			godSendPacket(root)
		end
	end)
end))

-- Re-spoof as soon as a new character exists, so respawns and new rounds are covered
-- without having to toggle God Mode again.
table.insert(Connections, LocalPlayer.CharacterAdded:Connect(function()
	if not GodState.Enabled then
		return
	end
	task.delay(GOD.respawnDelay, godSpoofNow)
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
