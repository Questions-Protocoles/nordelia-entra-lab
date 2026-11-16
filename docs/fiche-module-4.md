# Fiche Module 4 : Authentification, MFA et sans mot de passe

**Lab Nordelia (tenant Nordelia (lab), licence Microsoft Entra ID Free), 14 et 15/11/2026.** Ce module régle la stratégie des méthodes d'authentification, pousse l'inscription à Microsoft Authenticator, fait arriver une salariée sans qu'elle connaisse jamais de mot de passe (TAP, jonction Microsoft Entra, Windows Hello), puis simule le vol de son poste. Il contient les deux livrables du module : « Inscription MFA d'un salarié » et « Compte compromis : réaction en 15 minutes ».

## Contexte

Ticket : « Plus aucun compte sans MFA. Les salariés doivent pouvoir réinitialiser seuls leur mot de passe. Un nouvel arrivant doit pouvoir s'inscrire sans mot de passe. »

La licence gratuite couvre la stratégie des méthodes, la campagne d'inscription, le Temporary Access Pass (TAP), la jonction d'appareils et la révocation de sessions. La réinitialisation en libre-service (SSPR) des utilisateurs, la liste personnalisée de mots de passe interdits et les rapports d'inscription demandent une licence P1.

## Résultat avant / après

| Élément | Avant | Après |
| --- | --- | --- |
| Comptes avec une méthode MFA | 6 sur 34 (18 %) | 8 sur 36 (22 %) |
| Clé d'accès (passkey, FIDO2) | Désactivée | Activée pour tous, libre-service, profil par défaut |
| Passe d'accès temporaire | Activé | Vérifié : 1 h par défaut, 8 h maximum, réutilisable, 8 caractères |
| Authenticator : nom de l'application et lieu dans la notification | Géré par Microsoft | Activé pour tous |
| Campagne d'inscription Authenticator | Non relevée | Activée, report 1 jour, comptes d'urgence exclus |
| SMS et appel vocal | Désactivés | Inchangés (aucun SMS, y compris pour les administrateurs) |
| Jonction d'appareils | MFA non exigée, 50 appareils, aucun administrateur local | MFA exigée, 10 appareils, Administrateur général administrateur local |
| Poste de travail | Aucun | NOR-PC001 (Windows 11) joint à Microsoft Entra, Windows Hello |

L'objectif de 100 % n'est pas atteint : les comptes qui ne se sont jamais connectés n'ont pas encore rencontré l'invite d'inscription (14 jours avec les paramètres de sécurité par défaut). Le script d'inventaire permet de suivre la progression.

## Fonctionnement

- **Stratégie des méthodes d'authentification** : elle décide quelles méthodes un utilisateur peut inscrire et utiliser. Elle remplace les anciennes stratégies MFA et SSPR.
- **Paramètres de sécurité par défaut** : ils exigent l'inscription à Authenticator (14 jours de délai) et la MFA quand le risque le justifie. Ils seront remplacés par l'accès conditionnel au module 5.
- **Campagne d'inscription** : après une connexion réussie, elle pousse vers Authenticator les comptes qui utilisent une méthode plus faible.
- **TAP** : code limité dans le temps, délivré par un administrateur ; il compte comme authentification forte et sert à amorcer un compte ou à inscrire une méthode sans mot de passe.
- **Windows Hello** : sur un poste joint, le code PIN déverrouille une clé stockée dans le TPM. Windows obtient un jeton d'actualisation principal (PRT) qui donne l'authentification unique (SSO) vers les services Microsoft.
- **Révocation de sessions** : elle fixe une date (StsRefreshTokenValidFrom) avant laquelle tous les jetons d'actualisation et le PRT sont refusés.

## Procédure 1 : inscription MFA d'un salarié (livrable)

