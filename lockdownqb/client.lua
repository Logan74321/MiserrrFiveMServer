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
local activeExtractionPoint = nil
local extractionActive = false
local extractionTimeRemaining = 0
local contractActive = false
local contractData = nil
local policeUnits = {}
local wantedLevel = 0
local playerBlips = {}
local startTime = 0
local joinWindowActive = false
local extractionsCount = 0
local maxExtractions = 4

-- Check for join window status on script start
CreateThread(function()
    QBCore.Functions.TriggerCallback('lockdown:isJoinWindowOpen', function(isOpen)
        joinWindowActive = isOpen
    end)
end)

-- Listen for key presses (Enter key for joining)
CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        -- Check for Enter key press when popup shows
        if joinWindowActive and not InLockdown and not lockdownLobby then
            if IsControlJustPressed(0, 18) then -- 18 is Enter key
                OpenLockdownMenu()
            end
            
            -- Show instruction text
            SetTextComponentFormat("STRING")
            AddTextComponentString("Press ~INPUT_ENTER~ to join Lockdown Protocol")
            DisplayHelpTextFromStringLabel(0, 0, 1, -1)
        else
            Citizen.Wait(500)
        end
    end
end)

-- Register the command to open the Lockdown menu (admin only)
RegisterCommand(Config.CommandName, function()
    if IsPlayerAceAllowed(PlayerId(), "command.lockdown") then
        OpenLockdownMenu()
    else
        ShowNotification("You don't have permission to use this command.")
    end
end, false)

-- Function to open the Lockdown menu
function OpenLockdownMenu()
    if not InLockdown and joinWindowActive then
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
                    
                    -- Show notification for lockdown protocol
                    TriggerEvent('lockdown:showNotification', 'Lockdown Protocol activated. Join a match now!', 'warning')
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
                
                -- Show notification for lockdown protocol
                TriggerEvent('lockdown:showNotification', 'Lockdown Protocol activated. Join a match now!', 'warning')
            end
        end)
    elseif not joinWindowActive then
        ShowNotification("Lockdown Protocol is not active right now.")
    end
end

-- Add enhanced notification system
RegisterNetEvent('lockdown:showNotification')
AddEventHandler('lockdown:showNotification', function(message, type)
    type = type or 'info'
    
    SendNUIMessage({
        type = 'notification',
        message = message,
        notificationType = type
    })
    
    -- Also show default notification for backup
    ShowNotification(message)
end)

-- Event to handle lockdown announcement
RegisterNetEvent('lockdown:announceProtocol')
AddEventHandler('lockdown:announceProtocol', function(zoneName)
    -- Set join window active
    joinWindowActive = true
    
    -- Show big notification
    SendNUIMessage({
        type = 'lockdownAnnouncement',
        zoneName = zoneName
    })
    
    -- Play alert sound
    PlaySoundFrontend(-1, "Beep_Red", "DLC_HEIST_HACKING_SNAKE_SOUNDS", false)
    Citizen.Wait(500)
    PlaySoundFrontend(-1, "Beep_Red", "DLC_HEIST_HACKING_SNAKE_SOUNDS", false)
    
    -- Flash screen briefly
    StartScreenEffect("FocusIn", 0, false)
    Citizen.Wait(1000)
    StopScreenEffect("FocusIn")
    
    TriggerEvent('lockdown:showNotification', "⚠️ LOCKDOWN INITIATED IN " .. zoneName .. "! Press ENTER to join", 'warning')
end)

-- Event to handle join window closing
RegisterNetEvent('lockdown:closeJoinWindow')
AddEventHandler('lockdown:closeJoinWindow', function()
    joinWindowActive = false
    
    if lockdownLobby then
        -- If player is in lobby but didn't join, kick them out
        LeaveLobby()
    end
})

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
    SetTimecycleModifier("")
    NetworkEndTutorialSession()
    lockdownLobby = false
    if coordsBefore then
        SetEntityCoords(PlayerPedId(), coordsBefore.x, coordsBefore.y, coordsBefore.z)
    end
    TriggerServerEvent('lockdown:leaveLobby')
    ShowNotification(Config.Language.LobbyLeft)
}

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
            
            -- Add backspace to exit
            if IsControlJustPressed(0, 177) then -- 177 is backspace
                LeaveLobby()
            end
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
    SetTimecycleModifier("hud_def_blur")  -- Add slight blur effect
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
}

