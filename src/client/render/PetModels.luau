--!strict
-- Modèles de Pets côté client, construits à partir de PetVisualConfig (CDC §7.2 « Pets cubiques »).
-- Pièces ancrées et sans collision : le suiveur (PetFollowerController) les déplace avec PivotTo.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetVisualConfig = require(ReplicatedStorage.Shared.config.PetVisualConfig)
local Pets = require(ReplicatedStorage.Shared.domain.Pets)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)

local PetModels = {}

PetModels.MAIN_ATTRIBUTE = "IsMain"

local function vector(values: { number }): Vector3
	return Vector3.new(values[1], values[2], values[3])
end

-- Construit le Pet `key` à l'échelle `scale`, origine au sol, avant vers -Z.
function PetModels.build(key: string, scale: number): Model?
	local species, variant = Pets.parse(key)
	if not species or not variant then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = key
	local anchor = Instance.new("Part")
	anchor.Name = "Anchor"
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Parent = model
	model.PrimaryPart = anchor
	local goldColor = PetVisualConfig.VARIANT_COLORS.Gold
	for k, piece in PetVisualConfig.SPECIES[species.id] do
		local isGold = piece.isMain == true and variant.id == "Gold"
		local part = Bricks.decor(`Piece{k}`, vector(piece.size) * scale, if isGold then goldColor else piece.color)
		part.CFrame = CFrame.new(vector(piece.offset) * scale)
		if piece.shape then
			part.Shape = (Enum.PartType :: any)[piece.shape]
		end
		if piece.material then
			part.Material = (Enum.Material :: any)[piece.material]
		end
		if isGold then
			part.Reflectance = PetVisualConfig.GOLD_REFLECTANCE
		end
		part:SetAttribute(PetModels.MAIN_ATTRIBUTE, piece.isMain == true)
		part.Parent = model
	end
	return model
end

return PetModels
