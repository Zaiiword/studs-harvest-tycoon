--!strict
-- Rebirth, format du profil et ProfileStore (verrou de session, réessais).
local TestKit = require("../TestKit")
local FakeDataStore = require("../helpers/FakeDataStore")
local TycoonConfig = require("../../src/shared/config/TycoonConfig")
local Profile = require("../../src/shared/domain/Profile")
local ProfileStore = require("../../src/shared/domain/ProfileStore")
local Rebirth = require("../../src/shared/domain/Rebirth")
local Tycoon = require("../../src/shared/domain/Tycoon")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function completeTycoon(money: number): Tycoon.State
	local state = Tycoon.new()
	for _, machine in TycoonConfig.MACHINES do
		state.machines[machine.id] = true
	end
	state.money = money
	return state
end

describe("Rebirth", function()
	it("exige toutes les machines (A8)", function()
		local state = Tycoon.new()
		state.money = 1e9
		expect(Rebirth.canRebirth(state, Rebirth.newProgress())).toBe(false)
	end)
	it("exige 1e6 × 3^r $ (CDC §8)", function()
		local progress = { rebirths = 2, gems = 0 }
		expect(Rebirth.canRebirth(completeTycoon(8_999_999), progress)).toBe(false)
		expect(Rebirth.canRebirth(completeTycoon(9_000_000), progress)).toBe(true)
	end)
	it("remet l'usine à zéro mais garde le silo (A37)", function()
		local state = completeTycoon(1_000_000)
		state.silo, state.conveyorLevel = 500, 7
		local progress = Rebirth.newProgress()
		expect(Rebirth.apply(state, progress)).toBe(true)
		expect(state.money).toBe(0)
		expect(state.conveyorLevel).toBe(1)
		expect(next(state.machines)).toBe(nil)
		expect(state.silo).toBe(500)
	end)
	it("donne 10 × (r + 1) gemmes et un Rebirth de plus (A9)", function()
		local progress = { rebirths = 1, gems = 5 }
		Rebirth.apply(completeTycoon(3_000_000), progress)
		expect(progress.rebirths).toBe(2)
		expect(progress.gems).toBe(25)
	end)
	it("augmente les revenus de 50 % par Rebirth (CDC §7)", function()
		local state = Tycoon.new()
		Tycoon.deposit(state, 100)
		local income = Tycoon.tick(state, 1, Rebirth.incomeBonus({ rebirths = 1, gems = 0 }))
		expect(income).toBe(1.5 * TycoonConfig.CONVEYOR.BASE_RATE)
	end)
end)

describe("Profile", function()
	it("donne un profil neuf par défaut", function()
		local data = Profile.sanitize(nil)
		expect(data.money).toBe(0)
		expect(data.tier).toBe(1)
		expect(data.version).toBe(Profile.VERSION)
	end)
	it("remplace les valeurs corrompues par les valeurs par défaut", function()
		local data = Profile.sanitize({ money = 0 / 0, tier = 99, conveyorLevel = -3, gems = "beaucoup" })
		expect(data.money).toBe(0)
		expect(data.tier).toBe(7)
		expect(data.conveyorLevel).toBe(1)
		expect(data.gems).toBe(0)
	end)
	it("ignore les machines inconnues et les doublons", function()
		local data = Profile.sanitize({ machines = { "Mill", "Mill", "Tardis", 42 } })
		expect(#data.machines).toBe(1)
	end)
	it("fait l'aller-retour jeu → profil → jeu", function()
		local state = completeTycoon(1234)
		state.silo, state.conveyorLevel = 77, 5
		local data = Profile.fromGame(state, 4, { rebirths = 2, gems = 30 })
		local restored = Profile.toTycoon(data)
		expect(restored.money).toBe(1234)
		expect(restored.conveyorLevel).toBe(5)
		expect(restored.machines.Factory).toBe(true)
		expect(data.tier).toBe(4)
		expect(Profile.toProgress(data).gems).toBe(30)
	end)
end)

local function newStore(
	fake: FakeDataStore.FakeDataStore,
	sessionId: string,
	clock: { now: number },
	waits: { number }?
)
	return ProfileStore.new(fake:adapter(), {
		sessionId = sessionId,
		now = function()
			return clock.now
		end,
		wait = function(seconds: number)
			if waits then
				table.insert(waits, seconds)
			end
		end,
		lockTtl = 300,
		maxAttempts = 3,
		baseBackoff = 1,
	})
end

describe("ProfileStore", function()
	it("crée un profil neuf au premier chargement et pose son verrou", function()
		local fake, clock = FakeDataStore.new(), { now = 0 }
		local result = newStore(fake, "A", clock):load("p1")
		expect((result.data :: Profile.Data).money).toBe(0)
		expect(fake.records.p1.lock.id).toBe("A")
	end)
	it("retrouve les données sauvegardées", function()
		local fake, clock = FakeDataStore.new(), { now = 0 }
		local store = newStore(fake, "A", clock)
		local data = store:load("p1").data :: Profile.Data
		data.money = 500
		expect(store:save("p1", data, true)).toBe(true)
		expect((newStore(fake, "B", clock):load("p1").data :: Profile.Data).money).toBe(500)
	end)
	it("refuse de charger un profil verrouillé par un autre serveur (anti-duplication)", function()
		local fake, clock = FakeDataStore.new(), { now = 0 }
		newStore(fake, "A", clock):load("p1")
		local result = newStore(fake, "B", clock):load("p1")
		expect(result.data).toBe(nil)
		expect(result.reason).toBe(ProfileStore.REASON_LOCKED)
	end)
	it("reprend un verrou abandonné (serveur planté) après son expiration", function()
		local fake, clock = FakeDataStore.new(), { now = 0 }
		newStore(fake, "A", clock):load("p1")
		clock.now = 301
		expect(newStore(fake, "B", clock):load("p1").data ~= nil).toBe(true)
	end)
	it("n'écrase pas les données d'un serveur qui a repris le verrou", function()
		local fake, clock = FakeDataStore.new(), { now = 0 }
		local storeA = newStore(fake, "A", clock)
		local dataA = storeA:load("p1").data :: Profile.Data
		clock.now = 301
		local storeB = newStore(fake, "B", clock)
		local dataB = storeB:load("p1").data :: Profile.Data
		dataB.money = 999
		storeB:save("p1", dataB, false)
		dataA.money = 1
		expect(storeA:save("p1", dataA, false)).toBe(false)
		expect(fake.records.p1.data.money).toBe(999)
	end)
	it("libère le verrou au départ du joueur", function()
		local fake, clock = FakeDataStore.new(), { now = 0 }
		local store = newStore(fake, "A", clock)
		store:save("p1", store:load("p1").data :: Profile.Data, true)
		expect(fake.records.p1.lock).toBe(nil)
	end)
	it("réessaie avec un délai qui double quand le DataStore échoue", function()
		local fake, clock, waits = FakeDataStore.new(), { now = 0 }, {}
		fake:failNext(2)
		local result = newStore(fake, "A", clock, waits):load("p1")
		expect(result.data ~= nil).toBe(true)
		expect(table.concat(waits :: { any }, ",")).toBe("1,2")
	end)
	it("abandonne après le nombre maximal de tentatives", function()
		local fake, clock = FakeDataStore.new(), { now = 0 }
		fake:failNext(10)
		local result = newStore(fake, "A", clock):load("p1")
		expect(result.reason).toBe(ProfileStore.REASON_ERROR)
	end)
end)
