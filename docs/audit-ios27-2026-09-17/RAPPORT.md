# WorkTimer — audit iOS 27 et améliorations proposées

Audit commencé le 17 septembre 2026, finalisé le 18 septembre 2026. Analyse du code présent sur ce Mac, y compris les modifications non commitées. Aucun fichier de l’application n’a été modifié pour cet audit.

## Conclusion

WorkTimer possède déjà une bonne base : SwiftUI natif, requêtes limitées aux périodes visibles, index SwiftData, calculs séparés de plusieurs vues, tests, StoreKit 2, App Intents et extension widget. Une réécriture complète apporterait peu. Les meilleurs investissements sont la cohérence des chiffres, l’actualisation des données, une interface plus centrée sur la journée en cours et des exports fiables.

Le SDK iOS **27.0 est déjà installé**, avec **Xcode 27.0, build 27A266a**. L’archive Release de l’app et du widget a réussi avec ce SDK. La cible minimale peut rester iOS 26 ; les nouvelles API spécifiques à iOS 27 devront avoir une disponibilité conditionnelle.

## Vérifications et documentation

- SDK utilisé : `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.0.sdk`.
- Archive Release de l’app et du widget : **réussie, non signée**. Elle vérifie la compilation Release, pas la distribution App Store ni une synchronisation iCloud réelle. Le journal est conservé ; le paquet d’archive temporaire du 17 septembre n’est plus présent après la reprise du 18 septembre.
- Tests : résultats définitifs consignés dans la section de validation en fin de rapport.
- Corpus : **33 documents officiels Apple**, comprenant les notes complètes iOS/iPadOS 27 et Xcode 27, les mises à jour des frameworks utilisés et les recommandations de design. [Index local](/Users/jordan/Documents/Xcode/WorkTimer/docs/audit-ios27-2026-09-17/apple/INDEX.md).
- Ce corpus n’est pas une copie exhaustive de toute la bibliothèque Apple : les références de chaque API, toutes les vidéos et tous les exemples ne sont pas téléchargés. Certaines pages de frameworks décrivent aussi iOS 26 et les versions antérieures ; elles ne constituent pas toutes des nouveautés iOS 27.
- [Environnement vérifié](/Users/jordan/Documents/Xcode/WorkTimer/docs/audit-ios27-2026-09-17/verification/environment.json), [journal de l’archive](/Users/jordan/Documents/Xcode/WorkTimer/docs/audit-ios27-2026-09-17/verification/archive.log), [journal des tests existants](/Users/jordan/Documents/Xcode/WorkTimer/docs/audit-ios27-2026-09-17/verification/tests.log).

## 1. Fiabilité et logique : les priorités

### A. Corriger la synthèse des PDF mensuels — priorité haute

La couverture reçoit tout l’historique et `calculateStats` ne filtre que l’année. Ainsi, un PDF de septembre peut afficher les heures d’août + septembre sur sa couverture, alors que les lignes détaillées concernent septembre uniquement.

**Proposition :** distinguer explicitement les données de la période exportée des données nécessaires au report des vacances. Faire partager la même définition de période à la couverture, au tableau et aux graphiques. Les indicateurs annuels de congés peuvent rester annuels, avec un libellé explicite.

La pagination annuelle utilise également un total fixe de 13 et un numéro dérivé du mois, alors que certains mois sont absents, qu’une page de synthèse peut s’ajouter et qu’un tableau peut déborder. Calculer le nombre réel de pages puis numéroter toutes les pages générées.

Preuves : [PDFService.swift](/Users/jordan/Documents/Xcode/WorkTimer/WorkTimer/PDFService.swift:83), [filtre annuel](/Users/jordan/Documents/Xcode/WorkTimer/WorkTimer/PDFService.swift:1149), [pagination](/Users/jordan/Documents/Xcode/WorkTimer/WorkTimer/PDFService.swift:110).

