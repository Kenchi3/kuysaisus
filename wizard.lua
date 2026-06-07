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
    Brew = Window:CreateTab{
        Title = "Brew Potion",
        Icon = "phosphor-flask-bold"
    },
    Sell = Window:CreateTab{
        Title = "Sell",
        Icon = "phosphor-coins-bold"
    },
    Player = Window:CreateTab{
        Title = "Player",
        Icon = "phosphor-user-bold"
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
local SellRemote = EquipRemote
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
        [1] = 4,
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
-- Dynamic Config & Translation Loading (IMPROVED)
-- ========================
local ConfigModule = ReplicatedFirst:WaitForChild("AllSideCode"):WaitForChild("ToolBasic"):WaitForChild("ConfigInstance")
local ConfigInstance = require(ConfigModule)

local enemyConf = ConfigInstance.enemyConf or {}
local materialConf = ConfigInstance.materialConf or {}
local potionConf = ConfigInstance.potionConf or {}

local LangModule = ReplicatedFirst:WaitForChild("AllSideCode"):WaitForChild("ToolBasic"):WaitForChild("TranslationHelper"):WaitForChild("Language")
local LangData = require(LangModule)
local localizationtableConf = LangData.localizationtableConf or {}

-- ==========================================
-- [ เพิ่มส่วนนี้: Manual Translation Table ]
-- ==========================================
-- ใส่ ID ของไอเทม/มอนเตอร์ ที่แปลผิดเพื่อบังคับชื่อที่ต้องการแสดงผล
local ManualTranslations = {
    -- ตัวอย่างจากรูปภาพ:
    ["5021006"] = "Volcanic Rock",
    ["5021007"] = "Fireproof Plant", -- เปลี่ยนเป็นชื่อจริงๆของไอเทมนี้แทนประโยคยาว
    ["2000007"] = "Goblin Finger",
    ["2000008"] = "Goblin Bone",
    
    -- คุณสามารถเพิ่มเติม ID อื่นๆ ที่แปลผิดได้ที่นี่ เช่น:
    -- ["1234567"] = "Correct Item Name",
}

-- ฟังก์ชันตรวจสอบว่า string เป็นชื่อที่ใช้ได้ (ไม่ใช่ตัวเลข, ไม่ว่าง, ยาวกว่า 1 ไบต์)
local function isNameCandidate(s)
    if type(s) ~= "string" then return false end
    if s == "" then return false end
    if tonumber(s) then return false end  -- กรอง "1", "2", "3" ออก
    if #s <= 1 then return false end       -- กรองตัวอักษรเดี่ยวออก
    return true
end

-- ฟังก์ชันเช็คว่าน่าจะเป็นคำอธิบาย (ประโยคยาว) หรือไม่
local function isLikelyDescription(s)
    if not s then return false end
    -- ถ้าข้อความยาวเกิน 30 ตัวอักษร หรือมีเว้นวรรคเยอะ (มากกว่า 4 คำ) ให้ถือว่าเป็นคำอธิบาย
    if #s > 30 then return true end
    local wordCount = select(2, string.gsub(s, "%S+", ""))
    if wordCount > 4 then return true end
    return false
end

-- ฟังก์ชันดึงชื่อ + แปลอัตโนมัติแบบฉลาด (เพิ่ม id เข้าไปเพื่อเช็ค Manual)
local function getLocalizedName(id, data, preferredIndices)
    -- 1. เช็คจาก Manual Translations ก่อนอันดับแรก (ถ้ามี)
    local strId = tostring(id)
    if ManualTranslations[strId] then
        return ManualTranslations[strId]
    end
    
    if type(data) ~= "table" then return "Unknown" end
    
    -- 2. ลองจาก preferred indices (ตามลำดับที่ระบุ)
    if preferredIndices then
        for _, idx in ipairs(preferredIndices) do
            local v = data[idx]
            if isNameCandidate(v) and not isLikelyDescription(v) then
                local trans = localizationtableConf[v]
                if trans and trans[2] and trans[2] ~= "" then
                    return trans[2]
                end
                return v  -- ใช้ชื่อจีนถ้าไม่มีคำแปล
            end
        end
    end
    
    -- 3. Fallback: หา string ที่ดีที่สุดจากทุก field (กรองคำอธิบายออก)
    local translatedCandidate = nil
    local untranslatedCandidate = nil
    
    for i, v in pairs(data) do
        if isNameCandidate(v) and not isLikelyDescription(v) then
            local trans = localizationtableConf[v]
            if trans and trans[2] and trans[2] ~= "" then
                -- มีคำแปล: เลือกอันที่สั้นที่สุด (ชื่อสั้นกว่าคำอธิบายเสมอ)
                if not translatedCandidate or #v < #translatedCandidate.raw then
                    translatedCandidate = {raw = v, translated = trans[2]}
                end
            else
                -- ไม่มีคำแปล: เก็บไว้เป็นตัวเลือกสำรอง
                if not untranslatedCandidate or #v < #untranslatedCandidate then
                    untranslatedCandidate = v
                end
            end
        end
    end
    
    -- ให้ลำดับความสำคัญ: มีคำแปล > ไม่มีคำแปล
    if translatedCandidate then return translatedCandidate.translated end
    if untranslatedCandidate then return untranslatedCandidate end
    
    return "Unknown"
end

-- สร้าง Mob Dropdown
local mobDropdownList = {}
local mobNameToIdMap = {}
do
    local mobIds = {}
    for id, _ in pairs(enemyConf) do table.insert(mobIds, id) end
    table.sort(mobIds)
    
    for _, id in ipairs(mobIds) do
        local data = enemyConf[id]
        -- **ส่ง id เข้าไปในฟังก์ชันด้วย**
        local displayName = getLocalizedName(id, data, {1, 5, 4})
        local entry = string.format("%s (ID: %s)", displayName, id)
        
        table.insert(mobDropdownList, entry)
        mobNameToIdMap[entry] = id
    end
end

-- Quest Config
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

-- สร้าง Material & Potion Dropdown
local materialDropdownList = {}
local potionDropdownList = {}
local sellNameToDataMap = {} 
local brewDropdownList = {"None"}

do
    local matIds = {}
    for id, _ in pairs(materialConf) do table.insert(matIds, id) end
    table.sort(matIds)
    
    for _, id in ipairs(matIds) do
        local data = materialConf[id]
        -- **ส่ง id เข้าไปในฟังก์ชันด้วย**
        local displayName = getLocalizedName(id, data, {1, 16})
        local entry = string.format("%s (ID: %s)", displayName, id)
        
        table.insert(materialDropdownList, entry)
        sellNameToDataMap[entry] = { ItemID = id }
        table.insert(brewDropdownList, entry)
    end

    local potIds = {}
    for id, _ in pairs(potionConf) do table.insert(potIds, id) end
    table.sort(potIds)
    
    for _, id in ipairs(potIds) do
        local data = potionConf[id]
        -- **ส่ง id เข้าไปในฟังก์ชันด้วย**
        local displayName = getLocalizedName(id, data, {4, 1, 10})
        local entry = string.format("%s (ID: %s)", displayName, id)
        
        table.insert(potionDropdownList, entry)
        sellNameToDataMap[entry] = { ItemID = id }
    end

    table.sort(materialDropdownList)
    table.sort(potionDropdownList)
    table.sort(brewDropdownList, function(a, b) 
        if a == "None" then return true end
        if b == "None" then return false end
        return a < b 
    end)
end
-- ==========================================
-- [ 3. สร้าง UI Elements ]
-- ==========================================
local MobDropdown = Tabs.Main:AddDropdown("SelectMob", {
    Title = "Select Mob (Multi)", Values = mobDropdownList, Multi = true, Default = {},Searchable = true,
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

local parrysecion = Tabs.Main:AddSection("Parry")
local AutoParryToggle = Tabs.Main:AddToggle("AutoParry", {
    Title = "Auto Parry", Default = false
})
local ParryDelaySlider = Tabs.Main:AddSlider("ParryDelay", {
    Title = "Parry Delay", Min = 0, Max = 1, Default = 0.5, Rounding = 2
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
-- [ Brew UI ]
-- ==========================================
local BrewSection = Tabs.Brew:AddSection("Auto Brew")

local Mat1Dropdown = Tabs.Brew:AddDropdown("BrewMat1", { Title = "Material 1", Values = brewDropdownList, Default = 1, Searchable = true,})
local Mat2Dropdown = Tabs.Brew:AddDropdown("BrewMat2", { Title = "Material 2", Values = brewDropdownList, Default = 1, Searchable = true, })
local Mat3Dropdown = Tabs.Brew:AddDropdown("BrewMat3", { Title = "Material 3", Values = brewDropdownList, Default = 1, Searchable = true, })
local Mat4Dropdown = Tabs.Brew:AddDropdown("BrewMat4", { Title = "Material 4", Values = brewDropdownList, Default = 1, Searchable = true, })
local Mat5Dropdown = Tabs.Brew:AddDropdown("BrewMat5", { Title = "Material 5", Values = brewDropdownList, Default = 1, Searchable = true, })

local AutoBrewToggle = Tabs.Brew:AddToggle("AutoBrew", {
    Title = "Auto Brew Potion",
    Default = false
})

-- ==========================================
-- [ Sell UI ]
-- ==========================================
local SellSection = Tabs.Sell:AddSection("Auto Sell")

local SellMaterialDropdown = Tabs.Sell:AddDropdown("SelectMaterialToSell", {
    Title = "Select Material to Sell", Values = materialDropdownList, Multi = true, Default = {}, Searchable = true,
})

local SellPotionDropdown = Tabs.Sell:AddDropdown("SelectPotionToSell", {
    Title = "Select Potion to Sell", Values = potionDropdownList, Multi = true, Default = {}, Searchable = true,
})

local AutoSellToggle = Tabs.Sell:AddToggle("AutoSell", {
    Title = "Auto Sell Items", Default = false
})

-- ==========================================
-- [ Player UI ]
-- ==========================================
local StatSection = Tabs.Player:AddSection("Auto Allocate Stats")

local StatDropdown = Tabs.Player:AddDropdown("SelectStat", {
    Title = "Select Stat to Allocate",
    Values = {"Attack", "HP", "Cooling Reduction", "Movement Speed"},
    Multi = true,
    Default = {}
})

local AutoStatToggle = Tabs.Player:AddToggle("AutoAllocate", {
    Title = "Auto Allocate Stat",
    Default = false
})

local AscendSection = Tabs.Player:AddSection("Auto Ascend")

local AutoAscendToggle = Tabs.Player:AddToggle("AutoAscend", {
    Title = "Auto Ascend / Rebirth",
    Default = false
})

-- ==========================================
-- [ 4. Auto Farm Logic ]
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
-- [ 4.1 Auto Skill Loop ]
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
-- [ 4.2 Smart Auto Sell Logic ]
-- ==========================================
local isSelling = false

local function checkAndSellItems()
    if isSelling then return end
    if not AutoSellToggle.Value then return end
    
    local selectedMaterials = Options.SelectMaterialToSell.Value
    local selectedPotions = Options.SelectPotionToSell.Value
    
    if (not selectedMaterials or next(selectedMaterials) == nil) and (not selectedPotions or next(selectedPotions) == nil) then return end

    local bagData = PlayerData.GetPlrDataByKey(Player, "Bag")
    if not bagData or type(bagData) ~= "table" then return end

    local targetItemIds = {}
    
    if selectedMaterials then
        for name, _ in pairs(selectedMaterials) do
            local data = sellNameToDataMap[name]
            if data and data.ItemID then
                targetItemIds[data.ItemID] = true
            end
        end
    end
    
    if selectedPotions then
        for name, _ in pairs(selectedPotions) do
            local data = sellNameToDataMap[name]
            if data and data.ItemID then
                targetItemIds[data.ItemID] = true
            end
        end
    end

    local idsToSell = {}
    for _, item in pairs(bagData) do
        if type(item) == "table" then
            local itemId = item.id
            local onlyId = item.onlyID
            
            if itemId and onlyId and targetItemIds[itemId] then
                if not (item.lock and item.lock == 1) then
                    table.insert(idsToSell, onlyId)
                end
            end
        end
    end

    if #idsToSell > 0 then
        isSelling = true
        local args = {"出售背包物品", { onlyIDList = idsToSell } }
        
        local success, err = pcall(function()
            SellRemote:InvokeServer(unpack(args))
        end)
        
        if not success then
            warn("Auto Sell Error:", err)
        end
        
        task.wait(1) 
        isSelling = false
    end
end

task.spawn(function()
    while task.wait(3) do
        if AutoSellToggle.Value then 
            checkAndSellItems() 
        end
    end
end)

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
        if isAttacking == true and minDist <= 30 then
            isParrying = true
            task.wait(Options.ParryDelay.Value)
            parryRemote:FireServer(5)
            task.wait(0.3)
            parryRemote:FireServer(5, {skillButtonPhase = "up"})
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
                            local dropname = tonumber(dropItem.Name)
                            local args = {"pick", dropname}
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
            if tick() - lastQuestTime < 3 then continue end

            local selectedQuests = Options.SelectQuest.Value
            if selectedQuests and type(selectedQuests) == "table" then
                for questName, isSelected in pairs(selectedQuests) do
                    if isSelected then
                        local questId = QuestData[questName]
                        if questId then
                            local args = {
                                "发放任务",
                                { questId }
                            }
                            pcall(function()
                                QuestRemote:InvokeServer(unpack(args))
                            end)

                            local submitArgs = {
                                "触发聊天",
                                {
                                    "哈利因特",
                                    "10010100"
                                }
                            }
                            pcall(function()
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

-- ==========================================
-- [ 8. Auto Brew Logic ]
-- ==========================================
task.spawn(function()
    while task.wait(1) do
        if AutoBrewToggle.Value then
            local selectedMats = {
                Options.BrewMat1.Value,
                Options.BrewMat2.Value,
                Options.BrewMat3.Value,
                Options.BrewMat4.Value,
                Options.BrewMat5.Value
            }

            local materialsTableStart = {} 
            local materialsTableFinish = {} 
            local hasMaterial = false

            for _, matName in pairs(selectedMats) do
                if matName ~= "None" then
                    local data = sellNameToDataMap[matName] 
                    if data and data.ItemID then
                        materialsTableStart[data.ItemID] = (materialsTableStart[data.ItemID] or 0) + 1
                        materialsTableFinish[tostring(data.ItemID)] = (materialsTableFinish[tostring(data.ItemID)] or 0) + 1
                        hasMaterial = true
                    end
                end
            end

            if hasMaterial then
                local startArgs = {
                    "炼药游戏开始",
                    {
                        cauldronID = 8000001,
                        materials = materialsTableStart
                    }
                }
                pcall(function()
                    EquipRemote:InvokeServer(unpack(startArgs))
                end)

                task.wait(0.5) 

                local finishArgs = {
                    "炼药",
                    {
                        cauldronID = 8000001,
                        materials = materialsTableFinish,
                        gameScore = 100
                    }
                }
                pcall(function()
                    EquipRemote:InvokeServer(unpack(finishArgs))
                end)

                task.wait(5)
            end
        end
    end
end)

-- ==========================================
-- [ 9. Auto Allocate Stat Logic ]
-- ==========================================
local StatMap = {
    ["Attack"] = 1,
    ["HP"] = 5,
    ["Cooling Reduction"] = 39,
    ["Movement Speed"] = 41
}

task.spawn(function()
    while task.wait(0.5) do
        if AutoStatToggle.Value then
            local bag = Player:FindFirstChild("Bag")
            if bag then
                local statPointObj = bag:FindFirstChild("5")
                if statPointObj and statPointObj:IsA("IntValue") or statPointObj:IsA("NumberValue") then
                    local currentPoints = statPointObj.Value
                    
                    if currentPoints > 0 then
                        local selectedStats = Options.SelectStat.Value
                        if selectedStats and type(selectedStats) == "table" then
                            for statName, isSelected in pairs(selectedStats) do
                                if isSelected then
                                    if statPointObj.Value <= 0 then break end
                                    
                                    local attrId = StatMap[statName]
                                    if attrId then
                                        local args = {
                                            "属性加点",
                                            {
                                                AttrTp = attrId,
                                                PointNum = 1
                                            }
                                        }
                                        pcall(function()
                                            EquipRemote:InvokeServer(unpack(args))
                                        end)
                                        task.wait(0.1)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ==========================================
-- [ Auto Ascend Logic ]
-- ==========================================
task.spawn(function()
    while task.wait(5) do
        if AutoAscendToggle.Value then
            local args = {
                "\233\135\141\231\148\159"
            }
            pcall(function()
                EquipRemote:InvokeServer(unpack(args))
            end)
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