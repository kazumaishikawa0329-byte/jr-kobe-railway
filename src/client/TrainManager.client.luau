-- 運転席GUI / 車内モード / 音響管理

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local SoundService      = game:GetService("SoundService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local camera           = workspace.CurrentCamera
local currentSeatPart  = nil
local currentTrackNum  = nil
local doorIsOpen       = false   -- 乗車中列車のドア状態
local isInInterior     = false   -- 車内モードフラグ
local doorOpenStates   = {}      -- [trackNum] = bool（全列車のドア状態）

-- 車体サイズ定数（車内判定用）
local CAR_HALF_W = 4.2
local CAR_HALF_Z = 12.5
local CAR_FLOOR  = 1.5
local CAR_TOP    = 8.5

local function getTrackNum(seatPart)
    local car   = seatPart.Parent
    local train = car and car.Parent
    if train then
        local n = tonumber(string.match(train.Name, "Train_(%d+)"))
        if n then return n end
    end
    return 1
end

local function setMobileControls(enabled)
    local touchGui = playerGui:FindFirstChild("TouchGui")
    if touchGui then touchGui.Enabled = enabled end
end

local hiddenParts = {}

local function hideDrivingCar(seatPart)
    local car = seatPart.Parent
    for _, part in ipairs(car:GetDescendants()) do
        if part:IsA("BasePart") then
            hiddenParts[part] = true
            part.LocalTransparencyModifier = 1
        end
    end
end

local function restoreDrivingCar()
    for part in pairs(hiddenParts) do
        if part and part.Parent then
            part.LocalTransparencyModifier = 0
        end
    end
    hiddenParts = {}
end

-- カメラ制御
local camYaw     = 0
local camPitch   = math.rad(-7)
local isDragging   = false
local lastInputPos = nil
local CAM_SENS     = 0.004

RunService.RenderStepped:Connect(function()
    if currentSeatPart == nil then return end
    local seatCF = currentSeatPart.CFrame
    local eyePos = seatCF.Position + Vector3.new(0, 1.5, 0)
    local lookCF = seatCF.Rotation
        * CFrame.Angles(0, camYaw, 0)
        * CFrame.Angles(camPitch, 0, 0)
    camera.CFrame = CFrame.new(eyePos, eyePos + lookCF.LookVector)
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed or not currentSeatPart then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        isDragging   = true
        lastInputPos = input.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not isDragging or not currentSeatPart then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        if lastInputPos then
            local delta = input.Position - lastInputPos
            camYaw   = camYaw - delta.X * CAM_SENS
            camPitch = math.clamp(
                camPitch - delta.Y * CAM_SENS,
                math.rad(-85), math.rad(85))
        end
        lastInputPos = input.Position
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        isDragging   = false
        lastInputPos = nil
    end
end)

-- RemoteEvents
local remotes     = ReplicatedStorage:WaitForChild("TrainRemotes")
local evtSetDir   = remotes:WaitForChild("SetDirection")
local evtSetCtrl  = remotes:WaitForChild("SetControl")
local evtSpeedUpd = remotes:WaitForChild("SpeedUpdate")
local evtDoorCtrl = remotes:WaitForChild("DoorControl")
local evtDoorState= remotes:WaitForChild("DoorState")

-- ============================================================
-- 効果音
-- 注意: SoundId は Roblox ツールボックスの音声アセットIDに置き換えてください
-- ============================================================
local function makeSound(id, volume, looped)
    local s = Instance.new("Sound")
    s.SoundId  = id ~= "" and ("rbxassetid://" .. id) or ""
    s.Volume   = volume
    s.Looped   = looped or false
    s.Parent   = SoundService
    return s
end

local sndDoorOpen  = makeSound("88183508778438",   0.8, false)  -- ドア開放音
local sndDoorClose = makeSound("89298627645193",   0.8, false)  -- ドア閉鎖音
local sndMotor     = makeSound("140634290299044",   0.7, true)   -- 電動機音
local sndBrake     = makeSound("110384127808149",   0.6, false)  -- ブレーキ音
sndBrake.PlaybackSpeed = 5

local prevSpeed = 0
local motorRunning = false

-- ============================================================
-- 運転席 GUI
-- ============================================================
local cabGui = Instance.new("ScreenGui")
cabGui.Name           = "DriverCabGui"
cabGui.Enabled        = false
cabGui.ResetOnSpawn   = false
cabGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
cabGui.Parent         = playerGui

local dash = Instance.new("Frame")
dash.Size                   = UDim2.new(1, 0, 0, 200)
dash.Position               = UDim2.new(0, 0, 1, -200)
dash.BackgroundColor3       = Color3.fromRGB(10, 10, 16)
dash.BackgroundTransparency = 0.90
dash.BorderSizePixel        = 0
dash.Parent                 = cabGui

-- 速度計（中央）
local speedBox = Instance.new("Frame")
speedBox.Size             = UDim2.fromOffset(185, 158)
speedBox.Position         = UDim2.new(0.5, -92, 0.5, -72)
speedBox.BackgroundColor3       = Color3.fromRGB(6, 6, 12)
speedBox.BackgroundTransparency = 0.75
speedBox.BorderSizePixel        = 0
speedBox.Parent           = dash
local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 12); sc.Parent = speedBox

