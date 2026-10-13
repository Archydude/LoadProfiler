-- Load Profiler: the /lp window. Two tabs share it: the loading screen (login
-- sessions) and while playing (play sessions and boss fights).

local _, ns = ...

local format = string.format
local Format, Model, Play, Switch = ns.Format, ns.Model, ns.Play, ns.Switch

local Window = {}
ns.Window = Window

-- Layout
local WINDOW_WIDTH, WINDOW_HEIGHT = 600, 590
local ROW_HEIGHT = 18
local LIST_WIDTH = 540    -- the scrolling list
local BAR_WIDTH = 536     -- the biggest entry's bar; the rest scale to it
local NAME_X = 4          -- "Addon" column
local COLUMN_GAP = 6      -- between the name and the first number
local LINE_Y = { -32, -52, -70 } -- the three lines at the top
local OPTIONS_Y = -94     -- the checkboxes
local SEARCH_Y = -124     -- the search box
local SEARCH_WIDTH = 220
local HEADER_Y = -152     -- column headers
local HEADER_HEIGHT = 18
local LIST_TOP = -172
local FOOTER_HEIGHT = 40  -- hint and Reload button under the list
local LIVE_REFRESH = 1    -- seconds between redraws of the session in progress

-- Bars: red, orange or blue.
local BAR_SLOW = { 1, 0.2, 0.2, 0.35 }
local BAR_MEDIUM = { 1, 0.6, 0.1, 0.30 }
local BAR_FAST = { 0.4, 0.7, 1, 0.20 }

-- Load time bars: red from SLOW_MS, orange from MEDIUM_MS.
local SLOW_MS, MEDIUM_MS = 500, 100

-- A Blizzard module this slow is the game loading the world, not the module itself.
local GAME_LOADING_MS = 1000

-- Play rows: Play.THRESHOLDS index of 10 ms and 50 ms.
local OVER_10, OVER_50 = 3, 4

local KIND_LABEL = { login = "Cold login", reload = "/reload", other = "Other" }

local GREY = "|cff888888"
local DOT = "  " .. GREY .. "·|r  "

local ui
local mode = 1             -- which tab is shown
local viewIndex = { 1, 1 } -- per tab, which session is shown: 1 = newest
local playSort = "over10"  -- the While playing list's sort column (Model.PLAY_SORTS)
local rowFrames = {}

-- Each tab: its sessions, the lines at the top, the list, and its columns. A
-- column's text(e) fills it; the name column comes first and takes the rest.
local views = {}

views[1] = {
	tab = "Loading screen",
	columns = {
		{ label = "Load time", width = 90, text = function(e) return Format.Time(e.ms) end },
		{ label = "Memory", width = 90, text = function(e) return Format.Memory(e.kb) end },
	},
	sessions = function() return ns.db.sessions end,
	empty = "No data yet. Log out and back in to record a session.",
	lines = function(s, i, n)
		return format("%s%s%s%s%s  %s(%d of %d)|r", s.char, DOT, s.date, DOT, KIND_LABEL[s.kind] or s.kind, GREY, i, n),
			format("Addons loading: |cffffd100%s|r   Login init: %s   Game itself: %s   Total: %s",
				Format.Time(s.addonMs), Format.Time(s.initMs), Format.Time(Model.GameMs(s)), Format.Time(s.totalMs)),
			GREY .. (s.kind == "reload"
				and "A /reload reads cached files and is faster. Compare cold logins for real numbers."
				or "Login init = all addons' startup code after loading, combined (can't be split per addon).") .. "|r"
	end,
	entries = function(s, query) return Model.Entries(s, ns.opts, query) end,
	size = function(e) return e.ms end,
	color = function(e) return e.ms >= SLOW_MS and BAR_SLOW or e.ms >= MEDIUM_MS and BAR_MEDIUM or BAR_FAST end,
	label = function(e, label)
		if e.b and not e.c and e.ms >= GAME_LOADING_MS then
			label = label .. " " .. GREY .. "(mostly game loading)|r"
		end
		return label
	end,
}

local function over(e, i)
	local n = Model.Over(e, i)
	return n > 0 and Format.Count(n) or GREY .. "0|r"
end

local function playTitle(rec)
	if rec.live then return "This session so far" end
	if rec.kind == "boss" then
		local result = rec.success and " (kill)" or rec.success == nil and "" or " (wipe)"
		return "Boss fight: " .. (rec.name or "?") .. result
	end
	return "Play session"
end

