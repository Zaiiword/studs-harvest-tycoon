--!strict
-- Tirage de rareté d'un brin qui repousse (CDC §4). Le générateur est injecté pour des tests déterministes.
local FieldConfig = require("../config/FieldConfig")

export type Rng = () -> number -- renvoie un nombre dans [0, 1)

local Rarity = {}

local RARITIES = FieldConfig.RARITIES
local byId: { [number]: FieldConfig.RarityDef } = {}
for _, def in RARITIES do
	byId[def.id] = def
end

Rarity.NORMAL = RARITIES.Normal.id
Rarity.GIANT = RARITIES.Giant.id
Rarity.RAINBOW = RARITIES.Rainbow.id

function Rarity.byId(id: number): FieldConfig.RarityDef
	local def = byId[id]
	assert(def, `rareté inconnue : {id}`)
	return def
end

-- `rainbowBoost` multiplie la chance Arc-en-ciel (Nuit Néon ×5, CDC §6). Le plus rare est testé en premier.
function Rarity.roll(rng: Rng, rainbowBoost: number?): number
	local roll = rng()
	local rainbowChance = RARITIES.Rainbow.chance * (rainbowBoost or 1)
	if roll < rainbowChance then
		return Rarity.RAINBOW
	end
	if roll < rainbowChance + RARITIES.Giant.chance then
		return Rarity.GIANT
	end
	return Rarity.NORMAL
end

return Rarity
