--!strict
-- Courbe de progression (docs/EQUILIBRAGE.md, A51, A55, A56) : temps de jeu d'un joueur seul, sans Pet ni avantage
-- Robux, pour atteindre chaque palier et le premier Rebirth. Un réglage de prix qui sort de ces fourchettes
-- doit être intentionnel (mettre à jour ce fichier et EQUILIBRAGE.md).
local TestKit = require("../TestKit")
local EconomySim = require("../helpers/EconomySim")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local MINUTE = 60
local result = EconomySim.run(8 * 3600)

local function minutes(seconds: number?): number
	return (seconds or math.huge) / MINUTE
end

local function within(value: number, low: number, high: number): boolean
	return value >= low and value <= high
end

describe("Courbe de progression (golden)", function()
	it("premiers achats rapides : Faux en moins de 6 min (CDC §8 « effet dopamine »)", function()
		expect(within(minutes(result.tierReachedAt[2]), 2, 6)).toBe(true)
	end)
	it("Tondeuse vers 10-15 min, Tracteur vers 40-60 min", function()
		expect(within(minutes(result.tierReachedAt[3]), 8, 15)).toBe(true)
		expect(within(minutes(result.tierReachedAt[4]), 40, 60)).toBe(true)
	end)
	it("Double Faucheuse vers 1 h 30 - 2 h, Moissonneuse XL vers 2 h 30 - 3 h", function()
		expect(within(minutes(result.tierReachedAt[5]), 90, 120)).toBe(true)
		expect(within(minutes(result.tierReachedAt[6]), 150, 180)).toBe(true)
	end)
	it("premier Rebirth possible vers 2 h 30 - 3 h, Cyber-Laser vers 3 h", function()
		expect(within(minutes(result.rebirthReadyAt), 150, 190)).toBe(true)
		expect(within(minutes(result.tierReachedAt[7]), 165, 210)).toBe(true)
	end)
	it(
		"la grange se bâtit tout du long : façade vers 1 h 15, toit puis machines de l'étage après 3 h (A56)",
		function()
			expect(within(minutes(result.builtAt.WallBack), 10, 40)).toBe(true)
			expect(within(minutes(result.builtAt.Facade), 50, 100)).toBe(true)
			expect(within(minutes(result.builtAt.Roof), 180, 230)).toBe(true)
			expect(result.builtAt.Dryer > result.builtAt.Roof).toBe(true)
		end
	)
end)
