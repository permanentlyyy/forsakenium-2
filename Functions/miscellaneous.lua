--// Miscellaneous tab: lighting, camera, device spoofer, privacy and field of view.

local Miscellaneous = {}

local State = {}

local function set(key)
	return function(value)
		State[key] = value
	end
end

function Miscellaneous:Get(key)
	return State[key]
end

function Miscellaneous.Build(Tab, ctx)
	Tab:Section({ Title = "Lighting", Icon = "sun", TextSize = 15 })

	Tab:Toggle({ Title = "Fullbright", Desc = "Brighten the entire map.", Value = false, Callback = set("Fullbright") })
	Tab:Toggle({ Title = "No Fog", Desc = "Remove distance fog.", Value = false, Callback = set("NoFog") })

	Tab:Section({ Title = "Camera", Icon = "camera", TextSize = 15 })

	Tab:Toggle({ Title = "Infinite Zoom", Desc = "Remove the maximum zoom distance.", Value = false, Callback = set("InfiniteZoom") })
	Tab:Toggle({ Title = "Camera Noclip", Desc = "Let the camera pass through objects.", Value = false, Callback = set("CameraNoclip") })

	Tab:Section({ Title = "Device Spoofer", Icon = "smartphone", TextSize = 15 })

	Tab:Dropdown({
		Title = "Choose Device",
		Desc = "Device type reported to the game.",
		Values = { "PC", "Mobile", "Console", "Unknown" },
		Value = "PC",
		Multi = false,
		Callback = set("Device"),
	})

	Tab:Section({ Title = "Privacy", Icon = "eye-off", TextSize = 15 })

	Tab:Toggle({ Title = "Show Hidden Stats", Desc = "Reveal normally hidden stats.", Value = false, Callback = set("ShowHiddenStats") })
	Tab:Toggle({ Title = "Hide Name", Desc = "Hide your name from other players.", Value = false, Callback = set("HideName") })

	Tab:Section({ Title = "Field of View", Icon = "scan", TextSize = 15 })

	Tab:Slider({
		Title = "Custom FOV",
		Desc = "Override the camera field of view.",
		Value = { Default = 80, Min = 70, Max = 120 },
		Step = 1,
		Callback = set("CustomFOV"),
	})
end

function Miscellaneous.Unload() end

return Miscellaneous
