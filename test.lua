-- ==========================================
-- [ 1. โหลด Fluent UI Library ]
-- ==========================================
local Library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
local SaveManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"))()

local Window = Library:CreateWindow{
    Title = "Klakuylek Hub",
    SubTitle = "Hook Physics v3 (Height Lock)",
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
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local RootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

local Remotes = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local POST = Remotes:WaitForChild("POST")
local GET = Remotes:WaitForChild("GET")
local TitansFolder = Workspace:FindFirstChild("Titans")
local ButtonsFolder = Player:WaitForChild("PlayerGui"):WaitForChild("Interface"):FindFirstChild("Buttons")

local PlaceId = game.PlaceId
local isRaidMap = workspace:GetAttribute("Type") == "Raids"
local RaidBossWeakPoints = {} 

local farmingStarted = false
local fallbackStartTime = 0
local LAST_TITAN_THRESHOLD = 5 
local runCounter = 0
local lastJoinAttempt = 0

local opFarmInitialized = false
local OP_FLY_HEIGHT = 300
local OP_MAX_TARGETS = 3

-- [ระบบฟิสิกส์]
local savedHoverY = nil
local flyTargetPos = nil
local isFlying = false
local physicsConn = nil
local lockHeight_Y = nil -- ตัวแปรสำหรับล๊อคความสูงในโหมด Normal Farm

local runCountFile = "NonnyHub/game/runcount_" .. Player.Name .. "_" .. tostring(game.GameId) .. ".json"

local function saveRunCount()
    if not isfolder("NonnyHub") then makefolder("NonnyHub") end
    if not isfolder("NonnyHub/game") then makefolder("NonnyHub/game") end
    pcall(function() writefile(runCountFile, HttpService:JSONEncode({ count = runCounter })) end)
end

local function loadRunCount()
    pcall(function()
        if isfile(runCountFile) then
            local data = HttpService:JSONDecode(readfile(runCountFile))
            if data and type(data.count) == "number" then runCounter = data.count end
        end
    end)
end
loadRunCount()

local UPGRADE_STATS = {
    Blades = { "ODM_Damage", "Crit_Damage", "Crit_Chance", "Blade_Durability", "ODM_Speed", "ODM_Control", "ODM_Range", "ODM_Gas" },
    Spears = { "TS_Damage", "Crit_Damage", "Crit_Chance", "Blast_Radius", "TS_Speed", "TS_Control", "TS_Range", "TS_Gas" }
}

-- ==========================================
-- [ ระบบตรวจสอบ Phase และ Anchor ]
-- ==========================================
local function getRaidAnchorPos()
    local unclimbable = workspace:FindFirstChild("Unclimbable")
    if not unclimbable then return nil end
    if PlaceId == 14012874501 then
        local bg = unclimbable:FindFirstChild("Background")
        if bg then local npc = bg:FindFirstChild("Attack_Titan"); if npc then return npc:IsA("Model") and npc:GetPivot().Position or npc.Position end end
    elseif PlaceId == 13379349730 then
        local obj = unclimbable:FindFirstChild("Objective")
        if obj then local boat = obj:FindFirstChild("Boat1"); if boat then return boat:IsA("Model") and boat:GetPivot().Position or boat.Position end end
    end
    return nil
end

local function isAnchorPhaseActive()
    if not isRaidMap then return false end
    if TitansFolder then
        local activeBoss = TitansFolder:FindFirstChild("Attack_Titan") or TitansFolder:FindFirstChild("Armored_Titan")
        if activeBoss and activeBoss:FindFirstChildOfClass("Humanoid") then
            if activeBoss.Humanoid.Health > 0 then return false end
        end
    end
    if PlaceId == 14012874501 then
        local unclimbable = workspace:FindFirstChild("Unclimbable")
        return unclimbable and unclimbable:FindFirstChild("Background") and unclimbable.Background:FindFirstChild("Attack_Titan") ~= nil or false
    elseif PlaceId == 13379349730 then
        local unclimbable = workspace:FindFirstChild("Unclimbable")
        if unclimbable and unclimbable:FindFirstChild("Objective") then
            local bossObj = unclimbable.Objective:FindFirstChild("Armored_Boss")
            return bossObj and bossObj:GetAttribute("Phase") == 1 or false
        end
    end
    return false
end

-- ==========================================
-- [ 3. ฟังก์ชันระบบทำงาน ]
-- ==========================================
local FLY_OFFSET = 150

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
    for _, bossName in ipairs({"Attack_Titan", "Armored_Titan"}) do
        if RaidBossWeakPoints[bossName] and RaidBossWeakPoints[bossName].Parent then return RaidBossWeakPoints[bossName] end
        local bossModel = TitansFolder and TitansFolder:FindFirstChild(bossName)
        if bossModel and bossModel:FindFirstChildOfClass("Humanoid") and bossModel.Humanoid.Health > 0 then
            local hf = bossModel:FindFirstChild("Hitboxes") and bossModel.Hitboxes:FindFirstChild("Hit")
            if hf then local nape = hf:FindFirstChild("Nape") or hf:FindFirstChildWhichIsA("BasePart"); if nape then return nape end end
        end
    end
    return nil
end

local function getAliveTitanCount()
    local count = 0; if not TitansFolder then return 0 end
    for _, t in ipairs(TitansFolder:GetChildren()) do if t:IsA("Model") and t:FindFirstChildOfClass("Humanoid") and t.Humanoid.Health > 0 then count = count + 1 end end
    return count
end

local function getTargetsNearAnchor(maxCount, radius)
    local ap = getRaidAnchorPos(); if not ap or not TitansFolder then return {}, nil end
    local targets = {}
    for _, t in ipairs(TitansFolder:GetChildren()) do
        if t:IsA("Model") and t:FindFirstChildOfClass("Humanoid") and t.Humanoid.Health > 0 and t:FindFirstChild("Hitboxes") then
            local tp = RaidBossWeakPoints[t.Name] or (t.Hitboxes:FindFirstChild("Hit") and t.Hitboxes.Hit:FindFirstChild("Nape"))
            if tp and (tp.Position - ap).Magnitude <= radius then table.insert(targets, tp) end
        end
    end
    table.sort(targets, function(a, b) return (a.Position - ap).Magnitude < (b.Position - ap).Magnitude end)
    local lim = {}
    for i = 1, math.min(#targets, maxCount) do table.insert(lim, targets[i]) end
    return lim, ap
end

local function getTargetCluster(maxCount, radius)
    local cp, md, anchorPos = nil, math.huge, RootPart.Position
    if isRaidMap then local p = getRaidAnchorPos(); if p then anchorPos = p end end
    if not TitansFolder then return {}, nil end
    for _, t in ipairs(TitansFolder:GetChildren()) do
        if t:IsA("Model") and t:FindFirstChildOfClass("Humanoid") and t.Humanoid.Health > 0 and t:FindFirstChild("Hitboxes") then
            local tp = RaidBossWeakPoints[t.Name] or (t.Hitboxes:FindFirstChild("Hit") and t.Hitboxes.Hit:FindFirstChild("Nape"))
            if tp then local d = (anchorPos - tp.Position).Magnitude; if d < md then md = d; cp = tp end end
        end
    end
    if not cp then return {}, nil end
    local tgt, lim = {}, {}
    for _, t in ipairs(TitansFolder:GetChildren()) do
        if t:IsA("Model") and t:FindFirstChildOfClass("Humanoid") and t.Humanoid.Health > 0 and t:FindFirstChild("Hitboxes") then
            local tp = RaidBossWeakPoints[t.Name] or (t.Hitboxes:FindFirstChild("Hit") and t.Hitboxes.Hit:FindFirstChild("Nape"))
            if tp and (tp.Position - cp.Position).Magnitude <= radius then table.insert(tgt, tp) end
        end
    end
    table.sort(tgt, function(a, b) return (a.Position - cp.Position).Magnitude < (b.Position - cp.Position).Magnitude end)
    for i = 1, math.min(#tgt, maxCount) do table.insert(lim, tgt[i]) end
    return lim, cp.Position
end

local function getAllTargets()
    local targets = {}; if not TitansFolder then return targets end
    for _, t in ipairs(TitansFolder:GetChildren()) do
        if t:IsA("Model") and t:FindFirstChildOfClass("Humanoid") and t.Humanoid.Health > 0 then
            local tp = RaidBossWeakPoints[t.Name] or (t:FindFirstChild("Hitboxes") and t.Hitboxes:FindFirstChild("Hit") and t.Hitboxes.Hit:FindFirstChild("Nape") or t.Hitboxes.Hit:FindFirstChildWhichIsA("BasePart"))
            if tp then table.insert(targets, tp) end
        end
    end
    return targets
end

local function executeStealthSlash(napesArray, isOP)
    if not napesArray or #napesArray == 0 then return false end
    Humanoid.PlatformStand = false
    
    if not isOP then
        local mainTarget = napesArray[1]
        if mainTarget and mainTarget.Parent then
            pcall(function() workspace.CurrentCamera.CFrame = CFrame.lookAt(workspace.CurrentCamera.CFrame.Position, mainTarget.Position) end)
        end
    end

    pcall(function() POST:FireServer("Attacks", "Slash", true) end)
    
    for i, napePart in ipairs(napesArray) do
        if napePart and napePart.Parent then
            task.spawn(function()
                pcall(function() GET:InvokeServer("Hitboxes", "Register", napePart, math.random(180, 260), math.random(10, 100)) end)
            end)
        end
    end

    -- [แก้ไข] ถ้าเป็น Normal Farm ให้เปิด PlatformStand ทันทีหลังโจมตีเพื่อไม่ให้ตก
    if isOP then 
        Humanoid.PlatformStand = true 
    else
        if Options.Autofarm.Value then
            Humanoid.PlatformStand = true
        end
    end
    return true
end

local function executeBossBurst(bossPart, burstAmount)
    if not bossPart then return false end
    for i = 1, burstAmount do
        Humanoid.PlatformStand = false
        pcall(function() POST:FireServer("Attacks", "Slash", true) end)
        pcall(function() GET:InvokeServer("Hitboxes", "Register", bossPart, math.random(180, 260), math.random(10, 100)) end)
        if Options.OPFarm.Value then Humanoid.PlatformStand = true end
    end
    return true
end

local function selectAndPressEnter(button)
    if button and button:IsA("GuiButton") then
        GuiService.SelectedObject = button; task.wait(0.3)
        GuiService:SendKeyEvent(true, Enum.KeyCode.Return, false, game); task.wait(0.1)
        GuiService:SendKeyEvent(false, Enum.KeyCode.Return, false, game); task.wait(0.2)
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
    return (inf:FindFirstChild("Chests") and inf.Chests.Visible) or (inf:FindFirstChild("Rewards") and inf.Rewards.Visible) or false
end

local function joinBoostedMission()
    local bm = Workspace:GetAttribute("Boosted_Map")
    if not bm then Library:Notify({Title="Error", Content="No Boosted Map!", Duration=3}); return false end
    if table.find({"Attack Titan", "Armored Titan", "Female Titan", "Colossal Titan"}, bm) then return false end
    for _, d in ipairs({"Aberrant", "Severe", "Hard", "Normal", "Easy"}) do
        local s, r = pcall(function() return GET:InvokeServer("S_Missions", "Create", {Name = bm, Difficulty = d, Type = "Missions", Objective = "Skirmish"}) end)
        if s and r then Library:Notify({Title="Success", Content="Joined "..d, Duration=3}); task.wait(1); GET:InvokeServer("S_Missions", "Start"); return true end
    end
    return false
end

-- ==========================================
-- [ 4. สร้าง UI Elements ]
-- ==========================================
Tabs.Main:CreateSection("Auto Upgrade")
Tabs.Main:CreateToggle("AutoUpgrade", { Title = "Auto Upgrade Equipment", Default = false })
Tabs.Main:CreateDropdown("UpgradeWeaponType", { Title = "Weapon Type", Values = {"Blades", "Spears", "Both"}, Default = 1 })

Tabs.Main:CreateSection("Auto Farm (Hook Physics)")
Tabs.Main:CreateToggle("OPFarm", { Title = "OP Farm (Sky Nuke)", Default = false })
Tabs.Main:CreateToggle("BossBurst", { Title = "Raid Boss Burst", Default = false })
Tabs.Main:CreateSlider("BurstAmount", { Title = "Burst Hits Amount", Min = 1, Max = 9, Default = 5, Rounding = 0 })

Tabs.Main:CreateToggle("Autofarm", { Title = "Auto Farm (Safe)", Default = false })
Tabs.Main:CreateToggle("EnableAntiCheatActions", { Title = "Anti-Cheat Simulation", Default = false }) 
Tabs.Main:CreateSlider("TargetLimit", { Title = "AoE Target Limit", Min = 1, Max = 10, Default = 5, Rounding = 0 })
Tabs.Main:CreateSlider("AoERadius", { Title = "AoE Radius", Min = 50, Max = 1000, Default = 250, Rounding = 0 })
Tabs.Main:CreateSlider("SlashDelay", { Title = "Slash Delay", Min = 0.1, Max = 2.0, Default = 0.6, Rounding = 1 })

Tabs.Main:CreateSection("Time Guard")
Tabs.Main:CreateToggle("UseMissionTimer", { Title = "Hybrid Time Guard", Default = false })
Tabs.Main:CreateInput("MinMissionTime", { Title = "Min. Mission Time (Seconds)", Default = "60", Numeric = true, Finished = true })
local TimerDisplay = Tabs.Main:CreateParagraph("TimerDisplay", { Title = "Timer Status", Content = "Status: Idle" })

Tabs.Main:CreateSection("Misc")
Tabs.Main:CreateToggle("Noclip", { Title = "Noclip (Phase Through Walls)", Default = true })
Tabs.Main:CreateToggle("OpenPremiumChest", { Title = "Open Premium Chest", Default = false })
Tabs.Main:CreateToggle("AutoRetry", { Title = "Auto Retry", Default = true })
local RunDisplay = Tabs.Main:CreateParagraph("RunDisplay", { Title = "Run Progress", Content = "Current: 0 / Max: 0" })
Tabs.Main:CreateInput("MaxRuns", { Title = "Max Runs (0 = Infinite)", Default = "5", Numeric = true, Finished = true })
Tabs.Main:CreateButton{ Title = "Shadow Ban Check", Callback = function() Library:Notify({ Title = "Shadow Ban Status", Content = Player:GetAttribute("Exploiter") and "⚠️ BANNED" or "✅ SAFE", Duration = 5 }) end }
Tabs.Main:CreateToggle("AutoJoinBoosted", { Title = "Auto Join Boosted Mission", Default = false })
Tabs.Main:CreateToggle("MouseFix", { Title = "Mouse Fix", Default = true })

-- ==========================================
-- [ 5. Hook Physics Engine & Noclip ]
-- ==========================================

-- [ระบบ Noclip]
RunService.Stepped:Connect(function()
    if Options.Noclip.Value then
        if Character then
            for _, part in pairs(Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end
end)

-- Function สั่งบิน
local function hookFlyTo(targetPos)
    if not RootPart then return end
    isFlying = true
    flyTargetPos = targetPos
    lockHeight_Y = nil -- ปลดล๊อคความสูงเมื่อเริ่มบินใหม่
    Humanoid.PlatformStand = true
end

-- Function หยุดบิน
local function stopFlying()
    isFlying = false
    flyTargetPos = nil
    lockHeight_Y = nil
end

-- Loop หลักฟิสิกส์
spawn(function()
    physicsConn = RunService.Heartbeat:Connect(function(dt)
        if not RootPart or not Humanoid then return end
        
        if Options.Autofarm.Value or Options.OPFarm.Value then
            
            -- [สถานะ 1: บินไปเป้าหมาย]
            if isFlying and flyTargetPos then
                local direction = (flyTargetPos - RootPart.Position)
                local dist = direction.Magnitude
                
                -- คำนวณความสูง (Arc)
                local heightBoost = math.clamp(dist / 2, 0, 150) 
                local adjustedTarget = Vector3.new(flyTargetPos.X, flyTargetPos.Y + heightBoost, flyTargetPos.Z)
                
                local targetDir = (adjustedTarget - RootPart.Position).Unit
                local targetSpeed = math.clamp(dist * 5, 50, 300)
                
                local targetVelocity = targetDir * targetSpeed
                RootPart.AssemblyLinearVelocity = RootPart.AssemblyLinearVelocity:Lerp(targetVelocity, 0.2)
                
                -- ถึงเป้าหมาย
                if dist < 10 then
                    isFlying = false
                    flyTargetPos = nil
                    
                    -- [Logic ล๊อคความสูง]
                    if Options.Autofarm.Value then
                         lockHeight_Y = RootPart.Position.Y -- จำความสูงตอนนี้ไว้
                    end
                    
                    RootPart.AssemblyLinearVelocity = RootPart.AssemblyLinearVelocity * 0.3
                    return
                end
                
                local lookTarget = Vector3.new(flyTargetPos.X, RootPart.Position.Y, flyTargetPos.Z)
                RootPart.CFrame = CFrame.lookAt(RootPart.Position, lookTarget)
            
            -- [สถานะ 2: Hover แบบ OP Farm]
            elseif savedHoverY then
                local diffY = savedHoverY - RootPart.Position.Y
                local targetVel = Vector3.new(0, diffY * 50, 0)
                RootPart.AssemblyLinearVelocity = RootPart.AssemblyLinearVelocity:Lerp(targetVel, 0.1)
            
            -- [สถานะ 3: ล๊อคความสูง Normal Farm]
            elseif lockHeight_Y and Options.Autofarm.Value then
                Humanoid.PlatformStand = true
                local diffY = lockHeight_Y - RootPart.Position.Y
                -- ใช้ Velocity เพื่อรักษาตำแหน่งแกน Y และหยุดการเคลื่อนไหวแนวนอน
                local targetVel = Vector3.new(0, diffY * 50, 0)
                RootPart.AssemblyLinearVelocity = RootPart.AssemblyLinearVelocity:Lerp(targetVel, 0.15)
                
            -- [สถานะ 4: ยืนนิ่งๆ]
            elseif not isFlying then
                 if Options.OPFarm.Value then
                    Humanoid.PlatformStand = true
                 else
                    -- ถ้าไม่มี lockHeight จะปิด PlatformStand (แต่ถ้าเปิด Normal Farm ควรจะมี lockHeight เสมอ)
                    if not Options.Autofarm.Value then
                        Humanoid.PlatformStand = false
                    end
                 end
            end
        else
            -- Reset เมื่อปิด Farm
            if isFlying or savedHoverY or lockHeight_Y then
                isFlying = false
                flyTargetPos = nil
                savedHoverY = nil
                lockHeight_Y = nil
                Humanoid.PlatformStand = false
            end
        end
    end)
end)

-- Reset เมื่อตาย
Humanoid.Died:Connect(function()
    stopFlying()
    savedHoverY = nil
    lockHeight_Y = nil
    opFarmInitialized = false
    Character = Player.CharacterAdded:Wait()
    RootPart = Character:WaitForChild("HumanoidRootPart")
    Humanoid = Character:WaitForChild("Humanoid")
end)

spawn(function()
    while task.wait(0.5) do
        local cc, mc = runCounter, tonumber(Options.MaxRuns.Value) or 0
        RunDisplay:SetContent(mc == 0 and string.format("Current: %d / Max: ∞", cc) or string.format("Current: %d / Max: %d", cc, mc))
    end
end)

spawn(function()
    local cl = nil; pcall(function() cl = Player.PlayerGui.Interface.Cursor end)
    while task.wait(0.5) do
        if Options.MouseFix.Value then pcall(function()
            if not cl or not cl.Parent then cl = Player.PlayerGui:FindFirstChild("Interface"):FindFirstChild("Cursor") end
            if cl then cl.Visible = false end
            UserInputService.MouseIconEnabled = true
        end) end
    end
end)

spawn(function()
    while task.wait(2) do
        if Workspace:GetAttribute("Map") == "Lobby" then
            if runCounter ~= 0 then runCounter = 0; saveRunCount() end
            if Options.AutoUpgrade.Value then
                local sl = {}
                local st = Options.UpgradeWeaponType.Value
                if st == "Blades" or st == "Both" then for _, s in pairs(UPGRADE_STATS.Blades) do table.insert(sl, s) end end
                if st == "Spears" or st == "Both" then for _, s in pairs(UPGRADE_STATS.Spears) do table.insert(sl, s) end end
                repeat local sc = 0; for _, sn in pairs(sl) do local s, r = pcall(function() return GET:InvokeServer("S_Equipment", "Upgrade", {sn}) end); if s and r then sc = sc+1; task.wait(0.3) else task.wait(0.1) end end; if sc == 0 then break end; task.wait(1) until false
            end
            if Options.AutoJoinBoosted.Value and tick() - lastJoinAttempt > 5 then lastJoinAttempt = tick(); joinBoostedMission() end
        end
    end
end)

spawn(monitorRaidBosses)

spawn(function()
    while task.wait(0.1) do
        if not Options.Autofarm.Value and not Options.OPFarm.Value then 
            stopFlying()
            savedHoverY = nil
            lockHeight_Y = nil
            opFarmInitialized = false; Humanoid.PlatformStand = false; farmingStarted = false
            continue 
        end

        local bt = getAvailableBossWeakPoint()
        local ac = getAliveTitanCount()
        local ck = true
        if Options.UseMissionTimer.Value and ac <= LAST_TITAN_THRESHOLD then
            local mt = tonumber(Options.MinMissionTime.Value) or 60
            if not farmingStarted then farmingStarted = true; fallbackStartTime = tick() end
            ck = (Workspace:GetAttribute("Seconds") or (tick() - fallbackStartTime)) >= mt
        end

        if Options.OPFarm.Value and Workspace:GetAttribute("Map") ~= "Lobby" then
            lockHeight_Y = nil -- ปิดล๊อคความสูงแบบ Normal
            stopFlying() 
            Humanoid.PlatformStand = true
            local ap = getRaidAnchorPos()
            
            if not opFarmInitialized then
                savedHoverY = (ap and (ap.Y + FLY_OFFSET)) or OP_FLY_HEIGHT + math.random(-5, 5)
                opFarmInitialized = true
            end
            
            if isBladeEmpty() then safeRefillBlades(); task.wait(1); continue end

            if isAnchorPhaseActive() and ap then
                local targetFlat = Vector3.new(ap.X, savedHoverY, ap.Z)
                if (RootPart.Position - targetFlat).Magnitude > 20 then
                     local dir = (targetFlat - RootPart.Position).Unit
                     RootPart.AssemblyLinearVelocity = Vector3.new(dir.X * 100, 0, dir.Z * 100)
                else
                     RootPart.AssemblyLinearVelocity = Vector3.new(0,0,0) 
                end
                
                local nt = getTargetsNearAnchor(Options.TargetLimit.Value, Options.AoERadius.Value)
                if #nt > 0 and ck then executeStealthSlash(nt, true) end
            else
                if bt then executeBossBurst(bt, Options.BurstAmount.Value)
                else
                    local at = getAllTargets(); local lt = {}; for i = 1, math.min(#at, OP_MAX_TARGETS) do table.insert(lt, at[i]) end
                    if #lt > 0 and ck then executeStealthSlash(lt, true) end
                end
            end
            task.wait(1); continue 
        end

        if Options.Autofarm.Value then
            savedHoverY = nil -- ปิด Hover แบบ OP
            opFarmInitialized = false
            
            if isBladeEmpty() then safeRefillBlades(); task.wait(1); continue end
            
            if isAnchorPhaseActive() then
                local ap = getRaidAnchorPos()
                if ap then
                    if (RootPart.Position - ap).Magnitude > 40 then 
                        hookFlyTo(ap) 
                        while isFlying do task.wait(0.05) end 
                    end
                    local nt = getTargetsNearAnchor(Options.TargetLimit.Value, Options.AoERadius.Value)
                    if #nt > 0 then
                        if ck then executeStealthSlash(nt, false) end
                        task.wait(math.max(0.1, Options.SlashDelay.Value + math.random(-0.1, 0.2)))
                    else task.wait(0.5) end
                    continue 
                end
            end
            
            if bt then
                hookFlyTo(bt.Position)
                while isFlying do task.wait(0.05) end
                if ck then executeBossBurst(bt, Options.BurstAmount.Value) end
                task.wait(math.max(0.1, Options.SlashDelay.Value + math.random(-0.1, 0.2)))
            else
                local t, ap = getTargetCluster(Options.TargetLimit.Value, Options.AoERadius.Value)
                if #t > 0 and ap then
                    hookFlyTo(ap)
                    while isFlying do task.wait(0.05) end
                    if ck then executeStealthSlash(t, false) end
                    task.wait(math.max(0.1, Options.SlashDelay.Value + math.random(-0.1, 0.2)))
                else task.wait(0.5) end
            end
        end
    end
end)

spawn(function()
    while task.wait(0.1) do
        if Options.UseMissionTimer.Value then
            local rem = (tonumber(Options.MinMissionTime.Value) or 60) - (Workspace:GetAttribute("Seconds") or (tick() - fallbackStartTime))
            TimerDisplay:SetContent(rem > 0 and string.format("%02d:%02d", math.floor(rem / 60), math.floor(rem % 60)) or "Ready!")
        else TimerDisplay:SetContent("--:--") end
    end
end)

if ButtonsFolder then
    ButtonsFolder.ChildAdded:Connect(function(btn)
        if Options.Autofarm.Value or Options.OPFarm.Value then
            stopFlying()
            lockHeight_Y = nil
            opFarmInitialized = false
            task.wait(0.15); POST:FireServer("Attacks", "Slash_Escape"); btn:Destroy(); task.wait(0.3)
            local bt = getAvailableBossWeakPoint()
            if Options.OPFarm.Value then
                if bt then executeBossBurst(bt, Options.BurstAmount.Value)
                else local t = getAllTargets(); local l = {}; for i=1, math.min(#t, OP_MAX_TARGETS) do table.insert(l, t[i]) end; if #l>0 then executeStealthSlash(l, true) end end
            else
                if bt then executeBossBurst(bt, Options.BurstAmount.Value)
                else local t, _ = getTargetCluster(Options.TargetLimit.Value, Options.AoERadius.Value); if #t>0 then executeStealthSlash(t, false) end end
            end
        end
    end)
end

spawn(function()
    local ms = false 
    while task.wait(2) do
        if not Options.AutoRetry.Value then continue end
        if not ms and getAliveTitanCount() > 0 then ms = true end
        local sp = false
        if ms and Workspace:GetAttribute("Map") ~= "Lobby" then
            sp = isRaidMap and isRaidCompleted() or getAliveTitanCount() == 0
        end
        if sp then
            runCounter = runCounter + 1; saveRunCount()
            local mr = tonumber(Options.MaxRuns.Value) or 0
            if mr > 0 and runCounter >= mr then
                pcall(function() POST:FireServer("Functions", "Teleport") end); runCounter = 0; ms = false; task.wait(10)
            else
                if isRaidMap then openRaidChests(); task.wait(1.5) end
                ms = false; pcall(function() GET:InvokeServer("Functions", "Retry", "Add") end); farmingStarted = false; task.wait(6)
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
Library:Notify({Title="Loaded", Content="Height Lock System Enabled", Duration=5})
SaveManager:LoadAutoloadConfig()