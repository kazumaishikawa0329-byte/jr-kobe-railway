-- 列車管理パネル（呼び出し/格納）と運転席GUI

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- RemoteEvents（サーバーが生成するまで待機）
local remotes   = ReplicatedStorage:WaitForChild("TrainRemotes")
local evRespawn = remotes:WaitForChild("RespawnTrain")
local evStore   = remotes:WaitForChild("StoreTrain")

-- ============================================================
-- 管理パネル（常時右下に表示）
-- ============================================================
local mgGui = Instance.new("ScreenGui")
mgGui.Name           = "TrainMgrGui"
mgGui.ResetOnSpawn   = false
mgGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
mgGui.Parent         = playerGui

local panel = Instance.new("Frame")
panel.Size                  = UDim2.fromOffset(236, 62)
panel.Position              = UDim2.new(1, -246, 1, -72)
panel.BackgroundColor3      = Color3.fromRGB(12, 12, 22)
panel.BackgroundTransparency = 0.2
panel.BorderSizePixel       = 0
panel.Parent                = mgGui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 8)
panelCorner.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection         = Enum.FillDirection.Horizontal
listLayout.VerticalAlignment     = Enum.VerticalAlignment.Center
listLayout.HorizontalAlignment   = Enum.HorizontalAlignment.Center
listLayout.Padding               = UDim.new(0, 8)
listLayout.Parent                = panel

local padding = Instance.new("UIPadding")
padding.PaddingLeft  = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.Parent       = panel

local function makeBtn(text, bg, cb)
    local b = Instance.new("TextButton")
    b.Size             = UDim2.fromOffset(104, 44)
    b.BackgroundColor3 = bg
    b.BorderSizePixel  = 0
    b.Text             = text
    b.TextColor3       = Color3.fromRGB(255, 255, 255)
    b.TextSize         = 12
    b.Font             = Enum.Font.GothamBold
    b.Parent           = panel
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 5)
    c.Parent       = b
    b.MouseButton1Click:Connect(cb)
    return b
end

makeBtn("列車を呼び出す", Color3.fromRGB(0, 100, 180), function() evRespawn:FireServer() end)
makeBtn("列車を格納する", Color3.fromRGB(65, 65, 75),  function() evStore:FireServer()   end)

-- ============================================================
-- 運転席 GUI（DriverSeat 着席時のみ表示）
-- ============================================================
local cabGui = Instance.new("ScreenGui")
cabGui.Name           = "DriverCabGui"
cabGui.Enabled        = false
cabGui.ResetOnSpawn   = false
cabGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
cabGui.Parent         = playerGui

-- 半透明の暗幕（背景）
local overlay = Instance.new("Frame")
overlay.Size                  = UDim2.fromScale(1, 1)
overlay.BackgroundColor3      = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.42
overlay.BorderSizePixel       = 0
overlay.Parent                = cabGui

-- ヘッダーバー（行先表示）
local header = Instance.new("Frame")
header.Size            = UDim2.new(1, 0, 0, 52)
header.BackgroundColor3 = Color3.fromRGB(0, 78, 162)
header.BorderSizePixel = 0
header.Parent          = overlay

local headerTxt = Instance.new("TextLabel")
headerTxt.Size                = UDim2.fromScale(1, 1)
headerTxt.BackgroundTransparency = 1
headerTxt.Text                = "JR神戸線　快速　神戸 行"
headerTxt.TextColor3          = Color3.fromRGB(255, 255, 255)
headerTxt.TextSize            = 24
headerTxt.Font                = Enum.Font.GothamBold
headerTxt.Parent              = header

-- 閉じるボタン
local closeBtn = Instance.new("TextButton")
closeBtn.Size            = UDim2.fromOffset(72, 30)
closeBtn.Position        = UDim2.new(1, -80, 0, 11)
closeBtn.BackgroundColor3 = Color3.fromRGB(140, 20, 20)
closeBtn.BorderSizePixel = 0
closeBtn.Text            = "閉じる"
closeBtn.TextColor3      = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize        = 13
closeBtn.Font            = Enum.Font.GothamBold
closeBtn.Parent          = overlay
local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 5)
closeBtnCorner.Parent = closeBtn
closeBtn.MouseButton1Click:Connect(function()
    cabGui.Enabled = false
end)

-- 計器パネル（下部）
local dash = Instance.new("Frame")
dash.Size                  = UDim2.new(1, 0, 0, 190)
dash.Position              = UDim2.new(0, 0, 1, -190)
dash.BackgroundColor3      = Color3.fromRGB(12, 12, 18)
dash.BackgroundTransparency = 0.08
dash.BorderSizePixel       = 0
dash.Parent                = overlay

-- 速度計（中央）
local speedBox = Instance.new("Frame")
speedBox.Size            = UDim2.fromOffset(180, 150)
speedBox.Position        = UDim2.new(0.5, -90, 0.5, -68)
speedBox.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
speedBox.BorderSizePixel = 0
speedBox.Parent          = dash
local speedCorner = Instance.new("UICorner")
speedCorner.CornerRadius = UDim.new(0, 12)
speedCorner.Parent = speedBox

local speedNum = Instance.new("TextLabel")
speedNum.Size                = UDim2.new(1, 0, 0.6, 0)
speedNum.Position            = UDim2.new(0, 0, 0.04, 0)
speedNum.BackgroundTransparency = 1
speedNum.Text                = "0"
speedNum.TextColor3          = Color3.fromRGB(0, 230, 120)
speedNum.TextSize            = 82
speedNum.Font                = Enum.Font.GothamBold
speedNum.Parent              = speedBox

local speedUnit = Instance.new("TextLabel")
speedUnit.Size                = UDim2.new(1, 0, 0.22, 0)
speedUnit.Position            = UDim2.new(0, 0, 0.72, 0)
speedUnit.BackgroundTransparency = 1
speedUnit.Text                = "km/h"
speedUnit.TextColor3          = Color3.fromRGB(130, 130, 130)
speedUnit.TextSize            = 18
speedUnit.Font                = Enum.Font.Gotham
speedUnit.Parent              = speedBox

-- 計器ボックスを生成するヘルパー
local function makeGauge(labelTxt, valueTxt, posXScale)
    local f = Instance.new("Frame")
    f.Size            = UDim2.fromOffset(138, 110)
    f.Position        = UDim2.new(posXScale, 0, 0.5, -50)
    f.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
    f.BorderSizePixel = 0
    f.Parent          = dash
    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(0, 8)
    fc.Parent = f

    local lbl = Instance.new("TextLabel")
    lbl.Size                = UDim2.new(1, 0, 0.32, 0)
    lbl.Position            = UDim2.new(0, 0, 0.06, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                = labelTxt
    lbl.TextColor3          = Color3.fromRGB(140, 140, 140)
    lbl.TextSize            = 14
    lbl.Font                = Enum.Font.Gotham
    lbl.Parent              = f

    local val = Instance.new("TextLabel")
    val.Size                = UDim2.new(1, 0, 0.42, 0)
    val.Position            = UDim2.new(0, 0, 0.5, 0)
    val.BackgroundTransparency = 1
    val.Text                = valueTxt
    val.TextColor3          = Color3.fromRGB(220, 200, 70)
    val.TextSize            = 20
    val.Font                = Enum.Font.GothamBold
    val.Parent              = f
end

makeGauge("ブレーキ", "非常制動", 0.12)
makeGauge("マスコン",  "OFF",     0.72)

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
