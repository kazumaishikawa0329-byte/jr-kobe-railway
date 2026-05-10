-- 大阪 → 網干 全30駅・地上路線
-- 駅間距離: 2400〜3800 stud（130 km/h で約 67〜105 秒、平均 ≈ 90 秒）

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

-- CFrame 直接指定版（遮断機など回転が必要なパーツ用）
local function mkCF(parent, name, size, cf, color, mat)
    local p = Instance.new("Part")
    p.Name          = name
    p.Size          = size
    p.CFrame        = cf
    p.Anchored      = true
    p.Color         = color
    p.Material      = mat or Enum.Material.SmoothPlastic
    p.TopSurface    = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent        = parent
    return p
end

-- ============================================================
-- 路線インフラ（レール・バラスト）をセグメント分割で生成
-- ============================================================
local TRACK_GAUGE  = 1.5
local RAIL_H       = 0.3
local SEG_LEN      = 2000   -- 1セグメント（Roblox パーツ上限 2048 stud 以内）
local TRACK_HALF   = 85500  -- Z- 側（網干方面）の端
local OSAKA_Z      = 4530   -- 大阪駅 Z
local TRACK_END_Z  = OSAKA_Z + 70

-- 車線ゾーン境界（Z座標）
local Z_4T_END = -39870   -- 西明石：ここより Z+ 側が 4 車線
local Z_2T_END = -62270   -- 姫路：ここより Z- 側が 1 車線

-- 各ゾーンの線路 X オフセット
local X_4TRACK = {-15, -5, 5, 15}
local X_2TRACK = {-5, 5}
local X_1TRACK = {0}

