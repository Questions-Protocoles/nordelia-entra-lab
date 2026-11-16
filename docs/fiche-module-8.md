# Fiche de procédure : synchroniser un Active Directory local avec Entra ID (Cloud Sync)

13 et 14/11/2026

Un Active Directory local (forêt nordelia.local) a été monté sur un serveur Windows Server 2022, puis relié au tenant par Microsoft Entra Cloud Sync. Seules les OU Paris et Dakar sont synchronisées : 10 salariés y sont créés et arrivent dans Entra avec leur mot de passe AD (synchronisation du hachage). Les tests de cycle de vie sont concluants : un changement de poste et une désactivation faits dans l'AD se répercutent dans le cloud. Deux incidents réels ont été diagnostiqués et corrigés : une quarantaine d'UPN après suppression et recréation d'un compte, et un mot de passe temporaire non synchronisé. Réalisé en licence gratuite : le proxy d'application (P1) n'est pas couvert.

## Contexte

| Élément | Valeur |
| --- | --- |
| Demande | « Les salariés gérés dans l'AD local doivent se connecter aux services cloud avec le même identifiant et le même mot de passe. » |
| Tenant | Nordelia (lab), licence Microsoft Entra ID gratuite |
| Comptes utilisés | admin.nordelia (Administrateur général) côté cloud ; NORDELIA\\Administrateur côté AD |
| Serveur | NOR-DC01, Windows Server 2022 Standard Evaluation, VMware Workstation, réseau NAT 10.10.10.0/24, IP fixe 10.10.10.10 |
| Domaine | nordelia.local (NetBIOS NORDELIA), niveau fonctionnel Windows2016Domain |
| Durée réelle | Deux sessions (13 et 14/11/2026), incidents compris |

## Résultat

| Élément | Avant | Après |
| --- | --- | --- |
| Annuaire local | Aucun | Forêt nordelia.local, OU Nordelia > Paris, Dakar, Comptes de service |
| Comptes synchronisés | 0 | 10 (5 Paris, 5 Dakar) |
| Comptes dans le tenant | 25 | 35 |
| Authentification des salariés AD | Sans objet | Mot de passe AD, par synchronisation du hachage |
| Périmètre synchronisé | Sans objet | OU Paris et Dakar uniquement |
| Protection contre les suppressions | Sans objet | Arrêt au-delà de 5 suppressions |
| Infrastructure de synchronisation | Aucune | Agent léger sur le contrôleur de domaine, compte de service géré provAgentgMSA |

## Fonctionnement

L'agent installé sur NOR-DC01 lit l'annuaire avec le compte de service géré provAgentgMSA, dont AD change seul le mot de passe. Il ne reçoit aucune connexion entrante : il ouvre lui-même une connexion sortante vers le service Cloud Sync, qui écrit dans Entra ID. La configuration (étendue, mappage des attributs, seuil de suppression) est stockée dans le cloud. Les utilisateurs sont synchronisés toutes les 20 minutes (intervalle fixe), les hachages de mot de passe toutes les 5 minutes. Chaque compte est relié à son objet AD par un ID immuable, calculé à partir de l'identifiant unique de l'objet.

## Procédure 1 : préparer le contrôleur de domaine

