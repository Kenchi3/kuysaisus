-- ==========================================
-- [ 1. โหลด Fluent UI Library ]
-- ==========================================
local Library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
local SaveManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"))()

local Window = Library:CreateWindow{
    Title = "Klakuylek Hub",
    SubTitle = "Hook Physics v4 (Safe Above Head)",
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
local PostRemote = Remotes:WaitForChild("POST")
local GetRemote = Remotes:WaitForChild("GET")
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
local lockHeight_Y = nil
local SAFE_FARM_HOVER_HEIGHT = 15 -- ความสูงเหนือหัวไททัน

local runCountFile = "NonnyHub/game/runcount_" .. Player.Name .. "_" .. tostring(game.GameId) .. ".json"

-- [Function: Save/Load Run Count]
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
-- [ Identity Protection / Caller Spoofing ]
-- ==========================================

-- 1. เลือกสคริปต์ของเกมที่ปลอดภัย เพื่อเอาไว้ "อ้างอิงตัวตน"
-- แนะนำให้ใช้สคริปต์ที่อยู่ใน PlayerScripts หรือ ReplicatedStorage ที่มักจะเรียก Remote อยู่แล้ว
local FakeCallerScript = nil
pcall(function()
    -- พยายามหาสคริปต์ของเกมที่ขื่อว่า CombatFramework หรืออะไรก็ตามที่มีอยู่จริงในเกม
    FakeCallerScript = game.Players.LocalPlayer.PlayerScripts:FindFirstChildWhichIsA("LocalScript", true)
    if not FakeCallerScript then
        FakeCallerScript = game.ReplicatedStorage:FindFirstChildWhichIsA("LocalScript", true)
    end
end)

-- 2. ดัก (Hook) ฟังก์ชัน getcallingscript เพื่อปลอมตัวตน
local OriginalGetCallingScript = getcallingscript
if OriginalGetCallingScript then
    hookfunction(getcallingscript, newcclosure(function()
        -- เมื่อเซิร์ฟเวอร์ถามว่าใครเรียกมา ให้ตอบว่าเป็นสคริปต์ของเกมเอง
        if FakeCallerScript then
            return FakeCallerScript
        end
        -- ถ้าหาไม่เจอ ให้ทำงานปกติ
        return OriginalGetCallingScript()
    end))
end

-- 3. ดัก (Hook) __namecall เพื่อซ่อนรอยเมื่อมีการเรียก FireServer / InvokeServer
local OldNamecall
OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    
    -- ตรวจสอบว่าเป็นการส่งข้อมูลเข้าเซิร์ฟเวอร์หรือไม่
    if method == "FireServer" or method == "InvokeServer" then
        -- [จุดนี้แหละที่เราจะใส่ระบบป้องกันเพิ่มเติม]
        -- บางเกมเช็ค stack trace (ประวัติการเรียกฟังก์ชัน) 
        -- newcclosure ช่วยซ่อนว่ามาจาก exploit แล้ว, hook getcallingscript ช่วยปลอมตัวตนแล้ว
    end
    
    return OldNamecall(self, ...)
end))

-- 4. ป้องกันการถูกตรวจจับย้อนกลับ (Anti-Detection)
-- ซ่อนคำสั่ง hook ต่างๆ เพื่อไม่ให้เกมสแกนเจอ
local mt = getrawmetatable(game)
if mt and setreadonly then
    setreadonly(mt, false)
    -- ปลอมแปลงฟังก์ชันที่เกมมักใช้ตรวจสอบว่ามีการ Hook เกิดขึ้นหรือไม่
    local oldNamecallCheck = mt.__namecall
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" or method == "InvokeServer" then
            -- เซิร์ฟเวอร์อาจจะส่งค่าหลอกมาเช็ค แต่เราจะปล่อยผ่านไปปกติ
        end
        return oldNamecallCheck(self, ...)
    end)
    setreadonly(mt, true)
end

