--
-- Database_Oracle_CI.sql
--
-- Target DBMS : Oracle
--
-- Copyright Deltek, Inc.
--
--
-- Script for initializing a new Oracle database for CI/CD environments.
-- This is a lightweight version of Database_Oracle.sql optimized for GitHub Actions and other CI/CD runners.
--
-- This script does the following:
-- 1) Upgrade the database to support extended string size that is required to use column level collations.
-- 2) Create the PPMWEB tablespace with CI-appropriate sizing (100MB initial, 2GB max)
-- 3) Create the PPMWEB and PPMWEBADMIN accounts for the PPM Web environment and assign the default PPMWEB tablespace.
-- 4) Grant the default Roles and Privileges to the PPMWEB and PPMWEBADMIN accounts.
--

--
-- Upgrade the database to support extended string size
-- SKIPPED IN CI: This requires significant disk space for system tablespace expansion
-- The extended string size is not critical for integration tests
--
-- For CI environments, we skip this step to conserve disk space:
-- SHUTDOWN IMMEDIATE;
-- STARTUP UPGRADE;
-- ALTER SYSTEM SET max_string_size=extended;
-- START $ORACLE_HOME/rdbms/admin/utl32k.sql
-- SHUTDOWN IMMEDIATE;
-- STARTUP;


--
-- TABLESPACE : PPMWEB (CI-optimized sizing)
-- For CI environments, we use a much smaller initial size and rely on the existing USERS tablespace
-- when possible to minimize disk usage on resource-constrained GitHub Actions runners
--

CREATE BIGFILE TABLESPACE PPMWEB
    DATAFILE
    '/opt/oracle/oradata/FREE/FREEPDB1/PPMWEB.dbf' SIZE 50M AUTOEXTEND ON NEXT 10M MAXSIZE 1G
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
 