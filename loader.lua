
-- Football Hub
-- detects the game by PlaceId and loads the matching script behind one menu

local VERSION = "1.7"
local AUTOLOAD = true
local DISCORD = "https://discord.gg/" -- new invite goes here

-- ---------------------------------------------------------------------------
-- kill switch (status.lua in the repo decides whether the hub stays up)
-- ---------------------------------------------------------------------------

local STATUS_URL = "https://raw.githubusercontent.com/footballholder/hub/main/status.lua"

local statusSource
do
    local ok, res = pcall(function()
        return game:HttpGet(STATUS_URL)
    end)
    if ok and type(res) == "string" and #res > 0 then
        statusSource = res
    end
end

if statusSource then
    local ok, cfg = pcall(function()
        return loadstring(statusSource, "=Status")()
    end)
    if ok and type(cfg) == "table" and cfg.enabled == false then
        warn("[Football Hub] " .. tostring(cfg.message or "Temporarily unavailable, try again later."))
        return
    end
end

local env = (getgenv and getgenv()) or _G
env.FootballHub = env.FootballHub or {}

-- ---------------------------------------------------------------------------
-- settings (scripts read these live, so menu edits apply instantly)
-- ---------------------------------------------------------------------------

local SETTINGS = env.FootballHub.settings
if not SETTINGS or SETTINGS.version ~= 2 then
    SETTINGS = {
        version = 2,
        TPL = {
            Enabled = true,
            HorizontalSize = 7,
            HeightSize = 2,
            Distance = 35,
        },
        TPS = {
            reachEnabled = true,
            groundReach = 4,
            jumpLegReach = 4,
            headReachEnabled = false,
            headReachRadius = 3,
            reactEnabled = true,
            reactLevel = 2,
            gkAimEnabled = false,
            silentDribble = false,
            autoFakeEnabled = false,
            autoFakeKeybind = "T",
            aimbotSmoothness = 0.2,
            mossEnabled = false,
            mossLevel = 2,
            pingSpoofEnabled = false,
            cooldownRemover = false,
            cooldownKeybind = "P",
            ballEspEnabled = false,
            ballVectorEnabled = false,
            ballTrailEnabled = false,
            dashAfterimage = false,
            playerChams = false,
            playerPredictor = false,
            worldColorEnabled = false,
            flagsEnabled = true,
            flags = {
                DFIntTargetTimeDelayFacctorTenths = "15",
                FIntInterpolationMaxDelayMSec = "80",
                DFIntNetworkLatencyTolerance = "1",
                DFIntNetworkSimLagThresholdMS = "150",
                DFIntMaxFrameBufferSize = "4",
                DFIntMaxAverageFrameDelayExceedFactor = "2",
                DFIntMaxAcceptableUpdateDelay = "15",
                FIntInterpolationAwareTargetTimeLerpHundredth = "130",
                FIntInterpolationMaxTimeMS = "85",
            },
        },
        TOUCHLINE = {
            reachNoCollide = { enabled = false, size = 6, visible = false },
            reachCollide = { enabled = true, size = 5, distance = 100, visible = false },
            walk = { enabled = false, speed = 25 },
            tpWalk = { enabled = false, speed = 3 },
            fly = { enabled = false, speed = 40 },
            gk = { enabled = false, range = 40, speed = 45, lift = 28, cooldown = 1, hitRadius = 6 },
            prediction = { enabled = false, touch = 6, range = 20, ahead = 1.4 },
            jump = { enabled = false, power = 50 },
            dribble = { enabled = false, speed = 16 },
            airDribble1 = { enabled = false, size = 9, yOffset = 1, visible = false },
            airDribble2 = { enabled = false, size = 25, visible = false },
            ballFling = { enabled = false, reach = 15 },
            moss = { enabled = false, level = 2, pingSpoof = false },
        },
    }
    env.FootballHub.settings = SETTINGS
end

-- ---------------------------------------------------------------------------
-- TPL
-- ---------------------------------------------------------------------------

local function scriptTPL()
-- tpl bigfoot W anticheat
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- ps5 react
local STATE = STATE or { alive = function() return true end }
local PS5 = (pcall(function() return Enum.Platform.PS5 end) and Enum.Platform.PS5) or Enum.Platform.PS4

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    if STATE.alive() and not checkcaller() and rawequal(self, UserInputService) and getnamecallmethod() == "GetPlatform" then
        return PS5
    end
    return oldNamecall(self, ...)
end))

local Settings = SETTINGS.TPL

local trackedBalls = {}
local originalSizes = {}

local function getFootballFolder()
    return Workspace:FindFirstChild("TPSSystem") or Workspace:FindFirstChild("Footballs")
end

local function setupBall(ballPart)
    if not trackedBalls[ballPart] then
        trackedBalls[ballPart] = true
        originalSizes[ballPart] = ballPart.Size
    end
end

local folder = getFootballFolder()
if folder then
    for _, item in ipairs(folder:GetChildren()) do
        local part = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart")
        if part and part.Name == "TPS" then
            setupBall(part)
        end
    end

    folder.ChildAdded:Connect(function(item)
        task.wait(0.05)
        local part = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart")
        if part and part.Name == "TPS" then
            setupBall(part)
        end
    end)
end

RunService.RenderStepped:Connect(function()
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for part, _ in pairs(trackedBalls) do
        if part and part.Parent then
            if Settings.Enabled then
                local dist = (part.Position - hrp.Position).Magnitude

                if dist <= Settings.Distance then
                    part.Size = Vector3.new(Settings.HorizontalSize, Settings.HeightSize, Settings.HorizontalSize)
                    part.CanCollide = false
                else
                    if originalSizes[part] then
                        part.Size = originalSizes[part]
                        part.CanCollide = true
                    end
                end
            else
                if originalSizes[part] then
                    part.Size = originalSizes[part]
                    part.CanCollide = true
                end
            end
        else
            trackedBalls[part] = nil
            originalSizes[part] = nil
        end
    end
end)
end

-- ---------------------------------------------------------------------------
-- TPS Street Soccer
-- ---------------------------------------------------------------------------

local function scriptTPS()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local lp = Players.LocalPlayer
local input = UserInputService

-- the hub gated most of this behind a whitelist; here it's all on
local IS_PREMIUM = true

local theme = {
    Background     = Color3.fromRGB(5, 5, 5),
    TopBar         = Color3.fromRGB(10, 10, 10),
    Sidebar        = Color3.fromRGB(8, 8, 8),
    Panel          = Color3.fromRGB(12, 12, 12),
    ElementBg      = Color3.fromRGB(17, 17, 17),
    ElementHover   = Color3.fromRGB(25, 25, 25),
    ElementOutline = Color3.fromRGB(35, 35, 35),
    Accent         = Color3.fromRGB(157, 78, 221),
    AccentGlow     = Color3.fromRGB(199, 125, 255),
    Text           = Color3.fromRGB(245, 245, 245),
    SubText        = Color3.fromRGB(120, 120, 120),
    Border         = Color3.fromRGB(25, 25, 25),
}

local cfg = SETTINGS.TPS
local FAST_FLAGS = cfg.flags

local function cleanFlagName(z)
    z = z:gsub("^DFInt", "")
    z = z:gsub("^DFFlag", "")
    z = z:gsub("^FString", "")
    z = z:gsub("^FLog", "")
    z = z:gsub("^FFlag", "")
    z = z:gsub("^DFint", "")
    z = z:gsub("^FInt", "")
    return z
end

local function applyFastFlags()
    if not setfflag then return end
    for flag, value in pairs(FAST_FLAGS) do
        local cleanedFlag = cleanFlagName(flag)
        pcall(function()
            if getfflag and getfflag(cleanedFlag) then
                setfflag(cleanedFlag, value)
            elseif getfflag and getfflag(flag) then
                setfflag(flag, value)
            else
                setfflag(cleanedFlag, value)
            end
        end)
    end
end

applyFastFlags()

task.spawn(function()
    while true do
        if cfg.flagsEnabled then applyFastFlags() end
        task.wait(0.5)
    end
end)

local topisimleri = { TPS = true, ESA = true, MRS = true, VEF = true, MPS = true }
local groundLimbs = { "Torso", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local toplar = {}
local sonyenileme = 0

local function guncelleToplar(zorla)
    if not zorla and os.time() - sonyenileme < 2 then return end
    sonyenileme = os.time()
    table.clear(toplar)
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v and v.Name and topisimleri[v.Name] then table.insert(toplar, v) end
    end
end
guncelleToplar(true)

local lastReactTick = 0
local function applyReactPhysics(level)
    if tick() - lastReactTick < 0.1 then return end
    lastReactTick = tick()
    pcall(function()
        local tps = Workspace:FindFirstChild("TPSSystem") and Workspace.TPSSystem:FindFirstChild("TPS")
        if not tps then return end
        local effectiveLevel = level
        local char = lp.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local lookDir = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)

        if effectiveLevel == 1 then
            tps.Velocity = Vector3.new(lookDir.X * 120, math.random(0, 4), lookDir.Z * 120)
        else
            local origSize = tps.Size
            if effectiveLevel == 2 then
                settings():GetService().IncomingReplicationLag = 0.05
                tps.Size = Vector3.new(2.65, 2.65, 2.65)
                tps.Velocity = Vector3.new(lookDir.X * 180, math.random(0, 5), lookDir.Z * 180)
            elseif effectiveLevel == 3 then
                settings():GetService().IncomingReplicationLag = 0.08
                tps.Size = Vector3.new(2.7, 2.7, 2.7)
                tps.Velocity = Vector3.new(lookDir.X * 240, math.random(0, 6), lookDir.Z * 240)
            elseif effectiveLevel == 4 then
                settings():GetService().IncomingReplicationLag = 0.12
                tps.Size = Vector3.new(2.75, 2.75, 2.75)
                tps.Velocity = Vector3.new(lookDir.X * 320, math.random(0, 8), lookDir.Z * 320)
            end
            task.delay(0.25, function()
                pcall(function()
                    settings():GetService().IncomingReplicationLag = 0
                    if tps and tps.Parent then tps.Size = origSize end
                end)
            end)
        end
    end)
end

task.spawn(function()
    while task.wait(0.1) do
        if cfg.reachEnabled then
            local char = lp.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                for _, part in ipairs(toplar) do
                    if part and part.Parent and part.Name == "TPS" then
                        local dist = (root.Position - part.Position).Magnitude
                        local safeReach = math.clamp(cfg.groundReach or 4, 1, 15)
                        if dist <= safeReach then
                            pcall(function()
                                local changeOwner = ReplicatedStorage:FindFirstChild("ChangeOwner")
                                local changeValue = ReplicatedStorage:FindFirstChild("ChangeValue")
                                if changeOwner then changeOwner:FireServer(part) end
                                if changeValue then changeValue:FireServer(part) end
                                if changeOwner then changeOwner:FireServer(part) end
                            end)
                            if cfg.reactEnabled then applyReactPhysics(cfg.reactLevel) end
                        end
                    end
                end
            end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if not cfg.reachEnabled then return end
    guncelleToplar(false)
    local char = lp.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    local head = char:FindFirstChild("Head")
    if not root or not hum then return end

    local isJumping = (hum.FloorMaterial == Enum.Material.Air)
    local hitByLegThisFrame = false

    for _, limbName in ipairs(groundLimbs) do
        local limb = char:FindFirstChild(limbName)
        if limb then
            for _, v in ipairs(limb:GetDescendants()) do
                if v:IsA("TouchTransmitter") or v.Name == "TouchInterest" then
                    for _, top in ipairs(toplar) do
                        if top and top.Parent then
                            local rawStud = isJumping and (cfg.jumpLegReach or 4) or (cfg.groundReach or 4)
                            local currentStud = math.clamp(rawStud, 1, 15)
                            if (top.Position - limb.Position).Magnitude < currentStud then
                                if firetouchinterest then
                                    pcall(function() firetouchinterest(top, v.Parent, 0) firetouchinterest(top, v.Parent, 1) end)
                                    if cfg.reactEnabled then applyReactPhysics(cfg.reactLevel) end
                                    hitByLegThisFrame = true
                                end
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    if cfg.headReachEnabled and head and not hitByLegThisFrame then
        for _, v in ipairs(head:GetDescendants()) do
            if v:IsA("TouchTransmitter") or v.Name == "TouchInterest" then
                for _, top in ipairs(toplar) do
                    if top and top.Parent then
                        local dist = (top.Position - head.Position).Magnitude
                        local rawRadius = cfg.headReachRadius or 4
                        local yDiff = top.Position.Y - head.Position.Y
                        local dynamicRadius = rawRadius
                        if yDiff < 0.5 then dynamicRadius = math.min(1.5, rawRadius) end
                        local radius = math.clamp(dynamicRadius, 1, 15)
                        local isBallHighEnough = yDiff > 1.25
                        if dist < radius and (isJumping or isBallHighEnough) then
                            if firetouchinterest then
                                pcall(function() firetouchinterest(top, head, 0) firetouchinterest(top, head, 1) end)
                                if cfg.reactEnabled then applyReactPhysics(cfg.reactLevel) end
                            end
                            break
                        end
                    end
                end
            end
        end
    end
end)

