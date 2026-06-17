import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../core/app_colors.dart';
import '../core/app_strings.dart';
import 'player_screen.dart';
import 'youtube_player_screen.dart';

class OnlineVideoScreen extends StatefulWidget {
  const OnlineVideoScreen({super.key});

  @override
  State<OnlineVideoScreen> createState() => _OnlineVideoScreenState();
}

class _OnlineVideoScreenState extends State<OnlineVideoScreen> {
  final _urlController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _play() {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = AppStrings.invalidUrl);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme.isEmpty || !uri.isAbsolute) {
      setState(() => _error = AppStrings.invalidUrl);
      return;
    }
    setState(() => _error = null);

    final youtubeId = YoutubePlayer.convertUrlToId(url);
    if (youtubeId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => YoutubePlayerScreen(videoId: youtubeId),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen.network(networkUrl: url),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.onlineVideoTitle),
        backgroundColor: AppColors.background,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.link_rounded, size: 56, color: AppColors.primary),
            const SizedBox(height: 32),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: AppStrings.videoUrlHint,
                prefixIcon: const Icon(Icons.link_rounded),
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
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _play(),
              autofocus: true,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _play,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(AppStrings.playVideo),
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
