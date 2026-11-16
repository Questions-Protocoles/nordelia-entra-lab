<#
.SYNOPSIS
    Crée ou met à jour les salariés de Nordelia dans Microsoft Entra ID à partir de la liste maîtresse.

.DESCRIPTION
    Lit nordelia-users.csv (séparateur point-virgule, colonnes « Libellé [nomTechnique] »).
    - Compte absent  : création avec mot de passe temporaire à changer à la première connexion.
    - Compte présent : mise à jour des attributs (Poste, Département, Lieu du bureau, etc.).
    - Second passage : pose du gestionnaire (manager) de chaque salarié.
    Le script est idempotent : on peut le relancer sans créer de doublons.

.PARAMETER Simulation
    N'écrit rien dans le tenant : affiche seulement ce qui serait fait.

.EXAMPLE
    .\New-NordeliaUsers.ps1 -Simulation
    .\New-NordeliaUsers.ps1

.NOTES
    Prérequis : modules Microsoft.Graph.Authentication et Microsoft.Graph.Users,
    connexion préalable : Connect-MgGraph -Scopes "User.ReadWrite.All" -TenantId "nordelia.onmicrosoft.com"
    Lab Nordelia, module 2, étapes 2.3 et 2.4.
#>
[CmdletBinding()]
param(
    [string]$CheminCsv = (Join-Path $PSScriptRoot '..\data\nordelia-users.csv'),
    [switch]$Simulation
)

$ErrorActionPreference = 'Stop'

# 1. Vérifier la connexion Graph et ses droits
$ctx = Get-MgContext
if (-not $ctx) { throw "Pas de session Graph. Lancez d'abord Connect-MgGraph -Scopes 'User.ReadWrite.All'." }
if (-not $Simulation -and $ctx.Scopes -notcontains 'User.ReadWrite.All') {
    throw "La session n'a pas le droit User.ReadWrite.All. Reconnectez-vous avec ce scope."
}
Write-Host "Connecté en $($ctx.Account)" -ForegroundColor Cyan

# 2. Lire la liste maîtresse et indexer chaque ligne par nom technique (le texte entre crochets)
$lignes = Import-Csv -Path $CheminCsv -Delimiter ';' -Encoding UTF8
$salaries = foreach ($l in $lignes) {
    $s = @{}
    foreach ($p in $l.PSObject.Properties) {
        if ($p.Name -match '\[(\w+)\]') { $s[$Matches[1]] = $p.Value.Trim() }
    }
    $s
}
Write-Host "$($salaries.Count) salariés lus dans $CheminCsv" -ForegroundColor Cyan

# Table nom d'affichage -> UPN, pour retrouver les gestionnaires
$upnParNom = @{}
foreach ($s in $salaries) { $upnParNom[$s.displayName] = $s.userPrincipalName }

# 3. Mot de passe temporaire saisi par l'opérateur (jamais écrit dans un fichier)
$motDePasse = $null
if (-not $Simulation) {
    $secure = Read-Host 'Mot de passe temporaire des nouveaux comptes' -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $motDePasse = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

$attributs = 'givenName','surname','displayName','jobTitle','companyName','department','officeLocation','city','country','usageLocation'
$bilan = @()

# 4. Premier passage : créer ou mettre à jour
foreach ($s in $salaries) {
    $upn = $s.userPrincipalName
    $corps = @{}
    foreach ($a in $attributs) { if ($s[$a]) { $corps[$a] = $s[$a] } }

    # Recherche par filtre : renvoie simplement « rien » si le compte n'existe pas (pas d'erreur 404 affichée)
    $existant = Get-MgUser -Filter "userPrincipalName eq '$upn'" -Property Id

    if ($existant) {
        $action = 'Mis à jour'
        if (-not $Simulation) { Update-MgUser -UserId $upn -BodyParameter $corps }
    } else {
        $action = 'Créé'
        if (-not $Simulation) {
            $corps['userPrincipalName'] = $upn
            $corps['mailNickname']      = $upn.Split('@')[0]
            $corps['accountEnabled']    = $true
            $corps['passwordProfile']   = @{ password = $motDePasse; forceChangePasswordNextSignIn = $true }
            New-MgUser -BodyParameter $corps | Out-Null
        }
    }
    if ($Simulation) { $action = "[Simulation] $action" }
    $bilan += [pscustomobject]@{ Compte = $upn.Split('@')[0]; Action = $action; Gestionnaire = $s.manager }
    Write-Host ("{0,-22} {1}" -f $upn.Split('@')[0], $action)
}
$motDePasse = $null

# 5. Second passage : poser les gestionnaires (les comptes existent maintenant tous)
if (-not $Simulation) {
    Start-Sleep -Seconds 10   # laisse le temps à l'annuaire de répliquer les nouveaux comptes
    foreach ($s in $salaries) {
        if (-not $s.manager) { continue }
        $upnManager = $upnParNom[$s.manager]
        if (-not $upnManager) { Write-Warning "Gestionnaire introuvable pour $($s.displayName) : $($s.manager)"; continue }
        $idManager = (Get-MgUser -UserId $upnManager -Property Id).Id
        Set-MgUserManagerByRef -UserId $s.userPrincipalName -BodyParameter @{ '@odata.id' = "https://graph.microsoft.com/v1.0/users/$idManager" }
    }
    Write-Host 'Gestionnaires posés.' -ForegroundColor Cyan
}

# 6. Bilan
$bilan | Group-Object Action | Select-Object @{n='Action';e={$_.Name}}, Count | Format-Table -AutoSize
