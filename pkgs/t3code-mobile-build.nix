{
  androidSdkRoot,
  coreutils,
  gnugrep,
  jdk17,
  openssl,
  writeShellApplication,
}:

writeShellApplication {
  name = "build-t3code-mobile";
  runtimeInputs = [
    coreutils
    gnugrep
    jdk17
    openssl
  ];
  text = ''
    set -euo pipefail

    if [ ! -f package.json ] || [ ! -f apps/mobile/app.config.ts ]; then
      printf 'Run this command from the official T3 Code repository root.\n' >&2
      exit 64
    fi

    output="''${1:-$HOME/Downloads/t3-code-preview.apk}"
    signing_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/t3code-mobile-signing"
    credentials="$signing_dir/credentials"
    keystore="$signing_dir/t3code-preview.keystore"

    install -d -m 0700 "$signing_dir"
    if [ ! -f "$credentials" ] || [ ! -f "$keystore" ]; then
      umask 0077
      password="$(openssl rand -hex 32)"
      ${jdk17}/bin/keytool -genkeypair \
        -alias t3code-preview \
        -keyalg RSA \
        -keysize 4096 \
        -validity 10000 \
        -dname 'CN=Jet T3 Code Preview, O=Personal' \
        -keystore "$keystore" \
        -storepass "$password" \
        -keypass "$password"
      printf 'KEYSTORE_PASSWORD=%s\nKEY_PASSWORD=%s\n' "$password" "$password" > "$credentials"
      chmod 0600 "$credentials" "$keystore"
    fi

    # shellcheck disable=SC1090
    source "$credentials"
    corepack pnpm install --filter '@t3tools/mobile...' --frozen-lockfile

    (
      cd apps/mobile
      APP_VARIANT=preview EXPO_NO_GIT_STATUS=1 corepack pnpm exec expo prebuild --clean --platform android
      APP_VARIANT=preview MOBILE_VERSION_POLICY=fingerprint ./android/gradlew -p android \
        :app:assembleRelease \
        -Pandroid.injected.signing.store.file="$keystore" \
        -Pandroid.injected.signing.store.password="$KEYSTORE_PASSWORD" \
        -Pandroid.injected.signing.key.alias=t3code-preview \
        -Pandroid.injected.signing.key.password="$KEY_PASSWORD"
    )

    apk=apps/mobile/android/app/build/outputs/apk/release/app-release.apk
    install -D -m 0644 "$apk" "$output"
    ${androidSdkRoot}/build-tools/36.0.0/apksigner verify --verbose --print-certs "$output"
    ${androidSdkRoot}/build-tools/36.0.0/aapt2 dump badging "$output" \
      | grep -F "package: name='com.t3tools.t3code.preview'" >/dev/null
    printf 'APK: %s\n' "$output"
    printf 'Signing key: %s\n' "$keystore"
  '';
}
