-- 4輪自動車の生成・格納管理

local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OFFSET    = Vector3.new(40, 0, 0)
local RW_FOLDER = "RailwayTest"

-- RemoteEvents
local carRem = Instance.new("Folder")
carRem.Name   = "CarRemotes"
carRem.Parent = ReplicatedStorage

local function mkEv(name)
    local e = Instance.new("RemoteEvent"); e.Name = name; e.Parent = carRem; return e
end
local evtCarSpawn = mkEv("CarSpawn")
local evtCarStore = mkEv("CarStore")
local evtCarState = mkEv("CarState")

local carModel = nil

-- スポーン位置（大阪駅付近、線路から離れた場所）
local CAR_LX = 52     -- local X (OFFSET で world X = 92)
local CAR_LZ = 4505   -- local Z
local CAR_LY = 3.6    -- 初期高さ（落下してグランドに着地）

-- 色定義
local COL_BODY  = Color3.fromRGB( 25,  55, 120)
local COL_TRIM  = Color3.fromRGB( 15,  20,  35)
local COL_WHEEL = Color3.fromRGB( 22,  22,  22)
local COL_HUB   = Color3.fromRGB(150, 155, 165)
local COL_GLASS = Color3.fromRGB( 22,  60, 140)
local COL_HEAD  = Color3.fromRGB(255, 245, 200)
local COL_TAIL  = Color3.fromRGB(200,  10,  10)

