-- ==========================================
-- [ 1. โหลด Fluent UI Library ]
-- ==========================================
local Library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
local SaveManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"))()

local WindowTitle = "Klakuylek Hub - Auto Farm"

local Window = Library:CreateWindow{
    Title = WindowTitle,
    SubTitle = "by nxnn_nn",
    TabWidth = 160,
    Size = UDim2.fromOffset(830, 525),
    Resize = true,
    MinSize = Vector2.new(470, 380),
    Acrylic = true, 
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl 
}

local Tabs = {
    Main = Window:CreateTab{
        Title = "Main",
        Icon = "phosphor-sword-bold"
    },
    Settings = Window:CreateTab{
        Title = "Settings",
        Icon = "settings"
    }
}

local Options = Library.Options

-- ==========================================
-- [ 2. ตั้งค่าตัวแปรเกมและระบบต่างๆ ]
-- ==========================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VIM = game:GetService("VirtualInputManager")

-- [เพิ่มเติม] โหลด UtilsSystem เพื่อเข้าถึง PlayerData
local UtilsSystem = require(ReplicatedFirst:WaitForChild("AllSideCode"):WaitForChild("UtilsSystem"))
local PlayerData = UtilsSystem.PlayerData

-- ========================
-- Anti AFK
-- ========================
Player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ========================
-- Remote Event & Functions
-- ========================
local ReleaseEvent = ReplicatedStorage:WaitForChild("Msg"):WaitForChild("RemoteEvent"):WaitForChild("ReleaseGroupSkill")
local EquipRemote = ReplicatedStorage:WaitForChild("Msg"):WaitForChild("RemoteFunction"):WaitForChild("RemoteFunction")
local PickRemote = ReplicatedStorage:WaitForChild("Msg"):WaitForChild("RemoteEvent"):WaitForChild("RemoteEvent")
local SellRemote = EquipRemote -- ใช้ Remote เดียวกับ Equip
local QuestRemote = ReplicatedStorage:WaitForChild("Msg"):WaitForChild("Function"):WaitForChild("TalkFunc")

local function castM1(targetChar)
    local myCharacter = Player.Character
    local myHrp = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end

    local targetCF = myHrp.CFrame * CFrame.new(0, 0, -5) 
    if targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
        targetCF = targetChar.HumanoidRootPart.CFrame
    end

    local args = {
        [1] = 4, -- M1 Skill ID
        [2] = {
            ["targetCF"] = targetCF,
            ["trackTargetId"] = targetChar
        }
    }
    ReleaseEvent:FireServer(unpack(args))
end

local function castskill(skillId, targetChar)
    local myCharacter = Player.Character
    local myHrp = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end

    local targetCF = myHrp.CFrame * CFrame.new(0, 0, -5) 
    if targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
        targetCF = targetChar.HumanoidRootPart.CFrame
    end

    local args = {
        [1] = skillId,
        [2] = {
            ["targetCF"] = targetCF,
            ["releaseCF"] = myHrp.CFrame
        }
    }
    ReleaseEvent:FireServer(unpack(args))
end

-- [เพิ่มฟังก์ชัน] Auto Equip Wand
local lastEquipTime = 0
local function autoEquipWand()
    if tick() - lastEquipTime < 3 then return end
    local characterFolder = Workspace:FindFirstChild("Characters")
    if not characterFolder then return end
    local myWorkspaceChar = characterFolder:FindFirstChild(Player.Name)
    if not myWorkspaceChar then return end
    local currentHandFolder = myWorkspaceChar:FindFirstChild("当前手持")
    if currentHandFolder and #currentHandFolder:GetChildren() > 0 then return end
    local backpackFolder = myWorkspaceChar:FindFirstChild("装备武器背挂")
    if backpackFolder then
        local children = backpackFolder:GetChildren()
        if #children > 0 then
            local wandItem = children[1]
            local wandId = wandItem:GetAttribute("OnlyID")
            if wandId then
                local args = {"切换手持物品", wandId}
                EquipRemote:InvokeServer(unpack(args))
                lastEquipTime = tick()
            end
        end
    elseif not backpackFolder then
        VIM:SendKeyEvent(true, Enum.KeyCode.One, false, game) task.wait(0.01) VIM:SendKeyEvent(false, Enum.KeyCode.One, false, game)
    end
