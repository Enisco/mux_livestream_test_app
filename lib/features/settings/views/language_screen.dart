import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/settings/repo/account_repo.dart';
import 'package:test_app/features/settings/views/account_forms.dart'
    show showAccountSnack;
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// What the app should speak.
///
/// `PATCH /v1/user/{id}` takes `language` as **BCP 47** — `en` and `en-NG`
/// both validate — and `GET /v1/user/profile` returns it.
///
/// **Null is not English.** It means the viewer has not chosen, which is the
/// only state from which falling back to the device's own language is
/// honest. So "Match my device" is a real option here rather than a synonym
/// for English, and choosing it sends `null`.
class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key, this.repo});

  final AccountRepo? repo;

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

/// What the app ships strings for today.
///
/// Deliberately short: offering a language the app has no copy in would be a
/// setting that changes nothing a reader can see.
const _languages = <(String, String)>[('en', 'English')];

/// The label for a stored tag, for the Account row.
///
/// An unknown tag — one chosen on another client, or a region this build does
/// not name — prints as itself rather than being silently shown as English.
String languageLabel(String? tag) {
  if (tag == null || tag.trim().isEmpty) return AppStrings.languageDevice;
  for (final (code, label) in _languages) {
    if (code == tag) return label;
  }
  return tag;
}

class _LanguageScreenState extends State<LanguageScreen> {
  late final _repo = widget.repo ?? AccountRepo();
  late String? _chosen = LocalStorage.cachedLanguage;
  bool _busy = false;

  Future<void> _choose(String? tag) async {
    if (_busy || tag == _chosen) return;
    final before = _chosen;
    setState(() {
      _chosen = tag;
      _busy = true;
    });
    try {
      await _repo.updateAccount(
        language: tag,
        // An explicit null is what clears a choice; omitting the key would
        // leave whatever was there.
        clearLanguage: tag == null,
      );
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (e) {
      logger.w('Language change failed', error: e);
      if (!mounted) return;
      setState(() {
        _chosen = before;
        _busy = false;
      });
      showAccountSnack(context, AppStrings.settingsSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base1,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.s, 10.s, 20.s, 24.s),
              child: Row(
                children: [
                  const GTubeBackButton(size: 24, box: 24),
                  SizedBox(width: 12.s),
                  Text(
                    AppStrings.settingsLanguage,
                    style: AppStyles.label(
                      18,
                      weight: AppStyles.bold,
                      lineHeight: 28 / 18,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 20.s),
                children: [
                  _Option(
                    label: AppStrings.languageDevice,
                    note: AppStrings.languageDeviceNote,
                    selected: _chosen == null,
                    onTap: () => unawaited(_choose(null)),
                  ),
                  for (final (code, label) in _languages)
                    _Option(
                      label: label,
                      selected: _chosen == code,
                      onTap: () => unawaited(_choose(code)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.selected,
    required this.onTap,
    this.note,
  });

  final String label;
  final String? note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('language-$label'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.s),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.neutral900)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: AppStyles.label(14)),
                  if (note case final line?) ...[
                    SizedBox(height: 3.s),
                    Text(
                      line,
                      style: AppStyles.label(
                        12,
                        color: AppColors.neutral500,
                        lineHeight: 16 / 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check, size: 18.s, color: AppColors.brandPrimary),
          ],
        ),
      ),
    );
  }
}
