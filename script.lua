-- ════════════════════════════════════
-- COINMASTER MM2 v5.0
-- by dj | engine rewrite | oct 2026
-- ════════════════════════════════════
-- [CRIT FIX] FTI аргументы: firetouchinterest(coinPart, hrp, 0/1) — в v4 было наоборот
-- [NEW] smoothTP: lerp + velocity=zero каждый шаг → нет "invalid position"
-- [NEW] NoCollide-система: workspace BasePart → CanCollide=false клиентски
-- [NEW] DescendantAdded watcher: новые части тоже получают NoCollide
-- [OPT] Дебаунс _collectedCoins: нет двойного счёта
-- [OPT] Кэш монет, инвалидация между раундами
-- [FIX] Счёт монет: только в основном цикле через дебаунс
-- ════════════════════════════════════

if getgenv().CM_LOADED then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "CoinMaster"; Text = "Уже запущен!"; Duration = 3;
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
    DelayMin       = 1.8,
    DelayMax       = 3.2,
    CoinType       = "Coin_Server",
    StealthMode    = true,
    ImproveFPS     = false,
    ShowStats      = true,
    InvisCollect   = true,    -- FTI под картой (ноль видимости)
    HeadEdgeOffset = 3.0,     -- R6: HRP.Y = coin.Y - 3.0
    SmoothDur      = 0.18,    -- секунды lerp (HeadEdge)
    NoCollide      = true,    -- клиентский CanCollide=false для workspace
}

-- Проверяем FTI в этом экзекуторе
local HAS_FTI = typeof(firetouchinterest) == "function"

-- ════ СТАТИСТИКА ═════════════════════
local STATS = {
    CoinsThisRound = 0,
    CoinsTotal     = 0,
    RoundsPlayed   = 0,
    SessionStart   = os.clock(),
}
-- Дебаунс: instance → true после сбора. Сбрасывается между раундами.
local _collectedCoins = {}

-- ════ БЕЗОПАСНОЕ МЕСТО ═══════════════
-- Y = -50: ниже карты, выше killplane MM2 (обычно < -100)
local HIDE_X = math.random(-8, 8)
local HIDE_Z = math.random(-8, 8)
local HIDE_Y = -50

local safePart = Instance.new("Part")
safePart.Anchored     = true
safePart.Massless     = true
safePart.Transparency = 1
safePart.CanCollide   = true
safePart.Size         = Vector3.new(2048, 0.5, 2048)
safePart.CFrame       = CFrame.new(HIDE_X, HIDE_Y - 1, HIDE_Z)
safePart.Parent       = workspace

local hideSpot = CFrame.new(
    HIDE_X + math.random(-4, 4) * 0.05,
    HIDE_Y + 1,
    HIDE_Z + math.random(-4, 4) * 0.05
)

-- ════ NO-COLLIDE СИСТЕМА ═════════════
-- Клиентски выключаем CanCollide на всех workspace.BasePart
-- кроме safePart и частей персонажа.
-- → Фазинг сквозь геометрию без physics bounce.
-- → Сервер ничего не видит — только локальный physics.

local noCollideConn = nil

local function shouldSkipPart(part)
    if part == safePart then return true end
    local char = LP.Character
    if char and part:IsDescendantOf(char) then return true end
    return false
end

local function applyNoCollide(part)
    if shouldSkipPart(part) then return end
    pcall(function() part.CanCollide = false end)
end

local function enableNoCollide()
    if noCollideConn then return end
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") then applyNoCollide(v) end
    end
    noCollideConn = workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("BasePart") then
            task.defer(function()
                if obj and obj.Parent then applyNoCollide(obj) end
            end)
        end
    end)
end

local function stopNoCollide()
    if noCollideConn then
        noCollideConn:Disconnect()
        noCollideConn = nil
    end
    safePart.CanCollide = true -- safePart остаётся твёрдой всегда
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

