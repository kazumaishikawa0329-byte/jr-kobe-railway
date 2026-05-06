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
local TRACK_GAUGE  = 1.5
local RAIL_H       = 0.3
local SEG_LEN      = 2000   -- 1セグメント（Roblox パーツ上限 2048 stud 以内）
local TRACK_HALF   = 6000   -- Z- 側（網干方面）の端
local OSAKA_Z      = 4530   -- 大阪駅 Z
local TRACK_END_Z  = OSAKA_Z + 70  -- 大阪駅ホーム端 + 余裕（電車止め設置位置）

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
buildTrackZone("C", -TRACK_HALF, Z_2T_END,   X_1TRACK, 40,  7)
-- ゾーン B: 2 車線（西明石〜姫路）
buildTrackZone("B",  Z_2T_END,   Z_4T_END,   X_2TRACK, 40, 20)
-- ゾーン A: 4 車線（大阪〜西明石）大阪駅終端で打ち切り
buildTrackZone("A",  Z_4T_END,   TRACK_END_Z, X_4TRACK, 56, 40)

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
    local canopy = mkP(st, "Canopy",
        Vector3.new(platW, 0.28, PLAT_LEN),
        Vector3.new(platX, CANOPY_Y + 0.14, stZ),
        C_CANOPY)
    -- 夜間照明（NightLight）
    local cpl = Instance.new("PointLight")
    cpl.Name       = "NightLight"
    cpl.Brightness = 3
    cpl.Range      = 28
    cpl.Color      = Color3.fromRGB(255, 248, 220)
    cpl.Enabled    = false
    cpl.Parent     = canopy

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

-- ============================================================
-- 電車止め（大阪駅終端・4線分）
-- ============================================================
local function buildBufferStop(label, xOff, z)
    local railTop = 0.575 + RAIL_H          -- レール上面 Y ≈ 1.025
    local beamH   = 0.60
    local beamY   = railTop + beamH / 2

    -- 主衝撃ビーム（赤）
    mkP(folder, "BufBeam" .. label,
        Vector3.new(TRACK_GAUGE * 2 + 1.2, beamH, 0.50),
        Vector3.new(xOff, beamY, z),
        Color3.fromRGB(210, 30, 30))

    -- 左右縦支柱（ダークグレー）
    for _, sd in ipairs({ {-1, "L"}, {1, "R"} }) do
        local sx = xOff + sd[1] * TRACK_GAUGE
        mkP(folder, "BufPost" .. label .. sd[2],
            Vector3.new(0.28, railTop + beamH, 0.28),
            Vector3.new(sx, (railTop + beamH) / 2, z),
            Color3.fromRGB(55, 55, 55))
    end

    -- ベースプレート（線路方向）
    mkP(folder, "BufBase" .. label,
        Vector3.new(TRACK_GAUGE * 2 + 1.2, 0.28, 1.5),
        Vector3.new(xOff, 0.14, z + 0.75),
        Color3.fromRGB(55, 55, 55))

    -- 警告帯（黄色・上部）
    mkP(folder, "BufWarn" .. label,
        Vector3.new(TRACK_GAUGE * 2 + 1.2, 0.22, 0.52),
        Vector3.new(xOff, beamY + beamH / 2 + 0.11, z),
        Color3.fromRGB(240, 185, 0), Enum.Material.Neon, true)
end

for _, xOff in ipairs(X_4TRACK) do
    buildBufferStop(tostring(xOff), xOff, TRACK_END_Z)
end

-- ============================================================
-- 沿線地盤 & 風景の生成
-- ============================================================
math.randomseed(54321)
local function rr(lo, hi) return lo + math.random() * (hi - lo) end
local _si = 0
local function nsi() _si += 1; return tostring(_si) end

-- ── 地盤生成（線路外の地面） ───────────────────────────────────
local CONCRETE_COL = Color3.fromRGB(162, 162, 155)
local SOIL_COL     = Color3.fromRGB(112,  85,  52)

