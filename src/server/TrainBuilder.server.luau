-- 223系2000番台 4両編成の生成・管理

local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- クライアントとの通信用 RemoteEvent
local remotes = Instance.new("Folder")
remotes.Name  = "TrainRemotes"
remotes.Parent = ReplicatedStorage

local evRespawn = Instance.new("RemoteEvent")
evRespawn.Name  = "RespawnTrain"
evRespawn.Parent = remotes

local evStore  = Instance.new("RemoteEvent")
evStore.Name   = "StoreTrain"
evStore.Parent = remotes

-- ============================================================
-- 定数 (RailwayTestBuilder と同じ WORLD_OFFSET を使用)
-- ============================================================
local OFFSET    = Vector3.new(40, 0, 0)
local RW_FOLDER = "RailwayTest"

local CLEN    = 24      -- 車両長 (Z方向)
local CWID    = 8       -- 車両幅 (X方向)
local CHGT    = 6       -- 車両高さ (Y方向)
local CBOT    = 1.5     -- 車両底面のY座標
local SPACING = CLEN + 1.5
local NCARS   = 4

-- 223系2000番台カラーパレット
local C = {
    body       = Color3.fromRGB(215, 215, 215),
    stripe     = Color3.fromRGB(0,   100, 180),
    window     = Color3.fromRGB(25,  30,  45),
    roof       = Color3.fromRGB(175, 175, 175),
    underframe = Color3.fromRGB(45,  45,  45),
    front      = Color3.fromRGB(20,  20,  20),
    headlight  = Color3.fromRGB(255, 245, 200),
    taillight  = Color3.fromRGB(210, 10,  10),
    seat       = Color3.fromRGB(40,  40,  40),
}

local trainModel = nil

-- ============================================================
-- ヘルパー
-- ============================================================
local function mkPart(parent, name, size, localPos, color)
    local p = Instance.new("Part")
    p.Name         = name
    p.Size         = size
    p.Position     = localPos + OFFSET
    p.Anchored     = true
    p.Color        = color
    p.TopSurface   = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent       = parent
    return p
end

local function getOrCreateFolder(parent, name)
    local f = parent:FindFirstChild(name)
    if not f then
        f = Instance.new("Folder")
        f.Name   = name
        f.Parent = parent
    end
    return f
end

-- ============================================================
-- 1両分の構築
-- ============================================================
local function buildCar(trainParent, idx, cz, hasFront, hasRear)
    local car = Instance.new("Model")
    car.Name   = "Car" .. idx
    car.Parent = trainParent

    local cy = CBOT + CHGT / 2   -- 車体中心Y

    -- 車体本体
    mkPart(car, "Body",
        Vector3.new(CWID, CHGT, CLEN),
        Vector3.new(0, cy, cz), C.body)

    -- 屋根
    mkPart(car, "Roof",
        Vector3.new(CWID, 0.55, CLEN),
        Vector3.new(0, CBOT + CHGT + 0.27, cz), C.roof)

    -- 床下機器
    mkPart(car, "Underframe",
        Vector3.new(CWID - 0.4, 0.6, CLEN - 1),
        Vector3.new(0, CBOT - 0.3, cz), C.underframe)

    -- 側面パーツ（左右対称）
    for _, s in ipairs({ -1, 1 }) do
        local sx  = s * (CWID / 2 + 0.06)
        local tag = s < 0 and "L" or "R"

        -- 青帯（下側）
        mkPart(car, "Stripe" .. tag,
            Vector3.new(0.12, 1.0, CLEN),
            Vector3.new(sx, CBOT + 1.4, cz), C.stripe)

        -- 窓帯（上側）
        mkPart(car, "Windows" .. tag,
            Vector3.new(0.12, CHGT * 0.44, CLEN - 1),
            Vector3.new(sx, CBOT + CHGT * 0.67, cz), C.window)
    end

    -- 妻面（前端 or 後端）の構築
    local function buildEnd(dirZ)
        -- dirZ: -1=前方(Z-)、+1=後方(Z+)
        local fz  = cz + dirZ * (CLEN / 2)
        local tk  = 0.35
        local tag = dirZ < 0 and "F" or "R"

        -- 妻面ベース（黒）
        mkPart(car, "EndFace" .. tag,
            Vector3.new(CWID, CHGT + 0.6, tk),
            Vector3.new(0, cy + 0.3, fz + dirZ * tk / 2), C.front)

        -- フロントガラス
        mkPart(car, "Windshield" .. tag,
            Vector3.new(CWID * 0.55, 1.9, tk + 0.1),
            Vector3.new(0, CBOT + CHGT * 0.63, fz + dirZ * tk), C.window)

        -- 前照灯・尾灯（左右）
        for _, s in ipairs({ -1, 1 }) do
            local sx = s * CWID * 0.31
            local lt = s < 0 and "L" or "R"
            mkPart(car, "Head" .. lt .. tag,
                Vector3.new(0.9, 0.5, tk + 0.12),
                Vector3.new(sx, CBOT + CHGT * 0.8, fz + dirZ * tk), C.headlight)
            mkPart(car, "Tail" .. lt .. tag,
                Vector3.new(0.7, 0.4, tk + 0.1),
                Vector3.new(sx, CBOT + 0.75, fz + dirZ * tk), C.taillight)
        end
    end

    if hasFront then
        buildEnd(-1)

        -- 運転席シート（Car1前方から3 stud内側）
        local seat = Instance.new("Seat")
        seat.Name        = "DriverSeat"
        seat.Size        = Vector3.new(1.5, 0.5, 1.5)
        seat.Position    = Vector3.new(OFFSET.X, CBOT + 1.2, cz - CLEN / 2 + 3)
        seat.Anchored    = true
        seat.Color       = C.seat
        seat.TopSurface  = Enum.SurfaceType.Smooth
        seat.BottomSurface = Enum.SurfaceType.Smooth
        seat.Parent      = car
    end

    if hasRear then
        buildEnd(1)
    end
end

-- ============================================================
-- 列車全体の生成
-- ============================================================
local function buildTrain()
    if trainModel then
        trainModel:Destroy()
        trainModel = nil
    end

    local rwFolder = getOrCreateFolder(Workspace, RW_FOLDER)

    local existing = rwFolder:FindFirstChild("Train")
    if existing then existing:Destroy() end

    local train = Instance.new("Model")
    train.Name   = "Train"
    train.Parent = rwFolder
    trainModel   = train

    for i = 1, NCARS do
        local cz = (i - (NCARS + 1) / 2) * SPACING
        buildCar(train, i, cz,
            i == 1,       -- Car1: 前方運転台
            i == NCARS)   -- Car4: 後方運転台
    end

    print("[TrainBuilder] 223系2000番台 4両編成を生成しました。")
end

-- ============================================================
-- 列車の格納
-- ============================================================
local function storeTrain()
    if trainModel then
        trainModel:Destroy()
        trainModel = nil
        print("[TrainBuilder] 列車を格納しました。")
    end
end

-- 起動時に生成
buildTrain()

-- RemoteEvent ハンドラ
evRespawn.OnServerEvent:Connect(function() buildTrain() end)
evStore.OnServerEvent:Connect(function()   storeTrain()  end)
