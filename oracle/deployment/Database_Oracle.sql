--
-- Database_Oracle.sql
--
-- Target DBMS : Oracle
--
-- Copyright Deltek, Inc.
--
--
-- Script for initializing a new Oracle database.
--
-- This script does the following:
-- 1) Upgrade the database to support extended string size that is required to use column level collations.
-- 2) Create the PPMWEB tablespace
-- 3) Create the PPMWEB and PPMWEBADMIN accounts for the PPM Web environment and assign the default PPMWEB tablespace.
-- 4) Grant the default Roles and Privileges to the PPMWEB and PPMWEBADMIN accounts.
--

--
-- Upgrade the database to support extended string size
--
SHUTDOWN IMMEDIATE;
STARTUP UPGRADE;
ALTER SYSTEM SET max_string_size=extended;
START $ORACLE_HOME/rdbms/admin/utl32k.sql
SHUTDOWN IMMEDIATE;
STARTUP;


--
-- TABLESPACE : PPMWEB
--

CREATE BIGFILE TABLESPACE PPMWEB
    DATAFILE
    '/opt/oracle/oradata/FREE/FREEPDB1/PPMWEB.dbf' SIZE 1073741824 AUTOEXTEND ON NEXT 104857600 MAXSIZE UNLIMITED
    NOLOGGING
    ONLINE
    SEGMENT SPACE MANAGEMENT AUTO
    EXTENT MANAGEMENT LOCAL AUTOALLOCATE;

--
-- USER: PPMWEB  Default Schema for PPMWEB
--

-- USER SQL
CREATE USER "PPMWEB" IDENTIFIED BY "PPMWEB"
    DEFAULT TABLESPACE "PPMWEB"
    TEMPORARY TABLESPACE "TEMP";

-- QUOTAS
ALTER USER "PPMWEB" QUOTA UNLIMITED ON "PPMWEB";

-- ROLES
GRANT "CONNECT" TO "PPMWEB";

-- SYSTEM PRIVILEGES
GRANT ALTER SESSION TO "PPMWEB" ;
GRANT DELETE ANY TABLE TO "PPMWEB" ;
GRANT EXECUTE ANY PROCEDURE TO "PPMWEB" ;
GRANT UPDATE ANY TABLE TO "PPMWEB" ;
GRANT READ ANY TABLE TO "PPMWEB" ;


--
-- USER: PPMWEBADMIN SYSDBA account for the PPMWEB database.
--

-- USER SQL
CREATE USER "PPMWEBADMIN" IDENTIFIED BY "PPMWEBADMIN"
    DEFAULT TABLESPACE "PPMWEB"
    TEMPORARY TABLESPACE "TEMP";

-- QUOTAS
ALTER USER "PPMWEBADMIN" QUOTA UNLIMITED ON "PPMWEB";

-- ROLES
GRANT "DBA" TO "PPMWEBADMIN" WITH ADMIN OPTION;
ALTER USER "PPMWEBADMIN" DEFAULT ROLE "DBA";

-- SYSTEM PRIVILEGES
GRANT SYSDBA TO "PPMWEBADMIN" WITH ADMIN OPTION;

-- Added to ensure the script exits after its execution in the integration pipeline
EXIT;
