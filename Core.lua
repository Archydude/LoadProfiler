-- Load Profiler: startup. Saved data, events, the chat summary and /lp.

local ADDON_NAME, ns = ...

local format = string.format
local Format, Measure, MinimapButton, Model, Options, Window =
	ns.Format, ns.Measure, ns.MinimapButton, ns.Model, ns.Options, ns.Window

local SUMMARY_DELAY = 3 -- seconds after entering the world before the chat summary
local SUMMARY_COUNT = 5 -- slowest addons named in it

ns.DEFAULT_OPTS = {
	group = false,      -- window: group by addon family
	blizz = false,      -- window: show Blizzard modules
	minimap = true,     -- minimap button
	summary = true,     -- chat summary after each login
	-- minimapIcon: the minimap button's position, made at login and kept by LibDBIcon
}

local function loadSettings()
	LoadProfilerDB = LoadProfilerDB or {}
	local db = LoadProfilerDB
	db.sessions = db.sessions or {}
	db.opts = db.opts or {}
	for key, value in pairs(ns.DEFAULT_OPTS) do
		if db.opts[key] == nil then db.opts[key] = value end
	end
	ns.db, ns.opts = db, db.opts
end

local function printSummary(s)
	local top = Model.Slowest(s)
	local parts = {}
	for i = 1, math.min(SUMMARY_COUNT, #top) do
		parts[i] = format("%s (%s)", top[i].n, Format.Time(top[i].ms))
	end
	print(format("|cffff9933Load Profiler:|r %d addons took %s to load%s. Slowest: %s. Type |cffffff00/lp|r for the full list.",
		s.count, Format.Time(s.addonMs), s.kind == "reload" and " (/reload, cached)" or "",
		#parts > 0 and table.concat(parts, ", ") or "none"))
end

-- /lp reset, and Clear in the options.
function ns.ClearHistory()
	wipe(ns.db.sessions)
	Window.Reset()
	print("|cffff9933Load Profiler:|r history cleared.")
end

SLASH_LOADPROFILER1 = "/lp"
SLASH_LOADPROFILER2 = "/loadprofiler"
SlashCmdList.LOADPROFILER = function(msg)
	msg = strtrim((msg or ""):lower())
	if msg == "reset" then
		ns.ClearHistory()
	elseif msg == "minimap" then
		MinimapButton.Toggle()
	elseif msg == "options" or msg == "config" then
		Options.Open()
	else
		Window.Toggle()
	end
end

-- Two listeners time each ADDON_LOADED: `events` hears it first (it registered
-- before any other addon loaded) and `tail` hears it after every other addon's
-- handler. Frames hear an event in the order they registered for it, so
-- whenever another frame registers for ADDON_LOADED, tail registers again to
-- stay last. If it ever isn't last, that addon is simply timed without its setup.
local tail = CreateFrame("Frame")
local measuring, moving = true, false

local function keepTailLast(frame, event)
	if not measuring or moving or event ~= "ADDON_LOADED" or frame == tail then return end
	moving = true
	tail:UnregisterEvent("ADDON_LOADED")
	tail:RegisterEvent("ADDON_LOADED")
	moving = false
end

-- Widget kinds addons register events on. Each kind has its own method table.
local hooked = {}
for _, kind in ipairs({ "Frame", "Button", "CheckButton", "StatusBar", "ScrollFrame", "Slider" }) do
	local methods = getmetatable(CreateFrame(kind)).__index
	if type(methods) == "table" and not hooked[methods] then
		hooked[methods] = true
		hooksecurefunc(methods, "RegisterEvent", keepTailLast)
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")

tail:RegisterEvent("ADDON_LOADED")
tail:SetScript("OnEvent", function()
	Measure.SetupDone(Measure.Now())
end)
events:SetScript("OnEvent", function(self, event, ...)
	local now = Measure.Now()
	if event == "ADDON_LOADED" then
		local name = ...
		if name == ADDON_NAME then
			loadSettings()
		else
			Measure.AddonLoaded(name, now)
		end
		Measure.Restart()
	elseif event == "PLAYER_LOGIN" then
		Measure.Login(now)
		MinimapButton.Create()
		Options.Create()
	elseif event == "PLAYER_ENTERING_WORLD" then
		self:UnregisterAllEvents()
		measuring = false
		tail:UnregisterAllEvents()
		local isInitialLogin, isReload = ...
		local session = Measure.Finish(now, isInitialLogin, isReload)
		if ns.opts.summary then
			C_Timer.After(SUMMARY_DELAY, function() printSummary(session) end)
		end
	end
end)