-- Плавный TP: lerp за duration секунд, velocity = zero каждый шаг.
-- Smoothstep (t²(3-2t)): мягкий старт и стоп → не триггерит speed-чеки.
-- Прерывается если CFG.Enabled = false или персонаж умер.
local function smoothTP(targetCF, duration)
    duration = duration or CFG.SmoothDur
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local startCF = hrp.CFrame
    local elapsed = 0

    repeat
        local dt = task.wait(0.016)
        elapsed   = elapsed + dt
        local t   = math.min(elapsed / duration, 1)
        local a   = t * t * (3 - 2 * t) -- smoothstep

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
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title; Text = text; Duration = dur or 3;
        })
    end)
end

-- ════ ПОИСК КОНТЕЙНЕРА ═══════════════
local _cachedContainer = nil

local function findContainer()
    if _cachedContainer and _cachedContainer.Parent then
        return _cachedContainer
    end
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
    Coin_Server = true, Coin = true,
    BeachBall   = true, Shell = true,
    Candy       = true, SnowToken = true, Egg = true,
}

local function findCoins()
    local coins, seen = {}, {}
    local container = findContainer()
    if not container then return coins end

    -- Метод 1: TouchTransmitter (самый точный)
    for _, v in ipairs(container:GetDescendants()) do
        if v:IsA("TouchTransmitter") then
            local part = v.Parent
            if part and part:IsA("BasePart") and not seen[part]
            and part:IsDescendantOf(workspace) then
                seen[part] = true
                table.insert(coins, part)
            end
        end
    end

    -- Метод 2: По имени
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
                    seen[part] = true
                    table.insert(coins, part)
                end
            end
        end
    end

    -- Метод 3: Атрибут CoinID
    if #coins == 0 then
        for _, v in ipairs(container:GetDescendants()) do
            if v:IsA("BasePart") and not seen[v] then
                local ok, attr = pcall(function() return v:GetAttribute("CoinID") end)
                if ok and attr then
                    seen[v] = true
                    table.insert(coins, v)
                end
            end
        end
    end

    return coins
end

-- ════ ФИЛЬТР ТИПА МОНЕТЫ ════════════
local function coinMatchesType(coinPart)
    if CFG.CoinType == "All" then return true end
    local ok, attr = pcall(function() return coinPart:GetAttribute("CoinID") end)
    if ok and attr then return attr == CFG.CoinType end
    if coinPart.Name == CFG.CoinType then return true end
    if coinPart.Parent and coinPart.Parent.Name == CFG.CoinType then return true end
    return false
end

-- ════ СБОР МОНЕТЫ ════════════════════
--
-- [v5 CRIT FIX] FTI порядок аргументов:
--   ПРАВИЛЬНО:    firetouchinterest(coinPart, hrp, 0)  -- монета первая
--   НЕПРАВИЛЬНО:  firetouchinterest(hrp, coinPart, 0)  -- так было в v4 → FTI не работал
--
-- [v5 NEW] HeadEdge:
--   smoothTP к монете → task.wait(0.06) → smoothTP обратно
--   CanCollide=false на workspace → нет physics bounce → нет "invalid position"
--
local function collectCoin(hrp, coinPart)
    if not coinPart or not coinPart.Parent then return false end
    if not coinPart:IsDescendantOf(workspace) then return false end

    if CFG.InvisCollect and HAS_FTI then
        -- ── FTI: персонаж не двигается ───────────────────────────────
        pcall(firetouchinterest, coinPart, hrp, 0)   -- [v5 FIX]
        task.wait(0.08)
        pcall(firetouchinterest, coinPart, hrp, 1)
        return true
    else
        -- ── HeadEdge: smooth lerp к монете и обратно ─────────────────
        local jitter = Vector3.new(
            (math.random() - 0.5) * 0.4,
            0,
            (math.random() - 0.5) * 0.4
        )
        local targetCF = CFrame.new(
            coinPart.Position.X + jitter.X,
            coinPart.Position.Y - CFG.HeadEdgeOffset,
            coinPart.Position.Z + jitter.Z
        )
        smoothTP(targetCF)       -- плавно летим к монете
        task.wait(0.06)
        smoothTP(hideSpot)       -- плавно возвращаемся под карту
        return true
    end
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

-- ════ ФЛАГ СМЕРТИ ════════════════════
local deadThisRound = false

