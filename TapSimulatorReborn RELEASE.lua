
local env = (getgenv and getgenv()) or _G
if env.TSR_Stop then pcall(env.TSR_Stop) end


local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService        = game:GetService("GuiService")
local TeleportService   = game:GetService("TeleportService")
local RunService        = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Remotes     = ReplicatedStorage:WaitForChild("RemoteServices", 15)
local Shared      = ReplicatedStorage:WaitForChild("Shared")

local DataController      = require(ReplicatedStorage.Controllers.Core.DataController)
local RebirthConfig       = require(Shared.Progression.RebirthConfig)
local RebirthButtonConfig = require(Shared.Progression.RebirthButtonConfig)
local UpgradeConfig       = require(Shared.Progression.UpgradeConfig)
local EggConfig           = require(Shared.Pets.LaunchEggConfig)
local EggPricing          = require(Shared.Pets.EggPricing)
local SkillTreeFormula    = require(Shared.Progression.SkillTreeFormula)
local IslandConfig        = require(Shared.Progression.IslandConfig)
local GamepassPerks       = require(Shared.Monetization.GamepassPerks)
local BoostFormula        = require(Shared.Items.BoostFormula)
local ShinyStarConfig     = require(Shared.Game.ShinyStarConfig)
local TapChestConfig      = require(Shared.Game.TapChestConfig)
local MachineConfig       = require(Shared.Pets.MachineConfig)
local PetIndexCatalog     = require(Shared.Pets.PetIndexCatalog)
local CollectionService   = game:GetService("CollectionService")
local PhysicalUpgradeConfig = require(Shared.Progression.PhysicalUpgradeConfig)
local HallowBossConfig    = require(Shared.Game.HallowBossConfig)
local MenuController      = require(ReplicatedStorage.Controllers.UI.MenuController)
local HallowBossController = require(ReplicatedStorage.Controllers.Game.HallowBossController)
local NpcQuestConfig      = require(Shared.Quests.NpcQuestConfig)
local ShrineConfig        = require(Shared.Game.ShrineConfig)
local DigConfig           = require(Shared.Minigames.DigConfig)
local PetPower            = require(Shared.Pets.PetPower)
local function optionalRequire(path)
    local ok, mod = pcall(require, path)
    return ok and mod or nil
end
local ShrineVisuals         = optionalRequire(ReplicatedStorage.Modules.Client.Game.ShrineVisuals)
local DigController         = optionalRequire(ReplicatedStorage.Controllers.Minigames.DigController)
local DigRewardPopup        = optionalRequire(ReplicatedStorage.Controllers.Minigames.DigRewardPopup)
local RewardPopupController = optionalRequire(ReplicatedStorage.Controllers.UI.RewardPopupController)


local function Data()
    local replica = DataController:GetReplica()
    return replica and replica.Data
end

local function remote(service, kind, name)
    return Remotes:WaitForChild(service):WaitForChild(kind):WaitForChild(name)
end

local R = {
    Tap          = remote("TapService", "RE", "TapRequested"),
    Rebirth      = remote("RebirthService", "RE", "RebirthRequested"),
    Hatch        = remote("EggService", "RE", "EggHatchRequested"),
    HatchResult  = remote("EggService", "RE", "EggHatchResult"),
    PetAction    = remote("PetService", "RE", "PetActionRequested"),
    Upgrade      = remote("UpgradeService", "RF", "Purchase"),
    ClaimQuest   = remote("QuestService", "RF", "ClaimQuest"),
    OfflineClaim = remote("OfflineRewardsService", "RF", "Claim"),
    SkillUnlock  = remote("SkillTreeService", "RF", "Unlock"),
    AutoClick    = remote("AutoClickService", "RE", "AutoClickRequested"),
    DuckSpawn    = remote("LuckyDuckyService", "RE", "Spawn"),
    DuckClaim    = remote("LuckyDuckyService", "RF", "Claim"),
    IslandTravel = remote("IslandService", "RF", "Travel"),
    IslandUnlock = remote("IslandService", "RE", "IslandUnlockRequested"),
    IslandResult = remote("IslandService", "RE", "IslandUnlockResult"),
    Setting      = remote("SettingsService", "RF", "UpdateSetting"),
    ChestClaim   = remote("TapChestService", "RF", "Claim"),
    Craft        = remote("MachineService", "RE", "MachineCraftRequested"),
    CraftResult  = remote("MachineService", "RE", "MachineCraftResult"),
    Knock        = remote("TrickOrTreatService", "RF", "Knock"),
    UseBoost     = remote("BoostService", "RF", "Use"),
    IndexClaim   = remote("PetIndexService", "RE", "RewardClaimRequested"),
    BuyPhysical  = remote("PhysicalUpgradeService", "RF", "Purchase"),
    BossAttack   = remote("HallowBossService", "RE", "Attack"),
    NpcTalk      = remote("NpcQuestService", "RF", "Talk"),
    NpcCollect   = remote("NpcQuestService", "RF", "Collect"),
    ShrineChoose = remote("ShrineService", "RF", "Choose"),
}

local function findGameFunction(name, moduleName)
    for _, f in ipairs(getgc(false)) do
        if type(f) == "function" and islclosure(f) then
            local ok, fnName, source = pcall(debug.info, f, "ns")
            if ok and fnName == name and source:find(moduleName, 1, true) then
                return f
            end
        end
    end
end

local GameTap   = findGameFunction("sendTap", "TapController")  
local GameHatch = findGameFunction("requestHatch", "EggController")  

local function safe(fn, ...)
    local ok, result = pcall(fn, ...)
    return ok and result or nil
end


local function humanWait(base)
    task.wait(base * (0.85 + math.random() * 0.3))
end

local Kicks = {}
local function kick(key) Kicks[key] = true end
local function nap(base, key)
    local untilTime = os.clock() + base * (0.85 + math.random() * 0.3)
    while os.clock() < untilTime and not Kicks[key] do task.wait(0.2) end
    Kicks[key] = nil
end


local State = {
    Running       = true,

    AutoTap       = false,
    TapsPerSec    = 8,

    AutoRebirth   = false,
    RebirthChoice = "Best affordable",

    AutoHatch     = false,
    SelectedEgg   = "Best affordable",
    HatchAmount   = "Max affordable",
    MoveMode      = "Teleport",

    AutoUpgrade   = false,
    AutoQuests    = false,
    AutoEquipBest = false,
    AutoOffline   = true,
    SkipHatchAnim = false,

    AutoSkillTree = false,
    GameAutoClick = false,
    AutoDucky     = false,

    AutoWorldChests = false,
    AutoTapChests   = false,
    AutoStars       = false,
    AutoTrickTreat  = false,
    AutoBoosts      = false,
    AutoIndex       = false,
    AutoGolden      = false,
    AutoDiamond     = false,
    AutoRainbow     = false,
    AutoJumps       = false,
    AutoIslands     = false,
    AutoBoss        = false,
    AutoMobs        = false,
    AutoStartColosseum = false,
    AutoDig         = false,
    AutoBalloons    = false,
    AutoNpcQuests   = false,
    AutoShrine      = false,
    ShrineChoice    = nil, 
    AutoDelete      = false,
    KeepBest        = 20,
    KeepOneEach     = true,
    DeleteTiers     = "Normal only",
    SkillTrees      = {},
    AutoClosePopups = true,
    KeepRarities    = {},
    AutoMine        = false,
    AutoSellOres    = true,
    AutoPickaxe     = false,
    AutoEnchant     = false,
    EnchantRanks    = {},
    EnchantPetRarities = {},
    AutoRejoin    = false,
    LowGpu        = false,
}

env.TSR_Stop  = function() State.Running = false end
env.TSR_State = State 
local Status = {}
local Fn = {}

local Session = { Hatched = 0, Chests = 0, Stars = 0, Crafted = 0, Knocks = 0, StartedAt = os.clock() }
env.TSR_Session = Session


local function canTap()
    for _, attr in ipairs({ "MiningActive", "AtDigsite", "DiggingActive", "ColosseumActive" }) do
        if LocalPlayer:GetAttribute(attr) == true then return false end
    end
    return true
end

local function rebirthOptions(d)
    local world    = d.Progression.World or "Main"
    local unlocked = RebirthButtonConfig.GetUnlockedCount(d.Upgrades.RebirthButtons or 0, world)
    return RebirthButtonConfig.GetOptionCount(unlocked, world)
end

local function rebirthPrice(d, index)
    return RebirthConfig.GetPrice(RebirthConfig.GetAmountFromIndex(index), d.Statistics.Rebirths)
end


local function bestRebirthIndex(d)
    local options = rebirthOptions(d)
    local choice = tonumber(string.match(State.RebirthChoice, "^#(%d+)"))
    if choice then
        if choice <= options and d.Currencies.Coins >= rebirthPrice(d, choice) then return choice end
        return nil
    end
    for index = options, 1, -1 do
        if d.Currencies.Coins >= rebirthPrice(d, index) then return index end
    end
    return nil
end

local RebirthChoices = { "Best affordable" }
for index = 1, RebirthButtonConfig.GetMaximumOptions("Main") do
    table.insert(RebirthChoices, string.format("#%d (+%s rebirths)", index, tostring(RebirthConfig.GetAmountFromIndex(index))))
end

local EggList = {}
for name, cfg in pairs(EggConfig) do
    if type(cfg) == "table" and cfg.Price and name ~= "Test" then
        table.insert(EggList, { Name = name, Price = cfg.Price, Island = cfg.Island })
    end
end
table.sort(EggList, function(a, b) return a.Price < b.Price end)

local EggNames = { "Best affordable" }
for _, egg in ipairs(EggList) do table.insert(EggNames, egg.Name) end

local function eggCost(d, name, count)
    return EggPricing.GetTotal(d, name, EggConfig[name].Price, count)
end

local EggSpots = {}
local function eggModel(name)
    local folder = workspace:FindFirstChild("Eggs")
    local model = folder and folder:FindFirstChild(name)
    if model then EggSpots[name] = model:GetPivot() end
    -- Far-away eggs can exist as empty shells; treat those as "not loaded"
    if model and not model:FindFirstChild("Egg") then return nil end
    return model
end
local MachinePoints = {} 
local PortalSpots = {}   
local BossSpot = nil    
local ChestSpots = {}   

local HttpService = game:GetService("HttpService")
local SPOTS_FILE = "TSR/spots.json"
local function packCF(cf) return { cf:GetComponents() } end
local function unpackCF(t) return CFrame.new(table.unpack(t)) end

local function loadSpots()
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(SPOTS_FILE)) end)
    if not ok or type(data) ~= "table" or data.PlaceId ~= game.PlaceId then return end
    for name, t in pairs(data.Eggs or {}) do EggSpots[name] = EggSpots[name] or unpackCF(t) end
    for name, t in pairs(data.Machines or {}) do MachinePoints[name] = MachinePoints[name] or unpackCF(t) end
    for key, t in pairs(data.Chests or {}) do ChestSpots[key] = ChestSpots[key] or { Rest = unpackCF(t), CheckedAt = 0 } end
    for name, t in pairs(data.Portals or {}) do PortalSpots[name] = PortalSpots[name] or unpackCF(t) end
    if data.Boss and not BossSpot then
        BossSpot = { CFrame = unpackCF(data.Boss.CFrame), Size = Vector3.new(table.unpack(data.Boss.Size)) }
    end
end

local function saveSpots()
    local data = { PlaceId = game.PlaceId, Eggs = {}, Machines = {}, Chests = {} }
    for name, cf in pairs(EggSpots) do data.Eggs[name] = packCF(cf) end
    for name, cf in pairs(MachinePoints) do data.Machines[name] = packCF(cf) end
    for key, spot in pairs(ChestSpots) do data.Chests[key] = packCF(spot.Rest) end
    data.Portals = {}
    for name, cf in pairs(PortalSpots) do data.Portals[name] = packCF(cf) end
    if BossSpot then data.Boss = { CFrame = packCF(BossSpot.CFrame), Size = { BossSpot.Size.X, BossSpot.Size.Y, BossSpot.Size.Z } } end
    pcall(function()
        if not isfolder("TSR") then makefolder("TSR") end
        writefile(SPOTS_FILE, HttpService:JSONEncode(data))
    end)
end

do 
    local folder = workspace:FindFirstChild("Eggs")
    for _, egg in ipairs(folder and folder:GetChildren() or {}) do EggSpots[egg.Name] = egg:GetPivot() end
    loadSpots()
end


local function eggIslandOpen(d, name)
    local cfg = EggConfig[name]
    local island, zone = cfg.Island, cfg.Zone

    if zone and zone ~= "Spawn" and not d.Progression.UnlockedZones[zone] then return false end
    return island == nil or island == "Spawn" or d.Progression.UnlockedIslands[island] == true
end


local function hatchCount(d, name)
    local wanted = State.HatchAmount
    if wanted ~= "Max affordable" then return tonumber(wanted) end
    local coins = d.Currencies.Coins
    if (GamepassPerks.Has(d, "x8Egg") or BoostFormula.HasType(d, "OctoHatch")) and eggCost(d, name, 8) <= coins then
        return 8
    end
    if eggCost(d, name, 3) <= coins then return 3 end
    if eggCost(d, name, 1) <= coins then return 1 end
    return nil
end

local function pickEgg(d)
    if State.SelectedEgg ~= "Best affordable" then
        return State.SelectedEgg
    end
    for i = #EggList, 1, -1 do
        local name = EggList[i].Name
        if (eggModel(name) or EggSpots[name]) and eggIslandOpen(d, name) and eggCost(d, name, 1) <= d.Currencies.Coins then
            return name
        end
    end
    return nil
end

local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChildOfClass("Humanoid")
end

local function positionOf(target)
    if typeof(target) == "Vector3" then return target end
    if target:IsA("Model") then return target:GetPivot().Position end
    if target:IsA("BasePart") then return target.Position end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function standingSpot(target, distance)
    local pivot, size
    if target:IsA("Model") then
        pivot, size = target:GetPivot(), target:GetExtentsSize()
    else
        pivot, size = target.CFrame, target.Size
    end
    local spot = pivot.Position + pivot.LookVector * (size.Z / 2 + distance)

    rayParams.FilterDescendantsInstances = { LocalPlayer.Character, target }
    local hit = workspace:Raycast(spot + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), rayParams)
    if not hit then
        if target:IsA("BasePart") and target.CanCollide then
            return pivot.Position + Vector3.new(0, size.Y / 2 + 3, 0), pivot.Position
        end
        return nil, pivot.Position -- nothing safe to stand on (area not loaded)
    end
    return hit.Position + Vector3.new(0, 3, 0), pivot.Position
end

local function teleportTo(position, facing)
    local root = getRoot()
    if not root then return false end
    local look = facing and Vector3.new(facing.X, position.Y, facing.Z) or position + root.CFrame.LookVector
    if (look - position).Magnitude < 0.1 then look = position + Vector3.new(0, 0, -1) end
    root.CFrame = CFrame.lookAt(position, look)
    root.AssemblyLinearVelocity = Vector3.zero
    return true
end

