-- 運転席GUI（DriverSeat着席時に表示）
-- 列車管理はワールド内のClickDetectorパネルで行うため、管理UIは不要

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 列車制御 RemoteEvents
local remotes    = ReplicatedStorage:WaitForChild("TrainRemotes")
local evtSetDir  = remotes:WaitForChild("SetDirection")
local evtSetCtrl = remotes:WaitForChild("SetControl")
local evtSpeedUpd = remotes:WaitForChild("SpeedUpdate")

-- ============================================================
-- 運転席 GUI
-- ============================================================
local cabGui = Instance.new("ScreenGui")
cabGui.Name           = "DriverCabGui"
cabGui.Enabled        = false
cabGui.ResetOnSpawn   = false
cabGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
cabGui.Parent         = playerGui

-- 背景（半透明暗幕）
local overlay = Instance.new("Frame")
overlay.Size                   = UDim2.fromScale(1, 1)
overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.42
overlay.BorderSizePixel        = 0
overlay.Parent                 = cabGui

-- ヘッダー：行先表示（JR西日本ブルー）
local header = Instance.new("Frame")
header.Size             = UDim2.new(1, 0, 0, 52)
header.BackgroundColor3 = Color3.fromRGB(0, 78, 162)
header.BorderSizePixel  = 0
header.Parent           = overlay

local headerTxt = Instance.new("TextLabel")
headerTxt.Size                   = UDim2.fromScale(1, 1)
headerTxt.BackgroundTransparency = 1
headerTxt.Text                   = "JR神戸線　新快速　姫路 行"
headerTxt.TextColor3             = Color3.fromRGB(255, 255, 255)
headerTxt.TextSize               = 24
headerTxt.Font                   = Enum.Font.GothamBold
headerTxt.Parent                 = header

-- 閉じるボタン
local closeBtn = Instance.new("TextButton")
closeBtn.Size             = UDim2.fromOffset(72, 30)
closeBtn.Position         = UDim2.new(1, -80, 0, 11)
closeBtn.BackgroundColor3 = Color3.fromRGB(130, 18, 18)
closeBtn.BorderSizePixel  = 0
closeBtn.Text             = "閉じる"
closeBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize         = 13
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.Parent           = overlay
local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 5)
closeBtnCorner.Parent       = closeBtn
closeBtn.MouseButton1Click:Connect(function()
    cabGui.Enabled = false
end)

-- 計器パネル（画面下部）
local dash = Instance.new("Frame")
dash.Size                   = UDim2.new(1, 0, 0, 200)
dash.Position               = UDim2.new(0, 0, 1, -200)
dash.BackgroundColor3       = Color3.fromRGB(10, 10, 16)
dash.BackgroundTransparency = 0.06
dash.BorderSizePixel        = 0
dash.Parent                 = overlay

-- 速度計（中央）
local speedBox = Instance.new("Frame")
speedBox.Size             = UDim2.fromOffset(185, 158)
speedBox.Position         = UDim2.new(0.5, -92, 0.5, -72)
speedBox.BackgroundColor3 = Color3.fromRGB(6, 6, 12)
speedBox.BorderSizePixel  = 0
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

-- ATC制限速度（赤）
local atcLabel = Instance.new("TextLabel")
atcLabel.Size                   = UDim2.fromOffset(50, 28)
atcLabel.Position               = UDim2.new(1, -6, 0, 6)
atcLabel.BackgroundColor3       = Color3.fromRGB(160, 10, 10)
atcLabel.BackgroundTransparency = 0
atcLabel.BorderSizePixel        = 0
atcLabel.Text                   = "70"
atcLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
atcLabel.TextSize               = 16
atcLabel.Font                   = Enum.Font.GothamBold
atcLabel.Parent                 = speedBox
local atcCorner = Instance.new("UICorner"); atcCorner.CornerRadius = UDim.new(0, 4); atcCorner.Parent = atcLabel

-- 計器ボックス生成ヘルパー
local function makeGauge(labelTxt, valueTxt, posXScale)
    local f = Instance.new("Frame")
    f.Size             = UDim2.fromOffset(142, 118)
    f.Position         = UDim2.new(posXScale, 0, 0.5, -54)
    f.BackgroundColor3 = Color3.fromRGB(6, 6, 12)
    f.BorderSizePixel  = 0
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
end

local brakeValLbl  = makeGauge("ブレーキ", "解除", 0.22)
local masconValLbl = makeGauge("マスコン", "OFF",  0.62)

-- ============================================================
-- 方向ボタン（前 / 中 / 後）— dash 左端
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
        evtSetDir:FireServer(lbl)
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
-- 制御ボタン（加速 / 加速停止 / ブレーキ / 急ブレーキ）— dash 右端
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
    btn.MouseButton1Click:Connect(function()
        evtSetCtrl:FireServer(def.label)
        masconValLbl.Text = def.label == "加速" and "加速" or "OFF"
        if def.label == "ブレーキ" then
            brakeValLbl.Text = "常用制動"
        elseif def.label == "急ブレーキ" then
            brakeValLbl.Text = "非常制動"
        else
            brakeValLbl.Text = "解除"
        end
    end)
end

-- 速度をサーバーから受信して表示
evtSpeedUpd.OnClientEvent:Connect(function(speed)
    speedNum.Text = tostring(speed)
end)

-- ============================================================
-- DriverSeat 着席検出
-- ============================================================
local function onCharacterAdded(character)
    local humanoid = character:WaitForChild("Humanoid")
    humanoid.Seated:Connect(function(isSeated, seatPart)
        if isSeated and seatPart and seatPart.Name == "DriverSeat" then
            cabGui.Enabled = true
        elseif not isSeated then
            cabGui.Enabled = false
        end
    end)
end

if player.Character then
    onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)
