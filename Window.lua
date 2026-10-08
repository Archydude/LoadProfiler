-- Load Profiler: the /lp window.

local _, ns = ...

local format = string.format
local Format, Model, Switch = ns.Format, ns.Model, ns.Switch

local Window = {}
ns.Window = Window

-- Layout
local WINDOW_WIDTH, WINDOW_HEIGHT = 520, 500
local ROW_HEIGHT = 16
local LIST_WIDTH = 460    -- the scrolling list
local BAR_WIDTH = 456     -- the slowest entry's bar; the rest scale to it
local NAME_WIDTH = 280    -- "Addon" column
local TIME_X, MEMORY_X = 290, 375
local NUMBER_WIDTH = 80   -- "Load time" and "Memory" columns
local OPTIONS_Y = -78     -- the checkboxes
local HEADER_Y = -108     -- column headers
local LIST_TOP = -124
local FOOTER_HEIGHT = 40  -- hint and Reload button under the list

-- Load time bars: red from SLOW_MS, orange from MEDIUM_MS, blue below.
local SLOW_MS, MEDIUM_MS = 500, 100
local BAR_SLOW = { 1, 0.2, 0.2, 0.35 }
local BAR_MEDIUM = { 1, 0.6, 0.1, 0.30 }
local BAR_FAST = { 0.4, 0.7, 1, 0.20 }

-- A Blizzard module this slow is the game loading the world, not the module itself.
local GAME_LOADING_MS = 1000

local KIND_LABEL = { login = "Cold login", reload = "/reload", other = "Other" }

local ui
local viewIndex = 1 -- which session is shown: 1 = newest
local rowFrames = {}

local function showTooltip(row)
	local e = row.entry
	if not e then return end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:AddLine(e.n, 1, 1, 1)
	if e.members then
		GameTooltip:AddLine(table.concat(e.members, ", "), 0.7, 0.7, 0.7, true)
	end

	local names = Switch.Targets(e)
	if e.b then
		GameTooltip:AddLine("Part of the game. It can't be turned off.", 0.7, 0.7, 0.7, true)
	elseif #names == 0 then
		GameTooltip:AddLine("Not installed anymore.", 0.7, 0.7, 0.7, true)
	elseif Switch.AnyOn(names) then
		GameTooltip:AddLine(format("Right-click to turn %s off for %s.", e.members and "them" or "it", Switch.Me()), 0.4, 1, 0.4, true)
		local deps = Switch.Dependents(names, ui.session)
		if #deps > 0 then
			GameTooltip:AddLine("These need it and won't load either: " .. table.concat(deps, ", "), 1, 0.6, 0.1, true)
		end
	else
		GameTooltip:AddLine(format("Off for %s. Right-click to turn %s back on.", Switch.Me(), e.members and "them" or "it"), 1, 0.4, 0.4, true)
	end
	GameTooltip:Show()
end

local function getRow(i)
	local row = rowFrames[i]
	if row then return row end

	row = CreateFrame("Button", nil, ui.child)
	row:SetSize(LIST_WIDTH, ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	row:RegisterForClicks("RightButtonUp")
	row:SetScript("OnClick", function(self)
		Switch.Toggle(self.entry)
		Window.Refresh()
		showTooltip(self)
	end)
	row:SetScript("OnEnter", showTooltip)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)

	row.bar = row:CreateTexture(nil, "BACKGROUND")
	row.bar:SetPoint("LEFT")
	row.bar:SetHeight(ROW_HEIGHT - 2)

	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.name:SetPoint("LEFT", 4, 0)
	row.name:SetWidth(NAME_WIDTH)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)

	row.ms = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.ms:SetPoint("LEFT", TIME_X, 0)
	row.ms:SetWidth(NUMBER_WIDTH)
	row.ms:SetJustifyH("RIGHT")

	row.kb = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.kb:SetPoint("LEFT", MEMORY_X, 0)
	row.kb:SetWidth(NUMBER_WIDTH)
	row.kb:SetJustifyH("RIGHT")

	rowFrames[i] = row
	return row
end

local function drawRow(row, e, max)
	local label = e.c and format("%s |cff888888(%d)|r", e.n, e.c) or e.n
	if e.b and not e.c and e.ms >= GAME_LOADING_MS then
		label = label .. " |cff888888(mostly game loading)|r"
	end
	local targets = Switch.Targets(e)
	local off = #targets > 0 and not Switch.AnyOn(targets)
	if off then label = label .. " |cffff6060off|r" end
	row.entry = e
	row.name:SetText(label)
	if off then row.name:SetTextColor(0.5, 0.5, 0.5) else row.name:SetTextColor(1, 1, 1) end
	row.ms:SetText(Format.Time(e.ms))
	row.kb:SetText(Format.Memory(e.kb))
	local color = e.ms >= SLOW_MS and BAR_SLOW or e.ms >= MEDIUM_MS and BAR_MEDIUM or BAR_FAST
	row.bar:SetColorTexture(color[1], color[2], color[3], color[4])
	row.bar:SetWidth(math.max(1, BAR_WIDTH * e.ms / max))
	row:Show()
end

