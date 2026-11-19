-- MySQL dump 10.13  Distrib 8.0.36, for Linux (x86_64)
-- Host: ehr-db-prod-02    Database: ehr_legacy
-- Server version 8.0.36
/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40103 SET TIME_ZONE='+00:00' */;

DROP TABLE IF EXISTS `patients`;
CREATE TABLE `patients` (
  `id` int NOT NULL AUTO_INCREMENT,
  `mrn` varchar(16) NOT NULL,
  `last_name` varchar(64) NOT NULL,
  `first_name` varchar(64) NOT NULL,
  `sex` varchar(16) DEFAULT NULL,
  `dob` date DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
INSERT INTO `patients` (`id`,`mrn`,`last_name`,`first_name`,`sex`,`dob`) VALUES (89,'71304C2E','Cremin','Silvana','F','1959-10-01');

DROP TABLE IF EXISTS `encounters`;
CREATE TABLE `encounters` (`id` int, `patient_id` int, `admit_ts` datetime, `ward` varchar(8), `attending` varchar(64), `bp` varchar(8), `hr` int, `temp_f` decimal(4,1));
INSERT INTO `encounters` VALUES (890,89,'2026-01-15 08:41:00','B-9','P. Lindqvist','138/73',63,97.7);

DROP TABLE IF EXISTS `diagnoses`;
CREATE TABLE `diagnoses` (`id` int, `encounter_id` int, `code_system` varchar(16), `code` varchar(24), `description` varchar(255));
INSERT INTO `diagnoses` VALUES
  (8900,890,'SNOMED','44054006','Diabetes'),
  (8901,890,'SNOMED','19169002','Miscarriage in first trimester'),
  (8902,890,'SNOMED','302870006','Hypertriglyceridemia (disorder)');

DROP TABLE IF EXISTS `symptoms`;
CREATE TABLE `symptoms` (`id` int, `encounter_id` int, `description` varchar(128), `severity` varchar(8));
INSERT INTO `symptoms` VALUES
  (8900,890,'shortness of breath','mild'),
  (8901,890,'sore throat','moderate'),
  (8902,890,'chest pain','severe'),
  (8903,890,'joint pain','mild');

DROP TABLE IF EXISTS `billing_events`;
CREATE TABLE `billing_events` (`id` int, `encounter_id` int, `payer_id` varchar(16), `amount_cents` int, `status` varchar(16));
INSERT INTO `billing_events` VALUES (623,890,'PAYER-4471',15793,'PENDING'),(624,890,'PAYER-4471',2500,'COPAY');

DROP TABLE IF EXISTS `audit_log`;
CREATE TABLE `audit_log` (`ts` datetime, `user` varchar(32), `action` varchar(32));
INSERT INTO `audit_log` VALUES ('2026-01-15 08:40:12','frontdesk3','VIEW_PATIENT'),('2026-01-15 09:02:51','awhitfield','OPEN_CHART'),('2026-01-15 09:30:07','svc_batch','EXPORT');
-- Dump completed on 2026-01-15 23:59:59
