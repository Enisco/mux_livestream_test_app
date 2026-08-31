package com.gospeltube_app.gospeltube_mobile

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity, not FlutterActivity: the media session binds to the
// hosting activity, and a plain FlutterActivity leaves the notification's
// controls wired to nothing once the app is backgrounded.
class MainActivity : AudioServiceActivity()
