-- 踏切管理: 列車接近で警報音 + 遮断機降下、通過後に上昇
-- 複数踏切（RailwayCrossing_* という名前のモデルをすべて対象）

local Workspace    = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local RW_FOLDER    = "RailwayTest"
local NUM_TRACKS   = 4
local DETECT_RANGE = 900    -- 鳴動開始距離 stud（130 km/h ≈ 25 秒前）
local SOUND_ID     = "113257060463968"
local SOUND_VOL    = 4.0    -- 踏切音量（4倍）

-- 遮断機アニメーション設定
local GATE_DOWN_INFO = TweenInfo.new(3.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local GATE_UP_INFO   = TweenInfo.new(3.0, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-- RailwayTestBuilder と一致する定数
local GATE_HALF_LEN  = 4.25   -- (8+0.5)/2
local GATE_PIVOT_Y   = 3.8    -- CROSSING_PIVOT_Y

-- ── RailwayTest が生成されるまで待機 ─────────────────────────
repeat task.wait(1) until Workspace:FindFirstChild(RW_FOLDER)
local rwFolder = Workspace:FindFirstChild(RW_FOLDER)

-- ── 踏切モデルをすべて収集（名前が RailwayCrossing_ で始まるもの）
repeat task.wait(0.5) until (function()
    for _, child in ipairs(rwFolder:GetChildren()) do
        if child:IsA("Model") and child.Name:find("^RailwayCrossing") then
            return true
        end
    end
    return false
end)()

-- ── 踏切ごとのデータ構造を構築 ───────────────────────────────
local crossings = {}

for _, child in ipairs(rwFolder:GetChildren()) do
    if not (child:IsA("Model") and child.Name:find("^RailwayCrossing")) then continue end

    local road = child:FindFirstChild("CrossRoad")
    if not road then continue end

    -- 踏切音（路面パーツに 3D 空間音として設置）
    local snd = Instance.new("Sound")
    snd.SoundId             = "rbxassetid://" .. SOUND_ID
    snd.Volume              = SOUND_VOL
    snd.Looped              = true
    snd.RollOffMaxDistance  = 500
    snd.RollOffMinDistance  = 30
    snd.Parent              = road

    -- 遮断機腕木パーツ（Gate_ で始まる全パーツ）を収集
    -- 全パーツは同一ピボット軸を共有: pivotZ = part.Z、pivotY = GATE_PIVOT_Y
    -- armD = arm center からのオフセット（raised 時 world Y = GATE_PIVOT_Y + GATE_HALF_LEN + armD）
    -- loweredCF = CFrame.new(pivotX, GATE_PIVOT_Y, crossZ + armD)  ← 回転なし（水平）
    local gates = {}
    for _, part in ipairs(child:GetDescendants()) do
        if part:IsA("BasePart") and part.Name:match("^Gate_") then
            local raisedCF = part.CFrame
            local p        = part.Position
            local pivotX   = p.X
            local crossZ   = p.Z + GATE_HALF_LEN                              -- 踏切中心 Z
            local armD     = p.Y - (GATE_PIVOT_Y + GATE_HALF_LEN)             -- 腕木軸オフセット
            local loweredCF = CFrame.new(pivotX, GATE_PIVOT_Y, crossZ + armD)

            table.insert(gates, {
                part      = part,
                raisedCF  = raisedCF,
                loweredCF = loweredCF,
                tween     = nil,
            })
        end
    end

    -- 踏切の Z 座標（CrossingZ StringValue から取得、なければ road.Position.Z で代用）
    local czVal = child:FindFirstChild("CrossingZ")
    local crossingZ = czVal and tonumber(czVal.Value) or road.Position.Z

    table.insert(crossings, {
        model     = child,
        sound     = snd,
        gates     = gates,
        crossingZ = crossingZ,
        ringing   = false,
    })
end

print(string.format("[CrossingManager] %d 箇所の踏切を管理開始", #crossings))

-- ── 0.5 秒ごとに列車位置をチェック ──────────────────────────
while true do
    task.wait(0.5)

    for _, cx in ipairs(crossings) do
        -- いずれかの列車が検知範囲内か確認
        local anyNear = false
        for t = 1, NUM_TRACKS do
            local train = rwFolder:FindFirstChild("Train_" .. t)
            if not train then continue end
            local car1 = train:FindFirstChild("Car1")
            if not car1 then continue end
            local body = car1:FindFirstChild("Body")
            if not body then continue end
            if math.abs(body.Position.Z - cx.crossingZ) < DETECT_RANGE then
                anyNear = true
                break
            end
        end

        if anyNear and not cx.ringing then
            -- 警報開始 + 遮断機降下
            cx.sound:Play()
            cx.ringing = true
            for _, g in ipairs(cx.gates) do
                if g.tween then g.tween:Cancel() end
                g.tween = TweenService:Create(g.part, GATE_DOWN_INFO, {CFrame = g.loweredCF})
                g.tween:Play()
            end
            print("[CrossingManager] " .. cx.model.Name .. " 警報 ON")

        elseif not anyNear and cx.ringing then
            -- 警報停止 + 遮断機上昇
            cx.sound:Stop()
            cx.ringing = false
            for _, g in ipairs(cx.gates) do
                if g.tween then g.tween:Cancel() end
                g.tween = TweenService:Create(g.part, GATE_UP_INFO, {CFrame = g.raisedCF})
                g.tween:Play()
            end
            print("[CrossingManager] " .. cx.model.Name .. " 警報 OFF")
        end
    end
end
