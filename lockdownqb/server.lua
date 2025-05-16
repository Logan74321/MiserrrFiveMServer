local QBCore = exports['qb-core']:GetCoreObject()

-- Local variables
local PlayersInZone = {}
local MinPlayers = Config.MinPlayers
local MaxPlayers = Config.MaxPlayers
local LockdownInProgress = false
local ActiveZones = {}
local ActiveVehicles = {}
local ActiveContracts = {}
local AnnouncementCooldown = false
local LockdownJoinWindow = false
local JoinWindowDuration = 120000  -- 2 minutes to join (configurable)
local ExtractionCount = 0
local MaxExtractions = 4

-- Initialize database (following QBCore style)
CreateThread(function()
    print("^2Lockdown Protocol: Initializing database...^7")
    
    -- Check if lockdown_contracts table exists
    MySQL.query('SHOW TABLES LIKE "lockdown_contracts"', function(result)
        if result[1] then
            print("^2Lockdown Protocol: lockdown_contracts table exists^7")
            
            -- Check if we need to insert default contracts
            MySQL.query('SELECT COUNT(*) as count FROM lockdown_contracts', function(count)
                if count[1].count == 0 then
                    print("^3Lockdown Protocol: Inserting default contracts...^7")
                    
                    -- Insert default contracts
                    for _, contract in pairs(Config.Contracts) do
                        MySQL.insert('INSERT INTO lockdown_contracts (name, description, reward_xp, reward_cash, min_tier) VALUES (?, ?, ?, ?, ?)', 
                        {
                            contract.name,
                            contract.description,
                            contract.reward_xp,
                            contract.reward_cash,
                            contract.min_tier
                        })
                    end
                end
            end)
        else
            print("^1Lockdown Protocol: lockdown_contracts table missing! Please run the SQL file.^7")
            print("^3Attempting to create lockdown_contracts table...^7")
            
            MySQL.query([[
                CREATE TABLE IF NOT EXISTS `lockdown_contracts` (
                    `id` int(11) NOT NULL AUTO_INCREMENT,
                    `name` varchar(100) DEFAULT NULL,
                    `description` text DEFAULT NULL,
                    `reward_xp` int(11) DEFAULT 0,
                    `reward_cash` int(11) DEFAULT 0,
                    `min_tier` int(11) DEFAULT 1,
                    `is_active` tinyint(1) DEFAULT 1,
                    PRIMARY KEY (`id`)
                ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
            ]], function()
                print("^2Lockdown Protocol: Created lockdown_contracts table^7")
                
                -- Insert default contracts
                for _, contract in pairs(Config.Contracts) do
                    MySQL.insert('INSERT INTO lockdown_contracts (name, description, reward_xp, reward_cash, min_tier) VALUES (?, ?, ?, ?, ?)', 
                    {
                        contract.name,
                        contract.description,
                        contract.reward_xp,
                        contract.reward_cash,
                        contract.min_tier
                    })
                end
            end)
        end
    end)
    
    -- Check other tables using the same pattern
    local tables = {
        "lockdown_stats",
        "lockdown_gangs",
        "lockdown_gang_members"
    }
    
    for _, table in ipairs(tables) do
        MySQL.query('SHOW TABLES LIKE "' .. table .. '"', function(result)
            if result[1] then
                print("^2Lockdown Protocol: " .. table .. " table exists^7")
            else
                print("^1Lockdown Protocol: " .. table .. " table missing! Please run the SQL file.^7")
                
                -- Create tables if they don't exist
                if table == "lockdown_stats" then
                    MySQL.query([[
                        CREATE TABLE IF NOT EXISTS `lockdown_stats` (
                            `id` int(11) NOT NULL AUTO_INCREMENT,
                            `identifier` varchar(255) NOT NULL,
                            `name` varchar(50) DEFAULT NULL,
                            `extractions` int(11) DEFAULT 0,
                            `deaths` int(11) DEFAULT 0,
                            `kills` int(11) DEFAULT 0,
                            `contracts_completed` int(11) DEFAULT 0,
                            `extracted_value` int(11) DEFAULT 0,
                            `highest_solo_streak` int(11) DEFAULT 0,
                            `criminal_tier` int(11) DEFAULT 1,
                            `timestamp` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                            PRIMARY KEY (`id`),
                            KEY `identifier` (`identifier`)
                        ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
                    ]])
                    print("^2Lockdown Protocol: Created lockdown_stats table^7")
                elseif table == "lockdown_gangs" then
                    MySQL.query([[
                        CREATE TABLE IF NOT EXISTS `lockdown_gangs` (
                            `id` int(11) NOT NULL AUTO_INCREMENT,
                            `name` varchar(50) DEFAULT NULL,
                            `color` varchar(7) DEFAULT '#FFFFFF',
                            `emblem` int(11) DEFAULT 0,
                            `created_by` varchar(255) DEFAULT NULL,
                            `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
                            PRIMARY KEY (`id`),
                            KEY `name` (`name`)
                        ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
                    ]])
                    print("^2Lockdown Protocol: Created lockdown_gangs table^7")
                elseif table == "lockdown_gang_members" then
                    MySQL.query([[
                        CREATE TABLE IF NOT EXISTS `lockdown_gang_members` (
                            `id` int(11) NOT NULL AUTO_INCREMENT,
                            `gang_id` int(11) NOT NULL,
                            `identifier` varchar(255) DEFAULT NULL,
                            `name` varchar(50) DEFAULT NULL,
                            `rank` int(11) DEFAULT 1,
                            `joined_at` timestamp NOT NULL DEFAULT current_timestamp(),
                            PRIMARY KEY (`id`),
                            KEY `gang_id` (`gang_id`),
                            KEY `identifier` (`identifier`)
                        ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
                    ]])
                    print("^2Lockdown Protocol: Created lockdown_gang_members table^7")
                end
            end
        end)
    end
end)

-- Admin command to trigger Lockdown
RegisterCommand('lockdown', function(source, args, rawCommand)
    -- Check if source is console or admin
    if source == 0 or IsPlayerAceAllowed(source, "command.lockdown") then
        -- Select random zone for announcement
        local zoneIndex = math.random(1, #Config.Zones)
        local zoneName = Config.Zones[zoneIndex].name
        
        -- Trigger announcement for all players
        TriggerLockdownAnnouncement(zoneName)
        
        if source == 0 then
            print("^2Lockdown Protocol: Manual announcement triggered for zone " .. zoneName .. "^7")
        else
            TriggerClientEvent('lockdown:notification', source, "Lockdown announcement triggered for " .. zoneName)
        end
    else
        TriggerClientEvent('lockdown:notification', source, "You don't have permission to use this command.")
    end
end, false)

-- Function to trigger lockdown announcement and open join window
function TriggerLockdownAnnouncement(zoneName)
    if LockdownInProgress or LockdownJoinWindow then
        return -- Don't start a new lockdown if one is already in progress
    end
    
    -- Start join window
    LockdownJoinWindow = true
    
    -- Trigger announcement for all players
    TriggerClientEvent('lockdown:announceProtocol', -1, zoneName)
    
    -- Close join window after JoinWindowDuration
    Citizen.SetTimeout(JoinWindowDuration, function()
        -- Close join window
        LockdownJoinWindow = false
        
        -- Start the lockdown if we have enough players
        local zoneId = nil
        for id, zone in pairs(ActiveZones) do
            if not zone.started and #zone.players >= MinPlayers then
                zoneId = id
                break
            end
        end
        
        if zoneId then
            StartLockdown(zoneId)
        else
            -- Not enough players joined, cleanup
            for id, zone in pairs(ActiveZones) do
                if not zone.started then
                    -- Return players to freemode
                    for _, player in ipairs(zone.players) do
                        TriggerClientEvent('lockdown:notification', player, "Not enough players joined. Lockdown cancelled.")
                        TriggerClientEvent('lockdown:returnToFreemode', player)
                        
                        -- Reset player routing bucket
                        SetPlayerRoutingBucket(player, 0)
                    end
                    
                    -- Remove zone
                    ActiveZones[id] = nil
                end
            end
            
            -- Reset players in zone
            PlayersInZone = {}
        end
    end)
end

-- Periodic Lockdown announcement
CreateThread(function()
    while true do
        Citizen.Wait(Config.LockdownDuration * 60000) -- Convert minutes to milliseconds
        
        if not LockdownInProgress and not LockdownJoinWindow and not AnnouncementCooldown then
            -- Select random zone for announcement
            local zoneIndex = math.random(1, #Config.Zones)
            local zoneName = Config.Zones[zoneIndex].name
            
            -- Trigger lockdown announcement
            TriggerLockdownAnnouncement(zoneName)
            
            -- Set cooldown
            AnnouncementCooldown = true
            Citizen.SetTimeout(5 * 60000, function() -- 5 minute cooldown
                AnnouncementCooldown = false
            end)
        end
    end
end)

-- Callback for getting player stats
QBCore.Functions.CreateCallback('lockdown:getPlayerStats', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(nil) end
    
    local identifier = Player.PlayerData.citizenid
    
    MySQL.query('SELECT * FROM lockdown_stats WHERE identifier = ?', {identifier}, function(results)
        if results and results[1] then
            -- Get criminal tier info
            local tier = GetCriminalTier(results[1].extractions)
            results[1].tier_name = tier.name
            results[1].tier_color = tier.color
            cb(results[1])
        else
            -- Create new entry for player
            MySQL.insert('INSERT INTO lockdown_stats (identifier, name, extractions, deaths, kills, contracts_completed, extracted_value, highest_solo_streak, criminal_tier) VALUES (?, ?, 0, 0, 0, 0, 0, 0, 1)', 
            {
                identifier,
                Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
            })
            
            -- Return default stats
            cb({
                extractions = 0,
                deaths = 0,
                kills = 0,
                contracts_completed = 0,
                extracted_value = 0,
                highest_solo_streak = 0,
                criminal_tier = 1,
                tier_name = Config.CriminalTiers[1].name,
                tier_color = Config.CriminalTiers[1].color
            })
        end
    end)
end)

-- Get criminal tier based on extractions
function GetCriminalTier(extractions)
    local highestTier = Config.CriminalTiers[1]
    
    for _, tier in pairs(Config.CriminalTiers) do
        if extractions >= tier.requiredExtractions and tier.id > highestTier.id then
            highestTier = tier
        end
    end
    
    return highestTier
end

-- Gang system callbacks
QBCore.Functions.CreateCallback('lockdown:getGangData', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(nil) end
    
    local identifier = Player.PlayerData.citizenid
    
    -- Check if player is in a gang
    MySQL.query('SELECT g.*, gm.rank FROM lockdown_gangs g INNER JOIN lockdown_gang_members gm ON g.id = gm.gang_id WHERE gm.identifier = ?', {identifier}, function(results)
        if results and results[1] then
            -- Player is in a gang
            local gangData = results[1]
            gangData.in_gang = true
            
            -- Get gang members
            MySQL.query('SELECT name, rank FROM lockdown_gang_members WHERE gang_id = ?', {gangData.id}, function(members)
                gangData.members = members
                cb(gangData)
            end)
        else
            -- Player is not in a gang, get all available gangs
            MySQL.query('SELECT id, name, color FROM lockdown_gangs', {}, function(gangs)
                cb({
                    in_gang = false,
                    gangs = gangs or {}
                })
            end)
        end
    end)
end)

QBCore.Functions.CreateCallback('lockdown:createGang', function(source, cb, gangName, gangColor, gangEmblem)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false, "Player not found") end
    
    local identifier = Player.PlayerData.citizenid
    local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    -- Check if player is already in a gang
    MySQL.query('SELECT * FROM lockdown_gang_members WHERE identifier = ?', {identifier}, function(results)
        if results and results[1] then
            return cb(false, "You are already in a gang")
        end
        
        -- Check if gang name already exists
        MySQL.query('SELECT * FROM lockdown_gangs WHERE name = ?', {gangName}, function(results)
            if results and results[1] then
                return cb(false, "Gang name already taken")
            end
            
            -- Create new gang
            MySQL.insert('INSERT INTO lockdown_gangs (name, color, emblem, created_by) VALUES (?, ?, ?, ?)', 
            {
                gangName,
                gangColor,
                gangEmblem,
                identifier
            }, function(gangId)
                if gangId > 0 then
                    -- Add creator as OG (rank 3)
                    MySQL.insert('INSERT INTO lockdown_gang_members (gang_id, identifier, name, rank) VALUES (?, ?, ?, 3)', 
                    {
                        gangId,
                        identifier,
                        playerName
                    })
                    
                    cb(true, "Gang created successfully")
                else
                    cb(false, "Failed to create gang")
                end
            end)
        end)
    end)
end)

QBCore.Functions.CreateCallback('lockdown:joinGang', function(source, cb, gangId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false, "Player not found") end
    
    local identifier = Player.PlayerData.citizenid
    local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    -- Check if player is already in a gang
    MySQL.query('SELECT * FROM lockdown_gang_members WHERE identifier = ?', {identifier}, function(results)
        if results and results[1] then
            return cb(false, "You are already in a gang")
        end
        
        -- Check if gang exists
        MySQL.query('SELECT * FROM lockdown_gangs WHERE id = ?', {gangId}, function(results)
            if not results or not results[1] then
                return cb(false, "Gang not found")
            end
            
            -- Check if gang is full
            MySQL.query('SELECT COUNT(*) as count FROM lockdown_gang_members WHERE gang_id = ?', {gangId}, function(results)
                if results[1].count >= Config.GangSystem.MaxMembers then
                    return cb(false, "Gang is full")
                end
                
                -- Add player to gang as Prospect (rank 1)
                MySQL.insert('INSERT INTO lockdown_gang_members (gang_id, identifier, name, rank) VALUES (?, ?, ?, 1)', 
                {
                    gangId,
                    identifier,
                    playerName
                })
                
                cb(true, "You have joined the gang")
            end)
        end)
    end)
end)

QBCore.Functions.CreateCallback('lockdown:leaveGang', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false, "Player not found") end
    
    local identifier = Player.PlayerData.citizenid
    
    -- Check if player is in a gang
    MySQL.query('SELECT * FROM lockdown_gang_members WHERE identifier = ?', {identifier}, function(results)
        if not results or not results[1] then
            return cb(false, "You are not in a gang")
        end
        
        -- Remove player from gang
        MySQL.query('DELETE FROM lockdown_gang_members WHERE identifier = ?', {identifier}, function()
            cb(true, "You have left the gang")
        end)
    end)
end)

-- Leaderboard callback
QBCore.Functions.CreateCallback('lockdown:getLeaderboard', function(source, cb)
    MySQL.query('SELECT name, extractions, kills, extracted_value FROM lockdown_stats ORDER BY extracted_value DESC LIMIT 10', {}, function(results)
        cb(results or {})
    end)
end)

-- Contract system callbacks
QBCore.Functions.CreateCallback('lockdown:getAvailableContracts', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end
    
    local identifier = Player.PlayerData.citizenid
    
    -- Get player's tier
    MySQL.query('SELECT criminal_tier FROM lockdown_stats WHERE identifier = ?', {identifier}, function(results)
        local tier = 1
        if results and results[1] then
            tier = results[1].criminal_tier
        end
        
        -- Get contracts available for player's tier
        MySQL.query('SELECT * FROM lockdown_contracts WHERE min_tier <= ? AND is_active = 1', {tier}, function(contracts)
            cb(contracts or {})
        end)
    end)
end)

QBCore.Functions.CreateCallback('lockdown:acceptContract', function(source, cb, contractId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false, nil) end
    
    -- Check if contract exists
    MySQL.query('SELECT * FROM lockdown_contracts WHERE id = ? AND is_active = 1', {contractId}, function(results)
        if not results or not results[1] then
            return cb(false, nil)
        end
        
        -- Store active contract for player
        ActiveContracts[source] = results[1]
        
        cb(true, results[1])
    end)
end)

-- Check if player has a specific item
QBCore.Functions.CreateCallback('lockdown:hasItem', function(source, cb, itemName)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end
    
    local hasItem = Player.Functions.HasItem(itemName)
    cb(hasItem)
end)

-- Check if join window is open
QBCore.Functions.CreateCallback('lockdown:isJoinWindowOpen', function(source, cb)
    cb(LockdownJoinWindow)
end)

-- Join Lockdown request
RegisterNetEvent('lockdown:joinRequest')
AddEventHandler('lockdown:joinRequest', function(joinType, gangId)
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    -- Check if join window is open
    if not LockdownJoinWindow then
        TriggerClientEvent('lockdown:joinResponse', source, 'window_closed')
        return
    end
    
    -- Check if player is already in a lockdown session
    if PlayersInZone[source] then
        TriggerClientEvent('lockdown:joinResponse', source, 'already_joined')
        return
    end
    
    -- Check if there's an active zone with space
    local availableZone = nil
    local playerCount = 0
    
    for zoneId, zone in pairs(ActiveZones) do
        if #zone.players < MaxPlayers and not zone.started then
            availableZone = zone
            playerCount = #zone.players
            break
        end
    end
    
    -- If no available zone, create a new one
    if not availableZone then
        -- Select a random zone from config
        local zoneIndex = math.random(1, #Config.Zones)
        local zoneData = Config.Zones[zoneIndex]
        
        -- Create new zone
        local newZoneId = os.time()
        ActiveZones[newZoneId] = {
            id = newZoneId,
            data = zoneData,
            players = {},
            startTime = os.time(),
            started = false
        }
        
        availableZone = ActiveZones[newZoneId]
        playerCount = 0
    end
    
    -- If joining with gang, check gang members
    local gangMembers = {}
    if joinType == "gang" and gangId then
        -- Check if player is in specified gang
        MySQL.query('SELECT * FROM lockdown_gang_members WHERE gang_id = ? AND identifier = ?', {gangId, Player.PlayerData.citizenid}, function(results)
            if not results or not results[1] then
                TriggerClientEvent('lockdown:joinResponse', source, 'not_in_gang')
                return
            end
            
            -- Get other gang members (up to MaxMembersPerMatch - 1)
            MySQL.query('SELECT identifier FROM lockdown_gang_members WHERE gang_id = ? AND identifier != ? LIMIT ?', 
            {
                gangId, 
                Player.PlayerData.citizenid, 
                Config.GangSystem.MaxMembersPerMatch - 1
            }, function(members)
                for _, member in ipairs(members) do
                    local memberSource = QBCore.Functions.GetPlayerByCitizenId(member.identifier)
                    if memberSource then
                        table.insert(gangMembers, memberSource.PlayerData.source)
                    end
                end
                
                -- Check if there's enough space for all gang members
                if availableZone and playerCount + 1 + #gangMembers <= MaxPlayers then
                    -- Add player and gang members to zone
                    AddPlayerToZone(source, availableZone.id)
                    
                    -- Invite gang members
                    for _, memberSource in ipairs(gangMembers) do
                        TriggerClientEvent('lockdown:gangInvite', memberSource, Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname, availableZone.id)
                    end
                    
                    TriggerClientEvent('lockdown:joinResponse', source, 'joined', playerCount + 1, MaxPlayers, availableZone.data)
                else
                    TriggerClientEvent('lockdown:joinResponse', source, 'zone_full')
                end
            end)
        end)
    else
        -- Solo join
        if availableZone and playerCount < MaxPlayers then
            -- Add player to zone
            AddPlayerToZone(source, availableZone.id)
            
            TriggerClientEvent('lockdown:joinResponse', source, 'joined', playerCount + 1, MaxPlayers, availableZone.data)
        else
            TriggerClientEvent('lockdown:joinResponse', source, 'zone_full')
        end
    end
end)

-- Function to add player to zone
function AddPlayerToZone(source, zoneId)
    if not ActiveZones[zoneId] then return end
    
    -- Check if player is already in a zone
    for id, zone in pairs(ActiveZones) do
        for i, player in ipairs(zone.players) do
            if player == source then
                table.remove(zone.players, i)
                break
            end
        end
    end
    
    -- Add player to specified zone
    table.insert(ActiveZones[zoneId].players, source)
    PlayersInZone[source] = zoneId
    
    -- Set player routing bucket
    SetPlayerRoutingBucket(source, Config.RoutingBucket)
    
    -- Update player count for all players in the zone
    UpdatePlayerCount(zoneId)
end

-- Function to update player count for all players in a zone
function UpdatePlayerCount(zoneId)
    if not ActiveZones[zoneId] then return end
    
    local count = #ActiveZones[zoneId].players
    
    for _, player in ipairs(ActiveZones[zoneId].players) do
        TriggerClientEvent('lockdown:playerCount', player, count)
    end
end

-- Gang invitation response
RegisterNetEvent('lockdown:gangInviteResponse')
AddEventHandler('lockdown:gangInviteResponse', function(accept, zoneId)
    local source = source
    
    if accept and ActiveZones[zoneId] then
        AddPlayerToZone(source, zoneId)
        TriggerClientEvent('lockdown:joinResponse', source, 'joined', #ActiveZones[zoneId].players, MaxPlayers, ActiveZones[zoneId].data)
    end
end)

-- Function to start Lockdown in a zone
function StartLockdown(zoneId)
    if not ActiveZones[zoneId] then return end
    
    -- Reset extraction count
    ExtractionCount = 0
    
    -- Mark zone as started
    ActiveZones[zoneId].started = true
    LockdownInProgress = true
    
    -- Notify all players and spawn them
    local spawnPoints = GetSpawnPoints(ActiveZones[zoneId].data.center, ActiveZones[zoneId].data.radius)
    local gangMembers = GetGangMembers(ActiveZones[zoneId].players)
    
    for playerIndex, player in ipairs(ActiveZones[zoneId].players) do
        -- Generate a random contract if available
        local contract = nil
        
        if ActiveContracts[player] then
            contract = ActiveContracts[player]
        end
        
        -- Determine spawn point based on gang membership
        local spawn = nil
        
        if gangMembers[player] then
            -- Player is in a gang, use gang's spawn point
            spawn = spawnPoints[gangMembers[player].gangIndex]
        else
            -- Solo player, use individual spawn point
            spawn = spawnPoints[playerIndex]
        end
        
        -- Start Lockdown for player
        TriggerClientEvent('lockdown:start', player, ActiveZones[zoneId].data, contract, spawn)
    end
    
    -- Spawn vehicles
    SpawnVehiclesInZone(zoneId)
    
    -- Schedule extraction points (every 4 minutes)
    ScheduleExtraction(zoneId, 4 * 60000) -- 4 minutes * 60000 ms
    
    -- Set a timer to end the Lockdown if no one extracts
    Citizen.SetTimeout(20 * 60000, function() -- 20 minutes
        EndLockdown(zoneId)
    end)
end

-- Function to get spawn points distributed across the zone
function GetSpawnPoints(center, radius)
    local spawnPoints = {}
    local angles = {0, 45, 90, 135, 180, 225, 270, 315} -- Distribute around the circle
    
    for i = 1, MaxPlayers do
        local angle = angles[((i-1) % 8) + 1] * math.pi / 180
        local distance = radius * 0.7 -- 70% of the way to the edge
        
        local x = center.x + math.cos(angle) * distance
        local y = center.y + math.sin(angle) * distance
        local z = center.z
        
        -- Find ground Z
        local ground = 0
        local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, 1000.0, 0)
        
        if foundGround then
            z = groundZ + 1.0
        end
        
        table.insert(spawnPoints, vector3(x, y, z))
    end
    
    return spawnPoints
end

-- Function to group players by gang
function GetGangMembers(players)
    local gangMembers = {}
    local gangIndex = 1
    
    for _, playerId in ipairs(players) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            local identifier = Player.PlayerData.citizenid
            
            -- Check if player is in a gang
            MySQL.query('SELECT gang_id FROM lockdown_gang_members WHERE identifier = ?', {identifier}, function(results)
                if results and results[1] then
                    local gangId = results[1].gang_id
                    
                    -- Find or create gang group
                    local gangFound = false
                    for _, member in pairs(gangMembers) do
                        if member.gangId == gangId then
                            gangMembers[playerId] = {gangId = gangId, gangIndex = member.gangIndex}
                            gangFound = true
                            break
                        end
                    end
                    
                    if not gangFound then
                        gangMembers[playerId] = {gangId = gangId, gangIndex = gangIndex}
                        gangIndex = gangIndex + 1
                    end
                end
            end)
        end
    end
    
    return gangMembers
end

-- Function to schedule extraction points
function ScheduleExtraction(zoneId, delay)
    if ExtractionCount >= MaxExtractions then
        return -- All extractions used
    end
    
    Citizen.SetTimeout(delay, function()
        if not ActiveZones[zoneId] or not ActiveZones[zoneId].started then
            return -- Zone no longer active
        end
        
        -- Increment extraction count
        ExtractionCount = ExtractionCount + 1
        
        -- Select a random extraction point
        local extractionIndex = math.random(1, #Config.ExtractionPoints)
        local extraction = Config.ExtractionPoints[extractionIndex]
        
        -- Notify all players in the zone
        for _, player in ipairs(ActiveZones[zoneId].players) do
            TriggerClientEvent('lockdown:activateExtractionPoint', player, extraction, 45) -- 45 seconds duration
        end
        
        -- Schedule next extraction if not at max
        if ExtractionCount < MaxExtractions then
            ScheduleExtraction(zoneId, 4 * 60000) -- 4 minutes
        else
            -- This is the last extraction - warn players
            for _, player in ipairs(ActiveZones[zoneId].players) do
                TriggerClientEvent('lockdown:notification', player, "WARNING: This is the final extraction opportunity!")
            end
        end
    end)
end

-- Function to spawn vehicles in the zone
function SpawnVehiclesInZone(zoneId)
    if not ActiveZones[zoneId] then return end
    
    for _, spawnPoint in ipairs(Config.VehicleSpawns) do
        -- Check spawn chance
        if math.random() <= spawnPoint.spawnChance then
            -- Choose random vehicle model
            local modelIndex = math.random(1, #spawnPoint.models)
            local modelName = spawnPoint.models[modelIndex]
            
            -- Create vehicle
            local vehicle = CreateVehicleServerSetter(GetHashKey(modelName), 'automobile', spawnPoint.coords.x, spawnPoint.coords.y, spawnPoint.coords.z, spawnPoint.heading)
            
            -- Set routing bucket
            SetEntityRoutingBucket(vehicle, Config.RoutingBucket)
            
            -- Add to active vehicles
            table.insert(ActiveVehicles, vehicle)
        end
    end
end

-- Function to end Lockdown in a zone
function EndLockdown(zoneId)
    if not ActiveZones[zoneId] then return end
    
    -- Notify all remaining players
    for _, player in ipairs(ActiveZones[zoneId].players) do
        TriggerClientEvent('lockdown:eliminated', player)
    end
    
    -- Clear zone data
    PlayersInZone = {}
    ActiveZones[zoneId] = nil
    
    -- Reset LockdownInProgress
    LockdownInProgress = false
    
    -- Clean up vehicles
    for _, vehicle in ipairs(ActiveVehicles) do
        if DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
        end
    end
    ActiveVehicles = {}
    
    -- Reset extraction count
    ExtractionCount = 0
    
    -- Reset announcement cooldown
    AnnouncementCooldown = false
end

-- Leave zone event
RegisterNetEvent('lockdown:leaveZone')
AddEventHandler('lockdown:leaveZone', function()
    local source = source
    local zoneId = PlayersInZone[source]
    
    if not zoneId or not ActiveZones[zoneId] then return end
    
    -- Clear player inventory if using ox_inventory
    if Config.CheckInventory then
        exports.ox_inventory:ClearInventory(source)
    end
    
    -- Remove player from zone
    for i, player in ipairs(ActiveZones[zoneId].players) do
        if player == source then
            table.remove(ActiveZones[zoneId].players, i)
            break
        end
    end
    
    -- Update player's death count
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        MySQL.query('UPDATE lockdown_stats SET deaths = deaths + 1 WHERE identifier = ?', {Player.PlayerData.citizenid})
    end
    
    -- Remove from PlayersInZone
    PlayersInZone[source] = nil
    
    -- Reset player routing bucket
    SetPlayerRoutingBucket(source, 0)
    
    -- Check if zone is empty or has only one player left
    if #ActiveZones[zoneId].players <= 1 and ActiveZones[zoneId].started then
        -- If one player left, they win
        if #ActiveZones[zoneId].players == 1 then
            local winner = ActiveZones[zoneId].players[1]
            TriggerClientEvent('lockdown:gameEnd', winner)
            
            -- Update winner stats
            local WinnerPlayer = QBCore.Functions.GetPlayer(winner)
            if WinnerPlayer then
                -- Award bonus for winning
                if Config.RewardExtraction then
                    WinnerPlayer.Functions.AddMoney('cash', Config.ExtractionBonus)
                end
                
                -- Update stats
                MySQL.query('UPDATE lockdown_stats SET extractions = extractions + 1 WHERE identifier = ?', {WinnerPlayer.PlayerData.citizenid})
                
                -- Check for criminal tier upgrade
                CheckCriminalTierUpgrade(WinnerPlayer.PlayerData.citizenid)
            end
            
            -- Reset player routing bucket
            SetPlayerRoutingBucket(winner, 0)
        end
        
        -- End the Lockdown
        EndLockdown(zoneId)
    else
        -- Update player count
        UpdatePlayerCount(zoneId)
    end
    
    -- Notify the player they've been eliminated
    TriggerClientEvent('lockdown:eliminated', source)
end)

-- Leave lobby event
RegisterNetEvent('lockdown:leaveLobby')
AddEventHandler('lockdown:leaveLobby', function()
    local source = source
    local zoneId = PlayersInZone[source]
    
    if zoneId and ActiveZones[zoneId] and not ActiveZones[zoneId].started then
        -- Remove player from zone
        for i, player in ipairs(ActiveZones[zoneId].players) do
            if player == source then
                table.remove(ActiveZones[zoneId].players, i)
                break
            end
        end
        
        -- Remove from PlayersInZone
        PlayersInZone[source] = nil
        
        -- Reset player routing bucket if needed
        SetPlayerRoutingBucket(source, 0)
        
        -- Update player count
        UpdatePlayerCount(zoneId)
    end
end)

-- Record match participation
RegisterNetEvent('lockdown:recordParticipation')
AddEventHandler('lockdown:recordParticipation', function()
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    -- Set player routing bucket
    SetPlayerRoutingBucket(source, Config.RoutingBucket)
    SetRoutingBucketPopulationEnabled(Config.RoutingBucket, false)
    SetRoutingBucketEntityLockdownMode(Config.RoutingBucket, 'inactive')
end)

-- Player killed event
RegisterNetEvent('lockdown:playerKilled')
AddEventHandler('lockdown:playerKilled', function(killerId)
    local source = source
    local zoneId = PlayersInZone[source]
    
    if not zoneId or not ActiveZones[zoneId] or not killerId then return end
    
    -- Increment killer's kill count
    TriggerClientEvent('lockdown:addKill', killerId)
    
    -- Update killer's stats
    local KillerPlayer = QBCore.Functions.GetPlayer(killerId)
    if KillerPlayer then
        MySQL.query('UPDATE lockdown_stats SET kills = kills + 1 WHERE identifier = ?', {KillerPlayer.PlayerData.citizenid})
    end
end)

-- Add loot to player inventory
RegisterNetEvent('lockdown:addLoot')
AddEventHandler('lockdown:addLoot', function(lootName, lootData)
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    -- Add item to player's inventory
    local amount = 1
    
    if lootData.name == "cash_bag" then
        -- Generate random cash value
        local value = math.random(lootData.value.min, lootData.value.max)
        
        -- Store as a tracked item with value metadata
        Player.Functions.AddItem(lootName, amount, false, {value = value})
        
    elseif lootData.name == "weapon_cache" then
        -- Choose random weapon from cache
        local weaponIndex = math.random(1, #lootData.items)
        local weaponName = lootData.items[weaponIndex]
        
        -- Add weapon
        Player.Functions.AddItem(weaponName, 1)
        
        -- Add ammo if specified
        if lootData.ammo then
            local ammoAmount = math.random(lootData.ammo.amount.min, lootData.ammo.amount.max)
            Player.Functions.AddItem(lootData.ammo.name, ammoAmount)
        end
        
    else
        -- Standard item
        Player.Functions.AddItem(lootName, amount)
    end
end)

-- Start extraction event
RegisterNetEvent('lockdown:startExtraction')
AddEventHandler('lockdown:startExtraction', function(extractionName)
    local source = source
    local zoneId = PlayersInZone[source]
    
    if not zoneId or not ActiveZones[zoneId] then return end
    
    -- Notify other players in the zone
    for _, player in ipairs(ActiveZones[zoneId].players) do
        if player ~= source then
            TriggerClientEvent('lockdown:notification', player, "A player is extracting at " .. extractionName .. "!")
        end
    end
end)

-- Complete extraction event
RegisterNetEvent('lockdown:completeExtraction')
AddEventHandler('lockdown:completeExtraction', function(extractionName)
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    local zoneId = PlayersInZone[source]
    if not zoneId or not ActiveZones[zoneId] then return end
    
    -- Process player's loot
    local totalValue = 0
    
    -- Get all items from player inventory
    local items = nil
    
    if Config.CheckInventory then
        items = exports.ox_inventory:GetInventoryItems(source)
    else
        items = Player.PlayerData.items
    end
    
    if items then
        for _, item in pairs(items) do
            -- Check each loot type
            for _, lootType in pairs(Config.LootTypes) do
                if item.name == lootType.name then
                    local value = 0
                    
                    -- Get value based on item type
                    if lootType.name == "cash_bag" then
                        if item.metadata and item.metadata.value then
                            value = item.metadata.value
                        else
                            value = math.random(lootType.value.min, lootType.value.max)
                        end
                    else
                        value = math.random(lootType.value.min, lootType.value.max)
                    end
                    
                    totalValue = totalValue + value
                end
            end
        end
    end
    
    -- Add any extraction bonus
    if Config.RewardExtraction then
        totalValue = totalValue + Config.ExtractionBonus
    end
    
    -- Check if player completed a contract
    if ActiveContracts[source] then
        totalValue = totalValue + ActiveContracts[source].reward_cash
        
        -- Update contract completion stats
        MySQL.query('UPDATE lockdown_stats SET contracts_completed = contracts_completed + 1 WHERE identifier = ?', {Player.PlayerData.citizenid})
        
        -- Notify player
        TriggerClientEvent('lockdown:contractCompleted', source, ActiveContracts[source].reward_cash)
        
        -- Clear active contract
        ActiveContracts[source] = nil
    end
    
    -- Add money to player
    Player.Functions.AddMoney('cash', math.floor(totalValue * Config.LaunderingRate))
    
    -- Update player stats
    MySQL.query('UPDATE lockdown_stats SET extractions = extractions + 1, extracted_value = extracted_value + ? WHERE identifier = ?', 
    {
        totalValue,
        Player.PlayerData.citizenid
    })
    
    -- Check for criminal tier upgrade
    CheckCriminalTierUpgrade(Player.PlayerData.citizenid)
    
    -- Remove player from zone
    for i, player in ipairs(ActiveZones[zoneId].players) do
        if player == source then
            table.remove(ActiveZones[zoneId].players, i)
            break
        end
    end
    
    -- Remove from PlayersInZone
    PlayersInZone[source] = nil
    
    -- Reset player routing bucket
    SetPlayerRoutingBucket(source, 0)
    
    -- Clear inventory if using ox_inventory
    if Config.CheckInventory then
        exports.ox_inventory:ClearInventory(source)
    end
    
    -- Check if zone should end
    if #ActiveZones[zoneId].players <= 1 then
        EndLockdown(zoneId)
    else
        -- Update player count
        UpdatePlayerCount(zoneId)
    end
end)

-- Function to check for criminal tier upgrade
function CheckCriminalTierUpgrade(identifier)
    -- Get player's current stats
    MySQL.query('SELECT extractions, criminal_tier FROM lockdown_stats WHERE identifier = ?', {identifier}, function(results)
        if not results or not results[1] then return end
        
        local extractions = results[1].extractions
        local currentTier = results[1].criminal_tier
        
        -- Check for tier upgrade
        for _, tier in pairs(Config.CriminalTiers) do
            if extractions >= tier.requiredExtractions and tier.id > currentTier then
                -- Upgrade tier
                MySQL.query('UPDATE lockdown_stats SET criminal_tier = ? WHERE identifier = ?', {tier.id, identifier})
                
                -- Notify player of upgrade
                local playerSource = QBCore.Functions.GetPlayerByCitizenId(identifier)
                if playerSource then
                    TriggerClientEvent('lockdown:notification', playerSource.PlayerData.source, "Criminal tier upgraded to " .. tier.name .. "!")
                end
                
                break
            end
        end
    end)
end

-- Timer to check if Lockdown zones need to end
Citizen.CreateThread(function()
    while true do 
        Citizen.Wait(60000) -- Check every minute
        
        for zoneId, zone in pairs(ActiveZones) do
            if zone.started and #zone.players <= 1 then
                -- If one player left, they win
                if #zone.players == 1 then
                    local winner = zone.players[1]
                    TriggerClientEvent('lockdown:gameEnd', winner)
                    
                    -- Update winner stats
                    local WinnerPlayer = QBCore.Functions.GetPlayer(winner)
                    if WinnerPlayer then
                        -- Award bonus for winning
                        if Config.RewardExtraction then
                            WinnerPlayer.Functions.AddMoney('cash', Config.ExtractionBonus)
                        end
                        
                        -- Update stats
                        MySQL.query('UPDATE lockdown_stats SET extractions = extractions + 1 WHERE identifier = ?', {WinnerPlayer.PlayerData.citizenid})
                        
                        -- Check for criminal tier upgrade
                        CheckCriminalTierUpgrade(WinnerPlayer.PlayerData.citizenid)
                    end
                    
                    -- Reset player routing bucket
                    SetPlayerRoutingBucket(winner, 0)
                end
                
                -- End the Lockdown
                EndLockdown(zoneId)
            end
        end
    end
end)

-- Player disconnect handler
AddEventHandler('playerDropped', function(reason)
    local source = source
    local zoneId = PlayersInZone[source]
    
    if zoneId and ActiveZones[zoneId] then
        -- Remove player from zone
        for i, player in ipairs(ActiveZones[zoneId].players) do
            if player == source then
                table.remove(ActiveZones[zoneId].players, i)
                break
            end
        end
        
        -- Remove from PlayersInZone
        PlayersInZone[source] = nil
        
        -- Clear inventory if using ox_inventory
        if Config.CheckInventory then
            exports.ox_inventory:ClearInventory(source)
        end
        
        -- Update player count
        UpdatePlayerCount(zoneId)
        
        -- Check if zone should end
        if ActiveZones[zoneId].started and #ActiveZones[zoneId].players <= 1 then
            if #ActiveZones[zoneId].players == 1 then
                -- Last player wins
                local winner = ActiveZones[zoneId].players[1]
                TriggerClientEvent('lockdown:gameEnd', winner)
                
                -- Update winner stats
                local WinnerPlayer = QBCore.Functions.GetPlayer(winner)
                if WinnerPlayer then
                    -- Award bonus for winning
                    if Config.RewardExtraction then
                        WinnerPlayer.Functions.AddMoney('cash', Config.ExtractionBonus)
                    end
                    
                    -- Update stats
                    MySQL.query('UPDATE lockdown_stats SET extractions = extractions + 1 WHERE identifier = ?', {WinnerPlayer.PlayerData.citizenid})
                    
                    -- Check for criminal tier upgrade
                    CheckCriminalTierUpgrade(WinnerPlayer.PlayerData.citizenid)
                end
                
                -- Reset player routing bucket
                SetPlayerRoutingBucket(winner, 0)
            end
            
            -- End the Lockdown
            EndLockdown(zoneId)
        end
    end
end)