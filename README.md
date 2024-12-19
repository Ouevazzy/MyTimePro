# MyTimePro

MyTimePro est une application iOS pour l'enregistrement et le suivi du temps de travail avec synchronisation CloudKit.

## Fonctionnalités

- Enregistrement du temps de travail quotidien
- Statistiques hebdomadaires, mensuelles et annuelles
- Synchronisation iCloud
- Sauvegarde et restauration automatique
- Support hors-ligne

## Configuration requise

- iOS 15.0 ou supérieur
- Compte iCloud actif
- Xcode 14.0 ou supérieur (pour le développement)

## Installation

1. Cloner le repository
2. Ouvrir `MyTimePro.xcodeproj` dans Xcode
3. Configurer les capabilities iCloud dans Xcode :
   - Sélectionner le projet MyTimePro
   - Aller dans Signing & Capabilities
   - Ajouter iCloud capability
   - Activer CloudKit
   - Ajouter le container : `iCloud.jordan-payez.MyTimePro`

## Architecture

### Structure des dossiers

```
MyTimePro/
├── Models/
│   ├── TimeRecord.swift
│   ├── Settings.swift
│   └── StatisticsPeriod.swift
├── Views/
│   ├── TimeRecordingView.swift
│   ├── StatisticsView.swift
│   └── SettingsView.swift
├── ViewModels/
│   ├── TimeRecordingViewModel.swift
│   └── StatisticsViewModel.swift
└── Managers/
    └── CloudKitManager.swift
```

### CloudKit

L'application utilise CloudKit pour :
- Synchroniser les paramètres utilisateur
- Sauvegarder les enregistrements de temps
- Restaurer les données lors de la réinstallation

## Tests

Le projet inclut des tests unitaires pour :
- Les modèles de données
- Les ViewModels
- L'intégration CloudKit

Pour exécuter les tests :
1. Ouvrir le projet dans Xcode
2. Cmd + U ou Product > Test

## Migration des données

Le service `DataMigrationService` gère la migration des données :
- Sauvegarde des données existantes
- Migration vers CloudKit
- Mise à jour du schéma de données

## Contribution

1. Fork le projet
2. Créer une branche pour la fonctionnalité
3. Commiter les changements
4. Pousser vers la branche
5. Créer une Pull Request

## Documentation

Pour plus d'informations sur l'implémentation :
- [Guide de développement](docs/DEVELOPMENT.md)
- [Guide de synchronisation CloudKit](docs/CLOUDKIT.md)
- [Guide de migration](docs/MIGRATION.md)

## License

Ce projet est sous licence MIT. Voir le fichier LICENSE pour plus de détails.
