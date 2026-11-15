--!strict
-- Améliorations permanentes en gemmes (A65), sans API Roblox : niveaux possédés, prix du suivant, effet cumulé.
local UpgradeConfig = require("../config/UpgradeConfig")

export type Levels = { [string]: number } -- id → niveau acheté (0 si absent)

local Upgrades = {}

local byId: { [string]: UpgradeConfig.UpgradeDef } = {}
for _, upgrade in UpgradeConfig.UPGRADES do
	byId[upgrade.id] = upgrade
end

function Upgrades.get(id: any): UpgradeConfig.UpgradeDef?
	return if typeof(id) == "string" then byId[id] else nil
end

-- Niveaux connus, entiers et bornés par le niveau maximal de chaque amélioration.
function Upgrades.sanitize(raw: any): Levels
	local levels: Levels = {}
	if typeof(raw) ~= "table" then
		return levels
	end
	for id, value in raw do
		local def = Upgrades.get(id)
		if def and typeof(value) == "number" and value == value and value >= 1 then
			levels[def.id] = math.min(math.floor(value), #def.prices)
		end
	end
	return levels
end

-- Prix en gemmes du prochain niveau, ou nil au niveau maximal.
function Upgrades.price(levels: Levels, id: string): number?
	local def = byId[id]
	return if def then def.prices[(levels[id] or 0) + 1] else nil
end

-- Multiplicateur d'un effet : produit des améliorations qui le portent (1 sans amélioration).
function Upgrades.multiplier(levels: Levels, effect: UpgradeConfig.Effect): number
	local multiplier = 1
	for _, def in UpgradeConfig.UPGRADES do
		if def.effect == effect then
			multiplier *= 1 + def.perLevel * (levels[def.id] or 0)
		end
	end
	return multiplier
end

-- « Bag=2,Blades=1 » pour l'attribut du joueur, et l'inverse côté client.
function Upgrades.encode(levels: Levels): string
	local parts = {}
	for _, def in UpgradeConfig.UPGRADES do
		table.insert(parts, `{def.id}={levels[def.id] or 0}`)
	end
	return table.concat(parts, ",")
end

function Upgrades.decode(text: any): Levels
	local raw: { [string]: number } = {}
	for id, value in string.gmatch(if typeof(text) == "string" then text else "", "(%w+)=(%d+)") do
		raw[id] = tonumber(value) :: number
	end
	return Upgrades.sanitize(raw)
end

return Upgrades