function ShowNotification(message, duration)
    duration = duration or 4800
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(true, true)
}

function Draw3DText(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local p = GetGameplayCamCoords()
    local distance = #(p - vector3(x, y, z))
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
}

-- Lockdown join response event
RegisterNetEvent('lockdown:joinResponse')
AddEventHandler('lockdown:joinResponse', function(response, playerCount, maxPlayers, zoneData)
    if response == 'joined' then 
        TriggerEvent('lockdown:showNotification', Config.Language.Joined, 'success')
        if zoneData then
            CurrentZone = zoneData
            ZoneCoords = {x = zoneData.center.x, y = zoneData.center.y, z = zoneData.center.z}
            radius = zoneData.radius
        end
    elseif response == 'zone_full' then
        TriggerEvent('lockdown:showNotification', Config.Language.ZoneFull, 'error')
    elseif response == 'already_joined' then
        TriggerEvent('lockdown:showNotification', Config.Language.AlreadyJoined, 'error')
    elseif response == 'in_progress' then
        TriggerEvent('lockdown:showNotification', Config.Language.InProgress, 'error')
    elseif response == 'window_closed' then
        TriggerEvent('lockdown:showNotification', "The join window has closed. Wait for the next Lockdown announcement.", 'error')
        LeaveLobby()
    end
})

-- Start Lockdown event
RegisterNetEvent('lockdown:start')
AddEventHandler('lockdown:start', function(zoneData, contract, spawnPoint)
    SetNuiFocus(false, false)
    DestroyCam(cam, false)
    spawnedObjects = 0
    ClearFocus()
    RenderScriptCams(false, false, 0, true, false)
    SetTimecycleModifier("")
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
    extractionsCount = 0
    wantedLevel = Config.PoliceAI.InitialWantedLevel
    startTime = GetGameTimer()
    
    -- Set wanted level
    SetPlayerWantedLevel(PlayerId(), wantedLevel, false)
    SetPlayerWantedLevelNow(PlayerId(), false)
    
    -- Reset extraction points
    extractionPoints = {}
    activeExtractionPoint = nil
    
    -- Spawn the player at the provided spawn point
    if spawnPoint then
        -- Teleport the player to spawn point
        SetEntityCoords(PlayerPedId(), spawnPoint.x, spawnPoint.y, spawnPoint.z)
        
        -- Give starting weapons
        GiveWeaponToPed(PlayerPedId(), GetHashKey("WEAPON_PISTOL"), 30, false, true)
        
        -- Wait a moment before proceeding
        Citizen.Wait(500)
    end
    
    -- Spawn loot objects in the zone
    SpawnLootInZone()
    
    -- Spawn AI police units based on initial wanted level
    SpawnPoliceUnits(wantedLevel)
})

-- Event to activate an extraction point
RegisterNetEvent('lockdown:activateExtractionPoint')
AddEventHandler('lockdown:activateExtractionPoint', function(extraction, duration)
    if not InLockdown then return end
    
    -- Increment extraction count
    extractionsCount = extractionsCount + 1
    
    -- Store extraction point
    activeExtractionPoint = extraction
    extractionActive = true
    extractionTimeRemaining = duration
    
    -- Create blip
    local blip = AddBlipForCoord(extraction.coords.x, extraction.coords.y, extraction.coords.z)
    SetBlipSprite(blip, 358) -- Extraction point sprite
    SetBlipColour(blip, 2) -- Green
    SetBlipAsShortRange(blip, false)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(extraction.name .. " - EXTRACTION POINT")
    EndTextCommandSetBlipName(blip)
    
    -- Store the blip to remove it later
    table.insert(playerBlips, blip)
    
    -- Show notification
    TriggerEvent('lockdown:showNotification', 'Extraction point active: ' .. extraction.name .. ' (' .. duration .. ' seconds)', 'warning')
    
    if extractionsCount >= maxExtractions then
        TriggerEvent('lockdown:showNotification', 'FINAL EXTRACTION POINT! Extract now or be eliminated!', 'error')
    end
    
    -- Start timer to deactivate extraction point
    Citizen.SetTimeout(duration * 1000, function()
        extractionActive = false
        activeExtractionPoint = nil
        
        -- Remove extraction blip
        for i, blip in ipairs(playerBlips) do
            RemoveBlip(blip)
        end
        playerBlips = {}
        
        TriggerEvent('lockdown:showNotification', 'Extraction point deactivated!', 'error')
    end)
})

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
}

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
}

