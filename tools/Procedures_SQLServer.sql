--
-- Model_SQLServer.sql
--
-- Target DBMS : SQL Server
--
-- Copyright Deltek, Inc.
--
-- Procedures used for creating tables, views, indexes, primary keys and foreign keys.
--

SET NOCOUNT ON;
GO

--DECLARE
--    @drop_tables CHAR(1),
--    @debug CHAR(1)

---- Set drop_tables to '1' to drop tables before creating them.
--SET @drop_tables = '1';

---- Set debug to '1' to output debug messages
--SET @debug = '1';

-- CREATE_TABLE procedure
CREATE OR ALTER PROCEDURE #CREATE_TABLE
    @tableName NVARCHAR(128),
    @query NVARCHAR(MAX)
AS
BEGIN
    DECLARE @exists INT
    DECLARE @newQuery NVARCHAR(MAX)

    SELECT @exists = COUNT(*)
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = @tableName

    IF @exists = 0
    BEGIN
        --IF @debug = '1'
        --BEGIN
        --    PRINT 'Creating table ' + @tableName
        --END

        SET @newQuery = @query
        -- No tablespace concept in SQL Server, so we'll remove those placeholders
        SET @newQuery = REPLACE(@newQuery, '%TABLETABLESPACE%', '')
        SET @newQuery = REPLACE(@newQuery, '%INDEXTABLESPACE%', '')
        SET @newQuery = REPLACE(@newQuery, '%LOBTABLESPACE%', '')

        EXEC sp_executesql @newQuery
    END
END
GO

-- DROP_FK_CONSTRAINTS procedure
CREATE OR ALTER PROCEDURE #DROP_FK_CONSTRAINTS
(
    @tableName NVARCHAR(128)
)
AS
BEGIN
    DECLARE @sql NVARCHAR(MAX) = N'';
    DECLARE @fkCount INT;

    -- Check if the table has foreign key constraints
    SELECT @fkCount = COUNT(*)
    FROM sys.foreign_keys AS f
    INNER JOIN sys.foreign_key_columns AS fc ON f.object_id = fc.constraint_object_id
    INNER JOIN sys.columns AS c ON fc.parent_object_id = c.object_id AND fc.parent_column_id = c.column_id
    WHERE OBJECT_NAME(f.referenced_object_id) = PARSENAME(@tableName, 1);

    -- If foreign key constraints exist, construct and execute the dynamic SQL to drop them
    IF @fkCount > 0
    BEGIN
        SELECT @sql += N'ALTER TABLE ' + QUOTENAME(OBJECT_NAME(f.parent_object_id)) + N' DROP CONSTRAINT ' + QUOTENAME(f.name) + N';' + CHAR(13) + CHAR(10)
        FROM sys.foreign_keys AS f
        INNER JOIN sys.foreign_key_columns AS fc ON f.object_id = fc.constraint_object_id
        INNER JOIN sys.columns AS c ON fc.parent_object_id = c.object_id AND fc.parent_column_id = c.column_id
        WHERE OBJECT_NAME(f.referenced_object_id) = PARSENAME(@tableName, 1);

        -- Execute the dynamic SQL
        EXEC sp_executesql @sql;
    END
END
GO

-- DROP_TABLE procedure
CREATE OR ALTER PROCEDURE #DROP_TABLE
    @tableName NVARCHAR(128)
AS
BEGIN
    DECLARE @exists INT
    DECLARE @query NVARCHAR(MAX)

    SELECT @exists = COUNT(*)
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = @tableName

    IF @exists = 1
    BEGIN
        --IF @debug = '1'
        --BEGIN
        --    PRINT 'Dropping table ' + @tableName
        --END
        BEGIN
            --Drop foreign key constraints
            EXEC #DROP_FK_CONSTRAINTS @tableName
        END

        SET @query = 'DROP TABLE ' + 'dbo.' +
            QUOTENAME(@tableName)
        EXEC sp_executesql @query
    END
END
GO

-- CREATE_VIEW procedure
CREATE OR ALTER PROCEDURE #CREATE_VIEW
    @viewName NVARCHAR(128),
    @query NVARCHAR(MAX)
AS
BEGIN
    DECLARE @exists INT

    SELECT @exists = COUNT(*)
    FROM INFORMATION_SCHEMA.VIEWS
    WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = @viewName

    IF @exists = 0
    BEGIN
        --IF @debug = '1'
        --BEGIN
        --    PRINT 'Creating view ' + @viewName
        --END

        EXEC sp_executesql @query
    END
END
GO

-- CREATE_INDEX procedure
CREATE OR ALTER PROCEDURE #CREATE_INDEX
    @tableName NVARCHAR(128),
    @fields NVARCHAR(MAX)
