import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/settings/data/two_factor_dummy_data.dart';
import 'package:test_app/features/settings/views/widgets/settings_form.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/shared/components/otp_code_field.dart';
import 'package:test_app/shared/components/otp_verification_view.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Turning on a second factor: what it is, the secret to add, the code that
/// proves it was added, and the state afterwards.
///
/// None of it is wired, and the gap is larger than a missing payload — see
/// [TwoFactorDummyData], which records that the spec's 2FA routes look like a
/// server-sent OTP rather than the authenticator app this flow describes.

void _report(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: AppStyles.body(13)),
      backgroundColor: AppColors.neutral800,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Step one: what a second factor buys, and which apps it works with.
class TwoFactorIntroScreen extends StatelessWidget {
  const TwoFactorIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsFormScaffold(
      title: AppStrings.twoFactorTitle,
      actionLabel: AppStrings.twoFactorSetup,
      onAction: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TwoFactorScanScreen()),
      ),
      children: [
        SizedBox(height: 8.s),
        const Center(child: _ShieldBadge()),
        SizedBox(height: 16.s),
        Text(
          AppStrings.twoFactorHeading,
          textAlign: TextAlign.center,
          style: AppStyles.heading(
            20,
            lineHeight: 28 / 20,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: 10.s),
        Text(
          AppStrings.twoFactorBody,
          textAlign: TextAlign.center,
          style: AppStyles.label(13, color: AppColors.neutral300),
        ),
        SizedBox(height: 24.s),
        _Card(
          child: Text(
            AppStrings.twoFactorApps,
            style: AppStyles.label(
              13,
              color: AppColors.neutral300,
              lineHeight: 20 / 13,
            ),
          ),
        ),
      ],
    );
  }
}

/// Step two: the secret, as a code to scan and as characters to type.
class TwoFactorScanScreen extends StatelessWidget {
  const TwoFactorScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsFormScaffold(
      title: AppStrings.twoFactorScanTitle,
      actionLabel: AppStrings.twoFactorAdded,
      onAction: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TwoFactorCodeScreen()),
      ),
      children: [
        Text(
          AppStrings.twoFactorScanBody,
          style: AppStyles.label(13, color: AppColors.neutral300),
        ),
        SizedBox(height: 10.s),
        const Center(child: _QrTile()),
        SizedBox(height: 10.s),
        Text(
          AppStrings.twoFactorHeading,
          textAlign: TextAlign.center,
          style: AppStyles.heading(
            20,
            lineHeight: 28 / 20,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: 10.s),
        Text(
          AppStrings.twoFactorBody,
          textAlign: TextAlign.center,
          style: AppStyles.label(13, color: AppColors.neutral300),
        ),
        SizedBox(height: 10.s),
        const Center(child: _SecretChip()),
      ],
    );
  }
}

/// Step three: the code the authenticator is showing right now, which is what
/// proves the secret actually made it across.
class TwoFactorCodeScreen extends StatefulWidget {
  const TwoFactorCodeScreen({super.key});

  @override
  State<TwoFactorCodeScreen> createState() => _TwoFactorCodeScreenState();
}

class _TwoFactorCodeScreenState extends State<TwoFactorCodeScreen> {
  final _code = TextEditingController();

  /// A TOTP code is generated on the phone, so there is nothing to resend —
  /// the design still offers it, which would mean issuing a fresh secret.
  static const _cooldown = 60;
  int _secondsLeft = _cooldown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsFormScaffold(
      title: AppStrings.twoFactorCodeTitle,
      actionLabel: AppStrings.twoFactorTurnOn,
      onAction: () {
        if (_code.text.length < 6) return;
        _report(context, AppStrings.twoFactorNotWired);
      },
      children: [
        Text(
          AppStrings.twoFactorCodeBody,
          style: AppStyles.label(13, color: AppColors.neutral300),
        ),
        SizedBox(height: 24.s),
        OtpCodeField(controller: _code, onCompleted: (_) => setState(() {})),
        SizedBox(height: 20.s),
        Center(
          child: OtpResendRow(
            secondsLeft: _secondsLeft,
            onResend: () =>
                _report(context, AppStrings.twoFactorResendNotWired),
          ),
        ),
      ],
    );
  }
}

/// The state afterwards: whether it is on, how to re-enrol, and what to do if
/// the phone with the authenticator is lost.
class TwoFactorManageScreen extends StatefulWidget {
  const TwoFactorManageScreen({super.key});

  @override
  State<TwoFactorManageScreen> createState() => _TwoFactorManageScreenState();
}

