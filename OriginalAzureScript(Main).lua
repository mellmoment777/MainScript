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

local gui = Instance.new("ScreenGui")
gui.Name = "AzureMM2UI"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 340, 0, 280)
main.Position = UDim2.new(0.5, -170, 0.5, -140)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.BackgroundColor3 = Color3.fromRGB(8, 12, 25)
main.BackgroundTransparency = 0
main.BorderSizePixel = 0
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = main

local glow = Instance.new("Frame")
glow.Size = UDim2.new(1, 6, 1, 6)
glow.Position = UDim2.new(0, -3, 0, -3)
glow.ZIndex = 0
glow.BackgroundColor3 = Color3.fromRGB(20, 90, 160)
glow.BackgroundTransparency = 0.95
glow.BorderSizePixel = 0
glow.ClipsDescendants = true
glow.Parent = main

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 52)
header.Position = UDim2.new(0, 0, 0, 0)
header.BackgroundTransparency = 1
header.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0.7, -10, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Azure MM2 Farm"
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextColor3 = Color3.fromRGB(175, 220, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local version = Instance.new("TextLabel")
version.Size = UDim2.new(0.3, -10, 1, 0)
version.Position = UDim2.new(0.7, 10, 0, 0)
version.BackgroundTransparency = 1
version.Text = "v1.0"
version.Font = Enum.Font.Gotham
version.TextSize = 14
version.TextColor3 = Color3.fromRGB(130, 200, 255)
version.TextXAlignment = Enum.TextXAlignment.Right
version.Parent = header

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 36, 0, 24)
minBtn.Position = UDim2.new(1, -70, 0, 10)
minBtn.Text = "—"
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 18
minBtn.TextColor3 = Color3.new(1, 1, 1)
minBtn.BackgroundTransparency = 0
minBtn.BackgroundColor3 = Color3.fromRGB(14, 40, 80)
minBtn.Parent = header

local minCorner = Instance.new("UICorner")
minCorner.Parent = minBtn

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -30, 0, 10)
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.BackgroundColor3 = Color3.fromRGB(190, 60, 60)
closeBtn.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.Parent = closeBtn

local content = Instance.new("Frame")
content.Size = UDim2.new(0.94, 0, 0.78, 0)
content.Position = UDim2.new(0.03, 0, 0.17, 0)
content.BackgroundColor3 = Color3.fromRGB(10, 18, 32)
content.BackgroundTransparency = 0.15
content.BorderSizePixel = 0
content.Parent = main

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 10)
contentCorner.Parent = content

local inner = Instance.new("Frame")
inner.Size = UDim2.new(1, -14, 1, -14)
inner.Position = UDim2.new(0, 7, 0, 7)
inner.BackgroundTransparency = 1
inner.Parent = content

local KNOB_ON_POS      = UDim2.new(1, -26, 0, 2)
local KNOB_OFF_POS     = UDim2.new(0, 2, 0, 2)
local TOGGLE_ON_COLOR  = Color3.fromRGB(60, 160, 255)
local TOGGLE_OFF_COLOR = Color3.fromRGB(80, 80, 100)

local farmLabel = Instance.new("TextLabel")
farmLabel.Size = UDim2.new(0.7, 0, 0, 28)
farmLabel.Position = UDim2.new(0.03, 0, 0, 4)
farmLabel.BackgroundTransparency = 1
farmLabel.Text = "🔹 Auto Farm"
farmLabel.Font = Enum.Font.GothamSemibold
farmLabel.TextSize = 15
farmLabel.TextColor3 = Color3.fromRGB(200, 230, 255)
farmLabel.TextXAlignment = Enum.TextXAlignment.Left
farmLabel.Parent = inner

local farmToggle = Instance.new("TextButton")
farmToggle.Size = UDim2.new(0, 56, 0, 28)
farmToggle.Position = UDim2.new(0.78, 0, 0, 6)
farmToggle.BackgroundColor3 = TOGGLE_OFF_COLOR
farmToggle.AutoButtonColor = false
farmToggle.Text = ""
farmToggle.Parent = inner

local farmToggleCorner = Instance.new("UICorner")
farmToggleCorner.CornerRadius = UDim.new(1, 0)
farmToggleCorner.Parent = farmToggle

local farmKnob = Instance.new("Frame")
farmKnob.Size = UDim2.new(0, 24, 0, 24)
farmKnob.Position = KNOB_OFF_POS
farmKnob.BackgroundColor3 = Color3.fromRGB(245, 250, 255)
farmKnob.Parent = farmToggle

local farmKnobCorner = Instance.new("UICorner")
farmKnobCorner.CornerRadius = UDim.new(1, 0)
farmKnobCorner.Parent = farmKnob