1. **Machine virtuelle** : Windows Server 2022 Standard Evaluation (Expérience de bureau), 2 vCPU, disque 60 Go, réseau NAT. Créer la VM avec « J'installerai le système d'exploitation plus tard » pour éviter l'installation simplifiée de VMware.
2. **Réseau** : IP fixe 10.10.10.10/24, passerelle et DNS 10.10.10.2 (passerelle NAT de VMware ; .1 est la carte de l'hôte). Renommer en NOR-DC01, installer les mises à jour, prendre un instantané.
3. **Rôle et forêt** :

```powershell
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
Install-ADDSForest -DomainName "nordelia.local" -DomainNetbiosName "NORDELIA" -InstallDns
```

4. **DNS après promotion** : le DNS client passe à 127.0.0.1 et l'ancien DNS (10.10.10.2) devient redirecteur, ce qui garde l'accès à internet. Vérifier avec Get-ADDomain, Get-DnsClientServerAddress et Resolve-DnsName microsoft.com.
5. **Icône réseau « Pas d'accès à Internet »** après la promotion : relancer le service de connaissance des emplacements réseau et le passer en démarrage différé.

```powershell
Restart-Service NlaSvc -Force
sc.exe config NlaSvc start= delayed-auto
```

## Procédure 2 : préparer l'annuaire

1. **Suffixe UPN** : Domaines et approbations Active Directory > Propriétés > Suffixes UPN, ajouter nordelia.onmicrosoft.com. nordelia.local n'est pas routable : sans ce suffixe, les comptes recevraient dans Entra un identifiant différent de leur identifiant AD.
2. **Unités d'organisation** : Utilisateurs et ordinateurs Active Directory, OU Nordelia sous nordelia.local, puis Paris, Dakar et Comptes de service dans Nordelia, protégées contre la suppression accidentelle.
3. **Utilisateurs** : 10 nouvelles personnes, absentes du tenant. Camille Rousseau créée à la main, les 9 autres par scripts\\New-NordeliaADUsers.ps1 (idempotent, mode -Simulation, mot de passe demandé à l'exécution et jamais stocké, fichier en UTF-8 avec nomenclature). Le script crée les comptes avec -ChangePasswordAtLogon $false, condition pour que le mot de passe soit synchronisé.

## Procédure 3 : agent et configuration Cloud Sync

1. **Télécharger l'agent** depuis le contrôleur de domaine : Entra ID > Entra Connect > Synchronisation cloud > Agents > Télécharger l'agent local.
2. **Installer** : connexion Entra avec un administrateur, « Créer un gMSA » avec un compte administrateur du domaine (utilisé une seule fois), domaine nordelia.local connecté. Vérifier l'agent « actif » dans le portail et le compte provAgentgMSA dans l'AD.
3. **Nouvelle configuration** : Synchronisation AD vers Microsoft Entra ID, domaine nordelia.local, synchronisation du hachage de mot de passe cochée.
4. **Filtres d'étendue** : Synchroniser les unités d'organisation sélectionnées, OU=Paris,OU=Nordelia,DC=nordelia,DC=local et OU=Dakar,OU=Nordelia,DC=nordelia,DC=local.
5. **Propriétés** : Empêcher la suppression accidentelle activé, seuil abaissé de 500 à 5.
6. **Approvisionner à la demande** un seul compte avant d'activer, puis lire chaque étape : import, étendue, correspondance, action.
7. **Vérifier et activer** la configuration, puis suivre le premier cycle dans Présentation > État actuel du cycle et dans Approvisionnement de journaux.

## Contrôles et preuves

| Contrôle | Méthode | Résultat |
| --- | --- | --- |
| Agent opérationnel | Synchronisation cloud > Agents ; Get-ADServiceAccount | NOR-DC01.nordelia.local actif ; provAgentgMSA activé |
| Premier compte | Approvisionnement à la demande de Camille Rousseau | Create ; Synchronisation locale activée = Oui, ID immuable présent |
| Comptes système exclus | Approvisionnement à la demande de l'Administrateur | Delete ignoré (JoinNotFound) : aucun compte créé dans Entra |
| Synchronisation planifiée | État du cycle, liste des utilisateurs | USER 10 au premier cycle (35 secondes) ; 35 comptes, les 10 synchronisés à « Oui » |
| Mot de passe AD dans le cloud | Connexion de Seydou Kane puis de Camille Rousseau | Connexions réussies avec le mot de passe AD |
| Changement d'attribut | Poste de Lucas Fournier modifié dans l'AD | Update ; « Développeur senior » dans Entra |
| Départ d'un salarié | Antoine Mercier désactivé dans l'AD | Update ; état du compte Désactivé dans Entra |
| Restrictions du module 1 | Seydou Kane ouvre la liste des utilisateurs du portail | « Vous n'avez pas accès » |

## Incidents et résolutions

| Symptôme | Cause | Résolution |
| --- | --- | --- |
| « Windows ne trouve pas le Contrat de licence » à l'installation | Installation simplifiée de VMware (disquette autoinst.flp) incompatible avec l'ISO d'évaluation | Disquette retirée, installation manuelle |
| « Pas d'accès à Internet » sur le contrôleur de domaine | Le service NlaSvc teste le réseau avant que AD et DNS soient prêts | Redémarrage du service, démarrage différé |
| Script : « Attribut inattendu CmdletBinding » | En-tête altéré par le copier-coller | Bloc d'aide retiré de la copie sur le serveur |
| Script : « Impossible d'appeler une méthode dans une expression Null » | Sous-tableaux aplatis faute de virgules entre les lignes | Virgules ajoutées, structure testée (10 éléments) |
| Risque d'accents illisibles dans l'AD | Windows PowerShell 5.1 lit l'UTF-8 sans nomenclature comme de l'ANSI | Fichier enregistré en UTF-8 avec nomenclature |
| Camille Rousseau : UPN camille.rousseau5441@… | Compte supprimé puis recréé dans l'AD ; le nouveau a été créé dans Entra 4 secondes avant la suppression de l'ancien, conflit d'UPN, mise en quarantaine | Objet AD modifié (Description) puis approvisionnement à la demande : UPN rétabli |
| Camille Rousseau : « mot de passe incorrect » | pwdLastSet = 0 : mot de passe temporaire (« doit changer à la prochaine ouverture de session »), non synchronisé par défaut | Mot de passe réinitialisé dans l'AD sans cette case : connexion réussie |

## Points d'attention

- **Un UPN identique à celui d'un compte cloud fusionne les deux comptes** (soft match) : le compte cloud passe sous contrôle de l'AD. Les comptes de ce module sont de nouvelles personnes pour l'éviter.
- **Ne jamais supprimer et recréer un compte AD pour résoudre un problème de mot de passe.** Le nouvel objet a un nouvel ID immuable : Entra crée une autre identité et l'ancienne perd ses groupes, applications, licences et méthodes MFA.
- **Un mot de passe temporaire n'est pas synchronisé.** Avec « l'utilisateur doit changer le mot de passe », le compte ne peut pas se connecter au cloud tant qu'il n'a pas choisi son mot de passe dans l'AD (sauf fonction ForcePasswordChangeOnLogOn). Vérifier pwdLastSet en premier.
- **L'approvisionnement à la demande ne synchronise pas le mot de passe** : il ne part qu'avec le cycle planifié.
- **Un compte hors étendue apparaît comme un « Delete » ignoré** (JoinNotFound) dans les journaux, pas forcément comme « hors étendue ».
- **Après synchronisation, l'AD est la source** : nom, poste, service et état du compte ne se modifient plus dans Entra.
- **Pour un départ, désactiver plutôt que supprimer** : l'accès est coupé partout, et le compte reste disponible pour un audit ou un retour.
- **Le seuil de suppression accidentelle doit suivre la taille de l'annuaire** : le seuil par défaut de 500 ne protège rien sur 10 comptes.
- **La restriction du portail ne couvre pas Graph ni PowerShell** : elle ne remplace pas le moindre privilège.

## Limites en licence gratuite

Non couverts : proxy d'application pour publier une application interne (P1), écriture différée des mots de passe vers l'AD avec la réinitialisation en libre-service (P1), groupes dynamiques et attribution de licences par groupe (P1).

## Retour arrière

Désactiver puis supprimer la configuration nordelia.local ; désinstaller l'agent d'approvisionnement et supprimer provAgentgMSA. Les comptes déjà synchronisés restent dans Entra et ne redeviennent modifiables qu'après désactivation de la synchronisation d'annuaire du tenant (opération longue). Côté serveur : revenir à l'instantané « Avant AD DS ».

## Compétences mobilisées (SC-300)

Préparer un annuaire local pour l'identité hybride (suffixe UPN, unités d'organisation) ; installer et configurer Microsoft Entra Cloud Sync ; définir l'étendue et la protection contre les suppressions ; mettre en œuvre la synchronisation du hachage de mot de passe ; tester avec l'approvisionnement à la demande ; analyser les journaux d'approvisionnement ; diagnostiquer les conflits d'attributs et les échecs de synchronisation de mot de passe ; gérer le cycle de vie des comptes depuis l'AD.