end

-- ========================
-- Mob Config & Translation
-- ========================
local enemyConfig = {}
local success, configData = pcall(function()
    return require(ReplicatedFirst:WaitForChild("AllSideCode"):WaitForChild("ToolBasic"):WaitForChild("ConfigInstance"))
end)
if success and configData then
    enemyConfig = configData.enemyConf or {}
end

local MobTranslations = {
    [5000001] = "Dwarf", [5000002] = "Warhammer Dwarf", [5000004] = "Knife Goblin",
    [5000005] = "Archer Goblin", [5000006] = "Dwarf King", [5000007] = "Elite Hammer Goblin",
    [5000008] = "Elite Bow Goblin", [5001001] = "Blueberry Bush", [5001002] = "Mushroom Group",
    [5001003] = "Bird's Nest", [5001004] = "Large Blueberry Bush", [5001005] = "Large Mushroom Group",
    [5001006] = "Big Bird's Nest"
}

local function getMobName(id)
    if MobTranslations[id] then return MobTranslations[id] end
    if enemyConfig[id] then
        local data = enemyConfig[id]
        return data[4] or data[1] or "Unknown Mob"
    end
    return "Unknown Mob"
end

local mobDropdownList = {}
local mobNameToIdMap = {}
if enemyConfig then
    local mobIds = {}
    for id, _ in pairs(enemyConfig) do table.insert(mobIds, id) end
    table.sort(mobIds)
    for _, id in pairs(mobIds) do
        local name = getMobName(id)
        local displayName = string.format("%s (ID: %s)", name, id)
        table.insert(mobDropdownList, displayName)
        mobNameToIdMap[displayName] = id
    end
end

--quest config
local QuestData = {
    ["Dwarf"] = "任务3",
    ["Knife Goblin"] = "任务3",
    ["Warhammer Dwarf"] = "任务4",
    ["Archer Goblin"] = "任务5",
    ["Dwarf King"] = "任务6"
}
local questDropdownList = {}
for name, _ in pairs(QuestData) do table.insert(questDropdownList, name) end
table.sort(questDropdownList)

-- ========================
-- Sell Item Config (แก้ไข: เอา OnlyID ออก, เก็บแค่ ID ประเภท)
-- ========================
local SellItemData = {
    ["Blueberry"] = {ItemID = 2000001}, 
    ["Withered Mushroom"] = {ItemID = 2000002},
    ["Seagull Egg"] = {ItemID = 2000003}, 
    ["Dwarf Emblem"] = {ItemID = 2000004},
    ["Golden Tooth"] = {ItemID = 2000005}, 
    ["Flame Crest"] = {ItemID = 2000006},
    ["Furnace Core"] = {ItemID = 2000010}, 
    ["Goblin Finger"] = {ItemID = 2000007},
    ["Goblin Bone"] = {ItemID = 2000008}, 
    ["Copper Earring"] = {ItemID = 2000009}
}
local sellDropdownList = {}
local sellNameToDataMap = {}
for name, data in pairs(SellItemData) do
    table.insert(sellDropdownList, name)
    sellNameToDataMap[name] = data
end
table.sort(sellDropdownList)

