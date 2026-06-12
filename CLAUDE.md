# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Crosswords** is a Swedish magazine-style crossword puzzle game (korsord), where clues are embedded inside the grid cells with directional arrows, and images can serve as visual clues.

### Key Features
- Interactive Crossword Grid: Tap cells to select, type letters, auto-advance through words
- Swedish Korsord Style: Hint cells with clue text and arrows inside the grid (not a separate clue list)
- Image Clues: Images spanning multiple grid cells act as visual clues
- User Accounts: Email/Google sign-in with cloud-synced progress
- Subscriptions: RevenueCat for in-app purchases

### Tech Stack
- **Framework**: Flutter 3.41.9
- **State Management**: flutter_bloc (Cubit pattern)
- **Backend**: AWS (own-hosted during development)
- **Subscriptions**: RevenueCat (purchases_flutter)
- **Platform**: iOS and Android

## Development Commands

### Running the App
```bash
flutter run
```

### Code Quality
```bash
flutter analyze
dart analyze
flutter test
dart fix --apply
flutter clean
```

## Architecture

### Clean Architecture with BLoC Pattern

```
lib/
├── feature_name/
│   ├── data/
│   │   ├── remote/            # API calls (RemoteDataSource)
│   │   ├── repository/        # Data coordination layer
│   │   └── entities/          # Data models (JSON serializable)
│   ├── domain/
│   │   ├── services/          # Business logic with ValueNotifiers
│   │   └── entities/          # Domain models
│   └── presentation/
│       ├── screen_name/
│       │   ├── cubit/         # State management (Cubit + State)
│       │   ├── widgets/       # Screen-specific widgets
│       │   └── screen.dart    # Main screen file
├── common/
│   ├── data/constants/        # Theme, strings, assets
│   └── presentation/widgets/  # Reusable widgets
├── utils/
└── app_data/
```

### Key Feature Modules
- `gameplay/` - Crossword grid rendering, cell interaction, puzzle state
- `home/` - Main dashboard, puzzle selection
- `profile/` - User profile and settings
- `subscription/` - In-app purchases
- `onboarding/` - Welcome screens
- `login/` - Authentication

### Data Flow

`UI Screen → Cubit → Service → Repository → RemoteDataSource → Backend (AWS)`

### State Management: Hybrid Approach

**Cubits** - Screen-specific state (one per screen/feature), located in `presentation/[screen]/cubit/`.

**Services with ValueNotifiers** - Cross-feature shared state (e.g. user data, subscription status, puzzle progress).

### Dependency Injection

All services registered in `main.dart` via `MultiRepositoryProvider` + `MultiBlocProvider`.

**CRITICAL: Service Access Rules**:
- **ONLY Cubits can access services** via constructor injection
- Services are passed to Cubits when creating the BlocProvider
- **NEVER access services directly in UI widgets** using `context.read<Service>()`

```dart
// CORRECT
BlocProvider(
  create: (context) => MyCubit(myService: context.read<MyService>()),
  child: const MyScreenBuilder(),
)

// WRONG - Service accessed in UI widget
final service = context.read<MyService>();
```

### Navigation

- Uses `Navigator.push/pushReplacement` (no named routes or GoRouter)
- Navigation logic lives in Cubit listeners via navigation event states

## Code Style & Conventions

### State Management Philosophy

**ALL widgets MUST be StatelessWidget - NO EXCEPTIONS**:
- **NEVER** use `StatefulWidget`, `ValueNotifier`, `setState`, `addListener`, `initState`, or `dispose` in widgets
- If a widget needs local state, create a Cubit for it
- All state lives in Cubit and flows down via BlocBuilder/BlocConsumer

### Cubit Pattern

Each screen has `*_cubit.dart` (logic) and `*_state.dart` (state class) in `cubit/`.

**Cubit Constructor Pattern** - dependencies MUST be private:
```dart
class MyCubit extends Cubit<MyState> {
  final MyService _myService;

  MyCubit({required MyService myService})
      : _myService = myService,
        super(const MyState());
}
```

**TextEditingController and FocusNode Management** - controllers/focus nodes MUST be in the Cubit, not UI:
```dart
class EditProfileCubit extends Cubit<EditProfileState> {
  final TextEditingController firstNameController = TextEditingController();
  final FocusNode focusNode = FocusNode();

  @override
  Future<void> close() async {
    firstNameController.dispose();
    focusNode.dispose();
    return super.close();
  }
}

// In UI:
TextField(controller: context.read<EditProfileCubit>().firstNameController)
```

**State Class Structure**:
```dart
class MyState extends Equatable {
  final List<Item> items;
  final bool isLoading;

  const MyState({this.items = const [], this.isLoading = false});

  @override
  List<Object?> get props => [items, isLoading];

  MyState copyWith({List<Item>? items, bool? isLoading}) {
    return MyState(items: items ?? this.items, isLoading: isLoading ?? this.isLoading);
  }

  MyState.copy(MyState state)
    : items = state.items,
      isLoading = state.isLoading;
}
```

