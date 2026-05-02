-- 大阪 → 網干 全28駅・地上路線
-- 駅間距離: 280〜460 stud（130 km/h で約 8〜13 秒、平均 ≈ 10 秒）
-- 最大/最短 比 = 460/280 = 1.64（2倍以内）

local Workspace = game:GetService("Workspace")

local FOLDER_NAME  = "RailwayTest"
local WORLD_OFFSET = Vector3.new(40, 0, 0)

local existing = Workspace:FindFirstChild(FOLDER_NAME)
if existing then existing:Destroy() end

local folder = Instance.new("Folder")
folder.Name   = FOLDER_NAME
folder.Parent = Workspace

-- ============================================================
-- ヘルパー
-- ============================================================
local function mkP(parent, name, size, lp, color, mat, noCollide)
    local p = Instance.new("Part")
    p.Name          = name
    p.Size          = size
    p.Position      = lp + WORLD_OFFSET
    p.Anchored      = true
    p.Color         = color
    p.Material      = mat or Enum.Material.SmoothPlastic
    p.TopSurface    = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.CanCollide    = not noCollide
    p.Parent        = parent
    return p
end

-- ============================================================
-- 路線インフラ（レール・バラスト）をセグメント分割で生成
-- ============================================================
local TRACK_GAUGE = 1.5
local RAIL_H      = 0.3
local SEG_LEN     = 2000   -- 1セグメント（Roblox パーツ上限 2048 stud 以内）
local TRACK_HALF  = 6000   -- 片側 6000、総長 12000（路線全長 ≈ 9630 stud をカバー）

local segIdx = 0
local z0     = -TRACK_HALF
while z0 < TRACK_HALF do
    local zc  = z0 + SEG_LEN / 2
    local sfx = tostring(segIdx)
    segIdx   += 1

    -- 地面（線路中心 ±20 stud の草地）
    mkP(folder, "Ground" .. sfx,
        Vector3.new(40, 0.2, SEG_LEN),
        Vector3.new(0, -0.1, zc),
        Color3.fromRGB(106, 155, 85), Enum.Material.Grass)

    mkP(folder, "Ballast" .. sfx,
        Vector3.new(7, 0.35, SEG_LEN),
        Vector3.new(0, 0.175, zc),
        Color3.fromRGB(130, 120, 110), nil, true)
    mkP(folder, "RailL" .. sfx,
        Vector3.new(0.3, RAIL_H, SEG_LEN),
        Vector3.new(-TRACK_GAUGE, 0.575 + RAIL_H / 2, zc),
        Color3.fromRGB(130, 130, 140))
    mkP(folder, "RailR" .. sfx,
        Vector3.new(0.3, RAIL_H, SEG_LEN),
        Vector3.new( TRACK_GAUGE, 0.575 + RAIL_H / 2, zc),
        Color3.fromRGB(130, 130, 140))

    -- 枕木（5 stud 間隔）
    for i = 0, SEG_LEN / 5 - 1 do
        mkP(folder, "Slp" .. sfx .. "_" .. i,
            Vector3.new(4.5, 0.25, 0.55),
            Vector3.new(0, 0.45, z0 + i * 5 + 2.5),
            Color3.fromRGB(90, 60, 30), nil, true)
    end

    z0 += SEG_LEN
end

-- ============================================================
-- 駅構築関数
-- ============================================================
local PLAT_W   = 6
local PLAT_H   = 1.2
local PLAT_X   = TRACK_GAUGE + 1.3 + PLAT_W / 2   -- local X ≈ 5.8
local PLAT_LEN = 100
local CANOPY_Y = 12.0   -- キャノピー底面 Y（パンタグラフ上方）

local C_PLAT   = Color3.fromRGB(210, 210, 200)
local C_SIGN   = Color3.fromRGB(0,   78,  162)
local C_CANOPY = Color3.fromRGB(100, 130, 160)
local C_PILLAR = Color3.fromRGB(160, 165, 170)
local C_YELLOW = Color3.fromRGB(240, 185,   0)

