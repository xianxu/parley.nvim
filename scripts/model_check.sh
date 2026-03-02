#!/usr/bin/env bash
# scripts/model_check.sh
#
# Fetches current model listings from OpenAI, Anthropic, and Google AI,
# shows which model each fixture currently uses, and lets you pick a new one.
# Updates scripts/record_fixtures.lua with your selections.
#
# Auth inputs:
# - OPENAI_API_KEY
# - ANTHROPIC_API_KEY
# - GOOGLEAI_API_KEY
#
# Requires: curl, jq

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_SCRIPT="$SCRIPT_DIR/record_fixtures.lua"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Check dependencies
for cmd in curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}Error: $cmd is required but not installed.${RESET}"
        exit 1
    fi
done

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Pretty-print a numbered list and let user pick. Returns selected value via stdout.
# All UI goes to stderr so stdout is clean for the caller.
# Usage: pick_model "Provider" "current_model" model1 model2 ...
pick_model() {
    local provider="$1"
    local current="$2"
    shift 2
    local models=("$@")

    if [ ${#models[@]} -eq 0 ]; then
        echo -e "${RED}No models found for $provider.${RESET}" >&2
        echo ""
        return
    fi

    echo -e "${BOLD}${CYAN}$provider models (${#models[@]} found):${RESET}" >&2
    echo -e "  Current fixture model: ${GREEN}$current${RESET}" >&2
    echo "" >&2

    local i=1
    for m in "${models[@]}"; do
        local marker=""
        if [ "$m" = "$current" ]; then
            marker=" ${YELLOW}<-- current${RESET}"
        fi
        echo -e "  ${BOLD}$i)${RESET} $m$marker" >&2
        ((i++))
    done
    echo -e "  ${BOLD}0)${RESET} Keep current (${current})" >&2
    echo "" >&2

    local choice
    while true; do
        echo -en "  Select model [0-$((${#models[@]}))] (0 to keep): " >&2
        read -r choice
        if [ "$choice" = "0" ] || [ -z "$choice" ]; then
            echo "$current"
            return
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#models[@]} ]; then
            echo "${models[$((choice-1))]}"
            return
        fi
        echo -e "  ${RED}Invalid choice. Try again.${RESET}" >&2
    done
}

# Prompt for manual model entry. Returns selected value via stdout.
# Usage: pick_model_manual "Provider" "current_model"
pick_model_manual() {
    local provider="$1"
    local current="$2"

    echo -e "${BOLD}${CYAN}$provider:${RESET}" >&2
    echo -e "  Current fixture model: ${GREEN}$current${RESET}" >&2
    echo -en "  Enter new model name (or press Enter to keep current): " >&2
    local manual
    read -r manual
    if [ -n "$manual" ]; then
        echo "$manual"
    else
        echo "$current"
    fi
}

escape_sed() {
    printf '%s' "$1" | sed -e 's/[\/&|]/\\&/g'
}

extract_section_model() {
    local start_pat="$1"
    local end_pat="$2"
    sed -n "/$start_pat/,/$end_pat/p" "$FIXTURE_SCRIPT" \
        | grep -m1 -o '\\"model\\":\\"[^\\"]*\\"' \
        | sed 's/^\\"model\\":\\"//; s/\\"$//'
}

extract_quoted_assignment() {
    local var_name="$1"
    sed -nE "s/^[[:space:]]*local[[:space:]]+${var_name}[[:space:]]*=[[:space:]]*\"([^\"]+)\".*/\\1/p" "$FIXTURE_SCRIPT" | head -1
}

# Update the fixture script with new model for a provider
update_fixture_model() {
    local provider="$1"
    local old_model="$2"
    local new_model="$3"

    if [ "$old_model" = "$new_model" ]; then
        return
    fi

    local escaped_old
    local escaped_new
    escaped_old=$(escape_sed "$old_model")
    escaped_new=$(escape_sed "$new_model")

    case "$provider" in
        anthropic)
            sed -i '' "/-- ─── Anthropic/,/write_fixture(\\\"anthropic_stream.txt\\\"/ s|\\\\\"model\\\\\":\\\\\"${escaped_old}\\\\\"|\\\\\"model\\\\\":\\\\\"${escaped_new}\\\\\"|" "$FIXTURE_SCRIPT"
            ;;
        openai)
            if grep -q 'local openai_model = ' "$FIXTURE_SCRIPT"; then
                sed -i '' "s|local openai_model = \"${escaped_old}\"|local openai_model = \"${escaped_new}\"|" "$FIXTURE_SCRIPT"
            else
                sed -i '' "/-- ─── OpenAI/,/write_fixture(\\\"openai_stream.txt\\\"/ s|\\\\\"model\\\\\":\\\\\"${escaped_old}\\\\\"|\\\\\"model\\\\\":\\\\\"${escaped_new}\\\\\"|" "$FIXTURE_SCRIPT"
            fi
            ;;
        googleai)
            sed -i '' "s|local model = \"${escaped_old}\"|local model = \"${escaped_new}\"|" "$FIXTURE_SCRIPT"
            ;;
    esac
    echo -e "  ${GREEN}Updated $provider fixture model: $old_model -> $new_model${RESET}"
}

