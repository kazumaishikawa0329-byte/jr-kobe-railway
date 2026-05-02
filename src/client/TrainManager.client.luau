-- 運転席GUI（DriverSeat着席時に表示）
-- 列車管理はワールド内のClickDetectorパネルで行うため、管理UIは不要

local Players = game:GetService("Players")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

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

makeGauge("ブレーキ", "非常制動", 0.11)
makeGauge("マスコン",  "OFF",     0.73)

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
