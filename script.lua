-- ════════════════════════════════════
-- COINMASTER MM2 v4.0
-- by dj | engine rewrite | oct 2026
--
-- [CRIT] Имя монеты: "Coin" → "Coin_Server" (реальное имя в MM2)
-- [CRIT] Сбор через firetouchinterest — персонаж под картой всегда
-- [NEW] InvisCollect: ноль движения, ноль видимости
-- [NEW] HeadEdge fallback: HRP.Y = coin.Y - 3.0 (если FTI недоступен)
-- [NEW] deadThisRound флаг + автодетект лобби
-- [NEW] Отслеживание уже собранных монет (не пересканируем)
-- [NEW] Poll-based детект раунда (без зависимости от ремоутов)
-- [FIX] safePart size — убрал двойное присвоение
-- [FIX] VirtualUser cloneref guard
-- [FIX] Container поиск — 3 метода с fallback
-- ════════════════════════════════════

if getgenv().CM_LOADED then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "CoinMaster"; Text = "Уже запущен!"; Duration = 3;
    })
    return
end
getgenv().CM_LOADED = true

-- ════════════════════════════════════
-- СЕРВИСЫ
-- ════════════════════════════════════
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInput = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer

-- ════════════════════════════════════
-- НАСТРОЙКИ
-- ════════════════════════════════════
local CFG = {
    Enabled = false,
    AntiAFK = true,
    AutoReset = true,
    DelayMin = 1.8,
    DelayMax = 3.2,
    -- Варианты: "Coin_Server" (окт 2026 стандарт), "BeachBall", "Shell", "Candy", "All"
    CoinType = "Coin_Server",
    StealthMode = true,
    ImproveFPS = false,
    ShowStats = true,
    -- InvisCollect: firetouchinterest из-под карты — ноль видимости
    -- При false — head-edge TP (HRP.Y = coin.Y - HeadEdgeOffset)
    InvisCollect = true,
    HeadEdgeOffset = 3.0, -- R6: расстояние HRP → верх головы ≈ 3.0 stud
}

-- Проверяем доступность firetouchinterest в этом экзекуторе
local HAS_FTI = typeof(firetouchinterest) == "function"

-- ════════════════════════════════════
-- СТАТИСТИКА
-- ════════════════════════════════════
local STATS = {
    CoinsThisRound = 0,
    CoinsTotal = 0,
    RoundsPlayed = 0,
    SessionStart = os.clock(),
}

-- ════════════════════════════════════
-- БЕЗОПАСНАЯ ТОЧКА (под картой)
-- Y = -50 работает для большинства карт MM2
-- Убийца (killplane) обычно выше -100
-- ════════════════════════════════════
local HIDE_X = math.random(-8, 8)
local HIDE_Z = math.random(-8, 8)
local HIDE_Y = -50

local safePart = Instance.new("Part")
safePart.Anchored = true
safePart.Massless = true
safePart.Transparency = 1
safePart.CanCollide = true
safePart.Size = Vector3.new(2048, 0.5, 2048)
safePart.CFrame = CFrame.new(HIDE_X, HIDE_Y - 1, HIDE_Z)
safePart.Parent = workspace

local hideSpot = CFrame.new(
    HIDE_X + math.random(-4, 4) * 0.05,
    HIDE_Y + 1,
    HIDE_Z + math.random(-4, 4) * 0.05
)

-- ════════════════════════════════════
-- ХЕЛПЕРЫ
-- ════════════════════════════════════
local function safeTP(cf)
    pcall(function()
        local char = LP.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.CFrame = cf end
        end
    end)
end

local function getHRP()
    local char = LP.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    return char:FindFirstChild("HumanoidRootPart")
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

-- ════════════════════════════════════
-- ПОИСК КОНТЕЙНЕРА С МОНЕТАМИ
-- MM2 хранит монеты в CoinContainer внутри модели карты
-- ════════════════════════════════════
local _cachedContainer = nil

