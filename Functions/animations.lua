--// Animations tab: killer animation changer and animation-related extras.

local Animations = {}

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

function Animations:Get(key)
	return State[key]
end

function Animations.Build(Tab, ctx)
	Tab:Section({ Title = "Animation Changer", Icon = "clapperboard", TextSize = 15 })

	Tab:Dropdown({
		Title = "Killer",
		Desc = "Killer whose animations are replaced.",
		Values = KILLERS,
		Value = "c00lkidd",
		Multi = false,
		Callback = set("KillerAnimations"),
	})

	Tab:Toggle({
		Title = "Enable Killer Animations",
		Desc = "Apply the selected killer's animations to your character.",
		Value = false,
		Callback = set("EnableKillerAnimations"),
	})

	Tab:Section({ Title = "Miscellaneous", Icon = "sparkles", TextSize = 15 })

	Tab:Toggle({
		Title = "Emote as Killer",
		Desc = "Allow emoting while playing a killer.",
		Value = false,
		Callback = set("EmoteAsKiller"),
	})
end

function Animations.Unload() end

return Animations
