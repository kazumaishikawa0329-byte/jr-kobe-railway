-- 223系2000番台 4両編成の生成・管理（ワールド内コントロールパネル付き）

local Workspace = game:GetService("Workspace")

-- RailwayTestBuilder と同一オフセット
local OFFSET    = Vector3.new(40, 0, 0)
local RW_FOLDER = "RailwayTest"

-- 車両寸法
local CLEN    = 24      -- 車両長 (Z方向)
local CWID    = 8       -- 車両幅 (X方向)
local CHGT    = 6       -- 車両高さ (Y方向)
local CBOT    = 1.5     -- 車両底面 Y
local SPACING = CLEN + 1.5
local NCARS   = 4

-- 223系2000番台カラー（実物写真準拠）
local C = {
    body     = Color3.fromRGB(196, 198, 194),   -- ステンレス銀
    door     = Color3.fromRGB(186, 188, 184),   -- ドア（わずかに暗め）
    stripe   = Color3.fromRGB(0,   82,  160),   -- JR西日本ブルー
    window   = Color3.fromRGB(22,  28,  45),    -- 濃紺窓
    sill     = Color3.fromRGB(55,  60,  72),    -- 窓下ライン
    roof     = Color3.fromRGB(158, 160, 155),   -- 屋根
    skirt    = Color3.fromRGB(35,  35,  35),    -- 床下・パンタ
    front    = Color3.fromRGB(12,  12,  12),    -- 前面（ほぼ黒）
    headlamp = Color3.fromRGB(255, 250, 215),   -- 前照灯（白）
    taillamp = Color3.fromRGB(195, 8,   8),     -- 尾灯（赤）
    dest     = Color3.fromRGB(225, 145, 0),     -- 行先表示LED（橙）
    coupler  = Color3.fromRGB(75,  75,  75),    -- 連結器
    seat     = Color3.fromRGB(38,  48,  72),    -- 運転席シート
    indic    = Color3.fromRGB(255, 228, 0),     -- 乗車インジケーター（黄）
    btnBlue  = Color3.fromRGB(0,   100, 180),   -- 呼出ボタン
    btnDark  = Color3.fromRGB(55,  55,  65),    -- 格納ボタン
}

local trainModel = nil
local rwFolder   = nil

-- 前方宣言（ClickDetector コールバックから参照するため）
local buildTrain
local storeTrain

-- ============================================================
-- ヘルパー
-- ============================================================
local function mkP(parent, name, size, lp, color, mat)
    local p = Instance.new("Part")
    p.Name          = name
    p.Size          = size
    p.Position      = lp + OFFSET
    p.Anchored      = true
    p.Color         = color
    p.Material      = mat or Enum.Material.SmoothPlastic
    p.TopSurface    = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent        = parent
    return p
end

