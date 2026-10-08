-- Load Profiler: numbers as display text.

local _, ns = ...

local format = string.format

local Format = {}
ns.Format = Format

function Format.Time(ms)
	if ms >= 1000 then return format("%.2f s", ms / 1000) end
	return format("%.0f ms", ms)
end

function Format.Memory(kb)
	if not kb then return "" end
	if kb >= 1024 then return format("%.1f MB", kb / 1024) end
	return format("%d KB", kb)
end
