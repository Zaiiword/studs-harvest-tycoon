--!strict
-- Intégration Sprint 4 : une session complète (chargement, jeu, Rebirth, sauvegarde, reconnexion), et
-- le scénario anti-duplication « le joueur rejoint un autre serveur avant que le premier ait sauvegardé ».
local TestKit = require("../TestKit")
local FakeDataStore = require("../helpers/FakeDataStore")
local TycoonConfig = require("../../src/shared/config/TycoonConfig")
local Profile = require("../../src/shared/domain/Profile")
local ProfileStore = require("../../src/shared/domain/ProfileStore")
local Rebirth = require("../../src/shared/domain/Rebirth")
local Tycoon = require("../../src/shared/domain/Tycoon")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function serverStore(fake: FakeDataStore.FakeDataStore, sessionId: string, clock: { now: number })
	return ProfileStore.new(fake:adapter(), {
		sessionId = sessionId,
		now = function()
			return clock.now
		end,
		wait = function() end,
		lockTtl = 300,
		maxAttempts = 2,
		baseBackoff = 1,
	})
end

describe("Session joueur", function()
	it("retrouve sa progression et son Rebirth après reconnexion", function()
		local fake, clock = FakeDataStore.new(), { now = 0 }
		local server = serverStore(fake, "srv-1", clock)
		local data = server:load("player_1").data :: Profile.Data
		local state, progress = Profile.toTycoon(data), Profile.toProgress(data)
		for _, machine in TycoonConfig.MACHINES do
			state.machines[machine.id] = true
		end
		state.money = 1_000_000
		expect(Rebirth.apply(state, progress)).toBe(true)
		Tycoon.deposit(state, 40)
		server:save("player_1", Profile.fromGame(state, 1, progress, { LegendaryEgg = 1 }), true)

		local restored = serverStore(fake, "srv-2", clock):load("player_1").data :: Profile.Data
		expect(restored.rebirths).toBe(1)
		expect(restored.gems).toBe(10)
		expect(restored.silo).toBe(40)
		expect(#restored.machines).toBe(0)
		expect(restored.items.LegendaryEgg).toBe(1)
	end)

	it("empêche la duplication : un second serveur ne charge pas un profil encore ouvert", function()
		local fake, clock = FakeDataStore.new(), { now = 0 }
		local first = serverStore(fake, "srv-1", clock)
		local data = first:load("player_1").data :: Profile.Data
		data.money = 5_000
		first:save("player_1", data, false) -- sauvegarde automatique, verrou conservé

		local second = serverStore(fake, "srv-2", clock):load("player_1")
		expect(second.data).toBe(nil)

		first:save("player_1", data, true) -- départ du joueur : verrou libéré
		local third = serverStore(fake, "srv-2", clock):load("player_1").data :: Profile.Data
		expect(third.money).toBe(5_000)
	end)
end)
