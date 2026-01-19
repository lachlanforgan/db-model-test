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