-- ============================================================
-- 1両の構築
-- ============================================================
local function buildCar(parent, idx, cz, hasFront, hasRear)
    local car = Instance.new("Model")
    car.Name   = "Car" .. idx
    car.Parent = parent

    local cy = CBOT + CHGT / 2

    -- 車体本体（ステンレス銀）
    mkP(car, "Body", Vector3.new(CWID, CHGT, CLEN),
        Vector3.new(0, cy, cz), C.body)

    -- 屋根（本体よりやや暗め）
    mkP(car, "Roof", Vector3.new(CWID, 0.55, CLEN),
        Vector3.new(0, CBOT + CHGT + 0.27, cz), C.roof)

    -- 床下スカート（車体より僅かに広く、暗色）
    mkP(car, "Skirt", Vector3.new(CWID + 0.3, 0.65, CLEN + 0.1),
        Vector3.new(0, CBOT - 0.325, cz), C.skirt)

    -- 屋根上機器（ベンチレーター）
    mkP(car, "RoofEquip", Vector3.new(1.2, 0.38, 3.0),
        Vector3.new(0, CBOT + CHGT + 0.47, cz - 5), C.skirt)

    -- パンタグラフ（M車: Car1・Car3）
    if idx == 1 or idx == 3 then
        local py = CBOT + CHGT + 0.55   -- 屋根上面Y
        mkP(car, "PantBase", Vector3.new(1.6, 0.22, 0.9),
            Vector3.new(0, py + 0.11, cz + 5), C.skirt)
        mkP(car, "PantArm", Vector3.new(0.12, 1.6, 0.12),
            Vector3.new(0, py + 0.91, cz + 5), C.skirt)
        mkP(car, "PantContact", Vector3.new(CWID * 0.48, 0.1, 0.28),
            Vector3.new(0, py + 1.71, cz + 5), C.skirt)
    end

    -- 側面パーツ（左右対称）
    for _, s in ipairs({ -1, 1 }) do
        local sx  = s * (CWID / 2 + 0.07)
        local tag = s < 0 and "L" or "R"

        -- 青帯（下部）
        mkP(car, "Stripe" .. tag, Vector3.new(0.11, 0.95, CLEN),
            Vector3.new(sx, CBOT + 1.35, cz), C.stripe)

        -- 窓帯（上部、濃紺）
        mkP(car, "WinBand" .. tag, Vector3.new(0.11, CHGT * 0.43, CLEN - 0.4),
            Vector3.new(sx, CBOT + CHGT * 0.685, cz), C.window)

        -- 窓下ライン（水平）
        mkP(car, "Sill" .. tag, Vector3.new(0.11, 0.18, CLEN),
            Vector3.new(sx, CBOT + CHGT * 0.455, cz), C.sill)

        -- ドア4箇所（将来のドア開閉に対応した命名・サイズ）
        for d, doff in ipairs({ -9, -3, 3, 9 }) do
            mkP(car, "Door" .. tag .. d, Vector3.new(0.1, CHGT * 0.70, 1.65),
                Vector3.new(sx, CBOT + CHGT * 0.35, cz + doff), C.door)
        end
    end

    -- 妻面（前端・後端）
    local function buildEnd(dirZ)
        local fz  = cz + dirZ * (CLEN / 2)
        local tk  = 0.32
        local tag = dirZ < 0 and "F" or "R"
        local face = dirZ < 0 and Enum.NormalId.Front or Enum.NormalId.Back

        -- 妻面ベース（ほぼ黒）
        mkP(car, "EndFace" .. tag, Vector3.new(CWID, CHGT + 0.55, tk),
            Vector3.new(0, cy + 0.27, fz + dirZ * tk / 2), C.front)

        -- フロントガラス（上部、濃紺）
        mkP(car, "Shield" .. tag, Vector3.new(CWID * 0.58, CHGT * 0.33, tk + 0.1),
            Vector3.new(0, CBOT + CHGT * 0.71, fz + dirZ * tk), C.window)

        -- 行先表示板（オレンジLED）
        local dp = mkP(car, "Dest" .. tag, Vector3.new(CWID * 0.24, 0.45, tk + 0.06),
            Vector3.new(0, CBOT + CHGT * 0.94, fz + dirZ * tk), C.dest)
        local dsg = Instance.new("SurfaceGui")
        dsg.Face = face; dsg.Parent = dp
        local dlbl = Instance.new("TextLabel")
        dlbl.Size = UDim2.fromScale(1, 1); dlbl.BackgroundTransparency = 1
        dlbl.Text = "快速　神戸"; dlbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        dlbl.TextScaled = true; dlbl.Font = Enum.Font.GothamBold; dlbl.Parent = dsg

        -- 前照灯（実物に近い下寄り配置、左右）
        for _, s in ipairs({ -1, 1 }) do
            local hx = s * CWID * 0.31
            local lt = s < 0 and "L" or "R"
            -- ヘッドライト本体（白）
            mkP(car, "Head" .. lt .. tag, Vector3.new(1.1, 0.58, tk + 0.12),
                Vector3.new(hx, CBOT + CHGT * 0.38, fz + dirZ * tk), C.headlamp)
            -- 尾灯（赤、ヘッドライトより下）
            mkP(car, "Tail" .. lt .. tag, Vector3.new(0.75, 0.38, tk + 0.1),
                Vector3.new(hx, CBOT + CHGT * 0.16, fz + dirZ * tk), C.taillamp)
        end

        -- 連結器（中央下部）
        mkP(car, "Coupler" .. tag, Vector3.new(0.8, 0.55, 0.85),
            Vector3.new(0, CBOT - 0.2, fz + dirZ * (tk + 0.42)), C.coupler)
    end

    if hasFront then buildEnd(-1) end
    if hasRear  then buildEnd(1)  end

    -- 運転席（Car1のみ）
    if hasFront then
        local frontZ = cz - CLEN / 2   -- 前面Z（ローカル）

        -- シート：車体前方の外側に配置（プレイヤーがアクセス可能）
        local seat = Instance.new("Seat")
        seat.Name          = "DriverSeat"
        seat.Size          = Vector3.new(1.8, 0.5, 1.8)
        seat.Position      = Vector3.new(OFFSET.X, 1.0, frontZ - 2.5)
        seat.Anchored      = true
        seat.Color         = C.seat
        seat.TopSurface    = Enum.SurfaceType.Smooth
        seat.BottomSurface = Enum.SurfaceType.Smooth
        seat.Parent        = car

        -- 乗車位置インジケーター（Neonスフィア + BillboardGui）
        local ind = mkP(car, "SeatIndicator", Vector3.new(0.65, 0.65, 0.65),
            Vector3.new(0, 4.5, frontZ - 2.5), C.indic, Enum.Material.Neon)
        ind.Shape      = Enum.PartType.Ball
        ind.CanCollide = false

        local bbg = Instance.new("BillboardGui")
        bbg.Size        = UDim2.fromOffset(155, 46)
        bbg.StudsOffset = Vector3.new(0, 1.5, 0)
        bbg.AlwaysOnTop = true
        bbg.Parent      = ind

        local bbl = Instance.new("TextLabel")
        bbl.Size                   = UDim2.fromScale(1, 1)
        bbl.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
        bbl.BackgroundTransparency = 0.22
        bbl.Text                   = "▼ 運転席 [E]"
        bbl.TextColor3             = Color3.fromRGB(255, 230, 0)
        bbl.TextSize               = 17
        bbl.Font                   = Enum.Font.GothamBold
        bbl.Parent                 = bbg
        local bbcr = Instance.new("UICorner")
        bbcr.CornerRadius = UDim.new(0, 5); bbcr.Parent = bbl
    end
