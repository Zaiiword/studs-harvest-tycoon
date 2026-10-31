--!strict
-- Affichage d'une récompense (cadeaux, quêtes, roue ; CDC §7.4) : une icône et un court texte lisible,
-- avec le vrai nom des objets (« Œuf Légendaire » et non « LegendaryEgg »).
local PetConfig = require("../config/PetConfig")
local RetentionConfig = require("../config/RetentionConfig")
local SabotageConfig = require("../config/SabotageConfig")
local Format = require("../util/Format")

local RewardText = {}

local MONEY_ICON, GEMS_ICON, EGG_ICON, GIFT_ICON = "💰", "💎", "🥚", "🎁"

local function itemLook(id: string): (string, string)
	for _, item in SabotageConfig.ITEMS do
		if item.id == id then
			return item.icon, item.name
		end
	end
	for _, egg in PetConfig.EGGS do
		if egg.id == id then
			return EGG_ICON, egg.name
		end
	end
	return GIFT_ICON, id
end

function RewardText.icon(reward: RetentionConfig.Reward): string
	if reward.money then
		return MONEY_ICON
	elseif reward.gems then
		return GEMS_ICON
	end
	return (itemLook(reward.item or ""))
end

-- Texte court : « 5 K $ », « 10 💎 », « 2 × Gant de Boxe ».
function RewardText.label(reward: RetentionConfig.Reward): string
	if reward.money then
		return `{Format.money(reward.money)} $`
	elseif reward.gems then
		return `{reward.gems} {GEMS_ICON}`
	end
	local _, name = itemLook(reward.item or "")
	return `{reward.count or 1} × {name}`
end

-- Chances de chaque case de la roue, en pourcentage arrondi au dixième (A45 : chances affichées).
function RewardText.wheelOdds(): { number }
	local total = 0
	for _, segment in RetentionConfig.WHEEL do
		total += segment.weight
	end
	local odds = {}
	for _, segment in RetentionConfig.WHEEL do
		table.insert(odds, math.floor(segment.weight / total * 1000 + 0.5) / 10)
	end
	return odds
end

return RewardText