local speedNum = Instance.new("TextLabel")
speedNum.Size                   = UDim2.new(1, 0, 0.6, 0)
speedNum.Position               = UDim2.new(0, 0, 0.04, 0)
speedNum.BackgroundTransparency = 1
speedNum.Text                   = "0"
speedNum.TextColor3             = Color3.fromRGB(0, 228, 115)
speedNum.TextSize               = 84
speedNum.Font                   = Enum.Font.GothamBold
speedNum.Parent                 = speedBox

local speedUnit = Instance.new("TextLabel")
speedUnit.Size                   = UDim2.new(1, 0, 0.22, 0)
speedUnit.Position               = UDim2.new(0, 0, 0.72, 0)
speedUnit.BackgroundTransparency = 1
speedUnit.Text                   = "km/h"
speedUnit.TextColor3             = Color3.fromRGB(120, 120, 120)
speedUnit.TextSize               = 18
speedUnit.Font                   = Enum.Font.Gotham
speedUnit.Parent                 = speedBox

local atcLabel = Instance.new("TextLabel")
atcLabel.Size                   = UDim2.fromOffset(50, 28)
atcLabel.Position               = UDim2.new(1, -6, 0, 6)
atcLabel.BackgroundColor3       = Color3.fromRGB(160, 10, 10)
atcLabel.BackgroundTransparency = 0.45
atcLabel.BorderSizePixel        = 0
atcLabel.Text                   = "70"
atcLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
atcLabel.TextSize               = 16
atcLabel.Font                   = Enum.Font.GothamBold
atcLabel.Parent                 = speedBox
local atcCorner = Instance.new("UICorner"); atcCorner.CornerRadius = UDim.new(0, 4); atcCorner.Parent = atcLabel

