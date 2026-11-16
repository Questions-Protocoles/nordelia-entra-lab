<#
.SYNOPSIS
    Produit l'inventaire des applications du tenant Nordelia (lab) : qui y accède, avec quels droits,
    et quand expirent leurs certificats et secrets.

.DESCRIPTION
    Retient les principaux de service qui comptent pour la sécurité :
      - les applications de l'organisation (inscriptions et applications de galerie) ;
      - toute application, même tierce ou Microsoft, qui a reçu un consentement délégué
        ou une permission d'application sur Microsoft Graph.
    Pour chacune : éditeur, type d'authentification, propriétaires, affectation requise,
    accès attribués (utilisateur : rôle), permissions d'application, permissions déléguées,
    certificats et secrets, prochaine expiration et jours restants.
    Exporte un CSV (séparateur point-virgule, UTF-8) lisible dans Excel.
    Lab Nordelia, module 6, étape 6.7. Lecture seule : le script ne modifie rien.

.EXAMPLE
    Connect-MgGraph -Scopes "Application.Read.All","Directory.Read.All" -TenantId "nordelia.onmicrosoft.com"
    .\Get-NordeliaAppInventory.ps1
#>
[CmdletBinding()]
param(
    [string]$CheminCsv = (Join-Path $PSScriptRoot '..\output\inventaire-applications.csv')
)
$ErrorActionPreference = 'Stop'

$ctx = Get-MgContext
if (-not $ctx) { throw "Pas de session Graph. Lancez d'abord Connect-MgGraph -Scopes 'Application.Read.All','Directory.Read.All'." }
if ($ctx.AuthType -eq 'AppOnly') { throw "Session applicative détectée ($($ctx.AppName)). Reconnectez-vous avec admin.nordelia." }
Write-Host "Connecté en $($ctx.Account)" -ForegroundColor Cyan

$tenantId   = $ctx.TenantId
# Tenants éditeurs connus des applications Microsoft ; à défaut, on se fie à l'éditeur vérifié
# (Microsoft publie depuis plusieurs tenants, ex. cdc5aeea-... pour Microsoft Graph Command Line Tools)
$microsoft  = @('f8cdef31-a31e-4b4a-93e4-5f571e91255a', '72f988bf-86f1-41af-91ab-2d7cd011db47', 'cdc5aeea-15c5-4db6-b079-fcadd2505dc2')
$graphAppId = '00000003-0000-0000-c000-000000000000'   # Microsoft Graph
$aujourdhui = Get-Date

# 1. Tous les principaux de service, indexés par Id
$proprietes = 'Id','AppId','DisplayName','AppOwnerOrganizationId','PreferredSingleSignOnMode',
              'AppRoleAssignmentRequired','KeyCredentials','PasswordCredentials','AppRoles','Oauth2PermissionScopes','VerifiedPublisher'
$sps = Get-MgServicePrincipal -All -Property $proprietes
$spParId = @{}; foreach ($s in $sps) { $spParId[$s.Id] = $s }
Write-Host "$($sps.Count) principaux de service dans le tenant" -ForegroundColor Cyan

# 2. Consentements délégués (une seule requête pour tout le tenant)
$grants = @(Get-MgOauth2PermissionGrant -All)

# 3. Permissions d'application accordées sur Microsoft Graph
$graph = $sps | Where-Object AppId -eq $graphAppId
$permsGraph = @(Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $graph.Id -All)

# 4. Périmètre : applications de l'organisation + applications ayant reçu des droits
$ids = [System.Collections.Generic.HashSet[string]]::new()
foreach ($s in $sps)        { if ($s.AppOwnerOrganizationId -eq $tenantId) { [void]$ids.Add($s.Id) } }
foreach ($g in $grants)     { [void]$ids.Add($g.ClientId) }
foreach ($p in $permsGraph) { if ($p.PrincipalType -eq 'ServicePrincipal') { [void]$ids.Add($p.PrincipalId) } }

function Get-NomRole($resource, [string]$roleId) {
    if ($roleId -eq '00000000-0000-0000-0000-000000000000') { return 'Accès par défaut' }
    $r = $resource.AppRoles | Where-Object { $_.Id -eq $roleId }
    if (-not $r) { return $roleId }
    # Certains rôles de galerie (msiam_access) n'ont pas de valeur : on prend alors le nom d'affichage
    if ($r.Value) { $r.Value } else { $r.DisplayName }
}

