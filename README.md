# Nordelia — lab Microsoft Entra ID (SC-300)

Lab pratique d'administration des identités avec **Microsoft Entra ID**, mené sur un tenant de test pour une entreprise fictive, **Nordelia** (environ 20 salariés, sites de Paris et Dakar).

Chaque module part d'une demande métier (« ticket »), applique la configuration, la **vérifie par des preuves** (portail, journaux, scripts PowerShell Microsoft Graph) et se termine par une fiche de procédure réutilisable : contexte, avant/après, procédure, contrôles, incidents rencontrés, limites de licence, retour arrière.

> Tenant de lab en licence **Microsoft Entra ID Free**. Les fonctions qui demandent une licence P1/P2 sont signalées dans chaque fiche et seront traitées dans une seconde phase.

## Modules

| Module | Thème | État | Fiche |
|---|---|---|---|
| 0 | Sécurisation initiale : comptes d'urgence, administrateur nominatif, paramètres de sécurité par défaut | Terminé | — |
| 1 | Configuration de base du tenant, paramètres utilisateur, moindre privilège | Terminé | [fiche-module-1](docs/fiche-module-1.md) |
| 2 | Comptes et groupes : portail, import CSV, PowerShell Graph, contrôles automatisés | Terminé (groupes dynamiques : P1) | [fiche-module-2](docs/fiche-module-2.md) |
| 3 | Rôles et Privileged Identity Management | À venir (P2) | — |
| 4 | Authentification, MFA, sans mot de passe (TAP, Windows Hello), réponse à un compte compromis | Terminé (SSPR : P1) | [fiche-module-4](docs/fiche-module-4.md) |
| 5 | Accès conditionnel | À venir (P1) | — |
| 6 | Applications : SSO SAML, identité d'application par certificat, consentement, inventaire | Terminé | [fiche-module-6](docs/fiche-module-6.md) |
| 7 | Invités et partenaires externes (B2B) | Partie gratuite terminée | [fiche-module-7](docs/fiche-module-7.md) |
| 8 | Identité hybride : Active Directory local et Entra Cloud Sync | Terminé (proxy d'application : P1) | [fiche-module-8](docs/fiche-module-8.md) |
| 9 | Surveillance : journaux de connexion et d'audit, score d'identité sécurisée, rapport mensuel | Partie gratuite terminée | [fiche-module-9](docs/fiche-module-9.md), [rapport](docs/rapport-mensuel-2026-11.md) |

L'historique détaillé est dans [CHANGELOG.md](CHANGELOG.md).

## Scripts PowerShell (Microsoft Graph)

| Script | Rôle | Écriture ? |
|---|---|---|
| [New-NordeliaUsers.ps1](scripts/New-NordeliaUsers.ps1) | Crée ou met à jour les comptes cloud depuis la liste maîtresse, pose les gestionnaires. Mode `-Simulation` | Oui |
| [Test-NordeliaUsers.ps1](scripts/Test-NordeliaUsers.ps1) | Compare un export de l'annuaire à la liste maîtresse (9 attributs par salarié) | Non |
| [Set-NordeliaGroupMembers.ps1](scripts/Set-NordeliaGroupMembers.ps1) | Remplit le groupe de tous les salariés et contrôle les groupes métier. Mode `-Simulation` | Oui |
| [New-NordeliaADUsers.ps1](scripts/New-NordeliaADUsers.ps1) | Crée les comptes dans l'Active Directory local (module 8). Mode `-Simulation` | Oui (AD) |
| [Get-NordeliaMfaInventory.ps1](scripts/Get-NordeliaMfaInventory.ps1) | Inventaire des méthodes d'authentification et taux de couverture MFA | Non |
| [Get-NordeliaAppInventory.ps1](scripts/Get-NordeliaAppInventory.ps1) | Inventaire des applications : propriétaires, accès, permissions, expiration des certificats et secrets | Non |
| [Export-NordeliaTenant.ps1](scripts/Export-NordeliaTenant.ps1) | Export de la configuration du tenant (comptes, groupes, rôles, stratégies, applications) en CSV et JSON, pour la reconstruire dans un autre tenant | Non |

Principes communs : connexion déléguée avec les scopes minimaux, mots de passe **demandés à l'exécution** (jamais stockés), scripts relançables sans créer de doublon, mode simulation avant toute écriture.

### Utilisation

```powershell
# Prérequis (une fois)
Install-Module Microsoft.Graph -Scope CurrentUser

# Exemple : contrôle de la couverture MFA (lecture seule)
Connect-MgGraph -Scopes "User.Read.All","UserAuthenticationMethod.Read.All" -TenantId "<votre-tenant>.onmicrosoft.com"
.\scripts\Get-NordeliaMfaInventory.ps1
```

Les résultats sont écrits dans `output/`, qui n'est pas versionné.

## Structure

```
data/      Liste maîtresse des salariés fictifs (nordelia-users.csv)
docs/      Fiches de procédure par module et rapport mensuel
scripts/   Scripts PowerShell Microsoft Graph et Active Directory
output/    Résultats des scripts (ignoré par Git)
export/    Exports du tenant (créé par Export-NordeliaTenant.ps1, ignoré par Git)
```

## Confidentialité

Le dépôt est anonymisé : le domaine du tenant est remplacé par `nordelia.onmicrosoft.com`, les noms de comptes d'administration sont génériques, et aucun mot de passe, secret, certificat ni résultat d'inventaire réel n'est versionné. Les salariés de Nordelia sont fictifs.

## Compétences SC-300 travaillées

Gestion des utilisateurs, groupes et paramètres du tenant ; authentification forte et sans mot de passe ; identité hybride (Cloud Sync) ; intégration d'applications (SAML, OAuth, identités d'application) ; collaboration externe B2B ; surveillance (journaux, score d'identité sécurisée) ; automatisation avec Microsoft Graph PowerShell.
