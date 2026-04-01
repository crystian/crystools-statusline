# ============================================================
#  install-crystools.ps1
#  Instalador automático de crystools para Windows
#  Repositorio: https://github.com/crystian/crystools
# ============================================================

param(
    [switch]$SkipVerification,
    [switch]$Verbose
)

# ── Helpers ──────────────────────────────────────────────────

function Write-Step { param($msg) Write-Host "`n▶  $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "  ✔  $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  ⚠  $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "  ✘  $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "     $msg" -ForegroundColor Gray }

function Invoke-Step {
    param(
        [string]$Description,
        [scriptblock]$Action,
        [switch]$ContinueOnError
    )
    Write-Step $Description
    try {
        $result = & $Action
        return $result
    } catch {
        Write-Fail "Error: $_"
        if (-not $ContinueOnError) {
            Write-Host "`nInstalacion cancelada. Corrige el error y vuelve a ejecutar.`n" -ForegroundColor Red
            exit 1
        }
        return $false
    }
}

# ── Banner ───────────────────────────────────────────────────

Write-Host @"

  ╔══════════════════════════════════════════╗
  ║   crystools · mia-marketplace installer  ║
  ║   for Claude Code on Windows             ║
  ╚══════════════════════════════════════════╝

"@ -ForegroundColor Magenta

# ── PASO 1: Verificar Claude Code ───────────────────────────

Invoke-Step "Verificando instalacion de Claude Code..." {
    $claudePath = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claudePath) {
        Write-Fail "Claude Code no encontrado en el PATH."
        Write-Info "Instalalo desde: https://claude.ai/code"
        exit 1
    }
    $version = & claude --version 2>&1
    Write-OK "Claude Code encontrado: $version"
    Write-Info "Ruta: $($claudePath.Source)"
}

# ── PASO 2: Verificar Node.js ────────────────────────────────

Invoke-Step "Verificando Node.js..." {
    $nodeVersion = & node --version 2>&1
    $npmVersion  = & npm  --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Node.js no encontrado (Claude Code normalmente lo incluye)."
    } else {
        Write-OK "Node $nodeVersion  /  npm $npmVersion"
    }
} -ContinueOnError

# ── PASO 3: Añadir marketplace ───────────────────────────────

Invoke-Step "Anadiendo marketplace crystian/mia-marketplace..." {
    $marketplaces = & claude plugins marketplace list 2>&1
    if ($Verbose) { Write-Info $marketplaces }

    if ($marketplaces -match "mia-marketplace") {
        Write-Warn "El marketplace ya estaba configurado. Saltando."
        return
    }

    $output = & claude plugins marketplace add crystian/mia-marketplace 2>&1
    if ($Verbose) { Write-Info $output }

    if ($LASTEXITCODE -ne 0) {
        throw "Fallo la adicion del marketplace. Output: $output"
    }
    Write-OK "Marketplace anadido correctamente."
}

# ── PASO 4: Instalar plugin statusline ──────────────────────

Invoke-Step "Instalando plugin statusline@mia-marketplace..." {
    $plugins = & claude plugins list 2>&1
    if ($Verbose) { Write-Info $plugins }

    if ($plugins -match "statusline") {
        Write-Warn "El plugin statusline ya estaba instalado. Saltando."
        return
    }

    $output = & claude plugins install statusline@mia-marketplace 2>&1
    if ($Verbose) { Write-Info $output }

    if ($LASTEXITCODE -ne 0) {
        throw "Fallo la instalacion del plugin. Output: $output"
    }
    Write-OK "Plugin statusline instalado correctamente."
}

# ── PASO 5: Verificacion final ───────────────────────────────

if (-not $SkipVerification) {
    Invoke-Step "Verificando resultado final..." {
        $marketplaces = & claude plugins marketplace list 2>&1
        $plugins      = & claude plugins list 2>&1

        if ($marketplaces -match "mia-marketplace") {
            Write-OK "Marketplace mia-marketplace: activo"
        } else {
            Write-Warn "Marketplace no detectado. Revisa: claude plugins marketplace list"
        }

        if ($plugins -match "statusline") {
            Write-OK "Plugin statusline: instalado"
        } else {
            Write-Warn "Plugin no detectado. Revisa: claude plugins list"
        }
    } -ContinueOnError
}

# ── Resumen ──────────────────────────────────────────────────

Write-Host @"

  ╔══════════════════════════════════════════╗
  ║   Instalacion completada correctamente   ║
  ╚══════════════════════════════════════════╝

  Proximos pasos:
    1. Abre una nueva sesion de Claude Code
    2. Comprueba la statusline en la parte inferior
    3. Si algo falla, depura con:
         claude plugins marketplace list
         claude plugins list

"@ -ForegroundColor Green
