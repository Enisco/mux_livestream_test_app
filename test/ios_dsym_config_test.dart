import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A dSYM in the archive for every framework that does not bring one.
///
/// App Store Connect answered an upload with eighteen "Upload Symbols
/// Failed" warnings, one per framework `media_kit_libs_ios_video` vendors:
/// the libmpv and FFmpeg stack arrives as prebuilt, already-stripped
/// `.xcframework` slices with no DWARF and no `.dSYM` beside them, so
/// Xcode has nothing to collect and the archive goes up incomplete.
///
/// `dsymutil` writes a bundle carrying the binary's UUID even when there
/// is no debug info to put in it, which is what the check asks for. The
/// alternative — unchecking "Upload your app's symbols" — would have cost
/// the app's own symbols too.
///
/// Nothing about this can be caught by running the app: it is a build
/// phase, a shell script and an archive, so it is read off disk here.
String get _pbxproj =>
    File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

final _script = File('ios/scripts/vendored_framework_dsyms.sh');

/// One of the stripped binaries, used as a stand-in for the real thing.
/// Only there after `flutter pub get`, so the tests that need it say so.
final _vendored = File(
  'ios/.symlinks/plugins/media_kit_libs_ios_video/ios/Frameworks/'
  'Ass.xcframework/ios-arm64/Ass.framework/Ass',
);

/// Why these cannot run here, if they cannot: `dsymutil` is Apple's, and
/// the stripped binary they read arrives with `flutter pub get`.
String? get _cannotRun => !Platform.isMacOS
    ? 'dsymutil and the vendored frameworks are macOS-only'
    : !_vendored.existsSync()
    ? 'needs flutter pub get: ${_vendored.path}'
    : null;

/// The entries of the Runner target's `buildPhases`, in order.
List<String> _runnerPhases() {
  final target = RegExp(
    r'97C146ED1CF9000F007C117D /\* Runner \*/ = \{(.*?)\n\t\t\};',
    dotAll: true,
  ).firstMatch(_pbxproj);
  expect(target, isNotNull, reason: 'the Runner native target');

  final list = RegExp(
    r'buildPhases = \((.*?)\);',
    dotAll: true,
  ).firstMatch(target!.group(1)!);
  expect(list, isNotNull, reason: "Runner's build phases");

  return list!
      .group(1)!
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
}

/// A throwaway `Runner.app/Frameworks` holding [names], each a copy of the
/// stripped vendored binary, plus the dSYM folder Xcode would hand over.
Directory _fakeBuild(List<String> names) {
  final root = Directory.systemTemp.createTempSync('dsym-phase');
  addTearDown(() => root.deleteSync(recursive: true));
  Directory('${root.path}/dsyms').createSync();
  for (final name in names) {
    final dir = Directory(
      '${root.path}/build/Runner.app/Frameworks/'
      '$name.framework',
    );
    dir.createSync(recursive: true);
    _vendored.copySync('${dir.path}/$name');
  }
  return root;
}

ProcessResult _runPhase(Directory root, {required String format}) {
  return Process.runSync(
    'bash',
    ['ios/scripts/vendored_framework_dsyms.sh'],
    environment: {
      'DEBUG_INFORMATION_FORMAT': format,
      'TARGET_BUILD_DIR': '${root.path}/build',
      'FRAMEWORKS_FOLDER_PATH': 'Runner.app/Frameworks',
      'DWARF_DSYM_FOLDER_PATH': '${root.path}/dsyms',
    },
  );
}

String? _uuidOf(String path) {
  final out = Process.runSync('dwarfdump', ['--uuid', path]).stdout as String;
  return RegExp(r'UUID: ([0-9A-F-]{36})').firstMatch(out)?.group(1);
}

