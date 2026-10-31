--!strict
-- Onglets « bonbon » en haut d'une fenêtre (CDC §10) : l'onglet actif est doré, les autres bleus.
-- Chaque onglet montre une page posée sous la barre ; les boutons se partagent la largeur.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Style = require(script.Parent.Style)

local Tabs = {}
Tabs.__index = Tabs

type Tab = { button: TextButton, gradient: UIGradient, page: GuiObject }

export type Tabs = typeof(setmetatable({} :: { body: GuiObject, list: { Tab } }, Tabs))

local WINDOW = UiConfig.WINDOW
local GAP = WINDOW.TAB_GAP
local LABEL_INSET = 10

function Tabs.new(body: GuiObject): Tabs
	return setmetatable({ body = body, list = {} }, Tabs)
end

-- Hauteur occupée par la barre d'onglets : les pages commencent en dessous.
Tabs.BAR_HEIGHT = WINDOW.TAB_HEIGHT + GAP

local function layout(self: Tabs)
	local count = #self.list
	for index, tab in self.list do
		local share = 1 / count
		-- Chaque bouton laisse GAP à gauche ; le dernier laisse aussi GAP à droite.
		tab.button.Position = UDim2.new((index - 1) * share, GAP - (index - 1) * GAP / count, 0, GAP / 2)
		tab.button.Size = UDim2.new(share, -GAP - GAP / count, 0, WINDOW.TAB_HEIGHT)
	end
end

-- Ajoute un onglet ; `page` est placée sous la barre et n'est visible que si l'onglet est actif.
function Tabs.add(self: Tabs, text: string, page: GuiObject)
	local button = Style.button(
		self.body,
		{ top = WINDOW.TAB_OFF_TOP, bottom = WINDOW.TAB_OFF_BOTTOM, edge = WINDOW.STROKE_COLOR }
	)
	local label = Style.label(button, text, UDim2.new(1, -LABEL_INSET, 1, -LABEL_INSET))
	label.Position = UDim2.fromOffset(LABEL_INSET / 2, LABEL_INSET / 2)
	page.Position = UDim2.fromOffset(0, Tabs.BAR_HEIGHT)
	page.Size = UDim2.new(1, 0, 1, -Tabs.BAR_HEIGHT)
	page.Visible = false
	page.Parent = self.body
	local tab: Tab =
		{ button = button, gradient = button:FindFirstChildOfClass("UIGradient") :: UIGradient, page = page }
	table.insert(self.list, tab)
	button.Activated:Connect(function()
		self:select(table.find(self.list, tab) :: number)
	end)
	layout(self)
end

function Tabs.select(self: Tabs, index: number)
	for k, tab in self.list do
		local isOn = k == index
		local top = if isOn then WINDOW.TAB_ON_TOP else WINDOW.TAB_OFF_TOP
		local bottom = if isOn then WINDOW.TAB_ON_BOTTOM else WINDOW.TAB_OFF_BOTTOM
		tab.gradient.Color = ColorSequence.new(Bricks.rgb(top), Bricks.rgb(bottom))
		tab.page.Visible = isOn
	end
end

return Tabs