**CRITICAL: Event States for Side Effects**

Side effects (errors, toasts, navigation) MUST use dedicated event state classes with `UniqueKey`:

```dart
class ShowError extends MyState {
  final String errorMessage;
  final Key key = UniqueKey();

  ShowError({required MyState state, required this.errorMessage})
      : super.copy(state);

  @override
  List<Object?> get props => [...super.props, errorMessage, key];
}
```

Rules:
- **ALWAYS** add `final Key key = UniqueKey();` to ALL event states
- **ALWAYS** override `props` to include the key
- **NEVER** use `copyWith` for side effects

### Screen Structure Pattern

**REQUIRED: All screens MUST follow this three-widget structure:**

```dart
// 1. Screen Wrapper - Provides BlocProvider
class MyScreen extends StatelessWidget {
  const MyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MyCubit(service: context.read<MyService>()),
      child: const MyScreenBuilder(),
    );
  }
}

// 2. Screen Builder - Handles BlocConsumer logic
class MyScreenBuilder extends StatelessWidget {
  const MyScreenBuilder({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MyCubit, MyState>(
      listener: (context, state) {
        if (state is NavigateToNextScreen) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const NextScreen()));
        }
      },
      builder: (context, state) => MyScreenContent(state: state),
    );
  }
}

// 3. Screen Content - Pure UI rendering from state
class MyScreenContent extends StatelessWidget {
  final MyState state;
  const MyScreenContent({required this.state, super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: ...);
  }
}
```

### Entities & Domain Models

- **Naming**: Plain names without "Entity" suffix — `CrosswordPuzzle`, `Cell` (not `CrosswordPuzzleEntity`)
- **File names**: Match class in snake_case — `crossword_puzzle.dart`
- All models extend `Equatable` with `const` constructors, `final` fields, `copyWith()`, and `toJson()`/`fromJson()` if persisted
- Use sealed classes for type hierarchies (e.g. `sealed class Cell`)

**Nullable Fields in copyWith()** — NEVER use sentinel values:
```dart
// CORRECT
MyState copyWith({Recipe? recipe}) => MyState(recipe: recipe ?? this.recipe);
MyState withRecipeAsNull() => MyState(recipe: null);

// WRONG - sentinel values
const Object _undefined = Object();
MyState copyWith({Object? recipe = _undefined}) { ... }
```

### Null Safety

**NEVER use the null assertion operator (`!`)**:
```dart
// WRONG
if (state.recipe != null && state.recipe!.focusAreas.isNotEmpty) { ... }

// CORRECT
if (state.recipe?.focusAreas.isNotEmpty == true) { ... }
final name = user?.profile?.name ?? 'Unknown';
```

### Crossword Grid Specifics

- Grid rendered with Flutter **widgets** (Table + Stack), NOT CustomPainter or game engine
- Cell size computed from screen width: `cellSize = screenWidth / puzzle.cols`
- Image cells spanning multiple positions use `Positioned` overlay in a `Stack`
- Word highlighting computed dynamically by scanning contiguous answer cells from selected cell
- Keyboard input via `Focus` widget with `onKeyEvent` (handles Swedish characters åäöÅÄÖ)

### Strings & Localization

**NEVER HARDCODE USER-FACING STRINGS**:
- **ALWAYS use `Strings` constants** from a centralized strings file
- Primary language: Swedish (`'sv'` locale)

### Images & Network Resources

**Always use `CachedNetworkImage`** — never `Image.network()`.

### Theme & Styling

- **Always use `AppColors` constants** — never hardcode colors
- **Color opacity**: Use `withAlpha()` not deprecated `withOpacity()`. Conversion: `alpha = (opacity * 255).round()`

### Tappable Elements

**NEVER** use `GestureDetector` for tappable UI — **ALWAYS** use `InkWell` wrapped in `Material` (except for grid cells where `GestureDetector` is acceptable for performance).

### Code Formatting

- Trailing commas required (enforced by linter)
- Use `const` constructors wherever possible
- Prefer `final` over `var`
- Private fields/methods prefixed with `_`
- Boolean variables: `isValid`, `hasWinner`, `shouldShow`

### Lint Rules

- Performance: `avoid_unnecessary_containers`, `use_decorated_box`
- Code Quality: `prefer_const_constructors`, `prefer_single_quotes`
- Safety: `avoid_print`
- Style: `require_trailing_commas`, `prefer_const_declarations`

## Important Notes

- **Do not commit sensitive data**: Avoid `.env`, `credentials.json`, etc.
- **Error handling**: Use try-catch blocks in async operations
- **Testing**: Write cubit tests for all business logic
- **Comments**: English for all code comments
- **User-facing text**: Swedish (follow localization patterns)
- **Import order**: Dart/Flutter → Packages → Local (with blank lines between)
