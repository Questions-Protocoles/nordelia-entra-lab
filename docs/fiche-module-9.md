# Fiche Module 9 — Surveillance et rapports

## En bref

Analyse des journaux de connexion et d'audit d'Entra ID, lecture du score d'identité sécurisée, puis production d'un rapport mensuel d'une page. Module en lecture seule : aucun paramètre du tenant n'a été modifié, seulement l'affichage des colonnes.

## Contexte

La direction de Nordelia veut savoir chaque mois si les identités sont bien protégées : qui échoue à se connecter et pourquoi, qui a modifié quoi, et si la posture de sécurité progresse. En Entra ID Free, les journaux ne sont conservés que 7 jours et ne peuvent pas être envoyés vers Log Analytics : l'analyse est donc manuelle et hebdomadaire.

## Résultat avant / après

| Élément | Avant | Après |
|---|---|---|
| Connaissance des échecs de connexion | Aucune analyse | Codes d'erreur identifiés et expliqués, y compris 3 codes absents de la documentation |
| Traçabilité des modifications | Non vérifiée | Création d'un groupe retrouvée de bout en bout (qui, quoi, quand) |
| Score d'identité sécurisée | 68,42 % (étape 0) | 70,83 % (17/24) |
| Rapport de pilotage | Inexistant | Rapport mensuel d'une page ([rapport-mensuel-2026-11.md](rapport-mensuel-2026-11.md)) |

## Fonctionnement

- **Journaux de connexion** (Événements de connexion) : une ligne par tentative, avec état (Réussite, Défaillance, Interrompu), application, code d'erreur et raison. Quatre onglets : connexions utilisateur interactives, non interactives, du principal de service, d'identités managées.
- **Journaux d'audit** : une ligne par modification ou lecture de l'annuaire, avec service, catégorie, activité, cibles, propriétés modifiées et acteur (Initié par).
- **Score d'identité sécurisée** : pourcentage des points obtenus sur les recommandations de sécurité applicables ; recalculé toutes les 24 heures avec un jour de décalage.

## Procédure « revue hebdomadaire des identités »

1. Surveillance et intégrité > Journaux de connexion, onglet Connexions utilisateur (interactives), Plage de dates : Les 7 derniers jours.
2. Ajouter un filtre État = Défaillance. Gérer l'affichage > Colonnes : cocher Code d'erreur de connexion, décocher Adresse IP pour les captures. Enregistrer.
3. Regrouper les échecs par code. Pour un code inconnu, ouvrir la ligne : onglet Informations de base, champ Raison de la défaillance.
4. Repérer les signaux : rafales de 50126 sur un même compte, toute connexion des comptes d'urgence.
5. Journaux d'audit, 7 derniers jours : filtrer Service = Core Directory (écarte les lectures du service Self-service Group Management) et la Catégorie voulue. Ajouter la colonne Initié par (acteur).
6. Ouvrir une ligne pour la preuve : onglets Cible(s) et Propriétés modifiées.
7. Télécharger les journaux en CSV (conservation limitée à 7 jours) et relever le score d'identité sécurisée.

## Contrôles et preuves

| Contrôle | Résultat | Preuve |
|---|---|---|
| Échecs sur 7 jours, par code | Environ 50 échecs ; codes 50126, 50133, 50105, 500141, 650053, 50199, 500121, 50089, 399218, 130503, 500344 | Captures de la liste filtrée (IP masquée) |
| Codes non documentés | 399218 = confirmation de tenant requise ; 130503 = TAP incorrect ; 500344 = aucun compte pour la passkey utilisée | Captures du détail (Raison de la défaillance) |
| Traçabilité GRP-COM-PARTENAIRES | Add group, Add member, Add owner (16/11, compte d'administration) | Captures des journaux d'audit et du détail |
| Score d'identité sécurisée | 70,83 % ; 4 recommandations terminées, 2 actives | Capture de la page du score |

## Incidents et leçons

- **Filtre « Cible commence par » sans résultat** : il ne regarde que la première cible, compare l'identifiant de connexion (en minuscules) et est sensible à la casse. Pour « Add owner to group », la première cible est l'utilisateur, pas le groupe. Solution : filtrer par Service et Catégorie.
- **Libellés** : le portail en français diffère de la documentation (« Défaillance » au lieu de « Échec », « Gérer l'affichage » au lieu de « Colonnes »). Les captures font foi.
- **Bruit d'audit** : la plupart des lignes GroupManagement sont des lectures du portail, pas des modifications.

## Points d'attention

- Ne jamais publier une capture avec la colonne Adresse IP ou des adresses personnelles visibles.
- L'emplacement affiché est déduit de l'adresse IP : il est approximatif.
- Le total de points du score change quand Microsoft ajoute une recommandation : comparer aussi le nombre de recommandations terminées.

## Limites de la licence gratuite

- Conservation des journaux limitée à 7 jours ; pas d'export vers Log Analytics ni de classeurs (P1).
- Pas d'alertes automatiques sur les comptes d'urgence (nécessite Log Analytics ou Microsoft Sentinel).
- Connexions à risque et utilisateurs à risque (Identity Protection) : P2.

## Retour arrière

Aucun : module en lecture seule. Pour revenir à l'affichage d'origine, Gérer l'affichage > Colonnes et décocher les colonnes ajoutées, puis Réinitialiser les filtres.

## Compétences SC-300

- Analyser les journaux de connexion et résoudre les échecs d'authentification.
- Examiner les journaux d'audit pour attribuer une modification à un acteur.
- Interpréter le score d'identité sécurisée et prioriser les recommandations.
- Produire un rapport de surveillance pour la direction.