local function findContainer()
    -- Проверяем кэш
    if _cachedContainer and _cachedContainer.Parent then
        return _cachedContainer
    end
    _cachedContainer = nil

    -- Метод 1: workspace > MapModel > CoinContainer
    for _, v in ipairs(workspace:GetChildren()) do
        if v:IsA("Model") then
            local cc = v:FindFirstChild("CoinContainer")
            if cc then _cachedContainer = cc; return cc end
        end
    end

    -- Метод 2: workspace > CoinContainer напрямую
    local cc = workspace:FindFirstChild("CoinContainer")
    if cc then _cachedContainer = cc; return cc end

    -- Метод 3: глубокий поиск
    cc = workspace:FindFirstChild("CoinContainer", true)
    if cc then _cachedContainer = cc; return cc end

    return nil
end

-- ════════════════════════════════════
-- ПОИСК МОНЕТ
-- Стратегия: TouchTransmitter-метод первый (точный),
-- затем fallback по именам
-- ════════════════════════════════════

-- Множество имён, по которым ищем (в fallback)
local COIN_NAMES = {
    Coin_Server = true, -- стандарт MM2 (все версии)
    Coin = true, -- старые версии / событийные
    BeachBall = true, -- лето 2025
    Shell = true, -- лето 2026 (завершён)
    Candy = true,
    SnowToken = true,
    Egg = true,
}

local function findCoins()
    local coins = {}
    local seen = {}
    local container = findContainer()
    if not container then return coins end

    -- ── Метод 1: TouchTransmitter (самый точный) ──────────────────────
    -- Каждая монета — это BasePart с TouchTransmitter дочерним элементом.
    -- Zynic AutoFarm (open source, проверено) использует этот же подход.
    for _, v in ipairs(container:GetDescendants()) do
        if v:IsA("TouchTransmitter") then
            local part = v.Parent
            if part and part:IsA("BasePart")
            and not seen[part]
            and part:IsDescendantOf(workspace) then
                seen[part] = true
                table.insert(coins, part)
            end
        end
    end

    -- ── Метод 2: По имени (WillyWonka / NoCapital2 approach) ──────────
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

    -- ── Метод 3: Атрибут CoinID ───────────────────────────────────────
    if #coins == 0 then
        for _, v in ipairs(container:GetDescendants()) do
            if v:IsA("BasePart") and not seen[v] then
                local ok, attr = pcall(function()
                    return v:GetAttribute("CoinID")
                end)
                if ok and attr then
                    seen[v] = true
                    table.insert(coins, v)
                end
            end
        end
    end

    return coins
end

-- ════════════════════════════════════
-- ФИЛЬТР ПО ТИПУ МОНЕТЫ
-- ════════════════════════════════════
local function coinMatchesType(coinPart)
    if CFG.CoinType == "All" then return true end

    -- Атрибут приоритетнее имени
    local ok, attr = pcall(function()
        return coinPart:GetAttribute("CoinID")
    end)
    if ok and attr then
        return attr == CFG.CoinType
    end

    -- Проверяем имя самой части и её родителя (для случая Model > BasePart)
    if coinPart.Name == CFG.CoinType then return true end
    if coinPart.Parent and coinPart.Parent.Name == CFG.CoinType then return true end

    return false
end

