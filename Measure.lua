-- Load Profiler: timing.
-- The folder name starts with "!!" so the client loads this addon before
-- (almost) everything else, and this file loads first in it, so the clock
-- starts as early as possible. From then on, the time between consecutive
-- ADDON_LOADED events is the time the client spent running that addon's
-- files and reading its saved variables.

local _, ns = ...

local clock = debugprofilestop
local startTime = clock()

local Measure = {}
ns.Measure = Measure
Measure.Now = clock

local MAX_SESSIONS = 10 -- sessions kept in the history

local lastMark = startTime    -- when the previous addon finished, or our own handler ended
local lastAddonAt = startTime -- when the last addon finished loading
local loginAt                 -- when PLAYER_LOGIN fired
local rows = {}               -- this login's addons, in load order
local stack = {}              -- nested addons whose ADDON_LOADED handlers are still running

local function round1(ms)
	return math.floor(ms * 10 + 0.5) / 10
end

-- An addon (other than this one) finished loading at now.
function Measure.AddonLoaded(name, now)
	-- t = when it finished (ms since we started); late = loaded after PLAYER_LOGIN,
	-- in which case the gap before it also covers the game's own world loading.
	local row = {
		n = name, ms = now - lastMark, t = round1(now - startTime),
		b = name:find("^Blizzard_") and true or nil, late = loginAt and true or nil,
	}
	stack[#stack + 1] = row
	rows[#rows + 1] = row
	if not loginAt then lastAddonAt = now end
end

-- Restarts the clock after our own event handler, so its cost isn't counted.
function Measure.Restart()
	lastMark = clock()
end

-- Every other ADDON_LOADED handler has run. That's mostly the addon setting
-- itself up now that it's loaded, so the time counts on it; otherwise it would
-- land on the next addon to load.
function Measure.SetupDone(name, now)
	if type(name) == "number" and now == nil then name, now = nil, name end
	for i = #stack, 1, -1 do
		if not name or stack[i].n == name then
			local row = table.remove(stack, i)
			row.ms = row.ms + (now - lastMark)
			break
		end
	end
	lastMark = clock()
end

function Measure.Login(now)
	loginAt = now
end

-- Closes this login's session at PLAYER_ENTERING_WORLD and adds it to the front
-- of the history.
function Measure.Finish(now, isInitialLogin, isReload)
	local getMem = GetAddOnMemoryUsage
	-- Memory reads are guarded: one failing here would lose the whole session.
	if UpdateAddOnMemoryUsage then pcall(UpdateAddOnMemoryUsage) end

	local addonMs, blizzMs = 0, 0
	for _, r in ipairs(rows) do
		if getMem then
			local ok, kb = pcall(getMem, r.n)
			if ok and kb then r.kb = math.floor(kb) end
		end
		if not r.late then
			if r.b then blizzMs = blizzMs + r.ms else addonMs = addonMs + r.ms end
		end
		r.late = nil
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

	local sessions = ns.db.sessions
	table.insert(sessions, 1, session)
	for i = #sessions, MAX_SESSIONS + 1, -1 do sessions[i] = nil end

	return session
end
