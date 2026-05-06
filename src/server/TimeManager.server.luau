-- 現実の日本時間（JST）に連動した採光・夜間照明管理 + 手動時刻設定パネル

local Lighting  = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local RW_FOLDER = "RailwayTest"
local OFFSET    = Vector3.new(40, 0, 0)   -- RailwayTestBuilder と同一

-- ── JST 現在時刻（小数時間 0〜24）を返す ──────────────────────
local function getJSTHour()
    local jstSec = os.time() + 9 * 3600
    local h = math.floor(jstSec / 3600) % 24
    local m = math.floor(jstSec / 60)   % 60
    local s = jstSec % 60
    return h + m / 60 + s / 3600
end

-- ── 時間帯判定 ────────────────────────────────────────────────
local function getPeriod(h)
    if     h >= 5.5  and h <  6.5  then return "dawn"
    elseif h >= 6.5  and h < 10.0  then return "morning"
    elseif h >= 10.0 and h < 16.0  then return "noon"
    elseif h >= 16.0 and h < 19.0  then return "evening"
    else                                 return "night"
    end
end

-- ── 時間帯別ライティング設定 ─────────────────────────────────
-- ClockTime: 手動切替時に使う代表時刻（太陽位置を合わせるため）
local PERIOD_CFG = {
    dawn = {
        ClockTime=6.0,
        Brightness=0.8, Ambient=Color3.fromRGB(65,55,78),
        OutdoorAmbient=Color3.fromRGB(98,78,88),
        FogEnd=4000, FogStart=600, FogColor=Color3.fromRGB(188,140,128),
    },
    morning = {
        ClockTime=8.0,
        Brightness=2.2, Ambient=Color3.fromRGB(95,82,68),
        OutdoorAmbient=Color3.fromRGB(148,128,108),
        FogEnd=80000, FogStart=0, FogColor=Color3.fromRGB(200,195,190),
    },
    noon = {
        ClockTime=13.0,
        Brightness=3.0, Ambient=Color3.fromRGB(108,108,112),
        OutdoorAmbient=Color3.fromRGB(138,138,142),
        FogEnd=100000, FogStart=0, FogColor=Color3.fromRGB(200,200,205),
    },
    evening = {
        ClockTime=17.5,
        Brightness=1.5, Ambient=Color3.fromRGB(95,68,48),
        OutdoorAmbient=Color3.fromRGB(145,98,58),
        FogEnd=6000, FogStart=300, FogColor=Color3.fromRGB(228,155,92),
    },
    night = {
        ClockTime=23.0,
        Brightness=0.08, Ambient=Color3.fromRGB(18,18,30),
        OutdoorAmbient=Color3.fromRGB(12,12,22),
        FogEnd=1800, FogStart=0, FogColor=Color3.fromRGB(8,8,16),
    },
}

-- ── 夜間照明トグル ────────────────────────────────────────────
local nightLightsState = nil

local function toggleNightLights(enable)
    if nightLightsState == enable then return end
    nightLightsState = enable
    local rwFolder = Workspace:FindFirstChild(RW_FOLDER)
    if not rwFolder then return end
    for _, desc in ipairs(rwFolder:GetDescendants()) do
        if desc:IsA("PointLight") and desc.Name == "NightLight" then
            desc.Enabled = enable
        end
    end
    print(string.format("[TimeManager] 夜間照明 %s", enable and "ON" or "OFF"))
end

-- ── ライティング適用 ──────────────────────────────────────────
Lighting.GeographicLatitude = 34.7   -- 大阪の緯度

local prevPeriod   = nil
local timeOverride = nil   -- nil=実時間モード / string=手動設定中

local function applyLighting()
    local h      = getJSTHour()
    local period = timeOverride or getPeriod(h)

    -- 手動設定中は時間帯の代表時刻で太陽位置を固定、実時間モードは実時刻
    if timeOverride then
        Lighting.ClockTime = PERIOD_CFG[timeOverride].ClockTime
    else
        Lighting.ClockTime = h
    end

    if period ~= prevPeriod then
        prevPeriod = period
        local cfg = PERIOD_CFG[period]
        Lighting.Brightness     = cfg.Brightness
        Lighting.Ambient        = cfg.Ambient
        Lighting.OutdoorAmbient = cfg.OutdoorAmbient
        Lighting.FogEnd         = cfg.FogEnd
        Lighting.FogStart       = cfg.FogStart
        Lighting.FogColor       = cfg.FogColor
        toggleNightLights(period == "night")
        print(string.format("[TimeManager] 時間帯: %s (JST %.1f時)", period, h))
    end
end

-- ── 時刻設定パネル ────────────────────────────────────────────
-- 電車リスポーンキオスク（Z=4530〜4566）の隣に設置
local PANEL_X = 32
local PANEL_Z = 4582   -- 4番線キオスク(Z=4566)の次

