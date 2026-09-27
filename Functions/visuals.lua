--// Visuals tab.
--//
--// Implemented features:
--//   Killer ESP   - Roblox Highlight on each killer character
--//   Show Killer Name   - BillboardGui name above the killer
--//   Show Killer Health - BillboardGui health bar above the killer
--//
--// Roblox only renders one Highlight per model. Some rounds add their own Highlight
--// to the killer (and remove it later); when theirs is removed ours can stop showing
--// until it is re-added. So whenever a foreign Highlight leaves a killer, we re-parent
--// ours to force it to render again.

local Visuals = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local KILLER_FOLDER = "Killers"
local SCAN_INTERVAL = 0.25
local HIGHLIGHT_NAME = "ForsakeniumKillerESP"
local BILLBOARD_NAME = "ForsakeniumKillerInfo"

-- Nothing is drawn past this distance (studs). Shared by every ESP in this module.
local MAX_DISTANCE = 1000

local State = {
	KillerESP = false,
	ShowName = false,
	ShowHealth = false,
	Color = Color3.fromHex("ff3232"),
	FillTransparency = 0.7,
	OutlineTransparency = 0.3,
}

local tracked = {}
local connections = {}
local scanClock = 0

local killerFolder = nil
local lastRecursiveSearch = 0

-- The round containers are nested (e.g. workspace.Players.Killers), so resolve the
-- folder dynamically and cache it until it disappears.
local function getKillerFolder()
	if killerFolder and killerFolder.Parent then
		return killerFolder
	end

	killerFolder = nil

	local direct = workspace:FindFirstChild(KILLER_FOLDER)
	if direct then
		killerFolder = direct
		return killerFolder
	end

	local players = workspace:FindFirstChild("Players")
	if players then
		local nested = players:FindFirstChild(KILLER_FOLDER)
		if nested then
			killerFolder = nested
			return killerFolder
		end
	end

	-- Recursive search is the expensive fallback, so throttle it.
	local now = os.clock()
	if now - lastRecursiveSearch >= 2 then
		lastRecursiveSearch = now
		local found = workspace:FindFirstChild(KILLER_FOLDER, true)
		if found then
			killerFolder = found
			return killerFolder
		end
	end

	return nil
end

local function isActive()
	return State.KillerESP or State.ShowName or State.ShowHealth
end

local function getReferencePosition()
	local character = LocalPlayer.Character
	local root = character
		and (character.PrimaryPart or character:FindFirstChild("HumanoidRootPart"))

	if root then
		return root.Position
	end

	local camera = workspace.CurrentCamera
	return camera and camera.CFrame.Position or nil
end

local function isWithinRange(model)
	local reference = getReferencePosition()
	if not reference then
		return true
	end

	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not root then
		return true
	end

	return (root.Position - reference).Magnitude <= MAX_DISTANCE
end

local function style(highlight)
	highlight.FillColor = State.Color
	highlight.OutlineColor = State.Color
	highlight.FillTransparency = State.FillTransparency
	highlight.OutlineTransparency = State.OutlineTransparency
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
end

local function countForeignHighlights(model, ours)
	local count = 0
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("Highlight") and child ~= ours then
			count += 1
		end
	end
	return count
end

-- Force Roblox to render our Highlight again by re-adding it to the model, making it
-- the most recently applied Highlight.
local function refresh(entry)
	local highlight = entry.highlight
	local model = entry.model

	if not highlight or not highlight.Parent or not model.Parent then
		return
	end

	highlight.Enabled = false
	highlight.Parent = nil
	highlight.Parent = model
	highlight.Enabled = State.KillerESP and isWithinRange(model)
end

local function watch(entry)
	local model = entry.model
	local ours = entry.highlight

	entry.onAdded = model.ChildAdded:Connect(function(child)
		if child:IsA("Highlight") and child ~= ours then
			entry.foreign += 1
		end
	end)

	entry.onRemoved = model.ChildRemoved:Connect(function(child)
		if child:IsA("Highlight") and child ~= ours then
			entry.foreign = math.max(entry.foreign - 1, 0)
			task.defer(refresh, entry)
		end
	end)
end

local function unwatch(entry)
	if entry.onAdded then
		entry.onAdded:Disconnect()
	end
	if entry.onRemoved then
		entry.onRemoved:Disconnect()
	end
end

local function createBillboard(model)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = BILLBOARD_NAME
	billboard.Adornee = model
	billboard.Size = UDim2.fromOffset(240, 20)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = MAX_DISTANCE
	billboard.ResetOnSpawn = false
	billboard.LightInfluence = 0
	billboard.Enabled = false
	billboard.Parent = model

	local label = Instance.new("TextLabel")
	label.Name = "Info"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.5
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Text = ""
	label.Parent = billboard

	return billboard, label
