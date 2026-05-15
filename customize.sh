#!/sbin/sh
#############################################################################################################
# ThemeCenter Universal Patch — customize.sh
# Format: Standard Magisk/KernelSU/APatch module
# Original logic by @BlassGO (DynamicInstaller) - Modified by @Benj2557 for Magisk/KSU/Apatch compatibility
# Converted to standard format — tools extracted from META-INF/zbin/
#############################################################################################################

# Signal to the root manager that we handle extraction ourselves
SKIPUNZIP=1

# module.prop MUST be in $MODPATH — KernelSU/APatch require it even with SKIPUNZIP=1
unzip -o "$ZIPFILE" module.prop -d "$MODPATH" >/dev/null 2>&1 \
  || abort "! Failed to extract module.prop into MODPATH"

##############################################################################
# 1 ── Extract and set up the embedded ARM tool suite (apktool, aapt, etc.)
##############################################################################

ui_print " "
ui_print " -- Setting up embedded tools..."

ZBIN="$TMPDIR/zbin_raw"
TOOLS="$TMPDIR/di_tools"
mkdir -p "$ZBIN" "$TOOLS"

# Extract the three required entries from the zip
for entry in META-INF/zbin/busybox META-INF/zbin/bash META-INF/zbin/bin; do
  unzip -o "$ZIPFILE" "$entry" -d "$ZBIN" >/dev/null 2>&1 \
    || abort "! Failed to extract $entry"
done

BB="$ZBIN/META-INF/zbin/busybox"
BS="$ZBIN/META-INF/zbin/bash"
chmod +x "$BB" "$BS"

# Set up busybox symlinks so standard commands are available
"$BB" --install -s "$TOOLS" 2>/dev/null || {
  for cmd in $("$BB" --list 2>/dev/null); do
    ln -sf "$BB" "$TOOLS/$cmd" 2>/dev/null || true
  done
}

export PATH="$TOOLS:$PATH"

# Decompress the xz tool bundle (contains apktool.jar, aapt, zipalign, …)
cp "$ZBIN/META-INF/zbin/bin" "$TMPDIR/bin.xz"
xz -d "$TMPDIR/bin.xz" 2>/dev/null || abort "! Failed to decompress tool bundle (bin.xz)"
[ -f "$TMPDIR/bin" ] || abort "! Tool bundle not found after decompression"

unzip -qo "$TMPDIR/bin" -d "$TMPDIR/zbin_tools" >/dev/null 2>&1
find "$TMPDIR/zbin_tools" -type f -exec mv -f {} "$TOOLS/" \;
find "$TOOLS" -type f -exec chmod 777 {} +

# l is the DynamicInstaller convention for the tools directory
export l="$TOOLS"

ui_print " -- Tools ready ($(ls "$TOOLS" | wc -l | tr -d ' ') binaries)"

##############################################################################
# 2 ── Helper functions (ported from DynamicInstaller core)
##############################################################################

# defined VAR — true if variable is non-empty
defined() {
  eval _val=\"\$$1\"
  [ -n "$_val" ]
}

# find_apk PACKAGE SEARCH_DIR — prints the path of the APK matching the package name
find_apk() {
  local pkg="$1" dir="$2"
  aapt version >/dev/null 2>&1 || { ui_print "! aapt not available"; return 1; }
  find "$dir" -type f -name "*.apk" 2>/dev/null | while read -r apk; do
    local p
    p=$(aapt dump badging "$apk" 2>/dev/null | sed -n "s/.*package: name='\([^']*\)'.*/\1/p")
    [ "$p" = "$pkg" ] && echo "$apk" && return
  done
}

# apktool ARGS — thin wrapper using dalvikvm + the embedded apktool.jar
apktool() {
  [ -f "$l/apktool.jar" ] || abort "! apktool.jar not found in tool suite"
  # Copy framework-res so apktool can decode resources
  [ -f /system/framework/framework-res.apk ] \
    && cp -f /system/framework/framework-res.apk "$TMPDIR/1.apk" 2>/dev/null
  # Try new dalvikvm flag set first, fall back to older
  dalvikvm -Djava.io.tmpdir=. -Xnodex2oat -Xnoimage-dex2oat \
      -cp "$l/apktool.jar" brut.apktool.Main \
      --aapt "$l/aapt" -p "$TMPDIR" "$@" 2>/dev/null \
    || dalvikvm -Djava.io.tmpdir=. -Xnoimage-dex2oat \
      -cp "$l/apktool.jar" brut.apktool.Main \
      --aapt "$l/aapt" -p "$TMPDIR" "$@"
}