views[2] = {
	tab = "While playing",
	columns = {
		{ label = "Per frame", width = 80, sort = "ms", text = function(e) return Format.Fine(e.ms) end,
			tip = "The addon's average time in each frame. At 60 fps the whole game has 16.7 ms for a frame." },
		{ label = "Over 10 ms", width = 82, sort = "over10", text = function(e) return over(e, OVER_10) end,
			tip = "Frames where this addon alone took over 10 ms, most of a frame at 60 fps. These are the frames it most likely cost you." },
		{ label = "Over 50 ms", width = 82, sort = "over50", text = function(e) return over(e, OVER_50) end,
			tip = "Frames where this addon alone took over 50 ms: a stutter you can see." },
		{ label = "Worst", width = 82, sort = "worst", text = function(e) return Format.Worst(Model.Worst(e)) end,
			tip = "The addon's slowest frame." },
	},
	sessions = function()
		local list = Play.Recordings()
		if #list == 0 then
			views[2].empty = Play.Problem() or "Nothing recorded yet. Recording starts when the loading screen ends."
		end
		return list
	end,
	lines = function(rec, i, n)
		local share = rec.appMs > 0 and format(", %d%% of the game's time", math.floor(100 * rec.ms / rec.appMs + 0.5)) or ""
		local appHitches, addonHitches = rec.appO[OVER_50], rec.o[OVER_50]
		local line3
		if appHitches > 0 then
			line3 = format("Frames over 50 ms: %s. All addons together took over 50 ms in %s of them.",
				Format.Count(appHitches), Format.Count(addonHitches))
		else
			line3 = "No frames over 50 ms."
		end
		return format("%s%s%s%s%s  %s(%d of %d)|r", rec.char, DOT, rec.date, DOT, playTitle(rec), GREY, i, n),
			format("Played: %s   All addons: |cffffd100%s|r per frame%s",
				Format.Duration(rec.secs), Format.Fine(rec.ms), share),
			GREY .. line3 .. "|r"
	end,
	entries = function(rec, query) return Model.PlayEntries(rec, ns.opts, query, playSort) end,
	size = function(e) return Model.PLAY_SORTS[playSort](e) end,
	color = function(e)
		local worst = Model.Worst(e)
		return worst >= OVER_50 and BAR_SLOW or worst >= OVER_10 and BAR_MEDIUM or BAR_FAST
	end,
	label = function(_, label) return label end,
}

-- The lines on a play row's tooltip: its time per frame and slow frame counts.
local function addPlayDetails(e)
	GameTooltip:AddDoubleLine("Average per frame", Format.Fine(e.ms), 1, 0.82, 0, 1, 1, 1)
	local any = false
	for i, ms in ipairs(Play.THRESHOLDS) do
		local n = Model.Over(e, i)
		if n > 0 then
			any = true
			local limit = ms >= 1000 and format("%g s", ms / 1000) or format("%d ms", ms)
			GameTooltip:AddDoubleLine("Frames over " .. limit, Format.Count(n), 1, 0.82, 0, 1, 1, 1)
		end
	end
	if not any then GameTooltip:AddLine("Never took over 1 ms in a frame.", 0.7, 0.7, 0.7) end
	if e.c then
		GameTooltip:AddLine("Family totals add up its addons, so a frame two of them were slow in counts twice.", 0.7, 0.7, 0.7, true)
	end
end

local function showTooltip(row)
	local e = row.entry
	if not e then return end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:AddLine(e.n, 1, 1, 1)
	if e.members then
		GameTooltip:AddLine(table.concat(e.members, ", "), 0.7, 0.7, 0.7, true)
	end
	if mode == 2 then addPlayDetails(e) end

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

-- Where each column of view v goes: x and width for the name, then each number.
local function columnLayout(v)
	local x = LIST_WIDTH
	local spots = {}
	for i = #v.columns, 1, -1 do
		x = x - v.columns[i].width
		spots[i + 1] = { x = x, width = v.columns[i].width }
	end
	spots[1] = { x = NAME_X, width = x - NAME_X - COLUMN_GAP }
	return spots
end

local function text(parent)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	fs:SetWordWrap(false)
	return fs
end

-- Puts a row's text in the current tab's columns.
local function layoutRow(row)
	local spots = columnLayout(views[mode])
	for i, cell in ipairs(row.cells) do
		local spot = spots[i]
		cell:SetShown(spot ~= nil)
		if spot then
			cell:ClearAllPoints()
			cell:SetPoint("LEFT", spot.x, 0)
			cell:SetWidth(spot.width)
			cell:SetJustifyH(i == 1 and "LEFT" or "RIGHT")
		end
	end
	row.mode = mode
end

