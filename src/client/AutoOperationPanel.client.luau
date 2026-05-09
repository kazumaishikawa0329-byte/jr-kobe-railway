-- 統合列車管理パネル（クライアント）

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

-- 駅リスト構築
local STATION_NAMES = {}
do
    local i = 1
    while stListFld:FindFirstChild(tostring(i)) do
        table.insert(STATION_NAMES, stListFld[tostring(i)].Value)
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
    {id="dawn",    label="早朝",  color=Color3.fromRGB( 90, 70,120)},
    {id="morning", label="朝",    color=Color3.fromRGB(200,135, 45)},
    {id="noon",    label="昼",    color=Color3.fromRGB( 45,120,200)},
    {id="evening", label="夕方",  color=Color3.fromRGB(200, 80, 22)},
    {id="night",   label="夜",    color=Color3.fromRGB( 18, 18, 78)},
    {id="auto",    label="実時間",color=Color3.fromRGB( 35,105, 50)},
}

-- 選択状態（画面をまたいで保持）
local selTrack    = 1
local selStartIdx = {1, 1, 1, 1}
local selEndIdx   = {#STATION_NAMES, #STATION_NAMES, #STATION_NAMES, #STATION_NAMES}

-- サーバー状態キャッシュ
local trainPresent = {false, false, false, false}
local autoOpActive = {false, false, false, false}

local panelGui   = nil
local statusLabel = nil

-- ============================================================
-- UI ヘルパー（CornerRadius は UICorner 経由で設定）
-- ============================================================
local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = parent
    return c
end

local function mkFrame(parent, bg, props)
    local f = Instance.new("Frame")
    f.BackgroundColor3 = bg or Color3.fromRGB(0,0,0)
    f.BorderSizePixel  = 0
    if props then for k,v in pairs(props) do f[k]=v end end
    f.Parent = parent
    return f
end

local function mkLabel(parent, text, props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.BorderSizePixel        = 0
    l.Text                   = text
    if props then for k,v in pairs(props) do l[k]=v end end
    l.Parent = parent
    return l
end

local function mkBtn(parent, text, bg, props)
    local b = Instance.new("TextButton")
    b.BackgroundColor3 = bg
    b.BorderSizePixel  = 0
    b.AutoButtonColor  = false
    b.Text             = text
    b.TextColor3       = Color3.fromRGB(255,255,255)
    b.Font             = Enum.Font.GothamBold
    b.TextSize         = 15
    if props then for k,v in pairs(props) do b[k]=v end end
    b.Parent = parent
    corner(b, props and props.r or 7)
    return b
end

local function hLayout(parent, gap)
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Horizontal
    l.SortOrder     = Enum.SortOrder.LayoutOrder
    l.Padding       = UDim.new(0, gap or 6)
    l.Parent        = parent
    return l
end

local function vLayout(parent, gap)
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Vertical
    l.SortOrder     = Enum.SortOrder.LayoutOrder
    l.Padding       = UDim.new(0, gap or 6)
    l.Parent        = parent
    return l
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
local function makeStationPicker(parent, getter, setter)
    local fr = mkFrame(parent, Color3.fromRGB(18, 26, 54),
        {Size = UDim2.new(1,0, 0,36), LayoutOrder = 99})
    corner(fr, 7)

    local decBtn = mkBtn(fr, "◀", Color3.fromRGB(32,44,80),
        {Size=UDim2.fromOffset(36,36), Position=UDim2.new(0,0,0,0), TextSize=17})
    local incBtn = mkBtn(fr, "▶", Color3.fromRGB(32,44,80),
        {Size=UDim2.fromOffset(36,36), Position=UDim2.new(1,-36,0,0), TextSize=17})
    local namLbl = mkLabel(fr, "",
        {Size=UDim2.new(1,-80,1,0), Position=UDim2.new(0,40,0,0),
         TextColor3=Color3.fromRGB(232,242,255), TextSize=15, Font=Enum.Font.GothamBold})

    local function refresh()
        local i = getter()
        namLbl.Text = string.format("[%d/%d]  %s", i, #STATION_NAMES, STATION_NAMES[i] or "?")
    end
    refresh()

    decBtn.Activated:Connect(function() setter(math.max(1, getter()-1)); refresh() end)
    incBtn.Activated:Connect(function() setter(math.min(#STATION_NAMES, getter()+1)); refresh() end)

    for _, btn in ipairs({decBtn, incBtn}) do
        local delta = btn == decBtn and -1 or 1
        local down  = false
        btn.MouseButton1Down:Connect(function()
            down = true
            task.delay(0.45, function()
                while down do
                    setter(math.clamp(getter()+delta, 1, #STATION_NAMES))
                    refresh(); task.wait(0.07)
                end
            end)
        end)
        btn.MouseButton1Up:Connect(function()   down = false end)
        btn.MouseLeave:Connect(function()        down = false end)
    end

    return refresh
end

-- ============================================================
-- パネル構築
-- ============================================================
local function buildPanel(statuses, initialTrack, initTrainPresent, initConfigs)
    closePanel()

    -- 状態反映
    if type(initialTrack) == "number" and initialTrack >= 1 and initialTrack <= 4 then
        selTrack = initialTrack
    end
    for t = 1, 4 do
        autoOpActive[t]  = statuses          and statuses[t]          or false
        trainPresent[t]  = initTrainPresent  and initTrainPresent[t]  or false
        if initConfigs and initConfigs[t] then
            if initConfigs[t].startIdx then selStartIdx[t] = initConfigs[t].startIdx end
            if initConfigs[t].endIdx   then selEndIdx[t]   = initConfigs[t].endIdx   end
        end
    end

    -- ScreenGui
    local screen = Instance.new("ScreenGui")
    screen.Name           = "UnifiedControlGui"
    screen.ResetOnSpawn   = false
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.Parent         = gui
    panelGui = screen

    -- 半透明オーバーレイ
    local ov = mkFrame(screen, Color3.fromRGB(0,0,0),
        {Size=UDim2.fromScale(1,1), BackgroundTransparency=0.55})
    ov.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then closePanel() end
    end)

    -- メインウィンドウ
    local win = mkFrame(screen, Color3.fromRGB(12,18,40),
        {Size=UDim2.fromOffset(500,510),
         Position=UDim2.fromScale(0.5,0.5),
         AnchorPoint=Vector2.new(0.5,0.5)})
    corner(win, 10)

    -- タイトルバー
    local titleBar = mkFrame(win, Color3.fromRGB(0,75,200),
        {Size=UDim2.new(1,0,0,44)})
    corner(titleBar, 10)
    mkFrame(titleBar, Color3.fromRGB(0,75,200),  -- 角丸下消し
        {Size=UDim2.new(1,0,0.5,0), Position=UDim2.new(0,0,0.5,0)})
    mkLabel(titleBar, "列車管理パネル",
        {Size=UDim2.new(1,-50,1,0), Position=UDim2.new(0,14,0,0),
         TextColor3=Color3.fromRGB(255,255,255), TextSize=20,
         Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left})
    local xBtn = mkBtn(titleBar, "✕", Color3.fromRGB(195,42,42),
        {Size=UDim2.fromOffset(34,34), Position=UDim2.new(1,-38,0,5), TextSize=15, r=6})
    xBtn.Activated:Connect(closePanel)

    -- スクロールフレーム（コンテンツ）
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size                  = UDim2.new(1,-10, 1,-52)
    scroll.Position              = UDim2.new(0,5, 0,48)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel       = 0
    scroll.ScrollBarThickness    = 5
    scroll.ScrollBarImageColor3  = Color3.fromRGB(70,95,160)
    scroll.CanvasSize            = UDim2.new(0,0, 0,0)
    scroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
    scroll.Parent                = win

    vLayout(scroll, 7)
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft   = UDim.new(0,8)
    pad.PaddingRight  = UDim.new(0,8)
    pad.PaddingTop    = UDim.new(0,6)
    pad.PaddingBottom = UDim.new(0,8)
    pad.Parent        = scroll

    local orderIdx = 0
    local function lo() orderIdx += 1; return orderIdx end

    local function secLbl(text)
        return mkLabel(scroll, text, {
            Size=UDim2.new(1,0,0,20), LayoutOrder=lo(),
            TextColor3=Color3.fromRGB(120,158,220), TextSize=13,
            Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left})
    end
    local function divLine()
        return mkFrame(scroll, Color3.fromRGB(35,50,90),
            {Size=UDim2.new(1,0,0,1), LayoutOrder=lo()})
    end

    -- ── 番線タブ ────────────────────────────────────────────────
    local tabRow = mkFrame(scroll, Color3.fromRGB(0,0,0),
        {Size=UDim2.new(1,0,0,42), BackgroundTransparency=1, LayoutOrder=lo()})
    hLayout(tabRow, 5)

    local trackBtns = {}

    -- ── 番線別コンテンツ（タブ切替で再構築）───────────────────
    local dynSection = mkFrame(scroll, Color3.fromRGB(0,0,0),
        {Size=UDim2.new(1,0,0,0), BackgroundTransparency=1,
         AutomaticSize=Enum.AutomaticSize.Y, LayoutOrder=lo()})
    vLayout(dynSection, 6)

    divLine()

    -- ── 時刻設定 ─────────────────────────────────────────────────
    secLbl("■ 時刻設定")

    local timeRow = mkFrame(scroll, Color3.fromRGB(0,0,0),
        {Size=UDim2.new(1,0,0,38), BackgroundTransparency=1, LayoutOrder=lo()})
    hLayout(timeRow, 4)

    for _, tb in ipairs(TIME_BTNS) do
        local tbtn = mkBtn(timeRow, tb.label, tb.color,
            {Size=UDim2.new(1/#TIME_BTNS,-4,1,0), TextSize=13, r=6})
        local cid = tb.id
        tbtn.Activated:Connect(function()
            evtSetTime:FireServer(cid)
            if statusLabel and panelGui and panelGui.Parent then
                statusLabel.Text      = "時刻を「" .. tb.label .. "」に設定しました"
                statusLabel.TextColor3 = Color3.fromRGB(200,200,255)
            end
        end)
    end

    -- ステータスライン
    local sLbl = mkLabel(scroll, "", {
        Size=UDim2.new(1,0,0,22), LayoutOrder=lo(),
        TextColor3=Color3.fromRGB(100,210,130), TextSize=13, Font=Enum.Font.Gotham})
    statusLabel = sLbl

    -- ── 番線タブコンテンツ再構築 ─────────────────────────────────
    local function rebuildDyn(t)
        for _, c in ipairs(dynSection:GetChildren()) do
            if not c:IsA("UIListLayout") then c:Destroy() end
        end

        local dIdx = 0
        local function dlo() dIdx += 1; return dIdx end

        local tc     = TRACK_COLORS[t]
        local pres   = trainPresent[t]
        local autoOn = autoOpActive[t]

        -- 列車スポーン
        mkLabel(dynSection, "■ 列車スポーン（" .. t .. "番線）", {
            Size=UDim2.new(1,0,0,20), LayoutOrder=dlo(),
            TextColor3=Color3.fromRGB(120,158,220), TextSize=13,
            Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left})

        local spRow = mkFrame(dynSection, Color3.fromRGB(0,0,0),
            {Size=UDim2.new(1,0,0,40), BackgroundTransparency=1, LayoutOrder=dlo()})
        hLayout(spRow, 8)

        local spBtn = mkBtn(spRow, "スポーン",
            pres and Color3.fromRGB(45,52,78) or tc,
            {Size=UDim2.new(0.5,-4,1,0),
             TextColor3= pres and Color3.fromRGB(100,110,135) or Color3.fromRGB(255,255,255)})
        local stBtn = mkBtn(spRow, "格　納",
            pres and Color3.fromRGB(155,32,32) or Color3.fromRGB(45,52,78),
            {Size=UDim2.new(0.5,-4,1,0),
             TextColor3= pres and Color3.fromRGB(255,255,255) or Color3.fromRGB(100,110,135)})

        spBtn.Activated:Connect(function()
            if trainPresent[t] then return end
            evtSpawnTrain:FireServer(t, "spawn")
            sLbl.Text = t .. "番線: スポーン要求を送信しました"
            sLbl.TextColor3 = Color3.fromRGB(100,210,130)
        end)
        stBtn.Activated:Connect(function()
            if not trainPresent[t] then return end
            evtSpawnTrain:FireServer(t, "store")
            sLbl.Text = t .. "番線: 格納要求を送信しました"
            sLbl.TextColor3 = Color3.fromRGB(255,195,60)
        end)

        -- 状態表示
        mkLabel(dynSection, pres and "状態: ● スポーン中" or "状態: ○ 格納中", {
            Size=UDim2.new(1,0,0,18), LayoutOrder=dlo(),
            TextColor3= pres and Color3.fromRGB(100,220,130) or Color3.fromRGB(160,165,185),
            TextSize=13, Font=Enum.Font.Gotham,
            TextXAlignment=Enum.TextXAlignment.Left})

        -- 区切り
        mkFrame(dynSection, Color3.fromRGB(35,50,90),
            {Size=UDim2.new(1,0,0,1), LayoutOrder=dlo()})

        -- 自動運行
        mkLabel(dynSection, "■ 自動運行（" .. t .. "番線）", {
            Size=UDim2.new(1,0,0,20), LayoutOrder=dlo(),
            TextColor3=Color3.fromRGB(120,158,220), TextSize=13,
            Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left})

        local aoRow = mkFrame(dynSection, Color3.fromRGB(0,0,0),
            {Size=UDim2.new(1,0,0,40), BackgroundTransparency=1, LayoutOrder=dlo()})
        hLayout(aoRow, 8)

        local startBtn = mkBtn(aoRow, "▶  自動運行 開始",
            autoOn and Color3.fromRGB(45,52,78) or Color3.fromRGB(0,125,55),
            {Size=UDim2.new(0.57,-4,1,0), TextSize=14,
             TextColor3= autoOn and Color3.fromRGB(100,110,135) or Color3.fromRGB(255,255,255)})
        local stopBtn = mkBtn(aoRow, "■  停止",
            autoOn and Color3.fromRGB(155,24,24) or Color3.fromRGB(45,52,78),
            {Size=UDim2.new(0.43,-4,1,0), TextSize=14,
             TextColor3= autoOn and Color3.fromRGB(255,255,255) or Color3.fromRGB(100,110,135)})

        -- 始発駅
        mkLabel(dynSection, "始発駅", {
            Size=UDim2.new(1,0,0,18), LayoutOrder=dlo(),
            TextColor3=Color3.fromRGB(150,172,215), TextSize=12,
            Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left})
        local stPicker = makeStationPicker(dynSection,
            function() return selStartIdx[t] end,
            function(v) selStartIdx[t] = v end)
        dynSection:FindFirstChild("99") -- dummy
        local spFrame = dynSection:GetChildren()
        -- stPickerのLayoutOrderを修正
        for _, c in ipairs(dynSection:GetChildren()) do
            if c:IsA("Frame") and c.Name == "Frame" and c.Size == UDim2.new(1,0,0,36) then
                c.LayoutOrder = dlo()
                break
            end
        end

        -- 終着駅
        mkLabel(dynSection, "終着駅", {
            Size=UDim2.new(1,0,0,18), LayoutOrder=dlo(),
            TextColor3=Color3.fromRGB(150,172,215), TextSize=12,
            Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left})
        makeStationPicker(dynSection,
            function() return selEndIdx[t] end,
            function(v) selEndIdx[t] = v end)
        for _, c in ipairs(dynSection:GetChildren()) do
            if c:IsA("Frame") and c.Name == "Frame" and c.LayoutOrder == 99 then
                c.LayoutOrder = dlo()
                break
            end
        end

        startBtn.Activated:Connect(function()
            if autoOpActive[t] then return end
            if selStartIdx[t] == selEndIdx[t] then
                sLbl.Text = "始発駅と終着駅に同じ駅は選べません"
                sLbl.TextColor3 = Color3.fromRGB(255,90,70)
                return
            end
            evtStart:FireServer(t, selStartIdx[t], selEndIdx[t])
            sLbl.Text = t .. "番線: 自動運行を開始します（" ..
                STATION_NAMES[selStartIdx[t]] .. "〜" .. STATION_NAMES[selEndIdx[t]] .. "）"
            sLbl.TextColor3 = Color3.fromRGB(100,210,130)
        end)
        stopBtn.Activated:Connect(function()
            evtStop:FireServer(t)
            sLbl.Text = t .. "番線: 自動運行を停止します"
            sLbl.TextColor3 = Color3.fromRGB(255,195,60)
        end)
    end

    -- タブボタン生成
    local function refreshTabs()
        for t, btn in ipairs(trackBtns) do
            local on = autoOpActive[t]
            local pr = trainPresent[t]
            btn.BackgroundColor3 = (t == selTrack) and TRACK_COLORS[t] or Color3.fromRGB(24,32,58)
            btn.TextColor3 = (t == selTrack) and Color3.fromRGB(255,255,255) or Color3.fromRGB(145,165,210)
            local info = on and "運行中" or (pr and "待機中" or "")
            btn.Text = t .. "番線\n" .. info
        end
    end

    for t = 1, 4 do
        local btn = mkBtn(tabRow, t .. "番線", Color3.fromRGB(24,32,58),
            {Size=UDim2.new(0.25,-4,1,0), TextSize=13, r=6})
        local capturedT = t
        btn.Activated:Connect(function()
            selTrack = capturedT
            refreshTabs()
            rebuildDyn(selTrack)
        end)
        trackBtns[t] = btn
    end
    refreshTabs()
    rebuildDyn(selTrack)

    -- Escape で閉じる
    local escConn
    escConn = UserInputService.InputBegan:Connect(function(inp, handled)
        if not handled and inp.KeyCode == Enum.KeyCode.Escape then
            escConn:Disconnect(); closePanel()
        end
    end)
end

-- ============================================================
-- イベント受信
-- ============================================================
evtOpen.OnClientEvent:Connect(function(statuses, initialTrack, initTrainPresent, initConfigs)
    buildPanel(statuses, initialTrack, initTrainPresent, initConfigs)
end)

evtStatus.OnClientEvent:Connect(function(trackNum, state, stationName)
    if     state == "stopped"   then autoOpActive[trackNum] = false
    elseif state == "running"
        or state == "departing"
        or state == "arrived"   then autoOpActive[trackNum] = true
    end
    local msgs = {
        departing = string.format("%d番線 → %s に向け出発", trackNum, stationName),
        arrived   = string.format("%d番線 → %s に到着（乗降中）", trackNum, stationName),
        stopped   = string.format("%d番線: 自動運行を終了しました", trackNum),
        running   = string.format("%d番線: 自動運行中", trackNum),
    }
    if statusLabel and panelGui and panelGui.Parent then
        statusLabel.Text      = msgs[state] or ""
        statusLabel.TextColor3 = state == "stopped"
            and Color3.fromRGB(255,195,60) or Color3.fromRGB(100,210,130)
    end
end)

evtStateSync.OnClientEvent:Connect(function(trackNum, hasTrail)
    trainPresent[trackNum] = hasTrail
end)