function IsCoordValid(coord)
    if spawnedObjects > 0 then
        local validate = true
        
        -- Check if the coordinate is too close to existing loot
        for _, loot in pairs(lootObjects) do
            if #(coord - GetEntityCoords(loot.object)) < 10 then
                validate = false
                break
            end
        end
        
        -- Check if the coordinate is within the zone
        if #(coord - vector3(ZoneCoords.x, ZoneCoords.y, ZoneCoords.z)) > radius then
            validate = false
        end
        
        return validate
    else
        return true
    end
}

function GetCoordZ(x, y)
    local groundCheckHeights = {28.0, 29.0, 30.0, 31.0, 32.0, 32.9, 33.0, 34.0, 35.0, 36.0, 37.0, 38.0, 39.0, 40.0}
    
    for i, height in ipairs(groundCheckHeights) do
        local foundGround, z = GetGroundZFor_3dCoord(x, y, height)
        
        if foundGround then
            return z
        end
    end
    
    return 43.0 -- Default height if ground not found
}

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
        
        -- Make police angrier at higher wanted levels
        if level >= 4 then
            GiveWeaponToPed(ped, GetHashKey("WEAPON_PUMPSHOTGUN"), 50, false, true)
        end
        if level >= 5 then 
            GiveWeaponToPed(ped, GetHashKey("WEAPON_CARBINERIFLE"), 150, false, true)
            SetPedAccuracy(ped, 85)  -- More accurate at 5 stars
        end
        
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
}

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
}

function normalize(v)
    local length = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    if length == 0 then
        return vector3(0.0, 0.0, 0.0)
    else
        return vector3(v.x / length, v.y / length, v.z / length)
    end
}

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
                    TriggerEvent('lockdown:showNotification', "Police presence increasing! Wanted level: " .. wantedLevel .. " stars", 'warning')
                    
                    -- Set player wanted level
                    SetPlayerWantedLevel(PlayerId(), wantedLevel, false)
                    SetPlayerWantedLevelNow(PlayerId(), false)
                    
                    -- Spawn new police units
                    SpawnPoliceUnits(wantedLevel)
                    break
                end
            end
            
            -- Check if we've gone through all extractions
            if extractionsCount >= maxExtractions and not extractionActive then
                -- Increase wanted level to max if all extractions have passed
                wantedLevel = 5
                SetPlayerWantedLevel(PlayerId(), 5, false)
                SetPlayerWantedLevelNow(PlayerId(), false)
                TriggerEvent('lockdown:showNotification', "All extraction windows closed! Police are hunting you down!", 'error')
                SpawnPoliceUnits(5)
            end
        else
            Citizen.Wait(5000)
        end
    end
})

-- Display extraction timer if active
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if InLockdown and extractionActive and activeExtractionPoint and extractionTimeRemaining > 0 then
            -- Draw timer text
            SetTextFont(0)
            SetTextProportional(1)
            SetTextScale(0.5, 0.5)
            SetTextColour(255, 255, 255, 255)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(1, 0, 0, 0, 255)
            SetTextDropShadow()
            SetTextOutline()
            SetTextCentre(true)
            SetTextEntry("STRING")
            AddTextComponentString("EXTRACTION ACTIVE: " .. extractionTimeRemaining .. " SECONDS REMAINING")
            DrawText(0.5, 0.1)
            
            -- Draw 3D marker at extraction point
            DrawMarker(1, activeExtractionPoint.coords.x, activeExtractionPoint.coords.y, activeExtractionPoint.coords.z - 1.0, 0, 0, 0, 0, 0, 0, 5.0, 5.0, 1.0, 0, 255, 0, 200, false, true, 2, nil, nil, false)
        else
            Citizen.Wait(500)
        end
    end
})

