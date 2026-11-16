--!strict
-- Butin des chocs (A71) : quand un joueur est éjecté, une part de son sac tombe en tas de briques dorées autour de
-- lui. Le premier qui passe dessus les ramasse, la victime comprise après un court délai. Autoritaire : le serveur
-- retire du sac, pose les tas, détecte les ramassages et crédite les sacs (Spill, pur et testé).
-- Dépendances : BumperService (signal Ejected), HarvestService (sacs), MapGeometry (rester dans le champ).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BumperConfig = require(ReplicatedStorage.Shared.config.BumperConfig)
local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local SceneryConfig = require(ReplicatedStorage.Shared.config.SceneryConfig)
local MapGeometry = require(ReplicatedStorage.Shared.domain.MapGeometry)
local Spill = require(ReplicatedStorage.Shared.domain.Spill)
local Perks = require(ReplicatedStorage.Shared.net.Perks)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local Format = require(ReplicatedStorage.Shared.util.Format)
local Build = require(script.Parent.Parent.builders.Build)
local BumperService = require(script.Parent.BumperService)
local HarvestService = require(script.Parent.HarvestService)

local SpillService = {}

type Drop = {
	pile: Spill.Pile,
	model: Model,
	label: TextLabel,
	victim: Player,
	victimReadyAt: number, -- la victime ne ramasse pas avant : elle est encore en l'air
	expiresAt: number,
}

local SPILL = BumperConfig.SPILL

local drops: { Drop } = {}
local folder: Folder
local random = Random.new()
local elapsed = 0
local notify: RemoteEvent
local pickedUp: RemoteEvent

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Tas de briques dorées qui flotte et se dandine (animé par chaque client, comme les œufs du couvoir).
local function buildPile(pile: Spill.Pile): (Model, TextLabel)
	local model = Instance.new("Model")
	model.Name = "SpillPile"
	local base = CFrame.new(pile.x, MapConfig.FLOOR_TOP + SPILL.HOVER, pile.z)
		* CFrame.Angles(0, random:NextNumber(0, 6), 0)
	local bricks = {
		{ offset = Vector3.new(0, 0.6, 0), size = Vector3.new(3, 1.2, 2) },
		{ offset = Vector3.new(0.6, 1.8, 0.2), size = Vector3.new(2, 1.2, 2) },
		{ offset = Vector3.new(-0.3, 3, -0.1), size = Vector3.new(1.4, 1.2, 1.4) },
	}
	local primary: Part? = nil
	for _, brick in bricks do
		local part = Build.block(model, {
			name = "Brick",
			cframe = base * CFrame.new(brick.offset),
			size = brick.size,
			color = SPILL.COLOR,
		})
		part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
		part.CastShadow = false
		primary = primary or part
	end
	local anchor = primary :: Part
	local light = Instance.new("PointLight")
	light.Color = anchor.Color
	light.Range, light.Brightness = 12, 1.5
	light.Parent = anchor
	local label = Build.floatingLabel(anchor, SPILL.LABEL_HEIGHT, `+{Format.money(pile.places)}`)
	model.PrimaryPart = anchor
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute(SceneryConfig.BOB_HEIGHT, SPILL.BOB.height)
	model:SetAttribute(SceneryConfig.BOB_PERIOD, SPILL.BOB.period)
	model:SetAttribute(SceneryConfig.BOB_TILT, SPILL.BOB.tilt)
	model:SetAttribute(SceneryConfig.BOB_ROAM, 0)
	CollectionService:AddTag(model, SceneryConfig.BOB_TAG)
	model.Parent = folder
	return model, label
end

-- Un tas reste dans le champ : s'il devait tomber sur un mur ou dans l'eau, il reste aux pieds de la victime.
local function landingSpot(pile: Spill.Pile, origin: Vector3)
	local zone = MapGeometry.zoneAt(pile.x, pile.z)
	if not zone or MapConfig.VOID_ZONES[zone] or MapGeometry.zoneAt(pile.x + 4, pile.z) ~= zone then
		pile.x, pile.z = origin.X, origin.Z
	end
end

local function onEjected(attacker: Player, victim: Player)
	local root = rootOf(victim)
	local attackerRoot = rootOf(attacker)
	if not root or attacker == victim then
		return
	end
	local places, value = HarvestService.spill(victim)
	if places <= 0 then
		return
	end
	local away = if attackerRoot then root.Position - attackerRoot.Position else root.CFrame.LookVector
	local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
	local now = os.clock()
	local piles = Spill.scatter(places, value, root.Position.X, root.Position.Z, direction.X, direction.Z, function()
		return random:NextNumber()
	end)
	for _, pile in piles do
		landingSpot(pile, root.Position)
		local model, label = buildPile(pile)
		table.insert(drops, {
			pile = pile,
			model = model,
			label = label,
			victim = victim,
			victimReadyAt = now + SPILL.VICTIM_DELAY,
			expiresAt = now + SPILL.LIFETIME,
		})
	end
	local amount = Format.money(places)
	notify:FireClient(victim, `💥 {attacker.DisplayName} t'a fait lâcher {amount} de blé ! Reprends-le vite.`)
	notify:FireClient(attacker, `💥 {victim.DisplayName} a lâché {amount} de blé : ramasse-le !`)
end

local function collect(drop: Drop, now: number)
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and not (player == drop.victim and now < drop.victimReadyAt) then
			local reach = SPILL.PICKUP_RADIUS + Perks.tierOf(player).hitboxStuds / 2
			local dx, dz = root.Position.X - drop.pile.x, root.Position.Z - drop.pile.z
			if dx * dx + dz * dz <= reach * reach then
				local taken = HarvestService.collect(player, drop.pile)
				if taken > 0 then
					pickedUp:FireClient(player, drop.pile.x, drop.pile.z, taken)
					drop.label.Text = `+{Format.money(drop.pile.places)}`
				end
				if drop.pile.places <= 0 then
					return
				end
			end
		end
	end
end

local function update()
	local now = os.clock()
	for index = #drops, 1, -1 do
		local drop = drops[index]
		collect(drop, now)
		if drop.pile.places <= 0 or now >= drop.expiresAt then
			drop.model:Destroy()
			table.remove(drops, index)
		end
	end
end

function SpillService:Init()
	notify = Remotes.event(Remotes.NOTIFY)
	pickedUp = Remotes.event(Remotes.SPILL_PICKED_UP)
	folder = Instance.new("Folder")
	folder.Name = "Spills"
	folder.Parent = Workspace
end

function SpillService:Start()
	BumperService.Ejected:Connect(onEjected)
	RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= SPILL.CHECK_INTERVAL and #drops > 0 then
			elapsed = 0
			update()
		end
	end)
end

return SpillService
