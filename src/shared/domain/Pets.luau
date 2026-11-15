--!strict
-- Collection de Pets d'un joueur (CDC §7.2, §8 ; A1, A17, A42, A43), sans API Roblox.
-- Un Pet est identifié par une clé « Espèce:Variante » (« Dragon:Gold ») ; la collection compte les
-- exemplaires de chaque clé et liste ceux qui sont équipés (une clé peut être équipée plusieurs fois).
local PetConfig = require("../config/PetConfig")

export type Collection = {
	owned: { [string]: number },
	equipped: { string },
	discovered: { [string]: boolean }, -- index (A66) : clés déjà obtenues au moins une fois
}

local Pets = {}

local SEPARATOR = ":"
local speciesById: { [string]: PetConfig.SpeciesDef } = {}
local raritiesById: { [string]: PetConfig.RarityDef } = {}
local variantsById: { [string]: PetConfig.VariantDef } = {}
local eggsById: { [string]: PetConfig.EggDef } = {}
local speciesByRarity: { [string]: { PetConfig.SpeciesDef } } = {}
for _, species in PetConfig.SPECIES do
	speciesById[species.id] = species
	speciesByRarity[species.rarity] = speciesByRarity[species.rarity] or {}
	table.insert(speciesByRarity[species.rarity], species)
end
for _, rarity in PetConfig.RARITIES do
	raritiesById[rarity.id] = rarity
end
for _, variant in PetConfig.VARIANTS do
	variantsById[variant.id] = variant
end
for _, egg in PetConfig.EGGS do
	eggsById[egg.id] = egg
end

function Pets.key(speciesId: string, variantId: string): string
	return speciesId .. SEPARATOR .. variantId
end

function Pets.parse(key: string): (PetConfig.SpeciesDef?, PetConfig.VariantDef?)
	local speciesId, variantId = string.match(key, "^(%w+)" .. SEPARATOR .. "(%w+)$")
	if not speciesId then
		return nil, nil
	end
	return speciesById[speciesId], variantsById[variantId :: string]
end

function Pets.isKnown(key: any): boolean
	if typeof(key) ~= "string" then
		return false
	end
	local species, variant = Pets.parse(key)
	return species ~= nil and variant ~= nil
end

function Pets.rarityOf(key: string): PetConfig.RarityDef
	local species = Pets.parse(key)
	assert(species, `Pet inconnu : {key}`)
	return raritiesById[species.rarity]
end

-- A17 : bonus de la rareté, amplifié par la variante (Or ×2, Arc-en-ciel ×5) au-delà de 1.
function Pets.bonusOf(key: string): number
	local _, variant = Pets.parse(key)
	assert(variant, `Pet inconnu : {key}`)
	return 1 + (Pets.rarityOf(key).bonus - 1) * variant.multiplier
end

function Pets.egg(id: any): PetConfig.EggDef?
	return if typeof(id) == "string" then eggsById[id] else nil
end

-- Distributeur visible ? Il suffit d'atteindre l'un des seuils de PetConfig.EGG_UNLOCKS (A56).
function Pets.isEggVisible(eggId: string, tier: number, rebirths: number): boolean
	local unlock = PetConfig.EGG_UNLOCKS[eggId]
	if not unlock then
		return true
	end
	return tier >= (unlock.minTier or math.huge) or rebirths >= (unlock.minRebirths or math.huge)
end