local origAmbient = Lighting.Ambient
local origOutdoor = Lighting.OutdoorAmbient

local function updateWorldColor()
    local cc = Lighting:FindFirstChild("DyrmAmbience")
    if not cc then
        cc = Instance.new("ColorCorrectionEffect")
        cc.Name = "DyrmAmbience"
        cc.Parent = Lighting
    end

    if cfg.worldColorEnabled then
        local tint = Color3.new(1, 1, 1):Lerp(theme.Accent, 0.15)
        TweenService:Create(cc, TweenInfo.new(0.5), { TintColor = tint, Contrast = 0.1, Saturation = 0.2 }):Play()
        TweenService:Create(Lighting, TweenInfo.new(0.5), {
            Ambient = Color3.fromRGB(80, 80, 80),
            OutdoorAmbient = Color3.fromRGB(110, 110, 110),
        }):Play()
    else
        TweenService:Create(cc, TweenInfo.new(0.5), { TintColor = Color3.new(1, 1, 1), Contrast = 0, Saturation = 0 }):Play()
        TweenService:Create(Lighting, TweenInfo.new(0.5), {
            Ambient = origAmbient,
            OutdoorAmbient = origOutdoor,
        }):Play()
    end
end

local MOSS_FLAGS = { [1] = 15, [2] = 12, [3] = 10, [4] = 9, [5] = 7 }

local pingSpoofActive = false
local pingSpoofTasks = {}
local function startPingSpoof()
    if pingSpoofActive then return end
    pingSpoofActive = true
    local minPing, maxPing = 5, 25
    local RobloxGui = CoreGui:WaitForChild("RobloxGui", 3)
    local performanceStats = RobloxGui and RobloxGui:WaitForChild("PerformanceStats", 3)
    if not performanceStats then pingSpoofActive = false return end

    local targetStatButton, pingValueLabel, originalBarFrame
    for _, item in ipairs(performanceStats:GetChildren()) do
        local titleLabel = item:FindFirstChild("TitleLabel", true)
        if titleLabel and titleLabel.Text:lower():gsub(" ", ""):find("networkping") then
            targetStatButton = item
            pingValueLabel = item:FindFirstChild("ValueLabel", true)
            originalBarFrame = item:FindFirstChild("PS_BarFrame", true)
            break
        end
    end
    if not targetStatButton or not originalBarFrame then pingSpoofActive = false return end

    originalBarFrame.Visible = false
    local myGraph = Instance.new("Frame")
    myGraph.Name = "DyrmStableGraph"
    myGraph.Parent = originalBarFrame.Parent
    myGraph.Size = originalBarFrame.Size
    myGraph.Position = originalBarFrame.Position
    myGraph.BackgroundTransparency = 1
    myGraph.ClipsDescendants = true

    local layout = Instance.new("UIListLayout")
    layout.Parent = myGraph
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom

    local totalBars = 50
    local bars = {}
    local pingHistory = table.create(totalBars, 0)
    for i = 1, totalBars do
        local bar = Instance.new("Frame")
        bar.Parent = myGraph
        bar.BorderSizePixel = 0
        bar.LayoutOrder = i
        bar.Size = UDim2.new(1 / totalBars, 0, 0, 1)
        table.insert(bars, bar)
    end

    local currentPing = math.random(minPing, maxPing)
    table.insert(pingSpoofTasks, task.spawn(function()
        while pingSpoofActive do
            currentPing = math.random(minPing, maxPing)
            task.wait(5)
        end
    end))
    table.insert(pingSpoofTasks, task.spawn(function()
        while pingSpoofActive do
            table.remove(pingHistory, 1)
            table.insert(pingHistory, currentPing)
            for i, bar in ipairs(bars) do
                local val = pingHistory[i]
                bar.Size = UDim2.new(1 / totalBars, 0, math.clamp(val / 100, 0.05, 1), 0)
                bar.BackgroundColor3 = Color3.fromRGB(6, 182, 212)
            end
            task.wait(0.5)
        end
        if originalBarFrame then originalBarFrame.Visible = true end
        myGraph:Destroy()
        RunService:UnbindFromRenderStep("DyrmPingLock")
    end))
    RunService:BindToRenderStep("DyrmPingLock", Enum.RenderPriority.Last.Value, function()
        if pingSpoofActive and pingValueLabel then pingValueLabel.Text = tostring(math.floor(currentPing)) .. " ms" end
    end)
end
local function stopPingSpoof()
    pingSpoofActive = false
    for _, t in ipairs(pingSpoofTasks) do pcall(function() task.cancel(t) end) end
    pingSpoofTasks = {}
end

local ballHighlight, ballBillboard, ballTextLabel, landingRing, ballTrail, beamAttachment0
local playerHighlights = {}
local playerBeams = {}

local function isEnemy(plr)
    if not plr or plr == lp then return false end
    if not lp.Team or not plr.Team then return true end
    return plr.Team ~= lp.Team
end

local function createAfterimage(char)
    if not char then return end
    char.Archivable = true
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
            local success, clone = pcall(function() return part:Clone() end)
            if success and clone then
                clone:ClearAllChildren()
                clone.Anchored = true
                clone.CanCollide = false
                clone.CastShadow = false
                clone.Material = Enum.Material.ForceField
                clone.Color = theme.Accent
                clone.Transparency = -0.2
                clone.Parent = Workspace
                task.spawn(function()
                    for i = 1, 15 do
                        clone.Transparency = clone.Transparency + 0.08
                        clone.CFrame = clone.CFrame * CFrame.new(0, 0.03, 0)
                        task.wait(0.03)
                    end
                    clone:Destroy()
                end)
            end
        end
    end
end

