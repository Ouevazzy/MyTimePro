# Refonte design Liquid Glass iOS 26 — WorkTimer

Date : 2026-06-11
Statut : validé par Jordan

## Objectif

Refondre le design de l'app avec le langage Liquid Glass natif iOS 26, de façon
systématique et cohérente sur tous les écrans. La structure de navigation
(5 onglets) est conservée ; c'est la cohérence visuelle et la profondeur qui
changent. Aucun changement de logique métier ni de modèle de données.

## Contexte

- Le socle existe déjà : constantes `DS`, `dsGlassSurface`, `GlassEffectContainer`
  via `dsGlassEffectGroup`, API `Tab` iOS 26 native dans `ContentView`.
- Problème actuel : adoption Liquid Glass partielle et incohérente. Certains
  écrans utilisent le verre natif, d'autres un matériau simulé
  (`.regularMaterial` + opacité), d'autres des fonds opaques.
- Cible : iOS 26 uniquement (l'app utilise déjà `glassEffect`,
  `scrollEdgeEffectStyle`, `.buttonStyle(.glass)`).

## 1. Fondations — DesignSystem.swift

Fait en premier, tout le reste s'appuie dessus.

- **Verre natif par défaut** : `dsGlassSurface` rend `glassEffect(.regular)`
  par défaut (aujourd'hui réservé à `nativeGlass: true`). Le fallback opaque
  `Color(.secondarySystemGroupedBackground)` reste pour
  `accessibilityReduceTransparency`.
- **Hiérarchie de profondeur en 3 couches** :
  1. Fond : dégradé subtil teinté par onglet (remplace le
     `Color(.systemGroupedBackground)` plat).
  2. Contenu : cartes en verre.
  3. Contrôles flottants : verre interactif (`.regular.interactive()`).
- **Nouvelles primitives** :
  - `dsGlassPill` — badges, segments, sélecteurs (année, mois).
  - Variante teintée du verre (`tint` sémantique : travail = bleu,
    congés = orange, maladie = rouge…) pour les cartes liées à un type de jour.
  - Style de bouton flottant en verre interactif (pour le « + » global).
- **Nettoyage** : suppression des `DS.Shadow` sur les surfaces en verre (le
  verre apporte sa propre profondeur). Les ombres restent uniquement pour les
  rares éléments opaques.
- **Typographie** : `.rounded` systématique pour les valeurs numériques,
  `DS.Font.statDisplay` pour les chiffres héro.

## 2. Accueil (HomeTabView)

- **Héro** : le solde d'heures supplémentaires en très gros
  (`statDisplay`, `.rounded`, `contentTransition(.numericText())`),
  couleur sémantique vert/rouge. C'est la donnée la plus consultée.
- Cartes Année / Mois / Semaine en verre, groupées dans un
  `GlassEffectContainer` pour l'effet de fusion entre surfaces proches.
- Carte Congés avec jauge de progression animée (`DS.Animation.progress`).
- `tabBarMinimizeBehavior(.onScrollDown)` sur le TabView.
- **Bouton flottant « + »** en verre interactif au-dessus de la tab bar :
  ouvre `AddEditWorkDayView` (formulaire existant, inchangé). Présent sur
  Accueil, Journées et Calendrier.

## 3. Écrans restants

- **Journées (WorkDaysListView)** : lignes en cartes verre, en-têtes de mois
  épinglés en verre, apparitions étagées, swipe actions conservées.
- **Calendrier (CalendarView)** : la grille devient le héros — cellules avec
  pastilles en verre teinté sémantique, sélection avec morphing
  (`matchedGeometryEffect`), fiche du jour en sheet verre avec detents.
- **Statistiques (StatsView)** : StatCards en verre groupé, sélecteur d'année
  en pill verre, chiffres animés.
- **Graphiques (ChartsView, Pro)** : fond teinté, Swift Charts avec dégradés
  et sélection interactive (scrub).
- **Réglages (SettingsView + sections)** : sections en cartes verre, icônes
  harmonisées sur les tailles `DS.IconSize`.
- **Paywall (PaywallView)** : déjà récent — simple alignement sur les
  nouvelles primitives verre, pas de redesign.

## 4. Mouvement & retours

- Morphing verre (`glassEffectID` dans un `GlassEffectContainer`) là où c'est
  naturel : bouton « + » → formulaire.
- Haptiques `sensoryFeedback` systématisées sur sélections et validations.
- Respect strict de `reduceMotion` et `reduceTransparency` (comportement
  actuel maintenu et étendu aux nouvelles primitives).

## 5. Méthode & garde-fous

- **Ordre d'implémentation** : DesignSystem → Accueil → Journées → Calendrier
  → Stats/Charts → Réglages/Paywall. Chaque étape : build OK, capture
  simulateur pour validation visuelle, tests existants au vert.
- Pas de changement de logique métier, de modèle SwiftData, ni de
  localisations (ou très peu — toute nouvelle chaîne est ajoutée en FR/EN/DE).
- Le bouton « + » réutilise `AddEditWorkDayView` tel quel.
- Les deep links (Siri, notifications) et la navigation par onglets restent
  fonctionnels à l'identique.

## Hors périmètre

- Restructuration de la navigation (fusion d'onglets).
- Nouveau contenu ou nouvelles fonctionnalités.
- Modifications du flux d'achat StoreKit.
