Config = {}

-- General Settings
Config.DebugMode = false
Config.CommandName = "lockdown" -- Admin command to trigger lockdown
Config.KeybindEnabled = false    -- Disable F10 keybind (using Enter key instead)

-- Instance Settings
Config.MinPlayers = 2           -- Minimum players to start a Lockdown instance
Config.MaxPlayers = 12          -- Maximum players per Lockdown instance
Config.RoutingBucket = 8        -- Default routing bucket for instances
Config.LockdownDuration = 25    -- Minutes between automatic Lockdown announcements
Config.JoinWindowDuration = 120  -- Seconds (2 minutes) for players to join after announcement
Config.MatchStartDelay = 10     -- Seconds delay after minimum players reached before starting
Config.ExtractionDelay = 4      -- Minutes before first extraction point activates
Config.ExtractionDuration = 45  -- Seconds that each extraction point remains active
Config.MaxExtractions = 4       -- Maximum number of extraction opportunities
Config.ExtractTime = 10         -- Seconds needed to extract

-- Zone Settings
Config.Zones = {
    {
        name = "Aspatria Strip",
        center = vector3(-2102.951, 3088.354, 20.083972), -- Will need manual adjustment
        radius = 480.0,
        difficulty = 1,
        lootDensity = 1.0
    },
    {
        name = "Industrial Broker",
        center = vector3(-2239.648, 3163.924, 32.81008), -- Will need manual adjustment
        radius = 450.0,
        difficulty = 2,
        lootDensity = 1.2
    },
    {
        name = "East Island Docks",
        center = vector3(-1945.152, 2954.761, 32.80994), -- Will need manual adjustment
        radius = 500.0,
        difficulty = 3,
        lootDensity = 1.5
    },
    {
        name = "Firefly Projects",
        center = vector3(-1768.862, 3403.86, 32.80994), -- Will need manual adjustment
        radius = 420.0,
        difficulty = 4,
        lootDensity = 1.8
    }
}

-- Entry Settings
Config.OnlyCoords = { -- WHERE THE PLAYER CAN USE THE COMMAND
    Enabled = false, 
    Coords = vector3(132.306, -1309.271, 28.99515), -- Will need manual adjustment
    Distance = 200 
}

-- Extraction Points (need manual adjustment based on Liberty City map)
Config.ExtractionPoints = {
    {
        name = "Boat Extraction",
        coords = vector3(990.2447, -2981.834, 5.90047),
        type = "boat",
        requiredItems = {} -- No items required
    },
    {
        name = "Subway Extraction",
        coords = vector3(864.7849, -2973.79, 7.475422),
        type = "subway",
        requiredItems = {} -- No items required
    },
    {
        name = "Rooftop Extraction",
        coords = vector3(892.7546, -3035.43, 5.896654),
        type = "helicopter",
        requiredItems = {
            {name = "intel_usb", label = "Intel USB", reduce_time = 3} -- Optional item to reduce extraction time
        }
    },
    {
        name = "Warehouse Extraction",
        coords = vector3(950.3672, -3000.12, 5.900873),
        type = "vehicle",
        requiredItems = {} -- No items required
    },
    {
        name = "Dock Gate Extraction",
        coords = vector3(1000.876, -2950.23, 5.896234),
        type = "fence",
        requiredItems = {} -- No items required
    }
}

-- Loot Settings
Config.LootTypes = {
    {
        name = "cash_bag",
        label = "Cash Bag",
        prop = "prop_money_bag_01",
        value = {min = 1000, max = 5000},
        weight = 2,
        rarity = 0.4
    },
    {
        name = "drug_brick",
        label = "Drug Brick",
        prop = "prop_drug_package",
        value = {min = 4000, max = 8000},
        weight = 3,
        rarity = 0.2
    },
    {
        name = "weapon_cache",
        label = "Weapon Cache",
        prop = "prop_gun_case_01",
        value = {min = 2000, max = 6000},
        items = {"weapon_pistol", "weapon_smg"}, -- Random selection
        ammo = {name = "ammo-9", amount = {min = 1, max = 3}},
        rarity = 0.15
    },
    {
        name = "intel_usb",
        label = "Intel USB",
        prop = "prop_cs_usb_drive",
        value = {min = 500, max = 1500},
        weight = 1,
        special = "extract_reduction", -- Special effect - reduces extraction time
        rarity = 0.1
    },
    {
        name = "energy_drink",
        label = "Energy Drink",
        prop = "prop_ecola_can",
        value = {min = 100, max = 200},
        special = "speed_boost", -- Special effect - speed boost
        duration = 60, -- seconds
        weight = 1,
        rarity = 0.8
    }
}

-- Vehicle Spawn Points (escape or transport vehicles)
Config.VehicleSpawns = {
    {
        coords = vector3(-1945.152, 2954.761, 32.80994),
        heading = 146.34014892578,
        models = {"squaddie", "sultan", "kuruma"},
        spawnChance = 0.5
    },
    {
        coords = vector3(-2239.648, 3163.924, 32.81008),
        heading = 149.72506713867,
        models = {"squaddie", "sultan", "kuruma"},
        spawnChance = 0.5
    }
}

