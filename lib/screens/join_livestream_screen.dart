import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../core/app_colors.dart';
import '../core/app_strings.dart';
import '../core/logger.dart';
import '../features/creator/repo/creator_repo.dart';
import 'player_screen.dart';

class JoinLivestreamScreen extends StatefulWidget {
  const JoinLivestreamScreen({super.key});

  @override
  State<JoinLivestreamScreen> createState() => _JoinLivestreamScreenState();
}

class _JoinLivestreamScreenState extends State<JoinLivestreamScreen> {
  final _idController = TextEditingController();
  String? _error;
  bool _loading = false;
  String? _sessionId;

  String _clientSessionId() =>
      _sessionId ??= DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final creatorId = _idController.text.trim();
    if (creatorId.isEmpty) {
      setState(() => _error = AppStrings.streamIdInvalid);
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final repo = GetIt.instance<CreatorRepo>();

      final status = await repo.getCreatorLiveStatus(creatorId);
      if (!mounted) return;
      if (!status.isLive || status.mediaId == null) {
        setState(() => _error = AppStrings.notLiveError);
        return;
      }

      final token = await repo.getPlaybackToken(
        status.mediaId!,
        _clientSessionId(),
      );
      logger.i('JoinStream: opening player → ${token.hlsUrl}');

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen.network(networkUrl: token.hlsUrl),
        ),
      );
    } catch (e) {
      logger.e('JoinStream: failed', error: e);
      if (mounted) setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                hintText: AppStrings.streamIdHint,
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
              onPressed: _loading ? null : _join,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.cast_rounded),
              label: Text(
                _loading ? AppStrings.fetchingUrl : AppStrings.joinStream,
              ),
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
