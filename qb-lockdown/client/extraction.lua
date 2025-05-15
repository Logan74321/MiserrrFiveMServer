-- client/extraction.lua

local QBCore = exports['qb-core']:GetCoreObject()
local ExtractionPoints = {}
local ExtractionVehicles = {}
local IsExtracting = false

-- Init extraction points
RegisterNetEvent('qb-lockdown:client:ActivateExtractions', function(points)
    ExtractionPoints = points
    CreateExtractionPoints()
end)

-- Create extraction points and vehicles
function CreateExtractionPoints()
    -- Remove any existing vehicles
    for _, vehicle in pairs(ExtractionVehicles) do
        if DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
        end
    end
    ExtractionVehicles = {}
    
    -- Loop through extraction points
    for id, point in pairs(ExtractionPoints) do
        -- Create blip
        local blip = AddBlipForCoord(point.coords.x, point.coords.y, point.coords.z)
        SetBlipSprite(blip, 569) -- Extraction type
        SetBlipColour(blip, 2) -- Green
        SetBlipScale(blip, 1.0)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(point.label .. " Extraction")
        EndTextCommandSetBlipName(blip)
        
        point.blip = blip
        
        -- Create vehicle if needed
        if point.vehicleModel and point.vehicleSpawn then
            local hash = GetHashKey(point.vehicleModel)
            RequestModel(hash)
            while not HasModelLoaded(hash) do
                Wait(10)
            end
            
            local vehicle = CreateVehicle(hash, point.vehicleSpawn.x, point.vehicleSpawn.y, point.vehicleSpawn.z, point.vehicleSpawn.w, true, false)
            SetEntityAsMissionEntity(vehicle, true, true)
            SetVehicleDoorsLocked(vehicle, 1) -- Unlocked
            SetVehicleOnGroundProperly(vehicle)
            
            -- Store vehicle reference
            ExtractionVehicles[id] = vehicle
            point.vehicle = vehicle
            
            SetModelAsNoLongerNeeded(hash)
        end
        
        -- Create marker and interaction zone
        CreateThread(function()
            while InGame and CurrentGame do
                Wait(0)
                local playerPed = PlayerPedId()
                local playerCoords = GetEntityCoords(playerPed)
                local distance = #(playerCoords - point.coords)
                
                -- Draw marker
                DrawMarker(1, point.coords.x, point.coords.y, point.coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 5.0, 5.0, 1.0, 0, 255, 0, 100, false, true, 2, false, nil, nil, false)
                
                -- Check distance for interaction
                if distance < 5.0 and not IsExtracting then
                    -- Check if in correct vehicle type if required
                    local canExtract = true
                    local vehicleMessage = ""
                    
                    if point.vehicleModel then
                        canExtract = false
                        vehicleMessage = "Enter the " .. point.label .. " to extract"
                        
                        local vehicle = GetVehiclePedIsIn(playerPed, false)
                        if vehicle > 0 and vehicle == point.vehicle then
                            canExtract = true
                            vehicleMessage = ""
                        end
                    end
                    
                    if canExtract then
                        QBCore.Functions.DrawText3D(point.coords.x, point.coords.y, point.coords.z, "Press ~g~E~w~ to extract")
                        
                        if IsControlJustPressed(0, 38) then -- E key
                            TriggerEvent('qb-lockdown:client:BeginExtraction', id)
                        end
                    else
                        QBCore.Functions.DrawText3D(point.coords.x, point.coords.y, point.coords.z, vehicleMessage)
                    end
                end
            end
        end)
    end
    
    -- Update UI
    SendNUIMessage({
        action = "updateExtractions",
        extractionPoints = ExtractionPoints
    })
    
    QBCore.Functions.Notify("Extraction points are now active!", "success", 5000)
end

-- Begin extraction process
RegisterNetEvent('qb-lockdown:client:BeginExtraction', function(extractionId)
    if IsExtracting or not ExtractionPoints[extractionId] then return end
    
    IsExtracting = true
    local extractionPoint = ExtractionPoints[extractionId]
    
    -- Broadcast to all players
    TriggerServerEvent('qb-lockdown:server:BroadcastExtraction', CurrentGame.id, extractionId)
    
    -- Start progress bar
    QBCore.Functions.Progressbar("extracting", "Extracting...", Config.ExtractTime * 1000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = "mp_arresting",
        anim = "idle",
        flags = 49,
    }, {}, {}, function() -- Done
        -- Complete extraction
        IsExtracting = false
        TriggerServerEvent('qb-lockdown:server:PlayerExtract', CurrentGame.id, extractionId)
    end, function() -- Cancel
        IsExtracting = false
        QBCore.Functions.Notify("Extraction cancelled", "error")
    end)
end)

-- Broadcast extraction attempt
RegisterNetEvent('qb-lockdown:client:BroadcastExtraction', function(extractionId)
    if not InGame or not CurrentGame or not ExtractionPoints[extractionId] then return end
    
    local extractionPoint = ExtractionPoints[extractionId]
    
    QBCore.Functions.Notify("A player is attempting to extract at " .. extractionPoint.label .. "!", "error", 6000)
    
    -- Flash the extraction blip
    if extractionPoint.blip then
        SetBlipFlashes(extractionPoint.blip, true)
        SetTimeout(10000, function()
            if extractionPoint.blip then
                SetBlipFlashes(extractionPoint.blip, false)
            end
        end)
    end
    
    -- Play sound
    TriggerEvent('InteractSound_CL:PlayOnOne', 'alert', 0.5)
end)

-- Clean up extraction points
function CleanupExtractionPoints()
    for _, point in pairs(ExtractionPoints) do
        if point.blip then
            RemoveBlip(point.blip)
        end
    end
    
    for _, vehicle in pairs(ExtractionVehicles) do
        if DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
        end
    end
    
    ExtractionPoints = {}
    ExtractionVehicles = {}
    IsExtracting = false
end

AddEventHandler('qb-lockdown:client:LeaveGame', function()
    CleanupExtractionPoints()
end)