#!/bin/bash
#
# A dSYM for every embedded framework that does not bring its own.
#
# App Store Connect's symbol upload answers one "Upload Symbols Failed"
# warning per embedded framework whose dSYM is missing from the archive.
# Eighteen of them come from `media_kit_libs_ios_video`: the libmpv and
# FFmpeg stack (Mpv, Avcodec, Avfilter, Avformat, Avutil, Swscale,
# Swresample, Ass, Dav1d, Freetype, Fribidi, Harfbuzz, Png16, Uchardet,
# Xml2, Mbedtls, Mbedcrypto, Mbedx509) arrives as prebuilt `.xcframework`
# slices that are already stripped — `otool -l` shows no `__DWARF` segment
# and no `.dSYM` ships beside them — so Xcode has nothing to collect.
#
# `dsymutil` warns "no debug symbols in executable" on such a binary but
# still writes a bundle carrying its UUID, which is the whole of what the
# check is asking for. So the warnings go away and the app's own symbols
# keep being uploaded, which is what unchecking "Upload your app's symbols"
# would have cost. No stub can make those frames symbolize: the debug info
# does not exist upstream, and this neither pretends otherwise nor hides it.
#
# Deliberately not failing the build: a missing dSYM is cosmetic, and an
# archive is a bad moment to discover that. Everything that goes wrong is
# reported as a `warning:` so it shows up in Xcode's issue list.
#
# Run as the LAST build phase, after "[CP] Embed Pods Frameworks" — the
# frameworks have to be in the bundle before they can be read.

set -uo pipefail

note() { echo "note: $(basename "$0"): $*"; }
warn() { echo "warning: $(basename "$0"): $*"; }

# Only an archive carries dSYMs. A debug build is told to keep its debug
# info in the object files, and running this on every incremental build
# would cost eighteen `dsymutil` invocations for nothing.
if [[ "${DEBUG_INFORMATION_FORMAT:-}" != "dwarf-with-dsym" ]]; then
  note "DEBUG_INFORMATION_FORMAT is '${DEBUG_INFORMATION_FORMAT:-unset}', not dwarf-with-dsym; nothing to do"
  exit 0
fi

if [[ -z "${TARGET_BUILD_DIR:-}" || -z "${FRAMEWORKS_FOLDER_PATH:-}" || -z "${DWARF_DSYM_FOLDER_PATH:-}" ]]; then
  warn "TARGET_BUILD_DIR, FRAMEWORKS_FOLDER_PATH or DWARF_DSYM_FOLDER_PATH is unset; skipping"
  exit 0
fi

frameworks="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
dsyms="${DWARF_DSYM_FOLDER_PATH}"

if [[ ! -d "$frameworks" ]]; then
  # Either the app embeds no frameworks, or this phase has been moved
  # ahead of the one that embeds them. Both are worth seeing in the log.
  warn "no embedded frameworks at $frameworks; this phase must run after [CP] Embed Pods Frameworks"
  exit 0
fi

mkdir -p "$dsyms" || { warn "could not create $dsyms"; exit 0; }

shopt -s nullglob
made=0
quiet=0
for framework in "$frameworks"/*.framework; do
  name="$(basename "$framework" .framework)"

  # Flutter builds and collects these two itself, and its own phase may run
  # either side of this one. Writing a stub over the real App.framework
  # dSYM would throw away the only symbols that matter.
  case "$name" in
    App | Flutter) continue ;;
  esac

  binary="$framework/$name"
  [[ -f "$binary" ]] || continue

  # Anything that brought, or had generated, a real dSYM keeps it: a pod
  # built from source is already covered by Xcode.
  [[ -e "$dsyms/$name.framework.dSYM" ]] && continue

  # dsymutil's own output is captured rather than let through. It writes
  # "warning:" lines, which Xcode promotes into the build's warning list,
  # and Mpv.framework alone produces thousands of them: it kept its debug
  # map (`N_OSO` entries) while the object files it points at stayed on
  # whoever's CI built libmpv, so every one is reported as unreadable.
  # Nothing here is actionable, and burying real warnings under them is a
  # worse outcome than the warning this script exists to remove. On a
  # failure the output is printed, as notes, because then it is the
  # explanation.
  if log="$(dsymutil "$binary" -o "$dsyms/$name.framework.dSYM" 2>&1)"; then
    made=$((made + 1))
    quiet=$((quiet + $(printf '%s' "$log" | grep -c . || true)))
  else
    warn "could not generate a dSYM for $name.framework"
    printf '%s\n' "$log" | sed 's/^/note: /'
  fi
done

note "generated $made dSYM(s) into $dsyms ($quiet dsymutil message(s) suppressed)"
