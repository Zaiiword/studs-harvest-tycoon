--!strict
-- Classements (CDC §7.4, A47, A58) : statues des premiers, grands tableaux de scores (niveau, fortune, Robux, récolte,
-- éjections) et colonnes du menu des joueurs (leaderstats). Classement global via un OrderedDataStore par statistique ;
-- sans accès aux API (Studio), classement des joueurs du serveur.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local RetentionConfig = require(ReplicatedStorage.Shared.config.RetentionConfig)
local Scoreboard = require(ReplicatedStorage.Shared.domain.Scoreboard)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Format = require(ReplicatedStorage.Shared.util.Format)
local Build = require(script.Parent.Parent.builders.Build)
local ScoreboardModels = require(script.Parent.Parent.builders.ScoreboardModels)
local MonetizationService = require(script.Parent.MonetizationService)
local RetentionService = require(script.Parent.RetentionService)

local LeaderboardService = {}

type StatueDef = { id: string, label: string, stat: string, x: number, z: number }
type Statue = { def: StatueDef, plaque: TextLabel, avatar: Model?, leaderId: number? }
type Leader = Scoreboard.Entry

local PEDESTAL = { size = Vector3.new(8, 4, 8), color = { 27, 42, 53 } }
local AVATAR_SCALE = 1.6
local MAX_SCORE = 2 ^ 53 -- les OrderedDataStore stockent des entiers

local statues: { Statue } = {}
local boards: { { def: RetentionConfig.ScoreboardDef, board: ScoreboardModels.Board } } = {}
local names: { [number]: string } = {}
local stores: { [string]: OrderedDataStore } = {}
local isGlobal = true

local function buildStatue(parent: Instance, def: StatueDef): Statue
	local top = MapConfig.FLOOR_TOP
	local pedestal = Build.block(parent, {
		name = `Statue{def.id}`,
		cframe = CFrame.new(def.x, top + PEDESTAL.size.Y / 2, def.z) * CFrame.Angles(0, math.pi / 2, 0),
		size = PEDESTAL.size,
		color = PEDESTAL.color,
	})
	local plaque = Build.sign(pedestal, Enum.NormalId.Front, def.label, { 245, 205, 48 })
	return { def = def, plaque = plaque }
end

local function storeFor(stat: string): OrderedDataStore?
	if not stores[stat] then
		local ok, store = pcall(
			DataStoreService.GetOrderedDataStore,
			DataStoreService,
			RetentionConfig.LEADERBOARD_STORE_PREFIX .. stat
		)
		if not ok then
			return nil
		end
		stores[stat] = store
	end
	return stores[stat]
end

-- Score d'un joueur présent. Le niveau et les Robux ne font pas partie des statistiques de rétention.
local function scoreOf(player: Player, stat: string): number
	if stat == "level" then
		local tier = player:GetAttribute(PlayerAttributes.TIER)
		local rebirths = player:GetAttribute(PlayerAttributes.REBIRTHS)
		return Scoreboard.levelOf(
			if typeof(tier) == "number" then tier else 1,
			if typeof(rebirths) == "number" then rebirths else 0
		)
	elseif stat == "robux" then
		return MonetizationService.robuxSpent(player)
	end
	return RetentionService.stat(player, stat)
end

-- Publie les scores des joueurs présents, puis lit le haut du classement global.
local function globalTop(stat: string): { Leader }?
	local store = storeFor(stat)
	if not store then
		return nil
	end
	for _, player in Players:GetPlayers() do
		local score = math.min(MAX_SCORE, math.floor(scoreOf(player, stat)))
		if score > 0 and not pcall(store.SetAsync, store, tostring(player.UserId), score) then
			return nil
		end
	end
	local ok, pages = pcall(store.GetSortedAsync, store, false, RetentionConfig.SCOREBOARD_SIZE)
	if not ok then
		return nil
	end
	local top: { Leader } = {}
	for _, row in (pages :: DataStorePages):GetCurrentPage() do
		table.insert(top, { userId = tonumber(row.key) :: number, score = row.value })
	end
	return top
end

local function localTop(stat: string): { Leader }
	local entries: { Leader } = {}
	for _, player in Players:GetPlayers() do
		table.insert(entries, { userId = player.UserId, score = scoreOf(player, stat) })
	end
	return Scoreboard.top(entries, RetentionConfig.SCOREBOARD_SIZE)