-- Reward Vehicles (unlocked through progression)
Config.RewardVehicles = {
    {
        name = "Albany Raider",
        model = "raiden",
        requiredTier = 2,
        requiredExtractions = 10
    },
    {
        name = "Vapid Executioner",
        model = "dominator",
        requiredTier = 3,
        requiredExtractions = 25
    },
    {
        name = "Schyster Smuggler",
        model = "schafter2",
        requiredTier = 4,
        requiredExtractions = 50
    }
}

-- Criminal Progression Tiers
Config.CriminalTiers = {
    {
        id = 1,
        name = "Runner",
        requiredExtractions = 0,
        color = "#B0B0B0" -- Silver
    },
    {
        id = 2,
        name = "Enforcer",
        requiredExtractions = 10,
        color = "#CD7F32" -- Bronze
    },
    {
        id = 3,
        name = "Shot Caller",
        requiredExtractions = 25,
        color = "#FFD700" -- Gold
    },
    {
        id = 4,
        name = "Kingpin",
        requiredExtractions = 50,
        color = "#B9F2FF" -- Diamond Blue
    }
}

-- Contract types
Config.Contracts = {
    {
        name = "Plant Evidence",
        description = "Plant evidence on a police vehicle",
        reward_xp = 500,
        reward_cash = 1500,
        min_tier = 1
    },
    {
        name = "Eliminate Target",
        description = "Eliminate a specific target in the zone",
        reward_xp = 1000,
        reward_cash = 3000,
        min_tier = 2
    },
    {
        name = "Collect Intel",
        description = "Collect 3 intel drives and extract",
        reward_xp = 1500,
        reward_cash = 5000,
        min_tier = 3
    }
}

-- Gang Settings
Config.GangSystem = {
    MaxMembers = 10,
    MaxMembersPerMatch = 3,
    Ranks = {
        {id = 1, name = "Prospect", permissions = {"join_lockdown"}},
        {id = 2, name = "Shooter", permissions = {"join_lockdown", "invite_members"}},
        {id = 3, name = "OG", permissions = {"join_lockdown", "invite_members", "manage_gang"}}
    }
}

-- Police AI Settings
Config.PoliceAI = {
    InitialWantedLevel = 2,
    WantedLevelIncrease = {
        {time = 2, level = 3}, -- After 2 minutes, increase to level 3
        {time = 6, level = 4}, -- After 6 minutes, increase to level 4
        {time = 10, level = 5} -- After 10 minutes, increase to level 5
    },
    Models = {
        "s_m_y_cop_01", 
        "s_m_y_cop_02", 
        "s_m_y_sheriff_01"
    },
    Vehicles = {
        "police", 
        "police2", 
        "police3"
    }
}

-- Spawn Points Settings
Config.SpawnPoints = {
    -- North side of zone
    {offset = {x = 0, y = 0.7}, randomize = 50},
    -- East side of zone
    {offset = {x = 0.7, y = 0}, randomize = 50},
    -- South side of zone
    {offset = {x = 0, y = -0.7}, randomize = 50},
    -- West side of zone
    {offset = {x = -0.7, y = 0}, randomize = 50},
    -- Northeast corner
    {offset = {x = 0.5, y = 0.5}, randomize = 50},
    -- Southeast corner
    {offset = {x = 0.5, y = -0.5}, randomize = 50},
    -- Southwest corner
    {offset = {x = -0.5, y = -0.5}, randomize = 50},
    -- Northwest corner
    {offset = {x = -0.5, y = 0.5}, randomize = 50},
    -- Center
    {offset = {x = 0, y = 0}, randomize = 100},
    -- Random intermediate points
    {offset = {x = 0.3, y = 0.3}, randomize = 80},
    {offset = {x = -0.3, y = 0.3}, randomize = 80},
    {offset = {x = 0.3, y = -0.3}, randomize = 80},
    {offset = {x = -0.3, y = -0.3}, randomize = 80}
}

-- Inventory & Economy
Config.CheckInventory = false -- Set to true to use ox_inventory checks
Config.LaunderingRate = 0.85 -- 85% of dirty money converted to clean money
Config.RewardExtraction = true
Config.ExtractionBonus = 1000 -- Bonus for successful extraction

-- UI & Language Settings
Config.Language = {
    MenuTitle = "LOCKDOWN PROTOCOL",
    StartingSoon = 'Lockdown Protocol initiating...',
    GameEnded = 'Extraction successful! Rewards secured.',
    Joined = 'Successfully joined Lockdown zone! ',
    ZoneFull = 'Zone at capacity!',
    AlreadyJoined = 'Already in an active Lockdown!',
    InProgress = 'Lockdown in progress!',
    ClearInventory = 'Clear your inventory first!',
    Eliminated = 'You have been eliminated',
    Victory = 'Extraction Complete',
    Started = 'Lockdown Initiated',
    GameNotInvClear = 'Your inventory was not clear!',
    Open = '[E] - ',
    LobbyLeft = 'You have left the Lockdown lobby!',
    ExtractionActive = 'Extraction points are now active!',
    ExtractionStarted = 'Extraction sequence initiated...',
    ExtractionInterrupted = 'Extraction interrupted!',
    ExtractionComplete = 'Extraction complete!'
}

-- Keep some legacy settings for compatibility
Config.LootSound = true
Config.RevivePlayerAfterDeath = true