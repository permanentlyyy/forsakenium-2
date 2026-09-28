--// Visuals tab.
--//
--// Killer ESP and Survivor ESP share one implementation (makeESP):
--//   <target> ESP        - Roblox Highlight on each character
--//   Show <target> Name  - BillboardGui name above the character
--//   Show <target> Health- BillboardGui name + health above the character
--//
--// Roblox only renders one Highlight per model. Some rounds add their own Highlight
--// to a character (and remove it later); when theirs is removed ours can stop showing
--// until it is re-added. So whenever a foreign Highlight leaves a model, we re-parent
--// ours to force it to render again.

local Visuals = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local SCAN_INTERVAL = 0.25

-- Nothing is drawn past this distance (studs). Shared by every ESP in this module.
local MAX_DISTANCE = 1000

local folderCache = {}
local lastRecursiveSearch = 0

-- Round containers are nested (e.g. workspace.Players.Killers), so resolve the folder
-- by name dynamically and cache it until it disappears.
local function getFolder(name)
	local cached = folderCache[name]
	if cached and cached.Parent then
		return cached
	end

	folderCache[name] = nil

	local direct = workspace:FindFirstChild(name)
	if direct then
		folderCache[name] = direct
		return direct
	end

	local players = workspace:FindFirstChild("Players")
	if players then
		local nested = players:FindFirstChild(name)
		if nested then
			folderCache[name] = nested
			return nested
		end
	end

	-- Recursive search is the expensive fallback, so throttle it.
	local now = os.clock()
	if now - lastRecursiveSearch >= 2 then
		lastRecursiveSearch = now
		local found = workspace:FindFirstChild(name, true)
		if found then
			folderCache[name] = found
			return found
		end
	end

	return nil
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

local function isWithinRange(target)
	local reference = getReferencePosition()
	if not reference then
		return true
	end

	local position
	if target:IsA("BasePart") then
		position = target.Position
	else
		local root = target.PrimaryPart or target:FindFirstChild("HumanoidRootPart")
		position = root and root.Position
	end

	if not position then
		return true
	end

	return (position - reference).Magnitude <= MAX_DISTANCE
end

local function makeESP(opts)
	local state = {
		Enabled = false,
		ShowName = false,
		ShowHealth = false,
		Color = opts.color,
		FillTransparency = 0.7,
		OutlineTransparency = 0.3,
	}

	local tracked = {}
	local connections = {}
	local scanClock = 0

	local function isActive()
		return state.Enabled or state.ShowName or state.ShowHealth
	end

	local function style(highlight)
		highlight.FillColor = state.Color
		highlight.OutlineColor = state.Color
		highlight.FillTransparency = state.FillTransparency
		highlight.OutlineTransparency = state.OutlineTransparency
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

	-- Force Roblox to render our Highlight again by re-adding it to the model, making
	-- it the most recently applied Highlight.
	local function refresh(entry)
		local highlight = entry.highlight
		local model = entry.model

		if not highlight or not highlight.Parent or not model.Parent then
			return
		end

		highlight.Enabled = false
		highlight.Parent = nil
		highlight.Parent = model
		highlight.Enabled = state.Enabled and isWithinRange(model)
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
		billboard.Name = opts.billboardName
		billboard.Adornee = model
		billboard.Size = UDim2.fromOffset(240, 18)
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
		label.TextSize = 13
		label.TextColor3 = state.Color
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
		local model = entry.model

		if not billboard or not billboard.Parent then
			return
		end

		if not (state.ShowName or state.ShowHealth) then
			billboard.Enabled = false
			return
		end

		-- Defensive: the billboard must be parented to the model and have a valid
		-- adornee, otherwise it silently renders nothing.
		if billboard.Parent ~= model then
			billboard.Parent = model
		end

		local adornee = model:FindFirstChild("Head")
			or model:FindFirstChild("HumanoidRootPart")
			or model.PrimaryPart

		if adornee then
			if billboard.Adornee ~= adornee then
				billboard.Adornee = adornee
			end
		elseif not billboard.Adornee then
			billboard.Adornee = model
		end

		billboard.Enabled = true

		local label = entry.label
		if not label then
			return
		end

		local parts = {}
		if state.ShowName then
			table.insert(parts, model.Name)
		end

		if state.ShowHealth then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local maxHealth = math.max(humanoid.MaxHealth, 1)
				table.insert(parts, math.floor(humanoid.Health + 0.5) .. "/" .. math.floor(maxHealth + 0.5))
			end
		end

		label.Text = table.concat(parts, " | ")
		label.TextColor3 = state.Color
	end

	local function updateEntry(entry)
		if entry.highlight and entry.highlight.Parent then
			entry.highlight.Enabled = state.Enabled and isWithinRange(entry.model)
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
		highlight.Name = opts.highlightName
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
		local folder = getFolder(opts.folder)
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
			pcall(scan)
		end
		pcall(applyAll)
		if not isActive() then
			clearAll()
		end
	end

	local api = {}

	function api:SetEnabled(enabled)
		state.Enabled = enabled
		afterToggle(enabled)
	end

	function api:SetShowName(enabled)
		state.ShowName = enabled
		afterToggle(enabled)
	end

	function api:SetShowHealth(enabled)
		state.ShowHealth = enabled
		afterToggle(enabled)
	end

	function api:IsEnabled()
		return state.Enabled
	end

	function api:SetColor(color)
		state.Color = color
		applyAll()
	end

	function api:SetFillTransparency(value)
		state.FillTransparency = value
		applyAll()
	end

	function api:SetOutlineTransparency(value)
		state.OutlineTransparency = value
		applyAll()
	end

	function api.Unload()
		state.Enabled = false
		state.ShowName = false
		state.ShowHealth = false
		clearAll()

		for _, conn in ipairs(connections) do
			pcall(function()
				conn:Disconnect()
			end)
		end
		table.clear(connections)
	end

	return api
