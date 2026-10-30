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

	it("nombre de brins par anneau", function()
		expect(perZone.GreenWheat).toBe(1078)
		expect(perZone.GoldenCorn).toBe(556)
		expect(perZone.DiamondWheat).toBe(264)
	end)
	it("nombre de briques de sol", function()
		expect(#MapGeometry.floorRuns()).toBe(316)
	end)
end)
