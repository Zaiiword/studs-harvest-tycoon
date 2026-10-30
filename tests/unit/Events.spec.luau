--!strict
-- Météo, hotspot, boss Météorite, sabotage et inventaire (Sprint 5).
local TestKit = require("../TestKit")
local FakeRng = require("../helpers/FakeRng")
local EventConfig = require("../../src/shared/config/EventConfig")
local SabotageConfig = require("../../src/shared/config/SabotageConfig")
local Hotspot = require("../../src/shared/domain/Hotspot")
local Inventory = require("../../src/shared/domain/Inventory")
local MapGeometry = require("../../src/shared/domain/MapGeometry")
local MeteorBoss = require("../../src/shared/domain/MeteorBoss")
local Sabotage = require("../../src/shared/domain/Sabotage")
local Weather = require("../../src/shared/domain/Weather")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Weather", function()
	it("commence par 4 min de beau temps puis 2 min d'événement (A10)", function()
		expect(Weather.phaseAt(0).isEvent).toBe(false)
		expect(Weather.phaseAt(239).isEvent).toBe(false)
		expect(Weather.phaseAt(240).isEvent).toBe(true)
		expect(Weather.phaseAt(359).remaining).toBe(1)
		expect(Weather.phaseAt(360).isEvent).toBe(false)
	end)
	it("tire chacun des trois événements du CDC", function()
		expect(Weather.pick(FakeRng.constant(0)).id).toBe("GoldenRain")
		expect(Weather.pick(FakeRng.constant(0.5)).id).toBe("WindStorm")
		expect(Weather.pick(FakeRng.constant(0.999)).id).toBe("NeonNight")
	end)
	it("applique les effets du CDC §6", function()
		expect(Weather.byId("GoldenRain").valueMultiplier).toBe(2)
		expect(Weather.byId("WindStorm").vehicleSpeedMultiplier).toBe(1.25)
		expect(Weather.byId("NeonNight").rainbowBoost).toBe(5)
		expect(Weather.byId("Inconnu").id).toBe("Clear")
	end)
end)

describe("Hotspot", function()
	it("se place toujours dans le Blé Diamant (A11)", function()
		local rng = FakeRng.seeded(7)
		for _ = 1, 200 do
			local spot = Hotspot.pick(rng)
			expect(MapGeometry.zoneAt(spot.x, spot.z)).toBe("DiamondWheat")
		end
	end)
	it("contient les points à moins de 10 studs de son centre", function()
		local spot = { x = 1000, z = 0 }
		expect(Hotspot.contains(spot, 1005, 5)).toBe(true)
		expect(Hotspot.contains(spot, 1015, 0)).toBe(false)
		expect(Hotspot.contains(nil, 1000, 0)).toBe(false)
	end)
end)

describe("MeteorBoss", function()
	it("cumule les dégâts par joueur et meurt à 0 PV", function()
		local boss = MeteorBoss.new(100)
		expect(MeteorBoss.hit(boss, 1, 60)).toBe(60)
		expect(MeteorBoss.hit(boss, 2, 60)).toBe(40) -- on ne compte pas au-delà des PV restants
		expect(MeteorBoss.isDefeated(boss)).toBe(true)
		expect(MeteorBoss.hit(boss, 1, 10)).toBe(0)
	end)
	it("classe le Top 3 des dégâts (CDC §6)", function()
		local boss = MeteorBoss.new(EventConfig.METEOR.MAX_HP)
		MeteorBoss.hit(boss, 10, 500)
		MeteorBoss.hit(boss, 20, 900)
		MeteorBoss.hit(boss, 30, 100)
		MeteorBoss.hit(boss, 40, 700)
		local top = MeteorBoss.ranking(boss, 3)
		expect(table.concat(top :: { any }, ",")).toBe("20,40,10")
	end)
	it("convertit la puissance de coupe en dégâts (A40)", function()
		expect(MeteorBoss.damageFor(150)).toBe(150 * EventConfig.METEOR.DAMAGE_PER_CUT_POWER)
	end)
end)

local function body(id: number, x: number, z: number, isProtected: boolean?): any
	return {
		id = id,
		x = x,
		z = z,
		vx = 0,
		vz = 0,
		radius = 2,
		mass = 80,
		isVehicle = true,
		isProtected = isProtected == true,
	}
end

describe("Sabotage", function()
	it("vise avec le Gant la cible la plus proche au contact", function()
		local user = body(1, 0, 0)
		local target = Sabotage.gloveTarget(user, { body(2, 6, 0), body(3, 4, 0), body(4, 50, 0) })
		expect((target :: any).id).toBe(3)
	end)
	it("ignore une cible protégée (immunité de 15 s)", function()
		expect(Sabotage.gloveTarget(body(1, 0, 0), { body(2, 4, 0, true) })).toBe(nil)
	end)
	it("vise avec le Bazooka devant soi uniquement, à 60 studs au plus (A13)", function()
		local user = body(1, 0, 0)
		expect((Sabotage.bazookaTarget(user, 1, 0, { body(2, 40, 3) }) :: any).id).toBe(2)
		expect(Sabotage.bazookaTarget(user, 1, 0, { body(2, -40, 0) })).toBe(nil)
		expect(Sabotage.bazookaTarget(user, 1, 0, { body(2, 70, 0) })).toBe(nil)
	end)
	it("repousse tout le monde autour du Blé Arc-en-ciel sauf le lanceur", function()
		local targets = Sabotage.dynamiteTargets(0, 0, 1, { body(1, 2, 0), body(2, 10, 0), body(3, 40, 0) })
		expect(#targets).toBe(1)
		expect(targets[1].id).toBe(2)
	end)
	it("éjecte à la distance voulue (vol balistique)", function()
		local horizontal, vertical = Sabotage.launchForDistance(SabotageConfig.GLOVE.EJECT_DISTANCE)
		local flight = 2 * vertical / 196.2
		expect(horizontal * flight).toBeCloseTo(SabotageConfig.GLOVE.EJECT_DISTANCE, 1e-6)
	end)
end)

describe("Inventory", function()
	it("ajoute et consomme des objets", function()
		local inventory = {}
		expect(Inventory.add(inventory, "Bazooka", 3)).toBe(3)
		expect(Inventory.take(inventory, "Bazooka")).toBe(true)
		expect(Inventory.count(inventory, "Bazooka")).toBe(2)
	end)
	it("refuse de consommer un objet absent", function()
		expect(Inventory.take({}, "Mud")).toBe(false)
	end)
	it("plafonne les piles à MAX_STACK", function()
		local inventory = { Mud = SabotageConfig.MAX_STACK - 1 }
		expect(Inventory.add(inventory, "Mud", 10)).toBe(1)
	end)
	it("nettoie un inventaire corrompu", function()
		local inventory = Inventory.sanitize({ Mud = 2.7, Hack = 5, Glove = -3, Dynamite = 0 / 0 })
		expect(inventory.Mud).toBe(2)
		expect(inventory.Hack).toBe(nil)
		expect(inventory.Glove).toBe(nil)
		expect(inventory.Dynamite).toBe(nil)
	end)
end)
