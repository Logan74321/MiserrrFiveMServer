local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()
local CurrentGame = nil
local InGame = false
local WantedLevel = 0
local LootSpots = {}
local ExtractionPoints = {}
local LootDrops = {}
local PlayerLoot = {}

-- Initialize
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    RegisterKeyMapping('lockdownmenu', 'Open Lockdown Protocol Menu', 'keyboard', 'F10')
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
    CurrentGame = nil
    InGame = false
    WantedLevel = 0
    LootSpots = {}
    ExtractionPoints = {}
    LootDrops = {}
    PlayerLoot = {}
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    PlayerData = data
end)

-- Key binding for lockdown menu
RegisterCommand('lockdownmenu', function()
    if not InGame then
        TriggerServerEvent('qb-lockdown:server:RequestGames')
        SetTimeout(100, function()
            OpenLockdownMenu()
        end)
    else
        OpenLockdownGameMenu()
    end
end, false)

-- UI Functions
function OpenLockdownMenu()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "open",
        type = "main"
    })
    
    -- Get player stats
    QBCore.Functions.TriggerCallback('qb-lockdown:server:GetPlayerStats', function(stats)
        SendNUIMessage({
            action = "updateStats",
            stats = stats
        })
    end)
    
    -- Get active games
    QBCore.Functions.TriggerCallback('qb-lockdown:server:GetActiveGames', function(games)
        SendNUIMessage({
            action = "updateGames",
            games = games
        })
    end)
    
    -- Get player gang info
    QBCore.Functions.TriggerCallback('qb-lockdown:server:GetGangInfo', function(gangInfo)
        SendNUIMessage({
            action = "updateGang",
            gang = gangInfo
        })
    end)
    
    -- Get leaderboard
    QBCore.Functions.TriggerCallback('qb-lockdown:server:GetLeaderboard', function(leaderboard)
        SendNUIMessage({
            action = "updateLeaderboard",
            leaderboard = leaderboard
        })
    end)
end

function OpenLockdownGameMenu()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "open",
        type = "game",
        game = CurrentGame,
        loot = PlayerLoot,
        extractionPoints = ExtractionPoints
    })
end

-- Receive game updates from server
RegisterNetEvent('qb-lockdown:client:UpdateGames', function(games)
    SendNUIMessage({
        action = "updateGames",
        games = games
    })
end)

-- Join a game
RegisterNUICallback('joinGame', function(data, cb)
    TriggerServerEvent('qb-lockdown:server:JoinGame', data.gameId)
    SetNuiFocus(false, false)
    cb({})
end)

-- Enter the game
RegisterNetEvent('qb-lockdown:client:EnterGame', function(gameData, zoneData, stats)
    CurrentGame = gameData
    InGame = true
    
    -- Display initial info
    SendNUIMessage({
        action = "showGameInfo",
        game = gameData,
        zone = zoneData,
        stats = stats
    })
    
    -- Wait for game to start
    if gameData.state == "waiting" then
        QBCore.Functions.Notify("Waiting for more players to join...", "primary")
    else
        -- Game is already active, spawn and start
        GameStarted(gameData, gameData.players[tostring(GetPlayerServerId(PlayerId()))].spawnPoint)
    end
end)

-- Game started
RegisterNetEvent('qb-lockdown:client:GameStarted', function(gameData, spawnPoint)
    GameStarted(gameData, spawnPoint)
end)

function GameStarted(gameData, spawnPoint)
    CurrentGame = gameData
    
    -- Teleport to spawn point
    SetEntityCoords(PlayerPedId(), spawnPoint.x, spawnPoint.y, spawnPoint.z)
    SetEntityHeading(PlayerPedId(), spawnPoint.w)
    
    -- Set wanted level
    WantedLevel = Config.StarterWantedLevel
    SetPlayerWantedLevel(PlayerId(), WantedLevel)
    SetPlayerWantedLevelNow(PlayerId())
    
    -- Start police AI
    StartPoliceAI()
    
    -- Show game UI
    SendNUIMessage({
        action = "gameStarted",
        game = gameData
    })
    
    -- Start game timer
    StartGameTimer(gameData.endTime)
    
    QBCore.Functions.Notify("Lockdown Protocol has begun! Find loot and extract safely.", "success")
end

