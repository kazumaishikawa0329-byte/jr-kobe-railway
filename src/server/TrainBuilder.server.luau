-- 223系2000番台 4両編成の生成・管理

local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local OFFSET    = Vector3.new(40, 0, 0)   -- RailwayTestBuilder と同一
local RW_FOLDER = "RailwayTest"

local CLEN    = 24
local CWID    = 8
local CHGT    = 6
local CBOT    = 1.5
local PLAT_H  = 1.2   -- RailwayTestBuilder と一致
local SPACING = CLEN + 1.5
local NCARS   = 4

local C = {
    body     = Color3.fromRGB(196, 198, 194),
    door     = Color3.fromRGB(168, 172, 178),  -- ドアパネル（車体よりやや濃いシルバー）
    doorWin  = Color3.fromRGB(22,  28,  45),   -- ドア窓ガラス
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
    boarding = Color3.fromRGB(240, 185, 0),
    kiosk    = Color3.fromRGB(28,  34,  50),
    kioskTop = Color3.fromRGB(0,   180, 255),
    btnBlue  = Color3.fromRGB(0,   95,  175),
    btnDark  = Color3.fromRGB(50,  50,  62),
    screen   = Color3.fromRGB(8,   12,  20),
}

-- 列車制御 RemoteEvent
local remotesFolder = Instance.new("Folder")
remotesFolder.Name   = "TrainRemotes"
remotesFolder.Parent = ReplicatedStorage
local evtSetDir   = Instance.new("RemoteEvent"); evtSetDir.Name   = "SetDirection"; evtSetDir.Parent = remotesFolder
local evtSetCtrl  = Instance.new("RemoteEvent"); evtSetCtrl.Name  = "SetControl";   evtSetCtrl.Parent = remotesFolder
local evtSpeedUpd = Instance.new("RemoteEvent"); evtSpeedUpd.Name = "SpeedUpdate";  evtSpeedUpd.Parent = remotesFolder
local evtDoorCtrl = Instance.new("RemoteEvent"); evtDoorCtrl.Name = "DoorControl";  evtDoorCtrl.Parent = remotesFolder
local evtDoorState= Instance.new("RemoteEvent"); evtDoorState.Name= "DoorState";    evtDoorState.Parent= remotesFolder

local rwFolder    = nil
local statusLabel = nil

-- Per-track 列車状態
local NUM_TRACKS     = 4
local trainModels    = {}
local trainPartsList = {}

local trainSpeeds = {}; local trainDirs = {}; local trainCtrls = {}
for t = 1, 4 do
    trainSpeeds[t] = 0; trainDirs[t] = 0; trainCtrls[t] = "加速停止"
end

-- ドア状態
local trainDoorOpen  = {}
local trainDoorParts = {}   -- [trackNum] = { {part=Part, openDir=number}, ... }
for t = 1, 4 do
    trainDoorOpen[t]  = false
    trainDoorParts[t] = {}
end

local MAX_SPEED  = 130
local ACCEL_RATE = 15
local BRAKE_RATE = 12
local EMERG_RATE = 45
local DOOR_SLIDE = 1.5   -- 片側パネルのスライド量（stud）
local DOOR_TWEEN = TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
-- ドア寸法定数
local DOOR_W  = 2.4          -- 開口幅（両パネル合計、stud）
local DOOR_H  = CHGT * 0.82  -- ドア高さ（≈ 4.92 stud）
local PNL_W   = DOOR_W / 2   -- 片側パネル幅（1.2 stud）
local DOOR_ZS = { -9, -3, 3, 9 }  -- ドア中心オフセット（Z）

local buildTrain
local storeTrain

local fireTrainStateChanged = function() end  -- TrainStateChanged 発行用（末尾で定義）

local function getSpawnShift(trackNum)
    local mark = rwFolder and rwFolder:FindFirstChild("TrackSpawn_" .. trackNum)
    if not mark then return Vector3.zero end
    return Vector3.new(mark.Position.X - OFFSET.X, 0, mark.Position.Z)
