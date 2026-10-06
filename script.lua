-- ════════════════════════════════════
-- COINMASTER MM2 v8.8
-- by dj | full rewrite | oct 2026
-- ════════════════════════════════════
-- [FIX v8.1] HeadEdgeOffset=0
-- [FIX v8.2] NoCollide только во время маршрута
-- [FIX v8.3] safeTP при старте убран
-- [FIX v8.4] _parkY не сбрасывается
-- [FIX v8.5] GUI якорь верхний-левый
-- [NEW v8.6] Радужные цвета GUI
-- [FIX v8.7] Убрано падение между монетами (coin→coin без дипа)
-- [FIX v8.8] NoCollide скоупирован только на карту раунда
-- ════════════════════════════════════

if getgenv().CM_LOADED then
    game:GetService("StarterGui"):SetCore("SendNotification",{
        Title="CoinMaster"; Text="Уже запущен!"; Duration=3;
    })
    return
end
getgenv().CM_LOADED = true

-- ════ СЕРВИСЫ ════════════════════════
local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInput    = game:GetService("UserInputService")
local CoreGui      = game:GetService("CoreGui")
local LP           = Players.LocalPlayer

-- ════ НАСТРОЙКИ ══════════════════════
local CFG = {
    Enabled        = false,
    AntiAFK        = true,
    AutoReset      = true,
    DelayMin       = 1.5,
    DelayMax       = 2.5,
    CoinType       = "Coin_Server",
    StealthMode    = true,
    ImproveFPS     = false,
    ShowStats      = true,
    FTIAssist      = true,
    HeadEdgeOffset = 0,
    FlySpeed       = 10,
    HideDepth      = 6,
    TouchWait      = 0.8,
    CoinDelay      = 0.20,
    CoinDelayRng   = 0.25,
    NoCollide      = true,
}

local HAS_FTI = typeof(firetouchinterest) == "function"

-- ════ СТАТИСТИКА ═════════════════════
local STATS = {
    CoinsThisRound = 0,
    CoinsTotal     = 0,
    RoundsPlayed   = 0,
    SessionStart   = os.clock(),
}
local _collectedCoins = {}

-- ════ PARK Y ═════════════════════════
local HIDE_X = math.random(-8, 8)
local HIDE_Z = math.random(-8, 8)
local _parkY = nil

local function getParkY()
    if _parkY then return _parkY end
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    return hrp and (hrp.CFrame.Position.Y - 20) or -20
end

local function getHideSpot()
    return CFrame.new(
        HIDE_X + math.random(-4, 4) * 0.05,
        getParkY(),
        HIDE_Z + math.random(-4, 4) * 0.05
    )
end

local function updateParkY(coinsHint)
    local coins = coinsHint or {}
    local minY = math.huge
    for _, c in ipairs(coins) do
        if c and c.Parent then
            minY = math.min(minY, c.Position.Y)
        end
    end
    if minY ~= math.huge then
        _parkY = minY - CFG.HideDepth
    end
end

-- ════ CONTAINER CACHE ════════════════
-- [v8.8] объявляется ДО no-collide чтобы enableNoCollide видел переменную
local _cachedContainer = nil

-- ════ NO-COLLIDE ═════════════════════
-- [v8.8] скоупирован только на модель карты раунда, лобби не трогает
local noCollideConn = nil

local function isCoinPart(part)
    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("TouchTransmitter") then return true end
    end
    return false
end

local function shouldSkipPart(part)
    local char = LP.Character
    if char and part:IsDescendantOf(char) then return true end
    if isCoinPart(part) then return true end
    return false
end

local function applyNoCollide(part)
    if shouldSkipPart(part) then return end
    pcall(function() part.CanCollide = false end)
end

-- [v8.8] возвращает Model в workspace который является картой раунда
local function getRoundMapModel()
    if not _cachedContainer or not _cachedContainer.Parent then return nil end
    local p = _cachedContainer.Parent
    -- CoinContainer → родитель → он же в workspace = карта раунда
    if p and p ~= workspace and p.Parent == workspace then return p end
    -- CoinContainer лежит прямо в workspace, поднимаемся выше нет смысла
    return nil
end

local function enableNoCollide()
    if noCollideConn then return end
    local roundMap = getRoundMapModel()
    if not roundMap then return end  -- карта не найдена → пропустить
    for _, v in ipairs(roundMap:GetDescendants()) do
        if v:IsA("BasePart") then applyNoCollide(v) end
    end
    noCollideConn = roundMap.DescendantAdded:Connect(function(obj)
        if obj:IsA("BasePart") then
            task.defer(function()
                if obj and obj.Parent then applyNoCollide(obj) end
            end)
        end
    end)
end

