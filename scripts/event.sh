#!/usr/bin/env bash
set -euo pipefail

# Hyprland event socket
SOCK="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

# Emit {"active":N,"occupied":[...]} as one JSON line
snapshot() {
  # active workspace id
  local active
  active="$(hyprctl activeworkspace -j | jq -r '.id')"

  # occupied workspaces (windows > 0), sorted by id
  local occupied
  occupied="$(hyprctl workspaces -j | jq 'sort_by(.id)')"

  jq -c -n \
    --argjson occupied "$occupied" \
    --argjson active "$active" \
    '{occupied: $occupied, active: $active}'
}

# Emit an initial state so Eww has data immediately
snapshot

# Listen for events and re-emit on relevant ones
# socket2 lines look like: "workspace>>3" or "openwindow>>1234,kitty,title"
# We only need the event name to know when to refresh.
handle () {
  case "$1" in
    # switching ws / focus changes
    workspace*|focusedmon*)
      snapshot ;;
    # windows appearing/disappearing/moving can change "occupied"
    openwindow|closewindow|movewindow|movewindowv2)
      snapshot ;;
    # ws created/destroyed also changes state
    createworkspace|destroyworkspace)
      snapshot ''
  esac
}

socat -U - UNIX-CONNECT:"$SOCK" | while read -r line; do handle "$line"; done



