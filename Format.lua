-- Load Profiler: numbers as display text.

local _, ns = ...

local format = string.format

local Format = {}
ns.Format = Format

function Format.Time(ms)
	if ms >= 1000 then return format("%.2f s", ms / 1000) end
	return format("%.0f ms", ms)
end

-- Small times, like an addon's average per frame.
function Format.Fine(ms)
	if ms >= 100 then return format("%.0f ms", ms) end
	if ms >= 10 then return format("%.1f ms", ms) end
	return format("%.2f ms", ms)
end

function Format.Memory(kb)
	if not kb then return "" end
	if kb >= 1024 then return format("%.1f MB", kb / 1024) end
	return format("%d KB", kb)
end

-- A whole number with thousands separators: 12,345.
function Format.Count(n)
	local s = tostring(math.floor(n))
	local formatted
	repeat
		s, formatted = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
	until formatted == 0
	return s
end

-- A length of time in seconds: 45 s, 12 min, 1 h 05 min.
function Format.Duration(secs)
	if secs < 60 then return format("%d s", secs) end
	if secs < 3600 then return format("%d min", math.floor(secs / 60)) end
	return format("%d h %02d min", math.floor(secs / 3600), math.floor(secs % 3600 / 60))
end

-- The range a play row's worst frame falls in, from the index of the highest
-- threshold it went over (Model.Worst).
function Format.Worst(i)
	local t = ns.Play.THRESHOLDS
	local function ms(x) return x >= 1000 and format("%g s", x / 1000) or format("%g", x) end
	if i == 0 then return format("under %d ms", t[1]) end
	if i == #t then return "over " .. ms(t[i]) end
	if t[i + 1] >= 1000 then return format("%g-%s", t[i] / 1000, ms(t[i + 1])) end
	return format("%s-%s ms", ms(t[i]), ms(t[i + 1]))
end
