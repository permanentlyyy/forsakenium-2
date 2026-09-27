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
		Value = Color3.fromHex("ff3232"),
	})
end

function Visuals.Unload() end

return Visuals
