--!strict
-- Montant réel d'une récompense (cadeaux, quêtes, roue, connexion, codes ; A59, A73), sans API Roblox.
-- Une récompense en argent vaut `incomeMinutes` minutes de l'usine du joueur à plein régime, sans jamais dépasser la
-- moitié de son prochain achat (A73) : elle aide, elle ne fait pas sauter des paliers. Avant le premier Rebirth, un
-- montant plancher (`money`) donne un vrai coup de pouce au débutant dont l'usine ne rapporte encore rien ; après,
-- ce plancher fixe permettait de racheter d'un coup les premiers outils d'une nouvelle partie.
-- Le serveur et le client calculent la même chose : le menu affiche exactement ce que le serveur versera.
local RetentionConfig = require("../config/RetentionConfig")

export type Context = {
	income: number, -- revenu de l'usine à plein régime ($/s, sans boost temporaire)
	rebirths: number,
	goalPrice: number, -- prix du prochain achat (Goal) ; 0 sans objectif
}

local Rewards = {}

local SECONDS_PER_MINUTE = 60
Rewards.GOAL_SHARE = 0.5 -- une récompense paie au plus la moitié du prochain achat

local function isUsable(value: number): boolean
	return value == value and value > 0 and value ~= math.huge
end

function Rewards.moneyOf(reward: RetentionConfig.Reward, context: Context): number
	local minutes = reward.incomeMinutes or 0
	local amount = if minutes > 0 and isUsable(context.income)
		then math.floor(minutes * SECONDS_PER_MINUTE * context.income)
		else 0
	if isUsable(context.goalPrice) then
		amount = math.min(amount, math.floor(context.goalPrice * Rewards.GOAL_SHARE))
	end
	if context.rebirths <= 0 then
		amount = math.max(amount, reward.money or 0)
	end
	return amount
end

-- Copie concrète de la récompense : `money` contient le montant final, `incomeMinutes` disparaît.
function Rewards.resolve(reward: RetentionConfig.Reward, context: Context): RetentionConfig.Reward
	local resolved: RetentionConfig.Reward = {
		gems = reward.gems,
		item = reward.item,
		count = reward.count,
	}
	if reward.money or reward.incomeMinutes then
		resolved.money = Rewards.moneyOf(reward, context)
	end
	return resolved
end

-- Contexte d'un joueur d'après ses attributs (publiés par le serveur), et le revenu à plein régime.
function Rewards.contextOf(player: Instance, income: number): Context
	local rebirths = player:GetAttribute("Rebirths")
	local goalPrice = player:GetAttribute("GoalPrice")
	return {
		income = income,
		rebirths = if typeof(rebirths) == "number" then rebirths else 0,
		goalPrice = if typeof(goalPrice) == "number" then goalPrice else 0,
	}
end

return Rewards
