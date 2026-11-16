# Fiche de procédure : configuration de base du tenant

Nov 11, 2026

Le tenant Nordelia (lab) est renommé, ses contacts sont renseignés et les utilisateurs standard ne peuvent plus créer d'applications, de groupes, d'identités d'agent ni de tenants. Ces restrictions sont vérifiées dans le portail avec un compte standard, puis prouvées en PowerShell.

## Contexte

| Élément | Valeur |
| --- | --- |
| Demande | « L'annuaire doit porter l'identité de Nordelia, et les salariés ne doivent ni créer d'applications, ni créer de tenants, ni ouvrir le portail d'administration. » |
| Tenant | Nordelia (lab), nordelia.onmicrosoft.com, licence Microsoft Entra ID gratuite |
| Rôle requis | Administrateur général (compte nominatif admin.nordelia) |
| Durée réelle | Environ 2 h, dépannage compris |

## Configuration appliquée

| Paramètre (emplacement) | Avant | Après | Raison |
| --- | --- | --- | --- |
| Nom du tenant (Entra ID > Vue d'ensemble > Propriétés) | Default Directory | Nordelia (lab) | Identité de l'organisation sur les écrans de connexion et les invitations |
| Contact technique et contact de confidentialité global (même page) | Vides | Renseignés | Interlocuteurs exigés en audit et par Microsoft |
| Les utilisateurs peuvent inscrire des applications (Utilisateurs > Paramètres utilisateur) | Non | Non (inchangé) | Aucune application créée sans contrôle |
| Users can register agent identity blueprints (même page) | Oui | Non | Cohérence avec l'interdiction d'inscrire des applications |
| Empêcher les non-administrateurs de créer des tenants (même page) | Oui | Oui (inchangé) | Pas d'annuaire « fantôme » hors gouvernance |
| Les utilisateurs peuvent créer des groupes de sécurité (même page) | Oui | Non | Les groupes portent des droits : leur création revient à l'informatique |
| Restreindre l'accès au Centre d'administration Microsoft Entra (même page) | Non | Oui | Un salarié n'a pas à parcourir l'annuaire et ses paramètres |
| Restrictions d'accès des invités (même page) | Accès limité | Accès limité (inchangé) | Valeur recommandée ; traité au module 7 |

## Contrôles et preuves

| Contrôle | Méthode | Résultat |
| --- | --- | --- |
| Nouveau nom visible | Accueil Entra et sélecteur de répertoire | Nordelia (lab), après quelques minutes de propagation |
| Portail d'administration refusé à un salarié | Compte test en navigation privée sur entra.microsoft.com | « Vous n'avez pas accès » (NavigationDisallowed) |
| Inscriptions d'applications refusées à un salarié | Compte test sur portal.azure.com > Inscriptions d'applications | « Vous n'avez pas accès » |
| Paramètres réellement appliqués côté annuaire | PowerShell Microsoft Graph, compte admin.nordelia | AllowedToCreateApps, AllowedToCreateSecurityGroups, AllowedToCreateTenants = False |

## Script de vérification

```powershell
# Prérequis (une fois) : Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
# Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Identity.DirectoryManagement, Microsoft.Graph.Identity.SignIns -Scope CurrentUser

# Connexion en lecture seule avec le compte d'administration nominatif
Connect-MgGraph -Scopes "Directory.Read.All","Policy.Read.All" -TenantId "nordelia.onmicrosoft.com"

# Qui suis-je, et dans quel tenant ?
Get-MgContext | Select-Object Account, TenantId
Get-MgOrganization | Select-Object DisplayName, Id

# Permissions par défaut des utilisateurs standard
(Get-MgPolicyAuthorizationPolicy).DefaultUserRolePermissions | Format-List

Disconnect-MgGraph
```

## Points d'attention

- **La restriction du centre d'administration n'est pas une frontière de sécurité.** Elle bloque la navigation dans les portails, pas PowerShell ni l'API Microsoft Graph. La vraie protection contre la création d'applications est AllowedToCreateApps = False, vérifiée par script.
- **Le test dans le portail ne suffit pas.** Comme la restriction du portail bloque l'accès avant le paramètre d'inscription, seul le contrôle PowerShell prouve ce dernier.
- **Une connexion Graph vaut pour une seule session PowerShell.** Ouvrir un second onglet de terminal exige de se reconnecter.
- **Le changement de nom du tenant n'est pas immédiat.** Compter quelques minutes, et se reconnecter si besoin.
- **AllowedToReadOtherUsers reste à True.** Teams et Outlook ont besoin que les salariés voient l'annuaire.

## Retour arrière

Remettre les valeurs de la colonne « Avant » dans Utilisateurs > Paramètres utilisateur, puis enregistrer. Aucun autre objet n'est à supprimer, sauf l'application Microsoft Graph Command Line Tools si PowerShell n'est plus utilisé.

## Compétences mobilisées (SC-300)

Configurer les propriétés du tenant et les paramètres utilisateur et groupe ; appliquer le moindre privilège ; vérifier une configuration avec Microsoft Graph PowerShell ; documenter un changement avec ses preuves.
