--!strict
-- Tiny assertion helpers for specs. Each failure error()s with a readable message.
local Expect = {}

local function prefix(label: string?): string
	return if label then label .. ": " else ""
end

function Expect.equal(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(prefix(label) .. "expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

function Expect.near(actual: number, expected: number, epsilon: number?, label: string?)
	if math.abs(actual - expected) > (epsilon or 1e-6) then
		error(prefix(label) .. "expected ~" .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

function Expect.truthy(value: any, label: string?)
	if not value then
		error(prefix(label) .. "expected truthy, got " .. tostring(value), 2)
	end
end

function Expect.falsy(value: any, label: string?)
	if value then
		error(prefix(label) .. "expected falsy, got " .. tostring(value), 2)
	end
end

function Expect.throws(fn: () -> (), label: string?)
	local ok = pcall(fn)
	if ok then
		error(prefix(label) .. "expected an error, but none was thrown", 2)
	end
end

return Expect
