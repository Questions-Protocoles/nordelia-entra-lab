# Fiche de procédure : créer et contrôler les comptes et groupes des salariés

Nov 11, 2026

Les 20 salariés de Nordelia existent dans Entra ID avec des attributs homogènes et leur gestionnaire, répartis dans 5 groupes nommés selon la convention. Tout est vérifié par script contre une liste maîtresse : 180 contrôles d'attributs et 27 contrôles d'appartenance, 0 écart. Les groupes dynamiques et les licences (étape 2.6) attendent l'essai P2 du module 3.

## Contexte

| Élément | Valeur |
| --- | --- |
| Demande | « Créer les 20 comptes Nordelia avec leurs attributs, les ranger dans des groupes par service et leur attribuer une licence automatiquement. » |
| Tenant | Nordelia (lab), licence Microsoft Entra ID gratuite |
| Compte utilisé | admin.nordelia (Administrateur général) |
| Source de vérité | Liste maîtresse nordelia-users.csv : 20 salariés, 13 colonnes « Libellé du portail \[nom technique\] », séparateur point-virgule |
| Durée réelle | Environ 4 h, dépannage compris |

## Résultat

| Élément | Avant | Après |
| --- | --- | --- |
| Salariés Nordelia | 0 | 20 (6 services, Paris et Dakar, gestionnaire posé pour 19) |
| Groupes | 2, hors convention, dont 1 sans propriétaire | 5, tous nommés GRP-… et avec propriétaire |
| Scripts réutilisables | 0 | 3 (création, contrôle des comptes, groupes) |

## Méthodes de création comparées

| Étape | Méthode | Comptes | Quand l'utiliser | Limite constatée |
| --- | --- | --- | --- | --- |
| 2.1 | Portail, à la main | 2 | Arrivée isolée | Lent ; libellés du portail différents de la documentation |
| 2.2 | Portail, import CSV (modèle Microsoft) | 0 sur 8 | Vague d'arrivées sans script | Pas de colonne gestionnaire ni entreprise ; envoi refusé par le service (« erreur inattendue ») |
| 2.3 | Script PowerShell Microsoft Graph | 18 créés, 2 mis à jour | Volume, reproductibilité | Demande l'installation des modules et le bon scope |

## Groupes

| Groupe | Type | Propriétaire | Membres | Origine |
| --- | --- | --- | --- | --- |
| GRP-ALL-USERS | Sécurité, affecté | admin.nordelia | 20 salariés (par script) | Créé |
| GRP-FIN-PAIE | Sécurité, affecté | Julien Moreau | 3 (Finance) | Créé |
| GRP-CONS-USERS | Sécurité, affecté | Ousmane Cisse | 4 (Consultants) | Créé |
| GRP-IT-ADMIN-DOMAINES | Sécurité, affecté | admin.nordelia (ajouté) | 1 | Ex « Admin Domaines », conservé et mis aux normes |
| GRP-LIC-M365APPS | Microsoft 365, affecté | Compte propriétaire | 1 (test) | Ex « Word-Access\_Group », renommé |

## Scripts

| Script | Rôle | Scope Graph |
| --- | --- | --- |
| New-NordeliaUsers.ps1 | Crée ou met à jour les comptes depuis la liste maîtresse, pose les gestionnaires ; mode -Simulation ; mot de passe saisi masqué | User.ReadWrite.All |
| Test-NordeliaUsers.ps1 | Compare un export de l'annuaire à la liste maîtresse, 9 attributs par salarié | Aucun (lit 2 fichiers) |
| Set-NordeliaGroupMembers.ps1 | Remplit GRP-ALL-USERS et contrôle les membres des 3 groupes métier ; mode -Simulation | User.Read.All, GroupMember.ReadWrite.All |

Les trois scripts sont relançables sans créer de doublon. Ordre d'emploi : simulation, relecture, exécution, contrôle.

## Contrôles et preuves

| Contrôle | Méthode | Résultat |
| --- | --- | --- |
| Attributs des 20 comptes | Export Get-MgUser vers verification-2.4.csv, puis Test-NordeliaUsers.ps1 | 180 contrôles, 0 écart |
| Membres des groupes | Set-NordeliaGroupMembers.ps1 | 20/20, 3/3, 4/4, aucun manquant ni en trop |
| Restauration d'un compte supprimé (hugo.petit) | Utilisateurs supprimés > Restaurer, puis les deux contrôles | Attributs, gestionnaire et groupes revenus, 0 écart |

## Points d'attention

- **Les libellés du portail changent selon la version.** Poste = jobTitle, Département = department, Lieu du bureau = officeLocation, Gestionnaire = manager, Lieu d'utilisation = usageLocation. Les scripts et les règles utilisent le nom technique.
- **Le lieu d'utilisation est indispensable** pour attribuer une licence.
- **Un gestionnaire doit exister avant ses collaborateurs.** Le script pose donc les gestionnaires dans un second passage.
- **Le modèle CSV du portail utilise des virgules.** Excel en français l'affiche sur une seule colonne : l'ouvrir avec le Bloc-notes, ou via Données > À partir d'un fichier texte/CSV, sans réenregistrer.
- **Tester l'existence d'un compte avec -Filter, pas -UserId.** -UserId lève une erreur 404 quand le compte n'existe pas.
- **Format-Table tronque les colonnes dans un terminal étroit.** Pour une preuve, exporter en CSV.
- **Renommer un groupe ne change pas son ID** : droits et accès sont conservés. Un groupe Microsoft 365 renommé garde son ancienne adresse e-mail.
- **L'option « rôles Entra attribuables » ne se choisit qu'à la création d'un groupe.**
- **Un groupe de sécurité supprimé est perdu définitivement** ; un utilisateur ou un groupe Microsoft 365 reste restaurable 30 jours.
- **Le propriétaire d'un groupe métier est le responsable métier** (Julien Moreau pour la paie), pas l'informatique.

## Retour arrière

Supprimer les 20 comptes (restaurables 30 jours) et les 3 groupes créés ; renommer les 2 groupes existants avec leur ancien nom. Les scripts permettent de tout recréer à l'identique depuis la liste maîtresse.

## Compétences mobilisées (SC-300)

Créer, configurer et gérer des utilisateurs et des groupes ; automatiser des opérations en bloc avec le portail et PowerShell ; gérer le cycle de vie d'un compte (suppression, restauration) ; contrôler une configuration par script ; documenter un incident et son contournement.
