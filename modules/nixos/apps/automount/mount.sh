set -uo pipefail

DEVICE="/dev/$1"
BASE_MOUNT="@baseMountPath@"
SPELL_NAMES=(@fallbackVolumeNames@)
SPELL_INDEX_FILE="/var/lib/automount/.spell-index"

mkdir -p /var/lib/automount

# Initialize spell index counter
if [ ! -f "$SPELL_INDEX_FILE" ]; then
  echo 0 > "$SPELL_INDEX_FILE"
fi

get_next_spell() {
  local idx
  idx=$(cat "$SPELL_INDEX_FILE")
  local name="${SPELL_NAMES[$idx]}"
  idx=$(( (idx + 1) % ${#SPELL_NAMES[@]} ))
  echo "$idx" > "$SPELL_INDEX_FILE"
  echo "$name"
}

# Sanitize a name for use as a directory
sanitize_name() {
  echo "$1" | tr ' ' '_' | tr -cd '[:alnum:]_.-'
}

# Get or generate a mount name for a partition
get_mount_name() {
  local label="$1"
  local safe
  if [ -n "$label" ]; then
    safe=$(sanitize_name "$label")
  fi
  if [ -z "${safe:-}" ]; then
    safe=$(get_next_spell)
  fi
  echo "$safe"
}

# Skip internal drives (detect by looking at removable flag or transport)
REMOVABLE=$(cat "/sys/class/block/$(echo "$1" | sed 's/[0-9]*$//')/removable" 2>/dev/null || echo "")
PARENT_DEV=$(echo "$1" | sed 's/[0-9]*$//')
TRANSPORT=$(udevadm info --query=property --name="/dev/$PARENT_DEV" 2>/dev/null | grep "ID_BUS=" | cut -d= -f2 || echo "")

# Only mount USB/thunderbolt/firewire attached devices, or devices flagged removable
if [ "$REMOVABLE" != "1" ] && [ "$TRANSPORT" != "usb" ] && [ "$TRANSPORT" != "thunderbolt" ] && [ "$TRANSPORT" != "firewire" ]; then
  echo "automount: skipping non-removable device $DEVICE (transport=$TRANSPORT, removable=$REMOVABLE)"
  exit 0
fi

# Skip devices that are already mounted (e.g. system partitions)
if mount | grep -q "^$DEVICE "; then
  echo "automount: $DEVICE already mounted, skipping"
  exit 0
fi

# Detect filesystem type
FSTYPE=$(blkid -o value -s TYPE "$DEVICE" 2>/dev/null || echo "")
LABEL=$(blkid -o value -s LABEL "$DEVICE" 2>/dev/null || echo "")

if [ -z "$FSTYPE" ]; then
  echo "automount: no filesystem detected on $DEVICE, skipping"
  exit 0
fi

echo "automount: detected $FSTYPE on $DEVICE (label=$LABEL)"

case "$FSTYPE" in
  apfs)
    # APFS: use apfs-fuse, mount all volumes inside the container
    VOLUME_INFO=$(@apfsFuse@/bin/apfsutil "$DEVICE" 2>/dev/null || true)

    if [ -z "$VOLUME_INFO" ]; then
      # Single volume or can't parse, mount as-is
      MOUNT_NAME=$(get_mount_name "$LABEL")
      MOUNT_POINT="$BASE_MOUNT/$MOUNT_NAME"
      mkdir -p "$MOUNT_POINT"
      @apfsFuse@/bin/apfs-fuse -o uid=@mountUid@,gid=@mountGid@,allow_other "$DEVICE" "$MOUNT_POINT" || true
    else
      # Mount each volume by name
      VOL_ID=""
      while IFS= read -r line; do
        if echo "$line" | grep -q "^Volume [0-9]"; then
          VOL_ID=$(echo "$line" | sed 's/Volume \([0-9]*\).*/\1/')
        fi
        if echo "$line" | grep -q "^Name:"; then
          VOL_NAME=$(echo "$line" | sed 's/Name:[[:space:]]*//' | sed 's/[[:space:]]*(.*)//')
          MOUNT_NAME=$(get_mount_name "$VOL_NAME")
          MOUNT_POINT="$BASE_MOUNT/$MOUNT_NAME"
          mkdir -p "$MOUNT_POINT"
          echo "automount: mounting APFS volume $VOL_ID ($VOL_NAME) -> $MOUNT_POINT"
          @apfsFuse@/bin/apfs-fuse -o uid=@mountUid@,gid=@mountGid@,allow_other -v "$VOL_ID" "$DEVICE" "$MOUNT_POINT" || \
            echo "automount: failed to mount APFS volume $VOL_ID"
        fi
      done <<< "$VOLUME_INFO"
    fi
    ;;

  ntfs|ntfs3)
    MOUNT_NAME=$(get_mount_name "$LABEL")
    MOUNT_POINT="$BASE_MOUNT/$MOUNT_NAME"
    mkdir -p "$MOUNT_POINT"
    echo "automount: mounting NTFS $DEVICE -> $MOUNT_POINT"
    mount -t ntfs3 -o uid=@mountUid@,gid=@mountGid@,fmask=0133,dmask=0022 "$DEVICE" "$MOUNT_POINT" || \
      echo "automount: ntfs3 failed, trying ntfs-3g" && \
      @ntfs3g@/bin/ntfs-3g -o uid=@mountUid@,gid=@mountGid@,fmask=0133,dmask=0022 "$DEVICE" "$MOUNT_POINT" || true
    ;;

  exfat)
    MOUNT_NAME=$(get_mount_name "$LABEL")
    MOUNT_POINT="$BASE_MOUNT/$MOUNT_NAME"
    mkdir -p "$MOUNT_POINT"
    echo "automount: mounting exFAT $DEVICE -> $MOUNT_POINT"
    mount -t exfat -o uid=@mountUid@,gid=@mountGid@,fmask=0133,dmask=0022 "$DEVICE" "$MOUNT_POINT" || true
    ;;

  vfat)
    # Skip EFI partitions
    PARTTYPE=$(blkid -o value -s PART_ENTRY_TYPE "$DEVICE" 2>/dev/null || echo "")
    if [ "$PARTTYPE" = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" ]; then
      echo "automount: skipping EFI partition $DEVICE"
      exit 0
    fi
    MOUNT_NAME=$(get_mount_name "$LABEL")
    MOUNT_POINT="$BASE_MOUNT/$MOUNT_NAME"
    mkdir -p "$MOUNT_POINT"
    echo "automount: mounting FAT $DEVICE -> $MOUNT_POINT"
    mount -t vfat -o uid=@mountUid@,gid=@mountGid@,fmask=0133,dmask=0022 "$DEVICE" "$MOUNT_POINT" || true
    ;;

  ext2|ext3|ext4)
    MOUNT_NAME=$(get_mount_name "$LABEL")
    MOUNT_POINT="$BASE_MOUNT/$MOUNT_NAME"
    mkdir -p "$MOUNT_POINT"
    echo "automount: mounting $FSTYPE $DEVICE -> $MOUNT_POINT"
    mount -t "$FSTYPE" "$DEVICE" "$MOUNT_POINT" || true
    # ext* doesn't support uid mount option, fix ownership
    chown @mountUid@:@mountGid@ "$MOUNT_POINT"
    ;;

  btrfs|xfs|f2fs)
    MOUNT_NAME=$(get_mount_name "$LABEL")
    MOUNT_POINT="$BASE_MOUNT/$MOUNT_NAME"
    mkdir -p "$MOUNT_POINT"
    echo "automount: mounting $FSTYPE $DEVICE -> $MOUNT_POINT"
    mount -t "$FSTYPE" "$DEVICE" "$MOUNT_POINT" || true
    chown @mountUid@:@mountGid@ "$MOUNT_POINT"
    ;;

  hfsplus|hfs)
    MOUNT_NAME=$(get_mount_name "$LABEL")
    MOUNT_POINT="$BASE_MOUNT/$MOUNT_NAME"
    mkdir -p "$MOUNT_POINT"
    echo "automount: mounting HFS+ $DEVICE -> $MOUNT_POINT"
    mount -t hfsplus -o ro,uid=@mountUid@,gid=@mountGid@ "$DEVICE" "$MOUNT_POINT" || true
    ;;

  iso9660|udf)
    MOUNT_NAME=$(get_mount_name "$LABEL")
    MOUNT_POINT="$BASE_MOUNT/$MOUNT_NAME"
    mkdir -p "$MOUNT_POINT"
    echo "automount: mounting $FSTYPE $DEVICE -> $MOUNT_POINT"
    mount -t "$FSTYPE" -o ro,uid=@mountUid@,gid=@mountGid@ "$DEVICE" "$MOUNT_POINT" || true
    ;;

  *)
    echo "automount: unsupported filesystem $FSTYPE on $DEVICE, skipping"
    exit 0
    ;;
esac

echo "automount: done for $DEVICE"