local function setupVisuals()
    Players.PlayerRemoving:Connect(function(plr)
        if playerHighlights[plr] then playerHighlights[plr]:Destroy() playerHighlights[plr] = nil end
        if playerBeams[plr] then
            if playerBeams[plr].beam then playerBeams[plr].beam:Destroy() end
            if playerBeams[plr].attach0 then playerBeams[plr].attach0:Destroy() end
            if playerBeams[plr].attach1 then playerBeams[plr].attach1:Destroy() end
            playerBeams[plr] = nil
        end
    end)

    local lastAfterimage = 0
    local isRightClicking = false
    local isFaking = false
    local fakeStartTime = 0
    local fakeDir = 1

    local function isAutoFakeKey(kc)
        local target = cfg.autoFakeKeybind
        if typeof(target) == "EnumItem" then return kc == target end
        local ok, en = pcall(function() return Enum.KeyCode[target] end)
        return ok and kc == en
    end

    UserInputService.InputBegan:Connect(function(inp, gpe)
        if gpe then return end
        if inp.UserInputType == Enum.UserInputType.MouseButton2 then
            isRightClicking = true
        elseif isAutoFakeKey(inp.KeyCode) and cfg.autoFakeEnabled and cfg.silentDribble and isRightClicking then
            if not isFaking then
                isFaking = true
                fakeStartTime = tick()
                fakeDir = (math.random() > 0.5) and 1 or -1
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton2 then isRightClicking = false end
    end)

    local stCrosshairGui = Instance.new("ScreenGui")
    stCrosshairGui.Name = "DyrmSTCrosshair"
    stCrosshairGui.ResetOnSpawn = false

    local mobileGui, dStroke, sStroke
    if UserInputService.TouchEnabled then
        mobileGui = Instance.new("ScreenGui")
        mobileGui.Name = "DyrmMobileControls"
        mobileGui.ResetOnSpawn = false

        local dribbleBtn = Instance.new("TextButton", mobileGui)
        dribbleBtn.Size = UDim2.new(0, 70, 0, 70)
        dribbleBtn.Position = UDim2.new(1, -100, 1, -190)
        dribbleBtn.BackgroundColor3 = theme.ElementBg
        dribbleBtn.BackgroundTransparency = 0.1
        dribbleBtn.Text = "AIM"
        dribbleBtn.TextColor3 = theme.Accent
        dribbleBtn.Font = Enum.Font.GothamBold
        dribbleBtn.TextSize = 14
        Instance.new("UICorner", dribbleBtn).CornerRadius = UDim.new(0.5, 0)
        dribbleBtn.ZIndex = 100
        dStroke = Instance.new("UIStroke", dribbleBtn)
        dStroke.Thickness = 1.5
        dStroke.Color = theme.Accent
        dStroke.Transparency = 0.3

        dribbleBtn.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.Touch then isRightClicking = true end
        end)
        dribbleBtn.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.Touch then isRightClicking = false end
        end)

        local skillBtn = Instance.new("TextButton", mobileGui)
        skillBtn.Size = UDim2.new(0, 70, 0, 70)
        skillBtn.Position = UDim2.new(1, -100, 1, -280)
        skillBtn.BackgroundColor3 = theme.ElementBg
        skillBtn.BackgroundTransparency = 0.1
        skillBtn.Text = "SKILL"
        skillBtn.TextColor3 = theme.Text
        skillBtn.Font = Enum.Font.GothamBold
        skillBtn.TextSize = 12
        Instance.new("UICorner", skillBtn).CornerRadius = UDim.new(0.5, 0)
        skillBtn.ZIndex = 100
        sStroke = Instance.new("UIStroke", skillBtn)
        sStroke.Thickness = 1.5
        sStroke.Color = theme.SubText
        sStroke.Transparency = 0.3

        skillBtn.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.Touch and cfg.autoFakeEnabled and cfg.silentDribble and isRightClicking then
                if not isFaking then isFaking = true fakeStartTime = tick() end
            end
        end)

        local mobileOk = pcall(function() mobileGui.Parent = CoreGui end)
        if not mobileOk then mobileGui:Destroy() mobileGui = nil end
    end

    local chFrame = Instance.new("Frame")
    chFrame.Size = UDim2.new(0, 20, 0, 20)
    chFrame.BackgroundTransparency = 1
    chFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    chFrame.Visible = false
    chFrame.Parent = stCrosshairGui

    local chDot = Instance.new("Frame", chFrame)
    chDot.Size = UDim2.new(0, 4, 0, 4)
    chDot.AnchorPoint = Vector2.new(0.5, 0.5)
    chDot.Position = UDim2.new(0.5, 0, 0.5, 0)
    chDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", chDot).CornerRadius = UDim.new(1, 0)

    local chCircle = Instance.new("Frame", chFrame)
    chCircle.Size = UDim2.new(1, 0, 1, 0)
    chCircle.BackgroundTransparency = 1
    Instance.new("UICorner", chCircle).CornerRadius = UDim.new(1, 0)
    local chStroke = Instance.new("UIStroke", chCircle)
    chStroke.Thickness = 1.5
    chStroke.Color = Color3.fromRGB(255, 255, 255)
    chStroke.Transparency = 0.2

    local function applyChTheme()
        chDot.BackgroundColor3 = theme.Accent
        chStroke.Color = theme.AccentGlow
        if dStroke then dStroke.Color = theme.Accent end
        if sStroke then sStroke.Color = theme.Accent end
    end
    pcall(function() stCrosshairGui.Parent = CoreGui end)

    RunService.RenderStepped:Connect(function(dt)
        local tps = Workspace:FindFirstChild("TPSSystem") and Workspace.TPSSystem:FindFirstChild("TPS")
        local char = lp.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")

        applyChTheme()

        if isRightClicking and root and hum then
            local targetPos = nil

            if cfg.silentDribble then
                local cam = Workspace.CurrentCamera
                local lookDir = cam.CFrame.LookVector
                local flatDir = Vector3.new(lookDir.X, 0, lookDir.Z)
                if flatDir.Magnitude > 0.01 then flatDir = flatDir.Unit else flatDir = Vector3.new(1, 0, 0) end

                if isFaking then
                    local elapsed = tick() - fakeStartTime
                    local angle = 0
                    if elapsed < 0.12 then
                        angle = math.rad(70 * fakeDir)
                    elseif elapsed < 0.32 then
                        angle = math.rad(-85 * fakeDir)
                    else
                        isFaking = false
                    end
                    if angle ~= 0 then
                        local ca, sa = math.cos(angle), math.sin(angle)
                        flatDir = Vector3.new(flatDir.X * ca - flatDir.Z * sa, 0, flatDir.X * sa + flatDir.Z * ca)
                    end
                end

                targetPos = root.Position + (flatDir * 10)
                local vpSize = cam.ViewportSize
                chFrame.Position = UDim2.new(0, vpSize.X / 2, 0, vpSize.Y / 2)
                chFrame.Visible = true
            elseif cfg.gkAimEnabled and tps then
                local dist = (tps.Position - root.Position).Magnitude
                local pTime = math.clamp(dist / 60, 0, 0.35)
                local currentVel = tps.Velocity
                if dist < 12 then currentVel = Vector3.zero end
                local predictedPos = tps.Position + (currentVel * pTime)
                targetPos = Vector3.new(predictedPos.X, root.Position.Y, predictedPos.Z)
                local cam = Workspace.CurrentCamera
                local vpSize = cam.ViewportSize
                chFrame.Position = UDim2.new(0, vpSize.X / 2, 0, vpSize.Y / 2)
                chFrame.Visible = true
            else
                chFrame.Visible = false
            end

            UserInputService.MouseIconEnabled = not chFrame.Visible

            if targetPos and (targetPos - root.Position).Magnitude > 0.5 then
                local targetCFrame = CFrame.new(root.Position, targetPos)
                local lerpAlpha = math.clamp(cfg.aimbotSmoothness * (dt * 60), 0.01, 1)
                root.CFrame = root.CFrame:Lerp(targetCFrame, lerpAlpha)
                hum.AutoRotate = false
            else
                if not hum.AutoRotate then hum.AutoRotate = true end
            end
        else
            chFrame.Visible = false
            UserInputService.MouseIconEnabled = true
            if hum and not hum.AutoRotate then hum.AutoRotate = true end
        end

        if cfg.dashAfterimage and char and root then
            if root.Velocity.Magnitude > 22 and (tick() - lastAfterimage > 0.08) then
                lastAfterimage = tick()
                createAfterimage(char)
            end
        end

        if tps then
            if cfg.ballEspEnabled then
                if not ballHighlight or not ballHighlight.Parent then
                    ballHighlight = Instance.new("Highlight")
                    ballHighlight.Name = "DyrmBallEsp"
                    ballHighlight.FillColor = theme.Accent
                    ballHighlight.OutlineColor = theme.AccentGlow
                    ballHighlight.FillTransparency = 0.5
                    ballHighlight.OutlineTransparency = 0.1
                    ballHighlight.Parent = tps
                    ballBillboard = Instance.new("BillboardGui")
                    ballBillboard.Name = "DyrmBallTag"
                    ballBillboard.Size = UDim2.new(0, 150, 0, 40)
                    ballBillboard.StudsOffset = Vector3.new(0, 3, 0)
                    ballBillboard.AlwaysOnTop = true
                    ballBillboard.Parent = tps
                    ballTextLabel = Instance.new("TextLabel")
                    ballTextLabel.Size = UDim2.new(1, 0, 1, 0)
                    ballTextLabel.BackgroundTransparency = 1
                    ballTextLabel.TextColor3 = theme.Accent
                    ballTextLabel.Font = Enum.Font.GothamBlack
                    ballTextLabel.TextSize = 13
                    ballTextLabel.TextStrokeTransparency = 0.2
                    ballTextLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                    ballTextLabel.Parent = ballBillboard
                end
                ballHighlight.Enabled = true
                ballBillboard.Enabled = true
                if ballHighlight.FillColor ~= theme.Accent then
                    ballHighlight.FillColor = theme.Accent
                    ballHighlight.OutlineColor = theme.AccentGlow
                end
                if ballTextLabel.TextColor3 ~= theme.Accent then ballTextLabel.TextColor3 = theme.Accent end
                if root then
                    local dist = math.floor((root.Position - tps.Position).Magnitude)
                    ballTextLabel.Text = "[" .. dist .. "m]"
                end
            else
                if ballHighlight then ballHighlight.Enabled = false end
                if ballBillboard then ballBillboard.Enabled = false end
            end

            if cfg.ballVectorEnabled then
                if not landingRing or not landingRing.Parent then
                    landingRing = Instance.new("Part")
                    landingRing.Name = "DyrmLandingRing"
                    landingRing.Shape = Enum.PartType.Cylinder
                    landingRing.Size = Vector3.new(0.05, 4.5, 4.5)
                    landingRing.Material = Enum.Material.Neon
                    landingRing.CanCollide = false
                    landingRing.Anchored = true
                    landingRing.CastShadow = false
                    landingRing.Parent = Workspace
                    local decal = Instance.new("Decal", landingRing) decal.Texture = "rbxassetid://12223874929" decal.Face = Enum.NormalId.Right decal.Color3 = Color3.fromRGB(255, 255, 255)
                    local decal2 = Instance.new("Decal", landingRing) decal2.Texture = "rbxassetid://12223874929" decal2.Face = Enum.NormalId.Left decal2.Color3 = Color3.fromRGB(255, 255, 255)
                end
                landingRing.Color = theme.Accent
                landingRing.Transparency = 0.3 + math.abs(math.sin(tick() * 4)) * 0.4

                if tps.Velocity.Magnitude > 5 then
                    landingRing.Size = Vector3.new(0.05, 4.5, 4.5)
                    local g = Vector3.new(0, -Workspace.Gravity, 0)
                    local pPos = tps.Position
                    local pVel = tps.Velocity
                    if pVel.Magnitude > 200 or (root and (tps.Position - root.Position).Magnitude < 12) then pVel = Vector3.zero end
                    local dt2 = 0.05
                    local hitPart, hitPos, hitNormal
                    for i = 1, 30 do
                        local nextPos = pPos + pVel * dt2
                        local ray = Ray.new(pPos, nextPos - pPos)
                        hitPart, hitPos, hitNormal = Workspace:FindPartOnRayWithIgnoreList(ray, { char, tps, landingRing })
                        if hitPart then break end
                        pPos = nextPos
                        pVel = pVel + g * dt2
                    end
                    if not hitPart then
                        local ray = Ray.new(pPos, Vector3.new(0, -100, 0))
                        hitPart, hitPos, hitNormal = Workspace:FindPartOnRayWithIgnoreList(ray, { char, tps, landingRing })
                    end
                    if hitPos and hitNormal then
                        local right = hitNormal
                        local up = Vector3.new(0, 1, 0)
                        if math.abs(right.Y) > 0.99 then up = Vector3.new(1, 0, 0) end
                        local back = right:Cross(up).Unit
                        up = back:Cross(right).Unit
                        landingRing.CFrame = CFrame.fromMatrix(hitPos, right, up, back)
                    end
                else
                    landingRing.Size = Vector3.new(0, 0, 0)
                end
            elseif landingRing then
                landingRing.Size = Vector3.new(0, 0, 0)
            end

            if cfg.ballTrailEnabled then
                if not ballTrail or not ballTrail.Parent then
                    if not beamAttachment0 or not beamAttachment0.Parent then beamAttachment0 = Instance.new("Attachment", tps) end
                    local tA1 = Instance.new("Attachment", tps)
                    tA1.Position = Vector3.new(0, 0.6, 0)
                    ballTrail = Instance.new("Trail", tps)
                    ballTrail.Attachment0 = beamAttachment0
                    ballTrail.Attachment1 = tA1
                    ballTrail.Color = ColorSequence.new(theme.Accent)
                    ballTrail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
                    ballTrail.Lifetime = 0.4
                    ballTrail.LightEmission = 1
                end
                ballTrail.Color = ColorSequence.new(theme.Accent)
                ballTrail.Enabled = (tps.Velocity.Magnitude > 5)
            elseif ballTrail then
                ballTrail.Enabled = false
            end
        else
            if ballHighlight then ballHighlight.Enabled = false end
            if ballBillboard then ballBillboard.Enabled = false end
            if landingRing then landingRing.Size = Vector3.new(0, 0, 0) end
            if ballTrail then ballTrail.Enabled = false end
        end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= lp and plr.Character then
                local pRoot = plr.Character:FindFirstChild("HumanoidRootPart")
                local phum = plr.Character:FindFirstChild("Humanoid")
                local targetIsEnemy = isEnemy(plr)
                if cfg.playerChams and targetIsEnemy then
                    local hl = playerHighlights[plr]
                    if not hl or hl.Parent ~= plr.Character then
                        if hl then hl:Destroy() end
                        hl = Instance.new("Highlight")
                        hl.Name = "DyrmPlayerChams"
                        hl.FillColor = theme.Accent
                        hl.OutlineColor = theme.AccentGlow
                        hl.FillTransparency = 0.6
                        hl.OutlineTransparency = 0.2
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        hl.Parent = plr.Character
                        playerHighlights[plr] = hl
                    end
                    hl.Enabled = true
                    if hl.FillColor ~= theme.Accent then
                        hl.FillColor = theme.Accent
                        hl.OutlineColor = theme.AccentGlow
                    end
                elseif playerHighlights[plr] then
                    playerHighlights[plr].Enabled = false
                end

                if cfg.playerPredictor and targetIsEnemy and pRoot and phum then
                    local pData = playerBeams[plr]
                    if not pData or not pData.beam or pData.beam.Parent ~= pRoot then
                        if pData and pData.beam then pData.beam:Destroy() end
                        local a0 = Instance.new("Attachment", pRoot)
                        local a1 = Instance.new("Attachment", Workspace.Terrain)
                        local bm = Instance.new("Beam", pRoot)
                        bm.Color = ColorSequence.new(theme.Accent, theme.AccentGlow)
                        bm.Width0 = 0.35
                        bm.Width1 = 0.05
                        bm.Attachment0 = a0
                        bm.Attachment1 = a1
                        pData = { beam = bm, attach0 = a0, attach1 = a1 }
                        playerBeams[plr] = pData
                    end
                    pData.beam.Color = ColorSequence.new(theme.Accent, theme.AccentGlow)
                    local dir = phum.MoveDirection
                    if dir.Magnitude > 0.1 then
                        pData.attach1.WorldPosition = pRoot.Position + (dir * (phum.WalkSpeed * 0.8))
                        pData.beam.Enabled = true
                    else
                        pData.beam.Enabled = false
                    end
                elseif playerBeams[plr] then
                    playerBeams[plr].beam.Enabled = false
                end
            end
        end

    end)
end
task.spawn(setupVisuals)

local targetSpeed = 70
task.spawn(function()
    while task.wait(0) do
        if cfg.cooldownRemover then
            local backpack = lp:FindFirstChild("Backpack")
            local character = lp.Character
            if backpack and backpack:FindFirstChild("Speed") then backpack.Speed.Value = targetSpeed end
            if character and character:FindFirstChild("Speed") then character.Speed.Value = targetSpeed end
        end
    end
end)

task.spawn(function()
    while true do
        if cfg.mossEnabled then
            pcall(function() setfflag("TargetTimeDelayFacctorTenths", tostring(MOSS_FLAGS[cfg.mossLevel] or 15)) end)
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    local active = false
    while true do
        if cfg.pingSpoofEnabled and not active then
            active = true
            pcall(startPingSpoof)
        elseif not cfg.pingSpoofEnabled and active then
            active = false
            pcall(stopPingSpoof)
        end
        task.wait(0.5)
    end
end)

local function removeExistingSky()
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("Sky") then child:Destroy() end
    end
end

local function createSky(Bk, Dn, Ft, Lf, Rt, Up, StarCount)
    removeExistingSky()
    local sky = Instance.new("Sky")
    sky.SkyboxBk = Bk
    sky.SkyboxDn = Dn
    sky.SkyboxFt = Ft
    sky.SkyboxLf = Lf
    sky.SkyboxRt = Rt
    sky.SkyboxUp = Up
    sky.StarCount = StarCount or 0
    sky.Parent = Lighting
end

