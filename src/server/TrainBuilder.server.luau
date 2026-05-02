-- 223系2000番台 4両編成の生成・管理

local Workspace = game:GetService("Workspace")

local OFFSET    = Vector3.new(40, 0, 0)   -- RailwayTestBuilder と同一
local RW_FOLDER = "RailwayTest"

local CLEN    = 24
local CWID    = 8
local CHGT    = 6
local CBOT    = 1.5
local SPACING = CLEN + 1.5
local NCARS   = 4

local C = {
    body     = Color3.fromRGB(196, 198, 194),
    door     = Color3.fromRGB(186, 188, 184),
    stripe   = Color3.fromRGB(0,   82,  160),
    window   = Color3.fromRGB(22,  28,  45),
    sill     = Color3.fromRGB(55,  60,  72),
    roof     = Color3.fromRGB(158, 160, 155),
    skirt    = Color3.fromRGB(35,  35,  35),
    front    = Color3.fromRGB(12,  12,  12),
    headlamp = Color3.fromRGB(255, 250, 215),
    taillamp = Color3.fromRGB(195, 8,   8),
    dest     = Color3.fromRGB(225, 145, 0),
    coupler  = Color3.fromRGB(75,  75,  75),
    seat     = Color3.fromRGB(38,  48,  72),
    boarding = Color3.fromRGB(240, 185, 0),    -- 乗車マーカー（黄）
    kiosk    = Color3.fromRGB(28,  34,  50),   -- キオスク本体
    kioskTop = Color3.fromRGB(0,   180, 255),  -- キオスク上部（Neon）
    btnBlue  = Color3.fromRGB(0,   95,  175),
    btnDark  = Color3.fromRGB(50,  50,  62),
    screen   = Color3.fromRGB(8,   12,  20),
}

local trainModel  = nil
local rwFolder    = nil
local statusLabel = nil   -- キオスクのステータス表示ラベル

-- ClickDetector コールバックから参照するため前方宣言
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

local function addText(part, face, text, color)
    local sg  = Instance.new("SurfaceGui")
    sg.Face   = face
    sg.Parent = part
    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = text
    lbl.TextColor3             = color or Color3.fromRGB(255, 255, 255)
    lbl.TextScaled             = true
    lbl.Font                   = Enum.Font.GothamBold
    lbl.Parent                 = sg
    return lbl
end

