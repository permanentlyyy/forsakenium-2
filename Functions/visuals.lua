--// Visuals tab.

local Visuals = {}

function Visuals.Build(Tab, ctx)
	Tab:Section({ Title = "Killer", Icon = "skull", TextSize = 15 })

	Tab:Toggle({
		Title = "Killer ESP",
		Desc = "Highlight killers through walls.",
		Value = false,
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
	})

	Tab:Slider({
		Title = "Outline Transparency",
		Desc = "Transparency of the killer highlight outline.",
		Value = { Default = 0.3, Min = 0, Max = 1 },
		Step = 0.01,
	})

	Tab:Colorpicker({
		Title = "Killer Color",
		Desc = "Highlight color used for killers.",
		Default = Color3.fromHex("ff3232"),
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
		Title = "Killers",
		Desc = "Draw tracers to killers.",
		Value = false,
	})

	Tab:Toggle({
		Title = "Survivors",
		Desc = "Draw tracers to survivors.",
		Value = false,
	})

	Tab:Toggle({
		Title = "Generators",
		Desc = "Draw tracers to generators.",
		Value = false,
	})

	Tab:Toggle({
		Title = "Items",
		Desc = "Draw tracers to items.",
		Value = false,
	})

	Tab:Toggle({
		Title = "Tripwires",
		Desc = "Draw tracers to tripwires.",
		Value = false,
	})

	Tab:Toggle({
		Title = "Subspace Tripmines",
		Desc = "Draw tracers to subspace tripmines.",
		Value = false,
	})
end

function Visuals.Unload() end

return Visuals
