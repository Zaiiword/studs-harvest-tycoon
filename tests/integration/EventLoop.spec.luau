--!strict
-- Intégration Sprint 5 : un combat contre le boss Météorite avec des joueurs de paliers différents,
-- la validation des requêtes réseau, et les achats d'objets en gemmes.
local TestKit = require("../TestKit")
local EventConfig = require("../../src/shared/config/EventConfig")
local SabotageConfig = require("../../src/shared/config/SabotageConfig")
local VehicleConfig = require("../../src/shared/config/VehicleConfig")
local Inventory = require("../../src/shared/domain/Inventory")
local MeteorBoss = require("../../src/shared/domain/MeteorBoss")
local DevCommands = require("../../src/shared/net/DevCommands")
local ItemRequests = require("../../src/shared/net/ItemRequests")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Combat contre le boss Météorite", function()
	it("quatre engins abattent l'Épi de Cristal avant qu'il reparte (A40)", function()
		local boss = MeteorBoss.new(EventConfig.METEOR.MAX_HP)
		local fighters = { [1] = 4, [2] = 5, [3] = 6, [4] = 3 } -- UserId → palier
		local elapsed = 0
		while not MeteorBoss.isDefeated(boss) and elapsed < EventConfig.METEOR.DURATION_SECONDS do
			elapsed += EventConfig.METEOR.HIT_INTERVAL
			for userId, tier in fighters do
				MeteorBoss.hit(boss, userId, MeteorBoss.damageFor(VehicleConfig.TIERS[tier].cutPower))
			end
		end
		expect(MeteorBoss.isDefeated(boss)).toBe(true)
		expect(elapsed < EventConfig.METEOR.DURATION_SECONDS).toBe(true)
		local top = MeteorBoss.ranking(boss, EventConfig.METEOR.REWARD_TOP)
		expect(table.concat(top :: { any }, ",")).toBe("3,2,1") -- la Moissonneuse XL frappe le plus fort
	end)

	it("une Cyber-Laser seule met près d'une minute : le boss reste collectif", function()
		local boss = MeteorBoss.new(EventConfig.METEOR.MAX_HP)
		local elapsed = 0
		while not MeteorBoss.isDefeated(boss) do
			elapsed += EventConfig.METEOR.HIT_INTERVAL
			MeteorBoss.hit(boss, 1, MeteorBoss.damageFor(VehicleConfig.TIERS[7].cutPower))
		end
		expect(elapsed > 45).toBe(true)
	end)

	it("un joueur seul aux Mains Nues n'y arrive pas : il faut s'équiper ou s'allier", function()
		local boss = MeteorBoss.new(EventConfig.METEOR.MAX_HP)
		local hits = EventConfig.METEOR.DURATION_SECONDS / EventConfig.METEOR.HIT_INTERVAL
		for _ = 1, hits do
			MeteorBoss.hit(boss, 1, MeteorBoss.damageFor(VehicleConfig.TIERS[1].cutPower))
		end
		expect(MeteorBoss.isDefeated(boss)).toBe(false)
	end)
end)

describe("Requêtes réseau du Sprint 5", function()
	it("n'accepte que des identifiants d'objets connus", function()
		expect((ItemRequests.parse("Mud") :: SabotageConfig.ItemDef).id).toBe("Mud")
		expect(ItemRequests.parse("LegendaryEgg")).toBe(nil) -- une récompense ne s'utilise pas
		expect(ItemRequests.parse(42)).toBe(nil)
		expect(ItemRequests.parse(string.rep("x", 100))).toBe(nil)
	end)
	it("valide les commandes de test météo et boss", function()
		expect((DevCommands.parse("weather", "NeonNight") :: any).weather).toBe("NeonNight")
		expect(DevCommands.parse("weather", "Apocalypse")).toBe(nil)
		expect((DevCommands.parse("meteor", nil) :: any).kind).toBe("meteor")
	end)
end)

describe("Achats d'objets", function()
	it("un achat ajoute le nombre de charges prévu (Bazooka : 3 tirs, CDC §9)", function()
		local inventory = {}
		for _, item in SabotageConfig.ITEMS do
			Inventory.add(inventory, item.id, item.chargesPerPurchase)
		end
		expect(Inventory.count(inventory, "Bazooka")).toBe(3)
		expect(Inventory.count(inventory, "Mud")).toBe(1)
	end)
end)
