-- Load Profiler
-- The folder name starts with "!!" so the client loads this addon before
-- (almost) everything else. From then on, the time between consecutive
-- ADDON_LOADED events is the time the client spent running that addon's
-- files and reading its saved variables.

local ADDON_NAME = ...
local clock = debugprofilestop
local floor, format = math.floor, string.format

local MAX_SESSIONS = 10
local ROW_HEIGHT = 16

local startTime = clock()
local lastMark = startTime
local lastAddonAt = startTime
local loginAt
local rows = {}
local db, opts

---------------------------------------------------------------------------
-- Measurement
---------------------------------------------------------------------------

local function round1(ms)
	return floor(ms * 10 + 0.5) / 10
end

local function finish(now, isInitialLogin, isReload)
	local getMem = GetAddOnMemoryUsage
	if UpdateAddOnMemoryUsage then pcall(UpdateAddOnMemoryUsage) end

	local addonMs, blizzMs = 0, 0
	for _, r in ipairs(rows) do
		if getMem then
			local ok, kb = pcall(getMem, r.n)
			if ok and kb then r.kb = floor(kb) end
		end
		if r.b then blizzMs = blizzMs + r.ms else addonMs = addonMs + r.ms end
		r.ms = round1(r.ms)
	end

	local kind = isReload and "reload" or (isInitialLogin and "login" or "other")
	local session = {
		date = date("%Y-%m-%d %H:%M"),
		char = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?"),
		kind = kind,
		count = #rows,
		addonMs = round1(addonMs),
		blizzMs = round1(blizzMs),
		addonPhaseMs = round1(lastAddonAt - startTime),
		initMs = round1(now - (loginAt or now)),
		totalMs = round1(now - startTime),
		rows = rows,
	}

	local sessions = db.sessions
	table.insert(sessions, 1, session)
	for i = #sessions, MAX_SESSIONS + 1, -1 do sessions[i] = nil end

	return session
end

local function fmtTime(ms)
	if ms >= 1000 then return format("%.2f s", ms / 1000) end
	return format("%.0f ms", ms)
end

local function fmtMem(kb)
	if not kb then return "" end
	if kb >= 1024 then return format("%.1f MB", kb / 1024) end
	return format("%d KB", kb)
end

