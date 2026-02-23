import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class CountryData {
  final String name;
  final String code;
  final String flag;

  const CountryData({
    required this.name,
    required this.code,
    required this.flag,
  });
}

const _countries = [
  CountryData(name: 'India', code: '+91', flag: '🇮🇳'),
  CountryData(name: 'United States', code: '+1', flag: '🇺🇸'),
  CountryData(name: 'United Kingdom', code: '+44', flag: '🇬🇧'),
  CountryData(name: 'Canada', code: '+1', flag: '🇨🇦'),
  CountryData(name: 'Australia', code: '+61', flag: '🇦🇺'),
  CountryData(name: 'Germany', code: '+49', flag: '🇩🇪'),
  CountryData(name: 'France', code: '+33', flag: '🇫🇷'),
  CountryData(name: 'Brazil', code: '+55', flag: '🇧🇷'),
  CountryData(name: 'Japan', code: '+81', flag: '🇯🇵'),
  CountryData(name: 'South Korea', code: '+82', flag: '🇰🇷'),
  CountryData(name: 'China', code: '+86', flag: '🇨🇳'),
  CountryData(name: 'Russia', code: '+7', flag: '🇷🇺'),
  CountryData(name: 'Mexico', code: '+52', flag: '🇲🇽'),
  CountryData(name: 'Indonesia', code: '+62', flag: '🇮🇩'),
  CountryData(name: 'Turkey', code: '+90', flag: '🇹🇷'),
  CountryData(name: 'Saudi Arabia', code: '+966', flag: '🇸🇦'),
  CountryData(name: 'UAE', code: '+971', flag: '🇦🇪'),
  CountryData(name: 'Pakistan', code: '+92', flag: '🇵🇰'),
  CountryData(name: 'Bangladesh', code: '+880', flag: '🇧🇩'),
  CountryData(name: 'Nigeria', code: '+234', flag: '🇳🇬'),
  CountryData(name: 'South Africa', code: '+27', flag: '🇿🇦'),
  CountryData(name: 'Egypt', code: '+20', flag: '🇪🇬'),
  CountryData(name: 'Italy', code: '+39', flag: '🇮🇹'),
  CountryData(name: 'Spain', code: '+34', flag: '🇪🇸'),
  CountryData(name: 'Netherlands', code: '+31', flag: '🇳🇱'),
  CountryData(name: 'Singapore', code: '+65', flag: '🇸🇬'),
  CountryData(name: 'Malaysia', code: '+60', flag: '🇲🇾'),
  CountryData(name: 'Thailand', code: '+66', flag: '🇹🇭'),
  CountryData(name: 'Philippines', code: '+63', flag: '🇵🇭'),
  CountryData(name: 'Vietnam', code: '+84', flag: '🇻🇳'),
];

void showCountryPicker({
  required BuildContext context,
  required void Function(String code, String flag) onSelected,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.bgSecondary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (ctx) => _CountryPickerSheet(onSelected: onSelected),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  final void Function(String code, String flag) onSelected;

  const _CountryPickerSheet({required this.onSelected});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchController = TextEditingController();
  List<CountryData> _filtered = _countries;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = _countries;
      } else {
        final q = query.toLowerCase();
        _filtered = _countries
            .where((c) =>
                c.name.toLowerCase().contains(q) || c.code.contains(q))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Select Country',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: _filter,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search country...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textMuted,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            // List
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final country = _filtered[index];
                  return ListTile(
                    leading: Text(
                      country.flag,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(
                      country.name,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    trailing: Text(
                      country.code,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    onTap: () {
                      widget.onSelected(country.code, country.flag);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