farmToggle.MouseButton1Click:Connect(function()
	state.autoFarm = not state.autoFarm
	if not state.autoFarm then
		state.farmingActive = false
	end
	local knobTarget  = state.autoFarm and KNOB_ON_POS  or KNOB_OFF_POS
	local colorTarget = state.autoFarm and TOGGLE_ON_COLOR or TOGGLE_OFF_COLOR
	TweenService:Create(farmKnob, TweenInfo.new(0.18), {Position = knobTarget}):Play()
	TweenService:Create(farmToggle, TweenInfo.new(0.18), {BackgroundColor3 = colorTarget}):Play()
end)

local resetLabel = Instance.new("TextLabel")
resetLabel.Size = UDim2.new(0.7, 0, 0, 28)
resetLabel.Position = UDim2.new(0.03, 0, 0, 44)
resetLabel.BackgroundTransparency = 1
resetLabel.Text = "🔁 Auto Reset (when bag full)"
resetLabel.Font = Enum.Font.GothamSemibold
resetLabel.TextSize = 15
resetLabel.TextColor3 = Color3.fromRGB(200, 230, 255)
resetLabel.TextXAlignment = Enum.TextXAlignment.Left
resetLabel.Parent = inner

local resetToggle = Instance.new("TextButton")
resetToggle.Size = UDim2.new(0, 56, 0, 28)
resetToggle.Position = UDim2.new(0.78, 0, 0, 46)
resetToggle.BackgroundColor3 = TOGGLE_OFF_COLOR
resetToggle.AutoButtonColor = false
resetToggle.Text = ""
resetToggle.Parent = inner

local resetToggleCorner = Instance.new("UICorner")
resetToggleCorner.CornerRadius = UDim.new(1, 0)
resetToggleCorner.Parent = resetToggle

local resetKnob = Instance.new("Frame")
resetKnob.Size = UDim2.new(0, 24, 0, 24)
resetKnob.Position = KNOB_OFF_POS
resetKnob.BackgroundColor3 = Color3.fromRGB(245, 250, 255)
resetKnob.Parent = resetToggle

local resetKnobCorner = Instance.new("UICorner")
resetKnobCorner.CornerRadius = UDim.new(1, 0)
resetKnobCorner.Parent = resetKnob

resetToggle.MouseButton1Click:Connect(function()
	state.autoReset = not state.autoReset
	local knobTarget  = state.autoReset and KNOB_ON_POS  or KNOB_OFF_POS
	local colorTarget = state.autoReset and TOGGLE_ON_COLOR or TOGGLE_OFF_COLOR
	TweenService:Create(resetKnob, TweenInfo.new(0.18), {Position = knobTarget}):Play()
	TweenService:Create(resetToggle, TweenInfo.new(0.18), {BackgroundColor3 = colorTarget}):Play()
end)

local antiAFKBtn = Instance.new("TextButton")
antiAFKBtn.Size = UDim2.new(0.9, 0, 0, 34)
antiAFKBtn.Position = UDim2.new(0.05, 0, 0, 134)
antiAFKBtn.BackgroundColor3 = Color3.fromRGB(55, 130, 200)
antiAFKBtn.Font = Enum.Font.GothamBold
antiAFKBtn.TextSize = 15
antiAFKBtn.TextColor3 = Color3.new(1, 1, 1)
antiAFKBtn.Text = "Enable Anti-AFK"
antiAFKBtn.Parent = inner

local antiAFKCorner = Instance.new("UICorner")
antiAFKCorner.CornerRadius = UDim.new(0, 8)
antiAFKCorner.Parent = antiAFKBtn

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0.9, 0, 0, 26)
statusLabel.Position = UDim2.new(0.05, 0, 0, 184)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 14
statusLabel.TextColor3 = Color3.fromRGB(190, 220, 255)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = "⏱ Time: 0d 00h 00m 00s"
statusLabel.Parent = inner

local sessionStart = tick()

task.spawn(function()
	while true do
		task.wait(1)
		local t = tick() - sessionStart
		local d = math.floor(t / 86400)
		local h = math.floor((t % 86400) / 3600)
		local m = math.floor((t % 3600) / 60)
		local s = math.floor(t % 60)
		statusLabel.Text = string.format("⏱ Time: %dd %02dh %02dm %02ds", d, h, m, s)
	end
end)

local dragging  = false
local dragInput = nil
local dragStart = nil
local startPos  = nil

main.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging  = true
		dragStart = input.Position
		startPos  = main.Position
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

local minimized = false
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	main.Size = minimized and UDim2.new(0, 340, 0, 56) or UDim2.new(0, 340, 0, 280)
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
	antiAFKBtn.BackgroundColor3 = state.antiAFKEnabled
		and Color3.fromRGB(70, 190, 140)
		or  Color3.fromRGB(55, 130, 200)
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
	state.bagFull       = false
	state.resetting     = false
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
				local hrp      = character:WaitForChild("HumanoidRootPart")
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
						TweenInfo.new(math.clamp(dist / 18, 0.1, 4), Enum.EasingStyle.Linear),
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
