-- Load Profiler: startup. Saved data, events, the chat summary and /lp.

local ADDON_NAME, ns = ...

local format = string.format
local Format, Measure, Model, Window = ns.Format, ns.Measure, ns.Model, ns.Window

local SUMMARY_DELAY = 3 -- seconds after entering the world before the chat summary
local SUMMARY_COUNT = 5 -- slowest addons named in it

local DEFAULT_OPTS = { group = false, blizz = false }

local function loadSettings()
	LoadProfilerDB = LoadProfilerDB or {}
	local db = LoadProfilerDB
	db.sessions = db.sessions or {}
	db.opts = db.opts or {}
	for key, value in pairs(DEFAULT_OPTS) do
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

SLASH_LOADPROFILER1 = "/lp"
SLASH_LOADPROFILER2 = "/loadprofiler"
SlashCmdList.LOADPROFILER = function(msg)
	msg = strtrim((msg or ""):lower())
	if msg == "reset" then
		wipe(ns.db.sessions)
		Window.Reset()
		print("|cffff9933Load Profiler:|r history cleared.")
	else
		Window.Toggle()
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
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
	elseif event == "PLAYER_ENTERING_WORLD" then
		self:UnregisterAllEvents()
		local isInitialLogin, isReload = ...
		local session = Measure.Finish(now, isInitialLogin, isReload)
		C_Timer.After(SUMMARY_DELAY, function() printSummary(session) end)
	end
end)
