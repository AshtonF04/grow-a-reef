-- Just enough of Roblox for the shared rules and PlayerStateService to run in the Luau CLI.

__modules = {}
local cache = {}
function __require(name)
	if cache[name] == nil then
		local loader = __modules[name]
		assert(loader, "no module named " .. tostring(name))
		cache[name] = loader()
	end
	return cache[name]
end

__clock = 1000000

game = {
	GetService = function()
		return {}
	end,
}

workspace = {
	GetServerTimeNow = function()
		return __clock
	end,
}

local realTypeof = typeof
typeof = function(value)
	if type(value) == "table" and rawget(value, "UserId") ~= nil then
		return "Instance"
	end
	return realTypeof(value)
end
