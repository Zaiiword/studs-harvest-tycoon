--!strict
-- Engins des paliers 3 à 7 (CDC §5, Sprint 2) : une carrosserie soudée au HumanoidRootPart (WeldConstraint),
-- déplacée par LinearVelocity et orientée par AlignOrientation. Le client pilote ces contraintes
-- (VehicleController) car il possède physiquement son personnage ; le serveur construit l'engin, surveille
-- la vitesse (anti-triche) et reprend la main pendant une éjection (BumperService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VehicleConfig = require(ReplicatedStorage.Shared.config.VehicleConfig)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Trove = require(ReplicatedStorage.Packages.Trove)
local VehicleModels = require(script.Parent.Parent.builders.VehicleModels)

local VehicleService = {}

VehicleService.BODY_NAME = VehicleConfig.PARTS.BODY
VehicleService.MOVER_NAME = VehicleConfig.PARTS.MOVER
VehicleService.ALIGNER_NAME = VehicleConfig.PARTS.ALIGNER

local HANDLING = VehicleConfig.HANDLING
local SPEED_CHECK_INTERVAL = VehicleConfig.SPEED_CHECK_INTERVAL

local troves: { [Player]: any } = {}

function VehicleService.tierOf(player: Player): VehicleConfig.TierDef
	local id = player:GetAttribute(PlayerAttributes.TIER)
	return VehicleConfig.TIERS[if typeof(id) == "number" then id else 1] or VehicleConfig.TIERS[1]
end

function VehicleService.bodyOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild(VehicleService.BODY_NAME) :: BasePart?
end

local function newBody(def: VehicleConfig.BodyDef): Part
	local body = Instance.new("Part")
	body.Name = VehicleService.BODY_NAME
	body.Size = Vector3.new(def.width, def.height, def.length)
	body.CustomPhysicalProperties = PhysicalProperties.new(1, HANDLING.FRICTION, 0, 100, 1)
	Bricks.style(body, def.color)
	return body
end

local function addConstraints(body: Part)
	local attachment = Instance.new("Attachment")
	attachment.Parent = body
	local mover = Instance.new("LinearVelocity")
	mover.Name = VehicleService.MOVER_NAME
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane -- la gravité reste libre sur Y
	mover.PrimaryTangentAxis = Vector3.xAxis
	mover.SecondaryTangentAxis = Vector3.zAxis
	mover.PlaneVelocity = Vector2.zero
	-- Force illimitée : l'engin suit exactement la consigne. Une force proportionnelle à AssemblyMass était
	-- lue avant que la soudure soit prise en compte et valait presque zéro (véhicule immobile).
	mover.MaxForce = math.huge
	mover.Parent = body
	local aligner = Instance.new("AlignOrientation")
	aligner.Name = VehicleService.ALIGNER_NAME
	aligner.Mode = Enum.OrientationAlignmentMode.OneAttachment
	aligner.Attachment0 = attachment
	aligner.Responsiveness = HANDLING.ALIGN_RESPONSIVENESS
	aligner.MaxTorque = math.huge
	aligner.Parent = body
end

local function removeVehicle(character: Model)
	local body = character:FindFirstChild(VehicleService.BODY_NAME)
	if body then
		body:Destroy()
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
	end
end

-- Le pilote est soudé au-dessus de la carrosserie, orientée comme lui (CDC §5 « personnage soudé »).
local function mountVehicle(character: Model, tier: VehicleConfig.TierDef, def: VehicleConfig.BodyDef)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		warn(`[VehicleService] montage impossible : HumanoidRootPart ou Humanoid absent sur {character.Name}`)
		return
	end
	-- On soulève d'abord le pilote de la hauteur de l'engin, sinon la carrosserie naîtrait dans le sol.
	character:PivotTo(character:GetPivot() + Vector3.new(0, HANDLING.SEAT_HEIGHT + def.height, 0))
	local body = newBody(def)
	body.CFrame = root.CFrame * CFrame.new(0, -(root.Size.Y / 2 + HANDLING.SEAT_HEIGHT + def.height / 2), 0)
	VehicleModels.decorate(body, tier, def)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = body, root
	weld.Parent = body
	addConstraints(body)
	body.Parent = character
	humanoid.PlatformStand = true -- l'Humanoid ne doit pas lutter contre LinearVelocity
	-- Le pilote doit simuler lui-même son engin pour que ses consignes LinearVelocity s'appliquent.
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		pcall(root.SetNetworkOwner, root, player)
	end
end

local function refreshVehicle(player: Player)
	local character = player.Character
	if not character then
		return
	end
	removeVehicle(character)
	local tier = VehicleService.tierOf(player)
	local def = VehicleConfig.BODIES[tier.id]
	if tier.isVehicle and def then
		local ok, err = pcall(mountVehicle, character, tier, def)
		if not ok then
			warn(`[VehicleService] échec du montage du palier {tier.id} : {err}`)
		end
	end
end

local function onPlayerAdded(player: Player)
	local trove = Trove.new()
	troves[player] = trove
	trove:Connect(player:GetAttributeChangedSignal(PlayerAttributes.TIER), function()
		refreshVehicle(player)
	end)
	trove:Connect(player.CharacterAdded, function(character: Model)
		character:WaitForChild("HumanoidRootPart", 5)
		refreshVehicle(player)
	end)
	if player.Character then
		task.spawn(refreshVehicle, player)
	end
end

local function onPlayerRemoving(player: Player)
	local trove = troves[player]
	if trove then
		trove:Destroy()
		troves[player] = nil
	end
end

-- Anti-triche minimal : le client pilote son engin, le serveur vérifie qu'il ne dépasse pas sa vitesse.
-- Pour l'instant on journalise seulement (sanction au Sprint 8, une fois les seuils mesurés en jeu).
local function checkSpeeds()
	local now = Workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		local body = VehicleService.bodyOf(player)
		local dizzyUntil = player:GetAttribute(PlayerAttributes.DIZZY_UNTIL)
		local isKnocked = typeof(dizzyUntil) == "number" and now < dizzyUntil + SPEED_CHECK_INTERVAL
		if body and not isKnocked then
			local velocity = body.AssemblyLinearVelocity
			local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			if horizontal > VehicleService.tierOf(player).speed * VehicleConfig.SPEED_TOLERANCE then
				warn(`[VehicleService] vitesse suspecte {math.floor(horizontal)} studs/s pour {player.UserId}`)
			end
		end
	end
end

function VehicleService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		if not troves[player] then
			onPlayerAdded(player)
		end
	end
	task.spawn(function()
		while true do
			task.wait(SPEED_CHECK_INTERVAL)
			checkSpeeds()
		end
	end)
end

return VehicleService
