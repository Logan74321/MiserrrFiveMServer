local QBCore = exports['qb-core']:GetCoreObject()

local PlayerIds = {}
local MinPlayers = Config.MinPlayers
local MaxPlayers = Config.MaxPlayers
local PubgStarted = false
local vehicles = {}






QBCore.Functions.CreateCallback('pubg:getdatatoplist', function(source, cb)
    local data = MySQL.query.await('SELECT * FROM pubg_stats ORDER BY wins DESC LIMIT 10;' , {})
        cb(data)
end)

QBCore.Functions.CreateCallback('pubg:getdatacareer', function(source, cb)
    local data = MySQL.query.await('SELECT * FROM pubg_stats WHERE identifier = @identifier' , {
        ['@identifier'] = GetPlayerIdentifier(source)
    })
        cb(data)
end)


QBCore.Functions.CreateCallback('pubg:getdatawins', function(source, cb)
    local source = source
    local data = MySQL.Sync.fetchScalar('SELECT wins FROM pubg_stats WHERE identifier = @identifier' , {
        ['@identifier'] = GetPlayerIdentifier(source)
    })
    if data ~= nil then 
        cb(data)
    else
        cb(0)
    end
end)

RegisterNetEvent('pubg:matchplayed')
AddEventHandler('pubg:matchplayed', function()
    local playerIdentifier = GetPlayerIdentifier(source)
    MySQL.update('UPDATE pubg_stats SET games = games + 1 WHERE identifier = ?', {playerIdentifier}, function()
    end)
end)

RegisterServerEvent('pubg:join')
AddEventHandler('pubg:join', function()
    local id = source
    if not PubgStarted then
        if #PlayerIds == 0 then 
                        table.insert(PlayerIds, id)
                        local playercount = #PlayerIds
                        TriggerClientEvent('joinedHungerGames', id, 'joined', playercount , MaxPlayers)
                        if #PlayerIds >= Config.MinPlayers then
                            Citizen.Wait(4800)
                            for i, PlayersId in pairs(PlayerIds) do
                                TriggerClientEvent('pubg:notifications', PlayersId, Config.Language.StartingSoon)
                            end
                            Citizen.Wait(4800)
                            StartPubg()
                            PubgStarted = true
                        end
        elseif #PlayerIds > 0 then 
            for i, value in ipairs(PlayerIds) do 
                if value == id then 
                    TriggerClientEvent('joinedHungerGames', id, 'already')
                else
                    if #PlayerIds <= Config.MaxPlayers then 
                        table.insert(PlayerIds, id)
                        local playercount = #PlayerIds
                        TriggerClientEvent('joinedHungerGames', id, 'joined', playercount , MaxPlayers)
                    else
                        TriggerClientEvent('joinedHungerGames', id, 'notjoined')
                    end
                    if #PlayerIds >= Config.MinPlayers and not PubgStarted then
                        PubgStarted = true
                        Citizen.Wait(4800)
                        for i, PlayersId in pairs(PlayerIds) do
                            TriggerClientEvent('pubg:notifications', PlayersId, Config.Language.StartingSoon)
                        end
                        Citizen.Wait(4800)
                        StartPubg()     
                    end
                end
            end
        end
    else
        TriggerClientEvent('joinedHungerGames', id, 'started')
    end
end)




RegisterServerEvent('pubg:deleteid')
AddEventHandler('pubg:deleteid', function()
    local id = source
    if Config.CheckInventory then 
        exports.ox_inventory:ClearInventory(id)
    end
    TriggerClientEvent('pubg:removed', id)
    SetPlayerRoutingBucket(id, 0)
    for i, value in ipairs(PlayerIds) do
        if value == id then
            table.remove(PlayerIds, i)
            if #PlayerIds <= 1 then
                for i, PlayersId in pairs(PlayerIds) do
                    TriggerClientEvent('pubg:gameend', PlayersId)
                    SetPlayerRoutingBucket(PlayersId, 0)
                    if Config.CheckInventory then 
                        exports.ox_inventory:ClearInventory(PlayersId)
                    end
                    if Config.WinPayment then 
                        local Player  = QBCore.Functions.GetPlayer(PlayersId)
                        Player.Functions.AddMoney('cash', Config.Payamount)
                    end
                    local playerIdentifier = GetPlayerIdentifier(PlayersId)
                    local name = GetPlayerName(PlayersId)
                    MySQL.query('SELECT * FROM pubg_stats WHERE identifier = ?', {playerIdentifier}, function(result)
                        if json.encode(result) ~= '[]' then
                            MySQL.update('UPDATE pubg_stats SET wins = wins + 1 WHERE identifier = ?', {playerIdentifier}, function()
                            end)
                        else
                            MySQL.insert('INSERT INTO pubg_stats (identifier, name, wins) VALUES (?, ?, 1)', {playerIdentifier, name}, function()
                            end)
                        end
                    end)
                end
                PubgStarted = false
                PlayerIds = {}
                for k,v in pairs(vehicles) do
                    if DoesEntityExist(v) then
                        print('deleted')
                        DeleteEntity(v)
                    end
                end
            end
            break
        end
    end
end)


