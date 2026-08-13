abstract final class MuxConfig {
  static const tokenId = 'YOUR_MUX_TOKEN_ID';
  static const tokenSecret = 'YOUR_MUX_TOKEN_SECRET';

  static const apiBase = 'https://api.mux.com';
  static const rtmpIngestBase = 'rtmp://global-live.mux.com:5222/live';
  static const whipBase = 'https://global-live.mux.com/app';

  static String hlsUrl(String playbackId) =>
      'https://stream.mux.com/$playbackId.m3u8';

  static String rtmpUrl(String streamKey) => '$rtmpIngestBase/$streamKey';

  static String whipUrl(String streamKey) => '$whipBase/$streamKey';
}
