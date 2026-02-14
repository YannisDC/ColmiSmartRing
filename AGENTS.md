## 🏗️ Project Setup

We selected the [SwiftUI Blueprint](https://medium.com/mop-developers/build-your-first-swiftui-app-part-1-project-setup-45e172247883) as the architecture for the app since it's lightweight, based on MVVM with a nice separation of concern and features and allows for quick iteration with SwiftUI.

### Folder Structure

```bash
App
├── Code
│   ├── Features
│   │   ├── Feature-X
│   │   │   ├── Actions
│   │   │   ├── Models
│   │   │   ├── Screens
│   │   │   ├── ViewModels
│   │   │   └── Views
│   │   │
│   │   └── Feature-Y
│   │       ├── Actions
│   │       ├── Models
│   │       ├── Screens
│   │       ├── ViewModels
│   │       └── Views
│   │
│   └── Utilities
│
├── Environments
│   ├── DEV
│   └── PROD
│
├── Preview Content (compiles during development only)
│
├── Resources
│
└── Supporting Files (Contains the high level app files)
```

## 🌐 Translations

- **Always provide translations** for all user-facing text in the app
- Use the localization system (e.g., `NSLocalizedString` or SwiftUI's `LocalizedStringKey`)
- Never hardcode user-facing strings directly in code
- Ensure all new features include proper localization support

## ♿ Accessibility

- **Keep accessibility perfect** at all times
- Add proper accessibility labels, hints, and traits to all UI elements
- Test with VoiceOver and other accessibility features
- Ensure sufficient color contrast ratios
- Support Dynamic Type for text sizing
- Make all interactive elements accessible via keyboard navigation
- Test accessibility features during development, not as an afterthought

## 🎨 UI/UX Guidelines

- Use native iOS/macOS design patterns
- Provide clear visual feedback for file operations
- Show loading states for async operations
- Use appropriate system icons and symbols
- Support Dark Mode
- Follow accessibility guidelines (see Accessibility section above)