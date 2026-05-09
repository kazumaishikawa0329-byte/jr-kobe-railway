-- 自動運行モード管理サーバー

local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OFFSET    = Vector3.new(40, 0, 0)
local RW_FOLDER = "RailwayTest"

local updateBillboard = function() end  -- パネル生成後に再定義

local STATIONS = {
    {name = "大阪",          z =  4530},
    {name = "塚本",          z =  1630},
    {name = "尼崎",          z = -1570},
    {name = "甲子園口",      z = -4170},
    {name = "立花",          z = -6570},
    {name = "芦屋",          z = -9970},
    {name = "西芦屋",        z = -12770},
    {name = "三宮",          z = -15770},
    {name = "神戸三宮",      z = -18470},
    {name = "神戸",          z = -21370},
    {name = "神戸新町",      z = -24370},
    {name = "西神戸",        z = -27470},
    {name = "淡路橋",        z = -30670},
    {name = "神戸海",        z = -34070},
    {name = "明石",          z = -37070},
    {name = "西明石",        z = -39870},
    {name = "東加古川",      z = -43270},
    {name = "加古川",        z = -46570},
    {name = "加古川商店街",  z = -49470},
    {name = "海姫路",        z = -53070},
    {name = "東姫路",        z = -56270},
    {name = "姫路公園",      z = -59170},
    {name = "姫路",          z = -62270},
    {name = "山陽姫路",      z = -65270},
    {name = "西山陽姫路",    z = -67970},
    {name = "姫路野球場",    z = -70970},
    {name = "播磨姫路",      z = -74270},
    {name = "播磨勝原",      z = -77870},
    {name = "東網干",        z = -81670},
    {name = "網干",          z = -84970},
}

-- 自動運行状態
local autoOpActive = {}
for t = 1, 4 do autoOpActive[t] = false end

local trainPresent = {}
for t = 1, 4 do trainPresent[t] = false end

