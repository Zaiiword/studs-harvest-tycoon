--!strict
-- Éclairage ensoleillé et MaterialVariant Lego (CDC §2, Sprint 0 « rendu Lego actif »).
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetIds = require(ReplicatedStorage.Shared.config.AssetIds)
local RenderConfig = require(ReplicatedStorage.Shared.config.RenderConfig)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)

local RenderService = {}

local function applyLighting()
	local config = RenderConfig.LIGHTING
	Lighting.Brightness = config.BRIGHTNESS
	Lighting.ColorShift_Top = Bricks.rgb(config.COLOR_SHIFT_TOP)
	Lighting.OutdoorAmbient = Bricks.rgb(config.OUTDOOR_AMBIENT)
	Lighting.ClockTime = config.CLOCK_TIME
end

-- Sans texture configurée, on garde les surfaces Studs/Inlet natives (voir Bricks et décision A25).
local function createStudsVariant()
	if AssetIds.STUDS_COLOR_MAP == "" and AssetIds.STUDS_NORMAL_MAP == "" then
		return
	end
	local variant = Instance.new("MaterialVariant")
	variant.Name = RenderConfig.STUDS_MATERIAL_VARIANT
	variant.BaseMaterial = Enum.Material.Plastic
	variant.ColorMap = AssetIds.STUDS_COLOR_MAP
	variant.NormalMap = AssetIds.STUDS_NORMAL_MAP
	variant.StudsPerTile = RenderConfig.STUDS_TEXTURE_SIZE
	variant.Parent = MaterialService
end

function RenderService:Init()
	applyLighting()
	createStudsVariant()
end

return RenderService
