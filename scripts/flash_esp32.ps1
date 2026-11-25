<#
  Nap firmware vao ESP32 tren Windows: build, tu tim cong COM cua ESP32, nap code, mo Serial Monitor.
  File nay chi dung chu khong dau de Windows PowerShell 5.1 doc dung ma khong can BOM.

  Chay tu thu muc goc du an:
    powershell -ExecutionPolicy Bypass -File scripts\flash_esp32.ps1              # tu tim cong
    powershell -ExecutionPolicy Bypass -File scripts\flash_esp32.ps1 -Port COM7   # chi dinh cong
    powershell -ExecutionPolicy Bypass -File scripts\flash_esp32.ps1 -BuildOnly   # chi build, khong can cam ESP32
    powershell -ExecutionPolicy Bypass -File scripts\flash_esp32.ps1 -NoMonitor   # nap xong khong mo Serial Monitor
    powershell -ExecutionPolicy Bypass -File scripts\flash_esp32.ps1 -ListPorts   # chi liet ke cong
    powershell -ExecutionPolicy Bypass -File scripts\flash_esp32.ps1 -MonitorOnly # chi mo Serial Monitor, khong nap lai
#>
param(
    [string]$Port = "",
    [switch]$BuildOnly,
    [switch]$NoMonitor,
    [switch]$ListPorts,
    [switch]$MonitorOnly
)

$projectRoot = Split-Path -Parent $PSScriptRoot
$firmwareDir = Join-Path $projectRoot "firmware"

# Chip USB-UART hay gap tren board ESP32: CP210x, CH340/CH341, CH9102, FTDI, USB native cua Espressif.
# Cong COM cua Bluetooth co Hardware ID dang BTHENUM\... nen khong bao gio bi chon nham.
$EspUsbIds = "VID:PID=(10C4:EA60|1A86:7523|1A86:7522|1A86:55D4|0403:6001|0403:6010|0403:6015|303A:[0-9A-F]{4})"

function Write-Step([string]$text) { Write-Host ""; Write-Host "==> $text" -ForegroundColor Cyan }
function Write-Warn([string]$text) { Write-Host "[!] $text" -ForegroundColor Yellow }
function Write-Fail([string]$text) { Write-Host "[X] $text" -ForegroundColor Red }

# Tim lenh pio: trong PATH, trong thu muc cai cua PlatformIO IDE (VS Code), hoac goi qua Python
function Find-Pio {
    $cmd = Get-Command pio -ErrorAction SilentlyContinue
    if ($cmd) { return ,@($cmd.Source) }
    $penvPio = Join-Path $env:USERPROFILE ".platformio\penv\Scripts\pio.exe"
    if (Test-Path $penvPio) { return ,@($penvPio) }
    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($py) {
        $null = & $py.Source -c "import platformio" 2>$null
        if ($LASTEXITCODE -eq 0) { return ,@($py.Source, "-m", "platformio") }
    }
    return $null
}

# Doc danh sach cong COM tu PlatformIO (dang JSON) de loc ra cong cua ESP32
function Get-SerialPorts {
    $json = (& $script:PioExe @script:PioPrefix device list --serial --json-output) -join "`n"
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($json)) { return @() }
    return @($json | ConvertFrom-Json)
}

function Show-Ports($ports) {
    if ($ports.Count -eq 0) { Write-Host "    (khong co cong COM nao)"; return }
    foreach ($p in $ports) { Write-Host ("    {0,-7} {1}" -f $p.port, $p.description) }
}

Write-Host "========================================================"
Write-Host " HE THONG DINH DUONG DAT IOT - NAP FIRMWARE ESP32 (Windows)"
Write-Host " Cam bien do am: VCC -> 3V3, GND -> GND, AO -> GPIO34"
Write-Host "========================================================"

$pio = Find-Pio
if (-not $pio) {
    Write-Fail "Chua cai PlatformIO."
    Write-Host "    Cach 1: cai VS Code, vao Extensions cai 'PlatformIO IDE', khoi dong lai VS Code."
    Write-Host "    Cach 2: py -m pip install -U platformio"
    exit 1
}
# Goi pio truc tiep o cap script (khong boc trong ham) de log build/nap hien ngay va Serial Monitor nhan phim binh thuong
$script:PioExe = $pio[0]
$script:PioPrefix = @()
if ($pio.Count -gt 1) { $script:PioPrefix = $pio[1..($pio.Count - 1)] }
Write-Host ("PlatformIO: " + ($pio -join " "))

if ($ListPorts) {
    Write-Step "Cac cong COM dang co"
    Show-Ports (Get-SerialPorts)
    exit 0
}

if (-not $MonitorOnly) {
    if (-not (Test-Path (Join-Path $firmwareDir "src\secrets.h"))) {
        Write-Warn "Chua co firmware\src\secrets.h: tram se thu WiFi mau 'iPhone' / 'password' va khong vao duoc mang."
        Write-Warn "Chep firmware\src\secrets.example.h thanh secrets.h, dien WiFi 2.4 GHz roi chay lai script."
        Write-Warn "Van tiep tuc nap de kiem tra cam bien qua Serial Monitor (khong can mang)."
    }

    Write-Step "Build firmware (lan dau PlatformIO tai toolchain ESP32, mat vai phut)"
    & $script:PioExe @script:PioPrefix run -d $firmwareDir
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Build that bai. Xem loi o tren."
        Write-Host "    - Bao '#error ... secrets.h': mo firmware\src\secrets.h, dien WiFi roi xoa dong #error."
        exit 1
    }
    if ($BuildOnly) {
        Write-Host ""
        Write-Host "Build xong: firmware\.pio\build\esp32dev\firmware.bin" -ForegroundColor Green
        exit 0
    }
}

Write-Step "Tim cong COM cua ESP32"
if ($Port -eq "") {
    $all = Get-SerialPorts
    $esp = @($all | Where-Object { $_.hwid -match $EspUsbIds })
    if ($esp.Count -eq 0) {
        Write-Fail "Khong thay ESP32. Cac cong dang co:"
        Show-Ports $all
        Write-Host "    - Dung cap USB truyen du lieu (nhieu cap chi sac duoc)."
        Write-Host "    - Mo Device Manager > Ports (COM & LPT): phai thay CP210x hoac CH340."
        Write-Host "      Neu khong thay, cai driver CP210x (Silicon Labs) hoac CH341SER (WCH) theo chip USB tren board."
        Write-Host "    - Biet cong roi thi chay lai voi -Port COMx."
        exit 1
    }
    $Port = $esp[0].port
    if ($esp.Count -gt 1) {
        Write-Warn "Thay $($esp.Count) board ESP32, chon $Port. Dung -Port COMx de chon board khac."
    }
}
Write-Host "Cong ESP32: $Port"

if (-not $MonitorOnly) {
    Write-Step "Nap code vao ESP32 qua $Port"
    & $script:PioExe @script:PioPrefix run -d $firmwareDir -t upload --upload-port $Port
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Nap code that bai."
        Write-Host "    - Bao 'Timed out waiting for packet header': giu nut BOOT khi thay 'Connecting....', nha ra khi bat dau ghi."
        Write-Host "    - Bao 'could not open port' / 'PermissionError': dong Serial Monitor hoac Arduino IDE dang mo cong."
        exit 1
    }
    Write-Host ""
    Write-Host "Nap code thanh cong!" -ForegroundColor Green

    if ($NoMonitor) { exit 0 }
}

Write-Step "Mo Serial Monitor 115200 (Ctrl+C de thoat, bam nut EN/RST tren board de xem log tu dau)"
& $script:PioExe @script:PioPrefix device monitor -p $Port -b 115200