-- ==========================================
-- [ 3. สร้าง UI Elements ]
-- ==========================================
local MobDropdown = Tabs.Main:AddDropdown("SelectMob", {
    Title = "Select Mob (Multi)", Values = mobDropdownList, Multi = true, Default = {}
})
local MethodDropdown = Tabs.Main:AddDropdown("FarmMethod", {
    Title = "Farm Method", Values = { "Behind", "Above", "Below" }, Multi = false, Default = 1
})
local DistanceSlider = Tabs.Main:AddSlider("FarmDistance", {
    Title = "Distance", Min = 0, Max = 20, Default = 5, Rounding = 0
})
local AutoFarmToggle = Tabs.Main:AddToggle("AutoFarm", {
    Title = "Auto Farm Mob", Default = false
})
local SkillDropdown = Tabs.Main:AddDropdown("SelectSkill", {
    Title = "Select Skill (Multi)", Values = { "1", "2" }, Multi = true, Default = {}
})
local AutoSkillToggle = Tabs.Main:AddToggle("AutoCastSkill", {
    Title = "Auto Cast Skill", Default = false
})

local PickSection = Tabs.Main:AddSection("Auto Pick Drops")
local AutoPickToggle = Tabs.Main:AddToggle("AutoPickDrops", {
    Title = "Auto Pick Drops", Default = false
})

local SellSection = Tabs.Main:AddSection("Auto Sell")
local SellDropdown = Tabs.Main:AddDropdown("SelectItemToSell", {
    Title = "Select Material to Sell", Values = sellDropdownList, Multi = true, Default = {}
})
local AutoSellToggle = Tabs.Main:AddToggle("AutoSell", {
    Title = "Auto Sell Items", Default = false
})

local parrysecion = Tabs.Main:AddSection("Parry")
local AutoParryToggle = Tabs.Main:AddToggle("AutoParry", {
    Title = "Auto Parry", Default = false
})
local ParryDelaySlider = Tabs.Main:AddSlider("ParryDelay", {
    Title = "Parry Delay", Min = 0, Max = 1, Default = 0.5, Rounding = 1
})

local QuestSection = Tabs.Main:AddSection("Auto Quest")
local QuestDropdown = Tabs.Main:AddDropdown("SelectQuest", {
    Title = "Select Quest (Multi)",
    Values = questDropdownList,
    Multi = true,
    Default = {}
})

local AutoQuestToggle = Tabs.Main:AddToggle("AutoQuest", {
    Title = "Auto Accept Quest",
    Default = false
})

local GetGamepass = Tabs.Main:AddButton({
    Title = "Get Gamepass", Description = "Free gamepass",
    Callback = function()
        local player = game.Players.LocalPlayer
        local gamepassfolder = player:FindFirstChild("GamePass")
        if gamepassfolder then
            for _, child in pairs(gamepassfolder:GetChildren()) do
                if child:IsA("NumberValue") then child.Value = 1 end
            end
        end
    end
})

-- ==========================================
-- [ 4. Auto Farm Logic (Fixed Loop) ]
-- ==========================================
local CurrentTargetMob = nil

