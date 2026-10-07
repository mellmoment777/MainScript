local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local state = {
        autoFarm       = false,
        farmingActive  = false,
        autoReset      = false,
        bagFull        = false,
        antiAFKEnabled = false,
        resetting      = false,
        startCFrame    = nil,
}

local old = PlayerGui:FindFirstChild("AzureMM2UI")
if old then
        old:Destroy()
end

local COLOR_BACKGROUND    = Color3.fromRGB(15, 9, 26)
local COLOR_SURFACE       = Color3.fromRGB(23, 13, 42)
local COLOR_STROKE        = Color3.fromRGB(124, 77, 255)
local COLOR_ACCENT        = Color3.fromRGB(148, 90, 255)
local COLOR_TOGGLE_OFF    = Color3.fromRGB(52, 34, 88)
local COLOR_TEXT          = Color3.fromRGB(226, 210, 255)
local COLOR_TEXT_MUTED    = Color3.fromRGB(158, 138, 214)
local COLOR_KNOB          = Color3.fromRGB(238, 231, 255)
local COLOR_BUTTON_IDLE   = Color3.fromRGB(96, 56, 180)
local COLOR_BUTTON_ACTIVE = Color3.fromRGB(150, 96, 255)
local COLOR_BUTTON_CLOSE  = Color3.fromRGB(146, 48, 74)
local COLOR_BUTTON_MIN    = Color3.fromRGB(44, 28, 78)

local gui = Instance.new("ScreenGui")
gui.Name = "AzureMM2UI"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 340, 0, 280)
main.Position = UDim2.new(0.5, -170, 0.5, -140)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.BackgroundColor3 = COLOR_BACKGROUND
main.BorderSizePixel = 0
main.Active = true
main.ClipsDescendants = true
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = COLOR_STROKE
mainStroke.Thickness = 1
mainStroke.Transparency = 0.4
mainStroke.Parent = main

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 46)
header.BackgroundTransparency = 1
header.Parent = main

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(0, 180, 1, 0)
title.Position = UDim2.new(0, 14, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Azure MM2 Farm"
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.TextColor3 = COLOR_TEXT
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local version = Instance.new("TextLabel")
version.Name = "Version"
version.Size = UDim2.new(0, 56, 1, 0)
version.Position = UDim2.new(0, 198, 0, 0)
version.BackgroundTransparency = 1
version.Text = "v1.0"
version.Font = Enum.Font.Gotham
version.TextSize = 12
version.TextColor3 = COLOR_TEXT_MUTED
version.TextXAlignment = Enum.TextXAlignment.Left
version.Parent = header

local minBtn = Instance.new("TextButton")
minBtn.Name = "Minimize"
minBtn.Size = UDim2.new(0, 28, 0, 24)
minBtn.Position = UDim2.new(1, -72, 0, 11)
minBtn.Text = "-"
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 16
minBtn.TextColor3 = COLOR_TEXT
minBtn.AutoButtonColor = false
minBtn.BackgroundColor3 = COLOR_BUTTON_MIN
minBtn.BorderSizePixel = 0
minBtn.Parent = header

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 6)
minCorner.Parent = minBtn

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "Close"
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -34, 0, 11)
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.TextColor3 = Color3.fromRGB(255, 235, 240)
closeBtn.AutoButtonColor = false
closeBtn.BackgroundColor3 = COLOR_BUTTON_CLOSE
closeBtn.BorderSizePixel = 0
closeBtn.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

local headerDivider = Instance.new("Frame")
headerDivider.Name = "HeaderDivider"
headerDivider.Size = UDim2.new(1, -24, 0, 1)
headerDivider.Position = UDim2.new(0, 12, 0, 46)
headerDivider.BackgroundColor3 = COLOR_STROKE
headerDivider.BackgroundTransparency = 0.55
headerDivider.BorderSizePixel = 0
headerDivider.Parent = main

local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.new(1, -24, 1, -66)
content.Position = UDim2.new(0, 12, 0, 56)
content.BackgroundColor3 = COLOR_SURFACE
content.BorderSizePixel = 0
content.Parent = main

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 10)
contentCorner.Parent = content

local farmLabel = Instance.new("TextLabel")
farmLabel.Name = "FarmLabel"
farmLabel.Size = UDim2.new(1, -84, 0, 26)
farmLabel.Position = UDim2.new(0, 14, 0, 12)
farmLabel.BackgroundTransparency = 1
farmLabel.Text = "Auto Farm"
farmLabel.Font = Enum.Font.GothamSemibold
farmLabel.TextSize = 14
farmLabel.TextColor3 = COLOR_TEXT
farmLabel.TextXAlignment = Enum.TextXAlignment.Left
farmLabel.Parent = content