**Critère de validation :** avec 8 h en août et 9 h en septembre, le rapport de septembre affiche 9 h sur la couverture et dans le détail. Chaque pied de page correspond au nombre réel de pages.

### B. Donner une date d’effet aux horaires contractuels — priorité haute

À la fermeture de la section des horaires, une modification déclenche un recalcul de **tout l’historique**. Le lancement réconcilie aussi les soldes avec les réglages actuels. Ce comportement est explicite dans le code, mais risque de surprendre une personne qui change de contrat : une ancienne journée de 8 h peut acquérir un surplus après passage à 7 h par jour.

**Proposition produit :** enregistrer des périodes de contrat avec date d’effet, conserver la référence applicable à chaque journée et proposer séparément une correction rétroactive avec aperçu de son impact. Cette décision est plus importante qu’une nouvelle animation.

Preuves : [WorkTimeSettingsSection.swift](/Users/jordan/Documents/Xcode/WorkTimer/WorkTimer/WorkTimeSettingsSection.swift:103), [réconciliation au démarrage](/Users/jordan/Documents/Xcode/WorkTimer/WorkTimer/WorkTimerapp.swift:159).

**Critère de validation :** modifier les horaires à partir du 1er octobre ne change ni les soldes de septembre ni un rapport antérieur.

### C. Relier les vues à une actualisation commune — priorité haute

Les statistiques et graphiques chargent leurs résultats selon l’année et une révision locale ; le calendrier possède sa propre révision et conserve une fenêtre de données préchargée. Les mutations depuis un autre écran, Siri ou iCloud ne sont pas toutes reliées à ces révisions. Invalider `StatsCache` ne suffit pas à remplacer les valeurs déjà stockées dans les vues.

