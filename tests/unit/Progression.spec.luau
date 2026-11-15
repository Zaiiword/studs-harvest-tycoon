--!strict
local TestKit = require("../TestKit")
local RetentionConfig = require("../../src/shared/config/RetentionConfig")
local UpgradeConfig = require("../../src/shared/config/UpgradeConfig")
local Profile = require("../../src/shared/domain/Profile")
local Retention = require("../../src/shared/domain/Retention")
local Tycoon = require("../../src/shared/domain/Tycoon")
local Upgrades = require("../../src/shared/domain/Upgrades")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local HARVEST = RetentionConfig.ACHIEVEMENTS[1]

describe("Succès (A64)", function()
	it("vise le premier palier d'un nouveau joueur", function()
		local status = Retention.achievementStatus(Retention.newState(), HARVEST)
		expect(status.tier).toBe(1)
		expect(status.target).toBe(HARVEST.targets[1])
		expect(status.isClaimable).toBe(false)
	end)
	it("se réclame une fois le palier atteint, puis vise le suivant", function()
		local state = Retention.newState()
		Retention.record(state, HARVEST.stat, HARVEST.targets[1], 20_000)
		local reward = Retention.claimAchievement(state, HARVEST.id) :: RetentionConfig.Reward
		expect(reward.gems).toBe(HARVEST.gems[1])
		expect(Retention.claimAchievement(state, HARVEST.id)).toBe(nil)
		expect(Retention.achievementStatus(state, HARVEST).tier).toBe(2)
	end)
	it("termine la famille après le dernier palier", function()
		local state = Retention.newState()
		state.stats[HARVEST.stat] = HARVEST.targets[#HARVEST.targets]
		for _ = 1, #HARVEST.targets do
			Retention.claimAchievement(state, HARVEST.id)
		end
		expect(Retention.achievementStatus(state, HARVEST).isMaxed).toBe(true)
		expect(Retention.claimAchievement(state, HARVEST.id)).toBe(nil)
	end)
	it("refuse une famille inconnue", function()
		expect(Retention.claimAchievement(Retention.newState(), "Nope")).toBe(nil)
		expect(Retention.claimAchievement(Retention.newState(), 12)).toBe(nil)
	end)
	it("survit à la sauvegarde, bornée et nettoyée", function()
		local restored = Profile.sanitize({ retention = { achievements = { Harvest = 2, Bumper = 99, Nope = 1 } } })
		expect(restored.retention.achievements.Harvest).toBe(2)
		expect(restored.retention.achievements.Bumper).toBe(#RetentionConfig.ACHIEVEMENTS[5].targets)
		expect(restored.retention.achievements.Nope).toBe(nil)
	end)
	it("a des paliers croissants, chacun récompensé", function()
		for _, def in RetentionConfig.ACHIEVEMENTS do
			expect(#def.gems).toBe(#def.targets)
			for index = 2, #def.targets do
				expect(def.targets[index] > def.targets[index - 1]).toBe(true)
			end
			expect(table.find(RetentionConfig.STATS, def.stat) ~= nil).toBe(true)
		end
	end)
end)

describe("Améliorations en gemmes (A65)", function()
	it("coûte le prix du niveau suivant, jusqu'au maximum", function()
		local def = UpgradeConfig.UPGRADES[1]
		local levels: Upgrades.Levels = {}
		expect(Upgrades.price(levels, def.id)).toBe(def.prices[1])
		levels[def.id] = #def.prices
		expect(Upgrades.price(levels, def.id)).toBe(nil)
	end)
	it("cumule l'effet de chaque niveau", function()
		expect(Upgrades.multiplier({}, "bag")).toBe(1)
		expect(Upgrades.multiplier({ Bag = 3 }, "bag")).toBeCloseTo(1.3)
		expect(Upgrades.multiplier({ Bag = 3 }, "income")).toBe(1)
	end)
	it("se transmet au client et se sauvegarde, nettoyé", function()
		local levels = Upgrades.decode(Upgrades.encode({ Bag = 2, Accountant = 1 }))
		expect(levels.Bag).toBe(2)
		expect(levels.Accountant).toBe(1)
		expect(levels.Blades).toBe(nil)
		local data = Profile.sanitize({ upgrades = { Bag = 99, Nope = 3, Blades = 0 / 0 } })
		expect(data.upgrades.Bag).toBe(#UpgradeConfig.UPGRADES[1].prices)
		expect(data.upgrades.Nope).toBe(nil)
		expect(data.upgrades.Blades).toBe(nil)
	end)
	it("Comptable Génial multiplie le revenu de l'usine", function()
		local state = Tycoon.new()
		local bonus = { petBonuses = {}, rebirths = 0, hasIncomeX2 = false, upgradeMultiplier = 1.2 }
		expect(Tycoon.fullIncomePerSecond(state, bonus)).toBeCloseTo(
			Tycoon.fullIncomePerSecond(state, Tycoon.NO_BONUS) * 1.2
		)
	end)
end)