end

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
-- 1両の構築  doorList: ドアパーツ情報を格納するテーブル
-- ============================================================
local function buildCar(parent, idx, cz, hasFront, hasRear, doorList)
    local car = Instance.new("Model")
    car.Name   = "Car" .. idx
    car.Parent = parent

    local cy = CBOT + CHGT / 2

    local body = mkP(car, "Body",      Vector3.new(CWID, CHGT, CLEN),         Vector3.new(0, cy, cz),              C.body)
    body.CanCollide   = false
    body.Transparency = 1   -- 壁セグメントが外観を担うため不可視化（ドア越しに反対側が見える）
    mkP(car, "Roof",      Vector3.new(CWID, 0.55, CLEN),         Vector3.new(0, CBOT+CHGT+0.27, cz),  C.roof)
    local skirt = mkP(car, "Skirt", Vector3.new(CWID+0.3, 0.65, CLEN+0.1), Vector3.new(0, CBOT-0.325, cz), C.skirt)
    skirt.CanCollide = false
    mkP(car, "RoofEquip", Vector3.new(1.2, 0.38, 3.0),           Vector3.new(0, CBOT+CHGT+0.47, cz-5),C.skirt)

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
        local sdFace = s < 0 and Enum.NormalId.Left or Enum.NormalId.Right

        -- ──── 視覚デコレーション（ドア開口をスキップしてセグメント化）────
        local function buildStripes(name, height, centerY, color)
            local prev = cz - CLEN/2
            for si, dz_off in ipairs(DOOR_ZS) do
                local segEnd = cz + dz_off - PNL_W
                local segLen = segEnd - prev
                if segLen > 0.05 then
                    local p = mkP(car, name..tag..si, Vector3.new(0.11, height, segLen),
                        Vector3.new(sx, centerY, prev + segLen/2), color)
                    p.CanCollide = false
                end
                prev = cz + dz_off + PNL_W
            end
            local lastLen = (cz + CLEN/2) - prev
            if lastLen > 0.05 then
                local p = mkP(car, name..tag.."5", Vector3.new(0.11, height, lastLen),
                    Vector3.new(sx, centerY, prev + lastLen/2), color)
                p.CanCollide = false
            end
        end

        buildStripes("WinBand", CHGT*0.43, CBOT+CHGT*0.685, C.window)
        buildStripes("Stripe",  0.95,       CBOT+1.35,        C.stripe)
        buildStripes("Sill",    0.18,       CBOT+CHGT*0.455,  C.sill)

        -- ──── コリジョン壁（ドア開口以外の側壁）────
        -- 上部帯：ドア上端〜屋根、全幅
        local upperH = CHGT - DOOR_H
        local wTop = mkP(car, "WallTop"..tag,
            Vector3.new(0.18, upperH, CLEN),
            Vector3.new(sx, CBOT + DOOR_H + upperH/2, cz), C.body)
        wTop.CanCollide = true

        -- ドア高さ帯の壁セグメント（開口以外）
        local prevZ = cz - CLEN/2
        for wi, dz_off in ipairs(DOOR_ZS) do
            local openL  = cz + dz_off - PNL_W
            local segLen = openL - prevZ
            if segLen > 0.05 then
                local seg = mkP(car, "Wall"..tag..wi,
                    Vector3.new(0.18, DOOR_H, segLen),
                    Vector3.new(sx, CBOT + DOOR_H/2, prevZ + segLen/2), C.body)
                seg.CanCollide = true
            end
            prevZ = cz + dz_off + PNL_W
        end
        local lastLen = (cz + CLEN/2) - prevZ
        if lastLen > 0.05 then
            local seg = mkP(car, "Wall"..tag.."5",
                Vector3.new(0.18, DOOR_H, lastLen),
                Vector3.new(sx, CBOT + DOOR_H/2, prevZ + lastLen/2), C.body)
            seg.CanCollide = true
        end

        -- ──── ドア構造（両開き引き戸）────
        for di, dz_off in ipairs(DOOR_ZS) do
            local dz = cz + dz_off

            -- ドア枠：上部バー
            mkP(car, "DoorFrame"..tag..di,
                Vector3.new(0.22, 0.32, DOOR_W + 0.24),
                Vector3.new(sx, CBOT + DOOR_H + 0.16, dz), C.sill)

            -- ドア枠：左右縦ピラー
            for _, pSide in ipairs({ -1, 1 }) do
                mkP(car, "DoorPillar"..tag..di..(pSide<0 and "L" or "R"),
                    Vector3.new(0.22, DOOR_H, 0.24),
                    Vector3.new(sx, CBOT + DOOR_H/2, dz + pSide*(PNL_W + 0.12)), C.sill)
            end

            -- Aパネル（−Z 側、−Z 方向へスライド）
            local pa = mkP(car, "Door"..tag..di.."A",
                Vector3.new(0.18, DOOR_H * 0.62, PNL_W),
                Vector3.new(sx, CBOT + DOOR_H * 0.31, dz - PNL_W/2), C.door)
            pa.CanCollide = true
            -- Aパネル上部ガラス
            local paG = mkP(car, "DoorGlass"..tag..di.."A",
                Vector3.new(0.14, DOOR_H * 0.35, PNL_W - 0.1),
                Vector3.new(sx, CBOT + DOOR_H * 0.31 + DOOR_H * 0.62/2 + DOOR_H*0.35/2 - 0.05, dz - PNL_W/2), C.doorWin)
            paG.CanCollide = false
            if doorList then
                table.insert(doorList, { part = pa,  openDir = -1, collidable = true  })
                table.insert(doorList, { part = paG, openDir = -1, collidable = false })
            end

            -- Bパネル（+Z 側、+Z 方向へスライド）
            local pb = mkP(car, "Door"..tag..di.."B",
                Vector3.new(0.18, DOOR_H * 0.62, PNL_W),
                Vector3.new(sx, CBOT + DOOR_H * 0.31, dz + PNL_W/2), C.door)
            pb.CanCollide = true
            -- Bパネル上部ガラス
            local pbG = mkP(car, "DoorGlass"..tag..di.."B",
                Vector3.new(0.14, DOOR_H * 0.35, PNL_W - 0.1),
                Vector3.new(sx, CBOT + DOOR_H * 0.31 + DOOR_H * 0.62/2 + DOOR_H*0.35/2 - 0.05, dz + PNL_W/2), C.doorWin)
            pbG.CanCollide = false
            if doorList then
                table.insert(doorList, { part = pb,  openDir = 1,  collidable = true  })
                table.insert(doorList, { part = pbG, openDir = 1,  collidable = false })
            end
        end

        -- 側面行先表示板
        local sdx = s * (CWID / 2 + 0.09)
        local sdPart = mkP(car, "SideDest"..tag,
            Vector3.new(0.12, 1.5, 5.0),
            Vector3.new(sdx, CBOT + CHGT * 0.81, cz - 2), C.screen)
        local sg = Instance.new("SurfaceGui")
        sg.Face   = sdFace
        sg.Parent = sdPart
        local kindFr = Instance.new("Frame")
        kindFr.Size             = UDim2.new(1, 0, 0.42, 0)
        kindFr.BackgroundColor3 = Color3.fromRGB(0, 60, 160)
        kindFr.BorderSizePixel  = 0
        kindFr.Parent           = sg
        local kindLbl = Instance.new("TextLabel")
        kindLbl.Size                   = UDim2.fromScale(1, 1)
        kindLbl.BackgroundTransparency = 1
        kindLbl.Text                   = "新快速"
        kindLbl.TextColor3             = Color3.fromRGB(255, 255, 255)
        kindLbl.TextScaled             = true
        kindLbl.Font                   = Enum.Font.GothamBold
        kindLbl.Parent                 = kindFr
        local destFr = Instance.new("Frame")
        destFr.Size             = UDim2.new(1, 0, 0.58, 0)
        destFr.Position         = UDim2.new(0, 0, 0.42, 0)
        destFr.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
        destFr.BorderSizePixel  = 0
        destFr.Parent           = sg
        local destLbl = Instance.new("TextLabel")
        destLbl.Size                   = UDim2.fromScale(1, 1)
        destLbl.BackgroundTransparency = 1
        destLbl.Text                   = "姫路"
        destLbl.TextColor3             = Color3.fromRGB(225, 145, 0)
        destLbl.TextScaled             = true
        destLbl.Font                   = Enum.Font.GothamBold
        destLbl.Parent                 = destFr
    end

    -- ============================================================
    -- 車内（ドアを開けると見える内装）
    -- ============================================================
    -- 内装床（キャラクターが立てる・車幅いっぱい）
    local iFloor = mkP(car, "InteriorFloor",
        Vector3.new(CWID - 0.4, 0.18, CLEN - 0.4),
        Vector3.new(0, CBOT + 0.09, cz), Color3.fromRGB(92, 86, 76))
    iFloor.CanCollide = true
    iFloor.Material   = Enum.Material.SmoothPlastic

    -- 内装天井（視覚）
    local iCeil = mkP(car, "InteriorCeil",
        Vector3.new(CWID - 0.4, 0.16, CLEN - 0.4),
        Vector3.new(0, CBOT + CHGT - 0.08, cz), Color3.fromRGB(225, 222, 215))
    iCeil.CanCollide = false

    -- 室内灯（夜間: NightLight で制御）
    for li, lzOff in ipairs({ -(CLEN / 3), 0, CLEN / 3 }) do
        local lp = mkP(car, "IntLight" .. li, Vector3.new(0.18, 0.06, 0.18),
            Vector3.new(0, CBOT + CHGT - 0.12, cz + lzOff),
            Color3.fromRGB(255, 252, 228), Enum.Material.Neon)
        lp.CanCollide   = false
        lp.Transparency = 0.45
        local pl = Instance.new("PointLight")
        pl.Name       = "NightLight"
        pl.Brightness = 0.8
        pl.Range      = 7
        pl.Color      = Color3.fromRGB(255, 248, 215)
        pl.Enabled    = false
        pl.Parent     = lp
    end

    -- ロングシート（左右）
    for _, ss in ipairs({ -1, 1 }) do
        local stag = ss < 0 and "L" or "R"
        local sbx  = ss * (CWID/2 - 0.56)
        -- 座面
        local seat = mkP(car, "LongSeat"..stag,
            Vector3.new(0.85, 0.35, CLEN * 0.70),
            Vector3.new(sbx, CBOT + 0.175, cz), C.seat)
        seat.CanCollide = true
        -- 背もたれ
        local back = mkP(car, "SeatBack"..stag,
            Vector3.new(0.12, 0.55, CLEN * 0.70),
            Vector3.new(sbx - ss*0.37, CBOT + 0.55, cz), C.seat)
        back.CanCollide = false
    end

    -- 吊り手棒（天井パイプ）
    for _, hz in ipairs({ cz - 5, cz + 5 }) do
        local pole = mkP(car, "HoldBar"..math.floor(hz),
            Vector3.new(0.1, 0.1, CLEN * 0.80),
            Vector3.new(0, CBOT + CHGT - 0.55, hz), C.sill)
        pole.CanCollide = false
    end

    -- 妻面
    local function buildEnd(dirZ)
        local fz   = cz + dirZ * (CLEN / 2)
        local tk   = 0.32
        local tag  = dirZ < 0 and "F" or "R"
        local face = dirZ < 0 and Enum.NormalId.Front or Enum.NormalId.Back

        local ef = mkP(car, "EndFace"..tag, Vector3.new(CWID, CHGT+0.55, tk),
            Vector3.new(0, cy+0.27, fz+dirZ*tk/2), C.front)
        ef.CanCollide = false
        mkP(car, "Shield"..tag,  Vector3.new(CWID*0.58, CHGT*0.33, tk+0.1),
            Vector3.new(0, CBOT+CHGT*0.71, fz+dirZ*tk), C.window)

        local dp = mkP(car, "Dest"..tag, Vector3.new(CWID*0.55, 1.1, tk+0.06),
            Vector3.new(0, CBOT+CHGT*0.62, fz+dirZ*tk), C.dest)
        local dpSg = Instance.new("SurfaceGui"); dpSg.Face = face; dpSg.Parent = dp
        local dpKF = Instance.new("Frame")
        dpKF.Size = UDim2.new(1,0,0.42,0); dpKF.BackgroundColor3 = Color3.fromRGB(0,60,160)
        dpKF.BorderSizePixel = 0; dpKF.Parent = dpSg
        local dpKL = Instance.new("TextLabel")
        dpKL.Size = UDim2.fromScale(1,1); dpKL.BackgroundTransparency = 1
        dpKL.Text = "新快速"; dpKL.TextColor3 = Color3.fromRGB(255,255,255)
        dpKL.TextScaled = true; dpKL.Font = Enum.Font.GothamBold; dpKL.Parent = dpKF
        local dpDF = Instance.new("Frame")
        dpDF.Size = UDim2.new(1,0,0.58,0); dpDF.Position = UDim2.new(0,0,0.42,0)
        dpDF.BackgroundColor3 = Color3.fromRGB(8,8,8); dpDF.BorderSizePixel = 0; dpDF.Parent = dpSg
        local dpDL = Instance.new("TextLabel")
        dpDL.Size = UDim2.fromScale(1,1); dpDL.BackgroundTransparency = 1
        dpDL.Text = "姫路"; dpDL.TextColor3 = Color3.fromRGB(225,145,0)
        dpDL.TextScaled = true; dpDL.Font = Enum.Font.GothamBold; dpDL.Parent = dpDF

        for _, s in ipairs({ -1, 1 }) do
            local hx = s * CWID * 0.31
            local lt = s < 0 and "L" or "R"
            local headPart = mkP(car, "Head"..lt..tag, Vector3.new(1.1, 0.58, tk+0.12),
                Vector3.new(hx, CBOT+CHGT*0.38, fz+dirZ*tk), C.headlamp)
            local sl = Instance.new("SpotLight")
            sl.Name       = "NightLight"
            sl.Brightness = 4
            sl.Range      = 80
            sl.Angle      = 35
            sl.Color      = Color3.fromRGB(255, 248, 210)
            sl.Face       = dirZ < 0 and Enum.NormalId.Front or Enum.NormalId.Back
            sl.Enabled    = false
            sl.Parent     = headPart
            mkP(car, "Tail"..lt..tag, Vector3.new(0.75, 0.38, tk+0.1),
                Vector3.new(hx, CBOT+CHGT*0.16, fz+dirZ*tk), C.taillamp)
        end
        mkP(car, "Coupler"..tag, Vector3.new(0.8, 0.55, 0.85),
            Vector3.new(0, CBOT-0.2, fz+dirZ*(tk+0.42)), C.coupler)
    end

    if hasFront then buildEnd(-1) end
    if hasRear  then buildEnd(1)  end

    -- 乗務員室
    local function buildCab(dirZ)
        local faceZ   = cz + dirZ * (CLEN / 2)
        local markerZ = faceZ + dirZ * 2.2

        local marker = mkP(car, "BoardMarker"..(dirZ < 0 and "F" or "R"),
            Vector3.new(2.8, 0.22, 2.8),
            Vector3.new(0, 0.11, markerZ), C.boarding)

        addText(marker, Enum.NormalId.Top, "乗車口 ▲", Color3.fromRGB(0, 0, 0))

        local seatZ = faceZ - dirZ * 2.5
        local seat = Instance.new("Seat")
        seat.Name          = "DriverSeat"
        seat.Size          = Vector3.new(1.8, 0.5, 1.8)
        seat.CFrame        = CFrame.lookAt(
            Vector3.new(OFFSET.X, CBOT + 0.25, seatZ),
            Vector3.new(OFFSET.X, CBOT + 0.25, seatZ) + Vector3.new(0, 0, dirZ)
        )
        seat.Anchored      = true
        seat.Color         = C.seat
        seat.TopSurface    = Enum.SurfaceType.Smooth
        seat.BottomSurface = Enum.SurfaceType.Smooth
        seat.Parent        = car

        -- 前後どちらの運転台からでも乗車可能
        seat.Name     = "DriverSeat"
        seat.Disabled = true
    end

    if hasFront then buildCab(-1) end
    if hasRear  then buildCab(1)  end