-- Sync loot spots
RegisterNetEvent('qb-lockdown:client:SyncLoot', function(lootSpots)
    LootSpots = lootSpots
    
    -- Clear any existing loot blips/props
    for _, loot in pairs(LootSpots) do
        if loot.blip then
            RemoveBlip(loot.blip)
            loot.blip = nil
        end
        if loot.prop and DoesEntityExist(loot.prop) then
            DeleteEntity(loot.prop)
            loot.prop = nil
        end
    end
    
    -- Create loot blips and props
    for i, loot in pairs(LootSpots) do
        if not loot.looted then
            -- Create blip
            loot.blip = AddBlipForCoord(loot.coords.x, loot.coords.y, loot.coords.z)
            SetBlipSprite(loot.blip, 478) -- Appropriate blip sprite
            SetBlipColour(loot.blip, 5) -- Yellow
            SetBlipScale(loot.blip, 0.7)
            SetBlipAsShortRange(loot.blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString("Loot")
            EndTextCommandSetBlipName(loot.blip)
            
            -- Create prop
            local hash = GetHashKey(loot.model)
            RequestModel(hash)
            while not HasModelLoaded(hash) do
                Wait(10)
            end
            
            loot.prop = CreateObject(hash, loot.coords.x, loot.coords.y, loot.coords.z, false, false, false)
            PlaceObjectOnGroundProperly(loot.prop)
            FreezeEntityPosition(loot.prop, true)
            SetModelAsNoLongerNeeded(hash)
            
            -- Add target
            exports['qb-target']:AddTargetEntity(loot.prop, {
                options = {
                    {
                        type = "client",
                        event = "qb-lockdown:client:LootItem",
                        icon = "fas fa-hand-paper",
                        label = "Loot",
                        lootIndex = i
                    }
                },
                distance = 2.5
            })
        end
    end
end)

-- Loot an item
RegisterNetEvent('qb-lockdown:client:LootItem', function(data)
    if not InGame or not CurrentGame then return end
    
    local lootIndex = data.lootIndex
    if not LootSpots[lootIndex] or LootSpots[lootIndex].looted then return end
    
    -- Play animation
    TaskStartScenarioInPlace(PlayerPedId(), "PROP_HUMAN_BUM_BIN", 0, true)
    QBCore.Functions.Progressbar("looting_item", "Looting...", 3000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        ClearPedTasks(PlayerPedId())
        TriggerServerEvent('qb-lockdown:server:LootItem', CurrentGame.id, lootIndex)
    end, function() -- Cancel
        ClearPedTasks(PlayerPedId())
        QBCore.Functions.Notify("Looting cancelled", "error")
    end)
end)

-- Sync loot drops
RegisterNetEvent('qb-lockdown:client:SyncLootDrop', function(dropId, dropData)
    LootDrops[dropId] = dropData
    
    -- Create blip
    local blip = AddBlipForCoord(dropData.coords.x, dropData.coords.y, dropData.coords.z)
    SetBlipSprite(blip, 501) -- Different sprite for player drops
    SetBlipColour(blip, 1) -- Red
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(dropData.label)
    EndTextCommandSetBlipName(blip)
    
    LootDrops[dropId].blip = blip
    
    -- Create marker
    CreateThread(function()
        local dropProp = CreateObject(GetHashKey("bkr_prop_crate_set_01a"), dropData.coords.x, dropData.coords.y, dropData.coords.z - 1.0, false, false, false)
        PlaceObjectOnGroundProperly(dropProp)
        FreezeEntityPosition(dropProp, true)
        
        LootDrops[dropId].prop = dropProp
        
        -- Add target
        exports['qb-target']:AddTargetEntity(dropProp, {
            options = {
                {
                    type = "client",
                    event = "qb-lockdown:client:LootDrop",
                    icon = "fas fa-hand-paper",
                    label = "Loot " .. dropData.label,
                    dropId = dropId
                }
            },
            distance = 2.5
        })
    end)
end)

-- Remove loot drop
RegisterNetEvent('qb-lockdown:client:RemoveLootDrop', function(dropId)
    if not LootDrops[dropId] then return end
    
    if LootDrops[dropId].blip then
        RemoveBlip(LootDrops[dropId].blip)
    end
    
    if LootDrops[dropId].prop and DoesEntityExist(LootDrops[dropId].prop) then
        DeleteEntity(LootDrops[dropId].prop)
    end
    
    LootDrops[dropId] = nil
end)

-- Loot a drop
RegisterNetEvent('qb-lockdown:client:LootDrop', function(data)
    if not InGame or not CurrentGame or not LootDrops[data.dropId] then return end
    
    -- Play animation
    TaskStartScenarioInPlace(PlayerPedId(), "PROP_HUMAN_BUM_BIN", 0, true)
    QBCore.Functions.Progressbar("looting_drop", "Looting...", 5000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        ClearPedTasks(PlayerPedId())
        TriggerServerEvent('qb-lockdown:server:LootDrop', CurrentGame.id, data.dropId)
    end, function() -- Cancel
        ClearPedTasks(PlayerPedId())
        QBCore.Functions.Notify("Looting cancelled", "error")
    end)
end)

-- Update player loot
RegisterNetEvent('qb-lockdown:client:UpdateLoot', function(loot)
    PlayerLoot = loot
    
    -- Update UI
    SendNUIMessage({
        action = "updateLoot",
        loot = loot
    })
end)

-- Activate extraction points
RegisterNetEvent('qb-lockdown:client:ActivateExtractions', function(extractionPoints)
    ExtractionPoints = extractionPoints
    
    -- Clear any existing extraction blips
    for _, point in pairs(ExtractionPoints) do
        if point.blip then
            RemoveBlip(point.blip)
            point.blip = nil
        end
    end
    
    -- Create extraction blips and vehicles
    for name, point in pairs(ExtractionPoints) do
        -- Create blip
        local blip = AddBlipForCoord(point.coords.x, point.coords.y, point.coords.z)
        SetBlipSprite(blip, 569) -- Extraction blip
        SetBlipColour(blip, 2) -- Green
        SetBlipScale(blip, 1.0)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(point.label .. " Extraction")
        EndTextCommandSetBlipName(blip)
        
        point.blip = blip
        
        -- Spawn extraction vehicle
        local hash = GetHashKey(point.vehicleModel)
        RequestModel(hash)
        while not HasModelLoaded(hash) do
            Wait(10)
        end
        
        local vehicle = CreateVehicle(hash, point.vehicleSpawn.x, point.vehicleSpawn.y, point.vehicleSpawn.z, point.vehicleSpawn.w, false, false)
        SetEntityAsMissionEntity(vehicle, true, true)
        SetVehicleDoorsLocked(vehicle, 1) -- Unlocked
        SetVehicleOnGroundProperly(vehicle)
        
        point.vehicle = vehicle
        
        -- Create extraction marker
        CreateThread(function()
            local coords = point.coords
            
            while InGame and CurrentGame do
                Wait(0)
                DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 5.0, 5.0, 1.0, 0, 255, 0, 100, false, true, 2, false, nil, nil, false)
                
                local playerCoords = GetEntityCoords(PlayerPedId())
                local distance = #(playerCoords - coords)
                
                if distance < 5.0 then
                    -- Check if player is in extraction vehicle
                    local isValid = false
                    if point.type == "boat" or point.type == "heli" or point.type == "land" then
                        local playerVehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                        if playerVehicle == point.vehicle then
                            isValid = true
                        end
                    else
                        isValid = true
                    end
                    
                    if isValid then
                        DrawText3D(coords.x, coords.y, coords.z, "Press ~g~E~w~ to extract")
                        
                        if IsControlJustPressed(0, 38) then -- E key
                            StartExtraction(name)
                        end
                    else
                        DrawText3D(coords.x, coords.y, coords.z, "Enter the ~y~" .. point.label .. "~w~ to extract")
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
end)

-- Start extraction
function StartExtraction(extractionName)
    if not InGame or not CurrentGame or not ExtractionPoints[extractionName] then return end
    
    -- Play animation/effect based on extraction type
    local extractionPoint = ExtractionPoints[extractionName]
    
    QBCore.Functions.Progressbar("extracting", "Extracting...", Config.ExtractTime * 1000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        -- Complete extraction
        TriggerServerEvent('qb-lockdown:server:PlayerExtract', CurrentGame.id, extractionName)
    end, function() -- Cancel
        QBCore.Functions.Notify("Extraction cancelled", "error")
    end)
    
    -- Broadcast extraction attempt to all players
    TriggerServerEvent('qb-lockdown:server:BroadcastExtraction', CurrentGame.id, extractionName)
end

-- Broadcast extraction attempt
RegisterNetEvent('qb-lockdown:client:BroadcastExtraction', function(extractionName)
    if not InGame or not CurrentGame then return end
    
    local extractionPoint = ExtractionPoints[extractionName]
    if not extractionPoint then return end
    
    QBCore.Functions.Notify("A player is attempting to extract at " .. extractionPoint.label .. "!", "error")
    
    -- Flash the extraction blip
    if extractionPoint.blip then
        SetBlipFlashes(extractionPoint.blip, true)
        SetTimeout(10000, function()
            if extractionPoint.blip then
                SetBlipFlashes(extractionPoint.blip, false)
            end
        end)
    end
end)

-- Leave the game
RegisterNetEvent('qb-lockdown:client:LeaveGame', function()
    InGame = false
    CurrentGame = nil
    WantedLevel = 0
    
    -- Reset wanted level
    SetPlayerWantedLevel(PlayerId(), 0)
    SetPlayerWantedLevelNow(PlayerId())
    
    -- Clear all blips and props
    for _, loot in pairs(LootSpots) do
        if loot.blip then
            RemoveBlip(loot.blip)
        end
        if loot.prop and DoesEntityExist(loot.prop) then
            DeleteEntity(loot.prop)
        end
    end
    
    for _, point in pairs(ExtractionPoints) do
        if point.blip then
            RemoveBlip(point.blip)
        end
        if point.vehicle and DoesEntityExist(point.vehicle) then
            DeleteEntity(point.vehicle)
        end
    end
    
    for dropId, drop in pairs(LootDrops) do
        if drop.blip then
            RemoveBlip(drop.blip)
        end
        if drop.prop and DoesEntityExist(drop.prop) then
            DeleteEntity(drop.prop)
        end
    end
    
    LootSpots = {}
    ExtractionPoints = {}
    LootDrops = {}
    PlayerLoot = {}
    
    -- Return to spawn
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    
    -- Hide game UI
    SendNUIMessage({
        action = "endGame"
    })
end)

-- Show extraction report
RegisterNetEvent('qb-lockdown:client:ShowExtractionReport', function(reportMsg, totalValue)
    SendNUIMessage({
        action = "showExtractionReport",
        message = reportMsg,
        value = totalValue
    })
end)

-- Announce game to all players
RegisterNetEvent('qb-lockdown:client:AnnounceGame', function(zoneName)
    if not Config.Zones[zoneName] then return end
    
    -- Play sounds, show notification
    TriggerEvent('InteractSound_CL:PlayOnOne', 'Alert', 0.5)
    
    -- Show notification
    local zoneLabel = Config.Zones[zoneName].label
    QBCore.Functions.Notify("⚠️ LOCKDOWN INITIATED IN " .. zoneLabel .. "! PRESS F10 TO JOIN", "error", 10000)
    
    -- Show UI alert
    SendNUIMessage({
        action = "showAnnouncement",
        zone = zoneName,
        label = zoneLabel
    })
end)

-- Player died
CreateThread(function()
    while true do
        Wait(1000)
        
        if InGame and CurrentGame then
            local playerPed = PlayerPedId()
            
            if IsEntityDead(playerPed) then
                -- Get killer
                local killerPed = GetPedSourceOfDeath(playerPed)
                local killerServerId = 0
                
                if killerPed ~= playerPed then
                    local killerPlayer = NetworkGetPlayerIndexFromPed(killerPed)
                    if killerPlayer ~= -1 then
                        killerServerId = GetPlayerServerId(killerPlayer)
                    end
                end
                
                -- Notify server of death
                TriggerServerEvent('qb-lockdown:server:PlayerDied', CurrentGame.id, killerServerId)
                
                -- Reset player
                Wait(2000) -- Wait for death animation
                NetworkResurrectLocalPlayer(GetEntityCoords(playerPed), 0, false, false)
                SetPlayerInvincible(PlayerPedId(), true)
                SetTimeout(3000, function()
                    SetPlayerInvincible(PlayerPedId(), false)
                end)
                
                break
            end
        else
            Wait(1000)
        end
    end
end)

-- Start game timer
function StartGameTimer(endTime)
    CreateThread(function()
        while InGame and CurrentGame do
            Wait(1000)
            
            local timeRemaining = endTime - os.time()
            
            -- Update UI timer
            SendNUIMessage({
                action = "updateTimer",
                timeRemaining = timeRemaining
            })
            
            if timeRemaining <= 0 then
                -- Game is ending
                QBCore.Functions.Notify("Lockdown Protocol is ending!", "error")
                break
            end
        end
    end)
end

-- Police AI functions
function StartPoliceAI()
    CreateThread(function()
        local initialSpawned = false
        local level2Spawned = false
        local level3Spawned = false
        
        local startTime = GetGameTimer()
        
        while InGame and CurrentGame do
            Wait(1000)
            
            local gameTime = (GetGameTimer() - startTime) / 1000
            
            -- Initial police spawn
            if not initialSpawned then
                SpawnPolice(Config.Police.initialSpawns)
                initialSpawned = true
            end
            
            -- Level 2 response
            if gameTime >= Config.Police.responseTime.level1 and not level2Spawned then
                QBCore.Functions.Notify("Police response intensifying!", "error")
                SpawnPolice(Config.Police.initialSpawns) -- Spawn additional police
                level2Spawned = true
            end
            
            -- Level 3 response
            if gameTime >= Config.Police.responseTime.level2 and not level3Spawned then
                QBCore.Functions.Notify("Police setting up barricades!", "error")
                SpawnBarricades()
                level3Spawned = true
            end
            
            -- Final response
            if gameTime >= Config.Police.responseTime.level3 and not level4Spawned then
                QBCore.Functions.Notify("SWAT units deployed!", "error")
                SpawnRoadblocks()
                SpawnPolice(Config.Police.initialSpawns, true) -- Spawn SWAT
                level4Spawned = true
            end
        end
    end)
end

function SpawnPolice(count, isSwat)
    if not InGame or not CurrentGame then return end
    
    local zoneData = Config.Zones[CurrentGame.zone]
    if not zoneData then return end
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    for i = 1, count do
        -- Find spawn position away from player but in zone
        local spawnCoords = nil
        local attempts = 0
        
        while not spawnCoords and attempts < 10 do
            local angle = math.random() * math.pi * 2
            local distance = math.random(50, 100)
            
            local x = playerCoords.x + math.cos(angle) * distance
            local y = playerCoords.y + math.sin(angle) * distance
            
            local distanceToZone = #(vector3(x, y, playerCoords.z) - zoneData.coords)
            if distanceToZone < zoneData.radius then
                -- Check if position is valid
                local z = playerCoords.z
                local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, 1000.0, 0)
                if foundGround then
                    spawnCoords = vector4(x, y, groundZ + 1.0, math.random(0, 359))
                end
            end
            
            attempts = attempts + 1
        end
        
        if not spawnCoords then
            -- Fallback to random spawn point
            local randomSpawn = zoneData.spawnPoints[math.random(1, #zoneData.spawnPoints)]
            spawnCoords = randomSpawn
        end
        
        -- Spawn police ped
        local modelName = isSwat and "s_m_y_swat_01" or Config.Police.models[math.random(1, #Config.Police.models)]
        local modelHash = GetHashKey(modelName)
        
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do
            Wait(10)
        end
        
        local ped = CreatePed(4, modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, true, false)
        SetPedArmour(ped, isSwat and 100 or 50)
        SetPedAccuracy(ped, isSwat and 80 or 50)
        SetPedRelationshipGroupHash(ped, GetHashKey("POLICE"))
        
        -- Set as mission entity so it doesn't despawn
        SetEntityAsMissionEntity(ped, true, true)
        
        -- Give weapon
        local weaponType = isSwat and "WEAPON_CARBINERIFLE" or Config.Police.weapons[math.random(1, #Config.Police.weapons)]
        GiveWeaponToPed(ped, GetHashKey(weaponType), 500, false, true)
        
        -- Make aggressive
        TaskCombatPed(ped, playerPed, 0, 16)
        
        -- Spawn police vehicle sometimes
        if math.random() < 0.5 then
            local vehicleModel = Config.Police.vehicles[math.random(1, #Config.Police.vehicles)]
            local vehicleHash = GetHashKey(vehicleModel)
            
            RequestModel(vehicleHash)
            while not HasModelLoaded(vehicleHash) do
                Wait(10)
            end
            
            local vehicle = CreateVehicle(vehicleHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, true, false)
            SetEntityAsMissionEntity(vehicle, true, true)
            SetVehicleOnGroundProperly(vehicle)
            
            -- Put cop in vehicle
            SetPedIntoVehicle(ped, vehicle, -1)
            
            -- Make chase player
            TaskVehicleChase(ped, playerPed)
            SetDriverAbility(ped, 1.0)
            SetDriverAggressiveness(ped, 1.0)
        end
    end
end

function SpawnBarricades()
    if not InGame or not CurrentGame then return end
    
    local zoneData = Config.Zones[CurrentGame.zone]
    if not zoneData then return end
    
    -- Spawn barricades at zone edges
    local barricadeCount = 6
    local radius = zoneData.radius * 0.8
    local center = zoneData.coords
    
    for i = 1, barricadeCount do
        local angle = (i / barricadeCount) * math.pi * 2
        local x = center.x + math.cos(angle) * radius
        local y = center.y + math.sin(angle) * radius
        
        local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, 1000.0, 0)
        if foundGround then
            local coords = vector4(x, y, groundZ + 1.0, angle * 57.2958) -- Convert to degrees
            
            -- Spawn barrier
            local barrierHash = GetHashKey("prop_barrier_work05")
            RequestModel(barrierHash)
            while not HasModelLoaded(barrierHash) do
                Wait(10)
            end
            
            local barrier = CreateObject(barrierHash, coords.x, coords.y, coords.z, true, false, false)
            SetEntityHeading(barrier, coords.w)
            FreezeEntityPosition(barrier, true)
            SetEntityAsMissionEntity(barrier, true, true)
            
            -- Spawn police near barrier
            SpawnPolice(2)
        end
    end
end

function SpawnRoadblocks()
    if not InGame or not CurrentGame then return end
    
    local zoneData = Config.Zones[CurrentGame.zone]
    if not zoneData then return end
    
    -- Spawn roadblocks at major roads
    -- This would require knowledge of the map's road network
    -- For demonstration, we'll spawn some at the zone edges
    local blockCount = 4
    local radius = zoneData.radius * 0.7
    local center = zoneData.coords
    
    for i = 1, blockCount do
        local angle = (i / blockCount) * math.pi * 2
        local x = center.x + math.cos(angle) * radius
        local y = center.y + math.sin(angle) * radius
        
        local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, 1000.0, 0)
        if foundGround then
            local coords = vector4(x, y, groundZ + 1.0, angle * 57.2958) -- Convert to degrees
            
            -- Spawn roadblock
            local blockHash = GetHashKey("prop_mp_barrier_02b")
            RequestModel(blockHash)
            while not HasModelLoaded(blockHash) do
                Wait(10)
            end
            
            -- Create a line of barriers
            for j = -2, 2 do
                local offsetX = math.cos(angle + math.pi/2) * (j * 2.5)
                local offsetY = math.sin(angle + math.pi/2) * (j * 2.5)
                
                local block = CreateObject(blockHash, coords.x + offsetX, coords.y + offsetY, coords.z, true, false, false)
                SetEntityHeading(block, coords.w)
                FreezeEntityPosition(block, true)
                SetEntityAsMissionEntity(block, true, true)
            end
            
            -- Spawn police vehicle and cops
            local vehicleModel = Config.Police.vehicles[math.random(1, #Config.Police.vehicles)]
            local vehicleHash = GetHashKey(vehicleModel)
            
            RequestModel(vehicleHash)
            while not HasModelLoaded(vehicleHash) do
                Wait(10)
            end
            
            local offsetX = math.cos(angle + math.pi/2) * 5
            local offsetY = math.sin(angle + math.pi/2) * 5
            
            local vehicle = CreateVehicle(vehicleHash, coords.x + offsetX, coords.y + offsetY, coords.z, coords.w + 90, true, false)
            SetEntityAsMissionEntity(vehicle, true, true)
            SetVehicleOnGroundProperly(vehicle)
            
            -- Spawn cops
            SpawnPolice(3, true) -- SWAT at roadblocks
        end
    end
end

-- Utility Functions
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local p = GetGameplayCamCoords()
    local distance = #(p - vector3(x, y, z))
    local scale = (1 / distance) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    local scale = scale * fov

    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 90)
    end
end