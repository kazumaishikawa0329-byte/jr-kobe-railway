-- 大阪 → 網干 全30駅・地上路線
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
local TRACK_HALF  = 6000   -- 片側 6000、総長 12000

-- 車線ゾーン境界（Z座標）
local Z_4T_END = -450    -- 西明石：ここより Z+ 側が 4 車線
local Z_2T_END = -3050   -- 姫路：ここより Z- 側が 1 車線

-- 各ゾーンの線路 X オフセット（トラック間隔 10 stud）
local X_4TRACK = {-15, -5, 5, 15}
local X_2TRACK = {-5, 5}
local X_1TRACK = {0}

-- 路線インフラ生成（レール・バラスト・枕木）をゾーン単位で生成
local function buildTrackZone(label, zFrom, zTo, xOffsets, groundW, ballastW)
    local z   = zFrom
    local idx = 0
    while z < zTo do
        local segLen = math.min(SEG_LEN, zTo - z)
        local zc     = z + segLen / 2
        local sfx    = label .. idx
        idx += 1

        mkP(folder, "Ground" .. sfx,
            Vector3.new(groundW, 0.2, segLen),
            Vector3.new(0, -0.1, zc),
            Color3.fromRGB(106, 155, 85), Enum.Material.Grass)

        mkP(folder, "Ballast" .. sfx,
            Vector3.new(ballastW, 0.35, segLen),
            Vector3.new(0, 0.175, zc),
            Color3.fromRGB(130, 120, 110), nil, true)

        for ti, xOff in ipairs(xOffsets) do
            local tsfx = sfx .. "t" .. ti
            mkP(folder, "RailL" .. tsfx,
                Vector3.new(0.3, RAIL_H, segLen),
                Vector3.new(xOff - TRACK_GAUGE, 0.575 + RAIL_H / 2, zc),
                Color3.fromRGB(130, 130, 140))
            mkP(folder, "RailR" .. tsfx,
                Vector3.new(0.3, RAIL_H, segLen),
                Vector3.new(xOff + TRACK_GAUGE, 0.575 + RAIL_H / 2, zc),
                Color3.fromRGB(130, 130, 140))
            for i = 0, math.floor(segLen / 5) - 1 do
                mkP(folder, "Slp" .. tsfx .. "_" .. i,
                    Vector3.new(4.5, 0.25, 0.55),
                    Vector3.new(xOff, 0.45, z + i * 5 + 2.5),
                    Color3.fromRGB(90, 60, 30), nil, true)
            end
        end

        z += segLen
    end
end

-- ゾーン C: 1 車線（姫路より南・Z- 側）
buildTrackZone("C", -TRACK_HALF, Z_2T_END,  X_1TRACK, 40,  7)
-- ゾーン B: 2 車線（西明石〜姫路）
buildTrackZone("B",  Z_2T_END,   Z_4T_END,  X_2TRACK, 40, 20)
-- ゾーン A: 4 車線（大阪〜西明石）
buildTrackZone("A",  Z_4T_END,   TRACK_HALF, X_4TRACK, 56, 40)

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