print("[Protection] Identity Spoofing Active.")

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
    if hasSpareBlades() then pcall(function() GetRemote:InvokeServer("Blades", "Reload") end)
    else local s = findNearestStation(); if s then pcall(function() PostRemote:FireServer("Attacks", "Reload", s) end) end end
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

    pcall(function() PostRemote:FireServer("Attacks", "Slash", true) end)
    for i, napePart in ipairs(napesArray) do
        if napePart and napePart.Parent then
            task.spawn(function()
                pcall(function() GetRemote:InvokeServer("Hitboxes", "Register", napePart, math.random(180, 260), math.random(10, 100)) end)
            end)
        end
    end
    
    if isOP or Options.Autofarm.Value then -- ให้ Normal Farm ก็ PlatformStand หลังฟันเพื่อลอยตัวต่อ
        Humanoid.PlatformStand = true
    end
    return true
end

local function executeBossBurst(bossPart, burstAmount)
    if not bossPart then return false end
    for i = 1, burstAmount do
        Humanoid.PlatformStand = false
        pcall(function() PostRemote:FireServer("Attacks", "Slash", true) end)
        pcall(function() GetRemote:InvokeServer("Hitboxes", "Register", bossPart, math.random(180, 260), math.random(10, 100)) end)
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
        local s, r = pcall(function() return GetRemote:InvokeServer("S_Missions", "Create", {Name = bm, Difficulty = d, Type = "Missions", Objective = "Skirmish"}) end)
        if s and r then Library:Notify({Title="Success", Content="Joined "..d, Duration=3}); task.wait(1); GetRemote:InvokeServer("S_Missions", "Start"); return true end
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
Tabs.Main:CreateToggle("UseMissionTimer", { Title = "Hybrid Time Guard", Default = true })
Tabs.Main:CreateInput("MinMissionTime", { Title = "Min. Mission Time (Seconds)", Default = "33", Numeric = true, Finished = true })
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
-- [ 5. Hook Physics Engine v5 (Force-Based Fly) ]
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

-- [ตัวแปรระบบบิน]
local flyForce = nil
local flyAttachment = nil

-- Function สร้างระบบแรงดัน (ย้ายไปไว้ตรงนี้เพื่อความเสถียร)
local function setupFlyPhysics()
    if not RootPart then return end
    -- ลบของเก่าทิ้งก่อน (ป้องกันรั่ว)
    if flyForce then flyForce:Destroy() end
    if flyAttachment then flyAttachment:Destroy() end

    flyAttachment = Instance.new("Attachment")
    flyAttachment.Name = "FlyAttachment"
    flyAttachment.Parent = RootPart

    flyForce = Instance.new("VectorForce")
    flyForce.Name = "FlyVectorForce"
    flyForce.Attachment0 = flyAttachment
    flyForce.RelativeTo = Enum.ActuatorRelativeTo.World -- ใช้พิกัดโลก
    flyForce.Enabled = false
    flyForce.Parent = RootPart
end

setupFlyPhysics()

-- Function สั่งบิน
local function hookFlyTo(targetPos)
    if not RootPart then return end
    isFlying = true
    flyTargetPos = targetPos
    lockHeight_Y = nil 
    if flyForce then flyForce.Enabled = true end
    -- เปลี่ยนจาก PlatformStand เป็นการจำลองสถานะตกหลุ่น (ปลอดภัยกว่าแบบเดิม)
    Humanoid:ChangeState(Enum.HumanoidStateType.Freefall) 
end

-- Function หยุดบิน
local function stopFlying()
    isFlying = false
    flyTargetPos = nil
    lockHeight_Y = nil
    if flyForce then flyForce.Enabled = false end
end

