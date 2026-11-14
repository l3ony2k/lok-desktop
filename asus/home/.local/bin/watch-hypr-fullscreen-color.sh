#!/usr/bin/env bash
set -u

# Poll Hyprland and DRM state, printing only transitions. Use this while
# toggling a browser video between windowed and fullscreen.

output=${1:-eDP-1}
interval=${INTERVAL:-0.25}
connector=""
for path in /sys/class/drm/*-"$output"; do
    [[ -e "$path" ]] || continue
    connector=${path##*/}
break
done

if [[ -z "$connector" ]]; then
    printf 'DRM connector not found for %s\n' "$output" >&2
    exit 1
fi

get_backlight() {
    local value max
    for value in /sys/class/backlight/*/brightness; do
        [[ -r "$value" ]] || continue
        max=${value%/brightness}/max_brightness
        printf '%s/%s' "$(<"$value")" "$(<"$max")"
        return
    done
    printf 'n/a'
}

get_sunset() {
    local temp gamma
    temp=$(hyprctl hyprsunset temperature 2>/dev/null | tail -1 | tr -d '[:space:]')
    gamma=$(hyprctl hyprsunset gamma 2>/dev/null | tail -1 | tr -d '[:space:]')
    printf 'temp=%s gamma=%s' "${temp:-n/a}" "${gamma:-n/a}"
}

get_drm() {
    modetest -M i915 -c 2>/dev/null |
        awk -v wanted="$output" '
            $0 ~ "connected[[:space:]]+" wanted "[[:space:]]" { in_connector=1; next }
            in_connector && /^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+(connected|disconnected)/ { exit }
            in_connector && /^[[:space:]]*[0-9]+[[:space:]]+(max bpc|Colorspace|HDR_OUTPUT_METADATA):/ {
                property=$0
                sub(/^[[:space:]]*/, "", property)
                sub(/^[0-9]+[[:space:]]+/, "", property)
                sub(/:.*/, "", property)
                wanted_value=1
                next
            }
            in_connector && wanted_value && /^[[:space:]]*value:/ {
                value=$0
                sub(/^[[:space:]]*value:[[:space:]]*/, "", value)
                gsub(/[[:space:]]+/, " ", value)
                printf "%s=%s;", property, value
                wanted_value=0
            }
        ' | sed 's/;$//'
}

last=""
while :; do
    now=$(date '+%H:%M:%S.%3N')
    window=$(hyprctl -j activewindow 2>/dev/null || printf '{}')
    monitor=$(hyprctl -j monitors 2>/dev/null | jq -c --arg output "$output" '
        .[] | select(.name == $output) |
        {currentFormat, colorManagementPreset, sdrBrightness, sdrSaturation,
         sdrMinLuminance, sdrMaxLuminance}')
    state=$(jq -r -c '
        {class: (.class // ""), title: (.title // ""),
         fullscreen: (.fullscreen // 0), fullscreenClient: (.fullscreenClient // 0)}' <<<"$window")
    backlight=$(get_backlight)
    sunset=$(get_sunset)
    drm=$(get_drm)
    current="$state|$monitor|backlight=$backlight|$sunset|drm=$drm"

    if [[ "$current" != "$last" ]]; then
        printf '[%s] %s | %s | backlight=%s | %s | drm=%s\n' \
            "$now" "$state" "$monitor" "$backlight" "$sunset" "${drm:-n/a}"
        last=$current
    fi
    sleep "$interval"
done
