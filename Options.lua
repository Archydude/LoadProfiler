-- Load Profiler: options
-- Esc > Options > AddOns > Load Profiler, or right-click the minimap button.

local _, ns = ...

local Options = {}
ns.Options = Options

local category
local settings = {} -- key -> the options page's setting object

function Options.Open()
	if category then Settings.OpenToCategory(category:GetID()) end
end

-- Changes an option from elsewhere (/lp minimap) through the options page, so
-- the page stays in sync.
function Options.Set(key, value)
	if settings[key] then
		settings[key]:SetValue(value)
	else
		ns.opts[key] = value
		Options.Changed(key)
	end
end

-- What changing each option does right away.
function Options.Changed(key)
	if key == "minimap" then ns.MinimapButton.Refresh() end
end

function Options.Create()
	if category then return end
	local layout
	category, layout = Settings.RegisterVerticalLayoutCategory("Load Profiler")
	local VarType = Settings.VarType or { Boolean = "boolean" }

	-- Section headings; skipped on clients that can't draw them.
	local function header(text)
		if CreateSettingsListSectionHeaderInitializer then
			layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
		end
	end

	local function checkbox(key, name, tooltip)
		local s = Settings.RegisterAddOnSetting(category, "LOADPROFILER_" .. key:upper(), key, ns.opts,
			VarType.Boolean, name, ns.DEFAULT_OPTS[key])
		s:SetValueChangedCallback(function() Options.Changed(key) end)
		settings[key] = s
		Settings.CreateCheckbox(category, s, tooltip)
	end

	local function button(label, text, onClick, tooltip)
		layout:AddInitializer(CreateSettingsButtonInitializer(label, text, onClick, tooltip, true))
	end

	header("Minimap")
	checkbox("minimap", "Show minimap button",
		"Click it to open Load Profiler, hover it for the last login's slowest addons. Drag it to move it around the minimap."
			.. (AddonCompartmentFrame and " Load Profiler is also in the addon menu on the minimap." or ""))
	button("Minimap button position", "Reset", ns.MinimapButton.ResetPosition,
		"Put the minimap button back where it started.")

	header("After each login")
	checkbox("summary", "Chat summary",
		"A few seconds after you log in, chat shows the total load time and the 5 slowest addons.")

	header("History")
	button("Saved history", "Clear", ns.ClearHistory,
		"Forget all saved logins, play sessions and boss fights. The next login starts a new list.")

	Settings.RegisterAddOnCategory(category)
end
