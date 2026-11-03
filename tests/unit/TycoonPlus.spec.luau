--!strict
-- Options de l'usine (A53) : silo agrandissable, sauvegarde et flèches de guidage. Plan de la ferme : Farm.spec.
local TestKit = require("../TestKit")
local TycoonConfig = require("../../src/shared/config/TycoonConfig")
local Guide = require("../../src/shared/domain/Guide")
local Profile = require("../../src/shared/domain/Profile")
local Rebirth = require("../../src/shared/domain/Rebirth")
local Tycoon = require("../../src/shared/domain/Tycoon")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local SILO = TycoonConfig.SILO_UPGRADE

describe("Silo Géant", function()
	it("double la capacité à chaque niveau acheté", function()
		local state = Tycoon.new()
		state.money = 1e9
		state.machines.Mill = true -- le silo n'apparaît qu'après le Moulin
		expect(Tycoon.siloCapacity(state)).toBe(TycoonConfig.SILO_CAPACITY)
		expect(Tycoon.offer(state, SILO.ID, 1).price).toBe(SILO.PRICES[1])
		expect(Tycoon.buy(state, SILO.ID, 1).isPurchased).toBe(true)
		expect(Tycoon.siloCapacity(state)).toBe(TycoonConfig.SILO_CAPACITY * 2)
		expect(Tycoon.offer(state, SILO.ID, 1).price).toBe(SILO.PRICES[2])
	end)

	it("laisse le silo accepter plus de blé une fois agrandi", function()
		local state = Tycoon.new()
		state.silo = TycoonConfig.SILO_CAPACITY
		expect(Tycoon.deposit(state, 100)).toBe(0)
		state.siloLevel = 1
		expect(Tycoon.deposit(state, 100)).toBe(100)
	end)

	it("ne vend plus rien au niveau maximal", function()
		local state = Tycoon.new()
		state.siloLevel = #SILO.PRICES
		state.money = 1e12
		expect(Tycoon.offer(state, SILO.ID, 1).price).toBe(nil)
		expect(Tycoon.buy(state, SILO.ID, 1).isPurchased).toBe(false)
	end)
end)

describe("Rebirth et nouvelles options", function()
	it("garde le silo agrandi et les décorations (A53)", function()
		local state = Tycoon.new()
		for _, machine in TycoonConfig.MACHINES do
			state.machines[machine.id] = true
		end
		state.siloLevel, state.decor.Fountain = 2, true
		local progress = Rebirth.newProgress()
		state.money = Rebirth.cost(progress)
		expect(Rebirth.apply(state, progress)).toBe(true)
		expect(state.siloLevel).toBe(2)
		expect(state.decor.Fountain).toBe(true)
		expect(next(state.machines)).toBe(nil)
	end)
end)