local function buildStation(stName, stZ)
    local st    = Instance.new("Model")
    st.Name     = stName
    st.Parent   = folder

    -- 地盤コンクリート
    mkP(st, "Ground",
        Vector3.new(30, 0.5, PLAT_LEN + 40),
        Vector3.new(PLAT_X, 0.25, stZ),
        Color3.fromRGB(170, 170, 162), Enum.Material.Concrete)

    -- プラットホーム
    mkP(st, "Platform",
        Vector3.new(PLAT_W, PLAT_H, PLAT_LEN),
        Vector3.new(PLAT_X, PLAT_H / 2, stZ),
        C_PLAT, Enum.Material.Concrete)

    -- 安全線（黄色）
    mkP(st, "SafetyLine",
        Vector3.new(0.4, 0.06, PLAT_LEN),
        Vector3.new(PLAT_X - PLAT_W / 2 + 0.22, PLAT_H + 0.03, stZ),
        C_YELLOW, nil, true)

    -- 駅名看板（SurfaceGui・線路向き）
    local board = mkP(st, "SignBoard",
        Vector3.new(0.2, 1.1, 7.0),
        Vector3.new(PLAT_X - PLAT_W / 2 + 0.12, PLAT_H + 0.75, stZ),
        C_SIGN, nil, true)
    local sg  = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Left; sg.Parent = board
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.fromScale(1, 1); lbl.BackgroundTransparency = 1
    lbl.Text = stName; lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextScaled = true; lbl.Font = Enum.Font.GothamBold; lbl.Parent = sg

    -- キャノピー支柱
    local pillarH = CANOPY_Y - PLAT_H
    local nInterv = math.max(2, math.floor(PLAT_LEN / 18))
    local pillarX = PLAT_X + PLAT_W / 2 - 0.25
    for k = 0, nInterv do
        local pz = stZ - PLAT_LEN / 2 + k * (PLAT_LEN / nInterv)
        mkP(st, "Pillar" .. k,
            Vector3.new(0.35, pillarH, 0.35),
            Vector3.new(pillarX, PLAT_H + pillarH / 2, pz),
            C_PILLAR, nil, true)
    end

    -- キャノピー屋根
    mkP(st, "Canopy",
        Vector3.new(PLAT_W, 0.28, PLAT_LEN),
        Vector3.new(PLAT_X, CANOPY_Y + 0.14, stZ),
        C_CANOPY)

end

-- ============================================================
-- 全 28 駅の Z 座標
--
-- 基準: 130 km/h = 36.1 stud/s → 10 s ≈ 360 stud
-- 範囲: 280（三宮-神戸三宮）〜 460（播磨勝原-東網干）
-- スポーン(Z≈0)は 神戸海(+220) と 東加古川(-220) の中間
-- ============================================================
local STATIONS = {
    {name = "大阪",          z =  4530},   -- 路線始発
    {name = "塚本",          z =  4230},   -- 間隔 300
    {name = "尼崎",          z =  3880},   -- 間隔 350
    {name = "甲子園口",      z =  3560},   -- 間隔 320
    {name = "立花",          z =  3240},   -- 間隔 320
    {name = "芦屋",          z =  2900},   -- 間隔 340
    {name = "西芦屋",        z =  2600},   -- 間隔 300
    {name = "三宮",          z =  2260},   -- 間隔 340
    {name = "神戸三宮",      z =  1980},   -- 間隔 280（最短 ≈ 7.8 s）
    {name = "神戸",          z =  1680},   -- 間隔 300
    {name = "神戸新町",      z =  1350},   -- 間隔 330
    {name = "西神戸",        z =  1000},   -- 間隔 350
    {name = "淡路橋",        z =   620},   -- 間隔 380
    {name = "神戸海",        z =   220},   -- 間隔 400
    {name = "東加古川",      z =  -220},   -- 間隔 440
    {name = "加古川",        z =  -600},   -- 間隔 380
    {name = "加古川商店街",  z =  -930},   -- 間隔 330
    {name = "海姫路",        z = -1350},   -- 間隔 420
    {name = "東姫路",        z = -1730},   -- 間隔 380
    {name = "姫路公園",      z = -2080},   -- 間隔 350
    {name = "姫路",          z = -2440},   -- 間隔 360
    {name = "山陽姫路",      z = -2780},   -- 間隔 340
    {name = "西山陽姫路",    z = -3090},   -- 間隔 310
    {name = "姫路野球場",    z = -3440},   -- 間隔 350
    {name = "播磨姫路",      z = -3830},   -- 間隔 390
    {name = "播磨勝原",      z = -4260},   -- 間隔 430
    {name = "東網干",        z = -4720},   -- 間隔 460（最長 ≈ 12.7 s）
    {name = "網干",          z = -5100},   -- 間隔 380・路線終着
}

for _, st in ipairs(STATIONS) do
    buildStation(st.name, st.z)
end

-- TrainBuilder 起動同期シグナル（FindFirstChild("Platform") 対応）
local sync = Instance.new("Part")
sync.Name         = "Platform"
sync.Size         = Vector3.new(0.1, 0.1, 0.1)
sync.Position     = Vector3.new(40, -50, 0)
sync.Transparency = 1
sync.CanCollide   = false
sync.Anchored     = true
sync.Parent       = folder

print(string.format(
    "[RailwayTestBuilder] %s を生成しました（%d 駅、駅間 280〜460 stud）。",
    FOLDER_NAME, #STATIONS))
