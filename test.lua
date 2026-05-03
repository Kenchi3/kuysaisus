-- ==========================================
-- [ 1. โหลด Fluent UI Library ]
-- ==========================================
local Library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
local SaveManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"))()

local Window = Library:CreateWindow{
    Title = "Klakuylek Hub",
    SubTitle = "By nxnn_nn",
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

-- 🔥 [แก้ไข] เปลี่ยนระบบนับเวลา
local missionStartTime = nil -- เริ่มต้นเป็น nil ก่อน
local timerStarted = false   -- Flag สำหรับเช็คว่าเริ่มนับแล้วหรือยัง

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
        end
    end
    table.sort(t, function(a, b) return (a.Position - closestPart.Position).Magnitude < (b.Position - closestPart.Position).Magnitude end)
    for i = 1, math.min(#t, maxCount) do table.insert(lim, t[i]) end
    return lim, closestPart.Position
end

local function getAllTargets()
    local targets = {}
    if not TitansFolder then return targets end
    for _, titan in ipairs(TitansFolder:GetChildren()) do
        if titan:IsA("Model") and titan:FindFirstChildOfClass("Humanoid") and titan.Humanoid.Health > 0 then
            local tp = nil
            if RaidBossWeakPoints[titan.Name] then 
                tp = RaidBossWeakPoints[titan.Name]
            else
                local hb = titan:FindFirstChild("Hitboxes")
                if hb then local hf = hb:FindFirstChild("Hit"); if hf then tp = hf:FindFirstChild("Nape") or hf:FindFirstChildWhichIsA("BasePart") end end
            end
            if tp then table.insert(targets, tp) end
        end
    end
    return targets
end

local function performSimulatedClick(x, y)
    if GuiService.MenuIsOpen then return end
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(math.random(50, 150) / 1000)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

local function executeMultiSlash(napesArray)
    if not napesArray or #napesArray == 0 then return false end
    local mainTarget = napesArray[1]
    if mainTarget and mainTarget.Parent then
        pcall(function()
            workspace.CurrentCamera.CFrame = CFrame.lookAt(workspace.CurrentCamera.CFrame.Position, mainTarget.Position)
        end)
        task.wait(math.random(50, 100) / 1000)
    end

    POST:FireServer("Attacks", "Slash", true)
    if Options.EnableAntiCheatActions and Options.EnableAntiCheatActions.Value then
        task.wait(math.random(50, 100) / 1000)
        performSimulatedClick(1400 + math.random(-15, 15), 900 + math.random(-15, 15))
    end
    
    task.wait(0.05)
    for _, napePart in ipairs(napesArray) do
        if napePart and napePart.Parent then
            task.spawn(function()
                pcall(function() GET:InvokeServer("Hitboxes", "Register", napePart, math.random(180, 260), math.random(10, 100)) end)
            end)
        end
    end
    return true
end

local function executeOPSlash(napesArray)
    if not napesArray or #napesArray == 0 then return false end
    POST:FireServer("Attacks", "Slash", true)
    for _, napePart in ipairs(napesArray) do
        if napePart and napePart.Parent then
            task.spawn(function()
                pcall(function() GET:InvokeServer("Hitboxes", "Register", napePart, 9999, math.random(10, 100)) end)
            end)
        end
    end
    return true
end

local function executeBossBurst(bossPart, burstAmount)
    if not bossPart then return false end
    for i = 1, burstAmount do
        task.spawn(function()
            pcall(function() POST:FireServer("Attacks", "Slash", true) end)
            task.wait(math.random(1, 5) / 1000)
            pcall(function() GET:InvokeServer("Hitboxes", "Register", bossPart, 9999, math.random(10, 100)) end)
        end)
    end
    return true
end

local function selectAndPressEnter(button)
    if button and button:IsA("GuiButton") then
        GuiService.SelectedObject = button; task.wait(0.3)
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game); task.wait(0.1)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game); task.wait(0.2)
        GuiService.SelectedObject = nil
    end
end

local function openRaidChests()
    local cg = Player.PlayerGui:FindFirstChild("Interface") and Player.PlayerGui.Interface:FindFirstChild("Chests")
    if not cg or not cg.Visible then return false end
    local fb = cg:FindFirstChild("Free"); local t = 0
    while not fb and t < 15 do task.wait(1); t = t + 1; fb = cg:FindFirstChild("Free") end
    if fb then selectAndPressEnter(fb); task.wait(1.5) end
    local pb = cg:FindFirstChild("Premium"); if pb and Options.OpenPremiumChest.Value then selectAndPressEnter(pb); task.wait(1.5) end
    local fnb = cg:FindFirstChild("Finish"); if fnb then selectAndPressEnter(fnb); task.wait(1); return true end
    return false
