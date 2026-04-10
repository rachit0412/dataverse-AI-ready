# Dataverse Integration Test Runner
# Tests live Dataverse deployment without local Maven/Java
# Simulates REST Assured test patterns

$baseUrl = "http://localhost:8080"
$apiKey = "secret"
$testsPassed = 0
$testsFailed = 0

Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Dataverse Integration Test Suite (REST)  ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Test 1: API Health Check
Write-Host "[TEST 1/8] API Health Check" -ForegroundColor Yellow
try {
    $response = curl -s -w "`n%{http_code}" "$baseUrl/api/info/version" 2>$null
    $httpCode = $response[-1]
    $body = $response[0..($response.Length-2)] -join "`n"
    
    if ($httpCode -eq "200") {
        $version = $body | ConvertFrom-Json | Select-Object -ExpandProperty data | Select-Object -ExpandProperty version
        Write-Host "✅ PASS: API responding - v$version (HTTP $httpCode)" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "❌ FAIL: API not healthy (HTTP $httpCode)" -ForegroundColor Red
        $testsFailed++
    }
} catch {
    Write-Host "❌ FAIL: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 2: List Users (Admin endpoint)
Write-Host "`n[TEST 2/8] List Users - Admin Access" -ForegroundColor Yellow
try {
    $response = curl -s -w "`n%{http_code}" "$baseUrl/api/v1/admin/users?key=$apiKey" 2>$null
    $httpCode = $response[-1]
    $body = $response[0..($response.Length-2)] -join "`n"
    
    if ($httpCode -eq "200") {
        $users = $body | ConvertFrom-Json
        $count = $users.data | Measure-Object | Select-Object -ExpandProperty Count
        Write-Host "✅ PASS: Retrieved $count users (HTTP $httpCode)" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "❌ FAIL: Could not list users (HTTP $httpCode)" -ForegroundColor Red
        $testsFailed++
    }
} catch {
    Write-Host "❌ FAIL: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 3: Get Admin User Info
Write-Host "`n[TEST 3/8] Get Admin User - Retrieve Details" -ForegroundColor Yellow
try {
    $response = curl -s -w "`n%{http_code}" "$baseUrl/api/v1/users/admin?key=$apiKey" 2>$null
    $httpCode = $response[-1]
    $body = $response[0..($response.Length-2)] -join "`n"
    
    if ($httpCode -eq "200") {
        $user = $body | ConvertFrom-Json | Select-Object -ExpandProperty data
        $username = $user.userName
        Write-Host "✅ PASS: Retrieved user '$username' (HTTP $httpCode)" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "❌ FAIL: Could not retrieve user (HTTP $httpCode)" -ForegroundColor Red
        $testsFailed++
    }
} catch {
    Write-Host "❌ FAIL: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 4: Create Test User
Write-Host "`n[TEST 4/8] Create User - New User Registration" -ForegroundColor Yellow
try {
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $username = "testuser_$timestamp"
    
    $userData = @{
        firstName = "Integration"
        lastName = "Tester"
        userName = $username
        email = "tester@test.local"
        password = "IntegrationTest123"
    } | ConvertTo-Json
    
    $response = curl -s -w "`n%{http_code}" -X POST `
        -H "Content-Type: application/json" `
        -d $userData `
        "$baseUrl/api/v1/users?key=$apiKey" 2>$null
    
    $httpCode = $response[-1]
    $body = $response[0..($response.Length-2)] -join "`n"
    
    if ($httpCode -eq "201") {
        Write-Host "✅ PASS: User '$username' created (HTTP $httpCode)" -ForegroundColor Green
        $script:testUserName = $username
        $testsPassed++
    } elseif ($httpCode -eq "200") {
        Write-Host "✅ PASS: User created (HTTP $httpCode)" -ForegroundColor Green
        $script:testUserName = $username
        $testsPassed++
    } else {
        Write-Host "❌ FAIL: Could not create user (HTTP $httpCode)" -ForegroundColor Red
        $testsFailed++
    }
} catch {
    Write-Host "❌ FAIL: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 5: Retrieve Created User
Write-Host "`n[TEST 5/8] Retrieve User - Get Created User Details" -ForegroundColor Yellow
if ($script:testUserName) {
    try {
        $response = curl -s -w "`n%{http_code}" "$baseUrl/api/v1/users/$($script:testUserName)?key=$apiKey" 2>$null
        $httpCode = $response[-1]
        $body = $response[0..($response.Length-2)] -join "`n"
        
        if ($httpCode -eq "200") {
            $user = $body | ConvertFrom-Json | Select-Object -ExpandProperty data
            Write-Host "✅ PASS: Retrieved user '$($user.userName)' - Email: $($user.email) (HTTP $httpCode)" -ForegroundColor Green
            $testsPassed++
        } else {
            Write-Host "❌ FAIL: Could not retrieve user (HTTP $httpCode)" -ForegroundColor Red
            $testsFailed++
        }
    } catch {
        Write-Host "❌ FAIL: $_" -ForegroundColor Red
        $testsFailed++
    }
} else {
    Write-Host "⊘ SKIP: Test user not created" -ForegroundColor Gray
}

# Test 6: List Dataverses
Write-Host "`n[TEST 6/8] List Dataverses - Root Dataverse" -ForegroundColor Yellow
try {
    $response = curl -s -w "`n%{http_code}" "$baseUrl/api/v1/dataverses?key=$apiKey" 2>$null
    $httpCode = $response[-1]
    $body = $response[0..($response.Length-2)] -join "`n"
    
    if ($httpCode -eq "200") {
        $dataverses = $body | ConvertFrom-Json | Select-Object -ExpandProperty data
        $count = $dataverses | Measure-Object | Select-Object -ExpandProperty Count
        Write-Host "✅ PASS: Retrieved $count dataverse(s) (HTTP $httpCode)" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "❌ FAIL: Could not list dataverses (HTTP $httpCode)" -ForegroundColor Red
        $testsFailed++
    }
} catch {
    Write-Host "❌ FAIL: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 7: Get Root Dataverse Info
Write-Host "`n[TEST 7/8] Get Root Dataverse - Retrieve Metadata" -ForegroundColor Yellow
try {
    $response = curl -s -w "`n%{http_code}" "$baseUrl/api/v1/dataverses/root?key=$apiKey" 2>$null
    $httpCode = $response[-1]
    $body = $response[0..($response.Length-2)] -join "`n"
    
    if ($httpCode -eq "200") {
        $dv = $body | ConvertFrom-Json | Select-Object -ExpandProperty data
        Write-Host "✅ PASS: Retrieved root dataverse - Name: '$($dv.name)' (HTTP $httpCode)" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "❌ FAIL: Could not get root dataverse (HTTP $httpCode)" -ForegroundColor Red
        $testsFailed++
    }
} catch {
    Write-Host "❌ FAIL: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 8: API Permissions Check
Write-Host "`n[TEST 8/8] API Permissions - Invalid Key Rejection" -ForegroundColor Yellow
try {
    $response = curl -s -w "`n%{http_code}" "$baseUrl/api/v1/users/admin?key=invalid_key" 2>$null
    $httpCode = $response[-1]
    
    if ($httpCode -eq "401" -or $httpCode -eq "403") {
        Write-Host "✅ PASS: Invalid API key rejected (HTTP $httpCode)" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "⚠️  WARNING: Invalid key should return 401/403, got $httpCode" -ForegroundColor Yellow
        $testsFailed++
    }
} catch {
    Write-Host "❌ FAIL: $_" -ForegroundColor Red
    $testsFailed++
}

# Summary
Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║              TEST SUMMARY                 ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$total = $testsPassed + $testsFailed
Write-Host "Total Tests:      $total" -ForegroundColor Cyan
Write-Host "Passed:           $testsPassed" -ForegroundColor Green
Write-Host "Failed:           $testsFailed" -ForegroundColor Red

if ($testsFailed -eq 0) {
    Write-Host "`n✅ ALL TESTS PASSED!" -ForegroundColor Green
    Write-Host "`nYour Dataverse deployment is fully functional and ready for production testing.`n" -ForegroundColor Green
} else {
    Write-Host "`n⚠️  SOME TESTS FAILED`n" -ForegroundColor Yellow
    Write-Host "Check TESTING_WORKFLOW_GUIDE.md → 'Category 4: Coverage Report Missing'" -ForegroundColor Yellow
    Write-Host "for troubleshooting steps.`n" -ForegroundColor Yellow
}

# Test Statistics
$passRate = if ($total -gt 0) { [math]::Round(($testsPassed / $total) * 100, 1) } else { 0 }
Write-Host "Pass Rate:        ${passRate}%`n" -ForegroundColor Cyan

# Recommendations
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "├─ Review test results above" -ForegroundColor Gray
Write-Host "├─ Check TESTING_WORKFLOW_GUIDE.md for detailed procedures" -ForegroundColor Gray
Write-Host "├─ Install Java/Maven to run unit tests locally (optional)" -ForegroundColor Gray
Write-Host "├─ Generate code coverage reports (see TESTING_QUICK_REFERENCE.md)" -ForegroundColor Gray
Write-Host "└─ Write custom integration tests for your features`n" -ForegroundColor Gray