end


-- ============================================================
-- ドア開閉
-- ============================================================
local function setDoorState(trackNum, isOpen)
    if trainDoorOpen[trackNum] == isOpen then return end
    trainDoorOpen[trackNum] = isOpen

    local parts = trainDoorParts[trackNum]
    if parts then
        for _, info in ipairs(parts) do
            local p = info.part
            if not p or not p.Parent then continue end
            if isOpen then
                p.CanCollide = false
                local targetPos = p.Position + Vector3.new(0, 0, info.openDir * DOOR_SLIDE)
                TweenService:Create(p, DOOR_TWEEN, {Position = targetPos}):Play()
            else
                local targetPos = p.Position - Vector3.new(0, 0, info.openDir * DOOR_SLIDE)
                local tw = TweenService:Create(p, DOOR_TWEEN, {Position = targetPos})
                tw:Play()
                local origCollide = info.collidable ~= nil and info.collidable or true
                tw.Completed:Connect(function()
                    if p and p.Parent then p.CanCollide = origCollide end
                end)
            end
        end
    end

    -- DriverSeat（進行方向側）のみドア連動で有効/無効を切り替え
    -- DriverSeatEnd（電車止め側）は常時 Disabled=true のまま変更しない
    local model = trainModels[trackNum]
    if model then
        for _, desc in ipairs(model:GetDescendants()) do
            if desc:IsA("Seat") and desc.Name == "DriverSeat" then
                if isOpen then
                    desc.Disabled = false
                end
            end
        end
    end

    -- ドアが開いた瞬間に走行中なら緊急制動
    if isOpen and trainSpeeds[trackNum] > 0 then
        trainCtrls[trackNum] = "急ブレーキ"
    end

    evtDoorState:FireAllClients(trackNum, isOpen)
    print(string.format("[TrainBuilder] %d番線ドア%s", trackNum, isOpen and "開放" or "閉鎖"))
