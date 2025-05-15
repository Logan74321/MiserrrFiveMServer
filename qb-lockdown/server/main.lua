local QBCore = exports['qb-core']:GetCoreObject()
local ActiveGames = {}
local WaitingPlayers = {}
local Instances = {}
local InstanceCounter = 0

-- Database initialization
CreateThread(function()
    MySQL.query('CREATE TABLE IF NOT EXISTS lockdown_stats (citizenid VARCHAR(50), extractions INT DEFAULT 0, deaths INT DEFAULT 0, kills INT DEFAULT 0, total_value INT DEFAULT 0, highest_streak INT DEFAULT 0, contracts_completed INT DEFAULT 0, PRIMARY KEY (citizenid))')
    MySQL.query('CREATE TABLE IF NOT EXISTS lockdown_gangs (id INT AUTO_INCREMENT, name VARCHAR(50), color VARCHAR(7), emblem VARCHAR(50), leader VARCHAR(50), PRIMARY KEY (id))')
    MySQL.query('CREATE TABLE IF NOT EXISTS lockdown_gang_members (id INT AUTO_INCREMENT, gang_id INT, citizenid VARCHAR(50), rank INT DEFAULT 0, PRIMARY KEY (id))')
end)

-- Game initialization function
function InitializeGame(zoneName)
    InstanceCounter = InstanceCounter + 1
    local gameId = "lockdown_" .. InstanceCounter
    
    ActiveGames[gameId] = {
        id = gameId,
        zone = zoneName,
        players = {},
        startTime = os.time(),
        endTime = os.time() + (Config.MatchDuration * 60),
        state = "waiting", -- waiting, active, ending
        playerCount = 0,
        maxPlayers = Config.MaxPlayers,
        extractionPoints = {},
        lootSpawned = false,
        instance = InstanceCounter
    }
    
    -- Set up a routing bucket for this game instance
    SetRoutingBucketPopulationEnabled(InstanceCounter, false)
    
    print("^2Game initialized: " .. gameId .. " in zone " .. zoneName .. "^7")
    TriggerClientEvent('qb-lockdown:client:UpdateGames', -1, GetGameList())
    
    return gameId
end

-- Get all active games for the UI
function GetGameList()
    local games = {}
    for k, v in pairs(ActiveGames) do
        games[k] = {
            id = v.id,
            zone = v.zone,
            label = Config.Zones[v.zone].label,
            players = v.playerCount,
            maxPlayers = v.maxPlayers,
            state = v.state,
            timeRemaining = v.endTime - os.time()
        }
    end
    return games
end

