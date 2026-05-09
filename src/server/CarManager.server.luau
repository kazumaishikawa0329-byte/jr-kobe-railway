-- 4輪自動車の生成・格納・手動運転管理

local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
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
local evtCarSpawn    = mkEv("CarSpawn")
local evtCarStore    = mkEv("CarStore")
local evtCarState    = mkEv("CarState")
local evtCarDrive    = mkEv("CarDrive")      -- client→server: (throttle, steer)
local evtCarDismount = mkEv("CarDismount")   -- client→server: 降車要求

-- スポーン位置（大阪駅付近）
local CAR_LX = 52
local CAR_LZ = 4505
local CAR_LY = 2.0   -- 全パーツ Anchored、シャーシ底面 ≈ Y=0.5 に合わせた高さ

-- 走行パラメータ
local MAX_SPEED  = 50    -- studs/s ≈ 180 km/h
local REV_SPEED  = 10    -- 後退最高速
local ACCEL_RATE = 8     -- studs/s²
local BRAKE_RATE = 20    -- studs/s²
local TURN_RATE  = 1.6   -- rad/s（速度に比例して増減）

-- 色定義
local COL_BODY  = Color3.fromRGB( 25,  55, 120)
local COL_TRIM  = Color3.fromRGB( 15,  20,  35)
local COL_WHEEL = Color3.fromRGB( 22,  22,  22)
local COL_HUB   = Color3.fromRGB(150, 155, 165)
local COL_GLASS = Color3.fromRGB( 22,  60, 140)
local COL_HEAD  = Color3.fromRGB(255, 245, 200)
local COL_TAIL  = Color3.fromRGB(200,  10,  10)

-- 状態
local carModel          = nil
local carParts          = nil   -- {{part=BasePart, offset=CFrame}, ...}
local carRootCF         = nil   -- 車のルート CFrame（Seat の位置・向き）
local carSpeed          = 0
local carThrottle       = 0    -- -1/0/1
local carSteer          = 0    -- -1/0/1
local driverSeat        = nil  -- Seat インスタンス
local seatPrompt        = nil  -- ProximityPrompt
local prevOccupantChar  = nil  -- 直前の乗員キャラ（降車時グループ復元用）

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

    local baseCF = CFrame.new(Vector3.new(CAR_LX, CAR_LY, CAR_LZ) + OFFSET)

    -- ドライバーシート（Seat = 全パーツの基準 CFrame）
    local seat = Instance.new("Seat")
    seat.Name          = "DriverSeat"
    seat.Size          = Vector3.new(3.6, 0.5, 4.2)
    seat.CFrame        = baseCF
    seat.Anchored      = true
    seat.Color         = COL_BODY
    seat.Material      = Enum.Material.SmoothPlastic
    seat.TopSurface    = Enum.SurfaceType.Smooth
    seat.BottomSurface = Enum.SurfaceType.Smooth
    seat.CanCollide    = true
    seat.Parent        = carModel
    carModel.PrimaryPart = seat
    driverSeat = seat

    -- 乗車 ProximityPrompt
    local pp = Instance.new("ProximityPrompt")
    pp.ActionText            = "乗車"
    pp.ObjectText            = "自動車"
    pp.KeyboardKeyCode       = Enum.KeyCode.F
    pp.MaxActivationDistance = 8
    pp.RequiresLineOfSight   = false
    pp.HoldDuration          = 0
    pp.Parent                = seat
    seatPrompt = pp

    pp.Triggered:Connect(function(player)
        local char = player.Character
        local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
        if hum and not seat.Occupant then
            seat:Sit(hum)
            pp.Enabled = false
        end
    end)

    seat:GetPropertyChangedSignal("Occupant"):Connect(function()
        if seat.Occupant then
            local char = seat.Occupant.Parent
            if char then
                prevOccupantChar = char
                for _, desc in ipairs(char:GetDescendants()) do
                    if desc:IsA("BasePart") then
                        desc.CollisionGroup = "Car"
                    end
                end
            end
        else
            if prevOccupantChar then
                for _, desc in ipairs(prevOccupantChar:GetDescendants()) do
                    if desc:IsA("BasePart") then
                        pcall(function() desc.CollisionGroup = "Default" end)
                    end
                end
                prevOccupantChar = nil
            end
            if seatPrompt then seatPrompt.Enabled = true end
            carThrottle = 0
            carSteer    = 0
        end
    end)

    -- パーツ追加ヘルパー（すべて Anchored=true）
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
        pt.Anchored      = true
        pt.Parent        = carModel
        return pt
    end

    -- シャーシ
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

    -- ダッシュボード前面
    p("DashFront", Vector3.new(6.4, 1.9, 0.25),
        baseCF * CFrame.new(0, 0.65, -2.2), COL_BODY)

    -- フロントガラス
    p("Windshield", Vector3.new(6.0, 2.2, 0.22),
        baseCF * CFrame.new(0, 1.0, -4.5) * CFrame.Angles(math.rad(-24), 0, 0),
        COL_GLASS, Enum.Material.Glass)

    -- リアガラス
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

    -- ヘッドライト
    for _, sx in ipairs({-2.7, 2.7}) do
        p("Head" .. (sx < 0 and "L" or "R"),
            Vector3.new(2.0, 0.6, 0.4),
            baseCF * CFrame.new(sx, 0.22, -10.5),
            COL_HEAD, Enum.Material.Neon)
    end

    -- テールライト
    for _, sx in ipairs({-2.7, 2.7}) do
        p("Tail" .. (sx < 0 and "L" or "R"),
            Vector3.new(2.2, 0.5, 0.4),
            baseCF * CFrame.new(sx, 0.25, 10.5),
            COL_TAIL, Enum.Material.Neon)
    end

    -- ホイール 4本
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

    -- ホイールハブ
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

    -- パーツのローカルオフセットを記録（CFrame 更新用）
    carRootCF = baseCF
    carParts  = {}
    for _, desc in ipairs(carModel:GetDescendants()) do
        if desc:IsA("BasePart") then
            desc.CollisionGroup = "Car"
            table.insert(carParts, {part = desc, offset = carRootCF:Inverse() * desc.CFrame})
        end
    end
    carSpeed    = 0
    carThrottle = 0
    carSteer    = 0

    evtCarState:FireAllClients(true)
    print("[CarManager] 車を生成しました")