local autoOpConfig = {}
for t = 1, 4 do autoOpConfig[t] = {startIdx = 1, endIdx = #STATIONS} end

-- RemoteEvents
local remFolder = Instance.new("Folder")
remFolder.Name   = "AutoOpRemotes"
remFolder.Parent = ReplicatedStorage

local evtOpenPanel = Instance.new("RemoteEvent")
evtOpenPanel.Name   = "AutoOpOpenPanel"
evtOpenPanel.Parent = remFolder

local evtStart = Instance.new("RemoteEvent")
evtStart.Name   = "AutoOpStart"
evtStart.Parent = remFolder

local evtStop = Instance.new("RemoteEvent")
evtStop.Name   = "AutoOpStop"
evtStop.Parent = remFolder

local evtStatus = Instance.new("RemoteEvent")
evtStatus.Name   = "AutoOpStatus"
evtStatus.Parent = remFolder

local evtSpawnTrain = Instance.new("RemoteEvent")
evtSpawnTrain.Name   = "AutoOpSpawnTrain"
evtSpawnTrain.Parent = remFolder

local evtSetTime = Instance.new("RemoteEvent")
evtSetTime.Name   = "AutoOpSetTime"
evtSetTime.Parent = remFolder

local evtStateSync = Instance.new("RemoteEvent")
evtStateSync.Name   = "AutoOpStateSync"
evtStateSync.Parent = remFolder

-- 駅名リスト（クライアントが参照）
local stListFolder = Instance.new("Folder")
stListFolder.Name   = "StationList"
stListFolder.Parent = remFolder
for i, st in ipairs(STATIONS) do
    local sv = Instance.new("StringValue")
    sv.Name   = tostring(i)
    sv.Value  = st.name
    sv.Parent = stListFolder
end

-- TrainBuilder インターフェース参照（初期化後に設定）
local trainCtrl  = nil
local trainQuery = nil

-- ============================================================
-- 列車位置取得（4両の InteriorFloor の平均Z）
-- ============================================================
local function getTrainCenterZ(trackNum)
    local rwFolder = Workspace:FindFirstChild(RW_FOLDER)
    if not rwFolder then return nil end
    local model = rwFolder:FindFirstChild("Train_" .. trackNum)
    if not model then return nil end
    local sum, count = 0, 0
    for i = 1, 4 do
        local car   = model:FindFirstChild("Car" .. i)
        local floor = car and car:FindFirstChild("InteriorFloor")
        if floor and floor:IsA("BasePart") then
            sum   += floor.Position.Z
            count += 1
        end
    end
    return count > 0 and (sum / count) or nil
end

-- ============================================================
-- 自動運行コルーチン
-- ============================================================
local DWELL_TIME     = 6     -- ドア開放秒数
local BRAKE_MARGIN   = 1.45  -- 制動距離マージン
local DOOR_ANIM_WAIT = 2.1   -- ドア閉アニメーション待機
local STOP_DIST      = 14    -- 到着判定距離（stud）
local SLOW_DIST      = 55    -- 低速制御開始距離（stud）
local SLOW_SPEED_THR = 8     -- この速度以下で到着判定

local function autoOpCoroutine(trackNum, stationIndices)
    local ctrl  = trainCtrl
    local query = trainQuery
    if not ctrl or not query then
        print("[AutoOp] インターフェース未初期化")
        return
    end

    -- 列車が無ければ生成
    if not query:Invoke(trackNum, "HasTrain") then
        ctrl:Fire(trackNum, "Build", nil)
        task.wait(3)
    end

    -- 初期ドア閉
    ctrl:Fire(trackNum, "SetDoor", false)
    task.wait(DOOR_ANIM_WAIT + 0.3)

    local routeLen = #stationIndices

    -- 現在位置から最寄りルート駅を特定
    local posInRoute = 1
    local trainZ     = getTrainCenterZ(trackNum)
    if trainZ then
        local best = math.huge
        for ri, si in ipairs(stationIndices) do
            local d = math.abs(STATIONS[si].z - trainZ)
            if d < best then best = d; posInRoute = ri end
        end
    end

    local goingForward = posInRoute < routeLen

    evtStatus:FireAllClients(trackNum, "running",
        STATIONS[stationIndices[posInRoute]].name)

    while autoOpActive[trackNum] do
        -- 次駅決定
        local nextPos = goingForward and (posInRoute + 1) or (posInRoute - 1)

        if nextPos > routeLen then
            goingForward = false
            nextPos = posInRoute - 1
        elseif nextPos < 1 then
            goingForward = true
            nextPos = posInRoute + 1
        end

        if nextPos < 1 or nextPos > routeLen then break end

        local targetZ    = STATIONS[stationIndices[nextPos]].z
        local targetName = STATIONS[stationIndices[nextPos]].name

        evtStatus:FireAllClients(trackNum, "departing", targetName)

        trainZ = getTrainCenterZ(trackNum)
        if not trainZ then break end

        local moveDir = (targetZ > trainZ) and 1 or -1

        ctrl:Fire(trackNum, "SetDir", moveDir)
        ctrl:Fire(trackNum, "SetCtrl", "加速")

        -- ── 走行ループ ──
        local arrived = false
        while autoOpActive[trackNum] and not arrived do
            task.wait(0.1)
            trainZ = getTrainCenterZ(trackNum)
            if not trainZ then arrived = true; break end

            local dist = math.abs(targetZ - trainZ)
            local spd  = query:Invoke(trackNum, "Speed")

            -- オーバーシュート検出
            local pastTarget = (moveDir == 1 and trainZ > targetZ + STOP_DIST)
                            or (moveDir == -1 and trainZ < targetZ - STOP_DIST)

            if pastTarget then
                ctrl:Fire(trackNum, "SetDir", 0)
                ctrl:Fire(trackNum, "SetCtrl", "急ブレーキ")
                task.wait(2)
                if not autoOpActive[trackNum] then break end

                -- 微速で戻る
                ctrl:Fire(trackNum, "SetDir", -moveDir)
                ctrl:Fire(trackNum, "SetCtrl", "加速")
                while autoOpActive[trackNum] do
                    task.wait(0.1)
                    trainZ = getTrainCenterZ(trackNum)
                    if not trainZ then break end
                    local d2 = math.abs(targetZ - trainZ)
                    local s2 = query:Invoke(trackNum, "Speed")
                    if d2 < SLOW_DIST then ctrl:Fire(trackNum, "SetCtrl", "ブレーキ") end
                    if d2 < STOP_DIST and s2 < SLOW_SPEED_THR then
                        ctrl:Fire(trackNum, "SetDir", 0)
                        ctrl:Fire(trackNum, "SetCtrl", "急ブレーキ")
                        task.wait(1)
                        arrived = true
                        break
                    end
                end
                break
            end

            -- 制動開始距離: V²/86.4 × マージン + 最低30
            local brakeDist = math.max(30, (spd * spd) / 86.4 * BRAKE_MARGIN)

            if dist < STOP_DIST and spd < SLOW_SPEED_THR then
                ctrl:Fire(trackNum, "SetDir", 0)
                ctrl:Fire(trackNum, "SetCtrl", "急ブレーキ")
                task.wait(1)
                arrived = true
            elseif dist <= brakeDist then
                ctrl:Fire(trackNum, "SetCtrl", "ブレーキ")
            else
                ctrl:Fire(trackNum, "SetCtrl", "加速")
            end
        end

        if not autoOpActive[trackNum] then break end

        -- ── 到着処理 ──
        posInRoute = nextPos
        ctrl:Fire(trackNum, "SetDir", 0)
        ctrl:Fire(trackNum, "SetCtrl", "加速停止")

        evtStatus:FireAllClients(trackNum, "arrived", targetName)

        ctrl:Fire(trackNum, "SetDoor", true)

        -- 乗降待機
        local tick = 0
        while autoOpActive[trackNum] and tick < DWELL_TIME * 10 do
            task.wait(0.1); tick += 1
        end
        if not autoOpActive[trackNum] then break end

        ctrl:Fire(trackNum, "SetDoor", false)
        task.wait(DOOR_ANIM_WAIT)

        -- 折り返し判定更新
        if posInRoute >= routeLen then
            goingForward = false
        elseif posInRoute <= 1 then
            goingForward = true
        end
    end

    -- 終了処理
    ctrl:Fire(trackNum, "SetDir", 0)
    ctrl:Fire(trackNum, "SetCtrl", "急ブレーキ")
    ctrl:Fire(trackNum, "SetDoor", true)
    autoOpActive[trackNum] = false
    evtStatus:FireAllClients(trackNum, "stopped", "")
    print(string.format("[AutoOp] %d番線 自動運行終了", trackNum))
end

-- ============================================================
-- 開始 / 停止
-- ============================================================
local function startAutoOp(trackNum, startIdx, endIdx)
    if autoOpActive[trackNum] then
        autoOpActive[trackNum] = false
        task.wait(0.4)
    end

    local indices = {}
    local step = startIdx <= endIdx and 1 or -1
    for i = startIdx, endIdx, step do table.insert(indices, i) end

    if #indices < 2 then return end

    autoOpActive[trackNum] = true
    task.spawn(autoOpCoroutine, trackNum, indices)
    print(string.format("[AutoOp] %d番線 自動運行開始 (%s〜%s)",
        trackNum, STATIONS[startIdx].name, STATIONS[endIdx].name))
end

local function stopAutoOp(trackNum)
    autoOpActive[trackNum] = false
    print(string.format("[AutoOp] %d番線 自動運行停止要求", trackNum))
end

evtStart.OnServerEvent:Connect(function(_, trackNum, startIdx, endIdx)
    if type(trackNum) ~= "number" or trackNum < 1 or trackNum > 4 then return end
    if type(startIdx) ~= "number" or type(endIdx) ~= "number" then return end
    startIdx = math.clamp(math.floor(startIdx), 1, #STATIONS)
    endIdx   = math.clamp(math.floor(endIdx),   1, #STATIONS)
    if startIdx == endIdx then return end
    autoOpConfig[trackNum] = {startIdx = startIdx, endIdx = endIdx}
    startAutoOp(trackNum, startIdx, endIdx)
    task.defer(function() updateBillboard() end)
end)

evtStop.OnServerEvent:Connect(function(_, trackNum)
    if type(trackNum) == "number" and trackNum >= 1 and trackNum <= 4 then
        stopAutoOp(trackNum)
        task.defer(function() updateBillboard() end)
    end
end)

-- ============================================================
-- パネル生成（RailwayTest / TrainBuilder 起動待ち）
-- ============================================================
repeat task.wait() until Workspace:FindFirstChild(RW_FOLDER)
    and Workspace:FindFirstChild(RW_FOLDER):FindFirstChild("Platform")

trainCtrl  = ReplicatedStorage:WaitForChild("TrainAutoControl", 15)
trainQuery = ReplicatedStorage:WaitForChild("TrainAutoQuery",   15)

if not trainCtrl or not trainQuery then
    warn("[AutoOp] TrainBuilder インターフェースが見つかりません")
    return
end

local rwFolder = Workspace:FindFirstChild(RW_FOLDER)

local function mkP(parent, name, size, lp, color, mat)
    local p = Instance.new("Part")
    p.Name          = name
    p.Size          = size
    p.Position      = lp + OFFSET
    p.Anchored      = true
    p.Color         = color
    p.Material      = mat or Enum.Material.SmoothPlastic
    p.TopSurface    = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent        = parent
    return p
end

-- ============================================================
-- 物理パネル：キオスク列(X=32)と並行して X=44 に番線別ボタンを配置
-- キオスク Z と同じ位置: 4530, 4542, 4554, 4566
-- ============================================================
local PANEL_X   = 44     -- プレイヤースポーン(X=49)とキオスク列(X=32)の中間
local BTN_ZS    = {4530, 4542, 4554, 4566}
local GROUND_Y  = 0.5    -- OsakaPlaza 天面 Y
local BTN_H     = 1.8
local BTN_CY    = GROUND_Y + BTN_H / 2          -- 1.4
local POLE_H    = 3.4
local POLE_CY   = GROUND_Y + BTN_H + POLE_H / 2 -- 4.0

local TRACK_COLS = {
    Color3.fromRGB(0,   82, 160),
    Color3.fromRGB(0,  150,  60),
    Color3.fromRGB(200,  90,   0),
    Color3.fromRGB(180,   0,   0),
}

local panelModel = Instance.new("Model")
panelModel.Name   = "AutoOpPanel"
panelModel.Parent = rwFolder

-- 背面サポートバー
local spanZ   = BTN_ZS[4] - BTN_ZS[1]
local centerZ = (BTN_ZS[1] + BTN_ZS[4]) / 2

mkP(panelModel, "BackBar",
    Vector3.new(0.45, BTN_CY * 2 + 0.8, spanZ + 5),
    Vector3.new(PANEL_X - 2.0, BTN_CY + 0.4, centerZ),
    Color3.fromRGB(14, 20, 48))

-- タイトルバー（全ボタン上部）
local titlePart = mkP(panelModel, "TitleBar",
    Vector3.new(0.4, 0.75, spanZ + 5.5),
    Vector3.new(PANEL_X, GROUND_Y + BTN_H + 0.62, centerZ),
    Color3.fromRGB(0, 75, 195))

local tbbg = Instance.new("BillboardGui")
tbbg.Size        = UDim2.fromOffset(250, 36)
tbbg.StudsOffset = Vector3.new(1.6, 0, 0)
tbbg.MaxDistance = 35
tbbg.Parent      = titlePart
local tLbl = Instance.new("TextLabel")
tLbl.Size = UDim2.fromScale(1, 1); tLbl.BackgroundTransparency = 1
tLbl.Text = "自動運行設定"; tLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
tLbl.TextSize = 20; tLbl.Font = Enum.Font.GothamBold; tLbl.Parent = tbbg

-- 番線ごとのボタンとラベル
local trackBillboards = {}  -- [t] = TextLabel

for t = 1, 4 do
    local btnZ = BTN_ZS[t]

    -- ボタン本体
    local btn = mkP(panelModel, "TrackBtn_" .. t,
        Vector3.new(0.5, BTN_H, 3.8),
        Vector3.new(PANEL_X, BTN_CY, btnZ),
        TRACK_COLS[t])
    btn.CanCollide = false

    -- ネオンポール
    mkP(panelModel, "Pole_" .. t,
        Vector3.new(0.28, POLE_H, 0.28),
        Vector3.new(PANEL_X, POLE_CY, btnZ),
        TRACK_COLS[t], Enum.Material.Neon)

    -- BillboardGui（番線名 + 状態）
    local bbg = Instance.new("BillboardGui")
    bbg.Size        = UDim2.fromOffset(210, 56)
    bbg.StudsOffset = Vector3.new(1.6, 0, 0)
    bbg.MaxDistance = 30
    bbg.Parent      = btn

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.fromScale(1, 1)
    lbl.BackgroundColor3       = Color3.fromRGB(8, 12, 28)
    lbl.BackgroundTransparency = 0.08
    lbl.Text                   = t .. "番線\n待機中"
    lbl.TextColor3             = Color3.fromRGB(200, 215, 255)
    lbl.TextSize               = 17
    lbl.Font                   = Enum.Font.GothamBold
    lbl.Parent                 = bbg
    local lc = Instance.new("UICorner"); lc.CornerRadius = UDim.new(0, 5); lc.Parent = lbl

    trackBillboards[t] = lbl

    -- ProximityPrompt（番線番号を FireClient で渡す）
    local pp = Instance.new("ProximityPrompt")
    pp.ActionText            = "自動運行を設定"
    pp.ObjectText            = t .. "番線"
    pp.KeyboardKeyCode       = Enum.KeyCode.E
    pp.MaxActivationDistance = 8
    pp.RequiresLineOfSight   = false
    pp.HoldDuration          = 0
    pp.Parent                = btn

    local capturedT = t
    pp.Triggered:Connect(function(player)
        local statuses = {}
        for tr = 1, 4 do statuses[tr] = autoOpActive[tr] end
        evtOpenPanel:FireClient(player, statuses, capturedT, trainPresent, autoOpConfig)
    end)
end

-- Billboard 更新（autoOpActive を参照）
updateBillboard = function()
    for t = 1, 4 do
        local lbl = trackBillboards[t]
        if not lbl then continue end
        if autoOpActive[t] then
            lbl.Text      = t .. "番線\n自動運行中"
            lbl.TextColor3 = Color3.fromRGB(100, 220, 120)
        else
            lbl.Text      = t .. "番線\n待機中"
            lbl.TextColor3 = Color3.fromRGB(200, 215, 255)
        end
    end
end

print("[AutoOpManager] 自動運行パネルを設置しました。")

-- ============================================================
-- TrainStateChanged 購読（列車スポーン/格納状態を追跡）
-- ============================================================
local trainStateChanged = ReplicatedStorage:WaitForChild("TrainStateChanged", 15)
if trainStateChanged then
    trainStateChanged.Event:Connect(function(trackNum, hasTrain)
        if type(trackNum) ~= "number" then return end
        trainPresent[trackNum] = hasTrain
        evtStateSync:FireAllClients(trackNum, hasTrain)
        task.defer(function() updateBillboard() end)
    end)
end

-- ============================================================
-- スポーン/格納リクエスト処理
-- ============================================================
evtSpawnTrain.OnServerEvent:Connect(function(_, trackNum, action)
    if type(trackNum) ~= "number" or trackNum < 1 or trackNum > 4 then return end
    if action == "spawn" then
        trainCtrl:Fire(trackNum, "Build", nil)
    elseif action == "store" then
        if autoOpActive[trackNum] then stopAutoOp(trackNum) end
        trainCtrl:Fire(trackNum, "Store", nil)
    end
end)

-- ============================================================
-- 時刻設定リクエスト処理
-- ============================================================
local timeCtrl = ReplicatedStorage:WaitForChild("TimeControl", 15)

evtSetTime.OnServerEvent:Connect(function(_, periodId)
    if timeCtrl and type(periodId) == "string" then
        timeCtrl:Fire(periodId)
    end
end)
