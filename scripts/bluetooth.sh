#!/usr/bin/env bash

get_bluetooth_state () {

    local state

    state="$(bluetoothctl show \
  | awk -F': ' '/PowerState/ {print $2}')"

  jq -n -c \
  --arg state "$state" \
  '{state: $state}'


}

get_bluetooth_state

while IFS= read -r line; do
  get_bluetooth_state
done < <(stdbuf -oL bluetoothctl --monitor 2>/dev/null)
