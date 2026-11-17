# Affichage WorkTimer — 10 octobre 2026

L'accueil présente le solde annuel, puis la semaine, le mois, les congés et le bilan annuel. Les cartes de contenu ont un fond opaque, sans bordure ni ombre ajoutée. Les boutons et la navigation conservent les styles natifs. Cette séparation suit les [recommandations Apple sur les matériaux](https://developer.apple.com/design/human-interface-guidelines/materials).

Les statistiques mettent les heures travaillées et le solde en tête, puis regroupent les autres indicateurs en lignes. Le résumé et les mois défilent ensemble. Les grands caractères utilisent une seule colonne et des lignes empilées. Les réglages regroupent plusieurs rubriques dans chaque section ; les nombres du profil apparaissent immédiatement. Le bouton d'ajout de l'accueil est placé dans la barre de navigation pour laisser les valeurs visibles.

Un solde nul est neutre. Les couleurs des soldes positifs et négatifs ont des variantes claires et sombres. Sur un fond blanc, les couleurs claires définies dans les assets ont des contrastes sRGB calculés de 5,36:1 et 6,52:1 ; cela ne constitue pas un audit de contraste de l'ensemble de l'application.

## Captures

Les captures de l'application utilisent une base vide en mémoire, en français, sur le simulateur iPhone 18 Pro sous iOS 27. Les aperçus avec données d'exemple utilisent également un conteneur en mémoire, distinct des données de l'application. Les fixtures sont limitées à DEBUG et aux aperçus.

- [Accueil, mode clair](captures/home-light-empty.png)
- [Journées, mode clair](captures/workdays-light-empty.png)
- [Calendrier, mode clair](captures/calendar-light-empty.png)
- [Statistiques, mode clair](captures/stats-light-empty.png)
- [Réglages, mode clair](captures/settings-light-empty.png)
- [Accueil sombre avec données d'exemple](captures/home-dark-sample.png)
- [Statistiques avec données d'exemple](captures/stats-light-sample.png)
- [Statistiques avec texte agrandi AX 3](captures/stats-large-sample.png)
- [Réglages sombres avec texte agrandi AX 3](captures/settings-dark-large.png)

## Vérification

La compilation de la version finale a réussi. Les quatre tests d'interface existants — navigation entre les onglets, accès aux réglages, statistiques et captures — ont réussi, sans échec ni test ignoré. [Résultats des tests](test-results.txt).

Les aperçus de la version finale se compilent et ont été inspectés. Le mode clair, le mode sombre, des données d'exemple et la taille de texte AX 3 sont couverts par les captures ci-dessus. Cela ne couvre pas tous les appareils, toutes les tailles de texte, ni un usage sur iPhone physique.