local function stopNoCollide()
    if noCollideConn then noCollideConn:Disconnect(); noCollideConn = nil end
end

-- ════ ХЕЛПЕРЫ ════════════════════════
local function getHRP()
    local char = LP.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function safeTP(cf)
    pcall(function()
        local hrp = getHRP()
        if hrp then hrp.CFrame = cf end
    end)
end

local function smoothTP(targetCF, speed, abortFn)
    speed = speed or CFG.FlySpeed
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local startCF = hrp.CFrame
    local dist    = (startCF.Position - targetCF.Position).Magnitude
    if dist < 0.3 then return end

    local duration = math.clamp(dist / speed, 0.15, 5.0)
    local elapsed  = 0

    repeat
        local dt = task.wait(0.016)
        elapsed = elapsed + dt
        if abortFn and abortFn() then break end
        local t = math.min(elapsed / duration, 1)
        local a = t * t * (3 - 2 * t)
        pcall(function()
            if hrp and hrp.Parent then
                hrp.CFrame   = startCF:Lerp(targetCF, a)
                hrp.Velocity = Vector3.zero
            end
        end)
    until elapsed >= duration or not CFG.Enabled
end

local function randDelay()
    return CFG.DelayMin + math.random() * (CFG.DelayMax - CFG.DelayMin)
end

local function notify(title, text, dur)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification",{
            Title=title; Text=text; Duration=dur or 3;
        })
    end)
end

-- ════ ПОИСК КОНТЕЙНЕРА ═══════════════
-- _cachedContainer уже объявлен выше
local function findContainer()
    if _cachedContainer and _cachedContainer.Parent then return _cachedContainer end
    _cachedContainer = nil
    for _, v in ipairs(workspace:GetChildren()) do
        if v:IsA("Model") then
            local cc = v:FindFirstChild("CoinContainer")
            if cc then _cachedContainer = cc; return cc end
        end
    end
    local cc = workspace:FindFirstChild("CoinContainer")
    if cc then _cachedContainer = cc; return cc end
    cc = workspace:FindFirstChild("CoinContainer", true)
    if cc then _cachedContainer = cc; return cc end
    return nil
end

-- ════ ПОИСК МОНЕТ ════════════════════
local COIN_NAMES = {
    Coin_Server=true, Coin=true, BeachBall=true,
    Shell=true, Candy=true, SnowToken=true, Egg=true,
}

local function findCoins()
    local coins, seen = {}, {}
    local container = findContainer()
    if not container then return coins end

    for _, v in ipairs(container:GetDescendants()) do
        if v:IsA("TouchTransmitter") then
            local part = v.Parent
            if part and part:IsA("BasePart") and not seen[part]
            and part:IsDescendantOf(workspace) then
                seen[part] = true; table.insert(coins, part)
            end
        end
    end

    if #coins == 0 then
        for _, v in ipairs(container:GetDescendants()) do
            if COIN_NAMES[v.Name] then
                local part
                if v:IsA("BasePart") then
                    part = v
                elseif v:IsA("Model") then
                    part = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart", true)
                end
                if part and not seen[part] and part:IsDescendantOf(workspace) then
                    seen[part] = true; table.insert(coins, part)
                end
            end
        end
    end

    if #coins == 0 then
        for _, v in ipairs(container:GetDescendants()) do
            if v:IsA("BasePart") and not seen[v] then
                local ok, attr = pcall(function() return v:GetAttribute("CoinID") end)
                if ok and attr then seen[v] = true; table.insert(coins, v) end
            end
        end
    end

    return coins
end

local function coinMatchesType(coinPart)
    if CFG.CoinType == "All" then return true end
    local ok, attr = pcall(function() return coinPart:GetAttribute("CoinID") end)
    if ok and attr then return attr == CFG.CoinType end
    if coinPart.Name == CFG.CoinType then return true end
    if coinPart.Parent and coinPart.Parent.Name == CFG.CoinType then return true end
    return false
end

-- ════ СТЕЛС ══════════════════════════
local function isMurdererNearby(pos)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position - pos).Magnitude < 25 then
                for _, tool in ipairs(p.Character:GetChildren()) do
                    if tool:IsA("Tool") then return true end
                end
                local char = p.Character
                if char:FindFirstChild("KnifeTag")
                or char:FindFirstChild("MurderTag")
                or char:FindFirstChild("MurdererTag") then
                    return true
                end
            end
        end
    end
    return false
end

