abstract final class AppStrings {
  static const appTitle = 'GTube';

  // Home – library
  static const addVideos = 'Add Video';
  static const noVideosTitle = 'No videos found';
  static const noVideosSubtitle = 'No video files were found.\nTap + to open a specific file.';

  // Home – scanning
  static const scanningVideos = 'Scanning for videos…';

  // Home – permission
  static const permissionTitle = 'Media Access Required';
  static const permissionBody =
      'Allow GTube to scan your device for video files,\njust like VLC or MX Player.';
  static const permissionDeniedBody =
      'Permission was denied. Open Settings to enable\nmedia access for GTube.';
  static const grantAccess = 'Grant Access';
  static const openSettings = 'Open Settings';

  // Player
  static const loadingVideo = 'Loading video…';
  static const failedToLoad = 'Failed to load video';
  static const goBack = 'Go Back';
  static const tooltipVolume = 'Volume';
  static const tooltipFullscreen = 'Fullscreen (F)';
  static const tooltipExitFullscreen = 'Exit fullscreen (F)';

  // Landing
  static const landingSubtitle = 'Choose how to watch';
  static const featureGallery = 'My Videos';
  static const featureGalleryDesc = 'Browse videos stored on your device';
  static const featureOnlineVideo = 'Online Video';
  static const featureOnlineVideoDesc = 'Play any public video or YouTube link';
  static const featureStartLive = 'Go Live';
  static const featureStartLiveDesc = 'Stream your camera live via Mux';
  static const featureJoinLive = 'Join Stream';
  static const featureJoinLiveDesc = 'Watch an ongoing Mux livestream';

  // Online video
  static const onlineVideoTitle = 'Online Video';
  static const videoUrlHint = 'Paste a video URL or YouTube link…';
  static const playVideo = 'Play Video';
  static const invalidUrl = 'Please enter a valid URL';

  // YouTube player
  static const youtubePlayerTitle = 'YouTube';

  // Start livestream
  static const startLiveTitle = 'Go Live';
  static const cameraPermNeeded = 'Camera & Microphone Access Required';
  static const cameraPermBody =
      'GTube needs camera and microphone access\nto stream live video.';
  static const cameraPermDeniedBody =
      'Camera access was denied. Open Settings to\nenable camera for GTube.';
  static const creatingStream = 'Creating stream…';
  static const goLive = 'Go Live';
  static const rtmpUrl = 'RTMP URL';
  static const streamKey = 'Stream Key';
  static const playbackUrl = 'Playback URL';
  static const watchStream = 'Watch Your Stream';
  static const endStream = 'End Stream';
  static const copied = 'Copied!';
  static const startStreaming = 'Start Streaming';
  static const stopStreaming = 'Stop Streaming';
  static const endingStream = 'Ending stream…';
  static const streamStatus = 'Stream Status';
  static const statusIdle = 'Idle';
  static const statusActive = 'Active';
  static const showStreamKey = 'Show';
  static const hideStreamKey = 'Hide';

  // Join livestream
  static const joinLiveTitle = 'Join Stream';
  static const playbackIdHint = 'Enter Mux Playback ID or stream URL…';
  static const joinStream = 'Join Stream';
  static const invalidPlaybackId = 'Please enter a valid Playback ID';

  // Dynamic helpers
  static String filesCount(int n) => '$n file${n == 1 ? '' : 's'}';
}
