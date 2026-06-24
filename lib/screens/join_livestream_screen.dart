import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_strings.dart';
import '../core/mux_config.dart';
import 'player_screen.dart';

class JoinLivestreamScreen extends StatefulWidget {
  const JoinLivestreamScreen({super.key});

  @override
  State<JoinLivestreamScreen> createState() => _JoinLivestreamScreenState();
}

class _JoinLivestreamScreenState extends State<JoinLivestreamScreen> {
  final _idController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  String? _extractPlaybackId(String input) {
    final muxUrlMatch = RegExp(r'stream\.mux\.com/([^./?]+)').firstMatch(input);
    if (muxUrlMatch != null) return muxUrlMatch.group(1);
    if (RegExp(r'^[a-zA-Z0-9]{8,}$').hasMatch(input)) return input;
    return null;
  }

  void _join() {
    final input = _idController.text.trim();
    if (input.isEmpty) {
      setState(() => _error = AppStrings.invalidPlaybackId);
      return;
    }
    final playbackId = _extractPlaybackId(input);
    if (playbackId == null) {
      setState(() => _error = AppStrings.invalidPlaybackId);
      return;
    }
    setState(() => _error = null);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PlayerScreen.network(networkUrl: MuxConfig.hlsUrl(playbackId)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.joinStream),
        backgroundColor: AppColors.background,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.cast_rounded, size: 56, color: AppColors.primary),
            const SizedBox(height: 32),
            TextField(
              controller: _idController,
              decoration: InputDecoration(
                hintText: AppStrings.playbackIdHint,
                prefixIcon: const Icon(Icons.live_tv_rounded),
                errorText: _error,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
              ),
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _join(),
              autofocus: true,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _join,
              icon: const Icon(Icons.cast_rounded),
              label: const Text(AppStrings.joinStream),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
