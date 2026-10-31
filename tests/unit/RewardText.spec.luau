--!strict
-- Affichage des récompenses du menu 🎁 : vrais noms d'objets, icônes, chances de la roue.
local TestKit = require("../TestKit")
local RetentionConfig = require("../../src/shared/config/RetentionConfig")
local UiConfig = require("../../src/shared/config/UiConfig")
local RewardText = require("../../src/shared/domain/RewardText")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("RewardText", function()
	it("affiche l'argent abrégé et les gemmes avec leur icône", function()
		expect(RewardText.label({ money = 25_000 })).toBe("25 K $")
		expect(RewardText.icon({ money = 25_000 })).toBe("💰")
		expect(RewardText.label({ gems = 10 })).toBe("10 💎")
	end)

	it("donne le vrai nom des objets (pas leur identifiant)", function()
		expect(RewardText.label({ item = "LegendaryEgg", count = 1 })).toBe("1 × Œuf Légendaire")
		expect(RewardText.icon({ item = "LegendaryEgg", count = 1 })).toBe("🥚")
		expect(RewardText.label({ item = "Glove", count = 2 })).toBe("2 × Gant de Boxe")
		expect(RewardText.icon({ item = "Mud" })).toBe("🟫")
	end)

	it("trouve un nom lisible pour chaque récompense de cadeau, de quête et de la roue", function()
		local rewards = {}
		for _, gift in RetentionConfig.GIFTS do
			table.insert(rewards, gift.reward)
		end
		for _, quest in RetentionConfig.QUESTS do
			table.insert(rewards, quest.reward)
		end
		for _, segment in RetentionConfig.WHEEL do
			table.insert(rewards, segment.reward)
		end
		for _, reward in rewards do
			expect(RewardText.icon(reward) ~= "🎁").toBe(true)
		end
	end)

	it("affiche des chances de roue qui totalisent 100 % (A45)", function()
		local total = 0
		for _, odds in RewardText.wheelOdds() do
			total += odds
		end
		expect(total).toBeCloseTo(100, 0.5)
		expect(#RewardText.wheelOdds()).toBe(#RetentionConfig.WHEEL)
	end)

	it("donne une icône à chaque quête du catalogue", function()
		for _, quest in RetentionConfig.QUESTS do
			expect(UiConfig.RETENTION_MENU.QUEST_ICONS[quest.id] ~= nil).toBe(true)
		end
	end)
end)
