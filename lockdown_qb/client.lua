local QBCore = exports['qb-core']:GetCoreObject()

-- Local variables
local InLockdown = false
local ZoneCoords = {x = -2102.951, y = 3088.354, z = 20.083972}
local CurrentZone = nil
local radius = 480.0
local spawnedObjects = 0
local lootObjects = {}
local kills = 0
local playersInZone = 0
local canAddKill = true
local cam = nil
local lockdownLobby = false
local coordsBefore = nil
local Data = nil
local energyLevel = 0
local extractionPoints = {}
local contractActive = false
local contractData = nil
local policeUnits = {}
local wantedLevel = 0
local playerBlips = {}

-- Register the keybind if enabled
if Config.KeybindEnabled then
    RegisterKeyMapping(Config.CommandName, "Open Lockdown Protocol Menu", "keyboard", Config.KeybindKey)
end

-- Register the command to open the Lockdown menu
RegisterCommand(Config.CommandName, function()
    if Config.OnlyCoords.Enabled then 
        if GetDistanceBetweenCoords(GetEntityCoords(PlayerPedId()), Config.OnlyCoords.Coords.x, Config.OnlyCoords.Coords.y, Config.OnlyCoords.Coords.z) < Config.OnlyCoords.Distance then 
            OpenLockdownMenu()
        else
            ShowNotification('You cannot use this command here!')
        end
    else
        OpenLockdownMenu()
    end
end, false)

-- Function to open the Lockdown menu
function OpenLockdownMenu()
    if not InLockdown then
        QBCore.Functions.TriggerCallback('lockdown:getPlayerStats', function(data)  
            if Config.CheckInventory then 
                local inventory = exports.ox_inventory:GetPlayerItems()
                if inventory and #inventory > 0 then 
                    ShowNotification(Config.Language.ClearInventory)
                else
                    coordsBefore = GetEntityCoords(PlayerPedId())
                    SendNUIMessage({
                        type = 'lobbyscreen',
                        stats = data
                    })
                    StartLobbyCamera()
                    lockdownLobby = true
                    SetNuiFocus(true, true)
                    NetworkStartSoloTutorialSession()
                end 
            else
                coordsBefore = GetEntityCoords(PlayerPedId())
                SendNUIMessage({
                    type = 'lobbyscreen',
                    stats = data
                })
                StartLobbyCamera()
                lockdownLobby = true
                SetNuiFocus(true, true)
                NetworkStartSoloTutorialSession()
            end
        end)
    end
end

-- Gang system callbacks
RegisterNUICallback('getGangData', function(data, cb)
    QBCore.Functions.TriggerCallback('lockdown:getGangData', function(gangData)
        cb(gangData)
    end)
end)

RegisterNUICallback('createGang', function(data, cb)
    local gangName = data.name
    local gangColor = data.color
    local gangEmblem = data.emblem
    
    QBCore.Functions.TriggerCallback('lockdown:createGang', function(success, message)
        cb({success = success, message = message})
    end, gangName, gangColor, gangEmblem)
end)

RegisterNUICallback('joinGang', function(data, cb)
    local gangId = data.gangId
    
    QBCore.Functions.TriggerCallback('lockdown:joinGang', function(success, message)
        cb({success = success, message = message})
    end, gangId)
end)

-- Leaderboard callback
RegisterNUICallback('getLeaderboard', function(data, cb)
    QBCore.Functions.TriggerCallback('lockdown:getLeaderboard', function(leaderboardData)
        cb(leaderboardData)
    end)
end)

-- Player stats callback
RegisterNUICallback('getPlayerStats', function(data, cb)
    QBCore.Functions.TriggerCallback('lockdown:getPlayerStats', function(statsData)
        cb(statsData)
    end)
end)

-- Contract system callbacks
RegisterNUICallback('getContracts', function(data, cb)
    QBCore.Functions.TriggerCallback('lockdown:getAvailableContracts', function(contracts)
        cb(contracts)
    end)
end)

RegisterNUICallback('acceptContract', function(data, cb)
    local contractId = data.contractId
    
    QBCore.Functions.TriggerCallback('lockdown:acceptContract', function(success, contractDetails)
        if success then
            contractActive = true
            contractData = contractDetails
        end
        cb({success = success, contract = contractDetails})
    end, contractId)
end)

