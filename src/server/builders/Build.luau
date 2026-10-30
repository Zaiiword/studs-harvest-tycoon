--!strict
-- Briques élémentaires pour les modèles du décor, des machines et des véhicules (style Bricks, CDC §2).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bricks = require(ReplicatedStorage.Shared.util.Bricks)

local Build = {}

export type BlockSpec = {
	name: string,
	cframe: CFrame,
	size: Vector3,
	color: { number },
}

-- Brique ancrée et collidable.
function Build.block(parent: Instance, spec: BlockSpec): Part
	local part = Instance.new("Part")
	part.Name = spec.name
	part.Anchored = true
	part.Size = spec.size
	part.CFrame = spec.cframe
	Bricks.style(part, spec.color)
	part.Parent = parent
	return part
end

export type SpanSpec = {
	name: string,
	from: Vector3, -- l'altitude de `from` est celle du bas de la brique
	to: Vector3,
	thickness: number,
	height: number,
	color: { number },
}

-- Brique tendue entre deux points du plan (x, z). Elle déborde de `thickness / 2` à chaque bout pour que
-- deux segments consécutifs se rejoignent sans trou.
function Build.span(parent: Instance, spec: SpanSpec): Part
	local flatFrom, flatTo = Vector3.new(spec.from.X, 0, spec.from.Z), Vector3.new(spec.to.X, 0, spec.to.Z)
	local offset = flatTo - flatFrom
	local middle = (flatFrom + flatTo) / 2 + Vector3.new(0, spec.from.Y + spec.height / 2, 0)
	local direction = if offset.Magnitude > 1e-6 then offset.Unit else Vector3.zAxis
	return Build.block(parent, {
		name = spec.name,
		cframe = CFrame.lookAt(middle, middle + direction),
		size = Vector3.new(spec.thickness, spec.height, offset.Magnitude + spec.thickness),
		color = spec.color,
	})
end

-- Décoration soudée à une pièce mobile (véhicule) : sans masse ni collision.
function Build.attached(anchor: BasePart, spec: BlockSpec): Part
	local part = Instance.new("Part")
	part.Name = spec.name
	part.Size = spec.size
	part.CFrame = anchor.CFrame * spec.cframe
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	Bricks.style(part, spec.color)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = anchor, part
	weld.Parent = part
	part.Parent = anchor
	return part
end

-- Panneau texte collé sur une face d'une pièce (enseignes, portiques).
function Build.sign(part: BasePart, face: Enum.NormalId, text: string, color: { number }): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Bricks.rgb(color)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	gui.Parent = part
	return label
end

return Build
