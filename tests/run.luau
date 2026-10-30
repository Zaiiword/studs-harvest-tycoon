--!strict
-- Point d'entrée : `lune run tests/run`. Charge chaque *.spec.luau puis renvoie un code de sortie.
local fs = require("@lune/fs")
local process = require("@lune/process")
local TestKit = require("./TestKit")

local SUITES = { "unit", "integration", "regression" }

for _, suite in SUITES do
	local directory = `tests/{suite}`
	if fs.isDir(directory) then
		for _, file in fs.readDir(directory) do
			if string.match(file, "%.spec%.luau$") then
				require(`./{suite}/{string.gsub(file, "%.luau$", "")}`)
			end
		end
	end
end

process.exit(if TestKit.report() == 0 then 0 else 1)
