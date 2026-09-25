--// Forsakenium
--// Entry point. Builds the WindUI window + tabs, then loads one module per tab.
--// Every Functions/<tab>.lua file returns a module table with Build(Tab, Context),
--// and optionally Unload(). Features live with the tab they belong to.

--// Unload Previous Instance
if _G.__Forsakenium then
	pcall(_G.__Forsakenium)
end

--// Sources
local REPO = "https://raw.githubusercontent.com/permanentlyyy/forsakenium-2/main"

local Sources = {
	WindUI = "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",

	Player = REPO .. "/Functions/player.lua",
	Sprinting = REPO .. "/Functions/sprinting.lua",
	Generators = REPO .. "/Functions/generators.lua",
	Settings = REPO .. "/Functions/settings.lua",
}

--// Loader
local function load(url)
	return loadstring(game:HttpGet(url .. "?nocache=" .. tostring(tick())))()
end

--// Library
local WindUI = load(Sources.WindUI)

--// Themes
local DEFAULT_THEME = "Dark"

local themes = {}
for name in next, WindUI:GetThemes() do
	if name ~= "Rainbow" then
		table.insert(themes, name)
	end
end
table.sort(themes)

--// Window
local Window = WindUI:CreateWindow({
	Title = "Forsakenium",
	Author = "by you",
	Icon = "layout-dashboard",
	Folder = "Forsakenium",
	Theme = DEFAULT_THEME,

	Size = UDim2.fromOffset(620, 500),
	MinSize = Vector2.new(540, 380),
	MaxSize = Vector2.new(900, 640),
	ToggleKey = Enum.KeyCode.LeftControl,
	Transparent = false,
	Resizable = true,
	SideBarWidth = 185,
	HideSearchBar = false,

	Radius = 12,
	ElementsRadius = 4,

	NewElements = true,

	Topbar = {
		Height = 42,
		ButtonsType = "Default",
	},

	User = {
		Enabled = true,
		Anonymous = false,
	},
})

--// Early unload handler so re-running always clears the previous window.
_G.__Forsakenium = function()
	pcall(function()
		Window:Destroy()
	end)
end

--// Tabs
local TAB_DEFS = {
	{ Id = "Player", Title = "Player", Icon = "user-round" },
	{ Id = "Sprinting", Title = "Sprinting", Icon = "footprints" },
	{ Id = "Generators", Title = "Generators", Icon = "cog" },
	{ Id = "Settings", Title = "Settings", Icon = "settings" },
}

local Tabs = {}
local TabOrder = {}

for _, def in ipairs(TAB_DEFS) do
	local tab = Window:Tab({
		Title = def.Title,
		Icon = def.Icon,
		Border = false,
		ShowTabTitle = true,
	})

	Tabs[def.Id] = tab
	table.insert(TabOrder, tab)
end

Tabs.Player:Select()

-- Keep WindUI's default tab-title styling but tighten the gap before tab content.
for _, tab in ipairs(TabOrder) do
	local padding = tab.UIElements.ContainerFrame:FindFirstChildOfClass("UIPadding")
	if padding then
		padding.PaddingTop = UDim.new(0, 8)
	end
end

--// Shared context handed to every tab module
local Context = {
	WindUI = WindUI,
	Window = Window,
	Tabs = Tabs,
	Themes = themes,
	DefaultTheme = DEFAULT_THEME,
	Sources = Sources,
	load = load,
}

--// Load one module per tab and let it build its own UI + logic
local Modules = {}

for _, def in ipairs(TAB_DEFS) do
	local ok, module = pcall(load, Sources[def.Id])

	if not ok then
		warn("[Forsakenium] Failed to load " .. def.Id .. " module: " .. tostring(module))
	elseif type(module) ~= "table" then
		warn("[Forsakenium] " .. def.Id .. " module did not return a table")
	else
		Modules[def.Id] = module

		if type(module.Build) == "function" then
			local built, err = pcall(module.Build, Tabs[def.Id], Context)
			if not built then
				warn("[Forsakenium] Failed to build " .. def.Id .. " tab: " .. tostring(err))
			end
		end
	end
end

--// Unload Handler
_G.__Forsakenium = function()
	for _, module in pairs(Modules) do
		if type(module.Unload) == "function" then
			pcall(module.Unload)
		end
	end

	pcall(function()
		Window:Destroy()
	end)
end
