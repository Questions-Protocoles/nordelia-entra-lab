<#
.SYNOPSIS
    Exporte la configuration du tenant Nordelia (lecture seule) pour la reconstruire ailleurs.

.DESCRIPTION
    Lab Nordelia, préparation du transfert vers un nouveau tenant (option B).
    Lecture seule : uniquement des requêtes GET sur Microsoft Graph, aucune modification.
    Produit dans un dossier horodaté :
      - CSV  : utilisateurs, groupes, membres et propriétaires, rôles d'annuaire
      - JSON : organisation, domaines, stratégies (autorisation, méthodes d'authentification,
               paramètres de sécurité par défaut, appareils, consentement), applications
      - resume.txt : ce qui a été exporté, ce qui a échoué, ce qui n'est pas transférable

    Non transférable par nature : mots de passe, méthodes MFA inscrites, jonction des appareils,
    journaux, clés privées des certificats. Ces points se refont à la main dans le nouveau tenant.

    Les fichiers produits contiennent des données réelles du tenant : ne pas les publier.
    À exécuter sur le PC (pas sur la VM), connecté avec un compte Administrateur général
    ou Lecteur global.

.EXAMPLE
    .\Export-NordeliaTenant.ps1
    .\Export-NordeliaTenant.ps1 -Dossier D:\sauvegardes\nordelia
#>
[CmdletBinding()]
param([string]$Dossier = (Join-Path $PSScriptRoot '..\export'))
$ErrorActionPreference = 'Stop'

$scopes = 'User.Read.All', 'Group.Read.All', 'Directory.Read.All', 'Policy.Read.All',
          'Application.Read.All', 'RoleManagement.Read.Directory', 'Policy.Read.DeviceConfiguration'
Connect-MgGraph -Scopes $scopes -NoWelcome
$ctx = Get-MgContext
if ($ctx.AuthType -eq 'AppOnly') { throw "Session applicative détectée. Reconnectez-vous avec un compte administrateur." }

$cible = Join-Path $Dossier (Get-Date -Format 'yyyy-MM-dd_HHmm')
New-Item -ItemType Directory -Path $cible -Force | Out-Null
$bilan = [System.Collections.Generic.List[string]]::new()

# --- Outils -----------------------------------------------------------------

# GET avec pagination (@odata.nextLink). Renvoie la liste des objets.
function Get-Graph([string]$Uri) {
    $items = @()
    while ($Uri) {
        $r = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
        if ($null -ne $r.value) { $items += $r.value; $Uri = $r.'@odata.nextLink' }
        else { return $r }
    }
    return $items
}

function Save-Json([string]$Nom, $Objet) {
    $chemin = Join-Path $cible "$Nom.json"
    $Objet | ConvertTo-Json -Depth 12 | Out-File -FilePath $chemin -Encoding utf8
    $n = @($Objet).Count
    $bilan.Add(("OK      {0,-34} {1} élément(s)" -f "$Nom.json", $n))
}

function Save-Csv([string]$Nom, $Lignes) {
    $chemin = Join-Path $cible "$Nom.csv"
    @($Lignes) | Export-Csv -Path $chemin -NoTypeInformation -Encoding UTF8 -Delimiter ';'
    $bilan.Add(("OK      {0,-34} {1} ligne(s)" -f "$Nom.csv", @($Lignes).Count))
}

# Exécute un export ; en cas d'erreur (droit manquant, fonction absente en Free), note et continue.
function Invoke-Export([string]$Nom, [scriptblock]$Bloc) {
    try { & $Bloc }
    catch { $bilan.Add(("ÉCHEC   {0,-34} {1}" -f $Nom, $_.Exception.Message.Split("`n")[0])) }
}

$v1 = 'https://graph.microsoft.com/v1.0'

# --- Organisation et domaines ----------------------------------------------

Invoke-Export 'organisation' {
    Save-Json 'organisation' (Get-Graph "$v1/organization?`$select=displayName,countryLetterCode,preferredLanguage,technicalNotificationMails,privacyProfile,securityComplianceNotificationMails")
}
Invoke-Export 'domaines' {
    Save-Json 'domaines' (Get-Graph "$v1/domains?`$select=id,isDefault,isInitial,isVerified,authenticationType")
}

