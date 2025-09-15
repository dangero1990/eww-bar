#!/usr/bin/env bash
set -euo pipefail

get_state() {
  local connection_list wifi_strength

  printf '{"connection_list":[],"loading":true}\n'

  # devices -> [{type,state,connection}], no loopback
  connection_list="$(
    nmcli -t -f TYPE,STATE,CONNECTION device status \
    | jq -R -s -c '
        split("\n")
        | map(select(length>0)
          | split(":")
          | {type:.[0], state:.[1], connection:.[2]})
        | map(select(.type != "loopback"))
      '
  )"

  # active Wi-Fi → {"ssid":"...", "signal":NN} or null
  wifi_strength="$(
    nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi \
    | awk -F: '$1=="yes"{printf("{\"ssid\":\"%s\",\"signal\":%s}", $2, $3)}'
  )"
  [[ -z "${wifi_strength}" ]] && wifi_strength='null'

  jq -c -n \
    --argjson connection_list "$connection_list" \
    --argjson wifi_strength "$wifi_strength" \
    '
    $connection_list
    | map(
        if .type=="wifi" and .state=="connected" then
          . + {ssid: ($wifi_strength|.ssid),
               signal: ($wifi_strength|.signal|tonumber)}
        elif .type=="wifi" then
          . + {signal:0}
        elif .type=="ethernet" and .state=="connected" then
          . + {signal:100}
        elif .type=="ethernet" then
          . + {signal:0}
        else
          . + {signal:0}
        end
      )
    | {connection_list:. , loading: false}
    '
}

# One-shot
get_state

while IFS= read -r line; do
  get_state
done < <(nmcli monitor)