-- Update extraction timer
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Update every second
        
        if InLockdown and extractionActive and extractionTimeRemaining > 0 then
            extractionTimeRemaining = extractionTimeRemaining - 1
        end
    end
})

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
                    local distance = #(GetEntityCoords(PlayerPedId()) - lootCoords)
                    
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
                                    TriggerEvent('lockdown:showNotification', '+1 ' .. lootType.label, 'success')
                                else
                                    -- Add other items to inventory
                                    TriggerServerEvent('lockdown:addLoot', lootType.name, lootType)
                                    TriggerEvent('lockdown:showNotification', '+1 ' .. lootType.label, 'success')
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
            
            if not nearLoot and extractionActive and activeExtractionPoint then
                -- Check extraction point
                local distance = #(GetEntityCoords(PlayerPedId()) - activeExtractionPoint.coords)
                
                if distance < 3.0 then
                    sleep = 0
                    Draw3DText(activeExtractionPoint.coords.x, activeExtractionPoint.coords.y, activeExtractionPoint.coords.z, "[E] - Extract via " .. activeExtractionPoint.name)
                    
                    if IsControlJustPressed(0, 38) then
                        -- Start extraction process
                        StartExtraction(activeExtractionPoint)
                    end
                end
            } else {
                sleep = 800
            }
        else
            sleep = 1000
        end
    end
})

-- Variable to track extraction progress
local extracting = false
local extractionProgress = 0

function StartExtraction(point)
    if extracting then return end
    
    extracting = true
    extractionProgress = 0
    
    -- Broadcast extraction attempt to other players
    TriggerServerEvent('lockdown:startExtraction', point.name)
    
    TriggerEvent('lockdown:showNotification', Config.Language.ExtractionStarted, 'info')
    
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
                            TriggerEvent('lockdown:showNotification', "Intel allows for faster extraction!", 'success')
                        end
                    end, item.name)
                end
            end
        end
        
        while extracting do
            Citizen.Wait(1000)
            
            -- Check if player is still near extraction point
            local distance = #(GetEntityCoords(PlayerPedId()) - point.coords)
            if distance > 3.0 then
                -- Player moved away, cancel extraction
                extracting = false
                TriggerEvent('lockdown:showNotification', Config.Language.ExtractionInterrupted, 'error')
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
}

function CompleteExtraction()
    extracting = false
    
    -- Notify server of successful extraction
    TriggerServerEvent('lockdown:completeExtraction', activeExtractionPoint.name)
    
    -- Display success message
    SendNUIMessage({
        type = 'text',
        text = Config.Language.Victory
    })
    
    -- Cleanup
    InLockdown = false
    extractionActive = false
    activeExtractionPoint = nil
    
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
    
    -- Reset wanted level
    SetPlayerWantedLevel(PlayerId(), 0, false)
    SetPlayerWantedLevelNow(PlayerId(), false)
    
    -- Return player to original position after a delay
    Citizen.SetTimeout(4800, function()
        SendNUIMessage({
            type = 'uihide',
        })
        
        if coordsBefore then
            SetEntityCoords(PlayerPedId(), coordsBefore.x, coordsBefore.y, coordsBefore.z)
        end
    end)
}

-- Zone radius contraction thread (similar to the battle royale shrinking zone)
Citizen.CreateThread(function()
    while true do 
        Citizen.Wait(80)
        if InLockdown then 
            if radius > 80.0 then  -- Don't let it collapse completely
                radius = radius - 0.1     
            end
        end
    end
})

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
            }
            
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
})

-- Damage when outside the zone with enhanced police response
Citizen.CreateThread(function()
    while true do 
        Citizen.Wait(1000)
        if InLockdown then 
            -- Check if player is outside the zone
            if #(GetEntityCoords(PlayerPedId()) - vector3(ZoneCoords.x, ZoneCoords.y, ZoneCoords.z)) >= radius then 
                -- Apply damage
                SetEntityHealth(PlayerPedId(), GetEntityHealth(PlayerPedId()) - 20)
                
                -- If outside zone, set to max wanted level
                if wantedLevel < 5 then
                    wantedLevel = 5
                    SetPlayerWantedLevel(PlayerId(), 5, false)
                    SetPlayerWantedLevelNow(PlayerId(), false)
                    TriggerEvent('lockdown:showNotification', "WARNING: Outside the zone! Maximum wanted level.", 'error')
                    
                    -- Spawn extra police units to hunt the player
                    SpawnPoliceUnits(5)
                end
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
})