local resetLabel = Instance.new("TextLabel")
resetLabel.Name = "ResetLabel"
resetLabel.Size = UDim2.new(1, -84, 0, 26)
resetLabel.Position = UDim2.new(0, 14, 0, 50)
resetLabel.BackgroundTransparency = 1
resetLabel.Text = "Auto Reset (Bag Full)"
resetLabel.Font = Enum.Font.GothamSemibold
resetLabel.TextSize = 14
resetLabel.TextColor3 = COLOR_TEXT
resetLabel.TextXAlignment = Enum.TextXAlignment.Left
resetLabel.Parent = content

local KNOB_ON_POS  = UDim2.new(1, -23, 0, 3)
local KNOB_OFF_POS = UDim2.new(0, 3, 0, 3)

local function createToggle(yPos)
        local toggle = Instance.new("TextButton")
        toggle.Size = UDim2.new(0, 52, 0, 26)
        toggle.Position = UDim2.new(1, -66, 0, yPos)
        toggle.BackgroundColor3 = COLOR_TOGGLE_OFF
        toggle.AutoButtonColor = false
        toggle.Text = ""
        toggle.BorderSizePixel = 0
        toggle.Parent = content

        local toggleCorner = Instance.new("UICorner")
        toggleCorner.CornerRadius = UDim.new(1, 0)
        toggleCorner.Parent = toggle

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 20, 0, 20)
        knob.Position = KNOB_OFF_POS
        knob.BackgroundColor3 = COLOR_KNOB
        knob.BorderSizePixel = 0
        knob.Parent = toggle

        local knobCorner = Instance.new("UICorner")
        knobCorner.CornerRadius = UDim.new(1, 0)
        knobCorner.Parent = knob

        return toggle, knob
end

local farmToggle, farmKnob = createToggle(12)
local resetToggle, resetKnob = createToggle(50)

local contentDivider = Instance.new("Frame")
contentDivider.Name = "ContentDivider"
contentDivider.Size = UDim2.new(1, -28, 0, 1)
contentDivider.Position = UDim2.new(0, 14, 0, 92)
contentDivider.BackgroundColor3 = COLOR_STROKE
contentDivider.BackgroundTransparency = 0.75
contentDivider.BorderSizePixel = 0
contentDivider.Parent = content

local antiAFKBtn = Instance.new("TextButton")
antiAFKBtn.Name = "AntiAFK"
antiAFKBtn.Size = UDim2.new(1, -28, 0, 36)
antiAFKBtn.Position = UDim2.new(0, 14, 0, 106)
antiAFKBtn.BackgroundColor3 = COLOR_BUTTON_IDLE
antiAFKBtn.Font = Enum.Font.GothamBold
antiAFKBtn.TextSize = 14
antiAFKBtn.TextColor3 = Color3.fromRGB(250, 247, 255)
antiAFKBtn.Text = "Anti-AFK: OFF"
antiAFKBtn.AutoButtonColor = false
antiAFKBtn.BorderSizePixel = 0
antiAFKBtn.Parent = content

local antiAFKCorner = Instance.new("UICorner")
antiAFKCorner.CornerRadius = UDim.new(0, 8)
antiAFKCorner.Parent = antiAFKBtn

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(1, -28, 0, 22)
statusLabel.Position = UDim2.new(0, 14, 0, 158)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 13
statusLabel.TextColor3 = COLOR_TEXT_MUTED
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = "Time: 0d 00h 00m 00s"
statusLabel.Parent = content

local sessionStart = tick()

task.spawn(function()
        while true do
                task.wait(1)
                local t = tick() - sessionStart
                local d = math.floor(t / 86400)
                local h = math.floor((t % 86400) / 3600)
                local m = math.floor((t % 3600) / 60)
                local s = math.floor(t % 60)
                statusLabel.Text = string.format("Time: %dd %02dh %02dm %02ds", d, h, m, s)
        end
end)

local dragging = false
local dragInput = nil
local dragStart = nil
local startPos = nil

main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = main.Position
                input.Changed:Connect(function()
                        if input.UserInputState == Enum.UserInputState.End then
                                dragging = false
                        end
                end)
        end
end)

main.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
        end
end)

UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
                local delta = input.Position - dragStart
                main.Position = UDim2.new(
                        startPos.X.Scale, startPos.X.Offset + delta.X,
                        startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
        end
end)

UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
        end
end)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
                main.Size = UDim2.new(0, 340, 0, 46)
        else
                main.Size = UDim2.new(0, 340, 0, 280)
        end
end)

closeBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
end)

LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
end)

antiAFKBtn.MouseButton1Click:Connect(function()
        state.antiAFKEnabled = not state.antiAFKEnabled
        if state.antiAFKEnabled then
                antiAFKBtn.BackgroundColor3 = COLOR_BUTTON_ACTIVE
                antiAFKBtn.Text = "Anti-AFK: ON"
        else
                antiAFKBtn.BackgroundColor3 = COLOR_BUTTON_IDLE
                antiAFKBtn.Text = "Anti-AFK: OFF"
        end
end)

farmToggle.MouseButton1Click:Connect(function()
        state.autoFarm = not state.autoFarm
        if not state.autoFarm then
                state.farmingActive = false
        end
        local knobTarget = state.autoFarm and KNOB_ON_POS or KNOB_OFF_POS
        local colorTarget = state.autoFarm and COLOR_ACCENT or COLOR_TOGGLE_OFF
        TweenService:Create(farmKnob, TweenInfo.new(0.18), { Position = knobTarget }):Play()
        TweenService:Create(farmToggle, TweenInfo.new(0.18), { BackgroundColor3 = colorTarget }):Play()
end)

resetToggle.MouseButton1Click:Connect(function()
        state.autoReset = not state.autoReset
        local knobTarget = state.autoReset and KNOB_ON_POS or KNOB_OFF_POS
        local colorTarget = state.autoReset and COLOR_ACCENT or COLOR_TOGGLE_OFF
        TweenService:Create(resetKnob, TweenInfo.new(0.18), { Position = knobTarget }):Play()
        TweenService:Create(resetToggle, TweenInfo.new(0.18), { BackgroundColor3 = colorTarget }):Play()
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
                                state.bagFull = true
                                if state.autoReset and not state.resetting then
                                        state.resetting = true
                                        local character = LocalPlayer.Character
                                        if character then
                                                local hrp = character:WaitForChild("HumanoidRootPart")
                                                if state.startCFrame then
                                                        local back = TweenService:Create(hrp,
                                                                TweenInfo.new(1.8, Enum.EasingStyle.Linear),
                                                                { CFrame = state.startCFrame })
                                                        back:Play()
                                                        back.Completed:Wait()
                                                        task.wait(0.5)
                                                end
                                        end
                                end
                        end
                end
        end
end)

RoundStart.OnClientEvent:Connect(function()
        local character = LocalPlayer.Character
        if character then
                local hrp = character:WaitForChild("HumanoidRootPart")
                if not state.startCFrame then
                        state.startCFrame = hrp.CFrame
                end
        end
        state.farmingActive = true
        state.bagFull = false
        state.resetting = false
end)

RoundEndFade.OnClientEvent:Connect(function()
        state.farmingActive = false
end)

task.spawn(function()
        while true do
                task.wait(0.18)
                if state.autoFarm and state.farmingActive and not state.resetting then
                        local character = LocalPlayer.Character
                        if character then
                                local hrp = character:WaitForChild("HumanoidRootPart")
                                local bestDist = math.huge
                                local bestCoin = nil
                                for _, v in ipairs(workspace:GetChildren()) do
                                        local cc = v:FindFirstChild("CoinContainer")
                                        if cc then
                                                for _, coin in ipairs(cc:GetChildren()) do
                                                        if coin:IsA("BasePart")
                                                                and coin:FindFirstChild("TouchInterest") then
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
                                        character:WaitForChild("HumanoidRootPart")
                                        local dist = (hrp.Position - bestCoin.Position).Magnitude
                                        local flight = TweenService:Create(
                                                character:WaitForChild("HumanoidRootPart"),
                                                TweenInfo.new(math.clamp(dist / 18, 0.1, 4),
                                                        Enum.EasingStyle.Linear),
                                                { CFrame = bestCoin.CFrame }
                                        )
                                        flight:Play()
                                        while bestCoin:FindFirstChild("TouchInterest") do
                                                task.wait()
                                        end
                                end
                        end
                end
        end
end)

if toggleRender ~= nil then
        toggleRender.MouseButton1Click:Connect(function()
                gui.Enabled = not gui.Enabled
        end)
end

main.Size = UDim2.new(0, 0, 0, 0)
TweenService:Create(main,
        TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.new(0, 340, 0, 280) }):Play()
