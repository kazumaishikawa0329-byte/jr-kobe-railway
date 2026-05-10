-- 踏切管理: 電車が踏切に到着する20秒前から鳴動＋遮断機降下
--           電車の最後尾通過の2秒後に鳴動停止＋遮断機上昇
-- 1～4線すべての電車を監視。複数踏切（RailwayCrossing_* 名称）対応。

local Workspace    = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local RW_FOLDER   = "RailwayTest"
local NUM_TRACKS  = 4
local WARN_TIME   = 20    -- 鳴動開始（到着 N 秒前）
local PASS_DELAY  = 2     -- 最後尾通過後の停止ディレイ（秒）
local INTERVAL    = 0.5   -- ポーリング間隔（秒）
local MIN_SPEED   = 1.0   -- 有効速度の下限（studs/s）

local SOUND_ID    = "113257060463968"
local SOUND_VOL   = 4.0

local GATE_DOWN_INFO = TweenInfo.new(3.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local GATE_UP_INFO   = TweenInfo.new(3.0, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local GATE_HALF_LEN  = 4.25
local GATE_PIVOT_Y   = 3.8

-- ── RailwayTest 生成待機 ──────────────────────────────────────
repeat task.wait(1) until Workspace:FindFirstChild(RW_FOLDER)
local rwFolder = Workspace:FindFirstChild(RW_FOLDER)

-- ── 踏切モデル待機 ───────────────────────────────────────────
repeat task.wait(0.5) until (function()
    for _, child in ipairs(rwFolder:GetChildren()) do
        if child:IsA("Model") and child.Name:find("^RailwayCrossing") then
            return true
        end
    end
    return false
end)()

-- ── 踏切データ構造構築 ────────────────────────────────────────
local crossings = {}

for _, child in ipairs(rwFolder:GetChildren()) do
    if not (child:IsA("Model") and child.Name:find("^RailwayCrossing")) then continue end

    local road = child:FindFirstChild("CrossRoad")
    if not road then continue end

    local snd = Instance.new("Sound")
    snd.SoundId            = "rbxassetid://" .. SOUND_ID
    snd.Volume             = SOUND_VOL
    snd.Looped             = true
    snd.RollOffMaxDistance = 500
    snd.RollOffMinDistance = 30
    snd.Parent             = road

    local gates = {}
    for _, part in ipairs(child:GetDescendants()) do
        if part:IsA("BasePart") and part.Name:match("^Gate_") then
            local raisedCF  = part.CFrame
            local p         = part.Position
            local pivotX    = p.X
            local crossZ    = p.Z + GATE_HALF_LEN
            local armD      = p.Y - (GATE_PIVOT_Y + GATE_HALF_LEN)
            local loweredCF = CFrame.new(pivotX, GATE_PIVOT_Y, crossZ + armD)
            table.insert(gates, {
                part      = part,
                raisedCF  = raisedCF,
                loweredCF = loweredCF,
                tween     = nil,
            })
        end
    end

    local czVal     = child:FindFirstChild("CrossingZ")
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

-- ── 警報開始 ─────────────────────────────────────────────────
local function startCrossing(cx)
    if cx.ringing then return end
    cx.sound:Play()
    cx.ringing = true
    for _, g in ipairs(cx.gates) do
        if g.tween then g.tween:Cancel() end
        g.tween = TweenService:Create(g.part, GATE_DOWN_INFO, {CFrame = g.loweredCF})
        g.tween:Play()
    end
    print("[CrossingManager] " .. cx.model.Name .. " 警報 ON")
end

-- ── 警報停止 ─────────────────────────────────────────────────
local function stopCrossing(cx)
    if not cx.ringing then return end
    cx.sound:Stop()
    cx.ringing = false
    for _, g in ipairs(cx.gates) do
        if g.tween then g.tween:Cancel() end
        g.tween = TweenService:Create(g.part, GATE_UP_INFO, {CFrame = g.raisedCF})
        g.tween:Play()
    end
    print("[CrossingManager] " .. cx.model.Name .. " 警報 OFF")
end

-- ── 列車の Z 範囲（最小Z・最大Z）を取得 ─────────────────────
local function getTrainZRange(train)
    local minZ, maxZ = math.huge, -math.huge
    for i = 1, 4 do
        local car  = train:FindFirstChild("Car" .. i)
        local body = car and car:FindFirstChild("Body")
        if body and body:IsA("BasePart") then
            local z = body.Position.Z
            if z < minZ then minZ = z end
            if z > maxZ then maxZ = z end
        end
    end
    if minZ == math.huge then return nil, nil end
    return minZ, maxZ
end

-- ── 踏切×線路ごとの状態 ──────────────────────────────────────
-- state.prevMinZ  : 前フレームの minZ（速度推定用）
-- state.active    : この線路がこの踏切をアクティブにしているか
-- state.passedAt  : 最後尾通過時刻（PASS_DELAY 待機に使用）
-- state.activeDir : アクティブ化時の方向（-1 = -Z方向, 1 = +Z方向）
local trackStates = {}
for ci = 1, #crossings do
    trackStates[ci] = {}
    for t = 1, NUM_TRACKS do
        trackStates[ci][t] = {
            prevMinZ  = nil,
            active    = false,
            passedAt  = nil,
            activeDir = 0,
        }
    end
end

-- ── メインループ（INTERVAL 秒ごとに全踏切×全線路を評価）──────
while true do
    task.wait(INTERVAL)
    local now = tick()

    for ci, cx in ipairs(crossings) do
        local anyActive = false
        local cz = cx.crossingZ

        for t = 1, NUM_TRACKS do
            local state = trackStates[ci][t]
            local train = rwFolder:FindFirstChild("Train_" .. t)

            -- 列車が存在しない場合はリセット
            if not train then
                state.prevMinZ  = nil
                state.active    = false
                state.passedAt  = nil
                state.activeDir = 0
                continue
            end

            local minZ, maxZ = getTrainZRange(train)
            if not minZ then
                state.active    = false
                state.passedAt  = nil
                state.activeDir = 0
                continue
            end

            -- 速度推定（studs/s、正 = +Z方向）
            local vel = state.prevMinZ and ((minZ - state.prevMinZ) / INTERVAL) or 0
            state.prevMinZ = minZ

            if state.active then
                -- ── アクティブ中: 最後尾通過を監視 ──────────────────
                if state.passedAt then
                    -- 通過後 PASS_DELAY 秒待機中
                    if now - state.passedAt >= PASS_DELAY then
                        state.active    = false
                        state.passedAt  = nil
                        state.activeDir = 0
                    else
                        anyActive = true
                    end
                else
                    -- 最後尾が踏切を越えたか確認
                    -- activeDir を使い、アクティブ化時の方向を基準にする
                    local allPassed = false
                    if state.activeDir == -1 then
                        -- -Z方向: 最後尾 = maxZ（最も +Z 側の車両）
                        allPassed = (maxZ < cz)
                    elseif state.activeDir == 1 then
                        -- +Z方向: 最後尾 = minZ（最も -Z 側の車両）
                        allPassed = (minZ > cz)
                    end

                    if allPassed then
                        state.passedAt = now  -- 通過完了、PASS_DELAY 待機へ
                    end
                    anyActive = true  -- 通過中または待機中はアクティブ維持
                end
            else
                -- ── 非アクティブ: 接近チェック ───────────────────────
                if math.abs(vel) >= MIN_SPEED then
                    local isApproaching = false
                    local frontDist     = 0

                    if vel < 0 then
                        -- -Z方向移動: 前頭 = minZ
                        isApproaching = (minZ > cz)   -- まだ踏切に達していない
                        frontDist     = minZ - cz      -- 前頭から踏切までの距離（正）
                    else
                        -- +Z方向移動: 前頭 = maxZ
                        isApproaching = (maxZ < cz)   -- まだ踏切に達していない
                        frontDist     = cz - maxZ      -- 前頭から踏切までの距離（正）
                    end

                    if isApproaching and frontDist > 0 then
                        local tta = frontDist / math.abs(vel)  -- 到着までの秒数
                        if tta <= WARN_TIME then
                            state.active    = true
                            state.passedAt  = nil
                            state.activeDir = (vel < 0) and -1 or 1
                            anyActive       = true
                        end
                    end
                end
            end
        end

        -- 踏切制御: いずれかの線路がアクティブなら鳴動
        if anyActive and not cx.ringing then
            startCrossing(cx)
        elseif not anyActive and cx.ringing then
            stopCrossing(cx)
        end
    end
end
