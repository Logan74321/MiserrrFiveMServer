local InGame = false
local ZoneCoords = {x = -2102.951, y = 3088.354, z = 20.083972}
local radius = 480.0
local modelids = {}
local randomitem
local kills = 0
local playersingame = 0
local canAddKill = true
local cam = nil
local hungergameslobby = false
local coordsbefore = nil
local Data
local spawnedObjects = 0
local redbull = 0



local QBCore = exports['qb-core']:GetCoreObject()

local randomloots = {
    {name = 'weapon_carbinerifle', label = 'M4A4', amount = 1, ammoname = 'rifle_ammo', ammoamount = 2, prop = 'w_ar_carbinerifle_luxe'},
    {name = 'armor', label = 'ARMOR',  amount = 1, ammoname = nil, ammoamount = 0, prop = 'prop_ballistic_shield'},
    {name = 'redbull', label = 'REDBULL',  amount = 1, ammoname = nil, ammoamount = 0, prop = 'prop_ecola_can'},
    {name = 'redbull', label = 'REDBULL',  amount = 1, ammoname = nil, ammoamount = 0, prop = 'prop_ecola_can'},
    {name = 'redbull', label = 'REDBULL',  amount = 1, ammoname = nil, ammoamount = 0, prop = 'prop_ecola_can'},
    {name = 'weapon_pistol', label = 'PISTOL',  amount = 1, ammoname = 'pistol_ammo', ammoamount = 1, prop = 'w_pi_pistol'},
    {name = 'weapon_knife', label = 'KNIFE',  amount = 1, ammoname = nil, ammouamount = 0, prop = 'w_me_knife_01'},
    {name = 'weapon_microsmg', label = 'SMG',  amount = 1, ammoname = 'smg_ammo', ammouamount = 1, prop = 'w_sb_microsmg'},
    {name = 'pistol_ammo', label = '9MM',  amount = 1, ammoname = nil, ammouamount = 0, prop = 'w_pi_revolvermk2_mag1'},
    {name = 'smg_ammo', label = '9MM',  amount = 1, ammoname = nil, ammouamount = 0, prop = 'w_pi_revolvermk2_mag1'},
}


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



RegisterCommand('pubg', function()
    if Config.OnlyCoords.Enabled then 
        if GetDistanceBetweenCoords(GetEntityCoords(GetPlayerPed(-1)), Config.OnlyCoords.Coords.x, Config.OnlyCoords.Coords.y, Config.OnlyCoords.Coords.z) < Config.OnlyCoords.Distance then 
            if not InGame then
                QBCore.Functions.TriggerCallback('pubg:getdatawins', function(data)  
                
                    if Config.CheckInventory then 
                        if json.encode(exports.ox_inventory:GetPlayerItems()) ~= '[]' then 
                            ShowSubtitle(Config.Language.ClearInventory, 4800)
                        else
                            coordsbefore = GetEntityCoords(GetPlayerPed(-1))
                            SendNUIMessage({
                                type = 'lobbyscreen',
                                wins = data
                            })
                            StartFreeCam(68)
                            hungergameslobby = true
                            SetNuiFocus(true,true)
                            NetworkStartSoloTutorialSession()
                        end 
                    else
                        coordsbefore = GetEntityCoords(GetPlayerPed(-1))
                        SendNUIMessage({
                            type = 'lobbyscreen',
                            wins = data
                        })
                        StartFreeCam(68)
                        hungergameslobby = true
                        SetNuiFocus(true,true)
                        NetworkStartSoloTutorialSession()
                    end
                end)
            end
        else
            ShowSubtitle('Cant use it here!', 2800)
        end
    else
        if not InGame then
            QBCore.Functions.TriggerCallback('pubg:getdatawins', function(data)  
                if Config.CheckInventory then 
                    if json.encode(exports.ox_inventory:GetPlayerItems()) ~= '[]' then 
                        ShowSubtitle(Config.Language.ClearInventory, 4800)
                    else
                        coordsbefore = GetEntityCoords(GetPlayerPed(-1))
                        SendNUIMessage({
                            type = 'lobbyscreen',
                            wins = data
                        })
                        StartFreeCam(68)
                        hungergameslobby = true
                        SetNuiFocus(true,true)
                        NetworkStartSoloTutorialSession()
                    end 
                else
                    coordsbefore = GetEntityCoords(GetPlayerPed(-1))
                    SendNUIMessage({
                        type = 'lobbyscreen',
                        wins = data
                    })
                    StartFreeCam(68)
                    hungergameslobby = true
                    SetNuiFocus(true,true)
                    NetworkStartSoloTutorialSession()
                end
            end)
        end
    end
end, false)

