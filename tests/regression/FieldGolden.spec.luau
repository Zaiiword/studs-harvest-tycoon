--!strict
-- Valeurs figées de la carte et du champ : un changement doit être intentionnel (mettre à jour ce fichier).
local TestKit = require("../TestKit")
local FakeRng = require("../helpers/FakeRng")
local FieldGrid = require("../../src/shared/domain/FieldGrid")
local MapGeometry = require("../../src/shared/domain/MapGeometry")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Champ (golden)", function()
	local grid = FieldGrid.new(FakeRng.constant(0.5))
	local perZone: { [string]: number } = {}
	for _, index in grid:activeIndices() do
		local zone = (grid:cell(index) :: FieldGrid.Cell).zone
		perZone[zone] = (perZone[zone] or 0) + 1
	end

	it("nombre de brins par bande (carte en T)", function()
		expect(perZone.GreenWheat).toBe(1198)
		expect(perZone.GoldenCorn).toBe(772)
		expect(perZone.DiamondWheat).toBe(408)
	end)
	it("nombre de briques de sol", function()
		expect(#MapGeometry.floorRuns()).toBe(123)
	end)
end)
