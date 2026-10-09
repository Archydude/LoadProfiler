-- Load Profiler: minimap button (LibDBIcon, so minimap button collectors pick it
-- up) and addon compartment entry. Click to open the window, right-click for
-- options, hover for the last login's slowest addons.

local _, ns = ...

local MinimapButton = {}
ns.MinimapButton = MinimapButton

local format = string.format
local Format, Model, Window = ns.Format, ns.Model, ns.Window

local NAME = "LoadProfiler" -- the button's name with LibDBIcon
local ICON = "Interface\\Icons\\INV_Misc_PocketWatch_01"
local TOOLTIP_COUNT = 3     -- slowest addons named in the tooltip
local START_POSITION = 160  -- degrees around the minimap, away from where most buttons start

local LDBIcon = LibStub("LibDBIcon-1.0")
local registered = false

local function fillTooltip(tooltip)
	tooltip:SetText("Load Profiler")
	local s = ns.db.sessions[1]
	if s then
		tooltip:AddDoubleLine(s.kind == "reload" and "Last /reload" or "Last login", Format.Time(s.addonMs),
			1, 0.82, 0, 1, 1, 1)
		local top = Model.Slowest(s)
		for i = 1, math.min(TOOLTIP_COUNT, #top) do
			tooltip:AddDoubleLine(top[i].n, Format.Time(top[i].ms), 1, 1, 1, 1, 1, 1)
		end
	else
		tooltip:AddLine("Nothing measured yet.", 1, 1, 1)
	end
	tooltip:AddLine(" ")
	tooltip:AddLine("Click to open, right-click for options", 0.6, 0.6, 0.6)
end

local function onClick(mouseButton)
	if mouseButton == "RightButton" then ns.Options.Open() else Window.Toggle() end
end

function MinimapButton.Create()
	if registered then return end
	registered = true
	-- LibDBIcon keeps the button's position (and hidden state) in this table.
	ns.opts.minimapIcon = ns.opts.minimapIcon or { minimapPos = START_POSITION }
	ns.opts.minimapIcon.hide = not ns.opts.minimap
	local launcher = LibStub("LibDataBroker-1.1"):NewDataObject(NAME, {
		type = "launcher",
		label = "Load Profiler",
		icon = ICON,
		OnClick = function(_, mouseButton) onClick(mouseButton) end,
		OnTooltipShow = fillTooltip,
	})
	LDBIcon:Register(NAME, launcher, ns.opts.minimapIcon)
end

-- Shows or hides the button to match the option.
function MinimapButton.Refresh()
	if not registered then return end
	if ns.opts.minimap then LDBIcon:Show(NAME) else LDBIcon:Hide(NAME) end
end

function MinimapButton.ResetPosition()
	if not registered then return end
	ns.opts.minimapIcon.minimapPos = START_POSITION
	LDBIcon:Refresh(NAME, ns.opts.minimapIcon)
end

-- /lp minimap: hides or shows the button.
function MinimapButton.Toggle()
	ns.Options.Set("minimap", not ns.opts.minimap)
	print(format("|cffff9933Load Profiler:|r minimap button %s.",
		ns.opts.minimap and "shown" or "hidden. Type |cffffff00/lp minimap|r to bring it back"))
end

-- Addon compartment (the addon menu on Retail's minimap), named in the .toc.
function LoadProfiler_OnAddonCompartmentClick(_, mouseButton)
	onClick(mouseButton)
end

function LoadProfiler_OnAddonCompartmentEnter(_, menuButton)
	GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
	fillTooltip(GameTooltip)
	GameTooltip:Show()
end

function LoadProfiler_OnAddonCompartmentLeave()
	GameTooltip:Hide()
end