end

local function updateBillboard(entry)
	local billboard = entry.billboard
	if not billboard or not billboard.Parent then
		return
	end

	if not (State.ShowName or State.ShowHealth) then
		billboard.Enabled = false
		return
	end

	local model = entry.model
	local adornee = model:FindFirstChild("Head")
		or model:FindFirstChild("HumanoidRootPart")
		or model.PrimaryPart

	if adornee and billboard.Adornee ~= adornee then
		billboard.Adornee = adornee
	end

	billboard.Enabled = true

	local label = entry.label
	if not label then
		return
	end

	local parts = {}
	if State.ShowName then
		table.insert(parts, model.Name)
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local ratio = 1

	if State.ShowHealth and humanoid then
		local maxHealth = math.max(humanoid.MaxHealth, 1)
		ratio = math.clamp(humanoid.Health / maxHealth, 0, 1)
		table.insert(parts, math.floor(humanoid.Health + 0.5) .. "/" .. math.floor(maxHealth + 0.5))
	end

	label.Text = table.concat(parts, " | ")
	label.TextColor3 = ratio < 0.25
		and Color3.fromRGB(255, 90, 90)
		or Color3.fromRGB(255, 255, 255)
end

local function updateEntry(entry)
	if entry.highlight and entry.highlight.Parent then
		entry.highlight.Enabled = State.KillerESP and isWithinRange(entry.model)
	end
	updateBillboard(entry)
end

local function applyEntry(entry)
	if entry.highlight and entry.highlight.Parent then
		style(entry.highlight)
	end
	updateEntry(entry)
end

local function applyAll()
	for _, entry in pairs(tracked) do
		applyEntry(entry)
	end
end

local function createEntry(model)
	local highlight = Instance.new("Highlight")
	highlight.Name = HIGHLIGHT_NAME
	highlight.Adornee = model
	highlight.Parent = model
	style(highlight)

	local billboard, label = createBillboard(model)

	local entry = {
		model = model,
		highlight = highlight,
		billboard = billboard,
		label = label,
		foreign = countForeignHighlights(model, highlight),
	}

	watch(entry)
	applyEntry(entry)
	return entry
end

local function destroyEntry(entry)
	unwatch(entry)
	if entry.highlight then
		entry.highlight:Destroy()
	end
	if entry.billboard then
		entry.billboard:Destroy()
	end
end

local function clearAll()
	for model, entry in pairs(tracked) do
		destroyEntry(entry)
		tracked[model] = nil
	end
end

local function scan()
	local folder = getKillerFolder()
	local seen = {}

	if folder then
		for _, model in ipairs(folder:GetChildren()) do
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid and model ~= LocalPlayer.Character then
				seen[model] = true

				local entry = tracked[model]
				local broken = entry
					and (not entry.highlight or not entry.highlight.Parent
						or not entry.billboard or not entry.billboard.Parent)

				if not entry then
					tracked[model] = createEntry(model)
				elseif broken then
					-- Our instances were removed along with the game's; rebuild them.
					destroyEntry(entry)
					tracked[model] = createEntry(model)
				end
			end
		end
	end

	for model, entry in pairs(tracked) do
		if not seen[model] then
			destroyEntry(entry)
			tracked[model] = nil
		end
	end
end

table.insert(connections, RunService.Heartbeat:Connect(function(dt)
	if not isActive() then
		return
	end

	for _, entry in pairs(tracked) do
		pcall(updateEntry, entry)
	end

	scanClock += dt
	if scanClock < SCAN_INTERVAL then
		return
	end
	scanClock = 0

	pcall(scan)
end))

local function afterToggle(enabled)
	if enabled then
		scan()
	end
	applyAll()
	if not isActive() then
		clearAll()
	end
end

function Visuals:SetKillerESP(enabled)
	State.KillerESP = enabled
	afterToggle(enabled)
end

function Visuals:SetShowName(enabled)
	State.ShowName = enabled
	afterToggle(enabled)
end

function Visuals:SetShowHealth(enabled)
	State.ShowHealth = enabled
	afterToggle(enabled)
end

function Visuals:SetColor(color)
	State.Color = color
	applyAll()
end

function Visuals:SetFillTransparency(value)
	State.FillTransparency = value
	applyAll()
end

function Visuals:SetOutlineTransparency(value)
	State.OutlineTransparency = value
	applyAll()
end

