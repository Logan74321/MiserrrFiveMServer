-- client/police.lua

local QBCore = exports['qb-core']:GetCoreObject()
local CurrentWantedLevel = 0
local PoliceUnits = {}
local Barricades = {}
local Roadblocks = {}
local PoliceResponseLevel = 0

-- Initialize police AI when game starts
RegisterNetEvent('qb-lockdown:client:GameStarted', function()
    InitializePoliceAI()
end)

-- Set up initial police response
function InitializePoliceAI()
    CurrentWantedLevel = Config.StarterWantedLevel
    PoliceResponseLevel = 0
    
    -- Set player wanted level
    SetPlayerWantedLevel(PlayerId(), CurrentWantedLevel)
    SetPlayerWantedLevelNow(PlayerId())
    
    -- Spawn initial police units
    SpawnPoliceUnits(Config.Police.initialSpawns, false)
    
    -- Start police response thread
    StartPoliceResponseTimer()
end

-- Spawn police units
function SpawnPoliceUnits(amount, isSwat)
    if not InGame or not CurrentGame then return end
    
    local zoneData = Config.Zones[CurrentGame.zone]
    if not zoneData then return end
    
    local centerCoords = zoneData.coords
    local radius = zoneData.radius * 0.8 -- 80% of zone radius
    
    for i = 1, amount do
        -- Find spawn position
        local spawnPos = nil
        local attempts = 0
        
        while not spawnPos and attempts < 10 do
            local angle = math.random() * math.pi * 2
            local dist = math.random(50, 150)
            
            local x = centerCoords.x + math.cos(angle) * dist
            local y = centerCoords.y + math.sin(angle) * dist
            
            -- Check if position is within zone
            local distToCenter = #(vector3(x, y, 0) - vector3(centerCoords.x, centerCoords.y, 0))
            if distToCenter <= radius then
                -- Get ground Z
                local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, 1000.0, 0)
                if foundGround then
                    spawnPos = vector4(x, y, groundZ + 1.0, math.random(0, 359))
                end
            end
            
            attempts = attempts + 1
        end
        
        if not spawnPos then
            -- Fallback to a random point within zone
            local randomAngle = math.random() * math.pi * 2
            local randomDist = math.random(30, math.floor(radius * 0.5))
            local x = centerCoords.x + math.cos(randomAngle) * randomDist
            local y = centerCoords.y + math.sin(randomAngle) * randomDist
            
            local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, 1000.0, 0)
            if foundGround then
                spawnPos = vector4(x, y, groundZ + 1.0, math.random(0, 359))
            else
                spawnPos = vector4(x, y, centerCoords.z, math.random(0, 359))
            end
        end
        
        -- Spawn police ped
        local modelName = isSwat and "s_m_y_swat_01" or Config.Police.models[math.random(1, #Config.Police.models)]
        local modelHash = GetHashKey(modelName)
        
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do
            Wait(10)
        end
        
        local ped = CreatePed(4, modelHash, spawnPos.x, spawnPos.y, spawnPos.z, spawnPos.w, true, false)
        SetPedArmour(ped, isSwat and 100 or 50)
        SetPedCombatAttributes(ped, 46, true) -- BF_AlwaysFight
        SetPedCombatAttributes(ped, 5, true) -- BF_CanFightArmedPedsWhenNotArmed
        SetPedCombatAttributes(ped, 2, true) -- BF_CanDoDrivebys
        SetPedFleeAttributes(ped, 0, false) -- Don't flee
        SetPedRelationshipGroupHash(ped, GetHashKey('POLICE'))
        SetPedAsCop(ped, true)
        
        SetEntityAsMissionEntity(ped, true, true)
        
        -- Give weapon
        local weaponList = isSwat and {"WEAPON_CARBINERIFLE", "WEAPON_PUMPSHOTGUN_MK2"} or Config.Police.weapons
        local randomWeapon = weaponList[math.random(1, #weaponList)]
        GiveWeaponToPed(ped, GetHashKey(randomWeapon), 500, false, true)
        SetPedAccuracy(ped, isSwat and 70 or 50)
        
        -- Make aggressive to player
        SetPedCombatAttributes(ped, 46, true)
        SetPedCombatAttributes(ped, 5, true)
        TaskCombatPed(ped, PlayerPedId(), 0, 16)
        
        -- Chance to spawn in vehicle
        if math.random() < (isSwat and 0.7 or 0.5) then
            local vehicleModel = isSwat 
                and "police3" 
                or Config.Police.vehicles[math.random(1, #Config.Police.vehicles)]
            
            local vehicleHash = GetHashKey(vehicleModel)
            
            RequestModel(vehicleHash)
            while not HasModelLoaded(vehicleHash) do
                Wait(10)
            end
            
            local vehicle = CreateVehicle(vehicleHash, spawnPos.x, spawnPos.y, spawnPos.z, spawnPos.w, true, false)
            SetEntityAsMissionEntity(vehicle, true, true)
            SetVehicleOnGroundProperly(vehicle)
            
            -- Enhanced vehicle properties for police
            SetVehicleModKit(vehicle, 0)
            SetVehicleMod(vehicle, 11, 3, false) -- Engine Level 4
            SetVehicleMod(vehicle, 12, 2, false) -- Brakes Level 3
            SetVehicleMod(vehicle, 13, 2, false) -- Transmission Level 3
            SetVehicleMod(vehicle, 16, 4, false) -- Armor Level 5
            
            -- Police livery and extras
            SetVehicleLivery(vehicle, 0)
            for i = 1, 12 do
                if math.random() > 0.5 then
                    SetVehicleExtra(vehicle, i, false)
                end
            end
            
            -- Put cop in vehicle
            SetPedIntoVehicle(ped, vehicle, -1)
            
            -- Drive to player
            TaskVehicleChase(ped, PlayerPedId())
            SetDriverAbility(ped, 1.0)
            SetDriverAggressiveness(ped, 0.8)
            
            -- Sometimes add passenger
            if math.random() < 0.6 and isSwat then
                local passengerPed = CreatePed(4, modelHash, spawnPos.x, spawnPos.y, spawnPos.z, spawnPos.w, true, false)
                SetPedArmour(passengerPed, isSwat and 100 or 50)
                SetPedCombatAttributes(passengerPed, 46, true)
                SetPedCombatAttributes(passengerPed, 5, true)
                SetPedRelationshipGroupHash(passengerPed, GetHashKey('POLICE'))
                SetPedAsCop(passengerPed, true)
                
                SetEntityAsMissionEntity(passengerPed, true, true)
                
                -- Give weapon
                GiveWeaponToPed(passengerPed, GetHashKey(randomWeapon), 500, false, true)
                SetPedAccuracy(passengerPed, isSwat and 70 or 50)
                
                -- Put in passenger seat
                SetPedIntoVehicle(passengerPed, vehicle, 0)
                
                TaskCombatPed(passengerPed, PlayerPedId(), 0, 16)
                
                -- Add to list
                table.insert(PoliceUnits, passengerPed)
            end
            
            -- Add to list
            table.insert(PoliceUnits, ped)
            table.insert(PoliceUnits, vehicle)
        else
            -- On foot, navigate to player
            TaskCombatPed(ped, PlayerPedId(), 0, 16)
            
            -- Add to list
            table.insert(PoliceUnits, ped)
        end
        
        SetModelAsNoLongerNeeded(modelHash)
    end
end

-- Spawn barricades
function SpawnBarricades()
    if not InGame or not CurrentGame then return end
    
    local zoneData = Config.Zones[CurrentGame.zone]
    if not zoneData then return end
    
    -- Spawn barricades at edge of zone
    local centerCoords = zoneData.coords
    local radius = zoneData.radius * 0.9 -- 90% of zone radius
    local count = 8 -- Number of barricades
    
    for i = 1, count do
        local angle = ((i - 1) / count) * (2 * math.pi)
        local x = centerCoords.x + math.cos(angle) * radius
        local y = centerCoords.y + math.sin(angle) * radius
        
        local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, 1000.0, 0)
        local z = foundGround and groundZ + 1.0 or centerCoords.z
        
        -- Create barricade object
        local barrierHash = GetHashKey("prop_barrier_work05")
        RequestModel(barrierHash)
        while not HasModelLoaded(barrierHash) do
            Wait(10)
        end
        
        local barricade = CreateObject(barrierHash, x, y, z, true, false, false)
        SetEntityHeading(barricade, angle * 57.3) -- Convert to degrees
        PlaceObjectOnGroundProperly(barricade)
        FreezeEntityPosition(barricade, true)
        SetEntityAsMissionEntity(barricade, true, true)
        
        table.insert(Barricades, barricade)
        
        -- Add police nearby
        SpawnPoliceUnits(math.random(1, 2), false)
        
        SetModelAsNoLongerNeeded(barrierHash)
    end
    
    QBCore.Functions.Notify("Police have set up barricades around the area!", "error", 5000)
end

-- Spawn roadblocks
function SpawnRoadblocks()
    if not InGame or not CurrentGame then return end
    
    local zoneData = Config.Zones[CurrentGame.zone]
    if not zoneData then return end
    
    -- Spawn roadblocks at strategic positions
    local centerCoords = zoneData.coords
    local radius = zoneData.radius * 0.7 -- 70% of zone radius
    local count = 4 -- Number of roadblocks
    
    for i = 1, count do
        local angle = ((i - 1) / count) * (2 * math.pi)
        local x = centerCoords.x + math.cos(angle) * radius
        local y = centerCoords.y + math.sin(angle) * radius
        
        local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, 1000.0, 0)
        local z = foundGround and groundZ + 1.0 or centerCoords.z
        
        -- Create roadblock
        local blockHash = GetHashKey("prop_mp_barrier_02b")
        RequestModel(blockHash)
        while not HasModelLoaded(blockHash) do
            Wait(10)
        end
        
        -- Create a line of barriers
        for j = -2, 2 do
            local offsetX = math.cos(angle + (math.pi / 2)) * (j * 2.5)
            local offsetY = math.sin(angle + (math.pi / 2)) * (j * 2.5)
            
            local block = CreateObject(blockHash, x + offsetX, y + offsetY, z, true, false, false)
            SetEntityHeading(block, angle * 57.3) -- Convert to degrees
            PlaceObjectOnGroundProperly(block)
            FreezeEntityPosition(block, true)
            SetEntityAsMissionEntity(block, true, true)
            
            table.insert(Roadblocks, block)
        }
        
        -- Add armored police vehicle
        local policeHash = GetHashKey("police3")
        RequestModel(policeHash)
        while not HasModelLoaded(policeHash) do
            Wait(10)
        end
        
        local offsetX = math.cos(angle + (math.pi / 2)) * 5
        local offsetY = math.sin(angle + (math.pi / 2)) * 5
        
        local vehicle = CreateVehicle(policeHash, x + offsetX, y + offsetY, z, angle * 57.3 + 90, true, false)
        SetEntityAsMissionEntity(vehicle, true, true)
        SetVehicleOnGroundProperly(vehicle)
        
        table.insert(Roadblocks, vehicle)
        
        -- Add SWAT team
        SpawnPoliceUnits(3, true)
        
        SetModelAsNoLongerNeeded(blockHash)
        SetModelAsNoLongerNeeded(policeHash)
    end
    
    QBCore.Functions.Notify("SWAT teams have deployed roadblocks!", "error", 5000)
    
    -- Increase wanted level
    SetWantedLevel(CurrentWantedLevel + 1)
end

-- Increase wanted level
function SetWantedLevel(level)
    if level < 1 then level = 1 end
    if level > 5 then level = 5 end
    
    CurrentWantedLevel = level
    SetPlayerWantedLevel(PlayerId(), CurrentWantedLevel)
    SetPlayerWantedLevelNow(PlayerId())
    
    -- Update UI
    SendNUIMessage({
        action = "updateWantedLevel",
        level = CurrentWantedLevel
    })
end

-- Start police response timer
function StartPoliceResponseTimer()
    CreateThread(function()
        local startTime = GetGameTimer()
        
        while InGame and CurrentGame do
            Wait(1000)
            
            local currentTime = (GetGameTimer() - startTime) / 1000
            
            -- Level 1 response
            if PoliceResponseLevel == 0 and currentTime >= Config.Police.responseTime.level1 then
                QBCore.Functions.Notify("Police reinforcements are responding!", "error", 5000)
                SpawnPoliceUnits(Config.Police.initialSpawns, false)
                PoliceResponseLevel = 1
            end
            
            -- Level 2 response
            if PoliceResponseLevel == 1 and currentTime >= Config.Police.responseTime.level2 then
                SpawnBarricades()
                PoliceResponseLevel = 2
                SetWantedLevel(CurrentWantedLevel + 1)
            end
            
            -- Level 3 response
            if PoliceResponseLevel == 2 and currentTime >= Config.Police.responseTime.level3 then
                SpawnRoadblocks()
                PoliceResponseLevel = 3
            end
        end
    end)
end

-- Clean up police AI
function CleanupPoliceAI()
    for _, entity in ipairs(PoliceUnits) do
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end
    
    for _, barricade in ipairs(Barricades) do
        if DoesEntityExist(barricade) then
            DeleteEntity(barricade)
        end
    end
    
    for _, roadblock in ipairs(Roadblocks) do
        if DoesEntityExist(roadblock) then
            DeleteEntity(roadblock)
        end
    end
    
    PoliceUnits = {}
    Barricades = {}
    Roadblocks = {}
    CurrentWantedLevel = 0
    PoliceResponseLevel = 0
    
    -- Reset player wanted level
    SetPlayerWantedLevel(PlayerId(), 0)
    SetPlayerWantedLevelNow(PlayerId())
end

-- Clean up when leaving game
AddEventHandler('qb-lockdown:client:LeaveGame', function()
    CleanupPoliceAI()
end)