"""
Generate Database DDL script from Excel data dictionary.
Generate D2 diagram from Excel data dictionary.
"""

import os
import sys
import pandas as pd
import argparse
import re

# Enable debug mode via environment variable
DEBUG = os.environ.get('DEBUG', 'false').lower() == 'true'

def debug_print(message):
    """Print debug messages if DEBUG mode is enabled."""
    if DEBUG:
        print(f"[DEBUG] {message}")

# D2 reserved keywords that need to be escaped or avoided
D2_RESERVED_KEYWORDS = {
    'link', 'label', 'style', 'shape', 'icon', 'tooltip', 'width', 'height',
    'class', 'classes', 'constraint', 'source-arrowhead', 'target-arrowhead',
    'direction', 'grid-rows', 'grid-columns', 'vars', 'scenarios', 'steps',
    'layers', 'near', 'top', 'left', 'right', 'bottom'
}

def sanitize_d2_identifier(name):
    """
    Sanitize identifiers for D2 to avoid reserved keywords and invalid characters.
    Returns the identifier wrapped in quotes if it is a reserved keyword or contains
    any characters outside [A-Za-z0-9_]; otherwise returns the identifier unchanged.
    """
    if not name:
        return name

    # Work with a string representation and a normalized version for keyword checks
    name_str = str(name)
    name_lower = name_str.lower().strip()

    # Quote reserved keywords or identifiers containing any special characters
    if name_lower in D2_RESERVED_KEYWORDS or re.search(r'[^a-zA-Z0-9_]', name_str):
        # Escape any quotes in the name
        escaped_name = name_str.replace('"', '\\"')
        return f'"{escaped_name}"'

    # Safe identifier: only alphanumeric and underscore characters
    return name_str
# Define Oracle to SQL Server data type mapping
ORACLE_TO_SQLSERVER = {
    # Numeric types
    'NUMBER': 'NUMERIC',
    'INTEGER': 'INT',
    'FLOAT': 'FLOAT',
    'DECIMAL': 'DECIMAL',

    # Character types
    'CHAR': 'CHAR',
    'NCHAR': 'NCHAR',
    'VARCHAR2': 'VARCHAR',
    'NVARCHAR2': 'NVARCHAR',
    'CLOB': 'VARCHAR(MAX)',
    'NCLOB': 'NVARCHAR(MAX)',

    # JSON type
    'JSON': 'NVARCHAR(MAX)',

    # BOOLEAN type
    'BOOLEAN': 'INT',

    # Date and time types
    'DATE': 'DATETIME',
    'TIMESTAMP': 'DATETIME2',

    # Binary types
    'BLOB': 'VARBINARY(MAX)',
    'RAW': 'BINARY',
}


