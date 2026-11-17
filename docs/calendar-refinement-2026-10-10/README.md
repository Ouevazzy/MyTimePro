# Calendrier — 10 octobre 2026

Toucher une date la sélectionne et actualise un aperçu intégré en bas du calendrier. Cette interaction conserve la vue mensuelle. L’aperçu ne contient aucune action d’ouverture : il affiche la date, les types d’entrées, le total travaillé et le solde. Une date sans entrée affiche un message explicite.

Les vues Année, Mois et Jour sont accessibles par un sélecteur visible. Le bouton Aujourd’hui est placé à côté, avec une disposition verticale lorsque le texte est agrandi. Le menu de réglage conserve le choix d’une date, les numéros de semaine et les trois présentations des entrées.

La grille mensuelle utilise les abréviations localisées des jours, des symboles pour distinguer les types d’entrées et un compteur pour les entrées supplémentaires. Les totaux additionnent les valeurs existantes de toutes les entrées actives de la date. Le solde nul reste neutre. Les traductions française, anglaise et allemande ont été ajoutées.

Captures de l’application sur iPhone 18 Pro, simulateur iOS 27.0 :

- [Deux entrées et aperçu de leurs totaux](/Users/jordan/Documents/Xcode/WorkTimer/docs/calendar-refinement-2026-10-10/captures/calendar-multiple-entries.png)
- [Journée sans entrée](/Users/jordan/Documents/Xcode/WorkTimer/docs/calendar-refinement-2026-10-10/captures/calendar-empty.png)
- [Vue annuelle](/Users/jordan/Documents/Xcode/WorkTimer/docs/calendar-refinement-2026-10-10/captures/calendar-year.png)
- [Sélection d’une autre date sans ouverture](/Users/jordan/Documents/Xcode/WorkTimer/docs/calendar-refinement-2026-10-10/captures/calendar-date-selection.png)

Les aperçus Xcode utilisent un historique fictif en mémoire, comprenant une date avec deux plages de travail et une demi-journée de congé :

- [Aperçu avec plusieurs types d’entrées](/Users/jordan/Documents/Xcode/WorkTimer/docs/calendar-refinement-2026-10-10/captures/calendar-mixed-sample.png)
- [Mode sombre avec texte agrandi, AX 3](/Users/jordan/Documents/Xcode/WorkTimer/docs/calendar-refinement-2026-10-10/captures/calendar-dark-large-sample.png)

La compilation a réussi. Les quatre tests d’interface du calendrier ont passé : navigation, sélection conservant le mois et retour à Aujourd’hui, choix des trois vues, et aperçu de deux entrées après création puis changement de date. Les sept tests de grille et les trois tests de calcul/agrégation sans stockage ont aussi passé.

Les deux tests supplémentaires de stockage SwiftData passent aussi. Leur configuration en mémoire désactive maintenant explicitement CloudKit ; la configuration automatique produisait « No eligible connection available » sur ce simulateur. Le dernier passage comprend quatre tests d’interface et deux tests de stockage, tous réussis. [Résultats du passage final](/Users/jordan/Documents/Xcode/WorkTimer/docs/calendar-refinement-2026-10-10/test-results.txt).

Les captures utilisent uniquement les données en mémoire des tests. La sélection vérifie aussi son apparence et la date affichée dans l’aperçu. Les totaux, les actions d’ajout et les changements de vue ont été testés dans l’application. Les aperçus sombre et agrandi servent à vérifier la présentation ; ils ne constituent pas un audit complet VoiceOver ou une validation sur appareil physique.