env.FootballHub.tpsSky = {
    night = function() createSky("http://www.roblox.com/asset/?id=12064107", "http://www.roblox.com/asset/?id=12064152", "http://www.roblox.com/asset/?id=12064121", "http://www.roblox.com/asset/?id=12063984", "http://www.roblox.com/asset/?id=12064115", "http://www.roblox.com/asset/?id=12064131", 0) end,
    sakura = function() createSky("http://www.roblox.com/asset/?id=271042516", "http://www.roblox.com/asset/?id=271077243", "http://www.roblox.com/asset/?id=271042556", "http://www.roblox.com/asset/?id=271042310", "http://www.roblox.com/asset/?id=271042467", "http://www.roblox.com/asset/?id=271077958", 1334) end,
    purpleNight = function() createSky("http://www.roblox.com/asset/?id=5084575798", "http://www.roblox.com/asset/?id=5084575916", "http://www.roblox.com/asset/?id=5103949679", "http://www.roblox.com/asset/?id=5103948542", "http://www.roblox.com/asset/?id=5103948784", "http://www.roblox.com/asset/?id=5084576400", 3000) end,
    gray = function() createSky("http://www.roblox.com/asset/?id=18703245834", "http://www.roblox.com/asset/?id=18703243349", "http://www.roblox.com/asset/?id=18703240532", "http://www.roblox.com/asset/?id=18703237556", "http://www.roblox.com/asset/?id=18703235430", "http://www.roblox.com/asset/?id=18703232671", 3500) end,
    pinkie = function() createSky("http://www.roblox.com/asset/?id=11555017034", "http://www.roblox.com/asset/?id=11555013415", "http://www.roblox.com/asset/?id=11555010145", "http://www.roblox.com/asset/?id=11555006545", "http://www.roblox.com/asset/?id=11555000712", "http://www.roblox.com/asset/?id=11554996247", 3000) end,
    reset = function() removeExistingSky() end,
}

env.FootballHub.tpsAmbience = updateWorldColor
end

-- ---------------------------------------------------------------------------
-- Touchline
-- ---------------------------------------------------------------------------

local function scriptTouchline()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local lp = Players.LocalPlayer
local cfg = SETTINGS.TOUCHLINE

local function note(title, text)
    local lib = env.FootballHub.library
    if lib then pcall(function() lib:Notify({ Title = title, Text = text, Duration = 3 }) end) end
end

local function getFootballFolder()
    return Workspace:FindFirstChild("Footballs") or Workspace:FindFirstChild("TPSSystem")
end

local function getClosestFootball()
    local folder = getFootballFolder()
    if not folder then return nil end
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local best, closest = math.huge, nil
    for _, b in ipairs(folder:GetChildren()) do
        local part = b:IsA("BasePart") and b or b:FindFirstChildWhichIsA("BasePart")
        if part then
            local d = (part.Position - hrp.Position).Magnitude
            if d < best then best = d closest = part end
        end
    end
    return closest, best
end

local function removeExistingSky()
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("Sky") then child:Destroy() end
    end
end

local function createSky(Bk, Dn, Ft, Lf, Rt, Up, StarCount)
    removeExistingSky()
    local sky = Instance.new("Sky")
    sky.SkyboxBk = Bk
    sky.SkyboxDn = Dn
    sky.SkyboxFt = Ft
    sky.SkyboxLf = Lf
    sky.SkyboxRt = Rt
    sky.SkyboxUp = Up
    sky.StarCount = StarCount or 0
    sky.Parent = Lighting
end

env.FootballHub.touchlineSky = {
    night = function() createSky("http://www.roblox.com/asset/?id=12064107", "http://www.roblox.com/asset/?id=12064152", "http://www.roblox.com/asset/?id=12064121", "http://www.roblox.com/asset/?id=12063984", "http://www.roblox.com/asset/?id=12064115", "http://www.roblox.com/asset/?id=12064131", 0) end,
    sakura = function() createSky("http://www.roblox.com/asset/?id=271042516", "http://www.roblox.com/asset/?id=271077243", "http://www.roblox.com/asset/?id=271042556", "http://www.roblox.com/asset/?id=271042310", "http://www.roblox.com/asset/?id=271042467", "http://www.roblox.com/asset/?id=271077958", 1334) end,
    purpleNight = function() createSky("http://www.roblox.com/asset/?id=5084575798", "http://www.roblox.com/asset/?id=5084575916", "http://www.roblox.com/asset/?id=5103949679", "http://www.roblox.com/asset/?id=5103948542", "http://www.roblox.com/asset/?id=5103948784", "http://www.roblox.com/asset/?id=5084576400", 3000) end,
    gray = function() createSky("http://www.roblox.com/asset/?id=18703245834", "http://www.roblox.com/asset/?id=18703243349", "http://www.roblox.com/asset/?id=18703240532", "http://www.roblox.com/asset/?id=18703237556", "http://www.roblox.com/asset/?id=18703235430", "http://www.roblox.com/asset/?id=18703232671", 3500) end,
    pinkie = function() createSky("http://www.roblox.com/asset/?id=11555017034", "http://www.roblox.com/asset/?id=11555013415", "http://www.roblox.com/asset/?id=11555010145", "http://www.roblox.com/asset/?id=11555006545", "http://www.roblox.com/asset/?id=11555000712", "http://www.roblox.com/asset/?id=11554996247", 3000) end,
    reset = function() removeExistingSky() end,
}

-- ---------------------------------------------------------------------------
-- reach (collisionless = method 1, collision = method 2)
-- ---------------------------------------------------------------------------

-- collisionless: keeps every ball supersized with collision off
local noCollide = { parts = {}, on = false }

local function noCollideSnapshot()
    local folder = getFootballFolder()
    if not folder then return end
    for _, ball in ipairs(folder:GetChildren()) do
        local part = ball:IsA("BasePart") and ball or ball:FindFirstChildWhichIsA("BasePart")
        if part and not noCollide.parts[part] then
            noCollide.parts[part] = part.Size
        end
    end
end

local function noCollideReset()
    for part, size in pairs(noCollide.parts) do
        if part and part.Parent then
            part.Size = size
            part.Transparency = 0
            part.CanCollide = true
        end
    end
    noCollide.parts = {}
    noCollide.on = false
end

RunService.RenderStepped:Connect(function()
    if cfg.reachNoCollide.enabled then
        if not noCollide.on then noCollide.on = true end
        noCollideSnapshot()
        local size = math.clamp(cfg.reachNoCollide.size, 1, 30)
        local trans = cfg.reachNoCollide.visible and 0.7 or 1
        for part in pairs(noCollide.parts) do
            if part and part.Parent then
                part.Size = Vector3.new(size, size, size)
                part.Transparency = trans
                part.CanCollide = false
            end
        end
    elseif noCollide.on then
        noCollideReset()
    end
end)

-- collision: only the nearest ball within range gets resized, with a follow marker
local collide = { parts = {}, originals = {}, indicator = nil }

local function collideTrack(part)
    if part and part:IsA("BasePart") and not collide.originals[part] then
        collide.parts[part] = true
        collide.originals[part] = part.Size
    end
end

local function collideReset()
    for part, size in pairs(collide.originals) do
        if part and part.Parent then
            part.Size = size
            part.Transparency = 0
            part.CanCollide = true
        end
    end
    collide.parts = {}
    collide.originals = {}
    if collide.indicator then collide.indicator:Destroy() collide.indicator = nil end
end

