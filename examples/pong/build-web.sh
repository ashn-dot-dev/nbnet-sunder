#!/bin/sh
set -eux

# No spaces since sunder-compile will split CFLAGS on the space character.
ASYNCIFY_IMPORTS='-sASYNCIFY_IMPORTS=[__js_game_client_start,__js_game_client_close,__js_game_server_start]'

SUNDER_ARCH=wasm32 \
SUNDER_HOST=emscripten \
SUNDER_CC=emcc \
SUNDER_CFLAGS="$(${SUNDER_HOME}/lib/raylib/raylib-config web --cflags) --js-library ${SUNDER_HOME}/lib/nbnet/net_drivers/webrtc/js/api.js -sASYNCIFY ${ASYNCIFY_IMPORTS} -sALLOW_MEMORY_GROWTH=1 -sEXIT_RUNTIME=1 -sSINGLE_FILE=1 --shell-file shell.html" \
sunder-compile -o client.html \
    $(${SUNDER_HOME}/lib/raylib/raylib-config web --libs) \
    -L${SUNDER_HOME}/lib/nbnet -lnbnet-web \
    client.sunder

SUNDER_ARCH=wasm32 \
SUNDER_HOST=emscripten \
SUNDER_CC=emcc \
SUNDER_CFLAGS="--js-library ${SUNDER_HOME}/lib/nbnet/net_drivers/webrtc/js/api.js -sASYNCIFY ${ASYNCIFY_IMPORTS} -sALLOW_MEMORY_GROWTH=1 -sEXIT_RUNTIME=1" \
sunder-compile -o server.js \
    -L${SUNDER_HOME}/lib/nbnet -lnbnet-web \
    server.sunder
