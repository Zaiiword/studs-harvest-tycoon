--!strict
-- Nouvelles options de l'usine (A53) : silo agrandissable, décorations, plan de la base et flèches de guidage.
local TestKit = require("../TestKit")
local MapConfig = require("../../src/shared/config/MapConfig")
local PetConfig = require("../../src/shared/config/PetConfig")
local PetVisualConfig = require("../../src/shared/config/PetVisualConfig")
local TycoonConfig = require("../../src/shared/config/TycoonConfig")
local Guide = require("../../src/shared/domain/Guide")
local Profile = require("../../src/shared/domain/Profile")
local Rebirth = require("../../src/shared/domain/Rebirth")
local Tycoon = require("../../src/shared/domain/Tycoon")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local SILO = TycoonConfig.SILO_UPGRADE
local LAYOUT = TycoonConfig.LAYOUT

describe("Silo Géant", function()
	it("double la capacité à chaque niveau acheté", function()
		local state = Tycoon.new()
		state.money = 1e9
		expect(Tycoon.siloCapacity(state)).toBe(TycoonConfig.SILO_CAPACITY)
		expect(Tycoon.offer(state, SILO.ID, 1).price).toBe(SILO.PRICES[1])
		expect(Tycoon.buy(state, SILO.ID, 1).isPurchased).toBe(true)
		expect(Tycoon.siloCapacity(state)).toBe(TycoonConfig.SILO_CAPACITY * 2)
		expect(Tycoon.offer(state, SILO.ID, 1).price).toBe(SILO.PRICES[2])
	end)

	it("laisse le silo accepter plus de blé une fois agrandi", function()
		local state = Tycoon.new()
		state.silo = TycoonConfig.SILO_CAPACITY
		expect(Tycoon.deposit(state, 100)).toBe(0)
		state.siloLevel = 1
		expect(Tycoon.deposit(state, 100)).toBe(100)
	end)

	it("ne vend plus rien au niveau maximal", function()
		local state = Tycoon.new()
		state.siloLevel = #SILO.PRICES
		state.money = 1e12
		expect(Tycoon.offer(state, SILO.ID, 1).price).toBe(nil)
		expect(Tycoon.buy(state, SILO.ID, 1).isPurchased).toBe(false)
	end)
end)

describe("Décorations", function()
	it("s'achètent une seule fois", function()
		local state = Tycoon.new()
		local fountain = TycoonConfig.DECORATIONS[3]
		state.money = fountain.price
		expect(Tycoon.buy(state, fountain.id, 1).isPurchased).toBe(true)
		expect(state.decor[fountain.id]).toBe(true)
		expect(state.money).toBe(0)
		state.money = 1e9
		expect(Tycoon.buy(state, fountain.id, 1).isPurchased).toBe(false)
	end)

	it("refusent un achat sans les moyens", function()
		local state = Tycoon.new()
		expect(Tycoon.buy(state, "Lamps", 1).isPurchased).toBe(false)
		expect(state.decor.Lamps).toBe(nil)
	end)

	it("vont du moins cher au plus cher (l'ordre des boutons suit la progression)", function()
		for index = 2, #TycoonConfig.DECORATIONS do
			expect(TycoonConfig.DECORATIONS[index].price > TycoonConfig.DECORATIONS[index - 1].price).toBe(true)
		end
	end)

	it("ont chacune leur bouton au sol", function()
		for _, decor in TycoonConfig.DECORATIONS do
			expect(LAYOUT.PADS[decor.id] ~= nil).toBe(true)
		end
		expect(LAYOUT.PADS[SILO.ID] ~= nil).toBe(true)
	end)
end)

describe("Rebirth et nouvelles options", function()
	it("garde le silo agrandi et les décorations (A53)", function()
		local state = Tycoon.new()
		for _, machine in TycoonConfig.MACHINES do
			state.machines[machine.id] = true
		end
		state.siloLevel, state.decor.Fountain = 2, true
		local progress = Rebirth.newProgress()
		state.money = Rebirth.cost(progress)
		expect(Rebirth.apply(state, progress)).toBe(true)
		expect(state.siloLevel).toBe(2)
		expect(state.decor.Fountain).toBe(true)
		expect(next(state.machines)).toBe(nil)
	end)
end)

