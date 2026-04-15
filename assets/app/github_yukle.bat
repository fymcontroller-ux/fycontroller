@echo off
setlocal enabledelayedexpansion

:: Configuration
set "REPO=fymcontroller-ux/fycontroller"
set "JSON_FILE=fycontroller.json"
set "TAG=v1.0"
set "APK_FILENAME=fy_controller.apk"
set "APK_LOCAL_PATH=assets\app\%APK_FILENAME%"

echo ===========================================
echo    FY CONTROLLER - RELEASE UPDATER (V5)
echo ===========================================

set "SOURCE_DIR=D:\FY\Android Studio\Cherry\FY_Site"
cd /d "%SOURCE_DIR%"

:: 1. GitHub API ile Mevcut Versiyonu Oku
echo [1/4] GitHub verileri okunuyor...
powershell -NoProfile -Command ^
    "$raw = gh api repos/%REPO%/contents/%JSON_FILE% --jq '.content';" ^
    "$bytes = [System.Convert]::FromBase64String($raw);" ^
    "$json = [System.Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json;" ^
    "$app = $json | Where-Object { $_.pkgName -eq 'com.fatih.fycontroller' };" ^
    "if ($app) { Write-Host ('Mevcut Versiyon: ' + $app.version) -ForegroundColor Cyan } else { Write-Host 'HATA: Uygulama bulunamadi!' -ForegroundColor Red }"

:: 2. Yeni Versiyon Sor
echo.
echo [2/4] Yeni versiyon numarasini girin:
set /p "ver=FY Controller: "

if "%ver%"=="" (
    echo HATA: Versiyon bos birakilamaz!
    pause
    exit /b
)

:: 3. APK'yı GitHub Release'e Yükle (Release Taktiği)
echo.
echo [3/4] APK dosyasi GitHub Release (%TAG%) alanina yukleniyor...
if not exist "%APK_LOCAL_PATH%" (
    echo HATA: %APK_LOCAL_PATH% bulunamadi!
    pause
    exit /b
)

gh release upload %TAG% "%APK_LOCAL_PATH%" --clobber --repo %REPO%

if %errorlevel% neq 0 (
    echo.
    echo HATA: Release yuklemesi basarisiz oldu. 
    pause
    exit /b
)
echo [+] APK basariyla Release alanina yuklendi.

:: 4. JSON Dosyasını API ile Güncelle
echo.
echo [4/4] %JSON_FILE% guncelleniyor...
powershell -NoProfile -Command ^
    "$res = gh api repos/%REPO%/contents/%JSON_FILE% --jq '{content: .content, sha: .sha}' | ConvertFrom-Json;" ^
    "$sha = $res.sha;" ^
    "$raw = $res.content;" ^
    "$bytes = [System.Convert]::FromBase64String($raw);" ^
    "$json = [System.Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json;" ^
    "$app = ($json | Where-Object { $_.pkgName -eq 'com.fatih.fycontroller' });" ^
    "$app.version = '%ver%';" ^
    "$app.downloadUrl = 'https://github.com/%REPO%/releases/download/%TAG%/%APK_FILENAME%';" ^
    "$newJson = $json | ConvertTo-Json -Depth 10;" ^
    "$newBytes = [System.Text.Encoding]::UTF8.GetBytes($newJson);" ^
    "$base64 = [System.Convert]::ToBase64String($newBytes);" ^
    "$payload = @{ message='Update version to %ver% and downloadUrl to Release'; content=$base64; sha=$sha } | ConvertTo-Json -Depth 10;" ^
    "$payload | gh api --method PUT repos/%REPO%/contents/%JSON_FILE% --input -"

if %errorlevel% equ 0 (
    echo.
    echo [+] TUM ISLEMLER BASARIYLA TAMAMLANDI.
    echo [+] Yeni Versiyon: %ver%
) else (
    echo.
    echo [-] HATA: JSON guncelleme sirasinda sorun yasandi.
)

pause
