# SiKulak Project UI Conventions

- **Navigation Bar**: All pages that require a bottom navigation bar must use the `CustomNavBar` widget from `lib/widgets/navbar.dart`. This navbar is designed to only contain icons (no text labels) and must be placed in the `bottomNavigationBar` property of a `Scaffold` with `extendBody: true` to ensure the consistent floating pill layout is maintained across the app.
