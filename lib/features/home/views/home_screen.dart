import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/home/views/widgets/empty_state_view.dart';
import 'package:test_app/features/home/views/widgets/permission_request_view.dart';
import 'package:test_app/features/home/views/widgets/video_card.dart';
import 'package:test_app/features/player/views/player_screen.dart';
import 'package:test_app/shared/services/video_scanner_service.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

enum _Phase { loading, permissionNeeded, permissionDenied, done }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _scanner = VideoScannerService();
  final List<String> _videos = [];
  _Phase _phase = _Phase.loading;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScan();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (_phase == _Phase.permissionDenied ||
            _phase == _Phase.permissionNeeded)) {
      _initScan();
    }
  }

  Future<void> _initScan() async {
    setState(() => _phase = _Phase.loading);
    final permission = await _scanner.checkPermission();
    switch (permission) {
      case ScanPermission.granted:
        await _runScan();
      case ScanPermission.denied:
        setState(() => _phase = _Phase.permissionNeeded);
      case ScanPermission.permanentlyDenied:
        setState(() => _phase = _Phase.permissionDenied);
    }
  }

  Future<void> _requestPermission() async {
    setState(() => _phase = _Phase.loading);
    switch (await _scanner.requestPermission()) {
      case ScanPermission.granted:
        await _runScan();
      // Refused once is not refused for good: the system will ask again, so
      // the view keeps its "Grant access" button rather than sending the
      // reader to Settings over a question they can still be asked.
      case ScanPermission.denied:
        if (mounted) setState(() => _phase = _Phase.permissionNeeded);
      case ScanPermission.permanentlyDenied:
        if (mounted) setState(() => _phase = _Phase.permissionDenied);
    }
  }

  Future<void> _runScan() async {
    setState(() => _phase = _Phase.loading);
    List<String> found;
    try {
      found = await _scanner.scan();
    } catch (e) {
      // A library the platform will not enumerate — access revoked while the
      // screen was up, a provider that failed. An empty list is the honest
      // answer; an exception here would take the whole screen down.
      logger.w('Could not scan for videos', error: e);
      found = const [];
    }
    if (!mounted) return;
    final merged = <String>{..._videos, ...found}.toList()..sort();
    setState(() {
      _videos
        ..clear()
        ..addAll(merged);
      _phase = _Phase.done;
    });
  }

  Future<void> _pickVideos() async {
    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
      );
    } catch (e) {
      // `pickFiles` rethrows whatever the platform raised; unhandled, that
      // is a crash where a sentence will do.
      logger.w('Video picker failed', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.pickerUnavailable)),
        );
      }
      return;
    }
    if (result == null || !mounted) return;
    setState(() {
      for (final f in result!.files) {
        if (f.path != null && !_videos.contains(f.path)) {
          _videos.add(f.path!);
        }
      }
    });
  }

  void _openVideo(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen.file(filePath: path)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showList = _phase == _Phase.done && _videos.isNotEmpty;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _runScan,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(),
            if (_phase == _Phase.loading)
              const SliverFillRemaining(child: _ScanLoadingView())
            else if (_phase == _Phase.permissionNeeded)
              SliverFillRemaining(
                child: PermissionRequestView(
                  isPermanentlyDenied: false,
                  onPrimaryAction: _requestPermission,
                ),
              )
            else if (_phase == _Phase.permissionDenied)
              SliverFillRemaining(
                child: PermissionRequestView(
                  isPermanentlyDenied: true,
                  onPrimaryAction: _scanner.openSettings,
                ),
              )
            else if (!showList)
              const SliverFillRemaining(child: EmptyStateView())
            else
              _buildVideoList(),
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,

      flexibleSpace: FlexibleSpaceBar(
        title: Text(AppStrings.appTitle, style: AppStyles.appBarTitle),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.surface, AppColors.background],
            ),
          ),
        ),
      ),
      actions: [
        if (_phase == _Phase.done && _videos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: Text(
                AppStrings.filesCount(_videos.length),
                style: AppStyles.fileCount,
              ),
            ),
          ),
      ],
    );
  }

  SliverPadding _buildVideoList() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0 + 2),
            child: VideoCard(
              filePath: _videos[i],
              onTap: () => _openVideo(_videos[i]),
            ),
          ),
          childCount: _videos.length,
        ),
      ),
    );
  }

  Widget? _buildFab() {
    if (_phase == _Phase.loading) return null;
    return FloatingActionButton(
      onPressed: _pickVideos,
      tooltip: AppStrings.addVideos,
      child: const Icon(Icons.add_rounded),
    );
  }
}

class _ScanLoadingView extends StatelessWidget {
  const _ScanLoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16.0),
          Text(AppStrings.scanningVideos, style: AppStyles.loadingLabel),
        ],
      ),
    );
  }
}
