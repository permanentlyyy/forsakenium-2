--// Settings tab: appearance, interface and controls for the window itself.

local Settings = {}

function Settings.Build(Tab, ctx)
	local WindUI = ctx.WindUI
	local Window = ctx.Window
	local themes = ctx.Themes
	local DEFAULT_THEME = ctx.DefaultTheme

	local ELEMENT_GAP = 2
	Tab.Gap = ELEMENT_GAP

	local layout = Tab.UIElements.ContainerFrame:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.Padding = UDim.new(0, ELEMENT_GAP)
	end

	Tab:Section({ Title = "Appearance", Icon = "palette", TextSize = 15 })

	Tab:Dropdown({
		Title = "Theme",
		Desc = "Choose the UI color theme.",
		Values = themes,
		Value = DEFAULT_THEME,
		Callback = function(name)
			WindUI:SetTheme(name)
		end,
	})

	Tab:Toggle({
		Title = "Transparent window",
		Desc = "Toggle the window's background transparency.",
		Value = false,
		Callback = function(value)
			Window:ToggleTransparency(value)
		end,
	})

	Tab:Section({ Title = "Interface", Icon = "panel-top", TextSize = 15 })

	Tab:Toggle({
		Title = "Hide search bar",
		Desc = "Show or hide search in the sidebar.",
		Value = false,
		Callback = function(hidden)
			local sidebar = Window.UIElements.SideBar
			local sidebarContainer = Window.UIElements.SideBarContainer
			local searchButton = sidebarContainer:FindFirstChildOfClass("TextButton")

			Window.HideSearchBar = hidden
			searchButton.Visible = not hidden
			sidebar.Size = UDim2.new(1, 0, 1, hidden and 0 or -45)
			sidebarContainer.Content.Size = UDim2.new(
				1, 0, 1, hidden and -Window.UIPadding / 2 or -39 - 6 - Window.UIPadding
			)
		end,
	})

	Tab:Toggle({
		Title = "User profile",
		Desc = "Show or hide the profile area in the sidebar.",
		Value = true,
		Callback = function(value)
			if value then
				Window.User:Enable()
			else
				Window.User:Disable()
			end
		end,
	})

	Tab:Toggle({
		Title = "Anonymous",
		Desc = "Hide your username in the profile area.",
		Value = false,
		Callback = function(value)
			Window.User:SetAnonymous(value)
		end,
	})

	Tab:Section({ Title = "Controls", Icon = "keyboard", TextSize = 15 })

	Tab:Keybind({
		Title = "Toggle keybind",
		Desc = "Choose the key used to show or hide the window.",
		Value = "LeftControl",
		Callback = function(value)
			local keyCode = Enum.KeyCode[value]
			if keyCode then
				Window:SetToggleKey(keyCode)
			end
		end,
	})
end

function Settings.Unload() end

return Settings