local function buildSceneryGround(label, zFrom, zTo, xFrom, xTo, color, mat)
    local w  = math.abs(xTo - xFrom)
    local xc = (xFrom + xTo) / 2
    local z = zFrom; local idx = 0
    while z < zTo do
        local seg = math.min(SEG_LEN, zTo - z)
        local g = mkP(folder, "SGnd"..label..idx,
            Vector3.new(w, 0.2, seg),
            Vector3.new(xc, -0.1, z + seg/2),
            color, mat)
        g.CanCollide = false
        z += seg; idx += 1
    end
end

-- Zone A（4線・都市部 Z=-450〜4600）: コンクリート
buildSceneryGround("AL", Z_4T_END, TRACK_END_Z, -82, -28, CONCRETE_COL, Enum.Material.Concrete)
buildSceneryGround("AR", Z_4T_END, TRACK_END_Z,  28,  82, CONCRETE_COL, Enum.Material.Concrete)
-- Zone B上部（西明石〜海姫路 Z=-1960〜-450）: コンクリート
buildSceneryGround("BcL", STATIONS[20].z, Z_4T_END, -68, -22, CONCRETE_COL, Enum.Material.Concrete)
buildSceneryGround("BcR", STATIONS[20].z, Z_4T_END,  22,  68, CONCRETE_COL, Enum.Material.Concrete)
-- Zone B下部（姫路〜海姫路 Z=-3050〜-1960）: 土
buildSceneryGround("BsL", Z_2T_END, STATIONS[20].z, -65, -22, SOIL_COL, Enum.Material.Ground)
buildSceneryGround("BsR", Z_2T_END, STATIONS[20].z,  22,  65, SOIL_COL, Enum.Material.Ground)
-- Zone C（1線・農村 Z=-6000〜-3050）: 土
buildSceneryGround("CL", -TRACK_HALF, Z_2T_END, -62, -22, SOIL_COL, Enum.Material.Ground)
buildSceneryGround("CR", -TRACK_HALF, Z_2T_END,  22,  62, SOIL_COL, Enum.Material.Ground)

