import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.luckyclover.aceofaces',
  appName: '1918',
  webDir: 'www',
  // The game is 9:16 portrait, mobile-first.
  ios: {
    contentInset: 'always',
    // Mac Catalyst (Mac App Store) is enabled in Xcode, not here —
    // see SUBMIT.md step "Turn on Mac".
  },
};

export default config;
