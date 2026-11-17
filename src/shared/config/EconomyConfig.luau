--!strict
-- Constantes d'économie — CDC §8.

return table.freeze({
	TYCOON_PRICE_GROWTH = 1.35, -- Prix(n) = Base × 1,35^n
	REBIRTH_INCOME_BONUS = 0.5, -- (1 + 0,5 × Rebirths)
	REBIRTH_BASE_COST = 500_000_000, -- décision A8
	REBIRTH_COST_GROWTH = 4,
	-- A70 : à chaque Rebirth, le Garage, les machines et le tapis coûtent ×REBIRTH_PRICE_GROWTH. Sans cela, les Pets
	-- (conservés) rendaient chaque nouvelle partie plus courte que la précédente : 36, 15, puis 10 minutes.
	REBIRTH_PRICE_GROWTH = 2.5,
	INCOME_X2_MULTIPLIER = 2, -- Gamepass Revenus ×2
	GEMS_PER_REBIRTH = 25, -- A9, A70 : gemmes gagnées = 25 × (r + 1) (le Rebirth est devenu rare)
	-- Bonus social (A63) : jouer avec ses amis et avoir Roblox Premium font tourner l'usine plus vite.
	FRIEND_BONUS = 0.1, -- +10 % de revenus par ami présent sur le serveur…
	MAX_FRIENDS_COUNTED = 4, -- … dans la limite de 4 amis (+40 %)
	PREMIUM_BONUS = 0.1, -- +10 % pour les abonnés Roblox Premium
})