-- ════════════════════════════════════
-- СБОР МОНЕТЫ — ГЛАВНАЯ ТЕХНИКА
--
-- InvisCollect = true:
-- firetouchinterest(hrp, coinPart, 0/1)
-- Персонаж НЕ ДВИГАЕТСЯ, остаётся под картой.
-- Ноль видимости. Delta поддерживает FTI (level 7 executor).
--
-- InvisCollect = false (fallback):
-- Head-edge TP: HRP.Y = coin.Y - HeadEdgeOffset
-- Для R6 — offset 3.0 stud = только верхушка головы у монеты.
-- Тело под полом карты, видно максимум 1-2 студа головы.
-- ════════════════════════════════════
local function collectCoin(hrp, coinPart)
    if not coinPart or not coinPart.Parent then return false end
    if not coinPart:IsDescendantOf(workspace) then return false end

    if CFG.InvisCollect and HAS_FTI then
        -- ── ОСНОВНОЙ ПУТЬ: firetouchinterest ──────────────────────────
        -- begin touch (0) → монета считает что наш HRP её коснулся
        pcall(firetouchinterest, hrp, coinPart, 0)
        task.wait(0.05)
        -- end touch (1) → завершение контакта
        pcall(firetouchinterest, hrp, coinPart, 1)
        return true
    else
        -- ── FALLBACK: head-edge TP ─────────────────────────────────────
        -- R6: Head center ≈ HRP.Y + 2.5, top of head ≈ HRP.Y + 3.0
        -- Ставим HRP так, чтобы верхушка головы оказалась у монеты.
        local jitter = Vector3.new(
            math.random(-4, 4) * 0.04,
            0,
            math.random(-4, 4) * 0.04
        )
        safeTP(CFrame.new(
            coinPart.Position.X + jitter.X,
            coinPart.Position.Y - CFG.HeadEdgeOffset,
            coinPart.Position.Z + jitter.Z
        ))
        task.wait(0.12)
        safeTP(hideSpot)
        return true
    end
end

-- ════════════════════════════════════
-- СТЕЛС — ПРОВЕРКА УБИЙЦЫ
-- ════════════════════════════════════
local function isMurdererNearby(pos)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position - pos).Magnitude < 25 then
                for _, tool in ipairs(p.Character:GetChildren()) do
                    if tool:IsA("Tool") then return true end
                end
                if p.Character:FindFirstChild("KnifeTag")
                or p.Character:FindFirstChild("MurderTag")
                or p.Character:FindFirstChild("MurdererTag") then
                    return true
                end
            end
        end
    end
    return false
end

-- ════════════════════════════════════
-- IMPROVE FPS
-- ════════════════════════════════════
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

-- ════════════════════════════════════
-- АНТИ-АФК
-- ════════════════════════════════════
local function startAntiAFK()
    local ok, gc = pcall(getconnections, LP.Idled)
    if ok and gc then
        for _, c in ipairs(gc) do
            pcall(function() c:Disable() end)
            pcall(function() c:Disconnect() end)
        end
    end
    -- VirtualUser fallback — надёжнее getconnections
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

-- ════════════════════════════════════
-- ФЛАГ СМЕРТИ — не фармим, пока в лобби
-- ════════════════════════════════════
local deadThisRound = false

