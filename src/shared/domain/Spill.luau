--!strict
-- Butin des chocs (A71), sans API Roblox : un joueur éjecté lâche une part de son sac, répartie en tas que tout
-- le monde peut ramasser, lui compris. C'est l'enjeu des chocs : sans rien à perdre, pas de rivalité.
local BumperConfig = require("../config/BumperConfig")
local Bag = require("./Bag")

export type Pile = { x: number, z: number, places: number, value: number }

local Spill = {}

local SPILL = BumperConfig.SPILL

-- Vrai si le sac contient assez pour que le choc fasse tomber quelque chose.
function Spill.isWorthIt(bag: Bag.Bag): boolean
	return bag.count >= SPILL.MIN_PLACES
end

-- Retire du sac la part lâchée au choc. Renvoie (places, valeur) ; (0, 0) si le sac est presque vide.
function Spill.take(bag: Bag.Bag): (number, number)
	if not Spill.isWorthIt(bag) then
		return 0, 0
	end
	local places = math.floor(bag.count * SPILL.SHARE)
	local value = bag.value * places / bag.count
	bag.count -= places
	bag.value -= value
	return places, value
end

-- Répartit le butin en tas, projetés en éventail dans le sens de l'éjection. `rng` : générateur dans [0, 1[.
-- Les places sont entières et leur somme est exactement `places` ; la valeur suit la même proportion.
function Spill.scatter(
	places: number,
	value: number,
	originX: number,
	originZ: number,
	dirX: number,
	dirZ: number,
	rng: () -> number
): { Pile }
	local count = math.min(SPILL.PILES, places)
	local piles: { Pile } = {}
	if count <= 0 then
		return piles
	end
	local heading = math.atan2(dirZ, dirX)
	local left = places
	for index = 1, count do
		local share = if index == count then left else math.floor(places / count)
		left -= share
		local angle = heading + math.rad(SPILL.SPREAD_DEGREES) * (rng() * 2 - 1)
		local distance = SPILL.MIN_DISTANCE + (SPILL.MAX_DISTANCE - SPILL.MIN_DISTANCE) * rng()
		table.insert(piles, {
			x = originX + math.cos(angle) * distance,
			z = originZ + math.sin(angle) * distance,
			places = share,
			value = value * share / places,
		})
	end
	return piles
end

-- Ramasse dans le sac ce qui y tient d'un tas. Le reste demeure dans le tas. Renvoie les places prises.
function Spill.pickUp(bag: Bag.Bag, pile: Pile): number
	local room = if bag.capacity == math.huge then pile.places else math.floor(bag.capacity - bag.count)
	local taken = math.clamp(room, 0, pile.places)
	if taken <= 0 then
		return 0
	end
	local value = pile.value * taken / pile.places
	bag.count += taken
	bag.value += value
	pile.places -= taken
	pile.value -= value
	return taken
end

return Spill