$inventaire = foreach ($id in $ids) {
    $sp = $spParId[$id]
    if (-not $sp) { continue }

    # Éditeur
    $editeur = if ($sp.AppOwnerOrganizationId -eq $tenantId)               { 'Nordelia' }
               elseif ($microsoft -contains $sp.AppOwnerOrganizationId -or
                       $sp.VerifiedPublisher.DisplayName -eq 'Microsoft Corporation') { 'Microsoft' }
               else                                                        { 'Tiers' }
    $verifie = if ($sp.VerifiedPublisher.DisplayName) { $sp.VerifiedPublisher.DisplayName } else { 'Non vérifié' }

    # Identifiants : ceux de l'inscription (si elle est dans ce tenant) + ceux du principal de service
    $cles = @($sp.KeyCredentials); $secrets = @($sp.PasswordCredentials)
    if ($editeur -eq 'Nordelia') {
        $app = Get-MgApplication -Filter "appId eq '$($sp.AppId)'" -Property KeyCredentials,PasswordCredentials
        if ($app) { $cles += $app.KeyCredentials; $secrets += $app.PasswordCredentials }
    }
    # Un certificat SAML apparaît en double (usage Sign et Verify) : dédoublonner par nom et date de fin
    $cles = @($cles | Where-Object { $_ } | Group-Object { "$($_.DisplayName)|$($_.EndDateTime)" } | ForEach-Object { $_.Group[0] })
    # Un certificat de signature SAML s'accompagne d'une entrée « mot de passe » qui protège sa clé privée :
    # ce n'est pas un secret client, on l'écarte (même identifiant ou même date de fin que le certificat)
    $idsCles  = @($cles | Where-Object CustomKeyIdentifier | ForEach-Object { [Convert]::ToBase64String($_.CustomKeyIdentifier) })
    $finsCles = @($cles | ForEach-Object { "$($_.EndDateTime)" })
    $estSaml  = $sp.PreferredSingleSignOnMode -eq 'saml'
    $secrets = @($secrets | Where-Object { $_ } | Where-Object {
        $memeId  = $_.CustomKeyIdentifier -and $idsCles -contains [Convert]::ToBase64String($_.CustomKeyIdentifier)
        $memeFin = $estSaml -and $finsCles -contains "$($_.EndDateTime)"
        -not ($memeId -or $memeFin) })
    $fins = @(@($cles | ForEach-Object EndDateTime) + @($secrets | ForEach-Object EndDateTime) | Where-Object { $_ } | Sort-Object)
    $prochaine = if ($fins) { $fins[0] } else { $null }

    # Type d'authentification
    $typeAuth = if ($sp.PreferredSingleSignOnMode -eq 'saml') { 'SSO SAML' }
                elseif ($sp.PreferredSingleSignOnMode)       { "SSO $($sp.PreferredSingleSignOnMode)" }
                elseif ($cles -and -not $secrets)            { 'Identité d''application (certificat)' }
                elseif ($secrets)                            { 'Identité d''application (secret client)' }
                else                                         { 'OAuth / OIDC (délégué)' }

    # Propriétaires
    $proprios = (Get-MgServicePrincipalOwner -ServicePrincipalId $sp.Id -All |
                 ForEach-Object { $_.AdditionalProperties.displayName }) -join ', '

    # Utilisateurs et groupes attribués à l'application, avec leur rôle
    $acces = (Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $sp.Id -All |
              Where-Object PrincipalType -ne 'ServicePrincipal' |
              ForEach-Object { "$($_.PrincipalDisplayName) : $(Get-NomRole $sp $_.AppRoleId)" }) -join ' | '

    # Permissions d'application que CETTE application a reçues (sur toute API)
    $permsApp = (Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -All |
                 ForEach-Object { "$($_.ResourceDisplayName) : $(Get-NomRole $spParId[$_.ResourceId] $_.AppRoleId)" }) -join ' | '

    # Permissions déléguées consenties
    $permsDel = ($grants | Where-Object ClientId -eq $sp.Id | ForEach-Object {
                    $portee = if ($_.ConsentType -eq 'AllPrincipals') { 'tous' } else { 'un utilisateur' }
                    "$($spParId[$_.ResourceId].DisplayName) : $($_.Scope.Trim()) ($portee)"
                }) -join ' | '

    [pscustomobject][ordered]@{
        'Application'                  = $sp.DisplayName
        "ID d'application"             = $sp.AppId
        'Éditeur'                      = $editeur
        'Éditeur vérifié'              = $verifie
        "Type d'authentification"      = $typeAuth
        'Propriétaires'                = if ($proprios) { $proprios } else { 'AUCUN' }
        'Affectation requise'          = if ($sp.AppRoleAssignmentRequired) { 'Oui' } else { 'Non' }
        'Accès attribués'              = $acces
        "Permissions d'application"    = $permsApp
        'Permissions déléguées'        = $permsDel
        'Certificats'                  = $cles.Count
        'Secrets clients'              = $secrets.Count
        'Prochaine expiration'         = if ($prochaine) { $prochaine.ToString('dd/MM/yyyy') } else { '' }
        'Jours restants'               = if ($prochaine) { [int]($prochaine - $aujourdhui).TotalDays } else { '' }
    }
}

$inventaire = $inventaire | Sort-Object 'Éditeur', 'Application'
$inventaire | Export-Csv -Path $CheminCsv -Delimiter ';' -Encoding UTF8 -NoTypeInformation
Write-Host "$(@($inventaire).Count) application(s) inventoriée(s) -> $CheminCsv" -ForegroundColor Green

# Alertes de revue
foreach ($a in $inventaire) {
    if ($a.'Propriétaires' -eq 'AUCUN' -and $a.'Éditeur' -eq 'Nordelia') { Write-Warning "$($a.Application) : aucun propriétaire" }
    if ($a.'Secrets clients' -gt 0) { Write-Warning "$($a.Application) : secret client présent (préférer un certificat)" }
    if ($a.'Jours restants' -ne '' -and $a.'Jours restants' -lt 60) { Write-Warning "$($a.Application) : expiration dans $($a.'Jours restants') jours" }
}
$inventaire | Select-Object Application, 'Éditeur', "Type d'authentification", 'Propriétaires', 'Prochaine expiration' | Format-Table -AutoSize
