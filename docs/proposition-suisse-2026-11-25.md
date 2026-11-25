# Vendre WorkTimer en Suisse : état des lieux et propositions (25.11.2026)

La proposition 1 (jours fériés par canton) est codée. Les propositions 2 et 3 ne le sont pas.

## État des lieux

- Cibles : app iPhone (SwiftUI, SwiftData), app Apple Watch, widget, tests. iOS 27 minimum.
- Cinq onglets : Accueil, Journées, Calendrier, Statistiques, Réglages. Écrans secondaires : saisie, congés, graphiques, export, notifications, Siri, iCloud, diagnostic, achat.
- Gratuit : saisie, chrono, calendrier, statistiques, congés, rappels, montre, widget. Pro : export PDF/CSV, graphiques, raccourcis Siri.
- Achats StoreKit 2 : mensuel `com.worktimer.pro.subscription.monthly`, annuel `com.worktimer.pro.annual`, à vie `com.worktimer.pro.lifetime`. Les trois donnent le même accès. L'app relit les droits Apple au lancement et à chaque transaction. Il n'y a aucun serveur propre à l'app.
- App Store Connect, lu le 25.11.2026 : trois produits approuvés, textes fr/de/en présents, partage familial actif. Prix suisses : CHF 2.00, 8.00 et 18.00. La version 1.7.4 est déjà en ligne, la prochaine devra porter un numéro supérieur.

## Propositions pour la version payante

1. **Jours fériés par canton.** Choix du canton, puis du district ou de la commune quand la règle varie (AG, FR, NE, SO notamment). Affichage dans le calendrier et ajout en un geste, jamais sans confirmation. Calcul hors ligne. Source : annexe SECO, état au 12.12.2024.
2. **Feuille d'heures pour l'employeur.** PDF et CSV par semaine ou par mois : début, fin, pauses, total par jour et par semaine, absences, heures supplémentaires, lignes de signature.
3. **Contrôle de saisie.** Rappel des jours travaillés sans saisie, des fins de journée et des pauses manquantes, avec ouverture directe du jour à compléter. L'obligation légale incombe à l'employeur, l'app ne doit pas laisser croire l'inverse ni promettre une conformité.

Sources : kmu.admin.ch (saisie du temps de travail), seco.admin.ch (enregistrement de la durée du travail, annexe des jours fériés). Le texte de l'art. 73 OLT 1 reste à relire sur Fedlex avant de coder.