-- ════ СБОР МОНЕТЫ ════════════════════
local function collectCoin(coinPart)
    if not coinPart or not coinPart.Parent then return false end
    if not coinPart:IsDescendantOf(workspace) then return false end

    local jitter = Vector3.new((math.random()-0.5)*0.4, 0, (math.random()-0.5)*0.4)
    local targetCF = CFrame.new(
        coinPart.Position.X + jitter.X,
        coinPart.Position.Y - CFG.HeadEdgeOffset,
        coinPart.Position.Z + jitter.Z
    )

    local coinGone = function() return not (coinPart and coinPart.Parent) end
    smoothTP(targetCF, nil, coinGone)

    if not coinPart.Parent then return false end

    task.wait(0.033)
    task.wait(0.033)

    if not coinPart.Parent then return true end

    local waited = 0
    local step   = 0.05
    while coinPart.Parent and waited < CFG.TouchWait do
        if HAS_FTI and CFG.FTIAssist then
            local hrp = getHRP()
            if hrp then
                pcall(function() firetouchinterest(coinPart, hrp, 0) end)
            end
        end
        task.wait(step)
        waited = waited + step
        if HAS_FTI and CFG.FTIAssist and coinPart.Parent then
            local hrp = getHRP()
            if hrp then
                pcall(function() firetouchinterest(coinPart, hrp, 1) end)
            end
        end
    end

    return true
end

-- ════ МАРШРУТ GREEDY NN ══════════════
-- [v8.7] после каждой монеты НЕТ падения к parkY
--        персонаж идёт прямо к следующей монете
--        парковка только после завершения всего маршрута
local function runCoinRoute()
    local all = findCoins()
    if #all == 0 then return false end

    updateParkY(all)

    local remaining = {}
    for _, c in ipairs(all) do
        if c and c.Parent and not _collectedCoins[c] and coinMatchesType(c) then
            table.insert(remaining, c)
        end
    end
    if #remaining == 0 then return false end

    -- [v8.8] NoCollide теперь применяется только к модели карты раунда
    if CFG.NoCollide then enableNoCollide() end

    local anyCollected = false

    while #remaining > 0 do
        if not CFG.Enabled or bagFull or deadThisRound then break end

        local hrp = getHRP()
        if not hrp then break end

        local curPos = hrp.CFrame.Position
        local bestIdx, bestDist = nil, math.huge
        for i, coin in ipairs(remaining) do
            if coin and coin.Parent then
                local d = (coin.Position - curPos).Magnitude
                if d < bestDist then bestDist = d; bestIdx = i end
            end
        end

        if not bestIdx then
            local fresh = {}
            for _, c in ipairs(remaining) do
                if c and c.Parent and not _collectedCoins[c] then
                    table.insert(fresh, c)
                end
            end
            remaining = fresh
            if #remaining == 0 then break end
            continue
        end

        local coin = table.remove(remaining, bestIdx)
        if _collectedCoins[coin] then continue end
        if not coin.Parent then continue end
        if CFG.StealthMode and isMurdererNearby(coin.Position) then continue end

        local ok = collectCoin(coin)
        if ok then
            _collectedCoins[coin] = true
            if not coin.Parent then
                STATS.CoinsThisRound += 1
                STATS.CoinsTotal     += 1
            end
            anyCollected = true
            -- [v8.7] убрано: падение к parkY после каждой монеты
            -- летим прямо к следующей без дипа
        end

        task.wait(CFG.CoinDelay + math.random() * CFG.CoinDelayRng)

        local fresh = {}
        for _, c in ipairs(remaining) do
            if c and c.Parent and not _collectedCoins[c] then
                table.insert(fresh, c)
            end
        end
        remaining = fresh
    end

    -- NoCollide выключается после маршрута (было и раньше)
    if CFG.NoCollide then stopNoCollide() end

    return anyCollected
end

-- ════ IMPROVE FPS ════════════════════
local function improveFPS()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            for _, part in ipairs(p.Character:GetChildren()) do
                if part:IsA("Accessory") or part.Name == "Radio" then
                    pcall(function() part:Destroy() end)
                end
            end
        end
    end
end

-- ════ АНТИ-АФК ═══════════════════════
local function startAntiAFK()
    local ok, gc = pcall(getconnections, LP.Idled)
    if ok and gc then
        for _, c in ipairs(gc) do
            pcall(function() c:Disable() end)
            pcall(function() c:Disconnect() end)
        end
    end
    local VU
    pcall(function() VU = cloneref(game:GetService("VirtualUser")) end)
    if not VU then VU = game:GetService("VirtualUser") end
    LP.Idled:Connect(function()
        pcall(function()
            VU:CaptureController()
            VU:ClickButton2(Vector2.new())
        end)
    end)
end

-- ════ ФЛАГИ ══════════════════════════
local deadThisRound = false
local farmActive    = false
local bagFull       = false

