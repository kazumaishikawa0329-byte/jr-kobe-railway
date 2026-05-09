-- 自動運行モード管理サーバー（4線独立制）

local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OFFSET    = Vector3.new(40, 0, 0)
local RW_FOLDER = "RailwayTest"

local updateBillboard = function() end

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

local autoOpActive = {}
local trainPresent = {}
local autoOpConfig = {}

for t = 1, 4 do
    autoOpActive[t] = false
    trainPresent[t] = false
    autoOpConfig[t] = {startIdx = 1, endIdx = #STATIONS}
end

-- RemoteEvents
local remFolder = Instance.new("Folder")
remFolder.Name   = "AutoOpRemotes"
remFolder.Parent = ReplicatedStorage

local function mkEv(name)
    local e = Instance.new("RemoteEvent")
    e.Name = name; e.Parent = remFolder; return e
end

local evtOpenPanel  = mkEv("AutoOpOpenPanel")
local evtStart      = mkEv("AutoOpStart")
local evtStop       = mkEv("AutoOpStop")
local evtStatus     = mkEv("AutoOpStatus")
local evtSpawnTrain = mkEv("AutoOpSpawnTrain")
local evtSetTime    = mkEv("AutoOpSetTime")
local evtStateSync  = mkEv("AutoOpStateSync")

-- 駅名リスト
local stListFolder = Instance.new("Folder")
stListFolder.Name   = "StationList"
stListFolder.Parent = remFolder
for i, st in ipairs(STATIONS) do
    local sv = Instance.new("StringValue")
    sv.Name   = tostring(i)
    sv.Value  = st.name
    sv.Parent = stListFolder
end

local trainCtrl  = nil
local trainQuery = nil

-- ============================================================
-- 列車位置取得
-- ============================================================
local function getTrainCenterZ(trackNum)
    local rwf = Workspace:FindFirstChild(RW_FOLDER)
    if not rwf then return nil end
    local model = rwf:FindFirstChild("Train_" .. trackNum)
    if not model then return nil end
    local sum, count = 0, 0
    for i = 1, 4 do
        local car   = model:FindFirstChild("Car" .. i)
        local floor = car and car:FindFirstChild("InteriorFloor")
        if floor and floor:IsA("BasePart") then
            sum += floor.Position.Z; count += 1
        end
    end
    return count > 0 and (sum / count) or nil
end

-- ============================================================
-- 自動運行コルーチン
-- ============================================================
local DWELL_TIME     = 6
local BRAKE_MARGIN   = 1.45
local DOOR_ANIM_WAIT = 2.1
local STOP_DIST      = 14
local SLOW_DIST      = 55
local SLOW_SPEED_THR = 8

local function autoOpCoroutine(trackNum, stationIndices)
    local ctrl  = trainCtrl
    local query = trainQuery
    if not ctrl or not query then return end

    if not query:Invoke(trackNum, "HasTrain") then
        ctrl:Fire(trackNum, "Build", nil)
        task.wait(3)
    end

    ctrl:Fire(trackNum, "SetDoor", false)
    task.wait(DOOR_ANIM_WAIT + 0.3)

    local routeLen   = #stationIndices
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
    evtStatus:FireAllClients(trackNum, "running", STATIONS[stationIndices[posInRoute]].name)

    while autoOpActive[trackNum] do
        local nextPos = goingForward and (posInRoute + 1) or (posInRoute - 1)
        if nextPos > routeLen then goingForward = false; nextPos = posInRoute - 1
        elseif nextPos < 1   then goingForward = true;  nextPos = posInRoute + 1 end
        if nextPos < 1 or nextPos > routeLen then break end

        local targetZ    = STATIONS[stationIndices[nextPos]].z
        local targetName = STATIONS[stationIndices[nextPos]].name

        evtStatus:FireAllClients(trackNum, "departing", targetName)
        trainZ = getTrainCenterZ(trackNum)
        if not trainZ then break end

        local moveDir = (targetZ > trainZ) and 1 or -1
        ctrl:Fire(trackNum, "SetDir", moveDir)
        ctrl:Fire(trackNum, "SetCtrl", "加速")

        local arrived = false
        while autoOpActive[trackNum] and not arrived do
            task.wait(0.1)
            trainZ = getTrainCenterZ(trackNum)
            if not trainZ then arrived = true; break end

            local dist = math.abs(targetZ - trainZ)
            local spd  = query:Invoke(trackNum, "Speed")

            local pastTarget = (moveDir == 1 and trainZ > targetZ + STOP_DIST)
                            or (moveDir == -1 and trainZ < targetZ - STOP_DIST)
            if pastTarget then
                ctrl:Fire(trackNum, "SetDir", 0)
                ctrl:Fire(trackNum, "SetCtrl", "急ブレーキ")
                task.wait(2)
                if not autoOpActive[trackNum] then break end
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
                        task.wait(1); arrived = true; break
                    end
                end
                break
            end

            local brakeDist = math.max(30, (spd * spd) / 86.4 * BRAKE_MARGIN)
            if dist < STOP_DIST and spd < SLOW_SPEED_THR then
                ctrl:Fire(trackNum, "SetDir", 0)
                ctrl:Fire(trackNum, "SetCtrl", "急ブレーキ")
                task.wait(1); arrived = true
            elseif dist <= brakeDist then
                ctrl:Fire(trackNum, "SetCtrl", "ブレーキ")
            else
                ctrl:Fire(trackNum, "SetCtrl", "加速")
            end
        end

        if not autoOpActive[trackNum] then break end

        posInRoute = nextPos
        ctrl:Fire(trackNum, "SetDir", 0)
        ctrl:Fire(trackNum, "SetCtrl", "加速停止")
        evtStatus:FireAllClients(trackNum, "arrived", targetName)
        ctrl:Fire(trackNum, "SetDoor", true)

        local tick = 0
        while autoOpActive[trackNum] and tick < DWELL_TIME * 10 do
            task.wait(0.1); tick += 1
        end
        if not autoOpActive[trackNum] then break end

        ctrl:Fire(trackNum, "SetDoor", false)
        task.wait(DOOR_ANIM_WAIT)

        if posInRoute >= routeLen then goingForward = false
        elseif posInRoute <= 1   then goingForward = true end
    end

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
        autoOpActive[trackNum] = false; task.wait(0.4)
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

evtStart.OnServerEvent:Connect(function(player, trackNum, startIdx, endIdx)
    if type(trackNum) ~= "number" then return end
    trackNum = math.clamp(math.floor(trackNum), 1, 4)
    if type(startIdx) ~= "number" or type(endIdx) ~= "number" then return end
    startIdx = math.clamp(math.floor(startIdx), 1, #STATIONS)
    endIdx   = math.clamp(math.floor(endIdx),   1, #STATIONS)
    if startIdx == endIdx then return end
    autoOpConfig[trackNum] = {startIdx = startIdx, endIdx = endIdx}
    startAutoOp(trackNum, startIdx, endIdx)
    task.defer(function() updateBillboard() end)
end)

evtStop.OnServerEvent:Connect(function(player, trackNum)
    if type(trackNum) ~= "number" then return end
    trackNum = math.clamp(math.floor(trackNum), 1, 4)
    stopAutoOp(trackNum)
    task.defer(function() updateBillboard() end)
end)

-- ============================================================
-- パネル生成
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

local TERM_X = 32
local TERM_Z = 4548
local GND_Y  = 0.5
local TERM_W = 4.4
local TERM_H = 2.5
local TERM_D = 7.0

local termModel = Instance.new("Model")
termModel.Name   = "ControlTerminal"
termModel.Parent = rwFolder

local termBody = mkP(termModel, "Body",
    Vector3.new(TERM_W, TERM_H, TERM_D),
    Vector3.new(TERM_X, GND_Y + TERM_H / 2, TERM_Z),
    Color3.fromRGB(14, 20, 48))

local termScreen = mkP(termModel, "Screen",
    Vector3.new(0.28, TERM_H * 0.78, TERM_D - 0.8),
    Vector3.new(TERM_X + TERM_W / 2 + 0.14, GND_Y + TERM_H * 0.56, TERM_Z),
    Color3.fromRGB(4, 10, 28))
termScreen.CanCollide = false

mkP(termModel, "NeonTop",
    Vector3.new(TERM_W + 0.1, 0.22, TERM_D + 0.1),
    Vector3.new(TERM_X, GND_Y + TERM_H + 0.11, TERM_Z),
    Color3.fromRGB(0, 100, 220), Enum.Material.Neon)

for _, dz in ipairs({-(TERM_D / 2 + 0.1), (TERM_D / 2 + 0.1)}) do
    mkP(termModel, "Pole" .. (dz < 0 and "L" or "R"),
        Vector3.new(0.2, TERM_H + 0.8, 0.2),
        Vector3.new(TERM_X - TERM_W / 2 - 0.1, GND_Y + (TERM_H + 0.8) / 2, TERM_Z + dz),
        Color3.fromRGB(0, 100, 220), Enum.Material.Neon)
end

local bbg = Instance.new("BillboardGui")
bbg.Size        = UDim2.fromOffset(340, 100)
bbg.StudsOffset = Vector3.new(2.8, 0, 0)
bbg.MaxDistance = 32
bbg.Parent      = termScreen

local ttl = Instance.new("TextLabel")
ttl.Size                   = UDim2.new(1, 0, 0.52, 0)
ttl.BackgroundTransparency = 1
ttl.Text                   = "列車管理パネル"
ttl.TextColor3             = Color3.fromRGB(100, 200, 255)
ttl.TextSize               = 26
ttl.Font                   = Enum.Font.GothamBold
ttl.Parent                 = bbg

local subLbl = Instance.new("TextLabel")
subLbl.Size                   = UDim2.new(1, 0, 0.48, 0)
subLbl.Position               = UDim2.new(0, 0, 0.52, 0)
subLbl.BackgroundTransparency = 1
subLbl.Text                   = "列車 0 / 4 稼働中  ［ E ］ で操作"
subLbl.TextColor3             = Color3.fromRGB(160, 210, 255)
subLbl.TextSize               = 16
subLbl.Font                   = Enum.Font.Gotham
subLbl.Parent                 = bbg

local pp = Instance.new("ProximityPrompt")
pp.ActionText            = "パネルを開く"
pp.ObjectText            = "列車管理"
pp.KeyboardKeyCode       = Enum.KeyCode.E
pp.MaxActivationDistance = 10
pp.RequiresLineOfSight   = false
pp.HoldDuration          = 0
pp.Parent                = termBody

pp.Triggered:Connect(function(player)
    evtOpenPanel:FireClient(player, autoOpActive, trainPresent, autoOpConfig)
end)

updateBillboard = function()
    local cnt = 0
    for t = 1, 4 do if trainPresent[t] then cnt += 1 end end
    subLbl.Text = string.format("列車 %d / 4 稼働中  ［ E ］ で操作", cnt)
end

print("[AutoOpManager] 操作パネルを設置しました。")

-- ============================================================
-- TrainStateChanged 購読
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
-- スポーン/格納リクエスト
-- ============================================================
evtSpawnTrain.OnServerEvent:Connect(function(player, trackNum, action)
    if type(trackNum) ~= "number" then return end
    trackNum = math.clamp(math.floor(trackNum), 1, 4)
    if action == "spawn" then
        if trainPresent[trackNum] then return end
        trainCtrl:Fire(trackNum, "Build", nil)
    elseif action == "store" then
        if not trainPresent[trackNum] then return end
        if autoOpActive[trackNum] then stopAutoOp(trackNum) end
        trainCtrl:Fire(trackNum, "Store", nil)
    end
    task.defer(function() updateBillboard() end)
end)

-- ============================================================
-- 時刻設定
-- ============================================================
local timeCtrl = ReplicatedStorage:WaitForChild("TimeControl", 15)

evtSetTime.OnServerEvent:Connect(function(_, periodId)
    if timeCtrl and type(periodId) == "string" then
        timeCtrl:Fire(periodId)
    end
end)
