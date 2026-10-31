--!strict
-- Boucles de rétention (CDC §7.4, Sprint 7) : cadeaux de temps de jeu, Roue de la Fortune quotidienne,
-- quêtes de destruction du jour, statistiques cumulées (statues). Les statistiques arrivent par les signaux
-- des autres services : ni la récolte, ni les chocs, ni l'usine ne dépendent de la rétention.
-- Le temps de référence est Workspace:GetServerTimeNow() (secondes Unix), partagé avec le client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RetentionConfig = require(ReplicatedStorage.Shared.config.RetentionConfig)
local Retention = require(ReplicatedStorage.Shared.domain.Retention)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.util.RateLimiter)
local BumperService = require(script.Parent.BumperService)
local EventService = require(script.Parent.EventService)
local HarvestService = require(script.Parent.HarvestService)
local InventoryService = require(script.Parent.InventoryService)
local TycoonService = require(script.Parent.TycoonService)

local RetentionService = {}

type Entry = {
	state: Retention.State,
	sessionStartedAt: number,
	giftsClaimed: { [number]: boolean },
	isDirty: boolean,
}

local PUBLISH_INTERVAL = 0.5
local STAT_BY_ZONE: { [string]: string } = { GoldenCorn = "corn", DiamondWheat = "diamond" }

local random = Random.new()
local entries: { [Player]: Entry } = {}
local limiter = RateLimiter.new(5, 2)
local notify: RemoteEvent
local wheelResult: RemoteEvent
local publishElapsed = 0

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function entryOf(player: Player): Entry
	local entry = entries[player]
	if not entry then
		entry = { state = Retention.newState(), sessionStartedAt = now(), giftsClaimed = {}, isDirty = true }
		entries[player] = entry
	end
	return entry :: Entry
end

local function publish(player: Player, entry: Entry)
	entry.isDirty = false
	Retention.ensureDay(entry.state, Retention.dayOf(now()))
	local gifts, progress, claimed = {}, {}, {}
	for index in entry.giftsClaimed do
		table.insert(gifts, tostring(index))
	end
	for id, value in entry.state.quests.progress do
		table.insert(progress, `{id}={value}`)
	end
	for id in entry.state.quests.claimed do
		table.insert(claimed, id)
	end
	player:SetAttribute(PlayerAttributes.SESSION_STARTED_AT, entry.sessionStartedAt)
	player:SetAttribute(PlayerAttributes.GIFTS_CLAIMED, table.concat(gifts, ","))
	player:SetAttribute(
		PlayerAttributes.WHEEL_READY_AT,
		entry.state.lastWheelAt + RetentionConfig.WHEEL_COOLDOWN_SECONDS
	)
	player:SetAttribute(PlayerAttributes.QUEST_PROGRESS, table.concat(progress, ","))
	player:SetAttribute(PlayerAttributes.QUESTS_CLAIMED, table.concat(claimed, ","))
end

-- Verse une récompense (argent, gemmes ou objet) et prévient le joueur.
local function grant(player: Player, reward: RetentionConfig.Reward, source: string)
	if reward.money then
		TycoonService.grant(player, reward.money)
	end
	if reward.gems then
		TycoonService.grantGems(player, reward.gems)
	end
	if reward.item then
		InventoryService.add(player, reward.item, reward.count or 1)
	end
	notify:FireClient(player, `🎁 {source} : récompense reçue !`)
end

local function record(player: Player, stat: string, amount: number)
	local entry = entries[player]
	if entry then
		Retention.record(entry.state, stat, amount, Retention.dayOf(now()))
		entry.isDirty = true
	end
end

local function onClaimGift(player: Player, rawIndex: any)
	local entry = entries[player]
	if not entry or typeof(rawIndex) ~= "number" or not limiter:allow(player, os.clock()) then
		return
	end
	local index = math.floor(rawIndex)
	if not Retention.isGiftClaimable(index, now() - entry.sessionStartedAt, entry.giftsClaimed) then
		return
	end
	entry.giftsClaimed[index] = true
	grant(player, RetentionConfig.GIFTS[index].reward, `Cadeau n°{index}`)
	publish(player, entry)
end

local function onSpinWheel(player: Player)
	local entry = entries[player]
	if not entry or not limiter:allow(player, os.clock()) or Retention.wheelWait(entry.state, now()) > 0 then
		return
	end
	entry.state.lastWheelAt = now()
	local index = Retention.spin(function()
		return random:NextNumber()
	end)
	wheelResult:FireClient(player, index) -- le client fait tourner la roue jusqu'à cette case
	grant(player, RetentionConfig.WHEEL[index].reward, `Roue : {RetentionConfig.WHEEL[index].label}`)
	publish(player, entry)
end

local function onClaimQuest(player: Player, rawId: any)
	local entry = entries[player]
	if not entry or typeof(rawId) ~= "string" or not limiter:allow(player, os.clock()) then
		return
	end
	local reward = Retention.claimQuest(entry.state, rawId, Retention.dayOf(now()))
	if reward then
		grant(player, reward, "Quête du jour")
		publish(player, entry)
	end
end

-- Statistique cumulée d'un joueur (statues de classement).
function RetentionService.stat(player: Player, stat: string): number
	local entry = entries[player]
	return if entry then entry.state.stats[stat] or 0 else 0
end

function RetentionService.snapshot(player: Player): Retention.State
	local state = entryOf(player).state
	return Retention.sanitize(state) -- copie propre et indépendante
end

function RetentionService.restore(player: Player, state: Retention.State)
	local entry = entryOf(player)
	entry.state = Retention.sanitize(state)
	publish(player, entry)
end

function RetentionService.release(player: Player)
	entries[player] = nil
	limiter:forget(player)
end

local function connectStats()
	HarvestService.Harvested:Connect(function(player: Player, result: any)
		record(player, "harvested", 1)
		local stat = STAT_BY_ZONE[result.zone]
		if stat then
			record(player, stat, 1)
		end
	end)
	HarvestService.Unloaded:Connect(function(player: Player, value: number)
		if value > 0 then
			record(player, "unloads", 1)
		end
	end)
	BumperService.Ejected:Connect(function(attacker: Player)
		record(attacker, "ejections", 1)
	end)
	EventService.BossHit:Connect(function(player: Player, dealt: number)
		record(player, "bossDamage", dealt)
	end)
	TycoonService.Earned:Connect(function(player: Player, amount: number)
		record(player, "earned", amount)
	end)
end

function RetentionService:Init()
	notify = Remotes.event(Remotes.NOTIFY)
	wheelResult = Remotes.event(Remotes.WHEEL_RESULT)
	Remotes.event(Remotes.CLAIM_GIFT).OnServerEvent:Connect(onClaimGift)
	Remotes.event(Remotes.SPIN_WHEEL).OnServerEvent:Connect(onSpinWheel)
	Remotes.event(Remotes.CLAIM_QUEST).OnServerEvent:Connect(onClaimQuest)
end

function RetentionService:Start()
	connectStats()
	Players.PlayerAdded:Connect(entryOf)
	for _, player in Players:GetPlayers() do
		entryOf(player)
	end
	RunService.Heartbeat:Connect(function(deltaTime: number)
		publishElapsed += deltaTime
		if publishElapsed < PUBLISH_INTERVAL then
			return
		end
		publishElapsed = 0
		for player, entry in entries do
			if entry.isDirty then
				publish(player, entry)
			end
		end
	end)
end

return RetentionService
