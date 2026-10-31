--!strict
-- Intégration Sprint 7 : une journée de jeu fait avancer les quêtes et les statistiques, la roue ne tourne
-- qu'une fois par jour, et tout survit à une sauvegarde (profil v4).
local TestKit = require("../TestKit")
local FakeDataStore = require("../helpers/FakeDataStore")
local FakeRng = require("../helpers/FakeRng")
local RetentionConfig = require("../../src/shared/config/RetentionConfig")
local Pets = require("../../src/shared/domain/Pets")
local Profile = require("../../src/shared/domain/Profile")
local ProfileStore = require("../../src/shared/domain/ProfileStore")
local Rebirth = require("../../src/shared/domain/Rebirth")
local Retention = require("../../src/shared/domain/Retention")
local Tycoon = require("../../src/shared/domain/Tycoon")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local DAY = 20_400
local NOW = DAY * 86_400 + 3600

describe("Journée de jeu", function()
	it("chaque quête du jour se termine en jouant, puis se réclame une fois", function()
		local state = Retention.newState()
		local rewards = 0
		for _, quest in Retention.questsForDay(DAY) do
			Retention.record(state, quest.stat, quest.target, DAY)
			if Retention.claimQuest(state, quest.id, DAY) then
				rewards += 1
			end
		end
		expect(rewards).toBe(RetentionConfig.QUESTS_PER_DAY)
	end)

	it("la roue ne tourne qu'une fois par jour, et donne une case existante", function()
		local state = Retention.newState()
		expect(Retention.wheelWait(state, NOW)).toBe(0)
		local index = Retention.spin(FakeRng.seeded(9))
		expect(RetentionConfig.WHEEL[index] ~= nil).toBe(true)
		state.lastWheelAt = NOW
		expect(Retention.wheelWait(state, NOW + 60) > 0).toBe(true)
		expect(Retention.wheelWait(state, NOW + 86_400)).toBe(0)
	end)

	it("les 9 cadeaux se réclament tous en une heure de session", function()
		local claimed: { [number]: boolean } = {}
		for index in RetentionConfig.GIFTS do
			expect(Retention.isGiftClaimable(index, 3600, claimed)).toBe(true)
			claimed[index] = true
		end
	end)

	it("statistiques, quêtes et roue survivent à la sauvegarde (profil v4)", function()
		local fake = FakeDataStore.new()
		local store = ProfileStore.new(fake:adapter(), {
			sessionId = "srv",
			now = function()
				return 0
			end,
			wait = function() end,
			lockTtl = 300,
			maxAttempts = 2,
			baseBackoff = 1,
		})
		store:load("p")
		local retention = Retention.newState()
		Retention.record(retention, "ejections", 4, DAY)
		retention.lastWheelAt = NOW
		local data = Profile.fromGame({
			tycoon = Tycoon.new(),
			tier = 1,
			progress = Rebirth.newProgress(),
			items = {},
			pets = Pets.newCollection(),
			retention = retention,
		})
		store:save("p", data, true)
		local restored = (store:load("p").data :: Profile.Data).retention
		expect(restored.stats.ejections).toBe(4)
		expect(restored.lastWheelAt).toBe(NOW)
		expect(restored.quests.day).toBe(DAY)
	end)
end)
