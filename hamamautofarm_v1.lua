local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local autoFarm           = false
local farmingActive      = false
local autoReset          = false
local bagFull            = false
local antiAFKEnabled     = false
local resetting          = false
local startCFrame        = nil
local currentTween       = nil
local currentTarget      = nil
local currentTargetStart = 0
local savedCanCollide    = {}
local tweenSpeed         = 1.2
local tweenSmoothnessVal = 0.25
local speedDragging      = false
local smoothDragging     = false

local easingStyles = {
    Enum.EasingStyle.Linear,
    Enum.EasingStyle.Sine,
    Enum.EasingStyle.Quad,
    Enum.EasingStyle.Cubic,
}
local easingNames = { "Linear", "Sine", "Quad", "Cubic" }

local function getEasingStyle()
    local idx = math.clamp(math.floor(tweenSmoothnessVal * #easingStyles) + 1, 1, #easingStyles)
    return easingStyles[idx]
end

local function disableMapCollision()
    local lobby     = workspace:FindFirstChild("RegularLobby")
    local lobbyMain = lobby and lobby:FindFirstChild("MainLobby")
    local character = LocalPlayer.Character
    savedCanCollide = {}
    for _, part in ipairs(workspace:GetDescendants()) do
        if part:IsA("BasePart") then
            local skip = (lobbyMain and part:IsDescendantOf(lobbyMain))
                      or (character and part:IsDescendantOf(character))
            if not skip then
                savedCanCollide[part] = part.CanCollide
                part.CanCollide = false
            end
        end
    end
end

local function restoreMapCollision()
    for part, val in pairs(savedCanCollide) do
        if part and part.Parent then
            part.CanCollide = val
        end
    end
    savedCanCollide = {}
end

local function unanchorHRP()
    local ch = LocalPlayer.Character
    local h  = ch and ch:FindFirstChild("HumanoidRootPart")
    if h then h.Anchored = false end
end

local old = PlayerGui:FindFirstChild("AzureMM2UI")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name         = "AzureMM2UI"
gui.ResetOnSpawn = false
gui.Parent       = LocalPlayer:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size                   = UDim2.new(0, 340, 0, 420)
main.Position               = UDim2.new(0.5, 0, 0.5, 0)
main.AnchorPoint            = Vector2.new(0.5, 0.5)
main.BackgroundColor3       = Color3.fromRGB(8, 12, 25)
main.BackgroundTransparency = 0
main.BorderSizePixel        = 0
main.Parent                 = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = main

local glow = Instance.new("Frame")
glow.Size                   = UDim2.new(1, 12, 1, 12)
glow.Position               = UDim2.new(0, -6, 0, -6)
glow.ZIndex                 = 0
glow.BackgroundColor3       = Color3.fromRGB(100, 100, 255)
glow.BackgroundTransparency = 0.5
glow.BorderSizePixel        = 0
glow.Parent                 = main

local glowCorner = Instance.new("UICorner")
glowCorner.CornerRadius = UDim.new(0, 18)
glowCorner.Parent = glow

local header = Instance.new("Frame")
header.Size                   = UDim2.new(1, 0, 0, 52)
header.Position               = UDim2.new(0, 0, 0, 0)
header.BackgroundTransparency = 1
header.Parent                 = main

local title = Instance.new("TextLabel")
title.Size                   = UDim2.new(0.7, -10, 1, 0)
title.Position               = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text                   = "Azure MM2 Farm"
title.Font                   = Enum.Font.GothamBold
title.TextSize               = 20
title.TextColor3             = Color3.fromRGB(175, 220, 255)
title.TextXAlignment         = Enum.TextXAlignment.Left
title.Parent                 = header

local version = Instance.new("TextLabel")
version.Size                   = UDim2.new(0.3, -10, 1, 0)
version.Position               = UDim2.new(0.7, 10, 0, 0)
version.BackgroundTransparency = 1
version.Text                   = "v1.0"
version.Font                   = Enum.Font.Gotham
version.TextSize               = 14
version.TextColor3             = Color3.fromRGB(130, 200, 255)
version.TextXAlignment         = Enum.TextXAlignment.Right
version.Parent                 = header

local minBtn = Instance.new("TextButton")
minBtn.Size                   = UDim2.new(0, 36, 0, 24)
minBtn.Position               = UDim2.new(1, -70, 0, 10)
minBtn.Text                   = "—"
minBtn.Font                   = Enum.Font.GothamBold
minBtn.TextSize               = 18
minBtn.TextColor3             = Color3.new(1, 1, 1)
minBtn.BackgroundTransparency = 0
minBtn.BackgroundColor3       = Color3.fromRGB(14, 40, 80)
minBtn.Parent                 = header

local minCorner = Instance.new("UICorner")
minCorner.Parent = minBtn

local closeBtn = Instance.new("TextButton")
closeBtn.Size             = UDim2.new(0, 24, 0, 24)
closeBtn.Position         = UDim2.new(1, -30, 0, 10)
closeBtn.Text             = "X"
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.TextSize         = 14
closeBtn.TextColor3       = Color3.new(1, 1, 1)
closeBtn.BackgroundColor3 = Color3.fromRGB(190, 60, 60)
closeBtn.Parent           = header

local closeCorner = Instance.new("UICorner")
closeCorner.Parent = closeBtn

local content = Instance.new("Frame")
content.Size                   = UDim2.new(0.94, 0, 0.78, 0)
content.Position               = UDim2.new(0.03, 0, 0.17, 0)
content.BackgroundColor3       = Color3.fromRGB(10, 18, 32)
content.BackgroundTransparency = 0.15
content.BorderSizePixel        = 0
content.Parent                 = main

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 10)
contentCorner.Parent = content

local inner = Instance.new("Frame")
inner.Size                   = UDim2.new(1, -14, 1, -14)
inner.Position               = UDim2.new(0, 7, 0, 7)
inner.BackgroundTransparency = 1
inner.Parent                 = content

local farmLabel = Instance.new("TextLabel")
farmLabel.Size                   = UDim2.new(0.7, 0, 0, 28)
farmLabel.Position               = UDim2.new(0.03, 0, 0, 4)
farmLabel.BackgroundTransparency = 1
farmLabel.Text                   = "🔹 Auto Farm"
farmLabel.Font                   = Enum.Font.GothamSemibold
farmLabel.TextSize               = 15
farmLabel.TextColor3             = Color3.fromRGB(200, 230, 255)
farmLabel.TextXAlignment         = Enum.TextXAlignment.Left
farmLabel.Parent                 = inner

local farmToggle = Instance.new("TextButton")
farmToggle.Size             = UDim2.new(0, 56, 0, 28)
farmToggle.Position         = UDim2.new(0.78, 0, 0, 6)
farmToggle.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
farmToggle.AutoButtonColor  = false
farmToggle.Text             = ""
farmToggle.Parent           = inner

local farmToggleCorner = Instance.new("UICorner")
farmToggleCorner.CornerRadius = UDim.new(1, 0)
farmToggleCorner.Parent = farmToggle

local farmKnob = Instance.new("Frame")
farmKnob.Size             = UDim2.new(0, 24, 0, 24)
farmKnob.Position         = UDim2.new(0, 2, 0, 2)
farmKnob.BackgroundColor3 = Color3.fromRGB(245, 250, 255)
farmKnob.Parent           = farmToggle

local farmKnobCorner = Instance.new("UICorner")
farmKnobCorner.CornerRadius = UDim.new(1, 0)
farmKnobCorner.Parent = farmKnob

local resetLabel = Instance.new("TextLabel")
resetLabel.Size                   = UDim2.new(0.7, 0, 0, 28)
resetLabel.Position               = UDim2.new(0.03, 0, 0, 44)
resetLabel.BackgroundTransparency = 1
resetLabel.Text                   = "🔁 Auto Reset (when bag full)"
resetLabel.Font                   = Enum.Font.GothamSemibold
resetLabel.TextSize               = 15
resetLabel.TextColor3             = Color3.fromRGB(200, 230, 255)
resetLabel.TextXAlignment         = Enum.TextXAlignment.Left
resetLabel.Parent                 = inner

local resetToggle = Instance.new("TextButton")
resetToggle.Size             = UDim2.new(0, 56, 0, 28)
resetToggle.Position         = UDim2.new(0.78, 0, 0, 46)
resetToggle.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
resetToggle.AutoButtonColor  = false
resetToggle.Text             = ""
resetToggle.Parent           = inner

local resetToggleCorner = Instance.new("UICorner")
resetToggleCorner.CornerRadius = UDim.new(1, 0)
resetToggleCorner.Parent = resetToggle

local resetKnob = Instance.new("Frame")
resetKnob.Size             = UDim2.new(0, 24, 0, 24)
resetKnob.Position         = UDim2.new(0, 2, 0, 2)
resetKnob.BackgroundColor3 = Color3.fromRGB(245, 250, 255)
resetKnob.Parent           = resetToggle

local resetKnobCorner = Instance.new("UICorner")
resetKnobCorner.CornerRadius = UDim.new(1, 0)
resetKnobCorner.Parent = resetKnob

local antiAFKBtn = Instance.new("TextButton")
antiAFKBtn.Size             = UDim2.new(0.9, 0, 0, 34)
antiAFKBtn.Position         = UDim2.new(0.05, 0, 0, 84)
antiAFKBtn.BackgroundColor3 = Color3.fromRGB(55, 130, 200)
antiAFKBtn.Font             = Enum.Font.GothamBold
antiAFKBtn.TextSize         = 15
antiAFKBtn.TextColor3       = Color3.new(1, 1, 1)
antiAFKBtn.Text             = "Enable Anti-AFK"
antiAFKBtn.Parent           = inner

local antiAFKCorner = Instance.new("UICorner")
antiAFKCorner.CornerRadius = UDim.new(0, 8)
antiAFKCorner.Parent = antiAFKBtn

local speedLabel = Instance.new("TextLabel")
speedLabel.Size                   = UDim2.new(0.65, 0, 0, 18)
speedLabel.Position               = UDim2.new(0.03, 0, 0, 130)
speedLabel.BackgroundTransparency = 1
speedLabel.Text                   = "⚡ Tween Speed"
speedLabel.Font                   = Enum.Font.GothamSemibold
speedLabel.TextSize               = 14
speedLabel.TextColor3             = Color3.fromRGB(200, 230, 255)
speedLabel.TextXAlignment         = Enum.TextXAlignment.Left
speedLabel.Parent                 = inner

local speedValueLabel = Instance.new("TextLabel")
speedValueLabel.Size                   = UDim2.new(0.28, 0, 0, 18)
speedValueLabel.Position               = UDim2.new(0.69, 0, 0, 130)
speedValueLabel.BackgroundTransparency = 1
speedValueLabel.Text                   = "1.20s"
speedValueLabel.Font                   = Enum.Font.Gotham
speedValueLabel.TextSize               = 13
speedValueLabel.TextColor3             = Color3.fromRGB(130, 200, 255)
speedValueLabel.TextXAlignment         = Enum.TextXAlignment.Right
speedValueLabel.Parent                 = inner

local speedTrack = Instance.new("Frame")
speedTrack.Size             = UDim2.new(0.9, 0, 0, 16)
speedTrack.Position         = UDim2.new(0.05, 0, 0, 152)
speedTrack.BackgroundColor3 = Color3.fromRGB(30, 50, 80)
speedTrack.ClipsDescendants = false
speedTrack.BorderSizePixel  = 0
speedTrack.Parent           = inner

local speedTrackCorner = Instance.new("UICorner")
speedTrackCorner.CornerRadius = UDim.new(1, 0)
speedTrackCorner.Parent = speedTrack

local speedDefaultRelX = (2.0 - tweenSpeed) / 1.95

local speedFill = Instance.new("Frame")
speedFill.Size             = UDim2.new(speedDefaultRelX, 0, 1, 0)
speedFill.BackgroundColor3 = Color3.fromRGB(60, 160, 255)
speedFill.BorderSizePixel  = 0
speedFill.Parent           = speedTrack

local speedFillCorner = Instance.new("UICorner")
speedFillCorner.CornerRadius = UDim.new(1, 0)
speedFillCorner.Parent = speedFill

local speedKnob = Instance.new("Frame")
speedKnob.Size             = UDim2.new(0, 20, 0, 20)
speedKnob.Position         = UDim2.new(speedDefaultRelX, -10, 0.5, -10)
speedKnob.BackgroundColor3 = Color3.fromRGB(245, 250, 255)
speedKnob.ZIndex           = 2
speedKnob.BorderSizePixel  = 0
speedKnob.Parent           = speedTrack

local speedKnobCorner = Instance.new("UICorner")
speedKnobCorner.CornerRadius = UDim.new(1, 0)
speedKnobCorner.Parent = speedKnob

local smoothLabel = Instance.new("TextLabel")
smoothLabel.Size                   = UDim2.new(0.65, 0, 0, 18)
smoothLabel.Position               = UDim2.new(0.03, 0, 0, 180)
smoothLabel.BackgroundTransparency = 1
smoothLabel.Text                   = "✦ Easing Style"
smoothLabel.Font                   = Enum.Font.GothamSemibold
smoothLabel.TextSize               = 14
smoothLabel.TextColor3             = Color3.fromRGB(200, 230, 255)
smoothLabel.TextXAlignment         = Enum.TextXAlignment.Left
smoothLabel.Parent                 = inner

local smoothValueLabel = Instance.new("TextLabel")
smoothValueLabel.Size                   = UDim2.new(0.28, 0, 0, 18)
smoothValueLabel.Position               = UDim2.new(0.69, 0, 0, 180)
smoothValueLabel.BackgroundTransparency = 1
smoothValueLabel.Text                   = "Sine"
smoothValueLabel.Font                   = Enum.Font.Gotham
smoothValueLabel.TextSize               = 13
smoothValueLabel.TextColor3             = Color3.fromRGB(130, 200, 255)
smoothValueLabel.TextXAlignment         = Enum.TextXAlignment.Right
smoothValueLabel.Parent                 = inner

local smoothTrack = Instance.new("Frame")
smoothTrack.Size             = UDim2.new(0.9, 0, 0, 16)
smoothTrack.Position         = UDim2.new(0.05, 0, 0, 202)
smoothTrack.BackgroundColor3 = Color3.fromRGB(30, 50, 80)
smoothTrack.ClipsDescendants = false
smoothTrack.BorderSizePixel  = 0
smoothTrack.Parent           = inner

local smoothTrackCorner = Instance.new("UICorner")
smoothTrackCorner.CornerRadius = UDim.new(1, 0)
smoothTrackCorner.Parent = smoothTrack

local smoothDefaultRelX = tweenSmoothnessVal

local smoothFill = Instance.new("Frame")
smoothFill.Size             = UDim2.new(smoothDefaultRelX, 0, 1, 0)
smoothFill.BackgroundColor3 = Color3.fromRGB(60, 160, 255)
smoothFill.BorderSizePixel  = 0
smoothFill.Parent           = smoothTrack

local smoothFillCorner = Instance.new("UICorner")
smoothFillCorner.CornerRadius = UDim.new(1, 0)
smoothFillCorner.Parent = smoothFill

local smoothKnob = Instance.new("Frame")
smoothKnob.Size             = UDim2.new(0, 20, 0, 20)
smoothKnob.Position         = UDim2.new(smoothDefaultRelX, -10, 0.5, -10)
smoothKnob.BackgroundColor3 = Color3.fromRGB(245, 250, 255)
smoothKnob.ZIndex           = 2
smoothKnob.BorderSizePixel  = 0
smoothKnob.Parent           = smoothTrack

local smoothKnobCorner = Instance.new("UICorner")
smoothKnobCorner.CornerRadius = UDim.new(1, 0)
smoothKnobCorner.Parent = smoothKnob

local statusLabel = Instance.new("TextLabel")
statusLabel.Size                   = UDim2.new(0.9, 0, 0, 26)
statusLabel.Position               = UDim2.new(0.05, 0, 0, 232)
statusLabel.BackgroundTransparency = 1
statusLabel.Font                   = Enum.Font.Gotham
statusLabel.TextSize               = 14
statusLabel.TextColor3             = Color3.fromRGB(190, 220, 255)
statusLabel.TextXAlignment         = Enum.TextXAlignment.Left
statusLabel.Text                   = "⏱ Time: 0d 00h 00m 00s"
statusLabel.Parent                 = inner

local KNOB_ON_POS      = UDim2.new(1, -26, 0, 2)
local KNOB_OFF_POS     = UDim2.new(0, 2, 0, 2)
local TOGGLE_ON_COLOR  = Color3.fromRGB(60, 160, 255)
local TOGGLE_OFF_COLOR = Color3.fromRGB(80, 80, 100)
local KNOB_COLOR       = Color3.fromRGB(245, 250, 255)

local function setToggle(toggle, knob, on)
    knob.Position           = on and KNOB_ON_POS or KNOB_OFF_POS
    toggle.BackgroundColor3 = on and TOGGLE_ON_COLOR or TOGGLE_OFF_COLOR
    knob.BackgroundColor3   = KNOB_COLOR
end

local sessionStart = os.clock()
task.spawn(function()
    while true do
        task.wait(1)
        local t = os.clock() - sessionStart
        local d = math.floor(t / 86400)
        local h = math.floor((t % 86400) / 3600)
        local m = math.floor((t % 3600) / 60)
        local s = math.floor(t % 60)
        statusLabel.Text = string.format("⏱ Time: %dd %02dh %02dm %02ds", d, h, m, s)
    end
end)

task.spawn(function()
    local hue = 0
    while gui and gui.Parent do
        task.wait(0.04)
        hue = (hue + 0.004) % 1
        glow.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
    end
end)

local dragging  = false
local dragStart = nil
local startPos  = nil

local dragArea = Instance.new("TextButton")
dragArea.Size                   = UDim2.new(1, -80, 1, 0)
dragArea.Position               = UDim2.new(0, 0, 0, 0)
dragArea.BackgroundTransparency = 1
dragArea.Text                   = ""
dragArea.ZIndex                 = 5
dragArea.Parent                 = header

dragArea.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging  = true
        dragStart = input.Position
        startPos  = main.Position
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging       = false
        speedDragging  = false
        smoothDragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    if dragging then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
    if speedDragging then
        local ap   = speedTrack.AbsolutePosition
        local as   = speedTrack.AbsoluteSize
        local relX = math.clamp((input.Position.X - ap.X) / as.X, 0, 1)
        speedKnob.Position   = UDim2.new(relX, -10, 0.5, -10)
        speedFill.Size       = UDim2.new(relX, 0, 1, 0)
        tweenSpeed           = 2.0 - relX * 1.95
        speedValueLabel.Text = string.format("%.2fs", tweenSpeed)
    end
    if smoothDragging then
        local ap   = smoothTrack.AbsolutePosition
        local as   = smoothTrack.AbsoluteSize
        local relX = math.clamp((input.Position.X - ap.X) / as.X, 0, 1)
        smoothKnob.Position   = UDim2.new(relX, -10, 0.5, -10)
        smoothFill.Size       = UDim2.new(relX, 0, 1, 0)
        tweenSmoothnessVal    = relX
        local idx             = math.clamp(math.floor(relX * #easingStyles) + 1, 1, #easingStyles)
        smoothValueLabel.Text = easingNames[idx]
    end
end)

speedKnob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        speedDragging = true
    end
end)

smoothKnob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        smoothDragging = true
    end
end)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    dragging   = false
    minimized  = not minimized
    main.Size  = minimized and UDim2.new(0, 340, 0, 56) or UDim2.new(0, 340, 0, 420)
