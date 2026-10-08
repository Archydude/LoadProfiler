-- Load Profiler: turning addons on and off for the current character.

local _, ns = ...

local Switch = {}
ns.Switch = Switch

-- Addon list functions: C_AddOns on current clients, plain globals on older ones.
local AddOns = C_AddOns or {
	DisableAddOn = DisableAddOn,
	EnableAddOn = EnableAddOn,
	GetAddOnDependencies = GetAddOnDependencies,
	GetAddOnInfo = GetAddOnInfo,
	IsAddOnLoaded = IsAddOnLoaded,
	-- The old global takes the character first.
	GetAddOnEnableState = function(name, character) return GetAddOnEnableState(character, name) end,
}

local changed = {} -- addons turned on or off from the window since the last reload

function Switch.Me()
	return UnitName("player")
end

local function exists(name)
	if AddOns.DoesAddOnExist then return AddOns.DoesAddOnExist(name) end
	local _, _, _, _, reason = AddOns.GetAddOnInfo(name)
	return reason ~= "MISSING"
end

local function isOn(name)
	return (AddOns.GetAddOnEnableState(name, Switch.Me()) or 0) > 0
end

-- How many addons will load differently after a reload.
function Switch.PendingCount()
	local n = 0
	for name in pairs(changed) do
		if isOn(name) ~= (AddOns.IsAddOnLoaded(name) and true or false) then n = n + 1 end
	end
	return n
end

-- The installed addons a list entry stands for: one addon, or every addon in a family.
-- Blizzard modules are part of the game and can't be turned off.
function Switch.Targets(e)
	local list = {}
	if e.b then return list end
	for _, name in ipairs(e.members or { e.n }) do
		if exists(name) then list[#list + 1] = name end
	end
	return list
end

function Switch.AnyOn(names)
	for _, name in ipairs(names) do
		if isOn(name) then return true end
	end
	return false
end

-- Addons in session s that won't load without one of names.
function Switch.Dependents(names, s)
	local target, list = {}, {}
	for _, name in ipairs(names) do target[name] = true end
	for _, r in ipairs(s.rows) do
		if not r.b and not target[r.n] and exists(r.n) then
			for _, dep in ipairs({ AddOns.GetAddOnDependencies(r.n) }) do
				if target[dep] then
					list[#list + 1] = r.n
					break
				end
			end
		end
	end
	return list
end

-- Turns an entry's addons off for this character, or back on if they're all off already.
function Switch.Toggle(e)
	local names = Switch.Targets(e)
	if #names == 0 then return end
	local on = not Switch.AnyOn(names)
	for _, name in ipairs(names) do
		if on then AddOns.EnableAddOn(name, Switch.Me()) else AddOns.DisableAddOn(name, Switch.Me()) end
		changed[name] = true
	end
	if AddOns.SaveAddOns then AddOns.SaveAddOns() end
end
