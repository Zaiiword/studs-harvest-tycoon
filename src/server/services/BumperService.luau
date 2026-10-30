--!strict
-- Bumper PvP autoritaire (CDC §5, §6, Sprint 2) : à 10 Hz, le serveur cherche les contacts entre joueurs,
-- décide avec Bumper qui éjecte qui, puis applique lui-même l'impulsion. Pendant le tournis (0,8 s), il
-- reprend la propriété physique de la cible pour que le client ne puisse pas annuler l'éjection.
-- La cible ne perd jamais son blé ; elle gagne 15 s d'immunité, matérialisées par une bulle.
-- Dépendances : VehicleService (engins), Bumper / Formulas (règles pures).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BumperConfig = require(ReplicatedStorage.Shared.config.BumperConfig)
local Bumper = require(ReplicatedStorage.Shared.domain.Bumper)
local Formulas = require(ReplicatedStorage.Shared.domain.Formulas)
local MapGeometry = require(ReplicatedStorage.Shared.domain.MapGeometry)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local RateLimiter = require(ReplicatedStorage.Shared.util.RateLimiter)
local VehicleService = require(script.Parent.VehicleService)

local BumperService = {}

type Contestant = { player: Player, root: BasePart, body: Bumper.Body }

local pairLimiter = RateLimiter.new(1, 1 / BumperConfig.PAIR_COOLDOWN)
local elapsed = 0

local function isActive(player: Player, attribute: string, now: number): boolean
	local untilTime = player:GetAttribute(attribute)
	return typeof(untilTime) == "number" and now < untilTime
end

local function contestantOf(player: Player, now: number): Contestant?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local tier = VehicleService.tierOf(player)
	local vehicle = VehicleService.bodyOf(player)
	local position, velocity = root.Position, root.AssemblyLinearVelocity
	local isProtected = isActive(player, PlayerAttributes.IMMUNE_UNTIL, now)
		or isActive(player, PlayerAttributes.DIZZY_UNTIL, now)
		or Bumper.isSafeZone(MapGeometry.zoneAt(position.X, position.Z))
	local radius = if vehicle then math.max(vehicle.Size.X, vehicle.Size.Z) / 2 else BumperConfig.ON_FOOT_RADIUS
	local body: Bumper.Body = {
		id = player.UserId,
		x = position.X,
		z = position.Z,
		vx = velocity.X,
		vz = velocity.Z,
		radius = radius,
		mass = Formulas.effectiveMass(tier.mass, 0, false), -- Rebirths (Sprint 4) et Titan (Sprint 8) à venir
		isVehicle = vehicle ~= nil,
		isProtected = isProtected,
	}
	return { player = player, root = root, body = body }
end

-- Bulle d'immunité visible de tous (CDC §6) : une sphère soudée, détruite à la fin de l'immunité.
local function showBubble(root: BasePart, radius: number)
	local diameter = 2 * (radius + BumperConfig.BUBBLE_PADDING)
	local bubble = Instance.new("Part")
	bubble.Name = "ImmunityBubble"
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.one * diameter
	bubble.Material = Enum.Material.ForceField
	bubble.Color = Bricks.rgb(BumperConfig.BUBBLE_COLOR)
	bubble.Transparency = BumperConfig.BUBBLE_TRANSPARENCY
	bubble.Massless, bubble.CanCollide, bubble.CanQuery, bubble.CanTouch = true, false, false, false
	bubble.CFrame = root.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = root, bubble
	weld.Parent = bubble
	bubble.Parent = root.Parent
	task.delay(BumperConfig.IMMUNITY_SECONDS, bubble.Destroy, bubble)
end

-- Coupe ou rend le contrôle : contraintes de l'engin, ou Humanoid pour un joueur à pied.
local function setControlEnabled(player: Player, isEnabled: boolean)
	local vehicle = VehicleService.bodyOf(player)
	if vehicle then
		for _, name in { VehicleService.MOVER_NAME, VehicleService.ALIGNER_NAME } do
			local constraint = vehicle:FindFirstChild(name) :: Constraint?
			if constraint then
				constraint.Enabled = isEnabled
			end
		end
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = not isEnabled
	end
end

local function knock(target: Contestant, attacker: Contestant, collision: Bumper.Collision)
	local now = Workspace:GetServerTimeNow()
	local player, root = target.player, target.root
	player:SetAttribute(PlayerAttributes.DIZZY_UNTIL, now + BumperConfig.DIZZY_SECONDS)
	player:SetAttribute(PlayerAttributes.IMMUNE_UNTIL, now + BumperConfig.IMMUNITY_SECONDS)
	pcall(root.SetNetworkOwner, root, nil) -- le serveur simule l'éjection : le client ne peut pas l'annuler
	setControlEnabled(player, false)
	local horizontal, vertical = Bumper.launchSpeeds(collision.impactSpeed, attacker.body.mass, target.body.mass)
	root.AssemblyLinearVelocity = Vector3.new(collision.dirX * horizontal, vertical, collision.dirZ * horizontal)
	root.AssemblyAngularVelocity = Vector3.new(0, BumperConfig.DIZZY_SPIN_SPEED, 0)
	showBubble(root, target.body.radius)
	task.delay(BumperConfig.DIZZY_SECONDS, function()
		if root.Parent and player.Parent then
			setControlEnabled(player, true)
			pcall(root.SetNetworkOwner, root, player)
		end
	end)
end

local function pairKey(a: number, b: number): string
	return if a < b then `{a}:{b}` else `{b}:{a}`
end

local function detectCollisions()
	local now = Workspace:GetServerTimeNow()
	local contestants: { Contestant } = {}
	for _, player in Players:GetPlayers() do
		local contestant = contestantOf(player, now)
		if contestant then
			table.insert(contestants, contestant)
		end
	end
	for i = 1, #contestants - 1 do
		for j = i + 1, #contestants do
			local a, b = contestants[i], contestants[j]
			local collision = Bumper.detect(a.body, b.body)
			if collision and pairLimiter:allow(pairKey(a.body.id, b.body.id), now) then
				local isAAttacker = collision.attackerId == a.body.id
				knock(if isAAttacker then b else a, if isAAttacker then a else b, collision)
			end
		end
	end
end

function BumperService:Start()
	RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= BumperConfig.DETECTION_INTERVAL then
			elapsed = 0
			detectCollisions()
		end
	end)
end

-- Masse PvP utilisée par la formule de knockback (exposée pour les futurs objets de sabotage, Sprint 5).
function BumperService.massOf(player: Player): number
	return Formulas.effectiveMass(VehicleService.tierOf(player).mass, 0, false)
end

return BumperService