AS
BEGIN
    DECLARE @exists INT
    DECLARE @query NVARCHAR(MAX)
    DECLARE @indexName NVARCHAR(128)

    SET @indexName = 'IDX_' + @tableName + '_' + @fields
    SET @indexName = REPLACE(@indexName, ' ', '')
    SET @indexName = REPLACE(@indexName, ',', '_')

    SELECT @exists = COUNT(*)
    FROM sys.indexes i
    JOIN sys.objects o ON i.object_id = o.object_id
    JOIN sys.schemas s ON o.schema_id = s.schema_id
    WHERE s.name = 'dbo'
      AND o.name = @tableName
      AND i.name = @indexName

    IF @exists = 0
    BEGIN
        --IF @debug = '1'
        --BEGIN
        --    PRINT 'Creating index ' + @indexName
        --END

        SET @query = 'CREATE INDEX ' + @indexName + ' ON dbo.' +
            QUOTENAME(@tableName) + ' (' + @fields + ')'
        EXEC sp_executesql @query
    END
END
GO

-- -- CREATE_NATURAL_KEY procedure
-- CREATE OR ALTER PROCEDURE #CREATE_NATURAL_KEY
--     @tableName NVARCHAR(128),
--     @fields NVARCHAR(MAX)
-- AS
-- BEGIN
--     DECLARE @exists INT
--     DECLARE @query NVARCHAR(MAX)
--     DECLARE @indexName NVARCHAR(128)
--
--     SET @indexName = 'NK_' + @tableName
--
--     SELECT @exists = COUNT(*)
--     FROM sys.indexes i
--     JOIN sys.objects o ON i.object_id = o.object_id
--     JOIN sys.schemas s ON o.schema_id = s.schema_id
--     WHERE s.name = 'dbo'
--       AND o.name = @tableName
--       AND i.name = @indexName
--
--     IF @exists = 0
--     BEGIN
--         --IF @debug = '1'
--         --BEGIN
--         --    PRINT 'Creating natural key index ' + @indexName
--         --END
--
--         SET @query = 'CREATE UNIQUE INDEX ' + @indexName + ' ON dbo.' +
--             QUOTENAME(@tableName) + ' (' + @fields + ')'
--         EXEC sp_executesql @query
--     END
-- END
-- GO

-- CREATE_FOREIGN_KEY_INDEX procedure
CREATE OR ALTER PROCEDURE #CREATE_FOREIGN_KEY_INDEX
    @tableName NVARCHAR(128),
    @columnName NVARCHAR(128)
AS
BEGIN
    DECLARE @exists INT
    DECLARE @query NVARCHAR(MAX)
    DECLARE @indexName NVARCHAR(128)

    SET @indexName = 'FK_' + @tableName + '_' + @tableName + '_' + @columnName

    SELECT @exists = COUNT(*)
    FROM sys.indexes i
    JOIN sys.objects o ON i.object_id = o.object_id
    JOIN sys.schemas s ON o.schema_id = s.schema_id
    WHERE s.name = 'dbo'
      AND o.name = @tableName
      AND i.name = @indexName

    IF @exists = 0
    BEGIN
        --IF @debug = '1'
        --BEGIN
        --    PRINT 'Creating foreign key index ' + @indexName
        --END

        SET @query = 'CREATE INDEX ' + @indexName + ' ON dbo.' +
            QUOTENAME(@tableName) + ' (' + @columnName + ')'
        EXEC sp_executesql @query
    END
END
GO

-- CREATE_PRIMARY_KEY procedure
CREATE OR ALTER PROCEDURE #CREATE_PRIMARY_KEY
    @tableName NVARCHAR(128),
    @columnList NVARCHAR(MAX)
AS
BEGIN
    DECLARE @exists INT
    DECLARE @query NVARCHAR(MAX)
    DECLARE @constraintName NVARCHAR(128)

    SET @constraintName = 'PK_' + @tableName

    SELECT @exists = COUNT(*)
    FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = 'dbo'
      AND TABLE_NAME = @tableName
      AND CONSTRAINT_NAME = @constraintName
      AND CONSTRAINT_TYPE = 'PRIMARY KEY'

    IF @exists = 0
    BEGIN
        --IF @debug = '1'
        --BEGIN
        --    PRINT 'Creating primary key ' + @constraintName
        --END

        SET @query = 'ALTER TABLE dbo.' +
            QUOTENAME(@tableName) + ' ADD CONSTRAINT ' + @constraintName + ' PRIMARY KEY (' + @columnList + ')'
        EXEC sp_executesql @query
    END
END
GO

-- CREATE_FOREIGN_KEY procedure
CREATE OR ALTER PROCEDURE #CREATE_FOREIGN_KEY
    @tableName NVARCHAR(128),
    @columnName NVARCHAR(128),
    @foreignTableName NVARCHAR(128),
    @foreignColumnName NVARCHAR(128)
