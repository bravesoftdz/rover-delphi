@echo off
cd /d "%~dp0"

for %%i in (src, document, temp, product) do (
    md %%i >nul 2>nul
)

mklink /d /j %~dp0publish "E:\rover-self-work\delphi\delphi��Ŀģ��\publish" >nul 2>nul
mklink /d /j %~dp03rdparty "E:\rover-self-work\delphi\delphi��Ŀģ��\3rdparty" >nul 2>nul