--!strict
local TestKit = require("../TestKit")
local FakeRng = require("../helpers/FakeRng")
local DecorConfig = require("../../src/shared/config/DecorConfig")
local MapConfig = require("../../src/shared/config/MapConfig")
local RetentionConfig = require("../../src/shared/config/RetentionConfig")
local Decor = require("../../src/shared/domain/Decor")
local MapGeometry = require("../../src/shared/domain/MapGeometry")
local Purchases = require("../../src/shared/domain/Purchases")
local Retention = require("../../src/shared/domain/Retention")
local Scoreboard = require("../../src/shared/domain/Scoreboard")
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

describe("Tableaux de scores (A58)", function()
	local STYLE = DecorConfig.SCOREBOARD

	it("calcule un niveau qui ne redescend pas au Rebirth", function()
		expect(Scoreboard.levelOf(1, 0)).toBe(1)
		expect(Scoreboard.levelOf(7, 0)).toBe(7)
		expect(Scoreboard.levelOf(1, 1) > Scoreboard.levelOf(7, 0)).toBe(true)
	end)

	it("classe du meilleur au moins bon, écarte les scores nuls et limite la liste", function()
		local top = Scoreboard.top({
			{ userId = 1, score = 5 },
			{ userId = 2, score = 0 },
			{ userId = 3, score = 9 },
			{ userId = 4, score = 7 },
		}, 2)
		expect(#top).toBe(2)
		expect(top[1].userId).toBe(3)
		expect(top[2].userId).toBe(4)
	end)

	it("formate chaque score selon sa statistique", function()
		expect(Scoreboard.scoreText("level", 12)).toBe("Niv. 12")
		expect(Scoreboard.scoreText("earned", 2_000_000)).toBe("2 M $")
		expect(Scoreboard.scoreText("robux", 499)).toBe("499 R$")
		expect(Scoreboard.scoreText("harvested", 14_500)).toBe("14,5 K")
	end)

	it("couvre le niveau, la fortune et les Robux", function()
		local stats = {}
		for _, board in RetentionConfig.SCOREBOARDS do
			stats[board.stat] = true
		end
		expect(stats.level and stats.earned and stats.robux).toBe(true)
	end)

	it("pose les tableaux sur la barre, sans gêner les ponts et sans se chevaucher", function()
		for index, board in RetentionConfig.SCOREBOARDS do
			expect(MapGeometry.zoneAt(STYLE.X, board.z)).toBe("Plaza")
			for _, bridgeZ in MapConfig.BRIDGE_Z do
				expect(math.abs(board.z - bridgeZ) >= STYLE.WIDTH / 2 + MapConfig.BRIDGE_WIDTH / 2).toBe(true)
			end
			local nextBoard = RetentionConfig.SCOREBOARDS[index + 1]
			if nextBoard then
				expect(nextBoard.z - board.z >= STYLE.WIDTH).toBe(true)
			end
		end
	end)

	it("passe au-dessus des statues et reste hors de la route", function()
		expect(STYLE.X > MapConfig.ROAD.maxX).toBe(true)
		expect(STYLE.X + 0.5 <= MapConfig.MOAT.minX).toBe(true)
		expect(STYLE.LIFT > 12).toBe(true)
	end)
end)

describe("Robux dépensés (A58)", function()
	it("cumule les achats", function()
		local purchases = Purchases.new()
		Purchases.addSpent(purchases, 39)
		Purchases.addSpent(purchases, 99)
		expect(purchases.robuxSpent).toBe(138)
	end)

	it("ne compte un Gamepass qu'une fois, même revu à chaque connexion", function()
		local purchases = Purchases.new()
		Purchases.countPass(purchases, "Titan", 199)
		Purchases.countPass(purchases, "Titan", 199)
		expect(purchases.robuxSpent).toBe(199)
	end)

	it("survit à la sauvegarde et refuse une valeur corrompue", function()
		local saved = Purchases.sanitize({ robuxSpent = 500, countedPasses = { "Titan", "Titan", 3 } })
		expect(saved.robuxSpent).toBe(500)
		expect(#saved.countedPasses).toBe(1)
		expect(Purchases.sanitize({ robuxSpent = 0 / 0 }).robuxSpent).toBe(0)
		expect(Purchases.sanitize({ robuxSpent = -5 }).robuxSpent).toBe(0)
		expect(Purchases.sanitize({ robuxSpent = math.huge }).robuxSpent).toBe(0)
	end)

	it("reprend un ancien profil sans ces champs", function()
		local saved = Purchases.sanitize({ receipts = { "a" } })
		expect(saved.robuxSpent).toBe(0)
		expect(#saved.countedPasses).toBe(0)
	end)
end)
