set modelpath=..\model
set ddlpath=..\oracle\deployment
set sheet="Cobra Web"
@echo off
python ModelGenerator.py -mode ddl -model %modelpath%\Model.xlsx -sheet %sheet% -out %ddlpath%
python ModelGenerator.py -mode d2 -model %modelpath%\Model.xlsx -sheet %sheet% -out %modelpath%
python ModelGenerator.py -mode sjson -model %modelpath%\Model.xlsx -sheet %sheet% -out %modelpath%
d2 %modelpath%\Model.d2 %modelpath%\Model.svg
rem d2 --scale 0.33 %modelpath%\Model.d2 %modelpath%\Model.png
rem d2 -l tala %modelpath%\Model.d2 %modelpath%\Model(tala).svg
rem start notepad %modelpath%\Model.sql
rem start notepad %modelpath%\Model.d2
rem start  %modelpath%\Model.svg
rem start  %modelpath%\Model.png
rem start  %modelpath%\Model(tala).svg