local function hookCharacter(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if hum then
        hum.Died:Connect(function() deadThisRound = true end)
    end
end

LP.CharacterAdded:Connect(function(char)
    deadThisRound = false
    hookCharacter(char)
    if CFG.Enabled then
        task.wait(0.3)
        safeTP(hideSpot)
        -- Переприменяем NoCollide после респавна (новые части персонажа нужно исключить)
        if CFG.NoCollide then
            task.delay(0.1, enableNoCollide)
        end
    end
end)
if LP.Character then
    task.spawn(hookCharacter, LP.Character)
end

-- ════ СОСТОЯНИЕ РАУНДА ═══════════════
local farmActive = false
local bagFull    = false

-- Poll-детект (основной — не зависит от ремоутов)
task.spawn(function()
    local lastCount = 0
    while true do
        task.wait(2)
        local coins = findCoins()
        local count = #coins

        if count > 0 and not farmActive then
            farmActive    = true
            deadThisRound = false
        elseif count == 0 and lastCount > 0 then
            farmActive           = false
            bagFull              = false
            STATS.RoundsPlayed  += 1
            STATS.CoinsThisRound = 0
            _cachedContainer     = nil
            _collectedCoins      = {} -- сбрасываем дебаунс
        end
        lastCount = count
    end
end)

-- Ремоуты (бонус: faster events + AutoReset через мешок)
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
        -- Используем только для детекта полного мешка (счёт в основном цикле)
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
            farmActive           = true
            deadThisRound        = false
            bagFull              = false
            STATS.RoundsPlayed  += 1
            STATS.CoinsThisRound = 0
            _cachedContainer     = nil
            _collectedCoins      = {}
            if CFG.Enabled then safeTP(hideSpot) end
        end)
    end

    if RoundEnd then
        RoundEnd.OnClientEvent:Connect(function()
            farmActive = false
            bagFull    = false
        end)
    end
end)

-- Mid-inject: если скрипт инжектнули в активный раунд
task.delay(2, function()
    if not farmActive then
        local coins = findCoins()
        if #coins > 0 then farmActive = true end
    end
end)

-- ════ ОСНОВНОЙ ЦИКЛ ══════════════════
task.spawn(function()
    while true do
        if CFG.Enabled and farmActive and not bagFull and not deadThisRound then
            local hrp = getHRP()
            if hrp then
                local coins = findCoins()

                if #coins > 0 then
                    local useFTI = CFG.InvisCollect and HAS_FTI

                    -- В HeadEdge: начинаем с hideSpot
                    if not useFTI then safeTP(hideSpot) end

                    -- Сортируем по дистанции от hideSpot (ближние → меньше движения)
                    local hidePos = hideSpot.Position
                    table.sort(coins, function(a, b)
                        return (a.Position - hidePos).Magnitude < (b.Position - hidePos).Magnitude
                    end)

                    for _, coin in ipairs(coins) do
                        if bagFull or not CFG.Enabled then break end
                        if not coin or not coin.Parent then continue end
                        if _collectedCoins[coin] then continue end         -- дебаунс
                        if not coinMatchesType(coin) then continue end
                        if CFG.StealthMode and isMurdererNearby(coin.Position) then continue end

                        hrp = getHRP()
                        if not hrp then break end

                        local ok = collectCoin(hrp, coin)
                        if ok then
                            -- Единственное место счёта — нет двойного учёта
                            _collectedCoins[coin]  = true
                            STATS.CoinsThisRound  += 1
                            STATS.CoinsTotal      += 1
                        end

                        task.wait(0.10 + math.random() * 0.12)
                    end
                else
                    if farmActive then farmActive = false end
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

-- ════ GUI ════════════════════════════
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
Main.Size              = UDim2.new(0, 265, 0, 530)
Main.Position          = UDim2.new(0, 16, 0.5, -265)
Main.BackgroundColor3  = Color3.fromRGB(12, 12, 16)
Main.BorderSizePixel   = 0
Main.ClipsDescendants  = true
Main.Parent            = ScreenGui

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)

local mainStroke = Instance.new("UIStroke", Main)
mainStroke.Color       = Color3.fromRGB(255, 210, 0)
mainStroke.Thickness   = 1.5
mainStroke.Transparency = 0.4