-- ============================================================
-- 車生成
-- ============================================================
local function buildCar()
    if carModel then return end

    local rwf = Workspace:FindFirstChild(RW_FOLDER)
    if not rwf then return end

    carModel = Instance.new("Model")
    carModel.Name   = "PlayerCar"
    carModel.Parent = rwf

    -- 車が -Z 方向（駅方向）を向くよう CFrame を設定
    local baseCF = CFrame.new(Vector3.new(CAR_LX, CAR_LY, CAR_LZ) + OFFSET)

    -- VehicleSeat = 物理ルート（これが動くと溶接されたパーツもすべて動く）
    local seat = Instance.new("VehicleSeat")
    seat.Name            = "VehicleSeat"
    seat.Size            = Vector3.new(3.6, 0.5, 4.2)
    seat.CFrame          = baseCF
    seat.MaxSpeed        = 50        -- ≈ 180 km/h（1 stud = 1 m とした場合）
    seat.Torque          = 150
    seat.TurnSpeed       = 1.2
    seat.HeadsUpDisplay  = false
    seat.Color           = COL_BODY
    seat.Material        = Enum.Material.SmoothPlastic
    seat.TopSurface      = Enum.SurfaceType.Smooth
    seat.BottomSurface   = Enum.SurfaceType.Smooth
    seat.CanCollide      = true
    seat.Anchored        = false
    seat.Parent          = carModel
    carModel.PrimaryPart = seat

    -- パーツ追加ヘルパー（すべて VehicleSeat に溶接）
    local function p(name, size, cf, col, mat, canCol)
        local pt = Instance.new("Part")
        pt.Name          = name
        pt.Size          = size
        pt.CFrame        = cf
        pt.Color         = col or COL_BODY
        pt.Material      = mat or Enum.Material.SmoothPlastic
        pt.TopSurface    = Enum.SurfaceType.Smooth
        pt.BottomSurface = Enum.SurfaceType.Smooth
        pt.CanCollide    = canCol == true
        pt.Anchored      = false
        pt.Parent        = carModel
        local w = Instance.new("WeldConstraint")
        w.Part0 = seat; w.Part1 = pt; w.Parent = carModel
        return pt
    end

    -- シャーシ（主な当たり判定）
    p("Chassis",  Vector3.new(7.4, 1.2, 17),
        baseCF * CFrame.new(0, -0.9, 0.4), COL_TRIM, nil, true)

    -- 左右サイドボディ
    p("SideL", Vector3.new(0.25, 2.0, 8),
        baseCF * CFrame.new(-3.55, 0.55, 0.4), COL_BODY)
    p("SideR", Vector3.new(0.25, 2.0, 8),
        baseCF * CFrame.new( 3.55, 0.55, 0.4), COL_BODY)

    -- ルーフ
    p("Roof", Vector3.new(6.4, 0.25, 7.5),
        baseCF * CFrame.new(0, 1.88, 0.4), COL_BODY)

    -- ダッシュボード前面（フロント仕切り）
    p("DashFront", Vector3.new(6.4, 1.9, 0.25),
        baseCF * CFrame.new(0, 0.65, -2.2), COL_BODY)

    -- フロントガラス（斜め）
    p("Windshield", Vector3.new(6.0, 2.2, 0.22),
        baseCF * CFrame.new(0, 1.0, -4.5) * CFrame.Angles(math.rad(-24), 0, 0),
        COL_GLASS, Enum.Material.Glass)

    -- リアガラス（斜め）
    p("RearWindow", Vector3.new(6.0, 1.9, 0.22),
        baseCF * CFrame.new(0, 1.0, 5.0) * CFrame.Angles(math.rad(22), 0, 0),
        COL_GLASS, Enum.Material.Glass)

    -- ボンネット
    p("Hood", Vector3.new(7.4, 0.5, 6.5),
        baseCF * CFrame.new(0, 0.22, -7.5), COL_BODY)

    -- トランク
    p("Trunk", Vector3.new(7.4, 0.75, 4.5),
        baseCF * CFrame.new(0, 0.32, 7.2), COL_BODY)

    -- フロントバンパー
    p("BumperF", Vector3.new(7.4, 1.0, 0.6),
        baseCF * CFrame.new(0, -0.45, -10.8), COL_TRIM)

    -- リアバンパー
    p("BumperR", Vector3.new(7.4, 1.0, 0.6),
        baseCF * CFrame.new(0, -0.45, 10.8), COL_TRIM)

    -- ヘッドライト（Neon）
    for _, sx in ipairs({-2.7, 2.7}) do
        p("Head" .. (sx < 0 and "L" or "R"),
            Vector3.new(2.0, 0.6, 0.4),
            baseCF * CFrame.new(sx, 0.22, -10.5),
            COL_HEAD, Enum.Material.Neon)
    end

    -- テールライト（Neon）
    for _, sx in ipairs({-2.7, 2.7}) do
        p("Tail" .. (sx < 0 and "L" or "R"),
            Vector3.new(2.2, 0.5, 0.4),
            baseCF * CFrame.new(sx, 0.25, 10.5),
            COL_TAIL, Enum.Material.Neon)
    end

    -- ホイール 4本（シリンダー、X 軸周りに回転）
    -- Size: (幅=0.75, 直径=2.4, 直径=2.4)  ※ Y が軸長
    -- 回転: CFrame.Angles(0,0,π/2) でタイヤを立てる
    for _, w in ipairs({
        {"WheelFL", -3.8, -1.05, -6.5},
        {"WheelFR",  3.8, -1.05, -6.5},
        {"WheelRL", -3.8, -1.05,  6.8},
        {"WheelRR",  3.8, -1.05,  6.8},
    }) do
        local wp = p(w[1], Vector3.new(0.75, 2.4, 2.4),
            baseCF * CFrame.new(w[2], w[3], w[4]) * CFrame.Angles(0, 0, math.pi / 2),
            COL_WHEEL)
        wp.Shape = Enum.PartType.Cylinder
    end

    -- ホイールハブ（外側の小さな円盤）
    for _, w in ipairs({
        {"HubFL", -4.15, -1.05, -6.5},
        {"HubFR",  4.15, -1.05, -6.5},
        {"HubRL", -4.15, -1.05,  6.8},
        {"HubRR",  4.15, -1.05,  6.8},
    }) do
        local wp = p(w[1], Vector3.new(0.2, 1.5, 1.5),
            baseCF * CFrame.new(w[2], w[3], w[4]) * CFrame.Angles(0, 0, math.pi / 2),
            COL_HUB)
        wp.Shape = Enum.PartType.Cylinder
    end

    evtCarState:FireAllClients(true)
    print("[CarManager] 車を生成しました（世界座標 X=" ..
        (CAR_LX + OFFSET.X) .. ", Z=" .. CAR_LZ .. "）")
end

-- ============================================================
-- 車格納
-- ============================================================
local function storeCar()
    if not carModel then return end

    -- 着席中のプレイヤーを強制降車
    for _, desc in ipairs(carModel:GetDescendants()) do
        if desc:IsA("VehicleSeat") and desc.Occupant then
            desc.Occupant.Sit = false
        end
    end
    task.wait(0.1)

    carModel:Destroy()
    carModel = nil
    evtCarState:FireAllClients(false)
    print("[CarManager] 車を格納しました")
end

evtCarSpawn.OnServerEvent:Connect(function()
    buildCar()
end)

evtCarStore.OnServerEvent:Connect(function()
    storeCar()
end)

-- 起動: RailwayTest が生成されるまで待機
repeat task.wait(1) until
    Workspace:FindFirstChild(RW_FOLDER) and
    Workspace:FindFirstChild(RW_FOLDER):FindFirstChild("Platform")

print("[CarManager] 車管理システム準備完了")
