#!/system/bin/sh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 Dracen-W
#
# Mali GPU userspace driver r49p1 for MT6768 / Mali-G52 (64-bit only).
# Sourced by Magisk's module installer; MODPATH, ui_print, abort, set_perm* come from Magisk.
# shellcheck disable=SC2034  # read by the Magisk installer
SKIPUNZIP=0

ALLOWED_PLATFORMS="mt6768"                 # edit only if your SoC is a sibling with the same Mali-G52
OLD_MODULE_ID="mali_gpu_driver_mt6768"     # an early, much broader build; must not coexist
VND=/vendor

ui_print " "
ui_print " Mali GPU driver r49p1 (experimental)"
ui_print " Target: MT6768 / Mali-G52, 64-bit only"
ui_print " REQUIRES the r49p1 kernel to be flashed first (see docs/KERNEL.md)"
ui_print " "

# 1) wrong SoC -> refuse
PLAT=$(getprop ro.board.platform)
case " $ALLOWED_PLATFORMS " in
  *" $PLAT "*) ;;
  *) ui_print "! ro.board.platform='$PLAT', expected: $ALLOWED_PLATFORMS"
     abort "! Refusing to install: wrong SoC" ;;
esac

# 2) the early broad module present -> refuse (both overlay the same files)
if [ -d "/data/adb/modules/$OLD_MODULE_ID" ]; then
  abort "! Remove module '$OLD_MODULE_ID' first (reboot after removing), then install this one"
fi

V=$MODPATH/system/vendor

# 3) AIDL libs: keep ours only if the device lacks the file, or already has an identical copy
#    (an identical copy is a previous install of this module showing through the overlay)
ui_print "- Checking bundled AIDL libs"
for f in android.hardware.graphics.common-V5-ndk.so android.hardware.common-V2-ndk.so; do
  if [ -f "$VND/lib64/$f" ] && ! cmp -s "$VND/lib64/$f" "$V/lib64/$f"; then
    rm -f "$V/lib64/$f"
    ui_print "   device already has lib64/$f -> using the device's own"
  else
    ui_print "   installing lib64/$f"
  fi
done

# 4) device libraries the driver still links against (informational only, never aborts)
ui_print "- Device libraries this driver still relies on (64-bit)"
for f in android.hardware.graphics.allocator-V2-ndk.so android.hardware.graphics.mapper@4.0.so \
         libgralloctypes.so libgralloctypes_mtk.so libgralloc_extra.so libgralloc_metadata.so \
         libged.so libgpu_aux.so libladder.so libion.so libdmabufheap.so libutilscallstack.so \
         libhidlbase.so libhardware.so; do
  if   [ -f "$V/lib64/$f" ];      then ui_print "   [bundled]  $f"
  elif [ -f "$VND/lib64/$f" ];    then ui_print "   [vendor]   $f"
  elif [ -f "/system/lib64/$f" ]; then ui_print "   [system]   $f  (not in /vendor: may be invisible to the vendor namespace)"
  else                                 ui_print "   [MISSING]  $f"
  fi
done

# 5) ARM driver properties. r49p1 builds its EGL config table from ro.vendor.arm.* properties and
#    aborts (bad_optional_access) if they are missing; older vendors do not define them.
#    Write each into system.prop only if the device has no value, or already has the same value
#    (the latter covers re-installing this module). A different device value is never overridden.
ui_print "- ARM EGL/gralloc properties (system.prop)"
PROPFILE=$MODPATH/system.prop
: > "$PROPFILE"
ADDED=0; SKIPPED=0
while IFS='=' read -r k v; do
  [ -z "$k" ] && continue
  cur=$(getprop "$k")
  if [ -z "$cur" ] || [ "$cur" = "$v" ]; then
    echo "$k=$v" >> "$PROPFILE"; ADDED=$((ADDED+1))
  else
    ui_print "   keeping device value: $k=$cur (ours: $v)"; SKIPPED=$((SKIPPED+1))
  fi
done < "$MODPATH/docs/arm_props.txt"
ui_print "   $ADDED properties added, $SKIPPED kept from the device"

# 6) permissions / SELinux labels
ui_print "- Setting permissions"
set_perm_recursive "$V" 0 0 0755 0644 u:object_r:vendor_file:s0
[ -d "$V/lib64/egl" ] && set_perm "$V/lib64/egl" 0 0 0755 u:object_r:same_process_hal_file:s0
find "$V/lib64" -type f -name '*.so' | while read -r f; do
  set_perm "$f" 0 0 0644 u:object_r:same_process_hal_file:s0
done
find "$V/etc/permissions" -type f -name '*.xml' | while read -r f; do
  set_perm "$f" 0 0 0644 u:object_r:vendor_configs_file:s0
done

ui_print " "
ui_print "- Done. Reboot."
ui_print "- If boot hangs (adb still works): adb shell su -c 'rm -rf /data/adb/modules/mali_r49p1_mt6768_slim' && reboot"
ui_print " "
