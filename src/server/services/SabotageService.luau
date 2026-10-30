--!strict
-- Objets de sabotage (CDC §6, A13, A41, Sprint 5) : Flaque de Boue, Gant de Boxe, Onde de Choc, Bazooka.
-- Le client n'envoie qu'un identifiant d'objet : le serveur choisit la cible, vérifie la ligne de vue,
-- consomme l'objet seulement si l'effet a lieu, et passe par BumperService (mêmes règles d'immunité).
-- Achat en gemmes ici ; le Bazooka et les achats Robux arrivent avec MonetizationService (Sprint 8).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SabotageConfig = require(ReplicatedStorage.Shared.config.SabotageConfig)
local Bumper = require(ReplicatedStorage.Shared.domain.Bumper)
local MapGeometry = require(ReplicatedStorage.Shared.domain.MapGeometry)
local Sabotage = require(ReplicatedStorage.Shared.domain.Sabotage)
local ItemRequests = require(ReplicatedStorage.Shared.net.ItemRequests)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.util.RateLimiter)
local EventModels = require(script.Parent.Parent.builders.EventModels)
local BumperService = require(script.Parent.BumperService)
local FieldService = require(script.Parent.FieldService)
local InventoryService = require(script.Parent.InventoryService)
local TycoonService = require(script.Parent.TycoonService)

local SabotageService = {}

type Puddle = { part: Part, ownerId: number, x: number, z: number, expiresAt: number }
type Effect = (user: BumperService.Contestant, others: { BumperService.Contestant }) -> string?

local MUD = SabotageConfig.MUD

local requestLimiter = RateLimiter.new(4, 2)
local lastUseAt: { [Player]: number } = {}
local puddles: { Puddle } = {}
local feedback: RemoteEvent
local folder: Folder
local mudElapsed = 0

local function bodiesOf(contestants: { BumperService.Contestant }): { Bumper.Body }
	local bodies: { Bumper.Body } = {}
	for _, contestant in contestants do
		table.insert(bodies, contestant.body)
	end
	return bodies
end

local function contestantById(contestants: { BumperService.Contestant }, id: number): BumperService.Contestant?
	for _, contestant in contestants do
		if contestant.body.id == id then
			return contestant
		end
	end
	return nil
end

-- Éjecte `target` à l'opposé de (fromX, fromZ), assez fort pour parcourir `distance` studs.
local function ejectAway(target: BumperService.Contestant, fromX: number, fromZ: number, distance: number): boolean
	local dx, dz = target.body.x - fromX, target.body.z - fromZ
	local length = math.max(1e-6, math.sqrt(dx * dx + dz * dz))
	local horizontal, vertical = Sabotage.launchForDistance(distance)
	return BumperService.eject(
		target,
		{ dirX = dx / length, dirZ = dz / length, horizontal = horizontal, vertical = vertical }
	)
end