1. Vérifier que le salarié est dans la cible de Microsoft Authenticator (Entra ID > Méthodes d'authentification > Stratégies).
2. Le salarié installe Microsoft Authenticator sur son téléphone (Android ou iOS à jour).
3. Il se connecte à myapps.microsoft.com. L'écran « Plus d'informations requises » s'affiche.
4. Dans Authenticator : + > Compte professionnel ou scolaire > Scanner un code QR, puis Suivant sur le PC.
5. Il valide la notification de test en tapant le nombre affiché (correspondance des nombres).
6. L'administrateur contrôle le résultat avec `scripts/Get-NordeliaMfaInventory.ps1` : colonne MFA = True.

Recommandations : deux méthodes par salarié (par exemple Windows Hello et Authenticator) ; ne jamais diffuser une capture du code QR.

## Procédure 2 : nouvel arrivant sans mot de passe

1. **Compte** : créer le compte dans l'AD (OU Paris ou Dakar), suffixe @nordelia.onmicrosoft.com, mot de passe aléatoire jamais communiqué, case « doit changer le mot de passe » décochée. Approvisionner à la demande.
2. **TAP** : Utilisateurs > le salarié > Méthodes d'authentification > Ajouter > Passe d'accès temporaire, durée 2 h. Le transmettre par un canal sûr.
3. **Poste** : à l'installation de Windows 11, « Configurer pour le travail ou l'école », saisir l'adresse puis le TAP. Le poste est joint à Microsoft Entra.
4. **Windows Hello** : créer le code PIN proposé à la fin de l'installation.
5. **Méthode de secours** : inscrire Authenticator à la première ouverture de Mes applications.
6. **Contrôle** : `dsregcmd /status` doit afficher AzureAdJoined YES, NgcSet YES et AzureAdPrt YES.

## Procédure 3 : compte compromis, réaction en 15 minutes (livrable)

Cas traité : le poste NOR-PC001 de Karine Mendy (compte synchronisé depuis l'AD) est volé.

| Temps | Action | Où | Preuve |
| --- | --- | --- | --- |
| T+0 | Désactiver le compte : `Disable-ADAccount -Identity karine.mendy` | Contrôleur de domaine |  |
| T+2 | Approvisionner à la demande (ne pas attendre le cycle de 20 minutes) | Synchronisation cloud | Export AccountEnabled = False |
| T+4 | Révoquer les sessions : bouton « Révoquer les sessions » ou `Revoke-MgUserSignInSession -UserId <UPN>` | Portail ou PC d'administration | Audit : Update StsRefreshTokenValidFrom Timestamp |
| T+6 | Désactiver l'appareil | Appareils > NOR-PC001 > Désactiver | Activé = Non |
| T+10 | Vérifier les journaux de connexion du compte | Utilisateurs > Journaux de connexion | Uniquement des échecs après la révocation |
| T+15 | Informer le responsable et consigner l'incident | Journal des changements |  |

Pour un compte cloud, la première action se fait directement dans le portail (Modifier les propriétés > Compte activé décoché). Pour un compte synchronisé, le portail refuse : on agit dans l'AD.

Ce que la réponse ne couvre pas :

- Un jeton d'accès déjà délivré reste valable jusqu'à son expiration (environ une heure).
- La session Windows du poste volé s'ouvre encore avec le code PIN grâce aux informations en cache, mais sans aucun accès cloud.
- Les données du disque ne sont protégées que par BitLocker ; le verrouillage ou l'effacement à distance demande Intune.

Remise en service : `Enable-ADAccount`, approvisionnement à la demande, réactivation de l'appareil (dans la réalité, un poste volé est supprimé, jamais réactivé), puis nouvelle authentification forte du salarié pour obtenir un nouveau PRT.

## Contrôles et preuves

| Contrôle | Résultat |
| --- | --- |
| État initial | Paramètres de sécurité par défaut activés ; inventaire 6 sur 34 |
| Stratégie des méthodes | Passkey, Authenticator, TAP, OATH logiciel, OTP par e-mail activés ; SMS et vocal désactivés |
| Campagne d'inscription | Camille Rousseau inscrit Authenticator ; inventaire 7 sur 35 |
| Jonction de NOR-PC001 | AzureAdJoined YES, DomainJoined NO |
| Windows Hello | NgcSet YES |
| SSO | AzureAdPrt YES, CloudTgt YES (avant la simulation) |
| Révocation | Audit 15/11/2026 19:50:30, Update StsRefreshTokenValidFrom Timestamp, Success |
| Poste volé | Renouvellement du PRT refusé : AADSTS50173 (grant révoqué) |
| Connexions après révocation | Uniquement des échecs (50126, 500344) |
| Mesure finale | 8 sur 36 (22 %), fichier inventaire-mfa-fin-m4.csv |

## Incidents et résolutions

| Incident | Cause | Résolution |
| --- | --- | --- |
| Rapports « Détails de l'inscription » et « Activité » refusés (401) | Licence Premium exigée | Script Graph Get-NordeliaMfaInventory.ps1 |
| Passkey impossible dans Authenticator | Téléphone sous Android 12 (Android 14 requis) | Scénario déplacé sur un poste Windows 11 avec Windows Hello |
| Première VM sous Windows 10 | Fin de support ; TAP inutilisable hors installation | Réinstallation en Windows 11 avec TPM virtuel |
| « Entrez le mot de passe » à l'installation | Premier TAP expiré (1 h) | Nouveau TAP de 2 h |
| « Le serveur DNS configuré est incorrect » | Avertissement netsh, DC injoignable à cet instant | DNS secondaire 10.10.10.2 ajouté |
| Connect-MgGraph introuvable | Commande lancée sur le contrôleur de domaine | Révocation depuis le portail ; Graph reste sur le PC d'administration |
| AADSTS900561 | Page de connexion rechargée | Nouvelle fenêtre InPrivate |
| PRT non renouvelé après remise en service | Le PRT en cache date d'avant la révocation | Résolu le 16/11 : nouvelle authentification de Karine via un TAP à usage unique (Paramètres > Comptes > Accès professionnel ou scolaire), puis dsregcmd /refreshprt. Nouveau PRT émis à 08:47:46 UTC, plus d'erreur de tentative. Le code PIN seul ne suffit pas : il prolonge l'ancien PRT, qui a été révoqué |

## Points d'attention

- Le profil de passkey par défaut accepte les passkeys synchronisées et ne vérifie pas l'attestation. En production : un profil pour les administrateurs limité aux passkeys liées à l'appareil, avec attestation.
- Les comptes d'urgence restent exclus de la campagne d'inscription.
- L'ouverture de session mise en cache est voulue (travail hors ligne) : elle explique pourquoi la révocation ne bloque pas le poste lui-même.
- Les captures de codes QR, de TAP et de codes PIN ne doivent jamais être publiées.

## Limites de la licence gratuite

- SSPR pour les utilisateurs et écriture différée des mots de passe vers l'AD : P1.
- Liste personnalisée de mots de passe interdits : P1.
- Rapports d'inscription et d'activité : Premium.
- Verrouillage et effacement à distance d'un poste : Intune.
- Règles d'accès fines (MFA selon l'application, les lieux ou le risque) : accès conditionnel, P1.

## Retour arrière

- Stratégie des méthodes : repasser Clé d'accès sur Non et les options Authenticator sur Géré par Microsoft.
- Campagne d'inscription : État sur Désactivé.
- Poste : restaurer l'instantané VMware « NOR-PC001 joint », ou supprimer l'appareil dans Entra puis la VM.
- Passkey de test sur le PC hôte, le cas échéant : Paramètres Windows > Comptes > Clés d'accès.

## Compétences SC-300 travaillées

Stratégie des méthodes d'authentification, Microsoft Authenticator et correspondance des nombres, passkeys et profils, Temporary Access Pass, campagne d'inscription, jonction Microsoft Entra et Windows Hello, PRT et SSO, révocation de sessions, lecture des journaux d'audit et de connexion, diagnostic avec dsregcmd.
