--!strict
-- Validation des commandes du panneau de test (Studio uniquement). Pure : testée sous Lune.
-- Même en Studio, le serveur ne fait pas confiance au client : type, bornes et liste blanche.
local EventConfig = require("../config/EventConfig")
local MonetizationConfig = require("../config/MonetizationConfig")
local VehicleConfig = require("../config/VehicleConfig")

export type Command =
	{ kind: "tier", tier: number }
	| { kind: "money", amount: number }
	| { kind: "meteor" }
	| { kind: "weather", weather: string }
	| { kind: "items" }
	| { kind: "pass", key: string }
	| { kind: "product", key: string }

local DevCommands = {}

DevCommands.MONEY_GRANTS = { 10_000, 10_000_000 } -- liste fixe : le client ne choisit jamais une somme libre
DevCommands.ITEMS_GRANT = 3 -- exemplaires de chaque objet de sabotage
DevCommands.GEMS_GRANT = 50

-- Clé d'un Gamepass ou d'un produit de MonetizationConfig.
local function isKey(list: { { key: string } }, value: any): boolean
	for _, entry in list do
		if entry.key == value then
			return true
		end
	end
	return false
end

local function isWeather(value: any): boolean
	for _, weather in EventConfig.WEATHERS do
		if weather.id == value then
			return true
		end
	end
	return false
end

function DevCommands.parse(kind: any, value: any): Command?
	if kind == "tier" and typeof(value) == "number" and value == value // 1 and VehicleConfig.TIERS[value] then
		return { kind = "tier", tier = value }
	end
	if kind == "weather" and isWeather(value) then
		return { kind = "weather", weather = value }
	end
	if kind == "pass" and isKey(MonetizationConfig.GAMEPASSES, value) then
		return { kind = "pass", key = value }
	end
	if kind == "product" and isKey(MonetizationConfig.PRODUCTS, value) then
		return { kind = "product", key = value }
	end
	if kind == "money" and table.find(DevCommands.MONEY_GRANTS, value) then
		return { kind = "money", amount = value }
	end
	if kind == "meteor" or kind == "items" then
		return { kind = kind } :: any
	end
	return nil
end

return DevCommands
