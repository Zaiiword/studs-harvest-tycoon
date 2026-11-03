--!strict
-- Flèches de guidage au sol (A53), sans API Roblox : où emmener le joueur (une seule fois par objet : on ne
-- montre pas dix fois le tapis roulant), par quel chemin (les ponts pour franchir le fossé), et où poser
-- chaque chevron le long du trajet.
local MapConfig = require("../config/MapConfig")
local TycoonConfig = require("../config/TycoonConfig")
local MapGeometry = require("./MapGeometry")

export type Point = { x: number, z: number }
export type Button = { id: string, price: number, x: number, z: number }
export type Situation = {
	money: number,
	isBagFull: boolean,
	unload: Point?, -- grille de déchargement de sa base
	buttons: { Button }, -- boutons achetables de sa base (prix connu)
	seen: { [string]: boolean }, -- objets déjà montrés (ids de bouton, ou UNLOAD) : on n'y ramène plus
}
export type Target = { kind: "unload" | "button", point: Point, id: string? }
export type Chevron = { x: number, z: number, dirX: number, dirZ: number }
export type ChevronSpec = {
	spacing: number, -- studs entre deux chevrons
	start: number, -- distance laissée devant le joueur
	maxLength: number, -- on ne dessine que le début du trajet
	phase: number, -- décalage animé, dans [0, spacing)
}

local Guide = {}

local MOAT = MapConfig.MOAT

Guide.UNLOAD = TycoonConfig.GUIDE_UNLOAD_KEY -- clé de la grille de déchargement dans `seen`

-- Bouton le moins cher que le joueur peut payer tout de suite, parmi ceux pas encore montrés.
function Guide.cheapestAffordable(buttons: { Button }, money: number, seen: { [string]: boolean }): Button?
	local best: Button? = nil
	for _, button in buttons do
		if not seen[button.id] and button.price <= money and (best == nil or button.price < best.price) then
			best = button
		end
	end
	return best
end

-- Sac plein : décharger d'abord. Sinon : le bouton abordable le moins cher. Sinon : rien à montrer.
-- Chaque objet n'est montré qu'une fois (voir `seen`).
function Guide.target(situation: Situation): Target?
	if situation.isBagFull and situation.unload and not situation.seen[Guide.UNLOAD] then
		return { kind = "unload", point = situation.unload, id = Guide.UNLOAD }
	end
	local button = Guide.cheapestAffordable(situation.buttons, situation.money, situation.seen)
	if button then
		return { kind = "button", point = { x = button.x, z = button.z }, id = button.id }
	end
	return nil
end

local function isInField(point: Point): boolean
	return point.x >= MOAT.maxX
end

-- Porte d'une base (ouverte côté champ, DecorConfig.FENCE) : la clôture interdit de couper tout droit.
local function doorOf(base: MapGeometry.Placement): Point
	return { x = base.x + MapConfig.BASE_SIZE / 2, z = base.z }
end

local function baseAt(point: Point): MapGeometry.Placement?
	for _, base in MapGeometry.baseCenters() do
		if MapGeometry.isInsideBase(base, point.x, point.z) then
			return base
		end
	end
	return nil
end

-- Partie du trajet hors des bases : tout droit, ou par le pont le plus commode pour franchir le fossé.
local function outdoorRoute(from: Point, to: Point): { Point }
	if isInField(from) == isInField(to) then
		return { from, to }
	end
	local best, bestCost = nil, math.huge
	for _, bridge in MapGeometry.bridges() do
		local cost = math.abs(from.z - bridge.z) + math.abs(to.z - bridge.z)
		if cost < bestCost then
			best, bestCost = bridge, cost
		end
	end
	local bridge = best :: MapGeometry.BridgePlacement
	local fieldEnd = { x = bridge.x + bridge.length / 2, z = bridge.z }
	local plazaEnd = { x = bridge.x - bridge.length / 2, z = bridge.z }
	if isInField(from) then
		return { from, fieldEnd, plazaEnd, to }
	end
	return { from, plazaEnd, fieldEnd, to }
end

-- Trajet complet en ligne brisée : passe par les portes des bases quitte ou rejointe, puis par les ponts.
function Guide.route(from: Point, to: Point): { Point }
	local fromBase, toBase = baseAt(from), baseAt(to)
	if fromBase and toBase and fromBase.index == toBase.index then
		return { from, to }
	end
	local start = if fromBase then doorOf(fromBase) else from
	local finish = if toBase then doorOf(toBase) else to
	local route: { Point } = if fromBase then { from } else {}
	for _, point in outdoorRoute(start, finish) do
		table.insert(route, point)
	end
	if toBase then
		table.insert(route, to)
	end
	return route
end

-- Chevrons régulièrement espacés le long du trajet, orientés vers la cible, sans dépasser `maxLength`
-- ni recouvrir la cible elle-même.
function Guide.chevrons(route: { Point }, spec: ChevronSpec): { Chevron }
	local chevrons: { Chevron } = {}
	local walked = 0 -- distance parcourue au début du segment courant
	local nextAt = spec.start + spec.phase
	for index = 1, #route - 1 do
		local a, b = route[index], route[index + 1]
		local dx, dz = b.x - a.x, b.z - a.z
		local length = math.sqrt(dx * dx + dz * dz)
		if length > 0 then
			local isLast = index == #route - 1
			local stop = walked + length - (if isLast then spec.spacing / 2 else 0)
			while nextAt <= stop and nextAt <= spec.maxLength do
				local t = (nextAt - walked) / length
				table.insert(chevrons, { x = a.x + dx * t, z = a.z + dz * t, dirX = dx / length, dirZ = dz / length })
				nextAt += spec.spacing
			end
		end
		walked += length
	end
	return chevrons
end

return Guide
