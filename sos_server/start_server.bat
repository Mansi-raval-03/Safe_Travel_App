@echo off
echo ========================================
echo         SOS Server Setup & Start
echo ========================================
echo.

echo Installing Node.js dependencies...
call npm install

echo.
echo Starting SOS Server...
echo.
echo Server will be available at:
echo - Local: http://localhost:3001
echo - Dashboard: http://localhost:3001
echo.
echo Press Ctrl+C to stop the server
echo.

call npm start