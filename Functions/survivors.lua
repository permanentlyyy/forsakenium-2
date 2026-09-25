--// Survivors tab: one section per survivor for their specific features.

local Survivors = {}

local SURVIVORS = {
	"Elliot",
	"Noob",
	"Jane Doe",
	"007n7",
	"Guest 1337",
	"Dusekkar",
	"Veeronica",
	"Chance",
}

local State = {}

local function set(key)
	return function(value)
		State[key] = value
	end
end

function Survivors:Get(key)
	return State[key]
end

function Survivors.Build(Tab, ctx)
	for _, name in ipairs(SURVIVORS) do
		Tab:Section({ Title = name, Icon = "user", TextSize = 15 })
	end
end

function Survivors.Unload() end

return Survivors
