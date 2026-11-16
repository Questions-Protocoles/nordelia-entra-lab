<#
.SYNOPSIS
    Inventaire des méthodes d'authentification inscrites par chaque compte du tenant Nordelia.

.DESCRIPTION
    Lab Nordelia, module 4, étape 4.1. Remplace le rapport « Détails de l'inscription de
    l'utilisateur », réservé aux licences Premium (erreur 401 en Entra ID Free).
    Lecture seule : interroge /users/{id}/authentication/methods pour chaque compte.
    À exécuter sur le PC (pas sur la VM), connecté en admin.nordelia.

.EXAMPLE
    .\Get-NordeliaMfaInventory.ps1
    .\Get-NordeliaMfaInventory.ps1 -Chemin ..\inventaire-mfa-apres.csv
#>
[CmdletBinding()]
param([string]$Chemin = (Join-Path $PSScriptRoot '..\output\inventaire-mfa.csv'))
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'User.Read.All', 'UserAuthenticationMethod.Read.All' -NoWelcome

# Nom lisible de chaque type de méthode renvoyé par Graph
$noms = @{
    '#microsoft.graph.passwordAuthenticationMethod'                  = 'Mot de passe'
    '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod'    = 'Authenticator'
    '#microsoft.graph.fido2AuthenticationMethod'                     = 'Passkey (FIDO2)'
    '#microsoft.graph.phoneAuthenticationMethod'                     = 'Téléphone'
    '#microsoft.graph.softwareOathAuthenticationMethod'              = 'OATH logiciel'
    '#microsoft.graph.hardwareOathAuthenticationMethod'              = 'OATH matériel'
    '#microsoft.graph.temporaryAccessPassAuthenticationMethod'       = 'TAP'
    '#microsoft.graph.emailAuthenticationMethod'                     = 'E-mail'
    '#microsoft.graph.windowsHelloForBusinessAuthenticationMethod'   = 'Windows Hello'
    '#microsoft.graph.platformCredentialAuthenticationMethod'        = 'Platform SSO'
}
# Méthodes qui comptent comme second facteur (le mot de passe et l'e-mail ne comptent pas)
$fortes = 'Authenticator', 'Passkey (FIDO2)', 'Téléphone', 'OATH logiciel', 'OATH matériel', 'Windows Hello', 'Platform SSO'

$users = Get-MgUser -All -Property Id, DisplayName, UserPrincipalName, AccountEnabled, OnPremisesSyncEnabled |
    Sort-Object DisplayName

$resultat = foreach ($u in $users) {
    $methodes = Get-MgUserAuthenticationMethod -UserId $u.Id | ForEach-Object {
        $type = $_.AdditionalProperties['@odata.type']
        if ($noms.ContainsKey($type)) { $noms[$type] } else { $type }
    }
    $mfa = @($methodes | Where-Object { $_ -in $fortes })
    [pscustomobject]@{
        Nom        = $u.DisplayName
        UPN        = $u.UserPrincipalName
        Actif      = $u.AccountEnabled
        Source     = if ($u.OnPremisesSyncEnabled) { 'AD' } else { 'Cloud' }
        MFA        = [bool]$mfa.Count
        Methodes   = (@($methodes) | Sort-Object -Unique) -join ', '
    }
}

$resultat | Export-Csv -Path $Chemin -NoTypeInformation -Encoding UTF8 -Delimiter ';'

$total = @($resultat).Count
$avec  = @($resultat | Where-Object MFA).Count
$resultat | Format-Table Nom, Source, Actif, MFA, Methodes -AutoSize
Write-Host "$avec compte(s) sur $total avec au moins une méthode MFA ($([math]::Round(100 * $avec / $total)) %)." -ForegroundColor Cyan
Write-Host "Fichier : $((Resolve-Path $Chemin).Path)"