local function hookCharacter(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if hum then
        hum.Died:Connect(function() deadThisRound = true end)
    end
end

LP.CharacterAdded:Connect(function(char)
    deadThisRound = false
    hookCharacter(char)
end)
if LP.Character then task.spawn(hookCharacter, LP.Character) end

-- ════ ДЕТЕКТ РАУНДОВ ═════════════════
task.spawn(function()
    local lastCount = 0
    while true do
        task.wait(2)
        local coins = findCoins()
        local count = #coins
        if count > 0 and not farmActive then
            farmActive = true; deadThisRound = false
            updateParkY(coins)
        elseif count == 0 and lastCount > 0 then
            farmActive = false; bagFull = false
            STATS.RoundsPlayed += 1; STATS.CoinsThisRound = 0
            _cachedContainer = nil; _collectedCoins = {}
        end
        lastCount = count
    end
end)

task.spawn(function()
    local RS = game:GetService("ReplicatedStorage")
    local function tryPath(...)
        local cur = RS
        for _, name in ipairs({...}) do cur = cur and cur:FindFirstChild(name) end
        return cur
    end
    local CoinEvent  = tryPath("Remotes","Gameplay","CoinCollected")
    local RoundStart = tryPath("Remotes","Gameplay","RoundStart")
    local RoundEnd   = tryPath("Remotes","Gameplay","RoundEndFade")
                    or tryPath("Remotes","Gameplay","RoundEnd")

    if CoinEvent then
        CoinEvent.OnClientEvent:Connect(function(_, current, max)
            farmActive = true
            if tonumber(current) and tonumber(max)
            and tonumber(current) >= tonumber(max) then
                bagFull = true
                if CFG.AutoReset then
                    task.delay(0.4, function()
                        pcall(function()
                            local char = LP.Character
                            if char then
                                local hum = char:FindFirstChildOfClass("Humanoid")
                                if hum then hum.Health = 0 end
                            end
                        end)
                    end)
                end
            end
        end)
    end

    if RoundStart then
        RoundStart.OnClientEvent:Connect(function()
            farmActive = true; deadThisRound = false; bagFull = false
            STATS.RoundsPlayed += 1; STATS.CoinsThisRound = 0
            _cachedContainer = nil; _collectedCoins = {}
        end)
    end

    if RoundEnd then
        RoundEnd.OnClientEvent:Connect(function()
            farmActive = false; bagFull = false
        end)
    end
end)

task.delay(2, function()
    if not farmActive then
        local coins = findCoins()
        if #coins > 0 then
            farmActive = true
            updateParkY(coins)
        end
    end
end)

-- ════ ОСНОВНОЙ ЦИКЛ ══════════════════
task.spawn(function()
    while true do
        if CFG.Enabled and farmActive and not bagFull and not deadThisRound then
            local hrp = getHRP()
            if hrp then
                local anyCollected = runCoinRoute()
                if anyCollected then
                    -- парковка под картой только по завершении всего маршрута
                    hrp = getHRP()
                    if hrp then
                        smoothTP(getHideSpot(), CFG.FlySpeed * 0.7)
                    end
                else
                    farmActive = false
                end
            end
        end
        task.wait(randDelay())
    end
end)

-- ════ IMPROVE FPS WATCHER ════════════
local function connectImproveFPS(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.5)
        if CFG.ImproveFPS then improveFPS() end
    end)
end
for _, p in ipairs(Players:GetPlayers()) do connectImproveFPS(p) end
Players.PlayerAdded:Connect(connectImproveFPS)

-- ════ GUI v8 ═════════════════════════
pcall(function()
    local old = CoreGui:FindFirstChild("CoinMasterGUI")
    if old then old:Destroy() end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name             = "CoinMasterGUI"
ScreenGui.ResetOnSpawn     = false
ScreenGui.IgnoreGuiInset   = true
ScreenGui.DisplayOrder     = 999
ScreenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent           = (typeof(gethui) == "function" and gethui())
                           or LP.PlayerGui

local Main = Instance.new("Frame")
Main.Name              = "Main"
Main.Size              = UDim2.new(0, 265, 0, 540)
Main.Position          = UDim2.new(0, 10, 0, 10)
Main.AnchorPoint       = Vector2.new(0, 0)
Main.BackgroundColor3  = Color3.fromRGB(10, 10, 14)
Main.BorderSizePixel   = 0
Main.ClipsDescendants  = true
Main.Parent            = ScreenGui

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)

local mainStroke = Instance.new("UIStroke", Main)
mainStroke.Thickness    = 1.5
mainStroke.Transparency = 0.15

local Header = Instance.new("Frame", Main)
Header.Size             = UDim2.new(1, 0, 0, 46)
Header.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
Header.BorderSizePixel  = 0
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 12)