# Generate a database DDL script from Excel data dictionary in Oracle or SQL server format.
# It reads the data dictionary from the specified Excel file and sheet, processes the data,
# and generates the DDL script in the specified database format (Oracle or SQL Server) and
# saves it to the output folder.
#
# The script generator prepends the appropriate Procedures.sql file to the beginning of the
# output file and then emits calls to the various procedures to drop tables and create tables,
# primary keys, natural keys, foreign keys and comments.
#
# The function also handles the conversion of Oracle data types to SQL Server data types as
# well as other differences between Oracle and SQL server DDL syntax.
#
def generate_ddl(excel_file, data_dictionary_sheet, db_type="oracle", output_folder=None):
    debug_print(f"Starting DDL generation for {excel_file}, sheet: {data_dictionary_sheet}, db_type: {db_type}")

    # Check if the excel workbook exists
    if not os.path.exists(excel_file):
        print(f"\nError: The specified Excel file '{excel_file}' does not exist.")
        sys.exit(1)

    debug_print(f"Excel file found: {excel_file}")

    # Check if the data dictionary sheet exists
    xls = pd.ExcelFile(excel_file)
    debug_print(f"Available sheets: {xls.sheet_names}")

    if data_dictionary_sheet not in xls.sheet_names:
        print(f"\nError: The specified Excel sheet '{data_dictionary_sheet}' does not exist in the Excel file.")
        sys.exit(1)

    debug_print(f"Sheet '{data_dictionary_sheet}' found")

    # Determine the output folder
    if output_folder is None:
        output_folder = os.path.dirname(excel_file)
    else:
        if not os.path.exists(output_folder):
            os.makedirs(output_folder)

    # Check if the database type is valid
    db_type = db_type.lower()
    if db_type not in ["oracle", "sqlserver"]:
        print(
            f"\nError: The specified database type '{db_type}' is not valid. Valid types are 'oracle' or 'sqlserver'.")
        sys.exit(1)

    # Determine the required procedures file based on the database type
    if db_type == "oracle":
        procedures_file = "Procedures_Oracle.sql"
    else:
        procedures_file = "Procedures_SQLServer.sql"

    # Check if the procedures.sql file exists
    if not os.path.exists(procedures_file):
        print(f"\nError: The specified SQL procedures file '{procedures_file}' does not exist.")
        sys.exit(1)

    # Generate output file name
    base_name = os.path.splitext(os.path.basename(excel_file))[0]
    if db_type == "oracle":
        output_file = os.path.join(output_folder, f"{base_name}_Oracle.sql")
    else:
        output_file = os.path.join(output_folder, f"{base_name}_SqlServer.sql")

    tables = {}
    primary_keys = {}
    foreign_keys = {}
    comments = {}
    unique_keys = {}

    # Read the Excel file
    df = pd.read_excel(excel_file, sheet_name=data_dictionary_sheet, dtype=str)
    debug_print(f"Read {len(df)} rows from Excel file")

    # Strip leading and trailing whitespace from all string columns
    df = df.apply(lambda x: x.apply(lambda y: y.strip() if isinstance(y, str) else y), axis=0)
    debug_print("Stripped whitespace from all string columns")

    row_count = 0
    for _, row in df.iterrows():
        row_count += 1
        if pd.isna(row['DOMAIN']):
            continue

        table_name = row['TABLE_NAME']
        column_name = row['COLUMN_NAME']
        data_type = row['DATA_TYPE']
        sql_data_type = row['SQL_DATA_TYPE']
        data_length = row['DATA_LENGTH']
        scale = row['SCALE']
        not_null = row['NOT_NULL']
        default = row['DEFAULT']
        pk = row['PRIMARY_KEY']
        fk_table = row['FKEY_TABLE']
        fk_field = row['FKEY_COLUMN']
        description = row['DESCRIPTION']
        nk = row['NATURAL_KEY']

        # Convert Oracle data type to SQL Server if needed
        if db_type == "sqlserver":
            # Split length/scale declaration off the Oracle data type
            # and append it back after mapping to the SQL Server data type.
            if "(" in sql_data_type:
                base_type, params = sql_data_type.split("(", 1)
                base_type = base_type.strip()
                params = "(" + params

            else:
                base_type = sql_data_type
                params = ""

            if base_type in ORACLE_TO_SQLSERVER:
                # Fix the default value for BOOLEAN type as INT
                if base_type == "BOOLEAN":
                    if default == "FALSE":
                        default = "0"
                    elif default == "TRUE":
                        default = "1"

                base_type = ORACLE_TO_SQLSERVER[base_type]

            sql_data_type = base_type + params


        if table_name not in tables:
            tables[table_name] = []
            primary_keys[table_name] = []
            foreign_keys[table_name] = []
            comments[table_name] = []
            unique_keys[table_name] = []

        column_def = f"{column_name} {sql_data_type}"

        # Add data length and scale
        if pd.notna(data_length) and data_length:
            column_def += f"({data_length}"
            if pd.notna(scale) and scale:
                column_def += f",{scale}"
            column_def += ")"

        # Add BINARY_AI collation for NTEXT natural keys
        # Must appear BEFORE the NOT NULL constraint (Not sure about the Default constraint)
        # Requires setting Oracle MAX_STRING_SIZE option to EXTENDED
        # https://docs.oracle.com/en/database/oracle/oracle-database/23/refrn/MAX_STRING_SIZE.html
        #Comment out for now until databases are upgraded to  Oracle23c
        #        if db_type == "oracle" and nk == 'Y' and data_type == 'NTEXT':
        #            column_def += " COLLATE BINARY_AI"

        # Add DEFAULT Constraints
        if pd.notna(default) and default:
            column_def += f" DEFAULT ({default})"

        # Add NOT NULL Constraints
        if not_null == 'Y':
            column_def += " NOT NULL"

        tables[table_name].append(column_def)

        if pk == 'Y':
            primary_keys[table_name].append(column_name)

        if pd.notna(fk_table) and fk_table and pd.notna(fk_field) and fk_field:
            foreign_keys[table_name].append((column_name, fk_table, fk_field))

        if pd.notna(description) and description:
            comments[table_name].append((column_name, description))

        if nk == 'Y':
            unique_keys[table_name].append(column_name)

    debug_print(f"Processed {row_count} rows")
    debug_print(f"Found {len(tables)} tables")
    debug_print(f"Tables: {', '.join(tables.keys())}")

    # Read the database type-specific Procedures file
    with open(procedures_file, mode='r') as file:
        procedures_content = file.read()

    # Write the Procedures content to the output file
    with open(output_file, mode='w') as file:
        file.write(procedures_content)
        file.write("\n")

        # Then emit all the DDL procedure calls to the output file

        # The format of the procedure calls is different for each database type based on the database type.

        # SQL Server
        if db_type == "sqlserver":
            drop_format = "EXEC #DROP_TABLE '{0}'\nGO\n"
            create_table_format = """-- Create table {0}
EXEC #CREATE_TABLE
    @tableName = '{0}',
    @query = 'CREATE TABLE {0} (
    {1}
)'
GO

"""
            create_pk_format = "EXEC #CREATE_PRIMARY_KEY @tableName = '{0}', @columnList = '{1}'\nGO\n"
            create_nk_format = "EXEC #CREATE_NATURAL_KEY @tableName = '{0}', @columnList = '{1}'\nGO\n"
            add_comment_format = "EXEC #ADD_COLUMN_COMMENT @tableName = '{0}', @columnName = '{1}', @comment = '{2}'\nGO\n"
            create_fk_format = "EXEC #CREATE_FOREIGN_KEY @tableName = '{0}', @columnName = '{1}', @foreignTableName = '{2}', @foreignColumnName = '{3}'\nGO\n"
            end_script = ""

        # Oracle
        else:
            drop_format = "DROP_TABLE('{0}');\n"
            create_table_format = """-- Create table {0}
CREATE_TABLE(
 '{0}',
 'CREATE TABLE {0} (
    {1}
)
 %TABLETABLESPACE%'
);

"""
            create_pk_format = "CREATE_PRIMARY_KEY('{0}', '{1}');\n"
            create_nk_format = "CREATE_NATURAL_KEY('{0}', '{1}');\n"
            add_comment_format = "ADD_COLUMN_COMMENT('{0}', '{1}', '{2}');\n"
            create_fk_format = "CREATE_FOREIGN_KEY('{0}', '{1}', '{2}', '{3}');\n"
            end_script = "END;\n"

        # Write DROP statements
        for table_name, columns in tables.items():
            file.write(drop_format.format(table_name))
        file.write("\n")

        # Write CREATE TABLE statements
        for table_name, columns in tables.items():
            file.write(create_table_format.format(table_name, ",\n    ".join(columns)))

            if primary_keys[table_name]:
                pk_columns = ", ".join(primary_keys[table_name])
                file.write(create_pk_format.format(table_name, pk_columns))

            if unique_keys[table_name]:
                unique_columns = ", ".join(unique_keys[table_name])
                file.write(create_nk_format.format(table_name, unique_columns))

            file.write("\n")

            for column_name, description in comments[table_name]:
                # Replace single quotes in the description with double quotes to avoid SQL syntax errors
                safe_description = description.replace("'", "''")
                file.write(add_comment_format.format(table_name, column_name, safe_description))

            file.write("\n")

        # Generate Foreign Keys
        for table_name, columns in tables.items():
            for column_name, fk_table, fk_field in foreign_keys[table_name]:
                file.write(create_fk_format.format(table_name, column_name, fk_table, fk_field))

        if end_script:
            file.write(end_script)

        print(f"\nDDL Generation complete. '{output_file}' created for {db_type}.")