-- Register a player for a game
RegisterNetEvent('qb-lockdown:server:JoinGame', function(gameId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check if player is already in a game
    for k, v in pairs(ActiveGames) do
        for playerId, _ in pairs(v.players) do
            if tonumber(playerId) == src then
                TriggerClientEvent('QBCore:Notify', src, "You are already in a game!", "error")
                return
            end
        end
    end
    
    -- Check if game exists and has space
    if ActiveGames[gameId] and ActiveGames[gameId].playerCount < ActiveGames[gameId].maxPlayers then
        ActiveGames[gameId].players[tostring(src)] = {
            citizenid = Player.PlayerData.citizenid,
            name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
            kills = 0,
            loot = {},
            totalValue = 0,
            extracted = false,
            spawnPoint = nil
        }
        
        ActiveGames[gameId].playerCount = ActiveGames[gameId].playerCount + 1
        
        -- Assign player to routing bucket
        SetPlayerRoutingBucket(src, ActiveGames[gameId].instance)
        
        -- Get player's stats
        MySQL.query('SELECT * FROM lockdown_stats WHERE citizenid = ?', {Player.PlayerData.citizenid}, function(result)
            local stats = {}
            if result and #result > 0 then
                stats = result[1]
            else
                -- Create stats entry if it doesn't exist
                MySQL.insert('INSERT INTO lockdown_stats (citizenid) VALUES (?)', {Player.PlayerData.citizenid})
            end
            
            -- Notify player and send them to the game
            TriggerClientEvent('QBCore:Notify', src, "Joined Lockdown Protocol: " .. Config.Zones[ActiveGames[gameId].zone].label, "success")
            TriggerClientEvent('qb-lockdown:client:EnterGame', src, ActiveGames[gameId], Config.Zones[ActiveGames[gameId].zone], stats)
        end)
        
        -- Check if game should start
        if ActiveGames[gameId].playerCount >= Config.MinPlayersToStart and ActiveGames[gameId].state == "waiting" then
            StartGame(gameId)
        end
        
        -- Update all clients with the new player list
        TriggerClientEvent('qb-lockdown:client:UpdateGames', -1, GetGameList())
    else
        TriggerClientEvent('QBCore:Notify', src, "Unable to join game. It may be full or no longer available.", "error")
    end
end)

-- Start a game when enough players have joined
function StartGame(gameId)
    if not ActiveGames[gameId] then return end
    
    ActiveGames[gameId].state = "active"
    ActiveGames[gameId].startTime = os.time()
    ActiveGames[gameId].endTime = os.time() + (Config.MatchDuration * 60)
    
    -- Assign spawn points to players
    local zone = Config.Zones[ActiveGames[gameId].zone]
    local spawnPoints = zone.spawnPoints
    local usedSpawns = {}
    
    for playerId, _ in pairs(ActiveGames[gameId].players) do
        local availableSpawns = {}
        for i, spawn in ipairs(spawnPoints) do
            if not usedSpawns[i] then
                table.insert(availableSpawns, {index = i, spawn = spawn})
            end
        end
        
        if #availableSpawns > 0 then
            local randomIndex = math.random(1, #availableSpawns)
            local spawnData = availableSpawns[randomIndex]
            usedSpawns[spawnData.index] = true
            ActiveGames[gameId].players[playerId].spawnPoint = spawnData.spawn
        else
            -- If somehow we run out of spawn points, just use the first one
            ActiveGames[gameId].players[playerId].spawnPoint = spawnPoints[1]
        end
    end
    
    -- Spawn loot
    SpawnLoot(gameId)
    
    -- Notify all players in the game
    for playerId, playerData in pairs(ActiveGames[gameId].players) do
        TriggerClientEvent('qb-lockdown:client:GameStarted', tonumber(playerId), ActiveGames[gameId], playerData.spawnPoint)
    end
    
    -- Set timer for extraction points activation
    SetTimeout(10 * 60 * 1000, function() -- 10 minutes
        ActivateExtractionPoints(gameId)
    end)
    
    print("^2Game started: " .. gameId .. "^7")
    TriggerClientEvent('qb-lockdown:client:UpdateGames', -1, GetGameList())
end

-- Spawn loot for the game
function SpawnLoot(gameId)
    if not ActiveGames[gameId] or ActiveGames[gameId].lootSpawned then return end
    
    local zone = Config.Zones[ActiveGames[gameId].zone]
    local lootSpots = {}
    
    -- Create loot spots based on zone size and type
    local lootAmount = math.random(15, 30) -- Adjust based on zone size
    local centerCoords = zone.coords
    local radius = zone.radius
    
    for i = 1, lootAmount do
        local angle = math.random() * math.pi * 2
        local distance = math.sqrt(math.random()) * radius * 0.8 -- Keep within 80% of radius
        
        local x = centerCoords.x + math.cos(angle) * distance
        local y = centerCoords.y + math.sin(angle) * distance
        local z = centerCoords.z
        
        -- Get ground Z
        local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, z, 0)
        if foundGround then
            z = groundZ + 1.0
        end
        
        local lootTypes = {"cashbag", "drugstash", "weaponcrate", "intel"}
        local lootType = lootTypes[math.random(1, #lootTypes)]
        
        table.insert(lootSpots, {
            type = lootType,
            coords = vector3(x, y, z),
            looted = false,
            model = Config.LootSpots[lootType].model
        })
    end
    
    ActiveGames[gameId].lootSpots = lootSpots
    ActiveGames[gameId].lootSpawned = true
    
    -- Send loot spots to all players in the game
    for playerId, _ in pairs(ActiveGames[gameId].players) do
        TriggerClientEvent('qb-lockdown:client:SyncLoot', tonumber(playerId), lootSpots)
    end
end

-- Activate extraction points
function ActivateExtractionPoints(gameId)
    if not ActiveGames[gameId] or ActiveGames[gameId].state ~= "active" then return end
    
    local extractionPoints = {}
    
    -- Choose random extraction points (1 of each type)
    local types = {"boat", "heli", "land"}
    for _, extractType in ipairs(types) do
        local availablePoints = {}
        for k, v in pairs(Config.ExtractionPoints) do
            if v.type == extractType then
                table.insert(availablePoints, {key = k, data = v})
            end
        end
        
        if #availablePoints > 0 then
            local chosen = availablePoints[math.random(1, #availablePoints)]
            extractionPoints[chosen.key] = chosen.data
        end
    end
    
    ActiveGames[gameId].extractionPoints = extractionPoints
    
    -- Notify all players
    for playerId, _ in pairs(ActiveGames[gameId].players) do
        TriggerClientEvent('qb-lockdown:client:ActivateExtractions', tonumber(playerId), extractionPoints)
        TriggerClientEvent('QBCore:Notify', tonumber(playerId), "Extraction points are now active!", "success")
    end
end

-- Player extracts from the game
RegisterNetEvent('qb-lockdown:server:PlayerExtract', function(gameId, extractionPoint)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not ActiveGames[gameId] or not ActiveGames[gameId].players[tostring(src)] then return end
    
    local playerData = ActiveGames[gameId].players[tostring(src)]
    if playerData.extracted then return end
    
    -- Mark player as extracted
    playerData.extracted = true
    
    -- Process loot and add to player inventory/money
    local totalValue = 0
    local lootReport = {}
    
    for _, item in pairs(playerData.loot) do
        if item.type == "cash" then
            Player.Functions.AddMoney("cash", item.amount, "lockdown-extraction")
            totalValue = totalValue + item.amount
            lootReport[item.type] = (lootReport[item.type] or 0) + item.amount
        else
            -- Add item to player inventory
            local added = exports['qb-inventory']:AddItem(src, item.name, item.amount, nil, item.info)
            if added then
                local itemData = QBCore.Shared.Items[item.name]
                if itemData then
                    totalValue = totalValue + (itemData.price * item.amount)
                    lootReport[item.name] = (lootReport[item.name] or 0) + item.amount
                end
            end
        end
    end
    
    -- Update player stats
    MySQL.query('SELECT * FROM lockdown_stats WHERE citizenid = ?', {Player.PlayerData.citizenid}, function(result)
        if result and #result > 0 then
            local stats = result[1]
            local extractions = stats.extractions + 1
            local total_value = stats.total_value + totalValue
            
            MySQL.update('UPDATE lockdown_stats SET extractions = ?, total_value = ? WHERE citizenid = ?', 
                {extractions, total_value, Player.PlayerData.citizenid})
        else
            MySQL.insert('INSERT INTO lockdown_stats (citizenid, extractions, total_value) VALUES (?, ?, ?)', 
                {Player.PlayerData.citizenid, 1, totalValue})
        end
    end)
    
    -- Return player to regular routing bucket
    SetPlayerRoutingBucket(src, 0)
    
    -- Create loot report message
    local reportMsg = "Extraction Successful!\n"
    for itemName, amount in pairs(lootReport) do
        reportMsg = reportMsg .. itemName .. ": " .. amount .. "\n"
    end
    reportMsg = reportMsg .. "Total Value: $" .. totalValue
    
    -- Notify player of successful extraction
    TriggerClientEvent('QBCore:Notify', src, "You have successfully extracted with your loot!", "success")
    TriggerClientEvent('qb-lockdown:client:ShowExtractionReport', src, reportMsg, totalValue)
    TriggerClientEvent('qb-lockdown:client:LeaveGame', src)
    
    -- Check if all players have extracted or died
    CheckGameEnd(gameId)
end)

-- Player dies in the game
RegisterNetEvent('qb-lockdown:server:PlayerDied', function(gameId, killerSource)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not ActiveGames[gameId] or not ActiveGames[gameId].players[tostring(src)] then return end
    
    -- Update killer stats if it's another player
    if killerSource and killerSource > 0 and ActiveGames[gameId].players[tostring(killerSource)] then
        local Killer = QBCore.Functions.GetPlayer(killerSource)
        if Killer then
            ActiveGames[gameId].players[tostring(killerSource)].kills = ActiveGames[gameId].players[tostring(killerSource)].kills + 1
            
            -- Update killer's stats in database
            MySQL.query('SELECT * FROM lockdown_stats WHERE citizenid = ?', {Killer.PlayerData.citizenid}, function(result)
                if result and #result > 0 then
                    local kills = result[1].kills + 1
                    MySQL.update('UPDATE lockdown_stats SET kills = ? WHERE citizenid = ?', 
                        {kills, Killer.PlayerData.citizenid})
                else
                    MySQL.insert('INSERT INTO lockdown_stats (citizenid, kills) VALUES (?, ?)', 
                        {Killer.PlayerData.citizenid, 1})
                end
            end)
            
            TriggerClientEvent('QBCore:Notify', killerSource, "You eliminated " .. Player.PlayerData.charinfo.firstname .. "!", "success")
        end
    end
    
    -- Update death stats for the player
    MySQL.query('SELECT * FROM lockdown_stats WHERE citizenid = ?', {Player.PlayerData.citizenid}, function(result)
        if result and #result > 0 then
            local deaths = result[1].deaths + 1
            MySQL.update('UPDATE lockdown_stats SET deaths = ? WHERE citizenid = ?', 
                {deaths, Player.PlayerData.citizenid})
        else
            MySQL.insert('INSERT INTO lockdown_stats (citizenid, deaths) VALUES (?, ?)', 
                {Player.PlayerData.citizenid, 1})
        end
    end)
    
    -- Drop all items from player's loot
    local droppedItems = ActiveGames[gameId].players[tostring(src)].loot
    if #droppedItems > 0 then
        local playerCoords = GetEntityCoords(GetPlayerPed(src))
        local dropId = "lockdrop_" .. math.random(1000000, 9999999)
        
        -- Create loot drop at player's death location
        ActiveGames[gameId].lootDrops = ActiveGames[gameId].lootDrops or {}
        ActiveGames[gameId].lootDrops[dropId] = {
            coords = playerCoords,
            items = droppedItems,
            label = Player.PlayerData.charinfo.firstname .. "'s Loot",
            time = os.time()
        }
        
        -- Notify all players about the loot drop
        for playerId, _ in pairs(ActiveGames[gameId].players) do
            TriggerClientEvent('qb-lockdown:client:SyncLootDrop', tonumber(playerId), dropId, ActiveGames[gameId].lootDrops[dropId])
        end
    end
    
    -- Remove player from game
    ActiveGames[gameId].players[tostring(src)] = nil
    ActiveGames[gameId].playerCount = ActiveGames[gameId].playerCount - 1
    
    -- Return player to regular routing bucket
    SetPlayerRoutingBucket(src, 0)
    
    -- Notify and return player to normal world
    TriggerClientEvent('QBCore:Notify', src, "You were eliminated from Lockdown Protocol!", "error")
    TriggerClientEvent('qb-lockdown:client:LeaveGame', src)
    
    -- Check if game should end
    CheckGameEnd(gameId)
    
    -- Update all clients with new player count
    TriggerClientEvent('qb-lockdown:client:UpdateGames', -1, GetGameList())
end)

-- Loot an item
RegisterNetEvent('qb-lockdown:server:LootItem', function(gameId, lootIndex)
    local src = source
    
    if not ActiveGames[gameId] or not ActiveGames[gameId].lootSpots or not ActiveGames[gameId].lootSpots[lootIndex] then return end
    
    local lootSpot = ActiveGames[gameId].lootSpots[lootIndex]
    if lootSpot.looted then return end
    
    -- Mark as looted
    ActiveGames[gameId].lootSpots[lootIndex].looted = true
    
    -- Generate items from loot spot
    local lootType = lootSpot.type
    local items = {}
    
    if Config.LootSpots[lootType] then
        for _, itemConfig in pairs(Config.LootSpots[lootType].items) do
            local chance = math.random(1, 100)
            if chance <= itemConfig.chance then
                local amount = math.random(itemConfig.min, itemConfig.max)
                table.insert(items, {
                    name = itemConfig.name,
                    amount = amount,
                    type = itemConfig.name == "cash" and "cash" or "item",
                    info = {}
                })
            end
        end
    end
    
    -- Add items to player's loot
    if not ActiveGames[gameId].players[tostring(src)] then return end
    
    for _, item in pairs(items) do
        table.insert(ActiveGames[gameId].players[tostring(src)].loot, item)
    end
    
    -- Sync loot spots with all players
    for playerId, _ in pairs(ActiveGames[gameId].players) do
        TriggerClientEvent('qb-lockdown:client:SyncLoot', tonumber(playerId), ActiveGames[gameId].lootSpots)
    end
    
    -- Notify player of loot
    local itemList = ""
    for i, item in ipairs(items) do
        local itemName = item.name
        if item.name ~= "cash" then
            local itemData = QBCore.Shared.Items[item.name]
            if itemData then
                itemName = itemData.label
            end
        else
            itemName = "$" .. item.amount
        end
        
        itemList = itemList .. itemName .. " x" .. item.amount
        if i < #items then
            itemList = itemList .. ", "
        end
    end
    
    TriggerClientEvent('QBCore:Notify', src, "Looted: " .. itemList, "success")
    
    -- Update client's loot UI
    TriggerClientEvent('qb-lockdown:client:UpdateLoot', src, ActiveGames[gameId].players[tostring(src)].loot)
end)

-- Loot a drop
RegisterNetEvent('qb-lockdown:server:LootDrop', function(gameId, dropId)
    local src = source
    
    if not ActiveGames[gameId] or not ActiveGames[gameId].lootDrops or not ActiveGames[gameId].lootDrops[dropId] then return end
    
    -- Add items to player's loot
    if not ActiveGames[gameId].players[tostring(src)] then return end
    
    local dropItems = ActiveGames[gameId].lootDrops[dropId].items
    for _, item in pairs(dropItems) do
        table.insert(ActiveGames[gameId].players[tostring(src)].loot, item)
    end
    
    -- Remove the drop
    ActiveGames[gameId].lootDrops[dropId] = nil
    
    -- Sync drops with all players
    for playerId, _ in pairs(ActiveGames[gameId].players) do
        TriggerClientEvent('qb-lockdown:client:RemoveLootDrop', tonumber(playerId), dropId)
    end
    
    -- Notify player
    TriggerClientEvent('QBCore:Notify', src, "You looted the drop!", "success")
    
    -- Update client's loot UI
    TriggerClientEvent('qb-lockdown:client:UpdateLoot', src, ActiveGames[gameId].players[tostring(src)].loot)
end)

-- Check if the game should end
function CheckGameEnd(gameId)
    if not ActiveGames[gameId] then return end
    
    -- End game if all players have extracted or died
    local activePlayers = 0
    for _ in pairs(ActiveGames[gameId].players) do
        activePlayers = activePlayers + 1
    end
    
    if activePlayers == 0 or os.time() >= ActiveGames[gameId].endTime then
        EndGame(gameId)
    end
end

-- End the game
function EndGame(gameId)
    if not ActiveGames[gameId] then return end
    
    -- Notify any remaining players and force extract them
    for playerId, playerData in pairs(ActiveGames[gameId].players) do
        if not playerData.extracted then
            local Player = QBCore.Functions.GetPlayer(tonumber(playerId))
            if Player then
                -- Process loot
                local totalValue = 0
                for _, item in pairs(playerData.loot) do
                    if item.type == "cash" then
                        Player.Functions.AddMoney("cash", item.amount, "lockdown-extraction-endgame")
                        totalValue = totalValue + item.amount
                    else
                        -- Add item to player inventory
                        exports['qb-inventory']:AddItem(tonumber(playerId), item.name, item.amount, nil, item.info)
                        local itemData = QBCore.Shared.Items[item.name]
                        if itemData then
                            totalValue = totalValue + (itemData.price * item.amount)
                        end
                    end
                end
                
                -- Update stats
                MySQL.query('SELECT * FROM lockdown_stats WHERE citizenid = ?', {Player.PlayerData.citizenid}, function(result)
                    if result and #result > 0 then
                        local stats = result[1]
                        local extractions = stats.extractions + 1
                        local total_value = stats.total_value + totalValue
                        
                        MySQL.update('UPDATE lockdown_stats SET extractions = ?, total_value = ? WHERE citizenid = ?', 
                            {extractions, total_value, Player.PlayerData.citizenid})
                    else
                        MySQL.insert('INSERT INTO lockdown_stats (citizenid, extractions, total_value) VALUES (?, ?, ?)', 
                            {Player.PlayerData.citizenid, 1, totalValue})
                    end
                end)
                
                -- Return to regular routing bucket
                SetPlayerRoutingBucket(tonumber(playerId), 0)
                
                -- Notify player
                TriggerClientEvent('QBCore:Notify', tonumber(playerId), "Lockdown Protocol has ended. You've been extracted with your loot!", "success")
                TriggerClientEvent('qb-lockdown:client:LeaveGame', tonumber(playerId))
            end
        end
    end
    
    -- Remove the game
    ActiveGames[gameId] = nil
    
    print("^3Game ended: " .. gameId .. "^7")
    TriggerClientEvent('qb-lockdown:client:UpdateGames', -1, GetGameList())
end

-- Create a new game every X minutes
CreateThread(function()
    while true do
        Wait(60000) -- Check every minute
        
        -- Create a new game if there are no active games or waiting games
        local activeGamesCount = 0
        for _ in pairs(ActiveGames) do
            activeGamesCount = activeGamesCount + 1
        end
        
        if activeGamesCount == 0 then
            -- Choose a random zone
            local zones = {}
            for zoneName in pairs(Config.Zones) do
                table.insert(zones, zoneName)
            end
            
            if #zones > 0 then
                local randomZone = zones[math.random(1, #zones)]
                InitializeGame(randomZone)
                
                -- Announce to all players
                TriggerClientEvent('qb-lockdown:client:AnnounceGame', -1, randomZone)
            end
        end
        
        -- Clean up any games that have ended
        for gameId, gameData in pairs(ActiveGames) do
            if os.time() >= gameData.endTime then
                EndGame(gameId)
            end
        end
    end
end)

-- Player left the server
AddEventHandler('playerDropped', function()
    local src = source
    
    -- Remove player from any active games
    for gameId, gameData in pairs(ActiveGames) do
        if gameData.players[tostring(src)] then
            ActiveGames[gameId].players[tostring(src)] = nil
            ActiveGames[gameId].playerCount = ActiveGames[gameId].playerCount - 1
            
            -- Check if game should end
            CheckGameEnd(gameId)
            
            -- Update all clients with new player count
            TriggerClientEvent('qb-lockdown:client:UpdateGames', -1, GetGameList())
        end
    end
end)

-- Get player stats
QBCore.Functions.CreateCallback('qb-lockdown:server:GetPlayerStats', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end
    
    MySQL.query('SELECT * FROM lockdown_stats WHERE citizenid = ?', {Player.PlayerData.citizenid}, function(result)
        if result and #result > 0 then
            cb(result[1])
        else
            cb({
                extractions = 0,
                deaths = 0,
                kills = 0,
                total_value = 0,
                highest_streak = 0,
                contracts_completed = 0
            })
        end
    end)
end)

-- Get leaderboard
QBCore.Functions.CreateCallback('qb-lockdown:server:GetLeaderboard', function(source, cb)
    MySQL.query('SELECT l.*, p.charinfo FROM lockdown_stats l LEFT JOIN players p ON l.citizenid = p.citizenid ORDER BY l.total_value DESC LIMIT 10', {}, function(result)
        local leaderboard = {}
        if result and #result > 0 then
            for i, entry in ipairs(result) do
                local charInfo = json.decode(entry.charinfo) or {}
                table.insert(leaderboard, {
                    name = (charInfo.firstname or "Unknown") .. " " .. (charInfo.lastname or "Player"),
                    extractions = entry.extractions,
                    kills = entry.kills,
                    deaths = entry.deaths,
                    value = entry.total_value,
                    rank = i
                })
            end
        end
        cb(leaderboard)
    end)
end)

-- Get gang info
QBCore.Functions.CreateCallback('qb-lockdown:server:GetGangInfo', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(nil) end
    
    MySQL.query('SELECT g.*, gm.rank FROM lockdown_gang_members gm LEFT JOIN lockdown_gangs g ON gm.gang_id = g.id WHERE gm.citizenid = ?', {Player.PlayerData.citizenid}, function(result)
        if result and #result > 0 then
            cb(result[1])
        else
            cb(nil)
        end
    end)
end)

-- Create a gang
RegisterNetEvent('qb-lockdown:server:CreateGang', function(gangData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check if player is already in a gang
    MySQL.query('SELECT * FROM lockdown_gang_members WHERE citizenid = ?', {Player.PlayerData.citizenid}, function(result)
        if result and #result > 0 then
            TriggerClientEvent('QBCore:Notify', src, "You are already in a gang!", "error")
            return
        end
        
        -- Check if gang name is taken
        MySQL.query('SELECT * FROM lockdown_gangs WHERE name = ?', {gangData.name}, function(nameCheck)
            if nameCheck and #nameCheck > 0 then
                TriggerClientEvent('QBCore:Notify', src, "This gang name is already taken!", "error")
                return
            end
            
            -- Create gang
            MySQL.insert('INSERT INTO lockdown_gangs (name, color, emblem, leader) VALUES (?, ?, ?, ?)', 
                {gangData.name, gangData.color, gangData.emblem, Player.PlayerData.citizenid}, function(gangId)
                
                -- Add player as leader
                MySQL.insert('INSERT INTO lockdown_gang_members (gang_id, citizenid, rank) VALUES (?, ?, ?)', 
                    {gangId, Player.PlayerData.citizenid, 3}) -- Rank 3 = Leader
                
                TriggerClientEvent('QBCore:Notify', src, "Gang created successfully!", "success")
            end)
        end)
    end)
end)

-- Invite player to gang
RegisterNetEvent('qb-lockdown:server:InviteToGang', function(targetId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(targetId)
    
    if not Player or not Target then return end
    
    -- Check if player is in a gang and is a leader
    MySQL.query('SELECT g.*, gm.rank FROM lockdown_gang_members gm LEFT JOIN lockdown_gangs g ON gm.gang_id = g.id WHERE gm.citizenid = ?', {Player.PlayerData.citizenid}, function(result)
        if not result or #result == 0 or result[1].rank < 2 then -- Need to be rank 2+ to invite
            TriggerClientEvent('QBCore:Notify', src, "You don't have permission to invite members!", "error")
            return
        end
        
        -- Check if target is already in a gang
        MySQL.query('SELECT * FROM lockdown_gang_members WHERE citizenid = ?', {Target.PlayerData.citizenid}, function(targetCheck)
            if targetCheck and #targetCheck > 0 then
                TriggerClientEvent('QBCore:Notify', src, "This player is already in a gang!", "error")
                return
            end
            
            -- Send invitation
            TriggerClientEvent('qb-lockdown:client:GangInvite', targetId, {
                gangId = result[1].id,
                gangName = result[1].name,
                inviterName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
            })
            
            TriggerClientEvent('QBCore:Notify', src, "Gang invitation sent!", "success")
        end)
    end)
end)

-- Accept gang invitation
RegisterNetEvent('qb-lockdown:server:AcceptGangInvite', function(gangId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check if player is already in a gang
    MySQL.query('SELECT * FROM lockdown_gang_members WHERE citizenid = ?', {Player.PlayerData.citizenid}, function(result)
        if result and #result > 0 then
            TriggerClientEvent('QBCore:Notify', src, "You are already in a gang!", "error")
            return
        end
        
        -- Add to gang
        MySQL.insert('INSERT INTO lockdown_gang_members (gang_id, citizenid, rank) VALUES (?, ?, ?)', 
            {gangId, Player.PlayerData.citizenid, 1}) -- Rank 1 = Prospect
        
        TriggerClientEvent('QBCore:Notify', src, "You've joined the gang!", "success")
    end)
end)

-- Schedule server-wide announcements
CreateThread(function()
    while true do
        Wait(25 * 60 * 1000) -- Every 25 minutes
        
        -- Choose a random zone
        local zones = {}
        for zoneName in pairs(Config.Zones) do
            table.insert(zones, zoneName)
        end
        
        if #zones > 0 then
            local randomZone = zones[math.random(1, #zones)]
            
            -- Create a new game
            local gameId = InitializeGame(randomZone)
            
            -- Announce to all players
            TriggerClientEvent('qb-lockdown:client:AnnounceGame', -1, randomZone)
        end
    end
end)