RunService.Heartbeat:Connect(function()
    if not cfg.reachCollide.enabled then
        if next(collide.originals) ~= nil then collideReset() end
        return
    end
    local folder = getFootballFolder()
    if folder then
        for _, item in ipairs(folder:GetChildren()) do
            collideTrack(item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart"))
        end
    end
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local nearest, nearestDist = nil, math.huge
    for part in pairs(collide.parts) do
        if part and part.Parent then
            local d = (part.Position - hrp.Position).Magnitude
            if d < nearestDist then nearestDist = d nearest = part end
        end
    end
    if not collide.indicator or not collide.indicator.Parent then
        local indicator = Instance.new("Part")
        indicator.Name = "BallFollowPart"
        indicator.Shape = Enum.PartType.Ball
        indicator.Size = Vector3.new(2.25, 2.25, 2.25)
        indicator.Anchored = true
        indicator.CanCollide = true
        indicator.CanTouch = false
        indicator.CanQuery = false
        indicator.Transparency = 1
        indicator.Material = Enum.Material.ForceField
        indicator.Color = Color3.fromRGB(0, 200, 255)
        indicator.Parent = Workspace
        collide.indicator = indicator
    end
    local size = math.clamp(cfg.reachCollide.size, 1, 30)
    local trans = cfg.reachCollide.visible and 0.7 or 1
    if nearest and nearestDist <= cfg.reachCollide.distance then
        for part in pairs(collide.parts) do
            if part and part.Parent then
                part.Size = Vector3.new(size, size, size)
                part.Transparency = trans
                part.CanCollide = false
            end
        end
        collide.indicator.CFrame = nearest.CFrame
    else
        for part, orig in pairs(collide.originals) do
            if part and part.Parent then
                part.Size = orig
                part.Transparency = 0
                part.CanCollide = true
            end
        end
        collide.indicator.CFrame = CFrame.new(0, -1000, 0)
    end
end)

-- ---------------------------------------------------------------------------
-- movement
-- ---------------------------------------------------------------------------

local prevWalk = nil
RunService.Heartbeat:Connect(function()
    local char = lp.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if cfg.walk.enabled then
        if not prevWalk then prevWalk = hum.WalkSpeed end
        hum.WalkSpeed = cfg.walk.speed
    elseif prevWalk then
        hum.WalkSpeed = prevWalk
        prevWalk = nil
    end
end)

RunService.Heartbeat:Connect(function()
    if not cfg.tpWalk.enabled then return end
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    if hum.MoveDirection.Magnitude < 0.1 then return end
    hrp.CFrame = hrp.CFrame + hum.MoveDirection * cfg.tpWalk.speed
end)

local flyBV = nil
RunService.Heartbeat:Connect(function()
    if cfg.fly.enabled then
        local char = lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")
        if not hrp or not hum then return end
        hum.PlatformStand = true
        if not flyBV or not flyBV.Parent then
            flyBV = Instance.new("BodyVelocity", hrp)
            flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        end
        local move = hum.MoveDirection
        local upVec = UserInputService:IsKeyDown(Enum.KeyCode.Space) and Vector3.new(0, 1, 0) or Vector3.zero
        local downVec = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and Vector3.new(0, -1, 0) or Vector3.zero
        local dir = (move.Magnitude > 0.1 and move or Vector3.zero) + upVec + downVec
        flyBV.Velocity = dir.Magnitude > 0 and dir.Unit * cfg.fly.speed or Vector3.zero
    else
        if flyBV then pcall(function() flyBV:Destroy() end) flyBV = nil end
        local hum = lp.Character and lp.Character:FindFirstChild("Humanoid")
        if hum then hum.PlatformStand = false end
    end
end)

-- ---------------------------------------------------------------------------
-- GK auto dive
-- ---------------------------------------------------------------------------

local ANIM_HEADER = "rbxassetid://83669895507175"
local ANIM_BACK   = "rbxassetid://133843606757895"
local ANIM_RIGHT  = "rbxassetid://130737929832335"
local ANIM_LEFT   = "rbxassetid://97298506180835"

local gkOnCooldown = false
local gkAnimPlaying = false
local liveTrack = nil
local touchCD = false

local function inBox()
    local gui = lp:FindFirstChild("PlayerGui")
    if not gui then return false end
    local main = gui:FindFirstChild("Main")
    if not main then return false end
    local values = main:FindFirstChild("Values")
    if not values then return false end
    local goalie = values:FindFirstChild("Goalie")
    if not goalie then return false end
    return goalie.Value == true
end

local function getKickRemote()
    local r = ReplicatedStorage:FindFirstChild("Remotes")
    r = r and r:FindFirstChild("Game")
    r = r and r:FindFirstChild("Touch")
    r = r and r:FindFirstChild("Kick")
    return r
end

local function getAllBalls()
    local folder = getFootballFolder()
    if not folder then return {} end
    local balls = {}
    for _, obj in ipairs(folder:GetChildren()) do
        local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
        if part then table.insert(balls, part) end
    end
    return balls
end

local function getMostDangerousBall()
    local char = lp.Character
    if not char then return nil, math.huge end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, math.huge end
    local balls = getAllBalls()
    if #balls == 0 then return nil, math.huge end
    local bestBall, bestScore, bestDist = nil, -math.huge, math.huge
    for _, ball in ipairs(balls) do
        local toPlayer = hrp.Position - ball.Position
        local dist = toPlayer.Magnitude
        if dist <= cfg.gk.range then
            local vel = ball.AssemblyLinearVelocity
            local speed = vel.Magnitude
            local approachFactor = 0
            if speed > 1 and dist > 0 then approachFactor = vel.Unit:Dot(toPlayer.Unit) end
            local score = (approachFactor * speed) + (1 / math.max(dist, 1)) * 10
            if score > bestScore then bestScore = score bestBall = ball bestDist = dist end
        end
    end
    if not bestBall then
        local minDist = math.huge
        for _, ball in ipairs(balls) do
            local d = (ball.Position - hrp.Position).Magnitude
            if d < minDist then minDist = d bestBall = ball bestDist = d end
        end
    end
    return bestBall, bestDist
end

local function pickDive(hrp, ballPos)
    local lpos = hrp.CFrame:PointToObjectSpace(ballPos)
    if lpos.Y > 4 then return ANIM_HEADER, { Right = false, Ground = false, Left = false } end
    if math.abs(lpos.X) >= math.abs(lpos.Z) then
        if lpos.X > 0 then return ANIM_RIGHT, { Right = true, Ground = false, Left = false } else return ANIM_LEFT, { Right = false, Ground = false, Left = true } end
    else
        if lpos.Z < 0 then return ANIM_HEADER, { Right = false, Ground = false, Left = false } else return ANIM_BACK, { Right = false, Ground = false, Left = false } end
    end
end

local function reachTouchAll()
    for _, ball in ipairs(getAllBalls()) do
        local origSize = ball.Size
        local origCollide = ball.CanCollide
        pcall(function() ball.Size = Vector3.new(15, 15, 15) ball.CanCollide = false end)
        task.delay(0.18, function() pcall(function() if ball and ball.Parent then ball.Size = origSize ball.CanCollide = origCollide end end) end)
    end
end

local function fireAllKicks(hrp, flags)
    local remote = getKickRemote()
    if not remote then return end
    local cf = CFrame.new(hrp.Position, hrp.Position + hrp.CFrame.LookVector)
    for _, ball in ipairs(getAllBalls()) do
        pcall(function() remote:FireServer({ ball, "Dive", 1, flags, cf, Vector3.zero }) end)
    end
end

local function stopAnim()
    if liveTrack then pcall(function() liveTrack:Stop() end) liveTrack = nil end
    gkAnimPlaying = false
end

local function playAnim(char, animId)
    stopAnim()
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    gkAnimPlaying = true
    local anim = Instance.new("Animation")
    anim.AnimationId = animId
    local track = hum:LoadAnimation(anim)
    liveTrack = track
    track:Play()
    track.Stopped:Connect(function() gkAnimPlaying = false liveTrack = nil pcall(function() anim:Destroy() end) end)
    task.delay(4, function() if liveTrack == track then stopAnim() pcall(function() anim:Destroy() end) end end)
end

local function doDive(ball)
    if gkOnCooldown or gkAnimPlaying then return end
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    gkOnCooldown = true
    local ballPos = ball.Position
    local animId, flags = pickDive(hrp, ballPos)
    local flat = Vector3.new(ballPos.X - hrp.Position.X, 0, ballPos.Z - hrp.Position.Z)
    if flat.Magnitude < 0.01 then flat = hrp.CFrame.LookVector * Vector3.new(1, 0, 1) end
    flat = flat.Unit
    local launchVel = flat * cfg.gk.speed + Vector3.new(0, cfg.gk.lift, 0)
    hrp.AssemblyLinearVelocity = launchVel
    local frames = 0
    local pushConn
    pushConn = RunService.Heartbeat:Connect(function()
        frames = frames + 1
        if frames <= 3 then pcall(function() hrp.AssemblyLinearVelocity = launchVel end) else pushConn:Disconnect() end
    end)
    playAnim(char, animId)
    for _, t in ipairs({ 0.08, 0.22, 0.38, 0.52 }) do
        task.delay(t, function() reachTouchAll() end)
    end
    local loopStart = tick()
    local loopConn
    loopConn = RunService.PreSimulation:Connect(function()
        local h = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
        if not h then loopConn:Disconnect() return end
        for _, b in ipairs(getAllBalls()) do
            if (b.Position - h.Position).Magnitude < 5 then loopConn:Disconnect() return end
        end
        if tick() - loopStart >= 3.5 then loopConn:Disconnect() return end
        fireAllKicks(h, flags)
    end)
    task.delay(cfg.gk.cooldown, function() gkOnCooldown = false end)
end

RunService.Heartbeat:Connect(function()
    if not cfg.gk.enabled or not inBox() then return end
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local ball, dist = getMostDangerousBall()
    if not ball then return end
    if dist < 4.5 and not touchCD then
        touchCD = true
        reachTouchAll()
        task.delay(0.08, function() touchCD = false end)
    end
    if not gkOnCooldown and not gkAnimPlaying and dist <= cfg.gk.hitRadius then doDive(ball) end
end)

-- ---------------------------------------------------------------------------
-- ball prediction
-- ---------------------------------------------------------------------------

local PRED_GRAVITY = -98.1
local predObjs = {}
local cachedPing = 0.06

task.spawn(function()
    while true do
        pcall(function() cachedPing = math.clamp(lp:GetNetworkPing(), 0.008, 0.30) end)
        task.wait(0.2)
    end
end)

local function makePredBeam(ball)
    local folder = Workspace:FindFirstChild("_PredViz")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "_PredViz"
        folder.Parent = Workspace
    end
    local a0 = Instance.new("Attachment") a0.Parent = Workspace.Terrain
    local a1 = Instance.new("Attachment") a1.Parent = Workspace.Terrain
    local beam = Instance.new("Beam")
    beam.Attachment0 = a0
    beam.Attachment1 = a1
    beam.Width0 = 0.14
    beam.Width1 = 0.14
    beam.FaceCamera = true
    beam.LightInfluence = 0
    beam.Transparency = NumberSequence.new(0.15)
    beam.Parent = folder
    local sphere = Instance.new("Part")
    sphere.Anchored = true
    sphere.CanCollide = false
    sphere.Shape = Enum.PartType.Ball
    sphere.Size = Vector3.new(0.6, 0.6, 0.6)
    sphere.Material = Enum.Material.Neon
    sphere.Color = Color3.fromRGB(255, 220, 0)
    sphere.Transparency = 0.25
    sphere.CFrame = CFrame.new(0, -9999, 0)
    sphere.Parent = folder
    predObjs[ball] = { beam = beam, a0 = a0, a1 = a1, sphere = sphere }
end

local function cleanPredObjs()
    for _, t in pairs(predObjs) do
        pcall(function() t.beam:Destroy() t.a0:Destroy() t.a1:Destroy() t.sphere:Destroy() end)
    end
    predObjs = {}
    local f = Workspace:FindFirstChild("_PredViz")
    if f then f:Destroy() end
end

local function simulateLanding(pos, vel)
    local px, py, pz = pos.X, pos.Y, pos.Z
    local vx, vy, vz = vel.X, vel.Y, vel.Z
    local dt = 0.03
    local steps = math.floor(cfg.prediction.ahead / dt)
    for _ = 1, steps do
        vy = vy + PRED_GRAVITY * dt * dt
        px = px + vx * dt
        py = py + vy * dt
        pz = pz + vz * dt
        if py <= 1 then py = 1 break end
    end
    return Vector3.new(px, py, pz)
end

RunService.Heartbeat:Connect(function()
    if not cfg.prediction.enabled then
        if next(predObjs) ~= nil or Workspace:FindFirstChild("_PredViz") then cleanPredObjs() end
        return
    end
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for ball in pairs(predObjs) do
        if not ball or not ball.Parent then
            local t = predObjs[ball]
            if t then pcall(function() t.beam:Destroy() t.a0:Destroy() t.a1:Destroy() t.sphere:Destroy() end) end
            predObjs[ball] = nil
        end
    end
    local folder = getFootballFolder()
    if not folder then return end
    for _, ball in ipairs(folder:GetChildren()) do
        local part = ball:IsA("BasePart") and ball or ball:FindFirstChildWhichIsA("BasePart")
        if part then
            local dist = (part.Position - hrp.Position).Magnitude
            if dist <= cfg.prediction.range then
                if not predObjs[part] then makePredBeam(part) end
                local t = predObjs[part]
                local vel = part.AssemblyLinearVelocity
                if t and vel.Magnitude > 0.5 then
                    local landing = simulateLanding(part.Position, vel)
                    local predPos = Vector3.new(part.Position.X + vel.X * cachedPing, part.Position.Y + vel.Y * cachedPing, part.Position.Z + vel.Z * cachedPing)
                    local reachable = (predPos - hrp.Position).Magnitude < cfg.prediction.touch
                    local col = reachable and Color3.fromRGB(0, 255, 80) or Color3.fromRGB(255, 40, 40)
                    t.beam.Color = ColorSequence.new(col)
                    t.a0.WorldPosition = part.Position
                    t.a1.WorldPosition = landing
                    t.sphere.CFrame = CFrame.new(landing)
                end
            else
                local t = predObjs[part]
                if t then
                    pcall(function()
                        t.a0.WorldPosition = Vector3.new(0, -9999, 0)
                        t.a1.WorldPosition = Vector3.new(0, -9999, 0)
                        t.sphere.CFrame = CFrame.new(0, -9999, 0)
                    end)
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- extras
-- ---------------------------------------------------------------------------

local jumpOrig = nil
RunService.Heartbeat:Connect(function()
    local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if cfg.jump.enabled then
        if not jumpOrig then jumpOrig = hum.JumpPower end
        hum.UseJumpPower = true
        hum.JumpPower = cfg.jump.power
    elseif jumpOrig then
        hum.JumpPower = jumpOrig
        jumpOrig = nil
    end
end)

RunService.Heartbeat:Connect(function()
    if not cfg.dribble.enabled then return end
    local char = lp.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if not hum then return end
    local ball = getClosestFootball()
    if not ball then return end
    hum.WalkSpeed = cfg.dribble.speed
    hum:MoveTo(ball.Position)
end)

-- air dribble method 1 (platform under the closest ball)
local zzzPart = nil
RunService.RenderStepped:Connect(function()
    if cfg.airDribble1.enabled then
        if not zzzPart or not zzzPart.Parent then
            local part = Instance.new("Part")
            part.Name = "ZZZHelperPart"
            part.Shape = Enum.PartType.Cylinder
            part.Size = Vector3.new(0.2, cfg.airDribble1.size, cfg.airDribble1.size)
            part.CFrame = CFrame.Angles(0, 0, math.rad(90))
            part.Anchored = true
            part.CanCollide = true
            part.Transparency = cfg.airDribble1.visible and 0.45 or 1
            part.Color = Color3.fromRGB(255, 50, 90)
            part.Material = Enum.Material.ForceField
            part.Parent = Workspace
            zzzPart = part
        end
        zzzPart.Size = Vector3.new(0.2, cfg.airDribble1.size, cfg.airDribble1.size)
        zzzPart.Transparency = cfg.airDribble1.visible and 0.45 or 1
        local ball = getClosestFootball()
        if ball then
            zzzPart.CFrame = CFrame.new(ball.Position - Vector3.new(0, cfg.airDribble1.yOffset, 0)) * CFrame.Angles(0, 0, math.rad(90))
        else
            zzzPart.Position = Vector3.new(0, -999, 0)
        end
    elseif zzzPart then
        zzzPart:Destroy()
        zzzPart = nil
    end
end)

-- air dribble method 2 (a platform per ball, only solid while jumping)
local airPlatforms = {}
RunService.Heartbeat:Connect(function()
    if cfg.airDribble2.enabled then
        local folder = getFootballFolder()
        if folder then
            local hum = lp.Character and lp.Character:FindFirstChild("Humanoid")
            local isJumping = hum and (hum:GetState() == Enum.HumanoidStateType.Jumping or hum:GetState() == Enum.HumanoidStateType.Freefall)
            for _, item in ipairs(folder:GetChildren()) do
                local ball = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart")
                if ball then
                    local plat = airPlatforms[ball]
                    if not plat or not plat.Parent then
                        plat = Instance.new("Part")
                        plat.Name = "AirDribbleHelper"
                        plat.Anchored = true
                        plat.CanCollide = false
                        plat.CanTouch = false
                        plat.CanQuery = false
                        plat.Material = Enum.Material.Neon
                        plat.Color = Color3.fromRGB(128, 128, 128)
                        plat.Parent = Workspace
                        airPlatforms[ball] = plat
                    end
                    plat.Size = Vector3.new(cfg.airDribble2.size, 1, cfg.airDribble2.size)
                    plat.Transparency = cfg.airDribble2.visible and 0.5 or 1
                    plat.CFrame = CFrame.new(ball.Position.X, ball.Position.Y - 1.2, ball.Position.Z)
                    plat.CanCollide = isJumping and true or false
                    plat.CanTouch = isJumping and true or false
                    plat.CanQuery = isJumping and true or false
                end
            end
        end
    else
        for ball, plat in pairs(airPlatforms) do
            if plat then pcall(function() plat:Destroy() end) end
            airPlatforms[ball] = nil
        end
    end
end)

-- ball fling
local function getKickRemote2()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local gameRemote = remotes:FindFirstChild("Game")
        if gameRemote then
            local touch = gameRemote:FindFirstChild("Touch")
            if touch then return touch:FindFirstChild("Kick") end
        end
    end
    return nil
end

local function fireFlingKick()
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local ball, dist = getClosestFootball()
    local safeReach = math.clamp(cfg.ballFling.reach, 1, 15)
    if not ball or not dist or dist > safeReach then return end
    local kickRemote = getKickRemote2()
    if not kickRemote then return end
    local Camera = Workspace.CurrentCamera
    if not Camera then return end
    local lookVector = Camera.CFrame.LookVector
    local direction = CFrame.new(hrp.Position + lookVector * 5, hrp.Position + lookVector * 10)
    pcall(function() kickRemote:FireServer({ ball, "Shoot", 1, { Right = false, Ground = true, Left = false }, direction, Vector3.zero }) end)
end

RunService.PreSimulation:Connect(function()
    if cfg.ballFling.enabled then fireFlingKick() end
end)

-- ---------------------------------------------------------------------------
-- moss / misc
-- ---------------------------------------------------------------------------

local T_MOSS_FLAGS = { [1] = 15, [2] = 12, [3] = 10, [4] = 9, [5] = 7 }

task.spawn(function()
    while true do
        if cfg.moss.enabled then
            pcall(function() setfflag("TargetTimeDelayFacctorTenths", tostring(T_MOSS_FLAGS[cfg.moss.level] or 15)) end)
        end
        task.wait(0.5)
    end
end)

local tPingActive = false
local tPingTasks = {}
local function startTPingSpoof()
    if tPingActive then return end
    tPingActive = true
    local minPing, maxPing = 5, 25
    local RobloxGui = game:GetService("CoreGui"):WaitForChild("RobloxGui", 3)
    local performanceStats = RobloxGui and RobloxGui:WaitForChild("PerformanceStats", 3)
    if not performanceStats then tPingActive = false return end

    local targetStatButton, pingValueLabel, originalBarFrame
    for _, item in ipairs(performanceStats:GetChildren()) do
        local titleLabel = item:FindFirstChild("TitleLabel", true)
        if titleLabel and titleLabel.Text:lower():gsub(" ", ""):find("networkping") then
            targetStatButton = item
            pingValueLabel = item:FindFirstChild("ValueLabel", true)
            originalBarFrame = item:FindFirstChild("PS_BarFrame", true)
            break
        end
    end
    if not targetStatButton or not originalBarFrame then tPingActive = false return end

    originalBarFrame.Visible = false
    local myGraph = Instance.new("Frame")
    myGraph.Name = "DyrmStableGraph"
    myGraph.Parent = originalBarFrame.Parent
    myGraph.Size = originalBarFrame.Size
    myGraph.Position = originalBarFrame.Position
    myGraph.BackgroundTransparency = 1
    myGraph.ClipsDescendants = true

    local layout = Instance.new("UIListLayout")
    layout.Parent = myGraph
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom

    local totalBars = 50
    local bars = {}
    local pingHistory = table.create(totalBars, 0)
    for i = 1, totalBars do
        local bar = Instance.new("Frame")
        bar.Parent = myGraph
        bar.BorderSizePixel = 0
        bar.LayoutOrder = i
        bar.Size = UDim2.new(1 / totalBars, 0, 0, 1)
        table.insert(bars, bar)
    end

    local currentPing = math.random(minPing, maxPing)
    table.insert(tPingTasks, task.spawn(function()
        while tPingActive do
            currentPing = math.random(minPing, maxPing)
            task.wait(5)
        end
    end))
    table.insert(tPingTasks, task.spawn(function()
        while tPingActive do
            table.remove(pingHistory, 1)
            table.insert(pingHistory, currentPing)
            for i, bar in ipairs(bars) do
                local val = pingHistory[i]
                bar.Size = UDim2.new(1 / totalBars, 0, math.clamp(val / 100, 0.05, 1), 0)
                bar.BackgroundColor3 = Color3.fromRGB(6, 182, 212)
            end
            task.wait(0.5)
        end
        if originalBarFrame then originalBarFrame.Visible = true end
        myGraph:Destroy()
        RunService:UnbindFromRenderStep("DyrmPingLock")
    end))
    RunService:BindToRenderStep("DyrmPingLock", Enum.RenderPriority.Last.Value, function()
        if tPingActive and pingValueLabel then pingValueLabel.Text = tostring(math.floor(currentPing)) .. " ms" end
    end)
end
local function stopTPingSpoof()
    tPingActive = false
    for _, t in ipairs(tPingTasks) do pcall(function() task.cancel(t) end) end
    tPingTasks = {}
end

task.spawn(function()
    local active = false
    while true do
        if cfg.moss.pingSpoof and not active then
            active = true
            pcall(startTPingSpoof)
        elseif not cfg.moss.pingSpoof and active then
            active = false
            pcall(stopTPingSpoof)
        end
        task.wait(0.5)
    end
end)

env.FootballHub.touchlineNote = note
end

-- ---------------------------------------------------------------------------
-- VRA / Overtime
-- ---------------------------------------------------------------------------

local function scriptVRA()
local STATE = STATE or { alive = function() return true end }
local UIS = game:GetService("UserInputService")
local PS5 = (pcall(function() return Enum.Platform.PS5 end) and Enum.Platform.PS5) or Enum.Platform.PS4

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    if STATE.alive() and not checkcaller() and rawequal(self, UIS) and getnamecallmethod() == "GetPlatform" then
        return PS5
    end
    return oldNamecall(self, ...)
end))
end

