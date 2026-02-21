import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../config/app_theme.dart';

class GradeSelector extends StatelessWidget {
  final int? selectedGrade;
  final String? selectedCurriculum; // 'CBC' or 'KCSE'
  final Function(int grade, String curriculum) onGradeSelected;

  const GradeSelector({
    super.key,
    this.selectedGrade,
    this.selectedCurriculum,
    required this.onGradeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Primary (CBC)", theme),
        const SizedBox(height: AppTheme.spacingMd),
        _buildGradeGrid(1, 9, "CBC", theme),
        const SizedBox(height: AppTheme.spacingLg),
        _buildSectionTitle("Secondary (KCSE)", theme),
        const SizedBox(height: AppTheme.spacingMd),
        _buildGradeGrid(1, 4, "KCSE", theme),
      ],
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(
      title,
      style: GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _buildGradeGrid(
    int start,
    int end,
    String curriculum,
    ThemeData theme,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppTheme.spacingMd,
        mainAxisSpacing: AppTheme.spacingMd,
        childAspectRatio: 2.2,
      ),
      itemCount: (end - start) + 1,
      itemBuilder: (context, index) {
        final grade = start + index;
        final isSelected =
            selectedGrade == grade && selectedCurriculum == curriculum;
        final label = curriculum == "CBC" ? "Grade $grade" : "Form $grade";

        return InkWell(
          onTap: () => onGradeSelected(grade, curriculum),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: AnimatedContainer(
            duration: AppTheme.durationFast,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : theme.cardColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? AppTheme.getGlowShadow(AppColors.primary, intensity: 0.2)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                fontSize: 15,
              ),
            ),
          ),
        );
      },
    );
  }
}
