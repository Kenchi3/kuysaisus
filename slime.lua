-- ==========================================
-- [ 1. โหลด Fluent UI Library ]
-- ==========================================
local Library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
local SaveManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"))()

local Window = Library:CreateWindow{
    Title = "Klakuylek Hub - Slime RNG",
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
        Icon = "phosphor-users-bold"
    },
    Upgrades = Window:CreateTab{
        Title = "Upgrades",
        Icon = "phosphor-arrow-square-up-bold"
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
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer

local DataService = require(ReplicatedStorage.Packages._Index["leifstout_dataservice@0.4.0"].dataservice.DataServiceClient)
local UpgradeTree = require(ReplicatedStorage.Source.Features.Upgrades.UpgradeTree)

-- Remotes
local UpgradeRemote = ReplicatedStorage:WaitForChild("Packages")
    :WaitForChild("_Index")
    :WaitForChild("leifstout_networker@0.3.1")
    :WaitForChild("networker")
    :WaitForChild("_remotes")
    :WaitForChild("UpgradeService")
    :WaitForChild("RemoteFunction")

local RollRemote = ReplicatedStorage:WaitForChild("Packages")
    :WaitForChild("_Index")
    :WaitForChild("leifstout_networker@0.3.1")
    :WaitForChild("networker")
    :WaitForChild("_remotes")
    :WaitForChild("RollService")
    :WaitForChild("RemoteFunction")

local InventoryRemote = ReplicatedStorage:WaitForChild("Packages")
    :WaitForChild("_Index")
    :WaitForChild("leifstout_networker@0.3.1")
    :WaitForChild("networker")
    :WaitForChild("_remotes")
    :WaitForChild("InventoryService")
    :WaitForChild("RemoteFunction")

local LootRemote = ReplicatedStorage:WaitForChild("Packages")
    :WaitForChild("_Index")
    :WaitForChild("leifstout_networker@0.3.1")
    :WaitForChild("networker")
    :WaitForChild("_remotes")
    :WaitForChild("LootService")
    :WaitForChild("RemoteFunction")

local ZonesRemote = ReplicatedStorage:WaitForChild("Packages")
    :WaitForChild("_Index")
    :WaitForChild("leifstout_networker@0.3.1")
    :WaitForChild("networker")
    :WaitForChild("_remotes")
    :WaitForChild("ZonesService")
    :WaitForChild("RemoteFunction")

local RebirthRemote = ReplicatedStorage:WaitForChild("Packages")
    :WaitForChild("_Index")
    :WaitForChild("leifstout_networker@0.3.1")
    :WaitForChild("networker")
    :WaitForChild("_remotes")
    :WaitForChild("RebirthService")
    :WaitForChild("RemoteFunction")

local BoostRemote = ReplicatedStorage:WaitForChild("Packages")
    :WaitForChild("_Index")
    :WaitForChild("leifstout_networker@0.3.1")
    :WaitForChild("networker")
    :WaitForChild("_remotes")
    :WaitForChild("BoostService")
    :WaitForChild("RemoteFunction")

local lootFolder = Workspace:WaitForChild("Loot")
local zonesFolder = Workspace:WaitForChild("Zones")

-- ==========================================
-- [ 3. สร้าง UI Elements ]
-- ==========================================

-- Main Tab UI
Tabs.Main:CreateToggle("AutoRollToggle", {
    Title = "Auto Roll",
    Description = "Automatically rolls for you",
    Default = false
})

Tabs.Main:CreateSlider("RollDelaySlider", {
    Title = "Roll Delay",
    Description = "Delay between rolls to avoid detection",
    Default = 0.5,
    Min = 0.1,
    Max = 2,
    Rounding = 1,
})

Tabs.Main:CreateToggle("AutoEquipBestToggle", {
    Title = "Auto Equip Best",
    Description = "Automatically equips the best items (0.1s delay)",
    Default = false
})

Tabs.Main:CreateToggle("AutoRebirthToggle", {
    Title = "Auto Rebirth",
    Description = "Automatically rebirths when available",
    Default = false
})


Tabs.Main:CreateSection("Loots")

Tabs.Main:CreateToggle("AutoCollectToggle", {
    Title = "Auto Collect Loots",
    Description = "Automatically collects dropped loot via Remote",
    Default = false
})

Tabs.Main:CreateSlider("LootDelaySlider", {
    Title = "Collect Delay",
    Description = "Delay between each loot collection",
    Default = 0.1,
    Min = 0,
    Max = 1,
    Rounding = 2,
})

Tabs.Main:CreateSection("Zones")

Tabs.Main:CreateToggle("AutoPurchaseZoneToggle", {
    Title = "Auto Purchase Zone",
    Description = "Automatically purchases the next zone when affordable",
    Default = false
})

Tabs.Main:CreateToggle("AutoTPFurthestZoneToggle", {
    Title = "Auto TP Furthest Zone",
    Description = "Automatically teleports to the highest unlocked zone",
    Default = false
})

-- Boost UI
Tabs.Main:CreateSection("Boost")

Tabs.Main:CreateDropdown("BoostSelector", {
    Title = "Select Boosts",
    Description = "Select which boosts to activate automatically",
    Values = {"luck", "ultraLuck", "rollSpeed", "currency"},
    Multi = true,
    Default = {}
})

Tabs.Main:CreateToggle("AutoUseBoostToggle", {
    Title = "Auto Use Boost",
    Description = "Automatically uses selected boosts from your inventory",
    Default = false
})

local BoostAmountParagraph = Tabs.Main:CreateParagraph("BoostAmounts", {
    Title = "Boost Inventory",
    Content = "Loading..."
})

-- Upgrades Tab UI
Tabs.Upgrades:CreateToggle("AutoUpgradeToggle", {
    Title = "Auto Smart Upgrade",
    Description = "Automatically purchases unlocked upgrades you can afford",
    Default = false
})

local UpgradeListParagraph = Tabs.Upgrades:CreateParagraph("CurrentUpgradesList", {
    Title = "Owned Upgrades",
    Content = "Loading..."
})

-- ==========================================
-- [ 4. ระบบ Auto Roll & Equip ]
-- ==========================================
task.spawn(function()
    while task.wait(0.1) do
        if Library.Unloaded then break end
        
        if Options.AutoRollToggle.Value then
            pcall(function() RollRemote:InvokeServer("requestRoll") end)
            task.wait(Options.RollDelaySlider.Value)
        end
        
        if Options.AutoEquipBestToggle.Value then
            pcall(function() InventoryRemote:InvokeServer("requestEquipBest") end)
        end
    end
end)

-- ==========================================
-- [ 5. ระบบ Auto Collect Loots ]
-- ==========================================
local function collectLoot(lootInstance)
    if not Options.AutoCollectToggle.Value then return end
    if not lootInstance or not lootInstance.Parent then return end

    local lootId = lootInstance.Name
    if lootId and string.len(lootId) > 10 then
        pcall(function() LootRemote:InvokeServer("requestCollect", lootId) end)
        task.wait(Options.LootDelaySlider.Value)
    end
end

lootFolder.ChildAdded:Connect(function(newChild)
    task.wait(0.1)
    collectLoot(newChild)
end)

-- ==========================================
-- [ 6. ระบบ Auto Zones ]
-- ==========================================
local function isPlayerInZone(zoneId)
    local character = Player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local success, zoneObj = pcall(function()
        return zonesFolder:FindFirstChild(tostring(zoneId))
    end)

    if success and zoneObj then
        local hitbox = zoneObj:FindFirstChild("POI") and zoneObj.POI:FindFirstChild("Hitbox")
        if hitbox and hitbox:IsA("BasePart") then
            local localPos = hitbox.CFrame:ToObjectSpace(hrp.CFrame).Position
            local size = hitbox.Size / 2
            return (math.abs(localPos.X) <= size.X and math.abs(localPos.Y) <= size.Y and math.abs(localPos.Z) <= size.Z)
        end
    end
    return false
end

task.spawn(function()
    while task.wait(2) do
        if Library.Unloaded then break end
        if Options.AutoPurchaseZoneToggle.Value then
            pcall(function() ZonesRemote:InvokeServer("requestPurchaseZone") end)
        end
    end
end)

task.spawn(function()
    while task.wait(1) do
        if Library.Unloaded then break end
        if Options.AutoTPFurthestZoneToggle.Value then
            pcall(function()
                DataService:waitForData()
                local furthestZone = DataService:get("maxZone")
                if furthestZone and not isPlayerInZone(furthestZone) then
                    ZonesRemote:InvokeServer("requestTeleportZone", furthestZone)
                    task.wait(2)
                end
            end)
        end
    end
end)

-- ==========================================
-- [ 7. ระบบ Auto Rebirth ]
-- ==========================================
task.spawn(function()
    while task.wait(3) do
        if Library.Unloaded then break end
        if Options.AutoRebirthToggle.Value then
            pcall(function() RebirthRemote:InvokeServer("requestRebirth") end)
        end
    end
end)

-- ==========================================
-- [ 8. ระบบ Auto Use Boost ]
-- ==========================================
local boostNames = {luck = "Luck", ultraLuck = "Ultra Luck", rollSpeed = "Roll Speed", currency = "Coin"}

local function updateBoostUI()
    DataService:waitForData()
    local boostsData = DataService:get("boosts") or {}
    local lines = {}

    for id, name in pairs(boostNames) do
        local amount = 0
        if boostsData[id] then
            if type(boostsData[id]) == "table" and boostsData[id].amount then
                amount = boostsData[id].amount
            elseif type(boostsData[id]) == "number" then
                amount = boostsData[id]
            end
        end
        table.insert(lines, string.format("- %s: %d", name, amount))
    end
    
    table.sort(lines)
    BoostAmountParagraph:SetValue(table.concat(lines, "\n"))
end

task.spawn(function()
    while task.wait(5) do
        if Library.Unloaded then break end
        
        if Options.AutoUseBoostToggle.Value then
            DataService:waitForData()
            local boostsData = DataService:get("boosts") or {}
            local selectedBoosts = Options.BoostSelector.Value
            
            for boostId, isSelected in pairs(selectedBoosts) do
                if isSelected then
                    local hasBoost = false
                    if boostsData[boostId] then
                        if type(boostsData[boostId]) == "table" and boostsData[boostId].amount and boostsData[boostId].amount > 0 then
                            hasBoost = true
                        elseif type(boostsData[boostId]) == "number" and boostsData[boostId] > 0 then
                            hasBoost = true
                        end
                    end
                    
                    if hasBoost then
                        pcall(function()
                            BoostRemote:InvokeServer("requestUseBoost", boostId)
                        end)
                        task.wait(1)
                    end
                end
            end
            updateBoostUI()
        end
    end
end)

-- ==========================================
-- [ 9. ระบบ Smart Auto Upgrade & Realtime UI ]
-- ==========================================
local function updateUpgradeListUI(currentupgrades)
    local lines = {}
    for upgradeId, _ in pairs(currentupgrades) do
        local upgradeName = upgradeId 
        for treeName, treeData in pairs(UpgradeTree) do
            if treeData[upgradeId] and treeData[upgradeId].name then
                upgradeName = treeData[upgradeId].name
                break
            end
        end
        table.insert(lines, "- " .. upgradeName)
    end
    table.sort(lines)
    local content = #lines > 0 and table.concat(lines, "\n") or "No upgrades unlocked yet."
    UpgradeListParagraph:SetValue(content)
end

local function smartAutoUpgrade(currentupgrades, currentcoin, currentRollCurrency)
    if not Options.AutoUpgradeToggle.Value then return end
    for treeName, treeData in pairs(UpgradeTree) do
        for upgradeId, upgradeInfo in pairs(treeData) do
            if type(upgradeInfo) == "table" and upgradeInfo.cost then
                local alreadyOwned = currentupgrades[upgradeId] ~= nil
                if not alreadyOwned then
                    local depMet = true
                    if upgradeInfo.dependency then
                        if upgradeInfo.dependency ~= "originDependency" then
                            if not currentupgrades[upgradeInfo.dependency] then depMet = false end
                        end
                    end

                    local canAfford = false
                    local costAmount = upgradeInfo.cost.amount or 0
                    local costCurrency = upgradeInfo.cost.currency
                    if costCurrency == "coins" then canAfford = currentcoin >= costAmount
                    elseif costCurrency == "rollCurrency" then canAfford = currentRollCurrency >= costAmount end

                    if depMet and canAfford then
                        Library:Notify{ Title = "Auto Upgrade", Content = string.format("Buying: %s", upgradeInfo.name), Duration = 3 }
                        local success, result = pcall(function() return UpgradeRemote:InvokeServer("requestUnlock", upgradeId) end)
                        if success then
                            currentupgrades[upgradeId] = true
                            if costCurrency == "coins" then currentcoin = currentcoin - costAmount
                            elseif costCurrency == "rollCurrency" then currentRollCurrency = currentRollCurrency - costAmount end
                            task.wait(0.5)
                        else
                            warn("Purchase failed:", upgradeInfo.name, "Reason:", result)
                        end
                    end
                end
            end
        end
    end
end

-- ลูปหลัก (Upgrades, Loots, Boost UI)
local lastUpgradeState = ""
task.spawn(function()
    while task.wait(1) do
        if Library.Unloaded then break end
        
        -- ส่วนอัปเกรด
        local success, currentupgrades = pcall(function()
            DataService:waitForData()
            return DataService:get("upgrades") or {}
        end)
        if success and currentupgrades then
            local currentcoin = DataService:get("coins") or 0
            local currentRollCurrency = DataService:get("rollCurrency") or 0
            pcall(smartAutoUpgrade, currentupgrades, currentcoin, currentRollCurrency)

            local currentState = ""
            local keys = {}
            for k, _ in pairs(currentupgrades) do table.insert(keys, k) end
            table.sort(keys)
            currentState = table.concat(keys, "|")
            if currentState ~= lastUpgradeState then
                lastUpgradeState = currentState
                updateUpgradeListUI(currentupgrades)
            end
        end

        -- ส่วนเก็บของ
        if Options.AutoCollectToggle.Value then
            for _, child in ipairs(lootFolder:GetChildren()) do
                if child.Name ~= "LootHighlight" then
                    collectLoot(child)
                end
            end
        end

        -- ส่วนอัปเดต UI Boost
        pcall(updateBoostUI)
    end
end)

-- ==========================================
-- [ 10. Setup SaveManager & InterfaceManager ]
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

Library:Notify{
    Title = "Fluent",
    Content = "The script has been loaded.",
    Duration = 5
}

SaveManager:LoadAutoloadConfig()