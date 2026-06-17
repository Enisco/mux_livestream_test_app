import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_strings.dart';
import '../core/app_styles.dart';
import '../services/video_scanner_service.dart';
import '../widgets/home/empty_state_view.dart';
import '../widgets/home/permission_request_view.dart';
import '../widgets/home/video_card.dart';
import 'player_screen.dart';

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
    // Re-check whenever the user returns to the app from a permission-blocked state
    // (e.g. after granting access in device Settings).
    if (state == AppLifecycleState.resumed &&
        (_phase == _Phase.permissionDenied ||
            _phase == _Phase.permissionNeeded)) {
      _initScan();
    }
  }

  // ── Scanning logic ──────────────────────────────────────────────────────────

  Future<void> _initScan() async {
    setState(() => _phase = _Phase.loading);
    final permission = await _scanner.checkPermission();
    switch (permission) {
      case ScanPermission.granted:
        await _runScan();
      case ScanPermission.denied:
        // Not yet asked — show the system dialog immediately.
        setState(() => _phase = _Phase.permissionNeeded);
      case ScanPermission.permanentlyDenied:
        setState(() => _phase = _Phase.permissionDenied);
    }
  }

  Future<void> _requestPermission() async {
    setState(() => _phase = _Phase.loading);
    final result = await _scanner.requestPermission();
    if (result == ScanPermission.granted) {
      await _runScan();
    } else {
      setState(() => _phase = _Phase.permissionDenied);
    }
  }

  Future<void> _runScan() async {
    setState(() => _phase = _Phase.loading);
    final found = await _scanner.scan();
    final merged = <String>{..._videos, ...found}.toList()..sort();
    setState(() {
      _videos
        ..clear()
        ..addAll(merged);
      _phase = _Phase.done;
    });
  }

  // ── Manual file picker ───────────────────────────────────────────────────────

  Future<void> _pickVideos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() {
      for (final f in result.files) {
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

  // ── Build ────────────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.fromLTRB(
        16.0,
        8.0,
        16.0,
        100,
      ),
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
    // Hide FAB while loading or showing permission screens.
    if (_phase == _Phase.loading) return null;
    return FloatingActionButton(
      onPressed: _pickVideos,
      tooltip: AppStrings.addVideos,
      child: const Icon(Icons.add_rounded),
    );
  }
}

// ── Private loading widget ────────────────────────────────────────────────────

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