local TIME_BTNS = {
    { id="dawn",    label="早朝",  color=Color3.fromRGB( 90, 70,115) },
    { id="morning", label="朝",    color=Color3.fromRGB(210,145, 50) },
    { id="noon",    label="昼",    color=Color3.fromRGB( 50,130,210) },
    { id="evening", label="夕方",  color=Color3.fromRGB(210, 85, 25) },
    { id="night",   label="夜",    color=Color3.fromRGB( 20, 20, 85) },
    { id="auto",    label="実時間", color=Color3.fromRGB( 40,110, 55) },
}

local function mkLP(parent, name, size, lp, color)
    local p = Instance.new("Part")
    p.Name          = name
    p.Size          = size
    p.Position      = lp + OFFSET
    p.Anchored      = true
    p.Color         = color
    p.Material      = Enum.Material.SmoothPlastic
    p.TopSurface    = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent        = parent
    return p
end

local BTN_SPACING = 4    -- ボタン間隔（Z方向・stud）
local BTN_W       = 3.2  -- ボタン幅（Z方向）
local BTN_H       = 2.4  -- ボタン高さ（キャラクターが見やすい高さ）
local BTN_CY      = 1.8  -- ボタン中心Y

local function buildTimePanel(folder)
    local model = Instance.new("Model")
    model.Name   = "TimePanel"
    model.Parent = folder

    local totalSpan = (#TIME_BTNS - 1) * BTN_SPACING
    local centerZ   = PANEL_Z + totalSpan / 2

    -- 支柱（パネル後部）
    mkLP(model, "BackPole",
        Vector3.new(0.35, BTN_CY * 2 + 1.2, totalSpan + BTN_W + 0.4),
        Vector3.new(PANEL_X - 1.8, BTN_CY + 0.6, centerZ),
        Color3.fromRGB(28, 34, 50))

    -- タイトルバー（全ボタンの上）
    local titlePart = mkLP(model, "Title",
        Vector3.new(0.3, 0.7, totalSpan + BTN_W + 0.4),
        Vector3.new(PANEL_X, BTN_CY + BTN_H/2 + 0.55, centerZ),
        Color3.fromRGB(0, 55, 120))
    local tbbg = Instance.new("BillboardGui")
    tbbg.Size        = UDim2.fromOffset(200, 36)
    tbbg.StudsOffset = Vector3.new(1.2, 0, 0)
    tbbg.MaxDistance = 25
    tbbg.Parent      = titlePart
    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.fromScale(1,1); tl.BackgroundTransparency = 1
    tl.Text = "時刻設定"; tl.TextColor3 = Color3.fromRGB(255,255,255)
    tl.TextSize = 18; tl.Font = Enum.Font.GothamBold; tl.Parent = tbbg

    -- ボタン（Z方向に横並び）
    for i, tb in ipairs(TIME_BTNS) do
        local btnZ = PANEL_Z + (i - 1) * BTN_SPACING

        local btn = mkLP(model, "TBtn_"..tb.id,
            Vector3.new(0.5, BTN_H, BTN_W),
            Vector3.new(PANEL_X, BTN_CY, btnZ), tb.color)
        btn.CanCollide = false  -- プレイヤーがすぐ前に立てるように

        -- ラベル（BillboardGui はボタン正面に表示）
        local bbg = Instance.new("BillboardGui")
        bbg.Size        = UDim2.fromOffset(140, 44)
        bbg.StudsOffset = Vector3.new(1.2, 0, 0)  -- プレイヤー側（+X方向）に表示
        bbg.MaxDistance = 15
        bbg.Parent      = btn
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.fromScale(1,1); lbl.BackgroundTransparency = 1
        lbl.Text = tb.label; lbl.TextColor3 = Color3.fromRGB(255,255,255)
        lbl.TextSize = 18; lbl.Font = Enum.Font.GothamBold; lbl.Parent = bbg

        -- ProximityPrompt
        local pp = Instance.new("ProximityPrompt")
        pp.ActionText            = tb.label .. "に設定"
        pp.ObjectText            = "時刻"
        pp.KeyboardKeyCode       = Enum.KeyCode.E
        pp.MaxActivationDistance = 8   -- 十分な起動距離
        pp.RequiresLineOfSight   = false
        pp.HoldDuration          = 0
        pp.Parent                = btn

        local capturedId = tb.id
        pp.Triggered:Connect(function()
            if capturedId == "auto" then
                timeOverride = nil
            else
                timeOverride = capturedId
            end
            prevPeriod = nil
            applyLighting()
        end)
    end
end

-- ── 起動: RailwayTest が生成されるまで待機 ────────────────────
repeat task.wait(1) until
    Workspace:FindFirstChild(RW_FOLDER) and
    Workspace:FindFirstChild(RW_FOLDER):FindFirstChild("Platform")

local rwFolder = Workspace:FindFirstChild(RW_FOLDER)
buildTimePanel(rwFolder)
applyLighting()

-- 30 秒ごとに ClockTime・時間帯を更新（太陽が滑らかに動く）
while true do
    task.wait(30)
    applyLighting()
end
