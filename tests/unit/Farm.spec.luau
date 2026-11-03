--!strict
-- La grande ferme Lego (A56) : plan de construction révélé pièce par pièce, briques de la grange, étage et
-- disposition de la base. Un plan impossible à construire doit échouer ici, pas sous les yeux du joueur.
local TestKit = require("../TestKit")
local FarmConfig = require("../../src/shared/config/FarmConfig")
local MapConfig = require("../../src/shared/config/MapConfig")
local PetConfig = require("../../src/shared/config/PetConfig")
local PetVisualConfig = require("../../src/shared/config/PetVisualConfig")
local TycoonConfig = require("../../src/shared/config/TycoonConfig")
local FarmBlueprint = require("../../src/shared/domain/FarmBlueprint")
local Pets = require("../../src/shared/domain/Pets")
local Profile = require("../../src/shared/domain/Profile")
local Rebirth = require("../../src/shared/domain/Rebirth")
local Tycoon = require("../../src/shared/domain/Tycoon")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local LAYOUT = TycoonConfig.LAYOUT
local PLAN = TycoonConfig.DECORATIONS
local BARN = FarmConfig.BARN

-- Boutons que le joueur voit, à part le Rebirth (qui dépend de sa progression).
local function visibleButtons(state: Tycoon.State): { string }
	local visible: { string } = {}
	for id in LAYOUT.PADS do
		if id ~= TycoonConfig.REBIRTH_NAME and Tycoon.offer(state, id, 1).price ~= nil then
			table.insert(visible, id)
		end
	end
	return visible
end

local function ownAllMachines(state: Tycoon.State)
	for _, machine in TycoonConfig.MACHINES do
		state.machines[machine.id] = true
	end
end

local function buildPlanUpTo(state: Tycoon.State, id: string)
	for _, decor in PLAN do
		state.decor[decor.id] = true
		if decor.id == id then
			return
		end
	end
end