-- ---------------------------------------------------------------------------
-- game table + detection
-- ---------------------------------------------------------------------------

local GAMES = {
    {
        key = "tpl",
        name = "TPL",
        short = "TPL",
        ids = { 127035068456454 },
        match = { "tpl" },
        owner = { id = 113403743, group = true },
        run = scriptTPL,
    },
    {
        key = "tps",
        name = "TPS Street Soccer",
        short = "TPS",
        ids = { 335760407 },
        match = { "tps", "street soccer" },
        owner = { id = 1571620, group = false },
        run = scriptTPS,
    },
    {
        key = "touchline",
        name = "Touchline",
        short = "Touchline",
        ids = { 109258067111533 },
        match = { "touchline" },
        owner = { id = 35121139, group = true },
        run = scriptTouchline,
    },
    {
        key = "vra",
        name = "VRA/Overtime",
        short = "VRA",
        ids = { 73057116341460 },
        match = { "vra", "overtime" },
        owner = { id = 78475467, group = true },
        run = scriptVRA,
    },
}

local function ownedBy(g)
    if not g.owner or game.CreatorId ~= g.owner.id then
        return false
    end
    local isGroup = game.CreatorType == Enum.CreatorType.Group
    return isGroup == g.owner.group
end

-- PlaceId first, then the place name, then whoever owns the experience. The
-- owner check is what catches match/lobby sub-places that use a different id.
local function findGame()
    for _, g in ipairs(GAMES) do
        for _, id in ipairs(g.ids) do
            if game.PlaceId == id then
                return g
            end
        end
    end

    local name = string.lower(game.Name or "")
    for _, g in ipairs(GAMES) do
        for _, m in ipairs(g.match) do
            if string.find(name, m, 1, true) then
                return g
            end
        end
    end

    for _, g in ipairs(GAMES) do
        if ownedBy(g) then
            return g
        end
    end
end

local detected = findGame()

if not detected then
    print(string.format(
        "[Football Hub] no game matched (PlaceId=%d Name=%q CreatorId=%d CreatorType=%s)",
        game.PlaceId, tostring(game.Name), game.CreatorId, tostring(game.CreatorType)
    ))
end

-- the menu loads as its own chunk - this is the arrangement that runs on weak executors
-- Nebula UI v1.4 by SugaDev / SugaBlaz - https://github.com/SugaBlaz/UI-Library

local MENU_URLS = {
    "https://raw.githubusercontent.com/SugaBlaz/UI-Library/refs/heads/main/Nebula%20UI.lua",
    "https://cdn.jsdelivr.net/gh/SugaBlaz/UI-Library@main/Nebula%20UI.lua",
}

local function loadMenu()
    for _, url in ipairs(MENU_URLS) do
        local ok, lib = pcall(function()
            return loadstring(game:HttpGet(url))()
        end)
        if ok and type(lib) == "table" then
            return lib
        end
    end
end

local Library = loadMenu()

if not Library then
    warn("[Football Hub] menu library did not load, running without a menu")
    if AUTOLOAD and detected then
        task.spawn(function()
            pcall(detected.run)
        end)
    end
    return
end

if env.FootballHub.library then
    pcall(function()
        local old = env.FootballHub.library
        if old.Unload then
            old:Unload()
        elseif old.Destroy then
            old:Destroy()
        end
    end)
end
env.FootballHub.library = Library

Library:AddCustomTheme("Football", {
    Main = Color3.fromRGB(17, 19, 23),
    Sidebar = Color3.fromRGB(11, 13, 16),
    Element = Color3.fromRGB(28, 32, 38),
    Accent = Color3.fromRGB(60, 220, 130),
    Text = Color3.fromRGB(238, 243, 248),
    TextDark = Color3.fromRGB(139, 149, 161),
})

local Window = Library:CreateWindow({
    Name = "Football Hub v" .. VERSION,
    Theme = "Football",
    SaveName = "FootballHub",
    Size = UDim2.new(0, 700, 0, 450),
    Position = UDim2.new(0.5, 0, 0.5, 0),
})

local scriptsTab
local settingsBuilt = {}
local runGame
local ELEMS = {}

local LEVELS = { "10%", "25%", "50%", "75%", "100%" }
local REACT_LEVELS = { "25%", "50%", "75%", "100%" }

local function levelValue(label, list)
    for i, v in ipairs(list) do
        if v == label then return i end
    end
    return 1
end

local function addToggle(tab, flag, opts)
    local el = tab:CreateToggle({
        Name = opts.Text,
        CurrentValue = opts.Default,
        Flag = flag,
        Callback = function(v)
            if opts.Callback then opts.Callback(v) end
            Library:Save()
        end,
    })
    ELEMS[flag] = el
    return el
end

local function addSlider(tab, flag, opts)
    local el = tab:CreateSlider({
        Name = opts.Text,
        Range = { opts.Min, opts.Max },
        CurrentValue = opts.Default,
        Increment = opts.Increment or 1,
        Flag = flag,
        Callback = function(v)
            if opts.Callback then opts.Callback(v) end
            Library:Save()
        end,
    })
    ELEMS[flag] = el
    return el
end

local function addDropdown(tab, flag, opts)
    local el = tab:CreateDropdown({
        Name = opts.Text,
        Options = opts.Options,
        CurrentOption = opts.Default,
        Flag = flag,
        Callback = function(v)
            if opts.Callback then opts.Callback(v) end
            Library:Save()
        end,
    })
    ELEMS[flag] = el
    return el
end

local function addButton(tab, text, fn)
    tab:CreateButton({ Name = text, Callback = fn })
end

local function addKey(tab, flag, name, defaultKey, onPress)
    local el = tab:CreateKeybind({
        Name = name,
        CurrentKey = defaultKey or "None",
        Flag = flag,
        Callback = onPress,
    })
    ELEMS[flag] = el
    return el
end

local function addToggleWithKey(tab, flag, opts, keyFlag, keyName, keyDefault)
    local el = addToggle(tab, flag, opts)
    addKey(tab, keyFlag, keyName, keyDefault, function()
        el:Set(not Library.Flags[flag])
    end)
    return el
end

local function notify(title, content)
    pcall(function()
        Library:Notify({ Title = title, Text = content, Duration = 4 })
    end)
    print("[Football Hub] " .. title .. ": " .. content)
end

