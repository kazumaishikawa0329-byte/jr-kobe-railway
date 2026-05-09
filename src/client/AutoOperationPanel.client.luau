-- 統合列車管理パネル（クライアント・1プレイヤー1台制）

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
local evtTrackOwned = remFolder:WaitForChild("AutoOpTrackOwned")
local stListFld     = remFolder:WaitForChild("StationList")

-- 駅リスト構築
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

-- プレイヤー状態
local myTrack     = nil    -- 所有トラック番号（nil or 1〜4）
local myAutoOn    = false
local myTrainPres = false
local selStart    = 1
local selEnd      = #STATION_NAMES

local panelGui    = nil
local statusLabel = nil

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

local function secLabel(scroll, text, order)
    return mkLabel(scroll, text, {
        Size           = UDim2.new(1, 0, 0, 20),
        LayoutOrder    = order,
        TextColor3     = Color3.fromRGB(120, 158, 220),
        TextSize       = 13,
        Font           = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
end

local function divLine(scroll, order)
    return mkFrame(scroll, Color3.fromRGB(35, 50, 90),
        {Size = UDim2.new(1, 0, 0, 1), LayoutOrder = order})
end

-- ============================================================
-- 閉じる
-- ============================================================
local function closePanel()
    if panelGui then panelGui:Destroy(); panelGui = nil end
    statusLabel = nil
end

-- ============================================================
-- 駅ピッカー（◀ 駅名 ▶、長押し高速送り）
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
        {Size     = UDim2.new(1, -80, 1, 0), Position  = UDim2.new(0, 40, 0, 0),
         TextColor3 = Color3.fromRGB(232, 242, 255), TextSize = 15, Font = Enum.Font.GothamBold})

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
        btn.MouseButton1Up:Connect(function() down = false end)
        btn.MouseLeave:Connect(function()     down = false end)
    end

    return refresh
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

    -- 半透明オーバーレイ
    local ov = mkFrame(screen, Color3.fromRGB(0, 0, 0),
        {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.55})
    ov.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then closePanel() end
    end)

    -- メインウィンドウ
    local win = mkFrame(screen, Color3.fromRGB(12, 18, 40),
        {Size      = UDim2.fromOffset(480, 520),
         Position  = UDim2.fromScale(0.5, 0.5),
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

    -- スクロールフレーム
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size                 = UDim2.new(1, -10, 1, -52)
    scroll.Position             = UDim2.new(0, 5, 0, 48)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel      = 0
    scroll.ScrollBarThickness   = 5
    scroll.ScrollBarImageColor3 = Color3.fromRGB(70, 95, 160)
    scroll.CanvasSize           = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize  = Enum.AutomaticSize.Y
    scroll.Parent               = win
    vLayout(scroll, 7)

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft   = UDim.new(0, 8)
    pad.PaddingRight  = UDim.new(0, 8)
    pad.PaddingTop    = UDim.new(0, 6)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent        = scroll

    local order = 0
    local function lo() order += 1; return order end

    -- ── 自分の列車 ───────────────────────────────────────────────
    secLabel(scroll, "■ 自分の列車", lo())

    local trainInfoRow = mkFrame(scroll, Color3.fromRGB(0, 0, 0),
        {Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = lo()})
    hLayout(trainInfoRow, 8)

    local spawnBtn = mkBtn(trainInfoRow, "列車をスポーン",
        myTrainPres and Color3.fromRGB(40, 48, 72) or Color3.fromRGB(0, 120, 60),
        {Size      = UDim2.new(0.5, -4, 1, 0),
         TextColor3 = myTrainPres and Color3.fromRGB(90, 100, 125) or Color3.fromRGB(255, 255, 255)})

    local storeBtn = mkBtn(trainInfoRow, "列車を格納",
        myTrainPres and Color3.fromRGB(155, 32, 32) or Color3.fromRGB(40, 48, 72),
        {Size      = UDim2.new(0.5, -4, 1, 0),
         TextColor3 = myTrainPres and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(90, 100, 125)})

    -- 列車状態テキスト
    local function trainStateText()
        if not myTrainPres then return "状態: ○ 列車なし（空き線路を自動割り当て）" end
        local trackColor = myTrack and TRACK_COLORS[myTrack] or Color3.fromRGB(200, 200, 200)
        local trackStr   = myTrack and (myTrack .. "番線") or "?"
        if myAutoOn then return "状態: ● " .. trackStr .. " で自動運行中"
        else             return "状態: ● " .. trackStr .. " でスポーン中（待機）" end
    end

    local trainStateLbl = mkLabel(scroll, trainStateText(), {
        Size           = UDim2.new(1, 0, 0, 18),
        LayoutOrder    = lo(),
        TextColor3     = myTrainPres and Color3.fromRGB(100, 225, 135) or Color3.fromRGB(155, 165, 195),
        TextSize       = 13,
        Font           = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local function refreshTrainState()
        trainStateLbl.Text = trainStateText()
        trainStateLbl.TextColor3 = myTrainPres
            and Color3.fromRGB(100, 225, 135) or Color3.fromRGB(155, 165, 195)
        spawnBtn.BackgroundColor3 = myTrainPres and Color3.fromRGB(40,48,72) or Color3.fromRGB(0,120,60)
        spawnBtn.TextColor3 = myTrainPres and Color3.fromRGB(90,100,125) or Color3.fromRGB(255,255,255)
        storeBtn.BackgroundColor3 = myTrainPres and Color3.fromRGB(155,32,32) or Color3.fromRGB(40,48,72)
        storeBtn.TextColor3 = myTrainPres and Color3.fromRGB(255,255,255) or Color3.fromRGB(90,100,125)
    end

    spawnBtn.Activated:Connect(function()
        if myTrainPres then return end
        evtSpawnTrain:FireServer("spawn")
        if statusLabel then
            statusLabel.Text      = "列車のスポーンを要求しました..."
            statusLabel.TextColor3 = Color3.fromRGB(100, 210, 130)
        end
    end)

    storeBtn.Activated:Connect(function()
        if not myTrainPres then return end
        evtSpawnTrain:FireServer("store")
        if statusLabel then
            statusLabel.Text      = "列車の格納を要求しました"
            statusLabel.TextColor3 = Color3.fromRGB(255, 195, 60)
        end
    end)

    divLine(scroll, lo())

    -- ── 自動運行設定 ─────────────────────────────────────────────
    secLabel(scroll, "■ 自動運行設定", lo())

    local aoRow = mkFrame(scroll, Color3.fromRGB(0, 0, 0),
        {Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, LayoutOrder = lo()})
    hLayout(aoRow, 8)

    local function startColor()  return myAutoOn and Color3.fromRGB(40,48,72) or Color3.fromRGB(0,125,55) end
    local function startTxtCol() return myAutoOn and Color3.fromRGB(90,100,125) or Color3.fromRGB(255,255,255) end
    local function stopColor()   return myAutoOn and Color3.fromRGB(155,24,24) or Color3.fromRGB(40,48,72) end
    local function stopTxtCol()  return myAutoOn and Color3.fromRGB(255,255,255) or Color3.fromRGB(90,100,125) end

    local startBtn = mkBtn(aoRow, "▶  自動運行 開始", startColor(),
        {Size = UDim2.new(0.57, -4, 1, 0), TextSize = 14, TextColor3 = startTxtCol()})
    local stopBtn  = mkBtn(aoRow, "■  停止",          stopColor(),
        {Size = UDim2.new(0.43, -4, 1, 0), TextSize = 14, TextColor3 = stopTxtCol()})

    local function refreshAutoBtn()
        startBtn.BackgroundColor3 = startColor()
        startBtn.TextColor3       = startTxtCol()
        stopBtn.BackgroundColor3  = stopColor()
        stopBtn.TextColor3        = stopTxtCol()
    end

    -- 始発駅
    secLabel(scroll, "始発駅", lo())
    makeStationPicker(scroll,
        function() return selStart end,
        function(v) selStart = v end,
        lo())

    -- 終着駅
    secLabel(scroll, "終着駅", lo())
    makeStationPicker(scroll,
        function() return selEnd end,
        function(v) selEnd = v end,
        lo())

    startBtn.Activated:Connect(function()
        if myAutoOn or not myTrainPres then
            if statusLabel then
                statusLabel.Text      = myTrainPres and "すでに自動運行中です" or "先に列車をスポーンしてください"
                statusLabel.TextColor3 = Color3.fromRGB(255, 90, 70)
            end
            return
        end
        if selStart == selEnd then
            if statusLabel then
                statusLabel.Text      = "始発駅と終着駅に同じ駅は選べません"
                statusLabel.TextColor3 = Color3.fromRGB(255, 90, 70)
            end
            return
        end
        evtStart:FireServer(selStart, selEnd)
        if statusLabel then
            statusLabel.Text = "自動運行を開始します（"
                .. STATION_NAMES[selStart] .. "〜" .. STATION_NAMES[selEnd] .. "）"
            statusLabel.TextColor3 = Color3.fromRGB(100, 210, 130)
        end
    end)

    stopBtn.Activated:Connect(function()
        evtStop:FireServer()
        if statusLabel then
            statusLabel.Text      = "自動運行を停止します"
            statusLabel.TextColor3 = Color3.fromRGB(255, 195, 60)
        end
    end)

    divLine(scroll, lo())

    -- ── 時刻設定 ─────────────────────────────────────────────────
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

    -- Escape で閉じる
    local escConn
    escConn = UserInputService.InputBegan:Connect(function(inp, handled)
        if not handled and inp.KeyCode == Enum.KeyCode.Escape then
            escConn:Disconnect(); closePanel()
        end
    end)

    -- evtTrackOwned を受け取ったら UI を更新
    local ownedConn
    ownedConn = evtTrackOwned.OnClientEvent:Connect(function(trackNum, result)
        myTrack     = trackNum
        myTrainPres = trackNum ~= nil
        refreshTrainState()
        if result == "full" and statusLabel then
            statusLabel.Text      = "空き線路がありません（他のプレイヤーが使用中）"
            statusLabel.TextColor3 = Color3.fromRGB(255, 90, 70)
        end
    end)

    -- パネルが破棄されたらコネクション解除
    screen.Destroying:Connect(function()
        if ownedConn then ownedConn:Disconnect() end
    end)

    -- evtStatus を受け取ったら自動運行状態を更新
    local statusConn
    statusConn = evtStatus.OnClientEvent:Connect(function(trackNum, state, stationName)
        if trackNum ~= myTrack then return end
        if state == "stopped" then
            myAutoOn = false
        elseif state == "running" or state == "departing" or state == "arrived" then
            myAutoOn = true
        end
        refreshAutoBtn()
        local msgs = {
            departing = string.format("%d番線 → %s に向け出発", trackNum, stationName),
            arrived   = string.format("%d番線 → %s に到着（乗降中）", trackNum, stationName),
            stopped   = string.format("%d番線: 自動運行を終了しました", trackNum),
            running   = string.format("%d番線: 自動運行中", trackNum),
        }
        if statusLabel then
            statusLabel.Text      = msgs[state] or ""
            statusLabel.TextColor3 = state == "stopped"
                and Color3.fromRGB(255, 195, 60) or Color3.fromRGB(100, 210, 130)
        end
    end)

    screen.Destroying:Connect(function()
        if statusConn then statusConn:Disconnect() end
    end)
end

-- ============================================================
-- イベント受信
-- ============================================================
evtOpen.OnClientEvent:Connect(function(statuses, playerTrack, initTrainPresent, initConfigs)
    myTrack     = playerTrack
    myTrainPres = playerTrack ~= nil and (initTrainPresent and initTrainPresent[playerTrack] or false)
    myAutoOn    = playerTrack ~= nil and (statuses and statuses[playerTrack] or false)
    if playerTrack and initConfigs and initConfigs[playerTrack] then
        local cfg = initConfigs[playerTrack]
        if cfg.startIdx then selStart = cfg.startIdx end
        if cfg.endIdx   then selEnd   = cfg.endIdx   end
    end
    buildPanel()
end)

evtStateSync.OnClientEvent:Connect(function(trackNum, hasTrain)
    if trackNum == myTrack then
        myTrainPres = hasTrain
    end
end)

evtTrackOwned.OnClientEvent:Connect(function(trackNum, result)
    myTrack     = trackNum
    myTrainPres = trackNum ~= nil
end)
