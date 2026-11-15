--!strict
local TestKit = require("../TestKit")
local TycoonConfig = require("../../src/shared/config/TycoonConfig")
local Offline = require("../../src/shared/domain/Offline")
local Profile = require("../../src/shared/domain/Profile")
local Tycoon = require("../../src/shared/domain/Tycoon")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local NOW = 1_800_000_000
local MAX = TycoonConfig.OFFLINE.MAX_SECONDS

describe("Gains hors ligne (A60)", function()
	it("ne compte rien pour un nouveau profil ou une horloge qui recule", function()
		expect(Offline.awaySeconds(0, NOW)).toBe(0)
		expect(Offline.awaySeconds(NOW + 10, NOW)).toBe(0)
	end)
	it("plafonne l'absence", function()
		expect(Offline.awaySeconds(NOW - 3600, NOW)).toBe(3600)
		expect(Offline.awaySeconds(NOW - 10 * MAX, NOW)).toBe(MAX)
	end)
	it("fait tourner le tapis sur le silo pendant l'absence", function()
		local state = Tycoon.new()
		state.silo = 1_000
		local result = Offline.collect(state, NOW - 3600, NOW, Tycoon.NO_BONUS)
		expect(result.seconds).toBe(3600)
		expect(result.earned).toBeCloseTo(1_000) -- le silo (1 000 $ bruts) s'est vidé en 500 s, sans multiplicateur
		expect(state.silo).toBeCloseTo(0)
		expect(state.money).toBeCloseTo(1_000)
	end)
	it("ne gagne que ce que le silo contenait", function()
		local state = Tycoon.new()
		local result = Offline.collect(state, NOW - 3600, NOW, Tycoon.NO_BONUS)
		expect(result.earned).toBe(0)
	end)
	it("ignore les absences trop courtes", function()
		local state = Tycoon.new()
		state.silo = 1_000
		expect(Offline.collect(state, NOW - 10, NOW, Tycoon.NO_BONUS).earned).toBe(0)
		expect(state.silo).toBe(1_000)
	end)
	it("sauvegarde l'heure de départ dans le profil (v7)", function()
		local data = Profile.sanitize({ lastSeenAt = NOW })
		expect(data.lastSeenAt).toBe(NOW)
		expect(Profile.sanitize({}).lastSeenAt).toBe(0)
		expect(Profile.sanitize({ lastSeenAt = 0 / 0 }).lastSeenAt).toBe(0)
	end)
end)