void main() {
  group('the dSYM build phase is wired into the archive', () {
    test('the generator script is there, and runnable', () {
      expect(_script.existsSync(), isTrue, reason: _script.path);
      // A phase whose script is not executable fails the archive.
      final mode = _script.statSync().mode;
      expect(mode & 0x40, isNot(0), reason: 'owner-executable bit');
    });

    test('and the Runner target runs it', () {
      final phase = RegExp(
        r'/\* Generate dSYMs for prebuilt frameworks \*/ = \{(.*?)\n\t\t\};',
        dotAll: true,
      ).firstMatch(_pbxproj);
      expect(phase, isNotNull, reason: 'the shell script build phase');
      expect(phase!.group(1), contains('vendored_framework_dsyms.sh'));
      // It declares no inputs or outputs, so Xcode would otherwise decide
      // it is up to date and skip it.
      expect(phase.group(1), contains('alwaysOutOfDate = 1'));
    });

    test('after the frameworks it reads have been embedded', () {
      // The frameworks are read out of the built app bundle, so a phase
      // ahead of the one that puts them there sees an empty folder. This
      // is the ordering a `pod install` could disturb.
      final phases = _runnerPhases();
      final embed = phases.indexWhere(
        (p) => p.contains('Embed Pods Frameworks'),
      );
      final generate = phases.indexWhere((p) => p.contains('Generate dSYMs'));
      expect(embed, isNonNegative);
      expect(generate, greaterThan(embed));
      expect(generate, phases.length - 1, reason: 'it runs last');
    });
  });

  group('what the phase does', () {
    test('a dSYM per framework, carrying the binary UUID Apple asked for', () {
      final root = _fakeBuild(['Ass', 'Mpv']);
      final result = _runPhase(root, format: 'dwarf-with-dsym');

      expect(result.exitCode, 0, reason: result.stderr.toString());
      for (final name in ['Ass', 'Mpv']) {
        final dsym = '${root.path}/dsyms/$name.framework.dSYM';
        expect(Directory(dsym).existsSync(), isTrue, reason: dsym);
        expect(
          _uuidOf(dsym),
          _uuidOf(
            '${root.path}/build/Runner.app/Frameworks/'
            '$name.framework/$name',
          ),
          reason:
              'the UUID is the whole point: a dSYM under the right '
              'name but a different UUID is still a failed upload',
        );
      }
    });

    test("and it does not touch Flutter's own two", () {
      // App.framework's dSYM holds the only symbols that matter, and
      // Flutter's phase may run either side of this one.
      final root = _fakeBuild(['App', 'Flutter', 'Ass']);
      _runPhase(root, format: 'dwarf-with-dsym');

      final made = Directory('${root.path}/dsyms')
          .listSync()
          .map((e) => e.path.split(Platform.pathSeparator).last)
          .toList();
      expect(made, ['Ass.framework.dSYM']);
    });

    test('a dSYM already there is left alone', () {
      // A pod Xcode builds from source already has a real dSYM in this
      // folder. Replacing one with a stub would lose symbols the archive
      // was carrying, which is worse than the warning being fixed here.
      final root = _fakeBuild(['Ass']);
      final dwarf = File(
        '${root.path}/dsyms/Ass.framework.dSYM/Contents/Resources/DWARF/Ass',
      )..createSync(recursive: true);
      dwarf.writeAsStringSync('the real symbols');

      final result = _runPhase(root, format: 'dwarf-with-dsym');

      // The count, not just the file: dsymutil writes into a bundle that
      // already exists without clearing it out, so an untouched file left
      // beside its output does not prove anything was skipped.
      expect(result.stdout, contains('generated 0 dSYM(s)'));
      expect(dwarf.readAsStringSync(), 'the real symbols');
    });

    test('and a debug build is not slowed down by any of it', () {
      final root = _fakeBuild(['Ass']);
      final result = _runPhase(root, format: 'dwarf');

      expect(result.exitCode, 0);
      expect(Directory('${root.path}/dsyms').listSync(), isEmpty);
    });

    test('dsymutil is not allowed to fill the build log', () {
      // Mpv.framework kept its debug map while the object files it names
      // stayed on whoever built libmpv, so dsymutil reports every one as
      // unreadable — hundreds of lines Xcode would promote into the
      // build's warning list, burying anything real.
      final root = _fakeBuild(['Ass', 'Mpv']);
      final result = _runPhase(root, format: 'dwarf-with-dsym');
      final lines = (result.stdout as String)
          .split('\n')
          .where((l) => l.trim().isNotEmpty);

      expect(lines, hasLength(1));
      expect(lines.first, startsWith('note:'));
      expect(result.stderr, isEmpty);
    });
  }, skip: _cannotRun);
}
