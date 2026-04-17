#Requires -Version 5.1
<#
.SYNOPSIS
    Generate a patch compliance report from WSUS.
    Shows: compliant, missing updates, last sync per computer.
.PARAMETER WSUSServer
    WSUS server hostname. Default: localhost
.PARAMETER Port
    WSUS port. Default: 8530
.PARAMETER UseSSL
    Use HTTPS. Default: false
.PARAMETER ExportPath
    Optional CSV export path.
.EXAMPLE
    .\Get-PatchComplianceReport.ps1 -WSUSServer "WSUS01"
    .\Get-PatchComplianceReport.ps1 -WSUSServer "WSUS01" -ExportPath C:\Reports\compliance.csv
#>
[CmdletBinding()]
param(
    [string] $WSUSServer  = 'localhost',
    [int]    $Port        = 8530,
    [switch] $UseSSL,
    [string] $ExportPath  = ''
)

# Load WSUS assembly
[reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration") | Out-Null

try {
    $wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer($WSUSServer, $UseSSL, $Port)
    Write-Host "Connected to WSUS: $WSUSServer`:$Port" -ForegroundColor Green
} catch {
    Write-Error "Cannot connect to WSUS server '$WSUSServer': $_"
    exit 1
}

$computerScope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
$computers     = $wsus.GetComputerTargets($computerScope)

$report = foreach ($computer in $computers) {
    $summary = $computer.GetUpdateInstallationSummary()
    $total   = $summary.NotInstalledCount + $summary.InstalledCount + $summary.FailedCount

    [PSCustomObject]@{
        ComputerName     = $computer.FullDomainName
        IPAddress        = $computer.IPAddress
        OS               = $computer.OSDescription
        LastSyncTime     = $computer.LastSyncTime
        LastReportTime   = $computer.LastReportedStatusTime
        Installed        = $summary.InstalledCount
        Missing          = $summary.NotInstalledCount
        Failed           = $summary.FailedCount
        Total            = $total
        CompliancePct    = if ($total -gt 0) { [math]::Round(($summary.InstalledCount / $total) * 100, 1) } else { 100 }
        Status           = if ($summary.NotInstalledCount -eq 0 -and $summary.FailedCount -eq 0) { 'Compliant' } `
                           elseif ($summary.FailedCount -gt 0) { 'HasErrors' } `
                           else { 'Missing Updates' }
    }
}

# Summary
$total      = $report.Count
$compliant  = ($report | Where-Object Status -eq 'Compliant').Count
$missing    = ($report | Where-Object Status -eq 'Missing Updates').Count
$errors     = ($report | Where-Object Status -eq 'HasErrors').Count

Write-Host "`n=== Patch Compliance Report ===" -ForegroundColor Cyan
Write-Host "Total computers : $total"
Write-Host "Compliant       : $compliant" -ForegroundColor Green
Write-Host "Missing updates : $missing"   -ForegroundColor Yellow
Write-Host "Has errors      : $errors"    -ForegroundColor Red
Write-Host "Overall compliance: $([math]::Round(($compliant/$total)*100,1))%"

$report | Sort-Object CompliancePct | Format-Table ComputerName, OS, Missing, Failed, CompliancePct, Status -AutoSize

if ($ExportPath) {
    $report | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
    Write-Host "Exported to: $ExportPath" -ForegroundColor Green
}