echo -e "${BOLD}=== Model Check: Fetching current model offerings ===${RESET}"
echo ""

openai_secret="${OPENAI_API_KEY:-}"
anthropic_secret="${ANTHROPIC_API_KEY:-}"
googleai_api_key="${GOOGLEAI_API_KEY:-}"

# ─── OpenAI ──────────────────────────────────────────────────────────────────

openai_models=()
openai_current=""

if [ -z "$openai_secret" ]; then
    echo -e "${YELLOW}OPENAI_API_KEY not set — skipping OpenAI${RESET}"
else
    echo -e "${CYAN}Fetching OpenAI models...${RESET}"
    openai_raw=$(curl -s https://api.openai.com/v1/models \
        -H "Authorization: Bearer $openai_secret" 2>/dev/null || echo "")

    if echo "$openai_raw" | jq -e '.data' &>/dev/null; then
        while IFS= read -r m; do
            [ -n "$m" ] && openai_models+=("$m")
        done < <(echo "$openai_raw" | jq -r '.data[].id' | \
            grep -E '^(gpt-|o[0-9]|chatgpt-)' | \
            grep -v -E '(realtime|audio|tts|whisper|dall-e|embedding|search|instruct)' | \
            sort -u)
        echo -e "  Found ${#openai_models[@]} chat models"
    else
        echo -e "${RED}Failed to fetch OpenAI models. Response:${RESET}"
        echo "$openai_raw" | head -3
    fi

    openai_current=$(extract_quoted_assignment "openai_model")
    if [ -z "$openai_current" ]; then
        openai_current=$(extract_section_model '-- ─── OpenAI' 'write_fixture("openai_stream.txt"' || true)
    fi
    openai_current=$(trim "$openai_current")
    if [ -z "$openai_current" ]; then
        openai_current="unknown"
    fi
    echo ""
fi

# ─── Anthropic ───────────────────────────────────────────────────────────────

anthropic_models=()
anthropic_current=""

if [ -z "$anthropic_secret" ]; then
    echo -e "${YELLOW}ANTHROPIC_API_KEY not set — skipping Anthropic${RESET}"