-- Header
local Header = Instance.new("Frame", Main)
Header.Size             = UDim2.new(1, 0, 0, 46)
Header.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
Header.BorderSizePixel  = 0
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 12)

local headerFix = Instance.new("Frame", Header)
headerFix.Size             = UDim2.new(1, 0, 0.5, 0)
headerFix.Position         = UDim2.new(0, 0, 0.5, 0)
headerFix.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
headerFix.BorderSizePixel  = 0

local TitleLabel = Instance.new("TextLabel", Header)
TitleLabel.Size                = UDim2.new(1, -46, 1, 0)
TitleLabel.Position            = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text                = "🪙 CoinMaster MM2 v5.0"
TitleLabel.TextColor3          = Color3.fromRGB(255, 210, 0)
TitleLabel.TextSize            = 13
TitleLabel.Font                = Enum.Font.GothamBold
TitleLabel.TextXAlignment      = Enum.TextXAlignment.Left

local MinBtn = Instance.new("TextButton", Header)
MinBtn.Size             = UDim2.new(0, 30, 0, 30)
MinBtn.Position         = UDim2.new(1, -38, 0, 8)
MinBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
MinBtn.BorderSizePixel  = 0
MinBtn.Text             = "—"
MinBtn.TextColor3       = Color3.fromRGB(200, 200, 215)
MinBtn.TextSize         = 14
MinBtn.Font             = Enum.Font.GothamBold
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

-- Content
local Content = Instance.new("Frame", Main)
Content.Name              = "Content"
Content.Size              = UDim2.new(1, 0, 1, -46)
Content.Position          = UDim2.new(0, 0, 0, 46)
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

-- ── Фабрики ──────────────────────────
local function makeLabel(txt, col, sz, order)
    local lbl = Instance.new("TextLabel", Content)
    lbl.Size                    = UDim2.new(1, 0, 0, 16)
    lbl.BackgroundTransparency  = 1
    lbl.Text                    = txt
    lbl.TextColor3              = col or Color3.fromRGB(175, 175, 195)
    lbl.TextSize                = sz or 11
    lbl.Font                    = Enum.Font.Gotham
    lbl.TextXAlignment          = Enum.TextXAlignment.Left
    lbl.LayoutOrder             = order or 0
    return lbl
end

