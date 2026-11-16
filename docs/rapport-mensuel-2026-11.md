# Rapport mensuel identité — Nordelia (lab)

**Période analysée :** 10 au 16 novembre 2026 (fenêtre de 7 jours, limite de conservation des journaux en Entra ID Free)
**Tenant :** Nordelia (lab) — Entra ID Free, paramètres de sécurité par défaut activés
**Sources :** journaux de connexion, journaux d'audit, score d'identité sécurisée, inventaire MFA (Graph)

## Synthèse

Aucune compromission constatée. Le score d'identité sécurisée progresse de 68,42 % à **70,83 %**. Deux points demandent une action : une rafale de mots de passe invalides sur un compte utilisateur, et une couverture MFA encore faible (**22 %**). Les modifications sensibles de la période sont toutes tracées et attribuées à un administrateur identifié.

## Indicateurs clés

| Indicateur | Valeur | Tendance / commentaire |
|---|---|---|
| Score d'identité sécurisée | 70,83 % (17/24 points) | En hausse (68,42 % au départ) ; 4 recommandations sur 6 terminées |
| Couverture MFA (comptes avec méthode forte) | 22 % (8/36) | En hausse (18 % au départ), encore insuffisante |
| Échecs de connexion interactifs | environ 50 sur 7 jours | Majoritairement 50126 (mot de passe invalide) |
| Échecs sur les comptes d'urgence | 3 | À justifier : ces comptes ne doivent servir qu'en cas d'urgence |
| Administrateurs généraux | 4 | 4 conservés (risque accepté pour le compte créateur du tenant ; recommandation « rôles les moins privilégiés » restera Actif) |

## Échecs de connexion notables

| Constat | Code | Analyse |
|---|---|---|
| Rafale d'environ 30 échecs sur un compte utilisateur le 14/11, dont des tentatives avec un identifiant erroné | 50126 | Profil compatible avec un mot de passe deviné ; dans le lab, tests de connexion. À vérifier avec l'utilisateur |
| Sessions d'un compte refusées les 14 et 15/11 | 50133, 500344, 130503 | Liés à l'incident PRT du module 4 (révocation, passkey inconnue, TAP mal saisi) ; résolu le 16/11 |
| Utilisateur refusé sur l'application de paie | 50105 | Attendu : affectation requise sur l'application (contrôle du module 6) |
| Interruptions de confirmation | 399218, 50199 | Pas des échecs de sécurité |
| Permission Graph inexistante demandée par un script | 650053 | Erreur de script à corriger |

## Modifications auditées (exemple de traçabilité)

Création du groupe GRP-COM-PARTENAIRES le 16/11 par le compte d'administration (service Core Directory) : Add group (11:15:04), Add member to group (11:15:06), Add owner to group (11:17:31). Les ajouts de membres du 11/11 sont attribués à Microsoft Graph Command Line Tools (scripts PowerShell), ce qui distingue l'automatisation des actions manuelles.

## Actions recommandées

| Priorité | Action | Coût |
|---|---|---|
| Élevée | Vérifier la rafale 50126 (contacter l'utilisateur, contrôler le verrouillage intelligent, réinitialiser si doute) | Gratuit |
| Élevée | Campagne d'enregistrement MFA (Microsoft Authenticator) pour atteindre 100 % des comptes | Gratuit |
| Moyenne | Risque accepté : le compte créateur du tenant reste Administrateur général pour des raisons structurelles. Mesures compensatoires : MFA forte, usage réservé aux opérations structurelles, revue hebdomadaire de ses connexions. Comptes d'urgence testés le 16/11 | Gratuit |
| Moyenne | Revue hebdomadaire manuelle des connexions des comptes d'urgence, et export CSV hebdomadaire des journaux (conservation 7 jours) | Gratuit |
| Faible | Corriger la permission Graph demandée par le script (erreur 650053) | Gratuit |
| Faible | Marquer « identité managée » comme non applicable (pas d'abonnement Azure dans le lab) | Gratuit |
| Plus tard | Alertes automatiques et conservation longue via export vers Log Analytics, accès conditionnel, Identity Protection | Licence P1/P2 |
