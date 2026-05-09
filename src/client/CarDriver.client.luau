-- 自動車手動運転クライアント（WASD 操作・Space で降車）

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local gui    = player:WaitForChild("PlayerGui")

local carRem     = ReplicatedStorage:WaitForChild("CarRemotes", 20)
if not carRem then return end
local evtDrive   = carRem:WaitForChild("CarDrive",    10)
local evtDismount = carRem:WaitForChild("CarDismount", 10)
if not evtDrive or not evtDismount then return end

local driving  = false
local throttle = 0
local steer    = 0
local hudGui   = nil

-- ============================================================
-- HUD
-- ============================================================
local function showHUD()
    if hudGui then hudGui:Destroy() end
    hudGui = Instance.new("ScreenGui")
    hudGui.Name         = "CarDriverHUD"
    hudGui.ResetOnSpawn = false
    hudGui.Parent       = gui

    local f = Instance.new("Frame")
    f.Size                   = UDim2.fromOffset(380, 48)
    f.Position               = UDim2.new(0.5, -190, 1, -68)
    f.BackgroundColor3       = Color3.fromRGB(10, 15, 35)
    f.BackgroundTransparency = 0.28
    f.BorderSizePixel        = 0
    f.Parent                 = hudGui
    local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0, 8); cr.Parent = f

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = "運転中  　W / S  前後  　A / D  左右  　Space  降車"
    lbl.TextColor3             = Color3.fromRGB(100, 220, 255)
    lbl.TextSize               = 15
    lbl.Font                   = Enum.Font.GothamBold
    lbl.Parent                 = f
end

local function hideHUD()
    if hudGui then hudGui:Destroy(); hudGui = nil end
end

-- ============================================================
-- 運転開始 / 終了
-- ============================================================
local function startDriving()
    if driving then return end
    driving = true
    showHUD()
end

local function stopDriving()
    if not driving then return end
    driving  = false
    throttle = 0
    steer    = 0
    hideHUD()
end

local function sendInput()
    if not driving then return end
    evtDrive:FireServer(throttle, steer)
end

-- ============================================================
-- Seat 検出（Humanoid.SeatPart が PlayerCar の Seat になったら運転開始）
-- ============================================================
local function setupCharacter(char)
    local hum = char:WaitForChild("Humanoid")

    hum:GetPropertyChangedSignal("SeatPart"):Connect(function()
        local sp = hum.SeatPart
        if sp and sp.Parent and sp.Parent.Name == "PlayerCar" then
            startDriving()
        else
            if driving then
                stopDriving()
            end
        end
    end)
end

player.CharacterAdded:Connect(setupCharacter)
if player.Character then setupCharacter(player.Character) end

-- ============================================================
-- 入力処理
-- ============================================================
UserInputService.InputBegan:Connect(function(inp, handled)
    if not driving or handled then return end

    local changed = false

    if inp.KeyCode == Enum.KeyCode.W or inp.KeyCode == Enum.KeyCode.Up then
        throttle = 1; changed = true
    elseif inp.KeyCode == Enum.KeyCode.S or inp.KeyCode == Enum.KeyCode.Down then
        throttle = -1; changed = true
    elseif inp.KeyCode == Enum.KeyCode.A or inp.KeyCode == Enum.KeyCode.Left then
        steer = -1; changed = true
    elseif inp.KeyCode == Enum.KeyCode.D or inp.KeyCode == Enum.KeyCode.Right then
        steer = 1; changed = true
    elseif inp.KeyCode == Enum.KeyCode.Space then
        evtDismount:FireServer()
        stopDriving()
        return
    end

    if changed then sendInput() end
end)

UserInputService.InputEnded:Connect(function(inp)
    if not driving then return end

    local changed = false

    if inp.KeyCode == Enum.KeyCode.W or inp.KeyCode == Enum.KeyCode.Up
    or inp.KeyCode == Enum.KeyCode.S or inp.KeyCode == Enum.KeyCode.Down then
        throttle = 0; changed = true
    elseif inp.KeyCode == Enum.KeyCode.A or inp.KeyCode == Enum.KeyCode.Left
    or inp.KeyCode == Enum.KeyCode.D or inp.KeyCode == Enum.KeyCode.Right then
        steer = 0; changed = true
    end

    if changed then sendInput() end
end)
