{ config, lib, pkgs, ... }:

let
  apfs-fuse = pkgs.apfs-fuse;

  # D&D spell names as fallback volume names when partitions have no label
  spellNames = [
    "Fireball"
    "Eldritch_Blast"
    "Misty_Step"
    "Counterspell"
    "Shield_of_Faith"
    "Thunderwave"
    "Dimension_Door"
    "Power_Word_Kill"
    "Meteor_Swarm"
    "Time_Stop"
    "Wish"
    "Disintegrate"
    "Polymorph"
    "Banishment"
    "Chain_Lightning"
    "Finger_of_Death"
    "Prismatic_Wall"
    "Antimagic_Field"
    "True_Resurrection"
    "Astral_Projection"
  ];

  mountUser = "ep-o1";
  mountUid = 1000;
  mountGid = 100;
  baseMountPath = "/run/media/${mountUser}";

  # Unified auto-mount script for all external filesystems
  autoMountScript = pkgs.writeShellScript "external-automount" ''
    set -uo pipefail

    DEVICE="/dev/$1"
    BASE_MOUNT="${baseMountPath}"
    SPELL_NAMES=(${lib.concatStringsSep " " (map (s: ''"${s}"'') spellNames)})
    SPELL_INDEX_FILE="/var/lib/automount/.spell-index"

    mkdir -p /var/lib/automount

    # Initialize spell index counter
    if [ ! -f "$SPELL_INDEX_FILE" ]; then
      echo 0 > "$SPELL_INDEX_FILE"
    fi

    get_next_spell() {
      local idx
      idx=$(cat "$SPELL_INDEX_FILE")
      local name="''${SPELL_NAMES[$idx]}"
      idx=$(( (idx + 1) % ''${#SPELL_NAMES[@]} ))
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
      if [ -z "''${safe:-}" ]; then
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
        VOLUME_INFO=$(${apfs-fuse}/bin/apfsutil "$DEVICE" 2>/dev/null || true)

        if [ -z "$VOLUME_INFO" ]; then
          # Single volume or can't parse, mount as-is
          MOUNT_NAME=$(get_mount_name "$LABEL")
          MOUNT_POINT="$BASE_MOUNT/$MOUNT_NAME"
          mkdir -p "$MOUNT_POINT"
          ${apfs-fuse}/bin/apfs-fuse -o uid=${toString mountUid},gid=${toString mountGid},allow_other "$DEVICE" "$MOUNT_POINT" || true
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
              ${apfs-fuse}/bin/apfs-fuse -o uid=${toString mountUid},gid=${toString mountGid},allow_other -v "$VOL_ID" "$DEVICE" "$MOUNT_POINT" || \
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
        mount -t ntfs3 -o uid=${toString mountUid},gid=${toString mountGid},fmask=0133,dmask=0022 "$DEVICE" "$MOUNT_POINT" || \
          echo "automount: ntfs3 failed, trying ntfs-3g" && \
          ${pkgs.ntfs3g}/bin/ntfs-3g -o uid=${toString mountUid},gid=${toString mountGid},fmask=0133,dmask=0022 "$DEVICE" "$MOUNT_POINT" || true
        ;;

      exfat)
        MOUNT_NAME=$(get_mount_name "$LABEL")
        MOUNT_POINT="$BASE_MOUNT/$MOUNT_NAME"
        mkdir -p "$MOUNT_POINT"
        echo "automount: mounting exFAT $DEVICE -> $MOUNT_POINT"
        mount -t exfat -o uid=${toString mountUid},gid=${toString mountGid},fmask=0133,dmask=0022 "$DEVICE" "$MOUNT_POINT" || true
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
        mount -t vfat -o uid=${toString mountUid},gid=${toString mountGid},fmask=0133,dmask=0022 "$DEVICE" "$MOUNT_POINT" || true
        ;;

      ext2|ext3|ext4)
        MOUNT_NAME=$(get_mount_name "$LABEL")
        MOUNT_POINT="$BASE_MOUNT/$MOUNT_NAME"
        mkdir -p "$MOUNT_POINT"
        echo "automount: mounting $FSTYPE $DEVICE -> $MOUNT_POINT"
        mount -t "$FSTYPE" "$DEVICE" "$MOUNT_POINT" || true
        # ext* doesn't support uid mount option, fix ownership
        chown ${toString mountUid}:${toString mountGid} "$MOUNT_POINT"
        ;;

      btrfs|xfs|f2fs)
        MOUNT_NAME=$(get_mount_name "$LABEL")
        MOUNT_POINT="$BASE_MOUNT/$MOUNT_NAME"
        mkdir -p "$MOUNT_POINT"
        echo "automount: mounting $FSTYPE $DEVICE -> $MOUNT_POINT"
        mount -t "$FSTYPE" "$DEVICE" "$MOUNT_POINT" || true
        chown ${toString mountUid}:${toString mountGid} "$MOUNT_POINT"
        ;;

      hfsplus|hfs)
        MOUNT_NAME=$(get_mount_name "$LABEL")
        MOUNT_POINT="$BASE_MOUNT/$MOUNT_NAME"
        mkdir -p "$MOUNT_POINT"
        echo "automount: mounting HFS+ $DEVICE -> $MOUNT_POINT"
        mount -t hfsplus -o ro,uid=${toString mountUid},gid=${toString mountGid} "$DEVICE" "$MOUNT_POINT" || true
        ;;

      iso9660|udf)
        MOUNT_NAME=$(get_mount_name "$LABEL")
        MOUNT_POINT="$BASE_MOUNT/$MOUNT_NAME"
        mkdir -p "$MOUNT_POINT"
        echo "automount: mounting $FSTYPE $DEVICE -> $MOUNT_POINT"
        mount -t "$FSTYPE" -o ro,uid=${toString mountUid},gid=${toString mountGid} "$DEVICE" "$MOUNT_POINT" || true
        ;;

      *)
        echo "automount: unsupported filesystem $FSTYPE on $DEVICE, skipping"
        exit 0
        ;;
    esac

    echo "automount: done for $DEVICE"
  '';

  # Unmount script for device removal
  autoUnmountScript = pkgs.writeShellScript "external-autounmount" ''
    set -uo pipefail
    DEVICE="/dev/$1"
    BASE_MOUNT="${baseMountPath}"

    # Find all mounts from this device or under our base path associated with it
    # For APFS (FUSE), grep by apfs-fuse; for others, grep by device
    {
      mount | grep "$DEVICE " | awk '{print $3}'
      mount | grep "apfs-fuse" | grep "$BASE_MOUNT" | awk '{print $3}'
    } | sort -u | while read -r mp; do
      echo "automount: unmounting $mp"
      umount "$mp" 2>/dev/null || umount -l "$mp" 2>/dev/null || true
      rmdir "$mp" 2>/dev/null || true
    done
  '';

in
{
  environment.systemPackages = [
    apfs-fuse
    pkgs.ntfs3g
    pkgs.exfatprogs
  ];

  boot.kernelModules = [ "fuse" "ntfs3" "exfat" ];

  # Disable udiskie handling for APFS (it can't handle it)
  # udiskie still works for quick USB sticks if user prefers, but our service covers all cases

  # udev rules: trigger our service for any block device with a filesystem
  services.udev.extraRules = ''
    # Auto-mount external storage partitions when connected
    ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_TYPE}!="", TAG+="systemd", ENV{SYSTEMD_WANTS}+="external-automount@%k.service"
    ACTION=="remove", SUBSYSTEM=="block", RUN+="${autoUnmountScript} %k"
  '';

  # systemd template service
  systemd.services."external-automount@" = {
    description = "Auto-mount external storage on %i";
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${autoMountScript} %i";
      ExecStop = "${autoUnmountScript} %i";
    };
  };

  # Ensure base mount directory exists
  systemd.tmpfiles.rules = [
    "d ${baseMountPath} 0755 ${mountUser} users -"
  ];
}
