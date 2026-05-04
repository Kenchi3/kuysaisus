-- ==========================================
-- [ 1. โหลด Fluent UI Library ]
-- ==========================================
local Library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
local SaveManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"))()

local Window = Library:CreateWindow{
    Title = "Klakuylek Hub",
    SubTitle = "Quota System Edition",
    TabWidth = 160,
    Size = UDim2.fromOffset(830, 525),
    Acrylic = true, 
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightShift
}

local Tabs = {
    Main = Window:CreateTab{ Title = "Main", Icon = "sword" },
    Settings = Window:CreateTab{ Title = "Settings", Icon = "settings" }
}

local Options = Library.Options

-- ==========================================
-- [ 2. ตั้งค่าตัวแปรเกม ]
-- ==========================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local RootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

local Remotes = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local POST = Remotes:WaitForChild("POST")
local GET = Remotes:WaitForChild("GET")
local TitansFolder = Workspace:FindFirstChild("Titans")
local ButtonsFolder = Player:FindFirstChild("PlayerGui"):WaitForChild("Interface"):FindFirstChild("Buttons")

local PlaceId = game.PlaceId
local isRaidMap = (PlaceId == 14012874501 or PlaceId == 13379349730)
local RaidBossWeakPoints = {} 

-- 🔥 [Quota System Variables]
local totalTitanCount = 0 -- จำนวน Titan รวมทั้งหมดที่เคยเจอ
local lastAliveCount = 0 -- จำนวน Titan ที่มีชีวิตรอบที่แล้ว (ใช้ track wave)
local farmingStarted = false
local fallbackStartTime = 0

local opFarmInitialized = false
local OP_FLY_HEIGHT = 500
local OP_MAX_TARGETS = 5

local antiGravityConn = nil
local savedHoverY = nil

local function getRaidAnchorPos()
    local unclimbable = workspace:FindFirstChild("Unclimbable")
    if not unclimbable then return nil end
    if PlaceId == 14012874501 then
        local background = unclimbable:FindFirstChild("Background")
        if background then
            local npc = background:FindFirstChild("Attack_Titan")
            if npc then
                if npc:IsA("Model") then return npc:GetPivot().Position
                elseif npc:IsA("BasePart") then return npc.Position end
            end
        end
    elseif PlaceId == 13379349730 then
        local objective = unclimbable:FindFirstChild("Objective")
        if objective then
            local boat = objective:FindFirstChild("Boat1")
            if boat then
                if boat:IsA("Model") then return boat:GetPivot().Position
                elseif boat:IsA("BasePart") then return boat.Position end
            end
        end
    end
    return nil
end

-- ==========================================
-- [ 3. ฟังก์ชันระบบทำงาน ]
-- ==========================================
local FLY_OFFSET = 200
local FLY_SPEED = 300
local JITTER_AMOUNT = 2 
local isFlying = false
local NoclipConnection = nil
local flightConnection = nil 

local function humanizedFlyTo(targetPos)
    if not RootPart or isFlying then return end 
    isFlying = true
    RootPart.Anchored = false
    Humanoid.PlatformStand = true
    RootPart.AssemblyLinearVelocity = Vector3.zero
    
    local goalPos = targetPos + Vector3.new(
        math.random(-5, 5), 
        FLY_OFFSET + math.random(-2, 2), 
        math.random(-5, 5)
    )

    if flightConnection then flightConnection:Disconnect() end
    
    flightConnection = RunService.Heartbeat:Connect(function(dt)
        if not isFlying then return end
        
        local direction = (goalPos - RootPart.Position)
        local distance = direction.Magnitude
        
        if distance < 5 then
            isFlying = false
            RootPart.AssemblyLinearVelocity = Vector3.zero
            if flightConnection then flightConnection:Disconnect(); flightConnection = nil end
            return
        end

        local moveStep = direction.Unit * (FLY_SPEED * dt)
        
        local jitter = Vector3.new(
            math.random() * JITTER_AMOUNT - JITTER_AMOUNT/2,
            math.random() * JITTER_AMOUNT - JITTER_AMOUNT/2,
            math.random() * JITTER_AMOUNT - JITTER_AMOUNT/2
        )
        
        RootPart.CFrame = CFrame.new(RootPart.Position + moveStep + jitter, goalPos)
        RootPart.AssemblyLinearVelocity = Vector3.zero
    end)
end

local function findNearestStation()
    for _, obj in pairs(workspace:GetDescendants()) do
        if (obj.Name:find("Refill") or obj.Name:find("Station")) and (obj:IsA("Model") or obj:IsA("BasePart")) then return obj end
    end
    return nil
