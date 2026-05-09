-- 現実の日本時間（JST）に連動した採光・夜間照明管理 + 手動時刻設定パネル

local Lighting          = game:GetService("Lighting")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RW_FOLDER = "RailwayTest"

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

-- ── 起動: RailwayTest が生成されるまで待機 ────────────────────
repeat task.wait(1) until
    Workspace:FindFirstChild(RW_FOLDER) and
    Workspace:FindFirstChild(RW_FOLDER):FindFirstChild("Platform")

-- TimeControl BindableEvent（AutoOperationManager から時刻変更を受け付ける）
local timeCtrl = Instance.new("BindableEvent")
timeCtrl.Name   = "TimeControl"
timeCtrl.Parent = ReplicatedStorage

timeCtrl.Event:Connect(function(periodId)
    if periodId == "auto" then
        timeOverride = nil
    elseif PERIOD_CFG[periodId] then
        timeOverride = periodId
    end
    prevPeriod = nil
    applyLighting()
end)

applyLighting()

-- 30 秒ごとに ClockTime・時間帯を更新（太陽が滑らかに動く）
while true do
    task.wait(30)
    applyLighting()
end