-- Join Lockdown event
RegisterNUICallback("joinLockdown", function(data, cb)
    local joinType = data.type -- "solo" or "gang"
    local gangId = data.gangId or nil
    
    if Config.CheckInventory then 
        local inventory = exports.ox_inventory:GetPlayerItems()
        if inventory and #inventory > 0 then 
            ShowNotification(Config.Language.ClearInventory)
            cb({success = false})
        else
            TriggerServerEvent('lockdown:joinRequest', joinType, gangId)
            cb({success = true})
        end
    else
        TriggerServerEvent('lockdown:joinRequest', joinType, gangId)
        cb({success = true})
    end
end)

-- Leave lobby event
RegisterNUICallback("leaveLobby", function(data, cb)
    LeaveLobby()
    cb({})
end)

function LeaveLobby()
    SetNuiFocus(false, false)
    DestroyCam(cam, false)
    ClearFocus()
    RenderScriptCams(false, false, 0, true, false)
    SetTimecycleModifier(0)
    NetworkEndTutorialSession()
    lockdownLobby = false
    if coordsBefore then
        SetEntityCoords(PlayerPedId(), coordsBefore.x, coordsBefore.y, coordsBefore.z)
    end
    TriggerServerEvent('lockdown:leaveLobby')
    ShowNotification(Config.Language.LobbyLeft)
end

-- Lobby camera control thread
Citizen.CreateThread(function()
    while true do 
        Citizen.Wait(0)
        if DoesCamExist(cam) then
            SetUseHiDof()
        end
        if lockdownLobby then 
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 32, true)
            DisableControlAction(0, 33, true)
        else
            Citizen.Wait(480)
        end
    end
end)

function StartLobbyCamera(fov)
    fov = fov or 68
    -- Set the player to a nice camera viewing position
    SetEntityCoords(PlayerPedId(), 152.539, -736.085, 254.0285 - 1)
    FreezeEntityPosition(PlayerPedId(), true)
    SetEntityHeading(PlayerPedId(), 157.48512268066)
    SetTimecycleModifier(0)  
    cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", 149.7498, -745.1551, 254.1521 + 0.08, 0, 90, 0, fov * 0.38)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 0, true, true)
    PointCamAtEntity(cam, PlayerPedId(), 0, 0, 0, true)
    SetCamUseShallowDofMode(cam, true)
    SetCamNearDof(cam, 0.7)
    SetCamFarDof(cam, 6.8)
    SetCamDofStrength(cam, 0.28)
    SetCamAffectsAiming(cam, false)
    ShakeCam(cam, "FAMILY5_DRUG_TRIP_SHAKE", 0.02)
    ClearFocus()
    Citizen.Wait(800)
    FreezeEntityPosition(PlayerPedId(), false)
end

function ShowNotification(message, duration)
    duration = duration or 4800
    BeginTextCommandPrint('STRING')
    AddTextComponentString(message)
    EndTextCommandPrint(duration, true)
end

function Draw3DText(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local p = GetGameplayCamCoords()
    local distance = GetDistanceBetweenCoords(p.x, p.y, p.z, x, y, z, 1)
    local scale = (1 / distance) * 0.68
    local fov = (1 / GetGameplayCamFov()) * 100
    local scale = scale * fov 
    if onScreen then
        SetTextScale(0.0, scale)
        SetTextFont(0)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 210)
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- Lockdown join response event
RegisterNetEvent('lockdown:joinResponse')
AddEventHandler('lockdown:joinResponse', function(response, playerCount, maxPlayers, zoneData)
    if response == 'joined' then 
        ShowNotification(Config.Language.Joined, 4800)
        if zoneData then
            CurrentZone = zoneData
            ZoneCoords = {x = zoneData.center.x, y = zoneData.center.y, z = zoneData.center.z}
            radius = zoneData.radius
        end
    elseif response == 'zone_full' then
        ShowNotification(Config.Language.ZoneFull, 4800) 
    elseif response == 'already_joined' then
        ShowNotification(Config.Language.AlreadyJoined, 4800) 
    elseif response == 'in_progress' then
        ShowNotification(Config.Language.InProgress, 4800) 
    end
end)

