--!strict
-- Conduite arcade (VehicleMotion) et bousculade (Bumper).
local TestKit = require("../TestKit")
local BumperConfig = require("../../src/shared/config/BumperConfig")
local VehicleConfig = require("../../src/shared/config/VehicleConfig")
local VehicleMotion = require("../../src/shared/domain/VehicleMotion")
local Bumper = require("../../src/shared/domain/Bumper")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local HANDLING = VehicleConfig.HANDLING
local PARAMS: VehicleMotion.MotionParams = {
	maxSpeed = 30,
	turnRate = HANDLING.TURN_RATE,
	grip = HANDLING.GRIP,
	lateralGrip = HANDLING.LATERAL_GRIP,
	deadzone = HANDLING.INPUT_DEADZONE,
}
local DT = 1 / 60

local function drive(state: VehicleMotion.MotionState, dirX: number, dirZ: number, seconds: number)
	for _ = 1, math.floor(seconds / DT) do
		state = VehicleMotion.step(state, { dirX = dirX, dirZ = dirZ }, PARAMS, DT)
	end
	return state
end

local function speed(state: VehicleMotion.MotionState): number
	return math.sqrt(state.vx * state.vx + state.vz * state.vz)
end

describe("VehicleMotion", function()
	local still = { heading = 0, vx = 0, vz = 0 }

	it("accélère vers la vitesse du palier sans la dépasser", function()
		local state = drive(still, 1, 0, 3)
		expect(state.vx).toBeCloseTo(PARAMS.maxSpeed, 0.5)
		expect(speed(drive(still, 1, 0, 10)) <= PARAMS.maxSpeed + 1e-6).toBe(true)
	end)
	it("ralentit seul quand on lâche les commandes", function()
		local cruising = drive(still, 1, 0, 3)
		expect(speed(drive(cruising, 0, 0, 2)) < 1).toBe(true)
	end)
	it("tourne progressivement (pas de demi-tour instantané)", function()
		local cruising = drive(still, 1, 0, 3)
		local after = VehicleMotion.step(cruising, { dirX = -1, dirZ = 0 }, PARAMS, DT)
		expect(math.abs(after.heading) <= PARAMS.turnRate * DT + 1e-9).toBe(true)
	end)
	it("finit par s'aligner sur la direction voulue", function()
		local state = drive(still, 0, 1, 2)
		expect(state.heading).toBeCloseTo(math.pi / 2, 1e-3)
	end)
	it("dérape : la vitesse latérale persiste un instant après un virage serré", function()
		local cruising = drive(still, 1, 0, 3)
		local turned = drive(cruising, 0, 1, 0.5)
		local lateral = -turned.vx * math.sin(turned.heading) + turned.vz * math.cos(turned.heading)
		expect(math.abs(lateral) > 1).toBe(true)
	end)
	it("calcule l'écart angulaire le plus court", function()
		expect(VehicleMotion.angleDelta(0.1, 2 * math.pi - 0.1)).toBeCloseTo(-0.2)
	end)
end)

local function body(overrides: { [string]: any }): Bumper.Body
	local base: { [string]: any } = {
		id = 1,
		x = 0,
		z = 0,
		vx = 0,
		vz = 0,
		radius = 4,
		mass = 80,
		isVehicle = true,
		isProtected = false,
	}
	for key, value in overrides do
		base[key] = value
	end
	return base :: any
end

describe("Bumper", function()
	it("détecte l'attaquant : celui qui fonce vers l'autre", function()
		local tractor = body({ id = 1, x = 0, vx = 30 })
		local victim = body({ id = 2, x = 7 })
		local collision = Bumper.detect(tractor, victim) :: Bumper.Collision
		expect(collision.attackerId).toBe(1)
		expect(collision.targetId).toBe(2)
		expect(collision.dirX).toBeCloseTo(1)
		expect(collision.impactSpeed).toBeCloseTo(30)
	end)
	it("donne le même résultat quel que soit l'ordre des corps", function()
		local tractor = body({ id = 1, x = 0, vx = 30 })
		local victim = body({ id = 2, x = 7 })
		expect((Bumper.detect(victim, tractor) :: Bumper.Collision).attackerId).toBe(1)
	end)
	it("ignore deux corps trop éloignés", function()
		expect(Bumper.detect(body({ id = 1, vx = 30 }), body({ id = 2, x = 50 }))).toBe(nil)
	end)
	it("ignore un frôlement trop lent", function()
		local slow = BumperConfig.MIN_IMPACT_SPEED - 1
		expect(Bumper.detect(body({ id = 1, vx = slow }), body({ id = 2, x = 7 }))).toBe(nil)
	end)
	it("n'éjecte pas une cible protégée (immunité de 15 s, CDC §6)", function()
		expect(Bumper.detect(body({ id = 1, vx = 30 }), body({ id = 2, x = 7, isProtected = true }))).toBe(nil)
	end)
	it("ne laisse pas un joueur à pied éjecter un véhicule (A29)", function()
		local walker = body({ id = 1, vx = 16, isVehicle = false, radius = 1.5 })
		expect(Bumper.detect(walker, body({ id = 2, x = 5 }))).toBe(nil)
	end)
	it("ne bouscule pas dans la zone sécurisée débutant ni sur la barre des bases (A29)", function()
		expect(Bumper.isSafeZone("GreenWheat")).toBe(true)
		expect(Bumper.isSafeZone("Plaza")).toBe(true)
		expect(Bumper.isSafeZone("GoldenCorn")).toBe(false)
		expect(Bumper.isSafeZone("Moat")).toBe(false) -- les ponts sont des zones d'embuscade (CDC §3)
	end)

	describe("launchSpeeds", function()
		it("éjecte plus loin une cible plus légère (ratio de masse, CDC §5)", function()
			local light = Bumper.launchSpeeds(30, 80, 35)
			local heavy = Bumper.launchSpeeds(30, 80, 220)
			expect(light > heavy).toBe(true)
		end)
		it("reste dans les bornes (A30)", function()
			expect(Bumper.launchSpeeds(46, 350, 10)).toBe(BumperConfig.MAX_LAUNCH_SPEED)
			expect(Bumper.launchSpeeds(8, 35, 350)).toBe(BumperConfig.MIN_LAUNCH_SPEED)
		end)
		it("ajoute une composante verticale proportionnelle", function()
			local horizontal, vertical = Bumper.launchSpeeds(30, 80, 80)
			expect(vertical).toBeCloseTo(horizontal * BumperConfig.VERTICAL_RATIO)
		end)
	end)
end)
