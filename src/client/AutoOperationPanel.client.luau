-- 統合列車管理パネル（クライアント・4線独立制）

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local player = Players.LocalPlayer
local gui    = player:WaitForChild("PlayerGui")

local remFolder = ReplicatedStorage:WaitForChild("AutoOpRemotes", 20)
if not remFolder then return end

local evtOpen       = remFolder:WaitForChild("AutoOpOpenPanel")
local evtStart      = remFolder:WaitForChild("AutoOpStart")
local evtStop       = remFolder:WaitForChild("AutoOpStop")
local evtSpawnTrain = remFolder:WaitForChild("AutoOpSpawnTrain")
local evtSetTime    = remFolder:WaitForChild("AutoOpSetTime")
local evtStatus     = remFolder:WaitForChild("AutoOpStatus")
local evtStateSync  = remFolder:WaitForChild("AutoOpStateSync")
local stListFld     = remFolder:WaitForChild("StationList")

local carRem      = ReplicatedStorage:WaitForChild("CarRemotes", 20)
local evtCarSpawn = carRem and carRem:FindFirstChild("CarSpawn")
local evtCarStore = carRem and carRem:FindFirstChild("CarStore")
local evtCarState = carRem and carRem:FindFirstChild("CarState")

-- 駅リスト
local STATION_NAMES = {}
do
    local i = 1
    while stListFld:FindFirstChild(tostring(i)) do
        STATION_NAMES[i] = stListFld[tostring(i)].Value
        i += 1
    end
end

local TRACK_COLORS = {
    Color3.fromRGB(0,   82, 160),
    Color3.fromRGB(0,  150,  60),
    Color3.fromRGB(200,  90,   0),
    Color3.fromRGB(180,   0,   0),
}

local TIME_BTNS = {
    {id="dawn",    label="早朝",   color=Color3.fromRGB( 90, 70,120)},
    {id="morning", label="朝",     color=Color3.fromRGB(200,135, 45)},
    {id="noon",    label="昼",     color=Color3.fromRGB( 45,120,200)},
    {id="evening", label="夕方",   color=Color3.fromRGB(200, 80, 22)},
    {id="night",   label="夜",     color=Color3.fromRGB( 18, 18, 78)},
    {id="auto",    label="実時間", color=Color3.fromRGB( 35,105, 50)},
}

-- 状態
local trainPres  = {false, false, false, false}
local autoOn     = {false, false, false, false}
local selStart   = {}
local selEnd     = {}
local carPresent = false
local curTrack   = 1

for t = 1, 4 do
    selStart[t] = 1
    selEnd[t]   = #STATION_NAMES
end

-- パネル参照（グローバル、evtStateSync / evtStatus から更新する）
local panelGui         = nil
local statusLabel      = nil
local trackSpawnBtnRef = nil
local trackStoreBtnRef = nil
local trackStartBtnRef = nil
local trackStopBtnRef  = nil
local carSpawnBtnRef   = nil
local carStoreBtnRef   = nil

-- ============================================================
-- UI ヘルパー
-- ============================================================
local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = parent
end

local function mkFrame(parent, bg, props)
    local f = Instance.new("Frame")
    f.BackgroundColor3 = bg or Color3.fromRGB(0, 0, 0)
    f.BorderSizePixel  = 0
    if props then for k, v in pairs(props) do f[k] = v end end
    f.Parent = parent
    return f
end

