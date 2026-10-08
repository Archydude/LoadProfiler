-- Load Profiler: what to show for a saved session, as plain tables. No frames here.
--
-- A session's rows are { n = addon name, ms = load time, kb = memory,
-- b = true for Blizzard modules }. Families built by Model.Entries also carry
-- c (how many addons) and members (their names).

local _, ns = ...

local Model = {}
ns.Model = Model

-- The family an addon belongs to: its name up to the first "_" or "-"
-- (DBM-Core and DBM-Raids are both "DBM"). All Blizzard modules are one family.
function Model.FamilyOf(r)
	if r.b then return "Blizzard" end
	return r.n:match("^([^_%-]+)") or r.n
end

-- The window's list for session s: one entry per addon, or per family when
-- opts.group is on; Blizzard modules only when opts.blizz is on. Slowest first.
-- With a query, only addons whose name contains it (any case) are listed, and
-- families add up just those.
function Model.Entries(s, opts, query)
	query = query and query ~= "" and query:lower() or nil
	local list, groups = {}, {}
	for _, r in ipairs(s.rows) do
		if (opts.blizz or not r.b) and (not query or r.n:lower():find(query, 1, true)) then
			if opts.group then
				local key = Model.FamilyOf(r)
				local g = groups[key]
				if not g then
					g = { n = key, ms = 0, kb = 0, c = 0, b = r.b, members = {} }
					groups[key] = g
					list[#list + 1] = g
				end
				g.ms = g.ms + r.ms
				g.kb = g.kb + (r.kb or 0)
				g.c = g.c + 1
				g.members[g.c] = r.n
			else
				list[#list + 1] = r
			end
		end
	end
	table.sort(list, function(a, b) return a.ms > b.ms end)
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
