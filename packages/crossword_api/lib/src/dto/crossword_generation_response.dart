/// Parsed body of `POST /crossword-puzzles/generate`. Only the fields the
/// mapper needs are parsed; `cells`, `stats`, and clue-generation fields are
/// intentionally ignored for now.
class CrosswordGenerationResponse {
  final bool success;
  final String? failureReason;
  final List<List<GenerationGridCellDto>>? gridCells;
  final List<GenerationSlotDto>? slots;
  final List<GenerationAssignmentDto>? assignments;
  final List<GenerationSeedCellDto>? seedCells;

  const CrosswordGenerationResponse({
    required this.success,
    this.failureReason,
    this.gridCells,
    this.slots,
    this.assignments,
    this.seedCells,
  });

  factory CrosswordGenerationResponse.fromJson(Map<String, dynamic> json) {
    final rawGrid = json['grid_cells'] as List<dynamic>?;
    final rawSlots = json['slots'] as List<dynamic>?;
    final rawAssign = json['assignments'] as List<dynamic>?;
    final rawSeeds = json['seed_cells'] as List<dynamic>?;

    return CrosswordGenerationResponse(
      success: json['success'] as bool,
      failureReason: json['failure_reason'] as String?,
      gridCells: rawGrid
          ?.map((row) => (row as List<dynamic>)
              .map(
                (c) => GenerationGridCellDto.fromJson(c as Map<String, dynamic>),
              )
              .toList())
          .toList(),
      slots: rawSlots
          ?.map((s) => GenerationSlotDto.fromJson(s as Map<String, dynamic>))
          .toList(),
      assignments: rawAssign
          ?.map(
            (a) => GenerationAssignmentDto.fromJson(a as Map<String, dynamic>),
          )
          .toList(),
      seedCells: rawSeeds
          ?.map(
            (s) => GenerationSeedCellDto.fromJson(s as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class GenerationGridCellDto {
  final String kind;
  final int row;
  final int col;
  final int rowspan;
  final int colspan;
  final String? letter;
  final List<GenerationClueTagDto> clueTags;
  final String sepRight;
  final String sepBottom;

  const GenerationGridCellDto({
    required this.kind,
    required this.row,
    required this.col,
    this.rowspan = 1,
    this.colspan = 1,
    this.letter,
    this.clueTags = const [],
    this.sepRight = '',
    this.sepBottom = '',
  });

  factory GenerationGridCellDto.fromJson(Map<String, dynamic> json) {
    final rawTags = json['clue_tags'] as List<dynamic>?;
    return GenerationGridCellDto(
      kind: json['kind'] as String,
      row: json['row'] as int,
      col: json['col'] as int,
      rowspan: json['rowspan'] as int? ?? 1,
      colspan: json['colspan'] as int? ?? 1,
      letter: json['letter'] as String?,
      clueTags: rawTags
              ?.map(
                (t) => GenerationClueTagDto.fromJson(t as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      sepRight: json['sep_right'] as String? ?? '',
      sepBottom: json['sep_bottom'] as String? ?? '',
    );
  }
}

class GenerationClueTagDto {
  final int id;
  final String arrow;

  const GenerationClueTagDto({required this.id, required this.arrow});

  factory GenerationClueTagDto.fromJson(Map<String, dynamic> json) =>
      GenerationClueTagDto(
        id: json['id'] as int,
        arrow: json['arrow'] as String,
      );
}

class GenerationSlotDto {
  final int slotId;
  final int startRow;
  final int startCol;
  final String direction;
  final int length;
  final int clueRow;
  final int clueCol;

  const GenerationSlotDto({
    required this.slotId,
    required this.startRow,
    required this.startCol,
    required this.direction,
    required this.length,
    required this.clueRow,
    required this.clueCol,
  });

  factory GenerationSlotDto.fromJson(Map<String, dynamic> json) =>
      GenerationSlotDto(
        slotId: json['slot_id'] as int,
        startRow: json['start_row'] as int,
        startCol: json['start_col'] as int,
        direction: json['direction'] as String,
        length: json['length'] as int,
        clueRow: json['clue_row'] as int,
        clueCol: json['clue_col'] as int,
      );
}

class GenerationAssignmentDto {
  final int slotId;
  final String word;

  const GenerationAssignmentDto({required this.slotId, required this.word});

  factory GenerationAssignmentDto.fromJson(Map<String, dynamic> json) =>
      GenerationAssignmentDto(
        slotId: json['slot_id'] as int,
        word: json['word'] as String,
      );
}

class GenerationSeedCellDto {
  final int row;
  final int col;
  final String letter;

  const GenerationSeedCellDto({
    required this.row,
    required this.col,
    required this.letter,
  });

  factory GenerationSeedCellDto.fromJson(Map<String, dynamic> json) =>
      GenerationSeedCellDto(
        row: json['row'] as int,
        col: json['col'] as int,
        letter: json['letter'] as String,
      );
}
