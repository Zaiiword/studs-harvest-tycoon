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

-- Série de connexions quotidiennes (A61) : jour (Retention.dayOf) de la dernière récompense réclamée.
export type LoginState = { lastDay: number, streak: number }

-- Ce que montre le calendrier : la case du jour (1 à 7), et si on peut la réclamer.
export type LoginStatus = { index: number, streak: number, isClaimable: boolean }

export type CodeResult = "ok" | "invalid" | "used" | "expired"

-- Partie sauvegardée dans le profil (v4 ; connexion et codes en v8).
export type State = {
	lastWheelAt: number,
	quests: QuestState,
	stats: { [string]: number },
	login: LoginState,
	codes: { [string]: boolean }, -- codes déjà utilisés (A62)
}

local Retention = {}

local SECONDS_PER_DAY = 86_400
local questsById: { [string]: RetentionConfig.QuestDef } = {}
for _, quest in RetentionConfig.QUESTS do
	questsById[quest.id] = quest
end
local codesByName: { [string]: RetentionConfig.CodeDef } = {}
for _, code in RetentionConfig.CODES do
	codesByName[string.upper(code.code)] = code
end
local knownStats: { [string]: boolean } = {}
for _, stat in RetentionConfig.STATS do
	knownStats[stat] = true
end

function Retention.newState(): State
	return {
		lastWheelAt = 0,
		quests = { day = -1, progress = {}, claimed = {} },
		stats = {},
		login = { lastDay = -1, streak = 0 },
		codes = {},
	}
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
	local login = if typeof(source.login) == "table" then source.login else {}
	state.login.lastDay = count(login.lastDay) or -1
	state.login.streak = count(login.streak) or 0
	for code, value in if typeof(source.codes) == "table" then source.codes else {} do
		state.codes[code] = if typeof(code) == "string" and codesByName[code] and value == true then true else nil
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

-- Connexion quotidienne (A61) ----------------------------------------------------------------------------------

local function cycleIndex(streak: number): number
	return (math.max(streak, 1) - 1) % #RetentionConfig.LOGIN_REWARDS + 1
end

-- Réclamée aujourd'hui : la case reste affichée comme reçue. Réclamée hier : la série continue. Sinon : jour 1.
function Retention.loginStatus(state: State, today: number): LoginStatus
	local login = state.login
	if login.lastDay == today then
		return { index = cycleIndex(login.streak), streak = login.streak, isClaimable = false }
	end
	local streak = if login.lastDay == today - 1 then login.streak + 1 else 1
	return { index = cycleIndex(streak), streak = streak, isClaimable = true }
end

-- Réclame la récompense du jour. Renvoie la récompense, ou nil si elle a déjà été réclamée aujourd'hui.
function Retention.claimLogin(state: State, today: number): RetentionConfig.Reward?
	local status = Retention.loginStatus(state, today)
	if not status.isClaimable then
		return nil
	end
	state.login = { lastDay = today, streak = status.streak }
	return RetentionConfig.LOGIN_REWARDS[status.index]
end

-- Codes (A62) --------------------------------------------------------------------------------------------------

-- « bien venue » → « BIENVENUE » : majuscules, sans espaces. nil si ce n'est pas un texte raisonnable.
function Retention.normalizeCode(raw: any): string?
	if typeof(raw) ~= "string" or #raw > RetentionConfig.CODE_MAX_LENGTH * 4 then
		return nil
	end
	local code = string.upper((string.gsub(raw, "%s", "")))
	if code == "" or #code > RetentionConfig.CODE_MAX_LENGTH or string.find(code, "[^%w]") then
		return nil
	end
	return code
end

-- Utilise un code : sa récompense et "ok", ou nil et la raison du refus.
function Retention.redeemCode(state: State, raw: any, now: number): (RetentionConfig.Reward?, CodeResult)
	local code = Retention.normalizeCode(raw)
	local def = if code then codesByName[code] else nil
	if not code or not def then
		return nil, "invalid"
	end
	if state.codes[code] then
		return nil, "used"
	end
	if def.expiresAt and now >= def.expiresAt then
		return nil, "expired"
	end
	state.codes[code] = true
	return def.reward, "ok"
end

return Retention
