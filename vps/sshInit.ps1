$ErrorActionPreference = "Stop"

# ---- Config ----
$Org = "KrzysztofStaron"

# Prompt for repository name
$Repo = Read-Host "Enter the repository name (e.g., graph-llm-backend)"

if ([string]::IsNullOrWhiteSpace($Repo)) {
    Write-Host "Error: Repository name cannot be empty" -ForegroundColor Red
    exit 1
}

$FullRepo   = "$Org/$Repo"
$KeyName    = "${Org}_${Repo}_deploy_key"
$SecretName = "VPS_SSH_KEY"
$VpsHost = "vps"

Write-Host "`nConfiguration:" -ForegroundColor Cyan
Write-Host "  Organization: $Org"
Write-Host "  Repository:   $Repo"
Write-Host "  Full Repo:    $FullRepo"
Write-Host "  Key Name:     $KeyName"
Write-Host ""

# ---- 1. Generate SSH key (if missing) ----
if (-Not (Test-Path $KeyName)) {
    Write-Host "Generating SSH key: $KeyName" -ForegroundColor Yellow
    ssh-keygen -t ed25519 -f $KeyName -C "gh-actions:$Repo" -N '""'
} else {
    Write-Host "SSH key already exists, skipping generation." -ForegroundColor Green
}

# ---- 2. Append public key to VPS authorized_keys ----
ssh $VpsHost "mkdir -p ~/.ssh && chmod 700 ~/.ssh"

Get-Content "$KeyName.pub" |
    ssh $VpsHost "cat >> ~/.ssh/authorized_keys"

ssh $VpsHost "chmod 600 ~/.ssh/authorized_keys"

# ---- 3. Verify SSH access using the new key ----
Write-Host "Verifying SSH access with the new key..." -ForegroundColor Yellow
$sshTest = ssh -i $KeyName $VpsHost "echo 'SSH key works'" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nERROR: SSH key verification failed!" -ForegroundColor Red
    Write-Host "Cleaning up generated key files..." -ForegroundColor Yellow
    
    if (Test-Path $KeyName) {
        Remove-Item $KeyName -Force
        Write-Host "  Removed: $KeyName" -ForegroundColor Yellow
    }
    
    if (Test-Path "$KeyName.pub") {
        Remove-Item "$KeyName.pub" -Force
        Write-Host "  Removed: $KeyName.pub" -ForegroundColor Yellow
    }
    
    Write-Host "`nKey files have been cleaned up. Please check your VPS configuration." -ForegroundColor Red
    exit 1
}

Write-Host "SSH key verification successful!" -ForegroundColor Green

# ---- 4. Store private key as GitHub repo secret ----
Write-Host "`nStoring private key as GitHub secret..." -ForegroundColor Yellow
Get-Content $KeyName -Raw |
    gh secret set $SecretName --repo $FullRepo

Write-Host "`nDeployment setup complete!" -ForegroundColor Green
Write-Host "  SSH key: $KeyName" -ForegroundColor Cyan
Write-Host "  GitHub secret: $SecretName" -ForegroundColor Cyan
Write-Host "  Repository: $FullRepo" -ForegroundColor Cyan