describe("Plan de construction", function()
	it("ne montre au départ que le strict nécessaire", function()
		local visible = visibleButtons(Tycoon.new())
		table.sort(visible)
		expect(table.concat(visible, ",")).toBe("Conveyor,Garage,Mill,Path")
	end)

	it("ne révèle qu'un élément de décor à la fois, dans l'ordre", function()
		local state = Tycoon.new()
		state.money = 1e12
		for index, decor in PLAN do
			local count = 0
			for _, candidate in PLAN do
				count += if Tycoon.offer(state, candidate.id, 1).price then 1 else 0
			end
			expect(count).toBe(1)
			expect(Tycoon.offer(state, decor.id, 1).price).toBe(decor.price)
			if PLAN[index + 1] then
				expect(Tycoon.buy(state, PLAN[index + 1].id, 1).isPurchased).toBe(false) -- pas de saut d'étape
			end
			expect(Tycoon.buy(state, decor.id, 1).isPurchased).toBe(true)
			expect(Tycoon.buy(state, decor.id, 1).isPurchased).toBe(false) -- une seule fois
		end
	end)

	it("garde peu de boutons à l'écran, même en fin de partie", function()
		local state = Tycoon.new()
		ownAllMachines(state)
		buildPlanUpTo(state, "Roof")
		expect(#visibleButtons(state) <= 6).toBe(true)
	end)

	it("va du moins cher au plus cher", function()
		for index = 2, #PLAN do
			expect(PLAN[index].price > PLAN[index - 1].price).toBe(true)
		end
	end)

	it("bâtit dans un ordre logique : murs, puis escalier, plancher, murs de l'étage et toit", function()
		local order: { [string]: number } = {}
		for index, decor in PLAN do
			order[decor.id] = index
		end
		for _, pair in
			{
				{ "BarnFloor", "WallBack" },
				{ "WallNorth", "Facade" },
				{ "Facade", "Doors" },
				{ "Facade", "Stairs" },
				{ "Stairs", "Loft" },
				{ "Loft", "UpperWalls" },
				{ "UpperWalls", "Roof" },
				{ "Roof", "Cupola" },
			}
		do
			expect(order[pair[1]] < order[pair[2]]).toBe(true)
		end
	end)

	it("donne à chaque élément un bouton, une icône et des briques", function()
		for _, decor in PLAN do
			expect(LAYOUT.PADS[decor.id] ~= nil).toBe(true)
			expect(TycoonConfig.PAD_STYLE.ICONS[decor.id] ~= nil).toBe(true)
			expect(#FarmBlueprint.pieces(decor.id) > 0).toBe(true)
		end
	end)

	it("ne pose jamais deux boutons consécutifs au même endroit (achat en cascade)", function()
		for index = 2, #PLAN do
			local a, b = LAYOUT.PADS[PLAN[index - 1].id], LAYOUT.PADS[PLAN[index].id]
			expect(a.x ~= b.x or a.z ~= b.z).toBe(true)
		end
	end)
end)

describe("Chaîne de l'étage", function()
	it("n'existe qu'une fois le toit posé et l'Usine achetée", function()
		local state = Tycoon.new()
		local dryer = "Dryer"
		expect(Tycoon.isUnlocked(state, dryer)).toBe(false)
		buildPlanUpTo(state, "Roof")
		expect(Tycoon.isUnlocked(state, dryer)).toBe(false)
		ownAllMachines(state)
		expect(Tycoon.isUnlocked(state, dryer)).toBe(true)
	end)

	it("se débloque machine après machine, et multiplie les revenus", function()
		local state = Tycoon.new()
		ownAllMachines(state)
		buildPlanUpTo(state, "Roof")
		state.money = 1e12
		local before = Tycoon.machineMultiplier(state)
		expect(Tycoon.buy(state, "Press", 1).isPurchased).toBe(false)
		expect(Tycoon.buy(state, "Dryer", 1).isPurchased).toBe(true)
		expect(Tycoon.machineMultiplier(state)).toBeCloseTo(before * 1.5)
		expect(Tycoon.buy(state, "Press", 1).isPurchased).toBe(true)
		expect(Tycoon.buy(state, "Packer", 1).isPurchased).toBe(true)
		expect(Tycoon.machineMultiplier(state)).toBeCloseTo(before * 1.5 * 2 * 3)
	end)

	it("n'est pas exigée pour le Rebirth, et repart de zéro comme les autres machines", function()
		local state = Tycoon.new()
		ownAllMachines(state)
		expect(Rebirth.isTycoonComplete(state)).toBe(true)
		buildPlanUpTo(state, "Roof")
		state.machines.Dryer = true
		local progress = Rebirth.newProgress()
		state.money = Rebirth.cost(progress)
		expect(Rebirth.apply(state, progress)).toBe(true)
		expect(state.machines.Dryer).toBe(nil)
		expect(state.decor.Roof).toBe(true) -- la ferme, elle, reste
	end)

	it("est sauvegardée", function()
		local data = Profile.sanitize({ machines = { "Mill", "Dryer" } })
		expect(table.find(data.machines, "Dryer") ~= nil).toBe(true)
	end)

	it("a ses boutons et ses machines à l'étage", function()
		for _, machine in TycoonConfig.UPPER_MACHINES do
			expect(LAYOUT.PADS[machine.id].level).toBe(1)
			expect(LAYOUT.MACHINES[machine.id].level).toBe(1)
		end
	end)

	it("distingue le rez-de-chaussée de l'étage", function()
		expect(Tycoon.levelAt(3)).toBe(0) -- personnage debout au sol
		expect(Tycoon.levelAt(LAYOUT.LOFT_TOP + 3)).toBe(1)
	end)
end)

describe("Grange", function()
	local function span(piece: FarmBlueprint.Piece, axis: number): (number, number)
		return piece.at[axis] - piece.size[axis] / 2, piece.at[axis] + piece.size[axis] / 2
	end

	local spec: FarmBlueprint.WallSpec = {
		axis = "z",
		fixed = 0,
		from = -32,
		to = 32,
		baseY = 0,
		courses = 8,
		openings = { { from = -10, to = 10, bottom = 0, top = 15 } },
		hasQuoins = true,
		stoneCourses = 1,
	}

	it("monte des murs sans brique dans les ouvertures", function()
		for _, brick in FarmBlueprint.wallPieces(spec) do
			local fromZ, toZ = span(brick, 3)
			local fromY, toY = span(brick, 2)
			local isInDoor = fromZ < 10 - 1e-6 and toZ > -10 + 1e-6 and fromY < 15 - 1e-6
			expect(isInDoor).toBe(false)
			expect(toY > fromY).toBe(true)
		end
	end)

	it("remplit chaque rangée sans trou ni chevauchement", function()
		local byCourse: { [number]: number } = {}
		for _, brick in FarmBlueprint.wallPieces(spec) do
			local y = math.floor(brick.at[2] * 10)
			byCourse[y] = (byCourse[y] or 0) + brick.size[3]
		end
		for y, length in byCourse do
			local isDoorCourse = y / 10 < 15
			expect(length).toBeCloseTo(if isDoorCourse then 44 else 64, 1e-6)
		end
	end)

	it("décale les briques d'une rangée à l'autre (quinconce)", function()
		local joints: { [number]: { [number]: boolean } } = {}
		for _, brick in FarmBlueprint.wallPieces(spec) do
			local course = math.floor(brick.at[2] / BARN.COURSE)
			joints[course] = joints[course] or {}
			joints[course][brick.at[3] + brick.size[3] / 2] = true
		end
		local shared = 0
		for joint in joints[5] do
			shared += if joints[6][joint] then 1 else 0
		end
		expect(shared <= 1).toBe(true)
	end)

	it("laisse passer le tapis roulant dans le mur sud", function()
		local conveyor = LAYOUT.CONVEYOR
		local hole = BARN.BELT_HOLE
		expect(conveyor.fromZ < -BARN.HALF_Z).toBe(true)
		expect(conveyor.x - conveyor.width / 2 >= hole.fromX).toBe(true)
		expect(conveyor.x + conveyor.width / 2 <= hole.toX).toBe(true)
		for _, brick in FarmBlueprint.pieces("WallSouth") do
			local fromX, toX = span(brick, 1)
			local fromY = span(brick, 2)
			local isInHole = fromX < hole.toX - 1e-6 and toX > hole.fromX + 1e-6 and fromY < conveyor.height
			expect(isInHole).toBe(false)
		end
	end)

	it("a un escalier qui arrive pile au plancher de l'étage", function()
		local steps = {}
		for _, piece in FarmBlueprint.pieces("Stairs") do
			if piece.isSolid then
				table.insert(steps, piece)
			end
		end
		expect(#steps).toBe(BARN.STAIRS.steps)
		local _, top = span(steps[#steps], 2)
		expect(top).toBe(LAYOUT.LOFT_TOP)
		for index = 2, #steps do
			expect(steps[index].size[2] - steps[index - 1].size[2] <= 1).toBe(true) -- marche franchissable
		end
	end)

	it("relie l'étage au haut de l'escalier, sans trou", function()
		local stairs = BARN.STAIRS
		local stairEnd = stairs.startX - stairs.steps * stairs.run
		local reachesStair = false
		for _, piece in FarmBlueprint.pieces("Loft") do
			local fromX, toX = span(piece, 1)
			local fromZ, toZ = span(piece, 3)
			if piece.isSolid and fromZ <= stairs.maxZ and toZ >= stairs.minZ and fromX < stairEnd then
				reachesStair = reachesStair or math.abs(toX - stairEnd) < 1e-6
			end
		end
		expect(reachesStair).toBe(true)
	end)

	it("laisse assez de hauteur sous l'étage pour les machines", function()
		expect(LAYOUT.LOFT_TOP - BARN.LOFT_THICKNESS >= 19).toBe(true)
	end)

	it("a un toit qui couvre tout le bâtiment, avec un faîtage plus haut que l'avant-toit", function()
		local eaves = (BARN.GROUND_COURSES + BARN.UPPER_COURSES) * BARN.COURSE
		expect(FarmBlueprint.ridgeHeight() > eaves + 10).toBe(true)
		local widest = 0
		for _, piece in FarmBlueprint.pieces("Roof") do
			local _, toZ = span(piece, 3)
			widest = math.max(widest, toZ)
		end
		expect(widest >= BARN.HALF_Z).toBe(true)
	end)
end)

-- Rectangle au sol (coordonnées locales de la base) : centre et dimensions.
type Box = { name: string, x: number, z: number, sizeX: number, sizeZ: number }

local function box(name: string, center: { number }, sizeX: number, sizeZ: number): Box
	return { name = name, x = center[1], z = center[2], sizeX = sizeX, sizeZ = sizeZ }
end

local function padBox(id: string): Box
	local spot = LAYOUT.PADS[id]
	return box(`bouton {id}`, { spot.x, spot.z }, LAYOUT.PAD_SIZE, LAYOUT.PAD_SIZE)
end

-- Ce qui reste en place au rez-de-chaussée, quel que soit l'avancement du plan.
local function fixtures(): { Box }
	local boxes: { Box } = {}
	for _, id in { "Conveyor", "Garage", "Rebirth", "SiloUpgrade", "Mill", "Oven", "Factory" } do
		table.insert(boxes, padBox(id))
	end
	for _, machine in TycoonConfig.MACHINES do
		local spot = LAYOUT.MACHINES[machine.id]
		local depth = if machine.id == "Factory" then LAYOUT.MACHINE_SIZE * 1.3 else LAYOUT.MACHINE_SIZE
		table.insert(boxes, box(`machine {machine.id}`, { spot.x, spot.z }, LAYOUT.MACHINE_SIZE, depth))
	end
	local silo = LAYOUT.SILO
	table.insert(boxes, box("silo", { silo.x, silo.z }, silo.radius * 2, silo.radius * 2))
	local conveyor = LAYOUT.CONVEYOR
	local middle = (conveyor.fromZ + conveyor.toZ) / 2
	table.insert(boxes, box("tapis", { conveyor.x, middle }, conveyor.width, conveyor.toZ - conveyor.fromZ))
	local unload = LAYOUT.UNLOAD_PAD
	table.insert(boxes, box("déchargement", { unload.x, unload.z }, unload.size, unload.size))
	local eggBase = PetVisualConfig.DISPENSER.BASE_SIZE
	for id, spot in PetConfig.DISPENSERS do
		table.insert(
			boxes,
			box(`distributeur {id}`, { spot.x, spot.z }, PetConfig.DISPENSER_SIZE, PetConfig.DISPENSER_SIZE)
		)
		table.insert(boxes, box(`œuf {id}`, { spot.x + PetConfig.EGG_OFFSET_X, spot.z }, eggBase[1], eggBase[3]))
	end
	table.insert(boxes, box("apparition", { LAYOUT.SPAWN.x, LAYOUT.SPAWN.z }, 6, 6))
	return boxes
end

local function overlaps(a: Box, b: Box): boolean
	return math.abs(a.x - b.x) < (a.sizeX + b.sizeX) / 2 - 1e-6 and math.abs(a.z - b.z) < (a.sizeZ + b.sizeZ) / 2 - 1e-6
end

-- Briques qui gênent au sol : ni à plat (chemin, plancher), ni au-dessus de la tête.
local function groundPieces(id: string): { Box }
	local boxes: { Box } = {}
	for _, piece in FarmBlueprint.pieces(id) do
		local bottom = piece.at[2] - piece.size[2] / 2
		if piece.size[2] > 0.4 and bottom < 3 and not piece.tilt then
			table.insert(boxes, box(`{id}/{piece.name}`, { piece.at[1], piece.at[3] }, piece.size[1], piece.size[3]))
		end
	end
	return boxes
end

describe("Plan de la base", function()
	it("ne superpose aucun élément permanent", function()
		local boxes = fixtures()
		for i = 1, #boxes do
			for j = i + 1, #boxes do
				if overlaps(boxes[i], boxes[j]) then
					error(`{boxes[i].name} chevauche {boxes[j].name}`)
				end
			end
		end
	end)

	it("construit la ferme sans recouvrir un bouton, une machine ou un distributeur", function()
		for _, decor in PLAN do
			for _, piece in groundPieces(decor.id) do
				for _, fixture in fixtures() do
					if overlaps(piece, fixture) then
						error(`{piece.name} recouvre {fixture.name}`)
					end
				end
			end
		end
	end)

	it("pose chaque bouton du plan sur un emplacement libre", function()
		local built: { Box } = fixtures()
		for _, decor in PLAN do
			local pad = padBox(decor.id)
			for _, other in built do
				if overlaps(pad, other) then
					error(`{pad.name} recouvre {other.name}`)
				end
			end
			for _, piece in groundPieces(decor.id) do
				table.insert(built, piece) -- les boutons suivants devront éviter cette pièce
			end
		end
	end)

	it("garde les boutons de l'étage sur le plancher, loin du vide", function()
		local half = LAYOUT.PAD_SIZE / 2
		for _, machine in TycoonConfig.UPPER_MACHINES do
			local spot = LAYOUT.PADS[machine.id]
			expect(spot.x + half <= BARN.LOFT_FRONT_X).toBe(true)
			expect(spot.z + half <= BARN.STAIRS.minZ).toBe(true)
			expect(math.abs(spot.z) + half <= BARN.HALF_Z - BARN.WALL).toBe(true)
		end
	end)

	it("garde toute la ferme dans l'emprise de la base", function()
		local half = MapConfig.BASE_SIZE / 2
		for _, decor in PLAN do
			for _, piece in FarmBlueprint.pieces(decor.id) do
				if not piece.tilt then
					expect(math.abs(piece.at[1]) + piece.size[1] / 2 <= half).toBe(true)
					expect(math.abs(piece.at[3]) + piece.size[3] / 2 <= half).toBe(true)
				end
			end
		end
	end)
end)

describe("Distributeurs d'œufs", function()
	it("n'apparaissent qu'avec la progression", function()
		expect(Pets.isEggVisible("BasicEgg", 1, 0)).toBe(true)
		expect(Pets.isEggVisible("FarmEgg", 2, 0)).toBe(false)
		expect(Pets.isEggVisible("FarmEgg", 3, 0)).toBe(true)
		expect(Pets.isEggVisible("RebirthEgg", 7, 0)).toBe(false)
		expect(Pets.isEggVisible("RebirthEgg", 1, 1)).toBe(true)
	end)
end)
