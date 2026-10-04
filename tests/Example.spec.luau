--!strict
local Expect = require(script.Parent.Expect)

return {
	["addition works"] = function()
		Expect.equal(1 + 1, 2)
	end,
	["throws is detected"] = function()
		Expect.throws(function()
			error("boom")
		end)
	end,
}
