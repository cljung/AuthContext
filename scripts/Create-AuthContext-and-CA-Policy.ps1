# Import-Module Microsoft.Graph.Identity.SignIns
# Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess", "AuthenticationContext.ReadWrite.All"

$authContextName = "AuthContext-for-SensitiveOperations"
$caPolicyName = "AuthContext {auCtxId} Step-up MFA for sensitive operations"

Write-Host "Checking for available Authentication Context slots..." -ForegroundColor Cyan

$allContexts = Get-MgIdentityConditionalAccessAuthenticationContextClassReference

$usedNumbers = $allContexts.Id | ForEach-Object { if ($_ -match 'c(\d+)') { [int]$Matches[1] } }
$nextFreeId = $null
for ($i = 1; $i -le 99; $i++) {
    if ($i -notin $usedNumbers) {
        $nextFreeId = "c$i"
        break
    }
}
if ($nextFreeId) {
    Write-Host "The next free Authentication Context ID is: $nextFreeId" -ForegroundColor Green
} else {
    Write-Warning "No free IDs found. Entra ID strictly limits you to 99 contexts (c1-c99)."
}

$contextParams = @{
    DisplayName = $authContextName
    Description = "Triggers a mandatory MFA prompt for elevated or high-risk resource interactions."
    IsAvailable = $true 
}

Update-MgIdentityConditionalAccessAuthenticationContextClassReference `
    -AuthenticationContextClassReferenceId $nextFreeId `
    -BodyParameter $contextParams

Write-Host "Authentication Context successfully registered to slot [$nextFreeId]!" -ForegroundColor Green


Write-Host "Constructing Conditional Access Policy payload..." -ForegroundColor Cyan

$currentContext = Get-MgContext
$currentUserId = $currentContext.Account

# If Account yields an email, fetch the absolute Object ID instead
if ($currentUserId -like "*@*") {
    $currentUserProfile = Invoke-MgGraphRequest -Method GET -Uri "v1.0/me"
    $currentUserId = $currentUserProfile.id
}

$policyParams = @{
    displayName = $caPolicyName.Replace("{auCtxId}", $nextFreeId)
    state       = "disabled" # Created as disabled first for safety    
    conditions  = @{
        users = @{
            includeUsers = @($currentUserId)
            excludeUsers = @() # Recommended: Add break-glass / emergency account IDs here
        }
        applications = @{
            includeAuthenticationContextClassReferences = @($nextFreeId)
        }
    }
    grantControls = @{
        operator        = "OR"
        builtInControls = @("mfa")
    }
}

$caPolicy = New-MgIdentityConditionalAccessPolicy -BodyParameter $policyParams

Write-Host "Conditional Access Policy successfully deployed!" -ForegroundColor Green
Write-Host "Policy Name: $($caPolicy.DisplayName)"
Write-Host "Policy ID  : $($caPolicy.Id)"
Write-Host "Bound to   : $($nextFreeId) Authentication Context"
Write-Host "Target user: $($currentContext.Account)"
Write-Host "*** CA POLICY IS DISABLED. TO TEST, ENABLE IT FIRST! ***" -ForegroundColor White
