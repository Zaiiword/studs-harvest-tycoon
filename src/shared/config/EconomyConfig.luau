--!strict
-- Constantes d'économie — CDC §8.

return table.freeze({
	TYCOON_PRICE_GROWTH = 1.35, -- Prix(n) = Base × 1,35^n
	REBIRTH_INCOME_BONUS = 0.5, -- (1 + 0,5 × Rebirths)
	REBIRTH_BASE_COST = 1_000_000, -- décision A8
	REBIRTH_COST_GROWTH = 3,
	INCOME_X2_MULTIPLIER = 2, -- Gamepass Revenus ×2
})
