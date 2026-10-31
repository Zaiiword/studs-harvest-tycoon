--!strict
-- Bumper PvP autoritaire (CDC §5, §6, Sprints 2 et 5) : à 10 Hz, le serveur cherche les contacts entre joueurs,
-- décide avec Bumper qui éjecte qui, puis applique lui-même l'impulsion. Pendant le tournis, il reprend la
-- propriété physique de la cible pour que le client ne puisse pas annuler l'éjection.
-- La cible ne perd jamais son blé ; elle gagne 15 s d'immunité, matérialisées par une bulle.
-- Expose `contestants`, `eject` et `spin` aux objets de sabotage (SabotageService), qui respectent ainsi les
-- mêmes règles d'immunité. La Tempête de Vent amplifie les chocs (CDC §6).
-- Dépendances : VehicleService (engins), Bumper / Formulas / Weather (règles pures).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BumperConfig = require(ReplicatedStorage.Shared.config.BumperConfig)
local Bumper = require(ReplicatedStorage.Shared.domain.Bumper)
local Formulas = require(ReplicatedStorage.Shared.domain.Formulas)
local MapGeometry = require(ReplicatedStorage.Shared.domain.MapGeometry)
local Weather = require(ReplicatedStorage.Shared.domain.Weather)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local WorldAttributes = require(ReplicatedStorage.Shared.net.WorldAttributes)
local Perks = require(ReplicatedStorage.Shared.net.Perks)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local RateLimiter = require(ReplicatedStorage.Shared.util.RateLimiter)
local VehicleService = require(script.Parent.VehicleService)
local Signal = require(ReplicatedStorage.Packages.Signal)

local BumperService = {}

export type Contestant = { player: Player, root: BasePart, body: Bumper.Body }

export type Ejection = {
	dirX: number,
	dirZ: number,
	horizontal: number,
	vertical: number,
	attacker: Player?, -- auteur du choc ou de l'objet (statue « Roi du Pare-Chocs », quêtes)
}

BumperService.Ejected = Signal.new() -- (attaquant, cible) : écouté par la rétention

local pairLimiter = RateLimiter.new(1, 1 / BumperConfig.PAIR_COOLDOWN)
local elapsed = 0

local function isActive(player: Player, attribute: string, now: number): boolean
	local untilTime = player:GetAttribute(attribute)
	return typeof(untilTime) == "number" and now < untilTime
end

-- Masse PvP utilisée par la formule de knockback : +15 % par Rebirth, comptés une seule fois (A15).
function BumperService.massOf(player: Player): number
	local rebirths = player:GetAttribute(PlayerAttributes.REBIRTHS)
	local count = if typeof(rebirths) == "number" then rebirths else 0
	return Formulas.effectiveMass(VehicleService.tierOf(player).mass, count, Perks.hasPass(player, "Titan")) -- CDC §9 : ×2,5
end

local function contestantOf(player: Player, now: number): Contestant?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
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
		mass = BumperService.massOf(player),
		isVehicle = vehicle ~= nil,
		isProtected = isProtected,
	}
	return { player = player, root = root, body = body }
end

-- Tous les joueurs présents, décrits pour les règles pures (Bumper, Sabotage).
function BumperService.contestants(): { Contestant }
	local now = Workspace:GetServerTimeNow()
	local list: { Contestant } = {}
	for _, player in Players:GetPlayers() do
		local contestant = contestantOf(player, now)
		if contestant then
			table.insert(list, contestant)
		end
	end
	return list
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

-- Tournis : le serveur prend la main, fait tourner la cible, puis lui rend le contrôle après `seconds`.
-- La cible gagne la bulle d'immunité : aucune éjection ne peut s'enchaîner sur elle.
local function stun(target: Contestant, seconds: number): BasePart
	local now = Workspace:GetServerTimeNow()
	local player, root = target.player, target.root
	player:SetAttribute(PlayerAttributes.DIZZY_UNTIL, now + seconds)
	player:SetAttribute(PlayerAttributes.IMMUNE_UNTIL, now + BumperConfig.IMMUNITY_SECONDS)
	pcall(root.SetNetworkOwner, root, nil) -- le serveur simule : le client ne peut pas annuler l'effet
	setControlEnabled(player, false)
	root.AssemblyAngularVelocity = Vector3.new(0, BumperConfig.DIZZY_SPIN_SPEED, 0)
	showBubble(root, target.body.radius)
	task.delay(seconds, function()
		if root.Parent and player.Parent then
			setControlEnabled(player, true)
			pcall(root.SetNetworkOwner, root, player)
		end
	end)
	return root
end

-- Multiplicateur d'éjection de la météo en cours (Tempête de Vent ×1,5).
local function weatherKnockback(): number
	local weather = ReplicatedStorage:GetAttribute(WorldAttributes.WEATHER)
	return Weather.byId(if typeof(weather) == "string" then weather else "Clear").knockbackMultiplier
end

-- Éjecte une cible (choc ou objet de sabotage). Ne fait rien si elle est protégée.
function BumperService.eject(target: Contestant, ejection: Ejection): boolean
	if target.body.isProtected then
		return false
	end
	local root = stun(target, BumperConfig.DIZZY_SECONDS)
	local boost = weatherKnockback()
	local horizontal = ejection.horizontal * boost
	root.AssemblyLinearVelocity =
		Vector3.new(ejection.dirX * horizontal, ejection.vertical * boost, ejection.dirZ * horizontal)
	if ejection.attacker then
		BumperService.Ejected:Fire(ejection.attacker, target.player)
	end
	return true
end

-- Fait tourner une cible sur elle-même sans l'éjecter (Flaque de Boue, CDC §6).
function BumperService.spin(target: Contestant, seconds: number): boolean
	if target.body.isProtected then
		return false
	end
	stun(target, seconds)
	return true
end

local function pairKey(a: number, b: number): string
	return if a < b then `{a}:{b}` else `{b}:{a}`
end

local function resolve(target: Contestant, attacker: Contestant, collision: Bumper.Collision)
	local horizontal, vertical = Bumper.launchSpeeds(collision.impactSpeed, attacker.body.mass, target.body.mass)
	BumperService.eject(target, {
		dirX = collision.dirX,
		dirZ = collision.dirZ,
		horizontal = horizontal,
		vertical = vertical,
		attacker = attacker.player,
	})
end

local function detectCollisions()
	local now = Workspace:GetServerTimeNow()
	local contestants = BumperService.contestants()
	for i = 1, #contestants - 1 do
		for j = i + 1, #contestants do
			local a, b = contestants[i], contestants[j]
			local collision = Bumper.detect(a.body, b.body)
			if collision and pairLimiter:allow(pairKey(a.body.id, b.body.id), now) then
				local isAAttacker = collision.attackerId == a.body.id
				resolve(if isAAttacker then b else a, if isAAttacker then a else b, collision)
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

return BumperService