-- 枕木間隔: UnionAsync がサーバースクリプトで動作しないため 50 stud 間隔を維持
local SLEEPER_STEP = 50

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
            Color3.fromRGB(130, 120, 110))

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
            for i = 0, math.floor(segLen / SLEEPER_STEP) - 1 do
                mkP(folder, "Slp" .. tsfx .. "_" .. i,
                    Vector3.new(4.5, 0.25, 0.55),
                    Vector3.new(xOff, 0.45, z + i * SLEEPER_STEP + SLEEPER_STEP / 2),
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
local PLAT_X   = TRACK_GAUGE + 1.3 + PLAT_W / 2
local PLAT_LEN = 100
local CANOPY_Y = 12.0

local C_PLAT   = Color3.fromRGB(210, 210, 200)
local C_SIGN   = Color3.fromRGB(0,   78,  162)
local C_CANOPY = Color3.fromRGB(100, 130, 160)
local C_PILLAR = Color3.fromRGB(160, 165, 170)
local C_YELLOW = Color3.fromRGB(240, 185,   0)

local function buildStation(stName, stZ, prevName, nextName, platX, platW)
    prevName = prevName or ""
    nextName = nextName or ""
    platX    = platX or PLAT_X
    platW    = platW or PLAT_W
    local isCenter = (platX == 0)

    local st = Instance.new("Model")
    st.Name   = stName
    st.Parent = folder

    mkP(st, "Ground",
        Vector3.new(platW + 24, 0.5, PLAT_LEN + 40),
        Vector3.new(platX, 0.25, stZ),
        Color3.fromRGB(170, 170, 162), Enum.Material.Concrete)

    mkP(st, "Platform",
        Vector3.new(platW, PLAT_H, PLAT_LEN),
        Vector3.new(platX, PLAT_H / 2, stZ),
        C_PLAT, Enum.Material.Concrete)

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

    local board = mkP(st, "SignBoard",
        Vector3.new(0.3, 4.5, 30.0),
        Vector3.new(platX - platW / 2 + 0.15, PLAT_H + 3.5, stZ),
        Color3.fromRGB(255, 255, 255), nil, true)

    local hasNeighbors = prevName ~= "" or nextName ~= ""
    local nameHScale   = hasNeighbors and 0.60 or 1.0

    -- 両面（Left=線路側 / Right=ホーム側）に同じ看板を描画
    local function buildSignGui(face)
        local sg = Instance.new("SurfaceGui")
        sg.Face   = face
        sg.Parent = board

        local outerFr = Instance.new("Frame")
        outerFr.Size             = UDim2.fromScale(1, 1)
        outerFr.BackgroundColor3 = C_SIGN
        outerFr.BorderSizePixel  = 0
        outerFr.Parent           = sg

        local innerFr = Instance.new("Frame")
        innerFr.Size             = UDim2.new(0.97, 0, 0.90, 0)
        innerFr.Position         = UDim2.new(0.015, 0, 0.05, 0)
        innerFr.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        innerFr.BorderSizePixel  = 0
        innerFr.Parent           = outerFr

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size                   = UDim2.new(1, 0, nameHScale, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text                   = stName
        nameLbl.TextColor3             = C_SIGN
        nameLbl.TextScaled             = true
        nameLbl.Font                   = Enum.Font.GothamBold
        nameLbl.Parent                 = innerFr

        if hasNeighbors then
            local div = Instance.new("Frame")
            div.Size             = UDim2.new(1, 0, 0, 3)
            div.Position         = UDim2.new(0, 0, nameHScale - 0.01, 0)
            div.BackgroundColor3 = C_SIGN
            div.BorderSizePixel  = 0
            div.Parent           = innerFr

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
    end

    buildSignGui(Enum.NormalId.Left)   -- 線路側（電車内から見える面）
    buildSignGui(Enum.NormalId.Right)  -- ホーム側（ホームから見える面）

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

    local canopy = mkP(st, "Canopy",
        Vector3.new(platW, 0.28, PLAT_LEN),
        Vector3.new(platX, CANOPY_Y + 0.14, stZ),
        C_CANOPY)
    local cpl = Instance.new("PointLight")
    cpl.Name       = "NightLight"
    cpl.Brightness = 3
    cpl.Range      = 28
    cpl.Color      = Color3.fromRGB(255, 248, 220)
    cpl.Enabled    = false
    cpl.Parent     = canopy
end

-- ============================================================
-- 全 30 駅の Z 座標
-- 駅間距離 2400〜3800 stud（130 km/h で 67〜105 秒、平均 90 秒）
-- ============================================================
local STATIONS = {
    {name = "大阪",          z =  4530},
    {name = "塚本",          z =  1630},   -- 間隔 2900
    {name = "尼崎",          z = -1570},   -- 間隔 3200
    {name = "甲子園口",      z = -4170},   -- 間隔 2600
    {name = "立花",          z = -6570},   -- 間隔 2400
    {name = "芦屋",          z = -9970},   -- 間隔 3400
    {name = "西芦屋",        z = -12770},  -- 間隔 2800
    {name = "三宮",          z = -15770},  -- 間隔 3000
    {name = "神戸三宮",      z = -18470},  -- 間隔 2700
    {name = "神戸",          z = -21370},  -- 間隔 2900
    {name = "神戸新町",      z = -24370},  -- 間隔 3000
    {name = "西神戸",        z = -27470},  -- 間隔 3100
    {name = "淡路橋",        z = -30670},  -- 間隔 3200
    {name = "神戸海",        z = -34070},  -- 間隔 3400
    {name = "明石",          z = -37070},  -- 間隔 3000
    {name = "西明石",        z = -39870},  -- 間隔 2800  ← 4→2線境界
    {name = "東加古川",      z = -43270},  -- 間隔 3400
    {name = "加古川",        z = -46570},  -- 間隔 3300
    {name = "加古川商店街",  z = -49470},  -- 間隔 2900
    {name = "海姫路",        z = -53070},  -- 間隔 3600
    {name = "東姫路",        z = -56270},  -- 間隔 3200
    {name = "姫路公園",      z = -59170},  -- 間隔 2900
    {name = "姫路",          z = -62270},  -- 間隔 3100  ← 2→1線境界
    {name = "山陽姫路",      z = -65270},  -- 間隔 3000
    {name = "西山陽姫路",    z = -67970},  -- 間隔 2700
    {name = "姫路野球場",    z = -70970},  -- 間隔 3000
    {name = "播磨姫路",      z = -74270},  -- 間隔 3300
    {name = "播磨勝原",      z = -77870},  -- 間隔 3600
    {name = "東網干",        z = -81670},  -- 間隔 3800
    {name = "網干",          z = -84970},  -- 間隔 3300  ← 路線終着
}

for i, st in ipairs(STATIONS) do
    local prev = i > 1         and STATIONS[i - 1].name or ""
    local nxt  = i < #STATIONS and STATIONS[i + 1].name or ""
    local px = (st.z >= Z_2T_END) and 0 or PLAT_X
    buildStation(st.name, st.z, prev, nxt, px, PLAT_W)
end

-- ============================================================
-- 電車止め（大阪駅終端・4線分）
-- ============================================================
local function buildBufferStop(label, xOff, z)
    local railTop = 0.575 + RAIL_H
    local beamH   = 0.60
    local beamY   = railTop + beamH / 2

    mkP(folder, "BufBeam" .. label,
        Vector3.new(TRACK_GAUGE * 2 + 1.2, beamH, 0.50),
        Vector3.new(xOff, beamY, z),
        Color3.fromRGB(210, 30, 30))

    for _, sd in ipairs({ {-1, "L"}, {1, "R"} }) do
        local sx = xOff + sd[1] * TRACK_GAUGE
        mkP(folder, "BufPost" .. label .. sd[2],
            Vector3.new(0.28, railTop + beamH, 0.28),
            Vector3.new(sx, (railTop + beamH) / 2, z),
            Color3.fromRGB(55, 55, 55))
    end

    mkP(folder, "BufBase" .. label,
        Vector3.new(TRACK_GAUGE * 2 + 1.2, 0.28, 1.5),
        Vector3.new(xOff, 0.14, z + 0.75),
        Color3.fromRGB(55, 55, 55))

    mkP(folder, "BufWarn" .. label,
        Vector3.new(TRACK_GAUGE * 2 + 1.2, 0.22, 0.52),
        Vector3.new(xOff, beamY + beamH / 2 + 0.11, z),
        Color3.fromRGB(240, 185, 0), Enum.Material.Neon, true)
end

for _, xOff in ipairs(X_4TRACK) do
    buildBufferStop(tostring(xOff), xOff, TRACK_END_Z)
end

-- ============================================================
-- 踏切（modelName を指定して複数設置可能）
-- 遮断機は「上げた状態」で初期配置し、CrossingManager が動作に応じて制御する
-- ============================================================
local CROSSING_ROAD_W = 20  -- 4輪車すれ違い対応（元値 8 の 2.5倍）
local CROSSING_HALF   = (CROSSING_ROAD_W + 0.5) / 2   -- 腕木の半長 = 10.25 stud
local CROSSING_PIVOT_Y = 3.8                            -- 腕木の回転軸 Y 座標

local function buildRailwayCrossing(modelName, z)
    local model = Instance.new("Model")
    model.Name   = modelName
    model.Parent = folder

    local ROAD_W   = CROSSING_ROAD_W   -- 8
    local ARM_LEN  = ROAD_W + 0.5      -- 8.5
    local ARM_HALF = ARM_LEN / 2       -- 4.25 = CROSSING_HALF
    local PIVOT_Y  = CROSSING_PIVOT_Y  -- 3.8
    local ROAD_Y   = 0.1

    local C_WHITE  = Color3.fromRGB(238, 238, 238)
    local C_RED    = Color3.fromRGB(215, 20, 20)
    local C_BLACK  = Color3.fromRGB(28, 28, 28)
    local C_YELLOW = Color3.fromRGB(242, 190, 0)
    local C_ROAD   = Color3.fromRGB(32, 32, 32)

    -- ── 路面 ────────────────────────────────────────────────────
    local road = mkP(model, "CrossRoad",
        Vector3.new(160, 0.2, ROAD_W),
        Vector3.new(0, ROAD_Y, z),
        C_ROAD, Enum.Material.SmoothPlastic, true)
    road.CanCollide = false

    local cl = mkP(model, "CenterLine",
        Vector3.new(160, 0.05, 0.3),
        Vector3.new(0, ROAD_Y + 0.12, z),
        C_WHITE, nil, true)
    cl.CanCollide = false

    for _, dz in ipairs({ -(ROAD_W / 2 - 0.3), ROAD_W / 2 - 0.3 }) do
        local bl = mkP(model, "BoundLine_" .. math.floor(dz),
            Vector3.new(160, 0.05, 0.5),
            Vector3.new(0, ROAD_Y + 0.12, z + dz),
            C_YELLOW, nil, true)
        bl.CanCollide = false
    end

    -- ── 進入路 ──────────────────────────────────────────────────
    local apW = mkP(model, "ApproachW", Vector3.new(58, 0.2, ROAD_W),
        Vector3.new(-51, ROAD_Y, z), C_ROAD, Enum.Material.SmoothPlastic)
    apW.CanCollide = false
    local apE = mkP(model, "ApproachE", Vector3.new(58, 0.2, ROAD_W),
        Vector3.new(51, ROAD_Y, z), C_ROAD, Enum.Material.SmoothPlastic)
    apE.CanCollide = false

    -- ── 踏切内 舗装（レール間）──────────────────────────────
    mkP(model, "InnerRoad",
        Vector3.new(44, 0.22, ROAD_W),
        Vector3.new(0, ROAD_Y + 0.01, z),
        Color3.fromRGB(55, 50, 45), Enum.Material.SmoothPlastic, true).CanCollide = false

    -- ── 警報ポスト + 遮断機（各軌道群 E/W × 2） ─────────────
    for _, xs in ipairs({ -1, 1 }) do
        local px    = xs * 21          -- ローカル X（世界 X = px + 40）
        local sfxG  = xs > 0 and "E" or "W"
        local pX_w  = px + WORLD_OFFSET.X
        local pivotZ_w = z - ARM_HALF  -- 道路南端ピボット

        -- 各道路側 (南北) に警報ポスト + 警告灯
        for _, zs in ipairs({ -1, 1 }) do
            local pz  = z + zs * (ROAD_W / 2 + 1.6)
            local sfx = sfxG .. (zs > 0 and "N" or "S")

            -- 白い警報ポスト本体
            mkP(model, "WarnPost_" .. sfx,
                Vector3.new(0.38, 6.2, 0.38),
                Vector3.new(px, 3.1, pz),
                C_WHITE, Enum.Material.SmoothPlastic)
            -- ポスト先端キャップ
            mkP(model, "WarnCap_" .. sfx,
                Vector3.new(0.58, 0.28, 0.58),
                Vector3.new(px, 6.34, pz),
                C_WHITE)

            -- 踏切警告灯（赤ネオン球、2個横並び）
            for _, lx in ipairs({ -0.55, 0.55 }) do
                local lp = mkP(model, "Lamp_" .. sfx .. "_" .. (lx > 0 and "R" or "L"),
                    Vector3.new(0.85, 0.85, 0.85),
                    Vector3.new(px + lx, 6.55, pz),
                    Color3.fromRGB(220, 15, 15), Enum.Material.Neon)
                lp.Shape = Enum.PartType.Ball
                lp.CanCollide = false
            end

            -- X 字踏切標識（黄色、2本斜め棒）
            local XSIGN_Y = 5.2
            for ai, angle in ipairs({ math.rad(40), math.rad(-40) }) do
                local xp = mkCF(model, "XSign_" .. sfx .. "_" .. ai,
                    Vector3.new(0.18, 0.18, 1.5),
                    CFrame.new(pX_w, XSIGN_Y, pz) * CFrame.Angles(0, angle, 0),
                    C_YELLOW)
                xp.CanCollide = false
            end
            -- X 標識の中心円
            local xc = mkP(model, "XCenter_" .. sfx,
                Vector3.new(0.4, 0.4, 0.4),
                Vector3.new(px, XSIGN_Y, pz),
                C_BLACK)
            xc.Shape = Enum.PartType.Ball
            xc.CanCollide = false
        end

        -- 遮断機取り付けポスト（白、道路南側）
        mkP(model, "GatePost_" .. sfxG,
            Vector3.new(0.42, PIVOT_Y * 2, 0.42),
            Vector3.new(px, PIVOT_Y, z - ARM_HALF - 1.6),
            C_WHITE)
        -- ブラケット（黒）
        mkP(model, "GateBracket_" .. sfxG,
            Vector3.new(0.58, 0.58, 0.58),
            Vector3.new(px, PIVOT_Y, z - ARM_HALF),
            C_BLACK)

        -- ── 遮断機腕木（アニメーション対象、^Gate_ で CrossingManager が拾う）
        -- 回転: -π/2 around X → ローカル Z が ワールド Y 方向（上向き）
        -- d = オフセット（arm center から）、raised 時 world Y = PIVOT_Y + ARM_HALF + d

        local function raisedCF(d)
            return CFrame.new(pX_w, PIVOT_Y + ARM_HALF + d, pivotZ_w)
                   * CFrame.Angles(-math.pi / 2, 0, 0)
        end

        -- 腕木本体（赤）
        mkCF(model, "Gate_" .. sfxG,
            Vector3.new(0.22, 0.38, ARM_LEN),
            raisedCF(0),
            C_RED)

        -- 白ストライプ（8本、腕木に重ねる）
        for i, d in ipairs({ -8.75, -6.25, -3.75, -1.25, 1.25, 3.75, 6.25, 8.75 }) do
            mkCF(model, "Gate_" .. sfxG .. "_S" .. i,
                Vector3.new(0.26, 0.46, 1.0),
                raisedCF(d),
                C_WHITE)
        end

        -- 先端ネオン球
        local tipPart = mkCF(model, "Gate_" .. sfxG .. "_Tip",
            Vector3.new(0.6, 0.6, 0.6),
            raisedCF(ARM_HALF - 0.15),
            Color3.fromRGB(220, 15, 15), Enum.Material.Neon)
        tipPart.Shape = Enum.PartType.Ball
        tipPart.CanCollide = false

        -- カウンターウェイト（黒スタブ、Gate_ プレフィックスでアニメーション対象）
        mkCF(model, "Gate_CW_" .. sfxG,
            Vector3.new(0.32, 0.32, 1.0),
            raisedCF(-(ARM_HALF - 0.3)),
            C_BLACK)

        -- 腕木サポートワイヤ（斜め細棒、見た目のみ）
        local wireAngle = math.atan2(ARM_HALF * 0.75, 0.22)
        local wirePart = mkCF(model, "GateWire_" .. sfxG,
            Vector3.new(0.12, 0.12, ARM_HALF * 0.78),
            CFrame.new(pX_w, PIVOT_Y + ARM_HALF * 0.6, pivotZ_w)
            * CFrame.Angles(-math.pi / 2 + wireAngle * 0.5, 0, 0),
            Color3.fromRGB(130, 130, 130))
        wirePart.CanCollide = false

        -- オーバーヘッドアーチ（道路をまたぐ横梁）
        mkP(model, "Arch_" .. sfxG,
            Vector3.new(0.3, 0.3, ROAD_W + 4.5),
            Vector3.new(px, 7.8, z),
            C_WHITE)
        -- アーチ支柱（道路両端）
        for _, zs in ipairs({ -1, 1 }) do
            mkP(model, "ArchPillar_" .. sfxG .. (zs > 0 and "N" or "S"),
                Vector3.new(0.3, 7.9, 0.3),
                Vector3.new(px, 3.95, z + zs * (ROAD_W / 2 + 2.0)),
                C_WHITE)
            -- アーチ灯（赤ネオン）
            local al = mkP(model, "ArchLamp_" .. sfxG .. (zs > 0 and "N" or "S"),
                Vector3.new(0.7, 0.7, 0.7),
                Vector3.new(px, 7.65, z + zs * (ROAD_W / 2 + 0.5)),
                Color3.fromRGB(220, 15, 15), Enum.Material.Neon)
            al.Shape = Enum.PartType.Ball
            al.CanCollide = false
        end
    end

    -- ── 信号機（道路西側 = ローカル X ≈ -25）─────────────────
    for _, zs in ipairs({ -1, 1 }) do
        local sz  = z + zs * (ROAD_W / 2 + 1.7)
        local sfx = zs > 0 and "N" or "S"

        mkP(model, "SigPost_" .. sfx,
            Vector3.new(0.34, 8.5, 0.34),
            Vector3.new(-25, 4.25, sz),
            Color3.fromRGB(55, 55, 55))
        mkP(model, "SigBody_" .. sfx,
            Vector3.new(1.3, 3.8, 0.95),
            Vector3.new(-25, 8.4, sz),
            C_BLACK)
        -- 信号ランプ（赤/黄/緑）
        local sigColors = {
            Color3.fromRGB(200, 18, 18),
            Color3.fromRGB(200, 145, 0),
            Color3.fromRGB(10, 185, 55),
        }
        for li, yl in ipairs({ 9.65, 8.4, 7.15 }) do
            local sl = mkP(model, "SigLamp_" .. sfx .. "_" .. li,
                Vector3.new(0.82, 0.82, 0.82),
                Vector3.new(-25, yl, sz + 0.5),
                sigColors[li], Enum.Material.SmoothPlastic)
            sl.Shape = Enum.PartType.Ball
            sl.CanCollide = false
        end
        -- 信号アーム（横に張り出す）
        mkP(model, "SigArm_" .. sfx,
            Vector3.new(0.22, 0.22, 2.1),
            Vector3.new(-25, 8.5, sz + 1.05),
            Color3.fromRGB(55, 55, 55))
    end

    -- ── ボラード（道路進入部の黄黒ポスト）────────────────────
    for _, zs in ipairs({ -1, 1 }) do
        local bz = z + zs * (ROAD_W / 2 + 0.55)
        for i = 1, 4 do
            local bx = -23.5 + (i - 1) * 1.7
            local bp = mkP(model, "Bollard_" .. (zs > 0 and "N" or "S") .. "_" .. i,
                Vector3.new(0.48, 1.3, 0.48),
                Vector3.new(bx, 0.65, bz),
                C_YELLOW, Enum.Material.SmoothPlastic)
            -- 黒帯（ボラードに重ねる）
            mkP(model, "BollardBand_" .. (zs > 0 and "N" or "S") .. "_" .. i,
                Vector3.new(0.52, 0.28, 0.52),
                Vector3.new(bx, 0.75, bz),
                C_BLACK, Enum.Material.SmoothPlastic)
        end
    end

    -- ── CrossingZ ──────────────────────────────────────────────
    local sv = Instance.new("StringValue")
    sv.Name   = "CrossingZ"
    sv.Value  = tostring(z)
    sv.Parent = model

    print(string.format("[RailwayTestBuilder] 踏切 '%s' Z=%d", modelName, z))
end

-- 踏切 1: 立花〜芦屋
local CROSSING_Z_1 = math.floor((STATIONS[5].z + STATIONS[6].z) / 2)   -- ≈ -8270
-- 踏切 2: 塚本〜尼崎
local CROSSING_Z_2 = math.floor((STATIONS[2].z + STATIONS[3].z) / 2)   -- = 30
-- 踏切 3: 芦屋〜西芦屋
local CROSSING_Z_3 = math.floor((STATIONS[6].z + STATIONS[7].z) / 2)   -- = -11370
-- 踏切 4: 加古川〜加古川商店街
local CROSSING_Z_4 = math.floor((STATIONS[18].z + STATIONS[19].z) / 2) -- = -48020

buildRailwayCrossing("RailwayCrossing_TachibaraAshiya",    CROSSING_Z_1)
buildRailwayCrossing("RailwayCrossing_TsukamoAmagasaki",   CROSSING_Z_2)
buildRailwayCrossing("RailwayCrossing_AshiyaNishiAshiya",  CROSSING_Z_3)
buildRailwayCrossing("RailwayCrossing_KakogawaShotengai",  CROSSING_Z_4)

-- ============================================================
-- 沿線地盤 & 風景の生成
-- ============================================================
math.randomseed(54321)
local function rr(lo, hi) return lo + math.random() * (hi - lo) end
local _si = 0
local function nsi() _si += 1; return tostring(_si) end

-- ── 地盤生成 ─────────────────────────────────────────────────
local CONCRETE_COL = Color3.fromRGB(162, 162, 155)
local SOIL_COL     = Color3.fromRGB(112,  85,  52)

local function buildSceneryGround(label, zFrom, zTo, xFrom, xTo, color, mat)
    local w  = math.abs(xTo - xFrom)
    local xc = (xFrom + xTo) / 2
    local z = zFrom; local idx = 0
    while z < zTo do
        local seg = math.min(SEG_LEN, zTo - z)
        mkP(folder, "SGnd"..label..idx,
            Vector3.new(w, 0.2, seg),
            Vector3.new(xc, -0.1, z + seg/2),
            color, mat)
        z += seg; idx += 1
    end
end

-- Zone A（4線・都市部）: コンクリート
buildSceneryGround("AL", Z_4T_END, TRACK_END_Z, -82, -28, CONCRETE_COL, Enum.Material.Concrete)
buildSceneryGround("AR", Z_4T_END, TRACK_END_Z,  28,  82, CONCRETE_COL, Enum.Material.Concrete)
-- Zone B上部（西明石〜海姫路）: コンクリート
buildSceneryGround("BcL", STATIONS[20].z, Z_4T_END, -68, -22, CONCRETE_COL, Enum.Material.Concrete)
buildSceneryGround("BcR", STATIONS[20].z, Z_4T_END,  22,  68, CONCRETE_COL, Enum.Material.Concrete)
-- Zone B下部（姫路〜海姫路）: 土
buildSceneryGround("BsL", Z_2T_END, STATIONS[20].z, -65, -22, SOIL_COL, Enum.Material.Ground)
buildSceneryGround("BsR", Z_2T_END, STATIONS[20].z,  22,  65, SOIL_COL, Enum.Material.Ground)
-- Zone C（1線・農村）: 土
buildSceneryGround("CL", -TRACK_HALF, Z_2T_END, -62, -22, SOIL_COL, Enum.Material.Ground)
buildSceneryGround("CR", -TRACK_HALF, Z_2T_END,  22,  62, SOIL_COL, Enum.Material.Ground)

-- ── 風景ヘルパー ──────────────────────────────────────────────
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

-- ── 駅近傍スキップ判定（マージンを距離スケールに合わせて拡大）──
local function nearSt(z, margin)
    margin = margin or 560   -- 旧68 → 560（約8倍・ホーム前後エリア）
    for _, st in ipairs(STATIONS) do
        if math.abs(z - st.z) < margin then return true end
    end
    return false
end

-- ── 大阪駅: 超高層ビル密集ゾーン（塚本〜バッファ端）─────────
-- リスポーン側（Z≥OSAKA_Z-150 の +X）はアクセス経路として空ける
do
    local z = STATIONS[2].z + 50   -- 塚本Z+50 = 1680
    while z <= TRACK_END_Z + 5 do
        for _, sx in ipairs({ -38,-52,-66,-80,  38,52,66,80 }) do
            if sx > 0 and z >= OSAKA_Z - 150 then continue end
            local h = (z >= OSAKA_Z - 60) and rr(30,65) or rr(20,50)
            scBuilding(sx+rr(-4,4), z+rr(-8,8), rr(8,15), h, rr(8,16))
        end
        z += rr(130, 230)
    end
end

-- ── 各駅周辺ビル群（大阪は除く）──────────────────────────────
for i, st in ipairs(STATIONS) do
    if i == 1 then continue end
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

-- ── 市街地〜住宅地（尼崎〜神戸三宮 Z≈-1570〜-18470）────────
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
        z += rr(310, 520)
    end
end

-- ── 阪神〜海沿い（神戸三宮〜西明石）住宅＋ビル＋六甲山背景 ─
do
    local mz = STATIONS[16].z
    while mz < STATIONS[9].z do
        scMountain(-rr(85,115), mz, rr(55,100), rr(22,44), rr(80,160))
        mz += rr(990, 1650)
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
        z += rr(330, 560)
    end
end

-- ── 郊外（西明石〜姫路）住宅・田んぼ・木混在 ─────────────
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
        z += rr(450, 780)
    end
end

-- ── 農村（姫路〜網干）田んぼ・農家・木立 ────────────────
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
        z += rr(650, 1160)
    end
end

-- 大阪駅スポーン・キオスク広場（駅を中心に ±110 stud でプレイヤーが落下しないよう拡張）
mkP(folder, "OsakaPlaza",
    Vector3.new(70, 0.5, 220),
    Vector3.new(36, 0.25, 4530),
    Color3.fromRGB(170, 170, 162), Enum.Material.Concrete)

-- ============================================================
-- 各車線スポーン地点マーカー
-- ============================================================
local SPAWN_Z      = 4530
local SPAWN_Y      = 1.0
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

-- 既存 SpawnLocation を全削除
for _, obj in ipairs(Workspace:GetChildren()) do
    if obj:IsA("SpawnLocation") then obj:Destroy() end
end

-- プレイヤースポーン地点
local spawnLoc = Instance.new("SpawnLocation")
spawnLoc.Name                  = "OsakaSpawn"
spawnLoc.Size                  = Vector3.new(6, 1, 6)
spawnLoc.Position              = Vector3.new(49 + WORLD_OFFSET.X, 1.0, 4552)
spawnLoc.Anchored              = true
spawnLoc.Neutral               = true
spawnLoc.AllowTeamChangeOnTouch = false
spawnLoc.Color                 = Color3.fromRGB(100, 200, 100)
spawnLoc.Material              = Enum.Material.SmoothPlastic
spawnLoc.TopSurface            = Enum.SurfaceType.Smooth
spawnLoc.Parent                = Workspace

-- TrainBuilder 起動同期シグナル
local sync = Instance.new("Part")
sync.Name         = "Platform"
sync.Size         = Vector3.new(0.1, 0.1, 0.1)
sync.Position     = Vector3.new(40, -50, 0)
sync.Transparency = 1
sync.CanCollide   = false
sync.Anchored     = true
sync.Parent       = folder

print(string.format(
    "[RailwayTestBuilder] %s を生成しました（%d 駅、駅間 2400〜3800 stud、平均 90 秒）。全長 ≈ 89570 stud",
    FOLDER_NAME, #STATIONS))