local headerFix = Instance.new("Frame", Header)
headerFix.Size             = UDim2.new(1, 0, 0.5, 0)
headerFix.Position         = UDim2.new(0, 0, 0.5, 0)
headerFix.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
headerFix.BorderSizePixel  = 0

local TitleLabel = Instance.new("TextLabel", Header)
TitleLabel.Size                   = UDim2.new(1, -46, 1, 0)
TitleLabel.Position               = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text                   = "🪙 CoinMaster MM2 v8.8"
TitleLabel.TextSize               = 13
TitleLabel.Font                   = Enum.Font.GothamBold
TitleLabel.TextXAlignment         = Enum.TextXAlignment.Left

local MinBtn = Instance.new("TextButton", Header)
MinBtn.Size             = UDim2.new(0, 30, 0, 30)
MinBtn.Position         = UDim2.new(1, -38, 0, 8)
MinBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
MinBtn.BorderSizePixel  = 0
MinBtn.Text             = "—"
MinBtn.TextColor3       = Color3.fromRGB(200, 200, 215)
MinBtn.TextSize         = 14
MinBtn.Font             = Enum.Font.GothamBold
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

local ScrollFrame = Instance.new("ScrollingFrame", Main)
ScrollFrame.Name                   = "ScrollFrame"
ScrollFrame.Size                   = UDim2.new(1, 0, 1, -46)
ScrollFrame.Position               = UDim2.new(0, 0, 0, 46)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.BorderSizePixel        = 0
ScrollFrame.ScrollBarThickness     = 3
ScrollFrame.ScrollingDirection     = Enum.ScrollingDirection.Y
ScrollFrame.CanvasSize             = UDim2.new(0, 0, 0, 0)
ScrollFrame.AutomaticCanvasSize    = Enum.AutomaticSize.Y

local Content = Instance.new("Frame", ScrollFrame)
Content.Name                   = "Content"
Content.Size                   = UDim2.new(1, -8, 0, 0)
Content.AutomaticSize          = Enum.AutomaticSize.Y
Content.BackgroundTransparency = 1

local pad = Instance.new("UIPadding", Content)
pad.PaddingLeft   = UDim.new(0, 12)
pad.PaddingRight  = UDim.new(0, 12)
pad.PaddingTop    = UDim.new(0, 10)
pad.PaddingBottom = UDim.new(0, 10)

local list = Instance.new("UIListLayout", Content)
list.Padding       = UDim.new(0, 6)
list.SortOrder     = Enum.SortOrder.LayoutOrder
list.FillDirection = Enum.FillDirection.Vertical

-- ════ RAINBOW ════════════════════════
local _rainbowHue  = 0
local _rainbowRefs = {}

local function registerRainbow(inst, prop)
    table.insert(_rainbowRefs, {inst=inst, prop=prop})
end

task.spawn(function()
    while true do
        task.wait(0.05)
        _rainbowHue = (_rainbowHue + 0.004) % 1
        local col = Color3.fromHSV(_rainbowHue, 0.85, 1)
        for _, ref in ipairs(_rainbowRefs) do
            pcall(function() ref.inst[ref.prop] = col end)
        end
        mainStroke.Color      = col
        TitleLabel.TextColor3 = col
    end
end)

