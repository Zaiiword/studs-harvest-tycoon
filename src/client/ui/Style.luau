--!strict
-- Briques de style « Studs Pop » (CDC §10) partagées par les menus : coins arrondis, contours épais,
-- dégradés et gros textes contourrés, comme dans les jeux Roblox les plus joués.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)

local Style = {}

Style.FONT = (Enum.Font :: any)[UiConfig.FONT] :: Enum.Font

local WHITE = Color3.new(1, 1, 1)
local VERTICAL = 90 -- rotation d'un UIGradient du haut vers le bas
local SHINE_TRANSPARENCY = NumberSequence.new(0.6, 1)

function Style.corner(gui: GuiObject, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = gui
end

function Style.stroke(gui: GuiObject, rgb: { number }, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = Bricks.rgb(rgb)
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border -- contour du cadre, pas du texte
	stroke.Parent = gui
	return stroke
end

-- Dégradé vertical : le fond (ou le texte) passe de `top` à `bottom`. La couleur de base devient blanche.
function Style.gradient(gui: GuiObject, top: { number }, bottom: { number }): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Bricks.rgb(top), Bricks.rgb(bottom))
	gradient.Rotation = VERTICAL
	gradient.Parent = gui
	if gui:IsA("TextLabel") or gui:IsA("TextButton") then
		gui.TextColor3 = WHITE
	end
	gui.BackgroundColor3 = WHITE
	return gradient
end

-- Gros texte blanc contouré de noir, à la taille de son cadre.
function Style.label(parent: Instance, text: string, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Font = Style.FONT
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = WHITE
	label.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = UiConfig.STROKE_THICKNESS
	stroke.Color = Bricks.rgb(UiConfig.STROKE_COLOR)
	stroke.Parent = label
	label.Parent = parent
	return label
end

-- Bouton « bonbon » : dégradé, coins ronds, contour sombre ; le texte est un label contouré enfant.
function Style.button(parent: Instance, colors: { top: { number }, bottom: { number }, edge: { number } }): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.Text = ""
	Style.corner(button, UDim.new(0, UiConfig.CORNER_RADIUS))
	Style.gradient(button, colors.top, colors.bottom)
	Style.stroke(button, colors.edge, UiConfig.STROKE_THICKNESS)
	button.Parent = parent
	return button
end

-- Reflet clair sur la moitié haute d'un bouton ou d'une carte : l'effet « bonbon » des boutiques Roblox.
function Style.shine(parent: GuiObject)
	local shine = Instance.new("Frame")
	shine.Size = UDim2.fromScale(1, 0.5)
	shine.BackgroundColor3 = WHITE
	shine.BorderSizePixel = 0
	Style.corner(shine, UDim.new(0, UiConfig.CORNER_RADIUS))
	local fade = Instance.new("UIGradient")
	fade.Rotation = VERTICAL
	fade.Transparency = SHINE_TRANSPARENCY
	fade.Parent = shine
	shine.Parent = parent
end

-- Taille max d'un texte « TextScaled », pour garder des tailles homogènes sur une même carte.
function Style.maxTextSize(label: TextLabel, size: number)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = size
	constraint.Parent = label
end

return Style