describe("Profil v6", function()
	it("sauvegarde et restaure le silo et les décorations", function()
		local state = Tycoon.new()
		state.siloLevel, state.decor.Flag, state.decor.Lamps = 3, true, true
		state.silo = Tycoon.siloCapacityAt(3) -- plus que l'ancien plafond : ne doit pas être tronqué
		local data = Profile.fromGame({
			tycoon = state,
			tier = 1,
			progress = Rebirth.newProgress(),
			items = {},
			pets = { owned = {}, equipped = {} },
			retention = nil :: any,
			purchases = nil :: any,
		})
		expect(data.version).toBe(6)
		local restored = Profile.toTycoon(Profile.sanitize(data))
		expect(restored.siloLevel).toBe(3)
		expect(restored.decor.Flag).toBe(true)
		expect(restored.decor.Lamps).toBe(true)
		expect(restored.silo).toBe(Tycoon.siloCapacityAt(3))
	end)

	it("migre un profil v5 (sans silo agrandi ni décoration)", function()
		local data = Profile.sanitize({ version = 5, money = 10, machines = { "Mill" } })
		expect(data.siloLevel).toBe(0)
		expect(#data.decor).toBe(0)
	end)

	it("nettoie des décorations inconnues ou en double et un niveau de silo hors bornes", function()
		local data = Profile.sanitize({ decor = { "Fountain", "Fountain", "Piscine", 42 }, siloLevel = 99 })
		expect(#data.decor).toBe(1)
		expect(data.siloLevel).toBe(#SILO.PRICES)
	end)
end)

-- Rectangle au sol (coordonnées locales de la base) : centre et dimensions.
type Box = { name: string, x: number, z: number, sizeX: number, sizeZ: number }

local function footprints(): { Box }
	local boxes: { Box } = {}
	local function add(name: string, x: number, z: number, sizeX: number, sizeZ: number)
		table.insert(boxes, { name = name, x = x, z = z, sizeX = sizeX, sizeZ = sizeZ })
	end
	for id, spot in LAYOUT.PADS do
		add(`bouton {id}`, spot.x, spot.z, LAYOUT.PAD_SIZE, LAYOUT.PAD_SIZE)
	end
	for id, spot in LAYOUT.MACHINES do
		local depth = if id == "Factory" then LAYOUT.MACHINE_SIZE * 1.3 else LAYOUT.MACHINE_SIZE
		add(`machine {id}`, spot.x, spot.z, LAYOUT.MACHINE_SIZE, depth)
	end
	local silo = LAYOUT.SILO
	add("silo", silo.x, silo.z, silo.radius * 2, silo.radius * 2)
	local conveyor = LAYOUT.CONVEYOR
	add("tapis", conveyor.x, (conveyor.fromZ + conveyor.toZ) / 2, conveyor.width, conveyor.toZ - conveyor.fromZ)
	local unload = LAYOUT.UNLOAD_PAD
	add("déchargement", unload.x, unload.z, unload.size, unload.size)
	local eggBase = PetVisualConfig.DISPENSER.BASE_SIZE
	for id, spot in PetConfig.DISPENSERS do
		add(`distributeur {id}`, spot.x, spot.z, PetConfig.DISPENSER_SIZE, PetConfig.DISPENSER_SIZE)
		add(`œuf {id}`, spot.x + PetConfig.EGG_OFFSET_X, spot.z, eggBase[1], eggBase[3])
	end
	add("apparition", LAYOUT.SPAWN.x, LAYOUT.SPAWN.z, 2, 2)
	for _, decor in TycoonConfig.DECORATIONS do
		for k, spot in decor.spots do
			add(`{decor.id} {k}`, spot.x, spot.z, decor.footprint[1], decor.footprint[2])
		end
	end
	for _, sign in LAYOUT.SIGNS do
		add(`panneau {sign.text}`, sign.x, sign.z, LAYOUT.SIGN.footprint[1], LAYOUT.SIGN.footprint[2])
	end
	return boxes
end

local function overlaps(a: Box, b: Box): boolean
	return math.abs(a.x - b.x) < (a.sizeX + b.sizeX) / 2 and math.abs(a.z - b.z) < (a.sizeZ + b.sizeZ) / 2
end

describe("Plan de la base", function()
	it("ne superpose aucun bouton, machine, distributeur ou décoration", function()
		local boxes = footprints()
		for i = 1, #boxes do
			for j = i + 1, #boxes do
				if overlaps(boxes[i], boxes[j]) then
					error(`{boxes[i].name} chevauche {boxes[j].name}`)
				end
			end
		end
	end)

	it("ne superpose pas deux dalles de même hauteur (elles scintilleraient)", function()
		for _, group in { LAYOUT.ZONES, LAYOUT.AVENUES } do
			for i = 1, #group do
				for j = i + 1, #group do
					local a, b = group[i], group[j]
					local isApart = a.maxX <= b.minX or b.maxX <= a.minX or a.maxZ <= b.minZ or b.maxZ <= a.minZ
					expect(isApart).toBe(true)
				end
			end
		end
		expect(LAYOUT.AVENUE_THICKNESS > LAYOUT.ZONE_THICKNESS).toBe(true)
	end)

	it("garde tout à l'intérieur de la base", function()
		local half = MapConfig.BASE_SIZE / 2
		for _, box in footprints() do
			expect(math.abs(box.x) + box.sizeX / 2 <= half).toBe(true)
			expect(math.abs(box.z) + box.sizeZ / 2 <= half).toBe(true)
		end
	end)
end)

describe("Guide", function()
	local buttons = {
		{ id = "Mill", price = 250, x = 0, z = -20 },
		{ id = "Conveyor", price = 68, x = 0, z = -40 },
		{ id = "Oven", price = 20_000, x = 0, z = 0 },
	}

	it("montre le bouton abordable le moins cher", function()
		local target =
			Guide.target({ money = 300, isBagFull = false, unload = nil, buttons = buttons, seen = {} }) :: Guide.Target
		expect(target.kind).toBe("button")
		expect(target.id).toBe("Conveyor")
	end)

	it("ne montre rien quand aucun bouton n'est abordable", function()
		expect(Guide.target({ money = 10, isBagFull = false, unload = nil, buttons = buttons, seen = {} })).toBe(nil)
	end)

	it("emmène d'abord décharger quand le sac est plein", function()
		local unload = { x = 1, z = 2 }
		local target =
			Guide.target({ money = 1e6, isBagFull = true, unload = unload, buttons = buttons, seen = {} }) :: Guide.Target
		expect(target.kind).toBe("unload")
		expect(target.point).toBe(unload)
	end)

	it("aligne des chevrons régulièrement espacés, tournés vers la cible", function()
		local spec = { spacing = 4, start = 4, maxLength = 70, phase = 0 }
		local chevrons = Guide.chevrons({ { x = 0, z = 0 }, { x = 0, z = 30 } }, spec)
		expect(#chevrons).toBe(7) -- 4, 8, …, 28 : le dernier s'arrête avant la cible
		expect(chevrons[1].z).toBeCloseTo(4)
		expect(chevrons[2].z - chevrons[1].z).toBeCloseTo(4)
		expect(chevrons[1].dirZ).toBeCloseTo(1)
	end)

	it("ne dessine que le début d'un long trajet", function()
		local spec = { spacing = 4, start = 4, maxLength = 20, phase = 0 }
		local chevrons = Guide.chevrons({ { x = 0, z = 0 }, { x = 500, z = 0 } }, spec)
		expect(#chevrons).toBe(5)
		expect(chevrons[#chevrons].x <= 20).toBe(true)
	end)
end)

describe("Guidage une seule fois par objet", function()
	local buttons = {
		{ id = "Conveyor", price = 68, x = 0, z = -40 },
		{ id = "Mill", price = 250, x = 0, z = -20 },
	}

	it("passe au bouton suivant une fois le tapis déjà acheté", function()
		local seen = { Conveyor = true }
		local target = Guide.target({ money = 300, isBagFull = false, unload = nil, buttons = buttons, seen = seen })
		expect((target :: Guide.Target).id).toBe("Mill")
	end)

	it("ne ramène plus à la grille de déchargement après le premier déchargement", function()
		local unload = { x = 1, z = 2 }
		local seen = { [Guide.UNLOAD] = true, Conveyor = true, Mill = true }
		expect(Guide.target({ money = 1e6, isBagFull = true, unload = unload, buttons = buttons, seen = seen })).toBe(
			nil
		)
	end)

	it("retient chaque bouton acheté, et le garde au Rebirth et dans la sauvegarde", function()
		local state = Tycoon.new()
		state.money = 1e6
		Tycoon.buy(state, "Conveyor", 1)
		expect(state.guided.Conveyor).toBe(true)
		expect(state.guided.Mill).toBe(nil)
		local data = Profile.sanitize({ guided = { "Conveyor", "Unload", "Inconnu" } })
		expect(#data.guided).toBe(2)
		expect(Profile.toTycoon(data).guided.Unload).toBe(true)
	end)
end)
