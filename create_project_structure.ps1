$root = "hybrid_malware_platform"

$folders = @(
    "$root/backend/modules",
    "$root/backend/utils",
    "$root/backend/reports",
    "$root/backend/uploads",
    "$root/backend/sandbox",
    "$root/backend/database",
    "$root/frontend/templates",
    "$root/frontend/static",
    "$root/docs",
    "$root/tests"
)

$files = @(
    "$root/backend/app.py",
    "$root/backend/requirements.txt",
    "$root/backend/config.py",
    "$root/backend/.env",
    "$root/backend/modules/__init__.py",
    "$root/backend/modules/static_analysis.py",
    "$root/backend/modules/dynamic_analysis.py",
    "$root/backend/modules/ioc_extraction.py",
    "$root/backend/modules/threat_enrichment.py",
    "$root/backend/modules/fusion_scoring.py",
    "$root/backend/modules/correlation.py",
    "$root/backend/utils/file_utils.py",
    "$root/backend/utils/yara_utils.py",
    "$root/backend/utils/hash_utils.py",
    "$root/backend/utils/logging_utils.py",
    "$root/frontend/templates/index.html",
    "$root/frontend/templates/analysis_result.html",
    "$root/docs/architecture.md",
    "$root/docs/future_scope.md",
    "$root/docs/research_notes.md"
)

foreach ($folder in $folders) {
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
}

foreach ($file in $files) {
    New-Item -ItemType File -Force -Path $file | Out-Null
}

Write-Host "✅ Project structure created in $root" -ForegroundColor Green
