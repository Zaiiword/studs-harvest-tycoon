--!strict
-- Format sauvegardé du profil joueur (CDC §11 « sauvegarde JSON structurée »), sans API Roblox.
-- Tout ce qui sort du DataStore passe par `sanitize` : un champ absent, d'un mauvais type, NaN, infini ou hors
-- bornes reprend sa valeur par défaut. Le numéro de version permet de migrer le format plus tard.
local TycoonConfig = require("../config/TycoonConfig")
local VehicleConfig = require("../config/VehicleConfig")
local Inventory = require("./Inventory")
local Pets = require("./Pets")
local Rebirth = require("./Rebirth")
local Retention = require("./Retention")
local Tycoon = require("./Tycoon")

export type Data = {
	version: number,
	money: number,
	silo: number,
	conveyorLevel: number,
	machines: { string }, -- liste d'ids : sérialisable en JSON sans clé creuse
	tier: number,
	rebirths: number,
	gems: number,
	items: Inventory.Inventory, -- v2 : objets de sabotage et récompenses (Sprint 5)
	pets: Pets.Collection, -- v3 : Pets possédés et équipés (Sprint 6)
	retention: Retention.State, -- v4 : roue, quêtes du jour et statistiques (Sprint 7)
}

-- Ce que les services fournissent pour composer un profil à sauvegarder.
export type GameParts = {
	tycoon: Tycoon.State,
	tier: number,
	progress: Rebirth.Progress,
	items: Inventory.Inventory,
	pets: Pets.Collection,
	retention: Retention.State,
}

local Profile = {}

-- v1 → v2 : `items` ; v2 → v3 : `pets` ; v3 → v4 : `retention`. Un champ absent reprend sa valeur par défaut :
-- la migration est donc faite par `sanitize`, sans code spécifique.
Profile.VERSION = 4

local knownMachines: { [string]: boolean } = {}
for _, machine in TycoonConfig.MACHINES do
	knownMachines[machine.id] = true
end

function Profile.default(): Data
	return {
		version = Profile.VERSION,
		money = TycoonConfig.STARTING_MONEY,
		silo = 0,
		conveyorLevel = 1,
		machines = {},
		tier = Rebirth.STARTING_TIER,
		rebirths = 0,
		gems = 0,
		items = {},
		pets = Pets.newCollection(),
		retention = Retention.newState(),
	}
end

-- Nombre fini dans [min, max], sinon `fallback`. Les entiers attendus sont tronqués.
local function number(value: any, min: number, max: number, fallback: number, isInteger: boolean): number
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	local clamped = math.clamp(value, min, max)
	return if isInteger then math.floor(clamped) else clamped
end

local function machinesOf(value: any): { string }
	local machines: { string } = {}
	if typeof(value) ~= "table" then
		return machines
	end
	for _, id in value do
		if typeof(id) == "string" and knownMachines[id] and not table.find(machines, id) then
			table.insert(machines, id)
		end
	end
	return machines
end

function Profile.sanitize(raw: any): Data
	local source = if typeof(raw) == "table" then raw else {}
	local defaults = Profile.default()
	return {
		version = Profile.VERSION,
		money = number(source.money, 0, math.huge - 1, defaults.money, false),
		silo = number(source.silo, 0, TycoonConfig.SILO_CAPACITY, defaults.silo, false),
		conveyorLevel = number(source.conveyorLevel, 1, TycoonConfig.CONVEYOR.MAX_LEVEL, 1, true),
		machines = machinesOf(source.machines),
		tier = number(source.tier, 1, #VehicleConfig.TIERS, defaults.tier, true),
		rebirths = number(source.rebirths, 0, math.huge - 1, 0, true),
		gems = number(source.gems, 0, math.huge - 1, 0, true),
		items = Inventory.sanitize(source.items),
		pets = Pets.sanitize(source.pets),
		retention = Retention.sanitize(source.retention),
	}
end

function Profile.fromGame(parts: GameParts): Data
	local state = parts.tycoon
	local machines: { string } = {}
	for id, isOwned in state.machines do
		if isOwned then
			table.insert(machines, id)
		end
	end
	table.sort(machines)
	return Profile.sanitize({
		money = state.money,
		silo = state.silo,
		conveyorLevel = state.conveyorLevel,
		machines = machines,
		tier = parts.tier,
		rebirths = parts.progress.rebirths,
		gems = parts.progress.gems,
		items = parts.items,
		pets = parts.pets,
		retention = parts.retention,
	})
end

function Profile.toTycoon(data: Data): Tycoon.State
	local state = Tycoon.new()
	state.money, state.silo, state.conveyorLevel = data.money, data.silo, data.conveyorLevel
	for _, id in data.machines do
		state.machines[id] = true
	end
	return state
end

function Profile.toProgress(data: Data): Rebirth.Progress
	return { rebirths = data.rebirths, gems = data.gems }
end

return Profile