local function makeGauge(labelTxt, valueTxt, posXScale)
    local f = Instance.new("Frame")
    f.Size             = UDim2.fromOffset(142, 118)
    f.Position         = UDim2.new(posXScale, 0, 0.5, -54)
    f.BackgroundColor3       = Color3.fromRGB(6, 6, 12)
    f.BackgroundTransparency = 0.78
    f.BorderSizePixel        = 0
    f.Parent           = dash
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 8); fc.Parent = f

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, 0, 0.3, 0)
    lbl.Position               = UDim2.new(0, 0, 0.07, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = labelTxt
    lbl.TextColor3             = Color3.fromRGB(130, 130, 130)
    lbl.TextSize               = 14
    lbl.Font                   = Enum.Font.Gotham
    lbl.Parent                 = f

    local val = Instance.new("TextLabel")
    val.Size                   = UDim2.new(1, 0, 0.4, 0)
    val.Position               = UDim2.new(0, 0, 0.5, 0)
    val.BackgroundTransparency = 1
    val.Text                   = valueTxt
    val.TextColor3             = Color3.fromRGB(218, 196, 65)
    val.TextSize               = 20
    val.Font                   = Enum.Font.GothamBold
    val.Parent                 = f
    return val
end

local brakeValLbl  = makeGauge("ブレーキ", "解除", 0.22)
local masconValLbl = makeGauge("マスコン", "OFF",  0.62)

-- ============================================================
-- 方向ボタン（前 / 中 / 後）
-- ============================================================
local dirPanel = Instance.new("Frame")
dirPanel.Size                   = UDim2.new(0, 84, 1, -12)
dirPanel.Position               = UDim2.new(0, 6, 0, 6)
dirPanel.BackgroundTransparency = 1
dirPanel.Parent                 = dash

local dirBtnRefs = {}
for i, lbl in ipairs({"前", "中", "後"}) do
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(1, 0, 0, 52)
    btn.Position         = UDim2.new(0, 0, 0, (i - 1) * 56)
    btn.BackgroundColor3 = Color3.fromRGB(35, 42, 58)
    btn.BorderSizePixel  = 0
    btn.Text             = lbl
    btn.TextColor3       = Color3.fromRGB(180, 180, 180)
    btn.TextSize         = 22
    btn.Font             = Enum.Font.GothamBold
    btn.Parent           = dirPanel
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = btn
    dirBtnRefs[lbl] = btn
    btn.MouseButton1Click:Connect(function()
        evtSetDir:FireServer(currentTrackNum, lbl)
        for _, b in pairs(dirBtnRefs) do
            b.BackgroundColor3 = Color3.fromRGB(35, 42, 58)
            b.TextColor3       = Color3.fromRGB(180, 180, 180)
        end
        btn.BackgroundColor3 = lbl == "中"
            and Color3.fromRGB(110, 88, 0)
            or  Color3.fromRGB(0,   110, 50)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)
end

-- ============================================================
-- ドアボタン（ドア開 / ドア閉）— 方向パネルの右隣
-- ============================================================
local doorPanel = Instance.new("Frame")
doorPanel.Size                   = UDim2.new(0, 88, 1, -12)
doorPanel.Position               = UDim2.new(0, 94, 0, 6)
doorPanel.BackgroundTransparency = 1
doorPanel.Parent                 = dash

local doorBtnOpen = Instance.new("TextButton")
doorBtnOpen.Size             = UDim2.new(1, 0, 0, 52)
doorBtnOpen.Position         = UDim2.new(0, 0, 0, 0)
doorBtnOpen.BackgroundColor3 = Color3.fromRGB(0, 100, 160)
doorBtnOpen.BorderSizePixel  = 0
doorBtnOpen.Text             = "ドア開"
doorBtnOpen.TextColor3       = Color3.fromRGB(255, 255, 255)
doorBtnOpen.TextSize         = 20
doorBtnOpen.Font             = Enum.Font.GothamBold
doorBtnOpen.Parent           = doorPanel
local dbc1 = Instance.new("UICorner"); dbc1.CornerRadius = UDim.new(0, 8); dbc1.Parent = doorBtnOpen

local doorBtnClose = Instance.new("TextButton")
doorBtnClose.Size             = UDim2.new(1, 0, 0, 52)
doorBtnClose.Position         = UDim2.new(0, 0, 0, 56)
doorBtnClose.BackgroundColor3 = Color3.fromRGB(140, 40, 0)
doorBtnClose.BorderSizePixel  = 0
doorBtnClose.Text             = "ドア閉"
doorBtnClose.TextColor3       = Color3.fromRGB(255, 255, 255)
doorBtnClose.TextSize         = 20
doorBtnClose.Font             = Enum.Font.GothamBold
doorBtnClose.Parent           = doorPanel
local dbc2 = Instance.new("UICorner"); dbc2.CornerRadius = UDim.new(0, 8); dbc2.Parent = doorBtnClose

doorBtnOpen.MouseButton1Click:Connect(function()
    if currentTrackNum then
        evtDoorCtrl:FireServer(currentTrackNum, true)
        doorBtnOpen.BackgroundColor3  = Color3.fromRGB(0, 160, 220)
        doorBtnClose.BackgroundColor3 = Color3.fromRGB(140, 40, 0)
    end
end)

doorBtnClose.MouseButton1Click:Connect(function()
    if currentTrackNum then
        evtDoorCtrl:FireServer(currentTrackNum, false)
        doorBtnOpen.BackgroundColor3  = Color3.fromRGB(0, 100, 160)
        doorBtnClose.BackgroundColor3 = Color3.fromRGB(200, 60, 0)
    end
end)

-- ============================================================
-- 制御ボタン（加速 / 加速停止 / ブレーキ / 急ブレーキ）
-- ============================================================
local ctrlPanel = Instance.new("Frame")
ctrlPanel.Size                   = UDim2.new(0, 118, 1, -12)
ctrlPanel.Position               = UDim2.new(1, -124, 0, 6)
ctrlPanel.BackgroundTransparency = 1
ctrlPanel.Parent                 = dash

local ctrlDefs = {
    { label = "加速",      color = Color3.fromRGB(0,   140, 55)  },
    { label = "加速停止",  color = Color3.fromRGB(140, 118, 0)   },
    { label = "ブレーキ",  color = Color3.fromRGB(190, 70,  0)   },
    { label = "急ブレーキ",color = Color3.fromRGB(160, 15,  15)  },
}
local ctrlBtnRefs = {}
for i, def in ipairs(ctrlDefs) do
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(1, 0, 0, 42)
    btn.Position         = UDim2.new(0, 0, 0, (i - 1) * 46)
    btn.BackgroundColor3 = def.color
    btn.BorderSizePixel  = 0
    btn.Text             = def.label
    btn.TextColor3       = Color3.fromRGB(255, 255, 255)
    btn.TextSize         = 14
    btn.Font             = Enum.Font.GothamBold
    btn.Parent           = ctrlPanel
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    ctrlBtnRefs[def.label] = btn
    btn.MouseButton1Click:Connect(function()
        -- ドアが開いている間は加速不可
        if def.label == "加速" and doorIsOpen then return end
        evtSetCtrl:FireServer(currentTrackNum, def.label)
        masconValLbl.Text = def.label == "加速" and "加速" or "OFF"
        if def.label == "ブレーキ" then
            brakeValLbl.Text = "常用制動"
            sndBrake:Play()
        elseif def.label == "急ブレーキ" then
            brakeValLbl.Text = "非常制動"
            sndBrake:Play()
        else
            brakeValLbl.Text = "解除"
        end
    end)
end

-- 加速ボタンのドア連動表示更新
local function updateAccelBtn(isOpen)
    local btn = ctrlBtnRefs["加速"]
    if not btn then return end
    if isOpen then
        btn.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
        btn.Text             = "加速 [ドア開]"
    else
        btn.BackgroundColor3 = Color3.fromRGB(0, 140, 55)
        btn.Text             = "加速"
    end
end

-- 降車ボタン
local exitBtn = Instance.new("TextButton")
exitBtn.Size             = UDim2.fromOffset(96, 36)
exitBtn.Position         = UDim2.new(1, -106, 0, 10)
exitBtn.BackgroundColor3 = Color3.fromRGB(130, 18, 18)
exitBtn.BorderSizePixel  = 0
exitBtn.Text             = "降車する"
exitBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
exitBtn.TextSize         = 14
exitBtn.Font             = Enum.Font.GothamBold
exitBtn.Parent           = cabGui
local exitCorner = Instance.new("UICorner"); exitCorner.CornerRadius = UDim.new(0, 5); exitCorner.Parent = exitBtn
exitBtn.MouseButton1Click:Connect(function()
    if not doorIsOpen then return end  -- ドアが閉まっているときは降車不可
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.Sit = false end
end)

-- ============================================================
-- 車内モード GUI
-- ============================================================
local interiorGui = Instance.new("ScreenGui")
interiorGui.Name         = "InteriorGui"
interiorGui.Enabled      = false
interiorGui.ResetOnSpawn = false
interiorGui.Parent       = playerGui

local interiorLabel = Instance.new("TextLabel")
interiorLabel.Size                   = UDim2.fromOffset(130, 32)
interiorLabel.Position               = UDim2.new(0.5, -65, 0, 12)
interiorLabel.BackgroundColor3       = Color3.fromRGB(0, 40, 100)
interiorLabel.BackgroundTransparency = 0.45
interiorLabel.BorderSizePixel        = 0
interiorLabel.Text                   = "車内モード"
interiorLabel.TextColor3             = Color3.fromRGB(200, 230, 255)
interiorLabel.TextSize               = 16
interiorLabel.Font                   = Enum.Font.GothamBold
interiorLabel.Parent                 = interiorGui
local ilc = Instance.new("UICorner"); ilc.CornerRadius = UDim.new(0, 6); ilc.Parent = interiorLabel

-- 車内「降車」ボタン（ドアが開いているときに表示）
local interiorExitBtn = Instance.new("TextButton")
interiorExitBtn.Size             = UDim2.fromOffset(110, 36)
interiorExitBtn.Position         = UDim2.new(0.5, -55, 0, 52)
interiorExitBtn.BackgroundColor3       = Color3.fromRGB(120, 15, 15)
interiorExitBtn.BackgroundTransparency = 0.2
interiorExitBtn.BorderSizePixel  = 0
interiorExitBtn.Text             = "降車する"
interiorExitBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
interiorExitBtn.TextSize         = 14
interiorExitBtn.Font             = Enum.Font.GothamBold
interiorExitBtn.Visible          = false
interiorExitBtn.Parent           = interiorGui
local iec = Instance.new("UICorner"); iec.CornerRadius = UDim.new(0, 6); iec.Parent = interiorExitBtn

-- 降車: キャラクターをドア外側にテレポート
interiorExitBtn.MouseButton1Click:Connect(function()
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- 最も近い列車のドア位置に出す
    local rwFolder = workspace:FindFirstChild("RailwayTest")
    if not rwFolder then return end
    local bestPos = nil
    local bestDist = math.huge
    for t = 1, 4 do
        local trainModel = rwFolder:FindFirstChild("Train_" .. t)
        if not trainModel then continue end
        for _, carModel in ipairs(trainModel:GetChildren()) do
            if not carModel:IsA("Model") then continue end
            local body = carModel:FindFirstChild("Body")
            if not body then continue end
            local bp = body.Position
            local rp = root.Position
            local dist = (Vector3.new(bp.X, rp.Y, bp.Z) - rp).Magnitude
            if dist < bestDist then
                bestDist = dist
                -- 車体の右側（+X方向）に降車（CAR_FLOOR + 立ち上がり余裕）
                bestPos = Vector3.new(bp.X + CAR_HALF_W + 1.5, CAR_FLOOR + 2.5, bp.Z)
            end
        end
    end
    if bestPos then
        root.CFrame = CFrame.new(bestPos)
    end
end)

-- ============================================================
-- 車内モード 透明化管理
-- ============================================================
local interiorHiddenParts = {}

local function applyInteriorTransparency(char)
    local root = char:FindFirstChild("HumanoidRootPart")
    local rwFolder = workspace:FindFirstChild("RailwayTest")
    if not root or not rwFolder then return end

    for t = 1, 4 do
        local trainModel = rwFolder:FindFirstChild("Train_" .. t)
        if not trainModel then continue end
        for _, carModel in ipairs(trainModel:GetChildren()) do
            if not carModel:IsA("Model") then continue end
            local body = carModel:FindFirstChild("Body")
            if not body then continue end
            local bp = body.Position
            local rp = root.Position
            if math.abs(rp.X - bp.X) < CAR_HALF_W + 0.5
            and math.abs(rp.Z - bp.Z) < CAR_HALF_Z + 0.5 then
                for _, part in ipairs(carModel:GetDescendants()) do
                    if part:IsA("BasePart") then
                        local n = part.Name
                        -- 外壁パーツを半透明にして窓から外が見えるようにする
                        if string.find(n, "WinBand") or string.find(n, "WallTop")
                        or string.find(n, "^Wall[LR]") or string.find(n, "Body") then
                            interiorHiddenParts[part] = part.LocalTransparencyModifier
                            part.LocalTransparencyModifier = 0.72
                        end
                    end
                end
            end
        end
    end
end

local function restoreInteriorTransparency()
    for part, orig in pairs(interiorHiddenParts) do
        if part and part.Parent then
            part.LocalTransparencyModifier = orig
        end
    end
    interiorHiddenParts = {}
end

local function setInteriorMode(newState)
    if isInInterior == newState then return end
    isInInterior = newState
    interiorGui.Enabled = newState

    if newState then
        local char = player.Character
        if char then applyInteriorTransparency(char) end
    else
        restoreInteriorTransparency()
    end
end

-- ============================================================
-- ドア状態受信（音 + 状態同期）
-- ============================================================
evtDoorState.OnClientEvent:Connect(function(trackNum, isOpen)
    doorOpenStates[trackNum] = isOpen
    if trackNum == currentTrackNum then
        doorIsOpen = isOpen
        -- ドアボタンの色を同期
        if isOpen then
            doorBtnOpen.BackgroundColor3  = Color3.fromRGB(0, 160, 220)
            doorBtnClose.BackgroundColor3 = Color3.fromRGB(140, 40, 0)
        else
            doorBtnOpen.BackgroundColor3  = Color3.fromRGB(0, 100, 160)
            doorBtnClose.BackgroundColor3 = Color3.fromRGB(200, 60, 0)
        end
        updateAccelBtn(isOpen)
    end
    -- 降車ボタン可否
    if isInInterior then
        interiorExitBtn.Visible = isOpen
    end
    -- 開閉音を再生（最初の3秒をスキップ）
    if isOpen then
        sndDoorOpen.TimePosition = 2
        sndDoorOpen:Play()
    else
        sndDoorClose.TimePosition = 2
        sndDoorClose:Play()
    end
end)

-- ============================================================
-- 速度更新（速度計 + 電動機音）
-- ============================================================
evtSpeedUpd.OnClientEvent:Connect(function(trackNum, speed)
    if trackNum ~= currentTrackNum then return end
    speedNum.Text = tostring(speed)

    -- 電動機音（着席中のみ）
    if currentSeatPart then
        if speed > 0 then
            local t = speed / 130  -- 0〜1
            sndMotor.Volume       = 0.1 + t * 0.7
            sndMotor.PlaybackSpeed = 0.35 + t * 1.65
            if not sndMotor.IsPlaying then sndMotor:Play() end
        else
            if sndMotor.IsPlaying then sndMotor:Stop() end
        end
        -- 加速中: ピッチ上昇音（prevSpeed より大幅増加時）
        -- 減速中: ブレーキ音は急ブレーキボタンで再生済み
    end
    prevSpeed = speed
end)

-- ============================================================
-- 車内モード検出（非ドライバー向け）Heartbeat ポジションチェック
-- ============================================================
local INTERIOR_CHECK_INTERVAL = 0.25
local interiorCheckTimer = 0

RunService.Heartbeat:Connect(function(dt)
    -- ドライバーは除外（運転席GUIで視点管理）
    if currentSeatPart then
        if isInInterior then setInteriorMode(false) end
        return
    end

    interiorCheckTimer += dt
    if interiorCheckTimer < INTERIOR_CHECK_INTERVAL then return end
    interiorCheckTimer = 0

    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local rwFolder = workspace:FindFirstChild("RailwayTest")
    if not rwFolder then return end

    local foundInside = false
    local rp = root.Position
    for t = 1, 4 do
        local trainModel = rwFolder:FindFirstChild("Train_" .. t)
        if not trainModel then continue end
        for _, carModel in ipairs(trainModel:GetChildren()) do
            if not carModel:IsA("Model") then continue end
            local body = carModel:FindFirstChild("Body")
            if not body then continue end
            local bp = body.Position
            if math.abs(rp.X - bp.X) < CAR_HALF_W
            and math.abs(rp.Z - bp.Z) < CAR_HALF_Z
            and rp.Y > CAR_FLOOR and rp.Y < CAR_TOP then
                foundInside = true
                break
            end
        end
        if foundInside then break end
    end

    setInteriorMode(foundInside)

    -- 降車ボタン: 最寄り車両のドアが開いているときのみ表示
    if isInInterior then
        local anyDoorOpen = false
        for t, open in pairs(doorOpenStates) do
            if open then anyDoorOpen = true; break end
        end
        interiorExitBtn.Visible = anyDoorOpen
    end
end)

-- ============================================================
-- DriverSeat 着席検出
-- ============================================================
local function onCharacterAdded(character)
    local humanoid = character:WaitForChild("Humanoid")
    humanoid.Seated:Connect(function(isSeated, seatPart)
        if isSeated and seatPart and seatPart.Name == "DriverSeat" then
            currentSeatPart = seatPart
            currentTrackNum = getTrackNum(seatPart)
            doorIsOpen = doorOpenStates[currentTrackNum] or false
            -- ドアボタン初期色を同期
            if doorIsOpen then
                doorBtnOpen.BackgroundColor3  = Color3.fromRGB(0, 160, 220)
                doorBtnClose.BackgroundColor3 = Color3.fromRGB(140, 40, 0)
            else
                doorBtnOpen.BackgroundColor3  = Color3.fromRGB(0, 100, 160)
                doorBtnClose.BackgroundColor3 = Color3.fromRGB(200, 60, 0)
            end
            hideDrivingCar(seatPart)
            camera.CameraType = Enum.CameraType.Scriptable
            setMobileControls(false)
            cabGui.Enabled = true
        elseif not isSeated then
            -- 電動機音を止める
            if sndMotor.IsPlaying then sndMotor:Stop() end

            camYaw     = 0
            camPitch   = math.rad(-7)
            isDragging   = false
            lastInputPos = nil
            local prevSeat = currentSeatPart
            task.defer(function()
                local char = player.Character
                if char and prevSeat then
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if root then
                        local car = prevSeat.Parent
                        local mF = car and car:FindFirstChild("BoardMarkerF")
                        local mR = car and car:FindFirstChild("BoardMarkerR")
                        local marker = nil
                        if mF and mR then
                            local dF = (mF.Position - prevSeat.Position).Magnitude
                            local dR = (mR.Position - prevSeat.Position).Magnitude
                            marker = dF < dR and mF or mR
                        else
                            marker = mF or mR
                        end
                        if marker then
                            root.CFrame = CFrame.new(
                                marker.Position.X,
                                marker.Position.Y + 3,
                                marker.Position.Z)
                        else
                            root.CFrame = CFrame.new(
                                prevSeat.Position.X + 6,
                                prevSeat.Position.Y + 2,
                                prevSeat.Position.Z)
                        end
                    end
                end
            end)
            restoreDrivingCar()
            currentSeatPart = nil
            currentTrackNum = nil
            camera.CameraType = Enum.CameraType.Custom
            setMobileControls(true)
            cabGui.Enabled = false
        end
    end)
end

if player.Character then
    onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)