describe("Profil v6", function()
	it("sauvegarde et restaure le silo et les décorations", function()
		local state = Tycoon.new()
		state.siloLevel, state.decor.Flag, state.decor.Lamps = 3, true, true
		state.silo = Tycoon.siloCapacityAt(3) -- plus que l'ancien plafond : ne doit pas être tronqué
		local data = Profile.fromGame({
			tycoon = state,
			tier = 1,
			progress = Rebirth.newProgress(),
			items = {},
			pets = { owned = {}, equipped = {} },
			retention = nil :: any,
			purchases = nil :: any,
		})
		expect(data.version).toBe(6)
		local restored = Profile.toTycoon(Profile.sanitize(data))
		expect(restored.siloLevel).toBe(3)
		expect(restored.decor.Flag).toBe(true)
		expect(restored.decor.Lamps).toBe(true)
		expect(restored.silo).toBe(Tycoon.siloCapacityAt(3))
	end)

	it("migre un profil v5 (sans silo agrandi ni décoration)", function()
		local data = Profile.sanitize({ version = 5, money = 10, machines = { "Mill" } })
		expect(data.siloLevel).toBe(0)
		expect(#data.decor).toBe(0)
	end)

	it("nettoie des décorations inconnues ou en double et un niveau de silo hors bornes", function()
		local data = Profile.sanitize({ decor = { "Fountain", "Fountain", "Piscine", 42 }, siloLevel = 99 })
		expect(#data.decor).toBe(1)
		expect(data.siloLevel).toBe(#SILO.PRICES)
	end)
end)

describe("Guide", function()
	local buttons = {
		{ id = "Mill", price = 250, x = 0, z = -20 },
		{ id = "Conveyor", price = 68, x = 0, z = -40 },
		{ id = "Oven", price = 20_000, x = 0, z = 0 },
	}

	it("montre le bouton abordable le moins cher", function()
		local target =
			Guide.target({ money = 300, isBagFull = false, unload = nil, buttons = buttons, seen = {} }) :: Guide.Target
		expect(target.kind).toBe("button")
		expect(target.id).toBe("Conveyor")
	end)

	it("ne montre rien quand aucun bouton n'est abordable", function()
		expect(Guide.target({ money = 10, isBagFull = false, unload = nil, buttons = buttons, seen = {} })).toBe(nil)
	end)

	it("emmène d'abord décharger quand le sac est plein", function()
		local unload = { x = 1, z = 2 }
		local target =
			Guide.target({ money = 1e6, isBagFull = true, unload = unload, buttons = buttons, seen = {} }) :: Guide.Target
		expect(target.kind).toBe("unload")
		expect(target.point).toBe(unload)
	end)

	it("aligne des chevrons régulièrement espacés, tournés vers la cible", function()
		local spec = { spacing = 4, start = 4, maxLength = 70, phase = 0 }
		local chevrons = Guide.chevrons({ { x = 0, z = 0 }, { x = 0, z = 30 } }, spec)
		expect(#chevrons).toBe(7) -- 4, 8, …, 28 : le dernier s'arrête avant la cible
		expect(chevrons[1].z).toBeCloseTo(4)
		expect(chevrons[2].z - chevrons[1].z).toBeCloseTo(4)
		expect(chevrons[1].dirZ).toBeCloseTo(1)
	end)

	it("ne dessine que le début d'un long trajet", function()
		local spec = { spacing = 4, start = 4, maxLength = 20, phase = 0 }
		local chevrons = Guide.chevrons({ { x = 0, z = 0 }, { x = 500, z = 0 } }, spec)
		expect(#chevrons).toBe(5)
		expect(chevrons[#chevrons].x <= 20).toBe(true)
	end)
end)

describe("Guidage une seule fois par objet", function()
	local buttons = {
		{ id = "Conveyor", price = 68, x = 0, z = -40 },
		{ id = "Mill", price = 250, x = 0, z = -20 },
	}

	it("passe au bouton suivant une fois le tapis déjà acheté", function()
		local seen = { Conveyor = true }
		local target = Guide.target({ money = 300, isBagFull = false, unload = nil, buttons = buttons, seen = seen })
		expect((target :: Guide.Target).id).toBe("Mill")
	end)

	it("ne ramène plus à la grille de déchargement après le premier déchargement", function()
		local unload = { x = 1, z = 2 }
		local seen = { [Guide.UNLOAD] = true, Conveyor = true, Mill = true }
		expect(Guide.target({ money = 1e6, isBagFull = true, unload = unload, buttons = buttons, seen = seen })).toBe(
			nil
		)
	end)

	it("retient chaque bouton acheté, et le garde au Rebirth et dans la sauvegarde", function()
		local state = Tycoon.new()
		state.money = 1e6
		Tycoon.buy(state, "Conveyor", 1)
		expect(state.guided.Conveyor).toBe(true)
		expect(state.guided.Mill).toBe(nil)
		local data = Profile.sanitize({ guided = { "Conveyor", "Unload", "Inconnu" } })
		expect(#data.guided).toBe(2)
		expect(Profile.toTycoon(data).guided.Unload).toBe(true)
	end)
end)