local statusLabel
local function setStatus(text)
    if statusLabel then
        pcall(function() statusLabel:Set(text) end)
    end
end

-- opens the menu on a chosen tab instead of the first one
local function selectTab(tab)
    if not tab then return end
    pcall(function()
        for _, t in pairs(Window.Tabs) do
            t.Content.Visible = false
            t.Btn.BackgroundTransparency = 1
            t.Btn.TextColor3 = Library.Themes[Library.CurrentTheme].TextDark
        end
        tab.Content.Visible = true
        tab.Btn.BackgroundTransparency = 0
        tab.Btn.TextColor3 = Library.Themes[Library.CurrentTheme].Text
        Window.CurrentTab = tab
    end)
end

-- ---------------------------------------------------------------------------
-- TPS menu
-- ---------------------------------------------------------------------------

local function buildTPS(tab)
    local T = SETTINGS.TPS

    tab:CreateSection("Reach")
    addToggleWithKey(tab, "TPSReachEnabled", {
        Text = "Reach enabled",
        Default = T.reachEnabled,
        Callback = function(v) T.reachEnabled = v end,
    }, "TPSReachKey", "Toggle reach key", "K")
    addSlider(tab, "TPSGroundReach", {
        Text = "Ground reach",
        Default = T.groundReach,
        Min = 1,
        Max = 15,
        Callback = function(v) T.groundReach = v end,
    })
    addSlider(tab, "TPSJumpLeg", {
        Text = "Jump leg reach",
        Default = T.jumpLegReach,
        Min = 1,
        Max = 15,
        Callback = function(v) T.jumpLegReach = v end,
    })
    addToggle(tab, "TPSHeadReach", {
        Text = "Head reach",
        Default = T.headReachEnabled,
        Callback = function(v) T.headReachEnabled = v end,
    })
    addSlider(tab, "TPSHeadRadius", {
        Text = "Head reach radius",
        Default = T.headReachRadius,
        Min = 1,
        Max = 15,
        Callback = function(v) T.headReachRadius = v end,
    })

    tab:CreateSection("React")
    addToggle(tab, "TPSReact", {
        Text = "React enabled",
        Default = T.reactEnabled,
        Callback = function(v) T.reactEnabled = v end,
    })
    addDropdown(tab, "TPSReactLevel", {
        Text = "React amount",
        Options = REACT_LEVELS,
        Default = REACT_LEVELS[T.reactLevel] or "50%",
        Callback = function(v) T.reactLevel = levelValue(v, REACT_LEVELS) end,
    })

    tab:CreateSection("Movement & Aim")
    addToggle(tab, "TPSGkAim", {
        Text = "GK silent aim",
        Default = T.gkAimEnabled,
        Callback = function(v) T.gkAimEnabled = v end,
    })
    addToggle(tab, "TPSSilentDribble", {
        Text = "Silent dribble",
        Default = T.silentDribble,
        Callback = function(v) T.silentDribble = v end,
    })
    addToggle(tab, "TPSAutoFake", {
        Text = "Auto fake",
        Default = T.autoFakeEnabled,
        Callback = function(v) T.autoFakeEnabled = v end,
    })
    addKey(tab, "TPSAutoFakeKey", "Auto fake key", T.autoFakeKeybind, function(key)
        T.autoFakeKeybind = key
    end)
    -- the script listens for this key itself, so mirror it when it is rebound
    task.spawn(function()
        while true do
            local bound = Library.Flags.TPSAutoFakeKey
            if type(bound) == "string" and bound ~= "" and bound ~= T.autoFakeKeybind then
                T.autoFakeKeybind = bound
            end
            task.wait(0.5)
        end
    end)
    addSlider(tab, "TPSAimSmooth", {
        Text = "Aim smoothness",
        Default = math.floor((T.aimbotSmoothness or 0.2) * 100),
        Min = 1,
        Max = 100,
        Callback = function(v) T.aimbotSmoothness = v / 100 end,
    })

    tab:CreateSection("Visuals")
    addToggle(tab, "TPSBallEsp", { Text = "Ball ESP", Default = T.ballEspEnabled, Callback = function(v) T.ballEspEnabled = v end })
    addToggle(tab, "TPSBallVector", { Text = "Direction vector", Default = T.ballVectorEnabled, Callback = function(v) T.ballVectorEnabled = v end })
    addToggle(tab, "TPSBallTrail", { Text = "Trajectory trail", Default = T.ballTrailEnabled, Callback = function(v) T.ballTrailEnabled = v end })
    addToggle(tab, "TPSMoveEsp", { Text = "Movement ESP", Default = T.dashAfterimage, Callback = function(v) T.dashAfterimage = v end })
    addToggle(tab, "TPSPlayerChams", { Text = "Player chams", Default = T.playerChams, Callback = function(v) T.playerChams = v end })
    addToggle(tab, "TPSPathPred", { Text = "Path prediction", Default = T.playerPredictor, Callback = function(v) T.playerPredictor = v end })

    tab:CreateSection("Moss & Misc")
    addDropdown(tab, "TPSMossLevel", {
        Text = "Moss amount",
        Options = LEVELS,
        Default = LEVELS[T.mossLevel] or "25%",
        Callback = function(v) T.mossLevel = levelValue(v, LEVELS) end,
    })
    addToggle(tab, "TPSMoss", { Text = "Moss enabled", Default = T.mossEnabled, Callback = function(v) T.mossEnabled = v end })
    addToggle(tab, "TPSPingSpoof", { Text = "Ping spoof", Default = T.pingSpoofEnabled, Callback = function(v) T.pingSpoofEnabled = v end })
    addToggleWithKey(tab, "TPSCooldown", {
        Text = "Cooldown remover",
        Default = T.cooldownRemover,
        Callback = function(v) T.cooldownRemover = v end,
    }, "TPSCooldownKey", "Cooldown key", T.cooldownKeybind)

    tab:CreateSection("Skybox")
    addToggle(tab, "TPSAmbience", {
        Text = "World ambience",
        Default = T.worldColorEnabled,
        Callback = function(v)
            T.worldColorEnabled = v
            if type(env.FootballHub.tpsAmbience) == "function" then pcall(env.FootballHub.tpsAmbience) end
        end,
    })
    local function skyBtn(text, key)
        addButton(tab, text, function()
            local fn = env.FootballHub.tpsSky and env.FootballHub.tpsSky[key]
            if type(fn) == "function" then pcall(fn) end
        end)
    end
    skyBtn("Night sky", "night")
    skyBtn("Sakura sky", "sakura")
    skyBtn("Purple night", "purpleNight")
    skyBtn("Gray sky", "gray")
    skyBtn("Pinkie preppy", "pinkie")
    skyBtn("Reset sky", "reset")

    tab:CreateSection("FastFlags")
    addToggle(tab, "TPSFlags", {
        Text = "Apply fastflags",
        Default = T.flagsEnabled,
        Callback = function(v) T.flagsEnabled = v end,
    })
    local function flagSlider(key, flag, text, max, fallback)
        addSlider(tab, key, {
            Text = text,
            Default = tonumber(T.flags[flag]) or fallback,
            Min = 0,
            Max = max,
            Callback = function(v) T.flags[flag] = tostring(v) end,
        })
    end
    flagSlider("TPSFlagTarget", "DFIntTargetTimeDelayFacctorTenths", "Target time delay", 60, 15)
    flagSlider("TPSFlagInterpDelay", "FIntInterpolationMaxDelayMSec", "Interp max delay", 300, 80)
    flagSlider("TPSFlagInterpTime", "FIntInterpolationMaxTimeMS", "Interp max time", 300, 85)
    flagSlider("TPSFlagInterpLerp", "FIntInterpolationAwareTargetTimeLerpHundredth", "Interp target lerp", 400, 130)

    local function setOpt(name, value)
        local opt = ELEMS[name]
        if opt and opt.Set then pcall(function() opt:Set(value) end) end
    end

    local function applyPreset(kind)
        local gk = kind == "GK"
        setOpt("TPSReachEnabled", true)
        setOpt("TPSGroundReach", gk and 5 or 4)
        setOpt("TPSHeadReach", true)
        setOpt("TPSHeadRadius", gk and 4 or 3)
        setOpt("TPSReact", true)
        setOpt("TPSReactLevel", "50%")
        setOpt("TPSMoss", true)
        setOpt("TPSMossLevel", "25%")
        setOpt("TPSAmbience", true)
        setOpt("TPSBallEsp", true)
        setOpt("TPSBallVector", true)
        setOpt("TPSBallTrail", true)
        setOpt("TPSSilentDribble", not gk)
        setOpt("TPSGkAim", gk)
        setOpt("TPSAutoFake", not gk)
        local fn = env.FootballHub.tpsSky and env.FootballHub.tpsSky.night
        if type(fn) == "function" then pcall(fn) end
    end

    tab:CreateSection("Presets")
    addButton(tab, "Outfield preset", function() applyPreset("Outfield") end)
    addButton(tab, "Goalkeeper preset", function() applyPreset("GK") end)
end

-- ---------------------------------------------------------------------------
-- TPL menu
-- ---------------------------------------------------------------------------

local function buildTPL(tab)
    local T = SETTINGS.TPL

    tab:CreateSection("Reach")
    addToggleWithKey(tab, "TPLReach", {
        Text = "Reach enabled",
        Default = T.Enabled,
        Callback = function(v) T.Enabled = v end,
    }, "TPLReachKey", "Toggle reach key", "K")
    addSlider(tab, "TPLSize", {
        Text = "Ball reach size",
        Default = T.HorizontalSize,
        Min = 1,
        Max = 15,
        Callback = function(v) T.HorizontalSize = v end,
    })
    addSlider(tab, "TPLDistance", {
        Text = "Max reach distance",
        Default = T.Distance,
        Min = 5,
        Max = 60,
        Callback = function(v) T.Distance = v end,
    })
end

-- ---------------------------------------------------------------------------
-- Touchline menu
-- ---------------------------------------------------------------------------

local function stealAvatar(userId, character)
    if not character then return end
    local Players = game:GetService("Players")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local succ, appearance = pcall(function() return Players:GetCharacterAppearanceAsync(userId) end)
    if not succ or not appearance then return end
    local hasHeadless, hasKorblox = false, false
    local descSuccess, description = pcall(function() return Players:GetHumanoidDescriptionFromUserId(userId) end)
    if descSuccess and description then
        if description.Head == 47079 or description.Head == 1340101835 or description.Head == 6340101835 or description.Head == 6686307858 then hasHeadless = true end
        if description.RightLeg == 139607718 then hasKorblox = true end
    end
    for _, v in pairs(character:GetChildren()) do
        if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants") or v:IsA("CharacterMesh") or v:IsA("BodyColors") then v:Destroy() end
    end
    if character:FindFirstChild("Head") then
        for _, child in ipairs(character.Head:GetChildren()) do
            if child:IsA("Decal") then child:Destroy() end
        end
    end
    for _, v in ipairs(appearance:GetDescendants()) do
        if v:IsA("Shirt") or v:IsA("Pants") or v:IsA("BodyColors") then
            pcall(function() v:Clone().Parent = character end)
        elseif v:IsA("Accessory") then
            pcall(function() humanoid:AddAccessory(v:Clone()) end)
        elseif v:IsA("CharacterMesh") then
            pcall(function() v:Clone().Parent = character end)
        end
    end
    local faceTexture = nil
    for _, desc in ipairs(appearance:GetDescendants()) do
        if desc:IsA("Decal") and (desc.Name == "face" or desc.Name == "Face") then faceTexture = desc.Texture break end
    end
    local head = character:FindFirstChild("Head")
    if head then
        local face = Instance.new("Decal")
        face.Face = Enum.NormalId.Front
        face.Name = "face"
        face.Texture = faceTexture or "rbxasset://textures/face.png"
        face.Parent = head
    end
    if hasHeadless and character:FindFirstChild("Head") then
        character.Head.Transparency = 1
        if character.Head:FindFirstChildOfClass("SpecialMesh") then character.Head:FindFirstChildOfClass("SpecialMesh").MeshId = "" end
    elseif character:FindFirstChild("Head") then
        character.Head.Transparency = 0
    end
    local parent = character.Parent
    character.Parent = nil
    character.Parent = parent
end