end

local function isRaidCompleted()
    local inf = Player.PlayerGui:FindFirstChild("Interface"); if not inf then return false end
    local c, r = inf:FindFirstChild("Chests"), inf:FindFirstChild("Rewards")
    if c and c.Visible then return true end
    if r and r.Visible then return true end
    return false
end

-- ==========================================
-- [ 4. สร้าง UI Elements ]
-- ==========================================
Tabs.Main:CreateToggle("OPFarm", {
    Title = "OP Farm (Sky Nuke)",
    Description = "Risky!!",
    Default = false
})

Tabs.Main:CreateToggle("BossBurst", {
    Title = "Raid Boss Burst",
    Description = "Risky!!",
    Default = false
})

Tabs.Main:CreateSlider("BurstAmount", {
    Title = "Burst Hits Amount",
    Min = 1, Max = 5, Default = 5, Rounding = 0
})


Tabs.Main:CreateSlider("OPFarmDelay", { Title = "OP Farm Delay (Sec)", Min = 0.05, Max = 1.0, Default = 0.6, Rounding = 1 })

Tabs.Main:CreateSection("Auto Farm (Safe)")
Tabs.Main:CreateToggle("Autofarm", { Title = "Auto Farm (Safe)", Description = "", Default = false })
Tabs.Main:CreateToggle("EnableAntiCheatActions", { Title = "Anti-Cheat Simulation", Description = "Simulate Q,E randomly", Default = true })
Tabs.Main:CreateSlider("TargetLimit", { Title = "AoE Target Limit", Description = "Recommended 3-5", Min = 1, Max = 10, Default = 5, Rounding = 0 })
Tabs.Main:CreateSlider("AoERadius", { Title = "AoE Radius (Slash Range)", Min = 50, Max = 1000, Default = 250, Rounding = 0 })
Tabs.Main:CreateSlider("SlashDelay", { Title = "Slash Delay", Min = 0.1, Max = 2.0, Default = 0.6, Rounding = 1 })

Tabs.Main:CreateSection("Time Guard")
Tabs.Main:CreateToggle("UseMissionTimer", { 
    Title = "Mission Time Guard", 
    Description = "Starts counting on first hit. Pause if finishing too early.", 
    Default = false 
})

Tabs.Main:CreateInput("MinMissionTime", { Title = "Min. Mission Time (Seconds)", Default = "60", Numeric = true, Placeholder = "e.g. 120" })
Tabs.Main:CreateSection("Misc")
Tabs.Main:CreateToggle("OpenPremiumChest", { Title = "Open Premium Chest", Default = false })
Tabs.Main:CreateToggle("AutoRetry", { Title = "Auto Retry", Default = true })

