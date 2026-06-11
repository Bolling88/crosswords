import 'package:flutter/material.dart';

import '../../../../common/data/constants/app_colors.dart';

class BlockedCellWidget extends StatelessWidget {
  final double size;

  const BlockedCellWidget({required this.size, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.blockedCell,
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.gridLine, width: 0.5),
          ),
        ),
      ),
    );
  }
}
