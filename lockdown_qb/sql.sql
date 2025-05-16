-- lockdown_qb/sql.sql
-- Database structure for Lockdown Protocol (QBCore Compatible)

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
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `lockdown_gangs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) DEFAULT NULL,
  `color` varchar(7) DEFAULT '#FFFFFF',
  `emblem` int(11) DEFAULT 0,
  `created_by` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

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
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `lockdown_contracts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `reward_xp` int(11) DEFAULT 0,
  `reward_cash` int(11) DEFAULT 0,
  `min_tier` int(11) DEFAULT 1,
  `is_active` tinyint(1) DEFAULT 1,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Insert default contracts if table is empty
INSERT INTO `lockdown_contracts` (`name`, `description`, `reward_xp`, `reward_cash`, `min_tier`, `is_active`)
SELECT 'Plant Evidence', 'Plant evidence on a police vehicle', 500, 1500, 1, 1
WHERE NOT EXISTS (SELECT 1 FROM `lockdown_contracts` LIMIT 1);

INSERT INTO `lockdown_contracts` (`name`, `description`, `reward_xp`, `reward_cash`, `min_tier`, `is_active`)
SELECT 'Eliminate Target', 'Eliminate a specific target in the zone', 1000, 3000, 2, 1
WHERE (SELECT COUNT(*) FROM `lockdown_contracts`) < 2;

INSERT INTO `lockdown_contracts` (`name`, `description`, `reward_xp`, `reward_cash`, `min_tier`, `is_active`)
SELECT 'Collect Intel', 'Collect 3 intel drives and extract', 1500, 5000, 3, 1
WHERE (SELECT COUNT(*) FROM `lockdown_contracts`) < 3;