local function mkLabel(parent, text, props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.BorderSizePixel        = 0
    l.Text                   = text
    if props then for k, v in pairs(props) do l[k] = v end end
    l.Parent = parent
    return l
end

local function mkBtn(parent, text, bg, props)
    local b = Instance.new("TextButton")
    b.BackgroundColor3 = bg
    b.BorderSizePixel  = 0
    b.AutoButtonColor  = false
    b.Text             = text
    b.TextColor3       = Color3.fromRGB(255, 255, 255)
    b.Font             = Enum.Font.GothamBold
    b.TextSize         = 15
    local r = 7
    if props then
        for k, v in pairs(props) do
            if k == "r" then r = v else b[k] = v end
        end
    end
    b.Parent = parent
    corner(b, r)
    return b
end

local function vLayout(parent, gap)
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Vertical
    l.SortOrder     = Enum.SortOrder.LayoutOrder
    l.Padding       = UDim.new(0, gap or 6)
    l.Parent        = parent
end

local function hLayout(parent, gap)
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Horizontal
    l.SortOrder     = Enum.SortOrder.LayoutOrder
    l.Padding       = UDim.new(0, gap or 6)
    l.Parent        = parent
end

local function secLabel(parent, text, order)
    return mkLabel(parent, text, {
        Size           = UDim2.new(1, 0, 0, 20),
        LayoutOrder    = order,
        TextColor3     = Color3.fromRGB(120, 158, 220),
        TextSize       = 13,
        Font           = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
end

local function divLine(parent, order)
    return mkFrame(parent, Color3.fromRGB(35, 50, 90),
        {Size = UDim2.new(1, 0, 0, 1), LayoutOrder = order})
end

-- ============================================================
-- 駅ピッカー
-- ============================================================
local function makeStationPicker(parent, getter, setter, order)
    local fr = mkFrame(parent, Color3.fromRGB(18, 26, 54),
        {Size = UDim2.new(1, 0, 0, 36), LayoutOrder = order})
    corner(fr, 7)

    local decBtn = mkBtn(fr, "◀", Color3.fromRGB(32, 44, 80),
        {Size = UDim2.fromOffset(36, 36), Position = UDim2.new(0, 0, 0, 0), TextSize = 17})
    local incBtn = mkBtn(fr, "▶", Color3.fromRGB(32, 44, 80),
        {Size = UDim2.fromOffset(36, 36), Position = UDim2.new(1, -36, 0, 0), TextSize = 17})
    local namLbl = mkLabel(fr, "",
        {Size       = UDim2.new(1, -80, 1, 0),
         Position   = UDim2.new(0, 40, 0, 0),
         TextColor3 = Color3.fromRGB(232, 242, 255),
         TextSize   = 15,
         Font       = Enum.Font.GothamBold})

    local function refresh()
        local i = getter()
        namLbl.Text = string.format("[%d/%d]  %s", i, #STATION_NAMES, STATION_NAMES[i] or "?")
    end
    refresh()

    decBtn.Activated:Connect(function() setter(math.max(1, getter() - 1)); refresh() end)
    incBtn.Activated:Connect(function() setter(math.min(#STATION_NAMES, getter() + 1)); refresh() end)

    for _, btn in ipairs({decBtn, incBtn}) do
        local delta = btn == decBtn and -1 or 1
        local down  = false
        btn.MouseButton1Down:Connect(function()
            down = true
            task.delay(0.45, function()
                while down do
                    setter(math.clamp(getter() + delta, 1, #STATION_NAMES))
                    refresh(); task.wait(0.07)
                end
            end)
        end)
        btn.MouseButton1Up:Connect(function()  down = false end)
        btn.MouseLeave:Connect(function()      down = false end)
    end
end

-- ============================================================
-- 閉じる
-- ============================================================
local function closePanel()
    if panelGui then panelGui:Destroy(); panelGui = nil end
    statusLabel      = nil
    trackSpawnBtnRef = nil
    trackStoreBtnRef = nil
    trackStartBtnRef = nil
    trackStopBtnRef  = nil
    carSpawnBtnRef   = nil
    carStoreBtnRef   = nil
end

-- ============================================================
-- パネル構築
-- ============================================================
local function buildPanel()
    closePanel()

    local screen = Instance.new("ScreenGui")
    screen.Name           = "UnifiedControlGui"
    screen.ResetOnSpawn   = false
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.Parent         = gui
    panelGui = screen

    -- オーバーレイ
    local ov = mkFrame(screen, Color3.fromRGB(0, 0, 0),
        {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.55})
    ov.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then closePanel() end
    end)

    -- メインウィンドウ
    local win = mkFrame(screen, Color3.fromRGB(12, 18, 40),
        {Size        = UDim2.fromOffset(480, 600),
         Position    = UDim2.fromScale(0.5, 0.5),
         AnchorPoint = Vector2.new(0.5, 0.5)})
    corner(win, 10)

    -- タイトルバー
    local titleBar = mkFrame(win, Color3.fromRGB(0, 75, 200),
        {Size = UDim2.new(1, 0, 0, 44)})
    corner(titleBar, 10)
    mkFrame(titleBar, Color3.fromRGB(0, 75, 200),
        {Size = UDim2.new(1, 0, 0.5, 0), Position = UDim2.new(0, 0, 0.5, 0)})
    mkLabel(titleBar, "列車管理パネル",
        {Size           = UDim2.new(1, -50, 1, 0), Position = UDim2.new(0, 14, 0, 0),
         TextColor3     = Color3.fromRGB(255, 255, 255), TextSize = 20,
         Font           = Enum.Font.GothamBold,
         TextXAlignment = Enum.TextXAlignment.Left})
    local xBtn = mkBtn(titleBar, "✕", Color3.fromRGB(195, 42, 42),
        {Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -38, 0, 5), TextSize = 15, r = 6})
    xBtn.Activated:Connect(closePanel)

    -- タブ行（線路選択・絶対配置で等幅4ボタン）
    local tabRow = mkFrame(win, Color3.fromRGB(8, 12, 28),
        {Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 0, 0, 44)})

    local tabBtns = {}
    for t = 1, 4 do
        local xPct = (t - 1) * 0.25
        local tb = mkBtn(tabRow, t .. "番線",
            (t == curTrack) and TRACK_COLORS[t] or Color3.fromRGB(22, 30, 55),
            {Size     = UDim2.new(0.25, -2, 1, -10),
             Position = UDim2.new(xPct, 1, 0, 5),
             TextSize = 14, r = 6})
        tabBtns[t] = tb
    end

    -- スクロールフレーム（タブの下から）
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size                   = UDim2.new(1, -10, 1, -94)
    scroll.Position               = UDim2.new(0, 5, 0, 94)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel        = 0
    scroll.ScrollBarThickness     = 5
    scroll.ScrollBarImageColor3   = Color3.fromRGB(70, 95, 160)
    scroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    scroll.Parent                 = win
    vLayout(scroll, 7)

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft   = UDim.new(0, 8)
    pad.PaddingRight  = UDim.new(0, 8)
    pad.PaddingTop    = UDim.new(0, 6)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent        = scroll

    local scrollLo = 0
    local function lo() scrollLo += 1; return scrollLo end

    -- トラックセクションコンテナ（switchTab が中身を入れ替える）
    local trackContainer = mkFrame(scroll, Color3.fromRGB(0, 0, 0), {
        BackgroundTransparency = 1,
        Size          = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder   = lo()
    })

    divLine(scroll, lo())

    -- ── 自動車セクション ──────────────────────────────────────
    secLabel(scroll, "■ 自動車", lo())

    local carRow = mkFrame(scroll, Color3.fromRGB(0, 0, 0),
        {Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = lo()})
    hLayout(carRow, 8)

    local function carActiveBg()   return carPresent and Color3.fromRGB(40,48,72)  or Color3.fromRGB(0,100,50) end
    local function carActiveTxt()  return carPresent and Color3.fromRGB(90,100,125) or Color3.fromRGB(255,255,255) end
    local function carStoreBg()    return carPresent and Color3.fromRGB(155,32,32) or Color3.fromRGB(40,48,72) end
    local function carStoreTxt()   return carPresent and Color3.fromRGB(255,255,255) or Color3.fromRGB(90,100,125) end

    local spawnCarBtn = mkBtn(carRow, "車をスポーン", carActiveBg(),
        {Size = UDim2.new(0.5, -4, 1, 0), TextColor3 = carActiveTxt()})
    local storeCarBtn = mkBtn(carRow, "車を格納",     carStoreBg(),
        {Size = UDim2.new(0.5, -4, 1, 0), TextColor3 = carStoreTxt()})

    carSpawnBtnRef = spawnCarBtn
    carStoreBtnRef = storeCarBtn

    spawnCarBtn.Activated:Connect(function()
        if carPresent then return end
        if evtCarSpawn then evtCarSpawn:FireServer() end
        if statusLabel then
            statusLabel.Text      = "車のスポーンを要求しました..."
            statusLabel.TextColor3 = Color3.fromRGB(100, 210, 130)
        end
    end)
    storeCarBtn.Activated:Connect(function()
        if not carPresent then return end
        if evtCarStore then evtCarStore:FireServer() end
        if statusLabel then
            statusLabel.Text      = "車を格納しました"
            statusLabel.TextColor3 = Color3.fromRGB(255, 195, 60)
        end
    end)

    divLine(scroll, lo())

    -- ── 時刻設定 ──────────────────────────────────────────────
    secLabel(scroll, "■ 時刻設定", lo())

    local timeRow = mkFrame(scroll, Color3.fromRGB(0, 0, 0),
        {Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, LayoutOrder = lo()})
    hLayout(timeRow, 4)

    for _, tb in ipairs(TIME_BTNS) do
        local tbtn = mkBtn(timeRow, tb.label, tb.color,
            {Size = UDim2.new(1 / #TIME_BTNS, -4, 1, 0), TextSize = 13, r = 6})
        local cid = tb.id
        tbtn.Activated:Connect(function()
            evtSetTime:FireServer(cid)
            if statusLabel then
                statusLabel.Text      = "時刻を「" .. tb.label .. "」に設定しました"
                statusLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
            end
        end)
    end

    -- ステータスライン
    local sLbl = mkLabel(scroll, "", {
        Size           = UDim2.new(1, 0, 0, 22),
        LayoutOrder    = lo(),
        TextColor3     = Color3.fromRGB(100, 210, 130),
        TextSize       = 13,
        Font           = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    statusLabel = sLbl

    -- ── トラックセクション切替 ────────────────────────────────
    local trackConns = {}

    local function switchTab(t)
        for _, c in ipairs(trackConns) do c:Disconnect() end
        trackConns = {}
        trackSpawnBtnRef = nil
        trackStoreBtnRef = nil
        trackStartBtnRef = nil
        trackStopBtnRef  = nil

        curTrack = t

        for i, btn in ipairs(tabBtns) do
            btn.BackgroundColor3 = (i == t) and TRACK_COLORS[i] or Color3.fromRGB(22, 30, 55)
        end

        for _, c in ipairs(trackContainer:GetChildren()) do c:Destroy() end
        vLayout(trackContainer, 6)

        local tOrd = 0
        local function tlo() tOrd += 1; return tOrd end

        local pres = trainPres[t]
        local aon  = autoOn[t]

        -- 列車セクション
        secLabel(trackContainer, "■ 列車（" .. t .. "番線）", tlo())

        local trainRow = mkFrame(trackContainer, Color3.fromRGB(0, 0, 0),
            {Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = tlo()})
        hLayout(trainRow, 8)

        local spawnBtn = mkBtn(trainRow, "列車をスポーン",
            pres and Color3.fromRGB(40,48,72) or Color3.fromRGB(0,120,60),
            {Size      = UDim2.new(0.5, -4, 1, 0),
             TextColor3 = pres and Color3.fromRGB(90,100,125) or Color3.fromRGB(255,255,255)})
        local storeBtn = mkBtn(trainRow, "列車を格納",
            pres and Color3.fromRGB(155,32,32) or Color3.fromRGB(40,48,72),
            {Size      = UDim2.new(0.5, -4, 1, 0),
             TextColor3 = pres and Color3.fromRGB(255,255,255) or Color3.fromRGB(90,100,125)})

        trackSpawnBtnRef = spawnBtn
        trackStoreBtnRef = storeBtn

        table.insert(trackConns, spawnBtn.Activated:Connect(function()
            if trainPres[t] then return end
            evtSpawnTrain:FireServer(t, "spawn")
            if statusLabel then
                statusLabel.Text      = t .. "番線の列車をスポーンします..."
                statusLabel.TextColor3 = Color3.fromRGB(100, 210, 130)
            end
        end))
        table.insert(trackConns, storeBtn.Activated:Connect(function()
            if not trainPres[t] then return end
            evtSpawnTrain:FireServer(t, "store")
            if statusLabel then
                statusLabel.Text      = t .. "番線の列車を格納します"
                statusLabel.TextColor3 = Color3.fromRGB(255, 195, 60)
            end
        end))

        -- 自動運行セクション
        secLabel(trackContainer, "■ 自動運行", tlo())

        local aoRow = mkFrame(trackContainer, Color3.fromRGB(0, 0, 0),
            {Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, LayoutOrder = tlo()})
        hLayout(aoRow, 8)

        local startBtn = mkBtn(aoRow, "▶  自動運行 開始",
            aon and Color3.fromRGB(40,48,72) or Color3.fromRGB(0,125,55),
            {Size = UDim2.new(0.57, -4, 1, 0), TextSize = 14,
             TextColor3 = aon and Color3.fromRGB(90,100,125) or Color3.fromRGB(255,255,255)})
        local stopBtn = mkBtn(aoRow, "■  停止",
            aon and Color3.fromRGB(155,24,24) or Color3.fromRGB(40,48,72),
            {Size = UDim2.new(0.43, -4, 1, 0), TextSize = 14,
             TextColor3 = aon and Color3.fromRGB(255,255,255) or Color3.fromRGB(90,100,125)})

        trackStartBtnRef = startBtn
        trackStopBtnRef  = stopBtn

        secLabel(trackContainer, "始発駅", tlo())
        makeStationPicker(trackContainer,
            function() return selStart[t] end,
            function(v) selStart[t] = v end,
            tlo())

        secLabel(trackContainer, "終着駅", tlo())
        makeStationPicker(trackContainer,
            function() return selEnd[t] end,
            function(v) selEnd[t] = v end,
            tlo())

        table.insert(trackConns, startBtn.Activated:Connect(function()
            if autoOn[t] then
                if statusLabel then
                    statusLabel.Text      = t .. "番線はすでに自動運行中です"
                    statusLabel.TextColor3 = Color3.fromRGB(255, 90, 70)
                end
                return
            end
            if not trainPres[t] then
                if statusLabel then
                    statusLabel.Text      = "先に" .. t .. "番線の列車をスポーンしてください"
                    statusLabel.TextColor3 = Color3.fromRGB(255, 90, 70)
                end
                return
            end
            if selStart[t] == selEnd[t] then
                if statusLabel then
                    statusLabel.Text      = "始発駅と終着駅に同じ駅は選べません"
                    statusLabel.TextColor3 = Color3.fromRGB(255, 90, 70)
                end
                return
            end
            evtStart:FireServer(t, selStart[t], selEnd[t])
            if statusLabel then
                statusLabel.Text = t .. "番線 自動運行開始（"
                    .. STATION_NAMES[selStart[t]] .. "〜" .. STATION_NAMES[selEnd[t]] .. "）"
                statusLabel.TextColor3 = Color3.fromRGB(100, 210, 130)
            end
        end))

        table.insert(trackConns, stopBtn.Activated:Connect(function()
            evtStop:FireServer(t)
            if statusLabel then
                statusLabel.Text      = t .. "番線の自動運行を停止します"
                statusLabel.TextColor3 = Color3.fromRGB(255, 195, 60)
            end
        end))
    end

    -- タブクリック
    for t = 1, 4 do
        local tab = t
        tabBtns[t].Activated:Connect(function()
            if curTrack ~= tab then switchTab(tab) end
        end)
    end

    -- Escape で閉じる
    local escConn
    escConn = UserInputService.InputBegan:Connect(function(inp, handled)
        if not handled and inp.KeyCode == Enum.KeyCode.Escape then
            escConn:Disconnect(); closePanel()
        end
    end)

    screen.Destroying:Connect(function()
        if escConn then escConn:Disconnect(); escConn = nil end
        for _, c in ipairs(trackConns) do c:Disconnect() end
        trackConns = {}
        trackSpawnBtnRef = nil
        trackStoreBtnRef = nil
        trackStartBtnRef = nil
        trackStopBtnRef  = nil
        carSpawnBtnRef   = nil
        carStoreBtnRef   = nil
        statusLabel      = nil
    end)

    -- 初期タブ表示
    switchTab(curTrack)
end

-- ============================================================
-- グローバルイベントハンドラ
-- ============================================================
evtOpen.OnClientEvent:Connect(function(statuses, initTrainPresent, initConfigs)
    for t = 1, 4 do
        trainPres[t] = initTrainPresent and initTrainPresent[t] or false
        autoOn[t]    = statuses and statuses[t] or false
        if initConfigs and initConfigs[t] then
            if initConfigs[t].startIdx then selStart[t] = initConfigs[t].startIdx end
            if initConfigs[t].endIdx   then selEnd[t]   = initConfigs[t].endIdx   end
        end
    end
    buildPanel()
end)

evtStateSync.OnClientEvent:Connect(function(trackNum, hasTrain)
    trainPres[trackNum] = hasTrain
    if trackNum ~= curTrack then return end
    local pres = hasTrain
    if trackSpawnBtnRef then
        trackSpawnBtnRef.BackgroundColor3 = pres and Color3.fromRGB(40,48,72)  or Color3.fromRGB(0,120,60)
        trackSpawnBtnRef.TextColor3       = pres and Color3.fromRGB(90,100,125) or Color3.fromRGB(255,255,255)
    end
    if trackStoreBtnRef then
        trackStoreBtnRef.BackgroundColor3 = pres and Color3.fromRGB(155,32,32) or Color3.fromRGB(40,48,72)
        trackStoreBtnRef.TextColor3       = pres and Color3.fromRGB(255,255,255) or Color3.fromRGB(90,100,125)
    end
end)

evtStatus.OnClientEvent:Connect(function(trackNum, state, stationName)
    if state == "stopped" then
        autoOn[trackNum] = false
    elseif state == "running" or state == "departing" or state == "arrived" then
        autoOn[trackNum] = true
    end
    if trackNum == curTrack then
        local aon = autoOn[trackNum]
        if trackStartBtnRef then
            trackStartBtnRef.BackgroundColor3 = aon and Color3.fromRGB(40,48,72)   or Color3.fromRGB(0,125,55)
            trackStartBtnRef.TextColor3       = aon and Color3.fromRGB(90,100,125) or Color3.fromRGB(255,255,255)
        end
        if trackStopBtnRef then
            trackStopBtnRef.BackgroundColor3 = aon and Color3.fromRGB(155,24,24) or Color3.fromRGB(40,48,72)
            trackStopBtnRef.TextColor3       = aon and Color3.fromRGB(255,255,255) or Color3.fromRGB(90,100,125)
        end
    end
    if statusLabel then
        local msgs = {
            departing = string.format("%d番線 → %s に向け出発", trackNum, stationName),
            arrived   = string.format("%d番線 → %s に到着（乗降中）", trackNum, stationName),
            stopped   = string.format("%d番線: 自動運行を終了しました", trackNum),
            running   = string.format("%d番線: 自動運行中", trackNum),
        }
        statusLabel.Text      = msgs[state] or ""
        statusLabel.TextColor3 = state == "stopped"
            and Color3.fromRGB(255, 195, 60) or Color3.fromRGB(100, 210, 130)
    end
end)

if evtCarState then
    evtCarState.OnClientEvent:Connect(function(state)
        carPresent = state
        if carSpawnBtnRef then
            carSpawnBtnRef.BackgroundColor3 = carPresent and Color3.fromRGB(40,48,72)   or Color3.fromRGB(0,100,50)
            carSpawnBtnRef.TextColor3       = carPresent and Color3.fromRGB(90,100,125) or Color3.fromRGB(255,255,255)
        end
        if carStoreBtnRef then
            carStoreBtnRef.BackgroundColor3 = carPresent and Color3.fromRGB(155,32,32) or Color3.fromRGB(40,48,72)
            carStoreBtnRef.TextColor3       = carPresent and Color3.fromRGB(255,255,255) or Color3.fromRGB(90,100,125)
        end
    end)
end