AS
BEGIN
    DECLARE @exists INT
    DECLARE @query NVARCHAR(MAX)
    DECLARE @constraintName NVARCHAR(128)

    SET @constraintName = 'FK_' + @tableName + '_' + @columnName

    SELECT @exists = COUNT(*)
    FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = 'dbo'
      AND TABLE_NAME = @tableName
      AND CONSTRAINT_NAME = @constraintName
      AND CONSTRAINT_TYPE = 'FOREIGN KEY'

    IF @exists = 0
    BEGIN
        --IF @debug = '1'
        --BEGIN
        --    PRINT 'Creating foreign key ' + @constraintName
        --END

        SET @query = 'ALTER TABLE dbo.' +
            QUOTENAME(@tableName) +
            ' WITH NOCHECK' +
            ' ADD CONSTRAINT ' + @constraintName +
            ' FOREIGN KEY (' + @columnName + ') REFERENCES ' +
            'dbo.' + QUOTENAME(@foreignTableName) + '(' + @foreignColumnName + ')'
        EXEC sp_executesql @query
    END

    -- Create the index separately
    -- Don't create a foreign key index on the primary key column
    IF @columnName <> @foreignColumnName
    BEGIN
        EXEC #CREATE_FOREIGN_KEY_INDEX @tableName, @columnName
    END
END
GO


-- CREATE_NATURAL_KEY procedure
CREATE OR ALTER PROCEDURE #CREATE_NATURAL_KEY
    @tableName NVARCHAR(128),
    @columnList NVARCHAR(MAX)
AS
BEGIN
    DECLARE @exists INT
    DECLARE @query NVARCHAR(MAX)
    DECLARE @constraintName NVARCHAR(128)

    SET @constraintName = 'NK_' + @tableName

    SELECT @exists = COUNT(*)
    FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = 'dbo'
      AND TABLE_NAME = @tableName
      AND CONSTRAINT_NAME = @constraintName
      AND CONSTRAINT_TYPE = 'PRIMARY KEY'

    IF @exists = 0
    BEGIN
        --IF @debug = '1'
        --BEGIN
        --    PRINT 'Creating primary key ' + @constraintName
        --END

        SET @query = 'ALTER TABLE dbo.' +
            QUOTENAME(@tableName) + ' ADD CONSTRAINT ' + @constraintName + ' UNIQUE (' + @columnList + ')'
        EXEC sp_executesql @query
    END
END
GO


-- ADD_TABLE_COMMENT procedure
CREATE OR ALTER PROCEDURE #ADD_TABLE_COMMENT
    @tableName NVARCHAR(128),
    @comment NVARCHAR(MAX)
AS
BEGIN
    DECLARE @exists INT

    -- Check if the extended property exists for this table
    SELECT @exists = COUNT(*)
    FROM sys.extended_properties ep
    JOIN sys.objects o ON ep.major_id = o.object_id
    JOIN sys.schemas s ON o.schema_id = s.schema_id
    WHERE s.name = 'dbo'
      AND o.name = @tableName
      AND ep.name = 'MS_Description'
      AND ep.minor_id = 0

    IF @exists = 0
    BEGIN
        DECLARE @objectId INT

        SELECT @objectId = o.object_id
        FROM sys.objects o
        JOIN sys.schemas s ON o.schema_id = s.schema_id
        WHERE s.name = 'dbo'
          AND o.name = @tableName

        EXEC sp_addextendedproperty
            @name = N'MS_Description',
            @value = @comment,
            @level0type = N'SCHEMA',
            @level0name = N'dbo',
            @level1type = N'TABLE',
            @level1name = @tableName
    END
END
GO

-- ADD_COLUMN_COMMENT procedure
CREATE OR ALTER PROCEDURE #ADD_COLUMN_COMMENT
    @tableName NVARCHAR(128),
    @columnName NVARCHAR(128),
    @comment NVARCHAR(128)
AS
BEGIN
    DECLARE @exists INT

    -- Check if the extended property exists for this column
    SELECT @exists = COUNT(*)
    FROM sys.extended_properties ep
    JOIN sys.objects o ON ep.major_id = o.object_id
    JOIN sys.schemas s ON o.schema_id = s.schema_id
    JOIN sys.columns c ON o.object_id = c.object_id AND ep.minor_id = c.column_id
    WHERE s.name = 'dbo'
      AND o.name = @tableName
      AND c.name = @columnName
      AND ep.name = 'MS_Description'

    IF @exists = 0
    BEGIN
        EXEC sp_addextendedproperty
            @name = N'MS_Description',
            @value = @comment,
            @level0type = N'SCHEMA',
            @level0name = N'dbo',
            @level1type = N'TABLE',
            @level1name = @tableName,
            @level2type = N'COLUMN',
            @level2name = @columnName
    END
END
GO
