$ErrorActionPreference = "Stop"

Write-Host "== Hybrid Platform Part-2 Smoke Test =="

# 1) Structure check
$paths = @(
  "backend\app.py","backend\config.py","backend\requirements.txt",
  "backend\modules","backend\utils","backend\uploads","backend\reports",
  "frontend\templates\index.html","frontend\templates\analysis_result.html"
)
foreach ($p in $paths) {
  if (-not (Test-Path $p)) { throw "Missing required path: $p" }
}
Write-Host "[OK] Folder structure present"

# 2) Python & deps
if (-not (Test-Path "venv")) {
  python -m venv venv
}
. .\venv\Scripts\Activate.ps1
pip install -q -r backend\requirements.txt
Write-Host "[OK] Dependencies installed"

# 3) Env file
if (-not (Test-Path "backend\.env")) {
  @"
VT_API_KEY=
OTX_API_KEY=
MISP_URL=
MISP_KEY=
ABUSEIPDB_KEY=
UPLOAD_FOLDER=uploads
REPORT_FOLDER=reports
SECRET_KEY=dev_secret
"@ | Out-File -Encoding utf8 "backend\.env"
  Write-Host "[INFO] Created placeholder .env"
} else {
  Write-Host "[OK] .env exists"
}

# 4) Launch Flask (background)
$env:FLASK_ENV = "development"
$env:WERKZEUG_RUN_MAIN = "true"
$flask = Start-Process -FilePath "python" -ArgumentList "backend\app.py" -PassThru
Start-Sleep -Seconds 2

# 5) Health check (GET /)
try {
  $res = Invoke-WebRequest -Uri "http://127.0.0.1:5000/" -UseBasicParsing
  if ($res.StatusCode -ne 200) { throw "Unexpected status: $($res.StatusCode)" }
  Write-Host "[OK] GET / responded 200"
} catch {
  Stop-Process -Id $flask.Id -Force
  throw "Flask not responding on /: $_"
}

# 6) Upload a harmless dummy file
$dummy = "dummy.ps1"
"Write-Output 'hello'" | Out-File -Encoding ascii $dummy
try {
  $upload = Invoke-WebRequest -Uri "http://127.0.0.1:5000/upload" -Method Post -UseBasicParsing -Form @{ file = Get-Item $dummy }
  if ($upload.StatusCode -ne 200 -and $upload.StatusCode -ne 302) {
    throw "Unexpected status on upload: $($upload.StatusCode)"
  }
  Write-Host "[OK] Upload route accepted file (status $($upload.StatusCode))"
} catch {
  Stop-Process -Id $flask.Id -Force
  throw "Upload failed: $_"
}

# 7) Verify file stored by SHA256 + metadata JSON
$uploaded = Get-ChildItem backend\uploads | Where-Object { $_.Name -match '^[0-9a-f]{64}$' } | Select-Object -First 1
if (-not $uploaded) {
  Stop-Process -Id $flask.Id -Force
  throw "No SHA256-named file found in backend\uploads"
}
$json = "$($uploaded.FullName).json"
if (-not (Test-Path $json)) {
  Stop-Process -Id $flask.Id -Force
  throw "Metadata JSON missing: $json"
}
Write-Host "[OK] Quarantine file + metadata present"
Write-Host "[OK] Sample SHA256: $($uploaded.Name)"

# 8) Detail page loads
$detailUrl = "http://127.0.0.1:5000/detail/$($uploaded.Name)"
$res2 = Invoke-WebRequest -Uri $detailUrl -UseBasicParsing
if ($res2.StatusCode -ne 200) {
  Stop-Process -Id $flask.Id -Force
  throw "Detail page returned $($res2.StatusCode)"
}
Write-Host "[OK] Detail page renders"

# 9) Logs sanity (if you enabled logging_utils)
if (Test-Path "backend\logs\app.log") {
  $last = Get-Content "backend\logs\app.log" -Tail 5
  Write-Host "[INFO] Last log lines:`n$last"
}

Stop-Process -Id $flask.Id -Force
Write-Host "`nAll Part-2 checks passed ✅"
