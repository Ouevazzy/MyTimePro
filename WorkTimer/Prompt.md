# 📱 PROMPT : Application de Gestion du Temps de Travail Multi-Pays

## 🎯 Objectif

Créer une application **iOS native** en **SwiftUI + SwiftData** pour la gestion du temps de travail, conforme aux droits du travail **suisse, français et belge**, avec synchronisation iCloud.

**Cible** : iOS 26 / iPadOS 26 uniquement (pas de Watch, widgets, etc.)

---

## 🚀 ONBOARDING (Premier lancement)

### Étape 1 : Sélection du pays
- 🇨🇭 Suisse
- 🇫🇷 France
- 🇧🇪 Belgique

### Étape 2 : Sélection de la région (optionnel)
- **Suisse** : Canton (info uniquement)
- **France** : Département/Région
- **Belgique** : Région (Wallonie/Flandre/Bruxelles) + Statut (Ouvrier/Employé)

### Étape 3 : Configuration initiale
- Heures par semaine
- Jours travaillés
- Congés annuels
- Date de début d'embauche
- Solde initial de vacances

---

## ⚙️ RÉGLAGES (Settings)

### 📋 Profil utilisateur
- Nom
- Entreprise

### ⏰ Horaires de travail

| Paramètre | Description | Défaut par pays |
|-----------|-------------|-----------------|
| **Heures par semaine** | Slider ou saisie (ex: 41.0h) | CH: 41-42h, FR: 35h, BE: 38h |
| **Jours travaillés** | Toggle par jour (Lun-Dim) | Lun-Ven par défaut |
| **Heures par jour** | *Calculé automatiquement* | `heures_semaine / nb_jours` |

**Affichage** : "41.0h / 5 jours = 8.20h/jour (8h12)"

### 🏖️ Gestion des congés

| Paramètre | Description |
|-----------|-------------|
| **Jours de congé annuels** | Nombre total (ex: 25 jours) |
| **Date de début d'embauche** | Point de départ du calcul |
| **Solde initial** | Jours disponibles à la date de début (ex: 6.73 jours) |

**Calcul automatique** :
- Report des jours non utilisés d'une année sur l'autre
- Affichage : Droits annuels + Report - Utilisés = Solde restant

### 🇫🇷 RTT (Affiché uniquement si pays = France)

| Paramètre | Description |
|-----------|-------------|
| **RTT activés** | Oui/Non |
| **Jours RTT annuels** | Nombre (ex: 12 jours) |
| **Solde RTT initial** | Si reprise en cours d'année |

### 🤒 Maladie

| Paramètre | 🇨🇭 Suisse | 🇫🇷 France | 🇧🇪 Belgique |
|-----------|-----------|-----------|-------------|
| **Jours de carence** | 0-3 (configurable) | 3 jours (fixe) | 1 jour ouvrier / 0 employé |
| **Impact carence** | Payé mais déduit des heures supp. | Non payé | Non payé (ouvrier) |

### 🎨 Affichage
- **Format heures** : `hh:mm` (défaut) ou `décimal` (8.50h)
- **Thème** : Clair / Sombre / Automatique
- **Devise** : CHF ou EUR (selon pays)

### ☁️ Synchronisation iCloud
- État de la synchronisation
- Dernière synchro
- Restaurer depuis iCloud

---

## 🎛️ AFFICHAGE CONDITIONNEL SELON LE PAYS

### Réglages visibles par pays

| Paramètre | 🇨🇭 Suisse | 🇫🇷 France | 🇧🇪 Belgique |
|-----------|:----------:|:----------:|:------------:|
| Heures/semaine | ✅ | ✅ | ✅ |
| Jours travaillés | ✅ | ✅ | ✅ |
| Congés annuels | ✅ | ✅ | ✅ |
| **RTT** | ❌ | ✅ | ❌ |
| Jours de carence | ✅ | ✅ | ✅ |
| **Statut ouvrier/employé** | ❌ | ❌ | ✅ |

### Types de journées visibles par pays

