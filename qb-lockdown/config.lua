Config = {}

-- General Settings
Config.MaxPlayers = 18
Config.MatchDuration = 25 -- minutes
Config.MinPlayersToStart = 2
Config.ExtractTime = 10 -- seconds to extract
Config.EnableRandomEvents = true
Config.StarterWantedLevel = 1

-- Zones (customize these coordinates for Liberty City map)
Config.Zones = {
    ["Aspatria"] = {
        label = "Aspatria Strip",
        coords = vector3(100.0, 100.0, 30.0), -- Replace with actual coordinates
        radius = 300.0,
        spawnPoints = {
            vector4(110.0, 110.0, 30.0, 0.0), -- Replace with actual spawn points
            vector4(120.0, 120.0, 30.0, 90.0),
            vector4(130.0, 130.0, 30.0, 180.0),
            -- Add more spawn points
        }
    },
    ["Broker"] = {
        label = "Industrial Broker",
        coords = vector3(200.0, 200.0, 30.0), -- Replace with actual coordinates
        radius = 300.0,
        spawnPoints = {
            vector4(210.0, 210.0, 30.0, 0.0), -- Replace with actual spawn points
            vector4(220.0, 220.0, 30.0, 90.0),
            vector4(230.0, 230.0, 30.0, 180.0),
            -- Add more spawn points
        }
    },
    ["Docks"] = {
        label = "East Island Docks",
        coords = vector3(300.0, 300.0, 30.0), -- Replace with actual coordinates
        radius = 300.0,
        spawnPoints = {
            vector4(310.0, 310.0, 30.0, 0.0), -- Replace with actual spawn points
            vector4(320.0, 320.0, 30.0, 90.0),
            vector4(330.0, 330.0, 30.0, 180.0),
            -- Add more spawn points
        }
    },
    ["Firefly"] = {
        label = "Firefly Projects",
        coords = vector3(400.0, 400.0, 30.0), -- Replace with actual coordinates
        radius = 300.0,
        spawnPoints = {
            vector4(410.0, 410.0, 30.0, 0.0), -- Replace with actual spawn points
            vector4(420.0, 420.0, 30.0, 90.0),
            vector4(430.0, 430.0, 30.0, 180.0),
            -- Add more spawn points
        }
    }
}

-- Extraction Points
Config.ExtractionPoints = {
    ["Boat"] = {
        label = "Boat Extraction",
        coords = vector3(150.0, 150.0, 30.0), -- Replace with actual coordinates
        radius = 5.0,
        vehicleModel = "dinghy", -- Boat model
        vehicleSpawn = vector4(155.0, 155.0, 28.0, 90.0), -- Replace with actual coordinates
        type = "boat"
    },
    ["Helicopter"] = {
        label = "Helicopter Extraction",
        coords = vector3(250.0, 250.0, 60.0), -- Replace with actual coordinates
        radius = 5.0,
        vehicleModel = "maverick", -- Helicopter model
        vehicleSpawn = vector4(250.0, 250.0, 60.0, 0.0), -- Replace with actual coordinates
        type = "heli"
    },
    ["Truck"] = {
        label = "Truck Extraction",
        coords = vector3(350.0, 350.0, 30.0), -- Replace with actual coordinates
        radius = 5.0,
        vehicleModel = "benson", -- Truck model
        vehicleSpawn = vector4(355.0, 355.0, 30.0, 180.0), -- Replace with actual coordinates
        type = "land"
    }
}

-- Loot Configuration
Config.LootSpots = {
    ["cashbag"] = {
        model = "prop_money_bag_01", -- Prop model
        items = {
            {name = "cash", min = 5000, max = 20000, chance = 100},
            {name = "goldbar", min = 1, max = 3, chance = 10}
        }
    },
    ["drugstash"] = {
        model = "prop_drug_package", -- Prop model
        items = {
            {name = "coke_brick", min = 1, max = 3, chance = 80},
            {name = "weed_brick", min = 2, max = 5, chance = 90}
        }
    },
    ["weaponcrate"] = {
        model = "prop_box_ammo04a", -- Prop model
        items = {
            {name = "weapon_pistol", min = 1, max = 1, chance = 70},
            {name = "weapon_smg", min = 1, max = 1, chance = 30},
            {name = "pistol_ammo", min = 10, max = 30, chance = 90}
        }
    },
    ["intel"] = {
        model = "prop_usb_drive", -- Prop model
        items = {
            {name = "usb_drive", min = 1, max = 1, chance = 100}
        }
    }
}

-- Rank System
Config.Ranks = {
    {name = "Runner", extractionsRequired = 0, color = "#FFFFFF"},
    {name = "Enforcer", extractionsRequired = 10, color = "#4682B4"},
    {name = "Shot Caller", extractionsRequired = 25, color = "#9932CC"},
    {name = "Kingpin", extractionsRequired = 50, color = "#FFD700"}
}

-- Police AI Configuration
Config.Police = {
    initialSpawns = 5, -- Number of initial police NPCs
    maxPolice = 20, -- Maximum number of police NPCs
    models = {"s_m_y_cop_01", "s_m_y_sheriff_01"}, -- Police ped models
    vehicles = {"police", "police2", "police3"}, -- Police vehicle models
    weapons = {"WEAPON_PISTOL", "WEAPON_PUMPSHOTGUN", "WEAPON_CARBINERIFLE"}, -- Police weapons
    responseTime = {
        level1 = 120, -- Time in seconds before more police spawn (2 mins)
        level2 = 360, -- Time before barricades activate (6 mins)
        level3 = 600 -- Time before roadblocks activate (10 mins)
    }
}

-- Gang System
Config.MaxGangSize = 3 -- Maximum members per gang in Lockdown