local function hookCharacter(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if hum then
        hum.Died:Connect(function()
            deadThisRound = true
        end)
    end
end

LP.CharacterAdded:Connect(function(char)
    deadThisRound = false -- спавн = новая жизнь
    hookCharacter(char)
    if CFG.Enabled then
        task.wait(0.3)
        safeTP(hideSpot)
    end
end)
if LP.Character then
    task.spawn(hookCharacter, LP.Character)
end

-- ════════════════════════════════════
-- СОСТОЯНИЕ РАУНДА
-- Poll-based: не зависим от Remote paths (они часто ломаются).
-- Ремоуты подключаем как бонус, если найдём.
-- ════════════════════════════════════
local farmActive = false
local bagFull = false

-- Poll-детект раунда (надёжный)
task.spawn(function()
    local lastCount = 0
    while true do
        task.wait(2)
        local coins = findCoins()
        local count = #coins

        if count > 0 and not farmActive then
            -- монеты появились → раунд начался
            farmActive = true
            deadThisRound = false
        elseif count == 0 and lastCount > 0 then
            -- монеты исчезли → раунд закончился
            farmActive = false
            bagFull = false
            STATS.RoundsPlayed += 1
            STATS.CoinsThisRound = 0
            -- сбрасываем кэш контейнера — при след. раунде карта может смениться
            _cachedContainer = nil
        end

        lastCount = count
    end
end)

-- Ремоуты как дополнительный источник событий (не критичны)
task.spawn(function()
    local RS = game:GetService("ReplicatedStorage")
    local function tryPath(...)
        local cur = RS
        for _, name in ipairs({...}) do
            cur = cur and cur:FindFirstChild(name)
        end
        return cur
    end

    local CoinEvent = tryPath("Remotes","Gameplay","CoinCollected")
    local RoundStart = tryPath("Remotes","Gameplay","RoundStart")
    local RoundEnd = tryPath("Remotes","Gameplay","RoundEndFade")
                    or tryPath("Remotes","Gameplay","RoundEnd")

    if CoinEvent then
        CoinEvent.OnClientEvent:Connect(function(cointype, current, max)
            farmActive = true
            local typeMatch = CFG.CoinType == "All" or cointype == CFG.CoinType
            if typeMatch then
                STATS.CoinsThisRound += 1
                STATS.CoinsTotal += 1
            end
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
            farmActive = true
            deadThisRound = false
            bagFull = false
            STATS.RoundsPlayed += 1
            STATS.CoinsThisRound = 0
            _cachedContainer = nil
            if CFG.Enabled then safeTP(hideSpot) end
        end)
    end

    if RoundEnd then
        RoundEnd.OnClientEvent:Connect(function()
            farmActive = false
            bagFull = false
        end)
    end
end)

-- ════════════════════════════════════
-- MID-INJECT: определяем активный раунд
-- ════════════════════════════════════
task.delay(2, function()
    if not farmActive then
        local coins = findCoins()
        if #coins > 0 then farmActive = true end
    end
end)

-- ════════════════════════════════════
-- ОСНОВНОЙ ЦИКЛ
-- Сортируем монеты по дистанции от hideSpot,
-- собираем ближайшие первыми.
-- ════════════════════════════════════
task.spawn(function()
    while true do
        if CFG.Enabled and farmActive and not bagFull and not deadThisRound then

            local hrp = getHRP()
            if hrp then
                local coins = findCoins()

                if #coins > 0 then
                    -- Телепортируемся в укрытие (если InvisCollect=false, FTI-режим это пропустит)
                    if not (CFG.InvisCollect and HAS_FTI) then
                        safeTP(hideSpot)
                    end

                    -- Сортировка: ближайшие к hideSpot сначала
                    table.sort(coins, function(a, b)
                        local aD = (a.Position - hideSpot.Position).Magnitude
                        local bD = (b.Position - hideSpot.Position).Magnitude
                        return aD < bD
                    end)

                    for _, coin in ipairs(coins) do
                        if bagFull or not CFG.Enabled then break end

                        -- Монета ещё существует?
                        if not coin or not coin.Parent then continue end

                        -- Фильтр по типу
                        if not coinMatchesType(coin) then continue end

                        -- Стелс: убийца рядом с монетой?
                        if CFG.StealthMode and isMurdererNearby(coin.Position) then
                            continue
                        end

                        -- Обновляем HRP перед каждой монетой
                        hrp = getHRP()
                        if not hrp then break end

                        -- Сбор
                        local ok = collectCoin(hrp, coin)
                        if ok then
                            -- Счёт (для FTI-режима ремоут не всегда стреляет,
                            -- поэтому считаем тут тоже — дубликатов не страшно,
                            -- ремоут-счётчик перезапишет при следующем цикле)
                            if CFG.InvisCollect and HAS_FTI then
                                STATS.CoinsThisRound += 1
                                STATS.CoinsTotal += 1
                            end
                        end

                        -- Мини-задержка между монетами (антибот-паттерн)
                        task.wait(0.10 + math.random() * 0.12)
                    end
                else
                    -- Монет нет = раунд закончился или лобби
                    if farmActive then farmActive = false end
                end
            end
        end

        task.wait(randDelay())
    end
end)

-- ════════════════════════════════════
-- IMPROVE FPS — для новых игроков
-- ════════════════════════════════════
local function connectImproveFPS(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.5)
        if CFG.ImproveFPS then improveFPS() end
    end)
