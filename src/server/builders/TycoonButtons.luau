--!strict
-- Boutons au sol de l'usine façon grands tycoons (CDC §7.1, §10 ; A53) : socle sombre, plaque colorée, anneau
-- néon qui brille quand on peut payer, et panneau flottant (icône, nom, prix) en dégradé. Un bouton épuisé
-- disparaît. Les panneaux d'information (machines, déchargement) reprennent le même style.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TycoonConfig = require(ReplicatedStorage.Shared.config.TycoonConfig)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Build = require(script.Parent.Build)

local TycoonButtons = {}

export type State = "affordable" | "expensive" | "rebirth" | "locked" | "soldout"
export type View = { state: State, title: string, price: string? }
export type Pad = {
	top: Part, -- plaque sur laquelle on marche (porte les attributs lus par les flèches)
	parts: { BasePart },
	ring: { BasePart },
	gui: BillboardGui,
	gradient: UIGradient,
	title: TextLabel,
	price: TextLabel,
}
export type Label = { gradient: UIGradient, title: TextLabel, price: TextLabel }

local STYLE = TycoonConfig.PAD_STYLE
local LAYOUT = TycoonConfig.LAYOUT
local FONT = (Enum.Font :: any)[UiConfig.FONT] :: Enum.Font
local RIM_COLOR = UiConfig.WINDOW.STROKE_COLOR
local ICON_SHARE = 0.3 -- part du panneau occupée par l'icône
local PANEL_STROKE = 4

local function text(parent: Instance, size: UDim2, position: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size, label.Position = size, position
	label.Font = FONT
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = UiConfig.STROKE_THICKNESS
	stroke.Parent = label
	label.Parent = parent
	return label
end

-- Panneau flottant : icône à gauche, nom et prix à droite, sur un dégradé de la couleur de l'état.
function TycoonButtons.label(part: BasePart, icon: string, heightAbove: number): Label
	local gui = Instance.new("BillboardGui")
	gui.Name = "Panel"
	gui.Size = UDim2.fromScale(STYLE.LABEL_SIZE[1], STYLE.LABEL_SIZE[2])
	gui.StudsOffset = Vector3.new(0, heightAbove, 0)
	gui.MaxDistance = TycoonConfig.LABEL.MAX_DISTANCE
	gui.LightInfluence = 0
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.new(1, 1, 1)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = PANEL_STROKE
	stroke.Color = Bricks.rgb(RIM_COLOR)
	stroke.Parent = panel
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Parent = panel
	panel.Parent = gui
	text(panel, UDim2.fromScale(ICON_SHARE, 0.9), UDim2.fromScale(0.02, 0.05)).Text = icon
	local title = text(panel, UDim2.fromScale(1 - ICON_SHARE - 0.05, 0.48), UDim2.fromScale(ICON_SHARE, 0.06))
	local price = text(panel, UDim2.fromScale(1 - ICON_SHARE - 0.05, 0.4), UDim2.fromScale(ICON_SHARE, 0.54))
	gui.Parent = part
	return { gradient = gradient, title = title, price = price }
end

function TycoonButtons.paint(label: Label, styleName: string, title: string, price: string)
	local colors = STYLE.STATES[styleName]
	label.gradient.Color = ColorSequence.new(Bricks.rgb(colors.top), Bricks.rgb(colors.bottom))
	label.title.Text = title
	label.price.Text = price
end

-- Anneau néon : quatre baguettes posées sur le bord de la plaque.
local function buildRing(model: Model, origin: CFrame, top: number): { BasePart }
	local size, width = LAYOUT.PAD_SIZE, STYLE.RING_WIDTH
	local ring: { BasePart } = {}
	for _, side in { -1, 1 } do
		for _, isAlongX in { true, false } do
			local offset = side * (size / 2 - width / 2)
			local cframe = origin * CFrame.new(if isAlongX then 0 else offset, top, if isAlongX then offset else 0)
			local bar = Build.block(model, {
				name = "Ring",
				cframe = cframe,
				size = if isAlongX then Vector3.new(size, 0.1, width) else Vector3.new(width, 0.1, size),
				color = STYLE.STATES.affordable.ring,
			})
			bar.CanCollide = false
			bar.Material = Enum.Material.Neon
			table.insert(ring, bar)
		end
	end
	return ring
end

-- `origin` : centre du bouton au niveau du pont de la base, orienté comme la base.
function TycoonButtons.build(parent: Instance, buttonId: string, origin: CFrame): Pad
	local model = Instance.new("Model")
	model.Name = `Pad{buttonId}`
	local rimSize = LAYOUT.PAD_SIZE + STYLE.RIM_MARGIN
	local rim = Build.block(model, {
		name = "Rim",
		cframe = origin * CFrame.new(0, STYLE.RIM_HEIGHT / 2, 0),
		size = Vector3.new(rimSize, STYLE.RIM_HEIGHT, rimSize),
		color = RIM_COLOR,
	})
	local top = Build.block(model, {
		name = `Pad{buttonId}`,
		cframe = origin * CFrame.new(0, STYLE.RIM_HEIGHT + LAYOUT.PAD_THICKNESS / 2, 0),
		size = Vector3.new(LAYOUT.PAD_SIZE, LAYOUT.PAD_THICKNESS, LAYOUT.PAD_SIZE),
		color = STYLE.STATES.affordable.bottom,
	})
	local ring = buildRing(model, origin, STYLE.RIM_HEIGHT + LAYOUT.PAD_THICKNESS + 0.05)
	model.PrimaryPart = top
	model.Parent = parent
	local label = TycoonButtons.label(top, STYLE.ICONS[buttonId] or "⭐", STYLE.LABEL_HEIGHT_ABOVE)
	local parts: { BasePart } = { rim, top }
	for _, bar in ring do
		table.insert(parts, bar)
	end
	return {
		top = top,
		parts = parts,
		ring = ring,
		gui = top:FindFirstChildOfClass("BillboardGui") :: BillboardGui,
		gradient = label.gradient,
		title = label.title,
		price = label.price,
	}
end

-- Met le bouton à jour ; un bouton épuisé disparaît (et ne bloque plus le passage).
function TycoonButtons.update(pad: Pad, view: View)
	local isVisible = view.state ~= "soldout"
	for _, part in pad.parts do
		part.Transparency = if isVisible then 0 else 1
		part.CanCollide = isVisible and not table.find(pad.ring, part)
	end
	pad.gui.Enabled = isVisible
	if not isVisible then
		return
	end
	local colors = STYLE.STATES[view.state]
	pad.top.Color = Bricks.rgb(colors.bottom)
	for _, bar in pad.ring do
		bar.Color = Bricks.rgb(colors.ring)
		bar.Material = if view.state == "locked" then Enum.Material.SmoothPlastic else Enum.Material.Neon
	end
	TycoonButtons.paint(
		{ gradient = pad.gradient, title = pad.title, price = pad.price },
		view.state,
		view.title,
		view.price or ""
	)
end

return TycoonButtons