-- ── Фабрики ──────────────────────────
local function makeLabel(txt, sz, order, rainbow)
    local lbl = Instance.new("TextLabel", Content)
    lbl.Size                   = UDim2.new(1, 0, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = txt
    lbl.TextColor3             = Color3.fromRGB(175, 175, 195)
    lbl.TextSize               = sz or 11
    lbl.Font                   = Enum.Font.Gotham
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.LayoutOrder            = order or 0
    if rainbow then registerRainbow(lbl, "TextColor3") end
    return lbl
end

local function makeDivider(order)
    local d = Instance.new("Frame", Content)
    d.Size             = UDim2.new(1, 0, 0, 1)
    d.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
    d.BorderSizePixel  = 0
    d.LayoutOrder      = order or 0
    return d
end

local function makeToggle(label, cfgKey, order, callback)
    local row = Instance.new("Frame", Content)
    row.Size                   = UDim2.new(1, 0, 0, 30)
    row.BackgroundTransparency = 1
    row.LayoutOrder            = order

    local lbl = Instance.new("TextLabel", row)
    lbl.Size                   = UDim2.new(0.72, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = label
    lbl.TextColor3             = Color3.fromRGB(210, 210, 220)
    lbl.TextSize               = 12
    lbl.Font                   = Enum.Font.Gotham
    lbl.TextXAlignment         = Enum.TextXAlignment.Left

    local track = Instance.new("Frame", row)
    track.Size             = UDim2.new(0, 42, 0, 22)
    track.Position         = UDim2.new(1, -42, 0.5, -11)
    track.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
    track.BorderSizePixel  = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local ball = Instance.new("Frame", track)
    ball.Size             = UDim2.new(0, 16, 0, 16)
    ball.Position         = UDim2.new(0, 3, 0.5, -8)
    ball.BackgroundColor3 = Color3.fromRGB(130, 130, 145)
    ball.BorderSizePixel  = 0
    Instance.new("UICorner", ball).CornerRadius = UDim.new(1, 0)

    local function refresh()
        local on  = CFG[cfgKey]
        local col = Color3.fromHSV(_rainbowHue, 0.85, 1)
        TweenService:Create(track, TweenInfo.new(0.18), {
            BackgroundColor3 = on and col or Color3.fromRGB(35, 35, 48)
        }):Play()
        TweenService:Create(ball, TweenInfo.new(0.18), {
            Position = on and UDim2.new(0, 23, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
            BackgroundColor3 = on
                and Color3.fromRGB(255, 255, 255)
                or  Color3.fromRGB(130, 130, 145)
        }):Play()
    end
    refresh()

    local btn = Instance.new("TextButton", row)
    btn.Size                   = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text                   = ""
    btn.MouseButton1Click:Connect(function()
        CFG[cfgKey] = not CFG[cfgKey]
        refresh()
        if callback then callback(CFG[cfgKey]) end
    end)

    task.spawn(function()
        while true do
            task.wait(0.05)
            if CFG[cfgKey] then
                pcall(function()
                    track.BackgroundColor3 = Color3.fromHSV(_rainbowHue, 0.85, 1)
                end)
            end
        end
    end)
end

local function makeSlider(labelText, cfgKey, minVal, maxVal, step, order, onChange)
    local wrap = Instance.new("Frame", Content)
    wrap.Name                   = "Slider_" .. cfgKey
    wrap.Size                   = UDim2.new(1, 0, 0, 44)
    wrap.BackgroundTransparency = 1
    wrap.LayoutOrder            = order

    local nameLbl = Instance.new("TextLabel", wrap)
    nameLbl.Size                   = UDim2.new(0.68, 0, 0, 16)
    nameLbl.Position               = UDim2.new(0, 0, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text                   = labelText
    nameLbl.TextColor3             = Color3.fromRGB(210, 210, 220)
    nameLbl.TextSize               = 12
    nameLbl.Font                   = Enum.Font.Gotham
    nameLbl.TextXAlignment         = Enum.TextXAlignment.Left

    local valLbl = Instance.new("TextLabel", wrap)
    valLbl.Size                   = UDim2.new(0.32, 0, 0, 16)
    valLbl.Position               = UDim2.new(0.68, 0, 0, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.TextSize               = 12
    valLbl.Font                   = Enum.Font.GothamBold
    valLbl.TextXAlignment         = Enum.TextXAlignment.Right
    registerRainbow(valLbl, "TextColor3")

    local track = Instance.new("Frame", wrap)
    track.Size             = UDim2.new(1, 0, 0, 10)
    track.Position         = UDim2.new(0, 0, 0, 22)
    track.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
    track.BorderSizePixel  = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame", track)
    fill.Size             = UDim2.new(0, 0, 1, 0)
    fill.BorderSizePixel  = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    registerRainbow(fill, "BackgroundColor3")

    local thumb = Instance.new("Frame", track)
    thumb.AnchorPoint      = Vector2.new(0.5, 0.5)
    thumb.Size             = UDim2.new(0, 14, 0, 14)
    thumb.Position         = UDim2.new(0, 0, 0.5, 0)
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    thumb.BorderSizePixel  = 0
    thumb.ZIndex           = 3
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)

    local function fmtVal(v)
        if step and step < 1 then return string.format("%.1f", v) end
        return tostring(math.floor(v + 0.5))
    end

    local function setValue(alpha)
        alpha = math.clamp(alpha, 0, 1)
        local raw = minVal + (maxVal - minVal) * alpha
        if step then raw = math.round(raw / step) * step end
        raw = math.clamp(raw, minVal, maxVal)
        CFG[cfgKey] = raw
        local t = (raw - minVal) / (maxVal - minVal)
        fill.Size      = UDim2.new(t, 0, 1, 0)
        thumb.Position = UDim2.new(t, 0, 0.5, 0)
        valLbl.Text    = fmtVal(raw)
        if onChange then onChange(raw) end
    end

    setValue((CFG[cfgKey] - minVal) / (maxVal - minVal))

    local hitBtn = Instance.new("TextButton", track)
    hitBtn.Size                   = UDim2.new(1, 0, 0, 22)
    hitBtn.Position               = UDim2.new(0, 0, 0.5, -11)
    hitBtn.BackgroundTransparency = 1
    hitBtn.Text                   = ""
    hitBtn.ZIndex                 = 5

    local sliderDragging = false

    local function alphaFromX(screenX)
        local abs = track.AbsolutePosition
        local sz  = track.AbsoluteSize
        if sz.X == 0 then return 0 end
        return (screenX - abs.X) / sz.X
    end

    hitBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            sliderDragging = true
            setValue(alphaFromX(inp.Position.X))
        end
    end)
    hitBtn.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            sliderDragging = false
        end
    end)
    UserInput.InputChanged:Connect(function(inp)
        if sliderDragging and (
            inp.UserInputType == Enum.UserInputType.MouseMovement
         or inp.UserInputType == Enum.UserInputType.Touch
        ) then
            setValue(alphaFromX(inp.Position.X))
        end
    end)
    UserInput.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            sliderDragging = false
        end
    end)
end

local function makeCoinSelector(order)
    local row = Instance.new("Frame", Content)
    row.Size                   = UDim2.new(1, 0, 0, 30)
    row.BackgroundTransparency = 1
    row.LayoutOrder            = order

    local lbl = Instance.new("TextLabel", row)
    lbl.Size                   = UDim2.new(0.45, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = "Тип монет"
    lbl.TextColor3             = Color3.fromRGB(210, 210, 220)
    lbl.TextSize               = 12
    lbl.Font                   = Enum.Font.Gotham
    lbl.TextXAlignment         = Enum.TextXAlignment.Left

    local types = {"Coin_Server","All","BeachBall","Shell","Candy"}
    local idx = 1
    for i, t in ipairs(types) do
        if t == CFG.CoinType then idx = i end
    end

    local typeBtn = Instance.new("TextButton", row)
    typeBtn.Size             = UDim2.new(0.52, 0, 0, 24)
    typeBtn.Position         = UDim2.new(0.48, 0, 0.5, -12)
    typeBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    typeBtn.BorderSizePixel  = 0
    typeBtn.Text             = "◀ " .. types[idx] .. " ▶"
    typeBtn.TextSize         = 11
    typeBtn.Font             = Enum.Font.GothamBold
    Instance.new("UICorner", typeBtn).CornerRadius = UDim.new(0, 6)
    registerRainbow(typeBtn, "TextColor3")

    typeBtn.MouseButton1Click:Connect(function()
        idx = idx % #types + 1
        CFG.CoinType = types[idx]
        typeBtn.Text = "◀ " .. types[idx] .. " ▶"
    end)
end

-- ── Кнопка СТАРТ/СТОП ────────────────
makeLabel(" ФАРМ", 11, 1, true)

local startBtn = Instance.new("TextButton", Content)
startBtn.Size             = UDim2.new(1, 0, 0, 36)
startBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
startBtn.BorderSizePixel  = 0
startBtn.Text             = "▶ Начать фарм"
startBtn.TextColor3       = Color3.fromRGB(185, 185, 205)
startBtn.TextSize         = 13
startBtn.Font             = Enum.Font.GothamBold
startBtn.LayoutOrder      = 2
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 8)

local startBtnStroke = Instance.new("UIStroke", startBtn)
startBtnStroke.Thickness    = 1
startBtnStroke.Transparency = 0.5

task.spawn(function()
    while true do
        task.wait(0.05)
        local col = Color3.fromHSV(_rainbowHue, 0.85, 1)
        pcall(function()
            startBtnStroke.Color = col
            if CFG.Enabled then
                startBtn.BackgroundColor3 = Color3.fromHSV(_rainbowHue, 0.7, 0.55)
            end
        end)
    end
end)

local function refreshStartBtn()
    if CFG.Enabled then
        startBtn.Text       = "⏹ Остановить"
        startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        startBtnStroke.Transparency = 0
    else
        TweenService:Create(startBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(22, 22, 32)
        }):Play()
        startBtn.Text       = "▶ Начать фарм"
        startBtn.TextColor3 = Color3.fromRGB(185, 185, 205)
        startBtnStroke.Transparency = 0.5
    end
