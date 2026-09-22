export SCRIPT_DIR=$(realpath $(dirname $0))

replace() {
    export org=$2 new=$3
    find $1 -type f -exec sed -i 's@'$org'@'$new'@g' {} \;
}

set_keys() {
    mkdir -p $SCRIPT_DIR/keys
    echo $LOCAL_TEST_JKS | base64 -d > $SCRIPT_DIR/keys/local.properties
    echo $STORE_TEST_JKS | base64 -d > $SCRIPT_DIR/keys/test.jks
    unset LOCAL_TEST_JKS
    unset STORE_TEST_JKS
}

sign_apk() {
    export apksigner=$(find $ANDROID_HOME/build-tools -name apksigner | sort | tail -n 1)
    source $SCRIPT_DIR/keys/local.properties
    $apksigner sign -verbose -ks $SCRIPT_DIR/keys/test.jks --ks-pass pass:$storePassword --key-pass pass:$keyPassword --ks-key-alias $keyAlias --out $2 $1 || exit 1
}

sign_aab() {
    source $SCRIPT_DIR/keys/local.properties
    jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 -keystore $SCRIPT_DIR/keys/test.jks -storepass $storePassword -keypass $keyPassword -signedjar $2 $1 $keyAlias || exit 1
}

version_lt() {
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]
}

# Abort the build when a sed anchor string is absent from its target file.
#
# patch.sh is ~170 lines of blind `sed -i` against Chromium sources. When a
# Chromium version bump renames or reformats an anchor, sed exits 0 having
# changed nothing, and the result is a signed release that silently lacks the
# patch. Failing here turns that into a loud build error instead.
patch_require() {
    local file="$1" pattern="$2"
    if [ ! -f "$file" ]; then
        echo "patch.sh: MISSING FILE  $file" >&2
        exit 1
    fi
    if ! grep -qF -- "$pattern" "$file"; then
        echo "patch.sh: MISSING ANCHOR in $file" >&2
        echo "          expected: $pattern" >&2
        echo "          Chromium sources moved; update this patch." >&2
        exit 1
    fi
}