end


-- ============================================================
-- 列車格納
-- ============================================================
storeTrain = function(trackNum)
    if trainModels[trackNum] then
        trainModels[trackNum]:Destroy()
        trainModels[trackNum]    = nil
        trainPartsList[trackNum] = nil
        trainDoorOpen[trackNum]  = false
        trainDoorParts[trackNum] = {}
        trainSpeeds[trackNum] = 0; trainDirs[trackNum] = 0; trainCtrls[trackNum] = "加速停止"
        evtSpeedUpd:FireAllClients(trackNum, 0)
        evtDoorState:FireAllClients(trackNum, false)
        print(string.format("[TrainBuilder] %d番線の列車を格納しました。", trackNum))
        fireTrainStateChanged(trackNum, false)
    end
    if statusLabel then
        local anyActive = false
        for t = 1, NUM_TRACKS do if trainModels[t] then anyActive = true; break end end
        statusLabel.Text = anyActive and "列車: 運転中" or "列車: 格納中"
    end
end

-- ============================================================
-- 列車生成
-- ============================================================
buildTrain = function(trackNum)
    if trainModels[trackNum] then
        print(string.format("[TrainBuilder] %d番線はすでに運転中です。", trackNum))
        return
    end

    local train = Instance.new("Model")
    train.Name   = "Train_" .. trackNum
    train.Parent = rwFolder
    trainModels[trackNum] = train

    local doorList = {}
    for i = 1, NCARS do
        local cz = (i - (NCARS + 1) / 2) * SPACING
        buildCar(train, i, cz, i == 1, i == NCARS, doorList)
    end

    local parts = {}
    for _, desc in ipairs(train:GetDescendants()) do
        if desc:IsA("BasePart") then
            desc.CollisionGroup = "Train"
            table.insert(parts, desc)
        end
    end
    trainPartsList[trackNum] = parts

    local shift = getSpawnShift(trackNum)
    for _, part in ipairs(parts) do
        part.CFrame = part.CFrame + shift
    end

    trainDoorOpen[trackNum]  = false
    trainDoorParts[trackNum] = doorList

    trainSpeeds[trackNum] = 0; trainDirs[trackNum] = 0; trainCtrls[trackNum] = "加速停止"
    evtSpeedUpd:FireAllClients(trackNum, 0)

    -- スポーン直後はドアを開放状態にする
    task.defer(function() setDoorState(trackNum, true) end)

    -- 夜間照明の初期状態を新しい列車に同期
    local nightVal = ReplicatedStorage:FindFirstChild("NightLightsOn")
    if nightVal and nightVal.Value then
        for _, desc in ipairs(train:GetDescendants()) do
            if desc:IsA("Light") and desc.Name == "NightLight" then
                desc.Enabled = true
            end
        end
    end

    print(string.format("[TrainBuilder] %d番線に223系2000番台を生成しました。", trackNum))
    fireTrainStateChanged(trackNum, true)