local function getRow(i)
	local row = rowFrames[i]
	if not row then
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

		row.cells = {}
		for c = 1, 5 do row.cells[c] = text(row) end
		rowFrames[i] = row
	end
	if row.mode ~= mode then layoutRow(row) end
	return row
end

local function drawRow(row, e, max)
	local v = views[mode]
	local label = v.label(e, e.c and format("%s %s(%d)|r", e.n, GREY, e.c) or e.n)
	local targets = Switch.Targets(e)
	local off = #targets > 0 and not Switch.AnyOn(targets)
	if off then label = label .. " |cffff6060off|r" end
	row.entry = e
	row.cells[1]:SetText(label)
	if off then row.cells[1]:SetTextColor(0.5, 0.5, 0.5) else row.cells[1]:SetTextColor(1, 1, 1) end
	for i, column in ipairs(v.columns) do
		row.cells[i + 1]:SetText(column.text(e))
	end
	local color = v.color(e)
	row.bar:SetColorTexture(color[1], color[2], color[3], color[4])
	row.bar:SetWidth(math.max(1, BAR_WIDTH * v.size(e) / max))
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

local function refreshHeaders()
	for m, headers in ipairs(ui.headers) do
		for _, h in ipairs(headers) do
			h:SetShown(m == mode)
			if h.sort then
				h.text:SetFontObject(h.sort == playSort and "GameFontHighlight" or "GameFontNormal")
			end
		end
	end
end