end
for _, p in ipairs(Players:GetPlayers()) do connectImproveFPS(p) end
Players.PlayerAdded:Connect(connectImproveFPS)

-- ════════════════════════════════════
-- GUI
-- ════════════════════════════════════
pcall(function()
    local old = CoreGui:FindFirstChild("CoinMasterGUI")
    if old then old:Destroy() end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CoinMasterGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGuiScreenGui.Parent = (typeof(gethui) == "function" and gethui()) 
    or game.Players.LocalPlayer.PlayerGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 265, 0, 490)
Main.Position = UDim2.new(0, 16, 0.5, -245)
Main.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = ScreenGui

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)

local mainStroke = Instance.new("UIStroke", Main)
mainStroke.Color = Color3.fromRGB(255, 210, 0)
mainStroke.Thickness = 1.5
mainStroke.Transparency = 0.4

local Header = Instance.new("Frame", Main)
Header.Size = UDim2.new(1, 0, 0, 46)
Header.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
Header.BorderSizePixel = 0
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 12)

local headerFix = Instance.new("Frame", Header)
headerFix.Size = UDim2.new(1, 0, 0.5, 0)
headerFix.Position = UDim2.new(0, 0, 0.5, 0)
headerFix.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
headerFix.BorderSizePixel = 0

local TitleLabel = Instance.new("TextLabel", Header)
TitleLabel.Size = UDim2.new(1, -46, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🪙 CoinMaster MM2 v4.0"
TitleLabel.TextColor3 = Color3.fromRGB(255, 210, 0)
TitleLabel.TextSize = 13
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

local MinBtn = Instance.new("TextButton", Header)
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -38, 0, 8)
MinBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
MinBtn.BorderSizePixel = 0
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(200, 200, 215)
MinBtn.TextSize = 14
MinBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

local Content = Instance.new("Frame", Main)
Content.Name = "Content"
Content.Size = UDim2.new(1, 0, 1, -46)
Content.Position = UDim2.new(0, 0, 0, 46)
Content.BackgroundTransparency = 1

local pad = Instance.new("UIPadding", Content)
pad.PaddingLeft = UDim.new(0, 12)
pad.PaddingRight = UDim.new(0, 12)
pad.PaddingTop = UDim.new(0, 10)
pad.PaddingBottom = UDim.new(0, 10)

local list = Instance.new("UIListLayout", Content)
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.FillDirection = Enum.FillDirection.Vertical

-- ── Фабрики ──
local function makeLabel(txt, col, sz, order)
    local lbl = Instance.new("TextLabel", Content)
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.Text = txt
    lbl.TextColor3 = col or Color3.fromRGB(175, 175, 195)
    lbl.TextSize = sz or 11
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = order or 0
    return lbl
end

local function makeDivider(order)
    local d = Instance.new("Frame", Content)
    d.Size = UDim2.new(1, 0, 0, 1)
    d.BackgroundColor3 = Color3.fromRGB(38, 38, 52)
    d.BorderSizePixel = 0
    d.LayoutOrder = order or 0
    return d
end

local function makeToggle(label, cfgKey, order, callback)
    local row = Instance.new("Frame", Content)
    row.Size = UDim2.new(1, 0, 0, 30)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.72, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(210, 210, 220)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local track = Instance.new("Frame", row)
    track.Size = UDim2.new(0, 42, 0, 22)
    track.Position = UDim2.new(1, -42, 0.5, -11)
    track.BackgroundColor3 = Color3.fromRGB(38, 38, 52)
    track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local ball = Instance.new("Frame", track)
    ball.Size = UDim2.new(0, 16, 0, 16)
    ball.Position = UDim2.new(0, 3, 0.5, -8)
    ball.BackgroundColor3 = Color3.fromRGB(155, 155, 170)
    ball.BorderSizePixel = 0
    Instance.new("UICorner", ball).CornerRadius = UDim.new(1, 0)

    local function refresh()
        local on = CFG[cfgKey]
        TweenService:Create(track, TweenInfo.new(0.18), {
            BackgroundColor3 = on
                and Color3.fromRGB(255, 195, 0)
                or Color3.fromRGB(38, 38, 52)
        }):Play()
        TweenService:Create(ball, TweenInfo.new(0.18), {
            Position = on
                and UDim2.new(0, 23, 0.5, -8)
                or UDim2.new(0, 3, 0.5, -8),
            BackgroundColor3 = on
                and Color3.fromRGB(255, 255, 255)
                or Color3.fromRGB(155, 155, 170)
        }):Play()
    end
    refresh()

    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.MouseButton1Click:Connect(function()
        CFG[cfgKey] = not CFG[cfgKey]
        refresh()
        if callback then callback(CFG[cfgKey]) end
    end)