-- ============================================================
-- 1両の構築
-- ============================================================
local function buildCar(parent, idx, cz, hasFront, hasRear)
    local car = Instance.new("Model")
    car.Name   = "Car" .. idx
    car.Parent = parent

    local cy = CBOT + CHGT / 2

    -- 車体・屋根・スカート
    mkP(car, "Body",      Vector3.new(CWID, CHGT, CLEN),         Vector3.new(0, cy, cz),              C.body)
    mkP(car, "Roof",      Vector3.new(CWID, 0.55, CLEN),         Vector3.new(0, CBOT+CHGT+0.27, cz),  C.roof)
    mkP(car, "Skirt",     Vector3.new(CWID+0.3, 0.65, CLEN+0.1), Vector3.new(0, CBOT-0.325, cz),      C.skirt)
    mkP(car, "RoofEquip", Vector3.new(1.2, 0.38, 3.0),           Vector3.new(0, CBOT+CHGT+0.47, cz-5),C.skirt)

    -- パンタグラフ（M車: Car1・Car3）
    if idx == 1 or idx == 3 then
        local py = CBOT + CHGT + 0.55
        mkP(car, "PantBase",    Vector3.new(1.6, 0.22, 0.9),       Vector3.new(0, py+0.11, cz+5), C.skirt)
        mkP(car, "PantArm",     Vector3.new(0.12, 1.6, 0.12),      Vector3.new(0, py+0.91, cz+5), C.skirt)
        mkP(car, "PantContact", Vector3.new(CWID*0.48, 0.1, 0.28), Vector3.new(0, py+1.71, cz+5), C.skirt)
    end

    -- 側面（左右対称）
    for _, s in ipairs({ -1, 1 }) do
        local sx  = s * (CWID / 2 + 0.07)
        local tag = s < 0 and "L" or "R"
        mkP(car, "Stripe"..tag,  Vector3.new(0.11, 0.95, CLEN),          Vector3.new(sx, CBOT+1.35, cz),        C.stripe)
        mkP(car, "WinBand"..tag, Vector3.new(0.11, CHGT*0.43, CLEN-0.4), Vector3.new(sx, CBOT+CHGT*0.685, cz), C.window)
        mkP(car, "Sill"..tag,    Vector3.new(0.11, 0.18, CLEN),          Vector3.new(sx, CBOT+CHGT*0.455, cz), C.sill)
        for d, doff in ipairs({ -9, -3, 3, 9 }) do
            mkP(car, "Door"..tag..d, Vector3.new(0.1, CHGT*0.70, 1.65),
                Vector3.new(sx, CBOT+CHGT*0.35, cz+doff), C.door)
        end
    end

    -- 妻面
    local function buildEnd(dirZ)
        local fz   = cz + dirZ * (CLEN / 2)
        local tk   = 0.32
        local tag  = dirZ < 0 and "F" or "R"
        local face = dirZ < 0 and Enum.NormalId.Front or Enum.NormalId.Back

        mkP(car, "EndFace"..tag, Vector3.new(CWID, CHGT+0.55, tk),
            Vector3.new(0, cy+0.27, fz+dirZ*tk/2), C.front)
        mkP(car, "Shield"..tag,  Vector3.new(CWID*0.58, CHGT*0.33, tk+0.1),
            Vector3.new(0, CBOT+CHGT*0.71, fz+dirZ*tk), C.window)

        local dp = mkP(car, "Dest"..tag, Vector3.new(CWID*0.24, 0.45, tk+0.06),
            Vector3.new(0, CBOT+CHGT*0.94, fz+dirZ*tk), C.dest)
        addText(dp, face, "快速　神戸", Color3.fromRGB(255, 255, 255))

        for _, s in ipairs({ -1, 1 }) do
            local hx = s * CWID * 0.31
            local lt = s < 0 and "L" or "R"
            mkP(car, "Head"..lt..tag, Vector3.new(1.1, 0.58, tk+0.12),
                Vector3.new(hx, CBOT+CHGT*0.38, fz+dirZ*tk), C.headlamp)
            mkP(car, "Tail"..lt..tag, Vector3.new(0.75, 0.38, tk+0.1),
                Vector3.new(hx, CBOT+CHGT*0.16, fz+dirZ*tk), C.taillamp)
        end
        mkP(car, "Coupler"..tag, Vector3.new(0.8, 0.55, 0.85),
            Vector3.new(0, CBOT-0.2, fz+dirZ*(tk+0.42)), C.coupler)
    end

    if hasFront then buildEnd(-1) end
    if hasRear  then buildEnd(1)  end

    -- 乗務員室（前方・後方どちらにも対応）
    local function buildCab(dirZ)
        local faceZ   = cz + dirZ * (CLEN / 2)    -- 妻面Z（ローカル）
        local markerZ = faceZ + dirZ * 2.2         -- 車体外側 2.2 stud

        -- 地面の乗車マーカー（黄色プレート）
        local marker = mkP(car, "BoardMarker"..(dirZ < 0 and "F" or "R"),
            Vector3.new(2.8, 0.22, 2.8),
            Vector3.new(0, 0.11, markerZ), C.boarding)

        -- 乗車案内テキスト（Top面に「乗車口」）
        addText(marker, Enum.NormalId.Top, "乗車口 ▲", Color3.fromRGB(0, 0, 0))

        -- DriverSeat（マーカーの少し上）
        local seat = Instance.new("Seat")
        seat.Name          = "DriverSeat"
        seat.Size          = Vector3.new(1.8, 0.5, 1.8)
        seat.Position      = Vector3.new(OFFSET.X, 0.85, markerZ)
        seat.Anchored      = true
        seat.Color         = C.seat
        seat.TopSurface    = Enum.SurfaceType.Smooth
        seat.BottomSurface = Enum.SurfaceType.Smooth
        seat.Parent        = car

        -- ProximityPrompt（マーカー上、プレイヤーが近づいて E で乗車）
        local prompt = Instance.new("ProximityPrompt")
        prompt.ActionText            = "乗車する"
        prompt.ObjectText            = "運転席"
        prompt.KeyboardKeyCode       = Enum.KeyCode.E
        prompt.MaxActivationDistance = 7
        prompt.RequiresLineOfSight   = false
        prompt.HoldDuration          = 0
        prompt.Parent                = marker

        prompt.Triggered:Connect(function(player)
            local char = player.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then seat:Sit(hum) end
        end)
    end

    if hasFront then buildCab(-1) end   -- Car1 前方
    if hasRear  then buildCab(1)  end   -- Car4 後方
end