RegisterServerEvent('pubg:killerid')
AddEventHandler('pubg:killerid', function(id)
   TriggerClientEvent('pubg:addkillclient', id)
   local playerIdentifier = GetPlayerIdentifier(id)
   MySQL.update('UPDATE pubg_stats SET kills = kills + 1 WHERE identifier = ?', {playerIdentifier}, function()
   end)
end)


RegisterServerEvent('pubg:addloot')
AddEventHandler('pubg:addloot', function(name, amount, ammoname, ammoamount)
    local Player  = QBCore.Functions.GetPlayer(source)
    Player.Functions.AddItem(name, amount)
    if ammoname ~= nil then 
        Player.Functions.AddItem(ammoname, ammoamount)
    end
end)



function StartPubg()
    for i, PlayersId in pairs(PlayerIds) do
            TriggerClientEvent('StartPubg', PlayersId)
            SetPlayerRoutingBucket(PlayersId, 8)
            SetRoutingBucketPopulationEnabled(8, false)
            SetRoutingBucketEntityLockdownMode(8, 'inactive')
    end

    for k,v in pairs(Config.RandomVehicleCoords) do 
        car = CreateVehicleServerSetter(GetHashKey('squaddie'), 'automobile', v.x, v.y, v.z, 80.0)
        SetEntityRoutingBucket(car, 8)
        SetVehicleDoorsLocked(car, 1)
        table.insert(vehicles, car)
    end
end

Citizen.CreateThread(function()
    while true do 
        Citizen.Wait(128000)
        if PubgStarted then 
            if #PlayerIds <= 1 then
                for i, PlayersId in pairs(PlayerIds) do
                    TriggerClientEvent('pubg:gameend', PlayersId)
                    if Config.CheckInventory then 
                        exports.ox_inventory:ClearInventory(PlayersId)
                    end
                    if Config.WinPayment then 
                        local Player  = QBCore.Functions.GetPlayer(PlayersId)
                        Player.Functions.AddMoney('cash', Config.Payamount)
                    end
                    SetPlayerRoutingBucket(PlayersId, 0)
                    local playerIdentifier = GetPlayerIdentifier(PlayersId)
                    local name = GetPlayerName(PlayersId)
                    MySQL.query('SELECT * FROM pubg_stats WHERE identifier = ?', {playerIdentifier}, function(result)
                        if json.encode(result) ~= '[]' then
                            MySQL.update('UPDATE pubg_stats SET wins = wins + 1 WHERE identifier = ?', {playerIdentifier}, function()
                            end)
                        else
                            MySQL.insert('INSERT INTO pubg_stats (identifier, name, wins) VALUES (?, ?, 1)', {playerIdentifier, name}, function()
                            end)
                        end
                    end)
                end
                PubgStarted = false
                PlayerIds = {}
                for k,v in pairs(vehicles) do
                    if DoesEntityExist(v) then
                        print('deleted')
                        DeleteEntity(v)
                    end
                end
            end
        end
    end
end)


AddEventHandler('playerDropped', function(reason)
    for i, value in ipairs(PlayerIds) do
        if value == source then
            if Config.CheckInventory then 
                exports.ox_inventory:ClearInventory(i)
            end
            table.remove(PlayerIds, i)
        end
    end
end)


Citizen.CreateThread(function()
    while true do 
        Citizen.Wait(2000)
        for i, PlayersId in pairs(PlayerIds) do
            TriggerClientEvent('pubg:playercount', PlayersId, #PlayerIds)
        end
    end
end)




