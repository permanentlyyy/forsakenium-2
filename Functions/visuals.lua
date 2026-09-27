--// Visuals tab.
--//
--// Killer ESP is the only feature with logic. It uses a Roblox Highlight on each
--// killer character.
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

local State = {
	KillerESP = false,
	Color = Color3.fromHex("ff3232"),
	FillTransparency = 0.7,
	OutlineTransparency = 0.3,
}

local tracked = {}
local connections = {}
local scanClock = 0

local function getKillerFolder()
	return workspace:FindFirstChild(KILLER_FOLDER)
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
	highlight.Enabled = true
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

local function createEntry(model)
	local highlight = Instance.new("Highlight")
	highlight.Name = HIGHLIGHT_NAME
	highlight.Adornee = model
	highlight.Parent = model
	style(highlight)

	local entry = {
		model = model,
		highlight = highlight,
		foreign = countForeignHighlights(model, highlight),
	}

	watch(entry)
	return entry
end

local function destroyEntry(entry)
	unwatch(entry)
	if entry.highlight then
		entry.highlight:Destroy()
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
				if not entry then
					tracked[model] = createEntry(model)
				elseif not entry.highlight or not entry.highlight.Parent then
					-- Our Highlight was destroyed along with the game's; rebuild it.
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

local function restyleAll()
	for _, entry in pairs(tracked) do
		if entry.highlight then
			style(entry.highlight)
		end
	end
end

table.insert(connections, RunService.Heartbeat:Connect(function(dt)
	if not State.KillerESP then
		return
	end

	scanClock += dt
	if scanClock < SCAN_INTERVAL then
		return
	end
	scanClock = 0

	pcall(scan)
end))

function Visuals:SetKillerESP(enabled)
	State.KillerESP = enabled

	if enabled then
		scan()
	else
		clearAll()
	end
end

function Visuals:SetColor(color)
	State.Color = color
	restyleAll()
end

function Visuals:SetFillTransparency(value)
	State.FillTransparency = value
	restyleAll()
end

function Visuals:SetOutlineTransparency(value)
	State.OutlineTransparency = value
	restyleAll()
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
	})

	Tab:Toggle({
		Title = "Show Killer Health",
		Desc = "Draw the killer's health bar.",
		Value = false,
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
	clearAll()

	for _, conn in ipairs(connections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	table.clear(connections)
end

return Visuals
