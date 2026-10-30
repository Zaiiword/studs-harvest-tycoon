--!strict
-- Éclairage ensoleillé et MaterialVariant Lego (CDC §2, Sprint 0 « rendu Lego actif »).
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetIds = require(ReplicatedStorage.Shared.config.AssetIds)
local DecorConfig = require(ReplicatedStorage.Shared.config.DecorConfig)
local RenderConfig = require(ReplicatedStorage.Shared.config.RenderConfig)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)

local RenderService = {}

local function applyLighting()
	local config = RenderConfig.LIGHTING
	Lighting.Brightness = config.BRIGHTNESS
	Lighting.ColorShift_Top = Bricks.rgb(config.COLOR_SHIFT_TOP)
	Lighting.OutdoorAmbient = Bricks.rgb(config.OUTDOOR_AMBIENT)
	Lighting.ClockTime = config.CLOCK_TIME
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = RenderConfig.ATMOSPHERE.DENSITY
	atmosphere.Haze = RenderConfig.ATMOSPHERE.HAZE
	atmosphere.Color = Bricks.rgb(RenderConfig.ATMOSPHERE.COLOR)
	atmosphere.Parent = Lighting
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

-- Couleurs saturées et léger éclat (CDC §2), sans dénaturer les couleurs Lego.
local function applyPostProcessing()
	local post = DecorConfig.POST
	local correction = Instance.new("ColorCorrectionEffect")
	correction.Saturation = post.SATURATION
	correction.Contrast = post.CONTRAST
	correction.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = post.BLOOM_INTENSITY
	bloom.Size = post.BLOOM_SIZE
	bloom.Threshold = post.BLOOM_THRESHOLD
	bloom.Parent = Lighting
	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Intensity = post.SUN_RAYS_INTENSITY
	sunRays.Parent = Lighting
end

function RenderService:Init()
	applyLighting()
	applyPostProcessing()
	createStudsVariant()
end

return RenderService
