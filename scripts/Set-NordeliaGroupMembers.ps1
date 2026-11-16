<#
.SYNOPSIS
    Remplit GRP-ALL-USERS avec les salariés de la liste maîtresse, puis contrôle les 3 groupes métier.

.DESCRIPTION
    1. Ajoute à GRP-ALL-USERS chaque salarié de nordelia-users.csv qui n'en est pas encore membre
       (idempotent : relançable sans doublon).
    2. Contrôle l'appartenance attendue :
         GRP-ALL-USERS  = les 20 salariés
         GRP-FIN-PAIE   = les salariés du département Finance
         GRP-CONS-USERS = les salariés du département Consultants
       et signale tout membre manquant ou en trop.
    Lab Nordelia, module 2, étape 2.5.5.

.PARAMETER Simulation
    N'écrit rien : affiche seulement les ajouts prévus et le contrôle.

.NOTES
    Prérequis : Install-Module Microsoft.Graph.Groups -Scope CurrentUser
    Connect-MgGraph -Scopes "User.Read.All","GroupMember.ReadWrite.All" -TenantId "nordelia.onmicrosoft.com"
#>
[CmdletBinding()]
param(
    [string]$CheminCsv = (Join-Path $PSScriptRoot '..\data\nordelia-users.csv'),
    [switch]$Simulation
)
$ErrorActionPreference = 'Stop'

$ctx = Get-MgContext
if (-not $ctx) { throw "Pas de session Graph. Lancez d'abord Connect-MgGraph." }
Write-Host "Connecté en $($ctx.Account)" -ForegroundColor Cyan

# Liste maîtresse indexée par nom technique
$salaries = Import-Csv $CheminCsv -Delimiter ';' -Encoding UTF8 | ForEach-Object {
    $h = @{}
    foreach ($p in $_.PSObject.Properties) { if ($p.Name -match '\[(\w+)\]') { $h[$Matches[1]] = $p.Value.Trim() } }
    [pscustomobject]$h
}

function Get-Groupe([string]$nom) {
    $g = Get-MgGroup -Filter "displayName eq '$nom'" -Property Id,DisplayName
    if (-not $g) { throw "Groupe introuvable : $nom" }
    $g
}
function Get-MembresUpn([string]$groupId) {
    Get-MgGroupMember -GroupId $groupId -All | ForEach-Object { $_.AdditionalProperties.userPrincipalName } | Where-Object { $_ }
}

# 1. Remplir GRP-ALL-USERS
$all = Get-Groupe 'GRP-ALL-USERS'
$dejaMembres = @(Get-MembresUpn $all.Id)
$ajouts = 0
foreach ($s in $salaries) {
    if ($dejaMembres -contains $s.userPrincipalName) { continue }
    $ajouts++
    if ($Simulation) { Write-Host "[Simulation] Ajout de $($s.userPrincipalName.Split('@')[0])"; continue }
    $u = Get-MgUser -Filter "userPrincipalName eq '$($s.userPrincipalName)'" -Property Id
    New-MgGroupMember -GroupId $all.Id -DirectoryObjectId $u.Id
    Write-Host "Ajouté : $($s.userPrincipalName.Split('@')[0])"
}
Write-Host "$ajouts ajout(s) $(if ($Simulation) {'prévu(s)'} else {'effectué(s)'}) dans GRP-ALL-USERS." -ForegroundColor Cyan
if (-not $Simulation -and $ajouts) { Start-Sleep -Seconds 5 }

# 2. Contrôler les 3 groupes
$attendus = [ordered]@{
    'GRP-ALL-USERS'  = @($salaries.userPrincipalName)
    'GRP-FIN-PAIE'   = @($salaries | Where-Object department -eq 'Finance'     | ForEach-Object userPrincipalName)
    'GRP-CONS-USERS' = @($salaries | Where-Object department -eq 'Consultants' | ForEach-Object userPrincipalName)
}
$bilan = foreach ($nom in $attendus.Keys) {
    $reels = @(Get-MembresUpn (Get-Groupe $nom).Id)
    $manquants = @($attendus[$nom] | Where-Object { $reels -notcontains $_ })
    $enTrop    = @($reels | Where-Object { $attendus[$nom] -notcontains $_ })
    foreach ($m in $manquants) { Write-Warning "$nom : membre manquant $m" }
    foreach ($m in $enTrop)    { Write-Warning "$nom : membre en trop $m" }
    [pscustomobject]@{ Groupe = $nom; Attendus = $attendus[$nom].Count; Reels = $reels.Count; Manquants = $manquants.Count; EnTrop = $enTrop.Count }
}
$bilan | Format-Table -AutoSize
