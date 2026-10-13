-- Load Profiler: what to show for a saved session, as plain tables. No frames here.
--
-- A login session's rows are { n = addon name, ms = load time, kb = memory,
-- b = true for Blizzard modules }. A play recording's rows (Play.lua) have ms =
-- average time per frame and o = frame counts per threshold instead. Families
-- built by the Entries functions also carry c (how many addons) and members
-- (their names).

local _, ns = ...

local Model = {}
ns.Model = Model

-- The family an addon belongs to: its name up to the first "_" or "-"
-- (DBM-Core and DBM-Raids are both "DBM"). All Blizzard modules are one family.
function Model.FamilyOf(r)
	if r.b then return "Blizzard" end
	return r.n:match("^([^_%-]+)") or r.n
end

-- The rows to list: one per addon, or per family when opts.group is on, added
-- up with add(family, row); Blizzard modules only when opts.blizz is on. With a
-- query, only addons whose name contains it (any case), and families add up
-- just those.
local function collect(rows, opts, query, add)
	query = query and query ~= "" and query:lower() or nil
	local list, groups = {}, {}
	for _, r in ipairs(rows) do
		if (opts.blizz or not r.b) and (not query or r.n:lower():find(query, 1, true)) then
			if opts.group then
				local key = Model.FamilyOf(r)
				local g = groups[key]
				if not g then
					g = { n = key, ms = 0, c = 0, b = r.b, members = {} }
					groups[key] = g
					list[#list + 1] = g
				end
				g.ms = g.ms + r.ms
				g.c = g.c + 1
				g.members[g.c] = r.n
				add(g, r)
			else
				list[#list + 1] = r
			end
		end
	end
	return list
end

-- The window's list for login session s, slowest first.
function Model.Entries(s, opts, query)
	local list = collect(s.rows, opts, query, function(g, r)
		g.kb = (g.kb or 0) + (r.kb or 0)
	end)
	table.sort(list, function(a, b) return a.ms > b.ms end)
	return list
end

-- How many frames a play row took longer than Play.THRESHOLDS[i] ms.
function Model.Over(e, i)
	return e.o and e.o[i] or 0
end

-- A play row's worst frame, as the index of the highest threshold it went over (0 for none).
function Model.Worst(e)
	for i = #ns.Play.THRESHOLDS, 1, -1 do
		if Model.Over(e, i) > 0 then return i end
	end
	return 0
end

-- What a play list can be sorted by: a number per row, biggest first.
Model.PLAY_SORTS = {
	ms = function(e) return e.ms end,
	over10 = function(e) return Model.Over(e, 3) end,
	over50 = function(e) return Model.Over(e, 4) end,
	worst = Model.Worst,
}

-- The window's list for play recording rec, sorted by sortKey (see PLAY_SORTS),
-- then by time per frame.
function Model.PlayEntries(rec, opts, query, sortKey)
	local list = collect(rec.rows, opts, query, function(g, r)
		if r.o then
			g.o = g.o or {}
			for i, n in ipairs(r.o) do g.o[i] = (g.o[i] or 0) + n end
		end
	end)
	local key = Model.PLAY_SORTS[sortKey] or Model.PLAY_SORTS.ms
	table.sort(list, function(a, b)
		local ka, kb = key(a), key(b)
		if ka ~= kb then return ka > kb end
		return a.ms > b.ms
	end)
	return list
end

-- Every addon in session s except Blizzard modules, slowest first.
function Model.Slowest(s)
	local top = {}
	for _, r in ipairs(s.rows) do
		if not r.b then top[#top + 1] = r end
	end
	table.sort(top, function(a, b) return a.ms > b.ms end)
	return top
end

-- Whatever isn't addon loading or login init is the game itself (world, character, Blizzard UI).
function Model.GameMs(s)
	return math.max(0, s.totalMs - s.addonMs - s.initMs)
end
