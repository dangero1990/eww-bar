#!/usr/bin/env bash
set -euo pipefail

get_audio() {
  local list default volume mute

  # All sinks -> [{id,name,state,description}]
  list="$(
    pamixer --list-sinks \
    | tail -n +2 \
    | jq -R -s -c '
        split("\n")
        | map(select(length>0)
            | capture("^(?<id>\\d+)\\s+\"(?<name>[^\"]+)\"\\s+\"(?<state>[^\"]+)\"\\s+\"(?<description>[^\"]+)\"$")
            | (.id |= tonumber))
      '
  )"

  # Default sink -> {id,name,description}
  default="$(
    pamixer --get-default-sink \
    | tail -n1 \
    | jq -R -c '
        capture("^(?<id>\\d+)\\s+\"(?<name>[^\"]+)\"\\s+\"(?<description>[^\"]+)\"$")
        | (.id |= tonumber)
      '
  )"

  # Volume % of @DEFAULT_SINK@
  volume="$(pactl get-sink-volume @DEFAULT_SINK@ | grep -o '[0-9]\+%' | head -1 | tr -d '%')"

  # Mute -> boolean
  mute="$(pactl get-sink-mute @DEFAULT_SINK@ | awk '{print tolower($2)}')"
  [[ "$mute" == "yes" ]] && mute=true || mute=false

  jq -c -n \
    --argjson list "$list" \
    --argjson default "$default" \
    --arg       volume "$volume" \
    --argjson   mute "$mute" \
    '{list: $list, default: $default, volume: ($volume|tonumber), mute: $mute}'
}

# initial emit
get_audio

# re-emit on relevant events (include server for default-sink changes)
pactl subscribe 2>/dev/null \
| stdbuf -oL grep -E --line-buffered 'sink|server|card' \
| while IFS= read -r _; do
    get_audio
  done