function Visuals.Build(Tab, ctx)
	Tab:Section({ Title = "Killer", Icon = "skull", TextSize = 15 })

	Tab:Toggle({
		Title = "Killer ESP",
		Desc = "Highlight killers through walls.",
		Value = false,
		Callback = function(value)
			Visuals:SetKillerESP(value)
		end,
	})

	Tab:Toggle({
		Title = "Show Killer Name",
		Desc = "Draw the killer's name above them.",
		Value = false,
		Callback = function(value)
			Visuals:SetShowName(value)
		end,
	})

	Tab:Toggle({
		Title = "Show Killer Health",
		Desc = "Draw the killer's health bar.",
		Value = false,
		Callback = function(value)
			Visuals:SetShowHealth(value)
		end,
	})

	Tab:Slider({
		Title = "Fill Transparency",
		Desc = "Transparency of the killer highlight fill.",
		Value = { Default = 0.7, Min = 0, Max = 1 },
		Step = 0.01,
		Callback = function(value)
			Visuals:SetFillTransparency(value)
		end,
	})

	Tab:Slider({
		Title = "Outline Transparency",
		Desc = "Transparency of the killer highlight outline.",
		Value = { Default = 0.3, Min = 0, Max = 1 },
		Step = 0.01,
		Callback = function(value)
			Visuals:SetOutlineTransparency(value)
		end,
	})

	Tab:Colorpicker({
		Title = "Killer Color",
		Desc = "Highlight color used for killers.",
		Default = Color3.fromHex("ff3232"),
		Callback = function(color)
			Visuals:SetColor(color)
		end,
	})

	Tab:Section({ Title = "Survivor", Icon = "users", TextSize = 15 })

	Tab:Toggle({
		Title = "Survivor ESP",
		Desc = "Highlight survivors through walls.",
		Value = false,
	})

	Tab:Toggle({
		Title = "Show Survivor Name",
		Desc = "Draw the survivor's name above them.",
		Value = false,
	})

	Tab:Toggle({
		Title = "Show Survivor Health",
		Desc = "Draw the survivor's health bar.",
		Value = false,
	})

	Tab:Slider({
		Title = "Fill Transparency",
		Desc = "Transparency of the survivor highlight fill.",
		Value = { Default = 0.7, Min = 0, Max = 1 },
		Step = 0.01,
	})

	Tab:Slider({
		Title = "Outline Transparency",
		Desc = "Transparency of the survivor highlight outline.",
		Value = { Default = 0.3, Min = 0, Max = 1 },
		Step = 0.01,
	})

	Tab:Colorpicker({
		Title = "Survivor Color",
		Desc = "Highlight color used for survivors.",
		Default = Color3.fromHex("32ff32"),
	})

	Tab:Section({ Title = "Miscellaneous", Icon = "box", TextSize = 15 })

	Tab:Toggle({
		Title = "Generator ESP",
		Desc = "Highlight generators through walls.",
		Value = false,
	})

	Tab:Toggle({
		Title = "Item ESP",
		Desc = "Highlight items through walls.",
		Value = false,
	})

	Tab:Toggle({
		Title = "Tripwire ESP",
		Desc = "Highlight tripwires through walls.",
		Value = false,
	})

	Tab:Toggle({
		Title = "Subspace Tripmine ESP",
		Desc = "Highlight subspace tripmines through walls.",
		Value = false,
	})

	Tab:Toggle({
		Title = "Ritual ESP",
		Desc = "Highlight ritual objects through walls.",
		Value = false,
	})

	Tab:Toggle({
		Title = "Graffiti ESP",
		Desc = "Highlight graffiti through walls.",
		Value = false,
	})

	Tab:Section({ Title = "Tracers", Icon = "route", TextSize = 15 })

	Tab:Toggle({
		Title = "Killer Tracer",
		Desc = "Draw a tracer to the killer.",
		Value = false,
	})

	Tab:Toggle({
		Title = "Survivor Tracer",
		Desc = "Draw tracers to survivors.",
		Value = false,
	})

	Tab:Toggle({
		Title = "Generator Tracer",
		Desc = "Draw tracers to generators.",
		Value = false,
	})

	Tab:Toggle({
		Title = "Item Tracer",
		Desc = "Draw tracers to items.",
		Value = false,
	})

	Tab:Toggle({
		Title = "Tripwire Tracer",
		Desc = "Draw tracers to tripwires.",
		Value = false,
	})

	Tab:Toggle({
		Title = "Subspace Tripmine Tracer",
		Desc = "Draw tracers to subspace tripmines.",
		Value = false,
	})
end

function Visuals.Unload()
	State.KillerESP = false
	State.ShowName = false
	State.ShowHealth = false
	clearAll()

	for _, conn in ipairs(connections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	table.clear(connections)
end

return Visuals
