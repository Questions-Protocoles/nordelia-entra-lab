# Fiche de procédure : intégrer une application SaaS en SSO et une identité d'application

12/11/2026

L'outil de paie (simulé par le Microsoft Entra SAML Toolkit) est intégré en SSO SAML et réservé aux 3 salariés de la Finance ; un salarié hors Finance est refusé (AADSTS50105). Le consentement des utilisateurs est limité aux éditeurs vérifiés et aux permissions à faible risque, avec un circuit de demande à l'administrateur. Une application interne, Nordelia-Reporting-API, lit l'annuaire par certificat, sans secret, avec une seule permission ; toute écriture est refusée (403). Un inventaire des applications produit par script a révélé 3 écarts, tous corrigés. Réalisé en licence gratuite : l'identité managée (Function App Azure) est reportée faute d'abonnement Azure.

## Contexte

| Élément | Valeur |
| --- | --- |
| Demande | « La Finance veut se connecter à l'outil de paie SaaS sans nouveau mot de passe. Une application interne doit lire des données par API. » |
| Tenant | Nordelia (lab), licence Microsoft Entra ID gratuite |
| Compte utilisé | admin.nordelia (Administrateur général) |
| Applications | Nordelia-Paie (SAML Toolkit), application de galerie ; Nordelia-Reporting-API, inscription d'application |
| Durée réelle | Environ 5 h, enquêtes dans les journaux comprises |

## Résultat

| Élément | Avant | Après |
| --- | --- | --- |
| Applications de l'organisation | 0 | 2, chacune avec un propriétaire métier |
| Accès à l'outil de paie | Sans objet | 3 salariés Finance, affectation requise |
| Consentement des utilisateurs | « Laisser Microsoft gérer », clients de messagerie autorisés | Éditeurs vérifiés et 5 permissions à faible risque |
| Demandes de consentement administrateur | Désactivées | Activées, relecteur admin.nordelia, 30 jours |
| Microsoft Graph Command Line Tools | Droits délégués d'écriture consentis pour tous, ouvert à tous | Réservé à admin.nordelia (affectation requise) |
| Secrets clients | 0 | 0 (certificats uniquement) |

## Procédure 1 : SSO SAML pour une application de galerie

1. **Applications d'entreprise > Nouvelle application**, galerie « Microsoft Entra SAML Toolkit », nom selon la convention. Une application de galerie crée deux objets : l'inscription d'application (la définition) et le principal de service (son instance dans le tenant).
2. **Propriétés** : Affectation requise = Oui. Sans elle, tout salarié du tenant peut se connecter.
3. **Utilisateurs et groupes** : attribuer les salariés. En licence gratuite, l'attribution par groupe est impossible (P1 exigée) : attribution individuelle de Julien, Awa et Thomas.
4. **Propriétaires** : le responsable métier (Julien Moreau).
5. **Authentification unique > SAML** : URL de connexion, télécharger le certificat (brut), copier l'URL de connexion, l'identificateur Entra et l'URL de déconnexion.
6. **Côté éditeur** : créer la configuration SSO avec ces valeurs et le certificat ; il fournit son URL ACS (`…/SAML/Consume/22996`) et son URL de connexion (`…/SAML/Login/22996`).
7. **Retour dans Entra** : remplacer l'URL de réponse et l'URL de connexion par celles de l'éditeur. L'URL de réponse doit correspondre exactement, sinon AADSTS50011.

## Procédure 2 : identité d'application par certificat

1. Créer la paire de clés sur la machine qui exécutera l'application, clé **non exportable** :

```powershell
$cert = New-SelfSignedCertificate -Subject "CN=Nordelia-Reporting-API" -CertStoreLocation "Cert:\CurrentUser\My" -KeyExportPolicy NonExportable -KeySpec Signature -KeyLength 2048 -NotAfter (Get-Date).AddYears(1)
Export-Certificate -Cert $cert -FilePath "..\Nordelia-Reporting-API.cer"
```

2. **Inscriptions d'applications > Nouvelle inscription** : locataire unique, sans URI de redirection.
3. **Certificats et secrets** : charger le `.cer` (partie publique seulement). Aucun secret client.
4. **API autorisées** : retirer `User.Read` (déléguée, inutile), ajouter `User.Read.All` en **permission d'application**, accorder le consentement administrateur.
5. **Rôles d'application** : déclarer `Reporting.Lecteur` (utilisateurs/groupes), puis l'attribuer à Nicolas Roux dans l'application d'entreprise. On déclare dans l'inscription, on attribue dans l'application d'entreprise.
6. Connexion sans mot de passe :

```powershell
Connect-MgGraph -ClientId "<ID d'application>" -TenantId "<ID du tenant>" -CertificateThumbprint "<empreinte>"
```

## Consentement

| Réglage | Valeur |
| --- | --- |
| Consentement de l'utilisateur | Éditeurs vérifiés, autorisations sélectionnées |
| Classification « Faible » | openid, profile, email, offline\_access, User.Read |
| Demandes de consentement administrateur | Oui ; relecteur admin.nordelia ; notifications et rappels ; expiration 30 jours |

| Type de permission | Qui agit | Étendue | Qui consent |
| --- | --- | --- | --- |
| Déléguée | L'application au nom d'un utilisateur connecté | Limitée aux droits de l'utilisateur | L'utilisateur si faible risque, sinon un administrateur |
| Application | L'application seule | Tout le tenant | Toujours un administrateur |

