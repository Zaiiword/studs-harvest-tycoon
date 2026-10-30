--!strict
-- Valeurs figées de l'éjection (CDC §5, A30) : tout réglage d'équilibrage PvP doit être intentionnel.
local TestKit = require("../TestKit")
local VehicleConfig = require("../../src/shared/config/VehicleConfig")
local Bumper = require("../../src/shared/domain/Bumper")
local Formulas = require("../../src/shared/domain/Formulas")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function mass(tierId: number): number
	return Formulas.effectiveMass(VehicleConfig.TIERS[tierId].mass, 0, false)
end

describe("Éjection (golden)", function()
	it("Tracteur (80) contre Tondeuse (35) à 30 studs/s", function()
		local horizontal, vertical = Bumper.launchSpeeds(30, mass(4), mass(3))
		expect(horizontal).toBeCloseTo(34.2857, 1e-3)
		expect(vertical).toBeCloseTo(15.4286, 1e-3)
	end)
	it("Tondeuse contre Tracteur : éjection minimale", function()
		expect(Bumper.launchSpeeds(24, mass(3), mass(4))).toBe(30)
	end)
	it("Cyber-Laser contre joueur à pied : éjection maximale", function()
		expect(Bumper.launchSpeeds(46, mass(7), mass(1))).toBe(140)
	end)
end)