end

-- ============================================================
-- ワールド内コントロールパネルの生成（起動時に1度のみ）
-- ============================================================
local function buildControlPanel()
    if rwFolder:FindFirstChild("TrainControlPanel") then return end

    local cp = Instance.new("Model")
    cp.Name   = "TrainControlPanel"
    cp.Parent = rwFolder

    -- ホームの後端付近（local: X=5.5, Z=11〜13）
    local pnlX = 5.5    -- プラットフォーム中心X（ローカル）
    local pnlZ = 12.0   -- ホーム後端付近Z（ローカル）

    -- 案内支柱
    mkP(cp, "Post", Vector3.new(0.3, 2.5, 0.3),
        Vector3.new(pnlX, CBOT + 1.25, pnlZ + 1.2), C.skirt)

    -- 案内看板（X-方向がプレイヤー接近方向）
    local sign = mkP(cp, "Sign", Vector3.new(0.15, 0.9, 3.6),
        Vector3.new(pnlX - 0.075, CBOT + 3.15, pnlZ + 1.2), C.front)
    local ssg = Instance.new("SurfaceGui")
    ssg.Face = Enum.NormalId.Left; ssg.Parent = sign
    local sl = Instance.new("TextLabel")
    sl.Size = UDim2.fromScale(1, 1); sl.BackgroundTransparency = 1
    sl.Text = "列車コントロール"; sl.TextColor3 = Color3.fromRGB(255, 220, 0)
    sl.TextScaled = true; sl.Font = Enum.Font.GothamBold; sl.Parent = ssg

    -- ClickDetector付きボタン生成
    local function makeBtn(name, label, color, bz, cb)
        local btn = mkP(cp, name, Vector3.new(2.8, 0.4, 1.5),
            Vector3.new(pnlX, 1.2 + 0.2, bz), color)
        local sg = Instance.new("SurfaceGui")
        sg.Face = Enum.NormalId.Top; sg.Parent = btn
        local l = Instance.new("TextLabel")
        l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 1
        l.Text = label; l.TextColor3 = Color3.fromRGB(255, 255, 255)
        l.TextScaled = true; l.Font = Enum.Font.GothamBold; l.Parent = sg
        local cd = Instance.new("ClickDetector")
        cd.MaxActivationDistance = 12; cd.Parent = btn
        cd.MouseClick:Connect(function() cb() end)
    end

    makeBtn("SpawnBtn", "▶ 列車を呼び出す", C.btnBlue, pnlZ,       function() buildTrain() end)
    makeBtn("StoreBtn", "■ 列車を格納する",  C.btnDark, pnlZ + 2.0, function() storeTrain() end)
end

-- ============================================================
-- 列車の格納
-- ============================================================
storeTrain = function()
    if trainModel then
        trainModel:Destroy()
        trainModel = nil
        print("[TrainBuilder] 列車を格納しました。")
    end
end

-- ============================================================
-- 列車の生成
-- ============================================================
buildTrain = function()
    if trainModel then
        trainModel:Destroy()
        trainModel = nil
    end
    local existing = rwFolder:FindFirstChild("Train")
    if existing then existing:Destroy() end

    local train = Instance.new("Model")
    train.Name   = "Train"
    train.Parent = rwFolder
    trainModel   = train

    for i = 1, NCARS do
        local cz = (i - (NCARS + 1) / 2) * SPACING
        buildCar(train, i, cz, i == 1, i == NCARS)
    end

    print("[TrainBuilder] 223系2000番台 4両編成を生成しました。")
end

-- ============================================================
-- 初期化
-- ============================================================
rwFolder = Workspace:FindFirstChild(RW_FOLDER)
if not rwFolder then
    rwFolder = Instance.new("Folder")
    rwFolder.Name   = RW_FOLDER
    rwFolder.Parent = Workspace
end

buildControlPanel()   -- コントロールパネルは1回のみ生成
buildTrain()          -- 起動時に列車を生成
