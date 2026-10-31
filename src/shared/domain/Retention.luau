--!strict
-- Boucles de rétention (CDC §7.4 ; A44 à A46), sans API Roblox : cadeaux de temps de jeu (par session),
-- Roue de la Fortune quotidienne, quêtes du jour et statistiques cumulées (statues de classement).
-- L'horloge (secondes Unix) et le générateur aléatoire sont injectés.
local RetentionConfig = require("../config/RetentionConfig")

export type QuestState = {
	day: number,
	progress: { [string]: number }, -- id de quête → avancement du jour
	claimed: { [string]: boolean },
}

-- Partie sauvegardée dans le profil (v4).
export type State = {
	lastWheelAt: number,
	quests: QuestState,
	stats: { [string]: number },
}

local Retention = {}

local SECONDS_PER_DAY = 86_400
local questsById: { [string]: RetentionConfig.QuestDef } = {}
for _, quest in RetentionConfig.QUESTS do
	questsById[quest.id] = quest
end
local knownStats: { [string]: boolean } = {}
for _, stat in RetentionConfig.STATS do
	knownStats[stat] = true
end

function Retention.newState(): State
	return { lastWheelAt = 0, quests = { day = -1, progress = {}, claimed = {} }, stats = {} }
end

local function count(value: any): number?
	if typeof(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return nil
	end
	return math.floor(value)
end

-- Nettoie l'état lu depuis le DataStore (statistiques et quêtes connues, nombres finis et positifs).
function Retention.sanitize(raw: any): State
	local state = Retention.newState()
	local source = if typeof(raw) == "table" then raw else {}
	state.lastWheelAt = count(source.lastWheelAt) or 0
	if typeof(source.stats) == "table" then
		for stat, value in source.stats do
			state.stats[stat] = if knownStats[stat] then count(value) else nil
		end
	end
	local quests = if typeof(source.quests) == "table" then source.quests else {}
	state.quests.day = count(quests.day) or -1
	for id, value in if typeof(quests.progress) == "table" then quests.progress else {} do
		state.quests.progress[id] = if questsById[id] then count(value) else nil
	end
	for id, value in if typeof(quests.claimed) == "table" then quests.claimed else {} do
		state.quests.claimed[id] = if questsById[id] and value == true then true else nil
	end
	return state
end

-- Cadeaux de temps de jeu : le n-ième se débloque après GIFTS[n].minutes de présence dans la session.
function Retention.isGiftClaimable(index: number, sessionSeconds: number, claimed: { [number]: boolean }): boolean
	local gift = RetentionConfig.GIFTS[index]
	return gift ~= nil and not claimed[index] and sessionSeconds >= gift.minutes * 60
end

-- Secondes avant le prochain tour de roue (0 : on peut tourner).
function Retention.wheelWait(state: State, now: number): number
	return math.max(0, state.lastWheelAt + RetentionConfig.WHEEL_COOLDOWN_SECONDS - now)
end

-- Tire une case de la roue selon les poids affichés. Renvoie son index.
function Retention.spin(rng: () -> number): number
	local total = 0
	for _, segment in RetentionConfig.WHEEL do
		total += segment.weight
	end
	local pick = rng() * total
	for index, segment in RetentionConfig.WHEEL do
		if pick < segment.weight then
			return index
		end
		pick -= segment.weight
	end
	return #RetentionConfig.WHEEL
end

function Retention.dayOf(now: number): number
	return now // SECONDS_PER_DAY
end

-- Les quêtes du jour : tirées sans doublon dans le catalogue, toujours les mêmes pour une date donnée
-- (tous les serveurs proposent les mêmes quêtes le même jour).
function Retention.questsForDay(day: number): { RetentionConfig.QuestDef }
	local pool = table.clone(RetentionConfig.QUESTS)
	local seed = (day * 2654435761) % 4294967296
	local chosen: { RetentionConfig.QuestDef } = {}
	for _ = 1, math.min(RetentionConfig.QUESTS_PER_DAY, #pool) do
		seed = (1664525 * seed + 1013904223) % 4294967296
		table.insert(chosen, table.remove(pool, seed % #pool + 1) :: RetentionConfig.QuestDef)
	end
	return chosen
end

-- Change de jour si besoin : l'avancement et les récompenses réclamées repartent de zéro.
function Retention.ensureDay(state: State, day: number)
	if state.quests.day ~= day then
		state.quests = { day = day, progress = {}, claimed = {} }
	end
end

-- Enregistre une action : statistique cumulée (statues) et avancement des quêtes du jour qui la suivent.
function Retention.record(state: State, stat: string, amount: number, day: number)
	if not knownStats[stat] or amount <= 0 then
		return
	end
	state.stats[stat] = (state.stats[stat] or 0) + amount
	Retention.ensureDay(state, day)
	for _, quest in Retention.questsForDay(day) do
		if quest.stat == stat then
			state.quests.progress[quest.id] = (state.quests.progress[quest.id] or 0) + amount
		end
	end
end

-- Réclame une quête du jour terminée. Renvoie sa récompense, ou nil.
function Retention.claimQuest(state: State, questId: string, day: number): RetentionConfig.Reward?
	Retention.ensureDay(state, day)
	for _, quest in Retention.questsForDay(day) do
		local progress = state.quests.progress[quest.id] or 0
		if quest.id == questId and not state.quests.claimed[quest.id] and progress >= quest.target then
			state.quests.claimed[quest.id] = true
			return quest.reward
		end
	end
	return nil
end

return Retention
