# Widget WorkTimer — Installation (5 min dans Xcode)

Le code du widget est prêt (`WorkTimerWidget.swift`). Il reste 4 étapes manuelles
qui ne peuvent se faire que dans Xcode :

## 1. Créer le target

File → New → Target… → **Widget Extension**
- Product Name : `WorkTimerWidget`
- Décocher "Include Live Activity" et "Include Configuration App Intent"
- Activate scheme : oui

## 2. Remplacer le code généré

Supprimer les fichiers Swift générés par Xcode dans le nouveau dossier du target,
puis ajouter `WorkTimerWidget.swift` (ce dossier) au target **WorkTimerWidget**
(clic droit → Add Files, ou glisser dans le navigateur avec Target Membership = widget uniquement).

## 3. App Group (partage des données)

Sur **les deux** targets (WorkTimer + WorkTimerWidget) :
Signing & Capabilities → + Capability → **App Groups** → créer :

```
group.jordan-payez.MyTimePro
```

⚠️ Doit correspondre exactement à `WidgetSnapshotService.appGroupID` (app)
et `appGroupID` (widget). Si tu choisis un autre identifiant, mets à jour les deux constantes.

## 4. Vérifier

1. Lancer l'app, ajouter/modifier une journée (ça déclenche `SiriSummaryCacheService.refresh`
   → publication vers le widget)
2. Ajouter le widget sur l'écran d'accueil
3. Les valeurs doivent apparaître ; sinon vérifier l'App Group des deux côtés

## Fonctionnement

- L'app publie un instantané (heures semaine, heures supp, solde congés) dans
  l'App Group à chaque modification de données, puis appelle
  `WidgetCenter.reloadAllTimelines()`
- Le widget lit ces valeurs — aucun accès SwiftData/CloudKit dans l'extension
  (léger, rapide, pas de risque de migration concurrente)
- Familles supportées : petit, moyen, cercle et rectangle d'écran verrouillé
