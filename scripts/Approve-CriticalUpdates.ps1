#Requires -Version 5.1
<#
.SYNOPSIS
    Auto-approve Critical and Security updates in WSUS for a target group.
.PARAMETER WSUSServer
    WSUS server hostname.
.PARAMETER TargetGroup
    Computer target group name. Default: 'All Computers'
.PARAMETER Classifications
    Update classifications to approve.
.PARAMETER MinDaysOld
    Only approve updates released at least N days ago. Default: 1
.EXAMPLE
    .\Approve-CriticalUpdates.ps1 -WSUSServer "WSUS01" -TargetGroup "Servers" -MinDaysOld 1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]   $WSUSServer       = 'localhost',
    [int]      $Port             = 8530,
    [switch]   $UseSSL,
    [string]   $TargetGroup      = 'All Computers',
    [string[]] $Classifications  = @('Critical Updates', 'Security Updates'),
    [int]      $MinDaysOld       = 1
)

[reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration") | Out-Null
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer($WSUSServer, $UseSSL, $Port)

$group = $wsus.GetComputerTargetGroups() | Where-Object Name -eq $TargetGroup
if (-not $group) {
    Write-Error "Target group '$TargetGroup' not found."
    exit 1
}

$updateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
$updateScope.ApprovedStates = [Microsoft.UpdateServices.Administration.ApprovedStates]::NotApproved

$updates = $wsus.GetUpdates($updateScope) | Where-Object {
    $_.UpdateClassificationTitle -in $Classifications -and
    -not $_.IsDeclined -and
    $_.CreationDate -lt (Get-Date).AddDays(-$MinDaysOld)
}

Write-Host "Found $($updates.Count) update(s) to approve for '$TargetGroup'" -ForegroundColor Cyan
$approved = 0

foreach ($update in $updates) {
    Write-Host "  $($update.Title) [$($update.UpdateClassificationTitle)]"
    if ($PSCmdlet.ShouldProcess($update.Title, 'Approve')) {
        $update.Approve([Microsoft.UpdateServices.Administration.UpdateApprovalAction]::Install, $group) | Out-Null
        $approved++
    }
}

Write-Host "`nApproved: $approved update(s)" -ForegroundColor Green