-- ============================================================
-- 列車コントロールキオスク（スポーン地点近くに1度だけ生成）
-- ============================================================
local function buildControlPanel()
    if rwFolder:FindFirstChild("TrainKiosk") then return end

    local cp = Instance.new("Model")
    cp.Name   = "TrainKiosk"
    cp.Parent = rwFolder

    -- スポーン地点(X=0)とホーム(X=40+)の中間、絶対 X=12
    -- ローカル座標: X = 12 - 40 = -28
    local kx = -28
    local kz = 0

    -- キオスク本体
    mkP(cp, "Body", Vector3.new(2.4, 2.4, 0.9), Vector3.new(kx, 1.2, kz), C.kiosk)

    -- 上部 Neon（遠くから視認できるよう光らせる）
    local top = mkP(cp, "Top", Vector3.new(2.6, 0.45, 1.1),
        Vector3.new(kx, 2.625, kz), C.kioskTop, Enum.Material.Neon)

    -- キオスクタイトル（BillboardGui、遠くから見える高さに配置）
    local bbg = Instance.new("BillboardGui")
    bbg.Size        = UDim2.fromOffset(210, 54)
    bbg.StudsOffset = Vector3.new(0, 2.2, 0)
    bbg.AlwaysOnTop = false
    bbg.Parent      = top
    local bbl = Instance.new("TextLabel")
    bbl.Size                   = UDim2.fromScale(1, 1)
    bbl.BackgroundColor3       = Color3.fromRGB(0, 50, 120)
    bbl.BackgroundTransparency = 0.08
    bbl.Text                   = "列車コントロール"
    bbl.TextColor3             = Color3.fromRGB(255, 255, 255)
    bbl.TextSize               = 16
    bbl.Font                   = Enum.Font.GothamBold
    bbl.Parent                 = bbg
    local bbcr = Instance.new("UICorner"); bbcr.CornerRadius = UDim.new(0, 5); bbcr.Parent = bbl

    -- キオスク正面はプレイヤー接近方向（Left = -X 面）
    -- ボタン類はキオスク本体から 0.16 stud 突出させて z-fighting を防ぐ
    local FACE = Enum.NormalId.Left
    local bx   = kx - 1.28   -- 本体左端 (kx-1.2) より 0.08 外側

    -- ステータス表示（上段）
    local scrPart = mkP(cp, "Screen", Vector3.new(0.16, 0.62, 2.0),
        Vector3.new(bx, 2.0, kz), C.screen)
    statusLabel = addText(scrPart, FACE, "列車: 格納中", Color3.fromRGB(0, 225, 110))

    -- 「→ 神戸駅（テスト）方面」 案内ライン
    local dirPart = mkP(cp, "DirSign", Vector3.new(0.16, 0.42, 2.0),
        Vector3.new(bx, 1.46, kz), C.screen)
    addText(dirPart, FACE, "→ X+ 方向が神戸駅", Color3.fromRGB(255, 220, 70))

    -- 呼び出しボタン（青）
    local spPart = mkP(cp, "SpawnBtn", Vector3.new(0.16, 0.58, 1.85),
        Vector3.new(bx, 0.82, kz), C.btnBlue)
    addText(spPart, FACE, "▶  列車を呼び出す", Color3.fromRGB(255, 255, 255))
    local spCd = Instance.new("ClickDetector")
    spCd.MaxActivationDistance = 12; spCd.Parent = spPart
    spCd.MouseClick:Connect(function() buildTrain() end)

    -- 格納ボタン（暗色）
    local stPart = mkP(cp, "StoreBtn", Vector3.new(0.16, 0.58, 1.85),
        Vector3.new(bx, 0.16, kz), C.btnDark)
    addText(stPart, FACE, "■  列車を格納する",  Color3.fromRGB(200, 200, 200))
    local stCd = Instance.new("ClickDetector")
    stCd.MaxActivationDistance = 12; stCd.Parent = stPart
    stCd.MouseClick:Connect(function() storeTrain() end)
end

-- ============================================================
-- 列車格納
-- ============================================================
storeTrain = function()
    if trainModel then
        trainModel:Destroy()
        trainModel = nil
        if statusLabel then statusLabel.Text = "列車: 格納中" end
        print("[TrainBuilder] 列車を格納しました。")
    end
end

-- ============================================================
-- 列車生成
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

    if statusLabel then statusLabel.Text = "列車: 運転中" end
    print("[TrainBuilder] 223系2000番台 4両編成を生成しました。")
end

-- ============================================================
-- 初期化
-- ============================================================
rwFolder = Workspace:FindFirstChild(RW_FOLDER)
if not rwFolder then
    rwFolder        = Instance.new("Folder")
    rwFolder.Name   = RW_FOLDER
    rwFolder.Parent = Workspace
end

buildControlPanel()   -- キオスクは起動時に1回のみ生成
buildTrain()          -- 列車は起動時に自動生成
