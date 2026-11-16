# Fiche Module 7 : invités et partenaires externes (partie gratuite)

**En bref :** le cabinet partenaire Atlas peut désormais être invité dans l'annuaire de Nordelia sous contrôle. Seuls les administrateurs invitent, et uniquement vers des domaines autorisés. L'invité arrive sans aucun accès et ne voit pas le portail d'administration. Ses accès passent par un groupe dont le métier est responsable. Les packages d'accès, revues d'accès et workflows d'arrivée/départ demandent l'essai P2 ou Governance : ils seront faits dans le nouveau tenant.

## Contexte

**Ticket :** « Le cabinet partenaire Atlas doit accéder à l'espace Commercial pendant 90 jours. Les accès Finance doivent être revus chaque trimestre. Les départs doivent couper les accès le jour même, sans action manuelle. »

Cette fiche couvre la première phrase, pour la partie faisable en licence gratuite (Entra ID Free).

## Résultat

| Point | Avant | Après |
| --- | --- | --- |
| Qui peut inviter | Non relevé (valeur d'origine du tenant) | Seuls les rôles d'administration spécifiques (dont Inviteur d'invités) |
| Domaines invitables | Tous | Uniquement gmail.com et hotmail.fr (domaines qui jouent les partenaires) |
| Inscription libre-service des invités | Non | Non |
| Départ libre des externes | Oui | Oui |
| Accès des invités à l'annuaire | Limité (défaut) | Limité (inchangé) |
| Partenaire Atlas | Absent | Invité « Contact Atlas (partenaire) », invitation acceptée |
| Groupe des partenaires | Absent | GRP-COM-PARTENAIRES, propriétaire Marc Dubois, 1 membre |

## Fonctionnement

1. Un administrateur invite l'adresse du partenaire. Entra crée un compte de type **Invité** dont le nom d'utilisateur contient `#EXT#`.
2. Le partenaire reçoit un e-mail et clique sur **Accepter l'invitation**. Il garde son propre compte : Nordelia ne gère pas son mot de passe. Pour une adresse Gmail, Entra envoie un **code à usage unique par e-mail**.
3. Il accepte les autorisations de Nordelia, puis arrive sur Mes applications, vide : un invité n'a accès à rien par défaut.
4. Les accès se donnent au **groupe** GRP-COM-PARTENAIRES, jamais à la personne. Fin de mission : on retire le membre, et tous ses accès tombent.

## Procédure : inviter un partenaire externe

1. Vérifier que le domaine du partenaire figure dans **External Identities > Paramètres de collaboration externe > Restrictions de collaboration**. Sinon, l'ajouter et enregistrer.
2. **Utilisateurs > Nouvel utilisateur > Inviter un utilisateur externe** : adresse, nom d'affichage « Prénom Nom (Société) », message expliquant l'objet de l'accès.
3. Onglet Propriétés : nom de la société et service « Partenaire externe ».
4. Ajouter l'invité au groupe partenaires du métier concerné (ici GRP-COM-PARTENAIRES), pas à des applications une par une.
5. Contrôler sur la fiche de l'invité : type Invité, état de l'invitation, puis « Accepté » après sa première connexion.
6. Fin de mission : retirer l'invité du groupe, puis supprimer son compte.

## Contrôles et preuves

| Contrôle | Résultat attendu | Résultat obtenu |
| --- | --- | --- |
| Réglages enregistrés | Bouton Enregistrer grisé, domaines listés | OK : gmail.com et hotmail.fr |
| Création de l'invité | Type Invité, invitation en attente | OK (16/11/2026 10:55) |
| Acceptation | Arrivée sur Mes applications, aucune application | OK : « Il n'existe aucune application à afficher » |
| Accès au portail d'administration | Refusé | OK : « Vous n'avez pas accès », code 401, privilèges insuffisants |
| Groupe | 1 membre invité, propriétaire métier | OK : Contact Atlas / Marc Dubois |

## Incidents et résolutions

| Incident | Cause | Résolution |
| --- | --- | --- |
| L'adresse hotmail.fr prévue ne pouvait pas jouer l'invité | C'est le compte qui a créé le tenant : il est déjà dans l'annuaire (#EXT#) et administrateur | Utiliser une autre adresse (Gmail) et ajouter gmail.com aux domaines autorisés |
| gmail.com semblait ajouté mais pas enregistré | Saisie pas encore validée par le portail (Enregistrer grisé pendant la saisie) | Sortir du champ, enregistrer, quitter puis revenir sur la page pour contrôler |
| AADSTS50011 en ouvrant le portail en invité | Point final copié dans l'adresse (entra.microsoft.com.) | Retaper l'adresse sans point, avec le domaine du tenant à la fin |

## Points d'attention

- Un invité qui n'a pas d'annuaire Microsoft (Gmail) doit utiliser une adresse qui précise le tenant, par exemple `entra.microsoft.com/<domaine du tenant>`.
- La liste des domaines autorisés ne s'applique qu'aux nouvelles invitations : les invités déjà présents ne sont pas retirés.
- Les paramètres d'accès entre clients (cross-tenant) sont aussi évalués à l'invitation : un refus peut venir de là.
- Le compte créateur du tenant (adresse personnelle en #EXT#) ne doit jamais servir à des tests d'utilisateur.

## Limites de la licence gratuite

| Besoin du ticket | Fonction | Licence |
| --- | --- | --- |
| Accès Atlas limité à 90 jours, demandé et approuvé | Gestion des droits d'accès (package d'accès) | P2 ou Governance |
| Revue trimestrielle des accès Finance | Revues d'accès | P2 ou Governance |
| Départ coupé le jour même sans action manuelle | Workflows de cycle de vie | Governance |
| Conditions d'utilisation à accepter | Conditions d'utilisation (accès conditionnel) | P1 |

En attendant : expiration suivie à la main (date de fin de mission notée), retrait de l'invité du groupe en fin de mission.

## Retour arrière

- Supprimer l'invité Contact Atlas et le groupe GRP-COM-PARTENAIRES.
- Paramètres de collaboration externe : remettre l'invitation à « membres et rôles d'administration » et « Autoriser l'envoi des invitations à tous les domaines ».

## Compétences SC-300

- Configurer les paramètres de collaboration externe (restrictions d'invitation, liste de domaines autorisés).
- Inviter des utilisateurs externes (B2B) et gérer leur cycle d'acceptation.
- Comprendre les droits par défaut des invités et l'authentification par code à usage unique par e-mail.
- Gérer l'accès des partenaires par groupe avec un propriétaire métier.