function Window.Refresh()
	if not ui then return end
	local v = views[mode]
	local sessions = v.sessions()
	local index = math.min(viewIndex[mode], math.max(1, #sessions))
	viewIndex[mode] = index
	local s = sessions[index]
	ui.session = s

	ui.prev:SetEnabled(index < #sessions)
	ui.next:SetEnabled(index > 1)
	refreshFooter()
	refreshHeaders()

	if not s then
		ui.lines[1]:SetText(v.empty)
		ui.lines[2]:SetText("")
		ui.lines[3]:SetText("")
		ui.matches:SetText("")
		for _, row in ipairs(rowFrames) do row:Hide() end
		return
	end

	local l1, l2, l3 = v.lines(s, index, #sessions)
	ui.lines[1]:SetText(l1)
	ui.lines[2]:SetText(l2)
	ui.lines[3]:SetText(l3)

	-- Bars keep the full list's scale while searching.
	local all = v.entries(s)
	local query = strtrim(ui.search:GetText() or "")
	local list = query ~= "" and v.entries(s, query) or all
	if query == "" then
		ui.matches:SetText("")
	elseif #list == 0 then
		ui.matches:SetText("No matches")
	else
		ui.matches:SetText(format("Showing %d of %d", #list, #all))
	end

	local max = 0
	for _, e in ipairs(all) do max = math.max(max, v.size(e)) end
	if max <= 0 then max = 1 end
	for i, e in ipairs(list) do
		drawRow(getRow(i), e, max)
	end
	for i = #list + 1, #rowFrames do rowFrames[i]:Hide() end
	ui.child:SetHeight(math.max(1, #list * ROW_HEIGHT))

	-- Keep an open tooltip in step with a list that just changed under it.
	for _, row in ipairs(rowFrames) do
		if row:IsShown() and GameTooltip:IsOwned(row) then showTooltip(row) end
	end
end

local function makeCheck(parent, label, x, key)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	cb:SetPoint("TOPLEFT", x, OPTIONS_Y)
	local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
	fs:SetText(label)
	cb:SetChecked(ns.opts[key])
	cb:SetScript("OnClick", function(self)
		ns.opts[key] = self:GetChecked() and true or false
		Window.Refresh()
	end)
	return cb
end

-- The column headers for view v. A header with a sort column sorts the list when clicked.
local function makeHeaders(f, v)
	local headers = {}
	local spots = columnLayout(v)
	local function header(label, spot, justify, column)
		local h = CreateFrame("Button", nil, f)
		h:SetPoint("TOPLEFT", 14 + spot.x, HEADER_Y)
		h:SetSize(spot.width, HEADER_HEIGHT)
		h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		h.text:SetAllPoints()
		h.text:SetJustifyH(justify)
		h.text:SetText(label)
		if column and column.sort then
			h.sort = column.sort
			h:SetScript("OnClick", function()
				playSort = column.sort
				Window.Refresh()
			end)
		end
		if column and column.tip then
			h:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_TOP")
				GameTooltip:AddLine(column.label, 1, 1, 1)
				GameTooltip:AddLine(column.tip, 1, 0.82, 0, true)
				if column.sort then GameTooltip:AddLine("Click to sort by this.", 0.6, 0.6, 0.6) end
				GameTooltip:Show()
			end)
			h:SetScript("OnLeave", function() GameTooltip:Hide() end)
		end
		headers[#headers + 1] = h
	end
	header("Addon", spots[1], "LEFT")
	for i, column in ipairs(v.columns) do
		header(column.label, spots[i + 1], "RIGHT", column)
	end
	return headers
end

-- The tab template draws its text small; keep it at the window's text size.
local function selectTab(f, index)
	PanelTemplates_SetTab(f, index)
	for _, tab in ipairs(f.tabs) do
		tab:SetNormalFontObject(GameFontNormal)
		tab:SetHighlightFontObject(GameFontHighlight)
		tab:SetDisabledFontObject(GameFontHighlight)
		PanelTemplates_TabResize(tab, 0)
	end
end

local function setMode(index)
	mode = index
	selectTab(ui, index)
	Window.Refresh()
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
	ui = f

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOP", 0, -5)
	title:SetText("Load Profiler")

	f.lines = {}
	for i, y in ipairs(LINE_Y) do
		local fs = f:CreateFontString(nil, "OVERLAY", i == 1 and "GameFontNormal" or "GameFontHighlight")
		fs:SetPoint("TOPLEFT", 14, y)
		fs:SetWidth(WINDOW_WIDTH - 28)
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(false)
		f.lines[i] = fs
	end

	makeCheck(f, "Group by family", 10, "group")
	makeCheck(f, "Show Blizzard", 160, "blizz")

	f.next = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.next:SetSize(80, 22)
	f.next:SetPoint("TOPRIGHT", -14, OPTIONS_Y - 1)
	f.next:SetText("Newer >")
	f.next:SetScript("OnClick", function() viewIndex[mode] = viewIndex[mode] - 1; Window.Refresh() end)

	f.prev = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.prev:SetSize(80, 22)
	f.prev:SetPoint("RIGHT", f.next, "LEFT", -4, 0)
	f.prev:SetText("< Older")
	f.prev:SetScript("OnClick", function() viewIndex[mode] = viewIndex[mode] + 1; Window.Refresh() end)

	-- SearchBoxTemplate gives the magnifier and clear button; fall back to a plain
	-- input box on any client that doesn't have it.
	local ok, box = pcall(CreateFrame, "EditBox", nil, f, "SearchBoxTemplate")
	local plain = not (ok and box)
	if plain then
		box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
		box.Instructions = box:CreateFontString(nil, "ARTWORK", "GameFontDisable")
		box.Instructions:SetPoint("LEFT", box, "LEFT", 2, 0)
	end
	box.Instructions:SetText("Search addons")
	box.Instructions:SetFontObject("GameFontDisable")
	box:SetFontObject("GameFontHighlight")
	box:SetSize(SEARCH_WIDTH, 20)
	box:SetPoint("TOPLEFT", 20, SEARCH_Y)
	box:SetAutoFocus(false)
	box:HookScript("OnTextChanged", function(self)
		if plain then self.Instructions:SetShown((self:GetText() or "") == "") end
		Window.Refresh()
	end)
	box:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
	f.search = box

	f.matches = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	f.matches:SetPoint("LEFT", box, "RIGHT", 12, 0)

	f.headers = {}
	for m, v in ipairs(views) do f.headers[m] = makeHeaders(f, v) end

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

	-- Tabs under the window. Named, since older clients find tabs by name.
	f.tabs = {}
	for i, v in ipairs(views) do
		local tab = CreateFrame("Button", "LoadProfilerFrameTab" .. i, f, "PanelTabButtonTemplate")
		tab:SetID(i)
		tab:SetText(v.tab)
		if i == 1 then
			tab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 12, 2)
		else
			tab:SetPoint("LEFT", f.tabs[i - 1], "RIGHT", 4, 0)
		end
		tab:SetScript("OnClick", function()
			PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
			setMode(i)
		end)
		f.tabs[i] = tab
	end
	PanelTemplates_SetNumTabs(f, #views)
	selectTab(f, mode)

	-- Redraw the session in progress while it's on screen.
	local sinceRefresh = 0
	f:SetScript("OnUpdate", function(_, elapsed)
		sinceRefresh = sinceRefresh + elapsed
		if sinceRefresh < LIVE_REFRESH then return end
		sinceRefresh = 0
		if f.session and f.session.live then Window.Refresh() end
	end)
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
		viewIndex[mode] = 1
		ui:Show()
		Window.Refresh()
	end
end

-- After the history is cleared.
function Window.Reset()
	viewIndex = { 1, 1 }
	Window.Refresh()
end
