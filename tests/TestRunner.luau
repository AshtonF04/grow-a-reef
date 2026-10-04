--!strict
-- Runs every ModuleScript under ServerStorage.Tests whose name ends in ".spec".
-- Each spec returns { [testName]: () -> () }. Run from the command bar (Edit mode is fine):
--   require(game.ServerStorage.Tests.TestRunner).RunAll()
local TestRunner = {}

function TestRunner.RunAll(): (number, number)
	local passed, failed = 0, 0
	local specs = {}
	for _, child in script.Parent:GetDescendants() do
		if child:IsA("ModuleScript") and string.sub(child.Name, -5) == ".spec" then
			table.insert(specs, child)
		end
	end
	table.sort(specs, function(a, b)
		return a.Name < b.Name
	end)

	for _, specModule in specs do
		local specName = string.sub(specModule.Name, 1, -6)
		-- Clone so edits made since the last run are picked up (require caches by instance)
		local fresh = specModule:Clone()
		fresh.Parent = specModule.Parent
		local ok, spec = pcall(require, fresh)
		fresh:Destroy()
		if not ok or type(spec) ~= "table" then
			failed += 1
			warn(("[Tests] FAIL %s (failed to load: %s)"):format(specName, tostring(spec)))
			continue
		end

		local names = {}
		for name in spec do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in names do
			local testOk, err = pcall(spec[name])
			if testOk then
				passed += 1
				print(("[Tests] PASS %s > %s"):format(specName, name))
			else
				failed += 1
				warn(("[Tests] FAIL %s > %s: %s"):format(specName, name, tostring(err)))
			end
		end
	end

	print(("[Tests] %d passed, %d failed"):format(passed, failed))
	return passed, failed
end

return TestRunner
