import 'grid_cell_dto.dart';

class GridDto {
  final int width;
  final int height;
  final List<List<GridCellDto>> rows;

  const GridDto({
    required this.width,
    required this.height,
    required this.rows,
  });

  factory GridDto.fromJson(Map<String, dynamic> json) => GridDto(
        width: json['width'] as int,
        height: json['height'] as int,
        rows: (json['rows'] as List)
            .map(
              (row) => (row as List)
                  .map(
                    (cell) =>
                        GridCellDto.fromJson(cell as Map<String, dynamic>),
                  )
                  .toList(),
            )
            .toList(),
      );
}