local function makeDivider(order)
    local d = Instance.new("Frame", Content)
    d.Size             = UDim2.new(1, 0, 0, 1)
    d.BackgroundColor3 = Color3.fromRGB(38, 38, 52)
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
    lbl.Size                    = UDim2.new(0.72, 0, 1, 0)
    lbl.BackgroundTransparency  = 1
    lbl.Text                    = label
    lbl.TextColor3              = Color3.fromRGB(210, 210, 220)
    lbl.TextSize                = 12
    lbl.Font                    = Enum.Font.Gotham
    lbl.TextXAlignment          = Enum.TextXAlignment.Left

    local track = Instance.new("Frame", row)
    track.Size             = UDim2.new(0, 42, 0, 22)
    track.Position         = UDim2.new(1, -42, 0.5, -11)
    track.BackgroundColor3 = Color3.fromRGB(38, 38, 52)
    track.BorderSizePixel  = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local ball = Instance.new("Frame", track)
    ball.Size             = UDim2.new(0, 16, 0, 16)
    ball.Position         = UDim2.new(0, 3, 0.5, -8)
    ball.BackgroundColor3 = Color3.fromRGB(155, 155, 170)
    ball.BorderSizePixel  = 0
    Instance.new("UICorner", ball).CornerRadius = UDim.new(1, 0)

    local function refresh()
        local on = CFG[cfgKey]
        TweenService:Create(track, TweenInfo.new(0.18), {
            BackgroundColor3 = on
                and Color3.fromRGB(255, 195, 0)
                or  Color3.fromRGB(38, 38, 52)
        }):Play()
        TweenService:Create(ball, TweenInfo.new(0.18), {
            Position = on
                and UDim2.new(0, 23, 0.5, -8)
                or  UDim2.new(0, 3, 0.5, -8),
            BackgroundColor3 = on
                and Color3.fromRGB(255, 255, 255)
                or  Color3.fromRGB(155, 155, 170)
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
end

-- ── Селектор типа монеты ──
local function makeCoinSelector(order)
    local row = Instance.new("Frame", Content)
    row.Size                   = UDim2.new(1, 0, 0, 30)
    row.BackgroundTransparency = 1
    row.LayoutOrder            = order

    local lbl = Instance.new("TextLabel", row)
    lbl.Size                    = UDim2.new(0.45, 0, 1, 0)
    lbl.BackgroundTransparency  = 1
    lbl.Text                    = "Тип монет"
    lbl.TextColor3              = Color3.fromRGB(210, 210, 220)
    lbl.TextSize                = 12
    lbl.Font                    = Enum.Font.Gotham
    lbl.TextXAlignment          = Enum.TextXAlignment.Left

    local types = {"Coin_Server", "All", "BeachBall", "Shell", "Candy"}
    local idx = 1
    for i, t in ipairs(types) do
        if t == CFG.CoinType then idx = i end
    end

    local typeBtn = Instance.new("TextButton", row)
    typeBtn.Size             = UDim2.new(0.52, 0, 0, 24)
    typeBtn.Position         = UDim2.new(0.48, 0, 0.5, -12)
    typeBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    typeBtn.BorderSizePixel  = 0
    typeBtn.Text             = "◀ " .. types[idx] .. " ▶"
    typeBtn.TextColor3       = Color3.fromRGB(255, 210, 0)
    typeBtn.TextSize         = 11
    typeBtn.Font             = Enum.Font.GothamBold
    Instance.new("UICorner", typeBtn).CornerRadius = UDim.new(0, 6)

    typeBtn.MouseButton1Click:Connect(function()
        idx            = idx % #types + 1
        CFG.CoinType   = types[idx]
        typeBtn.Text   = "◀ " .. types[idx] .. " ▶"
    end)
end

-- ── Кнопка СТАРТ/СТОП ───────────────
makeLabel(" ФАРМ", Color3.fromRGB(255, 210, 0), 11, 1)

local startBtn = Instance.new("TextButton", Content)
startBtn.Size             = UDim2.new(1, 0, 0, 36)
startBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
startBtn.BorderSizePixel  = 0
startBtn.Text             = "▶ Начать фарм"
startBtn.TextColor3       = Color3.fromRGB(195, 195, 210)
startBtn.TextSize         = 13
startBtn.Font             = Enum.Font.GothamBold
startBtn.LayoutOrder      = 2
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 8)

local startBtnStroke = Instance.new("UIStroke", startBtn)
startBtnStroke.Color       = Color3.fromRGB(255, 210, 0)
startBtnStroke.Thickness   = 1
startBtnStroke.Transparency = 0.6

local function refreshStartBtn()
    if CFG.Enabled then
        TweenService:Create(startBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(175, 120, 0)
        }):Play()
        startBtn.Text          = "⏹ Остановить"
        startBtn.TextColor3    = Color3.fromRGB(255, 255, 255)
        startBtnStroke.Transparency = 0
    else
        TweenService:Create(startBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(28, 28, 38)
        }):Play()
        startBtn.Text          = "▶ Начать фарм"
        startBtn.TextColor3    = Color3.fromRGB(195, 195, 210)
        startBtnStroke.Transparency = 0.6
    end
end

