--!strict
-- Statues de classement (CDC §7.4) : Top $, Top Récolte, Roi du Pare-Chocs. Classement global via un
-- OrderedDataStore par statistique (A47) ; sans accès aux API (Studio), classement des joueurs du serveur.
-- Chaque statue montre l'avatar du premier sur un socle en briques, avec son nom et son score.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local RetentionConfig = require(ReplicatedStorage.Shared.config.RetentionConfig)
local Format = require(ReplicatedStorage.Shared.util.Format)
local Build = require(script.Parent.Parent.builders.Build)
local RetentionService = require(script.Parent.RetentionService)

local LeaderboardService = {}

type StatueDef = { id: string, label: string, stat: string, x: number, z: number }
type Statue = { def: StatueDef, plaque: TextLabel, avatar: Model?, leaderId: number? }
type Leader = { userId: number, score: number }

local PEDESTAL = { size = Vector3.new(8, 4, 8), color = { 27, 42, 53 } }
local AVATAR_SCALE = 1.6
local MAX_SCORE = 2 ^ 53 -- les OrderedDataStore stockent des entiers

local statues: { Statue } = {}
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

-- Publie les scores des joueurs présents, puis lit le premier du classement global.
local function globalLeader(stat: string): Leader?
	local store = storeFor(stat)
	if not store then
		return nil
	end
	for _, player in Players:GetPlayers() do
		local score = math.min(MAX_SCORE, math.floor(RetentionService.stat(player, stat)))
		if score > 0 and not pcall(store.SetAsync, store, tostring(player.UserId), score) then
			return nil
		end
	end
	local ok, pages = pcall(store.GetSortedAsync, store, false, 1)
	if not ok then
		return nil
	end
	local first = (pages :: DataStorePages):GetCurrentPage()[1]
	return first and { userId = tonumber(first.key) :: number, score = first.value }
end

local function localLeader(stat: string): Leader?
	local best: Leader? = nil
	for _, player in Players:GetPlayers() do
		local score = RetentionService.stat(player, stat)
		if score > 0 and (not best or score > best.score) then
			best = { userId = player.UserId, score = score }
		end
	end
	return best
end

local function displayName(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	if player then
		return player.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	return if ok then name else "?"
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

local function refresh()
	for _, statue in statues do
		local leader = if isGlobal then globalLeader(statue.def.stat) else nil
		if isGlobal and not leader and #Players:GetPlayers() > 0 then
			isGlobal = false -- DataStore indisponible : on reste en classement local
			warn("[LeaderboardService] classement global indisponible : classement du serveur seulement")
		end
		leader = leader or localLeader(statue.def.stat)
		if leader then
			statue.plaque.Text = `{statue.def.label}\n{displayName(leader.userId)} · {Format.money(leader.score)}`
			showAvatar(statue, leader.userId)
		end
	end
end

function LeaderboardService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Statues"
	folder.Parent = Workspace:FindFirstChild("Map") or Workspace
	for _, def in RetentionConfig.STATUES do
		table.insert(statues, buildStatue(folder, def))
	end
	task.spawn(function()
		while true do
			task.wait(RetentionConfig.LEADERBOARD_REFRESH_SECONDS)
			refresh()
		end
	end)
end

return LeaderboardService
