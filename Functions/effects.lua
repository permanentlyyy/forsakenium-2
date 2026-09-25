--// Effects tab: new tab reserved for on-screen / gameplay effects.
--// No features from the original single-file build mapped here yet, so this is a scaffold.

local Effects = {}

local State = {}

local function set(key)
	return function(value)
		State[key] = value
	end
end

function Effects:Get(key)
	return State[key]
end

function Effects.Build(Tab, ctx)
	Tab:Section({ Title = "Effects", Icon = "shield", TextSize = 15 })

	-- Add effect toggles here, e.g.:
	-- Tab:Toggle({
	-- 	Title = "Example Effect",
	-- 	Desc = "Describe the effect.",
	-- 	Value = false,
	-- 	Callback = set("ExampleEffect"),
	-- })
end

function Effects.Unload() end

return Effects