-- Start Lockdown event
RegisterNetEvent('lockdown:start')
AddEventHandler('lockdown:start', function(zoneData, contract)
    SetNuiFocus(false, false)
    DestroyCam(cam, false)
    spawnedObjects = 0
    ClearFocus()
    RenderScriptCams(false, false, 0, true, false)
    SetTimecycleModifier(0)
    NetworkEndTutorialSession()
    lockdownLobby = false
    
    if Config.CheckInventory then 
        local inventory = exports.ox_inventory:GetPlayerItems()
        if inventory and #inventory > 0 then 
            ShowNotification(Config.Language.GameNotInvClear, 4800)
            TriggerServerEvent('lockdown:leaveZone')
            return
        end
    end
    
    -- Initialize contract if provided
    if contract then
        contractActive = true
        contractData = contract
    end
    
    -- Record match participation
    TriggerServerEvent('lockdown:recordParticipation')
    
    -- Set current zone
    if zoneData then
        CurrentZone = zoneData
        ZoneCoords = {x = zoneData.center.x, y = zoneData.center.y, z = zoneData.center.z}
        radius = zoneData.radius
    end
    
    -- Show start notification
    SendNUIMessage({
        type = 'text',
        text = Config.Language.Started
    })
    
    -- Initialize HUD
    SendNUIMessage({
        type = 'ui',
        zone = CurrentZone.name
    })
    
    -- Set player in Lockdown
    InLockdown = true
    wantedLevel = Config.PoliceAI.InitialWantedLevel
    
    -- Start player insertion via plane or helicopter
    StartPlayerInsertion()
    
    -- Spawn loot objects in the zone
    SpawnLootInZone()
    
    -- Initialize extraction points (they'll become active later)
    InitializeExtractionPoints()
    
    -- Spawn AI police units based on initial wanted level
    SpawnPoliceUnits(wantedLevel)
end)

function StartPlayerInsertion()
    -- Similar to the battle royale plane entry, but themed for an urban infiltration
    local modelHash = GetHashKey('titan') -- Could be replaced with a helicopter for urban theme
    local pedHash = GetHashKey('mp_s_m_armoured_01')
    
    RequestModel(modelHash)
    RequestModel(pedHash)
    while not HasModelLoaded(modelHash) or not HasModelLoaded(pedHash) do Wait(1) end
    
    local veh = CreateVehicle(modelHash, -1768.862, 3403.86, 380.845, 146.34014892578, false, false)
    SetVehicleFuelLevel(veh, 80.0)
    while not DoesEntityExist(veh) do Wait(1) end
    SetVehicleOnGroundProperly(veh)
    SetVehicleEngineOn(veh, true, true, true)
    SetEntityProofs(veh, true, true, true, true, true, true, true, false)
    
    local ped = CreatePedInsideVehicle(veh, 6, pedHash, -1, false, false)
    SetPedIntoVehicle(PlayerPedId(), veh, 1)
    GiveWeaponToPed(PlayerPedId(), GetHashKey('gadget_parachute'), 1, false, true)
    while not DoesEntityExist(ped) do Wait(1) end
    SetBlockingOfNonTemporaryEvents(ped, true)
    
    -- Set a flight path toward the lockdown zone
    TaskPlaneMission(ped, veh, 0, 0, ZoneCoords.x, ZoneCoords.y, ZoneCoords.z + 300, 4, 100.0, 100.0, 270.0, 2000.0, 400.0)
end

function SpawnLootInZone()
    -- Request models for loot objects
    for _, lootType in pairs(Config.LootTypes) do
        RequestModel(GetHashKey(lootType.prop))
        while not HasModelLoaded(GetHashKey(lootType.prop)) do 
            Citizen.Wait(15)
        end
    end
    
    -- Spawn loot objects throughout the zone
    local lootDensity = CurrentZone.lootDensity or 1.0
    local totalLoot = math.floor(600 * lootDensity) -- Adjusted based on zone
    
    while spawnedObjects < totalLoot do
        Citizen.Wait(0)
        
        -- Generate a random coordinate
        local lootCoords = GenerateLootCoords()
        
        -- Determine which loot to spawn based on rarity
        local rand = math.random()
        local selectedLoot = nil
        
        for _, lootType in pairs(Config.LootTypes) do
            if rand <= lootType.rarity then
                selectedLoot = lootType
                break
            end
            rand = rand - lootType.rarity
        end
        
        if not selectedLoot then
            selectedLoot = Config.LootTypes[1] -- Default to first loot type if none selected
        end
        
        -- Create the loot object
        local lootObject = CreateObject(GetHashKey(selectedLoot.prop), lootCoords.x, lootCoords.y, lootCoords.z + 0.48, false, true, true)
        FreezeEntityPosition(lootObject, true)
        table.insert(lootObjects, {
            object = lootObject,
            lootType = selectedLoot.name
        })
        spawnedObjects = spawnedObjects + 1
        
        -- Add a second object nearby (similar to the original code's approach)
        if spawnedObjects < totalLoot then
            -- Select another random loot type
            rand = math.random()
            selectedLoot = nil
            
            for _, lootType in pairs(Config.LootTypes) do
                if rand <= lootType.rarity then
                    selectedLoot = lootType
                    break
                end
                rand = rand - lootType.rarity
            end
            
            if not selectedLoot then
                selectedLoot = Config.LootTypes[1]
            end
            
            local lootObject2 = CreateObject(GetHashKey(selectedLoot.prop), lootCoords.x + 0.48, lootCoords.y, lootCoords.z + 0.48, false, true, true)
            FreezeEntityPosition(lootObject2, true)
            table.insert(lootObjects, {
                object = lootObject2,
                lootType = selectedLoot.name
            })
            spawnedObjects = spawnedObjects + 1
        end
    end
end

function GenerateLootCoords()
    while true do
        Citizen.Wait(0)
        local coordX, coordY
        
        math.randomseed(GetGameTimer())
        local modX = math.random(-math.floor(radius), math.floor(radius))
        
        Citizen.Wait(8)
        
        math.randomseed(GetGameTimer())
        local modY = math.random(-math.floor(radius), math.floor(radius))
        
        coordX = ZoneCoords.x + modX
        coordY = ZoneCoords.y + modY
        
        local coordZ = GetCoordZ(coordX, coordY)
        local coord = vector3(coordX, coordY, coordZ)
        
        if IsCoordValid(coord) then
            return coord
        end
    end
end

function IsCoordValid(coord)
    if spawnedObjects > 0 then
        local validate = true
        
        -- Check if the coordinate is too close to existing loot
        for _, loot in pairs(lootObjects) do
            if GetDistanceBetweenCoords(coord, GetEntityCoords(loot.object), true) < 10 then
                validate = false
                break
            end
        end
        
        -- Check if the coordinate is within the zone
        if GetDistanceBetweenCoords(coord, ZoneCoords.x, ZoneCoords.y, ZoneCoords.z, false) > radius then
            validate = false
        end
        
        return validate
    else
        return true
    end
end

function GetCoordZ(x, y)
    local groundCheckHeights = {28.0, 29.0, 30.0, 31.0, 32.0, 32.9, 33.0, 34.0, 35.0, 36.0, 37.0, 38.0, 39.0, 40.0}
    
    for i, height in ipairs(groundCheckHeights) do
        local foundGround, z = GetGroundZFor_3dCoord(x, y, height)
        
        if foundGround then
            return z
        end
    end
    
    return 43.0 -- Default height if ground not found
end

function InitializeExtractionPoints()
    for i, extraction in ipairs(Config.ExtractionPoints) do
        local point = {
            coords = extraction.coords,
            name = extraction.name,
            type = extraction.type,
            requiredItems = extraction.requiredItems,
            active = false
        }
        
        table.insert(extractionPoints, point)
    end
    
    -- Set a timer to activate extraction points
    Citizen.SetTimeout(Config.ExtractionDelay * 60000, function()
        ActivateExtractionPoints()
    end)
end

function ActivateExtractionPoints()
    for i, point in ipairs(extractionPoints) do
        point.active = true
    end
    
    SendNUIMessage({
        type = 'text',
        text = Config.Language.ExtractionActive
    })
    
    -- Create blips for extraction points
    for i, point in ipairs(extractionPoints) do
        local blip = AddBlipForCoord(point.coords.x, point.coords.y, point.coords.z)
        SetBlipSprite(blip, 358) -- Extraction point sprite
        SetBlipColour(blip, 2) -- Green
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(point.name)
        EndTextCommandSetBlipName(blip)
        
        -- Store the blip to remove it later
        table.insert(playerBlips, blip)
    end
end

function SpawnPoliceUnits(level)
    -- Clear any existing police units
    for _, unit in ipairs(policeUnits) do
        if DoesEntityExist(unit.ped) then
            DeleteEntity(unit.ped)
        end
        if DoesEntityExist(unit.vehicle) then
            DeleteEntity(unit.vehicle)
        end
    end
    policeUnits = {}
    
    -- Determine how many units to spawn based on wanted level
    local unitCount = level * 2
    
    for i = 1, unitCount do
        -- Generate a position at the edge of the zone
        local angle = math.random() * 2 * math.pi
        local distance = radius * 0.8 -- Spawn inside the zone but near the edge
        local x = ZoneCoords.x + math.cos(angle) * distance
        local y = ZoneCoords.y + math.sin(angle) * distance
        local z = GetCoordZ(x, y)
        
        -- Choose random police model
        local modelIndex = math.random(1, #Config.PoliceAI.Models)
        local modelName = Config.PoliceAI.Models[modelIndex]
        local modelHash = GetHashKey(modelName)
        
        -- Request the model
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do
            Citizen.Wait(1)
        end
        
        -- Create the police ped
        local ped = CreatePed(4, modelHash, x, y, z, 0.0, true, false)
        
        -- Setup the ped
        SetPedArmour(ped, 100)
        SetPedAccuracy(ped, 50 + (level * 10)) -- Accuracy increases with wanted level
        SetPedCombatAttributes(ped, 46, true)
        SetPedCombatAttributes(ped, 5, true)
        SetPedCombatAttributes(ped, 0, true)
        SetPedCombatRange(ped, 2)
        SetPedRelationshipGroupHash(ped, GetHashKey("SECURITY_GUARD"))
        GiveWeaponToPed(ped, GetHashKey("WEAPON_PISTOL"), 250, false, true)
        
        -- Add to police units list
        table.insert(policeUnits, {
            ped = ped,
            vehicle = nil
        })
        
        -- Every other unit gets a vehicle
        if i % 2 == 0 then
            -- Choose random police vehicle
            local vehicleIndex = math.random(1, #Config.PoliceAI.Vehicles)
            local vehicleName = Config.PoliceAI.Vehicles[vehicleIndex]
            local vehicleHash = GetHashKey(vehicleName)
            
            -- Request the model
            RequestModel(vehicleHash)
            while not HasModelLoaded(vehicleHash) do
                Citizen.Wait(1)
            end
            
            -- Find a suitable road position
            local roadPosition = GetPointOnRoadSide(x, y, z)
            
            -- Create the vehicle
            local vehicle = CreateVehicle(vehicleHash, roadPosition.x, roadPosition.y, roadPosition.z, 0.0, true, false)
            SetVehicleOnGroundProperly(vehicle)
            
            -- Put the ped in the vehicle
            SetPedIntoVehicle(ped, vehicle, -1)
            
            -- Task the ped to drive around
            TaskVehicleDriveWander(ped, vehicle, 20.0, 786603)
            
            -- Update the police unit
            policeUnits[#policeUnits].vehicle = vehicle
        else
            -- Task the ped to patrol on foot
            TaskWanderStandard(ped, 10.0, 10)
        end
    end
    
    -- Set up relationship with player
    SetRelationshipBetweenGroups(5, GetHashKey("SECURITY_GUARD"), GetHashKey("PLAYER"))
    SetRelationshipBetweenGroups(5, GetHashKey("PLAYER"), GetHashKey("SECURITY_GUARD"))
end

function GetPointOnRoadSide(x, y, z)
    local outPosition = vector3(0.0, 0.0, 0.0)
    local roadPosition = vector3(0.0, 0.0, 0.0)
    local roadSide = 0
    local enteringRoad = false
    
    -- Try to find the closest vehicle node
    if GetClosestVehicleNode(x, y, z, roadPosition, 1, 3.0, 0) then
        -- Adjust position to the side of the road
        local direction = normalize(vector3(x, y, z) - roadPosition)
        outPosition = roadPosition + (direction * 5.0) -- 5 meters from the road
        return outPosition
    else
        -- If no road found, return the original position
        return vector3(x, y, z)
    end
end

function normalize(v)
    local length = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    if length == 0 then
        return vector3(0.0, 0.0, 0.0)
    else
        return vector3(v.x / length, v.y / length, v.z / length)
    end
end

-- Update police presence based on time
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000) -- Check every minute
        
        if InLockdown then
            local timeInZone = GetGameTimer() - startTime
            local minutes = timeInZone / 60000
            
            -- Check if we need to increase the wanted level
            for _, increase in ipairs(Config.PoliceAI.WantedLevelIncrease) do
                if minutes >= increase.time and wantedLevel < increase.level then
                    wantedLevel = increase.level
                    ShowNotification("Police presence increasing...")
                    SpawnPoliceUnits(wantedLevel)
                    break
                end
            end
        else
            Citizen.Wait(5000)
        end
    end
end)

-- Loot interaction thread
Citizen.CreateThread(function()
    local sleep = 800
    while true do 
        Citizen.Wait(sleep)
        if InLockdown then 
            local nearLoot = false
            
            for i, lootData in pairs(lootObjects) do
                if DoesEntityExist(lootData.object) then
                    local lootCoords = GetEntityCoords(lootData.object)
                    local distance = GetDistanceBetweenCoords(GetEntityCoords(PlayerPedId()), lootCoords, true)
                    
                    if distance < 12 then
                        SetEntityDrawOutline(lootData.object, true)
                        SetEntityDrawOutlineColor(255, 255, 255, 188)
                        SetEntityDrawOutlineShader(1)
                    else
                        SetEntityDrawOutline(lootData.object, false)
                    end
                    
                    if distance < 2 then 
                        sleep = 0
                        nearLoot = true
                        
                        -- Find which loot type this is
                        local lootType = nil
                        for _, config in pairs(Config.LootTypes) do
                            if lootData.lootType == config.name then
                                lootType = config
                                break
                            end
                        end
                        
                        if lootType then
                            Draw3DText(lootCoords.x, lootCoords.y, lootCoords.z - 0.08, Config.Language.Open .. lootType.label)
                            
                            if IsControlJustPressed(0, 38) then
                                if Config.LootSound then 
                                    SendNUIMessage({
                                        type = 'loot'
                                    })
                                end
                                
                                if lootType.name == "energy_drink" then
                                    -- Handle energy drink directly
                                    energyLevel = math.min(100, energyLevel + 20)
                                    ShowNotification('~o~+1~w~ ' .. lootType.label, 1480)
                                else
                                    -- Add other items to inventory
                                    TriggerServerEvent('lockdown:addLoot', lootType.name, lootType)
                                    ShowNotification('~o~+1~w~ ' .. lootType.label, 1480)
                                end
                                
                                -- Remove the loot object
                                DeleteEntity(lootData.object)
                                table.remove(lootObjects, i)
                            end
                        end
                        break
                    end
                end
            end
            
            if not nearLoot then
                -- Check extraction points
                for i, point in ipairs(extractionPoints) do
                    if point.active then
                        local distance = GetDistanceBetweenCoords(GetEntityCoords(PlayerPedId()), point.coords, true)
                        
                        if distance < 3.0 then
                            sleep = 0
                            Draw3DText(point.coords.x, point.coords.y, point.coords.z, "[E] - Extract via " .. point.name)
                            
                            if IsControlJustPressed(0, 38) then
                                -- Start extraction process
                                StartExtraction(point)
                            end
                            break
                        end
                    end
                end
                
                sleep = 800
            end
        else
            sleep = 1000
        end
    end
end)

-- Variable to track extraction progress
local extracting = false
local extractionProgress = 0
local currentExtractionPoint = nil

function StartExtraction(point)
    if extracting then return end
    
    extracting = true
    currentExtractionPoint = point
    extractionProgress = 0
    
    -- Broadcast extraction attempt to other players
    TriggerServerEvent('lockdown:startExtraction', point.name)
    
    ShowNotification(Config.Language.ExtractionStarted)
    
    -- Start extraction progress loop
    Citizen.CreateThread(function()
        local extractTime = Config.ExtractTime
        
        -- Check if player has intel item to reduce extraction time
        if point.requiredItems then
            for _, item in ipairs(point.requiredItems) do
                if item.reduce_time then
                    -- Check if player has the item
                    QBCore.Functions.TriggerCallback('lockdown:hasItem', function(hasItem)
                        if hasItem then
                            extractTime = extractTime - item.reduce_time
                            if extractTime < 3 then extractTime = 3 end -- Minimum 3 seconds
                            ShowNotification("Intel allows for faster extraction!")
                        end
                    end, item.name)
                end
            end
        end
        
        while extracting do
            Citizen.Wait(1000)
            
            -- Check if player is still near extraction point
            local distance = GetDistanceBetweenCoords(GetEntityCoords(PlayerPedId()), currentExtractionPoint.coords, true)
            if distance > 3.0 then
                -- Player moved away, cancel extraction
                extracting = false
                ShowNotification(Config.Language.ExtractionInterrupted)
                break
            end
            
            -- Update extraction progress
            extractionProgress = extractionProgress + (1 / extractTime)
            
            -- Display progress
            SendNUIMessage({
                type = 'extraction',
                progress = extractionProgress * 100
            })
            
            -- Check if extraction complete
            if extractionProgress >= 1.0 then
                -- Extraction complete
                CompleteExtraction()
                break
            end
        end
    end)
end

function CompleteExtraction()
    extracting = false
    
    -- Notify server of successful extraction
    TriggerServerEvent('lockdown:completeExtraction', currentExtractionPoint.name)
    
    -- Display success message
    SendNUIMessage({
        type = 'text',
        text = Config.Language.Victory
    })
    
    -- Cleanup
    InLockdown = false
    currentExtractionPoint = nil
    
    -- Cleanup extraction points and blips
    for _, blip in pairs(playerBlips) do
        RemoveBlip(blip)
    end
    playerBlips = {}
    
    -- Cleanup loot objects
    for _, lootData in pairs(lootObjects) do
        if DoesEntityExist(lootData.object) then
            DeleteEntity(lootData.object)
        end
    end
    lootObjects = {}
    
    -- Cleanup police units
    for _, unit in pairs(policeUnits) do
        if DoesEntityExist(unit.ped) then
            DeleteEntity(unit.ped)
        end
        if DoesEntityExist(unit.vehicle) then
            DeleteEntity(unit.vehicle)
        end
    end
    policeUnits = {}
    
    -- Return player to original position after a delay
    Citizen.SetTimeout(4800, function()
        SendNUIMessage({
            type = 'uihide',
        })
        
        SetEntityCoords(PlayerPedId(), coordsBefore.x, coordsBefore.y, coordsBefore.z)
    end)
end

-- Zone radius contraction thread (similar to the battle royale shrinking zone)
Citizen.CreateThread(function()
    while true do 
        Citizen.Wait(80)
        if InLockdown then 
            if radius >= 0.4 then 
                radius = radius - 0.1     
            end
        end
    end
end)

-- Energy drink effect thread
Citizen.CreateThread(function()
    while true do 
        Citizen.Wait(1000)
        if InLockdown then 
            if energyLevel >= 1 then 
                SendNUIMessage({
                    type = 'energy',
                    level = energyLevel  
                })
                energyLevel = energyLevel - 1
            end
            
            -- Apply effects based on energy level
            if energyLevel > 0 then
                SetRunSprintMultiplierForPlayer(PlayerId(), 1.12)
            else
                SetRunSprintMultiplierForPlayer(PlayerId(), 1.00)
            end
            
            -- Health regeneration if energy level is high
            if energyLevel > 49 then 
                if GetEntityHealth(PlayerPedId()) < GetEntityMaxHealth(PlayerPedId()) then 
                    SetEntityHealth(PlayerPedId(), GetEntityHealth(PlayerPedId()) + 4)
                end
            end
        end
    end
end)

-- Damage when outside the zone
Citizen.CreateThread(function()
    while true do 
        Citizen.Wait(1000)
        if InLockdown then 
            if GetDistanceBetweenCoords(GetEntityCoords(PlayerPedId()), ZoneCoords.x, ZoneCoords.y, ZoneCoords.z) >= radius then 
                SetEntityHealth(PlayerPedId(), GetEntityHealth(PlayerPedId()) - 20)
            end
            
            -- Handle player death
            if IsEntityDead(PlayerPedId()) then
                local entity = GetPedSourceOfDeath(PlayerPedId())
                if entity ~= 0 and canAddKill then 
                    local id = GetPlayerServerId(NetworkGetEntityOwner(entity))
                    TriggerServerEvent('lockdown:playerKilled', id)
                    canAddKill = false
                end
                
                -- Notify server that player has been eliminated
                TriggerServerEvent('lockdown:leaveZone')
                
                -- Revive player if configured
                if Config.RevivePlayerAfterDeath then 
                    Citizen.Wait(8800)
                    TriggerEvent('hospital:client:Revive', GetPlayerServerId(PlayerId()))
                end
            else
                canAddKill = true
            end
        end
    end
end)

-- Command to manually leave the Lockdown zone
RegisterCommand('leavelockdown', function()
    if InLockdown then 
        SetRunSprintMultiplierForPlayer(PlayerId(), 1.00)
        TriggerServerEvent('lockdown:leaveZone')
        InLockdown = false
        SendNUIMessage({
            type = 'uihide',
        })
        
        -- Return to original coordinates
        if coordsBefore then
            SetEntityCoords(PlayerPedId(), coordsBefore.x, coordsBefore.y, coordsBefore.z)
        end
        
        -- Cleanup loot objects
        for _, lootData in pairs(lootObjects) do
            if DoesEntityExist(lootData.object) then
                DeleteEntity(lootData.object)
            end
        end
        lootObjects = {}
    end
end, false)

-- Draw zone boundary
Citizen.CreateThread(function()
    while true do 
        Citizen.Wait(0)
        if InLockdown then 
            DrawMarker(28, ZoneCoords.x, ZoneCoords.y, ZoneCoords.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, radius, radius, radius, 0, 0, 255, 100, false, true, 2, false, false, false, false)
        else
            Citizen.Wait(800)
        end
    end
end)

-- Event handlers for player count and kills
RegisterNetEvent('lockdown:addKill')
AddEventHandler('lockdown:addKill', function()
    kills = kills + 1
    if InLockdown then 
        SendNUIMessage({
            type = 'ui',
            Kills = kills
        })
    end
end)

RegisterNetEvent('lockdown:playerCount')
AddEventHandler('lockdown:playerCount', function(players)
    playersInZone = players 
    if InLockdown then 
        SendNUIMessage({
            type = 'ui',
            Playersingame = playersInZone
        })
    end
end)

-- Event for when player is eliminated
RegisterNetEvent('lockdown:eliminated')
AddEventHandler('lockdown:eliminated', function()
    if InLockdown then 
        SendNUIMessage({
            type = 'text',
            text = Config.Language.Eliminated
        })
        Citizen.Wait(4800)
        SendNUIMessage({
            type = 'uihide',
        })
        
        InLockdown = false
        
        -- Return to original coordinates
        if coordsBefore then
            SetEntityCoords(PlayerPedId(), coordsBefore.x, coordsBefore.y, coordsBefore.z)
        end
        
        -- Cleanup loot objects
        for _, lootData in pairs(lootObjects) do
            if DoesEntityExist(lootData.object) then
                DeleteEntity(lootData.object)
            end
        end
        lootObjects = {}
        
        -- Revive player if configured
        if Config.RevivePlayerAfterDeath then 
            Citizen.Wait(800)
            TriggerEvent('hospital:client:Revive', GetPlayerServerId(PlayerId()))
        end
    end
end)

-- Event for notifications
RegisterNetEvent('lockdown:notification')
AddEventHandler('lockdown:notification', function(message)
    ShowNotification(message, 4800) 
end)

-- Contract completion event
RegisterNetEvent('lockdown:contractCompleted')
AddEventHandler('lockdown:contractCompleted', function(reward)
    contractActive = false
    contractData = nil
    
    ShowNotification("Contract completed! Reward: $" .. reward, 4800)
    
    -- Play a success sound
    PlaySoundFrontend(-1, "Mission_Pass_Notify", "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", 0)
end)