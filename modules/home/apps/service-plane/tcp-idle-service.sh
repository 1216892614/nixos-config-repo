activity_file="$ACTIVITY_DIR/@name@"
state=$(docker inspect --format='{{.State.Running}}' "service-plane-@name@-1" 2>/dev/null || echo "false")
@activityCheck@