startBtn.MouseButton1Click:Connect(function()
    CFG.Enabled = not CFG.Enabled
    if CFG.Enabled then
        bagFull = false
        local coins = findCoins()
        farmActive  = (#coins > 0)
        safeTP(hideSpot)
        if CFG.NoCollide then enableNoCollide() end
        local mode = (CFG.InvisCollect and HAS_FTI) and "FTI (невидимый)" or "HeadEdge (smooth)"
        notify("CoinMaster", "Фарм запущен 🪙 [" .. mode .. "]", 3)
    else
        stopNoCollide()
        notify("CoinMaster", "Фарм остановлен.", 2)
    end
    refreshStartBtn()
end)

-- ── Настройки ───────────────────────
makeDivider(3)
makeLabel(" НАСТРОЙКИ", Color3.fromRGB(255, 210, 0), 11, 4)

makeCoinSelector(5)

makeToggle("Anti-AFK", "AntiAFK", 6, function(v)
    if v then startAntiAFK() end
end)
makeToggle("Авто-сброс при полном мешке", "AutoReset", 7)
makeToggle("Stealth (обход убийцы)", "StealthMode", 8)
makeToggle("InvisCollect (FTI под картой)", "InvisCollect", 9)
makeToggle("NoCollide (фазинг сквозь стены)", "NoCollide", 10, function(v)
    if CFG.Enabled then
        if v then enableNoCollide() else stopNoCollide() end
    end
end)
makeToggle("Improve FPS (убрать акс.)", "ImproveFPS", 11, function(v)
    if v then improveFPS() end
end)

-- ── Статус FTI ──────────────────────
local ftiLabel = Instance.new("TextLabel", Content)
ftiLabel.Size                   = UDim2.new(1, 0, 0, 14)
ftiLabel.BackgroundTransparency = 1
ftiLabel.Text                   = HAS_FTI
    and "✓ FTI доступен → невидимый сбор"
    or  "✗ FTI недоступен → HeadEdge (smooth lerp)"
ftiLabel.TextColor3             = HAS_FTI
    and Color3.fromRGB(80, 190, 90)
    or  Color3.fromRGB(200, 140, 50)
ftiLabel.TextSize               = 10
ftiLabel.Font                   = Enum.Font.Gotham
ftiLabel.TextXAlignment         = Enum.TextXAlignment.Left
ftiLabel.LayoutOrder            = 12

-- ── Статистика ───────────────────────
makeDivider(13)
makeLabel(" СТАТИСТИКА", Color3.fromRGB(255, 210, 0), 11, 14)

local statLabel = Instance.new("TextLabel", Content)
statLabel.Size                   = UDim2.new(1, 0, 0, 80)
statLabel.BackgroundTransparency = 1
statLabel.Text                   = "Ожидание раунда..."
statLabel.TextColor3             = Color3.fromRGB(155, 155, 175)
statLabel.TextSize               = 11
statLabel.Font                   = Enum.Font.Gotham
statLabel.TextXAlignment         = Enum.TextXAlignment.Left
statLabel.TextWrapped            = true
statLabel.LayoutOrder            = 15

-- ── Перетаскивание ───────────────────
local dragging, dragStart, startPos = false, nil, nil
Header.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        dragging  = true
        dragStart = inp.Position
        startPos  = Main.Position
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

-- ── Минимизация ──────────────────────
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenService:Create(Main, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {
        Size = minimized
            and UDim2.new(0, 265, 0, 46)
            or  UDim2.new(0, 265, 0, 530)
    }):Play()
    MinBtn.Text = minimized and "+" or "—"
end)

-- ════ ОБНОВЛЕНИЕ СТАТИСТИКИ ══════════
task.spawn(function()
    while true do
        task.wait(1)
        if CFG.ShowStats then
            local elapsed = math.max(1, math.floor(os.clock() - STATS.SessionStart))
            local mins    = math.floor(elapsed / 60)
            local secs    = elapsed % 60
            local rate    = math.floor(STATS.CoinsTotal / elapsed * 60)
            local coinCount = #findCoins()
            local mode = (CFG.InvisCollect and HAS_FTI) and "FTI" or "HeadEdge"

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
                status = "🟡 Ждём раунд"
            end

            statLabel.Text = string.format(
                "%s\nРаунд: %d | Всего: %d\nСессия: %02d:%02d | ~%d/мин\nРаундов: %d",
                status,
                STATS.CoinsThisRound,
                STATS.CoinsTotal,
                mins, secs,
                rate,
                STATS.RoundsPlayed
            )
        end
    end
end)

-- ════ СТАРТ ══════════════════════════
if CFG.AntiAFK then startAntiAFK() end

local initMsg = HAS_FTI
    and "v5.0 ✓ FTI режим (фикс аргументов)"
    or  "v5.0 ✓ HeadEdge smooth (NoCollide)"
notify("CoinMaster", initMsg, 4)
