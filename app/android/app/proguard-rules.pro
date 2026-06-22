# Flutter embedding + plugin registration rely on reflection — keep them.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Plugins used by this app (defensive keeps / suppress missing-class warnings).
# Bonsoir uses Android NSD (no app-class reflection); these just silence warnings
# from its transitive Kotlin/AndroidX deps under R8.
-dontwarn kotlinx.**
-keep class fr.skyost.bonsoir.** { *; }
