# Write-Host "Starting CBT Diary backend and frontend..." -ForegroundColor Green

# $root = Split-Path -Parent $MyInvocation.MyCommand.Path
# $backendPath = Join-Path $root "backend"
# $frontendPath = Join-Path $root "frontend"

# Write-Host "Project root: $root" -ForegroundColor Cyan
# Write-Host "Backend path: $backendPath" -ForegroundColor Cyan
# Write-Host "Frontend path: $frontendPath" -ForegroundColor Cyan

# Start-Process powershell -ArgumentList @(
#     "-NoExit",
#     "-Command",
#     "cd '$backendPath'; .\venv\Scripts\Activate.ps1; uvicorn app.main:app --reload --host 0.0.0.0 --port 8000"
# )

# Start-Sleep -Seconds 2

# Start-Process powershell -ArgumentList @(
#     "-NoExit",
#     "-Command",
#     "cd '$frontendPath'; flutter run --dart-define=API_BASE_URL=http://localhost:8000"
# )