end

local KillerESP = makeESP({
	folder = "Killers",
	highlightName = "ForsakeniumKillerESP",
	billboardName = "ForsakeniumKillerInfo",
	color = Color3.fromHex("ff3232"),
})

local SurvivorESP = makeESP({
	folder = "Survivors",
	highlightName = "ForsakeniumSurvivorESP",
	billboardName = "ForsakeniumSurvivorInfo",
	color = Color3.fromHex("32ff32"),
})

-- Generator ESP. Real generators are models with a Progress NumberValue whose
-- GeneratorProfile is not "Fake"; fakes must be skipped. Progress runs 0-100 and a
-- generator is done once it reaches 100, at which point we stop highlighting it.
local GeneratorESP = (function()
	local state = {
		Enabled = false,
		Color = Color3.fromHex("ffcc33"),
		FillTransparency = 0.7,
		OutlineTransparency = 0.3,
	}

	local tracked = {}
	local connections = {}
	local scanClock = 0

	local function getContainers()
		local containers = {}
		local map = workspace:FindFirstChild("Map")
		if not map then
			return containers
		end

		local ingame = map:FindFirstChild("Ingame")
		local ingameMap = ingame and ingame:FindFirstChild("Map")
		if ingameMap then
			table.insert(containers, ingameMap)
		end

		local lobby = map:FindFirstChild("Lobby")
		local interactive = lobby and lobby:FindFirstChild("Interactive")
		if interactive then
			table.insert(containers, interactive)
		end

		return containers
	end

	local function isRealGenerator(model)
		if not model:IsA("Model") then
			return false
		end
		if model:GetAttribute("GeneratorProfile") == "Fake" then
			return false
		end
		return model:FindFirstChild("Progress") ~= nil
	end

	local function isCompleted(model)
		local progress = model:FindFirstChild("Progress")
		return progress ~= nil and progress.Value >= 100
	end

	local function style(highlight)
		highlight.FillColor = state.Color
		highlight.OutlineColor = state.Color
		highlight.FillTransparency = state.FillTransparency
		highlight.OutlineTransparency = state.OutlineTransparency
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	end

	local function createEntry(model)
		local highlight = Instance.new("Highlight")
		highlight.Name = "ForsakeniumGeneratorESP"
		highlight.Adornee = model
		highlight.Parent = model
		style(highlight)
		return { model = model, highlight = highlight }
	end

	local function destroyEntry(entry)
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
		local seen = {}

		for _, container in ipairs(getContainers()) do
			for _, model in ipairs(container:GetChildren()) do
				if isRealGenerator(model) and not isCompleted(model) then
					seen[model] = true

					local entry = tracked[model]
					local broken = entry and (not entry.highlight or not entry.highlight.Parent)

					if not entry then
						tracked[model] = createEntry(model)
					elseif broken then
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

	local function updateEntry(entry)
		if entry.highlight and entry.highlight.Parent then
			entry.highlight.Enabled = state.Enabled
				and not isCompleted(entry.model)
				and isWithinRange(entry.model)
		end
	end

	local function applyAll()
		for _, entry in pairs(tracked) do
			pcall(updateEntry, entry)
		end
	end

	table.insert(connections, RunService.Heartbeat:Connect(function(dt)
		if not state.Enabled then
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

	local api = {}

	function api:SetEnabled(enabled)
		state.Enabled = enabled
		if enabled then
			pcall(scan)
		else
			clearAll()
		end
		applyAll()
	end

	function api:SetColor(color)
		state.Color = color
		for _, entry in pairs(tracked) do
			if entry.highlight then
				style(entry.highlight)
			end
		end
	end

	function api.Unload()
		state.Enabled = false
		clearAll()

		for _, conn in ipairs(connections) do
			pcall(function()
				conn:Disconnect()
			end)
		end
		table.clear(connections)
	end

	return api
end)()

-- Item ESP. World items are Tool instances. A Highlight adorning the Tool covers all of
-- its parts, so each item only needs one. Colour is picked from the item's name: medkits
-- are white, colas a light brown, everything else a neutral default. The label sits above
-- the item and shows its name in the same colour as the highlight.
local ItemESP = (function()
	local state = {
		Enabled = false,
		FillTransparency = 0.7,
		OutlineTransparency = 0.3,
	}

	local MEDKIT_COLOR = Color3.fromRGB(255, 255, 255)
	local COLA_COLOR = Color3.fromRGB(205, 133, 63)
	local DEFAULT_COLOR = Color3.fromRGB(120, 200, 255)

	-- Once the player is this close the label just gets in the way of the item itself.
	local TEXT_HIDE_DISTANCE = 16

	local tracked = {}
	local connections = {}
	local scanClock = 0

	local function colorFor(name)
		local lower = string.lower(name)
		if string.find(lower, "medkit", 1, true) then
			return MEDKIT_COLOR
		end
		if string.find(lower, "cola", 1, true) then
			return COLA_COLOR
		end
		return DEFAULT_COLOR
	end

	-- A Tool held or equipped by a player ends up under their character; skip those.
	local function isHeldByCharacter(tool)
		local node = tool.Parent
		while node and node ~= workspace do
			if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then
				return true
			end
			node = node.Parent
		end
		return false
	end

	-- Items can sit anywhere (map spawns, dropped on the ground), so query every Tool
	-- in the workspace rather than only fixed containers.
	local function collectTools()
		local tools = {}

		if type(workspace.QueryDescendants) == "function" then
			local ok, found = pcall(function()
				return workspace:QueryDescendants("Tool")
			end)
			if ok and found then
				for _, tool in ipairs(found) do
					table.insert(tools, tool)
				end
				return tools
			end
		end

		local map = workspace:FindFirstChild("Map")
		if not map then
			return tools
		end

		local ingame = map:FindFirstChild("Ingame")
		local ingameMap = ingame and ingame:FindFirstChild("Map")
		if ingameMap then
			for _, child in ipairs(ingameMap:GetChildren()) do
				if child:IsA("Tool") then
					table.insert(tools, child)
				end
			end
		end

		local lobby = map:FindFirstChild("Lobby")
		local interactive = lobby and lobby:FindFirstChild("Interactive")
		if interactive then
			for _, child in ipairs(interactive:GetChildren()) do
				if child:IsA("Tool") then
					table.insert(tools, child)
				end
			end
		end

		return tools
	end

	-- Every BasePart in the item, used to size the label and pick an anchor part.
	local function collectParts(tool)
		local parts = {}
		for _, descendant in ipairs(tool:GetDescendants()) do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end
		return parts
	end

	local function primaryPart(parts)
		for _, part in ipairs(parts) do
			if part.Name == "ItemRoot" then
				return part
			end
		end
		return parts[1]
	end

	local function styleHighlight(highlight, color)
		highlight.FillColor = color
		highlight.OutlineColor = color
		highlight.FillTransparency = state.FillTransparency
		highlight.OutlineTransparency = state.OutlineTransparency
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	end

	-- Adorning the Tool itself covers every part, so one Highlight per item is enough.
	local function createHighlight(item, color)
		local highlight = Instance.new("Highlight")
		highlight.Name = "ForsakeniumItemESP"
		highlight.Adornee = item
		highlight.Parent = item
		styleHighlight(highlight, color)
		return highlight
	end

	-- Vertical distance from the anchor part up to the top of the item, so the label
	-- always clears the model instead of landing inside or below it.
	local function topOffset(parts, anchor)
		local top = -math.huge
		for _, part in ipairs(parts) do
			local cframe = part.CFrame
			local half = 0.5 * (
				math.abs(cframe.RightVector.Y) * part.Size.X
				+ math.abs(cframe.UpVector.Y) * part.Size.Y
				+ math.abs(cframe.LookVector.Y) * part.Size.Z
			)
			local y = part.Position.Y + half
			if y > top then
				top = y
			end
		end

		if top == -math.huge then
			return 1.5
		end
		return top - anchor.Position.Y + 1.2
	end

	local function createBillboard(part, name, color, offset)
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "ForsakeniumItemInfo"
		billboard.Adornee = part
		billboard.Size = UDim2.fromOffset(180, 18)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, offset, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = MAX_DISTANCE
		billboard.ResetOnSpawn = false
		billboard.LightInfluence = 0
		billboard.Enabled = false
		billboard.Parent = part

		local label = Instance.new("TextLabel")
		label.Name = "Info"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 13
		label.TextColor3 = color
		label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		label.TextStrokeTransparency = 0.5
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Text = name
		label.Parent = billboard

		return billboard, label
	end

	local function createEntry(tool)
		local color = colorFor(tool.Name)
		local parts = collectParts(tool)
		local primary = primaryPart(parts)
		if not primary then
			return nil
		end

		local highlight = createHighlight(tool, color)
		local billboard, label = createBillboard(primary, tool.Name, color, topOffset(parts, primary))

		return {
			tool = tool,
			color = color,
			highlight = highlight,
			primary = primary,
			billboard = billboard,
			label = label,
		}
	end

	local function destroyEntry(entry)
		if entry.highlight then
			entry.highlight:Destroy()
		end
		if entry.billboard then
			entry.billboard:Destroy()
		end
	end

	local function clearAll()
		for tool, entry in pairs(tracked) do
			destroyEntry(entry)
			tracked[tool] = nil
		end
	end

	-- Parts stream in and out, so re-anchor the label if its part disappears and keep
	-- the offset clear of the item.
	local function syncEntry(entry)
		if entry.highlight and not entry.highlight.Parent then
			entry.highlight = createHighlight(entry.tool, entry.color)
		end

		local parts = collectParts(entry.tool)
		if not entry.primary or not entry.primary.Parent then
			entry.primary = primaryPart(parts)
		end
		if not entry.primary then
			return
		end

		if not entry.billboard or not entry.billboard.Parent then
			entry.billboard, entry.label = createBillboard(entry.primary, entry.tool.Name, entry.color, topOffset(parts, entry.primary))
		else
			entry.billboard.StudsOffsetWorldSpace = Vector3.new(0, topOffset(parts, entry.primary), 0)
		end
	end

	local function scan()
		local seen = {}

		for _, tool in ipairs(collectTools()) do
			if not isHeldByCharacter(tool) then
				local entry = tracked[tool]

				if not entry then
					entry = createEntry(tool)
					if entry then
						tracked[tool] = entry
						seen[tool] = true
					end
				else
					seen[tool] = true
					syncEntry(entry)
				end
			end
		end

		for tool, entry in pairs(tracked) do
			if not seen[tool] then
				destroyEntry(entry)
				tracked[tool] = nil
			end
		end
	end

	-- Hide the label when the player is close enough to see the item unaided.
	local function isTooClose(position)
		local reference = getReferencePosition()
		if not reference or not position then
			return false
		end
		return (position - reference).Magnitude <= TEXT_HIDE_DISTANCE
	end

	local function updateEntry(entry)
		local within = state.Enabled and entry.primary ~= nil and isWithinRange(entry.primary)
		local near = entry.primary ~= nil and isTooClose(entry.primary.Position)

		if entry.highlight and entry.highlight.Parent then
			entry.highlight.Enabled = within
		end
		if entry.billboard and entry.billboard.Parent then
			entry.billboard.Enabled = state.Enabled and not near
		end
		if entry.label then
			entry.label.Text = entry.tool.Name
		end
	end

	local function applyAll()
		for _, entry in pairs(tracked) do
			pcall(updateEntry, entry)
		end
	end

	table.insert(connections, RunService.Heartbeat:Connect(function(dt)
		if not state.Enabled then
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

	local api = {}

	function api:SetEnabled(enabled)
		state.Enabled = enabled
		if enabled then
			pcall(scan)
		else
			clearAll()
		end
		applyAll()
	end

	function api.Unload()
		state.Enabled = false
		clearAll()

		for _, conn in ipairs(connections) do
			pcall(function()
				conn:Disconnect()
			end)
		end
		table.clear(connections)
	end

	return api
end)()

-- Tripwire / subspace tripmine ESP. Survivors place these traps, and both killers and
-- survivors can see them, so the toggles work for either team.

-- A trap carried inside a character is not a placed trap, so leave it alone.
local function isCarriedByCharacter(instance)
	local node = instance.Parent
	while node and node ~= workspace do
		if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then
			return true
		end
		node = node.Parent
	end
	return false
end

local function makeTrapESP(opts)
	local state = {
		Enabled = false,
		Color = opts.color,
		FillTransparency = 0.7,
		OutlineTransparency = 0.3,
	}

	local tracked = {}
	local connections = {}
	local scanClock = 0

	local function getContainers()
		local containers = {}
		local map = workspace:FindFirstChild("Map")
		if not map then
			return containers
		end

		local ingame = map:FindFirstChild("Ingame")
		if ingame then
			table.insert(containers, ingame)
			local ingameMap = ingame:FindFirstChild("Map")
			if ingameMap then
				table.insert(containers, ingameMap)
			end
		end

		local lobby = map:FindFirstChild("Lobby")
		if lobby then
			table.insert(containers, lobby)
			local interactive = lobby:FindFirstChild("Interactive")
			if interactive then
				table.insert(containers, interactive)
			end
		end

		return containers
	end

	local function style(highlight)
		highlight.FillColor = state.Color
		highlight.OutlineColor = state.Color
		highlight.FillTransparency = state.FillTransparency
		highlight.OutlineTransparency = state.OutlineTransparency
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	end

	local function createEntry(model)
		local highlight = Instance.new("Highlight")
		highlight.Name = opts.highlightName
		highlight.Adornee = model
		highlight.Parent = model
		style(highlight)
		return { model = model, highlight = highlight }
	end

	local function destroyEntry(entry)
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
		local seen = {}

		for _, container in ipairs(getContainers()) do
			for _, model in ipairs(container:GetChildren()) do
				if model:IsA("Model") and opts.matches(model) and not isCarriedByCharacter(model) then
					seen[model] = true

					local entry = tracked[model]
					if not entry then
						tracked[model] = createEntry(model)
					elseif not entry.highlight or not entry.highlight.Parent then
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

	local function updateEntry(entry)
		if entry.highlight and entry.highlight.Parent then
			entry.highlight.Enabled = state.Enabled and isWithinRange(entry.model)
		end
	end

	local function applyAll()
		for _, entry in pairs(tracked) do
			pcall(updateEntry, entry)
		end
	end

	table.insert(connections, RunService.Heartbeat:Connect(function(dt)
		if not state.Enabled then
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

	local api = {}

	function api:SetEnabled(enabled)
		state.Enabled = enabled

		if enabled then
			pcall(scan)
		else
			clearAll()
		end

		applyAll()
	end

	function api.Unload()
		state.Enabled = false
		clearAll()

		for _, conn in ipairs(connections) do
			pcall(function()
				conn:Disconnect()
			end)
		end
		table.clear(connections)
	end

	return api
end

local TRAP_COLOR = Color3.fromRGB(191, 255, 191)

local TripwireESP = makeTrapESP({
	highlightName = "ForsakeniumTripwireESP",
	color = TRAP_COLOR,
	matches = function(model)
		return string.find(string.lower(model.Name), "tripwire", 1, true) ~= nil
	end,
})

local TripmineESP = makeTrapESP({
	highlightName = "ForsakeniumTripmineESP",
	color = TRAP_COLOR,
	matches = function(model)
		return string.find(string.lower(model.Name), "tripmine", 1, true) ~= nil
	end,
})

-- Graffiti ESP. Each spray leaves a "<Username>Spray" Model in Map.Ingame, whose Hitbox
-- sits exactly where the graffiti is drawn. The Model is highlighted as a whole in pink,
-- with a label above it showing the model name.
local GraffitiESP = (function()
	local state = {
		Enabled = false,
		Color = Color3.fromRGB(255, 105, 180),
		FillTransparency = 0.7,
		OutlineTransparency = 0.3,
	}

	local tracked = {}
	local connections = {}
	local scanClock = 0

	local function getContainers()
		local containers = {}
		local map = workspace:FindFirstChild("Map")
		if not map then
			return containers
		end

		local ingame = map:FindFirstChild("Ingame")
		if ingame then
			table.insert(containers, ingame)
		end

		local lobby = map:FindFirstChild("Lobby")
		if lobby then
			table.insert(containers, lobby)
			local interactive = lobby:FindFirstChild("Interactive")
			if interactive then
				table.insert(containers, interactive)
			end
		end

		return containers
	end

	local function isSprayModel(instance)
		return instance:IsA("Model")
			and string.find(string.lower(instance.Name), "spray", 1, true) ~= nil
	end

	local function firstPart(model)
		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("BasePart") then
				return child
			end
		end
		return nil
	end

	-- Highest point of the model in world space, allowing for part rotation.
	local function modelTop(model)
		local top = -math.huge
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				local cframe = part.CFrame
				local half = 0.5 * (
					math.abs(cframe.RightVector.Y) * part.Size.X
					+ math.abs(cframe.UpVector.Y) * part.Size.Y
					+ math.abs(cframe.LookVector.Y) * part.Size.Z
				)
				local y = part.Position.Y + half
				if y > top then
					top = y
				end
			end
		end
		return top
	end

	local function style(highlight)
		highlight.FillColor = state.Color
		highlight.OutlineColor = state.Color
		highlight.FillTransparency = state.FillTransparency
		highlight.OutlineTransparency = state.OutlineTransparency
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	end

	local function createBillboard(part, text, offset)
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "ForsakeniumGraffitiInfo"
		billboard.Adornee = part
		billboard.Size = UDim2.fromOffset(200, 18)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, offset, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = MAX_DISTANCE
		billboard.ResetOnSpawn = false
		billboard.LightInfluence = 0
		billboard.Enabled = false
		billboard.Parent = part

		local label = Instance.new("TextLabel")
		label.Name = "Info"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 13
		label.TextColor3 = state.Color
		label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		label.TextStrokeTransparency = 0.5
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Text = text
		label.Parent = billboard

		return billboard, label
	end

	local function createEntry(model)
		local part = firstPart(model)
		if not part then
			return nil
		end

		local highlight = Instance.new("Highlight")
		highlight.Name = "ForsakeniumGraffitiESP"
		highlight.Adornee = model
		highlight.Parent = model
		style(highlight)

		local billboard, label = createBillboard(part, model.Name, modelTop(model) - part.Position.Y + 1.2)

		return {
			model = model,
			part = part,
			highlight = highlight,
			billboard = billboard,
			label = label,
		}
	end

	local function destroyEntry(entry)
		if entry.highlight then
			entry.highlight:Destroy()
		end
		if entry.billboard then
			entry.billboard:Destroy()
		end
	end

	local function clearAll()
		for part, entry in pairs(tracked) do
			destroyEntry(entry)
			tracked[part] = nil
		end
	end

	local function scan()
		local seen = {}

		for _, container in ipairs(getContainers()) do
			for _, instance in ipairs(container:GetChildren()) do
				if isSprayModel(instance) then
					seen[instance] = true

					local entry = tracked[instance]
					local broken = entry
						and (not entry.highlight or not entry.highlight.Parent
							or not entry.billboard or not entry.billboard.Parent)

					if not entry or broken then
						if entry then
							destroyEntry(entry)
						end

						local created = createEntry(instance)
						if created then
							tracked[instance] = created
						else
							seen[instance] = nil
						end
					end
				end
			end
		end

		for part, entry in pairs(tracked) do
			if not seen[part] then
				destroyEntry(entry)
				tracked[part] = nil
			end
		end
	end

	local function updateEntry(entry)
		local within = state.Enabled and isWithinRange(entry.part)

		if entry.highlight and entry.highlight.Parent then
			entry.highlight.Enabled = within
		end
		if entry.billboard and entry.billboard.Parent then
			entry.billboard.Enabled = state.Enabled
		end
		if entry.label then
			entry.label.Text = entry.model.Name
		end
	end

	local function applyAll()
		for _, entry in pairs(tracked) do
			pcall(updateEntry, entry)
		end
	end

	table.insert(connections, RunService.Heartbeat:Connect(function(dt)
		if not state.Enabled then
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

	local api = {}

	function api:SetEnabled(enabled)
		state.Enabled = enabled
		if enabled then
			pcall(scan)
		else
			clearAll()
		end
		applyAll()
	end

	function api.Unload()
		state.Enabled = false
		clearAll()

		for _, conn in ipairs(connections) do
			pcall(function()
				conn:Disconnect()
			end)
		end
		table.clear(connections)
	end

	return api
end)()

-- John Doe shadows. While Killer ESP is on and the local player is playing John Doe, any
-- "Shadow" part gets a highlight and is forced fully opaque so it can always be seen.
-- No separate toggle: it follows Killer ESP plus the John Doe check automatically.
local JohnDoeShadowESP = (function()
	local COLOR = Color3.fromRGB(255, 82, 85)

	local tracked = {}
	local connections = {}
	local scanClock = 0

	local function isLocalJohnDoe()
		local character = LocalPlayer.Character
		if not character then
			return false
		end

		local name = string.lower(character.Name):gsub("%s", "")
		return string.find(name, "johndoe", 1, true) ~= nil
	end

	local function collectShadowParts()
		local parts = {}

		local function fromContainer(container)
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("BasePart")
					and string.find(string.lower(child.Name), "shadow", 1, true) then
					table.insert(parts, child)
				elseif child:IsA("Folder")
					and string.find(string.lower(child.Name), "shadow", 1, true) then
					for _, nested in ipairs(child:GetChildren()) do
						if nested:IsA("BasePart")
							and string.find(string.lower(nested.Name), "shadow", 1, true) then
							table.insert(parts, nested)
						end
					end
				end
			end
		end

		local map = workspace:FindFirstChild("Map")
		if not map then
			return parts
		end

		local ingame = map:FindFirstChild("Ingame")
		if ingame then
			fromContainer(ingame)
		end

		local lobby = map:FindFirstChild("Lobby")
		if lobby then
			fromContainer(lobby)
		end

		return parts
	end

	local function style(highlight)
		highlight.FillColor = COLOR
		highlight.OutlineColor = COLOR
		highlight.FillTransparency = 0.7
		highlight.OutlineTransparency = 0.3
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	end

	local function createEntry(part)
		local highlight = Instance.new("Highlight")
		highlight.Name = "ForsakeniumShadowESP"
		highlight.Adornee = part
		highlight.Parent = part
		style(highlight)

		return {
			part = part,
			highlight = highlight,
			originalTransparency = part.Transparency,
		}
	end

	local function destroyEntry(entry)
		if entry.highlight then
			entry.highlight:Destroy()
		end
		if entry.part and entry.part.Parent and entry.originalTransparency ~= nil then
			entry.part.Transparency = entry.originalTransparency
		end
	end

	local function clearAll()
		for part, entry in pairs(tracked) do
			destroyEntry(entry)
			tracked[part] = nil
		end
	end

	local function updateEntry(entry)
		if entry.highlight and entry.highlight.Parent then
			entry.highlight.Enabled = isWithinRange(entry.part)
		end

		-- Anything that is not fully opaque gets forced to 0 transparency.
		if entry.part.Parent and entry.part.Transparency ~= 0 then
			if entry.originalTransparency == nil then
				entry.originalTransparency = entry.part.Transparency
			end
			entry.part.Transparency = 0
		end
	end

	local function scan()
		local seen = {}

		for _, part in ipairs(collectShadowParts()) do
			seen[part] = true

			local entry = tracked[part]
			local broken = entry and (not entry.highlight or not entry.highlight.Parent)

			if not entry or broken then
				if entry then
					destroyEntry(entry)
				end
				tracked[part] = createEntry(part)
			end
		end

		for part, entry in pairs(tracked) do
			if not seen[part] then
				destroyEntry(entry)
				tracked[part] = nil
			end
		end
	end

	table.insert(connections, RunService.Heartbeat:Connect(function(dt)
		if not (KillerESP:IsEnabled() and isLocalJohnDoe()) then
			if next(tracked) ~= nil then
				clearAll()
			end
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

	local api = {}

	function api.Unload()
		clearAll()

		for _, conn in ipairs(connections) do
			pcall(function()
				conn:Disconnect()
			end)
		end
		table.clear(connections)
	end

	return api
end)()

function Visuals.Build(Tab, ctx)
	Tab:Section({ Title = "Killer", Icon = "skull", TextSize = 15 })

	Tab:Toggle({
		Title = "Killer ESP",
		Desc = "Highlight killers through walls.",
		Value = false,
		Callback = function(value)
			KillerESP:SetEnabled(value)
		end,
	})

	Tab:Toggle({
		Title = "Show Killer Name",
		Desc = "Draw the killer's name above them.",
		Value = false,
		Callback = function(value)
			KillerESP:SetShowName(value)
		end,
	})

	Tab:Toggle({
		Title = "Show Killer Health",
		Desc = "Draw the killer's health.",
		Value = false,
		Callback = function(value)
			KillerESP:SetShowHealth(value)
		end,
	})

	Tab:Slider({
		Title = "Fill Transparency",
		Desc = "Transparency of the killer highlight fill.",
		Value = { Default = 0.7, Min = 0, Max = 1 },
		Step = 0.01,
		Callback = function(value)
			KillerESP:SetFillTransparency(value)
		end,
	})

	Tab:Slider({
		Title = "Outline Transparency",
		Desc = "Transparency of the killer highlight outline.",
		Value = { Default = 0.3, Min = 0, Max = 1 },
		Step = 0.01,
		Callback = function(value)
			KillerESP:SetOutlineTransparency(value)
		end,
	})

	Tab:Colorpicker({
		Title = "Killer Color",
		Desc = "Highlight color used for killers.",
		Default = Color3.fromHex("ff3232"),
		Callback = function(color)
			KillerESP:SetColor(color)
		end,
	})

	Tab:Section({ Title = "Survivor", Icon = "users", TextSize = 15 })

	Tab:Toggle({
		Title = "Survivor ESP",
		Desc = "Highlight survivors through walls.",
		Value = false,
		Callback = function(value)
			SurvivorESP:SetEnabled(value)
		end,
	})

	Tab:Toggle({
		Title = "Show Survivor Name",
		Desc = "Draw the survivor's name above them.",
		Value = false,
		Callback = function(value)
			SurvivorESP:SetShowName(value)
		end,
	})

	Tab:Toggle({
		Title = "Show Survivor Health",
		Desc = "Draw the survivor's health.",
		Value = false,
		Callback = function(value)
			SurvivorESP:SetShowHealth(value)
		end,
	})

	Tab:Slider({
		Title = "Fill Transparency",
		Desc = "Transparency of the survivor highlight fill.",
		Value = { Default = 0.7, Min = 0, Max = 1 },
		Step = 0.01,
		Callback = function(value)
			SurvivorESP:SetFillTransparency(value)
		end,
	})

	Tab:Slider({
		Title = "Outline Transparency",
		Desc = "Transparency of the survivor highlight outline.",
		Value = { Default = 0.3, Min = 0, Max = 1 },
		Step = 0.01,
		Callback = function(value)
			SurvivorESP:SetOutlineTransparency(value)
		end,
	})

	Tab:Colorpicker({
		Title = "Survivor Color",
		Desc = "Highlight color used for survivors.",
		Default = Color3.fromHex("32ff32"),
		Callback = function(color)
			SurvivorESP:SetColor(color)
		end,
	})

	Tab:Section({ Title = "Miscellaneous", Icon = "box", TextSize = 15 })

	Tab:Toggle({
		Title = "Generator ESP",
		Desc = "Highlight real generators (skips fakes and completed ones).",
		Value = false,
		Callback = function(value)
			GeneratorESP:SetEnabled(value)
		end,
	})

	Tab:Toggle({
		Title = "Item ESP",
		Desc = "Highlight world items (medkits white, colas brown).",
		Value = false,
		Callback = function(value)
			ItemESP:SetEnabled(value)
		end,
	})

	Tab:Toggle({
		Title = "Tripwire ESP",
		Desc = "Highlight tripwires through walls.",
		Value = false,
		Callback = function(value)
			TripwireESP:SetEnabled(value)
		end,
	})

	Tab:Toggle({
		Title = "Subspace Tripmine ESP",
		Desc = "Highlight subspace tripmines through walls.",
		Value = false,
		Callback = function(value)
			TripmineESP:SetEnabled(value)
		end,
	})

	Tab:Toggle({
		Title = "Graffiti ESP",
		Desc = "Highlight sprayed graffiti in pink with its name.",
		Value = false,
		Callback = function(value)
			GraffitiESP:SetEnabled(value)
		end,
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
	KillerESP.Unload()
	SurvivorESP.Unload()
	GeneratorESP.Unload()
	ItemESP.Unload()
	TripwireESP.Unload()
	TripmineESP.Unload()
	GraffitiESP.Unload()
	JohnDoeShadowESP.Unload()
end

return Visuals
