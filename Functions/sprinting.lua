--// Sprinting tab: stamina features (Infinite Stamina, Legit Stamina View, Always Sprint).

local Sprint = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local Network = require(ReplicatedStorage.Modules.Network.Network)
local Sprinting = require(ReplicatedStorage.Systems.Character.Game.Sprinting)

local env = (typeof(getgenv) == "function" and getgenv()) or _G

local Connections = {}

local AlwaysSprintState = { Enabled = false }
local InfStaminaState = { Enabled = false }
local LegitViewState = { Enabled = false, Screen = nil, Label = nil }

local virtual = 0
local virtualTimer = 0
local virtualPenalty = false
local virtualExhausted = false
local baseline = 0
local prevCap = nil
local capBaseVirtual = nil

local function virtualMax()
	return Sprinting.StaminaCap or Sprinting.MaxStamina or 100
end

local function virtualMin()
	return Sprinting.MinStamina or 0
end

local originalGrantStamina = (function()
	if not env.__ForsakenGrantOriginal then
		env.__ForsakenGrantOriginal = function(amount)
			Sprinting.Stamina = math.min((Sprinting.Stamina or 0) + amount, Sprinting.MaxStamina)
		end
	end
	return env.__ForsakenGrantOriginal
end)()

local wrappedGrantStamina = function(amount)
	originalGrantStamina(amount)
	virtual = math.min(virtual + amount, virtualMax())
end

pcall(function()
	Network.SetConnection("GrantStamina", "REMOTE_EVENT", wrappedGrantStamina)
end)

local function startSprint()
	if not Sprinting.CanSprint or Sprinting.IsSprinting then
		return
	end
	if (Sprinting.Stamina or 0) <= (Sprinting.MinStamina or 0) then
		return
	end
	Sprinting.IsSprinting = true
	if Sprinting.__sprintedEvent then
		Sprinting.__sprintedEvent:Fire(true)
	end
	pcall(function()
		Sprinting:Toggle(true)
	end)
end

local function stopSprint()
	if not Sprinting.IsSprinting then
		return
	end
	Sprinting.IsSprinting = false
	if Sprinting.__sprintedEvent then
		Sprinting.__sprintedEvent:Fire(false)
	end
	pcall(function()
		Sprinting:Toggle(false)
	end)
end

function Sprint:SetAlwaysSprint(enabled)
	if AlwaysSprintState.Enabled == enabled then
		return
	end
	AlwaysSprintState.Enabled = enabled

	if enabled then
		startSprint()
	else
		stopSprint()
	end
end

function Sprint:SetInfiniteStamina(enabled)
	InfStaminaState.Enabled = enabled
end

function Sprint:SetShowLegitStaminaView(enabled)
	LegitViewState.Enabled = enabled

	if enabled then
		local gui = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5)
		if not gui then
			return
		end

		local screen = Instance.new("ScreenGui")
		screen.Name = "ForsakeniumSecondaryStamina"
		screen.ResetOnSpawn = false
		screen.IgnoreGuiInset = true
		screen.DisplayOrder = 10000
		screen.Parent = gui

		local number = Instance.new("TextLabel")
		number.Name = "SecondaryStaminaNumber"
		number.AnchorPoint = Vector2.new(0.5, 0.5)
		number.Position = UDim2.fromScale(0.5, 0.5)
		number.Size = UDim2.new(0, 220, 0, 64)
		number.BackgroundTransparency = 1
		number.Font = Enum.Font.GothamBold
		number.TextColor3 = Color3.fromRGB(220, 230, 240)
		number.TextStrokeColor3 = Color3.fromRGB(20, 24, 32)
		number.TextStrokeTransparency = 0.25
		number.TextSize = 28
		number.TextXAlignment = Enum.TextXAlignment.Center
		number.TextYAlignment = Enum.TextYAlignment.Center
		number.Parent = screen

		LegitViewState.Screen = screen
		LegitViewState.Label = number

		virtual = Sprinting.Stamina or virtualMax()
		virtualTimer = Sprinting.timeUntilStaminaRecovers or 0
	else
		if LegitViewState.Screen then
			LegitViewState.Screen:Destroy()
		end
		LegitViewState.Screen = nil
		LegitViewState.Label = nil
	end
end

