--// Killers tab: one section per killer for their specific features.

local Killers = {}

local KILLERS = {
	"c00lkidd",
	"Slasher",
	"John Doe",
	"Noli",
	"1х1х1х1",
	"Guest 666",
	"Nosferatu",
	"Azure",
}

local State = {}

local function set(key)
	return function(value)
		State[key] = value
	end
end

function Killers:Get(key)
	return State[key]
end

function Killers.Build(Tab, ctx)
	for _, name in ipairs(KILLERS) do
		Tab:Section({ Title = name, Icon = "skull", TextSize = 15 })
	end
end

function Killers.Unload() end

return Killers
