--
-- Model_Oracle.sql
--
-- Target DBMS : Oracle
--
-- Copyright Deltek, Inc.
--
--
-- Procedures used for creating tables, views, indexes, primary keys and foreign keys.
--
-- For explicit Tablespace support for Tables, Indexes or LOBs, set the 'table_tablespace', 'index_tablespace' and 'lob_tablespace' variables in the DECLARE section.
--

DECLARE

--
-- Set the schema_name variable to the schema that will contain the tables.
-- This is necessary for the CREATE procedures to work because they must query
--   the ALL_TABLES and ALL_INDEXES catalogs which require the schema name for the
--   query to see if the table or index already exists.
-- For deployments that use the PPMWEB and PPMWEBADMIN schemas, the schema_name must be set to 'PPMWEB'.
-- For deployments to a developer's database schema, the schema_name must be set to the developer's schema name.
-- For Liquibase deployments, the defaultSchemaName property can be set in the liquibase.properties file.
--
--schema_name VARCHAR2(30);
--schema_name VARCHAR2(30) := 'PPMWEB';
schema_name VARCHAR2(30) := '${database.defaultSchemaName}';

-- Set drop_tables to 'T' to drop tables before creating them.--
drop_tables CHAR(1) := 'F';

--
-- Set the 'table_tablespace', 'index_tablespace' and 'lob_tablespace' variables to the desired tablespace names.
-- If the variables are set to NULL, the tables will be created in the schema's default tablespace.
--
table_tablespace VARCHAR2(30);
-- := 'PPM_DATA';
index_tablespace VARCHAR2(30);
-- := 'PPM_INDEX';
lob_tablespace VARCHAR2(30);
-- := 'PPM_LOB';

--
-- Procedure CREATE_TABLE
--
-- Creates tables with verification that the tables do not already exist.
--
PROCEDURE CREATE_TABLE
(
  tableName IN VARCHAR2,
  query IN NCLOB
)
IS
  x NUMBER;
  newQuery NCLOB;
  tableSpace VARCHAR2(100);
BEGIN
  SELECT ROWNUM INTO X FROM ALL_TABLES WHERE OWNER = schema_name AND TABLE_NAME = tableName;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    BEGIN
      newQuery := query;

      IF NOT table_tablespace IS NULL THEN
        tableSpace := 'TABLESPACE ' || table_tablespace;
        newQuery := REPLACE(newQuery, '%TABLETABLESPACE%', tableSpace );
      ELSE
        newQuery := REPLACE(newQuery, '%TABLETABLESPACE%');
      END IF;

      IF NOT index_tablespace IS NULL THEN
        tableSpace := 'USING INDEX TABLESPACE ' || index_tablespace;
        newQuery := REPLACE(newQuery, '%INDEXTABLESPACE%',tableSpace );
      ELSE
        newQuery := REPLACE(newQuery, '%INDEXTABLESPACE%');
      END IF;

      IF NOT lob_tablespace IS NULL THEN
        tableSpace := 'TABLESPACE ' || lob_tablespace;
        newQuery := REPLACE(newQuery, '%LOBTABLESPACE%', tableSpace );
      ELSE
        newQuery := REPLACE(newQuery, '%LOBTABLESPACE%');
      END IF;

      EXECUTE IMMEDIATE newQuery;
    END;
END CREATE_TABLE;

--
-- Procedure DROP_TABLE
--
-- Drops a table with verification that the table exists before dropping it.
--
PROCEDURE DROP_TABLE
(
  tableName IN VARCHAR2
)
IS
  x NUMBER;
  query NCLOB;
BEGIN
  IF drop_tables = 'F' THEN
    RETURN;
  END IF;
  SELECT ROWNUM INTO X FROM ALL_TABLES WHERE OWNER = schema_name AND TABLE_NAME = tableName;
  IF x <> 0 THEN
    BEGIN
      query := 'DROP TABLE ' || tableName || ' CASCADE CONSTRAINTS';
      EXECUTE IMMEDIATE query;
    END;
  END IF;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
END DROP_TABLE;


--
-- Procedure CREATE_VIEW
--
-- Creates a view with verification that the view does not already exist.
--
PROCEDURE CREATE_VIEW
(
  viewName IN VARCHAR2,
  query IN NCLOB
)
IS
  x    NUMBER;
BEGIN
  SELECT ROWNUM INTO X FROM ALL_VIEWS WHERE OWNER = schema_name AND VIEW_NAME = viewName;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    BEGIN
      EXECUTE IMMEDIATE query;
    END;
END CREATE_VIEW;


--
-- Procedure CREATE_INDEX
--
-- Creates indexes with verification that the indexes do not already exist.
--
PROCEDURE CREATE_INDEX
(
  tableName IN VARCHAR2,
  fields IN VARCHAR2
)
IS
  x    NUMBER;
  query NCLOB;
  tableSpace VARCHAR2(100);
  indexName VARCHAR2(100);
BEGIN
    indexName := 'IDX_' || tableName || '_' || fields;
    indexName := REPLACE(indexName, ' ', '');
    indexName := REPLACE(indexName, ',', '_');
    SELECT ROWNUM INTO X FROM ALL_INDEXES WHERE OWNER = schema_name AND INDEX_NAME = indexname;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    BEGIN
      IF NOT index_tablespace IS NULL THEN
        tableSpace := 'TABLESPACE ' || index_tablespace;
      END IF;
      query := 'CREATE INDEX ' || indexname || ' ON ' || tableName || ' ( ' || fields || ' ) ' || tableSpace;
      EXECUTE IMMEDIATE query;
    END;
END CREATE_INDEX;


--
-- Procedure CREATE_FOREIGN_KEY_INDEX
--
-- Creates indexes with verification that the indexes do not already exist.
--
PROCEDURE CREATE_FOREIGN_KEY_INDEX
(
  tableName IN VARCHAR2,
  columnName IN VARCHAR2
)
IS
  x    NUMBER;
  query NCLOB;
  tableSpace VARCHAR2(100);
  indexName VARCHAR2(100);
BEGIN
    indexName := 'FK_' || tableName || '_' || columnName;
    SELECT ROWNUM INTO X FROM ALL_INDEXES WHERE OWNER = schema_name AND INDEX_NAME = indexname;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    BEGIN
      IF NOT index_tablespace IS NULL THEN
        tableSpace := 'TABLESPACE ' || index_tablespace;
      END IF;
      query := 'CREATE INDEX ' || indexname || ' ON ' || tableName || ' ( ' || columnName || ' ) ' || tableSpace;
      EXECUTE IMMEDIATE query;
    END;
END CREATE_FOREIGN_KEY_INDEX;


--
-- Procedure CREATE_PRIMARY_KEY
--
-- Creates PRIMARY KEY constraint with verification that the primary key does not already exist.
--
PROCEDURE CREATE_PRIMARY_KEY
(
  tableName IN VARCHAR2,
  columnList IN VARCHAR2
)
IS
  x    NUMBER;
  query NCLOB;
  constraintName VARCHAR2(100);
  tableSpace VARCHAR2(100);
BEGIN
  constraintName := 'PK_' || tableName;
  SELECT COUNT(COLUMN_NAME) INTO x FROM ALL_CONS_COLUMNS WHERE OWNER = schema_name AND CONSTRAINT_NAME = constraintName AND TABLE_NAME = tableName;
  IF x = 0 THEN
    BEGIN
      IF NOT index_tablespace IS NULL THEN
        tableSpace := 'USING INDEX TABLESPACE ' || index_tablespace;
      END IF;
      query := 'ALTER TABLE ' || tableName || ' ADD CONSTRAINT ' || constraintName || ' PRIMARY KEY (' || columnList || ' ) ' || tableSpace;
      EXECUTE IMMEDIATE query;
    END;
  END IF;
END CREATE_PRIMARY_KEY;


--
-- Procedure CREATE_FOREIGN_KEY
--
-- Creates FOREIGN KEY constraint with verification that the primary key does not already exist.
-- Automatically creates the foreign key index along with the foreign key constraint.
--
PROCEDURE CREATE_FOREIGN_KEY
(
  tableName IN VARCHAR2,
  columnName IN VARCHAR2,
  foreignTableName IN VARCHAR2,
  foreignColumnName IN VARCHAR2
)
IS
  x    NUMBER;
  query NCLOB;
  tableSpace VARCHAR2(100);
  constraintName VARCHAR2(100);
BEGIN
  constraintName := 'FK_' || tableName || '_' || columnName;
  SELECT COUNT(COLUMN_NAME) INTO x FROM ALL_CONS_COLUMNS WHERE OWNER = schema_name AND CONSTRAINT_NAME = constraintName AND TABLE_NAME = tableName;
  IF x = 0 THEN
    BEGIN
      query := 'ALTER TABLE ' || tableName || ' ADD CONSTRAINT ' || constraintName || ' FOREIGN KEY (' || columnName || ' ) REFERENCES ' || foreignTableName || '(' || foreignColumnName || ') DISABLE ' || tableSpace;
      EXECUTE IMMEDIATE query;
    END;
  END IF;
  -- Create the index separately from the block that creates the constraint, so the CREATE_FOREIGN_INDEX call will be made even if the foreign key constraint exists.
  -- Don't create a foreign key index on the primary key column because it is already indexed by the primary key.
  IF columnName <> foreignColumnName THEN
    CREATE_FOREIGN_KEY_INDEX(tableName, columnName);
  END IF;
END CREATE_FOREIGN_KEY;


--
-- Procedure CREATE_NATURAL_KEY
--
-- Creates NATURAL KEY constraint with verification that the con key does not already exist.
--
PROCEDURE CREATE_NATURAL_KEY
(
  tableName IN VARCHAR2,
  columnList IN VARCHAR2
)
IS
  x    NUMBER;
  query NCLOB;
  constraintName VARCHAR2(100);
  tableSpace VARCHAR2(100);
BEGIN
  constraintName := 'NK_' || tableName;
  SELECT COUNT(COLUMN_NAME) INTO x FROM ALL_CONS_COLUMNS WHERE OWNER = schema_name AND CONSTRAINT_NAME = constraintName AND TABLE_NAME = tableName;
  IF x = 0 THEN
    BEGIN
      IF NOT index_tablespace IS NULL THEN
        tableSpace := 'USING INDEX TABLESPACE ' || index_tablespace;
      END IF;
      query := 'ALTER TABLE ' || tableName || ' ADD CONSTRAINT ' || constraintName || ' UNIQUE (' || columnList || ' ) ' || tableSpace;
      EXECUTE IMMEDIATE query;
    END;
  END IF;
END CREATE_NATURAL_KEY;


---
-- Procedure ADD_TABLE_COMMENT
--
-- Creates a comment on a table or column with verification that the comment does not already exist.
--
PROCEDURE ADD_TABLE_COMMENT
(
  tableName IN VARCHAR2,
  commentString IN VARCHAR2
)
IS
  x    NUMBER;
