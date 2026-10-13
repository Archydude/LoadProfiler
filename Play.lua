-- Load Profiler: how much each addon costs while you play.
-- The game's addon profiler keeps running counts per addon since the game
-- started: frames where the addon took over 1, 5, 10 ... ms. A recording reads
-- them when it starts and keeps the difference, leaving loading screens out.
-- The profiler also has each addon's average over its last 60 frames; adding
-- that up every 60 frames gives the addon's total time, and so its average per
-- frame, over the recording.
--
-- Recordings: one per play session (login or /reload until logout or the next
-- /reload) and one per boss fight. Rows are { n = addon name, ms = average ms
-- per frame, o = frame counts per threshold, b = true for Blizzard modules }.

local ADDON_NAME, ns = ...

local Play = {}
ns.Play = Play

local Profiler = C_AddOnProfiler
local Metric = Enum and Enum.AddOnProfilerMetric
local isSecret = issecretvalue or function() return false end

local RECENT_FRAMES = 60   -- frames in the profiler's recent average
local MAX_SESSIONS = 10    -- play sessions kept in the history
local MAX_FIGHTS = 20      -- boss fights kept in the history
local MIN_SESSION_SECS = 60
local MIN_FIGHT_SECS = 10
local LOADING_FALLBACK = 15 -- seconds after login to start anyway if the loading screen never reports ending

-- The frame times the profiler counts, in ms, in the order of a row's o.
Play.THRESHOLDS = { 1, 5, 10, 50, 100, 500, 1000 }
local COUNT_METRICS = Metric and {
	Metric.CountTimeOver1Ms, Metric.CountTimeOver5Ms, Metric.CountTimeOver10Ms, Metric.CountTimeOver50Ms,
	Metric.CountTimeOver100Ms, Metric.CountTimeOver500Ms, Metric.CountTimeOver1000Ms,
}

-- Keys for the totals: all addons together, and the whole game.
local ALL, APP = "\1all", "\1app"

local keys = { ALL, APP } -- what's read each sample: the totals, then every loaded addon
local watched = {}        -- addon name -> true once it's in keys
local periods = {}        -- recordings in progress: play, and boss during a fight
local started = false
local running = false     -- false during loading screens
local frames = 0          -- frames since the last sample
local loadingEvents = false -- whether a loading screen has reported starting or ending

-- Why there's nothing to measure, or nil when the profiler works.
function Play.Problem()
	if not (Profiler and Profiler.GetAddOnMetric and COUNT_METRICS) then
		return "This version of the game doesn't measure addon performance."
	end
	if Profiler.IsEnabled and not Profiler.IsEnabled() then
		return "The game's addon performance measuring is turned off right now, so there's nothing to record."
	end
end

-- One profiler value, or nil when the game won't give it.
local function value(key, metric)
	local ok, v
	if key == ALL then
		ok, v = pcall(Profiler.GetOverallMetric, metric)
	elseif key == APP then
		ok, v = pcall(Profiler.GetApplicationMetric, metric)
	else
		ok, v = pcall(Profiler.GetAddOnMetric, key, metric)
	end
	if ok and not isSecret(v) and type(v) == "number" then return v end
end

local function readCounts(key)
	local c = {}
	for i, metric in ipairs(COUNT_METRICS) do c[i] = value(key, metric) or 0 end
	return c
end

local function round3(x)
	return math.floor(x * 1000 + 0.5) / 1000
end

-- A recording's counts so far: finished stretches plus the one running now.
local function countsSoFar(p, key)
	local acc, base = p.acc[key], p.base and p.base[key]
	local cur = base and readCounts(key)
	local c = {}
	for i = 1, #COUNT_METRICS do
		c[i] = (acc and acc[i] or 0) + (cur and math.max(0, cur[i] - base[i]) or 0)
	end
	return c
end

local function startStretch(p)
	p.base, p.stretchAt = {}, GetTime()
	for _, key in ipairs(keys) do p.base[key] = readCounts(key) end
end

local function endStretch(p)
	if not p.base then return end
	for _, key in ipairs(keys) do p.acc[key] = countsSoFar(p, key) end
	p.secs = p.secs + (GetTime() - p.stretchAt)
	p.base = nil
end

local function newPeriod(kind, name)
	local p = {
		kind = kind, name = name,
		date = date("%Y-%m-%d %H:%M"),
		char = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?"),
		secs = 0, frames = 0, total = {}, acc = {},
	}
	if running then startStretch(p) end
	return p
end