end

local function displayName(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	if player then
		return player.DisplayName
	end
	if not names[userId] then
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		if not ok then
			return "?"
		end
		names[userId] = name
	end
	return names[userId]
end

-- Remplace l'avatar posé sur le socle quand le premier change (modèle Roblox de son avatar, figé).
local function showAvatar(statue: Statue, userId: number)
	if statue.leaderId == userId then
		return
	end
	if statue.avatar then
		statue.avatar:Destroy()
		statue.avatar = nil
	end
	statue.leaderId = userId
	local ok, model = pcall(Players.CreateHumanoidModelFromUserIdAsync, Players, userId)
	if not ok or not model then
		return
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	model:ScaleTo(AVATAR_SCALE)
	local height = model:GetExtentsSize().Y
	local base = CFrame.new(statue.def.x, MapConfig.FLOOR_TOP + PEDESTAL.size.Y + height / 2, statue.def.z)
	model:PivotTo(base * CFrame.Angles(0, math.pi / 2, 0)) -- tourné vers le champ (+X)
	model.Parent = statue.plaque:FindFirstAncestorWhichIsA("BasePart")
	statue.avatar = model
end

-- Classement d'une statistique, une seule fois par tour même si une statue et un tableau la partagent.
local function topOf(stat: string, cache: { [string]: { Leader } }): { Leader }
	if cache[stat] then
		return cache[stat]
	end
	local top = if isGlobal then globalTop(stat) else nil
	if isGlobal and not top and #Players:GetPlayers() > 0 then
		isGlobal = false -- DataStore indisponible : on reste en classement local
		warn("[LeaderboardService] classement global indisponible : classement du serveur seulement")
	end
	cache[stat] = top or localTop(stat)
	return cache[stat]
end

local function refresh()
	local cache: { [string]: { Leader } } = {}
	for _, statue in statues do
		local leader = topOf(statue.def.stat, cache)[1]
		if leader then
			local score = Scoreboard.scoreText(statue.def.stat, leader.score)
			statue.plaque.Text = `{statue.def.label}\n{displayName(leader.userId)} · {score}`
			showAvatar(statue, leader.userId)
		end
	end
	for _, entry in boards do
		local lines: { ScoreboardModels.Line } = {}
		for _, leader in topOf(entry.def.stat, cache) do
			table.insert(lines, {
				userId = leader.userId,
				name = displayName(leader.userId),
				score = Scoreboard.scoreText(entry.def.stat, leader.score),
			})
		end
		ScoreboardModels.update(entry.board, lines)
	end
end

-- Colonnes du menu des joueurs, en haut à droite de l'écran.
local function watchLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Niveau"
	level.Parent = folder
	local money = Instance.new("StringValue")
	money.Name = "Argent"
	money.Parent = folder
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = folder
	local function update()
		local cash = player:GetAttribute(PlayerAttributes.MONEY)
		local count = player:GetAttribute(PlayerAttributes.REBIRTHS)
		level.Value = scoreOf(player, "level")
		money.Value = `{Format.money(if typeof(cash) == "number" then cash else 0)} $`
		rebirths.Value = if typeof(count) == "number" then count else 0
	end
	for _, name in { PlayerAttributes.TIER, PlayerAttributes.REBIRTHS, PlayerAttributes.MONEY } do
		player:GetAttributeChangedSignal(name):Connect(update)
	end
	update()
	folder.Parent = player
end

function LeaderboardService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Statues"
	folder.Parent = Workspace:FindFirstChild("Map") or Workspace
	for _, def in RetentionConfig.STATUES do
		table.insert(statues, buildStatue(folder, def))
	end
	for _, def in RetentionConfig.SCOREBOARDS do
		table.insert(boards, { def = def, board = ScoreboardModels.build(folder, def) })
	end
	Players.PlayerAdded:Connect(watchLeaderstats)
	for _, player in Players:GetPlayers() do
		watchLeaderstats(player)
	end
	task.spawn(function()
		task.wait(RetentionConfig.LEADERBOARD_FIRST_DELAY)
		while true do
			refresh()
			task.wait(
				if isGlobal
					then RetentionConfig.LEADERBOARD_REFRESH_SECONDS
					else RetentionConfig.LOCAL_LEADERBOARD_REFRESH_SECONDS
			)
		end
	end)
end

return LeaderboardService