local function hasLineOfSight(from: BasePart, to: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(excluded, player.Character)
		end
	end
	params.FilterDescendantsInstances = excluded
	return Workspace:Raycast(from.Position, to.Position - from.Position, params) == nil
end

local function useMud(user: BumperService.Contestant): string?
	local zone = MapGeometry.zoneAt(user.body.x, user.body.z)
	if Bumper.isSafeZone(zone) or zone == nil then
		return "Pas de boue en zone sûre ni sur ta base."
	end
	local owned = 0
	for _, puddle in puddles do
		owned += if puddle.ownerId == user.body.id then 1 else 0
	end
	if owned >= MUD.MAX_PER_PLAYER then
		return `Déjà {MUD.MAX_PER_PLAYER} flaques posées.`
	end
	table.insert(puddles, {
		part = EventModels.mud(folder, user.body.x, user.body.z),
		ownerId = user.body.id,
		x = user.body.x,
		z = user.body.z,
		expiresAt = os.clock() + MUD.LIFETIME_SECONDS,
	})
	return nil
end

local function useGlove(user: BumperService.Contestant, others: { BumperService.Contestant }): string?
	local target = Sabotage.gloveTarget(user.body, bodiesOf(others))
	local contestant = target and contestantById(others, target.id)
	if not contestant then
		return "Aucune cible à portée de gant."
	end
	ejectAway(contestant, user.body.x, user.body.z, SabotageConfig.GLOVE.EJECT_DISTANCE)
	return nil
end

local function useBazooka(user: BumperService.Contestant, others: { BumperService.Contestant }): string?
	local look = user.root.CFrame.LookVector
	local target = Sabotage.bazookaTarget(user.body, look.X, look.Z, bodiesOf(others))
	local contestant = target and contestantById(others, target.id)
	if not contestant or not hasLineOfSight(user.root, contestant.root) then
		return "Aucune cible en ligne de mire."
	end
	ejectAway(contestant, user.body.x, user.body.z, SabotageConfig.BAZOOKA.EJECT_DISTANCE)
	return nil
end

local function useDynamite(user: BumperService.Contestant, others: { BumperService.Contestant }): string?
	local rainbow = FieldService.nearestRainbow(user.body.x, user.body.z, SabotageConfig.DYNAMITE.RAINBOW_RANGE)
	if not rainbow then
		return "Il faut être près d'un Blé Arc-en-ciel."
	end
	local targets = Sabotage.dynamiteTargets(rainbow.x, rainbow.z, user.body.id, bodiesOf(others))
	if #targets == 0 then
		return "Personne autour du Blé Arc-en-ciel."
	end
	for _, target in targets do
		local contestant = contestantById(others, target.id)
		if contestant then
			ejectAway(contestant, rainbow.x, rainbow.z, SabotageConfig.DYNAMITE.EJECT_DISTANCE)
		end
	end
	return nil
end

local EFFECTS: { [string]: Effect } = {
	Mud = useMud,
	Glove = useGlove,
	Bazooka = useBazooka,
	Dynamite = useDynamite,
}

local function onUse(player: Player, itemId: any)
	local item = ItemRequests.parse(itemId)
	local now = os.clock()
	if not item or not requestLimiter:allow(player, now) then
		return
	end
	if now - (lastUseAt[player] or -math.huge) < SabotageConfig.USE_COOLDOWN then
		return
	end
	if InventoryService.count(player, item.id) <= 0 then
		feedback:FireClient(player, `Plus de {item.name}.`)
		return
	end
	local contestants = BumperService.contestants()
	local user = contestantById(contestants, player.UserId)
	if not user then
		return
	end
	local refusal = EFFECTS[item.id](user, contestants)
	if refusal then
		feedback:FireClient(player, refusal)
		return
	end
	lastUseAt[player] = now
	InventoryService.take(player, item.id) -- consommé seulement si l'effet a eu lieu
	feedback:FireClient(player, `{item.icon} {item.name} !`)
end

local function onBuy(player: Player, itemId: any)
	local item = ItemRequests.parse(itemId)
	if not item or not requestLimiter:allow(player, os.clock()) then
		return
	end
	local price = item.gemPrice
	if not price then
		feedback:FireClient(player, `{item.name} : bientôt dans la boutique Robux.`)
		return
	end
	if not TycoonService.spendGems(player, price) then
		feedback:FireClient(player, `Il faut {price} 💎 pour {item.name}.`)
		return
	end
	InventoryService.add(player, item.id, item.chargesPerPurchase)
	feedback:FireClient(player, `+{item.chargesPerPurchase} {item.icon} {item.name}`)
end

-- Les engins qui roulent dans la boue d'un autre joueur tournent sur eux-mêmes (CDC §6).
local function updatePuddles()
	local now = os.clock()
	for k = #puddles, 1, -1 do
		if now >= puddles[k].expiresAt then
			puddles[k].part:Destroy()
			table.remove(puddles, k)
		end
	end
	for _, contestant in BumperService.contestants() do
		for _, puddle in puddles do
			local distance = math.sqrt((contestant.body.x - puddle.x) ^ 2 + (contestant.body.z - puddle.z) ^ 2)
			if contestant.body.isVehicle and contestant.body.id ~= puddle.ownerId and distance <= MUD.RADIUS then
				BumperService.spin(contestant, MUD.SPIN_SECONDS)
				break
			end
		end
	end
end

function SabotageService:Init()
	folder = Instance.new("Folder")
	folder.Name = "Sabotage"
	folder.Parent = Workspace
	feedback = Remotes.event(Remotes.ITEM_FEEDBACK)
	Remotes.event(Remotes.USE_ITEM).OnServerEvent:Connect(onUse)
	Remotes.event(Remotes.BUY_ITEM).OnServerEvent:Connect(onBuy)
end

function SabotageService:Start()
	Players.PlayerRemoving:Connect(function(player)
		requestLimiter:forget(player)
		lastUseAt[player] = nil
	end)
	RunService.Heartbeat:Connect(function(deltaTime: number)
		mudElapsed += deltaTime
		if mudElapsed >= MUD.CHECK_INTERVAL then
			mudElapsed = 0
			updatePuddles()
		end
	end)
end

return SabotageService