| Type | 🇨🇭 Suisse | 🇫🇷 France | 🇧🇪 Belgique |
|------|:----------:|:----------:|:------------:|
| Travail | ✅ | ✅ | ✅ |
| Congé | ✅ | ✅ | ✅ |
| Maladie | ✅ | ✅ | ✅ |
| Jour de carence | ✅ | ✅ | ✅ (ouvrier) |
| Journée compensatoire | ✅ | ✅ | ✅ |
| **RTT** | ❌ | ✅ | ❌ |
| Jour férié | ✅ | ✅ | ✅ |
| Formation | ✅ | ✅ | ✅ |
| **Service militaire** | ✅ | ❌ | ❌ |
| Congé maternité/paternité | ✅ | ✅ | ✅ |
| Congé spécial | ✅ | ✅ | ✅ |
| Congé sans solde | ✅ | ✅ | ✅ |
| **Crédit-temps** | ❌ | ❌ | ✅ |

### Dashboard - Sections visibles par pays

| Section | 🇨🇭 Suisse | 🇫🇷 France | 🇧🇪 Belgique |
|---------|:----------:|:----------:|:------------:|
| Heures année/mois/semaine | ✅ | ✅ | ✅ |
| Solde heures supp. | ✅ | ✅ | ✅ |
| Solde congés | ✅ | ✅ | ✅ |
| **Solde RTT** | ❌ | ✅ | ❌ |
| **Crédit-temps** | ❌ | ❌ | ✅ |

---

## 📝 AJOUT/MODIFICATION D'UNE ENTRÉE

### Structure de l'écran

```
┌─────────────────────────────────────────┐
│  ← Annuler    Nouvelle Journée   Enregistrer │
├─────────────────────────────────────────┤
│ DÉTAILS DE LA JOURNÉE                   │
│ ─────────────────────────────────────── │
│ 📅 Date de l'entrée     [10 déc. 2025]  │
│ 🏷️ Type de journée      [Travail    ▼]  │
│                                         │
│ ⏰ Heure de début        [07:00]        │
│ ⏰ Heure de fin          [17:00]        │
│ ☕ Temps de pause        [01:00]        │
├─────────────────────────────────────────┤
│ BONUS                                   │
│ ─────────────────────────────────────── │
│ 💰 Montant    [CHF 0.00]  +10 +18 +25   │
├─────────────────────────────────────────┤
│ NOTE                                    │
│ ─────────────────────────────────────── │
│ 📝 [Chantier Schöni - pose fenêtres]    │
├─────────────────────────────────────────┤
│ RÉSUMÉ                                  │
│ ─────────────────────────────────────── │
│ 🕐 Durée totale          9h00           │
│ ⚡ Heures supp.          +0h48          │
└─────────────────────────────────────────┘
```

### Types de journées

| Type | Icône | Impact heures supp. | Impact congés | Pays |
|------|-------|---------------------|---------------|------|
| **Travail** | 💼 | Calcul réel | - | Tous |
| **Congé** | ☀️ | Aucun | -1 jour | Tous |
| **Demi-journée congé** | 🌤️ | Aucun | -0.5 jour | Tous |
| **Maladie** | 🏥 | Aucun (payé) | - | Tous |
| **Jour de carence** | 🤒 | -1 journée standard (payé mais déduit) | - | Tous |
| **Journée compensatoire** | 🔄 | -1 journée standard | - | Tous |
| **RTT** | 🕐 | Aucun | -1 jour RTT | 🇫🇷 uniquement |
| **Jour férié** | ⭐ | Aucun (ajouté manuellement) | - | Tous |
| **Formation payée** | 📚 | = 1 journée standard | - | Tous |
| **Formation non payée** | 📖 | Aucun | - | Tous |
| **Service militaire** | 🎖️ | Aucun | - | 🇨🇭 uniquement |
| **Congé maternité** | 👶 | Aucun | - | Tous |
| **Congé paternité** | 👨‍👶 | Aucun | - | Tous |
| **Congé spécial** | 🎁 | Aucun | Selon type | Tous |
| **Congé sans solde** | ⏸️ | Aucun | - | Tous |
| **Crédit-temps** | ⏳ | Selon config | - | 🇧🇪 uniquement |

### Sous-types pour congés spéciaux

| Événement | 🇨🇭 | 🇫🇷 | 🇧🇪 |
|-----------|-----|-----|-----|
| Mariage employé | 2-3j | 4j | 2j |
| Naissance enfant | 1j | 3j | 10j |
| Décès conjoint | 3j | 3j | 10j |
| Décès parent | 3j | 3j | 3j |
| Déménagement | 1j | - | 1j |

### Champs conditionnels

- **Si type = Travail** : Afficher heures début/fin, pause, bonus
- **Si type = Congé spécial** : Afficher sous-type (mariage, décès, etc.)
- **Si type = Maladie** : Option "Jour de carence" (selon config pays)
- **Si type = Formation** : Option "Payée / Non payée"