RegisterNUICallback('dataleaderboard', function(data,cb)
    local topid = 0
    QBCore.Functions.TriggerCallback('pubg:getdatatoplist', function(data)  
        for k,v in pairs(data) do 
            topid = topid + 1
            SendNUIMessage({
                type = 'topdata',
                identifier = v.identifier,
                name = v.name,
                wins = v.wins,
                Topid = topid
            })
        end
    end)
end)

RegisterNUICallback('datacareer', function(data,cb)
    QBCore.Functions.TriggerCallback('pubg:getdatacareer', function(data)  
        for k,v in pairs(data) do 
            SendNUIMessage({
                type = 'datacareer',
                wins = v.wins,
                matchesplayed = v.games,
                kills = v.kills
            })
        end
    end)
end)



RegisterNUICallback("leavelobby", function(data,cb)
    SetNuiFocus(false,false)
    DestroyCam(cam, false)
    ClearFocus()
    RenderScriptCams(false, false, 0, true, false)
    SetTimecycleModifier(0)
    NetworkEndTutorialSession()
    hungergameslobby = false
    SetEntityCoords(GetPlayerPed(-1), coordsbefore)
    TriggerServerEvent('pubg:deleteid')
    ShowSubtitle(Config.Language.LobbyLeft, 2800)
end)

RegisterNUICallback("joingame", function(data,cb)
    if Config.CheckInventory then 
        if json.encode(exports.ox_inventory:GetPlayerItems()) ~= '[]' then 
            ShowSubtitle(Config.Language.ClearInventory, 4800)
        else
            TriggerServerEvent('pubg:join')
        end
    else
        TriggerServerEvent('pubg:join')
    end
end)


Citizen.CreateThread(function()
    while true do 
        Citizen.Wait(0)
            if DoesCamExist(cam) then
                SetUseHiDof()
            end
        if hungergameslobby then 
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 32, true)
            DisableControlAction(0, 33, true)
        else
            Citizen.Wait(480)
        end
    end
end)

function StartFreeCam(fov)
    SetEntityCoords(GetPlayerPed(-1), 152.539, -736.085, 254.0285 - 1)
    FreezeEntityPosition(GetPlayerPed(-1), true)
    SetEntityHeading(GetPlayerPed(-1), 157.48512268066)
    SetTimecycleModifier(0)  
    cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", 149.7498, -745.1551, 254.1521 + 0.08, 0, 90, 0, fov * 0.38)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 0, true, true)
    PointCamAtEntity(cam, GetPlayerPed(-1), 0, 0, 0, true)
    SetCamUseShallowDofMode(cam, true)

    -- This sets at what distance your camera should start to focus (Example: 0.7 meters)
    SetCamNearDof(cam, 0.7)

    -- This sets at what distance your camera should stop focusing (Example: 1.3 meters)
    SetCamFarDof(cam, 6.8)

    -- Tell the camera to 100% follow our DOF instructions
    SetCamDofStrength(cam, 0.28)

    SetCamAffectsAiming(cam, false)
    ShakeCam(cam, "FAMILY5_DRUG_TRIP_SHAKE", 0.02)
    ClearFocus()
    Citizen.Wait(800)
    FreezeEntityPosition(GetPlayerPed(-1), false)
end

