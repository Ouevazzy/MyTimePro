# Design — App revendeur Vinted/Leboncoin : marge nette + tableau fiscal FR

> Statut : validé (grandes lignes) — 2026-06-14
> Nom de travail : **Revendo** (provisoire, à arbitrer avant publication)
> Auteur : Jordan

## 1. Contexte & objectif business

Construire un **actif digital quasi-passif** : une app iOS de niche, locale (sans serveur),
distribuée et monétisée via l'App Store.

Contraintes du porteur :
- Budget de démarrage **< 500 €** (compte Apple Developer déjà payé).
- **5–10 h/semaine**, surtout en phase de setup.
- Priorité **« le plus passif possible »** : pas de backend, pas de support lourd, pas de pub payante au départ.
- Compétences : iOS/SwiftUI, déjà auteur de WorkTimer (moteur SwiftData + StoreKit + CloudKit réutilisable).

## 2. Niche & wedge défendable

**Cible** : les revendeurs particuliers/semi-pro français de seconde main (Vinted, Leboncoin).

Le marché des apps de suivi revendeur est saturé **mais uniquement côté anglo-saxon**
(Flip, FlipperHelper, Flippd, Resell Tracker — centrés eBay/Poshmark/Mercari, en anglais,
multi-plateformes). Vinted y est traité comme « une plateforme parmi 16 ».

**Faille exploitée** : aucune app iOS n'est pensée *française d'abord* pour deux douleurs
récurrentes :
1. Calculer la **marge nette réelle** sur Vinted/Leboncoin (frais plateforme, port, fournitures).
2. L'**angoisse fiscale** : seuils de déclaration **DAC7** (les plateformes transmettent au fisc
   au-delà de **2 000 € OU 30 ventes/an**) et seuil d'activité « achat-revente » (BIC).

Cette douleur fiscale est déjà monétisée en web (ex. VintedCRM) mais **pas sur iOS**.
Le wedge — **langue FR + frais FR exacts + tableau fiscal FR** — est difficile à copier pour
les acteurs anglo-saxons.

## 3. Périmètre MVP (v1)

### 3.1 Suivi d'articles (cœur calculateur)
- Saisie d'un article : prix d'achat, frais (port pris en charge, fournitures/emballage),
  plateforme (Vinted / Leboncoin / Autre), prix de vente.
- Calcul instantané : **marge nette (€) et marge (%)**.
- Statut article : *en stock* / *vendu* (avec date de vente).

### 3.2 Catalogue & historique
- Liste des articles (en stock vs vendus).
- Profit total agrégé par **mois** et par **année**.
- Indicateurs : nombre d'articles vendus, CA, marge moyenne.

### 3.3 Tableau de bord fiscal FR (le différenciateur)
- Compteurs glissants sur l'année civile : **nombre de ventes** et **CA cumulé**.
- Jauges vs **seuils DAC7** (2 000 € / 30 ventes) avec alerte visuelle à l'approche.
- Indicateur informatif sur le seuil « achat-revente » (activité commerciale).
- **Disclaimer obligatoire** : information générale, pas de conseil fiscal/comptable.

### 3.4 Technique
- **100 % local** : SwiftData, aucun compte, aucun serveur.
- Sync **CloudKit optionnelle** (réutilise l'implémentation de WorkTimer).
- **Export CSV** (réutilise `CSVService`).
- Localisation : **FR d'abord**, structure i18n prête pour EN/DE (réutilise le pattern WorkTimer).

### 3.5 Hors périmètre v1 (YAGNI)
- Cross-listing / import automatique depuis Vinted (pas d'API officielle → fragile, non passif).
- Multi-pays / multi-devises.
- OCR de tickets, scan de codes-barres, génération d'étiquettes.
- Déclaration fiscale automatisée (risque réglementaire).

## 4. Modèle de données (esquisse)

- `ResaleItem` : id, title, purchasePrice, suppliesCost, shippingCost, platform,
  salePrice?, purchaseDate, saleDate?, status (inStock/sold), notes.
- `Platform` (enum) : vinted, leboncoin, other — chacun porte sa **règle de frais** (configurable,
  versionnée en interne pour absorber un changement de barème sans casser les données).
- Agrégats calculés à la volée (pas de duplication d'état) : profit mensuel/annuel,
  compteurs DAC7. Cache léger possible côté UI (pattern `StatsCache` de WorkTimer si besoin).

## 5. Monétisation — Freemium

- **Gratuit** : suivi jusqu'à ~15 articles (assez pour ressentir la valeur).
- **Pro** débloque : articles illimités + tableau fiscal complet + export CSV.
- Prix : **abonnement 9,99 €/an** ET **achat unique « à vie » 19,99 €** (laisser le choix).
- Implémentation : réutilise `StoreManager` (StoreKit 2) + paywall de WorkTimer.
- Programme App Store Small Business (commission 15 %).

## 6. Go-to-market (passif, budget <500 €)

- **ASO FR** : titre + sous-titre + mots-clés sur requêtes à intention
  (« calcul marge vinted », « impôts vinted », « suivi ventes vinted », « revendeur seconde main »).
- **Landing page** statique simple (un domaine, hébergement gratuit type Pages).
- **Amorçage communautaire** *one-shot* : présence/partage dans 2-3 groupes FB / forums de
  revendeurs Vinted (effort ponctuel, pas récurrent).
- **Pas de pub payante** au lancement ; tester un petit budget Apple Search Ads seulement si
  l'ASO valide la demande.

## 7. Construction

- **Nouveau projet Xcode léger** (pas une branche de WorkTimer) pour garder l'actif isolé et
  potentiellement revendable.
- On **réimporte des composants éprouvés** de WorkTimer : stack SwiftData, `StoreManager`/paywall,
  `CSVService`, éléments du design system, pattern de localisation.
- Estimation : **4–6 semaines à 5–10 h/semaine** pour la v1 publiable.

## 8. Risques & parades

| Risque | Parade |
|---|---|
| Changement de barème de frais Vinted/Leboncoin | Règles de frais versionnées & éditables ; valeurs par défaut faciles à mettre à jour via update app. |
| Évolution des seuils DAC7 | Seuils stockés en constantes centralisées + disclaimer informatif ; mise à jour ponctuelle. |
| Risque réglementaire (conseil fiscal) | Positionnement « indicateur informatif » + disclaimer ; aucune déclaration automatisée. |
| Concurrent anglo qui se localise en FR | Avance sur l'ASO FR + profondeur fiscale FR ; itérer vite sur la v1. |
| Demande plus faible que prévu | MVP peu coûteux (réutilisation) ; pivot possible vers makers/locatif (mêmes briques). |

## 9. Roadmap

1. **v1** — FR, Vinted/Leboncoin, suivi + fiscal + freemium.
2. **v2** — multi-plateformes (eBay, Depop…) + autres pays/devises (la structure se duplique).
3. **v3** — palier d'abonnement enrichi (rappels, objectifs, rapports annuels).

## 10. Critères de succès

- v1 publiée sur l'App Store en ≤ 6 semaines d'effort.
- Premiers téléchargements organiques via ASO sans pub payante.
- Premier euro de conversion Pro (validation de la volonté de payer).
- Charge de maintenance < 2 h/mois en régime de croisière.
