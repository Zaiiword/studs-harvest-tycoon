--!strict
-- Modèles des événements (CDC §6) : Épi Géant de Cristal du boss Météorite, balise du hotspot,
-- flaque de boue. Tous ancrés ; le boss porte une barre de PV au-dessus de lui.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventConfig = require(ReplicatedStorage.Shared.config.EventConfig)
local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local SabotageConfig = require(ReplicatedStorage.Shared.config.SabotageConfig)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Build = require(script.Parent.Build)

local EventModels = {}

local METEOR = EventConfig.METEOR
local CRATER_COLOR = { 27, 42, 53 }
local SHARD_TILT = 0.45

export type BossModel = { model: Model, hpLabel: TextLabel }

local function crystal(parent: Instance, cframe: CFrame, size: Vector3): Part
	local part = Build.block(parent, { name = "Crystal", cframe = cframe, size = size, color = METEOR.COLOR })
	part.Material = Enum.Material.Glass
	part.Transparency = 0.15
	return part
end

-- Épi Géant de Cristal planté dans un cratère, au centre de l'arène.
function EventModels.meteor(parent: Instance, x: number, z: number): BossModel
	local model = Instance.new("Model")
	model.Name = "MeteorBoss"
	local top = MapConfig.FLOOR_TOP
	local craterDiameter = METEOR.WIDTH * 2.5
	local crater = Build.block(model, {
		name = "Crater",
		cframe = CFrame.new(x, top + 0.2, z) * CFrame.Angles(0, 0, math.pi / 2), -- cylindre couché à plat
		size = Vector3.new(0.4, craterDiameter, craterDiameter),
		color = CRATER_COLOR,
	})
	crater.Shape = Enum.PartType.Cylinder
	local base = CFrame.new(x, top, z)
	local core = crystal(
		model,
		base * CFrame.new(0, METEOR.HEIGHT / 2, 0) * CFrame.Angles(0, math.pi / 4, 0),
		Vector3.new(METEOR.WIDTH, METEOR.HEIGHT, METEOR.WIDTH)
	)
	for _, side in { -1, 1 } do
		crystal(
			model,
			base
				* CFrame.new(side * METEOR.WIDTH * 0.7, METEOR.HEIGHT * 0.3, 0)
				* CFrame.Angles(0, 0, -side * SHARD_TILT),
			Vector3.new(METEOR.WIDTH * 0.5, METEOR.HEIGHT * 0.55, METEOR.WIDTH * 0.5)
		)
	end
	model.PrimaryPart = core
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(320, 60)
	gui.StudsOffset = Vector3.new(0, METEOR.HEIGHT / 2 + 6, 0)
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	gui.Parent = core
	model.Parent = parent
	return { model = model, hpLabel = label }
end

-- « Météorite invoquée par … » en lettres géantes au-dessus du boss (CDC §9). Le DisplayName est déjà
-- filtré par Roblox : aucun texte libre saisi par un joueur n'est affiché (docs/ANALYSE_CDC.md §4).
function EventModels.showSummoner(boss: BossModel, displayName: string)
	local core = boss.model.PrimaryPart
	if not core then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Summoner"
	gui.Size = UDim2.fromOffset(600, 90)
	gui.StudsOffset = Vector3.new(0, METEOR.HEIGHT / 2 + 16, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 2000
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 196, 0)
	label.TextStrokeTransparency = 0
	label.Text = `☄️ Météorite Dorée invoquée par {displayName} !`
	label.Parent = gui
	gui.Parent = core
end

-- Balise du hotspot : disque néon au sol et faisceau, pour qu'on le repère de loin (A11).
function EventModels.hotspot(parent: Instance): Model
	local spec = EventConfig.HOTSPOT
	local model = Instance.new("Model")
	model.Name = "Hotspot"
	local disc = Bricks.decor("Disc", Vector3.new(0.3, spec.RADIUS * 2, spec.RADIUS * 2), spec.COLOR)
	disc.Shape = Enum.PartType.Cylinder
	disc.Material = Enum.Material.Neon
	disc.Transparency = 0.5
	disc.Parent = model
	local beam = Bricks.decor("Beam", Vector3.new(1, spec.BEAM_HEIGHT, 1), spec.COLOR)
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.4
	beam.Parent = model
	model.PrimaryPart = disc
	model.Parent = parent
	return model
end

function EventModels.placeHotspot(model: Model, x: number, z: number)
	local disc, beam = model:FindFirstChild("Disc") :: BasePart, model:FindFirstChild("Beam") :: BasePart
	local top = MapConfig.FLOOR_TOP
	disc.CFrame = CFrame.new(x, top + 0.2, z) * CFrame.Angles(0, 0, math.pi / 2)
	beam.CFrame = CFrame.new(x, top + EventConfig.HOTSPOT.BEAM_HEIGHT / 2, z)
end

-- Flaque de boue posée au sol (CDC §6) : décorative, sans collision ; l'effet est géré par le serveur.
function EventModels.mud(parent: Instance, x: number, z: number): Part
	local spec = SabotageConfig.MUD
	local puddle = Bricks.decor("MudPuddle", Vector3.new(0.3, spec.RADIUS * 2, spec.RADIUS * 2), spec.COLOR)
	puddle.Shape = Enum.PartType.Cylinder
	puddle.CFrame = CFrame.new(x, MapConfig.DECK_TOP + 0.2, z) * CFrame.Angles(0, 0, math.pi / 2)
	puddle.Parent = parent
	return puddle
end

return EventModels