**Proposition :** un mécanisme commun de notification des mutations, après sauvegarde réussie, puis une observation des changements persistants. iOS 27 fournit précisément `ResultsObserver` et `HistoryObserver` ; leur disponibilité iOS 27 a aussi été vérifiée dans le SDK installé. Conserver un chemin compatible iOS 26. [Mises à jour SwiftData d’Apple](https://developer.apple.com/documentation/updates/swiftdata).

Preuves : [StatsView.swift](/Users/jordan/Documents/Xcode/WorkTimer/WorkTimer/StatsView.swift:150), [CalendarView.swift](/Users/jordan/Documents/Xcode/WorkTimer/WorkTimer/CalendarView.swift:399), [ChartsView.swift](/Users/jordan/Documents/Xcode/WorkTimer/WorkTimer/ChartsView.swift:110).

**À reproduire en intégration :** calendrier déjà chargé → ajouter une entrée dans Journées → revenir au même mois ; faire ensuite le même essai avec une création Siri et un ajout depuis un deuxième appareil. L’absence de raccordement est visible dans le code ; les scénarios iCloud n’ont pas été exécutés pendant cet audit.

### D. Définir le traitement des demi-journées et des compensations — priorité haute

Avec 4 h travaillées, une demi-journée de vacances et une cible de 8 h, le calcul courant déduit encore 8 h et produit **−4 h**. Si la demi-journée de congé doit couvrir l’autre moitié de l’obligation, le solde attendu est 0 h. C’est une règle métier à formaliser avant correction, en particulier avec des horaires différents selon le jour.

Autre incohérence : les barres mensuelles et hebdomadaires ne prennent que les entrées de travail, mais le résumé des graphiques additionne les soldes de tous les types. Avec +2 h de travail et −8 h de compensation, les barres donnent +2 h tandis que le résumé donne −6 h.

**Proposition :** un calcul commun du bilan journalier, distinguant heures réellement travaillées, obligation contractuelle, absences créditées et consommation de compensation. Réutiliser ces résultats dans l’accueil, les graphiques, les PDF, Siri et le widget.

Preuves : [WorkTimeCalculations.swift](/Users/jordan/Documents/Xcode/WorkTimer/WorkTimer/WorkTimeCalculations.swift:16), [ChartsDataService.swift](/Users/jordan/Documents/Xcode/WorkTimer/WorkTimer/ChartsDataService.swift:101).

### E. Rendre le widget fiable même sans ouverture de l’app — priorité haute

Sans instantané, `fromSharedDefaults()` renvoie un exemple de **32,5 h, +1 h 30 et 12,5 jours**. Le drapeau `isPlaceholder` n’est pas utilisé pour masquer ces valeurs dans les vues. Le widget installé peut donc présenter des chiffres de démonstration comme des données réelles.

Le widget vérifie l’existence de `updatedAt`, mais ne lit pas son âge. Il redonne `date: .now` à des chiffres anciens, et son rafraîchissement horaire relit seulement ces mêmes chiffres. Un changement de semaine sans réouverture de l’app peut laisser les heures de la semaine précédente sous « cette semaine ».

**Proposition :** un vrai état « Ouvre WorkTimer pour actualiser », un instantané daté avec bornes de période, le traitement des changements de semaine/année et un rafraîchissement ciblé uniquement quand les valeurs changent. Une demande WidgetKit ne garantit pas une mise à jour immédiate. [Guide Apple sur les actualisations](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date).

Preuves : [WorkTimerWidget.swift](/Users/jordan/Documents/Xcode/WorkTimer/WorkTimerWidget/WorkTimerWidget.swift:16), [WidgetSnapshotService.swift](/Users/jordan/Documents/Xcode/WorkTimer/WorkTimer/WidgetSnapshotService.swift:25).

### F. Distinguer disponibilité iCloud et synchronisation terminée — priorité moyenne

`lastSyncDate` est actualisée après une vérification de disponibilité du compte. L’interface l’appelle « Dernière synchronisation », ce qui ne prouve pas que les changements ont été envoyés ou reçus. `isCloudKitActive` dépend uniquement de Debug/Release, alors que l’initialisation peut se rabattre sur un stockage sans CloudKit.

**Proposition :** afficher « Compte iCloud disponible » et « Dernière vérification » tant qu’aucun événement de transfert ne confirme la synchronisation. Transmettre au service le mode réellement actif du conteneur. Prévoir un scénario Release de test sur deux appareils ; Debug désactive actuellement CloudKit.

Preuves : [ModernCloudService.swift](/Users/jordan/Documents/Xcode/WorkTimer/WorkTimer/ModernCloudService.swift:97), [libellé de l’interface](/Users/jordan/Documents/Xcode/WorkTimer/WorkTimer/ModernCloudStatusView.swift:185).

### G. Petites incohérences à traiter ensuite

| Sujet | Constat précis | Proposition |
| --- | --- | --- |
| Date d’un nouvel ajout | Dans Journées, l’ajout utilise toujours le premier jour du mois visible. | Aujourd’hui lorsque le mois courant est affiché ; une date visible et explicite pour les autres mois. |
| Nuit de travail | Le formulaire ramène début et fin à la même date et exige fin > début. | Autoriser explicitement « fin le lendemain », avec tests de changement d’heure et traitement cohérent de Siri. |
| Devise | La saisie du bonus suit la devise de la région, plusieurs bilans et PDF affichent CHF en dur. | Une devise définie dans l’app, partagée par saisie, affichage et export ; aucune conversion implicite. |
| Restauration des achats | L’erreur de restauration est seulement journalisée ; l’interface ne distingue pas absence d’achat et échec. | États en cours/réussi/aucun achat/échec avec message et nouvelle tentative. |
| Offre annuelle absente | L’offre annuelle est présélectionnée même si StoreKit ne la renvoie pas ; le bouton peut rester actif sans action. | Sélectionner une offre réellement chargée et conditionner le bouton à cette sélection. |
| Erreur de lecture | Plusieurs échecs de récupération deviennent une liste vide ou des zéros. | Différencier « aucune donnée », « chargement » et « lecture impossible », en conservant si possible le dernier résultat. |

Preuves : [date d’ajout](/Users/jordan/Documents/Xcode/WorkTimer/WorkTimer/WorkDaysListView.swift:95), [horaires](/Users/jordan/Documents/Xcode/WorkTimer/WorkTimer/AddEditWorkDayView.swift:63), [saisie de devise](/Users/jordan/Documents/Xcode/WorkTimer/WorkTimer/AddEditWorkDayView.swift:258), [StoreManager.swift](/Users/jordan/Documents/Xcode/WorkTimer/WorkTimer/StoreManager.swift:94), [PaywallView.swift](/Users/jordan/Documents/Xcode/WorkTimer/WorkTimer/PaywallView.swift:179), [lecture accueil](/Users/jordan/Documents/Xcode/WorkTimer/WorkTimer/HomeTabView.swift:210).

Deux anomalies latentes méritent aussi d’être consignées : `.training` reçoit 0 h, car sa durée de référence n’est jamais initialisée ; le type est actuellement masqué dans le formulaire principal. L’ancien export CSV annuel compte une demi-journée de vacances comme 1 ; sa vue `CSVExportView` n’a pas d’appel de navigation trouvé, hors aperçu. Ces défauts ne doivent donc pas être présentés comme touchant tous les parcours actuels. [Formation](/Users/jordan/Documents/Xcode/WorkTimer/WorkTimer/WorkDay.swift:71), [CSV annuel](/Users/jordan/Documents/Xcode/WorkTimer/WorkTimer/CSVService.swift:112).

## 2. Améliorations visuelles et ergonomiques

### Ce qui a été observé à l’écran

Cinq captures ont été obtenues sur le simulateur iPhone 18 Pro sous iOS 27 : [voir les écrans](/Users/jordan/Documents/Xcode/WorkTimer/docs/audit-ios27-2026-09-17/captures/INDEX.md). Elles correspondent à une base de test vide, en français, en mode clair et à la taille de texte standard. Les observations visuelles ne couvrent donc pas un historique rempli ni les autres tailles d’écran.

- **Accueil :** le solde annuel occupe la première place puis réapparaît dans les cartes. Dans cet état vide, la répétition des zéros prend la place d’une action de démarrage clairement expliquée. Mettre « Ajouter ma journée » ou « Commencer » en tête, puis le bilan.
- **Statistiques :** les six indicateurs et le message « Aucune donnée pour 2026 » sont présents ; ce message invite à ajouter des journées sans bouton direct. Reprendre le bouton d’ajout déjà bien visible dans l’état vide de Journées.
- **Journées :** le bouton « Ajouter une journée » rend l’état vide actionnable. Le titre, la recherche et les grandes commandes mensuelles consomment beaucoup de hauteur ; les compacter permettrait de montrer davantage d’entrées lorsque la liste est remplie.
- **Calendrier :** le bouton Aujourd’hui et les commandes de changement de vue méritent une vérification sur les jours situés en bas du défilement et avec de grandes polices. Ajouter un libellé explicite au changement de présentation aiderait à comprendre les modes disponibles.
- **Réglages :** les rubriques sont lisibles, mais chaque ligne possède une carte, une bordure, une ombre et une icône colorée. Des groupes de réglages plus sobres réduiraient leur poids visuel. Les textes secondaires très pâles doivent faire l’objet d’une mesure de contraste ; aucune conformité chiffrée n’est déduite de ces seules captures.

### Donner une fonction précise à chaque écran

| Écran | Évolution proposée | Bénéfice |
| --- | --- | --- |
| Accueil | Carte « Aujourd’hui » en premier : état de la journée, horaires et action principale. Puis bilan hebdomadaire, solde et vacances. Réduire la répétition du bilan annuel. | Répondre d’abord à « que dois-je faire maintenant ? ». |
| Statistiques | Rendre les graphiques accessibles ici, au lieu de les enfouir dans Réglages → Fonctionnalités. Conserver le contrôle Pro à l’entrée. | Mettre ensemble les chiffres et leur explication. |
| Calendrier | Conserver les vues année/mois/jour, leur donner des commandes nommées clairement ; afficher les détails du jour à côté du mois quand la largeur le permet. | Navigation plus explicite et meilleure utilisation de l’iPad/des fenêtres larges. |
| Journées | Afficher clairement la portée « Ce mois » de la recherche et proposer « Tout l’historique ». Regrouper les actions liées à une entrée. | Éviter qu’une recherche vide soit comprise comme une absence dans toutes les données. |
| Réglages | Réserver cet écran aux préférences ; rapprocher Exporter et Graphiques des écrans concernés. | Moins de détours pour les actions fréquentes. |

### Réduire le verre sur les cartes de contenu

`dsGlassSurface` applique le verre natif à de nombreuses cartes de statistiques. Apple recommande d’utiliser Liquid Glass pour les contrôles et la navigation, et les matériaux ordinaires pour le contenu. Je garderais les barres et commandes natives, avec des cartes de chiffres plus opaques et une couleur d’accent limitée. [Recommandations Apple sur les matériaux](https://developer.apple.com/design/human-interface-guidelines/materials).

La modification peut être progressive : ajouter une surface de contenu distincte au design system, puis l’appliquer à l’accueil, aux statistiques et aux réglages. Ne pas remplacer globalement tous les usages de `dsGlassSurface`, car certains sont des commandes interactives légitimes. [DesignSystem.swift](/Users/jordan/Documents/Xcode/WorkTimer/WorkTimer/DesignSystem.swift:176).

### Terminer l’accessibilité

L’app possède déjà des libellés, des zones de 44 points, des adaptations à la réduction de transparence et plusieurs adaptations à la réduction des animations. À conserver.

Les points à vérifier sont les six cartes de statistiques placées au-dessus de la liste sans défilement global, les sélecteurs segmentés à nombreux choix, les petits boutons de bonus, les libellés allemands plus longs et les tableaux de données. Prévoir un empilement vertical en très grande taille de texte, une lecture VoiceOver cohérente, et un signe ou un texte en plus de la couleur pour les soldes. Les tests actuels de labels ne constituent pas un véritable audit VoiceOver. [Guide Apple d’accessibilité](https://developer.apple.com/design/human-interface-guidelines/accessibility).

## 3. Fonctions utiles à ajouter

1. **Pointage dans l’app, puis widget et Activité en direct.** Les actions Siri d’arrivée/départ fournissent déjà une base. Une vraie session en cours, avec pause/reprise, doit d’abord être robuste aux arrêts de l’app et au passage à minuit. Ensuite seulement afficher la session sur l’écran verrouillé. ActivityKit existe avant iOS 27 : ce n’est pas une nouveauté exclusive à cette version.
2. **Modèles de journées et duplication.** « Horaire habituel », « Reprendre hier », sélection de plusieurs dates avec aperçu avant enregistrement. Gain quotidien plus évident qu’une couche d’IA générique.
3. **Contrôle des anomalies.** Proposer une liste des oublis de départ, plages qui se chevauchent et journées incomplètes. Un rappel doit tenir compte des congés et des entrées déjà saisies.
4. **Recherche globale et filtres enregistrés.** Rechercher une note ou un type sur tout l’historique, avec une période visible et des résultats paginés.
5. **Annuler et restaurer.** Permettre l’annulation après suppression ou modification groupée. Sur iOS 27, `UndoableIntent` est une piste pour les actions Siri ; une annulation dans l’app reste utile sur iOS 26. [Mises à jour App Intents](https://developer.apple.com/documentation/updates/appintents).

L’import de planning par texte ou image avec Foundation Models reste une option ultérieure : créer un brouillon à vérifier, avec calculs déterministes des heures. Le ROI immédiat paraît inférieur aux points ci-dessus ; aucune indexation des notes de travail ni transmission à un fournisseur externe n’est nécessaire pour les réaliser.

## 4. Performance : optimiser ce qui reste mesurable

**Déjà bien fait :** le calendrier précharge une fenêtre limitée et construit un dictionnaire par date ; la liste interroge le mois courant et temporise la recherche ; les statistiques agrègent une année ; plusieurs sous-vues sont équatables. Il ne faut pas supprimer ces optimisations sous prétexte de modernisation.

**Travaux ciblés :**

- **Démarrage :** `reconcileAllDailyOvertime` parcourt tout l’historique à chaque lancement. Après introduction des périodes contractuelles, transformer la réparation historique en migration versionnée, puis limiter les recalculs aux jours réellement touchés.
- **Cache :** séparer « les données ont changé » de « un résultat a été mis en cache ». Actuellement, écrire les statistiques annuelles et douze mois modifie aussi `lastUpdate`, observé par l’accueil. Un compteur de révision métier évitera des invalidations parasites ; SwiftUI peut regrouper des notifications, donc cela ne prouve pas treize recalculs à chaque fois.
- **Exports :** le PDF charge toute la base pour calculer le report des vacances. Charger la période du rapport et un ensemble minimal de congés historiques. Le `@ModelActor` est créé depuis la vue ; sa présence seule ne démontre pas que le travail coûteux s’exécute hors du thread principal. Vérifier l’exécution réelle avec Instruments avant de promettre un gain.
- **Widget :** éviter `reloadAllTimelines()` lorsque l’instantané est inchangé ; rafraîchir le widget concerné et respecter les budgets système.
- **Mesures :** comparer 1 000, 10 000 et 50 000 entrées sur un iPhone réel, en Release : lancement, ouverture du mois, changement d’année, export annuel, mémoire et blocages d’interface. Les jeux volumineux sont des scénarios de mesure proposés, pas des résultats obtenus ici.

Le test de lancement existant a mesuré **2,203 s en moyenne sur cinq exécutions**, dans le simulateur iPhone 18 Pro, en Debug et sous automatisation. Ce chiffre n’est ni le temps du premier écran mesuré sur un iPhone réel, ni une preuve d’un goulot précis. [Méthode Apple de diagnostic SwiftUI](https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance).

## 5. Ordre de réalisation recommandé

| Lot | Contenu | Taille relative | Condition de réussite |
| --- | --- | --- | --- |
| 1 — Fiabiliser | PDF, cohérence compensation, widget sans données, messages de lecture et de restauration | Petite à moyenne | Mêmes chiffres sur tous les supports ; aucune donnée fictive présentée comme réelle. |
| 2 — Stabiliser les règles | Contrats datés, absences partielles, nuits, moteur de bilan commun | Grande | Anciennes périodes stables ; cas métier validés avec des exemples chiffrés. |
| 3 — Actualiser | Révisions communes, observation SwiftData 27, contrôle iCloud sur deux appareils | Moyenne | Un changement apparaît dans tous les écrans sans geste de rafraîchissement. |
| 4 — Clarifier les écrans | Accueil « Aujourd’hui », graphiques dans Statistiques, surfaces sobres, grande typographie | Moyenne | Parcours courts, lisibilité sur petit écran et grandes tailles de texte. |
| 5 — Accélérer l’usage | Modèles, duplication, pointage, widget interactif et Activité en direct | Moyenne à grande | Moins d’actions pour enregistrer une journée, reprise fiable après interruption. |

Les tailles indiquent la complexité relative, pas des délais garantis. La migration des données et les règles de contrat dominent le risque du lot 2.

## Validation finale

### Compilation et tests

| Vérification | Résultat et portée |
| --- | --- |
| SDK et environnement | Xcode 27.0 et SDK iOS 27.0 effectivement présents ; compilation avec ce SDK. |
| Archive Release | `ARCHIVE SUCCEEDED` pour l’app et le widget, signature désactivée. Ce n’est pas une validation de publication. |
| Tests d’interface existants, 17 septembre | **17 réussis, 0 échec** dans le journal. L’exécution globale a ensuite été interrompue pendant les tests unitaires bloqués : elle ne doit pas être présentée comme un succès global. |
| Tests unitaires du projet inchangé | **8 tests ont planté** dans `MultipleEntriesPerDayTests` et `SiriShortcutsTests`. Les conteneurs en mémoire conservent la configuration CloudKit automatique ; le journal montre une tentative CloudKit sur `/dev/null`, puis `No eligible connection available`. |
| Expérience d’isolation, 18 septembre | Dans une **copie temporaire**, ajouter `cloudKitDatabase: .none` aux trois configurations de test concernées donne **233 tests réussis, 0 échec, 0 ignoré**, dont les cinq sondes d’audit. Le code de l’application est inchangé. |
| Captures, 18 septembre | Le test de capture a réussi et les cinq écrans principaux ont été inspectés. |

La réussite après isolation étaye le diagnostic d’un problème de configuration des tests, sans démontrer le bon fonctionnement d’iCloud réel. Le [correctif proposé pour les tests](/Users/jordan/Documents/Xcode/WorkTimer/docs/audit-ios27-2026-09-17/verification/test-isolation-experiment.patch) est conservé comme pièce de l’audit ; il n’a pas été appliqué aux fichiers du projet de travail. [Bilan structuré des 233 tests](/Users/jordan/Documents/Xcode/WorkTimer/docs/audit-ios27-2026-09-17/verification/isolation-summary.json), [journal complet de cette expérience](/Users/jordan/Documents/Xcode/WorkTimer/docs/audit-ios27-2026-09-17/verification/isolation-experiment.log), [journal des plantages initiaux](/Users/jordan/Documents/Xcode/WorkTimer/docs/audit-ios27-2026-09-17/verification/unit-signed.log).

Les cinq sondes **confirment le comportement actuel indésirable**, elles ne prouvent pas sa correction :

| Sonde | Sortie effectivement obtenue |
| --- | --- |
| PDF mensuel, 8 h en août et 9 h en septembre | La couverture du PDF de septembre contient **17,00 h**. |
| 4 h de travail + demi-journée de vacances, cible de 8 h | **−4 h**. La règle de crédit des absences reste à formaliser. |
| +2 h travaillées et −8 h de compensation | Barres mensuelles **+2 h**, résumé **−6 h**. |
| Type formation | Durée calculée **0 h** ; type masqué dans le formulaire principal. |
| Ancien export CSV annuel, une demi-journée de vacances | Total de vacances **1 jour** ; parcours non trouvé dans la navigation actuelle. |

[Code des sondes](/Users/jordan/Documents/Xcode/WorkTimer/docs/audit-ios27-2026-09-17/verification/AuditBehaviorProbes.swift). Une première exécution avait une erreur d’indice de colonne dans la sonde CSV elle-même ; elle a été corrigée avant l’exécution finale réussie. Les journaux intermédiaires sont conservés pour distinguer cette erreur de test des anomalies de l’application.

### Limites et suites nécessaires

Les tests d’interface existants comportent des branches conditionnelles selon la présence d’éléments : leur réussite ne garantit pas que chaque parcours métier a été exercé. Aucun achat StoreKit réel, transfert iCloud entre deux appareils, migration d’un historique utilisateur, audit VoiceOver complet, profilage Instruments sur iPhone réel ou validation des fenêtres iPad/iPhone Duo n’a été réalisé ici. Ces contrôles restent nécessaires avant publication.

Les 33 fichiers sources du corpus Apple ont été vérifiés par leur empreinte SHA-256 le 18 septembre. Le manifeste distingue les téléchargements aboutis des tentatives échouées. L’audit laisse les fichiers de l’application et les changements préexistants intacts ; ses ajouts se trouvent uniquement dans ce dossier de documentation.
