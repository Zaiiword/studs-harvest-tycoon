--!strict
-- Page défilante en grille de cartes (CDC §10) : autant de colonnes que la largeur le permet, entre un minimum
-- et un maximum, pour rester lisible du téléphone au grand écran.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)

local Grid = {}

export type Spec = { minWidth: number, height: number, minColumns: number, maxColumns: number, padding: number }

local SCROLLBAR = 8
local TOP_ROOM = 4 -- laisse la place au rebond des cartes du haut

local function fitColumns(page: ScrollingFrame, grid: UIGridLayout, spec: Spec)
	local width = page.AbsoluteSize.X - page.ScrollBarThickness - 2 * spec.padding
	local fit = math.floor((width + spec.padding) / (spec.minWidth + spec.padding))
	local columns = math.clamp(fit, spec.minColumns, spec.maxColumns)
	grid.CellSize = UDim2.new(1 / columns, -spec.padding * (columns - 1) / columns, 0, spec.height)
end

-- Les cartes s'y ajoutent comme enfants, triées par LayoutOrder.
function Grid.page(spec: Spec): ScrollingFrame
	local page = Instance.new("ScrollingFrame")
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.CanvasSize = UDim2.new()
	page.ScrollBarThickness = SCROLLBAR
	page.ScrollBarImageColor3 = Bricks.rgb(UiConfig.WINDOW.STROKE_COLOR)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, spec.padding)
	padding.PaddingRight = UDim.new(0, spec.padding)
	padding.PaddingBottom = UDim.new(0, spec.padding)
	padding.PaddingTop = UDim.new(0, TOP_ROOM)
	padding.Parent = page
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(spec.padding, spec.padding)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = page
	page:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fitColumns(page, grid, spec)
	end)
	return page
end

return Grid