-- Loop หลักฟิสิกส์ (ใช้ระบบ P-Controller คำนวณแรง)
spawn(function()
    physicsConn = RunService.Heartbeat:Connect(function(dt)
        if not RootPart or not Humanoid or not flyForce then return end
        
        if Options.Autofarm.Value or Options.OPFarm.Value then
            
            local mass = RootPart.AssemblyMass
            local gravity = workspace.Gravity
            
            -- [สถานะ 1: บินไปเป้าหมายแบบใช้แรงดัน (Force-Based Approach)]
            if isFlying and flyTargetPos then
                flyForce.Enabled = true
                
                local finalTarget = flyTargetPos
                if Options.Autofarm.Value then
                    finalTarget = flyTargetPos + Vector3.new(0, SAFE_FARM_HOVER_HEIGHT, 0)
                end
                
                local direction = (finalTarget - RootPart.Position)
                local distToFinal = direction.Magnitude
                
                -- คำนวณความเร็วเป้าหมาย (Smooth Deceleration)
                local speedFactor = math.clamp((distToFinal / 80) * 150, 15, 150)
                local targetVelocity = direction.Unit * speedFactor
                
                -- คำนวณแรงที่ต้องใส่ (F = m*a) 
                -- 1. แรงถ่วงดึงลง (ต้องชดเชย)
                local counterGravityForce = Vector3.new(0, mass * gravity, 0)
                -- 2. แรงขับเคลื่อนไปข้างหน้า (P-Controller: ยิ่งห่างจากความเร็วเป้าหมาย ยิ่งอัดแรง)
                local currentVelocity = RootPart.AssemblyLinearVelocity
                local driveForce = (targetVelocity - currentVelocity) * mass * 10 
                
                -- รวมแรง
                flyForce.Force = counterGravityForce + driveForce
                
                -- หันหน้าไปทางเป้าหมาย
                local lookTarget = Vector3.new(flyTargetPos.X, RootPart.Position.Y, flyTargetPos.Z)
                if (RootPart.Position - lookTarget).Magnitude > 1 then
                    RootPart.CFrame = CFrame.lookAt(RootPart.Position, lookTarget)
                end
                
                -- ถึงเป้าหมาย (รัศมี 5 หน่วย)
                if distToFinal < 5 then
                    isFlying = false
                    flyTargetPos = nil
                    if Options.Autofarm.Value then
                        lockHeight_Y = RootPart.Position.Y 
                    end
                    return
                end
            
            -- [สถานะ 2: Hover แบบ OP Farm หรือ ล๊อคความสูง Normal Farm]
            elseif lockHeight_Y or savedHoverY then
                flyForce.Enabled = true
                Humanoid.PlatformStand = Options.OPFarm.Value -- ให้ OPFarm นอนได้ แต่ Normal Farm ยืนตรง
                
                local targetY = savedHoverY or lockHeight_Y
                local diffY = targetY - RootPart.Position.Y
                local currentVelocityY = RootPart.AssemblyLinearVelocity.Y
                
                -- ชดเชยแรงโน้มถ่วง + อัดแรงแกน Y เพื่อลอยนิ่งๆ (P-Controller แกน Y)
                local counterGravityForce = Vector3.new(0, mass * gravity, 0)
                local hoverForceY = (diffY - currentVelocityY) * mass * 15
                
                -- ห้ามเลื่อนแกน X, Z (เบรคแนวราบ)
                local brakeForceX = -RootPart.AssemblyLinearVelocity.X * mass * 10
                local brakeForceZ = -RootPart.AssemblyLinearVelocity.Z * mass * 10
                
                flyForce.Force = counterGravityForce + Vector3.new(brakeForceX, hoverForceY, brakeForceZ)
                
            -- [สถานะ 3: ยืนนิ่งๆ]
            elseif not isFlying then
                flyForce.Enabled = false
                if not Options.OPFarm.Value and not Options.Autofarm.Value then
                    Humanoid.PlatformStand = false
                end
            end
        else
            -- Reset เมื่อปิด Farm
            if isFlying or savedHoverY or lockHeight_Y then
                stopFlying()
                savedHoverY = nil
                lockHeight_Y = nil
                Humanoid.PlatformStand = false
            end
        end
    end)
end)