end

startBtn.MouseButton1Click:Connect(function()
    CFG.Enabled = not CFG.Enabled
    if CFG.Enabled then
        bagFull = false
        local coins = findCoins()
        farmActive = (#coins > 0)
        if #coins > 0 then
            updateParkY(coins)
            safeTP(getHideSpot())
        end
        local mode = (HAS_FTI and CFG.FTIAssist) and "HeadEdge + FTI" or "HeadEdge"
        notify("CoinMaster", "Фарм запущен 🪙 [" .. mode .. "]", 3)
    else
        stopNoCollide()
        notify("CoinMaster", "Фарм остановлен.", 2)
    end
    refreshStartBtn()
end)

-- ── Настройки ────────────────────────
makeDivider(3)
makeLabel(" НАСТРОЙКИ", 11, 4, true)

makeCoinSelector(5)
makeSlider("Скорость полёта (stud/s)", "FlySpeed",   1,  50, 1,   6)
makeSlider("Глубина под полом (stud)",  "HideDepth",  0,  30, 0.5, 7)

makeToggle("Anti-AFK",                        "AntiAFK",     8,  function(v) if v then startAntiAFK() end end)
makeToggle("Авто-сброс при полном мешке",     "AutoReset",   9)
makeToggle("Stealth (обход убийцы)",          "StealthMode", 10)
makeToggle("FTI Assist (FireTouch доп.)",     "FTIAssist",   11)
makeToggle("NoCollide (сквозь стены карты)",  "NoCollide",   12)
makeToggle("Improve FPS (убрать аксессуары)", "ImproveFPS",  13, function(v) if v then improveFPS() end end)

local ftiLabel = Instance.new("TextLabel", Content)
ftiLabel.Size                   = UDim2.new(1, 0, 0, 14)
ftiLabel.BackgroundTransparency = 1
ftiLabel.Text = HAS_FTI
    and "✓ FTI доступен → физика + FireTouch"
    or  "✗ FTI недоступен → только физическое касание"
ftiLabel.TextColor3 = HAS_FTI
    and Color3.fromRGB(70, 180, 80)
    or  Color3.fromRGB(190, 130, 40)
ftiLabel.TextSize       = 10
ftiLabel.Font           = Enum.Font.Gotham
ftiLabel.TextXAlignment = Enum.TextXAlignment.Left
ftiLabel.LayoutOrder    = 14

makeDivider(15)
makeLabel(" СТАТИСТИКА", 11, 16, true)

local statLabel = Instance.new("TextLabel", Content)
statLabel.Size                   = UDim2.new(1, 0, 0, 90)
statLabel.BackgroundTransparency = 1
statLabel.Text                   = "Ожидание раунда..."
statLabel.TextColor3             = Color3.fromRGB(145, 145, 165)
statLabel.TextSize               = 11
statLabel.Font                   = Enum.Font.Gotham
statLabel.TextXAlignment         = Enum.TextXAlignment.Left
statLabel.TextWrapped            = true
statLabel.LayoutOrder            = 17

-- ── Перетаскивание ────────────────────
local dragging, dragStart, startPos = false, nil, nil
Header.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = inp.Position; startPos = Main.Position
    end
end)
UserInput.InputChanged:Connect(function(inp)
    if dragging and (
        inp.UserInputType == Enum.UserInputType.MouseMovement
     or inp.UserInputType == Enum.UserInputType.Touch
    ) then
        local delta = inp.Position - dragStart
        Main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)