end

-- ============================================================
-- 車格納
-- ============================================================
local function storeCar()
    if not carModel then return end

    if driverSeat and driverSeat.Occupant then
        local char = driverSeat.Occupant.Parent
        if char then
            for _, desc in ipairs(char:GetDescendants()) do
                if desc:IsA("BasePart") then
                    pcall(function() desc.CollisionGroup = "Default" end)
                end
            end
        end
        driverSeat.Occupant.Sit = false
        task.wait(0.05)
    end
    prevOccupantChar = nil

    carModel:Destroy()
    carModel    = nil
    carParts    = nil
    carRootCF   = nil
    driverSeat  = nil
    seatPrompt  = nil
    carSpeed    = 0
    carThrottle = 0
    carSteer    = 0

    evtCarState:FireAllClients(false)
    print("[CarManager] 車を格納しました")
end

-- ============================================================
-- 走行ループ（列車と同方式: Anchored パーツの CFrame を毎フレーム更新）
-- ============================================================
RunService.Heartbeat:Connect(function(dt)
    if not carModel or not carParts or not carRootCF then return end

    -- ドライバーが降りたら停止
    if not (driverSeat and driverSeat.Occupant) then
        carThrottle = 0; carSteer = 0
    end

    -- 速度更新
    if carThrottle > 0 then
        carSpeed = math.min(MAX_SPEED, carSpeed + ACCEL_RATE * dt)
    elseif carThrottle < 0 then
        carSpeed = math.min(REV_SPEED, carSpeed + ACCEL_RATE * dt)
    else
        carSpeed = math.max(0, carSpeed - BRAKE_RATE * dt)
    end

    if carSpeed <= 0 then return end

    -- ステアリング（速度に比例）
    local speedFactor = math.min(1, carSpeed / 12) ^ 0.7
    local turnAmt     = -carSteer * TURN_RATE * speedFactor * dt
    carRootCF = carRootCF * CFrame.Angles(0, turnAmt, 0)

    -- 前後移動（local -Z = 前進、local +Z = 後退）
    if carThrottle > 0 then
        carRootCF = carRootCF * CFrame.new(0, 0, -carSpeed * dt)
    else
        carRootCF = carRootCF * CFrame.new(0, 0,  carSpeed * dt)
    end

    -- 全パーツ CFrame 更新
    for _, entry in ipairs(carParts) do
        local pt = entry.part
        if pt and pt.Parent then
            pt.CFrame = carRootCF * entry.offset
        end
    end
end)

-- ============================================================
-- イベント処理
-- ============================================================
evtCarSpawn.OnServerEvent:Connect(function()
    buildCar()
end)

evtCarStore.OnServerEvent:Connect(function()
    storeCar()
end)

evtCarDrive.OnServerEvent:Connect(function(player, t, s)
    if not driverSeat or not driverSeat.Occupant then return end
    if driverSeat.Occupant.Parent ~= player.Character then return end
    carThrottle = type(t) == "number" and math.clamp(t, -1, 1) or 0
    carSteer    = type(s) == "number" and math.clamp(s, -1, 1) or 0
end)

evtCarDismount.OnServerEvent:Connect(function(player)
    if not driverSeat then return end
    if driverSeat.Occupant and driverSeat.Occupant.Parent == player.Character then
        carThrottle = 0; carSteer = 0
        driverSeat.Disabled = true
        task.defer(function()
            if driverSeat then driverSeat.Disabled = false end
        end)
    end
end)

-- 起動待機
repeat task.wait(1) until
    Workspace:FindFirstChild(RW_FOLDER) and
    Workspace:FindFirstChild(RW_FOLDER):FindFirstChild("Platform")

print("[CarManager] 車管理システム準備完了")