end)

closeBtn.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

antiAFKBtn.MouseButton1Click:Connect(function()
    antiAFKEnabled = not antiAFKEnabled
    antiAFKBtn.BackgroundColor3 = antiAFKEnabled
        and Color3.fromRGB(70, 190, 140)
        or Color3.fromRGB(55, 130, 200)
end)

farmToggle.MouseButton1Click:Connect(function()
    autoFarm = not autoFarm
    setToggle(farmToggle, farmKnob, autoFarm)
    if not autoFarm then
        farmingActive = false
        if currentTween then
            currentTween:Cancel()
            currentTween = nil
        end
        currentTarget = nil
        unanchorHRP()
        restoreMapCollision()
    elseif farmingActive then
        task.spawn(disableMapCollision)
    end
end)

resetToggle.MouseButton1Click:Connect(function()
    autoReset = not autoReset
    setToggle(resetToggle, resetKnob, autoReset)
end)

local Remotes       = ReplicatedStorage:WaitForChild("Remotes")
local Gameplay      = Remotes:WaitForChild("Gameplay")
local CoinCollected = Gameplay:WaitForChild("CoinCollected")
local RoundStart    = Gameplay:WaitForChild("RoundStart")
local RoundEndFade  = Gameplay:WaitForChild("RoundEndFade")