-- Adds the last n frames' time to every recording in progress.
local function sample(n)
	frames = 0
	if n <= 0 then return end
	for _, key in ipairs(keys) do
		local v = value(key, Metric.RecentAverageTime)
		if v then
			for _, p in pairs(periods) do p.total[key] = (p.total[key] or 0) + v * n end
		end
	end
	for _, p in pairs(periods) do p.frames = p.frames + n end
end

local ticker = CreateFrame("Frame")
ticker:Hide()
ticker:SetScript("OnUpdate", function()
	frames = frames + 1
	if frames >= RECENT_FRAMES then sample(frames) end
end)

local function resume()
	if running then return end
	running = true
	frames = 0
	for _, p in pairs(periods) do startStretch(p) end
	ticker:Show()
end

local function pause()
	if not running then return end
	sample(frames)
	for _, p in pairs(periods) do endStretch(p) end
	running = false
	ticker:Hide()
end

local function watch(name)
	if not name or watched[name] then return end
	watched[name] = true
	keys[#keys + 1] = name
	for _, p in pairs(periods) do
		if p.base then p.base[name] = readCounts(name) end
	end
end

-- What a recording shows: a saved one's shape, made from one in progress.
local function snapshot(p)
	local rec = {
		kind = p.kind, name = p.name, date = p.date, char = p.char, success = p.success,
		secs = math.floor(p.secs + (p.base and GetTime() - p.stretchAt or 0)),
		frames = p.frames, rows = {},
	}
	local function avg(key)
		return p.frames > 0 and round3((p.total[key] or 0) / p.frames) or 0
	end
	rec.ms, rec.o = avg(ALL), countsSoFar(p, ALL)
	rec.appMs, rec.appO = avg(APP), countsSoFar(p, APP)
	for i = 3, #keys do
		local name = keys[i]
		local o = countsSoFar(p, name)
		rec.rows[#rec.rows + 1] = {
			n = name, ms = avg(name),
			o = o[1] > 0 and o or nil, -- every count is 0 when it never took over 1 ms
			b = name:find("^Blizzard_") and true or nil,
		}
	end
	return rec
end

-- Adds rec to the front of the history, keeping the newest sessions and fights.
local function save(rec)
	local kept, count = { rec }, { [rec.kind] = 1 }
	for _, r in ipairs(ns.db.play) do
		count[r.kind] = (count[r.kind] or 0) + 1
		if count[r.kind] <= (r.kind == "boss" and MAX_FIGHTS or MAX_SESSIONS) then kept[#kept + 1] = r end
	end
	ns.db.play = kept
end

local function finish(kind)
	local p = periods[kind]
	if not p then return end
	if running then
		sample(frames)
		endStretch(p)
	end
	periods[kind] = nil
	if p.secs >= (kind == "boss" and MIN_FIGHT_SECS or MIN_SESSION_SECS) then
		save(snapshot(p))
	end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		watch((...))
	elseif event == "LOADING_SCREEN_ENABLED" then
		loadingEvents = true
		pause()
	elseif event == "LOADING_SCREEN_DISABLED" then
		loadingEvents = true
		resume()
	elseif event == "ENCOUNTER_START" then
		local _, name = ...
		finish("boss")
		periods.boss = newPeriod("boss", type(name) == "string" and not isSecret(name) and name or nil)
	elseif event == "ENCOUNTER_END" then
		local success = select(5, ...)
		if periods.boss then periods.boss.success = success == 1 or nil end
		finish("boss")
	elseif event == "PLAYER_LOGOUT" then
		finish("boss")
		finish("play")
	end
end)

-- Starts the play session's recording once the login's loading screen ends.
-- rows: the addons that loaded at login.
function Play.Start(rows)
	if started or Play.Problem() then return end
	started = true
	watch(ADDON_NAME)
	for _, r in ipairs(rows) do watch(r.n) end
	periods.play = newPeriod("play")
	for _, event in ipairs({ "ADDON_LOADED", "LOADING_SCREEN_ENABLED", "LOADING_SCREEN_DISABLED",
		"ENCOUNTER_START", "ENCOUNTER_END", "PLAYER_LOGOUT" }) do
		events:RegisterEvent(event)
	end
	C_Timer.After(LOADING_FALLBACK, function()
		if not loadingEvents then resume() end
	end)
end

-- The play session so far, then the saved recordings, newest first.
function Play.Recordings()
	local list = {}
	if periods.play then
		if running then sample(frames) end
		local live = snapshot(periods.play)
		live.live = true
		list[1] = live
	end
	for _, rec in ipairs(ns.db.play) do list[#list + 1] = rec end
	return list
end

function Play.IsLive()
	return periods.play ~= nil
end
