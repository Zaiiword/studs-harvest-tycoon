--!strict
-- Style « Classic Studs » commun à toutes les briques du monde (CDC §2) : tenons sur le dessus,
-- inlets sur les flancs, et MaterialVariant Lego quand une texture est configurée (décision A25).
local AssetIds = require("../config/AssetIds")
local RenderConfig = require("../config/RenderConfig")

local Bricks = {}

local hasStudsVariant = AssetIds.STUDS_COLOR_MAP ~= "" or AssetIds.STUDS_NORMAL_MAP ~= ""

function Bricks.rgb(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

function Bricks.style(part: BasePart, rgb: { number })
	part.Color = Bricks.rgb(rgb)
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Inlet
	part.FrontSurface = Enum.SurfaceType.Inlet
	part.BackSurface = Enum.SurfaceType.Inlet
	part.LeftSurface = Enum.SurfaceType.Inlet
	part.RightSurface = Enum.SurfaceType.Inlet
	if hasStudsVariant then
		part.MaterialVariant = RenderConfig.STUDS_MATERIAL_VARIANT
	end
end

-- Brique décorative ancrée, sans collision ni requêtes physiques (blé, briques volantes).
function Bricks.decor(name: string, size: Vector3, rgb: { number }): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	Bricks.style(part, rgb)
	return part
end

return Bricks
