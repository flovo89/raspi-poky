#!/bin/bash
#
# Helper script to build a yocto image

# Stops on error
set -e

################################################################################
# Variables
PROJECT_BASE=$(pwd)
POKY_BASE=${PROJECT_BASE}/poky
META_LAYERS_FILE=meta-layers
CONF_DIR="${PROJECT_BASE}/conf"
BUILD_DIR="${PROJECT_BASE}/build"
DEPLOY_DIR="${PROJECT_BASE}/deploy"
MACHINE="raspberrypi"

# What to do
IS_BUILD_SDK=false
IS_BUILD_MINIMAL_SD_IMAGE=false
IS_SOURCE_ONLY=false

################################################################################
# Shows this script usage
usage()
{
  echo "${0}:"
  echo "-h    Shows this help"
  echo "-u    Update meta-layers repositories"
  echo "-i    Init poky environment"
  echo "-e    Prepare shell to run poky"
  echo "-M    Machine selection (${MACHINE})"
  echo "-V    Extra version to be appended to distro version"
  echo "-S    Build an SDK"
  echo "-D    Build a minimal sd image"
  echo "-A    Build all"
}

################################################################################
# Clone required repository and check out the right version
update_meta_layers()
{
  echo "Updating meta-layers ..."
  cd ${PROJECT_BASE}

  for layer in $(cat ${META_LAYERS_FILE} | grep -v ^#)
  do
    cd ${PROJECT_BASE}
    META_PATH=$(echo ${layer} | cut -d\; -f1)
    META_URL=$(echo ${layer} | cut -d\; -f2)
    META_REV=$(echo ${layer} | cut -d\; -f3)
    # Make sure we have correct entry
    if [ "${META_PATH}" = "" -o "${META_URL}" = "" -o ${META_REV} = "" ]
    then
      echo "Malformed meta-layer line:"
      echo ${layer}
      exit -1
    fi
    [ ! -d ${META_PATH} ] && git clone ${META_URL} ${META_PATH}
    cd ${META_PATH}
    git fetch origin
    git checkout ${META_REV}
    git pull origin ${META_REV}
  done
  echo "meta-layers up to date!"
}
################################################################################
# Initialize poky environment
init_poky_env()
{
  # Make sure update was called ...
  [ ! -d ${POKY_BASE} ] && update_meta_layers
  # Remove existing configuration if exists and user want to
  echo "Initializing poky environement ..."
  cd ${POKY_BASE}
  if [ -d build ]
  then
    echo -n "A poky environement already exists, would you like to remove it "
    echo "and restart again? [y/N]"
    read REMOVE_ENV
    REMOVE_ENV=$(echo $REMOVE_ENV | head -c1)
    if [ ${REMOVE_ENV} = "y" -o ${REMOVE_ENV} = "Y" ]
    then
      rm -rf build/conf
    else
      return
    fi
  fi
  # Initialize the environment
  export TEMPLATECONF=${CONF_DIR}
  . ./oe-init-build-env ${BUILD_DIR} > /dev/null
  # Workaround to the error "Do not use Bitbake as root." on jenkins.
  # Implement better solution as fast as possible (really do not run Bitbake as root).
  touch conf/sanity.conf
  echo "Your poky environment is ready!"
}

################################################################################
# Source the poky environement to start the build
source_poky_env()
{
  # Allow bitbake to get some variables form the environment
  export CONF_DIR
  export BB_ENV_EXTRAWHITE="DISTRO_EXTRA_VERSION  CONF_DIR"
  export MACHINE
  # Make sure we have an environement ready
  cd ${PROJECT_BASE}
  [ ! -d build/conf ] && init_poky_env
  cd ${POKY_BASE}
  . ./oe-init-build-env ${BUILD_DIR} > /dev/null
}

################################################################################
# Run bitbake to build the given recipe
# $1 the recipe to build
run_bitbake()
{
  echo "Running bitbake ${1} ..."
  source_poky_env
  bitbake ${1}
}

################################################################################
# Build the SDK for both architectures (x86_64 and i386)
build_sdk()
{
  export SDKMACHINE="x86_64"
  run_bitbake "-c populate_sdk stm32-prod-image"
  export SDKMACHINE="i686"
  run_bitbake "-c populate_sdk stm32-prod-image"
}

################################################################################
# Copy generated files in deploy directory for convenience
update_deploy_dir()
{
  IMAGES_DIR=${BUILD_DIR}/tmp-glibc/deploy/images/${MACHINE}
  SDK_DIR=${BUILD_DIR}/tmp/deploy/sdk
  RELEASE=$(run_bitbake -e | grep ^DISTRO_VERSION | cut -d\" -f2)
  RELEASE_SDK_DIR=${DEPLOY_DIR}/${RELEASE}
  RELEASE_DIR=${RELEASE_SDK_DIR}/${MACHINE}
  echo "Copying generated files in ${RELEASE_DIR} ..."
  mkdir -p ${RELEASE_DIR}
  # Development image
  if ${IS_BUILD_MINIMAL_SD_IMAGE}
  then
    cp -r ${IMAGES_DIR}/*rpi-sdimg ${RELEASE_DIR}
  fi
  # SDK
  if ${IS_BUILD_SDK}
  then
    for sdk in $(find ${SDK_DIR} | grep -e ${DISTRO_EXTRA_VERSION} | grep sh\$)
    do
      tar -C $(dirname ${sdk}) -cvz $(basename ${sdk}) -f ${RELEASE_SDK_DIR}/$(basename ${sdk}).tgz
    done
  fi
  # Make a symlink to the latest images
  cd ${DEPLOY_DIR}
  rm -f latest
  ln -s ${RELEASE} latest
}
################################################################################
# Main script
# Default extra version
export DISTRO_EXTRA_VERSION="-daily-$(date -u +%F-%H_%M_%S)"
while getopts "huieM:V:SDA" FLAG; do
  case $FLAG in
    h)
      usage
      exit 0
      ;;
    u)
      update_meta_layers
      ;;
    i)
      init_poky_env
      ;;
    e)
      IS_SOURCE_ONLY=true
      ;;
    M)
      MACHINE="$OPTARG"
      ;;
    V)
      export DISTRO_EXTRA_VERSION="$OPTARG"
      ;;
    S)
      IS_BUILD_SDK=true
      ;;
    D)
      IS_BUILD_MINIMAL_SD_IMAGE=true
      ;;
    A)
      IS_BUILD_SDK=true
      IS_BUILD_MINIMAL_SD_IMAGE=true
      ;;
    \?)
      usage
      exit 1
      ;;
  esac
done
# Get ready to run poky
if ${IS_SOURCE_ONLY}
then
  source_poky_env
  bash
  exit 0
fi
# Build things in order of amount of work (more to less)
${IS_BUILD_SDK} && build_sdk
${IS_BUILD_MINIMAL_SD_IMAGE} && run_bitbake core-image-base
update_deploy_dir
echo "Compilation done succesfully!"