else
    echo -e "${CYAN}Fetching Anthropic models...${RESET}"

    anthropic_url="https://api.anthropic.com/v1/models?limit=100"
    while true; do
        page_raw=$(curl -s "$anthropic_url" \
            -H "x-api-key: $anthropic_secret" \
            -H "anthropic-version: 2023-06-01" 2>/dev/null || echo "")

        if echo "$page_raw" | jq -e '.data' &>/dev/null; then
            while IFS= read -r m; do
                [ -n "$m" ] && anthropic_models+=("$m")
            done < <(echo "$page_raw" | jq -r '.data[].id')

            has_more=$(echo "$page_raw" | jq -r '.has_more // false')
            if [ "$has_more" = "true" ]; then
                last_id=$(echo "$page_raw" | jq -r '.last_id // empty')
                if [ -n "$last_id" ]; then
                    anthropic_url="https://api.anthropic.com/v1/models?limit=100&after_id=$last_id"
                    continue
                fi
            fi
        else
            echo -e "${RED}Failed to fetch Anthropic models. Response:${RESET}"
            echo "$page_raw" | head -3
        fi
        break
    done

    if [ ${#anthropic_models[@]} -gt 0 ]; then
        anthropic_models=( $(printf '%s\n' "${anthropic_models[@]}" | sort -u) )
        echo -e "  Found ${#anthropic_models[@]} models"
    fi

    anthropic_current=$(extract_section_model '-- ─── Anthropic' 'write_fixture("anthropic_stream.txt"' || true)
    anthropic_current=$(trim "$anthropic_current")
    if [ -z "$anthropic_current" ]; then
        anthropic_current="unknown"
    fi
    echo ""
fi

# ─── Google AI ───────────────────────────────────────────────────────────────

googleai_models=()
googleai_current=""

if [ -z "$googleai_api_key" ]; then
    echo -e "${YELLOW}GOOGLEAI_API_KEY not set — skipping Google AI${RESET}"
else
    echo -e "${CYAN}Fetching Google AI models...${RESET}"
    googleai_url="https://generativelanguage.googleapis.com/v1beta/models?key=$googleai_api_key&pageSize=100"

    while true; do
        page_raw=$(curl -s "$googleai_url" 2>/dev/null || echo "")

        if echo "$page_raw" | jq -e '.models' &>/dev/null; then
            while IFS= read -r m; do
                [ -n "$m" ] && googleai_models+=("$m")
            done < <(echo "$page_raw" | jq -r '.models[].name' | \
                sed 's|models/||' | \
                grep -E '^gemini-')

            next_token=$(echo "$page_raw" | jq -r '.nextPageToken // empty')
            if [ -n "$next_token" ]; then
                googleai_url="https://generativelanguage.googleapis.com/v1beta/models?key=$googleai_api_key&pageSize=100&pageToken=$next_token"
                continue
            fi
        else
            echo -e "${RED}Failed to fetch Google AI models. Response:${RESET}"
            echo "$page_raw" | head -3
        fi
        break
    done

    if [ ${#googleai_models[@]} -gt 0 ]; then
        googleai_models=( $(printf '%s\n' "${googleai_models[@]}" | sort -u) )
        echo -e "  Found ${#googleai_models[@]} Gemini models"
    fi

    googleai_current=$(extract_quoted_assignment "model")
    googleai_current=$(trim "$googleai_current")
    if [ -z "$googleai_current" ]; then
        googleai_current="unknown"
    fi
    echo ""
fi

# ─── Selection ───────────────────────────────────────────────────────────────

echo -e "${BOLD}=== Select models for fixtures ===${RESET}"
echo ""

changes=0

# OpenAI
if [ -n "$openai_secret" ]; then
    if [ ${#openai_models[@]} -gt 0 ]; then
        new_openai=$(pick_model "OpenAI" "$openai_current" "${openai_models[@]}")
    else
        new_openai=$(pick_model_manual "OpenAI" "$openai_current")
    fi
    if [ -n "$new_openai" ] && [ "$new_openai" != "$openai_current" ]; then
        update_fixture_model openai "$openai_current" "$new_openai"
        ((changes++))
    fi
    echo ""
fi

# Anthropic
if [ -n "$anthropic_secret" ]; then
    if [ ${#anthropic_models[@]} -gt 0 ]; then
        new_anthropic=$(pick_model "Anthropic" "$anthropic_current" "${anthropic_models[@]}")
    else
        new_anthropic=$(pick_model_manual "Anthropic" "$anthropic_current")
    fi
    if [ -n "$new_anthropic" ] && [ "$new_anthropic" != "$anthropic_current" ]; then
        update_fixture_model anthropic "$anthropic_current" "$new_anthropic"
        ((changes++))
    fi
    echo ""
fi

# Google AI
if [ -n "$googleai_api_key" ]; then
    if [ ${#googleai_models[@]} -gt 0 ]; then
        new_googleai=$(pick_model "Google AI" "$googleai_current" "${googleai_models[@]}")
    else
        new_googleai=$(pick_model_manual "Google AI" "$googleai_current")
    fi
    if [ -n "$new_googleai" ] && [ "$new_googleai" != "$googleai_current" ]; then
        update_fixture_model googleai "$googleai_current" "$new_googleai"
        ((changes++))
    fi
    echo ""
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo -e "${BOLD}=== Summary ===${RESET}"
if [ "$changes" -eq 0 ]; then
    echo -e "No changes made. Fixture models unchanged."
else
    echo -e "${GREEN}Updated $changes model(s) in $FIXTURE_SCRIPT${RESET}"
    echo -e "Run ${BOLD}make fixtures${RESET} to regenerate fixture files."
fi
