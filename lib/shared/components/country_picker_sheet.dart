import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/shared/components/country_flag_icon.dart';
import 'package:test_app/shared/components/gtube_text_field.dart';
import 'package:test_app/shared/data/countries.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

class CountryPickerSheet extends StatefulWidget {
  const CountryPickerSheet({super.key, this.selected});

  final Country? selected;

  static Future<Country?> show(BuildContext context, {Country? selected}) =>
      showModalBottomSheet<Country>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => CountryPickerSheet(selected: selected),
      );

  @override
  State<CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<CountryPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<Country> _results = Countries.all;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _results = Countries.search(_searchCtrl.text));
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.base1,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.s)),
          ),
          child: Column(
            children: [
              SizedBox(height: 14.s),
              SizedBox(
                width: 40.s,
                height: 3.s,
                child: const ColoredBox(color: AppColors.neutral400),
              ),
              SizedBox(height: 24.s),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.selectACountry,
                      style: AppStyles.body(16, color: AppColors.neutral400),
                    ),
                    SizedBox(height: 16.s),
                    GTubeTextField(
                      controller: _searchCtrl,
                      hint: AppStrings.searchCountryHint,
                      textInputAction: TextInputAction.search,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.s),
              Expanded(
                child: _results.isEmpty
                    ? Center(
                        child: Text(
                          AppStrings.noCountriesFound,
                          style: AppStyles.body(
                            14,
                            color: AppColors.neutral400,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(vertical: 8.s),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final country = _results[index];
                          return _CountryTile(
                            country: country,
                            selected: country == widget.selected,
                            onTap: () => Navigator.of(context).pop(country),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountryTile extends StatelessWidget {
  const _CountryTile({
    required this.country,
    required this.selected,
    required this.onTap,
  });

  final Country country;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.s, vertical: 14.s),
        child: Row(
          children: [
            CountryFlagIcon(isoCode: country.isoCode, height: 18.s),
            SizedBox(width: 12.s),
            Expanded(
              child: Text(
                country.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.label(
                  16,
                  weight: selected ? AppStyles.bold : AppStyles.medium,
                  color: selected
                      ? AppColors.brandPrimary
                      : AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(width: 12.s),
            Text(
              country.display,
              style: AppStyles.body(15, color: AppColors.neutral400),
            ),
          ],
        ),
      ),
    );
  }
}
