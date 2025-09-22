#!/usr/bin/env bash
set -euo pipefail

BTCTL=${BTCTL:-/usr/bin/bluetoothctl}
JQ=${JQ:-/usr/bin/jq}
STDBUF=${STDBUF:-/usr/bin/stdbuf}

# Read current state -> JSON {state: true|false|null}
get_bluetooth_state() {
  local raw
  raw="$("$BTCTL" show 2>/dev/null \
        | awk -F': ' '
            /^[[:space:]]*Powered:/     {print $2; exit}
            /^[[:space:]]*PowerState:/  {print $2; exit}
          ' || true)"

  local val
  case "$raw" in
    yes|on|true|True)   val=true  ;;
    no|off|false|False) val=false ;;
    *)                  val=null  ;; # unknown/no adapter
  esac

  "$JQ" -nc --argjson state "$val" '{state:$state}'
}

emit_if_changed() {
  local new="$1"
  if [[ "${LAST_STATE:-}" != "$new" ]]; then
    echo "$new"
    LAST_STATE="$new"
  fi
}

# Initial emit (so the bar gets a value immediately)
emit_if_changed "$(get_bluetooth_state)"

# Keep re-subscribing if the monitor ends (e.g., when you power off)
while :; do
  # If monitor is too quiet (some stacks), we still re-emit on a slow heartbeat
  # so the bar recovers after service restarts.
  "$STDBUF" -oL "$BTCTL" --monitor 2>/dev/null | \
  while IFS= read -r line || [[ -n "${line-}" ]]; do
    case "$line" in
      *Powered*|*PowerState*|*Controller*|*Adapter*)
        emit_if_changed "$(get_bluetooth_state)"
        ;;
      # Optional: heartbeat every N irrelevant lines (or time-based) — comment out if not wanted
      *)
        :
        ;;
    esac
  done
  # Monitor ended (likely powered off or BlueZ restart). Emit current state and retry.
  emit_if_changed "$(get_bluetooth_state)"
  sleep 0.3
done

