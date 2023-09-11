#!/bin/bash
# Set execution parameters to:
# Fail whenever any command fails
set -eu

# Repository configuration options
# dev-env
METAL3_DEV_ENV_REPO="https://github.com/metal3-io/metal3-dev-env"
METAL3_DEV_ENV_BRANCH="${METAL3_DEV_ENV_BRANCH:-main}"
METAL3_DEV_ENV_COMMIT="${METAL3_DEV_ENV_COMMIT:-HEAD}"
# repos used during IPA's install
IPA_REPO="${IPA_REPO:-https://opendev.org/openstack/ironic-python-agent}"
IRONIC_LIB_REPO="${IRONIc_LIB_REPO:-https://opendev.org/openstack/ironic-lib}"
OPENSTACK_REQUIREMENTS_REPO="${OPENSTACK_REQUIREMENTS_REPO:-https://opendev.org/openstack/requirements}"
# refs used during IPA's install
IPA_REF="${IPA_COMMIT:-refs/heads/master}"
OPENSTACK_REQUIREMENTS_REF="${OPENSTACK_REQUIREMENTS_REF:-refs/heads/master}"
IRONIC_LIB_REF="${IRONIC_LIB_REF:-refs/heads/master}"
# General environment variables
# The path to the directory that holds this script
CURRENT_SCRIPT_DIR="$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")"
IPA_BUILD_WORKSPACE="${IPA_BUILD_WORKSPACE:-/tmp/dib}"
IPA_IMAGE_NAME="${IPA_IMAGE_NAME:-ironic-python-agent}"
IPA_IMAGE_TAR="${IPA_IMAGE_NAME}.tar"
IPA_BASE_OS="${IPA_BASE_OS:-sles}"
IRONIC_SIZE_LIMIT_MB=500
DEV_ENV_REPO_LOCATION="${DEV_ENV_REPO_LOCATION:-$IPA_BUILD_WORKSPACE/metal3-dev-env}"
DEV_USER_SSH_PATH="${DEV_USER_SSH_PATH:-$HOME/.ssh/id_rsa.pub}"
# Do integration testing to see whether the new IPA does at least
# inspect and provision when it is used in dev env.
ENABLE_BOOTSTRAP_TEST="${ENABLE_BOOTSTRAP_TEST:-true}"
QUIET_CLEANUP="${QUIET_CLEANUP:-false}"
# Configure devuser
ENABLE_DEV_USER_PASS="${ENABLE_DEV_USER_PASS:-false}"
ENABLE_DEV_USER_SSH="${ENABLE_DEV_USER_SSH:-false}"

if [ -d "$IPA_BUILD_WORKSPACE" ]; then
    rm -rf "$IPA_BUILD_WORKSPACE"
fi

# Install required packages
#sudo apt install --yes python3-pip python3-virtualenv qemu-utils
dnf install -y python3-pip python3-virtualenv qemu-utils

# Create the work directory
mkdir --parents "${IPA_BUILD_WORKSPACE}"
cd "${IPA_BUILD_WORKSPACE}"

# Install the cloned IPA builder tool
virtualenv venv
# shellcheck source=/dev/null
source "./venv/bin/activate"
python3 -m pip install --upgrade pip
python3 -m pip install "diskimage-builder"

# Export variables that will be used by DIB
## Configure the IPA builder to pull the IPA source from Nordix fork
export DIB_REPOLOCATION_ironic_python_agent="${IPA_REPO}"
export DIB_REPOLOCATION_ironic_lib="${IRONIC_LIB_REPO}"
export DIB_REPOLOCATION_requirements="${OPENSTACK_REQUIREMENTS_REPO}"
export DIB_REPOREF_requirements="${OPENSTACK_REQUIREMENTS_REF}"
export DIB_REPOREF_ironic_python_agent="${IPA_REF}"
export DIB_REPOREF_ironic_lib="${IRONIC_LIB_REF}"
export DIB_DEV_USER_USERNAME=metal3
if [ "${ENABLE_DEV_USER_PASS}" == "true" ]; then
export DIB_DEV_USER_PWDLESS_SUDO=yes
export DIB_DEV_USER_PASSWORD="test"
fi
if [ "${ENABLE_DEV_USER_SSH}" == "true" ]; then
export DIB_DEV_USER_AUTHORIZED_KEYS="${DEV_USER_SSH_PATH}"
fi
export DIB_INSTALLTYPE_pip_and_virtualenv="package"
## List of additional kernel modules that should be loaded during boot separated by space
## This list is used by the custom element named ipa-modprobe
export DIB_ADDITIONAL_IPA_KERNEL_MODULES="megaraid_sas"
## Provide path(s) of the custom elemnts for DIB
CUSTOM_ELEMENTS="${CURRENT_SCRIPT_DIR}/ipa_builder_elements"
export ELEMENTS_PATH="${ELEMENTS_PATH:-${CUSTOM_ELEMENTS}}"

# Build the IPA initramfs and kernel images
disk-image-create \
    "sles-ipa-install" "${IPA_BASE_OS}" "sles-zypper-config" "sles-ipa-ramdisk-base" \
    "dynamic-login" "journal-to-console" "devuser" "openssh-server" "sles-extra-hardware" \
    "ipa-module-autoload" -o "${IPA_IMAGE_NAME}"

# Deactivate the python virtual environment
deactivate

#Package the initramfs and kernel images to a tar archive
tar --create --verbose --file="${IPA_IMAGE_TAR}" \
    "${IPA_IMAGE_NAME}.kernel" \
    "${IPA_IMAGE_NAME}.initramfs"

# Check the size of the archive
filesize=$(stat --printf="%s" /tmp/dib/ironic-python-agent.tar)
size_domain_offset=1024
filesize_MB=$((filesize / size_domain_offset / size_domain_offset))
echo "Size of the archive: ${filesize_MB}MB"
if [ ${filesize_MB} -ge ${IRONIC_SIZE_LIMIT_MB} ]; then
    exit 1
fi

# Test whether the newly built IPA is compatible with the choosen Ironic version and with
# the metal3-dev-env
if $ENABLE_BOOTSTRAP_TEST; then
    git clone --single-branch --branch "${METAL3_DEV_ENV_BRANCH}" "${METAL3_DEV_ENV_REPO}"
    # dev-env variables can be exported here to customze the test
    export USE_LOCAL_IPA=true
    export IPA_DOWNLOAD_ENABLED=false
    pushd "${DEV_ENV_REPO_LOCATION}"
    git checkout "${METAL3_DEV_ENV_COMMIT}"
    if $QUIET_CLEANUP; then
        make || make clean
        make test || make clean
        make clean
    else
        make || make clean > /dev/null
        make test || make clean > /dev/null
        make clean  > /dev/null
    fi
    popd
fi


