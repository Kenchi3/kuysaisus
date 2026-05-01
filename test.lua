-- ==========================================
-- [ 1. โหลด Fluent UI Library ]
-- ==========================================
local Library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
local SaveManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"))()

local Window = Library:CreateWindow{
    Title = "Titan Hub",
    SubTitle = "BodyMovers + Noclip + Raid",
    TabWidth = 160,
    Size = UDim2.fromOffset(600, 450),
    Acrylic = true, 
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
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

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local RootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

-- Path ของเกม
local Remotes = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local POST = Remotes:WaitForChild("POST")
local GET = Remotes:WaitForChild("GET")
local TitansFolder = Workspace:FindFirstChild("Titans")
local ButtonsFolder = Player:FindFirstChild("PlayerGui"):WaitForChild("Interface"):FindFirstChild("Buttons")

-- [ระบบ Raid]
local PlaceId = game.PlaceId
local isRaidMap = (PlaceId == 14012874501 or PlaceId == 13379349730)

-- 🔥 [เปลี่ยนแปลง] เก็บจุดอ่อนของ Raid Boss เป็นตาราง รองรับหลายตัว
local RaidBossWeakPoints = {} 

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
local FLY_OFFSET = 100        
local FAKE_VELOCITY = 220

local NoclipConnection = nil


local function flyToTarget(targetPos)
    if not RootPart then return end
    
    -- ตั้งค่า Tween (ปรับ EasingStyle ให้เป็น Quart/Expo เพื่อความเนียนแบบเหวี่ยง)
    local distance = (RootPart.Position - targetPos).Magnitude
    local speed = 200 -- ความเร็ว (Studs per second)
    local timeToFly = distance / speed
    
    local goalPos = targetPos + Vector3.new(0, FLY_OFFSET, 0)
    
    local TweenInfo = TweenInfo.new(
        timeToFly, 
        Enum.EasingStyle.Quart, -- Quint, Quart หรือ Expo ดูเนียนมากสำหรับการพุ่ง
        Enum.EasingDirection.Out -- ช้าลงตอนถึงเป้าหมาย
    )
    
    local Goal = {CFrame = CFrame.new(goalPos)}
    local Tween = TweenService:Create(RootPart, TweenInfo, Goal)
    
    -- เตรียมตัวละคร
    RootPart.Anchored = false
    Humanoid.PlatformStand = true
    RootPart.AssemblyLinearVelocity = Vector3.new(0,0,0) -- ล้างแรงเฉื่อย
    
    Tween:Play()
    Tween.Completed:Wait() -- รอจนกว่าจะพุ่งถึง
    
    -- ถึงแล้ว (สามารถเปลี่ยนเป็น Anchored หรือใช้ AlignPosition รั้งไว้กลางอากาศได้)
    RootPart.Anchored = true 
    Humanoid.PlatformStand = false
end

local function findNearestStation()
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name:find("Refill") or obj.Name:find("Station") then
            if obj:IsA("Model") or obj:IsA("BasePart") then return obj end
        end
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

local function normal_reload()
    pcall(function() GET:InvokeServer("Blades", "Reload") end)
    task.wait(0.5)
end

local function fullreload()
    local station = findNearestStation()
    if station then
        pcall(function() POST:FireServer("Attacks", "Reload", station) end)
    end
    task.wait(0.5)
end

local function refillBlades()
    if hasSpareBlades() then normal_reload() else fullreload() end
end

local function isBladeEmpty()
    local rig = Character:FindFirstChild("Rig_" .. Player.Name)
    if rig and rig:FindFirstChild("LeftHand") then
        local blade = rig.LeftHand:FindFirstChild("Blade_1")
        if not blade or blade.Transparency == 1 then return true end
    end
    return false
end

-- 🔥 [เปลี่ยนแปลง] ระบบ Monitor รองรับการติดตามหลาย Boss
local function trackBossWeakPoint(bossModel)
    if not bossModel then return end
    
    local marker = bossModel:FindFirstChild("Marker") or bossModel:WaitForChild("Marker", 30)
    if not marker then return end

    -- บันทึกจุดอ่อนปัจจุบันของบอสตัวนี้
    RaidBossWeakPoints[bossModel.Name] = marker.Adornee

    -- ติดตามเมื่อจุดอ่อนเปลี่ยน
    marker:GetPropertyChangedSignal("Adornee"):Connect(function()
        RaidBossWeakPoints[bossModel.Name] = marker.Adornee
    end)

    -- ล้างข้อมูลเมื่อบอสตาย
    local hum = bossModel:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Died:Connect(function()
            RaidBossWeakPoints[bossModel.Name] = nil
        end)
    end
end

local function monitorRaidBosses()
    if not isRaidMap then return end
    
    -- แยก Thread ติดตาม Attack_Titan
    task.spawn(function()
        local success, attackTitan = pcall(function()
            return TitansFolder:WaitForChild("Attack_Titan", 300)
        end)
        if success and attackTitan then 
            trackBossWeakPoint(attackTitan) 
        end
    end)

    -- แยก Thread ติดตาม Armored_Titan
    task.spawn(function()
        local success, armoredTitan = pcall(function()
            return TitansFolder:WaitForChild("Armored_Titan", 300)
        end)
        if success and armoredTitan then 
            trackBossWeakPoint(armoredTitan) 
        end
    end)
end

local function getTargetCluster(maxCount, radius)
    local closestPart = nil
    local minDistance = math.huge
    
    if not TitansFolder then return {}, nil end

    local anchorPosition = RootPart.Position
    if isRaidMap then
        local atPos = getRaidAnchorPos()
        if atPos then
            anchorPosition = atPos
        end
    end

    for _, titan in ipairs(TitansFolder:GetChildren()) do
        if titan:IsA("Model") then
            local hum = titan:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and titan:FindFirstChild("Hitboxes") then
                local targetPart = nil
                
                -- 🔥 [เปลี่ยนแปลง] เช็คว่าเป็น Raid Boss ที่มีจุดอ่อนโผล่มาไหม
                if isRaidMap and RaidBossWeakPoints[titan.Name] then
                    targetPart = RaidBossWeakPoints[titan.Name]
                else
                    local hitFolder = titan.Hitboxes:FindFirstChild("Hit")
                    if hitFolder then
                        targetPart = hitFolder:FindFirstChild("Nape")
                    end
                end

                if targetPart then
                    local dist = (anchorPosition - targetPart.Position).Magnitude
                    if dist < minDistance then
                        minDistance = dist
                        closestPart = targetPart
                    end
                end
            end
        end
    end

    if not closestPart then return {}, nil end

    local targetsToHit = {}
    for _, titan in ipairs(TitansFolder:GetChildren()) do
        if titan:IsA("Model") then
            local hum = titan:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and titan:FindFirstChild("Hitboxes") then
                local targetPart = nil
                
                -- 🔥 [เปลี่ยนแปลง] เช็คว่าเป็น Raid Boss ที่มีจุดอ่อนโผล่มาไหม
                if isRaidMap and RaidBossWeakPoints[titan.Name] then
                    targetPart = RaidBossWeakPoints[titan.Name]
                else
                    local hitFolder = titan.Hitboxes:FindFirstChild("Hit")
                    if hitFolder then
                        targetPart = hitFolder:FindFirstChild("Nape")
                    end
                end

                if targetPart then
                    local distToMainTarget = (targetPart.Position - closestPart.Position).Magnitude
                    if distToMainTarget <= radius then
                        table.insert(targetsToHit, targetPart)
                    end
                end
            end
        end
    end

    table.sort(targetsToHit, function(a, b)
        return (a.Position - closestPart.Position).Magnitude < (b.Position - closestPart.Position).Magnitude
    end)

    local limitedTargets = {}
    for i = 1, math.min(#targetsToHit, maxCount) do
        table.insert(limitedTargets, targetsToHit[i])
    end

    return limitedTargets, closestPart.Position
end

local function executeMultiSlash(napesArray)
    if #napesArray == 0 then return false end
    POST:FireServer("Attacks", "Slash", true)
    task.wait(0.05)
    for _, napePart in ipairs(napesArray) do
        if napePart and napePart.Parent then
            task.spawn(function()
                pcall(function()
                    GET:InvokeServer("Hitboxes", "Register", napePart, FAKE_VELOCITY, math.random(10, 100))
                end)
            end)
        end
    end
    return true
end

local function selectAndPressEnter(button)
    if button and button:IsA("GuiButton") then
        GuiService.SelectedObject = button
        task.wait(0.3)
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        task.wait(0.1)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        task.wait(0.2)
        GuiService.SelectedObject = nil
    end
end

local function openRaidChests()
    local chestsGui = Player.PlayerGui:FindFirstChild("Interface") and Player.PlayerGui.Interface:FindFirstChild("Chests")
    if not chestsGui or not chestsGui.Visible then return false end
    
    local freeBtn = chestsGui:FindFirstChild("Free")
    local timeout = 0
    while not freeBtn and timeout < 15 do
        task.wait(1)
        timeout = timeout + 1
        freeBtn = chestsGui:FindFirstChild("Free")
    end
    
    if freeBtn then
        selectAndPressEnter(freeBtn)
        task.wait(1.5)
    end
    
    local premiumBtn = chestsGui:FindFirstChild("Premium")
    if premiumBtn and Options.OpenPremiumChest.Value then
        selectAndPressEnter(premiumBtn)
        task.wait(1.5)
    end
    
    local finishBtn = chestsGui:FindFirstChild("Finish")
    if finishBtn then
        selectAndPressEnter(finishBtn)
        task.wait(1)
        return true
    end
    
    return false
end

local function isRaidCompleted()
    local interface = Player.PlayerGui:FindFirstChild("Interface")
    if not interface then return false end
    
    local chests = interface:FindFirstChild("Chests")
    local rewards = interface:FindFirstChild("Rewards")
    
    if chests and chests.Visible then return true end
    if rewards and rewards.Visible then return true end
    
    return false
end

-- ==========================================
-- [ 4. สร้าง UI Elements ]
-- ==========================================
Tabs.Main:CreateToggle("Autofarm", {
    Title = "Auto Farm (BodyMovers)",
    Description = "Auto enables Noclip & Skip while farming.",
    Default = false,
    Callback = function() end
})

Tabs.Main:CreateSlider("TargetLimit", {
    Title = "Target Limit",
    Min = 1, Max = 10, Default = 3, Rounding = 0
})

Tabs.Main:CreateSlider("AoERadius", {
    Title = "AoE Radius (Slash Range)",
    Min = 50, Max = 1000, Default = 200, Rounding = 0
})

Tabs.Main:CreateSlider("SlashDelay", {
    Title = "Slash Delay",
    Min = 0.1, Max = 2.0, Default = 0.6, Rounding = 1
})

Tabs.Main:CreateToggle("OpenPremiumChest", {
    Title = "Open Premium Chest",
    Default = false,
    Callback = function() end
})

Tabs.Main:CreateToggle("AutoRetry", {
    Title = "Auto Retry",
    Default = false,
    Callback = function() end
})

-- ==========================================
-- [ 5. Threads ]
-- ==========================================
spawn(function()
    setupMovers()
    -- เปลี่ยนมาเรียกฟังก์ชันที่รองรับหลายบอส
    spawn(monitorRaidBosses)
    
    while task.wait(0.1) do
        if Humanoid.Health <= 0 then
            Character = Player.Character or Player.CharacterAdded:Wait()
            RootPart = Character:WaitForChild("HumanoidRootPart")
            Humanoid = Character:WaitForChild("Humanoid")
            setupMovers()
            task.wait(2)
        end

        if not Options.Autofarm.Value then 
            Humanoid.PlatformStand = false
            RootPart.Anchored = false
            if BodyPos then BodyPos.MaxForce = Vector3.new(0,0,0) end
            if BodyGyro then BodyGyro.MaxTorque = Vector3.new(0,0,0) end
            if NoclipConnection then
                NoclipConnection:Disconnect()
                NoclipConnection = nil
                if Character then
                    for _, part in pairs(Character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = true
                        end
                    end
                end
            end
            continue 
        end

        local success, skipGui = pcall(function()
            return Player.PlayerGui.Interface.Skip
        end)

        if success and skipGui and skipGui.Visible then
            local interactBtn = skipGui:FindFirstChild("Interact")
            
            if interactBtn and interactBtn:IsA("GuiButton") then
                pcall(function()
                    GuiService.SelectedObject = interactBtn
                    task.wait(0.1)
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
                    task.wait(0.05)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
                    task.wait(0.1)
                    GuiService.SelectedObject = nil
                end)
                
                task.wait(0.5)
            end
        end

        if not NoclipConnection then
            NoclipConnection = RunService.Stepped:Connect(function()
                if Character then
                    for _, part in pairs(Character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end)
        end

        if isBladeEmpty() then
            refillBlades()
            task.wait(0.5)
        end

        local limit = Options.TargetLimit.Value
        local radius = Options.AoERadius.Value
        local delay = Options.SlashDelay.Value

        local targets, anchorPos = getTargetCluster(limit, radius)

        if #targets > 0 and anchorPos then
            flyToTarget(anchorPos)
            executeMultiSlash(targets)
            task.wait(delay)
        else
            task.wait()
        end
    end
end)
if ButtonsFolder then
    ButtonsFolder.ChildAdded:Connect(function(btn)
        if Options.Autofarm.Value then
            RootPart.Anchored = false
            if BodyPos then BodyPos.MaxForce = Vector3.new(0,0,0) end
            task.wait(0.15)
            POST:FireServer("Attacks", "Slash_Escape")
            btn:Destroy()
            task.wait(0.3)
            local targets, _ = getTargetCluster(1, 50)
            if #targets > 0 then
                executeMultiSlash(targets)
            end
        end
    end)
end
-- Thread: Auto Retry & Open Chests
spawn(function()
    while task.wait(1) do
        if not Options.AutoRetry.Value then continue end

        if isRaidMap then
            if isRaidCompleted() then
                openRaidChests()
                task.wait(1.5)
                pcall(function() GET:InvokeServer("Functions", "Retry", "Add") end)
                task.wait(3)
            end
        else
            local aliveTitans = 0
            if TitansFolder then
                for _, titan in ipairs(TitansFolder:GetChildren()) do
                    if titan:IsA("Model") and titan:FindFirstChildOfClass("Humanoid") and titan.Humanoid.Health > 0 then
                        aliveTitans = aliveTitans + 1
                    end
                end
            end

            if aliveTitans == 0 then
                pcall(function() GET:InvokeServer("Functions", "Retry", "Add") end)
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

local function getAutoSaveFile()
    return "autosave_" .. tostring(Player.Name) .. "_" .. tostring(game.PlaceId)
end

task.spawn(function()
    local autosaveName = getAutoSaveFile()
    local autosaveFile = SaveManager.Folder .. "/settings/" .. autosaveName .. ".json"

    if isfile(autosaveFile) then
        local success = SaveManager:Load(autosaveName)
        if success then
            Library:Notify({
                Title    = "Config",
                Content  = "Auto-loaded",
                Duration = 3,
            })
        end
    end
end)

local function autoSave()
    SaveManager:Save(getAutoSaveFile())
end

for _, option in pairs(Options) do
    if option.OnChanged then
        option:OnChanged(autoSave)
    end
end

Window:SelectTab(1)
Library:Notify({Title="Loaded", Content="Auto Farm Ready 🔥", Duration=5})
SaveManager:LoadAutoloadConfig()
