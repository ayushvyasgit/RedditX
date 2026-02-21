# ============================================================================
# TEST SCRIPT - Run tests for each component
# Usage: .\test-components.ps1
# ============================================================================

Write-Host "`n🧪 Comments Service - Component Testing`n" -ForegroundColor Cyan

# Colors
$Green = "Green"
$Red = "Red"
$Yellow = "Yellow"
$Cyan = "Cyan"

# Test counter
$testsPassed = 0
$testsFailed = 0

function Test-Component {
    param(
        [string]$ComponentName,
        [string]$Path
    )
    
    Write-Host "`n📦 Testing: $ComponentName" -ForegroundColor $Yellow
    Write-Host "   Path: $Path" -ForegroundColor Gray
    
    try {
        $output = go test -v $Path 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-Host "   ✅ PASSED" -ForegroundColor $Green
            Write-Host $output -ForegroundColor Gray
            $script:testsPassed++
            return $true
        } else {
            Write-Host "   ❌ FAILED" -ForegroundColor $Red
            Write-Host $output -ForegroundColor Red
            $script:testsFailed++
            return $false
        }
    } catch {
        Write-Host "   ❌ ERROR: $_" -ForegroundColor $Red
        $script:testsFailed++
        return $false
    }
}

# Check if we're in the right directory
if (-not (Test-Path "go.mod")) {
    Write-Host "❌ Error: go.mod not found. Please run from project root." -ForegroundColor $Red
    exit 1
}

Write-Host "📋 Starting component tests...`n" -ForegroundColor $Cyan

# Test 1: pkg/errors
Test-Component -ComponentName "Error Handling Package" -Path "./pkg/errors/"

# Summary
Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor $Cyan
Write-Host "📊 Test Summary" -ForegroundColor $Cyan
Write-Host "=" * 60 -ForegroundColor $Cyan
Write-Host "✅ Passed: " -NoNewline -ForegroundColor $Green
Write-Host $testsPassed
Write-Host "❌ Failed: " -NoNewline -ForegroundColor $Red
Write-Host $testsFailed
Write-Host "=" * 60 -ForegroundColor $Cyan

if ($testsFailed -eq 0) {
    Write-Host "`n🎉 All tests passed!`n" -ForegroundColor $Green
    exit 0
} else {
    Write-Host "`n⚠️  Some tests failed. Please review the output above.`n" -ForegroundColor $Yellow
    exit 1
}