local function refreshFooter()
	local pending = Switch.PendingCount()
	if pending > 0 then
		ui.hint:SetText(pending == 1 and "1 addon changes after a reload."
			or format("%d addons change after a reload.", pending))
		ui.hint:SetTextColor(1, 0.82, 0)
		ui.reload:Show()
	else
		ui.hint:SetText(format("Right-click an addon to turn it off for %s.", Switch.Me()))
		ui.hint:SetTextColor(0.6, 0.6, 0.6)
		ui.reload:Hide()
	end
end

function Window.Refresh()
	if not ui then return end
	local sessions = ns.db.sessions
	local s = sessions[viewIndex]
	ui.session = s

	ui.prev:SetEnabled(viewIndex < #sessions)
	ui.next:SetEnabled(viewIndex > 1)
	refreshFooter()

	if not s then
		ui.line1:SetText("No data yet. Log out and back in to record a session.")
		ui.line2:SetText("")
		ui.line3:SetText("")
		for _, row in ipairs(rowFrames) do row:Hide() end
		return
	end

	ui.line1:SetText(format("%s  |cff888888·|r  %s  |cff888888·|r  %s  |cff888888(%d of %d)|r",
		s.char, s.date, KIND_LABEL[s.kind] or s.kind, viewIndex, #sessions))
	ui.line2:SetText(format("Addons loading: |cffffd100%s|r   Login init: %s   Game itself: %s   Total: %s",
		Format.Time(s.addonMs), Format.Time(s.initMs), Format.Time(Model.GameMs(s)), Format.Time(s.totalMs)))
	ui.line3:SetText(s.kind == "reload"
		and "|cff888888A /reload reads cached files and is faster. Compare cold logins for real numbers.|r"
		or "|cff888888Login init = all addons' startup code after loading, combined (can't be split per addon).|r")

	local list = Model.Entries(s, ns.opts)
	local max = (list[1] and list[1].ms > 0) and list[1].ms or 1
	for i, e in ipairs(list) do
		drawRow(getRow(i), e, max)
	end
	for i = #list + 1, #rowFrames do rowFrames[i]:Hide() end
	ui.child:SetHeight(math.max(1, #list * ROW_HEIGHT))
end

local function makeCheck(parent, label, x, key)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	cb:SetPoint("TOPLEFT", x, OPTIONS_Y)
	local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
	text:SetText(label)
	cb:SetChecked(ns.opts[key])
	cb:SetScript("OnClick", function(self)
		ns.opts[key] = self:GetChecked() and true or false
		Window.Refresh()
	end)
	return cb
end

local function create()
	local f = CreateFrame("Frame", "LoadProfilerFrame", UIParent, "BasicFrameTemplateWithInset")
	f:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetClampedToScreen(true)
	tinsert(UISpecialFrames, "LoadProfilerFrame")

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOP", 0, -5)
	title:SetText("Load Profiler")

	f.line1 = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.line1:SetPoint("TOPLEFT", 14, -32)
	f.line2 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.line2:SetPoint("TOPLEFT", 14, -50)
	f.line3 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.line3:SetPoint("TOPLEFT", 14, -64)

	makeCheck(f, "Group by family", 10, "group")
	makeCheck(f, "Show Blizzard", 140, "blizz")

	f.next = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.next:SetSize(70, 22)
	f.next:SetPoint("TOPRIGHT", -14, OPTIONS_Y - 1)
	f.next:SetText("Newer >")
	f.next:SetScript("OnClick", function() viewIndex = viewIndex - 1; Window.Refresh() end)

	f.prev = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.prev:SetSize(70, 22)
	f.prev:SetPoint("RIGHT", f.next, "LEFT", -4, 0)
	f.prev:SetText("< Older")
	f.prev:SetScript("OnClick", function() viewIndex = viewIndex + 1; Window.Refresh() end)

	local function header(text, x, width, justify)
		local h = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		h:SetPoint("TOPLEFT", 14 + x, HEADER_Y)
		h:SetWidth(width)
		h:SetJustifyH(justify)
		h:SetText(text)
	end
	header("Addon", 4, NAME_WIDTH, "LEFT")
	header("Load time", TIME_X, NUMBER_WIDTH, "RIGHT")
	header("Memory", MEMORY_X, NUMBER_WIDTH, "RIGHT")

	local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 14, LIST_TOP)
	scroll:SetPoint("BOTTOMRIGHT", -34, FOOTER_HEIGHT)
	f.child = CreateFrame("Frame", nil, scroll)
	f.child:SetSize(LIST_WIDTH, 1)
	scroll:SetScrollChild(f.child)

	f.reload = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.reload:SetSize(90, 22)
	f.reload:SetPoint("BOTTOMRIGHT", -14, 10)
	f.reload:SetText("Reload")
	f.reload:SetScript("OnClick", function() ReloadUI() end)

	f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	f.hint:SetPoint("BOTTOMLEFT", 14, 15)
	f.hint:SetPoint("RIGHT", f.reload, "LEFT", -8, 0)
	f.hint:SetJustifyH("LEFT")
	f.hint:SetWordWrap(false)

	ui = f
end

-- Opens the window on the newest session, or closes it.
function Window.Toggle()
	if not ui then
		create()
		ui:Hide()
	end
	if ui:IsShown() then
		ui:Hide()
	else
		viewIndex = 1
		ui:Show()
		Window.Refresh()
	end
end

-- After the history is cleared.
function Window.Reset()
	viewIndex = 1
	Window.Refresh()
end
