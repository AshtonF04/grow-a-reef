--!strict
-- Argument shape checks for anything that arrives from a client (which may be forged or wrong-typed).
local Validate = {}

function Validate.IsString(v: any, maxLen: number): boolean
	return type(v) == "string" and #v > 0 and #v <= maxLen
end

function Validate.IsInteger(v: any, min: number, max: number): boolean
	return type(v) == "number" and v == v and math.floor(v) == v and v >= min and v <= max
end

function Validate.IsKnownId(v: any, tbl: { [string]: any }): boolean
	return type(v) == "string" and #v <= 64 and tbl[v] ~= nil
end

return Validate
