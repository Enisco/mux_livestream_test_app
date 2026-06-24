abstract final class AppStrings {
  static const appTitle = 'GTube';

  // Home – library
  static const addVideos = 'Add Video';
  static const noVideosTitle = 'No videos found';
  static const noVideosSubtitle =
      'No video files were found.\nTap + to open a specific file.';

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
  static const streamNotLive = 'Stream is not live yet';
  static const streamNotLiveDesc =
      'The stream hasn\'t started. Try again in a moment.';
  static const goBack = 'Go Back';
  static const tooltipVolume = 'Volume';
  static const tooltipFullscreen = 'Fullscreen (F)';
  static const tooltipExitFullscreen = 'Exit fullscreen (F)';

  // Landing
  static const landingSubtitle = 'Choose how to watch';
  static const featureGallery = 'My Videos';
  static const featureGalleryDesc = 'Browse videos stored on your device';
  static const featureStartLiveDesc = 'Stream your camera live via Mux';
  static const featureJoinLiveDesc = 'Watch an ongoing Mux livestream';

  // Auth
  static const signIn = 'Sign In';
  static const createAccount = 'Create Account';
  static const email = 'Email';
  static const password = 'Password';

  // Start livestream
  static const cameraPermNeeded = 'Camera & Microphone Access Required';
  static const cameraPermBody =
      'GTube needs camera and microphone access\nto stream live video.';
  static const cameraPermDeniedBody =
      'Camera access was denied. Open Settings to\nenable camera for GTube.';
  static const creatingStream = 'Creating stream…';
  static const goLive = 'Go Live';
  static const rtmpUrl = 'RTMP URL';
  static const streamKey = 'Stream Key';
  static const streamId = 'Stream ID';
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
  static const joinStream = 'Join Stream';
  static const streamIdHint = 'Enter Stream ID or Playback URL…';
  static const streamIdInvalid = 'Please enter a valid Stream ID';
  static const notLiveError = 'This creator is not live right now';
  static const fetchingUrl = 'Fetching…';
  static const noMediaIdError = 'Stream not ready — playback token unavailable';

  // Dynamic helpers
  static String filesCount(int n) => '$n file${n == 1 ? '' : 's'}';
}
