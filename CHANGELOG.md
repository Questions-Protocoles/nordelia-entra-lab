# Journal des changements

Résumé du journal tenu pendant le lab. Chaque changement y est noté avec sa date, l'action, la raison et la preuve.

## 16/11/2026

- **Module 4 (suite)** : PRT du poste NOR-PC001 renouvelé après la révocation des sessions, via un TAP à usage unique et `dsregcmd /refreshprt`.
- **Nettoyage** : TAP de test supprimé, inscription d'appareils réglée, intégration LinkedIn désactivée, compte de test supprimé.
- **Module 7 (partie gratuite)** : collaboration externe restreinte (invitations par les administrateurs, domaines autorisés), invitation et acceptation d'un partenaire, contrôle de ses droits (aucun accès par défaut, portail refusé), groupe GRP-COM-PARTENAIRES avec propriétaire métier.
- **Module 9 (partie gratuite)** : analyse des échecs de connexion sur 7 jours (dont 3 codes non documentés expliqués), traçabilité d'une modification dans les journaux d'audit, score d'identité sécurisée 70,83 %, rapport mensuel.
- **Moindres privilèges** : comptes d'urgence testés ; compte créateur du tenant conservé Administrateur général (risque accepté, mesures compensatoires documentées).
- **Export du tenant** : script `Export-NordeliaTenant.ps1` (lecture seule), 15 exports sur 15 réussis, en préparation d'une reconstruction dans un nouveau tenant pour les modules P1/P2.

## 15/11/2026

- **Module 4** : campagne d'inscription Authenticator, poste Windows 11 joint à Microsoft Entra avec TAP et Windows Hello, simulation de vol de poste (désactivation AD, révocation des sessions, désactivation de l'appareil).

## 14/11/2026

- **Module 4** : stratégie des méthodes d'authentification (passkey, Authenticator, TAP ; SMS et vocal désactivés), inventaire MFA par script.
- **Module 8** : Cloud Sync opérationnel, tests de cycle de vie (changement d'attribut, départ), incidents de quarantaine d'UPN et de mot de passe temporaire résolus.

## 13/11/2026

- **Module 8** : contrôleur de domaine Windows Server 2022, forêt `nordelia.local`, OU Paris et Dakar, 10 comptes AD, agent Cloud Sync.

## 12/11/2026

- **Module 6** : SSO SAML de l'application de paie (affectation requise), consentement des utilisateurs limité, application interne par certificat avec permission minimale, inventaire des applications.

## 11/11/2026

- **Module 1** : tenant renommé, contacts renseignés, restrictions des utilisateurs standard, vérification par Graph PowerShell.
- **Module 2** : 20 salariés créés et contrôlés (180 contrôles d'attributs, 0 écart), 5 groupes normalisés.

## 10/11/2026

- **Module 0** : deux comptes d'urgence, administrateur nominatif, MFA, paramètres de sécurité par défaut, score d'identité sécurisée initial 68,42 %.