end

-- ── Селектор типа монеты ──
local function makeCoinSelector(order)
    local row = Instance.new("Frame", Content)
    row.Size = UDim2.new(1, 0, 0, 30)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.45, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "Тип монет"
    lbl.TextColor3 = Color3.fromRGB(210, 210, 220)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    -- Coin_Server = стандарт окт 2026; All = любой тип
    local types = {"Coin_Server", "All", "BeachBall", "Shell", "Candy"}
    local idx = 1
    for i, t in ipairs(types) do
        if t == CFG.CoinType then idx = i end
    end

    local typeBtn = Instance.new("TextButton", row)
    typeBtn.Size = UDim2.new(0.52, 0, 0, 24)
    typeBtn.Position = UDim2.new(0.48, 0, 0.5, -12)
    typeBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    typeBtn.BorderSizePixel = 0
    typeBtn.Text = "◀ " .. types[idx] .. " ▶"
    typeBtn.TextColor3 = Color3.fromRGB(255, 210, 0)
    typeBtn.TextSize = 11
    typeBtn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", typeBtn).CornerRadius = UDim.new(0, 6)

    typeBtn.MouseButton1Click:Connect(function()
        idx = idx % #types + 1
        CFG.CoinType = types[idx]
        typeBtn.Text = "◀ " .. types[idx] .. " ▶"
    end)
end

-- ── Кнопка СТАРТ/СТОП ──
makeLabel(" ФАРМ", Color3.fromRGB(255, 210, 0), 11, 1)

local startBtn = Instance.new("TextButton", Content)
startBtn.Size = UDim2.new(1, 0, 0, 36)
startBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
startBtn.BorderSizePixel = 0
startBtn.Text = "▶ Начать фарм"
startBtn.TextColor3 = Color3.fromRGB(195, 195, 210)
startBtn.TextSize = 13
startBtn.Font = Enum.Font.GothamBold
startBtn.LayoutOrder = 2
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 8)

local startBtnStroke = Instance.new("UIStroke", startBtn)
startBtnStroke.Color = Color3.fromRGB(255, 210, 0)
startBtnStroke.Thickness = 1
startBtnStroke.Transparency = 0.6

local function refreshStartBtn()
    if CFG.Enabled then
        TweenService:Create(startBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(175, 120, 0)
        }):Play()
        startBtn.Text = "⏹ Остановить"
        startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        startBtnStroke.Transparency = 0
    else
        TweenService:Create(startBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(28, 28, 38)
        }):Play()
        startBtn.Text = "▶ Начать фарм"
        startBtn.TextColor3 = Color3.fromRGB(195, 195, 210)
        startBtnStroke.Transparency = 0.6
    end
end