BEGIN
  SELECT COUNT(TABLE_NAME) INTO x FROM ALL_TAB_COMMENTS WHERE OWNER = schema_name AND TABLE_NAME = tableName;
  IF x = 0 THEN
    EXECUTE IMMEDIATE 'COMMENT ON TABLE ' || tableName || ' IS ''' || commentString || '''';
  END IF;
END ADD_TABLE_COMMENT;


---
-- Procedure ADD_COLUMN_COMMENT
--
-- Creates a comment on a column with verification that the comment does not already exist.
--
PROCEDURE ADD_COLUMN_COMMENT
(
  tableName IN VARCHAR2,
  columnName IN VARCHAR2,
  commentString IN VARCHAR2
)
IS
BEGIN
  EXECUTE IMMEDIATE 'COMMENT ON COLUMN ' || tableName || '.' || columnName || ' IS ''' || commentString || '''';
END ADD_COLUMN_COMMENT;


--
-- Procedure ADD_COLUMN
--
-- Add a column to an existing table with verification that column does not already exist
--
PROCEDURE ADD_COLUMN
(
  v_TableName  IN VARCHAR2,
  v_ColumnName IN VARCHAR2,
  v_ColumnType IN VARCHAR2
)
IS
  x    NUMBER;
  QUERY NCLOB;
BEGIN
  SELECT ROWNUM INTO X FROM ALL_TAB_COLUMNS WHERE OWNER = schema_name AND TABLE_NAME = v_TableName AND COLUMN_NAME = v_ColumnName;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    BEGIN
      QUERY := 'ALTER TABLE ' || v_TableName || ' ADD ( ' || v_ColumnName || ' ' || v_ColumnType || ' )';
      EXECUTE IMMEDIATE QUERY;
    END;
END ADD_COLUMN;


--
-- Procedure DROP_INDEX
--
-- Drops the specified index with verification that the index exists.
--
PROCEDURE DROP_INDEX (
  v_indexName IN VARCHAR2
)
IS
  x NUMBER;
  query NCLOB;
BEGIN
  -- Check if the index exists
  BEGIN SELECT ROWNUM INTO x FROM ALL_INDEXES WHERE OWNER = schema_name AND INDEX_NAME = UPPER(v_indexName);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      -- If the index doesn't exist, exit the procedure
      RETURN;
  END;

  -- Drop the index if it exists
  query := 'DROP INDEX ' || v_indexName;
  EXECUTE IMMEDIATE query;
END DROP_INDEX;


--
-- Procedure DROP_NOT_NULL_CONSTRAINT
-- Drop a NOT NULL constraint from a column on a table.
--
PROCEDURE DROP_NOT_NULL_CONSTRAINT (
  v_TableName IN VARCHAR2,
  v_ColumnName IN VARCHAR2
)
IS
  query NCLOB;
BEGIN
  -- Drop the NOT NULL constraint if it exists
  query := 'ALTER TABLE ' || v_TableName || ' MODIFY ' || v_ColumnName || ' NULL';
  EXECUTE IMMEDIATE query;
EXCEPTION
    WHEN OTHERS THEN
        NULL; -- Ignore errors, such as if the column is already nullable
END DROP_NOT_NULL_CONSTRAINT;


--
-- Procedure DROP_UNIQUE_CONSTRAINT
--
-- Drops the specified unique key constraint with verification that the constraint exists.
--
PROCEDURE DROP_UNIQUE_CONSTRAINT (
  v_constraintName IN VARCHAR2
)
IS
  v_tableName VARCHAR2(128);
  query NCLOB;
BEGIN
  -- Check if the constraint exists and get the table name
  BEGIN
    SELECT TABLE_NAME INTO v_tableName FROM ALL_CONSTRAINTS WHERE OWNER = schema_name AND CONSTRAINT_NAME = UPPER(v_constraintName);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      -- If the constraint doesn't exist, exit the procedure
      RETURN;
  END;

  -- Drop the constraint if it exists
  query := 'ALTER TABLE ' || v_tableName || ' DROP CONSTRAINT ' || v_constraintName;
  EXECUTE IMMEDIATE query;

  DROP_INDEX(v_constraintName);
END DROP_UNIQUE_CONSTRAINT;


BEGIN

--
-- Alter session to set the current schema.
-- For Liquibase deployments, the defaultSchemaName property is set in the liquibase.properties file. So, the ALTER SESSION statement is not needed.
IF schema_name IS NOT NULL THEN
  EXECUTE IMMEDIATE 'ALTER SESSION SET CURRENT_SCHEMA = ' || schema_name;
END IF;

DROP_TABLE('CODE');
DROP_TABLE('CODE_FILE');
DROP_TABLE('CODE_THRESHOLD');
DROP_TABLE('PRODUCT_CONFIG');
DROP_TABLE('PRODUCT_PREFERENCE');
DROP_TABLE('FISCAL_CALENDAR');
DROP_TABLE('FISCAL_CALENDAR_HOLIDAY');
DROP_TABLE('FISCAL_CALENDAR_PERIOD');
DROP_TABLE('FISCAL_CALENDAR_SET');
DROP_TABLE('FISCAL_CALENDAR_SET_LABEL');
DROP_TABLE('PROJECT');
DROP_TABLE('PROJECT_AUDIT_LOG');
DROP_TABLE('PROJECT_AUDIT_LOG_ACCOUNTS');
DROP_TABLE('PROJECT_AUDIT_LOG_HISTORY');
DROP_TABLE('PROJECT_AUDIT_LOG_TPHASE');
DROP_TABLE('PROJECT_CALC_RESULT');
DROP_TABLE('PROJECT_CAWP');
DROP_TABLE('PROJECT_CAWP_RESOURCE');
DROP_TABLE('PROJECT_CAWP_RESOURCE_TPHASE');
DROP_TABLE('PROJECT_CAWP_TOTAL');
DROP_TABLE('PROJECT_CONTROL_ACCOUNT');
DROP_TABLE('PROJECT_WORK_PACKAGE');
DROP_TABLE('PROJECT_COST_CLASS');
DROP_TABLE('PROJECT_COST_CLASS_LINK');
DROP_TABLE('PROJECT_COST_SET');
DROP_TABLE('PROJECT_COST_SET_CLASS');
DROP_TABLE('PROJECT_COST_TOTAL');
DROP_TABLE('PROJECT_SUBPROJECT');
DROP_TABLE('PROJECT_WP_MILESTONE');
DROP_TABLE('RATE');
DROP_TABLE('RATE_FILE');
DROP_TABLE('RATE_SET');
DROP_TABLE('RESOURCE_COST_CALCULATION');
DROP_TABLE('RESOURCE_FILE');
DROP_TABLE('RESOURCE_FILE_COST_RESULT');
DROP_TABLE('RESOURCES');
DROP_TABLE('SPREAD_CURVE');
DROP_TABLE('ACCESS_CONTROL_ENTRY');
DROP_TABLE('USER_CODE_VALUE');
DROP_TABLE('USER_FIELD_DEFINITION');
DROP_TABLE('USER_FIELD_VALUE');
DROP_TABLE('USER_NOTE_VALUE');
DROP_TABLE('ACCOUNTS');
DROP_TABLE('CHNG_REQST');
DROP_TABLE('CHNG_REQST_PROGRAM');
DROP_TABLE('CLASSRANGES');
DROP_TABLE('CONNECTION');
DROP_TABLE('COSTDETL');
DROP_TABLE('LINK');
DROP_TABLE('PROCESSLOG');
DROP_TABLE('PROCESSLOGLINK');
DROP_TABLE('RCUTOFF');
DROP_TABLE('TEMP_CAWPID');
DROP_TABLE('TEMP_CHAR');
DROP_TABLE('TEMP_DIR');
DROP_TABLE('WST_LCK');
DROP_TABLE('WST_DCT');
DROP_TABLE('BATCH');
DROP_TABLE('BATCHREP');
DROP_TABLE('PROJECT_CONTROL_ACCOUNT_TOTAL');
DROP_TABLE('PROJECT_WORK_PACKAGE_TOTAL');

-- Create table CODE
CREATE_TABLE(
 'CODE',
 'CREATE TABLE CODE (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    CODE_FILE_UID RAW(16) NOT NULL,
    PARENT_CODE_UID RAW(16),
    NAME NVARCHAR2(100) NOT NULL,
    CODE_LEVEL NUMBER(5,0) DEFAULT (1),
    CHILD_COUNT NUMBER(5,0) DEFAULT (0),
    CHILD_POS NUMBER(5,0) DEFAULT (0),
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    DESCRIPTION NVARCHAR2(256),
    D1 NVARCHAR2(59),
    D2 NVARCHAR2(59),
    D3 NVARCHAR2(59),
    D4 NVARCHAR2(59),
    D5 NVARCHAR2(59),
    D6 NVARCHAR2(59),
    D7 NVARCHAR2(59),
    D8 NVARCHAR2(59),
    D9 NVARCHAR2(59),
    TAG VARCHAR2(60),
    BREAKFILE NVARCHAR2(22)
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('CODE', 'ROW_UID');
CREATE_NATURAL_KEY('CODE', 'CODE_FILE_UID, PARENT_CODE_UID, NAME');

ADD_COLUMN_COMMENT('CODE', 'ROW_UID', 'Unique Code Identifier.');
ADD_COLUMN_COMMENT('CODE', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('CODE', 'CODE_FILE_UID', 'Unique Identifier of the Code File record.');
ADD_COLUMN_COMMENT('CODE', 'PARENT_CODE_UID', 'Unique Identifier of the Parent Code record.');
ADD_COLUMN_COMMENT('CODE', 'NAME', 'Code Name.');
ADD_COLUMN_COMMENT('CODE', 'CODE_LEVEL', 'Code hierarchy level.');
ADD_COLUMN_COMMENT('CODE', 'CHILD_COUNT', 'Parent Code child count.');
ADD_COLUMN_COMMENT('CODE', 'CHILD_POS', 'Child Code position.');
ADD_COLUMN_COMMENT('CODE', 'CREATED_BY_USER_UID', 'The User that created the Code.');
ADD_COLUMN_COMMENT('CODE', 'CREATED_DATE', 'Date the Code was created.');
ADD_COLUMN_COMMENT('CODE', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Code.');
ADD_COLUMN_COMMENT('CODE', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Code.');
ADD_COLUMN_COMMENT('CODE', 'DESCRIPTION', 'Code Description.');

-- Create table CODE_FILE
CREATE_TABLE(
 'CODE_FILE',
 'CREATE TABLE CODE_FILE (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    NAME NVARCHAR2(100),
    CODE_TYPE VARCHAR2(1) NOT NULL,
    TH_FLAGS VARCHAR2(10) DEFAULT (''NNNNNNNNNN'') NOT NULL,
    DESCRIPTION NVARCHAR2(256),
    FIELD_NAME NVARCHAR2(30) NOT NULL,
    FIELD_DESCRIPTION NVARCHAR2(256),
    OWNER_USER_UID RAW(16) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    PAD_CHAR VARCHAR2(1),
    MAX_LEVEL NUMBER(19,0) DEFAULT (0),
    LEVEL1 NUMBER(19,0) DEFAULT (0),
    LEVEL2 NUMBER(19,0) DEFAULT (0),
    LEVEL3 NUMBER(19,0) DEFAULT (0),
    LEVEL4 NUMBER(19,0) DEFAULT (0),
    LEVEL5 NUMBER(19,0) DEFAULT (0),
    LEVEL6 NUMBER(19,0) DEFAULT (0),
    LEVEL7 NUMBER(19,0) DEFAULT (0),
    LEVEL8 NUMBER(19,0) DEFAULT (0),
    LEVEL9 NUMBER(19,0) DEFAULT (0),
    LEVEL10 NUMBER(19,0) DEFAULT (0),
    LEVEL11 NUMBER(19,0) DEFAULT (0),
    LEVEL12 NUMBER(19,0) DEFAULT (0),
    LEVEL13 NUMBER(19,0) DEFAULT (0),
    LEVEL14 NUMBER(19,0) DEFAULT (0),
    LEVEL15 NUMBER(19,0) DEFAULT (0),
    LEVEL16 NUMBER(19,0) DEFAULT (0),
    LEVEL17 NUMBER(19,0) DEFAULT (0),
    LEVEL18 NUMBER(19,0) DEFAULT (0),
    LEVEL19 NUMBER(19,0) DEFAULT (0),
    LEVEL20 NUMBER(19,0) DEFAULT (0),
    CODELENGTH NUMBER(19,0) DEFAULT (0)
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('CODE_FILE', 'ROW_UID');
CREATE_NATURAL_KEY('CODE_FILE', 'NAME');

ADD_COLUMN_COMMENT('CODE_FILE', 'ROW_UID', 'Unique Code File Identifier.');
ADD_COLUMN_COMMENT('CODE_FILE', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('CODE_FILE', 'NAME', 'Code File Name.');
ADD_COLUMN_COMMENT('CODE_FILE', 'CODE_TYPE', 'Code File Code Type. Supported values are P or N.');
ADD_COLUMN_COMMENT('CODE_FILE', 'TH_FLAGS', 'Flags to enable Code Threshold Variance options.');
ADD_COLUMN_COMMENT('CODE_FILE', 'DESCRIPTION', 'Code File Description.');
ADD_COLUMN_COMMENT('CODE_FILE', 'FIELD_NAME', 'Default User Field Name when this Code File is assigned to a User Define Field.');
ADD_COLUMN_COMMENT('CODE_FILE', 'FIELD_DESCRIPTION', 'Default Field Description when this Code File is assigned to a User Define Field.');
ADD_COLUMN_COMMENT('CODE_FILE', 'OWNER_USER_UID', 'The User that owns the Code File.');
ADD_COLUMN_COMMENT('CODE_FILE', 'CREATED_BY_USER_UID', 'The User that created the Code File.');
ADD_COLUMN_COMMENT('CODE_FILE', 'CREATED_DATE', 'Date the Code File was created.');
ADD_COLUMN_COMMENT('CODE_FILE', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Code File.');
ADD_COLUMN_COMMENT('CODE_FILE', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Code File.');
ADD_COLUMN_COMMENT('CODE_FILE', 'PAD_CHAR', 'Padding Character');
ADD_COLUMN_COMMENT('CODE_FILE', 'MAX_LEVEL', 'Maximum Level');
ADD_COLUMN_COMMENT('CODE_FILE', 'LEVEL1', 'Level 1');
ADD_COLUMN_COMMENT('CODE_FILE', 'LEVEL2', 'Level 2');
ADD_COLUMN_COMMENT('CODE_FILE', 'LEVEL3', 'Level 3');
ADD_COLUMN_COMMENT('CODE_FILE', 'LEVEL4', 'Level 4');
ADD_COLUMN_COMMENT('CODE_FILE', 'LEVEL5', 'Level 5');
ADD_COLUMN_COMMENT('CODE_FILE', 'LEVEL6', 'Level 6');
ADD_COLUMN_COMMENT('CODE_FILE', 'LEVEL7', 'Level 7');
ADD_COLUMN_COMMENT('CODE_FILE', 'LEVEL8', 'Level 8');
ADD_COLUMN_COMMENT('CODE_FILE', 'LEVEL9', 'Level 9');
ADD_COLUMN_COMMENT('CODE_FILE', 'LEVEL10', 'Level 10');
ADD_COLUMN_COMMENT('CODE_FILE', 'LEVEL11', 'Level 11');
ADD_COLUMN_COMMENT('CODE_FILE', 'LEVEL12', 'Level 12');
ADD_COLUMN_COMMENT('CODE_FILE', 'LEVEL13', 'Level 13');
ADD_COLUMN_COMMENT('CODE_FILE', 'LEVEL14', 'Level 14');
ADD_COLUMN_COMMENT('CODE_FILE', 'LEVEL15', 'Level 15');
ADD_COLUMN_COMMENT('CODE_FILE', 'LEVEL16', 'Level 16');
ADD_COLUMN_COMMENT('CODE_FILE', 'LEVEL17', 'Level 17');
ADD_COLUMN_COMMENT('CODE_FILE', 'LEVEL18', 'Level 18');
ADD_COLUMN_COMMENT('CODE_FILE', 'LEVEL19', 'Level 19');
ADD_COLUMN_COMMENT('CODE_FILE', 'LEVEL20', 'Level 20');
ADD_COLUMN_COMMENT('CODE_FILE', 'CODELENGTH', 'Code Length');

-- Create table CODE_THRESHOLD
CREATE_TABLE(
 'CODE_THRESHOLD',
 'CREATE TABLE CODE_THRESHOLD (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    SPVF NUMBER(21,6) DEFAULT (0) NOT NULL,
    SPVU NUMBER(21,6) DEFAULT (0) NOT NULL,
    SPPF NUMBER(5,2) DEFAULT (0) NOT NULL,
    SPPU NUMBER(5,2) DEFAULT (0) NOT NULL,
    SCVF NUMBER(21,6) DEFAULT (0) NOT NULL,
    SCVU NUMBER(21,6) DEFAULT (0) NOT NULL,
    SCPF NUMBER(5,2) DEFAULT (0) NOT NULL,
    SCPU NUMBER(5,2) DEFAULT (0) NOT NULL,
    CPVF NUMBER(21,6) DEFAULT (0) NOT NULL,
    CPVU NUMBER(21,6) DEFAULT (0) NOT NULL,
    CPPF NUMBER(5,2) DEFAULT (0) NOT NULL,
    CPPU NUMBER(5,2) DEFAULT (0) NOT NULL,
    CCVF NUMBER(21,6) DEFAULT (0) NOT NULL,
    CCVU NUMBER(21,6) DEFAULT (0) NOT NULL,
    CCPF NUMBER(5,2) DEFAULT (0) NOT NULL,
    CCPU NUMBER(5,2) DEFAULT (0) NOT NULL,
    CAVF NUMBER(21,6) DEFAULT (0) NOT NULL,
    CAVU NUMBER(21,6) DEFAULT (0) NOT NULL,
    CAPF NUMBER(5,2) DEFAULT (0) NOT NULL,
    CAPU NUMBER(5,2) DEFAULT (0) NOT NULL,
    SPF_TL VARCHAR2(3),
    SPU_TL VARCHAR2(3),
    SCF_TL VARCHAR2(3),
    SCU_TL VARCHAR2(3),
    CPF_TL VARCHAR2(3),
    CPU_TL VARCHAR2(3),
    CCF_TL VARCHAR2(3),
    CCU_TL VARCHAR2(3),
    CAF_TL VARCHAR2(3),
    CAU_TL VARCHAR2(3)
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('CODE_THRESHOLD', 'ROW_UID');

ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'ROW_UID', 'Unique Code Threshold Identifier.');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'SPVF', 'Threshold SV Value Current Period Favorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'SPVU', 'Threshold SV Value Current Period Unfavorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'SPPF', 'Threshold SV % Current Period Favorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'SPPU', 'Threshold SV % Current Period Unfavorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'SCVF', 'Threshold SV Value Cumulative Favorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'SCVU', 'Threshold SV Value Cumulative Unfavorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'SCPF', 'Threshold SV % Cumulative Favorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'SCPU', 'Threshold SV % Cumulative Unfavorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'CPVF', 'Threshold CV Value Current Period Favorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'CPVU', 'Threshold CV Value Current Period Unfavorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'CPPF', 'Threshold CV % Current Period Favorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'CPPU', 'Threshold CV % Current Period Unfavorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'CCVF', 'Threshold CV Value Cumulative Favorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'CCVU', 'Threshold CV Value Cumulative Unfavorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'CCPF', 'Threshold CV % Cumulative Favorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'CCPU', 'Threshold CV % Cumulative Unfavorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'CAVF', 'Threshold CV Value At Complete Favorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'CAVU', 'Threshold CV Value At Complete Unfavorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'CAPF', 'Threshold CV % At Complete Favorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'CAPU', 'Threshold CV % At Complete Unfavorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'SPF_TL', 'Threshold Logic SV Current Period Favorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'SPU_TL', 'Threshold Logic SV Current Period Unfavorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'SCF_TL', 'Threshold Logic SV Cumulative Favorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'SCU_TL', 'Threshold Logic SV Cumulative Unfavorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'CPF_TL', 'Threshold Logic CV Current Period Favorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'CPU_TL', 'Threshold Logic CV Current Period Unfavorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'CCF_TL', 'Threshold Logic CV Cumulative Favorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'CCU_TL', 'Threshold Logic CV Cumulative Unfavorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'CAF_TL', 'Threshold Logic CV At Complete Favorable');
ADD_COLUMN_COMMENT('CODE_THRESHOLD', 'CAU_TL', 'Threshold Logic CV At Complete Unfavorable');

-- Create table PRODUCT_CONFIG
CREATE_TABLE(
 'PRODUCT_CONFIG',
 'CREATE TABLE PRODUCT_CONFIG (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    PRODUCT_ID NUMBER(5,0) DEFAULT (0) NOT NULL,
    TYPE VARCHAR2(30) NOT NULL,
    NAME NVARCHAR2(100) NOT NULL,
    OWNER_USER_UID RAW(16),
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    DESCRIPTION NVARCHAR2(256),
    DATA NCLOB
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PRODUCT_CONFIG', 'ROW_UID');

ADD_COLUMN_COMMENT('PRODUCT_CONFIG', 'ROW_UID', 'Unique Product Setting  Identifier.');
ADD_COLUMN_COMMENT('PRODUCT_CONFIG', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('PRODUCT_CONFIG', 'PRODUCT_ID', 'Product ID that the Product Setting is associate with. 0 If Product Setting is not Product specific.');
ADD_COLUMN_COMMENT('PRODUCT_CONFIG', 'TYPE', 'Config Type');
ADD_COLUMN_COMMENT('PRODUCT_CONFIG', 'NAME', 'Product Setting Name');
ADD_COLUMN_COMMENT('PRODUCT_CONFIG', 'OWNER_USER_UID', 'The User that owns the Product Config.');
ADD_COLUMN_COMMENT('PRODUCT_CONFIG', 'CREATED_BY_USER_UID', 'The User that created the Product Config.');
ADD_COLUMN_COMMENT('PRODUCT_CONFIG', 'CREATED_DATE', 'Date the Product Config was created.');
ADD_COLUMN_COMMENT('PRODUCT_CONFIG', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Product Config.');
ADD_COLUMN_COMMENT('PRODUCT_CONFIG', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Product Config.');
ADD_COLUMN_COMMENT('PRODUCT_CONFIG', 'DESCRIPTION', 'Product Setting Description.');
ADD_COLUMN_COMMENT('PRODUCT_CONFIG', 'DATA', 'Product Setting data value.');

-- Create table PRODUCT_PREFERENCE
CREATE_TABLE(
 'PRODUCT_PREFERENCE',
 'CREATE TABLE PRODUCT_PREFERENCE (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    PRODUCT_ID NUMBER(5,0) DEFAULT (0),
    PRIMARY_ENTITY_UID RAW(16),
    LAST_MODIFIED_BY_USER_UID RAW(16),
    NAME VARCHAR2(60) NOT NULL,
    DATA VARCHAR2(2048) NOT NULL,
    SECURE NUMBER(1,0) DEFAULT (0) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    OWNER_USER_UID RAW(16),
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    DESCRIPTION NVARCHAR2(256)
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PRODUCT_PREFERENCE', 'ROW_UID');
CREATE_NATURAL_KEY('PRODUCT_PREFERENCE', 'PRODUCT_ID, PRIMARY_ENTITY_UID, LAST_MODIFIED_BY_USER_UID, NAME');

ADD_COLUMN_COMMENT('PRODUCT_PREFERENCE', 'ROW_UID', 'Unique Preferences Identifier.');
ADD_COLUMN_COMMENT('PRODUCT_PREFERENCE', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('PRODUCT_PREFERENCE', 'PRODUCT_ID', 'Product ID that the Product Preference is associate with. 0 If preference is not Product specific.');
ADD_COLUMN_COMMENT('PRODUCT_PREFERENCE', 'PRIMARY_ENTITY_UID', 'Unique Identifier for the Root Parent Entity  the Product Preference is associated with. NULL if preference is not associated with a Primary Entity.');
ADD_COLUMN_COMMENT('PRODUCT_PREFERENCE', 'LAST_MODIFIED_BY_USER_UID', 'User that the Product preference is associated with. NULL if the preference is not User specific.');
ADD_COLUMN_COMMENT('PRODUCT_PREFERENCE', 'NAME', 'Product Preference Name.');
ADD_COLUMN_COMMENT('PRODUCT_PREFERENCE', 'DATA', 'Product Preference data value.');
ADD_COLUMN_COMMENT('PRODUCT_PREFERENCE', 'SECURE', 'Identifies if the Product Preference Value is encrypted.');
ADD_COLUMN_COMMENT('PRODUCT_PREFERENCE', 'CREATED_DATE', 'Date the Product Config was created.');
ADD_COLUMN_COMMENT('PRODUCT_PREFERENCE', 'CREATED_BY_USER_UID', 'The User that created the Product Config.');
ADD_COLUMN_COMMENT('PRODUCT_PREFERENCE', 'OWNER_USER_UID', 'The User that owns the Product Config.');
ADD_COLUMN_COMMENT('PRODUCT_PREFERENCE', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Product preference.');
ADD_COLUMN_COMMENT('PRODUCT_PREFERENCE', 'DESCRIPTION', 'Product preference Description.');

-- Create table FISCAL_CALENDAR
CREATE_TABLE(
 'FISCAL_CALENDAR',
 'CREATE TABLE FISCAL_CALENDAR (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    NAME NVARCHAR2(100) NOT NULL,
    DESCRIPTION NVARCHAR2(256),
    HOURS_MONDAY NUMBER(6,2) DEFAULT (0) NOT NULL,
    HOURS_TUESDAY NUMBER(6,2) DEFAULT (0) NOT NULL,
    HOURS_WEDNESDAY NUMBER(6,2) DEFAULT (0) NOT NULL,
    HOURS_THURSDAY NUMBER(6,2) DEFAULT (0) NOT NULL,
    HOURS_FRIDAY NUMBER(6,2) DEFAULT (0) NOT NULL,
    HOURS_SATURDAY NUMBER(6,2) DEFAULT (0) NOT NULL,
    HOURS_SUNDAY NUMBER(6,2) DEFAULT (0) NOT NULL,
    PATTERN NVARCHAR2(256),
    OWNER_USER_UID RAW(16) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    DOW_HOURS VARCHAR2(60),
    DESC00 VARCHAR2(254),
    DESC01 VARCHAR2(254),
    DESC02 VARCHAR2(254),
    DESC03 VARCHAR2(254),
    DESC04 VARCHAR2(254),
    DESC05 VARCHAR2(254),
    DESC06 VARCHAR2(254),
    DESC07 VARCHAR2(254),
    DESC08 VARCHAR2(254),
    DESC09 VARCHAR2(254),
    DESC10 VARCHAR2(254),
    DESC11 VARCHAR2(254),
    DESC12 VARCHAR2(254),
    DESC13 VARCHAR2(254),
    DESC14 VARCHAR2(254),
    DESC15 VARCHAR2(254),
    DESC16 VARCHAR2(254),
    DESC17 VARCHAR2(254),
    DESC18 VARCHAR2(254),
    DESC19 VARCHAR2(254)
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('FISCAL_CALENDAR', 'ROW_UID');
CREATE_NATURAL_KEY('FISCAL_CALENDAR', 'NAME');

ADD_COLUMN_COMMENT('FISCAL_CALENDAR', 'ROW_UID', 'Unique Fiscal Calendar Identifier.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR', 'NAME', 'Fiscal Calendar Name.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR', 'DESCRIPTION', 'Fiscal Calendar Description.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR', 'HOURS_MONDAY', 'Working Hours for Monday.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR', 'HOURS_TUESDAY', 'Working Hours for Tuesday.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR', 'HOURS_WEDNESDAY', 'Working Hours for Wednesday.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR', 'HOURS_THURSDAY', 'Working Hours for Thursday.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR', 'HOURS_FRIDAY', 'Working Hours for Friday.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR', 'HOURS_SATURDAY', 'Working Hours for Saturday.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR', 'HOURS_SUNDAY', 'Working Hours for Sunday.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR', 'PATTERN', 'Pattern definition for generating Fiscal Calendar Periods.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR', 'OWNER_USER_UID', 'The User that owns the Fiscal Calendar.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR', 'CREATED_BY_USER_UID', 'The User that created the Fiscal Calendar.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR', 'CREATED_DATE', 'Date the Fiscal Calendar was created.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Fiscal Calendar.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Fiscal Calendar.');

-- Create table FISCAL_CALENDAR_HOLIDAY
CREATE_TABLE(
 'FISCAL_CALENDAR_HOLIDAY',
 'CREATE TABLE FISCAL_CALENDAR_HOLIDAY (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    FISCAL_CALENDAR_UID RAW(16) NOT NULL,
    HOLIDAY_DATE DATE NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    DESCRIPTION NVARCHAR2(256)
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('FISCAL_CALENDAR_HOLIDAY', 'ROW_UID');
CREATE_NATURAL_KEY('FISCAL_CALENDAR_HOLIDAY', 'FISCAL_CALENDAR_UID, HOLIDAY_DATE');

ADD_COLUMN_COMMENT('FISCAL_CALENDAR_HOLIDAY', 'ROW_UID', 'Unique Fiscal Holiday Identifier.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_HOLIDAY', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_HOLIDAY', 'FISCAL_CALENDAR_UID', 'Unique Fiscal Calendar Identifier.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_HOLIDAY', 'HOLIDAY_DATE', 'Fiscal Calendar Holiday Date.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_HOLIDAY', 'CREATED_BY_USER_UID', 'The User that created the Fiscal Calendar Holiday.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_HOLIDAY', 'CREATED_DATE', 'Date the Fiscal Calendar Holiday was created.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_HOLIDAY', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Fiscal Calendar Holiday.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_HOLIDAY', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Fiscal Calendar Holiday.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_HOLIDAY', 'DESCRIPTION', 'Fiscal Holiday Entity Description.');

-- Create table FISCAL_CALENDAR_PERIOD
CREATE_TABLE(
 'FISCAL_CALENDAR_PERIOD',
 'CREATE TABLE FISCAL_CALENDAR_PERIOD (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    FISCAL_CALENDAR_UID RAW(16) NOT NULL,
    END_DATE DATE NOT NULL,
    HOURS NUMBER(6,2) DEFAULT (0) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    FISCFILE NVARCHAR2(22),
    FIELD00 NVARCHAR2(20),
    FIELD01 NVARCHAR2(20),
    FIELD02 NVARCHAR2(20),
    FIELD03 NVARCHAR2(20),
    FIELD04 NVARCHAR2(20),
    FIELD05 NVARCHAR2(20),
    FIELD06 NVARCHAR2(20),
    FIELD07 NVARCHAR2(20),
    FIELD08 NVARCHAR2(20),
    FIELD09 NVARCHAR2(20),
    FIELD10 NVARCHAR2(20),
    FIELD11 NVARCHAR2(20),
    FIELD12 NVARCHAR2(20),
    FIELD13 NVARCHAR2(20),
    FIELD14 NVARCHAR2(20),
    FIELD15 NVARCHAR2(20),
    FIELD16 NVARCHAR2(20),
    FIELD17 NVARCHAR2(20),
    FIELD18 NVARCHAR2(20),
    FIELD19 NVARCHAR2(20),
    FLAG01 NVARCHAR2(20),
    FLAG02 NVARCHAR2(20),
    FLAG03 NVARCHAR2(20),
    FLAG04 NVARCHAR2(20),
    FLAG05 NVARCHAR2(20),
    FLAG06 NVARCHAR2(20),
    FLAG07 NVARCHAR2(20),
    FLAG08 NVARCHAR2(20),
    FLAG09 NVARCHAR2(20),
    FLAG10 NVARCHAR2(20),
    FLAG11 NVARCHAR2(20),
    FLAG12 NVARCHAR2(20),
    FLAG13 NVARCHAR2(20),
    FLAG14 NVARCHAR2(20),
    FLAG15 NVARCHAR2(20),
    FLAG16 NVARCHAR2(20),
    FLAG17 NVARCHAR2(20),
    FLAG18 NVARCHAR2(20),
    FLAG19 NVARCHAR2(20)
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('FISCAL_CALENDAR_PERIOD', 'ROW_UID');
CREATE_NATURAL_KEY('FISCAL_CALENDAR_PERIOD', 'FISCAL_CALENDAR_UID, END_DATE');

ADD_COLUMN_COMMENT('FISCAL_CALENDAR_PERIOD', 'ROW_UID', 'Unique Fiscal Period Identifier.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_PERIOD', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_PERIOD', 'FISCAL_CALENDAR_UID', 'Unique Fiscal Calendar Identifier.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_PERIOD', 'END_DATE', 'Fiscal Calendar Period End date.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_PERIOD', 'HOURS', 'Working hours in Fiscal Calendar Period.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_PERIOD', 'CREATED_BY_USER_UID', 'The User that created the Fiscal Calendar Period.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_PERIOD', 'CREATED_DATE', 'Date the Fiscal Calendar Period was created.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_PERIOD', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Fiscal Calendar Period.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_PERIOD', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Fiscal Calendar Period.');

-- Create table FISCAL_CALENDAR_SET
CREATE_TABLE(
 'FISCAL_CALENDAR_SET',
 'CREATE TABLE FISCAL_CALENDAR_SET (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    FISCAL_CALENDAR_UID RAW(16) NOT NULL,
    SET_ID NVARCHAR2(5) NOT NULL,
    LABEL_FORMAT NVARCHAR2(20) DEFAULT (''MM/dd/yy''),
    LABEL_VALUE NVARCHAR2(15),
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    DESCRIPTION NVARCHAR2(256)
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('FISCAL_CALENDAR_SET', 'ROW_UID');
CREATE_NATURAL_KEY('FISCAL_CALENDAR_SET', 'FISCAL_CALENDAR_UID, SET_ID');

ADD_COLUMN_COMMENT('FISCAL_CALENDAR_SET', 'ROW_UID', 'Unique Fiscal Calendar Set Identifier.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_SET', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_SET', 'FISCAL_CALENDAR_UID', 'Unique Fiscal Calendar Identifier.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_SET', 'SET_ID', 'System generated Fiscal Calendar Set name.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_SET', 'LABEL_FORMAT', 'Fiscal Calendar Label Format');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_SET', 'LABEL_VALUE', 'Fiscal Calendar Label Value for Label Format of Counter.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_SET', 'CREATED_BY_USER_UID', 'The User that created the Fiscal Calendar Set.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_SET', 'CREATED_DATE', 'Date the Fiscal Calendar Set was created.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_SET', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Fiscal Calendar Set.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_SET', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Fiscal Calendar Set.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_SET', 'DESCRIPTION', 'Fiscal Calendar Set Description.');

-- Create table FISCAL_CALENDAR_SET_LABEL
CREATE_TABLE(
 'FISCAL_CALENDAR_SET_LABEL',
 'CREATE TABLE FISCAL_CALENDAR_SET_LABEL (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    FISCAL_CALENDAR_SET_UID RAW(16) NOT NULL,
    FISCAL_CALENDAR_PERIOD_UID RAW(16) NOT NULL,
    LABEL NVARCHAR2(20),
    FLAG VARCHAR2(1),
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('FISCAL_CALENDAR_SET_LABEL', 'ROW_UID');
CREATE_NATURAL_KEY('FISCAL_CALENDAR_SET_LABEL', 'FISCAL_CALENDAR_SET_UID, FISCAL_CALENDAR_PERIOD_UID, LABEL');

ADD_COLUMN_COMMENT('FISCAL_CALENDAR_SET_LABEL', 'ROW_UID', 'Unique Fiscal Calendar Set Label Identifier.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_SET_LABEL', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_SET_LABEL', 'FISCAL_CALENDAR_SET_UID', 'Unique Fiscal Calendar Set Identifier.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_SET_LABEL', 'FISCAL_CALENDAR_PERIOD_UID', 'Unique Fiscal Calendar Period Identifier.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_SET_LABEL', 'LABEL', 'User entered label for a Fiscal Set Period.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_SET_LABEL', 'FLAG', 'Identifies if a Fiscal Set Period  is Floating or Fixed.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_SET_LABEL', 'CREATED_BY_USER_UID', 'The User that created the Fiscal Calendar Set Label.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_SET_LABEL', 'CREATED_DATE', 'Date the Fiscal Calendar Set Label was created.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_SET_LABEL', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Fiscal Calendar Set Label.');
ADD_COLUMN_COMMENT('FISCAL_CALENDAR_SET_LABEL', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Fiscal Calendar Set Label.');

-- Create table PROJECT
CREATE_TABLE(
 'PROJECT',
 'CREATE TABLE PROJECT (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    INACTIVE NUMBER(1,0) DEFAULT (0) NOT NULL,
    NAME NVARCHAR2(100) NOT NULL,
    DESCRIPTION NVARCHAR2(256),
    WBS_CODE_FILE_UID RAW(16),
    OBS_CODE_FILE_UID RAW(16),
    CHANGE_NUMBER_CODE_FILE_UID RAW(16),
    CLIN_CODE_FILE_UID RAW(16),
    FISCAL_CALENDAR_UID RAW(16),
    RESOURCE_FILE_UID RAW(16),
    RATE_FILE_UID RAW(16),
    RW_FISCAL_CALENDAR_UID RAW(16),
    PERIOD_START DATE NOT NULL,
    PERIOD_END DATE NOT NULL,
    SPTYPE NUMBER(5,0) DEFAULT (0),
    AUDIT_LOG_LEVEL VARCHAR2(3),
    SCALECAP VARCHAR2(20),
    BASELINE_START DATE NOT NULL,
    BASELINE_FINISH DATE NOT NULL,
    FORECAST_FINISH DATE NOT NULL,
    SCALEFAC NUMBER(5,0) DEFAULT (0),
    FEE_PRCENT NUMBER(21,6) DEFAULT (0),
    CTC NUMBER(21,6) DEFAULT (0),
    AUW NUMBER(21,6) DEFAULT (0),
    OTC NUMBER(21,6) DEFAULT (0),
    CBB NUMBER(21,6) DEFAULT (0),
    FEE NUMBER(21,6) DEFAULT (0),
    MR NUMBER(21,6) DEFAULT (0),
    UB NUMBER(21,6) DEFAULT (0),
    CEILING NUMBER(21,6) DEFAULT (0),
    LRE NUMBER(21,6) DEFAULT (0),
    ESTCEILING NUMBER(21,6) DEFAULT (0),
    ESTMR NUMBER(21,6) DEFAULT (0),
    ESTUB NUMBER(21,6) DEFAULT (0),
    BASELINED NUMBER(1,0) DEFAULT (0) NOT NULL,
    OTB NUMBER(21,6) DEFAULT (0),
    CCN_USEBDN NUMBER(1,0) DEFAULT (0) NOT NULL,
    CCN_REQUIRED NUMBER(1,0) DEFAULT (0) NOT NULL,
    CAM_REQUIRED NUMBER(1,0) DEFAULT (0) NOT NULL,
    CLASSIFICATION VARCHAR2(60),
    EVMS_ACCEPTANCE NUMBER(10,0) DEFAULT (0),
    EVMS_ACCEPTANCE_DATE DATE,
    OTB_DATE DATE,
    EAC_BEST NUMBER(21,6) DEFAULT (0),
    EAC_WORST NUMBER(21,6) DEFAULT (0),
    COMPLETE DATE,
    DEFINITE DATE,
    CURRENCY_SYMBOL VARCHAR2(6),
    CURRENCY_SYMBOL_RIGHT NUMBER(1,0) DEFAULT (0) NOT NULL,
    ESTPRICE NUMBER(21,6) DEFAULT (0),
    OTB_MR NUMBER(21,6) DEFAULT (0),
    ACWP NUMBER(21,6) DEFAULT (0) NOT NULL,
    ACWP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    ADDRESS VARCHAR2(70) DEFAULT ('' ''),
    BAC NUMBER(21,6) DEFAULT (0) NOT NULL,
    BAC_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BATCHNO NUMBER(19,0) DEFAULT (0) NOT NULL,
    BCWP NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWS_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    CA_ACTUAL VARCHAR2(1) DEFAULT ('' ''),
    CA_BD1 VARCHAR2(22),
    CA_BD2 VARCHAR2(22),
    CA_BD3 VARCHAR2(22),
    CA_ID1 VARCHAR2(10) DEFAULT ('' ''),
    CA_ID2 VARCHAR2(10) DEFAULT ('' ''),
    CA_ID3 VARCHAR2(10) DEFAULT ('' ''),
    CALC_FILE VARCHAR2(22) DEFAULT ('' ''),
    CAMCODE VARCHAR2(59),
    CCN_BDN VARCHAR2(22) DEFAULT ('' ''),
    CE_BDN VARCHAR2(22) DEFAULT ('' ''),
    CE_ID VARCHAR2(22) DEFAULT ('' ''),
    CITY VARCHAR2(30),
    CLC_PROMPT VARCHAR2(20) DEFAULT ('' ''),
    CLIN_CODE VARCHAR2(30),
    CONT_FLAG VARCHAR2(1) DEFAULT ('' ''),
    CONT_IDCODE VARCHAR2(20),
    CONT_IDTYPE VARCHAR2(15),
    CONT_LOC VARCHAR2(40) DEFAULT ('' ''),
    CONT_NAME VARCHAR2(250) DEFAULT ('' ''),
    CONT_NO VARCHAR2(100) DEFAULT ('' ''),
    CONT_PHASE VARCHAR2(20) DEFAULT ('' ''),
    CONT_PROGRAM VARCHAR2(80),
    CONT_PROGTYPE VARCHAR2(2) DEFAULT (''D''),
    CONT_REPEMAIL VARCHAR2(60),
    CONT_REPN VARCHAR2(60) DEFAULT ('' ''),
    CONT_REPPHONE VARCHAR2(20),
    CONT_REPT VARCHAR2(60) DEFAULT ('' ''),
    CONT_STATEMENT VARCHAR2(100),
    CONT_TASK VARCHAR2(80),
    CONT_TYPE VARCHAR2(10) DEFAULT ('' ''),
    CONTRACT VARCHAR2(100) DEFAULT ('' ''),
    COUNTRY VARCHAR2(20),
    EAC NUMBER(21,6) DEFAULT (0) NOT NULL,
    EAC_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    FC_TYPE1 VARCHAR2(1) DEFAULT ('' ''),
    FC_TYPE2 VARCHAR2(1) DEFAULT ('' ''),
    FC_TYPE3 VARCHAR2(1) DEFAULT ('' ''),
    FC_TYPE4 VARCHAR2(1) DEFAULT ('' ''),
    FISC_FILE VARCHAR2(22) DEFAULT ('' ''),
    FISC_RW VARCHAR2(22) DEFAULT ('' ''),
    IPMR2_CODE VARCHAR2(30),
    ISMASTER NUMBER(19,0) DEFAULT (0) NOT NULL,
    MGRFILE VARCHAR2(22),
    MGRTYPE VARCHAR2(1) DEFAULT ('' ''),
    MPSCODE VARCHAR2(59) DEFAULT ('' ''),
    OPP_PROJ VARCHAR2(255) DEFAULT ('' ''),
    P1 VARCHAR2(59),
    P2 VARCHAR2(59),
    P3 VARCHAR2(59),
    P4 VARCHAR2(59),
    P5 VARCHAR2(59),
    P6 VARCHAR2(59),
    P7 VARCHAR2(59),
    P8 VARCHAR2(59),
    P9 VARCHAR2(59),
    PERCENT1 NUMBER(19,0) DEFAULT (0) NOT NULL,
    PERCENT2 NUMBER(19,0) DEFAULT (0) NOT NULL,
    PERCENT3 NUMBER(19,0) DEFAULT (0) NOT NULL,
    PRODVIS NUMBER(19,0) DEFAULT (0) NOT NULL,
    PROGRAM VARCHAR2(22) DEFAULT ('' ''),
    QUANTITY NUMBER(19,0) DEFAULT (0) NOT NULL,
    RATE_FILE VARCHAR2(22) DEFAULT ('' ''),
    SHARERATIO VARCHAR2(20) DEFAULT ('' ''),
    STATE VARCHAR2(3) DEFAULT ('' ''),
    WP_BDN VARCHAR2(22) DEFAULT ('' ''),
    WP_ID VARCHAR2(10) DEFAULT ('' ''),
    ZIP VARCHAR2(11) DEFAULT ('' ''),
    OWNER_USER_UID RAW(16) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PROJECT', 'ROW_UID');
CREATE_NATURAL_KEY('PROJECT', 'NAME');

ADD_COLUMN_COMMENT('PROJECT', 'ROW_UID', 'Unique Project Identifier.');
ADD_COLUMN_COMMENT('PROJECT', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('PROJECT', 'INACTIVE', 'Project is inactive and not show in lists by default.');
ADD_COLUMN_COMMENT('PROJECT', 'NAME', 'Project Name.');
ADD_COLUMN_COMMENT('PROJECT', 'DESCRIPTION', 'Project Description.');
ADD_COLUMN_COMMENT('PROJECT', 'WBS_CODE_FILE_UID', 'Unique WBS Code File Identifier.');
ADD_COLUMN_COMMENT('PROJECT', 'OBS_CODE_FILE_UID', 'Unique OBS Code File Identifier.');
ADD_COLUMN_COMMENT('PROJECT', 'CHANGE_NUMBER_CODE_FILE_UID', 'Unique Change Number Code File Identifier.');
ADD_COLUMN_COMMENT('PROJECT', 'CLIN_CODE_FILE_UID', 'Unique CLIN Code File Identifier.');
ADD_COLUMN_COMMENT('PROJECT', 'FISCAL_CALENDAR_UID', 'Unique Fiscal Calendar Identifier.');
ADD_COLUMN_COMMENT('PROJECT', 'RESOURCE_FILE_UID', 'Unique Resource File Identifier.');
ADD_COLUMN_COMMENT('PROJECT', 'RATE_FILE_UID', 'Unique Rate File Identifier.');
ADD_COLUMN_COMMENT('PROJECT', 'RW_FISCAL_CALENDAR_UID', 'Unique Rolling Wave Fiscal Calendar Identifier.');
ADD_COLUMN_COMMENT('PROJECT', 'PERIOD_START', 'Period Start Date.');
ADD_COLUMN_COMMENT('PROJECT', 'PERIOD_END', 'Period End Date.');
ADD_COLUMN_COMMENT('PROJECT', 'SPTYPE', 'Spread Weight Method.');
ADD_COLUMN_COMMENT('PROJECT', 'AUDIT_LOG_LEVEL', 'Audit Log Level. (Control Account, Work Package, Both Control Account and Work Package)');
ADD_COLUMN_COMMENT('PROJECT', 'SCALECAP', 'Scale Caption.');
ADD_COLUMN_COMMENT('PROJECT', 'BASELINE_START', 'Baseline Start Date.');
ADD_COLUMN_COMMENT('PROJECT', 'BASELINE_FINISH', 'Baseline Finish Date.');
ADD_COLUMN_COMMENT('PROJECT', 'FORECAST_FINISH', 'Forecast Finish Date.');
ADD_COLUMN_COMMENT('PROJECT', 'SCALEFAC', 'Scale Factor.');
ADD_COLUMN_COMMENT('PROJECT', 'FEE_PRCENT', 'Fee Percent.');
ADD_COLUMN_COMMENT('PROJECT', 'CTC', 'Negotiated Cost.');
ADD_COLUMN_COMMENT('PROJECT', 'AUW', 'Authorized Unpriced Work.');
ADD_COLUMN_COMMENT('PROJECT', 'OTC', 'Original Negotiated Cost.');
ADD_COLUMN_COMMENT('PROJECT', 'CBB', 'Contract Budget Base.');
ADD_COLUMN_COMMENT('PROJECT', 'FEE', 'Fee.');
ADD_COLUMN_COMMENT('PROJECT', 'MR', 'Management Reserve.');
ADD_COLUMN_COMMENT('PROJECT', 'UB', 'Undistributed Budget.');
ADD_COLUMN_COMMENT('PROJECT', 'CEILING', 'Contract Price Ceiling.');
ADD_COLUMN_COMMENT('PROJECT', 'LRE', 'Forecast');
ADD_COLUMN_COMMENT('PROJECT', 'ESTCEILING', 'Estimated Ceiling.');
ADD_COLUMN_COMMENT('PROJECT', 'ESTMR', 'Estimated Management Reserve.');
ADD_COLUMN_COMMENT('PROJECT', 'ESTUB', 'Estimated Undistributed Budget.');
ADD_COLUMN_COMMENT('PROJECT', 'BASELINED', 'Is a Baseline Set.');
ADD_COLUMN_COMMENT('PROJECT', 'OTB', 'Negotiated Cost.');
ADD_COLUMN_COMMENT('PROJECT', 'CCN_USEBDN', 'Is Change Number Code File Used.');
ADD_COLUMN_COMMENT('PROJECT', 'CCN_REQUIRED', 'Is Change Number Code Required.');
ADD_COLUMN_COMMENT('PROJECT', 'CAM_REQUIRED', 'Control Account Manager value is required for a Control Account.');
ADD_COLUMN_COMMENT('PROJECT', 'CLASSIFICATION', 'Classification.');
ADD_COLUMN_COMMENT('PROJECT', 'EVMS_ACCEPTANCE', 'EVMS Acceptance.');
ADD_COLUMN_COMMENT('PROJECT', 'EVMS_ACCEPTANCE_DATE', 'EVMS Acceptance Date.');
ADD_COLUMN_COMMENT('PROJECT', 'OTB_DATE', 'Over Target Baseline Date.');
ADD_COLUMN_COMMENT('PROJECT', 'EAC_BEST', 'Best Case Forecast.');
ADD_COLUMN_COMMENT('PROJECT', 'EAC_WORST', 'Worst Case Forecast.');
ADD_COLUMN_COMMENT('PROJECT', 'COMPLETE', 'Complete.');
ADD_COLUMN_COMMENT('PROJECT', 'DEFINITE', 'Definitized.');
ADD_COLUMN_COMMENT('PROJECT', 'CURRENCY_SYMBOL', 'Currency Symbol.');
ADD_COLUMN_COMMENT('PROJECT', 'CURRENCY_SYMBOL_RIGHT', 'Show Currency Symbol on right.');
ADD_COLUMN_COMMENT('PROJECT', 'ESTPRICE', 'Estimated Price.');
ADD_COLUMN_COMMENT('PROJECT', 'OTB_MR', 'The OTB MR adjustment totals.');
ADD_COLUMN_COMMENT('PROJECT', 'ACWP', 'Actual Cost of Work Performed');
ADD_COLUMN_COMMENT('PROJECT', 'ACWP_HRS', 'Actual Cost of Work Performed Hours');
ADD_COLUMN_COMMENT('PROJECT', 'ADDRESS', 'Address');
ADD_COLUMN_COMMENT('PROJECT', 'BAC', 'Budget at Completion');
ADD_COLUMN_COMMENT('PROJECT', 'BAC_HRS', 'Budget at Completion Hours');
ADD_COLUMN_COMMENT('PROJECT', 'BATCHNO', 'Batch Number');
ADD_COLUMN_COMMENT('PROJECT', 'BCWP', 'Budgeted Cost of Work Performed');
ADD_COLUMN_COMMENT('PROJECT', 'BCWP_HRS', 'Budgeted Cost of Work Performed Hours');
ADD_COLUMN_COMMENT('PROJECT', 'BCWS', 'Budgeted Cost of Work Scheduled');
ADD_COLUMN_COMMENT('PROJECT', 'BCWS_HRS', 'Budgeted Cost of Work Scheduled Hours');
ADD_COLUMN_COMMENT('PROJECT', 'CA_ACTUAL', 'Control Account Actual');
ADD_COLUMN_COMMENT('PROJECT', 'CA_BD1', 'Control Account Breakdown 1');
ADD_COLUMN_COMMENT('PROJECT', 'CA_BD2', 'Control Account Breakdown 2');
ADD_COLUMN_COMMENT('PROJECT', 'CA_BD3', 'Control Account Breakdown 3');
ADD_COLUMN_COMMENT('PROJECT', 'CA_ID1', 'Control Account Identifier 1');
ADD_COLUMN_COMMENT('PROJECT', 'CA_ID2', 'Control Account Identifier 2');
ADD_COLUMN_COMMENT('PROJECT', 'CA_ID3', 'Control Account Identifier 3');
ADD_COLUMN_COMMENT('PROJECT', 'CALC_FILE', 'Calculation File');
ADD_COLUMN_COMMENT('PROJECT', 'CAMCODE', 'Control Account Manager Code');
ADD_COLUMN_COMMENT('PROJECT', 'CCN_BDN', 'Change Control Number Breakdown');
ADD_COLUMN_COMMENT('PROJECT', 'CE_BDN', 'Cost Element Breakdown');
ADD_COLUMN_COMMENT('PROJECT', 'CE_ID', 'Cost Element ID');
ADD_COLUMN_COMMENT('PROJECT', 'CITY', 'City');
ADD_COLUMN_COMMENT('PROJECT', 'CLC_PROMPT', 'Calculation Prompt');
ADD_COLUMN_COMMENT('PROJECT', 'CLIN_CODE', 'Contract Line Item Number Code');
ADD_COLUMN_COMMENT('PROJECT', 'CONT_FLAG', 'Contract Flag');
ADD_COLUMN_COMMENT('PROJECT', 'CONT_IDCODE', 'Contract ID Code');
ADD_COLUMN_COMMENT('PROJECT', 'CONT_IDTYPE', 'Contract ID Type');
ADD_COLUMN_COMMENT('PROJECT', 'CONT_LOC', 'Contract Location');
ADD_COLUMN_COMMENT('PROJECT', 'CONT_NAME', 'Contract Name');
ADD_COLUMN_COMMENT('PROJECT', 'CONT_NO', 'Contract Number');
ADD_COLUMN_COMMENT('PROJECT', 'CONT_PHASE', 'Contract Phase');
ADD_COLUMN_COMMENT('PROJECT', 'CONT_PROGRAM', 'Contract Program');
ADD_COLUMN_COMMENT('PROJECT', 'CONT_PROGTYPE', 'Contract Program Type');
ADD_COLUMN_COMMENT('PROJECT', 'CONT_REPEMAIL', 'Contract Representative Email');
ADD_COLUMN_COMMENT('PROJECT', 'CONT_REPN', 'Contract Representative Name');
ADD_COLUMN_COMMENT('PROJECT', 'CONT_REPPHONE', 'Contract Representative Phone');
ADD_COLUMN_COMMENT('PROJECT', 'CONT_REPT', 'Contract Report Type');
ADD_COLUMN_COMMENT('PROJECT', 'CONT_STATEMENT', 'Contract Statement');
ADD_COLUMN_COMMENT('PROJECT', 'CONT_TASK', 'Contract Task');
ADD_COLUMN_COMMENT('PROJECT', 'CONT_TYPE', 'Contract Type');
ADD_COLUMN_COMMENT('PROJECT', 'CONTRACT', 'Contract');
ADD_COLUMN_COMMENT('PROJECT', 'COUNTRY', 'Country');
ADD_COLUMN_COMMENT('PROJECT', 'EAC', 'Estimate at Completion');
ADD_COLUMN_COMMENT('PROJECT', 'EAC_HRS', 'Estimate at Completion Hours');
ADD_COLUMN_COMMENT('PROJECT', 'FC_TYPE1', 'Forecast Type 1');
ADD_COLUMN_COMMENT('PROJECT', 'FC_TYPE2', 'Forecast Type 2');
ADD_COLUMN_COMMENT('PROJECT', 'FC_TYPE3', 'Forecast Type 3');
ADD_COLUMN_COMMENT('PROJECT', 'FC_TYPE4', 'Forecast Type 4');
ADD_COLUMN_COMMENT('PROJECT', 'FISC_FILE', 'Fiscal File');
ADD_COLUMN_COMMENT('PROJECT', 'FISC_RW', 'Fiscal Rolling Wave');
ADD_COLUMN_COMMENT('PROJECT', 'IPMR2_CODE', 'Integrated Program Management Report Code');
ADD_COLUMN_COMMENT('PROJECT', 'ISMASTER', 'Is Master');
ADD_COLUMN_COMMENT('PROJECT', 'MGRFILE', 'Manager File');
ADD_COLUMN_COMMENT('PROJECT', 'MGRTYPE', 'Manager Type');
ADD_COLUMN_COMMENT('PROJECT', 'MPSCODE', 'Material Procurement Status Code');
ADD_COLUMN_COMMENT('PROJECT', 'OPP_PROJ', 'Opportunity Project');
ADD_COLUMN_COMMENT('PROJECT', 'P1', 'Period 1');
ADD_COLUMN_COMMENT('PROJECT', 'P2', 'Period 2');
ADD_COLUMN_COMMENT('PROJECT', 'P3', 'Period 3');
ADD_COLUMN_COMMENT('PROJECT', 'P4', 'Period 4');
ADD_COLUMN_COMMENT('PROJECT', 'P5', 'Period 5');
ADD_COLUMN_COMMENT('PROJECT', 'P6', 'Period 6');
ADD_COLUMN_COMMENT('PROJECT', 'P7', 'Period 7');
ADD_COLUMN_COMMENT('PROJECT', 'P8', 'Period 8');
ADD_COLUMN_COMMENT('PROJECT', 'P9', 'Period 9');
ADD_COLUMN_COMMENT('PROJECT', 'PERCENT1', 'Percent 1');
ADD_COLUMN_COMMENT('PROJECT', 'PERCENT2', 'Percent 2');
ADD_COLUMN_COMMENT('PROJECT', 'PERCENT3', 'Percent 3');
ADD_COLUMN_COMMENT('PROJECT', 'PRODVIS', 'Product Visibility');
ADD_COLUMN_COMMENT('PROJECT', 'PROGRAM', 'Program');
ADD_COLUMN_COMMENT('PROJECT', 'QUANTITY', 'Quantity');
ADD_COLUMN_COMMENT('PROJECT', 'RATE_FILE', 'Rate File');
ADD_COLUMN_COMMENT('PROJECT', 'SHARERATIO', 'Share Ratio');
ADD_COLUMN_COMMENT('PROJECT', 'STATE', 'State');
ADD_COLUMN_COMMENT('PROJECT', 'WP_BDN', 'Work Package Breakdown');
ADD_COLUMN_COMMENT('PROJECT', 'WP_ID', 'Work Package ID');
ADD_COLUMN_COMMENT('PROJECT', 'ZIP', 'ZIP Code');
ADD_COLUMN_COMMENT('PROJECT', 'OWNER_USER_UID', 'The User that owns the Project');
ADD_COLUMN_COMMENT('PROJECT', 'CREATED_BY_USER_UID', 'The User that created the Project.');
ADD_COLUMN_COMMENT('PROJECT', 'CREATED_DATE', 'Date the Project was created.');
ADD_COLUMN_COMMENT('PROJECT', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Project.');
ADD_COLUMN_COMMENT('PROJECT', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Project.');

-- Create table PROJECT_AUDIT_LOG
CREATE_TABLE(
 'PROJECT_AUDIT_LOG',
 'CREATE TABLE PROJECT_AUDIT_LOG (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    PROJECT_UID RAW(16) NOT NULL,
    PROJECT_CONTROL_ACCOUNT_NAME NVARCHAR2(100),
    PROJECT_WORK_PACKAGE_NAME NVARCHAR2(100),
    PROJECT_CAWP_RESOURCE_NAME NVARCHAR2(100),
    PERIOD_END DATE NOT NULL,
    REFERENCE_NUMBER NUMBER(10,0) DEFAULT (0) NOT NULL,
    TRANSACTION_UID RAW(16) NOT NULL,
    DEBIT NUMBER(1,0) DEFAULT (0) NOT NULL,
    CREDIT NUMBER(1,0) DEFAULT (0) NOT NULL,
    AMOUNT NUMBER(21,6) DEFAULT (0) NOT NULL,
    LOG_COMMENT NVARCHAR2(200),
    CPR3 NUMBER(1,0) DEFAULT (0) NOT NULL,
    CHANGE_NUMBER NVARCHAR2(100),
    SIGNIFICANT_CHANGE NUMBER(1,0) DEFAULT (0) NOT NULL,
    HOURS NUMBER(6,2) DEFAULT (0) NOT NULL,
    CLIN_NAME NVARCHAR2(100),
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    PROGRAM VARCHAR2(22)
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PROJECT_AUDIT_LOG', 'ROW_UID');

ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG', 'ROW_UID', 'Unique project audit log Identifier.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG', 'PROJECT_UID', 'Unique Project Identifier.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG', 'PROJECT_CONTROL_ACCOUNT_NAME', 'Name of the control account');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG', 'PROJECT_WORK_PACKAGE_NAME', 'Name of the work package');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG', 'PROJECT_CAWP_RESOURCE_NAME', 'Name of the resource');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG', 'PERIOD_END', 'End date of tphase');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG', 'REFERENCE_NUMBER', 'Batch number of Project');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG', 'TRANSACTION_UID', 'Capture same transactionid of different changes in CA or WP or Resources');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG', 'CREATED_BY_USER_UID', 'The User that created the project Audit log.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG', 'CREATED_DATE', 'Date the project Audit log was created.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the project audit log');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG', 'LAST_MODIFIED_DATE', 'Date the last change was made to the project audit log.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG', 'PROGRAM', 'The Program');

-- Create table PROJECT_AUDIT_LOG_ACCOUNTS
CREATE_TABLE(
 'PROJECT_AUDIT_LOG_ACCOUNTS',
 'CREATE TABLE PROJECT_AUDIT_LOG_ACCOUNTS (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    PROJECT_UID RAW(16) NOT NULL,
    REFERENCE_NUMBER NUMBER(10,0) DEFAULT (0) NOT NULL,
    TRANSACTION_UID NVARCHAR2(100) NOT NULL,
    PERIOD_END DATE NOT NULL,
    LABEL NVARCHAR2(10) NOT NULL,
    LOG_COMMENT NVARCHAR2(200),
    UB NUMBER(21,6) DEFAULT (0) NOT NULL,
    MR NUMBER(21,6) DEFAULT (0) NOT NULL,
    AUW NUMBER(21,6) DEFAULT (0) NOT NULL,
    CTC NUMBER(21,6) DEFAULT (0) NOT NULL,
    DB NUMBER(21,6) DEFAULT (0) NOT NULL,
    EAC NUMBER(21,6) DEFAULT (0) NOT NULL,
    FEE NUMBER(21,6) DEFAULT (0) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    PROGRAM VARCHAR2(22)
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PROJECT_AUDIT_LOG_ACCOUNTS', 'ROW_UID');

ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_ACCOUNTS', 'ROW_UID', 'Unique project audit log account Identifier.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_ACCOUNTS', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_ACCOUNTS', 'PROJECT_UID', 'Unique Project Identifier.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_ACCOUNTS', 'REFERENCE_NUMBER', 'Batch number of Project');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_ACCOUNTS', 'TRANSACTION_UID', 'Capture same transactionid of different changes in CA or WP or Resources');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_ACCOUNTS', 'PERIOD_END', 'Represents the period end date for which totals were captured');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_ACCOUNTS', 'LABEL', 'Label that identifies the period');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_ACCOUNTS', 'UB', 'The Undistributed Budget');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_ACCOUNTS', 'MR', 'The Management Reserve');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_ACCOUNTS', 'AUW', 'The Authorized Unpriced Work');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_ACCOUNTS', 'CTC', 'The Contract Target Cost');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_ACCOUNTS', 'DB', 'The Distributed Budget');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_ACCOUNTS', 'CREATED_BY_USER_UID', 'The User that created the project audit log account.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_ACCOUNTS', 'CREATED_DATE', 'Date the project audit log account was created.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_ACCOUNTS', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the project audit log account.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_ACCOUNTS', 'LAST_MODIFIED_DATE', 'Date the last change was made to the project audit log account.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_ACCOUNTS', 'PROGRAM', 'The Program');

-- Create table PROJECT_AUDIT_LOG_HISTORY
CREATE_TABLE(
 'PROJECT_AUDIT_LOG_HISTORY',
 'CREATE TABLE PROJECT_AUDIT_LOG_HISTORY (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    PROJECT_UID RAW(16) NOT NULL,
    PROJECT_CAWP_UID RAW(16) NOT NULL,
    PERIOD_END DATE NOT NULL,
    BAC NUMBER(21,6) DEFAULT (0) NOT NULL,
    EAC NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWP NUMBER(21,6) DEFAULT (0) NOT NULL,
    ACWP NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWS_HRS NUMBER(6,2) DEFAULT (0) NOT NULL,
    BCWP_HRS NUMBER(6,2) DEFAULT (0) NOT NULL,
    ACWP_HRS NUMBER(6,2) DEFAULT (0) NOT NULL,
    BAC_HRS NUMBER(6,2) DEFAULT (0) NOT NULL,
    EAC_HRS NUMBER(6,2) DEFAULT (0) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    CAWP NUMBER(19,0) DEFAULT (0),
    PROGRAM VARCHAR2(22) DEFAULT ('' '')
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PROJECT_AUDIT_LOG_HISTORY', 'ROW_UID');

ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_HISTORY', 'ROW_UID', 'Unique project audit log history Identifier.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_HISTORY', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_HISTORY', 'PROJECT_UID', 'Unique Project Identifier.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_HISTORY', 'PROJECT_CAWP_UID', 'Contains UID of control account or work package');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_HISTORY', 'CREATED_BY_USER_UID', 'The User that created the project audit log history.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_HISTORY', 'CREATED_DATE', 'Date the project audit log history was created.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_HISTORY', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the project audit log history.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_HISTORY', 'LAST_MODIFIED_DATE', 'Date the last change was made to the project audit log history.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_HISTORY', 'CAWP', 'The Control Account Work Package Identifier');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_HISTORY', 'PROGRAM', 'The Program');

-- Create table PROJECT_AUDIT_LOG_TPHASE
CREATE_TABLE(
 'PROJECT_AUDIT_LOG_TPHASE',
 'CREATE TABLE PROJECT_AUDIT_LOG_TPHASE (
    ROW_UID RAW(16) NOT NULL,
    PROJECT_UID RAW(16) NOT NULL,
    PROJECT_AUDIT_LOG_UID RAW(16) NOT NULL,
    TRANSACTION_UID RAW(16) NOT NULL,
    TPHASE_DATE TIMESTAMP NOT NULL,
    HOURS NUMBER(6,2) DEFAULT (0) NOT NULL,
    AMOUNT NUMBER(21,6) DEFAULT (0) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    PROGRAM VARCHAR2(22)
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PROJECT_AUDIT_LOG_TPHASE', 'ROW_UID');

ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_TPHASE', 'ROW_UID', 'Unique project audit log tphase Identifier.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_TPHASE', 'PROJECT_UID', 'Unique Project Identifier.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_TPHASE', 'PROJECT_AUDIT_LOG_UID', 'Unique Project Audit log  Identifier.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_TPHASE', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('PROJECT_AUDIT_LOG_TPHASE', 'PROGRAM', 'The Program');

-- Create table PROJECT_CALC_RESULT
CREATE_TABLE(
 'PROJECT_CALC_RESULT',
 'CREATE TABLE PROJECT_CALC_RESULT (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    PROJECT_UID RAW(16) NOT NULL,
    RESULT_CODE VARCHAR2(1) DEFAULT ('' '') NOT NULL,
    RESULT VARCHAR2(30) DEFAULT ('' '') NOT NULL,
    CURRENCY NUMBER(1,0) DEFAULT (0) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    EXPRESSION VARCHAR2(250) DEFAULT ('' ''),
    PROGRAM VARCHAR2(22) DEFAULT ('' '')
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PROJECT_CALC_RESULT', 'ROW_UID');
CREATE_NATURAL_KEY('PROJECT_CALC_RESULT', 'RESULT_CODE');

ADD_COLUMN_COMMENT('PROJECT_CALC_RESULT', 'ROW_UID', 'Unique Calculated Result Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CALC_RESULT', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CALC_RESULT', 'PROJECT_UID', 'Unique Project Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CALC_RESULT', 'RESULT_CODE', 'Result Field Display Order');
ADD_COLUMN_COMMENT('PROJECT_CALC_RESULT', 'RESULT', 'Result Field Name');
ADD_COLUMN_COMMENT('PROJECT_CALC_RESULT', 'CURRENCY', 'Is the calculated field result treated as a Currency value.');
ADD_COLUMN_COMMENT('PROJECT_CALC_RESULT', 'CREATED_BY_USER_UID', 'The User that created the Project Calculated Result.');
ADD_COLUMN_COMMENT('PROJECT_CALC_RESULT', 'CREATED_DATE', 'Date the Project Calculated Result was created.');
ADD_COLUMN_COMMENT('PROJECT_CALC_RESULT', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Project Calculated Result.');
ADD_COLUMN_COMMENT('PROJECT_CALC_RESULT', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Project Calculated Result.');
ADD_COLUMN_COMMENT('PROJECT_CALC_RESULT', 'EXPRESSION', 'Calculated Field Expression');
ADD_COLUMN_COMMENT('PROJECT_CALC_RESULT', 'PROGRAM', 'Program which is converted to Project_UID');

-- Create table PROJECT_CAWP
CREATE_TABLE(
 'PROJECT_CAWP',
 'CREATE TABLE PROJECT_CAWP (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    PROJECT_UID RAW(16) NOT NULL,
    NAME NVARCHAR2(100) NOT NULL,
    OBS_CODE_UID RAW(16),
    WBS_CODE_UID RAW(16),
    PARENT_PROJECT_CAWP_UID RAW(16),
    CAM_CODE_UID RAW(16),
    CLIN_CODE_UID RAW(16),
    IS_WP NUMBER(1,0) DEFAULT (0) NOT NULL,
    BASELINE_START DATE,
    BASELINE_FINISH DATE,
    ACTUAL_START DATE,
    ACTUAL_FINISH DATE,
    EARLY_START DATE,
    EARLY_FINISH DATE,
    LATE_START DATE,
    LATE_FINISH DATE,
    PENDING_START DATE,
    PENDING_FINISH DATE,
    FORECAST_START DATE,
    FORECAST_FINISH DATE,
    STATUS VARCHAR2(1),
    EVT VARCHAR2(1),
    START_PERCENT NUMBER(5,2) DEFAULT (0),
    PERCENT_COMPLETE NUMBER(5,2) DEFAULT (0),
    UNITS_TO_DO NUMBER(21,6) DEFAULT (0),
    UNITS_COMPLETE NUMBER(21,6) DEFAULT (0),
    ACWP NUMBER(21,6) DEFAULT (0) NOT NULL,
    ACWP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    ACWPCP NUMBER(21,6) DEFAULT (0) NOT NULL,
    ACWPCP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    APPLINK NUMBER(19,0) DEFAULT (0) NOT NULL,
    BAC NUMBER(21,6) DEFAULT (0) NOT NULL,
    BAC_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWP NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWPCP NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWPCP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWS_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWSCP NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWSCP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    C1 VARCHAR2(59),
    C10 VARCHAR2(59),
    C11 VARCHAR2(59),
    C12 VARCHAR2(59),
    C13 VARCHAR2(59),
    C14 VARCHAR2(59),
    C15 VARCHAR2(59),
    C16 VARCHAR2(59),
    C17 VARCHAR2(59),
    C18 VARCHAR2(59),
    C19 VARCHAR2(59),
    C2 VARCHAR2(59),
    C20 VARCHAR2(59),
    C3 VARCHAR2(59),
    C4 VARCHAR2(59),
    C5 VARCHAR2(59),
    C6 VARCHAR2(59),
    C7 VARCHAR2(59),
    C8 VARCHAR2(59),
    C9 VARCHAR2(59),
    CA1 VARCHAR2(59) DEFAULT ('' ''),
    CA2 VARCHAR2(59) DEFAULT ('' ''),
    CA3 VARCHAR2(59) DEFAULT ('' ''),
    CAWPID NUMBER(19,0) DEFAULT (0) NOT NULL,
    CL_BATCH NUMBER(19,0) DEFAULT (0) NOT NULL,
    EAC NUMBER(21,6) DEFAULT (0) NOT NULL,
    EAC_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    EAC_NONLAB NUMBER(21,6) DEFAULT (0) NOT NULL,
    EOC VARCHAR2(59),
    FLAG VARCHAR2(1) DEFAULT ('' ''),
    OP_BATCH NUMBER(19,0) DEFAULT (0) NOT NULL,
    USER_CHR01 VARCHAR2(100),
    USER_CHR02 VARCHAR2(100),
    USER_CHR03 VARCHAR2(100),
    USER_CHR04 VARCHAR2(100),
    USER_CHR05 VARCHAR2(100),
    USER_DTE01 DATE,
    USER_DTE02 DATE,
    USER_DTE03 DATE,
    USER_DTE04 DATE,
    USER_DTE05 DATE,
    USER_NUM01 NUMBER(21,6) DEFAULT (0) NOT NULL,
    USER_NUM02 NUMBER(21,6) DEFAULT (0) NOT NULL,
    USER_NUM03 NUMBER(21,6) DEFAULT (0) NOT NULL,
    USER_NUM04 NUMBER(21,6) DEFAULT (0) NOT NULL,
    USER_NUM05 NUMBER(21,6) DEFAULT (0) NOT NULL,
    PROGRAM VARCHAR2(22) DEFAULT ('' ''),
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    DESCRIPTION NVARCHAR2(256),
    RESERVED1 NVARCHAR2(256)
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PROJECT_CAWP', 'ROW_UID');
CREATE_NATURAL_KEY('PROJECT_CAWP', 'PROJECT_UID, NAME, PARENT_PROJECT_CAWP_UID');

ADD_COLUMN_COMMENT('PROJECT_CAWP', 'ROW_UID', 'Unique CAWP Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'PROJECT_UID', 'Unique Project Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'NAME', 'Project CAWP Name');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'OBS_CODE_UID', 'Unique OBS Code Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'WBS_CODE_UID', 'Unique WBS Code Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'PARENT_PROJECT_CAWP_UID', 'Unique Parent CAWP for a Work Package.');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'CAM_CODE_UID', 'Unique CAM Code Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'CLIN_CODE_UID', 'Unique CLIN Code Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'IS_WP', 'Boolean value indicating if the record is a Control Account or a Work Package');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'BASELINE_START', 'Baseline Start Date');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'BASELINE_FINISH', 'Baseline Finish Date');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'ACTUAL_START', 'Actual Start  / Forecast Start Date');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'ACTUAL_FINISH', 'Actual Finish / Forecast Finish Date');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'EARLY_START', 'Early Start Date');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'EARLY_FINISH', 'Early Finish Date');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'LATE_START', 'Late Start Date');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'LATE_FINISH', 'Late Finish Date');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'PENDING_START', 'Pending Start Date');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'PENDING_FINISH', 'Pending Finish Date');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'FORECAST_START', 'Forecast Start Date');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'FORECAST_FINISH', 'Forecast Finish Date');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'STATUS', 'Status');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'EVT', 'Earned Value Performance Measurement Technique');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'START_PERCENT', 'Start Percent');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'PERCENT_COMPLETE', 'Percent Complete');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'UNITS_TO_DO', 'Units To Do');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'UNITS_COMPLETE', 'Units Complete');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'ACWP', 'Actual Cost of Work Performed');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'ACWP_HRS', 'Actual Cost of Work Performed Hours');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'ACWPCP', 'Actual Cost of Work Performed Cumulative Previous');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'ACWPCP_HRS', 'Actual Cost of Work Performed Cumulative Previous Hours');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'APPLINK', 'Application Link');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'BAC', 'Budget at Completion');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'BAC_HRS', 'Budget at Completion Hours');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'BCWP', 'Budgeted Cost of Work Performed');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'BCWP_HRS', 'Budgeted Cost of Work Performed Hours');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'BCWPCP', 'Budgeted Cost of Work Performed Cumulative Previous');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'BCWPCP_HRS', 'Budgeted Cost of Work Performed Cumulative Previous Hours');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'BCWS', 'Budgeted Cost of Work Scheduled');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'BCWS_HRS', 'Budgeted Cost of Work Scheduled Hours');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'BCWSCP', 'Budgeted Cost of Work Scheduled Cumulative Previous');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'BCWSCP_HRS', 'Budgeted Cost of Work Scheduled Cumulative Previous Hours');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'C1', 'Custom Field 1');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'C10', 'Custom Field 10');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'C11', 'Custom Field 11');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'C12', 'Custom Field 12');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'C13', 'Custom Field 13');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'C14', 'Custom Field 14');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'C15', 'Custom Field 15');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'C16', 'Custom Field 16');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'C17', 'Custom Field 17');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'C18', 'Custom Field 18');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'C19', 'Custom Field 19');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'C2', 'Custom Field 2');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'C20', 'Custom Field 20');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'C3', 'Custom Field 3');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'C4', 'Custom Field 4');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'C5', 'Custom Field 5');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'C6', 'Custom Field 6');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'C7', 'Custom Field 7');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'C8', 'Custom Field 8');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'C9', 'Custom Field 9');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'CA1', 'Control Account 1');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'CA2', 'Control Account 2');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'CA3', 'Control Account 3');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'CAWPID', 'Control Account Work Package ID');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'CL_BATCH', 'Closing Batch');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'EAC', 'Estimate at Completion');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'EAC_HRS', 'Estimate at Completion Hours');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'EAC_NONLAB', 'Estimate at Completion Non-Labor');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'EOC', 'Element of Cost');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'FLAG', 'Flag');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'OP_BATCH', 'Opening Batch');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'USER_CHR01', 'User Character Field 01');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'USER_CHR02', 'User Character Field 02');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'USER_CHR03', 'User Character Field 03');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'USER_CHR04', 'User Character Field 04');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'USER_CHR05', 'User Character Field 05');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'USER_DTE01', 'User Date Field 01');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'USER_DTE02', 'User Date Field 02');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'USER_DTE03', 'User Date Field 03');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'USER_DTE04', 'User Date Field 04');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'USER_DTE05', 'User Date Field 05');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'USER_NUM01', 'User Number Field 01-05');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'USER_NUM02', 'User Number Field 01');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'USER_NUM03', 'User Number Field 02');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'USER_NUM04', 'User Number Field 03');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'USER_NUM05', 'User Number Field 04');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'PROGRAM', 'User Number Field 05');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'CREATED_BY_USER_UID', 'The User that created the Project CAWP.');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'CREATED_DATE', 'Date the Project CAWP was created.');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Project CAWP.');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Project CAWP.');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'DESCRIPTION', 'Project CAWP Description.');
ADD_COLUMN_COMMENT('PROJECT_CAWP', 'RESERVED1', 'Used internally to index data processing.');

-- Create table PROJECT_CAWP_RESOURCE
CREATE_TABLE(
 'PROJECT_CAWP_RESOURCE',
 'CREATE TABLE PROJECT_CAWP_RESOURCE (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    PROJECT_CAWP_UID RAW(16) NOT NULL,
    RESOURCES_UID RAW(16) NOT NULL,
    PROJECT_COST_CLASS_UID RAW(16) NOT NULL,
    SPREAD_CURVE_UID RAW(16),
    RSSTART DATE,
    RSFINISH DATE,
    BAC NUMBER(21,6) DEFAULT (0),
    ETC NUMBER(21,6) DEFAULT (0),
    PERCENT_COMPLETE NUMBER(5,2) DEFAULT (0),
    PF NUMBER(21,6) DEFAULT (0),
    GA_PF NUMBER(21,6) DEFAULT (0),
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    PROGRAM VARCHAR2(22) DEFAULT ('' ''),
    C1 NVARCHAR2(59),
    C2 NVARCHAR2(59),
    C3 NVARCHAR2(59),
    C4 NVARCHAR2(59),
    C5 NVARCHAR2(59),
    C6 NVARCHAR2(59),
    C7 NVARCHAR2(59),
    C8 NVARCHAR2(59),
    C9 NVARCHAR2(59),
    CAWPID NUMBER(19,0) DEFAULT (0),
    CECODE VARCHAR2(59) DEFAULT ('' ''),
    CLASS VARCHAR2(20),
    SPREADNAME VARCHAR2(16)
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PROJECT_CAWP_RESOURCE', 'ROW_UID');
CREATE_NATURAL_KEY('PROJECT_CAWP_RESOURCE', 'PROJECT_CAWP_UID, RESOURCES_UID, PROJECT_COST_CLASS_UID');

ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE', 'ROW_UID', 'Unique Cost Element Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE', 'PROJECT_CAWP_UID', 'Unique Project CAWP Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE', 'RESOURCES_UID', 'Unique Resource Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE', 'PROJECT_COST_CLASS_UID', 'Unique Cost Class Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE', 'SPREAD_CURVE_UID', 'Unique Spread Curve Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE', 'RSSTART', 'Resource Assignment Start Date.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE', 'RSFINISH', 'Resource Assignment End Date.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE', 'BAC', 'Budget at Completion.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE', 'ETC', 'Estimate at Completion.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE', 'PERCENT_COMPLETE', 'Percent Complete.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE', 'PF', 'Performance Factor.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE', 'GA_PF', 'G&A Performance Factor.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE', 'CREATED_BY_USER_UID', 'The User that created the Project Cost Element.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE', 'CREATED_DATE', 'Date the Project Cost Element was created.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Project Cost Element.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Project Cost Element.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE', 'CAWPID', 'Unique Project CAWP Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE', 'CECODE', 'Unique Resource Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE', 'CLASS', 'Unique Cost Class Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE', 'SPREADNAME', 'Unique Spread Curve Identifier.');

-- Create table PROJECT_CAWP_RESOURCE_TPHASE
CREATE_TABLE(
 'PROJECT_CAWP_RESOURCE_TPHASE',
 'CREATE TABLE PROJECT_CAWP_RESOURCE_TPHASE (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    PROJECT_CAWP_RESOURCE_UID RAW(16) NOT NULL,
    TPHASE_DATE DATE NOT NULL,
    RESULT1 NUMBER(21,6) DEFAULT (0),
    RESULT2 NUMBER(21,6) DEFAULT (0),
    RESULT3 NUMBER(21,6) DEFAULT (0),
    RESULT4 NUMBER(21,6) DEFAULT (0),
    RESULT5 NUMBER(21,6) DEFAULT (0),
    RESULT6 NUMBER(21,6) DEFAULT (0),
    RESULT7 NUMBER(21,6) DEFAULT (0),
    RESULT8 NUMBER(21,6) DEFAULT (0),
    RESULT9 NUMBER(21,6) DEFAULT (0),
    RESULT10 NUMBER(21,6) DEFAULT (0),
    RESULT11 NUMBER(21,6) DEFAULT (0),
    RESULT12 NUMBER(21,6) DEFAULT (0),
    RESULT13 NUMBER(21,6) DEFAULT (0),
    RESULT14 NUMBER(21,6) DEFAULT (0),
    RESULT15 NUMBER(21,6) DEFAULT (0),
    RESULT16 NUMBER(21,6) DEFAULT (0),
    RESULT17 NUMBER(21,6) DEFAULT (0),
    RESULT18 NUMBER(21,6) DEFAULT (0),
    RESULT19 NUMBER(21,6) DEFAULT (0),
    RESULT20 NUMBER(21,6) DEFAULT (0),
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    PROGRAM NVARCHAR2(22),
    CLASS NVARCHAR2(20),
    CECODE NVARCHAR2(59),
    BATCHNO NUMBER(10,0) DEFAULT (0),
    CAWPID NUMBER(19,0) DEFAULT (0),
    COM NUMBER(19,0) DEFAULT (0),
    DIRECT NUMBER(19,0) DEFAULT (0),
    FEE NUMBER(19,0) DEFAULT (0),
    FRINGE NUMBER(19,0) DEFAULT (0),
    FTE NUMBER(19,0) DEFAULT (0),
    GANDA NUMBER(19,0) DEFAULT (0),
    HOURS NUMBER(19,0) DEFAULT (0),
    OVERHEAD NUMBER(19,0) DEFAULT (0)
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PROJECT_CAWP_RESOURCE_TPHASE', 'ROW_UID');

ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'ROW_UID', 'Unique TPHASE Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'PROJECT_CAWP_RESOURCE_UID', 'Unique Project Cost Element Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'TPHASE_DATE', 'Represents the date for the tphase period. Aligns with calendar period, except last period which will always align with Res Asg finish date.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'RESULT1', 'Result 1 Value.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'RESULT2', 'Result 2 Value.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'RESULT3', 'Result 3 Value.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'RESULT4', 'Result 4 Value.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'RESULT5', 'Result 5 Value.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'RESULT6', 'Result 6 Value.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'RESULT7', 'Result 7 Value.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'RESULT8', 'Result 8 Value.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'RESULT9', 'Result 9 Value.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'RESULT10', 'Result 10 Value.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'RESULT11', 'Result 11 Value.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'RESULT12', 'Result 12 Value.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'RESULT13', 'Result 13 Value.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'RESULT14', 'Result 14 Value.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'RESULT15', 'Result 15 Value.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'RESULT16', 'Result 16 Value.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'RESULT17', 'Result 17 Value.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'RESULT18', 'Result 18 Value.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'RESULT19', 'Result 19 Value.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'RESULT20', 'Result 20 Value.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'CREATED_BY_USER_UID', 'The User that created the Project TPhase.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'CREATED_DATE', 'Date the Project TPhase was created.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Project TPhase.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Project TPhase.');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'PROGRAM', 'Program');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'CLASS', 'Class');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'CECODE', 'Cost Element Code');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'BATCHNO', 'Batch Number');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'CAWPID', 'Control Account Work Package ID');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'COM', 'Commitment');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'DIRECT', 'Direct');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'FEE', 'Fee');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'FRINGE', 'Fringe');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'FTE', 'Full Time Equivalent');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'GANDA', 'General and Administrative');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'HOURS', 'Hours');
ADD_COLUMN_COMMENT('PROJECT_CAWP_RESOURCE_TPHASE', 'OVERHEAD', 'Overhead');

-- Create table PROJECT_CAWP_TOTAL
CREATE_TABLE(
 'PROJECT_CAWP_TOTAL',
 'CREATE TABLE PROJECT_CAWP_TOTAL (
    ROW_UID RAW(16) NOT NULL,
    ACWP NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWP NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BAC NUMBER(21,6) DEFAULT (0) NOT NULL,
    EAC NUMBER(21,6) DEFAULT (0) NOT NULL,
    EAC_NONLAB NUMBER(21,6) DEFAULT (0) NOT NULL,
    ACWP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWS_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BAC_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    EAC_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    ACWPCP NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWPCP NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWSCP NUMBER(21,6) DEFAULT (0) NOT NULL,
    ACWPCP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWPCP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWSCP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PROJECT_CAWP_TOTAL', 'ROW_UID');

ADD_COLUMN_COMMENT('PROJECT_CAWP_TOTAL', 'ROW_UID', 'Unique CAWP Identifier. THIS TABLE IS DEPRECATED');
ADD_COLUMN_COMMENT('PROJECT_CAWP_TOTAL', 'ACWP', 'Actual Cost');
ADD_COLUMN_COMMENT('PROJECT_CAWP_TOTAL', 'BCWP', 'Earned Cost');
ADD_COLUMN_COMMENT('PROJECT_CAWP_TOTAL', 'BCWS', 'Budget Cost');
ADD_COLUMN_COMMENT('PROJECT_CAWP_TOTAL', 'BAC', 'Budget Cost At Completion');
ADD_COLUMN_COMMENT('PROJECT_CAWP_TOTAL', 'EAC', 'Forecast or Estimated Cost at Completion');
ADD_COLUMN_COMMENT('PROJECT_CAWP_TOTAL', 'EAC_NONLAB', 'Forecast or Estimated Non-Labor Cost at Completion');
ADD_COLUMN_COMMENT('PROJECT_CAWP_TOTAL', 'ACWP_HRS', 'Actual Hours');
ADD_COLUMN_COMMENT('PROJECT_CAWP_TOTAL', 'BCWP_HRS', 'Earned Hours');
ADD_COLUMN_COMMENT('PROJECT_CAWP_TOTAL', 'BCWS_HRS', 'Budget Hours');
ADD_COLUMN_COMMENT('PROJECT_CAWP_TOTAL', 'BAC_HRS', 'Budget Hours At Completion');
ADD_COLUMN_COMMENT('PROJECT_CAWP_TOTAL', 'EAC_HRS', 'Forecast or Estimated Hours at Completion');
ADD_COLUMN_COMMENT('PROJECT_CAWP_TOTAL', 'ACWPCP', 'Current Period Actual Cost');
ADD_COLUMN_COMMENT('PROJECT_CAWP_TOTAL', 'BCWPCP', 'Current Period Earned Cost');
ADD_COLUMN_COMMENT('PROJECT_CAWP_TOTAL', 'BCWSCP', 'Current Period Budget Cost');
ADD_COLUMN_COMMENT('PROJECT_CAWP_TOTAL', 'ACWPCP_HRS', 'Current Period Actual Hours');
ADD_COLUMN_COMMENT('PROJECT_CAWP_TOTAL', 'BCWPCP_HRS', 'Current Period Earned Hours');
ADD_COLUMN_COMMENT('PROJECT_CAWP_TOTAL', 'BCWSCP_HRS', 'Current Period Budget Hours');

-- Create table PROJECT_CONTROL_ACCOUNT
CREATE_TABLE(
 'PROJECT_CONTROL_ACCOUNT',
 'CREATE TABLE PROJECT_CONTROL_ACCOUNT (
    ACTUAL_FINISH DATE,
    ACTUAL_START DATE,
    ACWP NUMBER(21,6) DEFAULT (0),
    ACWP_HRS NUMBER(21,6) DEFAULT (0),
    ACWPCP NUMBER(21,6) DEFAULT (0),
    ACWPCP_HRS NUMBER(21,6) DEFAULT (0),
    APPLINK NUMBER(10,0) DEFAULT (0),
    BAC NUMBER(21,6) DEFAULT (0),
    BAC_HRS NUMBER(21,6) DEFAULT (0),
    BASELINE_FINISH DATE,
    BASELINE_START DATE,
    BCWP NUMBER(21,6) DEFAULT (0),
    BCWP_HRS NUMBER(21,6) DEFAULT (0),
    BCWPCP NUMBER(21,6) DEFAULT (0),
    BCWPCP_HRS NUMBER(21,6) DEFAULT (0),
    BCWS NUMBER(21,6) DEFAULT (0),
    BCWS_HRS NUMBER(21,6) DEFAULT (0),
    BCWSCP NUMBER(21,6) DEFAULT (0),
    BCWSCP_HRS NUMBER(21,6) DEFAULT (0),
    C1 NVARCHAR2(59),
    C10 NVARCHAR2(59),
    C11 NVARCHAR2(59),
    C12 NVARCHAR2(59),
    C13 NVARCHAR2(59),
    C14 NVARCHAR2(59),
    C15 NVARCHAR2(59),
    C16 NVARCHAR2(59),
    C17 NVARCHAR2(59),
    C18 NVARCHAR2(59),
    C19 NVARCHAR2(59),
    C2 NVARCHAR2(59),
    C20 NVARCHAR2(59),
    C3 NVARCHAR2(59),
    C4 NVARCHAR2(59),
    C5 NVARCHAR2(59),
    C6 NVARCHAR2(59),
    C7 NVARCHAR2(59),
    C8 NVARCHAR2(59),
    C9 NVARCHAR2(59),
    CA1 NVARCHAR2(59),
    CA2 NVARCHAR2(59),
    CA3 NVARCHAR2(59),
    CL_BATCH NUMBER(10,0) DEFAULT (0),
    CONTRACT_CLIN_UID RAW(16),
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    DESCRIPTION NVARCHAR2(256),
    EAC NUMBER(21,6) DEFAULT (0),
    EAC_HRS NUMBER(21,6) DEFAULT (0),
    EAC_NONLAB NUMBER(21,6) DEFAULT (0),
    EARLY_FINISH DATE,
    EARLY_START DATE,
    EOC VARCHAR2(59),
    FLAG VARCHAR2(1),
    FORECAST_FINISH DATE,
    FORECAST_START DATE,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    LATE_FINISH DATE,
    LATE_START DATE,
    MANAGER_USER_UID RAW(16),
    NAME NVARCHAR2(100) NOT NULL,
    OBS_CODE_UID RAW(16),
    OP_BATCH NUMBER(10,0) DEFAULT (0),
    PC_COMP NUMBER(21,6) DEFAULT (0),
    PENDING_FINISH DATE,
    PENDING_START DATE,
    PMT VARCHAR2(1),
    PROGRAM VARCHAR2(22),
    PROJECT_UID RAW(16) NOT NULL,
    RESERVED1 VARCHAR2(239),
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    STARTPC NUMBER(5,0) DEFAULT (0),
    UNITS_COMP NUMBER(21,6) DEFAULT (0),
    UNITSTODO NUMBER(21,6) DEFAULT (0),
    USER_CHR01 VARCHAR2(100),
    USER_CHR02 VARCHAR2(100),
    USER_CHR03 VARCHAR2(100),
    USER_CHR04 VARCHAR2(100),
    USER_CHR05 VARCHAR2(100),
    USER_DTE01 DATE,
    USER_DTE02 DATE,
    USER_DTE03 DATE,
    USER_DTE04 DATE,
    USER_DTE05 DATE,
    USER_NUM01 NUMBER(21,6) DEFAULT (0),
    USER_NUM02 NUMBER(21,6) DEFAULT (0),
    USER_NUM03 NUMBER(21,6) DEFAULT (0),
    USER_NUM04 NUMBER(21,6) DEFAULT (0),
    USER_NUM05 NUMBER(21,6) DEFAULT (0),
    WBS_CODE_UID RAW(16),
    WP VARCHAR2(59)
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PROJECT_CONTROL_ACCOUNT', 'ROW_UID');
CREATE_NATURAL_KEY('PROJECT_CONTROL_ACCOUNT', 'NAME, PROJECT_UID');

ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'ACTUAL_FINISH', 'Actual Finish / Forecast Finish Date');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'ACTUAL_START', 'Actual Start  / Forecast Start Date');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'BASELINE_FINISH', 'Baseline Finish Date');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'BASELINE_START', 'Baseline Start Date');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'CONTRACT_CLIN_UID', 'Unique Contract Line Item Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'CREATED_BY_USER_UID', 'The User that created the Project Control Account');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'CREATED_DATE', 'Date the Project Control Account was created.');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'DESCRIPTION', 'Project Control Account Description.');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'EARLY_FINISH', 'Early Finish Date');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'EARLY_START', 'Early Start Date');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'FORECAST_FINISH', 'Forecast Finish Date');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'FORECAST_START', 'Forecast Start Date');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Project Control Account.');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Project Control Account');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'LATE_FINISH', 'Late Finish Date');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'LATE_START', 'Late Start Date');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'MANAGER_USER_UID', 'Unique Control  Account Manager User Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'NAME', 'Project Control Account Name');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'OBS_CODE_UID', 'Unique OBS Code Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'PENDING_FINISH', 'Pending Finish Date');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'PENDING_START', 'Pending Start Date');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'PROJECT_UID', 'Unique Project Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'ROW_UID', 'Unique Project Control Account Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT', 'WBS_CODE_UID', 'Unique WBS Code Identifier.');

-- Create table PROJECT_WORK_PACKAGE
CREATE_TABLE(
 'PROJECT_WORK_PACKAGE',
 'CREATE TABLE PROJECT_WORK_PACKAGE (
    ACTUAL_FINISH DATE,
    ACTUAL_START DATE,
    APPORTIONED_PROJECT_WP_UID RAW(16),
    BASELINE_FINISH DATE,
    BASELINE_START DATE,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    DESCRIPTION NVARCHAR2(256),
    EARLY_FINISH DATE,
    EARLY_START DATE,
    EVT VARCHAR2(1),
    FORECAST_FINISH DATE,
    FORECAST_START DATE,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    LATE_FINISH DATE,
    LATE_START DATE,
    MANAGER_USER_UID RAW(16),
    NAME NVARCHAR2(100) NOT NULL,
    OBS_CODE_UID RAW(16),
    PENDING_FINISH DATE,
    PENDING_START DATE,
    PERCENT_COMPLETE NUMBER(5,2) DEFAULT (0),
    PROJECT_CONTROL_ACCOUNT_UID RAW(16) NOT NULL,
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    START_PERCENT NUMBER(5,2) DEFAULT (0),
    UNITS_COMPLETE NUMBER(21,6) DEFAULT (0),
    UNITS_TO_DO NUMBER(21,6) DEFAULT (0),
    WBS_CODE_UID RAW(16)
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PROJECT_WORK_PACKAGE', 'ROW_UID');
CREATE_NATURAL_KEY('PROJECT_WORK_PACKAGE', 'NAME, PROJECT_CONTROL_ACCOUNT_UID');

ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'ACTUAL_FINISH', 'Actual Finish / Forecast Finish Date');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'ACTUAL_START', 'Actual Start  / Forecast Start Date');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'APPORTIONED_PROJECT_WP_UID', 'Unique Apportioned Project Work Package Identifier.');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'BASELINE_FINISH', 'Baseline Finish Date');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'BASELINE_START', 'Baseline Start Date');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'CREATED_BY_USER_UID', 'The User that created the Project Work Package.');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'CREATED_DATE', 'Date the Project Work Package was created.');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'DESCRIPTION', 'Project Work Package Description.');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'EARLY_FINISH', 'Early Finish Date');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'EARLY_START', 'Early Start Date');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'EVT', 'Earned Value Performance Measurement Technique');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'FORECAST_FINISH', 'Forecast Finish Date');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'FORECAST_START', 'Forecast Start Date');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Project Work Package.');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Project Work Package.');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'LATE_FINISH', 'Late Finish Date');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'LATE_START', 'Late Start Date');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'MANAGER_USER_UID', 'Unique Work Package Manager User Identifier.');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'NAME', 'Project Work Package Name');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'OBS_CODE_UID', 'Unique OBS Code Identifier.');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'PENDING_FINISH', 'Pending Finish Date');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'PENDING_START', 'Pending Start Date');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'PERCENT_COMPLETE', 'Percent Complete');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'PROJECT_CONTROL_ACCOUNT_UID', 'Unique Project Contol Account Identifier.');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'ROW_UID', 'Unique Project Work Package Identifier.');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'START_PERCENT', 'Start Percent');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'UNITS_COMPLETE', 'Units Complete');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'UNITS_TO_DO', 'Units To Do');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE', 'WBS_CODE_UID', 'Unique WBS Code Identifier.');

-- Create table PROJECT_COST_CLASS
CREATE_TABLE(
 'PROJECT_COST_CLASS',
 'CREATE TABLE PROJECT_COST_CLASS (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    NAME NVARCHAR2(100) NOT NULL,
    PROJECT_UID RAW(16) NOT NULL,
    RATE_FILE_UID RAW(16) NOT NULL,
    FISCAL_CALENDAR_SET_UID RAW(16) NOT NULL,
    COST_CLASS_TYPE VARCHAR2(1) NOT NULL,
    COST_CLASS_LEVEL VARCHAR2(2) NOT NULL,
    REQUIRED NUMBER(1,0) DEFAULT (0) NOT NULL,
    CALC_SOURCE_RESULTS NUMBER(1,0) DEFAULT (1) NOT NULL,
    DATE_SET VARCHAR2(1),
    BUDGET_SOURCE VARCHAR2(3),
    FCAST_METHOD VARCHAR2(3),
    FCAST_SCALE_EAC VARCHAR2(1),
    FCAST_PERF_FACTOR_LEVEL VARCHAR2(3),
    FCAST_PERF_FACTOR_CODE VARCHAR2(1),
    FCAST_PERF_FACTOR_WEIGHT_A NUMBER(21,6) DEFAULT (0) NOT NULL,
    FCAST_PERF_FACTOR_WEIGHT_B NUMBER(21,6) DEFAULT (0) NOT NULL,
    FCAST_PCT_RANGE1_PERCENT NUMBER(5,0) DEFAULT (0) NOT NULL,
    FCAST_PCT_RANGE2_PERCENT NUMBER(5,0) DEFAULT (0) NOT NULL,
    FCAST_PCT_RANGE3_PERCENT NUMBER(5,0) DEFAULT (0) NOT NULL,
    FCAST_PCT_RANGE1_METHOD VARCHAR2(3),
    FCAST_PCT_RANGE2_METHOD VARCHAR2(3),
    FCAST_PCT_RANGE3_METHOD VARCHAR2(3),
    FCAST_PCT_RANGE4_METHOD VARCHAR2(3),
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    DESCRIPTION NVARCHAR2(256),
    READONLY NUMBER(5,0),
    RANGE_FIELDID VARCHAR2(30),
    IS_BCWS NUMBER(19,0) DEFAULT (0),
    IS_ACWP NUMBER(19,0) DEFAULT (0),
    FC_DATESET VARCHAR2(1) DEFAULT ('' ''),
    PLUSPLUS VARCHAR2(3) DEFAULT ('' ''),
    MINUSPLUS VARCHAR2(3) DEFAULT ('' ''),
    MINUSMINUS VARCHAR2(3) DEFAULT ('' ''),
    CLASSCAL VARCHAR2(2) DEFAULT ('' ''),
    CLASSRATE VARCHAR2(22) DEFAULT ('' ''),
    PROGRAM VARCHAR2(22) DEFAULT ('' '')
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PROJECT_COST_CLASS', 'ROW_UID');
CREATE_NATURAL_KEY('PROJECT_COST_CLASS', 'NAME, PROJECT_UID');

ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'ROW_UID', 'Unique Cost Class Identifier.');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'NAME', 'Class Name.');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'PROJECT_UID', 'Unique Project Identifier.');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'RATE_FILE_UID', 'Unique Rate File Identifier.');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'FISCAL_CALENDAR_SET_UID', 'Unique Fiscal Calendar Set Identifier.');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'COST_CLASS_TYPE', 'Cost Class Type');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'COST_CLASS_LEVEL', 'Cost Class Level');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'REQUIRED', 'Cost Class is System defined and cannot be deleted.');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'CALC_SOURCE_RESULTS', 'Calculate Source Results');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'DATE_SET', 'Budget or Forecast Date Set');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'BUDGET_SOURCE', 'Budget Source Account used in the Project Audit Log');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'FCAST_METHOD', 'Forecast Method');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'FCAST_SCALE_EAC', 'Scale EAC Values');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'FCAST_PERF_FACTOR_LEVEL', 'Performance Factor Level');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'FCAST_PERF_FACTOR_CODE', 'Performance Factor Code  when you choose a Performance Factor Level of Level1 - Level20');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'FCAST_PERF_FACTOR_WEIGHT_A', 'Performance Factor Weight A');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'FCAST_PERF_FACTOR_WEIGHT_B', 'Performance Factor Weight B');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'FCAST_PCT_RANGE1_PERCENT', 'Percent Complete Range 1 Percent');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'FCAST_PCT_RANGE2_PERCENT', 'Percent Complete Range 2 Percent');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'FCAST_PCT_RANGE3_PERCENT', 'Percent Complete Range 3 Percent');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'FCAST_PCT_RANGE1_METHOD', 'Percent Complete Range 1 Forecast Method');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'FCAST_PCT_RANGE2_METHOD', 'Percent Complete Range 2 Forecast Method');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'FCAST_PCT_RANGE3_METHOD', 'Percent Complete Range 3 Forecast Method');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'FCAST_PCT_RANGE4_METHOD', 'Percent Complete Range 4 Forecast Method');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'CREATED_BY_USER_UID', 'The User that created the Cost Class.');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'CREATED_DATE', 'Date the Cost Class was created.');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Cost Class.');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Cost Class.');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'DESCRIPTION', 'Cost Class Description');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'READONLY', 'Read Only');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'RANGE_FIELDID', 'Range Field ID');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'IS_BCWS', 'Is Budgeted Cost of Work Scheduled');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'IS_ACWP', 'Is Actual Cost of Work Performed');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'FC_DATESET', 'Forecast Date Set');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'PLUSPLUS', 'Plus Plus');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'MINUSPLUS', 'Minus Plus');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'MINUSMINUS', 'Minus Minus');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'CLASSCAL', 'Class Calculation');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'CLASSRATE', 'Class Rate');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS', 'PROGRAM', 'Program');

-- Create table PROJECT_COST_CLASS_LINK
CREATE_TABLE(
 'PROJECT_COST_CLASS_LINK',
 'CREATE TABLE PROJECT_COST_CLASS_LINK (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    PARENT_PROJECT_COST_CLASS_UID RAW(16) NOT NULL,
    PROJECT_COST_CLASS_UID RAW(16) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    PROGRAM VARCHAR2(22),
    CLASS VARCHAR2(20),
    CONTAINEDCLASS VARCHAR2(20)
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PROJECT_COST_CLASS_LINK', 'ROW_UID');
CREATE_NATURAL_KEY('PROJECT_COST_CLASS_LINK', 'PARENT_PROJECT_COST_CLASS_UID, PROJECT_COST_CLASS_UID');

ADD_COLUMN_COMMENT('PROJECT_COST_CLASS_LINK', 'ROW_UID', 'Unique Project Cost Class Link Identifier.');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS_LINK', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS_LINK', 'PARENT_PROJECT_COST_CLASS_UID', 'Unique Identifier of the Parent Project Cost Class.');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS_LINK', 'PROJECT_COST_CLASS_UID', 'Unique Identifier of the linked Project Cost Class.');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS_LINK', 'CREATED_BY_USER_UID', 'Unique Identifier of the User that created the Project Cost Class Link.');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS_LINK', 'CREATED_DATE', 'Date the Project Cost Class Link was created.');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS_LINK', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Cost Class Link.');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS_LINK', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Cost Class Link.');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS_LINK', 'PROGRAM', 'Program');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS_LINK', 'CLASS', 'Class');
ADD_COLUMN_COMMENT('PROJECT_COST_CLASS_LINK', 'CONTAINEDCLASS', 'Contained Class');

-- Create table PROJECT_COST_SET
CREATE_TABLE(
 'PROJECT_COST_SET',
 'CREATE TABLE PROJECT_COST_SET (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    PROJECT_UID RAW(16) NOT NULL,
    NAME NVARCHAR2(100) NOT NULL,
    REQUIRED NUMBER(1,0) DEFAULT (0) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    DESCRIPTION NVARCHAR2(256),
    PROGRAM NVARCHAR2(22) DEFAULT ('' '')
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PROJECT_COST_SET', 'ROW_UID');
CREATE_NATURAL_KEY('PROJECT_COST_SET', 'PROJECT_UID, NAME');

ADD_COLUMN_COMMENT('PROJECT_COST_SET', 'ROW_UID', 'Unique Cost Set Identifier.');
ADD_COLUMN_COMMENT('PROJECT_COST_SET', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('PROJECT_COST_SET', 'PROJECT_UID', 'Unique Project Identifier.');
ADD_COLUMN_COMMENT('PROJECT_COST_SET', 'NAME', 'Cost Set Name');
ADD_COLUMN_COMMENT('PROJECT_COST_SET', 'REQUIRED', 'Cost Set is System defined and cannot be deleted.');
ADD_COLUMN_COMMENT('PROJECT_COST_SET', 'CREATED_BY_USER_UID', 'The User that created the Cost Set.');
ADD_COLUMN_COMMENT('PROJECT_COST_SET', 'CREATED_DATE', 'Date the Cost Set was created.');
ADD_COLUMN_COMMENT('PROJECT_COST_SET', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Cost Set.');
ADD_COLUMN_COMMENT('PROJECT_COST_SET', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Cost Set.');
ADD_COLUMN_COMMENT('PROJECT_COST_SET', 'DESCRIPTION', 'Cost Set Description.');
ADD_COLUMN_COMMENT('PROJECT_COST_SET', 'PROGRAM', 'Program');

-- Create table PROJECT_COST_SET_CLASS
CREATE_TABLE(
 'PROJECT_COST_SET_CLASS',
 'CREATE TABLE PROJECT_COST_SET_CLASS (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    PROJECT_COST_SET_UID RAW(16) NOT NULL,
    PROJECT_COST_CLASS_UID RAW(16) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    PROGRAM VARCHAR2(22) DEFAULT ('' ''),
    COST VARCHAR2(20) DEFAULT ('' ''),
    CLASS VARCHAR2(20)
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PROJECT_COST_SET_CLASS', 'ROW_UID');
CREATE_NATURAL_KEY('PROJECT_COST_SET_CLASS', 'PROJECT_COST_SET_UID, PROJECT_COST_CLASS_UID');

ADD_COLUMN_COMMENT('PROJECT_COST_SET_CLASS', 'ROW_UID', 'Unique Cost Set Class Identifier.');
ADD_COLUMN_COMMENT('PROJECT_COST_SET_CLASS', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('PROJECT_COST_SET_CLASS', 'PROJECT_COST_SET_UID', 'Unique Project Cost Set Identifier.');
ADD_COLUMN_COMMENT('PROJECT_COST_SET_CLASS', 'PROJECT_COST_CLASS_UID', 'Unique Project Cost Class Identifier.');
ADD_COLUMN_COMMENT('PROJECT_COST_SET_CLASS', 'CREATED_BY_USER_UID', 'The User that created the Cost Set Class.');
ADD_COLUMN_COMMENT('PROJECT_COST_SET_CLASS', 'CREATED_DATE', 'Date the Cost Set Class was created.');
ADD_COLUMN_COMMENT('PROJECT_COST_SET_CLASS', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Cost Set Class.');
ADD_COLUMN_COMMENT('PROJECT_COST_SET_CLASS', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Cost Set Class.');
ADD_COLUMN_COMMENT('PROJECT_COST_SET_CLASS', 'PROGRAM', 'Program');
ADD_COLUMN_COMMENT('PROJECT_COST_SET_CLASS', 'COST', 'Cost');
ADD_COLUMN_COMMENT('PROJECT_COST_SET_CLASS', 'CLASS', 'Class');

-- Create table PROJECT_COST_TOTAL
CREATE_TABLE(
 'PROJECT_COST_TOTAL',
 'CREATE TABLE PROJECT_COST_TOTAL (
    ROW_UID RAW(16) NOT NULL,
    ACWP NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWP NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BAC NUMBER(21,6) DEFAULT (0) NOT NULL,
    EAC NUMBER(21,6) DEFAULT (0) NOT NULL,
    ACWP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWS_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BAC_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    EAC_HRS NUMBER(21,6) DEFAULT (0) NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PROJECT_COST_TOTAL', 'ROW_UID');

ADD_COLUMN_COMMENT('PROJECT_COST_TOTAL', 'ROW_UID', 'Unique Project Identifier.');
ADD_COLUMN_COMMENT('PROJECT_COST_TOTAL', 'ACWP', 'Actuals.');
ADD_COLUMN_COMMENT('PROJECT_COST_TOTAL', 'BCWP', 'Earned.');
ADD_COLUMN_COMMENT('PROJECT_COST_TOTAL', 'BCWS', 'Budget To Date.');
ADD_COLUMN_COMMENT('PROJECT_COST_TOTAL', 'BAC', 'Budget at Completion.');
ADD_COLUMN_COMMENT('PROJECT_COST_TOTAL', 'EAC', 'Forecast or Estimate at Complete.');
ADD_COLUMN_COMMENT('PROJECT_COST_TOTAL', 'ACWP_HRS', 'Hours Actual.');
ADD_COLUMN_COMMENT('PROJECT_COST_TOTAL', 'BCWP_HRS', 'Hours Earned.');
ADD_COLUMN_COMMENT('PROJECT_COST_TOTAL', 'BCWS_HRS', 'Hours Budget to Date.');
ADD_COLUMN_COMMENT('PROJECT_COST_TOTAL', 'BAC_HRS', 'Hours Budget.');
ADD_COLUMN_COMMENT('PROJECT_COST_TOTAL', 'EAC_HRS', 'Forecast Hours.');

-- Create table PROJECT_SUBPROJECT
CREATE_TABLE(
 'PROJECT_SUBPROJECT',
 'CREATE TABLE PROJECT_SUBPROJECT (
    PROJECT_UID RAW(16),
    SUBPROJECT_UID RAW(16),
    MASTER NVARCHAR2(22),
    SUBPROGRAM NVARCHAR2(22)
)
 %TABLETABLESPACE%'
);


ADD_COLUMN_COMMENT('PROJECT_SUBPROJECT', 'PROJECT_UID', 'Unique Project record identifier of the Master Project.');
ADD_COLUMN_COMMENT('PROJECT_SUBPROJECT', 'SUBPROJECT_UID', 'Unique Project record identifier of the SubProject.');

-- Create table PROJECT_WP_MILESTONE
CREATE_TABLE(
 'PROJECT_WP_MILESTONE',
 'CREATE TABLE PROJECT_WP_MILESTONE (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    PROJECT_WORK_PACKAGE_UID RAW(16) NOT NULL,
    NAME NVARCHAR2(100) NOT NULL,
    BASELINE_FINISH DATE,
    ACTUAL_FINISH DATE,
    STATUS VARCHAR2(1) NOT NULL,
    WEIGHT NUMBER(21,6) DEFAULT (0) NOT NULL,
    PERCENT_COMPLETE NUMBER(5,2) DEFAULT (0) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    DESCRIPTION NVARCHAR2(256),
    CL_BATCH NUMBER(19,0) DEFAULT (0),
    PROGRAM VARCHAR2(22) DEFAULT ('' ''),
    CAWPID NUMBER(19,0) DEFAULT (0),
    FORECAST_FINISH DATE
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PROJECT_WP_MILESTONE', 'ROW_UID');
CREATE_NATURAL_KEY('PROJECT_WP_MILESTONE', 'PROJECT_WORK_PACKAGE_UID, NAME');

ADD_COLUMN_COMMENT('PROJECT_WP_MILESTONE', 'ROW_UID', 'Unique Project Work Package Milestone Identifier.');
ADD_COLUMN_COMMENT('PROJECT_WP_MILESTONE', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('PROJECT_WP_MILESTONE', 'PROJECT_WORK_PACKAGE_UID', 'Unique Project Work Package Identifier.');
ADD_COLUMN_COMMENT('PROJECT_WP_MILESTONE', 'NAME', 'Project Work Package Milestone Name.');
ADD_COLUMN_COMMENT('PROJECT_WP_MILESTONE', 'BASELINE_FINISH', 'Baseline Finish.');
ADD_COLUMN_COMMENT('PROJECT_WP_MILESTONE', 'ACTUAL_FINISH', 'Actual Finish.');
ADD_COLUMN_COMMENT('PROJECT_WP_MILESTONE', 'STATUS', 'Status.');
ADD_COLUMN_COMMENT('PROJECT_WP_MILESTONE', 'WEIGHT', 'Weight.');
ADD_COLUMN_COMMENT('PROJECT_WP_MILESTONE', 'PERCENT_COMPLETE', 'Percent Complete.');
ADD_COLUMN_COMMENT('PROJECT_WP_MILESTONE', 'CREATED_BY_USER_UID', 'The User that created the Project Work Package Milestone.');
ADD_COLUMN_COMMENT('PROJECT_WP_MILESTONE', 'CREATED_DATE', 'Date the Project Work Package Milestone was created.');
ADD_COLUMN_COMMENT('PROJECT_WP_MILESTONE', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Project Work Package Milestone.');
ADD_COLUMN_COMMENT('PROJECT_WP_MILESTONE', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Project Work Package Milestone.');
ADD_COLUMN_COMMENT('PROJECT_WP_MILESTONE', 'DESCRIPTION', 'Project Work Package Milestone Description.');
ADD_COLUMN_COMMENT('PROJECT_WP_MILESTONE', 'CL_BATCH', 'Closing Batch');
ADD_COLUMN_COMMENT('PROJECT_WP_MILESTONE', 'PROGRAM', 'Program');
ADD_COLUMN_COMMENT('PROJECT_WP_MILESTONE', 'CAWPID', 'Control Account Work Package ID');
ADD_COLUMN_COMMENT('PROJECT_WP_MILESTONE', 'FORECAST_FINISH', 'Project Work Package Milestone forcast finish date.');

-- Create table RATE
CREATE_TABLE(
 'RATE',
 'CREATE TABLE RATE (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    RATE_SET_UID RAW(16) NOT NULL,
    RATE_DATE DATE NOT NULL,
    RATE_VALUE NUMBER(21,6) DEFAULT (0) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    RATEFILE VARCHAR2(22) DEFAULT ('' ''),
    RATE_TABLE VARCHAR2(59) DEFAULT ('' '')
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('RATE', 'ROW_UID');
CREATE_NATURAL_KEY('RATE', 'RATE_SET_UID, RATE_DATE');

ADD_COLUMN_COMMENT('RATE', 'ROW_UID', 'Unique Rate Identifier.');
ADD_COLUMN_COMMENT('RATE', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('RATE', 'RATE_SET_UID', 'Unique Rate Set Identifier.');
ADD_COLUMN_COMMENT('RATE', 'RATE_DATE', 'Effective Date of the Rate.');
ADD_COLUMN_COMMENT('RATE', 'RATE_VALUE', 'Rate Value.');
ADD_COLUMN_COMMENT('RATE', 'CREATED_BY_USER_UID', 'The User that created the Rate.');
ADD_COLUMN_COMMENT('RATE', 'CREATED_DATE', 'Date the Rate was created.');
ADD_COLUMN_COMMENT('RATE', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Rate.');
ADD_COLUMN_COMMENT('RATE', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Rate.');
ADD_COLUMN_COMMENT('RATE', 'RATEFILE', 'Rate File');
ADD_COLUMN_COMMENT('RATE', 'RATE_TABLE', 'Rate Table');

-- Create table RATE_FILE
CREATE_TABLE(
 'RATE_FILE',
 'CREATE TABLE RATE_FILE (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    NAME NVARCHAR2(100) NOT NULL,
    DESCRIPTION NVARCHAR2(256),
    OWNER_USER_UID RAW(16) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('RATE_FILE', 'ROW_UID');
CREATE_NATURAL_KEY('RATE_FILE', 'NAME');

ADD_COLUMN_COMMENT('RATE_FILE', 'ROW_UID', 'Unique Rate File Identifier.');
ADD_COLUMN_COMMENT('RATE_FILE', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('RATE_FILE', 'NAME', 'Rate File Name.');
ADD_COLUMN_COMMENT('RATE_FILE', 'DESCRIPTION', 'Rate File Description.');
ADD_COLUMN_COMMENT('RATE_FILE', 'OWNER_USER_UID', 'The User that owns the Rate File.');
ADD_COLUMN_COMMENT('RATE_FILE', 'CREATED_BY_USER_UID', 'The User that created the Rate File.');
ADD_COLUMN_COMMENT('RATE_FILE', 'CREATED_DATE', 'Date the Rate File was created.');
ADD_COLUMN_COMMENT('RATE_FILE', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Rate File.');
ADD_COLUMN_COMMENT('RATE_FILE', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Rate File.');

-- Create table RATE_SET
CREATE_TABLE(
 'RATE_SET',
 'CREATE TABLE RATE_SET (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    RATE_FILE_UID RAW(16) NOT NULL,
    NAME NVARCHAR2(100) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    DESCRIPTION NVARCHAR2(256),
    C1 VARCHAR2(59),
    C2 VARCHAR2(59),
    RATEFILE VARCHAR2(22)
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('RATE_SET', 'ROW_UID');
CREATE_NATURAL_KEY('RATE_SET', 'RATE_FILE_UID, NAME');

ADD_COLUMN_COMMENT('RATE_SET', 'ROW_UID', 'Unique Rate Set Identifier.');
ADD_COLUMN_COMMENT('RATE_SET', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('RATE_SET', 'RATE_FILE_UID', 'Unique Rate File Identifier.');
ADD_COLUMN_COMMENT('RATE_SET', 'NAME', 'Rate Set Name.');
ADD_COLUMN_COMMENT('RATE_SET', 'CREATED_BY_USER_UID', 'The User that created the Rate Set.');
ADD_COLUMN_COMMENT('RATE_SET', 'CREATED_DATE', 'Date the Rate Set was created.');
ADD_COLUMN_COMMENT('RATE_SET', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Rate Set.');
ADD_COLUMN_COMMENT('RATE_SET', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Rate Set.');
ADD_COLUMN_COMMENT('RATE_SET', 'DESCRIPTION', 'Rate Set Description.');
ADD_COLUMN_COMMENT('RATE_SET', 'RATEFILE', 'Rate File');

-- Create table RESOURCE_COST_CALCULATION
CREATE_TABLE(
 'RESOURCE_COST_CALCULATION',
 'CREATE TABLE RESOURCE_COST_CALCULATION (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    RESOURCES_UID RAW(16) NOT NULL,
    RATE_SET_UID RAW(16),
    LINE NUMBER(19,0) DEFAULT (0) NOT NULL,
    RESULT_FIELD VARCHAR2(10) NOT NULL,
    RESULT_LABEL VARCHAR2(20) NOT NULL,
    RESULT_CODE VARCHAR2(1),
    UNITS VARCHAR2(10) NOT NULL,
    CURRENCY NUMBER(1,0) DEFAULT (0) NOT NULL,
    SOURCE1 VARCHAR2(10),
    SOURCE2 VARCHAR2(10),
    SOURCE3 VARCHAR2(10),
    SOURCE4 VARCHAR2(10),
    SOURCE5 VARCHAR2(10),
    SOURCE6 VARCHAR2(10),
    SOURCE7 VARCHAR2(10),
    SOURCE8 VARCHAR2(10),
    SOURCE9 VARCHAR2(10),
    SOURCE10 VARCHAR2(10),
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    CALCFILE VARCHAR2(22),
    CECODE VARCHAR2(59) DEFAULT ('' ''),
    RATE_TABLE VARCHAR2(59)
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('RESOURCE_COST_CALCULATION', 'ROW_UID');

ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'ROW_UID', 'Unique Resource Result Identifier.');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'RESOURCES_UID', 'Unique Resource Identifier.');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'RATE_SET_UID', 'Unique Rate Set Identifier.');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'LINE', 'Line');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'RESULT_FIELD', 'Result Field Name');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'RESULT_LABEL', 'Display name of the Result Field.');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'RESULT_CODE', 'Result Code.');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'UNITS', 'Units for Measure.');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'CURRENCY', 'Result is a Currency Value.');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'SOURCE1', 'First Source Field.');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'SOURCE2', 'Second Source Field.');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'SOURCE3', 'Third Source Field.');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'SOURCE4', 'Fourth Source Field.');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'SOURCE5', 'Fifth Source Field.');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'SOURCE6', 'Sixth Source Field.');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'SOURCE7', 'Seventh Source Field.');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'SOURCE8', 'Eighth Source Field.');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'SOURCE9', 'Ninth Source Field.');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'SOURCE10', 'Tenth Source Field.');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'CREATED_BY_USER_UID', 'The User that created the Resource Result.');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'CREATED_DATE', 'Date the Resource Result was created.');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Resource Result.');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Resource Result.');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'CALCFILE', 'Calculation File');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'CECODE', 'Cost Element Code');
ADD_COLUMN_COMMENT('RESOURCE_COST_CALCULATION', 'RATE_TABLE', 'Rate Table');

-- Create table RESOURCE_FILE
CREATE_TABLE(
 'RESOURCE_FILE',
 'CREATE TABLE RESOURCE_FILE (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    NAME NVARCHAR2(100) NOT NULL,
    DESCRIPTION NVARCHAR2(256),
    CODE_TYPE VARCHAR2(1) NOT NULL,
    RATE_FILE_UID RAW(16),
    RSLTALL VARCHAR2(256),
    RSLTCURR VARCHAR2(256),
    OWNER_USER_UID RAW(16) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    CODELENGTH NUMBER(19,0) DEFAULT (0),
    LEVEL1 NUMBER(19,0) DEFAULT (0),
    LEVEL10 NUMBER(19,0) DEFAULT (0),
    LEVEL11 NUMBER(19,0) DEFAULT (0),
    LEVEL12 NUMBER(19,0) DEFAULT (0),
    LEVEL13 NUMBER(19,0) DEFAULT (0),
    LEVEL14 NUMBER(19,0) DEFAULT (0),
    LEVEL15 NUMBER(19,0) DEFAULT (0),
    LEVEL16 NUMBER(19,0) DEFAULT (0),
    LEVEL17 NUMBER(19,0) DEFAULT (0),
    LEVEL18 NUMBER(19,0) DEFAULT (0),
    LEVEL19 NUMBER(19,0) DEFAULT (0),
    LEVEL2 NUMBER(19,0) DEFAULT (0),
    LEVEL20 NUMBER(19,0) DEFAULT (0),
    LEVEL3 NUMBER(19,0) DEFAULT (0),
    LEVEL4 NUMBER(19,0) DEFAULT (0),
    LEVEL5 NUMBER(19,0) DEFAULT (0),
    LEVEL6 NUMBER(19,0) DEFAULT (0),
    LEVEL7 NUMBER(19,0) DEFAULT (0),
    LEVEL8 NUMBER(19,0) DEFAULT (0),
    LEVEL9 NUMBER(19,0) DEFAULT (0),
    MAX_LEVEL NUMBER(19,0) DEFAULT (0),
    PAD_CHAR VARCHAR2(1),
    TH_FLAGS VARCHAR2(10),
    RATEFILE VARCHAR2(22) DEFAULT ('' '')
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('RESOURCE_FILE', 'ROW_UID');
CREATE_NATURAL_KEY('RESOURCE_FILE', 'NAME');

ADD_COLUMN_COMMENT('RESOURCE_FILE', 'ROW_UID', 'Unique Resource File Identifier.');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'NAME', 'Resource File Name.');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'DESCRIPTION', 'Resource File Description.');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'CODE_TYPE', 'Resource File Code Type. Supported values are P or N.');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'RATE_FILE_UID', 'Unique Rate File Identifier.');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'RSLTALL', 'Result List.');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'RSLTCURR', 'Currency Results.');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'OWNER_USER_UID', 'The User that owns the Resource File.');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'CREATED_BY_USER_UID', 'The User that created the Resource File.');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'CREATED_DATE', 'Date the Resource File was created.');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Resource File.');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Resource File.');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'CODELENGTH', 'Code Length');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'LEVEL1', 'Level 1');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'LEVEL10', 'Level 10');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'LEVEL11', 'Level 11');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'LEVEL12', 'Level 12');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'LEVEL13', 'Level 13');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'LEVEL14', 'Level 14');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'LEVEL15', 'Level 15');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'LEVEL16', 'Level 16');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'LEVEL17', 'Level 17');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'LEVEL18', 'Level 18');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'LEVEL19', 'Level 19');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'LEVEL2', 'Level 2');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'LEVEL20', 'Level 20');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'LEVEL3', 'Level 3');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'LEVEL4', 'Level 4');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'LEVEL5', 'Level 5');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'LEVEL6', 'Level 6');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'LEVEL7', 'Level 7');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'LEVEL8', 'Level 8');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'LEVEL9', 'Level 9');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'MAX_LEVEL', 'Maximum Level');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'PAD_CHAR', 'Padding Character');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'TH_FLAGS', 'Threshold Flags');
ADD_COLUMN_COMMENT('RESOURCE_FILE', 'RATEFILE', 'Rate File');

-- Create table RESOURCE_FILE_COST_RESULT
CREATE_TABLE(
 'RESOURCE_FILE_COST_RESULT',
 'CREATE TABLE RESOURCE_FILE_COST_RESULT (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    RESOURCE_FILE_UID RAW(16) NOT NULL,
    RATE_SET_UID RAW(16),
    LINE NUMBER(5,0) DEFAULT (0) NOT NULL,
    RESULT_FIELD NVARCHAR2(10) NOT NULL,
    RESULT_LABEL NVARCHAR2(20) NOT NULL,
    RESULT_CODE NVARCHAR2(1) NOT NULL,
    UNITS NVARCHAR2(10) NOT NULL,
    CURRENCY NUMBER(1,0) DEFAULT (0) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    CALCFILE VARCHAR2(22) DEFAULT ('' ''),
    RATETABLE VARCHAR2(59) DEFAULT ('' '')
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('RESOURCE_FILE_COST_RESULT', 'ROW_UID');

ADD_COLUMN_COMMENT('RESOURCE_FILE_COST_RESULT', 'ROW_UID', 'Unique Resource File Result Identifier.');
ADD_COLUMN_COMMENT('RESOURCE_FILE_COST_RESULT', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('RESOURCE_FILE_COST_RESULT', 'RESOURCE_FILE_UID', 'Unique Resource File Identifier.');
ADD_COLUMN_COMMENT('RESOURCE_FILE_COST_RESULT', 'RATE_SET_UID', 'Unique Rate Set Identifier.');
ADD_COLUMN_COMMENT('RESOURCE_FILE_COST_RESULT', 'LINE', 'Line');
ADD_COLUMN_COMMENT('RESOURCE_FILE_COST_RESULT', 'RESULT_FIELD', 'Result Field Name');
ADD_COLUMN_COMMENT('RESOURCE_FILE_COST_RESULT', 'RESULT_LABEL', 'Display name of the Result Field.');
ADD_COLUMN_COMMENT('RESOURCE_FILE_COST_RESULT', 'RESULT_CODE', 'Result Code');
ADD_COLUMN_COMMENT('RESOURCE_FILE_COST_RESULT', 'UNITS', 'Units for Measure.');
ADD_COLUMN_COMMENT('RESOURCE_FILE_COST_RESULT', 'CURRENCY', 'Result is a Currency Value.');
ADD_COLUMN_COMMENT('RESOURCE_FILE_COST_RESULT', 'CREATED_BY_USER_UID', 'The User that created the Resource File Result.');
ADD_COLUMN_COMMENT('RESOURCE_FILE_COST_RESULT', 'CREATED_DATE', 'Date the Resource File Result was created.');
ADD_COLUMN_COMMENT('RESOURCE_FILE_COST_RESULT', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Resource File Result.');
ADD_COLUMN_COMMENT('RESOURCE_FILE_COST_RESULT', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Resource File Result.');
ADD_COLUMN_COMMENT('RESOURCE_FILE_COST_RESULT', 'CALCFILE', 'Calculation File');
ADD_COLUMN_COMMENT('RESOURCE_FILE_COST_RESULT', 'RATETABLE', 'Rate Table');

-- Create table RESOURCES
CREATE_TABLE(
 'RESOURCES',
 'CREATE TABLE RESOURCES (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    RESOURCE_FILE_UID RAW(16) NOT NULL,
    PARENT_RESOURCES_UID RAW(16),
    NAME NVARCHAR2(100) NOT NULL,
    CHILD_COUNT NUMBER(19,0) DEFAULT (0),
    RESOURCE_LEVEL NUMBER(19,0) DEFAULT (1),
    EOC VARCHAR2(59),
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    DESCRIPTION NVARCHAR2(256),
    D1 NVARCHAR2(59) DEFAULT ('' ''),
    D2 NVARCHAR2(59) DEFAULT ('' ''),
    D3 NVARCHAR2(59) DEFAULT ('' ''),
    D4 NVARCHAR2(59) DEFAULT ('' ''),
    D5 NVARCHAR2(59) DEFAULT ('' ''),
    D6 NVARCHAR2(59) DEFAULT ('' ''),
    D7 NVARCHAR2(59) DEFAULT ('' ''),
    D8 NVARCHAR2(59) DEFAULT ('' ''),
    D9 NVARCHAR2(59) DEFAULT ('' ''),
    TAG VARCHAR2(60) DEFAULT ('' ''),
    TH_CAPF NUMBER(21,6) DEFAULT (0),
    TH_CAPU NUMBER(21,6) DEFAULT (0),
    TH_CAVF NUMBER(21,6) DEFAULT (0),
    TH_CAVU NUMBER(21,6) DEFAULT (0),
    TH_CCPF NUMBER(21,6) DEFAULT (0),
    TH_CCPU NUMBER(21,6) DEFAULT (0),
    TH_CCVF NUMBER(21,6) DEFAULT (0),
    TH_CCVU NUMBER(21,6) DEFAULT (0),
    TH_CPPF NUMBER(21,6) DEFAULT (0),
    TH_CPPU NUMBER(21,6) DEFAULT (0),
    TH_CPVF NUMBER(21,6) DEFAULT (0),
    TH_CPVU NUMBER(21,6) DEFAULT (0),
    TH_SCPF NUMBER(21,6) DEFAULT (0),
    TH_SCPU NUMBER(21,6) DEFAULT (0),
    TH_SCVF NUMBER(21,6) DEFAULT (0),
    TH_SCVU NUMBER(21,6) DEFAULT (0),
    TH_SPPF NUMBER(21,6) DEFAULT (0),
    TH_SPPU NUMBER(21,6) DEFAULT (0),
    TH_SPVF NUMBER(21,6) DEFAULT (0),
    TH_SPVU NUMBER(21,6) DEFAULT (0),
    CALCFILE VARCHAR2(22) DEFAULT ('' ''),
    CHILD_POS NUMBER(5,0) DEFAULT (0)
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('RESOURCES', 'ROW_UID');
CREATE_NATURAL_KEY('RESOURCES', 'RESOURCE_FILE_UID, NAME');

ADD_COLUMN_COMMENT('RESOURCES', 'ROW_UID', 'Unique Resource Identifier.');
ADD_COLUMN_COMMENT('RESOURCES', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('RESOURCES', 'RESOURCE_FILE_UID', 'Unique Resource File Identifier.');
ADD_COLUMN_COMMENT('RESOURCES', 'PARENT_RESOURCES_UID', 'Unique Resource record identifier of the Resource records Parent Resource.');
ADD_COLUMN_COMMENT('RESOURCES', 'NAME', 'Resource Name');
ADD_COLUMN_COMMENT('RESOURCES', 'CHILD_COUNT', 'Resource hierarchy level.');
ADD_COLUMN_COMMENT('RESOURCES', 'RESOURCE_LEVEL', 'Child Resource position.');
ADD_COLUMN_COMMENT('RESOURCES', 'EOC', 'Element of Cost (null, L : Labor, M : Material, O:  ODC, S : Subcontract)');
ADD_COLUMN_COMMENT('RESOURCES', 'CREATED_BY_USER_UID', 'The User that created the Resource.');
ADD_COLUMN_COMMENT('RESOURCES', 'CREATED_DATE', 'Date the Resource was created.');
ADD_COLUMN_COMMENT('RESOURCES', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Resource.');
ADD_COLUMN_COMMENT('RESOURCES', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Resource.');
ADD_COLUMN_COMMENT('RESOURCES', 'DESCRIPTION', 'Resource Description.');
ADD_COLUMN_COMMENT('RESOURCES', 'D1', 'Data Field 1');
ADD_COLUMN_COMMENT('RESOURCES', 'D2', 'Data Field 2');
ADD_COLUMN_COMMENT('RESOURCES', 'D3', 'Data Field 3');
ADD_COLUMN_COMMENT('RESOURCES', 'D4', 'Data Field 4');
ADD_COLUMN_COMMENT('RESOURCES', 'D5', 'Data Field 5');
ADD_COLUMN_COMMENT('RESOURCES', 'D6', 'Data Field 6');
ADD_COLUMN_COMMENT('RESOURCES', 'D7', 'Data Field 7');
ADD_COLUMN_COMMENT('RESOURCES', 'D8', 'Data Field 8');
ADD_COLUMN_COMMENT('RESOURCES', 'D9', 'Data Field 9');
ADD_COLUMN_COMMENT('RESOURCES', 'TAG', 'Tag');
ADD_COLUMN_COMMENT('RESOURCES', 'TH_CAPF', 'Threshold Cost At Complete Percent Favorable');
ADD_COLUMN_COMMENT('RESOURCES', 'TH_CAPU', 'Threshold Cost At Complete Percent Unfavorable');
ADD_COLUMN_COMMENT('RESOURCES', 'TH_CAVF', 'Threshold Cost At Complete Variance Favorable');
ADD_COLUMN_COMMENT('RESOURCES', 'TH_CAVU', 'Threshold Cost At Complete Variance Unfavorable');
ADD_COLUMN_COMMENT('RESOURCES', 'TH_CCPF', 'Threshold Current Cost Percent Favorable');
ADD_COLUMN_COMMENT('RESOURCES', 'TH_CCPU', 'Threshold Current Cost Percent Unfavorable');
ADD_COLUMN_COMMENT('RESOURCES', 'TH_CCVF', 'Threshold Current Cost Variance Favorable');
ADD_COLUMN_COMMENT('RESOURCES', 'TH_CCVU', 'Threshold Current Cost Variance Unfavorable');
ADD_COLUMN_COMMENT('RESOURCES', 'TH_CPPF', 'Threshold Completion Percent Percent Favorable');
ADD_COLUMN_COMMENT('RESOURCES', 'TH_CPPU', 'Threshold Completion Percent Percent Unfavorable');
ADD_COLUMN_COMMENT('RESOURCES', 'TH_CPVF', 'Threshold Completion Percent Variance Favorable');
ADD_COLUMN_COMMENT('RESOURCES', 'TH_CPVU', 'Threshold Completion Percent Variance Unfavorable');
ADD_COLUMN_COMMENT('RESOURCES', 'TH_SCPF', 'Threshold Schedule Current Percent Favorable');
ADD_COLUMN_COMMENT('RESOURCES', 'TH_SCPU', 'Threshold Schedule Current Percent Unfavorable');
ADD_COLUMN_COMMENT('RESOURCES', 'TH_SCVF', 'Threshold Schedule Current Variance Favorable');
ADD_COLUMN_COMMENT('RESOURCES', 'TH_SCVU', 'Threshold Schedule Current Variance Unfavorable');
ADD_COLUMN_COMMENT('RESOURCES', 'TH_SPPF', 'Threshold Schedule Performance Percent Favorable');
ADD_COLUMN_COMMENT('RESOURCES', 'TH_SPPU', 'Threshold Schedule Performance Percent Unfavorable');
ADD_COLUMN_COMMENT('RESOURCES', 'TH_SPVF', 'Threshold Schedule Performance Variance Favorable');
ADD_COLUMN_COMMENT('RESOURCES', 'TH_SPVU', 'Threshold Schedule Performance Variance Unfavorable');
ADD_COLUMN_COMMENT('RESOURCES', 'CALCFILE', 'Calculation File');
ADD_COLUMN_COMMENT('RESOURCES', 'CHILD_POS', 'Parent Resource child count.');

-- Create table SPREAD_CURVE
CREATE_TABLE(
 'SPREAD_CURVE',
 'CREATE TABLE SPREAD_CURVE (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    NAME NVARCHAR2(100) NOT NULL,
    POINTS NUMBER(19,0) DEFAULT (0) NOT NULL,
    POINT_VALUES NCLOB NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    SP_F1 NUMBER(19,0) DEFAULT (0),
    SP_F10 NUMBER(19,0) DEFAULT (0),
    SP_F11 NUMBER(19,0) DEFAULT (0),
    SP_F12 NUMBER(19,0) DEFAULT (0),
    SP_F13 NUMBER(19,0) DEFAULT (0),
    SP_F14 NUMBER(19,0) DEFAULT (0),
    SP_F15 NUMBER(19,0) DEFAULT (0),
    SP_F16 NUMBER(19,0) DEFAULT (0),
    SP_F17 NUMBER(19,0) DEFAULT (0),
    SP_F18 NUMBER(19,0) DEFAULT (0),
    SP_F19 NUMBER(19,0) DEFAULT (0),
    SP_F2 NUMBER(19,0) DEFAULT (0),
    SP_F20 NUMBER(19,0) DEFAULT (0),
    SP_F21 NUMBER(19,0) DEFAULT (0),
    SP_F22 NUMBER(19,0) DEFAULT (0),
    SP_F23 NUMBER(19,0) DEFAULT (0),
    SP_F24 NUMBER(19,0) DEFAULT (0),
    SP_F25 NUMBER(19,0) DEFAULT (0),
    SP_F26 NUMBER(19,0) DEFAULT (0),
    SP_F27 NUMBER(19,0) DEFAULT (0),
    SP_F28 NUMBER(19,0) DEFAULT (0),
    SP_F29 NUMBER(19,0) DEFAULT (0),
    SP_F3 NUMBER(19,0) DEFAULT (0),
    SP_F30 NUMBER(19,0) DEFAULT (0),
    SP_F31 NUMBER(19,0) DEFAULT (0),
    SP_F32 NUMBER(19,0) DEFAULT (0),
    SP_F33 NUMBER(19,0) DEFAULT (0),
    SP_F34 NUMBER(19,0) DEFAULT (0),
    SP_F35 NUMBER(19,0) DEFAULT (0),
    SP_F36 NUMBER(19,0) DEFAULT (0),
    SP_F37 NUMBER(19,0) DEFAULT (0),
    SP_F38 NUMBER(19,0) DEFAULT (0),
    SP_F39 NUMBER(19,0) DEFAULT (0),
    SP_F4 NUMBER(19,0) DEFAULT (0),
    SP_F40 NUMBER(19,0) DEFAULT (0),
    SP_F41 NUMBER(19,0) DEFAULT (0),
    SP_F42 NUMBER(19,0) DEFAULT (0),
    SP_F43 NUMBER(19,0) DEFAULT (0),
    SP_F44 NUMBER(19,0) DEFAULT (0),
    SP_F45 NUMBER(19,0) DEFAULT (0),
    SP_F46 NUMBER(19,0) DEFAULT (0),
    SP_F47 NUMBER(19,0) DEFAULT (0),
    SP_F48 NUMBER(19,0) DEFAULT (0),
    SP_F49 NUMBER(19,0) DEFAULT (0),
    SP_F5 NUMBER(19,0) DEFAULT (0),
    SP_F50 NUMBER(19,0) DEFAULT (0),
    SP_F51 NUMBER(19,0) DEFAULT (0),
    SP_F52 NUMBER(19,0) DEFAULT (0),
    SP_F6 NUMBER(19,0) DEFAULT (0),
    SP_F7 NUMBER(19,0) DEFAULT (0),
    SP_F8 NUMBER(19,0) DEFAULT (0),
    SP_F9 NUMBER(19,0) DEFAULT (0),
    SPREADORD NUMBER(19,0) DEFAULT (0)
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('SPREAD_CURVE', 'ROW_UID');
CREATE_NATURAL_KEY('SPREAD_CURVE', 'NAME');

ADD_COLUMN_COMMENT('SPREAD_CURVE', 'ROW_UID', 'Calculation File');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'NAME', 'Spread Curve Name.');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'POINTS', 'The number of Spread Points defined for the Spread Curve.');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'POINT_VALUES', 'Spread Curve Point Values in JSON format.');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'CREATED_BY_USER_UID', 'The User that created the Spread Curve.');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'CREATED_DATE', 'Date the Spread Curve was created.');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Spread Curve.');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Spread Curve.');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F1', 'Spread Field 1');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F10', 'Spread Field 10');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F11', 'Spread Field 11');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F12', 'Spread Field 12');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F13', 'Spread Field 13');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F14', 'Spread Field 14');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F15', 'Spread Field 15');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F16', 'Spread Field 16');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F17', 'Spread Field 17');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F18', 'Spread Field 18');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F19', 'Spread Field 19');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F2', 'Spread Field 2');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F20', 'Spread Field 20');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F21', 'Spread Field 21');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F22', 'Spread Field 22');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F23', 'Spread Field 23');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F24', 'Spread Field 24');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F25', 'Spread Field 25');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F26', 'Spread Field 26');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F27', 'Spread Field 27');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F28', 'Spread Field 28');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F29', 'Spread Field 29');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F3', 'Spread Field 3');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F30', 'Spread Field 30');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F31', 'Spread Field 31');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F32', 'Spread Field 32');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F33', 'Spread Field 33');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F34', 'Spread Field 34');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F35', 'Spread Field 35');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F36', 'Spread Field 36');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F37', 'Spread Field 37');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F38', 'Spread Field 38');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F39', 'Spread Field 39');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F4', 'Spread Field 4');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F40', 'Spread Field 40');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F41', 'Spread Field 41');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F42', 'Spread Field 42');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F43', 'Spread Field 43');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F44', 'Spread Field 44');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F45', 'Spread Field 45');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F46', 'Spread Field 46');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F47', 'Spread Field 47');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F48', 'Spread Field 48');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F49', 'Spread Field 49');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F5', 'Spread Field 5');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F50', 'Spread Field 50');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F51', 'Spread Field 51');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F52', 'Spread Field 52');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F6', 'Spread Field 6');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F7', 'Spread Field 7');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F8', 'Spread Field 8');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SP_F9', 'Spread Field 9');
ADD_COLUMN_COMMENT('SPREAD_CURVE', 'SPREADORD', 'Spread Order');

-- Create table ACCESS_CONTROL_ENTRY
CREATE_TABLE(
 'ACCESS_CONTROL_ENTRY',
 'CREATE TABLE ACCESS_CONTROL_ENTRY (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    ENTITY_UID RAW(16) NOT NULL,
    USER_UID RAW(16),
    GROUP_UID RAW(16),
    ROLE_UID RAW(16),
    VIEWONLY NUMBER(1,0) DEFAULT (0) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('ACCESS_CONTROL_ENTRY', 'ROW_UID');
CREATE_NATURAL_KEY('ACCESS_CONTROL_ENTRY', 'ENTITY_UID, USER_UID, GROUP_UID');

ADD_COLUMN_COMMENT('ACCESS_CONTROL_ENTRY', 'ROW_UID', 'Unique Access Control Entry Identifier.');
ADD_COLUMN_COMMENT('ACCESS_CONTROL_ENTRY', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('ACCESS_CONTROL_ENTRY', 'ENTITY_UID', 'Unique Identifier for the Entity that the Access Control Entry is associated with.');
ADD_COLUMN_COMMENT('ACCESS_CONTROL_ENTRY', 'USER_UID', 'The User the Access Control Entry applies to. NULL if the entry applies to a Group.');
ADD_COLUMN_COMMENT('ACCESS_CONTROL_ENTRY', 'GROUP_UID', 'The Group the Access Control Entry applies to. NULL if the entry applies to a User.');
ADD_COLUMN_COMMENT('ACCESS_CONTROL_ENTRY', 'ROLE_UID', 'The Role that is granted by the Access Control Entry.');
ADD_COLUMN_COMMENT('ACCESS_CONTROL_ENTRY', 'VIEWONLY', 'Restrict the User or Group to Read-Only access to the Entity.');
ADD_COLUMN_COMMENT('ACCESS_CONTROL_ENTRY', 'CREATED_BY_USER_UID', 'The User that created the Access Control Entry.');
ADD_COLUMN_COMMENT('ACCESS_CONTROL_ENTRY', 'CREATED_DATE', 'Date the  Access Control Entry was created.');
ADD_COLUMN_COMMENT('ACCESS_CONTROL_ENTRY', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the  Access Control Entry.');
ADD_COLUMN_COMMENT('ACCESS_CONTROL_ENTRY', 'LAST_MODIFIED_DATE', 'Date the last change was made to the  Access Control Entry.');

-- Create table USER_CODE_VALUE
CREATE_TABLE(
 'USER_CODE_VALUE',
 'CREATE TABLE USER_CODE_VALUE (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    PRIMARY_ENTITY_UID RAW(16) NOT NULL,
    ENTITY_UID RAW(16) NOT NULL,
    FIELD_NAME NVARCHAR2(30) NOT NULL,
    CODE_UID RAW(16) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('USER_CODE_VALUE', 'ROW_UID');
CREATE_NATURAL_KEY('USER_CODE_VALUE', 'PRIMARY_ENTITY_UID, ENTITY_UID, FIELD_NAME');

ADD_COLUMN_COMMENT('USER_CODE_VALUE', 'ROW_UID', 'Unique User Code Value Identifier.');
ADD_COLUMN_COMMENT('USER_CODE_VALUE', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('USER_CODE_VALUE', 'PRIMARY_ENTITY_UID', 'Unique Identifier for the Root Entity  the User Code Value is associated with.');
ADD_COLUMN_COMMENT('USER_CODE_VALUE', 'ENTITY_UID', 'Unique Identifier of the Entity the User Code Value is assigned to.');
ADD_COLUMN_COMMENT('USER_CODE_VALUE', 'FIELD_NAME', 'The Field Name the User Code Value is assigned to.');
ADD_COLUMN_COMMENT('USER_CODE_VALUE', 'CODE_UID', 'Unique Identifier for the Code that is assigned to the field.');
ADD_COLUMN_COMMENT('USER_CODE_VALUE', 'CREATED_BY_USER_UID', 'The User that created the User Code Value.');
ADD_COLUMN_COMMENT('USER_CODE_VALUE', 'CREATED_DATE', 'Date the User Code Value was created.');
ADD_COLUMN_COMMENT('USER_CODE_VALUE', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the User Code Value.');
ADD_COLUMN_COMMENT('USER_CODE_VALUE', 'LAST_MODIFIED_DATE', 'Date the last change was made to the User Code Value.');

-- Create table USER_FIELD_DEFINITION
CREATE_TABLE(
 'USER_FIELD_DEFINITION',
 'CREATE TABLE USER_FIELD_DEFINITION (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    PRIMARY_ENTITY_UID RAW(16),
    CODE_FILE_UID RAW(16),
    ENTITY_TYPE VARCHAR2(30) NOT NULL,
    FIELD_NAME VARCHAR2(30) NOT NULL,
    FIELD_LABEL NVARCHAR2(30) NOT NULL,
    FIELD_DATA_TYPE VARCHAR2(30) NOT NULL,
    REQUIRED NUMBER(1,0) DEFAULT (0) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    DESCRIPTION NVARCHAR2(256),
    SCOPE VARCHAR2(10) NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('USER_FIELD_DEFINITION', 'ROW_UID');
CREATE_NATURAL_KEY('USER_FIELD_DEFINITION', 'PRIMARY_ENTITY_UID, ENTITY_TYPE, FIELD_NAME, FIELD_LABEL');

ADD_COLUMN_COMMENT('USER_FIELD_DEFINITION', 'ROW_UID', 'Unique User Defined Field Identifier.');
ADD_COLUMN_COMMENT('USER_FIELD_DEFINITION', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('USER_FIELD_DEFINITION', 'PRIMARY_ENTITY_UID', 'Unique Identifier for the Entity  the Product Preference is associated with.');
ADD_COLUMN_COMMENT('USER_FIELD_DEFINITION', 'CODE_FILE_UID', 'Unique Code File Identifier.');
ADD_COLUMN_COMMENT('USER_FIELD_DEFINITION', 'ENTITY_TYPE', 'Table name for the Entity the User Field is associated with.');
ADD_COLUMN_COMMENT('USER_FIELD_DEFINITION', 'FIELD_NAME', 'Name of the Field the User Field Definition is mapped to in the USER_FIELD_VALUE_TABLE.');
ADD_COLUMN_COMMENT('USER_FIELD_DEFINITION', 'FIELD_LABEL', 'Display name of the User Field Definition.');
ADD_COLUMN_COMMENT('USER_FIELD_DEFINITION', 'FIELD_DATA_TYPE', 'Data type of the User Defined Field. Enumerated Value of TEXT, NUMBER, DATE, FDATE, DURATION, CODE, MEMO');
ADD_COLUMN_COMMENT('USER_FIELD_DEFINITION', 'REQUIRED', 'A value must be entered in this User Field.');
ADD_COLUMN_COMMENT('USER_FIELD_DEFINITION', 'CREATED_BY_USER_UID', 'The User that created the User Field Definition.');
ADD_COLUMN_COMMENT('USER_FIELD_DEFINITION', 'CREATED_DATE', 'Date the User Field Definition was created.');
ADD_COLUMN_COMMENT('USER_FIELD_DEFINITION', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the User Field Definition.');
ADD_COLUMN_COMMENT('USER_FIELD_DEFINITION', 'LAST_MODIFIED_DATE', 'Date the last change was made to the User Field Definition.');
ADD_COLUMN_COMMENT('USER_FIELD_DEFINITION', 'SCOPE', 'Idenfiy whether the field is enterprise or local');

-- Create table USER_FIELD_VALUE
CREATE_TABLE(
 'USER_FIELD_VALUE',
 'CREATE TABLE USER_FIELD_VALUE (
    ROW_UID RAW(16) NOT NULL,
    PRIMARY_ENTITY_UID RAW(16),
    ENTITY_UID RAW(16) NOT NULL,
    DATE1 DATE,
    USER_FIELD_VALUES NCLOB,
    DATE2 DATE,
    DATE3 DATE,
    DATE4 DATE,
    DATE5 DATE,
    DATE6 DATE,
    DATE7 DATE,
    DATE8 DATE,
    DATE9 DATE,
    DATE10 DATE,
    DATE11 DATE,
    DATE12 DATE,
    DATE13 DATE,
    DATE14 DATE,
    DATE15 DATE,
    DATE16 DATE,
    DATE17 DATE,
    DATE18 DATE,
    DATE19 DATE,
    DATE20 DATE,
    NUMBER1 NUMBER(21,6) DEFAULT (0),
    NUMBER2 NUMBER(21,6) DEFAULT (0),
    NUMBER3 NUMBER(21,6) DEFAULT (0),
    NUMBER4 NUMBER(21,6) DEFAULT (0),
    NUMBER5 NUMBER(21,6) DEFAULT (0),
    NUMBER6 NUMBER(21,6) DEFAULT (0),
    NUMBER7 NUMBER(21,6) DEFAULT (0),
    NUMBER8 NUMBER(21,6) DEFAULT (0),
    NUMBER9 NUMBER(21,6) DEFAULT (0),
    NUMBER10 NUMBER(21,6) DEFAULT (0),
    NUMBER11 NUMBER(21,6) DEFAULT (0),
    NUMBER12 NUMBER(21,6) DEFAULT (0),
    NUMBER13 NUMBER(21,6) DEFAULT (0),
    NUMBER14 NUMBER(21,6) DEFAULT (0),
    NUMBER15 NUMBER(21,6) DEFAULT (0),
    NUMBER16 NUMBER(21,6) DEFAULT (0),
    NUMBER17 NUMBER(21,6) DEFAULT (0),
    NUMBER18 NUMBER(21,6) DEFAULT (0),
    NUMBER19 NUMBER(21,6) DEFAULT (0),
    NUMBER20 NUMBER(21,6) DEFAULT (0),
    TEXT1 NVARCHAR2(256),
    TEXT2 NVARCHAR2(256),
    TEXT3 NVARCHAR2(256),
    TEXT4 NVARCHAR2(256),
    TEXT5 NVARCHAR2(256),
    TEXT6 NVARCHAR2(256),
    TEXT7 NVARCHAR2(256),
    TEXT8 NVARCHAR2(256),
    TEXT9 NVARCHAR2(256),
    TEXT10 NVARCHAR2(256),
    TEXT11 NVARCHAR2(256),
    TEXT12 NVARCHAR2(256),
    TEXT13 NVARCHAR2(256),
    TEXT14 NVARCHAR2(256),
    TEXT15 NVARCHAR2(256),
    TEXT16 NVARCHAR2(256),
    TEXT17 NVARCHAR2(256),
    TEXT18 NVARCHAR2(256),
    TEXT19 NVARCHAR2(256),
    TEXT20 NVARCHAR2(256),
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('USER_FIELD_VALUE', 'ROW_UID');

ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'ROW_UID', 'Unique User Defined Field Identifier.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'PRIMARY_ENTITY_UID', 'Unique Identifier for the Root Entity  the User Field Value is associated with.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'ENTITY_UID', 'Unique Identifier of the Entity the User Field Value is assigned to.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'DATE1', 'User entered DATE value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'USER_FIELD_VALUES', 'JSON Array of the User Field Values.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'DATE2', 'User entered DATE value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'DATE3', 'User entered DATE value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'DATE4', 'User entered DATE value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'DATE5', 'User entered DATE value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'DATE6', 'User entered DATE value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'DATE7', 'User entered DATE value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'DATE8', 'User entered DATE value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'DATE9', 'User entered DATE value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'DATE10', 'User entered DATE value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'DATE11', 'User entered DATE value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'DATE12', 'User entered DATE value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'DATE13', 'User entered DATE value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'DATE14', 'User entered DATE value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'DATE15', 'User entered DATE value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'DATE16', 'User entered DATE value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'DATE17', 'User entered DATE value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'DATE18', 'User entered DATE value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'DATE19', 'User entered DATE value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'DATE20', 'User entered DATE value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'NUMBER1', 'User entered NUMBER value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'NUMBER2', 'User entered NUMBER value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'NUMBER3', 'User entered NUMBER value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'NUMBER4', 'User entered NUMBER value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'NUMBER5', 'User entered NUMBER value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'NUMBER6', 'User entered NUMBER value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'NUMBER7', 'User entered NUMBER value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'NUMBER8', 'User entered NUMBER value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'NUMBER9', 'User entered NUMBER value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'NUMBER10', 'User entered NUMBER value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'NUMBER11', 'User entered NUMBER value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'NUMBER12', 'User entered NUMBER value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'NUMBER13', 'User entered NUMBER value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'NUMBER14', 'User entered NUMBER value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'NUMBER15', 'User entered NUMBER value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'NUMBER16', 'User entered NUMBER value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'NUMBER17', 'User entered NUMBER value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'NUMBER18', 'User entered NUMBER value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'NUMBER19', 'User entered NUMBER value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'NUMBER20', 'User entered NUMBER value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'TEXT1', 'User entered TEXT value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'TEXT2', 'User entered TEXT value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'TEXT3', 'User entered TEXT value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'TEXT4', 'User entered TEXT value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'TEXT5', 'User entered TEXT value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'TEXT6', 'User entered TEXT value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'TEXT7', 'User entered TEXT value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'TEXT8', 'User entered TEXT value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'TEXT9', 'User entered TEXT value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'TEXT10', 'User entered TEXT value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'TEXT11', 'User entered TEXT value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'TEXT12', 'User entered TEXT value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'TEXT13', 'User entered TEXT value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'TEXT14', 'User entered TEXT value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'TEXT15', 'User entered TEXT value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'TEXT16', 'User entered TEXT value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'TEXT17', 'User entered TEXT value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'TEXT18', 'User entered TEXT value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'TEXT19', 'User entered TEXT value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'TEXT20', 'User entered TEXT value for field mapped from USER_FIELD_DEFINITION table.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'CREATED_BY_USER_UID', 'The User that created the User Field Value.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'CREATED_DATE', 'Date the User Field Value was created.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the User Field Value.');
ADD_COLUMN_COMMENT('USER_FIELD_VALUE', 'LAST_MODIFIED_DATE', 'Date the last change was made to the User Field Value.');

-- Create table USER_NOTE_VALUE
CREATE_TABLE(
 'USER_NOTE_VALUE',
 'CREATE TABLE USER_NOTE_VALUE (
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    PRIMARY_ENTITY_UID RAW(16) NOT NULL,
    ENTITY_UID RAW(16) NOT NULL,
    FIELD_NAME NVARCHAR2(30) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    FIELD_VALUE NCLOB NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('USER_NOTE_VALUE', 'ROW_UID');
CREATE_NATURAL_KEY('USER_NOTE_VALUE', 'PRIMARY_ENTITY_UID, ENTITY_UID, FIELD_NAME');

ADD_COLUMN_COMMENT('USER_NOTE_VALUE', 'ROW_UID', 'Unique Note Text Identifier.');
ADD_COLUMN_COMMENT('USER_NOTE_VALUE', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('USER_NOTE_VALUE', 'PRIMARY_ENTITY_UID', 'Unique Identifier for the Root Entity  the User Note Value is associated with.');
ADD_COLUMN_COMMENT('USER_NOTE_VALUE', 'ENTITY_UID', 'Unique Identifier of the Entity the User Note Value is assigned to.');
ADD_COLUMN_COMMENT('USER_NOTE_VALUE', 'FIELD_NAME', 'The Field Name the User Code Value is assigned to.');
ADD_COLUMN_COMMENT('USER_NOTE_VALUE', 'CREATED_BY_USER_UID', 'The User that created the User Note Value.');
ADD_COLUMN_COMMENT('USER_NOTE_VALUE', 'CREATED_DATE', 'Date the User Note Value was created.');
ADD_COLUMN_COMMENT('USER_NOTE_VALUE', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the User Note Value.');
ADD_COLUMN_COMMENT('USER_NOTE_VALUE', 'LAST_MODIFIED_DATE', 'Date the last change was made to the User Note Value.');
ADD_COLUMN_COMMENT('USER_NOTE_VALUE', 'FIELD_VALUE', 'User entered Note Text.');

-- Create table ACCOUNTS
CREATE_TABLE(
 'ACCOUNTS',
 'CREATE TABLE ACCOUNTS (
    NAME VARCHAR2(3),
    DESCRIPTION VARCHAR2(254),
    PROJECT_UID RAW(16),
    REQUIRED NUMBER(19,0) DEFAULT (0),
    PROGRAM VARCHAR2(22),
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('ACCOUNTS', 'ROW_UID');

ADD_COLUMN_COMMENT('ACCOUNTS', 'ROW_UID', 'Unique Note Text Identifier.');
ADD_COLUMN_COMMENT('ACCOUNTS', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('ACCOUNTS', 'CREATED_BY_USER_UID', 'The User that created the Spread Curve.');
ADD_COLUMN_COMMENT('ACCOUNTS', 'CREATED_DATE', 'Date the Spread Curve was created.');
ADD_COLUMN_COMMENT('ACCOUNTS', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the Spread Curve.');
ADD_COLUMN_COMMENT('ACCOUNTS', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Spread Curve.');

-- Create table CHNG_REQST
CREATE_TABLE(
 'CHNG_REQST',
 'CREATE TABLE CHNG_REQST (
    BFINISH DATE,
    BSTART DATE,
    CHNG_NUM VARCHAR2(22),
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    PERIOD DATE,
    REQST_TYPE VARCHAR2(2),
    PROJECT_UID RAW(16),
    SOURCE_PROGRAM VARCHAR2(22),
    STAGE VARCHAR2(2),
    TITLE VARCHAR2(120),
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    ROW_UID RAW(16) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('CHNG_REQST', 'ROW_UID');

ADD_COLUMN_COMMENT('CHNG_REQST', 'LAST_MODIFIED_DATE', 'Date the last change was made to the User Code Value.');
ADD_COLUMN_COMMENT('CHNG_REQST', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the User Code Value.');
ADD_COLUMN_COMMENT('CHNG_REQST', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('CHNG_REQST', 'ROW_UID', 'Unique Note Text Identifier.');
ADD_COLUMN_COMMENT('CHNG_REQST', 'CREATED_BY_USER_UID', 'The User that created the User Code Value.');
ADD_COLUMN_COMMENT('CHNG_REQST', 'CREATED_DATE', 'Date the User Code Value was created.');

-- Create table CHNG_REQST_PROGRAM
CREATE_TABLE(
 'CHNG_REQST_PROGRAM',
 'CREATE TABLE CHNG_REQST_PROGRAM (
    CHNG_NUM VARCHAR2(22),
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    PHASE VARCHAR2(2),
    PROJECT_UID RAW(16),
    PROGRAM VARCHAR2(22),
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    ROW_UID RAW(16) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('CHNG_REQST_PROGRAM', 'ROW_UID');

ADD_COLUMN_COMMENT('CHNG_REQST_PROGRAM', 'LAST_MODIFIED_DATE', 'Date the last change was made to the User Code Value.');
ADD_COLUMN_COMMENT('CHNG_REQST_PROGRAM', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the User Code Value.');
ADD_COLUMN_COMMENT('CHNG_REQST_PROGRAM', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('CHNG_REQST_PROGRAM', 'ROW_UID', 'Unique Note Text Identifier.');
ADD_COLUMN_COMMENT('CHNG_REQST_PROGRAM', 'CREATED_BY_USER_UID', 'The User that created the User Code Value.');
ADD_COLUMN_COMMENT('CHNG_REQST_PROGRAM', 'CREATED_DATE', 'Date the User Code Value was created.');

-- Create table CLASSRANGES
CREATE_TABLE(
 'CLASSRANGES',
 'CREATE TABLE CLASSRANGES (
    CLASS VARCHAR2(20),
    FIELDNUM NUMBER(19,0) DEFAULT (0),
    PROGRAM VARCHAR2(22),
    PROJECT_UID RAW(16),
    RANGE_KEY VARCHAR2(59),
    RANGE_VALUE VARCHAR2(100),
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('CLASSRANGES', 'ROW_UID');

ADD_COLUMN_COMMENT('CLASSRANGES', 'ROW_UID', 'Unique Note Text Identifier.');
ADD_COLUMN_COMMENT('CLASSRANGES', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('CLASSRANGES', 'CREATED_BY_USER_UID', 'The User that created the User Code Value.');
ADD_COLUMN_COMMENT('CLASSRANGES', 'CREATED_DATE', 'Date the User Code Value was created.');
ADD_COLUMN_COMMENT('CLASSRANGES', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the User Code Value.');
ADD_COLUMN_COMMENT('CLASSRANGES', 'LAST_MODIFIED_DATE', 'Date the last change was made to the User Code Value.');

-- Create table CONNECTION
CREATE_TABLE(
 'CONNECTION',
 'CREATE TABLE CONNECTION (
    CONN_ID VARCHAR2(59),
    CONN_TYPE VARCHAR2(10),
    DATA NCLOB,
    DESCRIPTION VARCHAR2(254),
    GRP_ID VARCHAR2(20),
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    OWNER_ID VARCHAR2(20),
    READONLY NUMBER(19,0) DEFAULT (0),
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    SHARED NUMBER(19,0) DEFAULT (0),
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    ROW_UID RAW(16) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('CONNECTION', 'ROW_UID');

ADD_COLUMN_COMMENT('CONNECTION', 'LAST_MODIFIED_DATE', 'Date the last change was made to the User Code Value.');
ADD_COLUMN_COMMENT('CONNECTION', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('CONNECTION', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the User Code Value.');
ADD_COLUMN_COMMENT('CONNECTION', 'ROW_UID', 'Unique Note Text Identifier.');
ADD_COLUMN_COMMENT('CONNECTION', 'CREATED_BY_USER_UID', 'The User that created the User Code Value.');
ADD_COLUMN_COMMENT('CONNECTION', 'CREATED_DATE', 'Date the User Code Value was created.');

-- Create table COSTDETL
CREATE_TABLE(
 'COSTDETL',
 'CREATE TABLE COSTDETL (
    CLASS VARCHAR2(20),
    COSTSET VARCHAR2(20),
    INSTANCE VARCHAR2(22),
    ORD NUMBER(19,0) DEFAULT (0),
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('COSTDETL', 'ROW_UID');

ADD_COLUMN_COMMENT('COSTDETL', 'ROW_UID', 'Unique Note Text Identifier.');
ADD_COLUMN_COMMENT('COSTDETL', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('COSTDETL', 'LAST_MODIFIED_DATE', 'Date the last change was made to the User Code Value.');
ADD_COLUMN_COMMENT('COSTDETL', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the User Code Value.');
ADD_COLUMN_COMMENT('COSTDETL', 'CREATED_BY_USER_UID', 'The User that created the User Code Value.');
ADD_COLUMN_COMMENT('COSTDETL', 'CREATED_DATE', 'Date the User Code Value was created.');

-- Create table LINK
CREATE_TABLE(
 'LINK',
 'CREATE TABLE LINK (
    BFINISH DATE,
    BSTART DATE,
    CA1 VARCHAR2(59),
    CA2 VARCHAR2(59),
    CA3 VARCHAR2(59),
    CAWPID NUMBER(19,0) DEFAULT (0),
    PROJECT_CAWP_UID RAW(16),
    CLASS VARCHAR2(20),
    DESCRIPTION VARCHAR2(254),
    EFDATE DATE,
    ESDATE DATE,
    FCSTCLASS VARCHAR2(20),
    FULLID VARCHAR2(59),
    ROW_UID RAW(16) NOT NULL,
    LFDATE DATE,
    LSDATE DATE,
    MS_NO VARCHAR2(59),
    MSWEIGHT NUMBER(21,6) DEFAULT (0),
    PFINISH DATE,
    PMT VARCHAR2(1),
    PRJNAME VARCHAR2(15),
    PROGRAM VARCHAR2(22),
    PROJECT_UID RAW(16),
    PSTART DATE,
    SFDATE DATE,
    SSDATE DATE,
    STARTPC NUMBER(19,0) DEFAULT (0),
    UNITSTODO NUMBER(19,0) DEFAULT (0),
    VALID VARCHAR2(1),
    WP VARCHAR2(59),
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('LINK', 'ROW_UID');

ADD_COLUMN_COMMENT('LINK', 'ROW_UID', 'Unique Note Text Identifier.');
ADD_COLUMN_COMMENT('LINK', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('LINK', 'LAST_MODIFIED_DATE', 'Date the last change was made to the User Code Value.');
ADD_COLUMN_COMMENT('LINK', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the User Code Value.');
ADD_COLUMN_COMMENT('LINK', 'CREATED_BY_USER_UID', 'The User that created the User Code Value.');
ADD_COLUMN_COMMENT('LINK', 'CREATED_DATE', 'Date the User Code Value was created.');

-- Create table PROCESSLOG
CREATE_TABLE(
 'PROCESSLOG',
 'CREATE TABLE PROCESSLOG (
    CONTEXT VARCHAR2(30),
    DATA NCLOB,
    DIR_ID VARCHAR2(20),
    ERRORCOUNT NUMBER(19,0) DEFAULT (0),
    FINISHTIME TIMESTAMP,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    PROCESS_ID VARCHAR2(59),
    PROGRESS_PCT NUMBER(19,0) DEFAULT (0),
    PROGRESS_TEXT VARCHAR2(254),
    ROW_UID RAW(16) NOT NULL,
    STARTTIME TIMESTAMP,
    USR_ABORT NUMBER(19,0) DEFAULT (0),
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    WARNINGCOUNT NUMBER(19,0) DEFAULT (0),
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PROCESSLOG', 'ROW_UID');

ADD_COLUMN_COMMENT('PROCESSLOG', 'LAST_MODIFIED_DATE', 'Date the last change was made to the User Code Value.');
ADD_COLUMN_COMMENT('PROCESSLOG', 'ROW_UID', 'Unique Note Text Identifier.');
ADD_COLUMN_COMMENT('PROCESSLOG', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the User Code Value.');
ADD_COLUMN_COMMENT('PROCESSLOG', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('PROCESSLOG', 'CREATED_BY_USER_UID', 'The User that created the User Code Value.');
ADD_COLUMN_COMMENT('PROCESSLOG', 'CREATED_DATE', 'Date the User Code Value was created.');

-- Create table PROCESSLOGLINK
CREATE_TABLE(
 'PROCESSLOGLINK',
 'CREATE TABLE PROCESSLOGLINK (
    BATCH_UID VARCHAR2(22),
    PROCESSLOG_UID RAW(16),
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PROCESSLOGLINK', 'ROW_UID');

ADD_COLUMN_COMMENT('PROCESSLOGLINK', 'ROW_UID', 'Unique Note Text Identifier.');
ADD_COLUMN_COMMENT('PROCESSLOGLINK', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('PROCESSLOGLINK', 'CREATED_BY_USER_UID', 'The User that created the User Code Value.');
ADD_COLUMN_COMMENT('PROCESSLOGLINK', 'CREATED_DATE', 'Date the User Code Value was created.');
ADD_COLUMN_COMMENT('PROCESSLOGLINK', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the User Code Value.');
ADD_COLUMN_COMMENT('PROCESSLOGLINK', 'LAST_MODIFIED_DATE', 'Date the last change was made to the User Code Value.');

-- Create table RCUTOFF
CREATE_TABLE(
 'RCUTOFF',
 'CREATE TABLE RCUTOFF (
    HOURS NUMBER(21,6) DEFAULT (0),
    INSTANCE VARCHAR2(22),
    PD_FINISH DATE,
    PD_START DATE,
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('RCUTOFF', 'ROW_UID');

ADD_COLUMN_COMMENT('RCUTOFF', 'ROW_UID', 'Unique Note Text Identifier.');
ADD_COLUMN_COMMENT('RCUTOFF', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('RCUTOFF', 'CREATED_BY_USER_UID', 'The User that created the User Code Value.');
ADD_COLUMN_COMMENT('RCUTOFF', 'CREATED_DATE', 'Date the User Code Value was created.');
ADD_COLUMN_COMMENT('RCUTOFF', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the User Code Value.');
ADD_COLUMN_COMMENT('RCUTOFF', 'LAST_MODIFIED_DATE', 'Date the last change was made to the User Code Value.');

-- Create table TEMP_CAWPID
CREATE_TABLE(
 'TEMP_CAWPID',
 'CREATE TABLE TEMP_CAWPID (
    CAWPID NUMBER(19,0) DEFAULT (0),
    PROJECT_CAWP_UID RAW(16),
    INSTANCE VARCHAR2(22),
    PROGRAM VARCHAR2(22),
    PROJECT_UID RAW(16),
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('TEMP_CAWPID', 'ROW_UID');

ADD_COLUMN_COMMENT('TEMP_CAWPID', 'ROW_UID', 'Unique Note Text Identifier.');
ADD_COLUMN_COMMENT('TEMP_CAWPID', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('TEMP_CAWPID', 'CREATED_BY_USER_UID', 'The User that created the User Code Value.');
ADD_COLUMN_COMMENT('TEMP_CAWPID', 'CREATED_DATE', 'Date the User Code Value was created.');
ADD_COLUMN_COMMENT('TEMP_CAWPID', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the User Code Value.');
ADD_COLUMN_COMMENT('TEMP_CAWPID', 'LAST_MODIFIED_DATE', 'Date the last change was made to the User Code Value.');

-- Create table TEMP_CHAR
CREATE_TABLE(
 'TEMP_CHAR',
 'CREATE TABLE TEMP_CHAR (
    CHAR_VAL VARCHAR2(255),
    INSTANCE VARCHAR2(22),
    CREATED_DATE TIMESTAMP NOT NULL,
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('TEMP_CHAR', 'ROW_UID');

ADD_COLUMN_COMMENT('TEMP_CHAR', 'CREATED_DATE', 'Date the User Code Value was created.');
ADD_COLUMN_COMMENT('TEMP_CHAR', 'ROW_UID', 'Unique Note Text Identifier.');
ADD_COLUMN_COMMENT('TEMP_CHAR', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('TEMP_CHAR', 'CREATED_BY_USER_UID', 'The User that created the User Code Value.');
ADD_COLUMN_COMMENT('TEMP_CHAR', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the User Code Value.');
ADD_COLUMN_COMMENT('TEMP_CHAR', 'LAST_MODIFIED_DATE', 'Date the last change was made to the User Code Value.');

-- Create table TEMP_DIR
CREATE_TABLE(
 'TEMP_DIR',
 'CREATE TABLE TEMP_DIR (
    DIR_ID VARCHAR2(22),
    INSTANCE VARCHAR2(22),
    CREATED_DATE TIMESTAMP NOT NULL,
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('TEMP_DIR', 'ROW_UID');

ADD_COLUMN_COMMENT('TEMP_DIR', 'CREATED_DATE', 'Date the User Code Value was created.');
ADD_COLUMN_COMMENT('TEMP_DIR', 'ROW_UID', 'Unique Note Text Identifier.');
ADD_COLUMN_COMMENT('TEMP_DIR', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('TEMP_DIR', 'CREATED_BY_USER_UID', 'The User that created the User Code Value.');
ADD_COLUMN_COMMENT('TEMP_DIR', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the User Code Value.');
ADD_COLUMN_COMMENT('TEMP_DIR', 'LAST_MODIFIED_DATE', 'Date the last change was made to the User Code Value.');

-- Create table WST_LCK
CREATE_TABLE(
 'WST_LCK',
 'CREATE TABLE WST_LCK (
    CONTEXT VARCHAR2(22),
    CONTEXT_ID VARCHAR2(200),
    DIR_UID VARCHAR2(22),
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    LCK_UID VARCHAR2(22),
    LOCKMODE VARCHAR2(1),
    MACHINE_ID VARCHAR2(48),
    PRD_UID NUMBER(5,0) DEFAULT (0),
    ULI_UID VARCHAR2(22),
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('WST_LCK', 'ROW_UID');

ADD_COLUMN_COMMENT('WST_LCK', 'LAST_MODIFIED_DATE', 'Date the last change was made to the User Code Value.');
ADD_COLUMN_COMMENT('WST_LCK', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the User Code Value.');
ADD_COLUMN_COMMENT('WST_LCK', 'ROW_UID', 'Unique Note Text Identifier.');
ADD_COLUMN_COMMENT('WST_LCK', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('WST_LCK', 'CREATED_BY_USER_UID', 'The User that created the User Code Value.');
ADD_COLUMN_COMMENT('WST_LCK', 'CREATED_DATE', 'Date the User Code Value was created.');

-- Create table WST_DCT
CREATE_TABLE(
 'WST_DCT',
 'CREATE TABLE WST_DCT (
    TABLE_TYPE VARCHAR2(30),
    FLD_NAME VARCHAR2(30),
    TYPE VARCHAR2(4),
    LENGTH NUMBER(19,0) DEFAULT (0),
    SCALE NUMBER(19,0) DEFAULT (1),
    COL_FLAGS NUMBER(19,0) DEFAULT (2),
    SYS_NAME VARCHAR2(30),
    USR_NAME VARCHAR2(60),
    STRING_ID NUMBER(19,0) DEFAULT (0),
    FKEY_TABLE VARCHAR2(30),
    FKEY_FLD_NAME VARCHAR2(30),
    FKEY_REQUIRED NUMBER(19,0) DEFAULT (0),
    FKEY_VIRTUAL NUMBER(19,0) DEFAULT (0),
    DEL_FOREIGN_ACTION VARCHAR2(50),
    ROW_UID RAW(16) NOT NULL,
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL,
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('WST_DCT', 'ROW_UID');

ADD_COLUMN_COMMENT('WST_DCT', 'ROW_UID', 'Unique Note Text Identifier.');
ADD_COLUMN_COMMENT('WST_DCT', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('WST_DCT', 'CREATED_BY_USER_UID', 'The User that created the User Code Value.');
ADD_COLUMN_COMMENT('WST_DCT', 'CREATED_DATE', 'Date the User Code Value was created.');
ADD_COLUMN_COMMENT('WST_DCT', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the User Code Value.');

-- Create table BATCH
CREATE_TABLE(
 'BATCH',
 'CREATE TABLE BATCH (
    BATCHREP_ID VARCHAR2(22) DEFAULT ('' ''),
    DIR_ID VARCHAR2(22),
    FILTER_ID VARCHAR2(59) DEFAULT ('' ''),
    FILTER_SHARED NUMBER(19,0) DEFAULT (0),
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    LINE NUMBER(19,0) DEFAULT (0),
    OWNER_ID VARCHAR2(20),
    REPORT_ID VARCHAR2(22) DEFAULT ('' ''),
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    SORT_ID VARCHAR2(59) DEFAULT ('' ''),
    SORT_SHARED NUMBER(19,0) DEFAULT (0),
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    ROW_UID RAW(16) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('BATCH', 'ROW_UID');

ADD_COLUMN_COMMENT('BATCH', 'LAST_MODIFIED_DATE', 'Date the last change was made to the Batch.');
ADD_COLUMN_COMMENT('BATCH', 'OWNER_ID', 'The user who own the batch');
ADD_COLUMN_COMMENT('BATCH', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('BATCH', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the User Code Value.');
ADD_COLUMN_COMMENT('BATCH', 'ROW_UID', 'Unique Note Text Identifier.');
ADD_COLUMN_COMMENT('BATCH', 'CREATED_BY_USER_UID', 'The User that created the User Code Value.');
ADD_COLUMN_COMMENT('BATCH', 'CREATED_DATE', 'Date the User Code Value was created.');

-- Create table BATCHREP
CREATE_TABLE(
 'BATCHREP',
 'CREATE TABLE BATCHREP (
    BATCHREP_ID VARCHAR2(22) DEFAULT ('' ''),
    BATCHREP_UID VARCHAR2(22),
    DESCRIPTION VARCHAR2(254) DEFAULT ('' ''),
    LAST_MODIFIED_DATE TIMESTAMP NOT NULL,
    OUTPUT_LOC VARCHAR2(254) DEFAULT ('' ''),
    OUTPUT_TYPE VARCHAR2(12) DEFAULT ('' ''),
    OWNER_ID VARCHAR2(20),
    PROJECT_UID RAW(16),
    PROGRAM VARCHAR2(22),
    SEQUENCE NUMBER(19,0) DEFAULT (0) NOT NULL,
    SUB_FOLDER NUMBER(19,0) DEFAULT (0),
    LAST_MODIFIED_BY_USER_UID RAW(16) NOT NULL,
    ROW_UID RAW(16) NOT NULL,
    CREATED_BY_USER_UID RAW(16) NOT NULL,
    CREATED_DATE TIMESTAMP NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('BATCHREP', 'ROW_UID');

ADD_COLUMN_COMMENT('BATCHREP', 'LAST_MODIFIED_DATE', 'Date the last change was made to the User Code Value.');
ADD_COLUMN_COMMENT('BATCHREP', 'OWNER_ID', 'The user who own the batch reporting');
ADD_COLUMN_COMMENT('BATCHREP', 'SEQUENCE', 'Concurrency Control Identifier.');
ADD_COLUMN_COMMENT('BATCHREP', 'LAST_MODIFIED_BY_USER_UID', 'The User that last changed the User Code Value.');
ADD_COLUMN_COMMENT('BATCHREP', 'ROW_UID', 'Unique Note Text Identifier.');
ADD_COLUMN_COMMENT('BATCHREP', 'CREATED_BY_USER_UID', 'The User that created the User Code Value.');
ADD_COLUMN_COMMENT('BATCHREP', 'CREATED_DATE', 'Date the User Code Value was created.');

-- Create table PROJECT_CONTROL_ACCOUNT_TOTAL
CREATE_TABLE(
 'PROJECT_CONTROL_ACCOUNT_TOTAL',
 'CREATE TABLE PROJECT_CONTROL_ACCOUNT_TOTAL (
    ROW_UID RAW(16) NOT NULL,
    ACWP NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWP NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BAC NUMBER(21,6) DEFAULT (0) NOT NULL,
    EAC NUMBER(21,6) DEFAULT (0) NOT NULL,
    EAC_NONLAB NUMBER(21,6) DEFAULT (0) NOT NULL,
    ACWP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWS_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BAC_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    EAC_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    ACWPCP NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWPCP NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWSCP NUMBER(21,6) DEFAULT (0) NOT NULL,
    ACWPCP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWPCP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWSCP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PROJECT_CONTROL_ACCOUNT_TOTAL', 'ROW_UID');

ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT_TOTAL', 'ROW_UID', 'Unique Control Account Identifier');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT_TOTAL', 'ACWP', 'Actual Cost');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT_TOTAL', 'BCWP', 'Earned Cost');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT_TOTAL', 'BCWS', 'Budget Cost');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT_TOTAL', 'BAC', 'Budget Cost At Completion');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT_TOTAL', 'EAC', 'Forecast or Estimated Cost at Completion');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT_TOTAL', 'EAC_NONLAB', 'Forecast or Estimated Non-Labor Cost at Completion');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT_TOTAL', 'ACWP_HRS', 'Actual Hours');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT_TOTAL', 'BCWP_HRS', 'Earned Hours');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT_TOTAL', 'BCWS_HRS', 'Budget Hours');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT_TOTAL', 'BAC_HRS', 'Budget Hours At Completion');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT_TOTAL', 'EAC_HRS', 'Forecast or Estimated Hours at Completion');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT_TOTAL', 'ACWPCP', 'Current Period Actual Cost');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT_TOTAL', 'BCWPCP', 'Current Period Earned Cost');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT_TOTAL', 'BCWSCP', 'Current Period Budget Cost');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT_TOTAL', 'ACWPCP_HRS', 'Current Period Actual Hours');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT_TOTAL', 'BCWPCP_HRS', 'Current Period Earned Hours');
ADD_COLUMN_COMMENT('PROJECT_CONTROL_ACCOUNT_TOTAL', 'BCWSCP_HRS', 'Current Period Budget Hours');

-- Create table PROJECT_WORK_PACKAGE_TOTAL
CREATE_TABLE(
 'PROJECT_WORK_PACKAGE_TOTAL',
 'CREATE TABLE PROJECT_WORK_PACKAGE_TOTAL (
    ROW_UID RAW(16) NOT NULL,
    ACWP NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWP NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BAC NUMBER(21,6) DEFAULT (0) NOT NULL,
    EAC NUMBER(21,6) DEFAULT (0) NOT NULL,
    EAC_NONLAB NUMBER(21,6) DEFAULT (0) NOT NULL,
    ACWP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWS_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BAC_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    EAC_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    ACWPCP NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWPCP NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWSCP NUMBER(21,6) DEFAULT (0) NOT NULL,
    ACWPCP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWPCP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL,
    BCWSCP_HRS NUMBER(21,6) DEFAULT (0) NOT NULL
)
 %TABLETABLESPACE%'
);

CREATE_PRIMARY_KEY('PROJECT_WORK_PACKAGE_TOTAL', 'ROW_UID');

ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE_TOTAL', 'ROW_UID', 'Unique Work Package Identifier');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE_TOTAL', 'ACWP', 'Actual Cost');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE_TOTAL', 'BCWP', 'Earned Cost');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE_TOTAL', 'BCWS', 'Budget Cost');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE_TOTAL', 'BAC', 'Budget Cost At Completion');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE_TOTAL', 'EAC', 'Forecast or Estimated Cost at Completion');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE_TOTAL', 'EAC_NONLAB', 'Forecast or Estimated Non-Labor Cost at Completion');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE_TOTAL', 'ACWP_HRS', 'Actual Hours');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE_TOTAL', 'BCWP_HRS', 'Earned Hours');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE_TOTAL', 'BCWS_HRS', 'Budget Hours');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE_TOTAL', 'BAC_HRS', 'Budget Hours At Completion');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE_TOTAL', 'EAC_HRS', 'Forecast or Estimated Hours at Completion');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE_TOTAL', 'ACWPCP', 'Current Period Actual Cost');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE_TOTAL', 'BCWPCP', 'Current Period Earned Cost');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE_TOTAL', 'BCWSCP', 'Current Period Budget Cost');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE_TOTAL', 'ACWPCP_HRS', 'Current Period Actual Hours');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE_TOTAL', 'BCWPCP_HRS', 'Current Period Earned Hours');
ADD_COLUMN_COMMENT('PROJECT_WORK_PACKAGE_TOTAL', 'BCWSCP_HRS', 'Current Period Budget Hours');

CREATE_FOREIGN_KEY('CODE', 'CODE_FILE_UID', 'CODE_FILE', 'ROW_UID');
CREATE_FOREIGN_KEY('CODE', 'PARENT_CODE_UID', 'CODE', 'ROW_UID');
CREATE_FOREIGN_KEY('CODE_THRESHOLD', 'ROW_UID', 'CODE', 'ROW_UID');
CREATE_FOREIGN_KEY('FISCAL_CALENDAR_HOLIDAY', 'FISCAL_CALENDAR_UID', 'FISCAL_CALENDAR', 'ROW_UID');
CREATE_FOREIGN_KEY('FISCAL_CALENDAR_PERIOD', 'FISCAL_CALENDAR_UID', 'FISCAL_CALENDAR', 'ROW_UID');
CREATE_FOREIGN_KEY('FISCAL_CALENDAR_SET', 'FISCAL_CALENDAR_UID', 'FISCAL_CALENDAR', 'ROW_UID');
CREATE_FOREIGN_KEY('FISCAL_CALENDAR_SET_LABEL', 'FISCAL_CALENDAR_SET_UID', 'FISCAL_CALENDAR_SET', 'ROW_UID');
CREATE_FOREIGN_KEY('FISCAL_CALENDAR_SET_LABEL', 'FISCAL_CALENDAR_PERIOD_UID', 'FISCAL_CALENDAR_PERIOD', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT', 'WBS_CODE_FILE_UID', 'CODE_FILE', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT', 'OBS_CODE_FILE_UID', 'CODE_FILE', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT', 'CHANGE_NUMBER_CODE_FILE_UID', 'CODE_FILE', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT', 'CLIN_CODE_FILE_UID', 'CODE_FILE', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT', 'FISCAL_CALENDAR_UID', 'FISCAL_CALENDAR', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT', 'RESOURCE_FILE_UID', 'RESOURCE_FILE', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT', 'RATE_FILE_UID', 'RATE_FILE', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT', 'RW_FISCAL_CALENDAR_UID', 'FISCAL_CALENDAR', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_AUDIT_LOG', 'PROJECT_UID', 'PROJECT', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_AUDIT_LOG_ACCOUNTS', 'PROJECT_UID', 'PROJECT', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_AUDIT_LOG_HISTORY', 'PROJECT_UID', 'PROJECT', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_AUDIT_LOG_TPHASE', 'PROJECT_UID', 'PROJECT', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_AUDIT_LOG_TPHASE', 'PROJECT_AUDIT_LOG_UID', 'PROJECT_AUDIT_LOG', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_CALC_RESULT', 'PROJECT_UID', 'PROJECT', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_CAWP', 'PROJECT_UID', 'PROJECT', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_CAWP', 'OBS_CODE_UID', 'CODE', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_CAWP', 'WBS_CODE_UID', 'CODE', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_CAWP', 'PARENT_PROJECT_CAWP_UID', 'PROJECT_CAWP', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_CAWP', 'CAM_CODE_UID', 'CODE', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_CAWP', 'CLIN_CODE_UID', 'CODE', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_CAWP_RESOURCE', 'PROJECT_CAWP_UID', 'PROJECT_CAWP', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_CAWP_RESOURCE', 'RESOURCES_UID', 'RESOURCES', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_CAWP_RESOURCE', 'PROJECT_COST_CLASS_UID', 'PROJECT_COST_CLASS', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_CAWP_RESOURCE', 'SPREAD_CURVE_UID', 'SPREAD_CURVE', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_CAWP_RESOURCE_TPHASE', 'PROJECT_CAWP_RESOURCE_UID', 'PROJECT_CAWP_RESOURCE', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_CAWP_TOTAL', 'ROW_UID', 'PROJECT_CAWP', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_CONTROL_ACCOUNT', 'OBS_CODE_UID', 'CODE', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_CONTROL_ACCOUNT', 'PROJECT_UID', 'PROJECT', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_CONTROL_ACCOUNT', 'WBS_CODE_UID', 'CODE', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_WORK_PACKAGE', 'APPORTIONED_PROJECT_WP_UID', 'PROJECT_WORK_PACKAGE', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_WORK_PACKAGE', 'OBS_CODE_UID', 'CODE', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_WORK_PACKAGE', 'PROJECT_CONTROL_ACCOUNT_UID', 'PROJECT_CONTROL_ACCOUNT', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_WORK_PACKAGE', 'WBS_CODE_UID', 'CODE', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_COST_CLASS', 'PROJECT_UID', 'PROJECT', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_COST_CLASS', 'RATE_FILE_UID', 'RATE_FILE', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_COST_CLASS', 'FISCAL_CALENDAR_SET_UID', 'FISCAL_CALENDAR_SET', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_COST_CLASS_LINK', 'PARENT_PROJECT_COST_CLASS_UID', 'PROJECT_COST_CLASS', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_COST_CLASS_LINK', 'PROJECT_COST_CLASS_UID', 'PROJECT_COST_CLASS', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_COST_SET', 'PROJECT_UID', 'PROJECT', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_COST_SET_CLASS', 'PROJECT_COST_SET_UID', 'PROJECT_COST_SET', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_COST_SET_CLASS', 'PROJECT_COST_CLASS_UID', 'PROJECT_COST_CLASS', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_COST_TOTAL', 'ROW_UID', 'PROJECT', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_SUBPROJECT', 'PROJECT_UID', 'PROJECT', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_SUBPROJECT', 'SUBPROJECT_UID', 'PROJECT', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_WP_MILESTONE', 'PROJECT_WORK_PACKAGE_UID', 'PROJECT_WORK_PACKAGE', 'ROW_UID');
CREATE_FOREIGN_KEY('RATE', 'RATE_SET_UID', 'RATE_SET', 'ROW_UID');
CREATE_FOREIGN_KEY('RATE_SET', 'RATE_FILE_UID', 'RATE_FILE', 'ROW_UID');
CREATE_FOREIGN_KEY('RESOURCE_COST_CALCULATION', 'RESOURCES_UID', 'RESOURCES', 'ROW_UID');
CREATE_FOREIGN_KEY('RESOURCE_COST_CALCULATION', 'RATE_SET_UID', 'RATE_SET', 'ROW_UID');
CREATE_FOREIGN_KEY('RESOURCE_FILE', 'RATE_FILE_UID', 'RATE_FILE', 'ROW_UID');
CREATE_FOREIGN_KEY('RESOURCE_FILE_COST_RESULT', 'RESOURCE_FILE_UID', 'RESOURCE_FILE', 'ROW_UID');
CREATE_FOREIGN_KEY('RESOURCE_FILE_COST_RESULT', 'RATE_SET_UID', 'RATE_SET', 'ROW_UID');
CREATE_FOREIGN_KEY('RESOURCES', 'RESOURCE_FILE_UID', 'RESOURCE_FILE', 'ROW_UID');
CREATE_FOREIGN_KEY('RESOURCES', 'PARENT_RESOURCES_UID', 'RESOURCES', 'ROW_UID');
CREATE_FOREIGN_KEY('USER_CODE_VALUE', 'CODE_UID', 'CODE', 'ROW_UID');
CREATE_FOREIGN_KEY('USER_FIELD_DEFINITION', 'CODE_FILE_UID', 'CODE_FILE', 'ROW_UID');
CREATE_FOREIGN_KEY('ACCOUNTS', 'PROJECT_UID', 'PROJECT', 'ROW_UID');
CREATE_FOREIGN_KEY('CHNG_REQST', 'PROJECT_UID', 'PROJECT', 'ROW_UID');
CREATE_FOREIGN_KEY('CHNG_REQST_PROGRAM', 'PROJECT_UID', 'PROJECT', 'ROW_UID');
CREATE_FOREIGN_KEY('CLASSRANGES', 'PROJECT_UID', 'PROJECT', 'ROW_UID');
CREATE_FOREIGN_KEY('LINK', 'PROJECT_CAWP_UID', 'PROJECT_CAWP', 'ROW_UID');
CREATE_FOREIGN_KEY('LINK', 'PROJECT_UID', 'PROJECT', 'ROW_UID');
CREATE_FOREIGN_KEY('PROCESSLOGLINK', 'PROCESSLOG_UID', 'PROCESSLOG', 'ROW_UID');
CREATE_FOREIGN_KEY('TEMP_CAWPID', 'PROJECT_CAWP_UID', 'PROJECT_CAWP', 'ROW_UID');
CREATE_FOREIGN_KEY('TEMP_CAWPID', 'PROJECT_UID', 'PROJECT', 'ROW_UID');
CREATE_FOREIGN_KEY('BATCHREP', 'PROJECT_UID', 'PROJECT', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_CONTROL_ACCOUNT_TOTAL', 'ROW_UID', 'PROJECT_CONTROL_ACCOUNT', 'ROW_UID');
CREATE_FOREIGN_KEY('PROJECT_WORK_PACKAGE_TOTAL', 'ROW_UID', 'PROJECT_WORK_PACKAGE', 'ROW_UID');
END;
