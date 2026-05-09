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
-- HUD（タッチD-pad + キーボードヒント）
-- ============================================================
local function showHUD()
    if hudGui then hudGui:Destroy() end
    hudGui = Instance.new("ScreenGui")
    hudGui.Name         = "CarDriverHUD"
    hudGui.ResetOnSpawn = false
    hudGui.Parent       = gui

    local BTN = 82   -- タッチボタン 1辺
    local GAP = 6

    -- ── タッチD-pad（左下）──────────────────────────────────────
    --  配置:  [◀][↑][▶]
    --             [↓]
    local dpad = Instance.new("Frame")
    dpad.Name                   = "DPad"
    dpad.Size                   = UDim2.fromOffset(BTN * 3 + GAP * 2, BTN * 2 + GAP)
    dpad.Position               = UDim2.new(0, 18, 1, -(BTN * 2 + GAP + 22))
    dpad.BackgroundTransparency = 1
    dpad.Parent                 = hudGui

    local function mkDBtn(lbl, col, row)
        local b = Instance.new("TextButton")
        b.Size             = UDim2.fromOffset(BTN, BTN)
        b.Position         = UDim2.fromOffset((BTN + GAP) * col, (BTN + GAP) * row)
        b.BackgroundColor3 = Color3.fromRGB(18, 28, 62)
        b.BackgroundTransparency = 0.30
        b.BorderSizePixel  = 0
        b.Text             = lbl
        b.TextColor3       = Color3.fromRGB(175, 215, 255)
        b.TextSize         = 36
        b.Font             = Enum.Font.GothamBold
        b.AutoButtonColor  = false
        b.ZIndex           = 10
        b.Parent           = dpad
        local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0, 14); cr.Parent = b
        return b
    end

    local upBtn    = mkDBtn("↑", 1, 0)
    local leftBtn  = mkDBtn("◀", 0, 0)
    local rightBtn = mkDBtn("▶", 2, 0)
    local downBtn  = mkDBtn("↓", 1, 1)

    -- ── 降車ボタン（右下）────────────────────────────────────────
    local exitTouchBtn = Instance.new("TextButton")
    exitTouchBtn.Size             = UDim2.fromOffset(112, BTN)
    exitTouchBtn.Position         = UDim2.new(1, -(112 + 18), 1, -(BTN + 22))
    exitTouchBtn.BackgroundColor3 = Color3.fromRGB(115, 16, 16)
    exitTouchBtn.BackgroundTransparency = 0.25
    exitTouchBtn.BorderSizePixel  = 0
    exitTouchBtn.Text             = "降車"
    exitTouchBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    exitTouchBtn.TextSize         = 24
    exitTouchBtn.Font             = Enum.Font.GothamBold
    exitTouchBtn.AutoButtonColor  = false
    exitTouchBtn.ZIndex           = 10
    exitTouchBtn.Parent           = hudGui
    local ec = Instance.new("UICorner"); ec.CornerRadius = UDim.new(0, 14); ec.Parent = exitTouchBtn

    -- ── キーボードヒント（中央下・PC向け）────────────────────────
    local hint = Instance.new("Frame")
    hint.Size                   = UDim2.fromOffset(330, 38)
    hint.Position               = UDim2.new(0.5, -165, 1, -50)
    hint.BackgroundColor3       = Color3.fromRGB(10, 15, 35)
    hint.BackgroundTransparency = 0.30
    hint.BorderSizePixel        = 0
    hint.Parent                 = hudGui
    local hc = Instance.new("UICorner"); hc.CornerRadius = UDim.new(0, 8); hc.Parent = hint
    local hLbl = Instance.new("TextLabel")
    hLbl.Size                   = UDim2.fromScale(1, 1)
    hLbl.BackgroundTransparency = 1
    hLbl.Text                   = "W/S 前後  A/D 左右  Space 降車"
    hLbl.TextColor3             = Color3.fromRGB(100, 200, 240)
    hLbl.TextSize               = 14
    hLbl.Font                   = Enum.Font.Gotham
    hLbl.Parent                 = hint

    -- ── タッチボタン入力処理 ──────────────────────────────────────
    local function wireDirBtn(btn, thV, stV)
        local function onDown()
            if not driving then return end
            if thV ~= 0 then throttle = thV end
            if stV ~= 0 then steer    = stV end
            sendInput()
            btn.BackgroundTransparency = 0.05
        end
        local function onUp()
            if not driving then return end
            if thV ~= 0 then throttle = 0 end
            if stV ~= 0 then steer    = 0 end
            sendInput()
            btn.BackgroundTransparency = 0.30
        end
        btn.MouseButton1Down:Connect(onDown)
        btn.MouseButton1Up:Connect(onUp)
        btn.MouseLeave:Connect(onUp)
    end

    wireDirBtn(upBtn,     1,  0)
    wireDirBtn(downBtn,  -1,  0)
    wireDirBtn(leftBtn,   0, -1)
    wireDirBtn(rightBtn,  0,  1)

    exitTouchBtn.Activated:Connect(function()
        if not driving then return end
        evtDismount:FireServer()
        stopDriving()
    end)
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