local function parseCounter(text)
    local values = {}
    for num in string.gmatch(tostring(text), ":(%d*):") do
        table.insert(values, tonumber(num) or 0)
    end
    return values
end

CoinCollected.OnClientEvent:Connect(function(...)
    for _, arg in ipairs({ ... }) do
        if type(arg) == "string" then
            local nums = parseCounter(arg)
            if #nums >= 1 then
                bagFull = true
                if autoReset then
                    resetting = true
                end
                local character = LocalPlayer.Character
                if character then
                    character:WaitForChild("HumanoidRootPart")
                end
            end
        end
    end
end)

RoundStart.OnClientEvent:Connect(function()
    local character = LocalPlayer.Character
    if character then
        local hrp = character:WaitForChild("HumanoidRootPart")
        if not startCFrame then
            startCFrame = hrp.CFrame
        end
        hrp.Anchored = false
    end
    farmingActive = true
    bagFull       = false
    resetting     = false
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    currentTarget = nil
    if autoFarm then
        task.delay(1, function()
            task.spawn(disableMapCollision)
        end)
    end
end)

RoundEndFade.OnClientEvent:Connect(function()
    farmingActive = false
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    currentTarget = nil
    unanchorHRP()
    task.spawn(restoreMapCollision)
end)

task.spawn(function()
    while true do
        task.wait(0.18)
        if not (autoFarm and farmingActive and not resetting) then
            if currentTween then
                currentTween:Cancel()
                currentTween = nil
            end
            currentTarget = nil
            unanchorHRP()
            continue
        end
        local character = LocalPlayer.Character
        if not character then continue end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        if currentTarget and currentTarget.Parent and currentTarget:FindFirstChild("TouchInterest") then
            if os.clock() - currentTargetStart < 3 then
                continue
            end
        end
        if currentTween then
            currentTween:Cancel()
            currentTween = nil
        end
        currentTarget = nil
        local bestDist = math.huge
        local bestCoin = nil
        for _, v in ipairs(workspace:GetChildren()) do
            local cc = v:FindFirstChild("CoinContainer")
            if cc then
                for _, coin in ipairs(cc:GetChildren()) do
                    if coin:IsA("BasePart") and coin:FindFirstChild("TouchInterest") then
                        local d = (hrp.Position - coin.Position).Magnitude
                        if d < bestDist then
                            bestDist = d
                            bestCoin = coin
                        end
                    end
                end
            end
        end
        if bestCoin then
            currentTarget      = bestCoin
            currentTargetStart = os.clock()
            local ti = TweenInfo.new(tweenSpeed, getEasingStyle(), Enum.EasingDirection.Out)
            hrp.Anchored = false
            currentTween = TweenService:Create(hrp, ti, { CFrame = bestCoin.CFrame })
            currentTween.Completed:Connect(function()
                currentTween = nil
                local ch = LocalPlayer.Character
                local h  = ch and ch:FindFirstChild("HumanoidRootPart")
                if h and autoFarm and farmingActive and not resetting then
                    h.Anchored = true
                end
            end)
            currentTween:Play()
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not currentTarget then return end
    if not currentTarget.Parent or not currentTarget:FindFirstChild("TouchInterest") then
        currentTarget = nil
    end
end)