table.insert(Connections, RunService.Heartbeat:Connect(function(dt)
	if AlwaysSprintState.Enabled and not Sprinting.IsSprinting then
		local floor = Sprinting.MinStamina or 0
		if (Sprinting.Stamina or 0) > floor then
			startSprint()
		end
	end

	local maxStamina = virtualMax()
	local minStamina = virtualMin()
	local realStamina = Sprinting.Stamina or maxStamina
	local frozen = Sprinting:IsStaminaFrozen()

	if InfStaminaState.Enabled then
		Sprinting.Stamina = maxStamina
		baseline = maxStamina
	end

	if not LegitViewState.Enabled then
		return
	end

	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")

	local realDraining = not frozen
		and char ~= nil
		and char.Parent ~= nil
		and root ~= nil
		and not root.Anchored
		and Sprinting.IsSprinting
		and realStamina > minStamina
		and root.AssemblyLinearVelocity.Magnitude > 0.4
		and Sprinting.CanSprint
		and not Sprinting.StaminaLossDisabled
		and char.Parent.Name ~= "Spectating"

	local expectedReal = baseline + (realDraining and -(Sprinting.StaminaLoss or 10) * dt or 0)
	local external = realStamina - expectedReal

	if math.abs(external) > 0.005 then
		virtual = math.clamp(virtual + external, minStamina, maxStamina)
	end

	local cap = Sprinting.StaminaCap
	if cap ~= prevCap then
		prevCap = cap
		if cap ~= nil then
			capBaseVirtual = virtual + math.max(cap - realStamina, 0)
		else
			capBaseVirtual = nil
		end
	end

	if not InfStaminaState.Enabled then
		virtual = realStamina
		baseline = realStamina
	end

	virtual = math.clamp(virtual, minStamina, maxStamina)

	if frozen then
		if LegitViewState.Label then
			LegitViewState.Label.Text = tostring(math.round(virtual)) .. "/" .. tostring(math.round(maxStamina))
		end
		return
	end

	if not char or not char.Parent then
		return
	end

	local canDrain = root ~= nil
		and not root.Anchored
		and Sprinting.IsSprinting
		and not virtualExhausted
		and virtual > minStamina
		and root.AssemblyLinearVelocity.Magnitude > 0.4
		and Sprinting.CanSprint
		and not Sprinting.StaminaLossDisabled
		and char.Parent.Name ~= "Spectating"

	if canDrain then
		virtualTimer = math.clamp(virtualTimer + dt * 0.05, 0.2, 2)
		virtual = math.clamp(virtual - (Sprinting.StaminaLoss or 10) * dt, minStamina, maxStamina)

		if virtual <= minStamina then
			virtualExhausted = true
			virtualTimer = 2
			virtualPenalty = true
		end
	else
		if not Sprinting.IsSprinting then
			virtualExhausted = false
		end

		local timerFloor = realDraining and 0 or (Sprinting.timeUntilStaminaRecovers or 0)
		virtualTimer = math.max(virtualTimer - dt, timerFloor)

		if virtualTimer <= 0 then
			virtualPenalty = false
		end

		if virtualTimer <= 0
			and not virtualPenalty
			and not realDraining
			and not char:GetAttribute("AbilityStaminaOverride")
			and not char:GetAttribute("StaminaPenaltyActive")
		then
			local regenCeiling = capBaseVirtual or maxStamina
			if regenCeiling > maxStamina then
				regenCeiling = maxStamina
			end
			virtual = math.clamp(virtual + (Sprinting.StaminaGain or 20) * dt, minStamina, regenCeiling)
		end
	end

	if LegitViewState.Label then
		LegitViewState.Label.Text = tostring(math.round(virtual)) .. "/" .. tostring(math.round(maxStamina))
		LegitViewState.Label.TextColor3 = virtual / maxStamina < 0.25
			and Color3.fromRGB(255, 105, 105)
			or Color3.fromRGB(220, 230, 240)
	end
end))

table.insert(Connections, LocalPlayer.CharacterAdded:Connect(function(char)
	virtual = virtualMax()
	virtualTimer = 0
	virtualPenalty = false
	virtualExhausted = false
end))

function Sprint:Unload()
	AlwaysSprintState.Enabled = false
	InfStaminaState.Enabled = false
	LegitViewState.Enabled = false

	stopSprint()

	if LegitViewState.Screen then
		LegitViewState.Screen:Destroy()
	end
	LegitViewState.Screen = nil
	LegitViewState.Label = nil

	pcall(function()
		Network.SetConnection("GrantStamina", "REMOTE_EVENT", originalGrantStamina)
	end)

	for _, conn in ipairs(Connections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	table.clear(Connections)
end

function Sprint.Build(Tab, ctx)
	Tab:Section({ Title = "Stamina", Icon = "battery-charging", TextSize = 15 })

	Tab:Toggle({
		Title = "Infinite Stamina",
		Desc = "Keep stamina pinned at maximum.",
		Value = false,
		Callback = function(value)
			Sprint:SetInfiniteStamina(value)
		end,
	})

	Tab:Toggle({
		Title = "Show Legit Stamina View",
		Desc = "Show a second, spoofed stamina counter.",
		Value = false,
		Callback = function(value)
			Sprint:SetShowLegitStaminaView(value)
		end,
	})

	Tab:Section({ Title = "Sprinting", Icon = "footprints", TextSize = 15 })

	Tab:Toggle({
		Title = "Always Sprint",
		Desc = "Automatically sprint whenever stamina allows.",
		Value = false,
		Callback = function(value)
			Sprint:SetAlwaysSprint(value)
		end,
	})
end

return Sprint
