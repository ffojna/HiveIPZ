-- phpMyAdmin SQL Dump
-- version 5.2.1deb3
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Apr 15, 2025 at 12:43 PM
-- Wersja serwera: 8.0.41-0ubuntu0.24.04.1
-- Wersja PHP: 8.3.6

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `userDatabase`
--

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `comment_reports`
--

CREATE TABLE `comment_reports` (
  `id` int NOT NULL,
  `comment_id` int NOT NULL,
  `event_id` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `user_id` int NOT NULL,
  `reason` text COLLATE utf8mb4_general_ci NOT NULL,
  `reported_at` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `events`
--

CREATE TABLE `events` (
  `id` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `location` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `description` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `type` varchar(50) COLLATE utf8mb4_general_ci NOT NULL,
  `start_date` datetime NOT NULL,
  `max_participants` int NOT NULL,
  `registered_participants` int NOT NULL,
  `image` text COLLATE utf8mb4_general_ci,
  `user_id` int DEFAULT NULL,
  `cena` decimal(10,2) NOT NULL DEFAULT '0.00',
  `is_promoted` tinyint(1) DEFAULT '0',
  `comments_enabled` tinyint(1) DEFAULT NULL,
  `score` int DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `events`
--

INSERT INTO `events` (`id`, `name`, `location`, `description`, `type`, `start_date`, `max_participants`, `registered_participants`, `image`, `user_id`, `cena`, `is_promoted`, `comments_enabled`, `score`) VALUES
('1742335399867', 'After-party po Rabbicie', 'Dom Filipa, Szczecin', 'AfterParty', 'Outdoor', '2025-04-10 00:00:00', 5, 3, 'assets/placeholder.jpg', 66, 2.00, 0, 1, 0),
('1742372732146', 'RabbIT', 'Wydział Informatyki ZUT', 'Wydział Informatyki ZUT', 'Firmowe', '2025-04-09 00:00:00', -1, 5, 'assets/rabbit.jpg', 38, 0.00, 1, NULL, 2),
('1742940594689', 'Gotowanie z Oliwka', 'wi zut', 'wi zut', 'Brak typu', '2025-03-25 23:08:53', 5, 4, 'assets/placeholder.jpg', 41, 0.00, 0, 1, -1),
('1742942345928', 'Zlot na WI3', 'Kebab \"Na Wernyhory\" Turecki', 'Kebsik', 'Brak typu', '2025-03-27 00:00:00', -1, 3, 'assets/placeholder.jpg', 38, 0.00, 0, 1, 1),
('1744152579559', 'testowa ocena', 'domek', 'test', 'Brak typu', '2025-04-09 00:00:00', -1, 2, 'assets/placeholder.jpg', 38, 0.00, 0, NULL, 1),
('1744152583645', 'testowa ocena', 'domek', 'test', 'Brak typu', '2025-04-09 00:00:00', -1, 2, 'assets/placeholder.jpg', 38, 0.00, 0, NULL, 1);

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `event_bans`
--

CREATE TABLE `event_bans` (
  `id` int NOT NULL,
  `event_id` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `user_id` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `event_comments`
--

CREATE TABLE `event_comments` (
  `id` int NOT NULL,
  `event_id` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `user_id` int NOT NULL,
  `content` text COLLATE utf8mb4_general_ci NOT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `event_comments`
--

INSERT INTO `event_comments` (`id`, `event_id`, `user_id`, `content`, `created_at`) VALUES
(1, '1742372732146', 38, 'pozdro', '2025-04-14 13:15:50'),
(3, '1742372732146', 38, 'test', '2025-04-14 14:34:22'),
(4, '1742372732146', 38, 'kolejna proba', '2025-04-14 14:34:34');

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `event_likes`
--

CREATE TABLE `event_likes` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `event_id` varchar(255) NOT NULL,
  `type` enum('like','dislike') NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `event_likes`
--

INSERT INTO `event_likes` (`id`, `user_id`, `event_id`, `type`) VALUES
(8, 38, '1742372732146', 'like'),
(9, 38, '1742335399867', 'like'),
(10, 38, '1742940594689', 'dislike'),
(11, 38, '1742942345928', 'like'),
(12, 38, '1744152579559', 'like'),
(13, 38, '1744152583645', 'like'),
(14, 116, '1742335399867', 'dislike'),
(15, 116, '1742372732146', 'like');

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `event_participants`
--

CREATE TABLE `event_participants` (
  `id` int NOT NULL,
  `event_id` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `user_id` int NOT NULL,
  `joined_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `ticket_number` varchar(36) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `event_participants`
--

INSERT INTO `event_participants` (`id`, `event_id`, `user_id`, `joined_at`, `ticket_number`) VALUES
(90, '1742372732146', 38, '2025-03-19 08:25:27', NULL),
(111, '1742335399867', 65, '2025-03-25 21:26:50', NULL),
(112, '1742940594689', 41, '2025-03-25 22:09:56', NULL),
(115, '1742942345928', 38, '2025-03-25 22:39:12', NULL),
(129, '1742940594689', 38, '2025-03-26 00:45:20', NULL),
(133, '1742335399867', 38, '2025-03-26 08:58:13', NULL),
(135, '1742335399867', 39, '2025-03-26 09:38:12', NULL),
(137, '1742372732146', 14, '2025-04-08 20:35:25', NULL),
(141, '1742372732146', 39, '2025-04-08 22:47:56', NULL),
(142, '1742940594689', 39, '2025-04-08 22:48:05', NULL),
(143, '1742942345928', 39, '2025-04-08 22:48:08', NULL),
(144, '1744152583645', 38, '2025-04-08 22:49:48', NULL),
(145, '1744152579559', 38, '2025-04-08 22:49:48', NULL),
(146, '1742372732146', 42, '2025-04-08 23:21:11', NULL),
(147, '1744152579559', 116, '2025-04-14 16:43:19', NULL),
(148, '1744152583645', 116, '2025-04-14 16:43:47', NULL),
(149, '1742942345928', 116, '2025-04-14 16:43:55', NULL),
(150, '1742940594689', 116, '2025-04-14 16:44:01', NULL),
(151, '1742372732146', 116, '2025-04-14 17:38:15', NULL);

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `event_reports`
--

CREATE TABLE `event_reports` (
  `id` int NOT NULL,
  `event_id` varchar(255) NOT NULL,
  `reason` text NOT NULL,
  `user_id` int NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `event_reports`
--

INSERT INTO `event_reports` (`id`, `event_id`, `reason`, `user_id`, `created_at`) VALUES
(1, '1742372732146', 'Fałszywe wydarzenie', 38, '2025-04-08 22:47:14'),
(2, '1742372732146', 'Spam', 38, '2025-04-08 22:47:40'),
(3, '1742335399867', 'Nieodpowiednia treść', 38, '2025-04-08 22:47:57'),
(4, '1742372732146', 'Spam', 38, '2025-04-08 23:05:57'),
(5, '1742372732146', 'Fałszywe wydarzenie', 38, '2025-04-08 23:08:19'),
(6, '1742372732146', 'Nieodpowiednia treść', 39, '2025-04-08 23:31:57'),
(13, '1742940594689', 'Spam', 38, '2025-04-09 07:17:56');

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `organizer_ratings`
--

CREATE TABLE `organizer_ratings` (
  `id` int NOT NULL,
  `organizer_id` int NOT NULL,
  `rated_by_user_id` int NOT NULL,
  `rating` int NOT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP
) ;

--
-- Dumping data for table `organizer_ratings`
--

INSERT INTO `organizer_ratings` (`id`, `organizer_id`, `rated_by_user_id`, `rating`, `created_at`) VALUES
(24, 38, 116, 4, '2025-04-14 16:43:42'),
(25, 41, 116, 5, '2025-04-14 16:44:04');

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `payments`
--

CREATE TABLE `payments` (
  `id` varchar(255) NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `title` varchar(255) NOT NULL,
  `user_id` int NOT NULL,
  `event_id` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `status` varchar(50) NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime DEFAULT NULL,
  `payment_method` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `payments`
--

INSERT INTO `payments` (`id`, `amount`, `title`, `user_id`, `event_id`, `status`, `created_at`, `updated_at`, `payment_method`) VALUES
('1SqQds8QfsklnJXb4Tcfog', 2.00, 'After-party po Rabbicie', 38, '1742335399867', 'PENDING', '2025-03-26 08:54:23', NULL, NULL),
('YHxQvvZ2Uco5SpS005WLzw', 2.00, 'After-party po Rabbicie', 38, '1742335399867', 'PENDING', '2025-03-26 08:58:07', NULL, NULL);

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `tickets`
--

CREATE TABLE `tickets` (
  `id` varchar(255) NOT NULL,
  `user_id` int NOT NULL,
  `event_id` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `payment_id` varchar(255) DEFAULT NULL,
  `purchase_date` datetime NOT NULL,
  `status` varchar(50) NOT NULL,
  `price` decimal(10,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `users`
--

CREATE TABLE `users` (
  `id` int NOT NULL,
  `email` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `password` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `nickName` text COLLATE utf8mb4_general_ci,
  `token` text COLLATE utf8mb4_general_ci,
  `imie` text COLLATE utf8mb4_general_ci,
  `nazwisko` text COLLATE utf8mb4_general_ci,
  `is_verified` tinyint(1) DEFAULT '0',
  `verification_token` text COLLATE utf8mb4_general_ci,
  `wiek` int DEFAULT NULL,
  `has_set_preferences` tinyint(1) DEFAULT '0',
  `points` int DEFAULT '0',
  `recent_searches` varchar(1000) COLLATE utf8mb4_general_ci DEFAULT '[]'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `email`, `password`, `nickName`, `token`, `imie`, `nazwisko`, `is_verified`, `verification_token`, `wiek`, `has_set_preferences`, `points`, `recent_searches`) VALUES
(8, 'kocham.pudziana@gmail.com', '12345678', 'kochamPudziana', 'dLBC02AVxWNVzbJJugcaBQ0RHqLkGU0GDgVRHn-HDRg', NULL, NULL, 0, NULL, NULL, 0, 0, ''),
(9, 'sila@pudzian.com', 'tajnehaslo123', 'mokryPudzian', NULL, NULL, NULL, 0, NULL, NULL, 0, 0, ''),
(12, 'e@mail.com', '12345678', 'testNick', 'WJNlz95Pa3Vf6kAjlNJB2HHAkUy_6SercHPnduaCGQU', NULL, NULL, 1, NULL, NULL, 1, 0, ''),
(13, 'ziut@gmail.com', '12345678', 'ziut', 'gKTgjv6LMpjd2zvdYXjACLE-urQ1z52Xp34ZsVk_PHM', NULL, NULL, 0, NULL, NULL, 0, 0, ''),
(14, 'mail@to.com', '12345678', 'Top1FanPudzianav2', NULL, 'patryknaprawiltogowno', 'dfsdas', 1, NULL, NULL, 1, 0, ''),
(15, 'dajogo2736@citdaca.com', 'Kozak123#', 'Kozak', NULL, NULL, NULL, 0, NULL, NULL, 0, 0, ''),
(37, 'nick@mqil.to', '12345678', 'testNixk', NULL, NULL, NULL, 0, NULL, NULL, 0, 0, ''),
(38, 'test@mail.to', 'test', 'testlogin', '3VLweRHleO0M9y1Ujr33MTY12o2tQ6dB2Fsp6BSvVVA', 'Android2', 'JobsPOZMIANIE', 1, '', 25, 1, 4500, '[\"a\", \"szczecin\"]'),
(39, 'hiyeka3992@dfesc.com', 'DZIALAJ123#', 'DZIALAJ', NULL, NULL, NULL, 1, NULL, NULL, 1, 0, ''),
(41, 'yifawi3736@citdaca.com', 'Nice123#', 'NICE', 'QZVa_Gk3-O4Y0-ivpnYIZgGJaH10IoRpJPDr6Y0kXv8', NULL, NULL, 1, NULL, NULL, 1, 0, ''),
(42, 'notide6189@downlor.com', '12345678', 'emailowski', NULL, NULL, NULL, 1, NULL, NULL, 1, 0, ''),
(47, 'mifatil655@kurbieh.com', 'Testowy123#', 'TEST', 'Ev73pc1yGQCx5F34oIzmxLc8pGuI_mNc15T6l5KFpzI', NULL, NULL, 1, NULL, NULL, 0, 0, ''),
(48, 'cqu52083@bcooq.com', '12345678', 'zzz', '_JvGiwq_CRLu1e_0sSK2K-nXwHfrm5w7Q_0KB0IeGiU', NULL, NULL, 1, NULL, NULL, 0, 0, ''),
(61, 'xyn84178@msssg.com', 'sdafasdf123#', 'dhgdgfhdfg', NULL, NULL, NULL, 1, NULL, NULL, 0, 0, ''),
(64, 'lanemi4184@halbov.com', '12345678', 'gigaOnePlus', 'oHplW0p__6KTrRtpmGqoxkHwe35Y7tCSJOmtYoAyflU', NULL, NULL, 1, NULL, NULL, 0, 0, ''),
(65, 'sovel55748@maonyn.com', '12345678', 'GigaKremówka', NULL, NULL, NULL, 1, NULL, NULL, 0, 0, ''),
(66, 'test2', 'test', 'test2', NULL, 'Testowirońskii', 'Pomarańcz', 1, '', 33, 0, 0, ''),
(67, 'testlogowani21312312@c.cmo', '12313213', 'testlogowania21312', NULL, NULL, NULL, 0, 'ubw0ABS8u655uoVZyjnQXKlON98OajRUfJ-0LAi7NHk', NULL, 0, 0, ''),
(68, 'jsdja@lkdjskld.com', '!QAZA1qqazwhi23hrhiuode', 'sjdadjd', NULL, 'janusz ', 'nowak', 0, 'YNQ08P94kYp5EiUsTu1UxnVOTO5aqaHkim1Qvs31of4', 45, 0, 0, ''),
(69, 'janusz@gmail.com', '!QAZA1qqazwhi23hrhiuode', 'sjdadjd', NULL, 'janusz ', 'nowak', 0, 'uoF8ttbuu-w6_wvauBV2tJgRQHpbeZtjLCtoNKb_CAQ', 45, 0, 0, ''),
(71, 'janusz15@gmail.com', '!QAZA1qqazwhi23hrhiuoded', 'fajowynick', NULL, 'januszek', 'nowakiewicz', 0, '3RC3BUqMLCcl2HS9wXJBmsSzxndkrErzCLZ00sEsq7U', 50, 0, 0, ''),
(73, 'janusz154@gmail.com', '!QAZA1qqazwhi23hrhiuodedf', 'fajowynickds', NULL, 'januszeksd', 'nowakiewiczsd', 0, 'jWteh9tmtPDWOcBY_mbUmnv0isr_rYm0-oUgE_OcEGw', 50, 0, 0, ''),
(74, 'janusz1554@gmail.com', '!QAZA1qqazwhi23h', 'fajowynicksdd', NULL, 'janud', 'nowakid', 0, '6rS2IUUuF-eejzSzpwqUFtl6udcSDeAR5Q5LXcgBGHE', 50, 0, 0, ''),
(76, 'kowal@wp.pl', '!QAZA1qqadgg#3e', 'kowal', NULL, 'jan', 'kowal', 0, 'KniUxs8h5wr4vKyu6QDG48p518gB3QGCWfafTY6PWgI', 45, 0, 0, ''),
(78, 'kowdal@wp.pl', '!QAZA1qqadgg#3ed', 'kowals', NULL, 'jan', 'kowal', 0, 'zFZT3ULLRH3lFKjXrT6ReOONDcimJn-VXKRQCcn66PU', 45, 0, 0, ''),
(79, 'michal@wp.pl', 'michal12!S', 'michal', NULL, 'michal', 'michalski', 0, 'ykStgP9jB_X7KOvIP2xFznaCFwx_0OE2v3W7eYXpkyM', 19, 0, 0, ''),
(80, 'maciek@gmail.com', '1qaz!QAZq', 'maciejoskox', NULL, 'maciek', 'kowal', 0, 'M2YR6i0CmdP8G5WOPnS9S87jPAKOPC_Ejszg1QhoTSg', 78, 0, 0, ''),
(82, 'xetolo7585@fundapk.com', '12345678', 'mikoMail', NULL, NULL, NULL, 1, NULL, NULL, 1, 0, ''),
(83, 'maciek12@gmail.com', '1qaz!QAZqs', 'maciejoskoxd', NULL, 'maciekds', 'kowalas', 0, 'nN91i0hvU5PNr1SMxzNJu6qgRQGQEOOvK6g3P95PtSs', 78, 0, 0, ''),
(84, 'test@wp.pl', '!QAZzaq12', 'sdsdsad', NULL, 'dkshj', 'khkhl', 0, 'MHBkI7z6ZpJKjZHOg9PCgN8jO37O5UPJOB1UwqrR_gE', 45, 0, 0, ''),
(86, 'testy@wp.pl', '!QAZzaq12d', 'sdsdsadds', NULL, 'dkshj', 'khkhlrd', 0, 'nJdIOIdNXjQFwGFXqzl-sUbSkiEWTpcaX4ylqfAGNv8', 45, 0, 0, ''),
(87, 'tester@wp.pl', '!QAZzaq1', 'testertestowy', NULL, 'testowy2', 'tescikowy', 0, 'uCVCtfXCFkpluW5R_D774bMtuA_n8tmLb7Y6BMvw44E', 45, 0, 0, ''),
(88, 'tester2@wp.pl', '!QAZzaq1d', 'testertestowy2', NULL, NULL, NULL, 0, '9fqKKKHfFfIcIpKROq2LXb6GCDnKMo_vv6vguya6Dpc', NULL, 0, 0, ''),
(90, 'tester32@wp.pl', '!QAZzaq1d', 'testertestowy23', NULL, NULL, NULL, 0, 'Yke4nWSKpJEPMk4JPQJ95Mo1PSTJ0R4cAHtDuBdygyE', NULL, 0, 0, ''),
(91, 'makrek@gmail.com', '12345678', 'marekogarek', NULL, 'marek', 'marewski', 0, 'FwJh0b7tpvGNkCtfFZmOfeIS6ZLu-6yUmTBBKsCseN0', 46, 0, 0, ''),
(93, 'jarek@gmail.com', '12345678', 'jareczekfajny', NULL, NULL, NULL, 0, '1j_MPXOmj_Y4cQJWvRQ3e_crZ2BL7wZowdr7FoEq3cc', NULL, 0, 0, ''),
(95, '43242@gmail.com', 'gfewrqgf43t2w34', '3213123', NULL, NULL, NULL, 0, 'zynKF9VXdilI9yh1_Nhn8a8Rf27HUxBh4F1HGgW7U0s', NULL, 0, 0, ''),
(96, '3424@cwel.com', '242323432423', '424243', NULL, '5432423', '4234', 0, 'lb_gnQGscgMf72-Pk9JE7dHdVjEHLj72787KPAOLwfo', 23, 0, 0, ''),
(97, 'gesimi7158@maonyn.com', 'Test123#', 'bigBen', NULL, 'Artur', 'Wiercipała', 1, NULL, 85, 0, 0, ''),
(98, 'xisak94403@downlor.com', 'Test123#', 'mariuSz', NULL, NULL, NULL, 1, NULL, NULL, 1, 0, ''),
(100, 'voxeme8223@dfesc.com', 'test123#', 'nazwa1', NULL, 'janusz', 'kowalski', 1, NULL, NULL, 0, 0, ''),
(103, 'adzialowy71@gmail.com', 'Nowe_123', 'fifi', 'RDtL9Jd9cg_lQ2ZHyE3tfj1pky6UHQxvKOWg9Ch2CpU', NULL, NULL, 1, NULL, NULL, 0, 0, ''),
(104, 'nevaro9852@citdaca.com', 'Kutas123#', 'cos', NULL, 'asfas', 'gdsa', 1, NULL, 18, 0, 0, ''),
(105, 'rodojan@wp.pl', 'Tetsowe!12345678', 'janrodo', NULL, 'jan', 'Kowalski', 0, '6dwQ6KeH0C-FCZU5aSJyIw7vAQAo4ForYnrWjcRH5EE', 60, 0, 0, ''),
(107, 'rodojannowy@wp.pl', 'Tetsowe!12345678', 'janrodonowy', NULL, 'jan', 'Kowalski', 0, '8WyTIVETQ8ZQQYlMjLC8GB8lWnzH7wf01fTxNzR7_JY', 60, 0, 0, ''),
(109, 'rodojannowynowy@wp.pl', 'Tetsowe!12345678', 'janrodonowynowy', NULL, 'jan', 'Kowalski', 0, 'oSt-v9uFA9TNqTqM2LaRxbRR6UqnBAi22M27ZeZ28VY', 60, 0, 0, ''),
(110, 'dokefen706@dmener.com', 'Testowehaslo!12345678', 'kowaljanusz', NULL, 'Janusz', 'Kowal', 0, '9BilsjlYvniEjQDCXEwg6kMEk-y54xv33N-_BDriPg4', 60, 0, 0, ''),
(111, 'hash@mail.to', '$argon2id$v=19$m=65536,t=3,p=4$6rc4kSuHm2EjMRBU5GNoVQ$MoJEDSIb/9QETS7FXBNQ999ijFT20Dh1Z6Rf7HVZIXw', 'testhash', '8wAaOfw9on61ceFcR8VrRf3PUKBP4DJJ4yZpSdkvYOw', 'hashiwanie', 'test', 1, '', 33, 0, 0, ''),
(112, 'mafir13929@boyaga.com', 'Testlogin!1', 'mikofalko', NULL, 'miko', 'falko', 0, 'XseJkvWIgm14lStbD3BAsIzc1YTe-orB9F-dMjrqA_I', 22, 0, 0, ''),
(114, 'jan@example.com', 'haslo123', 'jkowalski', NULL, 'Jan', 'Kowalski', 0, 'YPCnNksaAKYs4cxXSrRUzK6eb5TwHvM5', 30, 0, 0, ''),
(116, 'doggoone7@gmail.com', '', 'doggoone7', 'PHt6NE_ZUdsEw9V61rv5RAusCQcmsRYPNxJ6WPUS3f4', 'Filip Fojna', '', 1, NULL, 18, 1, 0, '[]');

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `users_info`
--

CREATE TABLE `users_info` (
  `userID` int NOT NULL,
  `last_login` datetime DEFAULT NULL,
  `token_expires_at` datetime DEFAULT NULL,
  `is2FAEnabled` tinyint(1) DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `users_info`
--

INSERT INTO `users_info` (`userID`, `last_login`, `token_expires_at`, `is2FAEnabled`) VALUES
(12, '2025-03-20 01:22:32', '2025-07-18 01:22:32', 0),
(14, '2025-04-08 20:33:58', '2025-08-06 20:33:58', 0),
(38, '2025-04-14 17:02:53', '2025-08-12 17:02:53', 0),
(39, '2025-04-08 23:24:58', '2025-08-06 23:24:58', 0),
(41, '2025-03-25 23:43:32', '2025-07-23 23:43:32', 0),
(42, '2025-04-08 23:21:05', '2025-08-06 23:21:05', 0),
(65, '2025-03-25 21:21:59', '2025-07-23 21:21:59', 0),
(66, '2025-03-18 20:59:41', NULL, 0),
(82, '2025-03-24 22:53:12', NULL, 0),
(97, '2025-03-19 22:36:10', NULL, 0),
(98, '2025-03-25 21:39:16', '2025-07-23 21:39:16', 0),
(111, '2025-03-21 12:46:17', '2025-07-19 12:46:17', 0);

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `user_event_preferences`
--

CREATE TABLE `user_event_preferences` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `event_type` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `user_event_preferences`
--

INSERT INTO `user_event_preferences` (`id`, `user_id`, `event_type`) VALUES
(49, 98, 'Warsztaty'),
(50, 98, 'Relaks'),
(51, 98, 'Outdoor'),
(52, 41, 'Domówka'),
(53, 41, 'Warsztaty'),
(54, 41, 'Impreza masowa'),
(55, 41, 'Sportowe'),
(56, 41, 'Kulturalne'),
(57, 41, 'Spotkanie towarzyskie'),
(58, 41, 'Outdoor'),
(59, 41, 'Relaks'),
(60, 41, 'Firmowe'),
(61, 41, 'Motoryzacyjne'),
(62, 42, 'Kulturalne'),
(66, 39, 'Spotkanie towarzyskie'),
(67, 39, 'Impreza masowa'),
(72, 38, 'Impreza masowa'),
(73, 38, 'Motoryzacyjne'),
(74, 38, 'Relaks'),
(78, 116, 'Spotkanie towarzyskie'),
(79, 116, 'Sportowe'),
(80, 116, 'Domówka'),
(83, 14, 'Domówka');

--
-- Indeksy dla zrzutów tabel
--

--
-- Indeksy dla tabeli `comment_reports`
--
ALTER TABLE `comment_reports`
  ADD PRIMARY KEY (`id`),
  ADD KEY `comment_id` (`comment_id`),
  ADD KEY `event_id` (`event_id`),
  ADD KEY `user_id` (`user_id`);

--
-- Indeksy dla tabeli `events`
--
ALTER TABLE `events`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_user_id` (`user_id`);

--
-- Indeksy dla tabeli `event_bans`
--
ALTER TABLE `event_bans`
  ADD PRIMARY KEY (`id`),
  ADD KEY `event_id` (`event_id`),
  ADD KEY `user_id` (`user_id`);

--
-- Indeksy dla tabeli `event_comments`
--
ALTER TABLE `event_comments`
  ADD PRIMARY KEY (`id`),
  ADD KEY `event_id` (`event_id`),
  ADD KEY `user_id` (`user_id`);

--
-- Indeksy dla tabeli `event_likes`
--
ALTER TABLE `event_likes`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `user_id` (`user_id`,`event_id`);

--
-- Indeksy dla tabeli `event_participants`
--
ALTER TABLE `event_participants`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `ticket_number` (`ticket_number`),
  ADD KEY `event_id` (`event_id`),
  ADD KEY `user_id` (`user_id`);

--
-- Indeksy dla tabeli `event_reports`
--
ALTER TABLE `event_reports`
  ADD PRIMARY KEY (`id`);

--
-- Indeksy dla tabeli `organizer_ratings`
--
ALTER TABLE `organizer_ratings`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `organizer_id` (`organizer_id`,`rated_by_user_id`);

--
-- Indeksy dla tabeli `payments`
--
ALTER TABLE `payments`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `event_id` (`event_id`);

--
-- Indeksy dla tabeli `tickets`
--
ALTER TABLE `tickets`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `event_id` (`event_id`),
  ADD KEY `payment_id` (`payment_id`);

--
-- Indeksy dla tabeli `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`);

--
-- Indeksy dla tabeli `users_info`
--
ALTER TABLE `users_info`
  ADD PRIMARY KEY (`userID`);

--
-- Indeksy dla tabeli `user_event_preferences`
--
ALTER TABLE `user_event_preferences`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_id` (`user_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `comment_reports`
--
ALTER TABLE `comment_reports`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `event_bans`
--
ALTER TABLE `event_bans`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT for table `event_comments`
--
ALTER TABLE `event_comments`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT for table `event_likes`
--
ALTER TABLE `event_likes`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;

--
-- AUTO_INCREMENT for table `event_participants`
--
ALTER TABLE `event_participants`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=152;

--
-- AUTO_INCREMENT for table `event_reports`
--
ALTER TABLE `event_reports`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=14;

--
-- AUTO_INCREMENT for table `organizer_ratings`
--
ALTER TABLE `organizer_ratings`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=117;

--
-- AUTO_INCREMENT for table `user_event_preferences`
--
ALTER TABLE `user_event_preferences`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=84;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `comment_reports`
--
ALTER TABLE `comment_reports`
  ADD CONSTRAINT `comment_reports_ibfk_1` FOREIGN KEY (`comment_id`) REFERENCES `event_comments` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `comment_reports_ibfk_2` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `comment_reports_ibfk_3` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `events`
--
ALTER TABLE `events`
  ADD CONSTRAINT `fk_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `event_bans`
--
ALTER TABLE `event_bans`
  ADD CONSTRAINT `event_bans_ibfk_1` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `event_bans_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `event_comments`
--
ALTER TABLE `event_comments`
  ADD CONSTRAINT `event_comments_ibfk_1` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `event_comments_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `event_participants`
--
ALTER TABLE `event_participants`
  ADD CONSTRAINT `event_participants_ibfk_1` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `event_participants_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `payments`
--
ALTER TABLE `payments`
  ADD CONSTRAINT `payments_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `payments_ibfk_2` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `tickets`
--
ALTER TABLE `tickets`
  ADD CONSTRAINT `tickets_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `tickets_ibfk_2` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `tickets_ibfk_3` FOREIGN KEY (`payment_id`) REFERENCES `payments` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `users_info`
--
ALTER TABLE `users_info`
  ADD CONSTRAINT `fk_user_id_users_info` FOREIGN KEY (`userID`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `user_event_preferences`
--
ALTER TABLE `user_event_preferences`
  ADD CONSTRAINT `user_event_preferences_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