end


-- ============================================================
-- 初期化
-- ============================================================
repeat task.wait() until Workspace:FindFirstChild(RW_FOLDER)
    and Workspace:FindFirstChild(RW_FOLDER):FindFirstChild("Platform")

rwFolder = Workspace:FindFirstChild(RW_FOLDER)

-- ============================================================
-- 列車制御イベント
-- ============================================================
evtSetDir.OnServerEvent:Connect(function(_, trackNum, dirStr)
    if not trainDirs[trackNum] then return end
    if     dirStr == "前" then trainDirs[trackNum] = -1
    elseif dirStr == "後" then trainDirs[trackNum] =  1
    else                       trainDirs[trackNum] =  0 end
end)

evtSetCtrl.OnServerEvent:Connect(function(_, trackNum, ctrl)
    if trainCtrls[trackNum] ~= nil then
        -- ドアが開いている間は加速を受け付けない
        if trainDoorOpen[trackNum] and ctrl == "加速" then return end
        trainCtrls[trackNum] = ctrl
    end
end)

evtDoorCtrl.OnServerEvent:Connect(function(_, trackNum, isOpen)
    if trainModels[trackNum] and type(isOpen) == "boolean" then
        setDoorState(trackNum, isOpen)
    end
end)

-- ============================================================
-- 物理ループ
-- ============================================================
local speedTimer = 0
RunService.Heartbeat:Connect(function(dt)
    speedTimer += dt
    local doSpeedUpdate = speedTimer >= 0.1
    if doSpeedUpdate then speedTimer = 0 end

    for t = 1, NUM_TRACKS do
        local parts = trainPartsList[t]
        if not parts then continue end

        local spd  = trainSpeeds[t]
        local dir  = trainDirs[t]
        local ctrl = trainCtrls[t]

        if ctrl == "加速" and dir ~= 0 then
            spd = math.min(MAX_SPEED, spd + ACCEL_RATE * dt)
        elseif ctrl == "ブレーキ" then
            spd = math.max(0, spd - BRAKE_RATE * dt)
        elseif ctrl == "急ブレーキ" then
            spd = math.max(0, spd - EMERG_RATE * dt)
        end
        if dir == 0 then
            spd = math.max(0, spd - BRAKE_RATE * dt)
        end
        trainSpeeds[t] = spd

        if doSpeedUpdate then
            evtSpeedUpd:FireAllClients(t, math.floor(spd + 0.5))
        end

        if dir ~= 0 and spd > 0 then
            local v = Vector3.new(0, 0, spd * (1000 / 3600) * dt * dir)
            for _, part in ipairs(parts) do
                part.Position += v
            end
        end
    end
end)

