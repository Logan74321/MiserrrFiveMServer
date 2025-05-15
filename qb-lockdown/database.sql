-- database.sql

-- Lockdown stats table
CREATE TABLE IF NOT EXISTS `lockdown_stats` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `extractions` int(11) NOT NULL DEFAULT 0,
  `deaths` int(11) NOT NULL DEFAULT 0,
  `kills` int(11) NOT NULL DEFAULT 0,
  `total_value` int(11) NOT NULL DEFAULT 0,
  `highest_streak` int(11) NOT NULL DEFAULT 0,
  `contracts_completed` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Lockdown gangs table
CREATE TABLE IF NOT EXISTS `lockdown_gangs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `color` varchar(10) NOT NULL DEFAULT '#FF0000',
  `emblem` varchar(50) NOT NULL DEFAULT 'skull',
  `leader` varchar(50) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Gang members table
CREATE TABLE IF NOT EXISTS `lockdown_gang_members` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gang_id` int(11) NOT NULL,
  `citizenid` varchar(50) NOT NULL,
  `rank` int(11) NOT NULL DEFAULT 1,
  `joined_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `citizenid` (`citizenid`),
  KEY `gang_id` (`gang_id`),
  CONSTRAINT `gang_members_ibfk_1` FOREIGN KEY (`gang_id`) REFERENCES `lockdown_gangs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Contracts table
CREATE TABLE IF NOT EXISTS `lockdown_contracts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(100) NOT NULL,
  `description` text NOT NULL,
  `reward` int(11) NOT NULL DEFAULT 0,
  `xp` int(11) NOT NULL DEFAULT 0,
  `type` varchar(50) NOT NULL DEFAULT 'elimination',
  `difficulty` int(11) NOT NULL DEFAULT 1,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Insert some default contracts
INSERT INTO `lockdown_contracts` (`title`, `description`, `reward`, `xp`, `type`, `difficulty`) VALUES
('LCPD Van Sabotage', 'Plant a bomb on the LCPD van parked near the canal', 10000, 500, 'sabotage', 2),
('Gang Leader Elimination', 'Eliminate the rival gang leader hiding in Firefly Projects', 15000, 750, 'elimination', 3),
('Intel Collection', 'Collect 3 USB drives scattered around the district', 8000, 400, 'collection', 1),
('Drug Shipment Seizure', 'Find and secure the unguarded drug shipment', 12000, 600, 'collection', 2),
('Vehicle Theft', 'Steal the armored car and deliver it to the extraction point', 20000, 1000, 'theft', 3);