# --- Utilisateurs ------------------------------------------------------------

$users = @()
Invoke-Export 'utilisateurs' {
    $champs = 'id,userPrincipalName,displayName,givenName,surname,jobTitle,department,companyName,' +
              'officeLocation,city,country,usageLocation,mail,accountEnabled,userType,' +
              'onPremisesSyncEnabled,externalUserState,creationType'
    $script:users = @(Get-Graph "$v1/users?`$select=$champs&`$expand=manager(`$select=userPrincipalName)")
    $lignes = foreach ($u in $script:users | Sort-Object userType, displayName) {
        [pscustomobject]@{
            userPrincipalName = $u.userPrincipalName
            displayName       = $u.displayName
            givenName         = $u.givenName
            surname           = $u.surname
            jobTitle          = $u.jobTitle
            department        = $u.department
            companyName       = $u.companyName
            officeLocation    = $u.officeLocation
            city              = $u.city
            country           = $u.country
            usageLocation     = $u.usageLocation
            mail              = $u.mail
            manager           = $u.manager.userPrincipalName
            accountEnabled    = $u.accountEnabled
            userType          = $u.userType
            source            = if ($u.onPremisesSyncEnabled) { 'AD (Cloud Sync)' } else { 'Cloud' }
            externalUserState = $u.externalUserState
        }
    }
    Save-Csv 'utilisateurs' $lignes
}

# --- Groupes, membres, propriétaires ----------------------------------------

Invoke-Export 'groupes' {
    $champs = 'id,displayName,description,mailEnabled,mailNickname,securityEnabled,groupTypes,' +
              'membershipRule,membershipRuleProcessingState,isAssignableToRole,visibility'
    $groupes = @(Get-Graph "$v1/groups?`$select=$champs") | Sort-Object displayName
    Save-Csv 'groupes' ($groupes | Select-Object displayName, description, securityEnabled, mailEnabled,
        mailNickname, @{n='groupTypes';e={$_.groupTypes -join ','}}, membershipRule,
        isAssignableToRole, visibility)

    $membres = foreach ($g in $groupes) {
        foreach ($m in Get-Graph "$v1/groups/$($g.id)/members?`$select=id,displayName,userPrincipalName") {
            [pscustomobject]@{ groupe = $g.displayName; relation = 'membre'
                type = $m.'@odata.type' -replace '#microsoft.graph.', ''
                userPrincipalName = $m.userPrincipalName; displayName = $m.displayName }
        }
        foreach ($o in Get-Graph "$v1/groups/$($g.id)/owners?`$select=id,displayName,userPrincipalName") {
            [pscustomobject]@{ groupe = $g.displayName; relation = 'propriétaire'
                type = $o.'@odata.type' -replace '#microsoft.graph.', ''
                userPrincipalName = $o.userPrincipalName; displayName = $o.displayName }
        }
    }
    Save-Csv 'groupes-membres' $membres
}

# --- Rôles d'annuaire (attributions actives) --------------------------------

Invoke-Export 'roles' {
    $definitions = @{}
    foreach ($d in Get-Graph "$v1/roleManagement/directory/roleDefinitions?`$select=id,displayName,isBuiltIn") {
        $definitions[$d.id] = $d
    }
    $attributions = Get-Graph "$v1/roleManagement/directory/roleAssignments?`$expand=principal"
    $lignes = foreach ($a in $attributions) {
        [pscustomobject]@{
            role              = $definitions[$a.roleDefinitionId].displayName
            integre           = $definitions[$a.roleDefinitionId].isBuiltIn
            portee            = $a.directoryScopeId
            principal         = $a.principal.displayName
            userPrincipalName = $a.principal.userPrincipalName
            type              = $a.principal.'@odata.type' -replace '#microsoft.graph.', ''
        }
    }
    Save-Csv 'roles-attributions' ($lignes | Sort-Object role, principal)
}

