--!strict
-- Montant réel d'une récompense (cadeaux, quêtes, roue, connexion, codes ; A59), sans API Roblox.
-- Une somme fixe ne vaut plus rien au bout d'une heure de jeu : une récompense en argent vaut donc le plus grand de
-- son montant plancher (`money`) et de `incomeMinutes` minutes de l'usine du joueur tournant à plein régime.
-- Le serveur et le client calculent la même chose : le menu affiche exactement ce que le serveur versera.
local RetentionConfig = require("../config/RetentionConfig")

local Rewards = {}

local SECONDS_PER_MINUTE = 60

-- Argent versé pour une récompense, d'après le revenu à plein régime de l'usine ($/s, sans boost temporaire).
function Rewards.moneyOf(reward: RetentionConfig.Reward, factoryIncome: number): number
	local floor = reward.money or 0
	local minutes = reward.incomeMinutes or 0
	if minutes <= 0 or factoryIncome ~= factoryIncome or factoryIncome <= 0 or factoryIncome == math.huge then
		return floor
	end
	return math.max(floor, math.floor(minutes * SECONDS_PER_MINUTE * factoryIncome))
end

-- Copie concrète de la récompense : `money` contient le montant final, `incomeMinutes` disparaît.
function Rewards.resolve(reward: RetentionConfig.Reward, factoryIncome: number): RetentionConfig.Reward
	local resolved: RetentionConfig.Reward = {
		gems = reward.gems,
		item = reward.item,
		count = reward.count,
	}
	if reward.money or reward.incomeMinutes then
		resolved.money = Rewards.moneyOf(reward, factoryIncome)
	end
	return resolved
end

return Rewards
