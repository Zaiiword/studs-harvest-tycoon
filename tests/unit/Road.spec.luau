--!strict
-- Boulevard vers le champ et engin réservé au champ (A54).
local TestKit = require("../TestKit")
local DecorConfig = require("../../src/shared/config/DecorConfig")
local MapConfig = require("../../src/shared/config/MapConfig")
local RetentionConfig = require("../../src/shared/config/RetentionConfig")
local VehicleConfig = require("../../src/shared/config/VehicleConfig")
local Decor = require("../../src/shared/domain/Decor")
local Guide = require("../../src/shared/domain/Guide")
local MapGeometry = require("../../src/shared/domain/MapGeometry")
local Movement = require("../../src/shared/domain/Movement")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local ROAD = MapConfig.ROAD
local ROAD_X = (ROAD.minX + ROAD.maxX) / 2
local TIERS = VehicleConfig.TIERS

describe("Attribution des bases", function()
	it("donne d'abord les bases les plus proches du champ", function()
		local order = MapGeometry.baseClaimOrder()
		local bases = MapGeometry.baseCenters()
		expect(#order).toBe(MapConfig.BASE_COUNT)
		for index = 2, #order do
			expect(math.abs(bases[order[index]].z) >= math.abs(bases[order[index - 1]].z)).toBe(true)
		end
		expect(math.abs(bases[order[1]].z)).toBe(MapConfig.BASE_PITCH / 2)
	end)

	it("place un pont en face de chacune des 4 bases centrales", function()
		local order, bases = MapGeometry.baseClaimOrder(), MapGeometry.baseCenters()
		for index = 1, #MapConfig.BRIDGE_Z do
			expect(table.find(MapConfig.BRIDGE_Z, bases[order[index]].z) ~= nil).toBe(true)
		end
	end)
end)

describe("Boulevard", function()
	it("longe toutes les bases, sans empiéter sur elles ni sur le fossé", function()
		for _, base in MapGeometry.baseCenters() do
			expect(base.x + MapConfig.BASE_SIZE / 2 <= ROAD.minX).toBe(true)
			expect(math.abs(base.z) + MapConfig.BASE_SIZE / 2 <= ROAD.halfLength).toBe(true)
		end
		expect(ROAD.maxX <= MapConfig.MOAT.minX).toBe(true)
		expect(ROAD.halfLength <= MapConfig.PLAZA.halfWidth).toBe(true)
	end)

	it("laisse les statues et les arbres sur le côté", function()
		for _, statue in RetentionConfig.STATUES do
			expect(statue.x > ROAD.maxX).toBe(true)
		end
		for _, tree in Decor.treeSpots() do
			expect(tree.x > ROAD.maxX or tree.x < ROAD.minX).toBe(true)
		end
	end)

	it("reconnaît la route, son raccord et les ponts, pas le reste", function()
		expect(MapGeometry.isOnRoad(ROAD_X, 500)).toBe(true)
		expect(MapGeometry.isOnRoad(-15, MapConfig.BRIDGE_Z[1])).toBe(true)
		expect(MapGeometry.isOnRoad(12, MapConfig.BRIDGE_Z[2])).toBe(true)
		expect(MapGeometry.isOnRoad(-15, 0)).toBe(false) -- à côté d'un pont
		expect(MapGeometry.isOnRoad(MapConfig.BASE_CENTER_X, 72.5)).toBe(false) -- dans une base
		expect(MapGeometry.isOnRoad(300, MapConfig.BRIDGE_Z[1])).toBe(false) -- dans le champ
	end)

	it("ne pose aucune bordure devant une porte de base ou un pont", function()
		local curb = DecorConfig.ROAD.CURB
		for _, spot in Decor.roadCurbs() do
			local openings: { number } = {}
			local halfOpening = MapConfig.BRIDGE_WIDTH / 2
			if spot.x < ROAD_X then
				halfOpening = DecorConfig.FENCE.GATE_WIDTH / 2
				for _, base in MapGeometry.baseCenters() do
					table.insert(openings, base.z)
				end
			else
				openings = table.clone(MapConfig.BRIDGE_Z) :: any
			end
			for _, center in openings do
				expect(math.abs(spot.z - center) >= halfOpening + curb.length / 2).toBe(true)
			end
		end
		expect(#Decor.roadCurbs() > 0).toBe(true)
	end)

	it("tient ses drapeaux à distance des ponts, statues et arbres", function()
		local flag = DecorConfig.ROAD.FLAG
		local flags = Decor.roadFlags()
		expect(#flags > 0).toBe(true)
		for _, spot in flags do
			for _, bridgeZ in MapConfig.BRIDGE_Z do
				expect(math.abs(spot.z - bridgeZ) >= flag.clearance).toBe(true)
			end
			for _, tree in Decor.treeSpots() do
				expect(math.sqrt((tree.x - spot.x) ^ 2 + (tree.z - spot.z) ^ 2) >= flag.clearance).toBe(true)
			end
		end
	end)
end)

describe("Vitesse à pied", function()
	it("court ×3 sur le boulevard", function()
		expect(Movement.walkSpeed(TIERS[1], false, true)).toBe(TIERS[1].speed * ROAD.SPEED_MULTIPLIER)
	end)
	it("garde la vitesse de l'outil aux Tiers 1 et 2", function()
		expect(Movement.walkSpeed(TIERS[2], false, false)).toBe(TIERS[2].speed)
	end)
	it("marche à une vitesse normale quand l'engin est garé", function()
		expect(Movement.walkSpeed(TIERS[7], false, false)).toBe(VehicleConfig.FOOT_SPEED)
	end)
	it("applique la pénalité du sac plein (CDC §4)", function()
		local expected = TIERS[1].speed * (1 - VehicleConfig.FULL_SPEED_PENALTY)
		expect(Movement.walkSpeed(TIERS[1], true, false)).toBeCloseTo(expected)
	end)
end)

describe("Engin réservé au champ", function()
	local fieldX = MapConfig.STEM.minX + 1

	it("n'apparaît ni dans la base, ni sur le boulevard, ni sur le pont à l'aller", function()
		expect(Movement.shouldRide(MapConfig.BASE_CENTER_X, 72.5, false)).toBe(false)
		expect(Movement.shouldRide(ROAD_X, 72.5, false)).toBe(false)
		expect(Movement.shouldRide(12, 72.5, false)).toBe(false)
	end)
	it("apparaît en entrant dans le champ", function()
		expect(Movement.shouldRide(fieldX, 72.5, false)).toBe(true)
	end)
	it("reste sur le pont au retour (zone d'embuscade), puis disparaît sur la barre", function()
		expect(Movement.shouldRide(12, 72.5, true)).toBe(true)
		expect(Movement.shouldRide(ROAD_X, 72.5, true)).toBe(false)
	end)
end)

describe("Trajet des flèches", function()
	local bases = MapGeometry.baseCenters()
	local base = bases[5]
	local door = base.x + MapConfig.BASE_SIZE / 2

	it("sort du champ par le pont, puis entre par la porte de la base", function()
		local route = Guide.route({ x = 300, z = 80 }, { x = base.x + 30, z = base.z + 20 })
		expect(#route).toBe(5)
		expect(route[2].z).toBe(72.5)
		expect(route[2].x > MapConfig.MOAT.maxX).toBe(true)
		expect(route[3].x < MapConfig.MOAT.minX).toBe(true)
		expect(route[4].x).toBe(door)
		expect(route[4].z).toBe(base.z)
	end)
	it("va tout droit à l'intérieur d'une même base", function()
		expect(#Guide.route({ x = base.x + 20, z = base.z }, { x = base.x + 30, z = base.z + 10 })).toBe(2)
	end)
	it("rejoint la porte depuis le boulevard, sans traverser la clôture", function()
		local route = Guide.route({ x = ROAD_X, z = 300 }, { x = base.x + 30, z = base.z })
		expect(#route).toBe(3)
		expect(route[2].x).toBe(door)
	end)
	it("passe la porte de la grange pour rejoindre un bouton à l'intérieur", function()
		local route = Guide.route({ x = base.x + 30, z = base.z }, { x = base.x - 16, z = base.z - 2 })
		expect(#route).toBe(3)
		expect(route[2].x).toBe(base.x + 2)
		expect(route[2].z).toBe(base.z)
	end)
	it("monte par l'escalier pour rejoindre un bouton de l'étage, et en redescend", function()
		local yard = { x = base.x + 30, z = base.z }
		local upper = { x = base.x - 29, z = base.z - 2, level = 1 }
		local route = Guide.route(yard, upper)
		expect(#route).toBe(5) -- cour, porte, bas de l'escalier, haut de l'escalier, bouton
		expect(route[3].z).toBe(base.z + 27.5)
		expect(route[4].x < route[3].x).toBe(true)
		local back = Guide.route({ x = upper.x, z = upper.z, level = 1 }, yard)
		expect(#back).toBe(5)
		expect(back[2].x < back[3].x).toBe(true) -- on redescend vers l'avant de la grange
	end)
end)
