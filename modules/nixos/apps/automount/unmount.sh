set -uo pipefail
DEVICE="/dev/$1"
BASE_MOUNT="@baseMountPath@"

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