end

local function hasSpareBlades()
    local rig = Character:FindFirstChild("Rig_" .. Player.Name)
    if rig then
        for i = 1, 3 do
            local spare = rig:FindFirstChild("Left_" .. i, true)
            if spare and spare:GetAttribute("Used") == nil then return true end
        end
    end
    return false
end

local function isBladeEmpty()
    local rig = Character:FindFirstChild("Rig_" .. Player.Name)
    if rig and rig:FindFirstChild("LeftHand") then
        local blade = rig.LeftHand:FindFirstChild("Blade_1")
        if not blade or blade.Transparency == 1 then return true end
    end
    return false
end

local lastRefillAttempt = 0
local REFILL_COOLDOWN = 2.5 

local function safeRefillBlades()
    if tick() - lastRefillAttempt < REFILL_COOLDOWN then return end
    lastRefillAttempt = tick()
    
    if hasSpareBlades() then 
        pcall(function() GET:InvokeServer("Blades", "Reload") end)
    else 
        local s = findNearestStation()
        if s then 
            pcall(function() POST:FireServer("Attacks", "Reload", s) end) 
        end 
    end
end

local function trackBossWeakPoint(bossModel)
    if not bossModel then return end
    local marker = bossModel:FindFirstChild("Marker") or bossModel:WaitForChild("Marker", 30)
    if not marker then return end
    RaidBossWeakPoints[bossModel.Name] = marker.Adornee
    marker:GetPropertyChangedSignal("Adornee"):Connect(function() RaidBossWeakPoints[bossModel.Name] = marker.Adornee end)
    local hum = bossModel:FindFirstChildOfClass("Humanoid")
    if hum then hum.Died:Connect(function() RaidBossWeakPoints[bossModel.Name] = nil end) end
end

local function monitorRaidBosses()
    if not isRaidMap then return end
    task.spawn(function()
        local s, a = pcall(function() return TitansFolder:WaitForChild("Attack_Titan", 300) end)
        if s and a then trackBossWeakPoint(a) end
    end)
    task.spawn(function()
        local s, a = pcall(function() return TitansFolder:WaitForChild("Armored_Titan", 300) end)
        if s and a then trackBossWeakPoint(a) end
    end)
end

local function getAvailableBossWeakPoint()
    if not Options.BossBurst.Value then return nil end
    for bossName, weakPoint in pairs(RaidBossWeakPoints) do
        if weakPoint and weakPoint:IsA("BasePart") and weakPoint.Parent then
            return weakPoint
        else
            RaidBossWeakPoints[bossName] = nil
        end
    end
    return nil
end

local function getAliveTitanCount()
    local count = 0
    if not TitansFolder then return 0 end
    for _, titan in ipairs(TitansFolder:GetChildren()) do
        if titan:IsA("Model") then
            local hum = titan:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                count = count + 1
            end
        end
    end
    return count
end

local function getTargetCluster(maxCount, radius)
    local closestPart, minDistance, anchorPosition = nil, math.huge, RootPart.Position
    if isRaidMap then local p = getRaidAnchorPos(); if p then anchorPosition = p end end
    if not TitansFolder then return {}, nil end
    
    for _, titan in ipairs(TitansFolder:GetChildren()) do
        if titan:IsA("Model") and titan:FindFirstChildOfClass("Humanoid") and titan.Humanoid.Health > 0 and titan:FindFirstChild("Hitboxes") then
            local tp = nil
            if RaidBossWeakPoints[titan.Name] then 
                tp = RaidBossWeakPoints[titan.Name]
            else 
                local h = titan.Hitboxes:FindFirstChild("Hit"); 
                if h then tp = h:FindFirstChild("Nape") end 
            end
            
            if tp then local d = (anchorPosition - tp.Position).Magnitude; if d < minDistance then minDistance = d; closestPart = tp end end
        end
    end
    
    if not closestPart then return {}, nil end
    local t, lim = {}, {}
    
    for _, titan in ipairs(TitansFolder:GetChildren()) do
        if titan:IsA("Model") and titan:FindFirstChildOfClass("Humanoid") and titan.Humanoid.Health > 0 and titan:FindFirstChild("Hitboxes") then
            local tp = nil
            if RaidBossWeakPoints[titan.Name] then 
                tp = RaidBossWeakPoints[titan.Name]
            else 
                local h = titan.Hitboxes:FindFirstChild("Hit"); 
                if h then tp = h:FindFirstChild("Nape") end 
            end
            
            if tp and (tp.Position - closestPart.Position).Magnitude <= radius then table.insert(t, tp) end