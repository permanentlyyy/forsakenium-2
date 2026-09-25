--// Visuals tab: killer / survivor ESP, object ESP and tracers.
--// UI scaffold mirrors the original Forsakenium layout; wire drawing logic into State as needed.

local Visuals = {}

local State = {}

local function set(key)
	return function(value)
		State[key] = value
	end
end

function Visuals:Get(key)
	return State[key]
end

function Visuals.Build(Tab, ctx)
	Tab:Section({ Title = "Killer", Icon = "skull", TextSize = 15 })

	Tab:Toggle({ Title = "Killer ESP", Desc = "Highlight killers through walls.", Value = false, Callback = set("KillerESP") })
	Tab:Toggle({ Title = "Show Killer Name", Desc = "Draw the killer's name.", Value = false, Callback = set("ShowKillerName") })
	Tab:Toggle({ Title = "Show Killer Health", Desc = "Draw the killer's health.", Value = false, Callback = set("ShowKillerHealth") })

	Tab:Slider({
		Title = "Fill Transparency",
		Desc = "Transparency of the killer highlight fill.",
		Value = { Default = 0.7, Min = 0, Max = 1 },
		Step = 0.01,
		Callback = set("KillerFillTransparency"),
	})

	Tab:Slider({
		Title = "Outline Transparency",
		Desc = "Transparency of the killer highlight outline.",
		Value = { Default = 0.3, Min = 0, Max = 1 },
		Step = 0.01,
		Callback = set("KillerOutlineTransparency"),
	})

	Tab:Colorpicker({
		Title = "Killer Color",
		Desc = "Highlight color used for killers.",
		Value = Color3.fromRGB(255, 50, 50),
		Callback = set("KillerColor"),
	})

	Tab:Section({ Title = "Survivor", Icon = "users", TextSize = 15 })

	Tab:Toggle({ Title = "Survivor ESP", Desc = "Highlight survivors through walls.", Value = false, Callback = set("SurvivorESP") })
	Tab:Toggle({ Title = "Show Survivor Name", Desc = "Draw the survivor's name.", Value = false, Callback = set("ShowSurvivorName") })
	Tab:Toggle({ Title = "Show Survivor Health", Desc = "Draw the survivor's health.", Value = false, Callback = set("ShowSurvivorHealth") })

	Tab:Slider({
		Title = "Fill Transparency",
		Desc = "Transparency of the survivor highlight fill.",
		Value = { Default = 0.7, Min = 0, Max = 1 },
		Step = 0.01,
		Callback = set("SurvivorFillTransparency"),
	})

	Tab:Slider({
		Title = "Outline Transparency",
		Desc = "Transparency of the survivor highlight outline.",
		Value = { Default = 0.3, Min = 0, Max = 1 },
		Step = 0.01,
		Callback = set("SurvivorOutlineTransparency"),
	})

	Tab:Colorpicker({
		Title = "Survivor Color",
		Desc = "Highlight color used for survivors.",
		Value = Color3.fromRGB(50, 255, 50),
		Callback = set("SurvivorColor"),
	})

	Tab:Section({ Title = "Miscellaneous", Icon = "box", TextSize = 15 })

	Tab:Dropdown({
		Title = "Object ESP",
		Desc = "Highlight selected world objects.",
		Values = { "Generator", "Item", "Tripwire", "Mine", "Ritual", "Graffiti" },
		Value = {},
		Multi = true,
		Callback = set("ObjectESP"),
	})

	Tab:Dropdown({
		Title = "Tracers",
		Desc = "Draw tracers to selected targets.",
		Values = { "Killer", "Survivor", "Generator", "Item", "Tripwire", "Mine" },
		Value = {},
		Multi = true,
		Callback = set("Tracers"),
	})
end

function Visuals.Unload() end

return Visuals
