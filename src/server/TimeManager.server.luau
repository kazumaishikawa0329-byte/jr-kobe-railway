-- 現実の日本時間（JST）に連動した採光・夜間照明管理 + 手動時刻設定パネル
-- 「現実に合わせる」モードでは大阪の実際の日の出・日の入り時刻（季節考慮）で
-- 早朝/朝/昼/夕方/夜 の境界を決定する。

local Lighting          = game:GetService("Lighting")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RW_FOLDER = "RailwayTest"

-- 大阪の地理情報
local OSAKA_LAT  = 34.7     -- 緯度（度）
local OSAKA_LON  = 135.52   -- 経度（度）
local JST_OFFSET = 9        -- UTC+9

-- ── JST 現在時刻（小数時間 0〜24）を返す ──────────────────────
local function getJSTHour()
    local jstSec = os.time() + JST_OFFSET * 3600
    local h = math.floor(jstSec / 3600) % 24
    local m = math.floor(jstSec / 60)   % 60
    local s = jstSec % 60
    return h + m / 60 + s / 3600
end

-- ── 年内通し番号（1〜366）を返す ───────────────────────────────
local function getDayOfYear()
    local jstSec        = os.time() + JST_OFFSET * 3600
    local daysSince1970 = math.floor(jstSec / 86400)
    local year = 1970
    local d    = daysSince1970
    while true do
        local isLeap     = (year % 4 == 0) and (year % 100 ~= 0 or year % 400 == 0)
        local daysInYear = isLeap and 366 or 365
        if d < daysInYear then break end
        d    = d - daysInYear
        year = year + 1
    end
    return d + 1  -- 1-indexed（1 = 1月1日）
end

-- ── 大阪の日の出・日の入り時刻（JST 小数時間）を天文計算 ──────
-- 精度: 実際の時刻との誤差は最大±数分（ゲーム用途では十分）
local function getOsakaSunTimes()
    local doy = getDayOfYear()

    -- 太陽赤緯（度）: 近似式
    local decl = -23.45 * math.cos(math.rad(360 / 365 * (doy + 10)))

    -- 日の出・日の入り時角（度）
    local cosH = -math.tan(math.rad(OSAKA_LAT)) * math.tan(math.rad(decl))
    cosH       = math.max(-1, math.min(1, cosH))   -- 極夜・白夜対策
    local H    = math.deg(math.acos(cosH))

    -- 均時差（分）: Spencer (1971) 近似
    local B   = math.rad(360 / 365 * (doy - 81))
    local EoT = 9.87 * math.sin(2 * B) - 7.53 * math.cos(B) - 1.5 * math.sin(B)

    -- 太陽正午（JST）= 12h − 経度補正 − 均時差
    local lonCorrH    = (OSAKA_LON - JST_OFFSET * 15) / 15   -- 大阪 135.52°、JST基準 135°
    local solarNoonJST = 12 - lonCorrH - EoT / 60

    -- 日の出・日の入り（JST）
    local sunrise = solarNoonJST - H / 15
    local sunset  = solarNoonJST + H / 15

    return sunrise, sunset
end

-- ── 時間帯判定（実際の日の出・日の入りを基準に設定）──────────
-- 早朝 (dawn)    : 日の出 −30分  ～  日の出 +30分
-- 朝   (morning) : 日の出 +30分  ～  日の出 +2.5時間
-- 昼   (noon)    : 日の出 +2.5時間  ～  日の入り −2.5時間
-- 夕方 (evening) : 日の入り −2.5時間  ～  日の入り +30分
-- 夜   (night)   : それ以外
local function getPeriodFromSun(h, sunrise, sunset)
    local dawnStart    = sunrise - 0.5
    local morningStart = sunrise + 0.5
    local noonStart    = sunrise + 2.5
    local eveningStart = sunset  - 2.5
    local nightStart   = sunset  + 0.5

    if     h >= dawnStart    and h < morningStart then return "dawn"
    elseif h >= morningStart and h < noonStart    then return "morning"
    elseif h >= noonStart    and h < eveningStart then return "noon"
    elseif h >= eveningStart and h < nightStart   then return "evening"
    else                                               return "night"
    end
end

-- ── 時間帯別ライティング設定 ─────────────────────────────────
-- ClockTime は手動切替時の代表時刻（実時間モードでは実JST時刻を使用）
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

local nightStatValue = Instance.new("BoolValue")
nightStatValue.Name   = "NightLightsOn"
nightStatValue.Value  = false
nightStatValue.Parent = ReplicatedStorage

local function toggleNightLights(enable)
    if nightLightsState == enable then return end
    nightLightsState     = enable
    nightStatValue.Value = enable
    local rwFolder = Workspace:FindFirstChild(RW_FOLDER)
    if not rwFolder then return end
    for _, desc in ipairs(rwFolder:GetDescendants()) do
        if desc:IsA("Light") and desc.Name == "NightLight" then
            desc.Enabled = enable
        end
    end
    print(string.format("[TimeManager] 夜間照明 %s", enable and "ON" or "OFF"))
end

-- ── ライティング適用 ──────────────────────────────────────────
Lighting.GeographicLatitude = OSAKA_LAT

local prevPeriod   = nil
local timeOverride = nil   -- nil = 実時間モード / string = 手動設定中

local function applyLighting()
    local h      = getJSTHour()
    local period

    if timeOverride then
        -- 手動設定: 固定代表時刻で太陽位置を固定
        period             = timeOverride
        Lighting.ClockTime = PERIOD_CFG[timeOverride].ClockTime
    else
        -- 実時間モード: 大阪の季節を考慮した日の出・日の入りで時間帯を判定
        local sunrise, sunset = getOsakaSunTimes()
        period             = getPeriodFromSun(h, sunrise, sunset)
        Lighting.ClockTime = h   -- 実際のJST時刻で太陽位置を反映

        if prevPeriod ~= period then
            -- 時間帯変化時に季節情報を出力
            print(string.format(
                "[TimeManager] 日の出 %02d:%02d / 日の入り %02d:%02d (大阪, 第%d日)",
                math.floor(sunrise), math.floor((sunrise % 1) * 60),
                math.floor(sunset),  math.floor((sunset  % 1) * 60),
                getDayOfYear()
            ))
        end
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
    prevPeriod = nil   -- 強制再適用
    applyLighting()
end)

applyLighting()

-- 30 秒ごとに ClockTime・時間帯を更新（太陽が滑らかに動く）
while true do
    task.wait(30)
    applyLighting()
end
