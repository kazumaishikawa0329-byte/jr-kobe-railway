-- ゲーム開始時に Workspace/RailwayTest へ線路・駅を生成する

local Workspace = game:GetService("Workspace")

local FOLDER_NAME = "RailwayTest"

local existing = Workspace:FindFirstChild(FOLDER_NAME)
if existing then
	existing:Destroy()
end

local folder = Instance.new("Folder")
folder.Name = FOLDER_NAME
folder.Parent = Workspace

-- 全オブジェクトをリスポーン地点（原点）から X方向に離す
local WORLD_OFFSET = Vector3.new(40, 0, 0)

local function makePart(name, size, position, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position + WORLD_OFFSET
	part.Anchored = true
	part.Color = color
	part.Parent = folder
	return part
end

-- ========== 線路 ==========
local RAIL_LENGTH  = 2000   -- 20倍（旧: 100）
local RAIL_WIDTH   = 0.3
local RAIL_HEIGHT  = 0.3
local TRACK_GAUGE  = 1.5   -- 中心からレールまでの距離（片側）
local RAIL_COLOR   = Color3.fromRGB(130, 130, 140)

makePart("RailLeft",
	Vector3.new(RAIL_WIDTH, RAIL_HEIGHT, RAIL_LENGTH),
	Vector3.new(-TRACK_GAUGE, RAIL_HEIGHT / 2, 0),
	RAIL_COLOR)

makePart("RailRight",
	Vector3.new(RAIL_WIDTH, RAIL_HEIGHT, RAIL_LENGTH),
	Vector3.new(TRACK_GAUGE, RAIL_HEIGHT / 2, 0),
	RAIL_COLOR)

-- ========== 枕木 ==========
local SLEEPER_SPAN     = TRACK_GAUGE * 2 + 1.0
local SLEEPER_HEIGHT   = 0.2
local SLEEPER_DEPTH    = 0.5
local SLEEPER_INTERVAL = 2.5
local SLEEPER_COUNT    = math.floor(RAIL_LENGTH / SLEEPER_INTERVAL)   -- 自動計算
local SLEEPER_COLOR    = Color3.fromRGB(90, 60, 30)

for i = 1, SLEEPER_COUNT do
	local z = -(SLEEPER_COUNT - 1) * SLEEPER_INTERVAL / 2 + (i - 1) * SLEEPER_INTERVAL
	makePart("Sleeper" .. i,
		Vector3.new(SLEEPER_SPAN, SLEEPER_HEIGHT, SLEEPER_DEPTH),
		Vector3.new(0, SLEEPER_HEIGHT / 2, z),
		SLEEPER_COLOR)
end

-- ========== 駅ホーム ==========
local PLATFORM_LENGTH = 30
local PLATFORM_WIDTH  = 6
local PLATFORM_HEIGHT = 1.2
local PLATFORM_X      = TRACK_GAUGE + 1 + PLATFORM_WIDTH / 2
local PLATFORM_COLOR  = Color3.fromRGB(210, 210, 200)

makePart("Platform",
	Vector3.new(PLATFORM_WIDTH, PLATFORM_HEIGHT, PLATFORM_LENGTH),
	Vector3.new(PLATFORM_X, PLATFORM_HEIGHT / 2, 0),
	PLATFORM_COLOR)

-- ========== 駅名看板 ==========
local SIGN_THICKNESS = 0.3
local SIGN_HEIGHT    = 1.5
local SIGN_SPAN      = 5.0
local SIGN_X         = TRACK_GAUGE + 1 + SIGN_THICKNESS / 2
local SIGN_Y         = PLATFORM_HEIGHT + 0.3 + SIGN_HEIGHT / 2
local SIGN_COLOR     = Color3.fromRGB(30, 60, 160)

local sign = makePart("StationSign",
	Vector3.new(SIGN_THICKNESS, SIGN_HEIGHT, SIGN_SPAN),
	Vector3.new(SIGN_X, SIGN_Y, 0),
	SIGN_COLOR)

local gui = Instance.new("SurfaceGui")
gui.Name = "StationNameGui"
gui.Face = Enum.NormalId.Left
gui.Parent = sign

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, 0, 1, 0)
label.BackgroundTransparency = 1
label.Text = "神戸駅（テスト）"
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.Parent = gui

print("[RailwayTestBuilder] Workspace/" .. FOLDER_NAME .. " を生成しました。")
