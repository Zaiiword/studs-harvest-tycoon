--!strict
local TestKit = require("../TestKit")
local FakeRng = require("../helpers/FakeRng")
local RetentionConfig = require("../../src/shared/config/RetentionConfig")
local Decor = require("../../src/shared/domain/Decor")
local MapGeometry = require("../../src/shared/domain/MapGeometry")
local Retention = require("../../src/shared/domain/Retention")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local DAY = 86_400

describe("Retention", function()
	describe("cadeaux de temps de jeu", function()
		it("propose 9 cadeaux entre 2 et 60 minutes (CDC §7.4)", function()
			expect(#RetentionConfig.GIFTS).toBe(9)
			expect(RetentionConfig.GIFTS[1].minutes).toBe(2)
			expect(RetentionConfig.GIFTS[9].minutes).toBe(60)
		end)
		it("débloque un cadeau après son délai, une seule fois", function()
			expect(Retention.isGiftClaimable(1, 119, {})).toBe(false)
			expect(Retention.isGiftClaimable(1, 120, {})).toBe(true)
			expect(Retention.isGiftClaimable(1, 999, { [1] = true })).toBe(false)
			expect(Retention.isGiftClaimable(10, 99_999, {})).toBe(false)
		end)
	end)

	describe("roue de la fortune", function()
		it("se tourne une fois toutes les 24 h (A45)", function()
			local state = Retention.newState()
			expect(Retention.wheelWait(state, 1_000_000)).toBe(0)
			state.lastWheelAt = 1_000_000
			expect(Retention.wheelWait(state, 1_000_000 + 3600)).toBe(DAY - 3600)
		end)
		it("respecte les poids affichés", function()
			expect(Retention.spin(FakeRng.constant(0))).toBe(1)
			expect(Retention.spin(FakeRng.constant(0.999))).toBe(#RetentionConfig.WHEEL)
		end)
	end)

	describe("quêtes du jour", function()
		it("tire 3 quêtes distinctes, les mêmes pour une date donnée (A46)", function()
			local today = Retention.questsForDay(20_000)
			expect(#today).toBe(RetentionConfig.QUESTS_PER_DAY)
			expect(today[1].id ~= today[2].id and today[2].id ~= today[3].id and today[1].id ~= today[3].id).toBe(true)
			expect(Retention.questsForDay(20_000)[2].id).toBe(today[2].id)
		end)
		it("fait avancer une quête puis la récompense une seule fois", function()
			local state = Retention.newState()
			local day = 20_000
			local quest = Retention.questsForDay(day)[1]
			Retention.record(state, quest.stat, quest.target - 1, day)
			expect(Retention.claimQuest(state, quest.id, day)).toBe(nil)
			Retention.record(state, quest.stat, 1, day)
			expect(Retention.claimQuest(state, quest.id, day) ~= nil).toBe(true)
			expect(Retention.claimQuest(state, quest.id, day)).toBe(nil)
		end)
		it("repart de zéro le lendemain, mais garde les statistiques cumulées", function()
			local state = Retention.newState()
			Retention.record(state, "harvested", 50, 20_000)
			Retention.record(state, "harvested", 10, 20_001)
			expect(state.quests.day).toBe(20_001)
			expect(state.stats.harvested).toBe(60)
		end)
		it("calcule le jour à partir de l'heure Unix", function()
			expect(Retention.dayOf(3 * DAY + 5)).toBe(3)
		end)
	end)

	describe("sauvegarde", function()
		it("nettoie un état corrompu", function()
			local state = Retention.sanitize({
				lastWheelAt = 0 / 0,
				stats = { harvested = 12.7, hack = 5, ejections = -3 },
				quests = { day = 7, progress = { Harvest = 3, Fake = 9 }, claimed = { Harvest = true, Corn = "oui" } },
			})
			expect(state.lastWheelAt).toBe(0)
			expect(state.stats.harvested).toBe(12)
			expect(state.stats.hack).toBe(nil)
			expect(state.stats.ejections).toBe(nil)
			expect(state.quests.progress.Fake).toBe(nil)
			expect(state.quests.claimed.Corn).toBe(nil)
		end)
	end)
end)

describe("Statues de classement", function()
	it("sont posées sur la barre, hors des bases, et aucun arbre ne les gêne", function()
		for _, statue in RetentionConfig.STATUES do
			expect(MapGeometry.zoneAt(statue.x, statue.z)).toBe("Plaza")
			for _, base in MapGeometry.baseCenters() do
				expect(MapGeometry.isInsideBase(base, statue.x, statue.z)).toBe(false)
			end
			for _, tree in Decor.treeSpots() do
				local distance = math.sqrt((tree.x - statue.x) ^ 2 + (tree.z - statue.z) ^ 2)
				expect(distance >= RetentionConfig.STATUE_CLEARANCE).toBe(true)
			end
		end
	end)
end)
