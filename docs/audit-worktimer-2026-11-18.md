# Audit de WorkTimer 1.7.4 du 18 novembre 2026

Revue de la branche `feature/live-timer-hourly-rate-watch`. Les constats ci-dessous portent sur cette branche. La version installée par les utilisateurs de l’App Store peut être différente.

## Résultat des essais

Sur simulateur iPhone 18 Pro, les 251 résultats de la suite unitaire sont au vert. Les 21 parcours d’interface ont réussi en plusieurs lots. Le premier lancement global a été interrompu en cours de route. Les parcours manquants ont été relancés. L’application compilée contient le widget et l’app Watch. Les cinq onglets ont aussi été examinés sur les captures du simulateur en français avec une base vide.

**Blocage de mise à niveau reproduit.** Une base temporaire créée avec le schéma V1 du projet contenait une journée de 7 h et une note. À sa réouverture avec le plan de migration utilisé par WorkTimer, Core Data a levé l’exception `Duplicate version checksums across stages detected` et le processus s’est arrêté. Cela établit un blocage pour cette base V1. Le nombre d’utilisateurs possédant une base équivalente est inconnu. Avant diffusion, comparer les schémas effectivement livrés, retirer l’ambiguïté entre les étapes de migration et prouver qu’une base de chaque version s’ouvre avec ses entrées intactes, y compris après un deuxième démarrage. Voir WorkDaySchemaV1.swift, WorkDayMigrationPlan.swift et WorkTimerapp.swift.

**PDF mensuel reproduit.** Avec une entrée de 8 h en janvier et une de 6 h en février, le PDF de février généré par WorkTimer affiche « 14h00 » et deux jours en couverture, puis « 6h00 » et un jour sur la page de détail.

## Priorités avant publication

| Parcours | Comportement actuel | Correction et critère de réussite |
|---|---|---|
| PDF mensuel | La couverture affiche le titre du mois avec les heures, jours travaillés et primes de toute l’année. Le détail de la page suivante est, lui, filtré sur le mois. | Calculer les indicateurs de la couverture sur la période sélectionnée. Garder l’historique nécessaire au report des vacances. Avec 8 h en janvier et 6 h en février, le PDF de février doit afficher 6 h sur les deux pages. |
| Travail et demi-journée de vacances | Pour une journée prévue de 8 h, 4 h travaillées et une demi-journée de vacances donnent −4 h au compteur. Ce résultat a été reproduit avec la fonction de calcul du projet. | Créditer la moitié de la durée prévue pour ce jour si le congé couvre l’autre moitié. Vérifier aussi un vendredi prévu à 6 h, avec 3 h travaillées, ainsi que plusieurs plages de travail le même jour. |
| Modification du contrat | Fermer les réglages après un changement d’horaire déclenche un recalcul de tout l’historique. Le calcul au démarrage utilise également la configuration actuelle. Le salaire brut estimé des anciens mois utilise le taux horaire actuel. | Dater les changements d’horaire et de taux. Une modification prenant effet le 1er décembre doit conserver les soldes et estimations de novembre, y compris après redémarrage. Prévoir une correction rétroactive volontaire pour une erreur de saisie. |
| Apple Watch hors connexion | Départ et arrêt transmettent leur heure. Pause et reprise transmettent uniquement la commande. Si les deux arrivent plus tard, l’iPhone calcule la pause à partir de leurs heures de réception. | Envoyer l’heure de chaque appui et un identifiant de session et de commande. Tester une pause de 12 h à 13 h, une reconnexion à 16 h, une livraison en double et un ancien arrêt reçu après le début d’une nouvelle session. |
| Confirmation sur la montre | La saisie affiche « Enregistré ✓ » dès l’envoi, même si le message attend encore son transfert. L’iPhone peut aussi ignorer un doublon ou échouer à sauvegarder. | Afficher « En attente de l’iPhone », puis confirmer l’écriture ou signaler l’échec. Un même envoi rejoué doit conserver une seule entrée. |

Points d’entrée du code, dans le dossier WorkTimer sauf mention contraire. PDFExportView.swift, PDFService.swift et PDFService+Data.swift pour les rapports. WorkTimeCalculations.swift, WorkDay.swift, WorkTimeSettingsSection.swift, WorkTimerapp.swift et StatsView.swift pour les calculs. WorkTimerWatch/WatchLink.swift, WorkTimerWatch/WatchAddDayView.swift et PhoneWatchConnectivity.swift pour la montre.

## Cohérence entre les écrans

