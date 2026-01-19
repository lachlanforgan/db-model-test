# Database Tools README.md

The database/tools folder contains the scripts that are needed to generate Database Model artifacts from the data dictionary model Excel workbook named
Model.xlsx in the database/model folder.


## Additional Information

The ModelGenerator.py script is used to generate database DDL script, D2 Diagram markdown files and JSON files from the
Excel data dictionary workbook.

The Procedures_XXX.sql files provide the base stored procedures for creating the various database entities such as Tables, Indexes and Constraints that will be included in the generated database DLL script.

The GenerateModel.bat file contains the various ModelGenerator script commands to generate the DDL, D2 and JSON outputs.

## Required Tools

### Python

[https://www.python.org/]   
Python is required to run the ModelGenerator.py script.

```winget install -e Python.Python.3.13```

_(You will need to restart your command window after this step.  
If you are running this from a command window in IntelliJ, you will need to restart IntelliJ in order for the command window to recognize the updated Path environment variable.)_

### Pyton Pandas Library

[https://pandas.pydata.org/]    
The Python Pandas Library is required to read Excel workbooks.

``` pip install pandas openpyxl```

_(You will need to restart your command window after this step.  
If you are running this from a command window in IntelliJ, you will need to restart IntelliJ in order for the command window to recognize the updated Path environment variable.)_

### Terrastruct D2

[https://terrastruct.com/]   
Terastruct D2 is needed to generate the D2 diagrams from the D2 Markdown files.

```winget install -e Terrastruct.D2```

_(You will need to restart your command window after this step.  
If you are running this from a command window in IntelliJ, you will need to restart IntelliJ in order for the command window to recognize the updated Path environment variable.)_


### Terrastruct Tala [Optional]

[https://terrastruct.com/tala/]    
Terastruct Tala is a layout generator that provides a nicer rendering of the ER Diagrams, but it is a paid product.  
Unlicensed copies of Tala generate a watermark on the diagrams.  
You can download and install Tala from the Tala Releases page:  
https://github.com/terrastruct/TALA/releases

## Running ModelGenerator.py

The ModelGenerator.py script is used to generate database DDL script, D2 Diagram markdown files and JSON files from the
Excel data dictionary workbook.

usage: ModelGenerator.py \[-h\] \[-mode \{ddl, d2, jsonp, jsons, all\}\] \[-model MODEL\] -sheet SHEET \[-out OUT\]

There are two formats for DDL script output: 'oracle' and 'sqlserver'.
SQLServer support is provided for teams that are using SQLServer as their database engine.

There are two formats for JSON output: 'jsonp' and 'jsons'.
The 'jsonp'2 format is a single JSON object with all the tables and their columns.
The 'jsons' format is a JSON structure organized by Domains, Tables and Columns.

| option       | Description                                                                               |
|--------------|-------------------------------------------------------------------------------------------|
| **-h**       | Show this help message and exit.                                                          |  
| **-dbtype**, | DDL Script type to generate: 'oracle', 'sqlserver'. Optional. Default is 'oracle'.        |
| **-mode**    | Mode of operation: 'ddl', 'd2', 'jsonp', 'jsons' or 'all'.  Optional.  Default is 'all'.  |
| **-model**   | Path to the Excel file containing the data dictionary.  Optional. Default is 'Model.xlsx' |  
| **-sheet**   | Name of the sheet in the Excel file that contains the model.                              |  
| **-out**     | Output path for the generated files. Optional. Default output path is '.\out'             |

#### Example:

###### python ModelGenerator.py -model ../model/Model.xlsx -sheet "Model" -out "../model"

## Running D2

###### d2 ../model/Model.d2 .../model/Model.svg

#### See GenerateModel.bat for more detailed examples