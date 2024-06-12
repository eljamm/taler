#!/bin/bash
# This file is in the public domain.
# Original: https://git.taler.net/exchange.git/tree/src/bank-lib/test_bank.sh?h=v0.11.2&id=eab8ddd7e778adca2a7a71afd2d15f80fb33fc0a
# shellcheck disable=SC2317
set -eu

SCRIPT=$(realpath "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
LOGPATH="$SCRIPTPATH/logs/"

HOST="localhost"
PORT="8082"
CURRENCY="EUR"

# Exit, with status code "skip" (no 'real' failure)
function exit_skip() {
    echo "$1"
    exit 77
}

# Cleanup to run whenever we exit
function cleanup() {
    for n in $(jobs -p); do
        kill "$n" 2>/dev/null || true
    done
    wait
}

# Install cleanup handler (except for kill -9)
trap cleanup EXIT

echo -n "Launching bank..."

if [ ! -d "$LOGPATH" ]; then
    mkdir -p "$LOGPATH"
fi

taler-fakebank-run \
    -c "$SCRIPTPATH/test_bank.conf" \
    -L DEBUG &>"$LOGPATH/fakebank_$(date +"%Y%m%d_%H%M%S").log" &

# Wait for bank to be available (usually the slowest)
for n in $(seq 1 50); do
    echo -n "."
    sleep 0.2
    OK=0
    # bank
    wget \
        --tries=1 \
        --timeout=1 \
        "http://$HOST:$PORT/" \
        -o /dev/null \
        -O /dev/null \
        >/dev/null ||
        continue
    OK=1
    break
done

if [ 1 != "$OK" ]; then
    exit_skip "Failed to launch services (bank)"
fi

echo "OK"

echo -n "Making wire transfer to exchange ..."

taler-exchange-wire-gateway-client \
    -b "http://$HOST:$PORT/accounts/exchange/taler-wire-gateway/" \
    -S "0ZSX8SH0M30KHX8K3Y1DAMVGDQV82XEF9DG1HC4QMQ3QWYT4AF00" \
    -D "payto://x-taler-bank/$HOST:$PORT/user?receiver-name=user" \
    -a "$CURRENCY:4" >/dev/null
echo " OK"

echo -n "Requesting exchange incoming transaction list ..."

taler-exchange-wire-gateway-client \
    -b "http://$HOST:$PORT/accounts/exchange/taler-wire-gateway/" \
    -i |
    grep "$CURRENCY:4" \
        >/dev/null

echo " OK"

echo -n "Making wire transfer from exchange..."

taler-exchange-wire-gateway-client \
    -b "http://$HOST:$PORT/accounts/exchange/taler-wire-gateway/" \
    -S "0ZSX8SH0M30KHX8K3Y1DAMVGDQV82XEF9DG1HC4QMQ3QWYT4AF00" \
    -C "payto://x-taler-bank/$HOST:$PORT/merchant?receiver-name=merchant" \
    -a "$CURRENCY:2" \
    -L DEBUG >/dev/null
echo " OK"

echo -n "Requesting exchange's outgoing transaction list..."

taler-exchange-wire-gateway-client \
    -b "http://$HOST:$PORT/accounts/exchange/taler-wire-gateway/" \
    -o |
    grep "$CURRENCY:2" \
        >/dev/null

echo " OK"

echo "All tests passed"

exit 0
