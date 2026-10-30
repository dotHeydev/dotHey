# shellcheck shell=bash
# Shared by f003's tests.

. "$(dirname -- "${BASH_SOURCE[0]}")/../f001--install-plug-and-play/helpers.sh"

COMMIT="4d342b097ba4acf1850d6caab9d63a52cea45457"

RELEASE="1.2.0"

# An install of release $RELEASE, as install or upgrade records it.
installed_release() {
  core "dot::save_state version '\"$RELEASE\"'"
  assert_success "record release $RELEASE"
}
