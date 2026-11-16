<#
.SYNOPSIS
    Compare l'export de l'annuaire (verification-2.4.csv) à la liste maîtresse (nordelia-users.csv).

.DESCRIPTION
    Pour chaque salarié de la liste maîtresse, vérifie qu'il existe dans l'export et que
    9 attributs sont identiques : displayName, jobTitle, department, officeLocation, city,
    country, usageLocation, companyName, manager. Affiche chaque écart puis le total.
    Lab Nordelia, module 2, étape 2.4.

.EXAMPLE
    .\Test-NordeliaUsers.ps1
#>
param(
    [string]$Maitresse = (Join-Path $PSScriptRoot '..\data\nordelia-users.csv'),
    [string]$Export    = (Join-Path $PSScriptRoot '..\output\verification-2.4.csv')
)

$m = Import-Csv $Maitresse -Delimiter ';' -Encoding UTF8 | ForEach-Object {
    $h = @{}
    foreach ($p in $_.PSObject.Properties) { if ($p.Name -match '\[(\w+)\]') { $h[$Matches[1]] = $p.Value.Trim() } }
    [pscustomobject]$h
}
$v = Import-Csv $Export -Delimiter ';' -Encoding UTF8

$correspondance = @{
    displayName = 'DisplayName'; jobTitle = 'JobTitle'; department = 'Department'
    officeLocation = 'OfficeLocation'; city = 'City'; country = 'Country'
    usageLocation = 'UsageLocation'; companyName = 'CompanyName'; manager = 'Manager'
}

$ecarts = 0
foreach ($r in $m) {
    $x = $v | Where-Object { $_.UserPrincipalName -ieq $r.userPrincipalName }
    if (-not $x) { Write-Warning "Manquant : $($r.userPrincipalName)"; $ecarts++; continue }
    foreach ($k in $correspondance.Keys) {
        $attendu = "$($r.$k)"; $obtenu = "$($x.($correspondance[$k]))"
        if ($attendu -cne $obtenu) { Write-Warning "$($r.userPrincipalName) $k : attendu [$attendu], obtenu [$obtenu]"; $ecarts++ }
    }
}
Write-Host "$($m.Count) salariés contrôlés, $($correspondance.Count) attributs chacun : $ecarts écart(s)." -ForegroundColor $(if ($ecarts) { 'Yellow' } else { 'Green' })