-- Reset เมื่อตาย (ต้องสร้าง Attachment และ Force ใหม่)
Humanoid.Died:Connect(function()
    stopFlying()
    savedHoverY = nil
    lockHeight_Y = nil
    opFarmInitialized = false
    Character = Player.CharacterAdded:Wait()
    RootPart = Character:WaitForChild("HumanoidRootPart")
    Humanoid = Character:WaitForChild("Humanoid")
    setupFlyPhysics() -- <-- สร้างระบบฟิสิกส์ใหม่ให้ตัวละครใหม่
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
                repeat local sc = 0; for _, sn in pairs(sl) do local s, r = pcall(function() return GetRemote:InvokeServer("S_Equipment", "Upgrade", {sn}) end); if s and r then sc = sc+1; task.wait(0.3) else task.wait(0.1) end end; if sc == 0 then break end; task.wait(1) until false
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
            lockHeight_Y = nil 
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
            savedHoverY = nil 
            opFarmInitialized = false
            
            if isBladeEmpty() then safeRefillBlades(); task.wait(1); continue end
            
            if isAnchorPhaseActive() then
                local ap = getRaidAnchorPos()
                if ap then
                    if (RootPart.Position - ap).Magnitude > 40 then 
                        hookFlyTo(ap) 
                    end
                    local nt = getTargetsNearAnchor(Options.TargetLimit.Value, Options.AoERadius.Value)
                    if #nt > 0 then
                        if ck then executeStealthSlash(nt, false) end
                        task.wait(math.max(0.1, Options.SlashDelay.Value))
                    else task.wait(0.5) end
                    continue 
                end
            end
            
            if bt then
                -- [ปรับปรุง] ไม่ต้องรอให้บินไปถึงแล้วหยุดนิ่ง ขอแค่เข้าใกล้พอก็ฟันได้เลย
                local distToBoss = (RootPart.Position - bt.Position).Magnitude
                if distToBoss > 25 then 
                    hookFlyTo(bt.Position)
                else
                    -- เข้าใกล้แล้ว ให้ระบบ Hover จับตำแหน่งเอง แล้วเราฟันทิ้งไปพร้อมกัน
                    lockHeight_Y = RootPart.Position.Y
                    if ck then executeBossBurst(bt, Options.BurstAmount.Value) end
                    task.wait(math.max(0.1, Options.SlashDelay.Value))
                end
            else
                local t, ap = getTargetCluster(Options.TargetLimit.Value, Options.AoERadius.Value)
                if #t > 0 and ap then
                    -- [ปรับปรุง] คำนวณระยะห่างจากก้อนศัตรู
                    local distToCluster = (RootPart.Position - ap).Magnitude
                    if distToCluster > 25 then
                        hookFlyTo(ap)
                    else
                        -- อยู่ในระยะพอสมควรแล้ว ล็อคความสูงแล้วฟันไปพร้อมๆ กับที่ตัวละครกำลังเบรคลอยนิ่ง
                        lockHeight_Y = RootPart.Position.Y
                        if ck then executeStealthSlash(t, false) end
                        task.wait(math.max(0.1, Options.SlashDelay.Value))
                    end
                else 
                    task.wait(0.5) 
                end
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
            task.wait(0.15); PostRemote:FireServer("Attacks", "Slash_Escape"); btn:Destroy(); task.wait(0.3)
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
                pcall(function() PostRemote:FireServer("Functions", "Teleport") end); runCounter = 0; ms = false; task.wait(10)
            else
                if isRaidMap then openRaidChests(); task.wait(1.5) end
                ms = false; pcall(function() GetRemote:InvokeServer("Functions", "Retry", "Add") end); farmingStarted = false; task.wait(6)
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
Library:Notify({Title="Loaded", Content="Safe Farm: Above Head Mode Enabled", Duration=5})
SaveManager:LoadAutoloadConfig()