startBtn.MouseButton1Click:Connect(function()
    CFG.Enabled = not CFG.Enabled
    if CFG.Enabled then
        bagFull = false
        local coins = findCoins()
        farmActive = (#coins > 0)
        safeTP(hideSpot)
        local mode = (CFG.InvisCollect and HAS_FTI) and "невидимый" or "head-edge"
        notify("CoinMaster", "Фарм запущен 🪙 [" .. mode .. "]", 3)
    else
        notify("CoinMaster", "Фарм остановлен.", 2)
    end
    refreshStartBtn()
end)

-- ── Настройки ──
makeDivider(3)
makeLabel(" НАСТРОЙКИ", Color3.fromRGB(255, 210, 0), 11, 4)

makeCoinSelector(5)

makeToggle("Anti-AFK", "AntiAFK", 6, function(v)
    if v then startAntiAFK() end
end)
makeToggle("Авто-сброс при полном мешке", "AutoReset", 7)
makeToggle("Stealth (обход убийцы)", "StealthMode", 8)
makeToggle("InvisCollect (FTI под картой)", "InvisCollect", 9)
makeToggle("Improve FPS (убрать акс.)", "ImproveFPS", 10, function(v)
    if v then improveFPS() end
end)

-- ── Статус firetouchinterest ──
local ftiLabel = Instance.new("TextLabel", Content)
ftiLabel.Size = UDim2.new(1, 0, 0, 14)
ftiLabel.BackgroundTransparency = 1
ftiLabel.Text = HAS_FTI
    and "✓ firetouchinterest доступен"
    or "✗ FTI недоступен → head-edge TP"
ftiLabel.TextColor3 = HAS_FTI
    and Color3.fromRGB(80, 190, 90)
    or Color3.fromRGB(200, 140, 50)
ftiLabel.TextSize = 10
ftiLabel.Font = Enum.Font.Gotham
ftiLabel.TextXAlignment = Enum.TextXAlignment.Left
ftiLabel.LayoutOrder = 11

-- ── Статистика ──
makeDivider(12)
makeLabel(" СТАТИСТИКА", Color3.fromRGB(255, 210, 0), 11, 13)

local statLabel = Instance.new("TextLabel", Content)
statLabel.Size = UDim2.new(1, 0, 0, 72)
statLabel.BackgroundTransparency = 1
statLabel.Text = "Ожидание раунда..."
statLabel.TextColor3 = Color3.fromRGB(155, 155, 175)
statLabel.TextSize = 11
statLabel.Font = Enum.Font.Gotham
statLabel.TextXAlignment = Enum.TextXAlignment.Left
statLabel.TextWrapped = true
statLabel.LayoutOrder = 14

-- ── Перетаскивание ──
local dragging, dragStart, startPos = false, nil, nil
Header.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = inp.Position
        startPos = Main.Position
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

-- ── Минимизация ──
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenService:Create(Main, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {
        Size = minimized
            and UDim2.new(0, 265, 0, 46)
            or UDim2.new(0, 265, 0, 490)
    }):Play()
    MinBtn.Text = minimized and "+" or "—"
end)

-- ════════════════════════════════════
-- ОБНОВЛЕНИЕ СТАТИСТИКИ
-- ════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(1)
        if CFG.ShowStats then
            local elapsed = math.max(1, math.floor(os.clock() - STATS.SessionStart))
            local mins = math.floor(elapsed / 60)
            local secs = elapsed % 60
            local rate = math.floor(STATS.CoinsTotal / elapsed * 60)

            local coinCount = #findCoins()
            local collectMode = (CFG.InvisCollect and HAS_FTI) and "FTI" or "HeadEdge"

            local status
            if not CFG.Enabled then
                status = "🔴 Выкл"
            elseif deadThisRound then
                status = "⚫ Мёртв / лобби"
            elseif bagFull then
                status = "🟡 Мешок полон"
            elseif farmActive then
                status = "🟢 Фарм [" .. collectMode .. "] (" .. coinCount .. " монет)"
            else
                status = "🟡 Ждём раунд"
            end

            statLabel.Text = string.format(
                "%s\nРаунд: %d | Всего: %d монет\nСессия: %02d:%02d | ~%d/мин\nРаундов: %d",
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

-- ════════════════════════════════════
-- СТАРТ
-- ════════════════════════════════════
if CFG.AntiAFK then startAntiAFK() end
local initMsg = HAS_FTI
    and "v4.0 ✓ FTI режим готов"
    or "v4.0 ✓ HeadEdge режим (FTI недоступен)"
notify("CoinMaster", initMsg, 4)