### Calcul automatique du résumé

```swift
// Durée totale
duréeTotale = heureFin - heureDebut - pause

// Heures supplémentaires
heuresStandard = settings.standardDailyHours // ex: 8.20h
heuresSupp = duréeTotale - heuresStandard

// Affichage
si heuresSupp > 0 : "+0h48" (vert)
si heuresSupp < 0 : "-0h12" (rouge)
si heuresSupp = 0 : "0h00" (gris)
```

---

## 🏠 ACCUEIL (Dashboard)

### Statistiques par période

```
┌─────────────────────────────────────────┐
│ 📅 ANNÉE 2025                           │
│   Heures travaillées: 1'642h30          │
│   Heures supp.: -21h37                  │
├─────────────────────────────────────────┤
│ 📆 MOIS EN COURS                        │
│   Heures travaillées: 152h00            │
│   Heures supp.: -7h25                   │
│   Heures restantes: 12h00               │
├─────────────────────────────────────────┤
│ 📋 CETTE SEMAINE                        │
│   Heures travaillées: 36h30             │
│   Heures supp.: -4h30                   │
│   Heures restantes: 4h30                │
├─────────────────────────────────────────┤
│ 🏖️ CONGÉS 2025                          │
│   Report: 6.7 + Annuel: 25 = 31.7       │
│   Utilisés: 15.5                        │
│   ━━━━━━━━━━━━━━░░░░░░ 16.2 restants    │
├─────────────────────────────────────────┤
│ 🕐 RTT 2025 (🇫🇷 uniquement)             │
│   Total: 12 | Utilisés: 8 | Reste: 4    │
├─────────────────────────────────────────┤
│ ⏳ CRÉDIT-TEMPS (🇧🇪 uniquement)         │
│   Solde: 2 mois                         │
└─────────────────────────────────────────┘
```

---

## 📊 STATISTIQUES DÉTAILLÉES

### Vue annuelle
- Grille avec les 12 mois
- Pour chaque mois : jours travaillés, heures, heures supp.
- Total annuel

### Vue mensuelle
- Liste des jours avec détail
- Graphique heures par jour (optionnel)
- Répartition par type de journée

---

## 📅 CALENDRIER

### Vue mensuelle
- Codes couleur par type de journée
- Indicateur heures supp. (+/-) par jour
- Jours fériés ajoutés manuellement comme les autres entrées

### Actions
- Tap : voir détail
- Long press : modifier

---

## 📤 EXPORT

### Formats disponibles
- **PDF** : Rapport mensuel ou annuel (logo entreprise optionnel)
- **CSV** : Pour Excel/tableur

### Options d'export
- Format heures : hh:mm ou décimal
- Période : mois ou année
- Inclure : notes, bonus, détail par jour

---

## 🔧 OUTILS DE DIAGNOSTIC

### Vérifications
- Cohérence des calculs
- Détection des doublons
- Entrées suspectes (>12h travail, etc.)

### Recalcul
- Bouton "Recalculer toutes les heures"
- Applique les paramètres actuels à toutes les entrées

---

## 💾 MODÈLE DE DONNÉES

