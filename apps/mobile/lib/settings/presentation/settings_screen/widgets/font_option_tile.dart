import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:crossword_ui/crossword_ui.dart';

/// A single selectable font row that previews itself in its own font.
class FontOptionTile extends StatelessWidget {
  final AppFont font;
  final bool isSelected;
  final VoidCallback onTap;

  const FontOptionTile({
    required this.font,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.highlight : AppColors.paper,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      font.displayName,
                      style: GoogleFonts.getFont(
                        font.googleFamily,
                        fontSize: 22,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Strings.fontPreviewSample,
                      style: GoogleFonts.getFont(
                        font.googleFamily,
                        fontSize: 18,
                        color: AppColors.inkMuted,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check, color: AppColors.brand),
            ],
          ),
        ),
      ),
    );
  }
}
