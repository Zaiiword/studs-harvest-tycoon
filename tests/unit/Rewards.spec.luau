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

local function context(income: number, rebirths: number?, goalPrice: number?): Rewards.Context
	return { income = income, rebirths = rebirths or 0, goalPrice = goalPrice or 0 }
end

describe("Rewards (A59, A73)", function()
	it("garde le montant plancher tant que l'usine rapporte peu, avant le premier Rebirth", function()
		expect(Rewards.moneyOf({ money = 2_000, incomeMinutes = 4 }, context(5))).toBe(2_000)
	end)
	it("vaut des minutes d'usine à plein régime quand c'est plus", function()
		expect(Rewards.moneyOf({ money = 2_000, incomeMinutes = 4 }, context(100))).toBe(24_000)
	end)
	it("ignore un revenu absent, nul ou invalide", function()
		local reward = { money = 500, incomeMinutes = 1 }
		expect(Rewards.moneyOf(reward, context(0))).toBe(500)
		expect(Rewards.moneyOf(reward, context(0 / 0))).toBe(500)
		expect(Rewards.moneyOf(reward, context(math.huge))).toBe(500)
	end)
	it("ne paie jamais plus de la moitié du prochain achat", function()
		local reward = { money = 2_000, incomeMinutes = 10 }
		expect(Rewards.moneyOf(reward, context(1_000, 2, 15_000))).toBe(7_500)
		expect(Rewards.moneyOf(reward, context(1, 2, 15_000))).toBe(600)
	end)
	it("supprime le plancher fixe après un Rebirth : plus de premiers outils rachetés d'un coup", function()
		local reward = { money = 25_000, incomeMinutes = 10 }
		expect(Rewards.moneyOf(reward, context(0, 0, 0))).toBe(25_000)
		expect(Rewards.moneyOf(reward, context(0, 1, 188))).toBe(0)
		expect(Rewards.moneyOf(reward, context(3, 1, 188))).toBe(94)
	end)
	it("lit le contexte dans les attributs du joueur", function()
		local fake = {
			GetAttribute = function(_, name: string): any
				return ({ Rebirths = 2, GoalPrice = 400 })[name]
			end,
		}
		local read = Rewards.contextOf(fake :: any, 12)
		expect(read.income).toBe(12)
		expect(read.rebirths).toBe(2)
		expect(read.goalPrice).toBe(400)
	end)
	it("ne touche ni aux gemmes ni aux objets", function()
		local resolved = Rewards.resolve({ gems = 5 }, context(1_000_000))
		expect(resolved.gems).toBe(5)
		expect(resolved.money).toBe(nil)
		local egg = Rewards.resolve({ item = "LegendaryEgg", count = 1 }, context(1_000_000))
		expect(egg.item).toBe("LegendaryEgg")
		expect(egg.money).toBe(nil)
	end)
	it("affiche le montant réel", function()
		expect(RewardText.label(Rewards.resolve({ money = 1_000, incomeMinutes = 2 }, context(1_000)))).toBe("120 K $")
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
