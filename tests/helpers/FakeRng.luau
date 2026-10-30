--!strict
-- Générateurs pseudo-aléatoires déterministes pour les tests (docs/CLEAN_CODE.md §6).

local FakeRng = {}

-- Renvoie toujours la même valeur.
function FakeRng.constant(value: number): () -> number
	return function()
		return value
	end
end

-- Renvoie les valeurs dans l'ordre, puis `fallback` une fois la liste épuisée.
function FakeRng.sequence(values: { number }, fallback: number): () -> number
	local position = 0
	return function()
		position += 1
		return values[position] or fallback
	end
end

-- Générateur congruentiel linéaire à graine (Numerical Recipes), uniforme dans [0, 1).
function FakeRng.seeded(seed: number): () -> number
	local state = seed % 4294967296
	return function()
		state = (1664525 * state + 1013904223) % 4294967296
		return state / 4294967296
	end
end

return FakeRng
