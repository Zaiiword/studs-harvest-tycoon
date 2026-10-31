--!strict
-- Fenêtre de menu « premium » (CDC §10) : fond assombri, cadre en dégradé à gros contour, titre doré,
-- croix rouge dans le coin, ouverture qui rebondit. Se ferme par la croix, un clic à côté, Échap ou B (manette).
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Style = require(script.Parent.Style)

local Window = {}
Window.__index = Window

export type Window = typeof(setmetatable(
	{} :: {
		name: string,
		backdrop: TextButton,
		frame: Frame,
		scale: UIScale,
		body: Frame, -- zone claire sous l'en-tête : le contenu du menu va ici
		isOpen: boolean,
		onOpen: (() -> ())?,
	},
	Window
))

local STYLE = UiConfig.WINDOW
local OPEN = TweenInfo.new(STYLE.OPEN_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE = TweenInfo.new(STYLE.CLOSE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local CIRCLE = UDim.new(0.5, 0)
local TITLE_TEXT_SIZE = 44
local TITLE_STROKE = 4
local INSET = 10 -- marge entre le cadre et la zone de contenu

local openWindow: Window? = nil -- une seule fenêtre ouverte à la fois

-- Croix rouge ronde à poser dans le coin haut droit d'un cadre (aussi utilisée par les anciens menus).
function Window.closeButton(parent: GuiObject, onClose: () -> ()): TextButton
	local button =
		Style.button(parent, { top = STYLE.CLOSE_TOP, bottom = STYLE.CLOSE_BOTTOM, edge = STYLE.CLOSE_STROKE })
	button.Name = "Close"
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.new(1, -STYLE.CLOSE_SIZE / 4, 0, STYLE.CLOSE_SIZE / 4)
	button.Size = UDim2.fromOffset(STYLE.CLOSE_SIZE, STYLE.CLOSE_SIZE)
	button.ZIndex = 10
	Style.corner(button, CIRCLE)
	local cross = Style.label(button, "X", UDim2.fromScale(0.7, 0.7))
	cross.AnchorPoint = Vector2.new(0.5, 0.5)
	cross.Position = UDim2.fromScale(0.5, 0.5)
	cross.ZIndex = 11
	button.Activated:Connect(onClose)
	return button
end

local function buildBackdrop(parent: Instance): TextButton
	local backdrop = Instance.new("TextButton") -- bouton : un clic à côté de la fenêtre la ferme
	backdrop.AutoButtonColor = false
	backdrop.Text = ""
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = STYLE.BACKDROP_TRANSPARENCY
	backdrop.Visible = false
	backdrop:SetAttribute(UiConfig.JUICE.NO_BOUNCE_ATTRIBUTE, true) -- sinon toute la fenêtre rebondirait
	backdrop.Parent = parent
	return backdrop
end

local function buildFrame(backdrop: TextButton): (Frame, UIScale)
	local frame = Instance.new("Frame")
	frame.Active = true -- absorbe les clics : cliquer dans la fenêtre ne la ferme pas
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(STYLE.SCALE[1], STYLE.SCALE[2])
	Style.corner(frame, UDim.new(0, STYLE.CORNER))
	Style.gradient(frame, STYLE.TOP, STYLE.BOTTOM)
	Style.stroke(frame, STYLE.STROKE_COLOR, STYLE.STROKE)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(STYLE.MAX_SIZE[1], STYLE.MAX_SIZE[2])
	limit.Parent = frame
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	frame.Parent = backdrop
	return frame, scale
end

local function buildTitle(frame: Frame, title: string)
	local label = Style.label(frame, title, UDim2.new(1, -2 * STYLE.CLOSE_SIZE, 0, STYLE.HEADER_HEIGHT - INSET))
	label.Position = UDim2.fromOffset(STYLE.CLOSE_SIZE, INSET / 2)
	label.TextColor3 = Color3.new(1, 1, 1)
	Style.maxTextSize(label, TITLE_TEXT_SIZE)
	local stroke = label:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Thickness = TITLE_STROKE
	stroke.Color = Bricks.rgb(STYLE.STROKE_COLOR)
	Style.gradient(label, STYLE.TITLE_TOP, STYLE.TITLE_BOTTOM)
	label.BackgroundTransparency = 1
end

local function buildBody(frame: Frame): Frame
	local body = Instance.new("Frame")
	body.Position = UDim2.fromOffset(INSET, STYLE.HEADER_HEIGHT)
	body.Size = UDim2.new(1, -2 * INSET, 1, -STYLE.HEADER_HEIGHT - INSET)
	body.BackgroundColor3 = Bricks.rgb(STYLE.INNER)
	body.BackgroundTransparency = STYLE.INNER_TRANSPARENCY
	body.ClipsDescendants = true
	Style.corner(body, UDim.new(0, STYLE.CORNER - INSET / 2))
	body.Parent = frame
	return body
end

function Window.new(parent: Instance, name: string, title: string): Window
	local backdrop = buildBackdrop(parent)
	local frame, scale = buildFrame(backdrop)
	buildTitle(frame, title)
	local self = setmetatable({
		name = name,
		backdrop = backdrop,
		frame = frame,
		scale = scale,
		body = buildBody(frame),
		isOpen = false,
		onOpen = nil,
	}, Window)
	Window.closeButton(frame, function()
		self:close()
	end)
	backdrop.Activated:Connect(function()
		self:close()
	end)
	return self
end

function Window.open(self: Window)
	if self.isOpen then
		return
	end
	if openWindow and openWindow ~= self then
		openWindow:close()
	end
	openWindow = self
	self.isOpen = true
	self.backdrop.Visible = true
	self.scale.Scale = STYLE.OPEN_FROM_SCALE
	TweenService:Create(self.scale, OPEN, { Scale = 1 }):Play()
	ContextActionService:BindAction(`Close{self.name}`, function(_, state)
		if state == Enum.UserInputState.Begin then
			self:close()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)
	if self.onOpen then
		self.onOpen()
	end
end

function Window.close(self: Window)
	if not self.isOpen then
		return
	end
	self.isOpen = false
	if openWindow == self then
		openWindow = nil
	end
	ContextActionService:UnbindAction(`Close{self.name}`)
	local shrink = TweenService:Create(self.scale, CLOSE, { Scale = STYLE.OPEN_FROM_SCALE })
	shrink.Completed:Connect(function()
		if not self.isOpen then
			self.backdrop.Visible = false
		end
	end)
	shrink:Play()
end

function Window.toggle(self: Window)
	if self.isOpen then
		self:close()
	else
		self:open()
	end
end

return Window