# smali_kit -c -m METHOD_NAME -remake NEW_BODY -d SMALI_DIR
# Replaces the body of every non-abstract method matching METHOD_NAME.
smali_kit() {
  local path="" method="" remake="" check=0 flag
  # Parse arguments
  while [ $# -gt 0 ]; do
    flag="$1"
    case "$flag" in
      -f|-file)       shift 2 ;;   # single-file mode not used here
      -d|-dir)        path="$2";   shift 2 ;;
      -m|-method)     method="$2"; shift 2 ;;
      -re|-remake)    remake="$2"; shift 2 ;;
      -c|-check)      check=1;     shift ;;
      *)              shift ;;
    esac
  done
  [ -z "$path" ] || [ -z "$method" ] && { ui_print "! smali_kit: -d and -m are required"; return 1; }

  grep -rnw "$path" -e "$method" 2>/dev/null | while IFS=: read -r smali_file line_no liner; do
    # Only target .method declarations (not abstract)
    echo "$liner" | grep -q "\.method" || continue
    echo "$liner" | grep -q "abstract"  && continue

    local escaped_liner old_block new_block file_content
    escaped_liner=$(echo "$liner" | sed -e 's/[]\/$*.^[]/\\&/g')

    old_block=$(sed -n "/$escaped_liner/,/\.end method/p" "$smali_file")
    [ -z "$old_block" ] && continue

    if [ -n "$remake" ]; then
      new_block=$(printf '%s\n%s\n.end method' "$liner" "$remake")
      file_content=$(cat "$smali_file")
      # Replace old block with new block
      echo "${file_content//$old_block/$new_block}" > "$smali_file"
    fi

    [ "$check" -eq 1 ] && ui_print "  Patched: $(basename "$smali_file") :: $method"
  done
}

##############################################################################
# 3 ── Module installation
##############################################################################

ui_print "-------------------------------------------------- "
ui_print " Universal ThemeCenter Patch for Samsung           "
ui_print "-------------------------------------------------- "
ui_print " by @BlassGO and @Benj2557     |   Version: 2.0    "
ui_print "-------------------------------------------------- "
ui_print " "

# ── Find ThemeCenter.apk ──────────────────────────────────────────────────────
ui_print " -- Finding ThemeCenter.apk "

stock_center=$(find_apk "com.samsung.android.themecenter" /system)

if defined stock_center; then
  ui_print "   Center: $stock_center "
  ui_print " "
else
  abort " Cant find ThemeCenter.apk — is this a Samsung device?"
fi

# Check that the APK is deodexed (must contain classes.dex)
if ! unzip -l "$stock_center" 2>/dev/null | grep -q classes.dex; then
  abort " ThemeCenter.apk is odexed — cannot patch without deodexed APK"
fi

mod_center="$MODPATH$stock_center"

# ── Smali stub: replaces a method body with an immediate return-void ──────────
dummy='
    .registers 5

    return-void
'

# ── Create the module overlay directory ──────────────────────────────────────
ui_print " -- Creating module overlay directory "
mkdir -p "$(dirname "$mod_center")"

# ── Decompile ─────────────────────────────────────────────────────────────────
ui_print " -- Decompiling ThemeCenter.apk (smali only)..."
apktool --no-res -f d "$stock_center" -o "$TMPDIR/center"
[ -d "$TMPDIR/center" ] || abort " ! Decompilation failed"
ui_print " "

# ── Patch ─────────────────────────────────────────────────────────────────────
ui_print " -- Patching smali methods..."
smali_kit -c -m "setTrialExpiredPackage" -remake "$dummy" -d "$TMPDIR/center"
smali_kit -c -m "setAlarm"               -remake "$dummy" -d "$TMPDIR/center"
ui_print " "

# ── Recompile ─────────────────────────────────────────────────────────────────
ui_print " -- Recompiling ThemeCenter.apk..."
apktool --copy-original -f b "$TMPDIR/center" -o "$TMPDIR/huh.apk"
[ -f "$TMPDIR/huh.apk" ] || abort " ! Recompilation produced no output"

# ── Align ─────────────────────────────────────────────────────────────────────
zipalign -f -v 4 "$TMPDIR/huh.apk" "$mod_center" >/dev/null 2>&1
[ -f "$mod_center" ] || abort " ! zipalign step failed"

# ── Verify ────────────────────────────────────────────────────────────────────
if ! unzip -l "$mod_center" 2>/dev/null | grep -q classes.dex; then
  abort " ! Output APK is invalid (missing classes.dex)"
fi

ui_print " "
ui_print " -- Done! Reboot to apply the patch."
ui_print " "
