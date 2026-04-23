#!/bin/bash
# Match zellij status-bar background (gruvbox black: 60,56,54)
BG="\033[48;2;60;56;54m"
FG="\033[38;2;213;196;161m"
RST="\033[0m"
while true; do
    cols=$(tput cols 2>/dev/null || echo 10)
    time_str=$(date +'%H:%M:%S')
    padding=$((cols - ${#time_str}))
    printf "\r${BG}${FG}%*s%s${RST}" "$padding" "" "$time_str"
    sleep 1
done