UserInput.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- ── Минимизация ───────────────────────
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenService:Create(Main, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {
        Size = minimized
            and UDim2.new(0, 265, 0, 46)
            or  UDim2.new(0, 265, 0, 540)
    }):Play()
    MinBtn.Text = minimized and "+" or "—"
end)

-- ════ СТАТИСТИКА АПДЕЙТ ══════════════
task.spawn(function()
    while true do
        task.wait(1)
        if CFG.ShowStats then
            local elapsed   = math.max(1, math.floor(os.clock() - STATS.SessionStart))
            local mins      = math.floor(elapsed / 60)
            local secs      = elapsed % 60
            local rate      = math.floor(STATS.CoinsTotal / elapsed * 60)
            local coinCount = #findCoins()
            local mode      = (HAS_FTI and CFG.FTIAssist) and "HE+FTI" or "HeadEdge"

            local status
            if not CFG.Enabled then
                status = "🔴 Выкл"
            elseif deadThisRound then
                status = "⚫ Мёртв / лобби"
            elseif bagFull then
                status = "🟡 Мешок полон"
            elseif farmActive then
                status = "🟢 Фарм [" .. mode .. "] (" .. coinCount .. " монет)"
            else
                status = "🟡 Ждём раунд..."
            end

            statLabel.Text = string.format(
                "%s\nРаунд: %d | Всего: %d\nСессия: %02d:%02d | ~%d/мин\nРаундов: %d | Park Y: %.1f",
                status,
                STATS.CoinsThisRound, STATS.CoinsTotal,
                mins, secs, rate,
                STATS.RoundsPlayed,
                getParkY()
            )
        end
    end
end)

-- ════ СТАРТ ══════════════════════════
if CFG.AntiAFK then startAntiAFK() end

local initMsg = HAS_FTI
    and "v8.8 ✓ HeadEdge+FTI | coin→coin | map-scoped nocollide"
    or  "v8.8 ✓ HeadEdge | coin→coin | map-scoped nocollide"
notify("CoinMaster", initMsg, 4)
