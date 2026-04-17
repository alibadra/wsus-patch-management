# WSUS Patch Management

PowerShell scripts to automate Windows Server Update Services (WSUS) administration: synchronization, approval, deployment, and compliance reporting.

## Scripts

| Script | Description |
|--------|-------------|
| `scripts/Invoke-WSUSSync.ps1` | Trigger WSUS sync and wait for completion |
| `scripts/Approve-CriticalUpdates.ps1` | Auto-approve Critical/Security updates |
| `scripts/Get-PatchComplianceReport.ps1` | Compliance report: patched vs. missing per server |
| `scripts/Invoke-ClientForceUpdate.ps1` | Force Windows Update on remote clients |
| `scripts/Get-WSUSHealthCheck.ps1` | WSUS server health: disk, database, sync status |

## Quick Start

```powershell
# Install WSUS role (on your WSUS server)
Install-WindowsFeature -Name UpdateServices, UpdateServices-UI, UpdateServices-DB `
    -IncludeManagementTools

# Connect to WSUS and run initial sync
.\scripts\Invoke-WSUSSync.ps1 -WSUSServer "WSUS01" -Port 8530

# Get compliance report
.\scripts\Get-PatchComplianceReport.ps1 -WSUSServer "WSUS01" | `
    Export-Csv C:\Reports\patch-compliance.csv

# Auto-approve critical updates for Servers group
.\scripts\Approve-CriticalUpdates.ps1 -WSUSServer "WSUS01" -TargetGroup "Servers"
```

## Patch Strategy

| Patch Type | Approval | Deployment Ring |
|-----------|---------|----------------|
| Critical / Security | Auto (after 24h) | Test → Pilot → Prod |
| Important | Manual review | Weekly maintenance window |
| Optional / Driver | Manual | On request |
