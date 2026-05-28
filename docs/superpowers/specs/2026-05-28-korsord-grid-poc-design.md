# Korsord Grid POC Design

## Goal

Validate that Flutter widgets can render a Swedish magazine-style crossword (korsord) grid with all cell types at real-world size with interactive input. This POC informs the architecture decision for the full app.

## Grid Specification

A realistic Swedish korsord grid: 13 columns x 15 rows (195 cells). Contains five cell types:

- **Hint cells** — Dark background, small white clue text, directional arrow(s) indicating answer direction (right, down, or both)
- **Answer cells** — White/light background, single uppercase letter, tappable for selection, accepts keyboard input
- **Blocked cells** — Solid dark fill, no interaction
- **Image cell** — A placeholder image spanning 3x3 cells, acts as a visual clue
- **Empty spanned cells** — Cells occupied by a spanning image, rendered as invisible

## Data Model

```dart
// Sealed class hierarchy for cell types
sealed class Cell {}

class HintCell extends Cell {
  final String clueText;
  final List<Direction> arrows; // where the answer goes
}

class AnswerCell extends Cell {
  final String solution;
  final String? userInput;
  final int? wordId; // groups cells into words for highlight
}

class BlockedCell extends Cell {}

class ImageCell extends Cell {
  final String imageRef;
  final int spanRows;
  final int spanCols;
  final bool isOrigin; // true for top-left cell of the span
}

enum Direction { right, down, downRight }
```

A `CrosswordPuzzle` holds:
- `rows: int` (15)
- `cols: int` (13)
- `cells: Map<(int, int), Cell>` keyed by (row, col)

## Widget Architecture

Follows the project's three-widget screen structure:

```
CrosswordScreen (StatelessWidget — provides BlocProvider)
  └── CrosswordScreenBuilder (BlocConsumer — handles side effects)
      └── CrosswordScreenContent (StatelessWidget — pure UI from state)
          └── AspectRatio
              └── Stack
                  ├── Table (uniform fixed-size cells)
                  │   └── per (row, col):
                  │       ├── HintCellWidget — dark bg, FittedBox for text, rotated arrow icon
                  │       ├── AnswerCellWidget — tap to select, shows letter, highlight states
                  │       ├── BlockedCellWidget — solid dark Container
                  │       └── SizedBox.shrink() — for non-origin image span cells
                  └── Positioned (image overlay — sized and placed by grid coordinates)
```

### Layout Strategy

- **Table** with uniform `FixedColumnWidth` calculated as `screenWidth / cols`
- Row heights match column widths (square cells)
- Image cells: origin cell renders empty in the Table; a `Positioned` widget in the parent `Stack` overlays the image at the correct grid coordinates
- Cell size adapts to screen width automatically

### Hint Cell Rendering

- Dark background (near-black or dark blue, matching Swedish magazine style)
- Clue text in white, wrapped inside `FittedBox` with `BoxFit.scaleDown` to fit the cell
- Arrow(s) rendered as a small icon in the corner, rotated with `Transform.rotate` based on `Direction`
- If a hint cell has two arrows (e.g., one clue goes right, another goes down), both arrows render in different corners

### Answer Cell Rendering

Three visual states:
1. **Default** — white background, black letter (or empty)
2. **Selected** — blue border/background, this is the active cell
3. **Word highlight** — light blue background, all cells in the current word

### Selection & Input

- **Tap an answer cell** → selects it, highlights its word, shows keyboard
- **Tap a hint cell** → selects the first answer cell of the clue's word
- **Type a letter** → fills selected cell, auto-advances to next answer cell in the current direction
- **Backspace** → clears current cell, moves back to previous answer cell
- **Tap selected cell again** → toggles direction (right ↔ down) if the cell belongs to two words

## Cubit State

```dart
class CrosswordState extends Equatable {
  final CrosswordPuzzle puzzle;
  final Map<(int, int), String> userInputs; // (row, col) -> letter
  final (int, int)? selectedCell;
  final Direction currentDirection;
  final Set<(int, int)> highlightedCells; // current word

  // props, copyWith, etc.
}
```

The Cubit handles: cell selection, direction toggling, letter input, backspace, and computing which cells to highlight.

## What This POC Validates

1. **Performance** — 195 widget cells render and rebuild smoothly on tap/type
2. **Text scaling** — FittedBox handles Swedish clue text in small hint cells
3. **Image spanning** — Stack overlay positions correctly over grid cells
4. **Arrow rendering** — Rotated icons look correct at small cell sizes
5. **Input flow** — Selection, typing, auto-advance, direction toggle feel natural

## Out of Scope

- Puzzle loading from backend/JSON
- Scoring, timers, completion detection
- Persistence of progress
- Multiple puzzles or navigation
- Animations or transitions
- Subscription or auth
- Error states or loading states

## Hardcoded Test Puzzle

The POC includes one hardcoded 13x15 Swedish korsord puzzle with:
- ~15-20 hint cells with real Swedish clue text
- ~120-140 answer cells forming intersecting words
- ~10-15 blocked cells
- One 3x3 image cell (placeholder asset or colored box)

This provides enough density to validate all cell types and interactions at a realistic scale.