function ShowSubtitle(message, duration)
    BeginTextCommandPrint('STRING')
    AddTextComponentString(message)
    EndTextCommandPrint(duration, true)
end

RegisterNetEvent('joinedHungerGames')
AddEventHandler('joinedHungerGames', function(info, playercount, maxplayers)
    if info == 'joined' then 
        ShowSubtitle(Config.Language.Joined, 4800) 
    elseif info == 'notjoined' then
        ShowSubtitle(Config.Language.LobbyFull, 4800) 
    elseif info == 'already' then
        ShowSubtitle(Config.Language.AlreadyJoined, 4800) 
    elseif info == 'started' then
        ShowSubtitle(Config.Language.InProgress, 4800) 
    end
end)







RegisterNetEvent('StartPubg')
AddEventHandler('StartPubg', function(position)
    SetNuiFocus(false,false)
    DestroyCam(cam, false)
    spawnedObjects = 0
    ClearFocus()
    RenderScriptCams(false, false, 0, true, false)
    SetTimecycleModifier(0)
    NetworkEndTutorialSession()
    hungergameslobby = false
    if Config.CheckInventory then 
        if json.encode(exports.ox_inventory:GetPlayerItems()) ~= '[]' then 
            ShowSubtitle(Config.Language.Gamenotinvclear, 4800)
            TriggerServerEvent('pubg:deleteid')
        else
            TriggerServerEvent('pubg:matchplayed')
            NetworkEndTutorialSession()
            SendNUIMessage({
                type = 'text',
                text = Config.Language.Started
            })
            SendNUIMessage({
                type = 'ui'
            })
            InGame = true
            radius = 480.0
            modelHash = GetHashKey('titan')
            pedHash = GetHashKey('mp_s_m_armoured_01')
            
            RequestModel(modelHash)
            RequestModel(pedHash)
            while not HasModelLoaded(modelHash) or not HasModelLoaded(pedHash) do Wait(1) end
            veh = CreateVehicle(modelHash, -1768.862, 3403.86, 380.845, 146.34014892578, false, false)
            SetVehicleFuelLevel(veh, 80.0)
            while not DoesEntityExist(veh) do Wait(1) end
            SetVehicleOnGroundProperly(veh)
            SetVehicleEngineOn(veh, true, true, true)
            SetEntityProofs(veh, true, true, true, true, true, true, true, false)
            print('1')
            
            ped = CreatePedInsideVehicle(veh, 6, pedHash, -1, false, false)
            SetPedIntoVehicle(GetPlayerPed(-1), veh, 1)
            GiveWeaponToPed(GetPlayerPed(-1), GetHashKey('gadget_parachute'), 1, false, true)
            while not DoesEntityExist(ped) do Wait(1) end
            SetBlockingOfNonTemporaryEvents(ped, true)
            TaskPlaneMission(ped, veh, 0, 0, -2548.654, 1672.006, 311.7999, 4, 100.0, 100.0, 149.72506713867, 2000.0, 400.0)
            
            RequestModel(2433343420)
            while not HasModelLoaded(2433343420) do 
                Citizen.Wait(0)
            end
            SpawnPumpkinPlants()
        end
    else
        NetworkEndTutorialSession()
        TriggerServerEvent('pubg:matchplayed')
        SendNUIMessage({
            type = 'text',
            text = Config.Language.Started
        })
        SendNUIMessage({
            type = 'ui'
        })
        InGame = true
            modelHash = GetHashKey('titan')
            pedHash = GetHashKey('mp_s_m_armoured_01')
            
            RequestModel(modelHash)
            RequestModel(pedHash)
            while not HasModelLoaded(modelHash) or not HasModelLoaded(pedHash) do Wait(1) end
            veh = CreateVehicle(modelHash, -1768.862, 3403.86, 380.845, 146.34014892578, false, false)
            
            SetVehicleFuelLevel(veh, 80.0)
            while not DoesEntityExist(veh) do Wait(1) end
            SetVehicleOnGroundProperly(veh)
            SetVehicleEngineOn(veh, true, true, true)
            SetEntityProofs(veh, true, true, true, true, true, true, true, false)
            
            ped = CreatePedInsideVehicle(veh, 6, pedHash, -1, false, false)
            SetPedIntoVehicle(GetPlayerPed(-1), veh, 1)
            GiveWeaponToPed(GetPlayerPed(-1), GetHashKey('gadget_parachute'), 1, false, true)
            while not DoesEntityExist(ped) do Wait(1) end
            SetBlockingOfNonTemporaryEvents(ped, true)
            TaskPlaneMission(ped, veh, 0, 0, -2548.654, 1672.006, 311.7999, 4, 100.0, 100.0, 149.72506713867, 2000.0, 400.0)
            radius = 480.0
            print('2')
        RequestModel(2433343420)
        while not HasModelLoaded(2433343420) do 
            Citizen.Wait(0)
        end
        SpawnPumpkinPlants()
    end
end)

