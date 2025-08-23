Config = {}
Config.Ped = {
    model = "amsp_robsdgunsmith_males_01", 
    spawn = vector4(-798.91, -1194.55, 42.95, 181.95), 
    animation = {
        scenario = "WORLD_HUMAN_COFFEE_DRINK"
    },
    blip = {
        enabled = true, 
        sprite = -1258576797, 
        scale = 0.7, 
        text = "Town Hall" 
    }
}
Config.Language = "en" 
Config.Interact = "ox_target" 
Config.InteractDistance = 2.5 
Config.CooldownSeconds = 30 
Config.WebhookURL = "" -- If you leave this empty, Discord logging is disabled

-- NEW: General licenses available to ALL players (no job requirement)
Config.GeneralLicenses = {
    {
        item = "weapon_licence",
        label = "Weapon Permit",
        description = "Legal authorization to carry weapons",
        price = 500,
        icon = "fa-solid fa-gun"
    },
    {
        item = "hunting_licence",
        label = "Hunting License",
        description = "Permission to hunt wild animals",
        price = 250,
        icon = "fa-solid fa-crosshairs"
    },
    {
        item = "fishing_licence",
        label = "Fishing License",
        description = "License to fish in all waters",
        price = 100,
        icon = "fa-solid fa-fish"
    }
}

-- Job-Specific License Configuration (can only be issued by certain jobs)
Config.Licenses = {
    -- Lawyer licenses
    {
        item = "marriage_licence",
        label = "Marriage License",
        description = "Legal document for marriage ceremonies",
        price = 100,
        icon = "fa-solid fa-heart",
        jobRequired = "priest"
    },
    {
        item = "coach_licence",
        label = "Coach License",
        description = "Permission to operate coach vehicles",
        price = 75,
        icon = "fa-solid fa-car",
        jobRequired = "taxi"
    }
}

Config.Jobs = {
    {
        jobName = "taxi",
        icon = "fa-solid fa-taxi",
        label = "Coach Driver",
        text = "Drive around picking up locals.",
        tutorial = "head to the location on the map",
        locations = {
            {pos = vector3(-216.43, 682.21, 113.60), label = "Coach Station", txt = "Start your Coach route here"}
        }
    },
    {
        jobName = "priest",
        icon = "fa-solid fa-cross",
        label = "Priest Job",
        text = "Conduct religious services and provide guidance.",
        tutorial = "Visit the church to perform ceremonies and counsel locals."
    },
    {
        jobName = "banker",
        icon = "fa-solid fa-money-bill",
        label = "Banker Job",
        text = "Manage finances and assist customers at the bank.",
        tutorial = "Work at the bank counter, handle deposits, withdrawals, and loans."
    },
    {
        jobName = "traindriver",
        icon = "fa-solid fa-train",
        label = "Train Driver Job",
        text = "Operate trains across the city.",
        tutorial = "Get your train at the station, follow the route schedule, and ensure safe travel.",
        locations = {
            {pos = vector3(-163.58, 638.60, 114.03), label = "Train Station", txt = "Start your train route here"}
        }
    },
    {
        jobName = "wagonmechanic",
        icon = "fa-solid fa-wrench",
        label = "Wagon Mechanic Job",
        text = "Repair and maintain wagons.",
        tutorial = "Visit the wagon repair shop, fix wagons, and ensure they're ready for use."
    },
    {
        jobName = "reporter",
        icon = "fa-solid fa-microphone",
        label = "Reporter Job",
        text = "Cover news stories and report events.",
        tutorial = "Buy a newspaper, gather stories, and broadcast reports."
    },
    {
        jobName = "lawyer",
        icon = "fa-solid fa-gavel",
        label = "Lawyer",
        text = "Provide legal services and sell licenses.",
        tutorial = "Help citizens with legal matters and process license applications.",
		locations = {
            {pos = vector3(-292.30, 784.41, 119.29), label = "Law office", txt = "location of law office"}
        }
    }
}
