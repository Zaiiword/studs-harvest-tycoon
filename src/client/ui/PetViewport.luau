--!strict
-- Pet en 3D dans l'interface (CDC §7.2, §10) : le modèle en briques de PetModels, cadré de trois quarts face
-- dans un ViewportFrame, comme les inventaires des jeux de Pets les plus joués.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local PetModels = require(script.Parent.Parent.render.PetModels)

local PetViewport = {}

export type View = { frame: ViewportFrame, model: Model, center: Vector3 }

local CAMERA = UiConfig.PET_MENU.CAMERA
local MODEL_SCALE = 1
local AMBIENT = Color3.fromRGB(200, 200, 200)

-- Fond transparent : la couleur de la carte (rareté) reste visible derrière le Pet.
function PetViewport.new(parent: Instance, key: string): View?
	local model = PetModels.build(key, MODEL_SCALE)
	if not model then
		return nil
	end
	local frame = Instance.new("ViewportFrame")
	frame.BackgroundTransparency = 1
	frame.Ambient = AMBIENT
	frame.LightDirection = Vector3.new(-1, -1, -1)
	model.Parent = frame
	local box, size = model:GetBoundingBox()
	local reach = math.max(size.X, size.Y, size.Z) * CAMERA.distance
	local camera = Instance.new("Camera")
	camera.FieldOfView = CAMERA.fov
	-- L'avant d'un Pet est -Z : la caméra se place devant lui, un peu de côté et au-dessus.
	local eye = box.Position + Vector3.new(CAMERA.side, CAMERA.height, -1).Unit * reach
	camera.CFrame = CFrame.lookAt(eye, box.Position)
	camera.Parent = frame
	frame.CurrentCamera = camera
	frame.Parent = parent
	return { frame = frame, model = model, center = box.Position }
end

-- Fait pivoter le Pet sur lui-même (fiche détaillée).
function PetViewport.turn(view: View, angle: number)
	local pivot = view.model:GetPivot()
	view.model:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(0, angle, 0))
end

return PetViewport
