Config = {}


Config.OnlyCoords = { -- WHERE THE PLAYER CAN USE THE COMMAND ( /pubg )
    Enabled = false, 
    Coords = vector3(132.306, -1309.271, 28.99515),
    Distance = 200 
}

Config.LootLocations = { -- ADD AS MANY LOOT LOCATIONS AS YOU WANT
    vector3(990.2447, -2981.834, 5.90047),
    vector3(864.7849, -2973.79, 7.475422),
    vector3(892.7546, -3035.43, 5.896654),
    vector3(892.7546, -3035.43, 5.896654),
    vector3(937.4085, -3184.44, 5.897563),
    vector3(1029.746, -3200.033, 5.90077),
    vector3(1118.763, -3193.878, 5.907419),
    vector3(1152.195, -3140.462, 5.891243),
    vector3(1165.124, -3167.062, 5.800608),
    vector3(924.7084, -3208.962, 5.895463),
    vector3(867.8343, -3291.567, 5.881361),
    vector3(1047.119, -3320.853, 5.909547),
    vector3(1086.142, -3256.718, 5.896869),
    vector3(1224.23, -3229.373, 5.917488),
    vector3(885.2202, -3054.198, 5.90716),
    vector3(819.0925, -3114.532, 5.899883),
    vector3(849.7806, -3219.741, 5.892829),
    vector3(829.382, -3288.629, 5.900026),
}

Config.RandomVehicleCoords = {
    vector3(-1945.152, 2954.761, 32.80994),
    vector3(-2239.648, 3163.924, 32.81008),
}

Config.MinPlayers = 2 -- MIN PLAYERS REQUIRED TO START THE HUNGERGAMES

Config.MaxPlayers = 48 -- MAX PLAYERS THAT CAN JOIN!

Config.WinPayment = true
Config.Payamount = 2800

Config.LootSound = true -- SOUND WHEN PICKING UP ITEMS ( YOU CAN ADD YOUR OWN SOUND JUST REPLACE THE LOOT.MP3 FILE IN THE HTML FOLDER ( NAME YOUR SOUND TO LOOT.MP3 ))

Config.Language = {
    StartingSoon = 'Battle Royale starting soon!',
    GameEnded = 'The game has ended, YOU HAVE WON!',
    Joined = 'Successfuly Joined! ',
    LobbyFull = 'Lobby FULL!',
    AlreadyJoined = 'Already Joined!',
    InProgress = 'Game in progress!',
    ClearInventory = 'Clear your INVENTORY FIRST!',
    Eliminated = 'Eliminated',
    Victory = 'Victory',
    Started = 'Match Started',
    Gamenotinvclear = 'Your inventory was not clear!',
    Open = '[E] - ',
    LobbyLeft = 'You have left the lobby!',
}

Config.CheckInventory = false -- OX INVENTORY NEEDED FOR THIS TO WORK!!!! OR EDIT IN THE CLIENT.LUA FILE TO YOUR INVENTORY CHECK

Config.RevivePlayerAfterDeath = true -- REVIVE THE PLAYER AFTER DEATH, IF YOU HAVE DIFFERENT AMBULANCE JOB PLEASE EDIT IT IN THE CLIENT.LUA FILE!
