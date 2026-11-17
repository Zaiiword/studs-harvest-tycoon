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
	-- A68 : premier quart d'heure accéléré (Faux, Tondeuse, Tracteur et Moulin moins chers). Le joueur simulé ne perd
	-- pas de temps sur les routes : en partie réelle, compter environ deux fois plus pour les premiers paliers.
	it("premiers achats rapides : Faux en moins de 2 min (« effet dopamine »)", function()
		expect(within(minutes(result.tierReachedAt[2]), 0.5, 2)).toBe(true)
	end)
	it("Tondeuse vers 4-8 min, Tracteur vers 20-35 min", function()
		expect(within(minutes(result.tierReachedAt[3]), 4, 8)).toBe(true)
		expect(within(minutes(result.tierReachedAt[4]), 20, 35)).toBe(true)
	end)
	it("Double Faucheuse vers 1 h 10 - 1 h 40, Moissonneuse XL vers 2 h 10 - 2 h 45", function()
		expect(within(minutes(result.tierReachedAt[5]), 70, 100)).toBe(true)
		expect(within(minutes(result.tierReachedAt[6]), 130, 165)).toBe(true)
	end)
	-- A70 : fin de partie allongée. Sans aucun Pet, le Rebirth demande plus de 5 h ; avec des Pets, voir « carrière ».
	it("Cyber-Laser vers 3 h - 3 h 30, premier Rebirth sans Pet vers 5 h - 6 h", function()
		expect(within(minutes(result.tierReachedAt[7]), 180, 210)).toBe(true)
		expect(within(minutes(result.rebirthReadyAt), 300, 350)).toBe(true)
	end)
	it("la grange se bâtit tout du long : façade vers 1 h, toit puis machines de l'étage vers 3 h (A56)", function()
		expect(within(minutes(result.builtAt.WallBack), 10, 40)).toBe(true)
		expect(within(minutes(result.builtAt.Facade), 50, 100)).toBe(true)
		expect(within(minutes(result.builtAt.Roof), 155, 200)).toBe(true)
		expect(result.builtAt.Dryer > result.builtAt.Roof).toBe(true)
	end)
end)

-- Carrière (A70) : plusieurs Rebirths de suite, pour un joueur réel (Pets, cadeaux, Retour Base Instantané) et un
-- joueur occasionnel. Avant A70 le joueur réel faisait 3 Rebirths en 60 min, chaque partie plus courte que la
-- précédente (36, 15, 10 min).
describe("Rythme des Rebirths (golden)", function()
	local real = EconomySim.career(EconomySim.REAL, 3, 12 * 3600).runs
	local casual = EconomySim.career(EconomySim.CASUAL, 2, 12 * 3600).runs

	it("garde le début rapide : Tracteur avant 15 min, Double Faucheuse avant 30 min", function()
		expect(within(minutes(real[1].tierAt[4]), 5, 15)).toBe(true)
		expect(within(minutes(real[1].tierAt[5]), 15, 30)).toBe(true)
	end)
	it("premier Rebirth d'un joueur réel vers 45-65 min, après la Cyber-Laser et l'étage", function()
		expect(within(minutes(real[1].seconds), 45, 65)).toBe(true)
		expect(real[1].tierAt[7] ~= nil and real[1].upperAt ~= nil).toBe(true)
	end)
	it("aucune partie suivante ne s'effondre : au moins 35 min, et elles s'allongent", function()
		expect(within(minutes(real[2].seconds), 35, 60)).toBe(true)
		expect(within(minutes(real[3].seconds), 55, 90)).toBe(true)
	end)
	it("joueur occasionnel : premier Rebirth en 1 h - 1 h 40, le suivant en moins de 2 h", function()
		expect(within(minutes(casual[1].seconds), 60, 100)).toBe(true)
		expect(within(minutes(casual[2].seconds), 60, 120)).toBe(true)
	end)
end)
