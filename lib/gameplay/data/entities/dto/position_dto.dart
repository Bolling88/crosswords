class PositionDto {
  final int col;
  final int row;

  const PositionDto({required this.col, required this.row});

  factory PositionDto.fromJson(Map<String, dynamic> json) => PositionDto(
        col: json['col'] as int,
        row: json['row'] as int,
      );
}