local function buildTouchline(tab)
    local T = SETTINGS.TOUCHLINE

    tab:CreateSection("Collisionless Reach")
    addToggle(tab, "TLNoCollide", {
        Text = "Collisionless reach",
        Default = T.reachNoCollide.enabled,
        Callback = function(v) T.reachNoCollide.enabled = v end,
    })
    addSlider(tab, "TLNoCollideSize", {
        Text = "Reach size",
        Default = T.reachNoCollide.size,
        Min = 1,
        Max = 30,
        Callback = function(v) T.reachNoCollide.size = v end,
    })
    addToggle(tab, "TLNoCollideShow", {
        Text = "Show ball",
        Default = T.reachNoCollide.visible,
        Callback = function(v) T.reachNoCollide.visible = v end,
    })

    tab:CreateSection("Collision Reach")
    addToggleWithKey(tab, "TLCollide", {
        Text = "Collision reach",
        Default = T.reachCollide.enabled,
        Callback = function(v) T.reachCollide.enabled = v end,
    }, "TLCollideKey", "Toggle reach key", "K")
    addSlider(tab, "TLCollideSize", {
        Text = "Reach size",
        Default = T.reachCollide.size,
        Min = 1,
        Max = 30,
        Callback = function(v) T.reachCollide.size = v end,
    })
    addSlider(tab, "TLCollideDistance", {
        Text = "Reach distance",
        Default = T.reachCollide.distance,
        Min = 10,
        Max = 200,
        Callback = function(v) T.reachCollide.distance = v end,
    })
    addToggle(tab, "TLCollideShow", {
        Text = "Show ball",
        Default = T.reachCollide.visible,
        Callback = function(v) T.reachCollide.visible = v end,
    })

    tab:CreateSection("Movement")
    addToggle(tab, "TLWalk", { Text = "Speed boost", Default = T.walk.enabled, Callback = function(v) T.walk.enabled = v end })
    addSlider(tab, "TLWalkSpeed", { Text = "Walk speed", Default = T.walk.speed, Min = 16, Max = 50, Callback = function(v) T.walk.speed = v end })
    addToggle(tab, "TLTpWalk", { Text = "TP walk", Default = T.tpWalk.enabled, Callback = function(v) T.tpWalk.enabled = v end })
    addSlider(tab, "TLTpSpeed", { Text = "TP speed", Default = T.tpWalk.speed, Min = 1, Max = 12, Callback = function(v) T.tpWalk.speed = v end })
    addToggle(tab, "TLFly", { Text = "Fly", Default = T.fly.enabled, Callback = function(v) T.fly.enabled = v end })
    addSlider(tab, "TLFlySpeed", { Text = "Fly speed", Default = T.fly.speed, Min = 10, Max = 120, Callback = function(v) T.fly.speed = v end })

    tab:CreateSection("GK Auto Dive")
    addToggle(tab, "TLGk", { Text = "Auto dive", Default = T.gk.enabled, Callback = function(v) T.gk.enabled = v end })
    addSlider(tab, "TLGkRange", { Text = "Dive range", Default = T.gk.range, Min = 10, Max = 60, Callback = function(v) T.gk.range = v end })
    addSlider(tab, "TLGkSpeed", { Text = "Dive speed", Default = T.gk.speed, Min = 20, Max = 100, Callback = function(v) T.gk.speed = v end })
    addSlider(tab, "TLGkLift", { Text = "Dive lift", Default = T.gk.lift, Min = 5, Max = 50, Callback = function(v) T.gk.lift = v end })
    addSlider(tab, "TLGkCooldown", { Text = "Cooldown", Default = T.gk.cooldown, Min = 1, Max = 5, Increment = 0.5, Callback = function(v) T.gk.cooldown = v end })
    addSlider(tab, "TLGkHitRadius", { Text = "Hit radius", Default = T.gk.hitRadius, Min = 2, Max = 15, Callback = function(v) T.gk.hitRadius = v end })

    tab:CreateSection("Ball Prediction")
    addToggle(tab, "TLPred", { Text = "Enable prediction", Default = T.prediction.enabled, Callback = function(v) T.prediction.enabled = v end })
    addSlider(tab, "TLPredTouch", { Text = "Reachable threshold", Default = T.prediction.touch, Min = 2, Max = 12, Callback = function(v) T.prediction.touch = v end })
    addSlider(tab, "TLPredRange", { Text = "Track range", Default = T.prediction.range, Min = 5, Max = 40, Callback = function(v) T.prediction.range = v end })
    addSlider(tab, "TLPredAhead", { Text = "Predict ahead", Default = math.floor(T.prediction.ahead * 10), Min = 5, Max = 30, Callback = function(v) T.prediction.ahead = v / 10 end })

    tab:CreateSection("Extras")
    addToggle(tab, "TLJump", { Text = "Custom jump power", Default = T.jump.enabled, Callback = function(v) T.jump.enabled = v end })
    addSlider(tab, "TLJumpPower", { Text = "Jump power", Default = T.jump.power, Min = 50, Max = 100, Callback = function(v) T.jump.power = v end })
    addToggle(tab, "TLDribble", { Text = "INF dribble", Default = T.dribble.enabled, Callback = function(v) T.dribble.enabled = v end })
    addSlider(tab, "TLDribbleSpeed", { Text = "Dribble speed", Default = T.dribble.speed, Min = 8, Max = 35, Callback = function(v) T.dribble.speed = v end })
    addToggle(tab, "TLAir1", { Text = "Air dribble M1", Default = T.airDribble1.enabled, Callback = function(v) T.airDribble1.enabled = v end })
    addSlider(tab, "TLAir1Size", { Text = "M1 platform size", Default = T.airDribble1.size, Min = 1, Max = 100, Callback = function(v) T.airDribble1.size = v end })
    addSlider(tab, "TLAir1Y", { Text = "M1 y offset", Default = T.airDribble1.yOffset, Min = 0.5, Max = 5, Increment = 0.5, Callback = function(v) T.airDribble1.yOffset = v end })
    addToggle(tab, "TLAir1Show", { Text = "Show M1 platform", Default = T.airDribble1.visible, Callback = function(v) T.airDribble1.visible = v end })
    addToggle(tab, "TLAir2", { Text = "Air dribble M2", Default = T.airDribble2.enabled, Callback = function(v) T.airDribble2.enabled = v end })
    addSlider(tab, "TLAir2Size", { Text = "M2 platform size", Default = T.airDribble2.size, Min = 1, Max = 50, Callback = function(v) T.airDribble2.size = v end })
    addToggle(tab, "TLAir2Show", { Text = "Show M2 platform", Default = T.airDribble2.visible, Callback = function(v) T.airDribble2.visible = v end })
    addToggle(tab, "TLFling", { Text = "Ball fling", Default = T.ballFling.enabled, Callback = function(v) T.ballFling.enabled = v end })
    addSlider(tab, "TLFlingReach", { Text = "Fling reach", Default = T.ballFling.reach, Min = 1, Max = 15, Callback = function(v) T.ballFling.reach = v end })
    tab:CreateTextbox({
        Name = "Avatar stealer",
        PlaceholderText = "Username...",
        Flag = "TLAvatarUser",
        Callback = function(text)
            text = text:gsub("^%s*(.-)%s*$", "%1")
            if text == "" then return end
            local Players = game:GetService("Players")
            local ok, userId = pcall(function() return Players:GetUserIdFromNameAsync(text) end)
            if ok and userId then
                pcall(function() stealAvatar(userId, Players.LocalPlayer.Character) end)
                notify("Avatar stealer", "Stole " .. text .. "'s avatar")
            else
                notify("Avatar stealer", "User not found")
            end
        end,
    })
    -- never replay the saved username when the config loads
    Library.Flags.TLAvatarUser = nil
    Library.FlagCallbacks.TLAvatarUser = function() end

    tab:CreateSection("Moss & Misc")
    addDropdown(tab, "TLMossLevel", {
        Text = "Moss amount",
        Options = LEVELS,
        Default = LEVELS[T.moss.level] or "25%",
        Callback = function(v) T.moss.level = levelValue(v, LEVELS) end,
    })
    addToggle(tab, "TLMoss", { Text = "Moss enabled", Default = T.moss.enabled, Callback = function(v) T.moss.enabled = v end })
    addToggle(tab, "TLPingSpoof", { Text = "Ping spoof", Default = T.moss.pingSpoof, Callback = function(v) T.moss.pingSpoof = v end })

    tab:CreateSection("Skys")
    local function skyBtn(text, key)
        addButton(tab, text, function()
            local fn = env.FootballHub.touchlineSky and env.FootballHub.touchlineSky[key]
            if type(fn) == "function" then pcall(fn) end
        end)
    end
    skyBtn("Night sky", "night")
    skyBtn("Sakura sky", "sakura")
    skyBtn("Purple night", "purpleNight")
    skyBtn("Gray sky", "gray")
    skyBtn("Pinkie preppy", "pinkie")
    skyBtn("Reset sky", "reset")
end

-- ---------------------------------------------------------------------------
-- VRA menu
-- ---------------------------------------------------------------------------

local function buildVRA(tab)
    tab:CreateSection("VRA/Overtime")
    tab:CreateLabel("The VRA/Overtime script is a spoofer for the game with no configurable options")
end

-- ---------------------------------------------------------------------------
-- menu wiring
-- ---------------------------------------------------------------------------

local function menuGui()
    local roots = {}
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then table.insert(roots, hui) end
    end
    pcall(function()
        table.insert(roots, game:GetService("CoreGui"))
    end)
    for _, root in ipairs(roots) do
        local found = root:FindFirstChild("Nebula")
        if found then return found end
    end
end

local function toggleMenu()
    pcall(function()
        local gui = menuGui()
        if not gui then return end
        local main
        for _, child in ipairs(gui:GetChildren()) do
            if child:IsA("Frame") and child:FindFirstChildOfClass("UIScale") then
                main = child
                break
            end
        end
        if not main then return end
        if main.Visible then
            main.Visible = false
        else
            local scale = main:FindFirstChildOfClass("UIScale")
            if scale then scale.Scale = 1 end
            main.Visible = true
        end
    end)
end

local function buildSettings(g)
    if settingsBuilt[g.key] then return end
    settingsBuilt[g.key] = true

    local tab = Window:CreateTab(g.short)
    if g.key == "tps" then
        buildTPS(tab)
    elseif g.key == "tpl" then
        buildTPL(tab)
    elseif g.key == "touchline" then
        buildTouchline(tab)
    else
        buildVRA(tab)
    end
    Library:Load()
    return tab
end

local function buildScriptsTab()
    if scriptsTab then return end

    scriptsTab = Window:CreateTab("Scripts")
    scriptsTab:CreateSection("Manual load")
    for _, g in ipairs(GAMES) do
        addButton(scriptsTab, g.name, function()
            buildSettings(g)
            runGame(g, { force = true })
        end)
    end
    return scriptsTab
end

runGame = function(g, opts)
    opts = opts or {}
    if not g then return end

    local key = "FootballHub_" .. g.key
    if env[key] and not opts.force then
        setStatus("Already running")
        return
    end

    env[key] = true
    setStatus("Loading...")

    task.spawn(function()
        local ok, err = pcall(g.run)
        if ok then
            setStatus("Running")
            notify("Loaded", g.name)
        else
            setStatus("Failed to load")
            notify("Load failed", tostring(err))
            buildScriptsTab()
        end
    end)
end

local home = Window:CreateTab("Home")
home:CreateSection("Status")
home:CreateLabel(detected and detected.name or "No game detected")
statusLabel = home:CreateLabel(detected and "Idle" or "Open the Scripts tab")
addButton(home, "Reload script", function()
    runGame(detected, { force = true })
end)

local startTab
if detected then
    startTab = buildSettings(detected)
else
    buildScriptsTab()
    startTab = scriptsTab
end
selectTab(startTab)

local uiTab = Window:CreateTab("UI")
uiTab:CreateSection("Menu")
addKey(uiTab, "MenuKeybind", "Menu key", "RightControl", function()
    toggleMenu()
end)
addButton(uiTab, "Hide menu", function()
    toggleMenu()
end)

uiTab:CreateSection("Theme")
for _, name in ipairs({ "Football", "Obsidian", "Midnight", "Mint", "Ocean" }) do
    addButton(uiTab, name, function()
        Library:SetTheme(name)
    end)
end

uiTab:CreateSection("Socials")
addButton(uiTab, "Copy Discord invite", function()
    if setclipboard then
        setclipboard(DISCORD)
        notify("Discord", "Invite copied to clipboard")
    end
end)

-- replay the saved config now that every element exists
Library:Load()

if AUTOLOAD and detected then
    runGame(detected)
end













