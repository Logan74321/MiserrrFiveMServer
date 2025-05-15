CREATE TABLE IF NOT EXISTS `pubg_stats` (
  `identifier` longtext DEFAULT NULL,
  `name` varchar(50) DEFAULT NULL,
  `wins` int(11) DEFAULT NULL,
  `games` int(11) DEFAULT NULL,
  `kills` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