# Generate a D2 diagram from the Excel data dictionary.
# It reads the data dictionary from the specified Excel file and sheet, processes the data,
# and generates the D2 diagram in the specified output folder.
# The D2 diagram is a visual representation of the database schema, including tables, columns,
# primary keys, foreign keys, and relationships between tables.
#
def generate_d2(excel_file, sheet_name, output_folder=None):
    debug_print(f"Starting D2 generation for {excel_file}, sheet: {sheet_name}")

    # Check if the Excel file exists
    if not os.path.exists(excel_file):
        print(f"\nError: The specified Excel file '{excel_file}' does not exist.")
        sys.exit(1)

    debug_print(f"Excel file found: {excel_file}")

    # Determine the output folder
    if output_folder is None:
        output_folder = os.path.dirname(excel_file)
    else:
        if not os.path.exists(output_folder):
            os.makedirs(output_folder)

    debug_print(f"Output folder: {output_folder}")

    # Generate output file name
    output_file = os.path.join(output_folder, f"{os.path.splitext(os.path.basename(excel_file))[0]}.d2")
    debug_print(f"Output file will be: {output_file}")

    # Read the Excel file
    df = pd.read_excel(excel_file, sheet_name=sheet_name)
    debug_print(f"Read {len(df)} rows from Excel file")

    # Clean and prepare data
    df = df.fillna('')
    df = df.apply(lambda x: x.apply(lambda y: y.strip() if isinstance(y, str) else y), axis=0)
    debug_print("Cleaned and prepared data")

    # Get unique tables with their domains
    tables = df[['TABLE_NAME', 'DOMAIN']].drop_duplicates().sort_values(['DOMAIN', 'TABLE_NAME'])
    debug_print(f"Found {len(tables)} unique tables")

    # Get columns for each table
    all_tables = {}
    table_count = 0
    for _, row in tables.iterrows():
        if row['DOMAIN'] == '':
            continue

        table_name = row['TABLE_NAME']
        domain = row['DOMAIN']
        table_count += 1

        debug_print(f"Processing table {table_count}: {table_name} in domain {domain}")

        # Get columns for this table
        table_df = df[df['TABLE_NAME'] == table_name]
        columns = []
        fk_count = 0
        for _, col_row in table_df.iterrows():
            if col_row['DOMAIN'] == '':
                continue

            has_fk = col_row['FKEY_TABLE'] != ''
            if has_fk:
                fk_count += 1

            column = {
                'name': col_row['COLUMN_NAME'],
                'type': col_row['SQL_DATA_TYPE'],
                'pk': col_row['PRIMARY_KEY'] == 'Y',
                'fk': has_fk,
                'fk_table': col_row['FKEY_TABLE'],
                'fk_column': col_row['FKEY_COLUMN']
            }
            columns.append(column)

        debug_print(f"  Table {table_name} has {len(columns)} columns and {fk_count} foreign keys")

        all_tables[table_name] = {
            'domain': domain,
            'columns': columns
        }

    debug_print(f"Processed {table_count} tables total")

    # Start building D2 content
    d2_content = '# Cobra Web Data Model (D2 Format)\n\n'

    # Add styles
    # d2_content += '# Define styles for domains\n'
    # d2_content += 'styles: {\n'

    # Define colors for domains
    # domain_colors = {
    #    'Authorization': '#E9D8FD',
    #    'Codes': '#BEE3F8',
    #    'CostClasses': '#FEEBC8',
    #    'Contracts': '#C6F6D5',
    #    'Contractors': '#E2E8F0',
    #    'CostSets': '#FED7D7',
    #    'Rates': '#FED7E2',
    #    'Fiscal Calendars': '#FEFCBF',
    #    'Shared': '#EDF2F7',
    #    'SpreadCurves': '#E6FFFA',
    #    'Resources': '#EBF4FF',
    #    'Programs': '#F0FFF4',
    #    'Projects': '#FAF5FF',
    #    'Other': '#FFFFFF'
    # }

    # Add domain styles
    # for domain, color in domain_colors.items():
    #    domain_id = domain.lower().replace(' ', '_')
    #    d2_content += f'  {domain_id}: {{\n'
    #    d2_content += f'    style.fill: "{color}"\n'
    #    d2_content += f'    style.border-radius: 8\n'
    #    d2_content += f'  }}\n'

    # Add table style
    # d2_content += '  table: {\n'
    # d2_content += '    style.border-radius: 4\n'
    # d2_content += '    shadow: true\n'
    # d2_content += '  }\n'
    # d2_content += '}\n\n'

    # Group tables by domain
    domains = {}
    for table_name, table_info in all_tables.items():
        domain = table_info['domain']
        if domain not in domains:
            domains[domain] = []
        domains[domain].append(table_name)

    # Add tables grouped by domain
    debug_print("Generating D2 content for tables...")
    for domain, tables in domains.items():
        domain_id = sanitize_d2_identifier(domain.lower().replace(' ', '_'))
        debug_print(f"Creating domain: {domain} (sanitized: {domain_id})")

        d2_content += f'# {domain} Domain\n'
        d2_content += f'{domain_id}: {{\n'
        d2_content += f'  label: "{domain} Domain"\n'

        for table_name in tables:
            table_info = all_tables[table_name]
            table_id = sanitize_d2_identifier(table_name)
            debug_print(f"  Creating table: {table_name} (sanitized: {table_id})")

            d2_content += f'  {table_id}: {{\n'
            d2_content += f'    shape: sql_table\n'

            for column in table_info['columns']:
                column_name = sanitize_d2_identifier(column['name'])
                constraints = []
                if column['pk']:
                    constraints.append('primary_key')
                if column['fk']:
                    constraints.append('foreign_key')

                constraints_str = ''
                if constraints:
                    constraints_str = f' {{constraint: [{",".join(constraints)}]}}'

                d2_content += f'    {column_name}: {column["type"]}{constraints_str}\n'

            d2_content += f'  }}\n\n'

        d2_content += f'}}\n\n'

    # Add relationships using simpler D2 syntax
    debug_print("Generating relationships...")
    d2_content += '# Define relationships\n'
    relationship_count = 0

    for table_name, table_info in all_tables.items():
        table_id = sanitize_d2_identifier(table_name)
        source_domain = sanitize_d2_identifier(table_info['domain'].lower().replace(' ', '_'))

        for column in table_info['columns']:
            if column['fk'] and column['fk_table'] and column['fk_column']:
                target_table = column['fk_table']
                target_table_id = sanitize_d2_identifier(target_table)
                target_domain = sanitize_d2_identifier(
                    all_tables.get(target_table, {}).get('domain', 'Other').lower().replace(' ', '_')
                )

                relationship_count += 1
                debug_print(f"  Relationship {relationship_count}: {target_domain}.{target_table_id} -> {source_domain}.{table_id}")

                # Use proper D2 relationship syntax with multi-line format
                d2_content += f'{target_domain}.{target_table_id} -> {source_domain}.{table_id}: {{\n'
                d2_content += '  source-arrowhead: {\n'
                d2_content += '    shape: diamond\n'
                d2_content += '    style: {\n'
                d2_content += '      filled: true\n'
                d2_content += '    }\n'
                d2_content += '  }\n'
                d2_content += '  target-arrowhead: {\n'
                d2_content += '    shape: arrow\n'
                d2_content += '    style: {\n'
                d2_content += '      filled: false\n'
                d2_content += '    }\n'
                d2_content += '  }\n'
                d2_content += '  label: "has"\n'
                d2_content += '}\n\n'

    debug_print(f"Generated {relationship_count} relationships")

    # Write to the file
    debug_print(f"Writing D2 content to {output_file}")
    with open(output_file, 'w') as f:
        f.write(d2_content)

    debug_print(f"D2 file size: {len(d2_content)} characters")
    print(f'D2 diagram generation complete: {output_file}')