local function printSummary(s)
	local top = {}
	for _, r in ipairs(s.rows) do
		if not r.b then top[#top + 1] = r end
	end
	table.sort(top, function(a, b) return a.ms > b.ms end)

	local parts = {}
	for i = 1, math.min(5, #top) do
		parts[i] = format("%s (%s)", top[i].n, fmtTime(top[i].ms))
	end
	print(format("|cffff9933Load Profiler:|r %d addons took %s to load%s. Slowest: %s. Type |cffffff00/lp|r for the full list.",
		s.count, fmtTime(s.addonMs), s.kind == "reload" and " (/reload, cached)" or "",
		#parts > 0 and table.concat(parts, ", ") or "none"))
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local ui
local viewIndex = 1
local rowFrames = {}

local function familyOf(r)
	if r.b then return "Blizzard" end
	return r.n:match("^([^_%-]+)") or r.n
end

local function buildList(s)
	local list, groups = {}, {}
	for _, r in ipairs(s.rows) do
		if opts.blizz or not r.b then
			if opts.group then
				local key = familyOf(r)
				local g = groups[key]
				if not g then
					g = { n = key, ms = 0, kb = 0, c = 0 }
					groups[key] = g
					list[#list + 1] = g
				end
				g.ms = g.ms + r.ms
				g.kb = g.kb + (r.kb or 0)
				g.c = g.c + 1
			else
				list[#list + 1] = r
			end
		end
	end
	table.sort(list, function(a, b) return a.ms > b.ms end)
	return list
end

local function getRow(i)
	local row = rowFrames[i]
	if row then return row end

	row = CreateFrame("Frame", nil, ui.child)
	row:SetSize(460, ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)

	row.bar = row:CreateTexture(nil, "BACKGROUND")
	row.bar:SetPoint("LEFT")
	row.bar:SetHeight(ROW_HEIGHT - 2)

	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.name:SetPoint("LEFT", 4, 0)
	row.name:SetWidth(280)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)

	row.ms = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.ms:SetPoint("LEFT", 290, 0)
	row.ms:SetWidth(80)
	row.ms:SetJustifyH("RIGHT")

	row.kb = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.kb:SetPoint("LEFT", 375, 0)
	row.kb:SetWidth(80)
	row.kb:SetJustifyH("RIGHT")

	rowFrames[i] = row
	return row
end

local KIND_LABEL = { login = "Cold login", reload = "/reload", other = "Other" }

local function refresh()
	if not ui then return end
	local sessions = db.sessions
	local s = sessions[viewIndex]

	ui.prev:SetEnabled(viewIndex < #sessions)
	ui.next:SetEnabled(viewIndex > 1)

	if not s then
		ui.line1:SetText("No data yet. Log out and back in to record a session.")
		ui.line2:SetText("")
		ui.line3:SetText("")
		for _, row in ipairs(rowFrames) do row:Hide() end
		return
	end

	ui.line1:SetText(format("%s  |cff888888·|r  %s  |cff888888·|r  %s  |cff888888(%d of %d)|r",
		s.char, s.date, KIND_LABEL[s.kind] or s.kind, viewIndex, #sessions))
	-- Whatever isn't addon loading or login init is the game itself (world, character, Blizzard UI).
	local gameMs = math.max(0, s.totalMs - s.addonMs - s.initMs)
	ui.line2:SetText(format("Addons loading: |cffffd100%s|r   Login init: %s   Game itself: %s   Total: %s",
		fmtTime(s.addonMs), fmtTime(s.initMs), fmtTime(gameMs), fmtTime(s.totalMs)))
	ui.line3:SetText(s.kind == "reload"
		and "|cff888888A /reload reads cached files and is faster. Compare cold logins for real numbers.|r"
		or "|cff888888Login init = all addons' startup code after loading, combined (can't be split per addon).|r")

	local list = buildList(s)
	local max = (list[1] and list[1].ms > 0) and list[1].ms or 1
	for i, e in ipairs(list) do
		local row = getRow(i)
		local label = e.c and format("%s |cff888888(%d)|r", e.n, e.c) or e.n
		-- A big gap before a Blizzard module is the game loading, not that module.
		if e.b and not e.c and e.ms >= 1000 then
			label = label .. " |cff888888(mostly game loading)|r"
		end
		row.name:SetText(label)
		row.ms:SetText(fmtTime(e.ms))
		row.kb:SetText(fmtMem(e.kb))
		if e.ms >= 500 then
			row.bar:SetColorTexture(1, 0.2, 0.2, 0.35)
		elseif e.ms >= 100 then
			row.bar:SetColorTexture(1, 0.6, 0.1, 0.30)
		else
			row.bar:SetColorTexture(0.4, 0.7, 1, 0.20)
		end
		row.bar:SetWidth(math.max(1, 456 * e.ms / max))
		row:Show()
	end
	for i = #list + 1, #rowFrames do rowFrames[i]:Hide() end
	ui.child:SetHeight(math.max(1, #list * ROW_HEIGHT))
end

local function makeCheck(parent, label, x, key)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	cb:SetPoint("TOPLEFT", x, -78)
	local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
	text:SetText(label)
	cb:SetChecked(opts[key])
	cb:SetScript("OnClick", function(self)
		opts[key] = self:GetChecked() and true or false
		refresh()
	end)
	return cb
end

local function createUI()
	local f = CreateFrame("Frame", "LoadProfilerFrame", UIParent, "BasicFrameTemplateWithInset")
	f:SetSize(520, 500)
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
	f.next:SetPoint("TOPRIGHT", -14, -79)
	f.next:SetText("Newer >")
	f.next:SetScript("OnClick", function() viewIndex = viewIndex - 1; refresh() end)

	f.prev = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.prev:SetSize(70, 22)
	f.prev:SetPoint("RIGHT", f.next, "LEFT", -4, 0)
	f.prev:SetText("< Older")
	f.prev:SetScript("OnClick", function() viewIndex = viewIndex + 1; refresh() end)

	local function header(text, x, width, justify)
		local h = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		h:SetPoint("TOPLEFT", 14 + x, -108)
		h:SetWidth(width)
		h:SetJustifyH(justify)
		h:SetText(text)
	end
	header("Addon", 4, 280, "LEFT")
	header("Load time", 290, 80, "RIGHT")
	header("Memory", 375, 80, "RIGHT")

	local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 14, -124)
	scroll:SetPoint("BOTTOMRIGHT", -34, 12)
	f.child = CreateFrame("Frame", nil, scroll)
	f.child:SetSize(460, 1)
	scroll:SetScrollChild(f.child)

	ui = f
end

local function toggleUI()
	if not ui then
		createUI()
		ui:Hide()
	end
	if ui:IsShown() then
		ui:Hide()
	else
		viewIndex = 1
		ui:Show()
		refresh()
	end
end

SLASH_LOADPROFILER1 = "/lp"
SLASH_LOADPROFILER2 = "/loadprofiler"
SlashCmdList.LOADPROFILER = function(msg)
	msg = strtrim((msg or ""):lower())
	if msg == "reset" then
		wipe(db.sessions)
		viewIndex = 1
		refresh()
		print("|cffff9933Load Profiler:|r history cleared.")
	else
		toggleUI()
	end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self, event, ...)
	local now = clock()
	if event == "ADDON_LOADED" then
		local name = ...
		if name == ADDON_NAME then
			LoadProfilerDB = LoadProfilerDB or {}
			db = LoadProfilerDB
			db.sessions = db.sessions or {}
			db.opts = db.opts or { group = false, blizz = false }
			opts = db.opts
		else
			-- t = when it finished (ms since we started); late = loaded after PLAYER_LOGIN,
			-- in which case the gap before it also covers the game's own world loading.
			rows[#rows + 1] = {
				n = name, ms = now - lastMark, t = round1(now - startTime),
				b = name:find("^Blizzard_") and true or nil, late = loginAt and true or nil,
			}
			lastAddonAt = now
		end
		-- Restart the clock after our own handler so its cost isn't counted.
		lastMark = clock()
	elseif event == "PLAYER_LOGIN" then
		loginAt = now
	elseif event == "PLAYER_ENTERING_WORLD" then
		self:UnregisterAllEvents()
		local isInitialLogin, isReload = ...
		local session = finish(now, isInitialLogin, isReload)
		C_Timer.After(3, function() printSummary(session) end)
	end
end)
