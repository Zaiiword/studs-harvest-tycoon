--!strict
-- Valeurs de référence figées : un changement d'équilibrage doit être volontaire (mettre à jour ce fichier).
local TestKit = require("../TestKit")
local Formulas = require("../../src/shared/domain/Formulas")
local VehicleConfig = require("../../src/shared/config/VehicleConfig")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Économie (golden)", function()
	it("prix des paliers inchangés (CDC §5)", function()
		local expected = { 0, 150, 1_200, 12_500, 85_000, 450_000, 3_500_000 }
		for index, tier in VehicleConfig.TIERS do
			expect(tier.price).toBe(expected[index])
		end
	end)
	it("coût du Rebirth n°3", function()
		expect(Formulas.rebirthCost(3)).toBe(27_000_000)
	end)
	it("bouton Tycoon niveau 10 (base 250)", function()
		expect(Formulas.tycoonButtonPrice(250, 10)).toBe(5_027)
	end)
end)