RegisterNetEvent('pubg:notifications')
AddEventHandler('pubg:notifications', function(message)
    ShowSubtitle(message, 4800) 
end)


RegisterNetEvent('pubg:gameend')
AddEventHandler('pubg:gameend', function()
    RequestNamedPtfxAsset("proj_xmas_firework")
    while not HasNamedPtfxAssetLoaded("proj_xmas_firework") do
        Citizen.Wait(8)
    end
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.00)
    local particleEffects = {}
    local smoke4
    for k,v in pairs(modelids) do
        DeleteObject(v)
    end

    ShowSubtitle(Config.Language.GameEnded, 4800)
    SendNUIMessage({
        type = 'text',
        text = Config.Language.Victory
    })
    InGame = false
    for x= 0, 28 do 
        coords = GetEntityCoords(GetPlayerPed(-1))
        SetPtfxAssetNextCall("proj_xmas_firework")
        local smoke4 = StartParticleFxLoopedAtCoord("scr_firework_xmas_spiral_burst_rgw", coords.x, coords.y, coords.z + 20  , 0.0, 0.0, 0.0, 4.8, false, false, false, false)
        Citizen.Wait(480)
    end
    Citizen.Wait(4000)
    SendNUIMessage({
        type = 'uihide',
    })
    StopParticleFxLooped(smoke4, 0)
    SetEntityCoords(GetPlayerPed(-1), coordsbefore.x, coordsbefore.y, coordsbefore.z)
end)


RegisterNetEvent('pubg:removed')
AddEventHandler('pubg:removed', function()
    if InGame then 
        SendNUIMessage({
            type = 'text',
            text = Config.Language.Eliminated
        })
        Citizen.Wait(4800)
        SendNUIMessage({
            type = 'uihide',
        })
        InGame = false
        SetEntityCoords(GetPlayerPed(-1), coordsbefore.x, coordsbefore.y, coordsbefore.z)
        for k,v in pairs(modelids) do
            DeleteObject(v)
        end
        Citizen.Wait(800)
        if Config.RevivePlayerAfterDeath then 
            TriggerServerEvent('esx_ambulancejob:revive', GetPlayerServerId(PlayerId()))  -- YOUR EVENT TO REVIVE A PLAYER
        end
    else
        Citizen.Wait(400)
    end
end)

Citizen.CreateThread(function()
    while true do 
        Citizen.Wait(0)
        if InGame then 
            DrawMarker(28, ZoneCoords.x, ZoneCoords.y, ZoneCoords.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, radius, radius, radius, 0, 0, 255, 100, false, true, 2, false, false, false, false)
        else
            Citizen.Wait(800)
        end
    end
end)

local adred = false