class _TwoFactorManageScreenState extends State<TwoFactorManageScreen> {
  bool _on = TwoFactorDummyData.enabled;

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
                  Flexible(
                    child: Text(
                      AppStrings.twoFactorTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyles.label(
                        18,
                        weight: AppStyles.bold,
                        lineHeight: 28 / 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 20.s),
                children: [
                  _Card(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _on
                                    ? AppStrings.twoFactorOn
                                    : AppStrings.twoFactorOff,
                                style: AppStyles.label(
                                  14,
                                  weight: AppStyles.bold,
                                ),
                              ),
                              SizedBox(height: 4.s),
                              Text(
                                // "Enabled Jun 9" contradicts a switch that
                                // is off, so it is only shown when it is on.
                                _on
                                    ? '${TwoFactorDummyData.enabledOn} · '
                                          '${TwoFactorDummyData.method}'
                                    : AppStrings.twoFactorOffSub,
                                style: AppStyles.label(
                                  12,
                                  color: AppColors.neutral500,
                                  lineHeight: 16 / 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _on,
                          activeThumbColor: AppColors.textPrimary,
                          activeTrackColor: AppColors.brandPrimary,
                          inactiveThumbColor: AppColors.neutral400,
                          inactiveTrackColor: AppColors.neutral800,
                          onChanged: (v) {
                            setState(() => _on = v);
                            _report(context, AppStrings.twoFactorNotWired);
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.s),
                  _Card(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppStrings.twoFactorRescan,
                                style: AppStyles.label(
                                  14,
                                  weight: AppStyles.bold,
                                ),
                              ),
                              SizedBox(height: 4.s),
                              Text(
                                AppStrings.twoFactorRescanSub,
                                style: AppStyles.label(
                                  12,
                                  color: AppColors.neutral500,
                                  lineHeight: 16 / 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 10.s),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TwoFactorScanScreen(),
                            ),
                          ),
                          child: Text(
                            AppStrings.twoFactorBeginSetup,
                            style: AppStyles.label(
                              12,
                              weight: AppStyles.bold,
                              color: AppColors.yellow600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.s, 0, 20.s, 20.s),
              child: _Card(
                child: Text.rich(
                  TextSpan(
                    style: AppStyles.label(
                      13,
                      color: AppColors.neutral300,
                      lineHeight: 20 / 13,
                    ),
                    children: [
                      TextSpan(
                        text: AppStrings.twoFactorLostPhoneLead,
                        style: AppStyles.label(
                          13,
                          weight: AppStyles.bold,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                      const TextSpan(text: AppStrings.twoFactorLostPhoneBody),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShieldBadge extends StatelessWidget {
  const _ShieldBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64.s,
      height: 64.s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brandPrimary.withValues(alpha: 0.15),
      ),
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedShieldUser,
          color: AppColors.brandPrimary,
          size: 28.s,
        ),
      ),
    );
  }
}

/// The provisioning code, on a white tile washed with brand colour — the
/// design bakes that wash into the image as an inset shadow.
class _QrTile extends StatelessWidget {
  const _QrTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 266.s,
      height: 266.s,
      padding: EdgeInsets.all(16.s),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(10.s),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              AppColors.brandPrimary.withValues(alpha: 0.16),
              AppColors.textPrimary,
            ),
            AppColors.textPrimary,
          ],
        ),
      ),
      child: QrImageView(
        data: TwoFactorDummyData.provisioningUri,
        version: QrVersions.auto,
        backgroundColor: Colors.transparent,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: AppColors.base1,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: AppColors.base1,
        ),
      ),
    );
  }
}

/// The same secret in characters, for anyone whose camera will not cooperate.
class _SecretChip extends StatelessWidget {
  const _SecretChip();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        await Clipboard.setData(
          const ClipboardData(text: TwoFactorDummyData.secret),
        );
      },
      child: Builder(
        builder: (context) => Container(
          padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 13.s),
          decoration: BoxDecoration(
            color: AppColors.fieldBg,
            borderRadius: BorderRadius.circular(11.s),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                TwoFactorDummyData.secret,
                style: AppStyles.label(13, color: AppColors.neutral300),
              ),
              SizedBox(width: 10.s),
              HugeIcon(
                icon: HugeIcons.strokeRoundedCopy01,
                color: AppColors.brandPrimary,
                size: 18.s,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The rounded plate the two-factor screens group things on.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.s),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(12.s),
      ),
      child: child,
    );
  }
}
