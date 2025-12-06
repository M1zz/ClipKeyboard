#!/bin/sh
# Remove keyboard extension when building for Mac Catalyst
if [ "$SDKROOT" == *"MacOSX"* ] || [ "$EFFECTIVE_PLATFORM_NAME" == "-maccatalyst" ]; then
    echo "Building for Mac Catalyst - removing keyboard extension"
    rm -rf "${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}/Contents/PlugIns/TokenKeyboard.appex"
fi