-- Tire un Pet (variante normale) selon la table de chances de l'œuf : la rareté d'abord, puis l'espèce au hasard
-- parmi celles de cette rareté (A66), avec le même nombre tiré (sa position dans la tranche de la rareté).
function Pets.roll(egg: PetConfig.EggDef, rng: () -> number): string
	local total = 0
	for _, weight in egg.odds do
		total += weight
	end
	local pick = rng() * total
	local chosen: string? = nil
	local share = 0 -- position du tirage dans la tranche de la rareté choisie, dans [0, 1)
	for _, rarity in PetConfig.RARITIES do -- ordre fixe : tirage reproductible
		local weight = egg.odds[rarity.id] or 0
		if weight > 0 then
			chosen = rarity.id
			share = math.clamp(pick / weight, 0, 0.999999)
			if pick < weight then
				break
			end
			pick -= weight
		end
	end
	local pool = speciesByRarity[chosen :: string]
	return Pets.key(pool[math.floor(share * #pool) + 1].id, "Normal")
end

-- Toutes les entrées de l'index (A66) : chaque espèce dans chaque variante, de la plus commune à la plus rare.
function Pets.indexKeys(): { string }
	local keys: { string } = {}
	for _, rarity in PetConfig.RARITIES do
		for _, species in speciesByRarity[rarity.id] or {} do
			for _, variant in PetConfig.VARIANTS do
				table.insert(keys, Pets.key(species.id, variant.id))
			end
		end
	end
	return keys
end

-- Gemmes gagnées à la première obtention d'une clé (A66).
function Pets.indexGems(key: string): number
	local _, variant = Pets.parse(key)
	return (PetConfig.INDEX_GEMS[Pets.rarityOf(key).id] or 0) * (if variant then variant.multiplier else 1)
end

-- Marque une clé comme découverte. Renvoie vrai si c'est une nouveauté.
function Pets.discover(collection: Collection, key: string): boolean
	if collection.discovered[key] or not Pets.isKnown(key) then
		return false
	end
	collection.discovered[key] = true
	return true
end

function Pets.newCollection(): Collection
	return { owned = {}, equipped = {}, discovered = {} }
end

function Pets.total(collection: Collection): number
	local total = 0
	for _, count in collection.owned do
		total += count
	end
	return total
end

function Pets.add(collection: Collection, key: string): boolean
	if not Pets.isKnown(key) or Pets.total(collection) >= PetConfig.MAX_PETS then
		return false
	end
	collection.owned[key] = (collection.owned[key] or 0) + 1
	Pets.discover(collection, key)
	return true
end

local function equippedCount(collection: Collection, key: string): number
	local count = 0
	for _, equipped in collection.equipped do
		count += if equipped == key then 1 else 0
	end
	return count
end

function Pets.equip(collection: Collection, key: string): boolean
	if #collection.equipped >= PetConfig.MAX_EQUIPPED then
		return false
	end
	if equippedCount(collection, key) >= (collection.owned[key] or 0) then
		return false
	end
	table.insert(collection.equipped, key)
	return true
end

function Pets.unequip(collection: Collection, key: string): boolean
	local position = table.find(collection.equipped, key)
	if not position then
		return false
	end
	table.remove(collection.equipped, position)
	return true
end

-- Variante suivante (Normal → Or → Arc-en-ciel), ou nil au sommet.
function Pets.nextVariant(key: string): string?
	local species, variant = Pets.parse(key)
	if not species or not variant then
		return nil
	end
	for index, candidate in PetConfig.VARIANTS do
		if candidate.id == variant.id then
			local nextOne = PetConfig.VARIANTS[index + 1]
			return nextOne and Pets.key(species.id, nextOne.id)
		end
	end
	return nil
end

-- Fusionne FUSION_COUNT exemplaires identiques en un exemplaire de la variante suivante (CDC §7.2).
-- Les exemplaires équipés qui n'existent plus après la fusion sont déséquipés.
function Pets.fuse(collection: Collection, key: string): string?
	local fused = Pets.nextVariant(key)
	local owned = collection.owned[key] or 0
	if not fused or owned < PetConfig.FUSION_COUNT then
		return nil
	end
	local remaining = owned - PetConfig.FUSION_COUNT
	collection.owned[key] = if remaining > 0 then remaining else nil
	while equippedCount(collection, key) > remaining do
		Pets.unequip(collection, key)
	end
	collection.owned[fused] = (collection.owned[fused] or 0) + 1
	Pets.discover(collection, fused)
	return fused
end

-- « Équiper les meilleurs » : les Pets au plus gros bonus, autant d'exemplaires qu'on en possède.
function Pets.equipBest(collection: Collection)
	local keys: { string } = {}
	for key in collection.owned do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		local bonusA, bonusB = Pets.bonusOf(a), Pets.bonusOf(b)
		return if bonusA ~= bonusB then bonusA > bonusB else a < b
	end)
	collection.equipped = {}
	for _, key in keys do
		for _ = 1, collection.owned[key] do
			if #collection.equipped >= PetConfig.MAX_EQUIPPED then
				return
			end
			table.insert(collection.equipped, key)
		end
	end
end

-- Bonus des Pets équipés, pour Formulas.petFactor (A1) : revenus de l'usine et puissance de coupe (A2).
function Pets.bonuses(collection: Collection): { number }
	local bonuses: { number } = {}
	for _, key in collection.equipped do
		table.insert(bonuses, Pets.bonusOf(key))
	end
	return bonuses
end

-- Nettoie une collection lue depuis le DataStore : clés connues, quantités entières, équipement cohérent.
function Pets.sanitize(raw: any): Collection
	local collection = Pets.newCollection()
	local source = if typeof(raw) == "table" then raw else {}
	if typeof(source.owned) == "table" then
		for key, count in source.owned do
			if Pets.isKnown(key) and typeof(count) == "number" and count == count and count >= 1 then
				collection.owned[key] = math.min(math.floor(count), PetConfig.MAX_PETS)
			end
		end
	end
	if typeof(source.equipped) == "table" then
		for _, key in source.equipped do
			if Pets.isKnown(key) then
				Pets.equip(collection, key)
			end
		end
	end
	-- Index (A66) : ce qui a été découvert, plus tout ce qu'on possède (profils d'avant l'index).
	if typeof(source.discovered) == "table" then
		for key, value in source.discovered do
			if value == true then
				Pets.discover(collection, key)
			end
		end
	end
	for key in collection.owned do
		Pets.discover(collection, key)
	end
	return collection
end

-- Contrat réseau : la collection est publiée dans un attribut texte « clé=nombre,clé=nombre » (menu client).
function Pets.encodeOwned(owned: { [string]: number }): string
	local parts: { string } = {}
	for key, count in owned do
		table.insert(parts, `{key}={count}`)
	end
	table.sort(parts)
	return table.concat(parts, ",")
end

function Pets.decodeOwned(text: any): { [string]: number }
	local owned: { [string]: number } = {}
	if typeof(text) ~= "string" then
		return owned
	end
	for key, count in string.gmatch(text, "([^,=]+)=(%d+)") do
		if Pets.isKnown(key) then
			owned[key] = tonumber(count) :: number
		end
	end
	return owned
end

-- Contrat réseau : l'index est publié dans un attribut texte « clé,clé » (A66).
function Pets.encodeDiscovered(discovered: { [string]: boolean }): string
	local keys: { string } = {}
	for key in discovered do
		table.insert(keys, key)
	end
	table.sort(keys)
	return table.concat(keys, ",")
end

function Pets.decodeDiscovered(text: any): { [string]: boolean }
	local discovered: { [string]: boolean } = {}
	for key in string.gmatch(if typeof(text) == "string" then text else "", "[^,]+") do
		if Pets.isKnown(key) then
			discovered[key] = true
		end
	end
	return discovered
end

-- Contrat réseau : les Pets équipés sont publiés dans un attribut texte « clé,clé,clé ».
function Pets.encodeEquipped(equipped: { string }): string
	return table.concat(equipped, ",")
end

function Pets.decodeEquipped(text: any): { string }
	local keys: { string } = {}
	if typeof(text) ~= "string" then
		return keys
	end
	for key in string.gmatch(text, "[^,]+") do
		if Pets.isKnown(key) and #keys < PetConfig.MAX_EQUIPPED then
			table.insert(keys, key)
		end
	end
	return keys
end

return Pets