RunService.Heartbeat:Connect(function()
    if not AutoFarmToggle.Value then CurrentTargetMob = nil return end
    
    local character = Player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChild("Humanoid")
    
    if not hrp or not humanoid or humanoid.Health <= 0 then 
        CurrentTargetMob = nil
        return 
    end
    
    autoEquipWand()
    hrp.Velocity = Vector3.new(0, 0, 0)
    
    local selectedMobs = Options.SelectMob.Value
    if not selectedMobs or type(selectedMobs) ~= "table" or next(selectedMobs) == nil then return end
    
    local farmMethod = Options.FarmMethod.Value
    local farmDistance = Options.FarmDistance.Value
    local targetIds = {}
    for name, _ in pairs(selectedMobs) do
        if mobNameToIdMap[name] then targetIds[mobNameToIdMap[name]] = true end
    end
    
    local targetMob = nil
    local minDist = math.huge
    
    local monsterFolder = Workspace:FindFirstChild("Monster")
    if monsterFolder then
        for _, mob in pairs(monsterFolder:GetChildren()) do
            if mob:IsA("Model") then
                local mobId = mob:GetAttribute("ID")
                local mobROOT = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Root")
                local mobHum = mob:FindFirstChild("Humanoid")
                
                if mobId and targetIds[mobId] and mobROOT and mobHum and mobHum.Health > 0 then
                    local dist = (mobROOT.Position - hrp.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        targetMob = mob
                    end
                end
            end
        end
    end
    
    CurrentTargetMob = targetMob
    
    if targetMob then
        local targetHRP = targetMob:FindFirstChild("HumanoidRootPart") or targetMob:FindFirstChild("Root")
        if targetHRP then
            local targetCFrame = targetHRP.CFrame
            local newPos
            
            if farmMethod == "Behind" then
                newPos = targetCFrame * CFrame.new(0, 0, farmDistance)
            elseif farmMethod == "Above" then
                newPos = targetCFrame * CFrame.new(0, farmDistance, 0) * CFrame.Angles(math.rad(-90), 0, 0)
            elseif farmMethod == "Below" then
                newPos = targetCFrame * CFrame.new(0, -farmDistance, 0) * CFrame.Angles(math.rad(90), 0, 0)
            end
            
            hrp.CFrame = newPos
            castM1(targetMob)
        end
    end
end)

-- ==========================================
-- [ 4.1 Auto Skill Loop (Fixed) ]
-- ==========================================
task.spawn(function()
    while task.wait(0.1) do
        if AutoFarmToggle.Value and AutoSkillToggle.Value and CurrentTargetMob then
            local selectedSkills = Options.SelectSkill.Value
            if selectedSkills and type(selectedSkills) == "table" then
                for skillName, isSelected in pairs(selectedSkills) do
                    if isSelected then
                        local skillNum = tonumber(skillName)
                        if skillNum then
                            if CurrentTargetMob and CurrentTargetMob.Parent then
                                local hum = CurrentTargetMob:FindFirstChild("Humanoid")
                                if hum and hum.Health > 0 then
                                     castskill(skillNum, CurrentTargetMob)
                                     task.wait(0.35)
                                else
                                     break 
                                end
                            else
                                break 
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ==========================================
-- [ 4.2 Smart Auto Sell Logic (Fixed) ]
-- ==========================================
local isSelling = false

local function checkAndSellItems()
    if isSelling then return end
    if not AutoSellToggle.Value then return end
    
    -- 1. ดึงรายการไอเทมที่เลือกจาก UI
    local selectedItems = Options.SelectItemToSell.Value
    if not selectedItems or type(selectedItems) ~= "table" or next(selectedItems) == nil then return end

    -- 2. ดึงข้อมูลกระเป๋าจาก PlayerData (ของจริงในเกม)
    local bagData = PlayerData.GetPlrDataByKey(Player, "Bag")
    if not bagData or type(bagData) ~= "table" then return end

    -- 3. สร้างตัวแปรเก็บ ID ประเภทที่จะขาย
    local targetItemIds = {}
    for name, _ in pairs(selectedItems) do
        local data = sellNameToDataMap[name]
        if data and data.ItemID then
            targetItemIds[data.ItemID] = true
        end
    end

    -- 4. วนเช็คไอเทมในกระเป๋า หา OnlyID ที่ตรงกัน
    local idsToSell = {}
    for _, item in pairs(bagData) do
        if type(item) == "table" then
            local itemId = item.id
            local onlyId = item.onlyID
            
            -- เช็คว่า ID ตรงกับที่เลือกไหม และมี OnlyID ไหม
            if itemId and onlyId and targetItemIds[itemId] then
                -- เช็ค Lock ถ้าล็อคไว้ (item.lock == 1) ก็ไม่ขาย
                if not (item.lock and item.lock == 1) then
                    table.insert(idsToSell, onlyId)
                end
            end
        end
    end

    -- 5. ถ้ามีไอเทมจะขาย ให้ยิง Remote ทีเดียว
    if #idsToSell > 0 then
        isSelling = true
        local args = {"出售背包物品", { onlyIDList = idsToSell } }
        
        -- ใช้ pcall เพื่อกัน error
        local success, err = pcall(function()
            SellRemote:InvokeServer(unpack(args))
        end)
        
        if not success then
            warn("Auto Sell Error:", err)
        end
        
        task.wait(1) -- รอ 1 วินาทีก่อนรอบถัดไป
        isSelling = false
    end
end

-- วนลูปตรวจสอบทุก 3 วินาที
task.spawn(function()
    while task.wait(3) do
        if AutoSellToggle.Value then 
            checkAndSellItems() 
        end
    end
end)

-- เชื่อมกับ Event เมื่อมีไอเทมหลุดเข้ากระเป๋า (ChildAdded)
-- หมายเหตุ: PlayerData เป็น Table ธรรมดา, ChildAdded อาจไม่ทำงานถ้าเกมไม่ได้ Sync ด้วย Instance
-- แต่ Loop ด้านบนจะช่วยจัดการเรื่องนี้อยู่แล้ว

-- ==========================================
-- [ 5. Auto Parry Logic ]
-- ==========================================
local isParrying = false
local parryRemote = ReplicatedStorage:WaitForChild("Msg"):WaitForChild("RemoteEvent"):WaitForChild("ReleaseGroupSkill")

RunService.Heartbeat:Connect(function()
    if not AutoParryToggle.Value then return end
    local character = Player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local nearestMob = nil
    local minDist = math.huge
    local monsterFolder = Workspace:FindFirstChild("Monster")
    if monsterFolder then
        for _, mob in pairs(monsterFolder:GetChildren()) do
            if mob:IsA("Model") then
                local mobRoot = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Root")
                local mobHum = mob:FindFirstChild("Humanoid")
                if mobRoot and mobHum and mobHum.Health > 0 then
                    local dist = (mobRoot.Position - hrp.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        nearestMob = mob
                    end
                end
            end
        end
    end
    
    if nearestMob and not isParrying then
        local isAttacking = nearestMob:GetAttribute("SkillActionLock")
        if isAttacking == true and minDist <= 20 then
            isParrying = true
            task.wait(Options.ParryDelay.Value)
            parryRemote:FireServer(5)
            task.wait(0.2)
            parryRemote:FireServer(5, {skillButtonPhase = "up"})
            task.wait(0.5)
            isParrying = false
        end
    end
end)

-- ==========================================
-- [ 6. Auto Pick Logic ]
-- ==========================================
task.spawn(function()
    while task.wait(0.1) do
        if AutoPickToggle.Value then
            local dropFolder = Workspace:FindFirstChild("Drops")
            if dropFolder then
                local myDrops = dropFolder:FindFirstChild(tostring(Player.UserId))
                if myDrops then
                    for _, dropItem in ipairs(myDrops:GetChildren()) do
                        if dropItem and dropItem.Parent and (dropItem:IsA("Vector3Value") or dropItem:IsA("BasePart")) then
                            local args = {"pick", dropItem}
                            pcall(function()
                                PickRemote:FireServer(unpack(args))
                            end)
                            task.wait(0.3)
                        end
                    end
                end
            end
        end
    end
end)

-- ==========================================
-- [ 7. Auto Accept Quest System ]
-- ==========================================
task.spawn(function()
    local lastQuestTime = 0
    while task.wait(1) do
        if AutoQuestToggle.Value then
            -- ป้องกันการยิง Remote รัวๆ (ส่งทุก 3 วินาที)
            if tick() - lastQuestTime < 3 then continue end

            local selectedQuests = Options.SelectQuest.Value
            if selectedQuests and type(selectedQuests) == "table" then
                for questName, isSelected in pairs(selectedQuests) do
                    if isSelected then
                        local questId = QuestData[questName]
                        if questId then
                            -- 1. รับเควส
                            local args = {
                                "发放任务",
                                { questId }
                            }
                            pcall(function()
                                QuestRemote:InvokeServer(unpack(args))
                            end)

                            -- 2. ส่งเควส (Trigger Chat) - เพิ่มใหม่
                            local submitArgs = {
                                "触发聊天",
                                {
                                    "哈利因特",
                                    "10010100"
                                }
                            }
                            pcall(function()
                                -- ใช้ PickRemote (ซึ่งกำหนดไว้เป็น Msg/RemoteEvent/RemoteEvent) ในการยิง
                                PickRemote:FireServer(unpack(submitArgs))
                            end)
                        end
                    end
                end
                lastQuestTime = tick()
            end
        end
    end
end)

-- ========================
-- Mobile Toggle Button
-- ========================
local MobileGui = Instance.new("ScreenGui")
MobileGui.Name = "MobileToggleGui"
MobileGui.Parent = game:GetService("CoreGui")
MobileGui.IgnoreGuiInset = true
MobileGui.ResetOnSpawn = false

local ToggleButton = Instance.new("ImageButton")
ToggleButton.Name = "ToggleButton"
ToggleButton.Parent = MobileGui
ToggleButton.BackgroundColor3 = Color3.fromRGB(20,20,20)
ToggleButton.BorderSizePixel = 0
ToggleButton.Size = UDim2.new(0,60,0,60)
ToggleButton.AnchorPoint = Vector2.new(0.5,0.5)
ToggleButton.Position = UDim2.new(0.5,0,0.15,0)
ToggleButton.Image = "rbxassetid://135519443641857"
ToggleButton.ImageColor3 = Color3.fromRGB(255,255,255)

local UICorner = Instance.new("UICorner"); UICorner.CornerRadius = UDim.new(0,15); UICorner.Parent = ToggleButton
local UIStroke = Instance.new("UIStroke"); UIStroke.Thickness = 3; UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; UIStroke.Parent = ToggleButton

task.spawn(function()
    local speed = 0.15
    while MobileGui and MobileGui.Parent do 
        UIStroke.Color = Color3.fromHSV(tick() * speed % 1, 0.8, 1)
        RunService.Heartbeat:Wait()
    end
end)

ToggleButton.MouseButton1Click:Connect(function()
    if Window then Window:Minimize() else MobileGui:Destroy() end
end)

local dragging, dragInput, dragStart, startPos
ToggleButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = ToggleButton.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

ToggleButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        TweenService:Create(ToggleButton, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        }):Play()
    end
end)

task.spawn(function()
    while task.wait(1) do
        if not MobileGui or not MobileGui.Parent then break end
        local isWindowAlive = false
        local expectedGuiName = "FluentRenewed_" .. WindowTitle
        pcall(function()
            local RobloxGui = game:GetService("CoreGui"):FindFirstChild("RobloxGui")
            if RobloxGui and RobloxGui:FindFirstChild(expectedGuiName) then isWindowAlive = true end
        end)
        if not isWindowAlive then MobileGui:Destroy() break end
    end
end)

-- ==========================================
-- [ Setup SaveManager & InterfaceManager ]
-- ==========================================
SaveManager:SetLibrary(Library)
InterfaceManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes{"CurrentUpgradesList", "BoostAmounts"} 
InterfaceManager:SetFolder("KlakuylekHub")
SaveManager:SetFolder("KlakuylekHub/specific-game")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

local function getAutoSaveFile() return "autosave_" .. tostring(Player.Name) .. "_" .. tostring(game.GameId) end
task.spawn(function() local n = getAutoSaveFile(); local f = SaveManager.Folder .. "/settings/" .. n .. ".json"; if isfile(f) then SaveManager:Load(n) end end)
local function autoSave() SaveManager:Save(getAutoSaveFile()) end
for _, o in pairs(Options) do if o.OnChanged then o:OnChanged(autoSave) end end

Window:SelectTab(1)
Library:Notify{ Title = "Fluent", Content = "Auto Farm Loaded successfully.", Duration = 5 }
SaveManager:LoadAutoloadConfig()