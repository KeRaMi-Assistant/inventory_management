# Social Login & Auth Setup (Sprint 2)

Projekt-Ref: `uzpkrdymlrrydtuxnvhy`
Supabase-Auth-Callback: `https://uzpkrdymlrrydtuxnvhy.supabase.co/auth/v1/callback`
Mobile/Desktop Deep-Link: `inventorymanagement://auth/callback` und `inventorymanagement://auth/reset`

## 1) Google

### Google Cloud Console
1. https://console.cloud.google.com/ → APIs & Services → Credentials
2. **Create Credentials → OAuth client ID → Web application**
3. **Authorized redirect URIs** hinzufügen:
   - `https://uzpkrdymlrrydtuxnvhy.supabase.co/auth/v1/callback`
4. Client-ID + Client-Secret kopieren

### Supabase Dashboard
1. https://supabase.com/dashboard/project/uzpkrdymlrrydtuxnvhy/auth/providers
2. **Google** aufklappen → **Enable** ✓
3. Client-ID + Client-Secret eintragen → **Save**

## 2) Apple (nur für iOS/macOS)

### Apple Developer Portal
1. https://developer.apple.com/account/resources/identifiers/list
2. **App-ID** anlegen mit Bundle-ID (z.B. `com.kerem.inventorymanagement`)
   → Capability **Sign In with Apple** aktivieren
3. **Service-ID** anlegen, Domain + Return-URL setzen:
   - Domain: `uzpkrdymlrrydtuxnvhy.supabase.co`
   - Return URL: `https://uzpkrdymlrrydtuxnvhy.supabase.co/auth/v1/callback`
4. **Key (Sign in with Apple)** anlegen, .p8-Datei herunterladen
5. **Team ID** + **Key ID** + **Service-ID** notieren

### Supabase Dashboard
1. **Apple** Provider aufklappen → **Enable** ✓
2. Service-ID, Team-ID, Key-ID, .p8-Inhalt einfügen → **Save**

### iOS Xcode
1. `ios/Runner.xcworkspace` öffnen
2. Target Runner → **Signing & Capabilities** → **+ Capability** → **Sign in with Apple**

## 3) Redirect-URLs (für Deep-Links)

Dashboard → Authentication → URL Configuration → **Redirect URLs (Allow list)**:
```
inventorymanagement://auth/callback
inventorymanagement://auth/reset
http://localhost:3000/*
http://localhost:8080/*
```

Site-URL (nur für Web-Build):
- Dev: `http://localhost:5000`
- Prod: deine Domain

## 4) E-Mail-Verifikation

Dashboard → Authentication → Sign In / Up → Email:
- **Dev/Staging:** "Confirm email" **AUS** (schnellere Iterationen)
- **Produktion:** "Confirm email" **EIN** — die App leitet dann automatisch
  zum `VerifyEmailScreen` weiter (Sprint 2 / C.1).

## 5) Smoke-Test nach Konfiguration

1. App starten → Login-Screen → "Mit Google anmelden"
2. Browser-Tab öffnet sich → Google-Login → Redirect zurück zur App
3. AuthGate sollte die neue Session erkennen → MainScreen
4. (iOS) "Mit Apple anmelden" analog

Falls der Redirect nicht zurück in die App führt, prüfe:
- iOS: `Info.plist` → `CFBundleURLSchemes` enthält `inventorymanagement`
- Android: `AndroidManifest.xml` → Intent-Filter für scheme=inventorymanagement, host=auth
- Supabase Dashboard → Redirect URLs enthält den Deep-Link