| Écran | Constat | Amélioration |
|---|---|---|
| iCloud | La date de « Dernière synchronisation » avance dès que la vérification du statut du compte retourne une réponse. Cet appel ne confirme aucun transfert de journée. | Afficher « Compte iCloud vérifié » pour cet événement. Réserver une confirmation de transfert aux événements d’import ou d’export effectivement observés. |
| Widget | En l’absence d’un premier instantané, la timeline utilise les valeurs de démonstration, dont 32 h 30 de travail. Ensuite, le rafraîchissement horaire relit les valeurs stockées, sans savoir à quelle semaine elles correspondent. | Afficher une invitation à ouvrir WorkTimer au premier lancement. Enregistrer la période de chaque instantané pour éviter de présenter le total du vendredi comme celui du lundi suivant. |
| Journées | Une erreur de lecture vide la liste et met les totaux à zéro. L’utilisateur peut croire que ses pointages ont disparu. | Conserver les dernières données lisibles, signaler l’échec et proposer « Réessayer ». |
| Diagnostic et graphiques | Deux plages de travail distinctes le même jour déclenchent un diagnostic de doublon. Le graphique « Répartition des journées » compte chaque plage comme une entrée distincte. | Vérifier les horaires avant de signaler un doublon. Préciser si le graphique mesure des saisies ou des jours et appliquer cette définition aux journées mixtes. |
| Rapports annuels | Les pieds de page supposent 13 pages et utilisent le numéro du mois pour la pagination. Les mois vides, la synthèse facultative et les tableaux longs changent le nombre de pages réel. | Numéroter les pages effectivement produites. Tester décembre seul, une année complète avec graphiques et un mois nécessitant une deuxième page de tableau. |
| WorkTimer Pro | En cas d’échec de restauration des achats, l’erreur est journalisée. Le bouton de restauration n’explique pas à l’utilisateur si la demande a échoué ou si aucun achat n’a été trouvé. | Afficher une progression puis le résultat et permettre une nouvelle tentative si nécessaire. |
| Anciennes formations | Le type formation est masqué à la création sur iPhone. Lors d’un recalcul, sa durée de référence reste à zéro, ce qui peut ramener les heures d’une formation historique à zéro. | Définir le traitement de ces anciennes entrées et les inclure dans un test de mise à niveau. |

Fichiers concernés pour ces constats. ModernCloudService.swift, ModernCloudStatusView.swift, WorkTimerWidget/WorkTimerWidget.swift, WidgetSnapshotService.swift, WorkDaysListView.swift, DiagnosticsView.swift, ChartsDataService.swift, PDFService.swift, PaywallView.swift et StoreManager.swift.

## Observations sur les cinq onglets

Sur la base vide, Journées place « Ajouter une journée » sous son message et Calendrier affiche la date sélectionnée. À l’inverse, l’accueil présente d’abord plusieurs compteurs à zéro lorsque le chrono est masqué. Statistiques conseille de saisir une journée, sans bouton dans le message. Reprendre le bouton de Journées à ces deux endroits raccourcirait le premier pointage. Dans Réglages, conserver la séparation entre horaires, affichage et abonnement. Ajouter un accès aux graphiques depuis Statistiques permettrait de les découvrir au moment où l’on consulte ses chiffres.

## Trois évolutions pour le chantier

1. **Une fiche hebdomadaire à partager.** Proposer la semaine dans le sélecteur d’export, avec plages travaillées, pauses, absences et total. La personne qui reçoit la fiche peut vérifier la semaine sans reconstituer les journées.
2. **Un chantier facultatif par plage.** Proposer les derniers chantiers en un appui, réutiliser le dernier si souhaité et autoriser une saisie vide. Une matinée à l’atelier et un après-midi en pose auraient chacun leur chantier, avec un seul objectif d’heures pour la journée.
3. **Un contrôle de semaine.** Montrer les jours planifiés sans saisie et les plages qui se chevauchent. Toucher une anomalie ouvrirait directement la date à corriger. Tenir compte des congés et des horaires personnalisés pour éviter les fausses alertes.

## Vérifications à renforcer

Le test d’interface PDF actuel peut réussir sans trouver le bouton d’export et sans générer de document. Vérifier le texte et le nombre de pages du PDF produit avec des données connues. Pour les achats, conserver les tests StoreKit locaux et vérifier le parcours de restauration avec TestFlight. Pour iCloud, créer, modifier puis supprimer une journée entre deux appareils avec une configuration qui active CloudKit. Pour la migration SwiftData, ouvrir une copie de base d’une ancienne version et comparer les dates, heures, absences et suppressions. Ces essais sur appareils et anciennes bases réelles restent à effectuer.

La configuration du projet demande iOS 27 pour l’iPhone. Si la compatibilité avec iOS 18 reste un objectif produit, elle demande une décision explicite et des essais avec cette version.