Citizen.CreateThread(function()
    local sleep = 800
    while true do 
        Citizen.Wait(sleep)
        if InGame then 
            for k,v in pairs(modelids) do 
                coordsobject = GetEntityCoords(v)
                if GetDistanceBetweenCoords(GetEntityCoords(GetPlayerPed(-1)), GetEntityCoords(v)) < 12 then
                    SetEntityDrawOutline(v, true)
                    SetEntityDrawOutlineColor(255,255,255,188)
                    SetEntityDrawOutlineShader(1)
                else
                   SetEntityDrawOutline(v, false)
                end
                if GetDistanceBetweenCoords(GetEntityCoords(GetPlayerPed(-1)), GetEntityCoords(v)) < 2 then 
                    sleep = 0
                    local hash = GetEntityModel(v)

                    for k,c in pairs(randomloots) do 
                        if hash == GetHashKey(c.prop) then
                            Draw3DText(coordsobject.x, coordsobject.y, coordsobject.z - 0.08, Config.Language.Open .. c.label)
                        end
                    end       
                    
                    if IsControlJustPressed(0,38) then 
                        for k,c in pairs(randomloots) do 
                            if hash == GetHashKey(c.prop) then
                                if Config.LootSound then 
                                    SendNUIMessage({
                                        type = 'loot'
                                    })
                                end
                                ShowSubtitle('~o~+1~w~ ' .. c.label, 1480)
                                if c.name ~= 'redbull' then 
                                    TriggerServerEvent('pubg:addloot', c.name, c.amount, c.ammoname, c.ammoamount)
                                else
                                    adred = true                                
                                end                     
                                DeleteObject(v)
                            end
                        end       
                    end
                    break 
                else
                    sleep = 800
                end
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do 
        Citizen.Wait(80)
        if InGame then 
            if radius >= 0.4 then 
                radius = radius - 0.1     
            end
        end
    end
end)


Citizen.CreateThread(function()
    while true do 
        Citizen.Wait(1000)
        if InGame then 

            if adred then
                if redbull <= 100 then
                    redbull = redbull + 20
                    if redbull > 100 then 
                        redbull = 100
                    end 
                end
                adred = false
            end


            if redbull >= 1 then 
                SendNUIMessage({
                    type = 'redbull',
                    Redbull = redbull  
                })
                redbull = redbull - 1
            end


            if redbull > 0 then
                SetRunSprintMultiplierForPlayer(PlayerId(), 1.12)
            else
                SetRunSprintMultiplierForPlayer(PlayerId(), 1.00)
            end

            if redbull > 49 then 
                if GetEntityHealth(GetPlayerPed(-1)) < GetEntityMaxHealth(GetPlayerPed(-1)) then 
                    SetEntityHealth(GetPlayerPed(-1), GetEntityHealth(GetPlayerPed(-1)) + 4)
                end
            end
        end
    end
end)
 
 



Citizen.CreateThread(function()
    while true do 
        Citizen.Wait(1000)
        if InGame then 
            if GetDistanceBetweenCoords(GetEntityCoords(GetPlayerPed(-1)), ZoneCoords.x, ZoneCoords.y, ZoneCoords.z) >= radius then 
                SetEntityHealth(GetPlayerPed(-1), GetEntityHealth(GetPlayerPed(-1)) - 20)
            end
            if IsEntityDead(GetPlayerPed(-1)) then
                local entity = GetPedSourceOfDeath(PlayerPedId())
                if entity ~= 0 and canAddKill then 
                    local id = GetPlayerServerId(NetworkGetEntityOwner(entity))
                    TriggerServerEvent('pubg:killerid', id)
                    canAddKill = false
                end
                TriggerServerEvent('pubg:deleteid')

                if Config.RevivePlayerAfterDeath then 
                    Citizen.Wait(8800)
                   TriggerEvent('hospital:client:Revive', GetPlayerServerId(PlayerId()))
                end
                Citizen.Wait(4800)
            else
                canAddKill = true
            end
        end
    end
end)


RegisterCommand('leavepubg', function()
    if InGame then 
        SetRunSprintMultiplierForPlayer(PlayerId(), 1.00)
        TriggerServerEvent('pubg:deleteid')
        InGame = false
        SendNUIMessage({
            type = 'uihide',
        })
        SetEntityCoords(GetPlayerPed(-1), coordsbefore.x, coordsbefore.y, coordsbefore.z)
        for k,v in pairs(modelids) do
            DeleteObject(v)
        end
    end
end, false)