```swift
// Configuration utilisateur
@Model
class AppConfiguration {
    var country: String // "CH", "FR", "BE"
    var region: String? // Canton, Département, Région
    var employeeStatus: String? // "ouvrier", "employé" (BE)
    
    var weeklyHours: Double
    var workingDays: [Bool] // [true, true, true, true, true, false, false]
    var standardDailyHours: Double // Calculé automatiquement
    
    var annualVacationDays: Int
    var vacationStartDate: Date
    var initialVacationDays: Double
    
    var hasRTT: Bool // FR uniquement
    var annualRTTDays: Int // FR
    var initialRTTDays: Double // FR
    
    var sickLeaveCarenceDays: Int
    
    var useDecimalHours: Bool
    var currency: String // "CHF", "EUR"
}

// Entrée de travail
@Model
class WorkDay {
    var id: UUID
    var date: Date
    var type: String // WorkDayType.rawValue
    var subType: String? // Pour congés spéciaux, formation, etc.
    
    var startTime: Date?
    var endTime: Date?
    var breakDuration: TimeInterval
    
    var totalHours: Double
    var overtimeSeconds: Int
    
    var bonusAmount: Double
    var note: String?
    
    var isCarenceDay: Bool
    var isPaid: Bool
    
    var createdAt: Date
    var modifiedAt: Date
    var isDeleted: Bool
    var cloudKitRecordID: String?
}

// Types de journées
enum WorkDayType: String, CaseIterable {
    // Communs à tous les pays
    case work = "Travail"
    case vacation = "Congé"
    case halfDayVacation = "Demi-journée de congé"
    case sickLeave = "Maladie"
    case sickLeaveCarence = "Jour de carence"
    case compensatory = "Journée compensatoire"
    case holiday = "Jour férié"
    case trainingPaid = "Formation payée"
    case trainingUnpaid = "Formation non payée"
    case maternityLeave = "Congé maternité"
    case paternityLeave = "Congé paternité"
    case specialLeave = "Congé spécial"
    case unpaidLeave = "Congé sans solde"
    
    // 🇫🇷 France uniquement
    case rtt = "RTT"
    
    // 🇨🇭 Suisse uniquement
    case militaryService = "Service militaire"
    
    // 🇧🇪 Belgique uniquement
    case timeCredit = "Crédit-temps"
    
    // Filtrer selon le pays
    static func availableTypes(for country: String) -> [WorkDayType] {
        var types: [WorkDayType] = [
            .work, .vacation, .halfDayVacation, .sickLeave,
            .sickLeaveCarence, .compensatory, .holiday,
            .trainingPaid, .trainingUnpaid, .maternityLeave,
            .paternityLeave, .specialLeave, .unpaidLeave
        ]
        
        switch country {
        case "CH":
            types.append(.militaryService)
        case "FR":
            types.append(.rtt)
        case "BE":
            types.append(.timeCredit)
        default:
            break
        }
        
        return types
    }
}

enum SpecialLeaveType: String, CaseIterable {
    case marriage = "Mariage"
    case childBirth = "Naissance enfant"
    case deathSpouse = "Décès conjoint"
    case deathChild = "Décès enfant"
    case deathParent = "Décès parent"
    case deathSibling = "Décès frère/sœur"
    case moving = "Déménagement"
    case sickChild = "Enfant malade"
}
```

---

## ✅ RÈGLES MÉTIER AUTOMATIQUES

### 1. Calcul heures/jour
```
standardDailyHours = weeklyHours / countWorkingDays
```

### 2. Heures supp. travail
```
overtimeSeconds = (endTime - startTime - break) - standardDailyHours
```

### 3. Journée compensatoire
- Retire `standardDailyHours` du solde heures supp.

### 4. Maladie
- **Jour de carence** : Déduit comme une journée compensatoire (payé mais retire `standardDailyHours` des heures supp.)
- **Maladie payée** : Pas de déduction heures supp. (payé, après les jours de carence)

### 5. Congés
- Déduit du solde vacances
- Report automatique année suivante

### 6. RTT (France)
- Compteur séparé des congés
- Déduit du solde RTT

### 7. Jour férié
- Ajouté manuellement comme une entrée normale
- Pas de déduction d'heures

### 8. Validation
- Alerte si heure fin < heure début
- Alerte si >12h de travail
- Détection doublons (même date)

---

## 🎨 DESIGN & UX

### Principes
- Design iOS 26 avec **Liquid Glass** (`.glassEffect()`)
- Animations fluides (spring animations)
- Feedback haptique sur les interactions
- Support Dark Mode
- Accessibilité (VoiceOver, Dynamic Type)

### Navigation
- TabBar avec : Accueil, Calendrier, Statistiques, Réglages
- Bouton "+" pour ajouter une entrée

### Couleurs par type
- Travail : Bleu
- Congé : Orange
- Maladie : Rouge
- Compensatoire : Vert
- Formation : Violet
- Férié : Jaune

---

## 🔄 SYNCHRONISATION

### iCloud + SwiftData
- Sync automatique en arrière-plan
- Multi-appareils (iPhone, iPad)

---

## 📚 RESSOURCES APPLE DEVELOPER

| Ressource | Lien |
|-----------|------|
| iOS 26 What's New | https://developer.apple.com/ios/whats-new/ |
| SwiftUI | https://developer.apple.com/documentation/swiftui |
| SwiftData | https://developer.apple.com/documentation/swiftdata |
| Liquid Glass (Materials) | https://developer.apple.com/design/human-interface-guidelines/materials |

---

*Dernière mise à jour : 10 décembre 2025*
*Compatible : iOS 26, iPadOS 26*




