--!strict
local TestKit = require("../TestKit")
local Formulas = require("../../src/shared/domain/Formulas")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Formulas", function()
	describe("petFactor", function()
		it("vaut 1 sans pet (régression A1)", function()
			expect(Formulas.petFactor({})).toBe(1)
		end)
		it("additionne les bonus au-delà de 1", function()
			expect(Formulas.petFactor({ 1.2, 2.5 })).toBeCloseTo(2.7)
		end)
	end)

	describe("incomePerSecond", function()
		it("vaut 0 quand le silo est vide", function()
			local income = Formulas.incomePerSecond({
				rawPerSecond = 0,
				machineMultiplier = 36,
				petBonuses = {},
				rebirths = 3,
				hasIncomeX2 = true,
			})
			expect(income).toBe(0)
		end)
		it("applique machines, rebirth et gamepass ×2", function()
			local income = Formulas.incomePerSecond({
				rawPerSecond = 10,
				machineMultiplier = 1.5,
				petBonuses = {},
				rebirths = 2,
				hasIncomeX2 = true,
			})
			expect(income).toBeCloseTo(10 * 1.5 * 2 * 2)
		end)
	end)

	describe("tycoonButtonPrice", function()
		it("suit Base × 1,35^n", function()
			expect(Formulas.tycoonButtonPrice(100, 0)).toBe(100)
			expect(Formulas.tycoonButtonPrice(100, 2)).toBe(182)
		end)
	end)

	describe("knockbackForce", function()
		it("est proportionnelle au ratio de masse", function()
			expect(Formulas.knockbackForce(30, 80, 40, 1)).toBe(60)
		end)
		it("ne devient jamais négative", function()
			expect(Formulas.knockbackForce(-5, 80, 40, 1)).toBe(0)
		end)
		it("refuse une masse cible nulle", function()
			expect(function()
				Formulas.knockbackForce(1, 1, 0, 1)
			end).toThrow()
		end)
	end)

	describe("effectiveMass", function()
		it("n'applique le bonus Rebirth qu'une seule fois (régression A15)", function()
			expect(Formulas.effectiveMass(100, 2, false)).toBeCloseTo(130)
			expect(Formulas.effectiveMass(100, 0, true)).toBeCloseTo(250)
		end)
	end)
end)
