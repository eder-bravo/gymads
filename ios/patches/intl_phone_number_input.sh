#!/bin/bash
PLUGIN_PATH="ios/.symlinks/plugins/libphonenumber_plugin/ios/Classes/SwiftLibphonenumberPlugin.swift"
if [ -f "$PLUGIN_PATH" ]; then
  echo "Applying custom patch to $PLUGIN_PATH"
  # Add commands to apply your changes, e.g., using `sed` or copying a backup
  cp ios/patches/SwiftLibphonenumberPlugin.swift "$PLUGIN_PATH"
fi
