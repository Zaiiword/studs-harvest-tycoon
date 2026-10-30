--!strict
-- Mini-framework de test (describe/it/expect) exécuté sous Lune, sans dépendance externe.

local TestKit = {}

type Result = { name: string, ok: boolean, err: string? }
local results: { Result } = {}
local prefix: { string } = {}

function TestKit.describe(name: string, body: () -> ())
	table.insert(prefix, name)
	body()
	table.remove(prefix)
end

function TestKit.it(name: string, body: () -> ())
	local fullName = table.concat(prefix, " › ") .. " › " .. name
	local ok, err = pcall(body)
	table.insert(results, { name = fullName, ok = ok, err = if ok then nil else tostring(err) })
end

local function fail(message: string)
	error(message, 3)
end

function TestKit.expect(actual: any)
	return {
		toBe = function(expected: any)
			if actual ~= expected then
				fail(`attendu {tostring(expected)}, obtenu {tostring(actual)}`)
			end
		end,
		toBeCloseTo = function(expected: number, epsilon: number?)
			if math.abs(actual - expected) > (epsilon or 1e-6) then
				fail(`attendu ≈{expected}, obtenu {actual}`)
			end
		end,
		toThrow = function()
			if pcall(actual) then
				fail("une erreur était attendue")
			end
		end,
	}
end

function TestKit.report(): number
	local failed = 0
	for _, result in results do
		if result.ok then
			print(`  ✓ {result.name}`)
		else
			failed += 1
			print(`  ✗ {result.name}\n      {result.err}`)
		end
	end
	print(`\n{#results - failed} réussis, {failed} échoués`)
	return failed
end

return TestKit