# --- Stratégies -----------------------------------------------------------------

Invoke-Export 'strategie-autorisation' {
    Save-Json 'strategie-autorisation' (Get-Graph "$v1/policies/authorizationPolicy")
}
Invoke-Export 'strategie-methodes-auth' {
    Save-Json 'strategie-methodes-auth' (Get-Graph "$v1/policies/authenticationMethodsPolicy")
}
Invoke-Export 'parametres-securite-defaut' {
    Save-Json 'parametres-securite-defaut' (Get-Graph "$v1/policies/identitySecurityDefaultsEnforcementPolicy")
}
Invoke-Export 'strategie-appareils' {
    Save-Json 'strategie-appareils' (Get-Graph "$v1/policies/deviceRegistrationPolicy")
}
Invoke-Export 'consentement-admin' {
    Save-Json 'consentement-admin' (Get-Graph "$v1/policies/adminConsentRequestPolicy")
}
Invoke-Export 'acces-inter-tenants' {
    Save-Json 'acces-inter-tenants' (Get-Graph "$v1/policies/crossTenantAccessPolicy/default")
}

# --- Applications de l'organisation ------------------------------------------

Invoke-Export 'applications' {
    $apps = Get-Graph "$v1/applications?`$select=id,appId,displayName,signInAudience,requiredResourceAccess,appRoles,web,identifierUris,keyCredentials"
    # Certificats : uniquement les métadonnées publiques (la clé privée ne quitte jamais la machine)
    $apps = foreach ($a in $apps) {
        $a | Select-Object appId, displayName, signInAudience, requiredResourceAccess, appRoles, web, identifierUris,
            @{n='certificats';e={ @($a.keyCredentials | Select-Object displayName, type, usage, endDateTime) }}
    }
    Save-Json 'applications' $apps

    $sps = foreach ($a in $apps) {
        $sp = @(Get-Graph "$v1/servicePrincipals?`$filter=appId eq '$($a.appId)'&`$select=id,displayName,appRoleAssignmentRequired,preferredSingleSignOnMode")[0]
        if (-not $sp) { continue }
        [pscustomobject]@{
            application               = $sp.displayName
            appRoleAssignmentRequired = $sp.appRoleAssignmentRequired
            preferredSingleSignOnMode = $sp.preferredSingleSignOnMode
            proprietaires = @(Get-Graph "$v1/servicePrincipals/$($sp.id)/owners?`$select=userPrincipalName").userPrincipalName
            affectations  = @(Get-Graph "$v1/servicePrincipals/$($sp.id)/appRoleAssignedTo") |
                            Select-Object principalDisplayName, principalType, appRoleId
        }
    }
    Save-Json 'applications-entreprise' $sps
}

# --- Bilan --------------------------------------------------------------------------

$resume = @(
    "Export du tenant : $($ctx.TenantId)"
    "Compte           : $($ctx.Account)"
    "Date             : $(Get-Date -Format 'dd/MM/yyyy HH:mm')"
    ''
    $bilan
    ''
    'Non exporté (à refaire à la main dans le nouveau tenant) :'
    '  - mots de passe et méthodes MFA inscrites (chaque utilisateur se réinscrit)'
    '  - jonction des appareils (NOR-PC001 à rejoindre au nouveau tenant)'
    '  - journaux de connexion et d''audit (non transférables)'
    '  - clés privées des certificats d''application (recréer et recharger les .cer)'
    '  - agent Cloud Sync (réinstaller et reconfigurer vers le nouveau tenant)'
    '  - liste des domaines autorisés pour les invitations B2B (relever dans le portail)'
)
$resume | Out-File -FilePath (Join-Path $cible 'resume.txt') -Encoding utf8
$resume | ForEach-Object { if ($_ -like 'ÉCHEC*') { Write-Host $_ -ForegroundColor Yellow } else { Write-Host $_ } }
Write-Host "`nDossier : $((Resolve-Path $cible).Path)" -ForegroundColor Cyan
Write-Host "Ce dossier contient des données réelles du tenant : ne pas le publier." -ForegroundColor Cyan