# Generate an unstructured JSON file from the Excel data dictionary.
#
def generate_plain_json(excel_file, sheet_name, output_folder=None):
    debug_print(f"Starting plain JSON generation for {excel_file}, sheet: {sheet_name}")

    # Check if the excel workbook exists
    if not os.path.exists(excel_file):
        print(f"\nError: The specified Excel file '{excel_file}' does not exist.")
        sys.exit(1)

    # Check if the data dictionary sheet exists
    xls = pd.ExcelFile(excel_file)
    if sheet_name not in xls.sheet_names:
        print(f"\nError: The specified Excel sheet '{sheet_name}' does not exist in the Excel file.")
        sys.exit(1)

    # Determine the output folder
    if output_folder is None:
        output_folder = os.path.dirname(excel_file)
    else:
        if not os.path.exists(output_folder):
            os.makedirs(output_folder)

    # Generate output file name
    base_name = os.path.splitext(os.path.basename(excel_file))[0]
    output_file = os.path.join(output_folder, f"{base_name}_json_plain.json")
    debug_print(f"Output file will be: {output_file}")

    # Read the Excel file
    df = pd.read_excel(excel_file, sheet_name=sheet_name, dtype=str)
    debug_print(f"Read {len(df)} rows from Excel file")

    # Convert the DataFrame to JSON format
    json_data = df.to_json(orient='records', indent=4)
    debug_print(f"JSON data size: {len(json_data)} characters")

    # Write the JSON data to the output file
    with open(output_file, 'w') as json_file:
        json_file.write(json_data)

    print(f"Plain JSON file generation complete: {output_file}")


