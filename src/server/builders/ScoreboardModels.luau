--!strict
-- Grands tableaux de scores sur poteaux (A58) : titre doré et 10 lignes (rang, portrait, nom, score), lisibles des
-- deux côtés, depuis le boulevard comme depuis le champ.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DecorConfig = require(ReplicatedStorage.Shared.config.DecorConfig)
local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local RetentionConfig = require(ReplicatedStorage.Shared.config.RetentionConfig)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local Scoreboard = require(ReplicatedStorage.Shared.domain.Scoreboard)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Build = require(script.Parent.Build)

local ScoreboardModels = {}

export type Line = { userId: number, name: string, score: string }
type Row = { frame: Frame, head: ImageLabel, name: TextLabel, score: TextLabel }
export type Board = { rows: { Row } }

local STYLE = DecorConfig.SCOREBOARD
local FONT = (Enum.Font :: any)[UiConfig.FONT] :: Enum.Font
local WHITE = Color3.new(1, 1, 1)
local MEDALS = { "🥇", "🥈", "🥉" }
local TITLE_SHARE = 0.15 -- part de la hauteur occupée par le titre
local STROKE = 2

local function text(parent: Instance, size: UDim2, position: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size, label.Position = size, position
	label.Font = FONT
	label.TextScaled = true
	label.TextColor3 = WHITE
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = STROKE
	stroke.Parent = label
	label.Parent = parent
	return label
end

local function corner(gui: GuiObject, radius: UDim)
	local round = Instance.new("UICorner")
	round.CornerRadius = radius
	round.Parent = gui
end

local function buildRow(parent: Instance, rank: number, count: number): Row
	local height = (1 - TITLE_SHARE) / count
	local frame = Instance.new("Frame")
	frame.Position = UDim2.fromScale(0.03, TITLE_SHARE + (rank - 1) * height)
	frame.Size = UDim2.fromScale(0.94, height * 0.9)
	frame.BackgroundColor3 = WHITE
	frame.BackgroundTransparency = if rank % 2 == 0 then 0.92 else 0.82
	corner(frame, UDim.new(0.2, 0))
	frame.Parent = parent
	local place = text(frame, UDim2.fromScale(0.11, 0.86), UDim2.fromScale(0.01, 0.07))
	place.Text = MEDALS[rank] or tostring(rank)
	local head = Instance.new("ImageLabel")
	head.BackgroundColor3 = Bricks.rgb(STYLE.PORTRAIT_COLOR)
	head.Position = UDim2.fromScale(0.13, 0.08)
	head.Size = UDim2.fromScale(0.84, 0.84)
	head.SizeConstraint = Enum.SizeConstraint.RelativeYY
	corner(head, UDim.new(0.5, 0))
	head.Parent = frame
	local name = text(frame, UDim2.fromScale(0.47, 0.72), UDim2.fromScale(0.23, 0.14))
	name.TextXAlignment = Enum.TextXAlignment.Left
	local score = text(frame, UDim2.fromScale(0.28, 0.66), UDim2.fromScale(0.71, 0.17))
	score.TextXAlignment = Enum.TextXAlignment.Right
	score.TextColor3 = Bricks.rgb(STYLE.SCORE_COLOR)
	frame.Visible = false
	return { frame = frame, head = head, name = name, score = score }
end

-- Une face du tableau : renvoie ses lignes.
local function buildFace(part: BasePart, face: Enum.NormalId, title: string): { Row }
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = STYLE.PIXELS_PER_STUD
	gui.LightInfluence = 0
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = WHITE
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Bricks.rgb(STYLE.TOP), Bricks.rgb(STYLE.BOTTOM))
	gradient.Rotation = 90
	gradient.Parent = panel
	panel.Parent = gui
	local heading = text(panel, UDim2.fromScale(0.94, TITLE_SHARE * 0.86), UDim2.fromScale(0.03, 0.01))
	heading.Text = title
	heading.TextColor3 = Bricks.rgb(STYLE.TITLE_COLOR)
	local rows: { Row } = {}
	for rank = 1, RetentionConfig.SCOREBOARD_SIZE do
		table.insert(rows, buildRow(gui, rank, RetentionConfig.SCOREBOARD_SIZE))
	end
	gui.Parent = part
	return rows
end

function ScoreboardModels.build(parent: Instance, def: RetentionConfig.ScoreboardDef): Board
	local x, width, height, lift = STYLE.X, STYLE.WIDTH, STYLE.HEIGHT, STYLE.LIFT
	local top = MapConfig.FLOOR_TOP
	for _, side in { -1, 1 } do
		Build.block(parent, {
			name = "Post",
			cframe = CFrame.new(x, top + (lift + height) / 2, def.z + side * (width / 2 - 1)),
			size = Vector3.new(1.4, lift + height, 1.4),
			color = STYLE.FRAME_COLOR,
		})
	end
	local panel = Build.block(parent, {
		name = `Scoreboard{def.id}`,
		cframe = CFrame.new(x, top + lift + height / 2, def.z),
		size = Vector3.new(1, height, width),
		color = STYLE.FRAME_COLOR,
	})
	Build.block(parent, {
		name = "Cap",
		cframe = CFrame.new(x, top + lift + height + 0.5, def.z),
		size = Vector3.new(2, 1, width + 1),
		color = STYLE.CAP_COLOR,
	})
	local rows = {}
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		for _, row in buildFace(panel, face, def.title) do
			table.insert(rows, row)
		end
	end
	return { rows = rows }
end

-- Affiche le classement sur les deux faces (les lignes de chaque face se suivent dans `rows`).
function ScoreboardModels.update(board: Board, lines: { Line })
	local perFace = RetentionConfig.SCOREBOARD_SIZE
	for index, row in board.rows do
		local line = lines[(index - 1) % perFace + 1]
		row.frame.Visible = line ~= nil
		if line then
			row.head.Image = Scoreboard.headshot(line.userId)
			row.name.Text = line.name
			row.score.Text = line.score
		end
	end
end

return ScoreboardModels
