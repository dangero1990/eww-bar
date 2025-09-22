#!/usr/bin/env bash

get_state() {
    local wifi_list active_connection

    wifi_list="$(nmcli -t --escape no -f IN-USE,BSSID,SSID,SIGNAL device wifi list \
        | jq -R -s '
        split("\n")[:-1]                                  
        | map(select(length>0))                            
        | map(
        split(":")
        | {
          INUSE: .[0],
          BSSID:  (.[1:7]   | join(":")),          
          SSID:   (.[7:-1]  | join(":")),           
          SIGNAL: (.[-1]    | tonumber)             
        }
    ) | map(select(.SSID != ""))')"

    active_connection="$(nmcli -t -f TYPE,STATE device status | jq -R -s '                                                            split("\n")                           # split into lines, drop last empty
    | map(select(length>0))                    
    | map(
        split(":") 
        | { type: .[0], state: .[1] }          
      ) | map(select(.type == "ethernet" or .type == "wifi"))')"

    jq -n -c \
    --argjson wifi_list "$wifi_list" \
    --argjson active_connection "$active_connection" \
    '{wifi_list: $wifi_list, active_connection: $active_connection}'

}

get_state

while IFS= read -r line; do
  get_state
done < <(nmcli monitor)