# Generate a structured JSON file grouped by DOMAINS and TABLES from the Excel data dictionary.
#
def generate_structured_json(excel_file, sheet_name, output_folder=None):
    """
    Generate a JSON file grouped by DOMAINS and TABLES from the Excel data dictionary.
    """
    import json
    import os
    import pandas as pd
    import sys

    debug_print(f"Starting structured JSON generation for {excel_file}, sheet: {sheet_name}")

    # Check if the Excel workbook exists
    if not os.path.exists(excel_file):
        print(f"\nError: The specified Excel file '{excel_file}' does not exist.")
        sys.exit(1)

    # Check if the data dictionary sheet exists
    xls = pd.ExcelFile(excel_file)
    if sheet_name not in xls.sheet_names:
        print(f"\nError: The specified Excel sheet '{sheet_name}' does not exist in the Excel file.")
        sys.exit(1)

    # Determine the output folder
    if output_folder is None:
        output_folder = os.path.dirname(excel_file)
    else:
        if not os.path.exists(output_folder):
            os.makedirs(output_folder)

    # Generate output file name
    base_name = os.path.splitext(os.path.basename(excel_file))[0]
    output_file = os.path.join(output_folder, f"{base_name}_json_structured.json")
    debug_print(f"Output file will be: {output_file}")

    # Read the Excel file
    df = pd.read_excel(excel_file, sheet_name=sheet_name, dtype=str)
    debug_print(f"Read {len(df)} rows from Excel file")

    # Fill NaN values with empty strings
    df = df.fillna('')

    # Group data by DOMAINS and TABLES
    grouped_data = {"DOMAINS": {}}
    debug_print("Starting to group data by domains and tables")
    for _, row in df.iterrows():

        if row['DOMAIN'] == '':
            continue

        domain = row['DOMAIN']
        table_name = row['TABLE_NAME']
        table_flags = row['TABLE_FLAGS']
        table_description = row['TABLE_DESCRIPTION']

        if domain not in grouped_data["DOMAINS"]:
            grouped_data["DOMAINS"][domain] = {"TABLES": {}}

        if table_name not in grouped_data["DOMAINS"][domain]["TABLES"]:
            grouped_data["DOMAINS"][domain]["TABLES"][table_name] = {
                "TABLE_FLAGS": table_flags,
                "TABLE_DESCRIPTION": table_description,
                "COLUMNS": []
            }

        # Remove TABLE_FLAGS from column data
        column_data = row.to_dict()
        column_data.pop('DOMAIN', None)
        column_data.pop('TABLE_NAME', None)
        column_data.pop('TABLE_FLAGS', None)
        column_data.pop('TABLE_DESCRIPTION', None)
        column_data.pop('COMMENTS', None)

        # Append column data to the table
        grouped_data["DOMAINS"][domain]["TABLES"][table_name]["COLUMNS"].append(column_data)

    debug_print(f"Grouped data contains {len(grouped_data['DOMAINS'])} domains")
    for domain, domain_data in grouped_data["DOMAINS"].items():
        debug_print(f"  Domain '{domain}' has {len(domain_data['TABLES'])} tables")

    # Write the grouped data to a JSON file
    with open(output_file, 'w') as json_file:
        json.dump(grouped_data, json_file, indent=4)

    debug_print(f"JSON file written successfully")
    print(f"Structured JSON file generation complete: {output_file}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate DDL and D2 scripts from an Excel data dictionary.")
    parser.add_argument("-mode", choices=["ddl", "d2", "pjson", "sjson", "all"],
                        help="Mode of operation: 'ddl', 'd2', 'pjson - plain json', 'sjson - structured json' or 'all'.",
                        default="all")
    parser.add_argument("-dbtype", choices=["oracle", "sqlserver"],
                        help="Database type for DDL generation: 'oracle' or 'sqlserver'.", default="oracle")
    parser.add_argument("-model", help="Path to the Excel file containing the data dictionary.", default="Model.xlsx")
    parser.add_argument("-sheet", required=True, help="Name of the sheet in the Excel file.")
    parser.add_argument("-out", help="Optional output folder for generated files.", default=".\\out")

    args = parser.parse_args()

    if args.mode in ["ddl", "all"]:
        generate_ddl(args.model, args.sheet, args.dbtype, args.out)

    if args.mode in ["d2", "all"]:
        generate_d2(args.model, args.sheet, args.out)

    if args.mode in ["pjson", "all"]:
        generate_plain_json(args.model, args.sheet, args.out)

    if args.mode in ["sjson", "all"]:
        generate_structured_json(args.model, args.sheet, args.out)
