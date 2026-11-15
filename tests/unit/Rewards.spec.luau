--!strict
local TestKit = require("../TestKit")
local RetentionConfig = require("../../src/shared/config/RetentionConfig")
local TycoonConfig = require("../../src/shared/config/TycoonConfig")
local VehicleConfig = require("../../src/shared/config/VehicleConfig")
local Goal = require("../../src/shared/domain/Goal")
local Rebirth = require("../../src/shared/domain/Rebirth")
local RewardText = require("../../src/shared/domain/RewardText")
local Rewards = require("../../src/shared/domain/Rewards")
local Tycoon = require("../../src/shared/domain/Tycoon")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Rewards (A59)", function()
	it("garde le montant plancher tant que l'usine rapporte peu", function()
		expect(Rewards.moneyOf({ money = 2_000, incomeMinutes = 4 }, 5)).toBe(2_000)
	end)
	it("vaut des minutes d'usine à plein régime quand c'est plus", function()
		expect(Rewards.moneyOf({ money = 2_000, incomeMinutes = 4 }, 100)).toBe(24_000)
	end)
	it("ignore un revenu absent, nul ou invalide", function()
		local reward = { money = 500, incomeMinutes = 1 }
		expect(Rewards.moneyOf(reward, 0)).toBe(500)
		expect(Rewards.moneyOf(reward, 0 / 0)).toBe(500)
		expect(Rewards.moneyOf(reward, math.huge)).toBe(500)
	end)
	it("ne touche ni aux gemmes ni aux objets", function()
		local resolved = Rewards.resolve({ gems = 5 }, 1_000_000)
		expect(resolved.gems).toBe(5)
		expect(resolved.money).toBe(nil)
		local egg = Rewards.resolve({ item = "LegendaryEgg", count = 1 }, 1_000_000)
		expect(egg.item).toBe("LegendaryEgg")
		expect(egg.money).toBe(nil)
	end)
	it("affiche le montant réel", function()
		expect(RewardText.label(Rewards.resolve({ money = 1_000, incomeMinutes = 2 }, 1_000))).toBe("120 K $")
	end)
	it("indexe toutes les récompenses en argent de la rétention sur le revenu", function()
		local function check(reward: RetentionConfig.Reward)
			if reward.money then
				expect((reward.incomeMinutes or 0) > 0).toBe(true)
			end
		end
		for _, gift in RetentionConfig.GIFTS do
			check(gift.reward)
		end
		for _, segment in RetentionConfig.WHEEL do
			check(segment.reward)
		end
		for _, quest in RetentionConfig.QUESTS do
			check(quest.reward)
		end
	end)
	it("le revenu à plein régime ne dépend pas du silo", function()
		local state = Tycoon.new()
		expect(Tycoon.incomePerSecond(state, Tycoon.NO_BONUS)).toBe(0)
		expect(Tycoon.fullIncomePerSecond(state, Tycoon.NO_BONUS)).toBe(TycoonConfig.CONVEYOR.BASE_RATE)
	end)
end)

describe("Goal (A59)", function()
	local progress = Rebirth.newProgress()

	it("vise d'abord la Faux au Garage", function()
		local goal = Goal.next(Tycoon.new(), 1, progress) :: Goal.Goal
		expect(goal.id).toBe(TycoonConfig.GARAGE_NAME)
		expect(goal.price).toBe(VehicleConfig.TIERS[2].price)
	end)
	it("choisit le moins cher entre le Garage et la prochaine machine", function()
		local state = Tycoon.new()
		state.machines.Mill = true
		local goal = Goal.next(state, 4, progress) :: Goal.Goal -- Four 20 000 $ contre Double Faucheuse 85 000 $
		expect(goal.id).toBe("Oven")
	end)
	it("propose le Rebirth une fois l'usine complète", function()
		local state = Tycoon.new()
		for _, machine in TycoonConfig.MACHINES do
			state.machines[machine.id] = true
		end
		local goal = Goal.next(state, #VehicleConfig.TIERS, progress) :: Goal.Goal
		expect(goal.id).toBe(TycoonConfig.REBIRTH_NAME)
		expect(goal.price).toBe(Rebirth.cost(progress))
	end)
end)