local function teleportToObject(target, distance)
    if not target then return false end
    local spot, center = standingSpot(target, distance or 5)
    if not spot then return false end
    return teleportTo(spot, center)
end

-- Remember where you're standing, and come back to it later
local function saveSpot()
    local root = getRoot()
    return root and root.CFrame
end

-- Hop into an area that hasn't loaded yet: freeze in place for a moment so
-- you don't fall while the map streams in around you
local function teleportAndLoad(position, seconds)
    local root = getRoot()
    if not root then return false end
    root.CFrame = CFrame.new(position)
    root.AssemblyLinearVelocity = Vector3.zero
    root.Anchored = true
    task.wait(seconds or 2.5)
    root.Anchored = false
    return true
end

local function returnTo(cf)
    local root = getRoot()
    if not (cf and root) or (root.Position - cf.Position).Magnitude < 10 then return end
    teleportAndLoad(cf.Position, 1.5)
    root.CFrame = cf
end

-- Walk to a position. Returns true once within range.
local function walkTo(position, range, timeout, keepGoing)
    local root, hum = getRoot()
    if not (root and hum) then return false end
    local started = os.clock()
    while (root.Position - position).Magnitude > range do
        if not State.Running or not keepGoing() or os.clock() - started > timeout then
            return false
        end
        hum:MoveTo(position)
        task.wait(0.4)
    end
    return true
end

local moveOwner = nil
local function tryLock(owner)
    -- Never pull you out of a Colosseum run (only the mob feature may act then)
    if owner ~= "mobs" and LocalPlayer:GetAttribute("ColosseumActive") == true then return false end
    -- ...or out of the mine while Auto Mine is working
    if owner ~= "mine" and LocalPlayer:GetAttribute("MiningActive") == true then return false end
    if moveOwner == nil or moveOwner == owner then
        moveOwner = owner
        return true
    end
    return false
end
local function unlock(owner)
    if moveOwner == owner then moveOwner = nil end
end

local lockWaiters = 0
local function waitLock(owner, timeout)
    local started = os.clock()
    lockWaiters += 1
    while not tryLock(owner) do
        if not State.Running or os.clock() - started > (timeout or 15) then
            lockWaiters -= 1
            return false
        end
        task.wait(0.25)
    end
    lockWaiters -= 1
    return true
end

env.TSR_MoveStatus = function() return moveOwner, lockWaiters end

local function leaveMine()
    if LocalPlayer:GetAttribute("MiningActive") ~= true then return true end
    local leave = findGameFunction("leave", "MiningController")
    if leave then pcall(leave) end
    local started = os.clock()
    repeat task.wait(0.25) until LocalPlayer:GetAttribute("MiningActive") ~= true or os.clock() - started > 10
    task.wait(1)
    return LocalPlayer:GetAttribute("MiningActive") ~= true
end
Fn.leaveMine = leaveMine

local function travelTo(island, force)
    if not force and LocalPlayer:GetAttribute("CurrentIsland") == island and LocalPlayer:GetAttribute("MiningActive") ~= true then return true end
    leaveMine()
    if not force and LocalPlayer:GetAttribute("CurrentIsland") == island then return true end
    for _ = 1, 2 do
        local result = safe(R.IslandTravel.InvokeServer, R.IslandTravel, { Island = island, Source = "Menu" })
        if result and result.Success then
            task.wait(2.5) -- let the island load in
            return true
        end
        task.wait(3)
    end
    return false
end

local function islandOpen(d, island)
    return island == nil or island == "Spawn" or d.Progression.UnlockedIslands[island] == true
end

local function serverNow()
    return workspace:GetServerTimeNow()
end

local function eggStandSpot(model)
    local body = model:FindFirstChild("Egg")
    local cf, size = model:GetBoundingBox()
    local center = body and body.Position or cf.Position
    local radius = math.max(size.X, size.Z) / 2 + 4
    local baseY = cf.Position.Y - size.Y / 2
    local root = getRoot()

    -- Try the side facing you first, then the rest of the compass
    local dirs = {}
    if root then
        local toMe = (root.Position - center) * Vector3.new(1, 0, 1)
        if toMe.Magnitude > 0.1 then table.insert(dirs, toMe.Unit) end
    end
    for i = 0, 7 do
        local a = i * math.pi / 4
        table.insert(dirs, Vector3.new(math.cos(a), 0, math.sin(a)))
    end

    rayParams.FilterDescendantsInstances = { LocalPlayer.Character, model }
    for _, dir in ipairs(dirs) do
        local spot = center * Vector3.new(1, 0, 1) + dir * radius + Vector3.new(0, baseY, 0)
        local floor = workspace:Raycast(spot + Vector3.new(0, 12, 0), Vector3.new(0, -30, 0), rayParams)
        if floor and math.abs(floor.Position.Y - baseY) < 6 then
            local standAt = floor.Position + Vector3.new(0, 3, 0)
            local blocked = workspace:Raycast(standAt, (Vector3.new(center.X, standAt.Y, center.Z) - standAt), rayParams)
            if not blocked then return standAt, center end
        end
    end
    return standingSpot(model, 3) -- fallback
end

-- Get within hatching range of an egg, by teleport or by walking
local function goToEgg(model)
    local root = getRoot()
    if not root then return false end
    local eggPos = model:GetPivot().Position
    if (root.Position - eggPos).Magnitude <= 9 then return true end

    if State.MoveMode == "Teleport" then
        local spot, center = eggStandSpot(model)
        if not spot then return false end
        teleportTo(spot, center or eggPos)
        task.wait(0.4) -- give the server a moment to see the new position
        return (root.Position - eggPos).Magnitude <= 12
    end
    return walkTo(eggPos, 9, 20, function() return State.AutoHatch end)
end


