--!strict
-- Bonus social (A63), sans API Roblox : +10 % de revenus par ami présent sur le serveur (4 au plus) et +10 % pour
-- les abonnés Roblox Premium. Inviter ses amis devient rentable, et Premium rapporte au jeu (Premium Payouts).
local EconomyConfig = require("../config/EconomyConfig")

local Social = {}

function Social.multiplier(friendsOnline: number, isPremium: boolean): number
	local friends = math.clamp(math.floor(friendsOnline), 0, EconomyConfig.MAX_FRIENDS_COUNTED)
	return 1 + EconomyConfig.FRIEND_BONUS * friends + (if isPremium then EconomyConfig.PREMIUM_BONUS else 0)
end

-- « +20 % » pour le HUD.
function Social.percent(multiplier: number): string
	return `+{math.floor((multiplier - 1) * 100 + 0.5)} %`
end

return Social