RegisterNetEvent('pubg:addkillclient')
AddEventHandler('pubg:addkillclient', function()
    kills = kills + 1
    if InGame then 
        SendNUIMessage({
            type = 'ui',
            Kills = kills
        })
    end
end)

RegisterNetEvent('pubg:playercount')
AddEventHandler('pubg:playercount', function(players)
    playersingame = players 
    if InGame then 
        SendNUIMessage({
            type = 'ui',
            Playersingame = playersingame
        })
    end
end)






function SpawnPumpkinPlants()
	while spawnedObjects < 600 do
		Citizen.Wait(0)
        local randomItemIndex = math.random(1, #randomloots) -- Generate a random index for randomloots
        local randomItem = randomloots[randomItemIndex] -- Retrieve the random item
        RequestModel(GetHashKey(randomItem.prop))
        while not HasModelLoaded(GetHashKey(randomItem.prop)) do
            Citizen.Wait(15)
        end
    
		local pumpkinCoords = GenerateCoords()
        pumpkinObjectt = CreateObject(GetHashKey(randomItem.prop), pumpkinCoords.x, pumpkinCoords.y, pumpkinCoords.z + 0.48, false, true, true)
        
        FreezeEntityPosition(pumpkinObjectt, true)
        table.insert(modelids, pumpkinObjectt)
        spawnedObjects = spawnedObjects + 1

        randomItemIndex = math.random(1, #randomloots) -- Generate a random index for randomloots
        randomItem = randomloots[randomItemIndex] -- Retrieve the random item
        RequestModel(GetHashKey(randomItem.prop))
        while not HasModelLoaded(GetHashKey(randomItem.prop)) do
            Citizen.Wait(15)
        end
    
        pumpkinObjectt2 = CreateObject(GetHashKey(randomItem.prop), pumpkinCoords.x + 0.48, pumpkinCoords.y, pumpkinCoords.z + 0.48, false, true, true)
        FreezeEntityPosition(pumpkinObjectt2, true)
        table.insert(modelids, pumpkinObjectt2)
        spawnedObjects = spawnedObjects + 1
	end
end


function IsCoordvalid(plantCoord)
	if spawnedObjects > 0 then
		local validate = true

		for k, v in pairs(modelids) do
			if GetDistanceBetweenCoords(plantCoord, GetEntityCoords(v), true) < 10 then
				validate = false
			end
		end

		if GetDistanceBetweenCoords(plantCoord, vector3(-2102.951, 3088.354, 45.0933), false) > 500 then
			validate = false
		end

		return validate
	else
		return true
	end
end

function GenerateCoords()
	while true do
		Citizen.Wait(0)
            local pumpkinCoordX, pumpkinCoordY

            math.randomseed(GetGameTimer())
            local modX = math.random(-480, 480)
    
            Citizen.Wait(8)
    
            math.randomseed(GetGameTimer())
            local modY = math.random(-480, 480)

            pumpkinCoordX = -2108.093 + modX
            pumpkinCoordY = 3088.129 + modY

            local coordZ = GetCoordZ(pumpkinCoordX, pumpkinCoordY)
            local coord = vector3(pumpkinCoordX, pumpkinCoordY, coordZ)

            if IsCoordvalid(coord) then
                return coord
            end
	end
end

function GetCoordZ(x, y)
	local groundCheckHeights = {28.0, 29.0, 30.0, 31.0, 32.0, 32.894, 33.0, 34.0, 35.0, 36.0, 37.0, 38.0, 39.0, 40.0 }


	for i, height in ipairs(groundCheckHeights) do
		local foundGround, z = GetGroundZFor_3dCoord(x, y, height)

		if foundGround then
			return z
		end
	end

	return 43.0
end






-- local prop = nil

-- local ped = nil

-- RegisterCommand('testped', function()
--     print('spawning')
--     RequestModel(0x6D1E15F7)
--     while not HasModelLoaded(0x6D1E15F7) do 
--         Citizen.Wait(15)
--     end
--     local coords = GetEntityCoords(GetPlayerPed(-1))
--     ped = CreatePed(1, 0x6D1E15F7, coords.x, coords.y, coords.z, 80.0, false, false)
--     local playerCoords = GetEntityCoords(ped)
--     SetPedArmour(GetPlayerPed(-1), 0)
--     SetEntityHealth(GetPlayerPed(-1), GetEntityMaxHealth(GetPlayerPed(-1)))
--     local propModel = GetHashKey('v_corp_sidechair')
--     RequestModel(propModel)
    
--     while not HasModelLoaded(propModel) do
--         Citizen.Wait(0)
--     end

--     prop = CreateObject(propModel, playerCoords.x, playerCoords.y, playerCoords.z, true, true, true)
--     SetEntityCollision(prop, true)
--     SetEntityVisible(ped, false)
--     SetEntityAlpha(ped, 0, false)
    
--     -- Attach the player to the prop
--     local boneIndex = GetPedBoneIndex(ped, 0) 
--     local xOffset, yOffset, zOffset = 0.0, 0.0, -1.0 
--     local xRotation, yRotation, zRotation = 0.0, 0.0, 0.0 
--     local p7, p8, p9 = 0, 0, 0
--     local p10 = 1

--     AttachEntityToEntity(prop, ped, boneIndex, xOffset, yOffset, zOffset, xRotation, yRotation, zRotation, p7, p8, p9, p10, 1, 1, 0)
    
-- end, false)






-- RegisterCommand('testprop', function()

--     local ped = GetPlayerPed(-1)
--     local playerCoords = GetEntityCoords(ped)
--     SetPedArmour(GetPlayerPed(-1), 0)
--     SetEntityHealth(GetPlayerPed(-1), GetEntityMaxHealth(GetPlayerPed(-1)))
--     local propModel = GetHashKey('prop_hotdogstand_01')
--     RequestModel(propModel)
    
--     while not HasModelLoaded(propModel) do
--         Citizen.Wait(0)
--     end

--     prop = CreateObject(propModel, playerCoords.x, playerCoords.y, playerCoords.z, true, true, true)
--     SetEntityCollision(prop, true)
--     SetEntityVisible(GetPlayerPed(-1), false)
--     SetEntityAlpha(GetPlayerPed(-1), 0, false)
    
--     -- Attach the player to the prop
--     local boneIndex = GetPedBoneIndex(ped, 0) 
--     local xOffset, yOffset, zOffset = 0.0, 0.0, -1.0 
--     local xRotation, yRotation, zRotation = 0.0, 0.0, 0.0 
--     local p7, p8, p9 = 0, 0, 0
--     local p10 = 1

--     AttachEntityToEntity(prop, ped, boneIndex, xOffset, yOffset, zOffset, xRotation, yRotation, zRotation, p7, p8, p9, p10, 1, 1, 0)
    
-- end, false)

-- RegisterCommand('clear', function()
--     DeleteObject(prop)
--     SetEntityVisible(GetPlayerPed(-1), true)
--     SetEntityAlpha(GetPlayerPed(-1), 255, false)
-- end, false)

-- Citizen.CreateThread(function()
--     while true do 
--         Citizen.Wait(0)
--         local ped = GetPlayerPed(-1)
--         local playerCoords = GetEntityCoords(ped)
--         if stealth then 
--             SetEntityCoordsNoOffset(PlayerPedId(), playerCoords.x, playerCoords.y, playerCoords.z, 0, 0, 0)
--         else
--             Draw3DText(playerCoords.x, playerCoords.y, playerCoords.z, '[E] - Stealth')
--         end
--         if IsControlJustPressed(0, 38) then 
--             if stealth then 
--                 stealth = false 
--             else
--                 stealth = true 
--             end
--         end
--     end
-- end)