# Recon summary

Artifact: `breezy-weather-v6.2.2_standard.apk`  
SHA-256: `20a33a588e884257ab9329fee794d30a9d15ea067f64302c70c69c9adc3c6309`  
Recon: 2026-11-15

## Scale

- App package: `org.breezyweather`
- App classes: **1204** java files, **178136** lines of decompiled Java (the porting surface)
- Note: decompiled Java overstates the Kotlin source (imports, lambda expansion, braces).
  Compare *file counts* against the port, not line counts.
- Bundled library classes: 8255 (dependencies, not ported)

## Framework shape

- Compose present in app classes
- No app-owned fragments (library hits ignored)
- DI: hilt present in app classes
- RecyclerView used by app classes: stage 6 has View-system list work, not only Compose
- ComposeView interop: Compose embedded in View hierarchy (check which is primary)
- Home-screen widgets present: NO iOS equivalent (WidgetKit is a different product)
- Live wallpaper present: NO iOS equivalent at all
- Background work beyond resume refresh: iOS BGTaskScheduler cannot do the same thing

## Structural markers

```
SharedPreferences      5
Canvas                 9
```

## What to read first

1. `03-permissions.txt` - permissions with no iOS equivalent are scope changes, not ports.
2. `08-markers.txt` - scroll containers per screen, and whether the app is Compose or Views.
3. `05-strings.txt` - the copy is parity; copy it, do not paraphrase.
4. `09-decompiled` - then one entry point, top-down.

## Gates before stage 3

- [ ] Checksum recorded (above)
- [ ] Permission deltas listed as decisions, not surprises
- [ ] Screen graph written down from component + marker evidence
- [ ] Compose vs Views decided (changes stage 6 entirely)
- [ ] Obfuscated or not (short-named file count above)
