import 'package:flutter/material.dart';

import '../../data/constants/app_colors.dart';
import '../../data/constants/app_text_styles.dart';

/// The shared brand-styled app bar (centred title, brand surface, no
/// elevation). Used across the crossword, settings, and account screens so the
/// chrome stays consistent in one place.
class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions;

  const BrandAppBar({required this.title, this.actions = const [], super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, style: AppTextStyles.appBarTitle()),
      centerTitle: true,
      backgroundColor: AppColors.brand,
      foregroundColor: AppColors.onBrand,
      elevation: 0,
      actions: actions,
    );
  }
}