-- ── 風景ヘルパー ───────────────────────────────────────────────
local CITY_COLS = {
    Color3.fromRGB(210,205,195), Color3.fromRGB(195,188,175),
    Color3.fromRGB(220,215,205), Color3.fromRGB(170,175,182),
    Color3.fromRGB(230,220,208), Color3.fromRGB(160,168,178),
    Color3.fromRGB(245,238,225), Color3.fromRGB(180,185,192),
}
local function scBuilding(x, z, w, h, d)
    local id = nsi()
    local b = mkP(folder,"ScB"..id, Vector3.new(w,h,d), Vector3.new(x,h/2,z),
        CITY_COLS[math.random(1,#CITY_COLS)])
    b.CanCollide = false
    local rt = mkP(folder,"ScBR"..id, Vector3.new(w+0.2,0.5,d+0.2),
        Vector3.new(x,h+0.25,z), Color3.fromRGB(75,78,82))
    rt.CanCollide = false
    -- 夜間照明（NightLight）
    local pl = Instance.new("PointLight")
    pl.Name       = "NightLight"
    pl.Brightness = 1.5
    pl.Range      = math.max(math.floor(h * 0.7), 10)
    pl.Color      = Color3.fromRGB(255, 240, 195)
    pl.Enabled    = false
    pl.Parent     = b
end

local LEAF_COLS = {
    Color3.fromRGB(40,130,40), Color3.fromRGB(55,145,35),
    Color3.fromRGB(35,120,55), Color3.fromRGB(70,155,30),
}
local function scTree(x, z, h)
    h = h or rr(3,6)
    local id = nsi()
    local tr = mkP(folder,"ScTr"..id, Vector3.new(0.45,h,0.45),
        Vector3.new(x,h/2,z), Color3.fromRGB(90,55,22), Enum.Material.Wood)
    tr.CanCollide = false
    local fr = rr(1.4,2.8)
    local fl = mkP(folder,"ScFl"..id, Vector3.new(fr*2,fr*1.2,fr*2),
        Vector3.new(x,h+fr*0.45,z),
        LEAF_COLS[math.random(1,#LEAF_COLS)], Enum.Material.LeafyGrass)
    fl.CanCollide = false
end

local HOUSE_COLS = {
    Color3.fromRGB(232,222,208), Color3.fromRGB(218,205,188),
    Color3.fromRGB(242,235,220), Color3.fromRGB(200,192,178),
}
local ROOF_COLS = {
    Color3.fromRGB(80,45,35), Color3.fromRGB(95,58,42),
    Color3.fromRGB(68,38,28), Color3.fromRGB(108,68,48),
}
local function scHouse(x, z)
    local id = nsi()
    local bw = rr(4,6); local bd = rr(4,6); local bh = rr(3,4.5)
    local b = mkP(folder,"ScH"..id, Vector3.new(bw,bh,bd), Vector3.new(x,bh/2,z),
        HOUSE_COLS[math.random(1,#HOUSE_COLS)])
    b.CanCollide = false
    local rf = mkP(folder,"ScHR"..id, Vector3.new(bw+0.6,rr(0.9,1.6),bd+0.6),
        Vector3.new(x,bh+rr(0.5,0.9),z), ROOF_COLS[math.random(1,#ROOF_COLS)])
    rf.CanCollide = false
end

local function scRice(x, z, w, d)
    local id = nsi()
    local col = math.random()<0.45
        and Color3.fromRGB(85,155,55)
        or  Color3.fromRGB(200,168,30)
    local f = mkP(folder,"ScRc"..id, Vector3.new(w,0.15,d),
        Vector3.new(x,0.075,z), col, Enum.Material.Grass)
    f.CanCollide = false
    mkP(folder,"ScAz"..id, Vector3.new(w+0.5,0.22,0.45),
        Vector3.new(x,0.11,z-d/2), Color3.fromRGB(115,95,65)).CanCollide = false
end

local function scMountain(x, z, w, h, d)
    local id = nsi()
    local m = mkP(folder,"ScMt"..id, Vector3.new(w,h,d),
        Vector3.new(x,h/2,z), Color3.fromRGB(78,92,68), Enum.Material.Grass)
    m.CanCollide = false
end

-- ── 大阪駅: 超高層ビル密集ゾーン（塚本〜バッファ端）────────────
-- リスポーン地点（X≈49, Z=4552）→キオスク（X=32, Z=4530〜4566）→駅への
-- アクセス経路を確保するため、大阪駅周辺（Z≥OSAKA_Z-150）の +X 側ビルは排除
do
    local z = STATIONS[2].z + 50   -- 塚本〜大阪間スタート
    while z <= TRACK_END_Z + 5 do
        for _, sx in ipairs({ -38,-52,-66,-80,  38,52,66,80 }) do
            if sx > 0 and z >= OSAKA_Z - 150 then continue end
            local h = (z >= OSAKA_Z - 60) and rr(30,65) or rr(20,50)
            scBuilding(sx+rr(-4,4), z+rr(-8,8), rr(8,15), h, rr(8,16))
        end
        z += rr(16,28)
    end
end

-- ── 各駅周辺ビル群（大阪は除く）─────────────────────────────
for i, st in ipairs(STATIONS) do
    if i == 1 then continue end   -- 大阪は上で処理済み
    local inA = (st.z >= Z_4T_END)
    local inB = (st.z < Z_4T_END and st.z >= Z_2T_END)
    local xList, hMin, hMax
    if inA then
        xList = { -38,-50,-62,  38,50,62 }
        hMin, hMax = 8, 25
    elseif inB then
        xList = { -28,-40,  28,40 }
        hMin, hMax = 5, 15
    else
        xList = { -26,-36,  26,36 }
        hMin, hMax = 4, 10
    end
    for _, dz in ipairs({ -40, 0, 40 }) do
        for _, sx in ipairs(xList) do
            scBuilding(sx+rr(-4,4), st.z+dz+rr(-8,8), rr(5,10), rr(hMin,hMax), rr(5,10))
        end
    end
end

-- ── 駅間スキップ判定 ─────────────────────────────────────────
local function nearSt(z, margin)
    margin = margin or 68
    for _, st in ipairs(STATIONS) do
        if math.abs(z - st.z) < margin then return true end
    end
    return false
end

-- ── 市街地〜住宅地（尼崎〜神戸三宮 Z≈1980〜3880）──────────────
do
    local z = STATIONS[9].z + 80
    while z < STATIONS[3].z - 80 do
        if not nearSt(z) then
            for _, side in ipairs({ -1, 1 }) do
                local xb = side * rr(34,48)
                if math.random()<0.55 then
                    scBuilding(xb+rr(-3,3), z+rr(-10,10), rr(5,10), rr(7,20), rr(5,11))
                else
                    scHouse(xb+rr(-3,3), z+rr(-8,8))
                end
                if math.random()<0.45 then scTree(side*rr(26,30), z+rr(-5,5)) end
            end
        end
        z += rr(38,65)
    end
end

-- ── 阪神〜海沿い（神戸三宮〜西明石）住宅＋ビル＋六甲山背景 ───
do
    local mz = STATIONS[16].z
    while mz < STATIONS[9].z do
        scMountain(-rr(85,115), mz, rr(55,100), rr(22,44), rr(80,160))
        mz += rr(120, 200)
    end
    local z = STATIONS[16].z + 80
    while z < STATIONS[9].z - 80 do
        if not nearSt(z) then
            for _, side in ipairs({ -1, 1 }) do
                local r = math.random()
                if r < 0.45 then
                    scBuilding(side*rr(32,46)+rr(-3,3), z+rr(-10,10), rr(4,9), rr(5,14), rr(4,9))
                elseif r < 0.80 then
                    scHouse(side*rr(30,42)+rr(-3,3), z+rr(-8,8))
                end
                if math.random()<0.5 then scTree(side*rr(26,30), z+rr(-5,5)) end
            end
        end
        z += rr(40,70)
    end
end

-- ── 郊外（西明石〜姫路）住宅・田んぼ・木混在 ─────────────────
do
    local z = STATIONS[23].z + 80
    while z < STATIONS[16].z - 80 do
        if not nearSt(z) then
            local r = math.random()
            if r < 0.28 then
                for _, side in ipairs({ -1, 1 }) do
                    scRice(side*rr(36,56), z, rr(16,28), rr(22,42))
                end
            elseif r < 0.62 then
                for _, side in ipairs({ -1, 1 }) do
                    scHouse(side*rr(30,42), z+rr(-8,8))
                    if math.random()<0.5 then scHouse(side*rr(30,42), z+rr(-8,8)) end
                end
            end
            if math.random()<0.65 then
                scTree(rr(-26,-30), z+rr(-8,8))
                scTree(rr(26,30),   z+rr(-8,8))
            end
        end
        z += rr(55,95)
    end
end

-- ── 農村（姫路〜網干）田んぼ・農家・木立 ────────────────────
do
    local z = -TRACK_HALF + 80
    while z < STATIONS[23].z - 80 do
        if not nearSt(z) then
            local r = math.random()
            if r < 0.52 then
                for _, side in ipairs({ -1, 1 }) do
                    scRice(side*rr(30,55), z, rr(22,42), rr(30,65))
                end
            elseif r < 0.75 then
                local cnt = math.random(2, 5)
                for _ = 1, cnt do
                    scTree(rr(-26,-42), z+rr(-18,18), rr(4,7))
                    scTree(rr( 26, 42), z+rr(-18,18), rr(4,7))
                end
            else
                for _, side in ipairs({ -1, 1 }) do
                    scHouse(side*rr(30,40), z+rr(-5,5))
                end
            end
        end
        z += rr(78,140)
    end
end

-- 大阪駅スポーン・キオスク広場（4番線東側）
-- 線路の右外（ローカルX=15〜57）にコンクリート地面を追加（プラットフォームからスポーンまで約2倍の距離を確保）
mkP(folder, "OsakaPlaza",
    Vector3.new(42, 0.5, PLAT_LEN + 40),
    Vector3.new(36, 0.25, 4530),
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
spawnLoc.Position              = Vector3.new(49 + WORLD_OFFSET.X, 1.0, 4552)  -- 広場（線路外、キオスク奥）
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
