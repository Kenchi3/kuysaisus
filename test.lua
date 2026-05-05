-- ==========================================
-- [ 1. โหลด Fluent UI Library ]
-- ==========================================
local Library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
local SaveManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"))()

local Window = Library:CreateWindow{
    Title = "Klakuylek Hub",
    SubTitle = "Stealth Hybrid Guard",
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
local HttpService = game:GetService("HttpService")

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

local farmingStarted = false
local fallbackStartTime = 0
local LAST_TITAN_THRESHOLD = 5 
local runCounter = 0
local lastJoinAttempt = 0

local opFarmInitialized = false
local OP_FLY_HEIGHT = 300
local OP_MAX_TARGETS = 3

local antiGravityConn = nil
local savedHoverY = nil

local runCountFile = "NonnyHub/game/runcount_" .. Player.Name .. "_" .. tostring(game.GameId) .. ".json"

local function saveRunCount()
    if not isfolder("NonnyHub") then makefolder("NonnyHub") end
    if not isfolder("NonnyHub/game") then makefolder("NonnyHub/game") end
    pcall(function()
        local data = { count = runCounter }
        writefile(runCountFile, HttpService:JSONEncode(data))
    end)
end

local function loadRunCount()
    pcall(function()
        if isfile(runCountFile) then
            local rawData = readfile(runCountFile)
            local data = HttpService:JSONDecode(rawData)
            if data and type(data.count) == "number" then runCounter = data.count end
        end
    end)
end

loadRunCount()

local UPGRADE_STATS = {
    Blades = { "ODM_Damage", "Crit_Damage", "Crit_Chance", "Blade_Durability", "ODM_Speed", "ODM_Control", "ODM_Range", "ODM_Gas" },
    Spears = { "TS_Damage", "Crit_Damage", "Crit_Chance", "Blast_Radius", "TS_Speed", "TS_Control", "TS_Range", "TS_Gas" }
}

local function getRaidAnchorPos()
    local unclimbable = workspace:FindFirstChild("Unclimbable")
    if not unclimbable then return nil end
    if PlaceId == 14012874501 then
        local background = unclimbable:FindFirstChild("Background")
        if background then local npc = background:FindFirstChild("Attack_Titan"); if npc then return npc:IsA("Model") and npc:GetPivot().Position or npc.Position end end
    elseif PlaceId == 13379349730 then
        local objective = unclimbable:FindFirstChild("Objective")
        if objective then local boat = objective:FindFirstChild("Boat1"); if boat then return boat:IsA("Model") and boat:GetPivot().Position or boat.Position end end
    end
    return nil
end

-- [เพิ่มเติม] ฟังก์ชันสำหรับดึง Object ตัวจริงมาเช็คว่ายังมีชีวิตอยู่ไหม
local function getRaidAnchorObj()
    local unclimbable = workspace:FindFirstChild("Unclimbable")
    if not unclimbable then return nil, nil end
    if PlaceId == 14012874501 then
        local background = unclimbable:FindFirstChild("Background")
        if background then 
            local npc = background:FindFirstChild("Attack_Titan") 
            if npc then 
                return npc, (npc:IsA("Model") and npc:GetPivot().Position or npc.Position)
            end 
        end
    elseif PlaceId == 13379349730 then
        local objective = unclimbable:FindFirstChild("Objective")
        if objective then 
            local boat = objective:FindFirstChild("Boat1") 
            if boat then 
                return boat, (boat:IsA("Model") and boat:GetPivot().Position or boat.Position)
            end 
        end
    end
    return nil, nil
end

-- ==========================================
-- [ 3. ฟังก์ชันระบบทำงาน (Stealth Version) ]
-- ==========================================
local FLY_OFFSET = 150
local FLY_SPEED = 200
local isFlying = false
local NoclipConnection = nil
local flightConnection = nil 

local function stealthFlyTo(targetPos)
    if not RootPart or isFlying then return end 
    isFlying = true
    Humanoid.PlatformStand = true
    
    local goalPos = targetPos + Vector3.new(math.random(-5, 5), FLY_OFFSET + math.random(-2, 2), math.random(-5, 5))

    if flightConnection then flightConnection:Disconnect() end
    
    flightConnection = RunService.Heartbeat:Connect(function(dt)
        if not isFlying then return end
        
        local direction = (goalPos - RootPart.Position)
        local distance = direction.Magnitude
        
        if distance < 5 then
            isFlying = false
            RootPart.AssemblyLinearVelocity = RootPart.AssemblyLinearVelocity * 0.1
            
            -- [แก้ไข] ปล่อย PlatformStand เมื่อบินถึงจุดหมาย เพื่อให้ระบบลอยซ่อนเสร็จแล้วทำงานต่อ
            if not Options.OPFarm.Value then
                Humanoid.PlatformStand = false
            end
            
            if flightConnection then flightConnection:Disconnect(); flightConnection = nil end
            return
        end

        local speedFactor = math.clamp(distance / 20, 0.5, 1)
        local targetVelocity = direction.Unit * (FLY_SPEED * speedFactor)
        
        RootPart.AssemblyLinearVelocity = RootPart.AssemblyLinearVelocity:Lerp(targetVelocity, 0.2)
        RootPart.CFrame = CFrame.lookAt(RootPart.Position, Vector3.new(goalPos.X, RootPart.Position.Y, goalPos.Z))
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
    if rig then for i = 1, 3 do local spare = rig:FindFirstChild("Left_" .. i, true); if spare and spare:GetAttribute("Used") == nil then return true end end end
    return false
end

local function isBladeEmpty()
    local rig = Character:FindFirstChild("Rig_" .. Player.Name)
    if rig and rig:FindFirstChild("LeftHand") then local blade = rig.LeftHand:FindFirstChild("Blade_1"); if not blade or blade.Transparency == 1 then return true end end
    return false
end

local lastRefillAttempt = 0
local REFILL_COOLDOWN = 2.5 

local function safeRefillBlades()
    if tick() - lastRefillAttempt < REFILL_COOLDOWN then return end
    lastRefillAttempt = tick()
    if hasSpareBlades() then pcall(function() GET:InvokeServer("Blades", "Reload") end)
    else local s = findNearestStation(); if s then pcall(function() POST:FireServer("Attacks", "Reload", s) end) end end
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
    task.spawn(function() local s, a = pcall(function() return TitansFolder:WaitForChild("Attack_Titan", 300) end); if s and a then trackBossWeakPoint(a) end end)
    task.spawn(function() local s, a = pcall(function() return TitansFolder:WaitForChild("Armored_Titan", 300) end); if s and a then trackBossWeakPoint(a) end end)
end

local function getAvailableBossWeakPoint()
    if not Options.BossBurst.Value then return nil end
    local raidBossNames = {"Attack_Titan", "Armored_Titan"}
    
    for _, bossName in ipairs(raidBossNames) do
        -- 1. ถ้ามีจุดอ่อน (Marker) ให้ยิงที่จุดอ่อนก่อน
        if RaidBossWeakPoints[bossName] and RaidBossWeakPoints[bossName].Parent then
            return RaidBossWeakPoints[bossName]
        end
        
        -- 2. ถ้าไม่มีจุดอ่อน ให้ลงไปหา Nape ของบอสตัวนั้นโดยตรง
        local bossModel = TitansFolder and TitansFolder:FindFirstChild(bossName)
        if bossModel and bossModel:IsA("Model") then
            local hum = bossModel:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local hb = bossModel:FindFirstChild("Hitboxes")
                if hb then
                    local hf = hb:FindFirstChild("Hit")
                    if hf then
                        -- ค้นหา Nape ใน Hitboxes
                        local nape = hf:FindFirstChild("Nape") or hf:FindFirstChildWhichIsA("BasePart")
                        if nape then return nape end
                    end
                end
            end
        end
    end
    
    return nil
end

local function getAliveTitanCount()
    local count = 0; if not TitansFolder then return 0 end
    for _, titan in ipairs(TitansFolder:GetChildren()) do if titan:IsA("Model") then local hum = titan:FindFirstChildOfClass("Humanoid"); if hum and hum.Health > 0 then count = count + 1 end end end
    return count
end

local function getTargetCluster(maxCount, radius)
    local closestPart, minDistance, anchorPosition = nil, math.huge, RootPart.Position
    if isRaidMap then local p = getRaidAnchorPos(); if p then anchorPosition = p end end
    if not TitansFolder then return {}, nil end
    for _, titan in ipairs(TitansFolder:GetChildren()) do
        if titan:IsA("Model") and titan:FindFirstChildOfClass("Humanoid") and titan.Humanoid.Health > 0 and titan:FindFirstChild("Hitboxes") then
            local tp = RaidBossWeakPoints[titan.Name] or (titan.Hitboxes:FindFirstChild("Hit") and titan.Hitboxes.Hit:FindFirstChild("Nape"))
            if tp then local d = (anchorPosition - tp.Position).Magnitude; if d < minDistance then minDistance = d; closestPart = tp end end
        end
    end
    if not closestPart then return {}, nil end
    local t, lim = {}, {}
    for _, titan in ipairs(TitansFolder:GetChildren()) do
        if titan:IsA("Model") and titan:FindFirstChildOfClass("Humanoid") and titan.Humanoid.Health > 0 and titan:FindFirstChild("Hitboxes") then
            local tp = RaidBossWeakPoints[titan.Name] or (titan.Hitboxes:FindFirstChild("Hit") and titan.Hitboxes.Hit:FindFirstChild("Nape"))
            if tp and (tp.Position - closestPart.Position).Magnitude <= radius then table.insert(t, tp) end
        end
    end
    table.sort(t, function(a, b) return (a.Position - closestPart.Position).Magnitude < (b.Position - closestPart.Position).Magnitude end)
    for i = 1, math.min(#t, maxCount) do table.insert(lim, t[i]) end
    return lim, closestPart.Position
end

local function getAllTargets()
    local targets = {}; if not TitansFolder then return targets end
    for _, titan in ipairs(TitansFolder:GetChildren()) do
        if titan:IsA("Model") and titan:FindFirstChildOfClass("Humanoid") and titan.Humanoid.Health > 0 then
            local tp = RaidBossWeakPoints[titan.Name]
            if not tp then local hb = titan:FindFirstChild("Hitboxes"); if hb then local hf = hb:FindFirstChild("Hit"); if hf then tp = hf:FindFirstChild("Nape") or hf:FindFirstChildWhichIsA("BasePart") end end end
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

local function executeStealthSlash(napesArray, isOP)
    if not napesArray or #napesArray == 0 then return false end
    
    if not isOP then
        local mainTarget = napesArray[1]
        if mainTarget and mainTarget.Parent then
            pcall(function() workspace.CurrentCamera.CFrame = CFrame.lookAt(workspace.CurrentCamera.CFrame.Position, mainTarget.Position) end)
            task.wait(math.random(50, 100) / 1000)
        end
    end

    pcall(function() POST:FireServer("Attacks", "Slash", true) end)
    
    if Options.EnableAntiCheatActions and Options.EnableAntiCheatActions.Value and not isOP then
        task.wait(math.random(50, 100) / 1000)
    end
    
    for i, napePart in ipairs(napesArray) do
        if napePart and napePart.Parent then
            task.spawn(function()
                task.wait(math.random(1, 3) / 100)
                pcall(function() GET:InvokeServer("Hitboxes", "Register", napePart, math.random(180, 260), math.random(10, 100)) end)
            end)
        end
    end
    return true
end

local function executeBossBurst(bossPart, burstAmount)
    if not bossPart then return false end
    
    -- ยิงตามจำนวน Burst Amount แบบรัวๆทันที
    for i = 1, burstAmount do
        task.spawn(function()
            -- ยิง Animation Slash
            pcall(function() POST:FireServer("Attacks", "Slash", true) end)
            
            -- หน่วงไมโครวินาทีเพื่อให้ Server ทันรับ Event แล้วค่อยยิง Hit
            
            -- ยิง Register Hit
            pcall(function() GET:InvokeServer("Hitboxes", "Register", bossPart, math.random(180, 260), math.random(10, 100)) end)
        end)
        
        -- หน่วงเล็กน้อยระหว่างแต่ละรอบที่สปัวน์ เพื่อไม่ให้ยิงทับกันใน 1 เฟรมมากเกินไป (ป้องกันล้มเหลวจาก Server Rate Limit)
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
    if c and c.Visible then return true end; if r and r.Visible then return true end; return false
end

local function joinBoostedMission()
    local boostedMap = Workspace:GetAttribute("Boosted_Map")
    if not boostedMap then Library:Notify({Title="Error", Content="No Boosted Map found!", Duration=3}); return false end
    local raidMaps = {"Attack Titan", "Armored Titan", "Female Titan", "Colossal Titan"}
    if table.find(raidMaps, boostedMap) then Library:Notify({Title="Info", Content="Boosted map is a Raid, skipping...", Duration=3}); return false end
    local difficulties = {"Aberrant", "Severe", "Hard", "Normal", "Easy"}
    for _, diff in ipairs(difficulties) do
        local success, result = pcall(function() return GET:InvokeServer("S_Missions", "Create", {Name = boostedMap, Difficulty = diff, Type = "Missions", Objective = "Skirmish"}) end)
        if success and result then Library:Notify({Title="Success", Content="Created " .. diff .. " lobby!", Duration=3}); task.wait(1); GET:InvokeServer("S_Missions", "Start"); return true end
    end
    return false
end

-- ==========================================
-- [ 4. สร้าง UI Elements ]
-- ==========================================
Tabs.Main:CreateSection("Auto Upgrade")
Tabs.Main:CreateToggle("AutoUpgrade", { Title = "Auto Upgrade Equipment", Default = false })
Tabs.Main:CreateDropdown("UpgradeWeaponType", { Title = "Weapon Type", Values = {"Blades", "Spears", "Both"}, Default = 1 })

Tabs.Main:CreateSection("Auto Farm (Safe)")
Tabs.Main:CreateToggle("OPFarm", { Title = "OP Farm (Sky Nuke)", Description = "Risky but Stealthier now!", Default = false })
Tabs.Main:CreateToggle("BossBurst", { Title = "Raid Boss Burst", Default = false })
Tabs.Main:CreateSlider("BurstAmount", { Title = "Burst Hits Amount", Min = 1, Max = 9, Default = 5, Rounding = 0 })

Tabs.Main:CreateToggle("Autofarm", { Title = "Auto Farm (Safe)", Default = false })
Tabs.Main:CreateToggle("EnableAntiCheatActions", { Title = "Anti-Cheat Simulation", Description = "Simulate Q,E randomly", Default = true })
Tabs.Main:CreateSlider("TargetLimit", { Title = "AoE Target Limit", Min = 1, Max = 10, Default = 5, Rounding = 0 })
Tabs.Main:CreateSlider("AoERadius", { Title = "AoE Radius (Slash Range)", Min = 50, Max = 1000, Default = 250, Rounding = 0 })
Tabs.Main:CreateSlider("SlashDelay", { Title = "Slash Delay", Min = 0.1, Max = 2.0, Default = 0.6, Rounding = 1 })

Tabs.Main:CreateSection("Time Guard")
Tabs.Main:CreateToggle("UseMissionTimer", { Title = "Hybrid Time Guard", Default = false })
Tabs.Main:CreateInput("MinMissionTime", { Title = "Min. Mission Time (Seconds)", Default = "60", Numeric = true })
local TimerDisplay = Tabs.Main:CreateParagraph("TimerDisplay", { Title = "Timer Status", Content = "Status: Idle" })

Tabs.Main:CreateSection("Misc")
Tabs.Main:CreateToggle("OpenPremiumChest", { Title = "Open Premium Chest", Default = false })
Tabs.Main:CreateToggle("AutoRetry", { Title = "Auto Retry", Default = true })
local RunDisplay = Tabs.Main:CreateParagraph("RunDisplay", { Title = "Run Progress", Content = "Current: 0 / Max: 0" })
Tabs.Main:CreateInput("MaxRuns", { Title = "Max Runs (0 = Infinite)", Default = "0", Numeric = true })
Tabs.Main:CreateButton{ Title = "Shadow Ban Check", Callback = function() Library:Notify({ Title = "Shadow Ban Status", Content = Player:GetAttribute("Exploiter") and "⚠️ BANNED" or "✅ SAFE", Duration = 5 }) end }
Tabs.Main:CreateToggle("AutoJoinBoosted", { Title = "Auto Join Boosted Mission", Default = false })

-- ==========================================
-- [ 5. Loop หลัก (Stealth Version) ]
-- ==========================================
Humanoid.Died:Connect(function()
    if flightConnection then flightConnection:Disconnect(); flightConnection = nil end
    if antiGravityConn then antiGravityConn:Disconnect(); antiGravityConn = nil end
    isFlying = false; opFarmInitialized = false; savedHoverY = nil; farmingStarted = false
    Character = Player.CharacterAdded:Wait()
    RootPart = Character:WaitForChild("HumanoidRootPart")
    Humanoid = Character:WaitForChild("Humanoid")
end)

spawn(function()
    while task.wait(0.5) do
        local currentCount = runCounter
        local maxCount = tonumber(Options.MaxRuns.Value) or 0
        RunDisplay:SetContent(maxCount == 0 and string.format("Current: %d / Max: ∞", currentCount) or string.format("Current: %d / Max: %d", currentCount, maxCount))
    end
end)

spawn(function()
    while task.wait(2) do
        local isLobby = Workspace:GetAttribute("Map") == "Lobby"
        if isLobby then
            if runCounter ~= 0 then runCounter = 0; saveRunCount() end
            if Options.AutoUpgrade.Value then
                local selectedType = Options.UpgradeWeaponType.Value; local statsList = {}
                if selectedType == "Blades" or selectedType == "Both" then for _, stat in pairs(UPGRADE_STATS.Blades) do table.insert(statsList, stat) end end
                if selectedType == "Spears" or selectedType == "Both" then for _, stat in pairs(UPGRADE_STATS.Spears) do table.insert(statsList, stat) end end
                local upgrading = true
                while upgrading do
                    local successCount = 0
                    for _, statName in pairs(statsList) do
                        local success, result = pcall(function() return GET:InvokeServer("S_Equipment", "Upgrade", {statName}) end)
                        if success and result then successCount = successCount + 1; task.wait(0.3) else task.wait(0.1) end
                    end
                    if successCount == 0 then upgrading = false end; task.wait(1)
                end
            end
            if Options.AutoJoinBoosted.Value and tick() - lastJoinAttempt > 5 then lastJoinAttempt = tick(); joinBoostedMission() end
        end
    end
end)

spawn(monitorRaidBosses)

spawn(function()
    while task.wait(0.1) do
        if not Options.Autofarm.Value and not Options.OPFarm.Value then 
            if flightConnection then flightConnection:Disconnect(); flightConnection = nil end
            if antiGravityConn then antiGravityConn:Disconnect(); antiGravityConn = nil end
            isFlying = false; opFarmInitialized = false; savedHoverY = nil; Humanoid.PlatformStand = false; RootPart.Anchored = false; farmingStarted = false
            if NoclipConnection then NoclipConnection:Disconnect(); NoclipConnection = nil
                if Character then for _, p in pairs(Character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = true end end end
            end
            continue 
        end

        -- [แก้ไขหลัก] Anti-Gravity ไม่ลบค่าความเร็วแกน X Z และหยุดทำงานเมื่อกำลังบิน
        if not antiGravityConn then
            antiGravityConn = RunService.Heartbeat:Connect(function()
                if RootPart and not RootPart.Anchored and (Options.Autofarm.Value or Options.OPFarm.Value) then
                    -- ถ้าระบบบินกำลังควบคุม ให้ Anti-Gravity ยกเลิกการแทรกแซงเพื่อไม่ให้ชนกัน
                    if isFlying then return end
                    
                    local currentVel = RootPart.AssemblyLinearVelocity
                    if savedHoverY then
                        local diff = savedHoverY - RootPart.Position.Y
                        -- ดันตัวขึ้นลงเท่านั้น โดยเก็บค่า X Z เดิมไว้
                        RootPart.AssemblyLinearVelocity = Vector3.new(currentVel.X, diff * 5, currentVel.Z)
                    else
                        -- ชะลอการตก โดยไม่รบกวนแกน X Z
                        RootPart.AssemblyLinearVelocity = Vector3.new(currentVel.X, math.clamp(currentVel.Y, -5, 100), currentVel.Z)
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
                        if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
                    end
                end
            end)
        end

        local currentBossTarget = getAvailableBossWeakPoint()
        local aliveCount = getAliveTitanCount()
        local isLastPhase = aliveCount <= LAST_TITAN_THRESHOLD
        local canKill = true

        if Options.UseMissionTimer.Value and isLastPhase then
            local minTime = tonumber(Options.MinMissionTime.Value) or 60
            if not farmingStarted then farmingStarted = true; fallbackStartTime = tick() end
            local gameTime = Workspace:GetAttribute("Seconds") or (tick() - fallbackStartTime)
            canKill = gameTime >= minTime
        end

        if Options.OPFarm.Value and Workspace:GetAttribute("Map") ~= "Lobby" then
            if flightConnection then flightConnection:Disconnect(); flightConnection = nil end
            isFlying = false; Humanoid.PlatformStand = true
            
            if not opFarmInitialized then
                savedHoverY = OP_FLY_HEIGHT + math.random(-5, 5)
                RootPart.AssemblyLinearVelocity = Vector3.new(0, 100, 0)
                opFarmInitialized = true
            end
            
            if isBladeEmpty() then 
                safeRefillBlades()
                task.wait(1) 
                continue 
            end

            if currentBossTarget then
                
                executeBossBurst(currentBossTarget, Options.BurstAmount.Value)
            else
                local allTargets = getAllTargets()
                local limitedTargets = {}; for i = 1, math.min(#allTargets, OP_MAX_TARGETS) do table.insert(limitedTargets, allTargets[i]) end
                if #limitedTargets > 0 then
                    if canKill then executeStealthSlash(limitedTargets, true) end
                end
            end
            task.wait(1); continue 
        end

        if Options.Autofarm.Value then
            opFarmInitialized = false; RootPart.Anchored = false 
            -- [แก้ไข] ปล่อย PlatformStand ทันทีเมื่อเข้า Safe Mode
            Humanoid.PlatformStand = false 
            
            if isBladeEmpty() then 
                if not savedHoverY then savedHoverY = RootPart.CFrame.Y end 
                safeRefillBlades(); task.wait(1); continue
            end
            
            savedHoverY = nil
            
            if currentBossTarget then
                stealthFlyTo(currentBossTarget.Position)
                while isFlying do task.wait(0.05) end
                if canKill then executeBossBurst(currentBossTarget, Options.BurstAmount.Value) end
                task.wait(math.max(0.1, Options.SlashDelay.Value + math.random(-0.1, 0.2)))
            else
                local limit = Options.TargetLimit.Value; local radius = Options.AoERadius.Value
                local targets, anchorPos = getTargetCluster(limit, radius)
                if #targets > 0 and anchorPos then
                    stealthFlyTo(anchorPos)
                    while isFlying do task.wait(0.05) end
                    if canKill then executeStealthSlash(targets, false) end
                    task.wait(math.max(0.1, Options.SlashDelay.Value + math.random(-0.1, 0.2)))
                else task.wait(0.5) end
            end
        end
    end
end)

spawn(function()
    while task.wait(0.1) do
        if Options.UseMissionTimer.Value then
            local minTime = tonumber(Options.MinMissionTime.Value) or 60
            local gameTime = Workspace:GetAttribute("Seconds") or (tick() - fallbackStartTime)
            local remaining = minTime - gameTime
            TimerDisplay:SetContent(remaining > 0 and string.format("%02d:%02d", math.floor(remaining / 60), math.floor(remaining % 60)) or "Ready!")
        else TimerDisplay:SetContent("--:--") end
    end
end)

spawn(function()
    while task.wait(math.random(5, 15)) do
        if Options.Autofarm.Value and Options.EnableAntiCheatActions and Options.EnableAntiCheatActions.Value then
            pcall(function()
                local k = (math.random(1, 2) == 1) and Enum.KeyCode.Q or Enum.KeyCode.E
                VirtualInputManager:SendKeyEvent(true, k, false, game); task.wait(math.random(100, 500) / 1000)
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
            task.wait(0.15); POST:FireServer("Attacks", "Slash_Escape"); btn:Destroy(); task.wait(0.3)
            local currentBossTarget = getAvailableBossWeakPoint()
            if Options.OPFarm.Value then
                if currentBossTarget then executeBossBurst(currentBossTarget, Options.BurstAmount.Value)
                else local t = getAllTargets(); local l = {}; for i = 1, math.min(#t, OP_MAX_TARGETS) do table.insert(l, t[i]) end; if #l > 0 then executeStealthSlash(l, true) end end
            else
                if currentBossTarget then executeBossBurst(currentBossTarget, Options.BurstAmount.Value)
                else local t, _ = getTargetCluster(Options.TargetLimit.Value, Options.AoERadius.Value); if #t > 0 then executeStealthSlash(t, false) end end
            end
        end
    end)
end

spawn(function()
    local missionstarted = false 
    while task.wait(2) do
        if not Options.AutoRetry.Value then continue end
        
        -- เริ่มนับเวลาเมื่อเจอไททันตัวแรก
        if not missionstarted and getAliveTitanCount() > 0 then 
            missionstarted = true 
        end
        
        -- [แก้ไขหลัก] แยกเงื่อนไขการจบเกมระหว่าง Raid กับโหมดธรรมดา
        local shouldProcess = false
        if missionstarted and Workspace:GetAttribute("Map") ~= "Lobby" then
            if isRaidMap then
                -- สำหรับ RAID: จะถือว่าจบก็ต่อเมื่อ UI กล่องสมบัติขึ้นมาจริงๆ เท่านั้น (ไม่สนหายไปชั่วคราวระหว่าง Phase)
                shouldProcess = isRaidCompleted()
            else
                -- สำหรับโหมมอื่น: ใช้เงื่อนไขเดิม (ไททันหมด = จบ)
                shouldProcess = getAliveTitanCount() == 0
            end
        end

        if shouldProcess then
            runCounter = runCounter + 1; saveRunCount()
            local maxRuns = tonumber(Options.MaxRuns.Value) or 0
            
            if maxRuns > 0 and runCounter >= maxRuns then
                pcall(function() POST:FireServer("Functions", "Teleport") end)
                runCounter = 0; missionstarted = false; task.wait(10)
            else
                if isRaidMap then 
                    openRaidChests(); task.wait(1.5) 
                end
                
                missionstarted = false 
                pcall(function() GET:InvokeServer("Functions", "Retry", "Add") end)
                farmingStarted = false; task.wait(6)
            end
        end
    end
end)

-- ==========================================
-- [ 6. Save/Load ]
-- ==========================================
SaveManager:SetLibrary(Library); InterfaceManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings(); SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("FluentScriptHub"); SaveManager:SetFolder("NonnyHub/game")
InterfaceManager:BuildInterfaceSection(Tabs.Settings); SaveManager:BuildConfigSection(Tabs.Settings)

local function getAutoSaveFile() return "autosave_" .. tostring(Player.Name) .. "_" .. tostring(game.GameId) end
task.spawn(function() local n = getAutoSaveFile(); local f = SaveManager.Folder .. "/settings/" .. n .. ".json"; if isfile(f) then SaveManager:Load(n) end end)
local function autoSave() SaveManager:Save(getAutoSaveFile()) end
for _, o in pairs(Options) do if o.OnChanged then o:OnChanged(autoSave) end end

Window:SelectTab(1)
Library:Notify({Title="Loaded", Content="Stealth Version Applied!", Duration=5})
SaveManager:LoadAutoloadConfig()