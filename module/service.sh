#!/system/bin/sh

MODDIR=${0%/*}

# Update module status
update_status() {
    local status_text="$1"
    local status_emoji="$2"
    local new_description="description=Reset the VBMeta digest property with the correct boot hash to fix detection. Status: $status_text $status_emoji"
    sed -i "s|^description=.*|$new_description|" "$MODPATH/module.prop"
}

BOOT_HASH_FILE="/data/data/com.reveny.vbmetafix.service/cache/boot.hash"
TARGET="/data/adb/tricky_store/target.txt"
keyboxss="/data/adb/tricky_store/keybox.xml"
retry_count=10
count=0

update_status "Initializing" "⏳"
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 1
done
while [ ! -d /sdcard/Android ]; do
    sleep 1
done
update_status "Boot completed, waiting for unlock phone" "⏳"

# Wait until we are in the launcher
while true; do
    if dumpsys activity activities | grep "mResumedActivity" | grep -qiE "launcher|lawnchair"; then
        update_status "Launcher detected (via activities)" "⏳"
        break
    fi
    
    if dumpsys activity recents | grep "Recent #0" | grep -qiE "launcher|lawnchair"; then
        update_status "Launcher detected (via recents)" "⏳"
        break
    fi
    
    launcher_counter=$((launcher_counter + 1))
    if [ $launcher_counter -gt $launcher_timeout ]; then
        update_status "Launcher timeout, continuing" "⚠️"
        break
    fi
    
    sleep 1
done

update_status "Unlocked ready, stabilizing system" "⏳"
sleep 10

rm -f $BOOT_HASH_FILE
update_status "Starting service" "⏳"

# Add to target.txt if not already present
if [ -f "$TARGET" ]; then
    if ! grep -q "com.reveny.vbmetafix.service" "$TARGET"; then
        sed -i -e ':a' -e '/^\n*$/{$d;N;};/\n$/ba' "$TARGET"
        echo "com.reveny.vbmetafix.service" >> "$TARGET"
    fi
else
    mkdir -p "$(dirname "$TARGET")"
    echo "com.reveny.vbmetafix.service" > "$TARGET"
fi

am broadcast -n com.reveny.vbmetafix.service/.FixerReceiver

update_status "Service started, waiting for hash file" "⏳"
sleep 5

while [ $count -lt $retry_count ]; do
    if [ -f "$BOOT_HASH_FILE" ]; then
        boot_hash=$(cat "$BOOT_HASH_FILE")
        if [ "$boot_hash" == "null" ]; then
            boot_hash=""
        fi
        update_status "Setting VBMeta properties" "⏳"

        # Set all VBMeta properties
        resetprop ro.boot.vbmeta.digest "$boot_hash"
        resetprop ro.boot.vbmeta.hash_alg "sha256"
        resetprop ro.boot.vbmeta.avb_version 1.0

        vbmeta_path="/dev/block/by-name/vbmeta$(getprop ro.boot.slot_suffix)"
        vbmeta_size=$(/bin/toybox blockdev --getbsz "$vbmeta_path" 2>/dev/null)
        vbmeta_size=${vbmeta_size:-0}

        resetprop ro.boot.vbmeta.size "$vbmeta_size"
        resetprop ro.boot.vbmeta.invalidate_on_error "yes"
        resetprop ro.boot.vbmeta.device_state "locked"
        update_status "Service Active" "✅"
        break
    else
        am broadcast -n com.reveny.vbmetafix.service/.FixerReceiver
        count=$((count + 1))
        sleep 1
    fi
done

# Check if we timed out
if [ $count -ge $retry_count ]; then
    update_status "Failed to set VBMeta properties" "❌"
else
am force-stop com.reveny.vbmetafix.service
[ -f "$MODDIR/run.log" ] && rm -fr "$MODDIR/run.log"
(
while true; do
[ -f $keyboxss ] && sizekey="$(wc -c <"$keyboxss")" || sizekey=""
if [ "$(cat $MODDIR/sizek.log 2>/dev/null)" != "$sizekey" ] && [ "$sizekey" ];then
    am broadcast -n com.reveny.vbmetafix.service/.FixerReceiver
    am force-stop com.reveny.vbmetafix.service
    boot_hash=$(cat "$BOOT_HASH_FILE" 2>/dev/null)
    if [ "$boot_hash" != "null" ] && [ "$boot_hash" ];then
    echo "$(date): Set boot hash → $boot_hash" >>$MODDIR/run.log
    resetprop ro.boot.vbmeta.digest "$boot_hash"
    echo "$sizekey" > "$MODDIR/sizek.log"
    fi
fi
sleep 2
done
) >/dev/null 2>&1 &
fi
