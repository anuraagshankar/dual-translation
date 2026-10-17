# Dual Translator

Personal translator app. Typing in any one of English, Spanish or Catalan shows the translation into the other two at the same time.

## Constraints
- Primary device: iPhone SE 2020 (old, low-end). The final app must be lightweight, fast and minimal: no unnecessary dependencies, animations or features.
- Main entry point is a Home Screen widget, so the app and the widget are built together.
- Translation engine: DeepL API (Apple's Translation framework doesn't support Catalan).

## Structure
- `web/`: prototype for iterating on UI/UX on my Mac. Performance doesn't matter here; speed of iteration does.
- `apple/`: the real iPhone app + widget (SwiftUI, WidgetKit).

## Workflow
1. Build and refine the UI in `web/` until I approve it.
2. Only then build `apple/`, treating the web app as the source of truth for design and behavior. Match it exactly unless something is impossible or inefficient on iOS; if so, tell me rather than silently changing it.
3. In `apple/`, always prefer the lightest, most efficient implementation.