-- ==========================================
-- [ 5. Loop หลัก ]
-- ==========================================
spawn(function()
    spawn(monitorRaidBosses)
    
    while task.wait(0.1) do
        -- 🔥 [Reset Logic เมื่อตาย]
        if Humanoid.Health <= 0 then
            if flightConnection then flightConnection:Disconnect(); flightConnection = nil end
            if antiGravityConn then antiGravityConn:Disconnect(); antiGravityConn = nil end
            isFlying = false; opFarmInitialized = false; savedHoverY = nil
            
            -- Reset Timer
            timerStarted = false
            missionStartTime = nil
            
            Character = Player.Character or Player.CharacterAdded:Wait()
            RootPart = Character:WaitForChild("HumanoidRootPart")
            Humanoid = Character:WaitForChild("Humanoid")
            task.wait(2)
            continue
        end

        if not Options.Autofarm.Value and not Options.OPFarm.Value then 
            if flightConnection then flightConnection:Disconnect(); flightConnection = nil end
            if antiGravityConn then antiGravityConn:Disconnect(); antiGravityConn = nil end
            isFlying = false; opFarmInitialized = false; savedHoverY = nil; Humanoid.PlatformStand = false; RootPart.Anchored = false
            
            -- Reset Timer เมื่อปิด Farm
            timerStarted = false
            missionStartTime = nil
            
            if NoclipConnection then
                NoclipConnection:Disconnect()
                NoclipConnection = nil
                if Character then
                    for _, p in pairs(Character:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = true end
                    end
                end
            end
            continue 
        end

        if not antiGravityConn then
            antiGravityConn = RunService.Heartbeat:Connect(function()
                if RootPart and not RootPart.Anchored and (Options.Autofarm.Value or Options.OPFarm.Value) then
                    RootPart.AssemblyLinearVelocity = Vector3.zero
                    if savedHoverY and not isFlying then
                        RootPart.CFrame = CFrame.new(RootPart.CFrame.X, savedHoverY, RootPart.CFrame.Z)
                    end
                end
            end)
        end

        local success, skipGui = pcall(function() return Player.PlayerGui.Interface.Skip end)
        if success and skipGui and skipGui.Visible then
            local ib = skipGui:FindFirstChild("Interact")
            if ib and ib:IsA("GuiButton") then
                task.wait(math.random(100, 300)/1000)
                GuiService.SelectedObject = ib; task.wait(0.1)
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game); task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game); task.wait(0.1)
                GuiService.SelectedObject = nil
            end
        end

        if not NoclipConnection then
            NoclipConnection = RunService.Stepped:Connect(function()
                if Character and (Options.Autofarm.Value or Options.OPFarm.Value) then
                    for _, p in pairs(Character:GetDescendants()) do
                        if p:IsA("BasePart") and p ~= RootPart then 
                            p.CanCollide = false 
                        end
                    end
                end
            end])
        end

        local currentBossTarget = getAvailableBossWeakPoint()

        -- ==========================================
        -- [ โหมด OP FARM ]
        -- ==========================================
        if Options.OPFarm.Value then
            if flightConnection then flightConnection:Disconnect(); flightConnection = nil end
            isFlying = false; Humanoid.PlatformStand = true
            
            if not opFarmInitialized then
                if RootPart.Position.Y < (OP_FLY_HEIGHT - 10) then
                    Humanoid.PlatformStand = true
                    RootPart.Anchored = true 
                    
                    local targetPos = CFrame.new(RootPart.Position.X, OP_FLY_HEIGHT, RootPart.Position.Z)
                    local distance = math.abs(OP_FLY_HEIGHT - RootPart.Position.Y)
                    local duration = math.clamp(distance / 150, 1, 5)
                    
                    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
                    local tween = TweenService:Create(RootPart, tweenInfo, {CFrame = targetPos})
                    
                    tween:Play()
                    tween.Completed:Wait()
                end
                
                RootPart.Anchored = true
                RootPart.AssemblyLinearVelocity = Vector3.zero
                opFarmInitialized = true
            end
            
            if isBladeEmpty() then 
                if not savedHoverY then savedHoverY = RootPart.CFrame.Y end
                RootPart.Anchored = false 
                safeRefillBlades() 
                task.wait(1) 
                continue 
            end

            if savedHoverY then 
                RootPart.Anchored = true
                savedHoverY = nil 
            end

            if currentBossTarget then
                -- 🔥 [Start Timer on First Action]
                if not timerStarted then
                    missionStartTime = tick()
                    timerStarted = true
                end
                performSimulatedClick(1400 + math.random(-15, 15), 900 + math.random(-15, 15))
                executeBossBurst(currentBossTarget, Options.BurstAmount.Value)
            else
                local allTargets = getAllTargets()
                local limitedTargets = {}
                for i = 1, math.min(#allTargets, OP_MAX_TARGETS) do table.insert(limitedTargets, allTargets[i]) end

                if #limitedTargets > 0 then
                    -- 🔥 [Start Timer on First Action]
                    if not timerStarted then
                        missionStartTime = tick()
                        timerStarted = true
                    end

                    local aliveCount = getAliveTitanCount()
                    local elapsed = tick() - missionStartTime
                    local minTime = tonumber(Options.MinMissionTime.Value) or 60

                    if Options.UseMissionTimer.Value and (#limitedTargets >= aliveCount) and (elapsed < minTime) then
                        task.wait(1)
                        continue
                    end

                    performSimulatedClick(1400 + math.random(-15, 15), 900 + math.random(-15, 15))
                    executeOPSlash(limitedTargets) 
                end
            end
            
            task.wait(Options.OPFarmDelay.Value)
            continue 
        end

        -- ==========================================
        -- [ โหมด HUMANIZED FARM ]
        -- ==========================================
        if Options.Autofarm.Value then
            opFarmInitialized = false; RootPart.Anchored = false 
            
            if isBladeEmpty() then 
                if not savedHoverY then savedHoverY = RootPart.CFrame.Y end 
                safeRefillBlades()
                task.wait(1)
                continue
            end
            
            if savedHoverY then savedHoverY = nil end 
            
            if currentBossTarget then
                -- 🔥 [Start Timer on First Action]
                if not timerStarted then
                    missionStartTime = tick()
                    timerStarted = true
                end
                humanizedFlyTo(currentBossTarget.Position)
                while isFlying do task.wait(0.05) end
                
                executeBossBurst(currentBossTarget, Options.BurstAmount.Value)
                task.wait(math.max(0.1, Options.SlashDelay.Value + math.random(-0.1, 0.2)))
            else
                local limit = Options.TargetLimit.Value
                local radius = Options.AoERadius.Value
                local baseDelay = Options.SlashDelay.Value
                
                local targets, anchorPos = getTargetCluster(limit, radius)

                if #targets > 0 and anchorPos then
                    -- 🔥 [Start Timer on First Action]
                    if not timerStarted then
                        missionStartTime = tick()
                        timerStarted = true
                    end

                    local aliveCount = getAliveTitanCount()
                    local elapsed = tick() - missionStartTime
                    local minTime = tonumber(Options.MinMissionTime.Value) or 60

                    if Options.UseMissionTimer.Value and (#targets >= aliveCount) and (elapsed < minTime) then
                        humanizedFlyTo(anchorPos)
                        while isFlying do task.wait(0.05) end
                        task.wait(1)
                        continue
                    end

                    humanizedFlyTo(anchorPos)
                    while isFlying do task.wait(0.05) end
                    
                    executeMultiSlash(targets)
                    task.wait(math.max(0.1, baseDelay + math.random(-0.1, 0.2)))
                else task.wait(0.5) end
            end
        end
    end
end)

spawn(function()
    while task.wait(math.random(5, 15)) do
        if Options.Autofarm.Value and Options.EnableAntiCheatActions and Options.EnableAntiCheatActions.Value then
            pcall(function()
                local k = (math.random(1, 2) == 1) and Enum.KeyCode.Q or Enum.KeyCode.E
                VirtualInputManager:SendKeyEvent(true, k, false, game)
                task.wait(math.random(100, 500) / 1000)
                VirtualInputManager:SendKeyEvent(false, k, false, game)
            end)
        end
    end
end)

if ButtonsFolder then
    ButtonsFolder.ChildAdded:Connect(function(btn)
        if Options.Autofarm.Value or Options.OPFarm.Value then
            if flightConnection then flightConnection:Disconnect(); flightConnection = nil end
            isFlying = false; opFarmInitialized = false; RootPart.Anchored = false
            task.wait(0.15)
            POST:FireServer("Attacks", "Slash_Escape")
            btn:Destroy(); task.wait(0.3)
            
            local currentBossTarget = getAvailableBossWeakPoint()
            
            if Options.OPFarm.Value then
                if currentBossTarget then
                    executeBossBurst(currentBossTarget, Options.BurstAmount.Value)
                else
                    local t = getAllTargets(); local l = {}
                    for i = 1, math.min(#t, OP_MAX_TARGETS) do table.insert(l, t[i]) end
                    if #l > 0 then executeOPSlash(l) end
                end
            else
                if currentBossTarget then
                    executeBossBurst(currentBossTarget, Options.BurstAmount.Value)
                else
                    local t, _ = getTargetCluster(Options.TargetLimit.Value, Options.AoERadius.Value)
                    if #t > 0 then executeMultiSlash(t) end
                end
            end
        end
    end)
end

spawn(function()
    while task.wait(1) do
        if not Options.AutoRetry.Value then continue end
        if isRaidMap then
            if isRaidCompleted() then
                openRaidChests(); task.wait(1.5)
                pcall(function() GET:InvokeServer("Functions", "Retry", "Add") end)
                -- 🔥 [Reset Timer on Retry]
                timerStarted = false
                missionStartTime = nil
                task.wait(3)
            end
        else
            local a = 0
            if TitansFolder then for _, t in ipairs(TitansFolder:GetChildren()) do if t:IsA("Model") and t:FindFirstChildOfClass("Humanoid") and t.Humanoid.Health > 0 then a = a + 1 end end end
            if a == 0 then 
                pcall(function() GET:InvokeServer("Functions", "Retry", "Add") end)
                -- 🔥 [Reset Timer on Retry]
                timerStarted = false
                missionStartTime = nil
                task.wait(3) 
            end
        end
    end
end)

-- ==========================================
-- [ 6. Save/Load ]
-- ==========================================
SaveManager:SetLibrary(Library)
InterfaceManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("NonnyHub/game")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

local function getAutoSaveFile() return "autosave_" .. tostring(Player.Name) .. "_" .. tostring(game.GameId) end
task.spawn(function()
    local n = getAutoSaveFile(); local f = SaveManager.Folder .. "/settings/" .. n .. ".json"
    if isfile(f) then local s = SaveManager:Load(n); if s then Library:Notify({ Title = "Config", Content = "Auto-loaded", Duration = 3 }) end end
end)
local function autoSave() SaveManager:Save(getAutoSaveFile()) end
for _, o in pairs(Options) do if o.OnChanged then o:OnChanged(autoSave) end end

Window:SelectTab(1)
Library:Notify({Title="Loaded", Content="Enjoy!", Duration=5})
SaveManager:LoadAutoloadConfig()