## Inventaire des applications

Produit par `scripts\Get-NordeliaAppInventory.ps1` (lecture seule) dans `inventaire-applications.csv`. Périmètre : applications de l'organisation et toute application ayant reçu des droits délégués ou des permissions d'application sur Microsoft Graph.

| Application | Éditeur | Authentification | Propriétaire | Accès | Permissions | Expiration |
| --- | --- | --- | --- | --- | --- | --- |
| Nordelia-Paie (SAML Toolkit) | Nordelia (galerie) | SSO SAML | Julien Moreau | Julien, Awa, Thomas (msiam\_access) | Aucune | Certificat de signature : 11/11/2029 |
| Nordelia-Reporting-API | Nordelia | Certificat client | Nicolas Roux | Nicolas Roux (Reporting.Lecteur) | Graph User.Read.All (application) | Certificat : 12/11/2027 |
| Microsoft Graph Command Line Tools | Microsoft (éditeur vérifié) | Délégué | Aucun (application Microsoft) | admin.nordelia | Graph délégué, consenti pour tous | Sans objet |

Écarts trouvés au premier passage et corrigés :

- Nordelia-Reporting-API sans propriétaire : Nicolas Roux désigné.
- admin.nordelia attribué « Accès par défaut » à Nordelia-Reporting-API, effet du consentement donné depuis le portail : affectation supprimée.
- Microsoft Graph Command Line Tools : droits délégués d'écriture consentis pour tous les utilisateurs lors du premier Connect-MgGraph, application ouverte à tous : affectation requise, réservée à admin.nordelia.

## Contrôles et preuves

| Contrôle | Méthode | Résultat |
| --- | --- | --- |
| SSO d'un salarié autorisé | Julien via le bouton SSO du Toolkit, après déconnexion locale | Connecté sans mot de passe de l'outil ; « Réussite » dans le journal de connexion |
| Refus d'un salarié non autorisé | Léa (Commercial) via l'URL SP-initiated | AADSTS50105 ; ID de requête identique dans le journal de connexion |
| Connexion de l'application | Get-MgContext après Connect-MgGraph par certificat | AuthType AppOnly, aucun compte, scope User.Read.All |
| Lecture autorisée | Get-MgUser groupé par département | 20 salariés |
| Écriture interdite | Update-MgUser lea.girard | 403 Authorization\_RequestDenied |
| Traçabilité de la configuration | Journaux d'audit, ApplicationManagement | Création, certificat, permissions et consentement horodatés |
| Revue des applications | Get-NordeliaAppInventory.ps1, deux passages | 3 écarts, 0 après correction |

## Points d'attention

- **Deux portes de connexion dans une application.** Le formulaire de compte local de l'éditeur ne passe pas par Entra : un refus à cet endroit ne prouve rien. Tester par le bouton SSO ou Mes applications, puis confirmer dans le journal de connexion.
- **Le journal de connexion Entra est la preuve du SSO**, pas la page d'accueil de l'application, qui peut garder une session locale.
- **Le NameID est le UPN.** L'attribut mail est vide pour des salariés sans boîte aux lettres : la revendication emailaddress l'est aussi.
- **Un certificat SAML expiré coupe le SSO pour tout le monde.** La date d'expiration est suivie dans l'inventaire et l'alerte part à admin.nordelia.
- **Le filtre par défaut d'Applications d'entreprise masque des applications.** Retirer « Type d'application » pour un inventaire complet.
- **Le consentement à une permission d'application apparaît comme une « app role assignment »** dans les journaux d'audit.
- **Les connexions des applications ne sont pas dans l'onglet interactif.** L'onglet « Connexions du principal de service » était encore vide au moment de la vérification (délai d'ingestion probable), à revérifier sur 7 jours.
- **Microsoft crée parfois ses propres principaux de service** (acteur « Jit Provisioning ») quand une fonctionnalité est activée ; identifier l'acteur, la cible et l'éditeur avant de conclure à un incident.
- **Un outil de contrôle se vérifie aussi.** Le premier passage du script comptait le mot de passe de clé du certificat SAML comme un secret client et classait une application Microsoft parmi les tiers.
- **Cocher « Consentement au nom de votre organisation » au premier Connect-MgGraph** accorde les scopes à tous les utilisateurs. Préférer le consentement pour soi seul, ou restreindre l'outil aux administrateurs.

## Retour arrière

Supprimer les applications d'entreprise Nordelia-Paie et Nordelia-Reporting-API (restaurables 30 jours) et la configuration 22996 dans le Toolkit ; supprimer le certificat CN=Nordelia-Reporting-API du magasin Personnel ; remettre les paramètres de consentement à leur état initial (captures avant/après au journal) ; remettre « Affectation requise » à Non sur Microsoft Graph Command Line Tools.

## Compétences mobilisées (SC-300)

Intégrer une application de galerie en SSO SAML ; gérer l'accès aux applications d'entreprise ; configurer le consentement des utilisateurs et le flux de demande administrateur ; inscrire une application, gérer ses identifiants et ses permissions d'API ; déclarer et attribuer des rôles d'application ; analyser les journaux de connexion et d'audit ; revoir et assainir les applications du tenant par script.