-- platX: プラットフォーム中心 X（デフォルト = 右側ホーム）
-- platW: プラットフォーム幅（デフォルト = PLAT_W）
local function buildStation(stName, stZ, prevName, nextName, platX, platW)
    prevName = prevName or ""
    nextName = nextName or ""
    platX    = platX or PLAT_X
    platW    = platW or PLAT_W
    local isCenter = (platX == 0)   -- 中央ホーム（2線・4線区間）

    local st    = Instance.new("Model")
    st.Name     = stName
    st.Parent   = folder

    -- 地盤コンクリート
    mkP(st, "Ground",
        Vector3.new(platW + 24, 0.5, PLAT_LEN + 40),
        Vector3.new(platX, 0.25, stZ),
        Color3.fromRGB(170, 170, 162), Enum.Material.Concrete)

    -- プラットホーム
    mkP(st, "Platform",
        Vector3.new(platW, PLAT_H, PLAT_LEN),
        Vector3.new(platX, PLAT_H / 2, stZ),
        C_PLAT, Enum.Material.Concrete)

    -- 安全線（中央ホームは両側に設置）
    mkP(st, "SafetyLineL",
        Vector3.new(0.4, 0.06, PLAT_LEN),
        Vector3.new(platX - platW / 2 + 0.22, PLAT_H + 0.03, stZ),
        C_YELLOW, nil, true)
    if isCenter then
        mkP(st, "SafetyLineR",
            Vector3.new(0.4, 0.06, PLAT_LEN),
            Vector3.new(platX + platW / 2 - 0.22, PLAT_H + 0.03, stZ),
            C_YELLOW, nil, true)
    end

    -- ============================================================
    -- 駅名看板（大型・JR西日本 駅名標スタイル）
    -- 高さ 4.5 stud × 幅 30 stud・プラットフォーム側面上部
    -- ============================================================
    local board = mkP(st, "SignBoard",
        Vector3.new(0.3, 4.5, 30.0),
        Vector3.new(platX - platW / 2 + 0.15, PLAT_H + 3.5, stZ),
        Color3.fromRGB(255, 255, 255), nil, true)

    local sg = Instance.new("SurfaceGui")
    sg.Face   = Enum.NormalId.Left
    sg.Parent = board

    -- 外枠（JRブルー）
    local outerFr = Instance.new("Frame")
    outerFr.Size             = UDim2.fromScale(1, 1)
    outerFr.BackgroundColor3 = C_SIGN
    outerFr.BorderSizePixel  = 0
    outerFr.Parent           = sg

    -- 内側白パネル（小余白）
    local innerFr = Instance.new("Frame")
    innerFr.Size             = UDim2.new(0.97, 0, 0.90, 0)
    innerFr.Position         = UDim2.new(0.015, 0, 0.05, 0)
    innerFr.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    innerFr.BorderSizePixel  = 0
    innerFr.Parent           = outerFr

    -- 隣駅があるかどうかで駅名の占有割合を変える
    local hasNeighbors = prevName ~= "" or nextName ~= ""
    local nameHScale   = hasNeighbors and 0.60 or 1.0

    -- 駅名（JRブルー・大きくスケール）
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size                   = UDim2.new(1, 0, nameHScale, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text                   = stName
    nameLbl.TextColor3             = C_SIGN
    nameLbl.TextScaled             = true
    nameLbl.Font                   = Enum.Font.GothamBold
    nameLbl.Parent                 = innerFr

    if hasNeighbors then
        -- 仕切り線
        local div = Instance.new("Frame")
        div.Size             = UDim2.new(1, 0, 0, 3)
        div.Position         = UDim2.new(0, 0, nameHScale - 0.01, 0)
        div.BackgroundColor3 = C_SIGN
        div.BorderSizePixel  = 0
        div.Parent           = innerFr

        -- 前駅（← 表示）
        local prevLbl = Instance.new("TextLabel")
        prevLbl.Size                   = UDim2.new(0.46, 0, 1 - nameHScale - 0.04, 0)
        prevLbl.Position               = UDim2.new(0.01, 0, nameHScale + 0.02, 0)
        prevLbl.BackgroundTransparency = 1
        prevLbl.Text                   = prevName ~= "" and ("← " .. prevName) or ""
        prevLbl.TextColor3             = C_SIGN
        prevLbl.TextScaled             = true
        prevLbl.Font                   = Enum.Font.Gotham
        prevLbl.TextXAlignment         = Enum.TextXAlignment.Left
        prevLbl.Parent                 = innerFr

        -- 次駅（→ 表示）
        local nextLbl = Instance.new("TextLabel")
        nextLbl.Size                   = UDim2.new(0.46, 0, 1 - nameHScale - 0.04, 0)
        nextLbl.Position               = UDim2.new(0.53, 0, nameHScale + 0.02, 0)
        nextLbl.BackgroundTransparency = 1
        nextLbl.Text                   = nextName ~= "" and (nextName .. " →") or ""
        nextLbl.TextColor3             = C_SIGN
        nextLbl.TextScaled             = true
        nextLbl.Font                   = Enum.Font.Gotham
        nextLbl.TextXAlignment         = Enum.TextXAlignment.Right
        nextLbl.Parent                 = innerFr
    end

    -- キャノピー支柱（中央ホームは両側）
    local pillarH = CANOPY_Y - PLAT_H
    local nInterv = math.max(2, math.floor(PLAT_LEN / 18))
    for k = 0, nInterv do
        local pz = stZ - PLAT_LEN / 2 + k * (PLAT_LEN / nInterv)
        mkP(st, "PillarR" .. k,
            Vector3.new(0.35, pillarH, 0.35),
            Vector3.new(platX + platW / 2 - 0.25, PLAT_H + pillarH / 2, pz),
            C_PILLAR, nil, true)
        if isCenter then
            mkP(st, "PillarL" .. k,
                Vector3.new(0.35, pillarH, 0.35),
                Vector3.new(platX - platW / 2 + 0.25, PLAT_H + pillarH / 2, pz),
                C_PILLAR, nil, true)
        end
    end

    -- キャノピー屋根
    mkP(st, "Canopy",
        Vector3.new(platW, 0.28, PLAT_LEN),
        Vector3.new(platX, CANOPY_Y + 0.14, stZ),
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
    {name = "明石",          z =  -130},   -- 間隔 350
    {name = "西明石",        z =  -450},   -- 間隔 320
    {name = "東加古川",      z =  -830},   -- 間隔 380
    {name = "加古川",        z = -1210},   -- 間隔 380
    {name = "加古川商店街",  z = -1540},   -- 間隔 330
    {name = "海姫路",        z = -1960},   -- 間隔 420
    {name = "東姫路",        z = -2340},   -- 間隔 380
    {name = "姫路公園",      z = -2690},   -- 間隔 350
    {name = "姫路",          z = -3050},   -- 間隔 360
    {name = "山陽姫路",      z = -3390},   -- 間隔 340
    {name = "西山陽姫路",    z = -3700},   -- 間隔 310
    {name = "姫路野球場",    z = -4050},   -- 間隔 350
    {name = "播磨姫路",      z = -4440},   -- 間隔 390
    {name = "播磨勝原",      z = -4870},   -- 間隔 430
    {name = "東網干",        z = -5330},   -- 間隔 460
    {name = "網干",          z = -5710},   -- 間隔 380・路線終着
}

for i, st in ipairs(STATIONS) do
    local prev = i > 1         and STATIONS[i - 1].name or ""
    local nxt  = i < #STATIONS and STATIONS[i + 1].name or ""
    -- 4車線・2車線ゾーン→中央ホーム、1車線ゾーン→右側ホーム
    local px = (st.z >= Z_2T_END) and 0 or PLAT_X
    buildStation(st.name, st.z, prev, nxt, px, PLAT_W)
end

-- 大阪駅スポーン・キオスク広場（4番線東側）
-- 線路の右外（ローカルX=15〜31）にコンクリート地面を追加
mkP(folder, "OsakaPlaza",
    Vector3.new(16, 0.5, PLAT_LEN + 40),
    Vector3.new(23, 0.25, 4530),
    Color3.fromRGB(170, 170, 162), Enum.Material.Concrete)

-- ============================================================
-- 各車線スポーン地点マーカー（大阪駅中心 Z=4530 に配置）
-- TrainBuilder がこれを参照して列車を生成する
-- ============================================================
local SPAWN_Z      = 4530   -- 大阪駅 Z
local SPAWN_Y      = 1.0    -- レール上面付近
local SPAWN_TRACKS = {
    {track = 1, x = -15},
    {track = 2, x =  -5},
    {track = 3, x =   5},
    {track = 4, x =  15},
}

for _, sp in ipairs(SPAWN_TRACKS) do
    local marker = Instance.new("Part")
    marker.Name         = "TrackSpawn_" .. sp.track
    marker.Size         = Vector3.new(8, 0.2, 26)
    marker.Position     = Vector3.new(sp.x, SPAWN_Y, SPAWN_Z) + WORLD_OFFSET
    marker.Anchored     = true
    marker.CanCollide   = false
    marker.Transparency = 0.4
    marker.Color        = Color3.fromRGB(240, 185, 0)
    marker.Material     = Enum.Material.Neon
    marker.Parent       = folder

    local bbg = Instance.new("BillboardGui")
    bbg.Size        = UDim2.fromOffset(120, 36)
    bbg.StudsOffset = Vector3.new(0, 2, 0)
    bbg.AlwaysOnTop = false
    bbg.MaxDistance = 60
    bbg.Parent      = marker

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.fromScale(1, 1)
    lbl.BackgroundColor3       = Color3.fromRGB(20, 20, 40)
    lbl.BackgroundTransparency = 0.1
    lbl.Text                   = sp.track .. "番線"
    lbl.TextColor3             = Color3.fromRGB(255, 220, 0)
    lbl.TextSize               = 18
    lbl.Font                   = Enum.Font.GothamBold
    lbl.Parent                 = bbg
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent       = lbl
end

-- 既存 SpawnLocation を全削除（デフォルト含む重複防止）
for _, obj in ipairs(Workspace:GetChildren()) do
    if obj:IsA("SpawnLocation") then obj:Destroy() end
end

-- プレイヤースポーン地点（大阪駅ホーム上）
local spawnLoc = Instance.new("SpawnLocation")
spawnLoc.Name                  = "OsakaSpawn"
spawnLoc.Size                  = Vector3.new(6, 1, 6)
spawnLoc.Position              = Vector3.new(26 + WORLD_OFFSET.X, 1.0, 4552)  -- 広場（線路外、キオスク奥）
spawnLoc.Anchored              = true
spawnLoc.Neutral               = true
spawnLoc.AllowTeamChangeOnTouch = false
spawnLoc.Color                 = Color3.fromRGB(100, 200, 100)
spawnLoc.Material              = Enum.Material.SmoothPlastic
spawnLoc.TopSurface            = Enum.SurfaceType.Smooth
spawnLoc.Parent                = Workspace   -- SpawnLocation は Workspace 直下が確実

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
    "[RailwayTestBuilder] %s を生成しました（%d 駅、駅間 280〜460 stud）。全長 ≈ 10240 stud",
    FOLDER_NAME, #STATIONS))