-- Command to manually leave the Lockdown zone
RegisterCommand('leavelockdown', function()
    if InLockdown then 
        SetRunSprintMultiplierForPlayer(PlayerId(), 1.00)
        TriggerServerEvent('lockdown:leaveZone')
        InLockdown = false
        SendNUIMessage({
            type = 'uihide',
        })
        
        -- Reset wanted level
        SetPlayerWantedLevel(PlayerId(), 0, false)
        SetPlayerWantedLevelNow(PlayerId(), false)
        
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

-- Draw zone boundary with improved visibility
Citizen.CreateThread(function()
    while true do 
        Citizen.Wait(0)
        if InLockdown then 
            -- Draw the zone boundary marker
            DrawMarker(28, ZoneCoords.x, ZoneCoords.y, ZoneCoords.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, radius, radius, radius, 0, 0, 255, 100, false, true, 2, false, false, false, false)
            
            -- Draw a red boundary when player is near the edge
            local playerPos = GetEntityCoords(PlayerPedId())
            local distToCenter = #(playerPos - vector3(ZoneCoords.x, ZoneCoords.y, ZoneCoords.z))
            
            if distToCenter > (radius - 50.0) and distToCenter < radius then
                -- Draw a warning marker when near the edge
                DrawMarker(28, ZoneCoords.x, ZoneCoords.y, ZoneCoords.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, radius, radius, radius, 255, 0, 0, 150, false, true, 2, false, false, false, false)
                
                -- Display warning
                if distToCenter > (radius - 10.0) then
                    SetTextComponentFormat("STRING")
                    AddTextComponentString("~r~WARNING: Zone boundary approaching!")
                    DisplayHelpTextFromStringLabel(0, 0, 1, -1)
                end
            end
        else
            Citizen.Wait(800)
        end
    end
})

-- Event handlers for player count and kills
RegisterNetEvent('lockdown:addKill')
AddEventHandler('lockdown:addKill', function()
    kills = kills + 1
    if InLockdown then 
        SendNUIMessage({
            type = 'ui',
            Kills = kills
        })
        TriggerEvent('lockdown:showNotification', "Kill confirmed: " .. kills .. " total", 'success')
    end
})

RegisterNetEvent('lockdown:playerCount')
AddEventHandler('lockdown:playerCount', function(players)
    playersInZone = players 
    if InLockdown then 
        SendNUIMessage({
            type = 'ui',
            Playersingame = playersInZone
        })
    end
})

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
        
        -- Reset wanted level
        SetPlayerWantedLevel(PlayerId(), 0, false)
        SetPlayerWantedLevelNow(PlayerId(), false)
        
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
})

-- Event for game end
RegisterNetEvent('lockdown:gameEnd')
AddEventHandler('lockdown:gameEnd', function()
    if InLockdown then 
        SendNUIMessage({
            type = 'text',
            text = Config.Language.Victory
        })
        Citizen.Wait(4800)
        SendNUIMessage({
            type = 'uihide',
        })
        
        InLockdown = false
        
        -- Reset wanted level
        SetPlayerWantedLevel(PlayerId(), 0, false)
        SetPlayerWantedLevelNow(PlayerId(), false)
        
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
})

-- Enhanced notification event
RegisterNetEvent('lockdown:notification')
AddEventHandler('lockdown:notification', function(message)
    TriggerEvent('lockdown:showNotification', message, 'info')
})

-- Contract completion event
RegisterNetEvent('lockdown:contractCompleted')
AddEventHandler('lockdown:contractCompleted', function(reward)
    contractActive = false
    contractData = nil
    
    TriggerEvent('lockdown:showNotification', "Contract completed! Reward: $" .. reward, 'success')
    
    -- Play a success sound
    PlaySoundFrontend(-1, "Mission_Pass_Notify", "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", false)
})

-- Event for returning to freemode (used when join window closes without enough players)
RegisterNetEvent('lockdown:returnToFreemode')
AddEventHandler('lockdown:returnToFreemode', function()
    if lockdownLobby then
        LeaveLobby()
    end
    
    if InLockdown then
        SetRunSprintMultiplierForPlayer(PlayerId(), 1.00)
        InLockdown = false
        SendNUIMessage({
            type = 'uihide',
        })
        
        -- Reset wanted level
        SetPlayerWantedLevel(PlayerId(), 0, false)
        SetPlayerWantedLevelNow(PlayerId(), false)
        
        -- Return to original coordinates
        if coordsBefore then
            SetEntityCoords(PlayerPedId(), coordsBefore.x, coordsBefore.y, coordsBefore.z)
        end
    }
})