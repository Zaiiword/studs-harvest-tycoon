--!strict
-- Valeurs de référence figées : un changement d'équilibrage doit être volontaire (mettre à jour ce fichier).
local TestKit = require("../TestKit")
local Formulas = require("../../src/shared/domain/Formulas")
local VehicleConfig = require("../../src/shared/config/VehicleConfig")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Économie (golden)", function()
	it("prix des paliers (CDC §5, entrée revue en A68)", function()
		local expected = { 0, 75, 400, 6_000, 85_000, 900_000, 12_000_000 }
		for index, tier in VehicleConfig.TIERS do
			expect(tier.price).toBe(expected[index])
		end
	end)
	it("coût du Rebirth n°1 et n°4 (A70)", function()
		expect(Formulas.rebirthCost(0)).toBe(500_000_000)
		expect(Formulas.rebirthCost(3)).toBe(32_000_000_000)
	end)
	it("inflation de prestige : ×2,5 par Rebirth (A70)", function()
		expect(Formulas.prestigePriceScale(0)).toBe(1)
		expect(Formulas.prestigePriceScale(2)).toBe(6.25)
	end)
	it("bouton Tycoon niveau 10 (base 250)", function()
		expect(Formulas.tycoonButtonPrice(250, 10)).toBe(5_027)
	end)
end)