-- Auto Tap: presses the game's tap key for you
task.spawn(function()
    -- Fallback only if the game function wasn't found: a high counter the server accepts.
    -- (While this fallback runs, your own manual taps won't count.)
    local sequence = 1e6
    while State.Running do
        if State.AutoTap and canTap() then
            if GameTap then
                GameTap("key_e", false, false)
            else
                sequence += 1
                R.Tap:FireServer({ Auto = false, ClientSequence = sequence, Source = "button" })
            end
            -- The client itself never taps faster than every 0.11s, so neither do we
            humanWait(math.max(1 / State.TapsPerSec, 0.12))
        else
            task.wait(0.25)
        end
    end
end)

task.spawn(function()
    while State.Running do
        local d = Data()
        if State.AutoRebirth and d then
            local index = bestRebirthIndex(d)
            if index then
                R.Rebirth:FireServer({ Index = index })
            end
        end
        humanWait(2)
    end
end)

local pausedHatchConns = {}
local function setHatchAnimation(skip)
    State.SkipHatchAnim = skip

    workspace:SetAttribute("HatchAnimation", skip and 3 or 1)
    task.spawn(safe, R.Setting.InvokeServer, R.Setting, { Name = "HatchAnimation", Value = skip and 3 or 1 })
    if skip then
        local ok, conns = pcall(getconnections, R.HatchResult.OnClientEvent)
        for _, c in ipairs(ok and conns or {}) do
            local src = c.Function and select(2, pcall(debug.info, c.Function, "s"))
            if type(src) == "string" and src:find("EggController", 1, true) then
                c:Disable()
                table.insert(pausedHatchConns, c)
            end
        end
    else
        for _, c in ipairs(pausedHatchConns) do pcall(function() c:Enable() end) end
        table.clear(pausedHatchConns)
    end
end

task.spawn(function()
    local seq = 1e6 -- only used by the fallback, see Auto Tap
    while State.Running do
        local d = Data()
        local name = State.AutoHatch and d and pickEgg(d)
        local model = name and eggModel(name)
        if name and not model and EggSpots[name] and lockWaiters == 0 and tryLock("hatch") then
            teleportAndLoad(EggSpots[name].Position + Vector3.new(0, 8, 0), 2) -- let it load in
            unlock("hatch")
            model = eggModel(name)
        end
        local count = model and hatchCount(d, name)

        if count and d.Currencies.Coins >= eggCost(d, name, count) and lockWaiters == 0 and tryLock("hatch") and goToEgg(model) then
            local answered = false
            local conn = R.HatchResult.OnClientEvent:Connect(function(result)
                if type(result) == "table" and result.Egg == name then
                    answered = true
                    if result.Success then
                        Session.Hatched += (result.Rolls or count)
                    end
                end
            end)
  
            local started = os.clock()
            if GameHatch and not State.SkipHatchAnim then
                repeat
                    GameHatch(name, count)
                    task.wait(0.25)
                until answered or not State.AutoHatch or os.clock() - started > 12
            else
                seq += 1
                R.Hatch:FireServer({ Egg = name, Count = count, Auto = false, Seq = seq })
                repeat task.wait(0.1) until answered or os.clock() - started > 8
            end
            conn:Disconnect()
            task.wait(0.1 + math.random() * 0.3) -- tiny human-like pause
            unlock("hatch")
        else
            unlock("hatch")
            task.wait(1)
        end
    end
end)

local UpgradeStatus = "Waiting..."
local function upgradeBuyable(d, name)
    local def = UpgradeConfig.Get(name)
    if not def or def.SkillTreeNode then return false, nil end
    local level = math.floor(d.Upgrades[name] or 0)
    if level >= def.LaunchTotal then return false, nil end
    local zone = UpgradeConfig.GetRetainedRequirement(name, level)
    if zone and not d.Progression.UnlockedZones[zone] then return false, "needs the " .. zone .. " zone" end
    local price = UpgradeConfig.GetPrice(name, level + 1)
    if not price or d.Currencies.Gems < price then return false, "not enough gems" end
    return true
end

task.spawn(function()
    while State.Running do
        local d = Data()
        if State.AutoUpgrade and d then
            local bought, reasons = 0, {}
            for _, name in ipairs(UpgradeConfig.Order) do
                if not State.AutoUpgrade then break end
                local ok, why = upgradeBuyable(d, name)
                if ok then
                    local result = safe(R.Upgrade.InvokeServer, R.Upgrade, { Name = name })
                    if result and result.Success then bought += 1 end
                    if result and result.Reason == "RateLimited" then break end
                    humanWait(1.5)
                elseif why then
                    reasons[why] = true
                end
            end
            local list = {}
            for why in pairs(reasons) do table.insert(list, why) end
            UpgradeStatus = bought > 0 and ("Bought " .. bought .. " upgrade(s)")
                or (#list > 0 and ("Nothing to buy: " .. table.concat(list, ", ")) or "Everything is maxed")
        end
        nap(30, "upgrade")
    end
end)

task.spawn(function()
    while State.Running do
        local d = Data()
        if State.AutoQuests and d and d.Quests then
            for questName, quest in pairs(d.Quests) do
                if type(quest) == "table" and quest.Completed and not quest.Claimed then
                    safe(R.ClaimQuest.InvokeServer, R.ClaimQuest, { Quest = questName })
                    humanWait(1.5)
                end
            end
        end
        nap(10, "quests")
    end
end)


task.spawn(function()
    while State.Running do
        if State.AutoEquipBest then
            R.PetAction:FireServer({ Action = "EquipBest", Mode = "Clicks" })
        end
        nap(30, "equip")
    end
end)

-- Offline rewards: claims them once when pending
task.spawn(function()
    while State.Running do
        local d = Data()
        if State.AutoOffline and d and d.Offline and d.Offline.Pending then
            safe(R.OfflineClaim.InvokeServer, R.OfflineClaim)
        end
        nap(20, "offline")
    end
end)

local SkillPriority = { SkillTreeFormula.AutoClickerNode, SkillTreeFormula.AutoRebirthNode }
local skillRefused  = {}

local function nextSkillNode(d)
    local unlocked, candidates = d.SkillTree.Unlocked, {}
    for name, node in pairs(SkillTreeFormula.Nodes) do
        local refusedAt = skillRefused[name]
        local focus = State.SkillTrees
        local inFocus = next(focus) == nil or table.find(focus, node.Tree) ~= nil
        if not unlocked[name] and inFocus
            and (node.Parent == nil or unlocked[node.Parent])
            and not (refusedAt and os.clock() - refusedAt < 300) then
            local price = SkillTreeFormula.GetPrice(d, name)
            local wallet = d.Currencies[node.Currency or "Gems"] or 0
            if price and wallet >= price then
                candidates[name] = price
            end
        end
    end
    for _, name in ipairs(SkillPriority) do
        if candidates[name] then return name end
    end
    local best, bestPrice
    for name, price in pairs(candidates) do
        if not bestPrice or price < bestPrice then best, bestPrice = name, price end
    end
    return best
end

task.spawn(function()
    while State.Running do
        local d = Data()
        local node = State.AutoSkillTree and d and nextSkillNode(d)
        if node then
            local result = safe(R.SkillUnlock.InvokeServer, R.SkillUnlock, { Name = node })
            if not (result and result.Success) then skillRefused[node] = os.clock() end
            humanWait(1.5)
        else
            nap(10, "skill")
        end
    end
end)

task.spawn(function()
    while State.Running do
        local d = Data()
        if State.GameAutoClick and d and SkillTreeFormula.HasAutoClicker(d)
            and d.Settings.AutoClickerEnabled ~= true then
            R.AutoClick:FireServer({ Enabled = true })
        end
        humanWait(15)
    end
end)

local clickedDucks = setmetatable({}, { __mode = "k" })
local function duckButton()
    local gui = LocalPlayer.PlayerGui:FindFirstChild("LuckyDucky")
    local hit = gui and gui:FindFirstChild("Hit", true)
    if hit and hit:IsA("GuiButton") and hit.Visible then return hit end
end

task.spawn(function()
    while State.Running do
        local hit = State.AutoDucky and duckButton()
        if hit and not clickedDucks[hit] then
            clickedDucks[hit] = true
            task.wait(0.8 + math.random() * 1.2) -- human reaction time (server needs > 0.3s)
            if hit.Parent then
                local ok, conns = pcall(getconnections, hit.Activated)
                for _, c in ipairs(ok and conns or {}) do pcall(function() c:Fire() end) end
            end
        end
        task.wait(0.25)
    end
end)

-- Backup: if a duck spawns but never appears on screen, claim it directly
local duckConn = R.DuckSpawn.OnClientEvent:Connect(function(duck)
    if not (State.Running and State.AutoDucky) then return end
    if type(duck) ~= "table" or type(duck.Id) ~= "string" then return end
    task.spawn(function()
        task.wait(2.5)
        if not duckButton() and not LocalPlayer.PlayerGui:FindFirstChild("LuckyDucky") then
            safe(R.DuckClaim.InvokeServer, R.DuckClaim, duck.Id)
        end
    end)
end)

local rejoinConn = GuiService.ErrorMessageChanged:Connect(function(message)
    if State.Running and State.AutoRejoin and message ~= "" then
        task.wait(5)
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end
end)

local function guardedLoop(lockName, body)
    task.spawn(function()
        while State.Running do
            local ok, err = pcall(body)
            if not ok then
                unlock(lockName)
                warn("[TSR] " .. lockName .. ": " .. tostring(err))
                task.wait(5)
            end
        end
    end)
end

local function tapOnce()
    if GameTap then GameTap("key_e", false, false) end
end

local function breakableAlive(b)
    return b.Parent ~= nil and b:GetAttribute("BreakableBroken") ~= true and b:GetAttribute("BreakableDespawned") ~= true
end

local BreakTargets = { WorldChest = true, MeteorSmall = true, MeteorBig = true, MeteorGolden = true, MysteryEgg = true }
local breakSkip = {} 
local function chestKey(cf) return string.format("%d,%d,%d", cf.X // 4, cf.Y // 4, cf.Z // 4) end

local function nextBreakable()
    local root = getRoot()
    if not root then return nil end
    local best, bestScore
    for _, b in ipairs(CollectionService:GetTagged("Breakable")) do
        local kind = b:GetAttribute("BreakableType")
        local rest = b:GetAttribute("BreakableRest")
        local owner = b:GetAttribute("BreakableOwner")
        local skipped = breakSkip[b] and os.clock() - breakSkip[b] < 120
        if kind == "WorldChest" and typeof(rest) == "CFrame" and not ChestSpots[chestKey(rest)] then
            ChestSpots[chestKey(rest)] = { Rest = rest, CheckedAt = 0 }
        end
        if BreakTargets[kind] and not skipped and breakableAlive(b) and typeof(rest) == "CFrame"
            and (owner == nil or owner == LocalPlayer.UserId) then
            -- Event breakables (meteors, egg drops) first, then the closest chest
            local score = (rest.Position - root.Position).Magnitude
            if kind ~= "WorldChest" then score -= 100000 end
            if not bestScore or score < bestScore then best, bestScore = b, score end
        end
    end
    return best
end

-- A remembered chest spot that's due a revisit and isn't loaded right now
local function staleChestSpot()
    local loaded = {}
    for _, b in ipairs(CollectionService:GetTagged("Breakable")) do
        local rest = b:GetAttribute("BreakableRest")
        if typeof(rest) == "CFrame" then loaded[chestKey(rest)] = true end
    end
    for key, spot in pairs(ChestSpots) do
        if not loaded[key] and os.clock() - spot.CheckedAt > 60 then return spot end
    end
end

local function eventTarget()
    local folder = workspace:FindFirstChild("WorldEventFx")
    if not folder then return nil end
    local root = getRoot()
    local best, bestDist
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") and m.Name:find("Pig") then
            local dist = root and (m:GetPivot().Position - root.Position).Magnitude or 0
            if not bestDist or dist < bestDist then best, bestDist = m, dist end
        end
    end
    return best
end

guardedLoop("chests", function()
    local target = State.AutoWorldChests and nextBreakable()
    local flying = State.AutoWorldChests and not target and eventTarget()
    if target and waitLock("chests", 10) then
        local rest = target:GetAttribute("BreakableRest")
        local size = target:GetAttribute("BreakableSize")
        local reach = (typeof(size) == "Vector3" and math.max(size.X, size.Z) / 2 or 4) + 5
        teleportTo(rest.Position + rest.LookVector * reach + Vector3.new(0, 3, 0), rest.Position)
        task.wait(0.3)
        local started = os.clock()
        local startHealth = target:GetAttribute("BreakableHealth")
        while breakableAlive(target) and State.AutoWorldChests and os.clock() - started < 8 do
            tapOnce()
            task.wait(0.13 + math.random() * 0.03)
            -- No damage after 3s? Our taps can't reach it; skip it for a while
            if os.clock() - started > 3 and target:GetAttribute("BreakableHealth") == startHealth then
                breakSkip[target] = os.clock()
                break
            end
        end
        if not breakableAlive(target) then Session.Chests += 1 end
        unlock("chests")
        task.wait(0.8) -- let other features take their turn
    elseif flying and waitLock("chests", 10) then
        -- Get within ~40 studs (well inside the hit range) and keep tapping
        local pos = flying:GetPivot().Position
        local root = getRoot()
        if root and (root.Position - pos).Magnitude > 60 then
            rayParams.FilterDescendantsInstances = { LocalPlayer.Character, flying }
            local hit = workspace:Raycast(pos, Vector3.new(0, -300, 0), rayParams)
            if hit then teleportTo(hit.Position + Vector3.new(0, 3, 0), pos) end -- only with real ground below
        end
        local started = os.clock()
        while flying.Parent and State.AutoWorldChests and os.clock() - started < 4 do
            tapOnce()
            task.wait(0.13)
        end
        unlock("chests")
    else
        -- Nothing loaded nearby: revisit a remembered chest spot
        local spot = State.AutoWorldChests and staleChestSpot()
        if spot and waitLock("chests", 10) then
            spot.CheckedAt = os.clock()
            teleportAndLoad(spot.Rest.Position + spot.Rest.LookVector * 8 + Vector3.new(0, 6, 0), 1.5)
            unlock("chests")
        else
            task.wait(2)
        end
    end
end)

-- Tap chests (Sky Island, Desert): one big coin chest per island, every 6h ----
local function findTapChest(id)
    for _, model in ipairs(CollectionService:GetTagged(TapChestConfig.Tag)) do
        if model:GetAttribute(TapChestConfig.Attributes.Id) == id then return model end
    end
end

guardedLoop("tapchest", function()
    local d = Data()
    if State.AutoTapChests and d then
        for id, chest in pairs(TapChestConfig.Chests) do
            if State.AutoTapChests and islandOpen(d, chest.Island)
                and serverNow() >= TapChestConfig.GetReadyAt(d, id) and waitLock("tapchest", 20) then
                local home, backSpot = LocalPlayer:GetAttribute("CurrentIsland"), saveSpot()
                if travelTo(chest.Island) then
                    local model = findTapChest(id)
                    local front = model and model:GetAttribute(TapChestConfig.Attributes.Front)
                    local size = model and model:GetAttribute(TapChestConfig.Attributes.Size)
                    if typeof(front) == "CFrame" and typeof(size) == "Vector3" then
                        local spot = front.Position + front.LookVector * (size.Z * 0.5 + 6) + Vector3.new(0, 3, 0)
                        teleportTo(spot, front.Position)
                        task.wait(2.5 + math.random()) -- about how long the 4-6 hits take by hand
                        local result = safe(R.ChestClaim.InvokeServer, R.ChestClaim, id)
                        if result and result.Success then
                            Session.Chests += 1
                            task.delay(3, closeRewardPopups)
                        end
                    end
                    if home and home ~= chest.Island then travelTo(home) end
                    returnTo(backSpot)
                end
                unlock("tapchest")
            end
        end
    end
    nap(30, "tapchest")
end)

-- Shiny stars: 15 hidden one-time collectibles. Finding them all raises your
-- shiny mutation chance. We stand on each star and the game picks it up.
guardedLoop("stars", function()
    local d = Data()
    if State.AutoStars and d then
        -- Which unlocked islands still have stars to find?
        local islands = {}
        for _, star in pairs(ShinyStarConfig.Stars) do
            if not d.ShinyStars.Found[star.Id] and islandOpen(d, star.Island) then
                islands[star.Island or "Spawn"] = true
            end
        end
        for island in pairs(islands) do
            if not State.AutoStars or not waitLock("stars", 20) then break end
            local home, backSpot = LocalPlayer:GetAttribute("CurrentIsland"), saveSpot()
            if travelTo(island) then
                local folder = workspace:FindFirstChild(ShinyStarConfig.Folder)
                for _, star in ipairs(folder and folder:GetChildren() or {}) do
                    local id = star:GetAttribute(ShinyStarConfig.IdAttribute) or star.Name
                    if not d.ShinyStars.Found[id] then
                        teleportTo(positionOf(star))
                        task.wait(1.5)
                        if d.ShinyStars.Found[id] then Session.Stars += 1 end
                    end
                end
                if home and home ~= island then travelTo(home) end
                returnTo(backSpot)
            end
            unlock("stars")
        end
    end
    nap(60, "stars")
end)

-- Trick-or-treat (Halloween event): knock on each house every 30 minutes ----
local TrickPads = {} -- [houseId] = zone position, remembered once seen
local function scanTrickPads()
    local folder = workspace:FindFirstChild("HalloweenIsland")
    if not folder then return end
    for _, d in ipairs(folder:GetDescendants()) do
        if d.Name == "TrickOrTreat" and d:IsA("Model") then
            local id, zone = d:GetAttribute("HouseId"), d:FindFirstChild("Zone")
            if id and zone then TrickPads[id] = zone.Position end
        end
    end
end

local trickBackoffUntil = 0
local TrickStatus = ""
guardedLoop("trick", function()
    local d = Data()
    if State.AutoTrickTreat and d and os.clock() > trickBackoffUntil then
        if LocalPlayer:GetAttribute("CurrentIsland") ~= "Spawn" and waitLock("trick", 20) then
            travelTo("Spawn") -- the Halloween island hangs off the Spawn island
            unlock("trick")
        end
        scanTrickPads()
        -- Haven't seen the houses yet? Hop next to one so the rest load in.
        if next(TrickPads) == nil and waitLock("trick", 20) then
            local folder = workspace:FindFirstChild("HalloweenIsland")
            for _, m in ipairs(folder and folder:GetDescendants() or {}) do
                if m.Name == "House" and m:IsA("Model") then
                    -- Far houses are empty shells until you get close
                    teleportAndLoad(m:GetPivot().Position + Vector3.new(0, 12, 0), 3)
                    scanTrickPads()
                    break
                end
            end
            unlock("trick")
        end
        local backSpot, refusals = nil, 0
        for id, zonePos in pairs(TrickPads) do
            local readyAt = tonumber(d.TrickOrTreat[id]) or 0
            if State.AutoTrickTreat and serverNow() >= readyAt and waitLock("trick", 20) then
                backSpot = backSpot or saveSpot()
                teleportTo(zonePos)
                task.wait(0.8)
                local result = safe(R.Knock.InvokeServer, R.Knock, id)
                unlock("trick")
                if result and result.Success then
                    Session.Knocks += 1
                    refusals = 0
                    TrickStatus = "Knocked " .. id
                elseif result and result.Reason then
                    -- That house said "come back later": skip it and try the next.
                    -- Three refusals in a row means something's off (event over?): wait 5 min.
                    TrickStatus = id .. ": " .. tostring(result.Reason)
                    refusals += 1
                    if refusals >= 3 then
                        trickBackoffUntil = os.clock() + 300
                        break
                    end
                else
                    TrickStatus = id .. ": no answer"
                end
                task.wait(1 + math.random())
            end
        end
        if backSpot and waitLock("trick", 20) then
            returnTo(backSpot)
            unlock("trick")
        end
    end
    nap(30, "trick")
end)

-- Boosts: drink potions/boosts you own whenever that boost isn't running ----
guardedLoop("boosts", function()
    local d = Data()
    if State.AutoBoosts and d then
        for name, owned in pairs(d.Boosts) do
            local timeLeft = tonumber(d.ActiveBoosts[name]) or 0
            if type(owned) == "number" and owned > 0 and timeLeft <= 2 then
                safe(R.UseBoost.InvokeServer, R.UseBoost, name)
                humanWait(2)
            end
        end
    end
    nap(20, "boosts")
end)

-- Pet index: claim the reward for every egg whose page you've completed ----
task.spawn(function()
    while State.Running do
        local d = Data()
        if State.AutoIndex and d then
            local ok, list = pcall(PetIndexCatalog.Claimables, d.Pets)
            local done = {}
            for _, item in ipairs(ok and list or {}) do
                if item.Kind == "Egg" and not done[item.Name] then
                    done[item.Name] = true
                    R.IndexClaim:FireServer(item.Name)
                    humanWait(1.5)
                end
            end
        end
        nap(60, "index")
    end
end)

-- Reward popups ------------------------------------------------------
-- Some rewards open a screen you'd normally have to click away (the
-- "Crafted! GOLDEN!" result, reward cards, dig rewards). We press the game's
-- own Continue button / call its own Close, so nothing piles up while AFK.
local function pressButton(button)
    local ok, conns = pcall(getconnections, button.Activated)
    for _, c in ipairs(ok and conns or {}) do pcall(function() c:Fire() end) end
end

local function craftingRollScreen()
    local tabs = LocalPlayer.PlayerGui:FindFirstChild("Tabs")
    local roll = tabs and tabs:FindFirstChild("CraftingRoll")
    if roll and roll:IsA("ScreenGui") and roll.Enabled then return roll end
end

local function closeCraftingRoll()
    local roll = craftingRollScreen()
    local continue = roll and roll:FindFirstChild("Continue", true)
    local button = continue and (continue:IsA("GuiButton") and continue or continue:FindFirstChildWhichIsA("GuiButton"))
    if button then pressButton(button) return true end
    return false
end

local function closeRewardPopups()
    closeCraftingRoll()
    if RewardPopupController then
        pcall(function()
            if RewardPopupController:IsOpen() then RewardPopupController:Close() end
        end)
    end
    if DigRewardPopup then pcall(function() DigRewardPopup:Close() end) end
end

-- Close a popup a little after it opens (so its animation can play first)
local popupSeen = {}
local function closeAfter(key, isOpen, close, delay)
    if isOpen() then
        popupSeen[key] = popupSeen[key] or os.clock()
        if os.clock() - popupSeen[key] >= delay then
            close()
            popupSeen[key] = nil
        end
    else
        popupSeen[key] = nil
    end
end

-- HUD safety net: minigames hide the main HUD and restore it when they end.
-- If it's still hidden a few seconds after you've left them, turn it back on.
local HudScreens = { "Game", "RightHud", "RightHudButtons", "RightHudButtonsReflection", "PinnedQuest" }
local hudHiddenSince
local function hudGuard()
    local busy = LocalPlayer:GetAttribute("MiningActive") == true or LocalPlayer:GetAttribute("ColosseumActive") == true
    local game_ = LocalPlayer.PlayerGui:FindFirstChild("Game")
    if busy or not game_ or game_.Enabled then hudHiddenSince = nil return end
    hudHiddenSince = hudHiddenSince or os.clock()
    if os.clock() - hudHiddenSince > 4 then
        for _, name in ipairs(HudScreens) do
            local screen = LocalPlayer.PlayerGui:FindFirstChild(name)
            if screen and screen:IsA("ScreenGui") then screen.Enabled = true end
        end
        hudHiddenSince = nil
    end
end

task.spawn(function()
    while State.Running do
        pcall(hudGuard)
        if State.AutoClosePopups then
            closeAfter("roll", function() return craftingRollScreen() ~= nil end, closeCraftingRoll, 1.5)
            if RewardPopupController then
                closeAfter("reward", function()
                    local ok, open = pcall(function() return RewardPopupController:IsOpen() end)
                    return ok and open
                end, function() pcall(function() RewardPopupController:Close() end) end, 2.5)
            end
        end
        task.wait(0.5)
    end
end)

-- "12:34" / "1:02:03"
local function clockText(seconds)
    seconds = math.max(0, math.floor(seconds))
    local h, m, sec = seconds // 3600, (seconds % 3600) // 60, seconds % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, sec) end
    return string.format("%d:%02d", m, sec)
end

-- Pet crafting: Golden (6 normals), Diamond (5 goldens), Rainbow (2-5 diamonds) ----
-- Only uses pets that aren't equipped or locked, and only 100% recipes.
-- Every island has its own Golden machine, so we use the closest one.
local function machinePoint(name)
    local root = getRoot()
    local best, bestDist
    for _, point in ipairs(CollectionService:GetTagged("InteractionPoint")) do
        if point.Name == name and point:IsA("BasePart") then
            local dist = root and (point.Position - root.Position).Magnitude or 0
            if not bestDist or dist < bestDist then best, bestDist = point, dist end
        end
    end
    if best then
        MachinePoints[name] = best.CFrame
        return best.CFrame
    end
    return MachinePoints[name]
end

-- The machine menus the game opens when you stand at a machine
local MachineMenus = { Golden = "Golden", Diamond = "Diamond", Rainbow = "RainbowFuse" }
local function closeMachineMenu(point)
    pcall(function() MenuController:Close(MachineMenus[point]) end)
    -- The "Crafted!" result screen can pop up a moment later: press Continue
    task.delay(1.5, closeCraftingRoll)
    task.delay(4, closeCraftingRoll)
end

-- Status text for the Crafting section
local CraftStatus = { Golden = "", Diamond = "", Rainbow = "" }

-- Group spare pets of one tier by species: { Bear = {id, id, ...}, ... }
local function sparePets(d, tier)
    local equipped = {}
    for _, id in pairs(d.Pets.Equipped) do equipped[id] = true end
    local groups = {}
    for id, pet in pairs(d.Pets.Owned) do
        if pet.Tier == tier and not equipped[id] and not pet.Locked and pet.Frozen == nil then
            groups[pet.Name] = groups[pet.Name] or {}
            table.insert(groups[pet.Name], id)
        end
    end
    return groups
end

-- Stand at a machine. Returns true if we're there.
local function goToMachine(name)
    local cf = machinePoint(name)
    if not cf then return false end
    teleportTo(cf.Position + cf.LookVector * 4 + Vector3.new(0, 1, 0), cf.Position)
    task.wait(0.6)
    return true
end

local function craftAndWait(payload)
    local answered, crafted = false, false
    local conn = R.CraftResult.OnClientEvent:Connect(function(result)
        if type(result) == "table" and result.Machine == payload.Machine then
            answered, crafted = true, result.Success == true
        end
    end)
    R.Craft:FireServer(payload)
    local started = os.clock()
    repeat task.wait(0.1) until answered or os.clock() - started > 6
    conn:Disconnect()
    if crafted then Session.Crafted += 1 end
    return crafted
end

-- Go to a machine once, do all the work there, close its menu, walk away.
local function machineSession(point, work)
    if not machinePoint(point) then
        CraftStatus[point] = "Machine not found yet (it's on an island you haven't reached)"
        return
    end
    if not waitLock("craft", 20) then return end
    local back = saveSpot()
    if goToMachine(point) then
        pcall(work)
        closeMachineMenu(point)
        task.wait(0.3)
        returnTo(back)
    end
    unlock("craft")
end

local function runCrafts(machine, enabledKey)
    local d = Data()
    local cfg = MachineConfig[machine]
    local need = #cfg.Chances -- copies for a 100% craft
    local batches = {}
    for _, ids in pairs(sparePets(d, cfg.SourceTier)) do
        while #ids >= need do
            local batch = {}
            for i = 1, need do batch[i] = table.remove(ids) end
            table.insert(batches, batch)
        end
    end
    if #batches == 0 then
        CraftStatus[machine] = "Waiting for " .. need .. " spare copies of one " .. cfg.SourceTier .. " pet"
        return
    end
    machineSession(machine, function()
        local made = 0
        for _, batch in ipairs(batches) do
            if not State[enabledKey] then break end
            if not craftAndWait({ Action = "Craft", Machine = machine, PetIds = batch }) then break end
            made += 1
            humanWait(1.2)
        end
        CraftStatus[machine] = "Crafted " .. made .. " " .. cfg.TargetTier .. " pet(s)"
    end)
end

local function runRainbow()
    local d = Data()
    local cfg = MachineConfig.Shiny
    local queue = d.Machines.Shiny.Queue
    local ready, used, starts = {}, 0, {}
    for craftId, entry in pairs(queue) do
        used += 1
        if type(entry) == "table" and (entry.EndTime or math.huge) <= serverNow() then table.insert(ready, craftId) end
    end
    for _, ids in pairs(sparePets(d, cfg.SourceTier)) do
        if used + #starts >= cfg.MaxQueue then break end
        if #ids >= cfg.MinPets then
            local batch = {}
            for i = 1, math.min(#ids, #cfg.Durations) do batch[i] = ids[i] end -- up to 5 = fastest
            table.insert(starts, batch)
        end
    end
    if #ready == 0 and #starts == 0 then
        CraftStatus.Rainbow = used > 0 and (used .. " fuse(s) cooking") or "Waiting for 2+ spare copies of one Diamond pet"
        return
    end
    machineSession("Rainbow", function()
        for _, craftId in ipairs(ready) do
            R.Craft:FireServer({ Machine = "Shiny", Action = "Claim", CraftId = craftId })
            Session.Crafted += 1
            task.wait(1.5)
        end
        for _, batch in ipairs(starts) do
            if not State.AutoRainbow then break end
            R.Craft:FireServer({ Machine = "Shiny", Action = "Start", PetIds = batch })
            task.wait(1.5)
        end
        CraftStatus.Rainbow = "Claimed " .. #ready .. ", started " .. #starts
    end)
end

guardedLoop("craft", function()
    if Data() then
        if State.AutoGolden then pcall(runCrafts, "Golden", "AutoGolden") end
        if State.AutoDiamond then pcall(runCrafts, "Diamond", "AutoDiamond") end
        if State.AutoRainbow then pcall(runRainbow) end
        unlock("craft") -- in case one of them stopped early
    end
    nap(20, "craft")
end)

-- Double jumps: each island has a "+1 Jump" machine. Buy the next one when
-- you can afford it, by standing next to that island's machine.
local JumpUpgrade = PhysicalUpgradeConfig.Get("+1 Jump")
local JumpStatus = ""

local function jumpMachine(island)
    local islandModel = workspace:FindFirstChild("Ts2Islands") and workspace.Ts2Islands:FindFirstChild(island)
    for _, m in ipairs(CollectionService:GetTagged("DoubleJumpMachine")) do
        if islandModel and m:IsDescendantOf(islandModel) then return m end
    end
end

guardedLoop("jumps", function()
    local d = Data()
    if State.AutoJumps and d and JumpUpgrade then
        local nextIndex = PhysicalUpgradeConfig.GetOwned(d, JumpUpgrade) + 1
        local price = PhysicalUpgradeConfig.GetPrice(JumpUpgrade, nextIndex)
        local island = JumpUpgrade.Islands and JumpUpgrade.Islands[nextIndex]
        local wallet = d.Currencies[JumpUpgrade.Currency] or 0
        if not price or not island then
            JumpStatus = "All double jumps bought"
        elseif not islandOpen(d, island) then
            JumpStatus = "Next jump needs " .. island
        elseif wallet < price then
            JumpStatus = "Next jump costs " .. price .. " " .. JumpUpgrade.Currency
        elseif waitLock("jumps", 20) then
            local home, back = LocalPlayer:GetAttribute("CurrentIsland"), saveSpot()
            if travelTo(island) then
                local machine = jumpMachine(island)
                local spot, center = machine and eggStandSpot(machine)
                if spot then
                    teleportTo(spot, center)
                    task.wait(0.8)
                    local result = safe(R.BuyPhysical.InvokeServer, R.BuyPhysical, { Upgrade = "+1 Jump", Index = nextIndex })
                    JumpStatus = (result and result.Success) and ("Bought jump #" .. nextIndex)
                        or ("Couldn't buy: " .. tostring(result and result.Reason))
                end
                if home and home ~= island then travelTo(home) end
                returnTo(back)
            end
            unlock("jumps")
        end
    end
    nap(30, "jumps")
end)

-- Colosseum mobs: while you're in the Colosseum minigame, attack the most
-- urgent opponent using the game's own attack (it respects the game's cooldown).
-- With Auto Start on, we also start a new run whenever its 30 min cooldown is up.
local ColosseumAttack = findGameFunction("onAttackInput", "ColosseumController")
local ColosseumStart = findGameFunction("attemptStartGame", "ColosseumController")
local ColosseumAdapter = select(2, pcall(require, ReplicatedStorage.Controllers.Minigames.ColosseumClientAdapter))
local MobStatus = ""

local function colosseumActive()
    return LocalPlayer:GetAttribute("ColosseumActive") == true
end

local function colosseumCooldownLeft()
    local ok, data = pcall(function() return ColosseumAdapter.Replication.Data end)
    local last = ok and type(data) == "table" and tonumber(data.WaveDefenseCooldown) or 0
    return math.max(0, last + 1800 - os.time())
end

local function fightMobs()
    while State.AutoMobs and State.Running and colosseumActive() do
        pcall(ColosseumAttack, nil)
        task.wait(0.12 + math.random() * 0.05)
    end
end

guardedLoop("mobs", function()
    if State.AutoMobs and ColosseumAttack and colosseumActive() then
        MobStatus = "Fighting!"
        fightMobs()
    elseif State.AutoMobs and State.AutoStartColosseum and ColosseumStart then
        local left = colosseumCooldownLeft()
        if left > 0 then
            MobStatus = "Next run in " .. math.ceil(left / 60) .. " min"
        elseif waitLock("mobs", 30) then
            local home, back = LocalPlayer:GetAttribute("CurrentIsland"), saveSpot()
            travelTo("Spawn")
            local arena = workspace:FindFirstChild("WaveDefence Island")
            local point = arena and arena:FindFirstChild("WaveDefense") and arena.WaveDefense:FindFirstChild("Colosseum")
            if point then
                teleportAndLoad(point.Position + Vector3.new(0, 3, 0), 1.5)
                task.spawn(ColosseumStart) -- the game's own "Play" button
                local started = os.clock()
                repeat task.wait(0.2) until colosseumActive() or os.clock() - started > 10
                MobStatus = "Fighting!"
                fightMobs()
                task.wait(4) -- let the game show the results
            else
                MobStatus = "Couldn't find the Colosseum"
            end
            if home and home ~= "Spawn" then travelTo(home) end
            returnTo(back)
            unlock("mobs")
        end
    else
        MobStatus = State.AutoMobs and "Waiting for you to start a Colosseum run" or ""
    end
    nap(2, "mobs")
end)

-- Hallow Lord boss (Halloween event): a fight starts every hour. We stand on
-- the boss platform and tap. When it throws bombs we jump to the spot on the
-- platform that's furthest from every bomb before they land.
local BossStatus = ""

local function bossState()
    local ok, st = pcall(function() return HallowBossController:GetDebugState() end)
    return ok and type(st) == "table" and st or { Phase = "Idle" }
end

-- The game's boss controller keeps a reference to the platform part, even
-- when that part of the map isn't loaded. We borrow it as a fallback.
local BossRefresh = findGameFunction("refreshPosition", "HallowBossController")

local function findBossPlatform()
    for _, part in ipairs(CollectionService:GetTagged(HallowBossConfig.PlatformTag)) do
        if part:IsA("BasePart") then
            BossSpot = { CFrame = part.CFrame, Size = part.Size }
            return BossSpot
        end
    end
    if not BossSpot and BossRefresh then
        for _, v in pairs(debug.getupvalues(BossRefresh)) do
            if typeof(v) == "Instance" and v:IsA("BasePart") and v.Name == HallowBossConfig.PlatformTag then
                BossSpot = { CFrame = v.CFrame, Size = v.Size }
            end
        end
    end
    return BossSpot
end

-- A point on top of the platform. x/z go from -1 to 1 across it.
local function platformPoint(x, z)
    local cf, size = BossSpot.CFrame, BossSpot.Size
    local margin = 5
    local local_ = Vector3.new(x * (size.X / 2 - margin), size.Y / 2 + 3, z * (size.Z / 2 - margin))
    return cf:PointToWorldSpace(local_)
end

local bossDodgeConn = R.BossAttack.OnClientEvent:Connect(function(attack)
    if not (State.AutoBoss and moveOwner == "boss" and BossSpot) then return end
    if type(attack) ~= "table" or type(attack.Targets) ~= "table" then return end
    local radius = (tonumber(attack.Radius) or HallowBossConfig.BombRadius) + 4
    local root = getRoot()
    if not root then return end

    local function safety(pos) -- distance to the closest bomb
        local closest = math.huge
        for _, t in ipairs(attack.Targets) do
            if typeof(t) == "Vector3" then
                closest = math.min(closest, (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(t.X, 0, t.Z)).Magnitude)
            end
        end
        return closest
    end

    if safety(root.Position) > radius then return end -- already safe
    -- Try a 7x7 grid on the platform and pick the safest point
    local best, bestScore
    for ix = -3, 3 do
        for iz = -3, 3 do
            local pos = platformPoint(ix / 3, iz / 3)
            local score = safety(pos)
            if not bestScore or score > bestScore then best, bestScore = pos, score end
        end
    end
    if best then teleportTo(best, BossSpot.CFrame.Position) end
end)

guardedLoop("boss", function()
    local st = bossState()
    local fighting = st.Phase == "Warning" or st.Phase == "Fight"
    if State.AutoBoss then
        local nextStart = HallowBossConfig.NextStart(serverNow())
        BossStatus = fighting and ("Fighting! Damage: " .. tostring(st.MyDamage or 0))
            or ("Next fight in " .. math.floor((nextStart - serverNow()) / 60) .. " min")
    end
    if State.AutoBoss and fighting and waitLock("boss", 30) then
        local home, back = LocalPlayer:GetAttribute("CurrentIsland"), saveSpot()
        travelTo("Spawn") -- the Halloween island is next to the Spawn island
        if not findBossPlatform() then
            -- Platform not seen yet: hop to the Halloween island so it loads
            local caudron = workspace:FindFirstChild("HalloweenIsland") and workspace.HalloweenIsland:FindFirstChild("Caudron")
            if caudron then teleportAndLoad(caudron:GetPivot().Position + Vector3.new(0, 15, 0), 3) end
            findBossPlatform()
        end
        if BossSpot then
            teleportAndLoad(platformPoint(math.random() - 0.5, math.random() - 0.5), 1.5)
            while State.AutoBoss and State.Running do
                st = bossState()
                if st.Phase ~= "Warning" and st.Phase ~= "Fight" then break end
                BossStatus = (st.Phase == "Warning" and "Waiting on the platform..." or "Fighting!")
                    .. " Damage: " .. tostring(st.MyDamage or 0) .. (st.Rank and (" (rank #" .. st.Rank .. ")") or "")
                tapOnce()
                -- Knocked off the platform? Get back on.
                local root = getRoot()
                if root and (root.Position - BossSpot.CFrame.Position).Magnitude > math.max(BossSpot.Size.X, BossSpot.Size.Z) then
                    teleportTo(platformPoint(0, 0), BossSpot.CFrame.Position)
                end
                task.wait(0.13 + math.random() * 0.03)
            end
            task.wait(3) -- stay for the reward
            task.delay(3, closeRewardPopups)
        else
            BossStatus = "Couldn't find the boss platform"
        end
        if home and home ~= "Spawn" then travelTo(home) end
        returnTo(back)
        unlock("boss")
    end
    nap(fighting and 1 or 5, "boss")
end)

do
-- Auto Dig (Autumn): a timing game, 10 digs per hour. We stand in the dig
-- zone and press the game's own dig button when the cursor is in the sweet spot.

local function digSession()
    if not DigController then return nil end
    for _, v in pairs(debug.getupvalues(DigController.Activate)) do
        if type(v) == "table" and type(v.Round) == "table" and v.Id ~= nil then return v end
    end
end

local function digsLeft(d)
    if type(d.Digging) ~= "table" then return 0, 0 end
    return DigConfig.Allowance(d.Digging, os.time())
end
Fn.digsLeft = digsLeft

local function digZone()
    local autumn = workspace:FindFirstChild("Ts2Islands") and workspace.Ts2Islands:FindFirstChild("Autumn")
    local site = autumn and autumn:FindFirstChild("Digsite")
    return site and site:FindFirstChild("DigZone")
end

-- Play one dig round to the end. Returns true if it finished.
local function playDig()
    pcall(function() DigController:Activate() end) -- Begin
    local started = os.clock()
    repeat task.wait(0.1) until digSession() or os.clock() - started > 4
    while State.AutoDig and State.Running and os.clock() - started < 120 do
        local session = digSession()
        if not session then return true end -- round finished
        local round, now = session.Round, serverNow()
        if now >= (round.Epoch or 0) then
            local cursor = DigConfig.Cursor(round, now)
            -- aim for the middle of the target zone ("PERFECT")
            if math.abs(cursor - round.Center) <= round.Width * 0.15 then
                pcall(function() DigController:Activate() end)
                task.wait(DigConfig.MinHitInterval + 0.05)
            end
        end
        RunService.Heartbeat:Wait()
    end
    return false
end

guardedLoop("dig", function()
    local d = Data()
    if State.AutoDig and d and DigController then
        local left, resetIn = digsLeft(d)
        if not islandOpen(d, "Autumn") then
            Status.Dig = "Unlock Autumn first"
        elseif left <= 0 then
            Status.Dig = "Out of digs. Refill in " .. clockText(resetIn)
        elseif waitLock("dig", 20) then
            local home, back = LocalPlayer:GetAttribute("CurrentIsland"), saveSpot()
            if travelTo("Autumn") then
                local zone = digZone()
                if zone then
                    teleportAndLoad(zone.Position + Vector3.new(0, 3, 0), 1)
                    task.wait(1)
                    while State.AutoDig and digsLeft(Data()) > 0 do
                        Status.Dig = "Digging... (" .. digsLeft(Data()) .. " left)"
                        playDig()
                        task.wait(2.5) -- reward reveal
                        closeRewardPopups()
                        task.wait(0.5)
                    end
                else
                    Status.Dig = "Couldn't find the dig site"
                end
            end
            if home and home ~= "Autumn" then travelTo(home) end
            returnTo(back)
            unlock("dig")
        end
    end
    nap(10, "dig")
end)

end

do
-- Auto Pop Balloons (Balloon Party event): stay in range and use the game's
-- own "hit nearest balloon" action, which has its own per-balloon cooldown.
local BalloonTrigger = findGameFunction("onTrigger", "BalloonPartyEffects")
local function nearestBalloon()
    local folder = workspace:FindFirstChild("WorldEventFx")
    local root = getRoot()
    local best, bestDist
    for _, m in ipairs(folder and folder:GetChildren() or {}) do
        if m:IsA("Model") and m.Name:sub(1, 8) == "Balloon_" then
            local dist = root and (m:GetPivot().Position - root.Position).Magnitude or math.huge
            if not bestDist or dist < bestDist then best, bestDist = m, dist end
        end
    end
    return best, bestDist
end

guardedLoop("balloons", function()
    if State.AutoBalloons and BalloonTrigger then
        local balloon, dist = nearestBalloon()
        if balloon then
            if dist > 110 and waitLock("balloons", 10) then
                local pos = balloon:GetPivot().Position
                rayParams.FilterDescendantsInstances = { LocalPlayer.Character, balloon }
                local hit = workspace:Raycast(pos, Vector3.new(0, -400, 0), rayParams)
                if hit then teleportTo(hit.Position + Vector3.new(0, 3, 0), pos) end
                unlock("balloons")
            end
            pcall(BalloonTrigger)
            task.wait(0.12)
            return
        end
    end
    nap(2, "balloons")
end)

end

do
-- Auto NPC Quests: talks to quest NPCs, collects their hidden items, and
-- waits on the tap / hatch / island steps (those finish by themselves).

local function npcModel(lineId)
    for _, v in ipairs(CollectionService:GetTagged("Interactable")) do
        local id = v:GetAttribute("InteractableId")
        if type(id) == "string" then
            local line = NpcQuestConfig.LineForNpc(id)
            if line == lineId or (type(line) == "table" and line.Id == lineId) then return v end
        end
    end
end

local function talkTo(lineId)
    travelTo("Spawn")
    local npc = npcModel(lineId)
    if not npc then return false, "NPC not around (some quests unlock after Greg's training)" end
    local spot, center = eggStandSpot(npc)
    if spot then teleportTo(spot, center) task.wait(0.8) end
    local result = safe(R.NpcTalk.InvokeServer, R.NpcTalk, { Line = lineId })
    return result and result.Success, result and result.Reason
end

guardedLoop("npc", function()
    local d = Data()
    if State.AutoNpcQuests and d then
        local notes = {}
        for lineId, line in pairs(NpcQuestConfig.Lines) do
            local entry = NpcQuestConfig.GetEntry(d, lineId)
            local step = NpcQuestConfig.CurrentStep(line, entry)
            if entry and entry.Done then
                table.insert(notes, line.Title .. ": done")
            elseif line.Unlock and not NpcQuestConfig.HasUnlock(d, line.Unlock) and not entry then
                table.insert(notes, line.Title .. ": not unlocked yet")
            elseif not entry or (step and step.Kind == "Talk") then
                if waitLock("npc", 20) then
                    local back = saveSpot()
                    local ok, why = talkTo(lineId)
                    returnTo(back)
                    unlock("npc")
                    table.insert(notes, line.Title .. ": " .. (ok and "talked" or tostring(why)))
                end
            elseif step and step.Kind == "Collect" then
                local cores = NpcQuestConfig.OpenCores(line, entry)
                if #cores > 0 and waitLock("npc", 20) then
                    local back = saveSpot()
                    travelTo("Spawn")
                    for _, core in ipairs(cores) do
                        teleportAndLoad(core.Position + Vector3.new(0, 3, 0), 1)
                        safe(R.NpcCollect.InvokeServer, R.NpcCollect, { Line = lineId, Core = core.Id })
                        task.wait(0.8)
                    end
                    returnTo(back)
                    unlock("npc")
                end
                table.insert(notes, line.Title .. ": collecting " .. step.Title)
            elseif step then
                table.insert(notes, line.Title .. ": waiting on '" .. step.Title .. "'")
            end
        end
        Status.Npc = table.concat(notes, "\n")
    end
    nap(20, "npc")
end)

end

do
-- Auto Shrine Blessing (Autumn): keeps the blessing you picked. Switching
-- resets the tier timer, so we only act when your blessing is different.
local ShrineSpot = nil

local function shrinePrompt()
    local ok, att = pcall(function() return ShrineVisuals and ShrineVisuals.GetPromptAttachment() end)
    if ok and att then ShrineSpot = att.WorldPosition return att.WorldPosition end
end

guardedLoop("shrine", function()
    local d = Data()
    local current = LocalPlayer:GetAttribute(ShrineConfig.Attributes.Blessing)
    if State.AutoShrine and d then
        if not State.ShrineChoice then
            Status.Shrine = "Pick a blessing first"
        elseif current == State.ShrineChoice then
            Status.Shrine = "Blessed with " .. ShrineConfig.Blessings[current].Name
                .. " (tier " .. tostring(LocalPlayer:GetAttribute(ShrineConfig.Attributes.Tier) or 1) .. ")"
        elseif not islandOpen(d, "Autumn") then
            Status.Shrine = "The shrine is on Autumn: unlock it first"
        elseif waitLock("shrine", 20) then
            local home, back = LocalPlayer:GetAttribute("CurrentIsland"), saveSpot()
            if travelTo("Autumn") then
                local pos = shrinePrompt()
                if not pos and ShrineSpot then
                    teleportAndLoad(ShrineSpot + Vector3.new(0, 10, 0), 2)
                    pos = shrinePrompt()
                end
                if pos then
                    teleportAndLoad(pos + Vector3.new(0, 3, 0), 1)
                    task.wait(1) -- let the server see where we're standing before choosing
                    local result = safe(R.ShrineChoose.InvokeServer, R.ShrineChoose, State.ShrineChoice)
                    Status.Shrine = (type(result) == "table" and result.Success == false)
                        and ("Couldn't choose: " .. tostring(result.Reason)) or ("Chose " .. State.ShrineChoice)
                else
                    Status.Shrine = "Couldn't find the shrine"
                end
            end
            if home and home ~= "Autumn" then travelTo(home) end
            returnTo(back)
            unlock("shrine")
        end
    end
    nap(30, "shrine")
end)

end

do
-- Auto Delete Pets: keeps your N strongest pets (and optionally one of every
-- pet, for collecting) and deletes the rest of the tiers you allow.
-- Equipped, locked and Secret pets are never deleted.
local deleteBatch = 5e6
local DeleteTierSets = {
    ["Normal only"]        = { Normal = true },
    ["Normal + Golden"]    = { Normal = true, Golden = true },
    ["All except Rainbow"] = { Normal = true, Golden = true, Diamond = true },
}

local function petPower(pet)
    local ok, power = pcall(PetPower.Get, pet)
    return (ok and tonumber(power)) or tonumber(pet.Power) or 0
end

local function petsToDelete(d)
    local tiers = DeleteTierSets[State.DeleteTiers] or DeleteTierSets["Normal only"]
    local equipped = {}
    for _, id in pairs(d.Pets.Equipped) do equipped[id] = true end

    local list = {}
    for id, pet in pairs(d.Pets.Owned) do table.insert(list, { Id = id, Pet = pet, Power = petPower(pet) }) end
    table.sort(list, function(a, b) return a.Power > b.Power end)

    local keep = {}
    for i = 1, math.min(State.KeepBest, #list) do keep[list[i].Id] = true end
    if State.KeepOneEach then
        local seen = {}
        for _, item in ipairs(list) do -- strongest first, so we keep the best copy
            local key = tostring(item.Pet.Name) .. "|" .. tostring(item.Pet.Tier)
            if not seen[key] then seen[key] = true keep[item.Id] = true end
        end
    end

    local ids = {}
    for _, item in ipairs(list) do
        local pet = item.Pet
        local secret = type(pet.Rarity) == "string" and pet.Rarity:match("^Secret") ~= nil
        local keepRarity = type(pet.Rarity) == "string" and table.find(State.KeepRarities, secret and "Secret" or pet.Rarity) ~= nil
        local craftFodder = State.AutoGolden and pet.Tier == "Normal" -- Auto Golden needs these
        if not keep[item.Id] and not equipped[item.Id] and not pet.Locked and not secret and not keepRarity
            and tiers[pet.Tier] and not craftFodder then
            table.insert(ids, item.Id)
        end
    end
    return ids, #list
end
Fn.petsToDelete = petsToDelete

guardedLoop("delete", function()
    local d = Data()
    if State.AutoDelete and d then
        local ids, total = petsToDelete(d)
        if #ids > 0 then
            for i = 1, #ids, 400 do
                deleteBatch += 1
                R.PetAction:FireServer({ Action = "Delete", PetIds = table.move(ids, i, math.min(i + 399, #ids), 1, {}), Batch = deleteBatch })
                task.wait(1.1)
            end
            Session.Deleted = (Session.Deleted or 0) + #ids
        end
        Status.Delete = "Deleted " .. (Session.Deleted or 0) .. " this session (" .. total .. " pets owned)"
            .. (State.AutoGolden and "\nNormal pets are kept for Auto Golden" or "")
    end
    nap(60, "delete")
end)

end

do
-- Auto Mine (Crystal Cave): breaks blocks with the game's own pickaxe swing,
-- sells ores on the Sell pad when the backpack is full and buys better
-- pickaxes / bags on the Shop pad. Needs you inside the mine (or it walks in).
local MiningConfig = optionalRequire(Shared.Minigames.Mining.MiningConfig)
local MiningSight  = optionalRequire(Shared.Minigames.Mining.MiningSight)
local MiningWorld  = optionalRequire(Shared.Minigames.Mining.MiningWorld)
local MinePurchase = remote("MiningService", "RF", "Purchase")
local swingFn, aimFn
local badCells = {} -- cells we couldn't reach, skipped for a while

-- The mining code is downloaded when you get near the mine, so look for its
-- functions each time until we find them
local function mineFunctions()
    if swingFn and aimFn then return true end
    for _, f in ipairs(getgc(false)) do
        if type(f) == "function" and islclosure(f) then
            local ok, name, source = pcall(debug.info, f, "ns")
            if ok and type(source) == "string" and source:find("MiningController", 1, true) then
                if name == "swing" then swingFn = f elseif name == "aim" then aimFn = f end
            end
        end
    end
    return swingFn ~= nil and aimFn ~= nil
end

-- The mine controller's live state (see its aim() upvalues)
local function mine()
    return {
        Active   = debug.getupvalue(aimFn, 2),  -- in the mine
        Cells    = debug.getupvalue(aimFn, 8),  -- exposed blocks: key -> grid position
        State    = debug.getupvalue(aimFn, 12), -- tool, backpack, balance...
        Marker   = debug.getupvalue(aimFn, 13), -- the mine's origin part
        Removed  = debug.getupvalue(aimFn, 15), -- mined-out cells
    }
end

local function inMine()
    return LocalPlayer:GetAttribute("MiningActive") == true and mineFunctions() and mine().Active == true
end

-- An empty cell next to a block, to stand in while mining it
local function standCell(m, cell)
    local candidates = {
        Vector3.new(0, -1, 0), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
        Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
    }
    for _, off in ipairs(candidates) do
        local c = cell + off
        if c.Y < 0 or m.Removed[MiningConfig.Key(c.X, c.Y, c.Z)] then return c end
    end
end

-- Best block to mine: one your pickaxe can break, as close as possible
local function pickBlock(m, tool, root)
    local best, bestDist
    for key, cell in pairs(m.Cells) do
        local skipUntil = badCells[key]
        if not (skipUntil and os.clock() < skipUntil) then
            local _, stats = MiningConfig.Ore(m.State.Seed, cell.X, cell.Y, cell.Z)
            if stats and (stats.pickaxeRequirement or 0) <= tool.Power then
                local dist = (MiningConfig.Position(m.Marker, cell.X, cell.Y, cell.Z) - root.Position).Magnitude
                if not bestDist or dist < bestDist then best, bestDist = cell, dist end
            end
        end
    end
    return best, bestDist
end

local function onPad(name, untilFn, timeout)
    local pad = MiningWorld.Part(name)
    local root = getRoot()
    if not (pad and root) then return false end
    local back = root.CFrame
    root.CFrame = CFrame.new(pad.Position + Vector3.new(0, 3, 0))
    root.AssemblyLinearVelocity = Vector3.zero
    local started = os.clock()
    repeat task.wait(0.25) until untilFn() or os.clock() - started > timeout
    root.CFrame = back
    return true
end

-- Buy the next pickaxe, then the next bag, when you can afford them
local function upgradeGear(m)
    local st = m.State
    local nextTool = MiningConfig.Tools[(st.Tool or 1) + 1]
    local nextBag = MiningConfig.Bags[(st.Backpack or 1) + 1]
    local buy
    if nextTool and st.Balance >= nextTool.Price then
        buy = { "BuyTool", nextTool.Name }
    elseif nextBag and st.Balance >= nextBag.Price then
        buy = { "BuyStorage", nextBag.Name }
    end
    if not buy then return end
    local pad = MiningWorld.Part("Shop")
    local root = getRoot()
    if not (pad and root) then return end
    local back = root.CFrame
    root.CFrame = CFrame.new(pad.Position + Vector3.new(0, 3, 0))
    root.AssemblyLinearVelocity = Vector3.zero
    task.wait(0.8)
    local result = safe(MinePurchase.InvokeServer, MinePurchase, buy[1], buy[2])
    if type(result) == "table" and not result.Error then
        debug.setupvalue(aimFn, 12, result) -- hand the new state to the game (its u3)
        local presentation = debug.getupvalue(swingFn, 5)
        pcall(function() presentation:Update(result) end)
        Status.Mine = "Bought " .. buy[2]
    elseif type(result) == "table" then
        Status.Mine = "Shop: " .. tostring(result.Error)
    end
    root.CFrame = back
    task.wait(0.5)
end

-- Walk into the mine through its portal on Crystal Cave
local function enterMine()
    if not islandOpen(Data(), "Crystal Cave") then
        Status.Mine = "Unlock Crystal Cave first"
        return false
    end
    travelTo("Crystal Cave")
    local portal = MiningWorld.Portal()
    if not portal then Status.Mine = "Couldn't find the mine portal" return false end
    Status.Mine = "Entering the mine..."
    local root = getRoot()
    for _ = 1, 3 do
        -- The game only lets you in after you've stepped away from the portal
        -- since your last visit, so step back first, then walk into its middle
        teleportAndLoad((portal.CFrame * CFrame.new(0, 2, -20)).Position, 1)
        task.wait(1)
        if root then
            root.CFrame = portal.CFrame
            root.AssemblyLinearVelocity = Vector3.zero
        end
        local started = os.clock()
        repeat task.wait(0.25) until LocalPlayer:GetAttribute("MiningActive") == true or os.clock() - started > 8
        if LocalPlayer:GetAttribute("MiningActive") == true then
            local loaded = os.clock()
            repeat task.wait(0.25) until inMine() or os.clock() - loaded > 10
            Status.Mine = "In the mine"
            return true
        end
    end
    Status.Mine = "Couldn't get into the mine. Try walking into the portal once."
    return false
end
Fn.enterMine = function()
    if inMine() then return true end
    if not waitLock("mine", 20) then return false end
    local ok = enterMine()
    unlock("mine")
    return ok
end

guardedLoop("mine", function()
    if not (State.AutoMine and MiningConfig and MiningWorld) then nap(3, "mine") return end
    if not inMine() then
        if waitLock("mine", 20) then
            enterMine()
            unlock("mine")
        end
        nap(5, "mine")
        return
    end
    if not waitLock("mine", 10) then return end

    local m = mine()
    local st = m.State
    local tool = MiningConfig.Tools[st.Tool or 1]
    local root = getRoot()

    -- Sell when the backpack is full
    if State.AutoSellOres and st.Count >= st.Capacity then
        Status.Mine = "Selling " .. st.Count .. " ores..."
        onPad("Sell", function() return mine().State.Count == 0 end, 6)
        if State.AutoPickaxe then upgradeGear(mine()) end
        unlock("mine")
        return
    end
    if State.AutoPickaxe then upgradeGear(m) m = mine() st = m.State tool = MiningConfig.Tools[st.Tool or 1] end
    if st.Count >= st.Capacity then
        Status.Mine = "Backpack full (turn on Auto Sell Ores)"
        unlock("mine")
        nap(3, "mine")
        return
    end

    local cell, dist = pickBlock(m, tool, root)
    if not cell then
        Status.Mine = next(m.Cells) and ("Every block left needs a better pickaxe than the " .. tool.Name)
            or "Mine cleared! It refills at the daily reset"
        unlock("mine")
        nap(10, "mine")
        return
    end

    -- Too far or out of sight? Stand in an empty cell right next to it
    local eye = root.Position + Vector3.new(0, 1.5, 0)
    if dist > tool.Range - 3 or not MiningSight.CanSee(m.Marker, m.Removed, eye, cell.X, cell.Y, cell.Z) then
        local stand = standCell(m, cell)
        if stand then
            local pos = MiningConfig.Position(m.Marker, stand.X, stand.Y, stand.Z)
            teleportTo(pos + Vector3.new(0, 0.5, 0), MiningConfig.Position(m.Marker, cell.X, cell.Y, cell.Z))
            task.wait(0.3)
        end
        eye = root.Position + Vector3.new(0, 1.5, 0)
        if not MiningSight.CanSee(m.Marker, m.Removed, eye, cell.X, cell.Y, cell.Z) then
            badCells[MiningConfig.Key(cell.X, cell.Y, cell.Z)] = os.clock() + 15
            unlock("mine")
            return
        end
    end

    -- Swing until it breaks (the game's own swing, aimed at our block)
    Status.Mine = string.format("Mining with %s | backpack %d/%d | %d coins", tool.Name, st.Count, st.Capacity, st.Balance)
    local key = MiningConfig.Key(cell.X, cell.Y, cell.Z)
    local started = os.clock()
    while State.AutoMine and m.Cells[key] and os.clock() - started < 12 do
        debug.setupvalue(swingFn, 1, false) -- "ore too strong" flag
        debug.setupvalue(swingFn, 2, cell)  -- the aimed block
        pcall(swingFn)
        task.wait(tool.Interval + 0.03 + math.random() * 0.04)
        if mine().State.Count >= mine().State.Capacity then break end
    end
    if m.Cells[key] then badCells[key] = os.clock() + 15 end
    unlock("mine")
end)
end

do
-- Auto Enchant: rolls enchants on your equipped pets with the game's own
-- auto-enchant at the machine on Shadow Realm, until each pet has an enchant
-- of a rarity you picked. Rare enchants you already own are never replaced.
local EnchantConfig = optionalRequire(Shared.Pets.EnchantConfig)
local Enchant = {
    SetFilters = remote("EnchantService", "RF", "SetFilters"),
    Start      = remote("EnchantService", "RF", "AutoStart"),
    Stop       = remote("EnchantService", "RF", "AutoStop"),
    Event      = remote("EnchantService", "RE", "AutoEvent"),
    Claim      = remote("EnchantService", "RF", "Claim"),
}

-- After a roll stops, the pet waits at the machine until it's claimed
-- (that also puts it back in your team)
local function claimPet()
    safe(Enchant.Claim.InvokeServer, Enchant.Claim)
    task.wait(1)
end
local RankNames = EnchantConfig and EnchantConfig.RankNames or {}
local ENCHANT_ISLAND = "Shadow Realm"

local function rankName(enchant)
    if not (enchant and EnchantConfig) then return nil end
    local ok, rank = pcall(EnchantConfig.RankOf, enchant)
    return ok and RankNames[rank] or nil
end

local function wanted(enchant)
    local name = rankName(enchant)
    return name ~= nil and table.find(State.EnchantRanks, name) ~= nil
end

-- Every equipped pet slot that still needs a roll: { PetId, Slot, Name }
local function enchantJobs(d)
    local jobs, skipped = {}, 0
    for _, petId in pairs(d.Pets.Equipped) do
        local pet = d.Pets.Owned[petId]
        local rarity = pet and (type(pet.Rarity) == "string" and pet.Rarity:match("^Secret") and "Secret" or pet.Rarity)
        local rarityOk = #State.EnchantPetRarities == 0 or table.find(State.EnchantPetRarities, rarity) ~= nil
        if pet and rarityOk then
            local ok, slots = pcall(EnchantConfig.GetSlotCount, pet)
            slots = ok and tonumber(slots) or 1
            for slot = 1, math.max(1, slots) do
                local current = slot == 2 and pet.Enchant2 or pet.Enchant
                if current and EnchantConfig.IsProtected(current) and not wanted(current) then
                    skipped += 1 -- a rare enchant we won't overwrite
                elseif not wanted(current) then
                    table.insert(jobs, { PetId = petId, Slot = slot, Name = tostring(pet.Name) })
                end
            end
        end
    end
    return jobs, skipped
end

local function enchantPoint()
    return machinePoint("Enchant")
end

guardedLoop("enchant", function()
    local d = Data()
    if not (State.AutoEnchant and d and EnchantConfig) then nap(5, "enchant") return end
    if #State.EnchantRanks == 0 then Status.Enchant = "Pick at least one enchant rarity to stop at" nap(5, "enchant") return end
    if not islandOpen(d, ENCHANT_ISLAND) then Status.Enchant = "The enchant machine is on " .. ENCHANT_ISLAND .. ": unlock it first" nap(30, "enchant") return end

    local jobs, skipped = enchantJobs(d)
    if #jobs == 0 then
        Status.Enchant = "All equipped pets have the enchants you want"
            .. (skipped > 0 and (" (" .. skipped .. " rare enchant(s) kept)") or "")
        nap(30, "enchant")
        return
    end
    local ok, price = pcall(EnchantConfig.GetRollPrice, d.Enchanting)
    price = ok and tonumber(price) or 25000
    if d.Currencies.Gems < price then Status.Enchant = "Not enough gems for a roll (" .. math.floor(price) .. " gems)" nap(30, "enchant") return end

    if not waitLock("enchant", 20) then return end
    local home, back = LocalPlayer:GetAttribute("CurrentIsland"), saveSpot()
    if travelTo(ENCHANT_ISLAND) then
        local cf = enchantPoint()
        if cf then
            teleportAndLoad(cf.Position + Vector3.new(0, 3, 0), 1)
            task.wait(0.8)
            -- Tell the game which enchants to stop on
            local names = {}
            for name in pairs(EnchantConfig.Enchants) do
                if wanted(name) and EnchantConfig.IsFilterable(name) then table.insert(names, name) end
            end
            safe(Enchant.SetFilters.InvokeServer, Enchant.SetFilters, names)
            claimPet() -- in case a pet was left at the machine earlier

            for _, job in ipairs(jobs) do
                if not State.AutoEnchant then break end
                local stopped, reason
                local conn = Enchant.Event.OnClientEvent:Connect(function(e)
                    if type(e) == "table" and e.Kind == "Stop" and (e.PetId == nil or e.PetId == job.PetId) then
                        stopped, reason = e, e.Reason
                    end
                end)
                Status.Enchant = "Enchanting " .. job.Name .. " (slot " .. job.Slot .. ")..."
                local result = safe(Enchant.Start.InvokeServer, Enchant.Start, { PetId = job.PetId, Slot = job.Slot })
                if result and result.Success then
                    local started = os.clock()
                    repeat task.wait(0.25) until stopped or not State.AutoEnchant or os.clock() - started > 180
                    if not stopped then safe(Enchant.Stop.InvokeServer, Enchant.Stop) end
                    claimPet()
                else
                    reason = result and result.Reason or "no answer"
                end
                conn:Disconnect()
                if stopped and stopped.Enchant then
                    Session.Enchants = (Session.Enchants or 0) + 1
                    Status.Enchant = job.Name .. " got " .. tostring(stopped.Enchant) .. " (" .. tostring(rankName(stopped.Enchant)) .. ")"
                elseif reason and reason ~= "Matched" then
                    Status.Enchant = job.Name .. ": " .. tostring(reason)
                    if reason ~= "Matched" and not (stopped and stopped.Enchant) then break end -- out of gems etc.
                end
                task.wait(0.5)
            end
            pcall(function() MenuController:Close("Enchant") end)
        else
            Status.Enchant = "Couldn't find the enchant machine"
        end
    end
    if home and home ~= ENCHANT_ISLAND then travelTo(home) end
    returnTo(back)
    unlock("enchant")
    nap(10, "enchant")
end)
end

-- Save remembered spots once a minute
task.spawn(function()
    while State.Running do
        task.wait(60)
        saveSpots()
    end
end)


---------------------------------------------------------------------
-- 6. UI (Lumina)
---------------------------------------------------------------------
local Lumina = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/xZenbo/Lumina-library/refs/heads/main/Lumina.lua"
))()

-- Stop every loop when the UI is destroyed (Settings -> Destroy UI)
local originalDestroy = Lumina.Destroy
Lumina.Destroy = function(self, ...)
    if self == Lumina then
        State.Running = false
        duckConn:Disconnect()
        bossDodgeConn:Disconnect()
        if State.SkipHatchAnim then setHatchAnimation(false) end
        rejoinConn:Disconnect()
        RunService:Set3dRenderingEnabled(true)
    end
    return originalDestroy(self, ...)
end

local function short(n)
    local units = { "", "K", "M", "B", "T", "Qa", "Qi" }
    local i = 1
    while n >= 1000 and i < #units do n /= 1000; i += 1 end
    return (i == 1 and tostring(math.floor(n)) or string.format("%.2f", n)) .. units[i]
end

-- Re-executing the script closes this window too, not just the loops
env.TSR_Stop = function() pcall(Lumina.Destroy, Lumina) end

local Window = Lumina.CreateWindow({
    Name = "Tap Sim Reborn",
    MaxSize = Vector2.new(700, 520),
    CustomTheme = false,
    UseCanvasGroup = true,
    Icon = "mouse-pointer-click",
})

---------------------------------------------------------------------
-- 7. Islands, places and teleports (used by several tabs below)
---------------------------------------------------------------------
local function notify(title, text, icon)
    Lumina:Notify({ Title = title, Content = text, Duration = 4, Icon = icon or "lucide-map-pin" })
end

-- Islands: uses the game's own island travel (same as the Teleport menu)
local IslandList = { { Name = "Spawn", Order = 0, Price = 0 } }
for name, cfg in pairs(IslandConfig.Islands) do
    table.insert(IslandList, { Name = name, Order = cfg.Order or 99, Price = cfg.Price or 0, Portal = cfg.PortalName })
end
table.sort(IslandList, function(a, b) return a.Order < b.Order end)
local IslandNames = {}
for _, isl in ipairs(IslandList) do table.insert(IslandNames, isl.Name) end

-- Find an island's portal: the "next island" doorway on the island before it
-- (named after the island) or the big portal at the Spawn hub (named after
-- the portal). Hub portal spots are remembered for later.
local function findPortal(islandName, portalName)
    local next_ = workspace:FindFirstChild("NextPortals")
    local door = next_ and next_:FindFirstChild(islandName)
    if door and door:IsA("Model") and door:GetExtentsSize().Magnitude > 0 then return door end
    local hub = workspace:FindFirstChild("Portals") and workspace.Portals:FindFirstChild("Portals")
    local portal = hub and hub:FindFirstChild(portalName)
    if portal and portal:IsA("Model") and portal:GetExtentsSize().Magnitude > 0 then
        PortalSpots[portalName] = portal:GetPivot()
        return portal
    end
end
-- Remember every hub portal that's loaded right now
for name, isl in pairs(IslandConfig.Islands) do if isl.PortalName then findPortal(name, isl.PortalName) end end

-- Stand a few studs in front of a portal's flat face, on whichever side has floor
local function portalSpot(portal)
    local cf, size = portal:GetBoundingBox()
    local axis = size.X < size.Z and cf.RightVector or cf.LookVector
    local depth = math.min(size.X, size.Z)
    local root = getRoot()
    local sides = { axis, -axis }
    if root and (root.Position - (cf.Position + axis)).Magnitude > (root.Position - (cf.Position - axis)).Magnitude then
        sides = { -axis, axis }
    end
    rayParams.FilterDescendantsInstances = { LocalPlayer.Character, portal }
    for _, dir in ipairs(sides) do
        local flat = Vector3.new(dir.X, 0, dir.Z)
        if flat.Magnitude > 0.1 then
            local spot = cf.Position + flat.Unit * (depth / 2 + 5)
            local floor = workspace:Raycast(spot + Vector3.new(0, size.Y / 2 + 10, 0), Vector3.new(0, -(size.Y + 40), 0), rayParams)
            if floor then return floor.Position + Vector3.new(0, 3, 0), cf.Position end
        end
    end
end

local function nextLockedIsland(d)
    for _, isl in ipairs(IslandList) do
        if isl.Portal and not d.Progression.UnlockedIslands[isl.Name] then return isl end
    end
end

-- Buy the next locked island: teleport next to its portal, buy it, come back
local function unlockNextIsland(quiet)
    local d = Data()
    local nextIsland = nextLockedIsland(d)
    if not nextIsland then
        if not quiet then notify("Islands", "Every island is already unlocked") end
        return false
    end
    if d.Currencies.Coins < nextIsland.Price then
        if not quiet then notify("Islands", nextIsland.Name .. " costs " .. short(nextIsland.Price) .. " coins", "lucide-x") end
        return false
    end
    if not waitLock("island", 20) then return false end
    local home, back = LocalPlayer:GetAttribute("CurrentIsland"), saveSpot()

    -- All island portals stand at the Spawn hub. From another island they
    -- aren't loaded, so go to Spawn first and, if needed, to where we last saw it.
    local portal = findPortal(nextIsland.Name, nextIsland.Portal)
    if not portal then
        travelTo("Spawn")
        portal = findPortal(nextIsland.Name, nextIsland.Portal)
        if not portal and PortalSpots[nextIsland.Portal] then
            teleportAndLoad(PortalSpots[nextIsland.Portal].Position + Vector3.new(0, 15, 0), 2.5)
            portal = findPortal(nextIsland.Name, nextIsland.Portal)
        end
    end
    if not portal then
        unlock("island")
        if home and home ~= LocalPlayer:GetAttribute("CurrentIsland") then travelTo(home) end
        notify("Islands", "Couldn't find the " .. nextIsland.Name .. " portal. Visit the Spawn hub once.", "lucide-x")
        return false
    end

    local answer
    local conn = R.IslandResult.OnClientEvent:Connect(function(r)
        if type(r) == "table" and r.Island == nextIsland.Name and r.Action == "Purchase" then answer = r end
    end)
    local spot, center = portalSpot(portal)
    if spot then
        teleportTo(spot, center)
        task.wait(0.6)
        R.IslandUnlock:FireServer({ Action = "Purchase", Island = nextIsland.Name })
        local started = os.clock()
        repeat task.wait(0.1) until answer or os.clock() - started > 5
    end
    conn:Disconnect()
    if home and home ~= LocalPlayer:GetAttribute("CurrentIsland") then travelTo(home) end
    returnTo(back)
    unlock("island")
    task.delay(2, closeRewardPopups)

    if answer and answer.Success then
        notify("Island unlocked", nextIsland.Name .. " is yours!", "lucide-check")
        return true, answer
    end
    notify("Unlock failed", (answer and answer.Reason) or "No safe spot next to the portal", "lucide-x")
    return false, answer
end
env.TSR_UnlockNextIsland = unlockNextIsland

guardedLoop("island", function()
    local d = Data()
    if State.AutoIslands and d then
        local nextIsland = nextLockedIsland(d)
        if nextIsland and d.Currencies.Coins >= nextIsland.Price then unlockNextIsland(true) end
    end
    nap(20, "islands")
end)

-- Key places. Paths are looked up when you click, since parts of the map load in and out.
local function find(path)
    -- "ip:Name" = the game's interaction point with that name (closest one)
    local pointName = path:match("^ip:(.+)$")
    if pointName then
        local root, best, bestDist = getRoot(), nil, nil
        for _, point in ipairs(CollectionService:GetTagged("InteractionPoint")) do
            if point.Name == pointName and point:IsA("BasePart") and point:IsDescendantOf(workspace) then
                local dist = root and (point.Position - root.Position).Magnitude or 0
                if not bestDist or dist < bestDist then best, bestDist = point, dist end
            end
        end
        return best
    end
    local node = workspace
    for part in string.gmatch(path, "[^/]+") do
        node = node and node:FindFirstChild(part)
    end
    return node
end

-- { name, path, island it's on (nil = main map) }. Where the game has an
-- "interaction point" (the exact spot its prompt uses) we aim for that.
local Places = {
    { "Spawn",                     "SpawnLocation" },
    { "Golden Machine (Crafting)", "ip:Golden" },
    { "Pet Index",                 "ip:PetIndex" },
    { "Skill Tree / Rebirth Shop (Spawn)", "Map1/Lbs/Placeholders/SkillTree" },
    { "Double Jump Machine",       "double jump machine" },
    { "Greg (Quest NPC)",          "Greg" },
    { "Honey Pot",                 "Map1/HoneyPotArea/HoneyPotMachine" },
    { "Colosseum",                 "WaveDefence Island/WaveDefense/Colosseum" },
    { "Memory Match",              "MemoryMatch/TouchToPlay" },
    { "Skill Tree / Rebirth Shop (Sky Island)", "Ts2Islands/Sky Island/PlaceholderAssets/Placeholder/SkillTree", "Sky Island" },
    { "Tap Chest (Sky Island)",    "Ts2Islands/Sky Island/TapChest",                                "Sky Island" },
    { "Dig Site (Autumn)",         "Ts2Islands/Autumn/Digsite/DigZone",                             "Autumn" },
    { "Enchant Machine (Shadow Realm)", "ip:Enchant",                                               "Shadow Realm" },
}
local PlaceNames, PlaceInfo = {}, {}
for _, place in ipairs(Places) do
    table.insert(PlaceNames, place[1])
    PlaceInfo[place[1]] = { Path = place[2], Island = place[3] }
end

-- Remember where each place is. Roblox unloads far-away parts of the map, so
-- once you're across the world a place may not exist on your side any more.
local PlaceCache = {}
local function rememberPlace(name)
    local target = find(PlaceInfo[name].Path)
    local spot, center = target and standingSpot(target, 4)
    if spot then PlaceCache[name] = { Spot = spot, Center = center } end
    return target
end
for _, name in ipairs(PlaceNames) do rememberPlace(name) end

-- Go to a place by name. Returns true on success.
local function goToPlace(name)
    local info = PlaceInfo[name]
    if not info then return false end
    leaveMine()
    local d = Data()

    -- If the place is on a different island, use the game's own island travel
    -- first, so the game's idea of where you are always matches reality
    local island = info.Island or "Spawn"
    if LocalPlayer:GetAttribute("CurrentIsland") ~= island then
        if island ~= "Spawn" and not d.Progression.UnlockedIslands[island] then
            notify("Teleport", "Unlock " .. island .. " first.", "lucide-x")
            return false
        end
        if not travelTo(island) then
            notify("Travel failed", "Couldn't travel to " .. island .. " (try again in a moment)", "lucide-x")
            return false
        end
    end

    -- Not loaded? Jump to where we last saw it, let the area load, then line up
    local target = rememberPlace(name)
    local cached = PlaceCache[name]
    if not target and cached then
        teleportTo(cached.Spot, cached.Center)
        task.wait(1.5)
        target = rememberPlace(name)
    end

    -- Still nothing? The game sometimes thinks you're on an island you aren't
    -- (e.g. right after leaving the mine), so travel there for real and retry
    if not target and travelTo(island, true) then
        target = rememberPlace(name)
        if not target and cached then
            teleportTo(cached.Spot, cached.Center)
            task.wait(1.5)
            target = rememberPlace(name)
        end
    end

    if teleportToObject(target, 4) then return true end
    if cached then return true end -- standing at the remembered spot
    notify("Teleport", name .. " isn't loaded yet. Try again in a moment.", "lucide-x")
    return false
end
env.TSR_GoTo = goToPlace -- e.g. getgenv().TSR_GoTo("Pet Index") from the console

---------------------------------------------------------------------
-- 8. The UI
---------------------------------------------------------------------
local function toggle(section, text, key, info, kickKey, onChange)
    return section:CreateToggle(text, State[key] == true, function(v)
        State[key] = v
        if v and kickKey then kick(kickKey) end
        if onChange then onChange(v) end
    end, false, info, key)
end

local tab, sec
local Labels = {}

-- Farm tab -----------------------------------------------------------
tab = Window:CreateTab("Farm", "lucide-mouse-pointer-click")

sec = tab:CreateSection("Tapping", false, "lucide-hand")
toggle(sec, "Auto Tap", "AutoTap", "Taps for you, same as clicking the tap button")
sec:CreateSlider("Taps per second", 1, 8, 8, function(v) State.TapsPerSec = v end,
    false, "8 is the game's own limit", "TapsPerSec")
toggle(sec, "Use Game Auto Clicker", "GameAutoClick", "Keeps the game's own auto clicker on once you own it (skill tree)")

sec = tab:CreateSection("Rebirth", false, "lucide-refresh-cw")
sec:CreateDropdown("Rebirth button", RebirthChoices, function(opt) State.RebirthChoice = opt end,
    false, false, "Which rebirth button to press. Locked or too pricey buttons are waited on.", "RebirthChoice")
toggle(sec, "Auto Rebirth", "AutoRebirth", "Presses the rebirth button picked above")

sec = tab:CreateSection("Progression", false, "lucide-trending-up")
local SkillTrees = {}
do
    local seen = {}
    for _, node in pairs(SkillTreeFormula.Nodes) do
        if node.Tree and not seen[node.Tree] then seen[node.Tree] = true table.insert(SkillTrees, node.Tree) end
    end
    table.sort(SkillTrees)
end
sec:CreateDropdown("Skill trees to buy", SkillTrees, function(opts)
    State.SkillTrees = type(opts) == "table" and opts or { opts }
    kick("skill")
end, true, false, "Pick one or more trees. None picked = all trees.", "SkillTrees")
toggle(sec, "Auto Skill Tree", "AutoSkillTree", "Spends gems on skill nodes: Auto Clicker and Auto Rebirth first, then cheapest", "skill")
toggle(sec, "Auto Buy Upgrades", "AutoUpgrade", "Buys gem upgrades the game will sell you", "upgrade")
toggle(sec, "Auto Buy Double Jumps", "AutoJumps", "Buys the next +1 Jump at its island's machine when you can afford it", "jumps")
toggle(sec, "Auto Unlock Next Island", "AutoIslands", "Buys the next island as soon as you can afford it", "islands")
Labels.UpgradeLabel = sec:CreateLabel("", "lucide-info")

-- Pets tab -----------------------------------------------------------
tab = Window:CreateTab("Pets", "lucide-egg")

-- Egg dropdown shows prices: "Spiked (200K)"
local EggChoices, EggByLabel = { "Best affordable" }, { ["Best affordable"] = "Best affordable" }
for _, egg in ipairs(EggList) do
    local label = string.format("%s (%s)", egg.Name, short(egg.Price))
    table.insert(EggChoices, label)
    EggByLabel[label] = egg.Name
end

sec = tab:CreateSection("Hatching", false, "lucide-egg")
sec:CreateDropdown("Egg", EggChoices, function(opt) State.SelectedEgg = EggByLabel[opt] or opt end,
    false, false, "'Best affordable' picks the priciest egg you can buy on any unlocked island", "SelectedEgg")
sec:CreateDropdown("Eggs per hatch", { "Max affordable", "1", "3", "8" }, function(opt) State.HatchAmount = opt end,
    false, false, "'Max affordable' uses 8 if you own x8, else 3, else 1", "HatchAmountMode")
sec:CreateDropdown("Get to egg by", { "Teleport", "Walk" }, function(opt) State.MoveMode = opt end,
    false, false, "Teleport is instant. Walk looks more natural but only works for nearby eggs.", "MoveMode")
toggle(sec, "Auto Hatch", "AutoHatch", "Goes to the egg and hatches it. Pauses when you can't afford it.")
sec:CreateToggle("Skip Hatch Animation", false, function(v) setHatchAnimation(v) end,
    false, "No hatch animation at all while Auto Hatch runs. Pets still arrive normally.", "SkipHatchAnim")

sec = tab:CreateSection("Crafting", false, "lucide-sparkles")
toggle(sec, "Auto Golden Pets", "AutoGolden", "Turns 6 spare copies of a pet into a Golden one (100%) at the Golden Machine",
    "craft", function(v) if not v then closeMachineMenu("Golden") end end)
toggle(sec, "Auto Diamond Pets", "AutoDiamond", "Turns 5 spare Golden copies into a Diamond one (needs the Diamond machine's island)",
    "craft", function(v) if not v then closeMachineMenu("Diamond") end end)
toggle(sec, "Auto Rainbow Pets", "AutoRainbow", "Fuses spare Diamond pets into Rainbow ones and claims them when ready",
    "craft", function(v) if not v then closeMachineMenu("Rainbow") end end)
sec:CreateLabel("Equipped and locked pets are never used. Lock pets to protect them.", "lucide-lock")
Labels.CraftLabel = sec:CreateLabel("", "lucide-info")

sec = tab:CreateSection("Team", false, "lucide-paw-print")
toggle(sec, "Auto Equip Best", "AutoEquipBest", "Equips your best pets right away, then every minute", "equip")

sec = tab:CreateSection("Enchanting (Shadow Realm)", false, "lucide-wand-sparkles")
sec:CreateDropdown("Stop at enchant rarity", { "Common", "Uncommon", "Rare", "Legendary", "Mythic", "Secret" },
    function(opts) State.EnchantRanks = type(opts) == "table" and opts or { opts } kick("enchant") end,
    true, false, "Keeps rolling a pet until it has an enchant of one of these rarities", "EnchantRanks")
sec:CreateDropdown("Only enchant pets of rarity", { "Common", "Rare", "Epic", "Legendary", "Mythical", "Leaderboard", "Release", "Secret" },
    function(opts) State.EnchantPetRarities = type(opts) == "table" and opts or { opts } kick("enchant") end,
    true, false, "Leave empty to enchant all your equipped pets", "EnchantPetRarities")
toggle(sec, "Auto Enchant", "AutoEnchant", "Rolls enchants on your equipped pets at the enchant machine (costs gems). Rare enchants you have are kept.", "enchant")
Labels.EnchantLabel = sec:CreateLabel("", "lucide-info")

sec = tab:CreateSection("Auto Delete", true, "lucide-trash-2")
sec:CreateSlider("Keep my best", 1, 100, 20, function(v) State.KeepBest = v end,
    false, "Your strongest pets (any tier) are always kept", "KeepBest")
sec:CreateDropdown("Keep rarities", { "Common", "Rare", "Epic", "Legendary", "Mythical", "Leaderboard", "Release" },
    function(opts) State.KeepRarities = type(opts) == "table" and opts or { opts } end,
    true, false, "Pets of these rarities are never deleted (Secrets are always kept)", "KeepRarities")
toggle(sec, "Keep 1 of each pet", "KeepOneEach", "Keeps your best copy of every pet (and every tier of it), for collecting", "delete")
sec:CreateDropdown("Tiers that may be deleted", { "Normal only", "Normal + Golden", "All except Rainbow" },
    function(opt) State.DeleteTiers = opt end, false, false, "Rainbow and Secret pets are never deleted", "DeleteTiers")
toggle(sec, "Auto Delete Pets", "AutoDelete", "Deletes everything else once a minute. Equipped and locked pets are safe.", "delete")
Labels.DeleteLabel = sec:CreateLabel("", "lucide-info")

-- Collect tab --------------------------------------------------------
tab = Window:CreateTab("Collect", "lucide-gem")

sec = tab:CreateSection("Chests", false, "lucide-package")
toggle(sec, "Auto World Chests & Events", "AutoWorldChests", "Breaks world chests (respawn every minute), meteors, mystery eggs and flying pigs")
toggle(sec, "Auto Tap Chests", "AutoTapChests", "Claims the big island tap chests (Sky Island, Desert) every 6 hours", "tapchest")

sec = tab:CreateSection("Collectibles", false, "lucide-star")
toggle(sec, "Auto Shiny Stars", "AutoStars", "Collects the hidden stars on your unlocked islands (all 15 = better shiny chance)", "stars")
toggle(sec, "Auto Index Rewards", "AutoIndex", "Claims the reward for each completed egg page in the Pet Index", "index")

sec = tab:CreateSection("Rewards", false, "lucide-gift")
toggle(sec, "Auto Claim Offline Rewards", "AutoOffline", "Claims offline earnings when they're waiting", "offline")
toggle(sec, "Auto Lucky Ducky", "AutoDucky", "Clicks the rare Lucky Ducky when it appears")
toggle(sec, "Auto Use Boosts", "AutoBoosts", "Drinks potions and boosts you own whenever that boost runs out", "boosts")

-- Quests tab ---------------------------------------------------------
tab = Window:CreateTab("Quests", "lucide-scroll")

sec = tab:CreateSection("Quests", false, "lucide-scroll")
toggle(sec, "Auto Claim Quests", "AutoQuests", "Claims finished quests", "quests")
toggle(sec, "Auto NPC Quests", "AutoNpcQuests", "Talks to quest NPCs and collects their hidden items", "npc")
Labels.NpcLabel = sec:CreateLabel("", "lucide-info")

local ShrineChoices, ShrineByLabel = { "Don't change" }, { ["Don't change"] = false }
for _, key in ipairs(ShrineConfig.Order) do
    local label = ShrineConfig.Blessings[key].Name .. " (" .. ShrineConfig.Blessings[key].Effect .. ")"
    table.insert(ShrineChoices, label)
    ShrineByLabel[label] = key
end
sec = tab:CreateSection("Shrine Blessing", false, "lucide-sparkle")
sec:CreateDropdown("Blessing", ShrineChoices, function(opt)
    local key = ShrineByLabel[opt]
    State.ShrineChoice = key or nil
    if key then kick("shrine") end
end,
    false, false, "Switching blessing resets its tier timer, so it only switches when needed", "ShrineChoice")
toggle(sec, "Auto Shrine Blessing", "AutoShrine", "Visits the shrine on Autumn and picks your blessing", "shrine")
Labels.ShrineLabel = sec:CreateLabel("", "lucide-info")

-- Minigames tab ------------------------------------------------------
tab = Window:CreateTab("Minigames", "lucide-gamepad-2")

sec = tab:CreateSection("Dig Site (Autumn)", false, "lucide-shovel")
toggle(sec, "Auto Dig", "AutoDig", "Plays all your digs (10 per hour) with perfect timing", "dig")
sec:CreateButton("Teleport to Dig Site", function() goToPlace("Dig Site (Autumn)") end)
Labels.DigLabel = sec:CreateLabel("", "lucide-info")

sec = tab:CreateSection("Colosseum", false, "lucide-swords")
toggle(sec, "Auto Kill Mobs", "AutoMobs", "In the Colosseum, attacks the most dangerous opponent for you", "mobs")
toggle(sec, "Auto Start Colosseum Runs", "AutoStartColosseum", "Starts a new run whenever the 30 min cooldown is up (needs Auto Kill Mobs)", "mobs")
sec:CreateButton("Teleport to Colosseum", function() goToPlace("Colosseum") end)
Labels.MobLabel = sec:CreateLabel("", "lucide-swords")

sec = tab:CreateSection("Mine (Crystal Cave)", false, "lucide-pickaxe")
sec:CreateButton("Enter Mine", function()
    task.spawn(Fn.enterMine)
end, "Takes you to Crystal Cave and into the mine")
toggle(sec, "Auto Mine", "AutoMine", "Enters the mine and breaks blocks with your pickaxe. Other features wait while you're in the mine.", "mine")
toggle(sec, "Auto Sell Ores", "AutoSellOres", "Sells on the Sell pad whenever your backpack is full", "mine")
toggle(sec, "Auto Upgrade Pickaxe & Bag", "AutoPickaxe", "Buys the next pickaxe (then bag) on the Shop pad when you can afford it", "mine")
Labels.MineLabel = sec:CreateLabel("", "lucide-info")

-- Event tab ----------------------------------------------------------
tab = Window:CreateTab("Event", "lucide-ghost")

sec = tab:CreateSection("Halloween", false, "lucide-ghost")
sec:CreateButton("Teleport to Halloween Island", function()
    if not waitLock("manual", 10) then return end
    travelTo("Spawn") -- the Halloween island hangs off the Spawn island
    local folder = workspace:FindFirstChild("HalloweenIsland")
    local caudron = folder and folder:FindFirstChild("Caudron")
    if caudron then
        teleportAndLoad(caudron:GetPivot().Position + Vector3.new(0, 15, 0), 2)
        local spot, center = eggStandSpot(caudron)
        if spot then teleportTo(spot, center) end
    end
    unlock("manual")
end, "Takes you to the Halloween houses and the cauldron")
toggle(sec, "Auto Trick-or-Treat", "AutoTrickTreat", "Knocks on every Halloween house when its 30 min cooldown is up (candy + potions)", "trick")
toggle(sec, "Auto Hallow Lord Boss", "AutoBoss", "Joins the hourly boss fight, taps it and dodges its bombs", "boss")
Labels.BossLabel = sec:CreateLabel("", "lucide-skull")

sec = tab:CreateSection("World Events", false, "lucide-party-popper")
toggle(sec, "Auto Pop Balloons", "AutoBalloons", "During Balloon Party, flies near the balloons and pops them", "balloons")

-- Teleport tab -------------------------------------------------------
tab = Window:CreateTab("Teleport", "lucide-map-pin")

local selectedIsland = "Spawn"
sec = tab:CreateSection("Islands", false, "lucide-globe")
sec:CreateDropdown("Island", IslandNames, function(opt) selectedIsland = opt end,
    false, true, "Islands you have unlocked", "TpIsland")
sec:CreateButton("Travel to Island", function()
    leaveMine()
    local result = safe(R.IslandTravel.InvokeServer, R.IslandTravel, { Island = selectedIsland, Source = "Menu" })
    if result and result.Success then
        notify("Travel", "Travelling to " .. selectedIsland)
    else
        notify("Travel failed", (result and result.Reason) or "No answer from the server", "lucide-x")
    end
end, "Uses the game's own island travel")
sec:CreateButton("Unlock Next Island", function()
    unlockNextIsland()
end, "Buys the next island at its portal, then brings you back")

local selectedPlace = PlaceNames[1]
sec = tab:CreateSection("Places", false, "lucide-landmark")
sec:CreateDropdown("Place", PlaceNames, function(opt) selectedPlace = opt end,
    false, true, "Machines, shops and minigames", "TpPlace")
sec:CreateButton("Teleport to Place", function()
    goToPlace(selectedPlace)
end, "Puts you right in front of it (travels to its island first if needed)")

local selectedTpEgg = EggList[1] and EggList[1].Name
sec = tab:CreateSection("Eggs", false, "lucide-egg")
sec:CreateDropdown("Egg", EggChoices, function(opt) selectedTpEgg = EggByLabel[opt] or opt end,
    false, true, "Any egg in the world", "TpEgg")
sec:CreateButton("Teleport to Egg", function()
    if selectedTpEgg == "Best affordable" then return end
    leaveMine()
    local model = selectedTpEgg and eggModel(selectedTpEgg)
    if not model then return notify("Teleport", tostring(selectedTpEgg) .. " isn't loaded right now.", "lucide-x") end
    local spot, center = eggStandSpot(model)
    if spot then
        teleportTo(spot, center)
    else
        notify("Teleport", "No floor near " .. selectedTpEgg .. " yet. Travel to its island first.", "lucide-x")
    end
end)

-- Misc tab -----------------------------------------------------------
tab = Window:CreateTab("Misc", "lucide-settings-2")

sec = tab:CreateSection("AFK", false, "lucide-moon")
toggle(sec, "Auto Rejoin", "AutoRejoin", "Rejoins if you get disconnected. Put the script in autoexec too.")
sec:CreateToggle("Low GPU Mode", false, function(v)
    State.LowGpu = v
    RunService:Set3dRenderingEnabled(not v)
end, false, "Stops drawing the 3D world to save power while AFK", "LowGpu")

sec = tab:CreateSection("Screen", false, "lucide-monitor")
toggle(sec, "Auto Close Reward Popups", "AutoClosePopups", "Presses Continue/Close on reward screens a moment after they open")

-- Live stats from your save data
sec = tab:CreateSection("Stats", false, "lucide-bar-chart-3")
Labels.StatsLabel = sec:CreateLabel("Loading stats...", "lucide-activity")

-- Console helpers: getgenv().TSR_Kick("equip") wakes a feature right away,
-- getgenv().TSR_Status() shows what each feature is up to
env.TSR_Kick = kick
env.TSR_SkipAnim = setHatchAnimation
-- Dry run: which pets would Auto Delete remove right now? (deletes nothing)
env.TSR_DeletePreview = function()
    local d = Data()
    local ids = Fn.petsToDelete(d)
    local counts = {}
    for _, id in ipairs(ids) do
        local pet = d.Pets.Owned[id]
        local key = tostring(pet.Tier) .. " " .. tostring(pet.Name)
        counts[key] = (counts[key] or 0) + 1
    end
    return #ids, counts
end
env.TSR_Status = function()
    return {
        Upgrades = UpgradeStatus, Jumps = JumpStatus, Boss = BossStatus, Craft = CraftStatus,
        Mobs = MobStatus, Trick = TrickStatus, Dig = Status.Dig, Npc = Status.Npc,
        Shrine = Status.Shrine, Delete = Status.Delete, Mine = Status.Mine, Enchant = Status.Enchant,
    }
end

-- Keep the status labels fresh (countdowns tick every second)
task.spawn(function()
    while State.Running do
        pcall(function()
            local st = bossState()
            if st.Phase == "Warning" or st.Phase == "Fight" then
                Labels.BossLabel:Set(State.AutoBoss and BossStatus or ("Boss fight is on! (" .. st.Phase .. ")"))
            else
                Labels.BossLabel:Set("Next boss fight in " .. clockText(HallowBossConfig.NextStart(serverNow()) - serverNow()))
            end

            if colosseumActive() then
                Labels.MobLabel:Set("In a Colosseum run: fighting!")
            else
                local left = colosseumCooldownLeft()
                Labels.MobLabel:Set(left > 0 and ("Next Colosseum run in " .. clockText(left))
                    or (State.AutoMobs and State.AutoStartColosseum and "Starting a run..." or "Colosseum is ready"))
            end

            local d = Data()
            if d then
                local digs, resetIn = Fn.digsLeft(d)
                Labels.DigLabel:Set(State.AutoDig and Status.Dig ~= "" and Status.Dig
                    or (digs > 0 and (digs .. " digs left") or ("Out of digs. Refill in " .. clockText(resetIn))))
            end

            Labels.UpgradeLabel:Set((State.AutoUpgrade and ("Upgrades: " .. UpgradeStatus) or "")
                .. (State.AutoJumps and ((State.AutoUpgrade and "\n" or "") .. "Jumps: " .. JumpStatus) or ""))
            local craft = {}
            if State.AutoGolden then table.insert(craft, "Golden: " .. CraftStatus.Golden) end
            if State.AutoDiamond then table.insert(craft, "Diamond: " .. CraftStatus.Diamond) end
            if State.AutoRainbow then table.insert(craft, "Rainbow: " .. CraftStatus.Rainbow) end
            Labels.CraftLabel:Set(table.concat(craft, "\n"))
            Labels.NpcLabel:Set(State.AutoNpcQuests and Status.Npc or "")
            Labels.ShrineLabel:Set(State.AutoShrine and Status.Shrine
                or ("Current: " .. tostring(LocalPlayer:GetAttribute(ShrineConfig.Attributes.Blessing) or "none")))
            Labels.DeleteLabel:Set(State.AutoDelete and Status.Delete or "")
            Labels.MineLabel:Set(State.AutoMine and (Status.Mine or "") or "")
            Labels.EnchantLabel:Set(State.AutoEnchant and (Status.Enchant or "") or "")
        end)
        task.wait(1)
    end
end)

task.spawn(function()
    while State.Running do
        local d = Data()
        if d then
            pcall(function()
                Labels.StatsLabel:Set(string.format(
                    "Coins %s | Gems %s | Rebirths %s | Eggs %s\nThis session: %s hatched, %s chests, %s stars, %s crafted, %s knocks, %s deleted",
                    short(d.Currencies.Coins), short(d.Currencies.Gems),
                    short(d.Statistics.Rebirths), short(d.Statistics.EggsOpened),
                    short(Session.Hatched), short(Session.Chests), short(Session.Stars),
                    short(Session.Crafted), short(Session.Knocks), short(Session.Deleted or 0)))
            end)
        end
        task.wait(2)
    end
end)

Lumina:Notify({
    Title = "Lumina HUB | Tap Sim Reborn",
    Content = "Loaded",
    Duration = 5,
    Icon = "lucide-check",
})