-- ============================================================
-- 自動運行向けサーバー間インターフェース（BindableEvent/Function）
-- ============================================================
local autoCtrlEvt = Instance.new("BindableEvent")
autoCtrlEvt.Name   = "TrainAutoControl"
autoCtrlEvt.Parent = ReplicatedStorage

local autoQueryFn = Instance.new("BindableFunction")
autoQueryFn.Name   = "TrainAutoQuery"
autoQueryFn.Parent = ReplicatedStorage

autoCtrlEvt.Event:Connect(function(trackNum, cmd, val)
    if cmd == "SetDir" then
        if trainDirs[trackNum] ~= nil then trainDirs[trackNum] = val end
    elseif cmd == "SetCtrl" then
        if trainCtrls[trackNum] ~= nil then
            if not (trainDoorOpen[trackNum] and val == "加速") then
                trainCtrls[trackNum] = val
            end
        end
    elseif cmd == "SetDoor" then
        if trainModels[trackNum] then setDoorState(trackNum, val) end
    elseif cmd == "Build" then
        buildTrain(trackNum)
    elseif cmd == "Store" then
        storeTrain(trackNum)
    end
end)

autoQueryFn.OnInvoke = function(trackNum, query)
    if query == "Speed"    then return trainSpeeds[trackNum]   or 0    end
    if query == "DoorOpen" then return trainDoorOpen[trackNum] or false end
    if query == "HasTrain" then return trainModels[trackNum]   ~= nil  end
    return nil
end

-- ============================================================
-- TrainStateChanged BindableEvent（スポーン/格納通知）
-- ============================================================
local trainStateChanged = Instance.new("BindableEvent")
trainStateChanged.Name   = "TrainStateChanged"
trainStateChanged.Parent = ReplicatedStorage

fireTrainStateChanged = function(trackNum, hasTrain)
    trainStateChanged:Fire(trackNum, hasTrain)
end
