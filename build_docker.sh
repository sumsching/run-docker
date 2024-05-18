#!/bin/bash

function usage
{
  echo "$0 [-bfnuh] -n <image name>"

  echo "-a <ARG>=<VAL>    Specify build arg (Dockerfile variable) ARG and set it to value VAL. The Dockerfile must handle the variable for it to have an effect"
  echo "-b <directory>    Use <directory> as build context, containing files that are supposed to be used during building the image (default: ./)"
  echo "-f <Dockerfile>   Specify which Dockerfile to use (default: <build context>/Dockerfile)"
  echo "-n <image name>   (recommended) Specify name/tag of the resulting Docker image. If non is provided, the image will only be available by its image ID"
  echo "-u <id>           Specify Dockerfile variable UID and set it to <id>"
  echo "                  Meant to specify another user id for user in docker container. Useful to access volumes from inside the container"
  echo "-g <gid>          Specify Dockerfile variable GID and set it to <gid>"
  echo "                  Meant to use another group id for the user in the docker container."
  echo "                  The Dockerfile must handle the UID and GID for the variables (build args) to have an effect"
  echo "-h                Print this help"
  echo
  echo "$0 -n custom_image"
  echo "$0"
  echo "$0 -n custom_image_with_proxy -f build/Dockerfile.with_proxy -b build -u 1001 -g 1001"
}

readonly SCRIPT_DIR=$(dirname $(readlink -f $0)) #real location of the script. Enables symlink compatibility with directory dependent Dockerfile
BUILD_CONTEXT=.
DOCKERFILE=${BUILD_CONTEXT}/Dockerfile
BUILD_ARGS=""
TAG_OPTION=""

while getopts "ha:b:f:n:u:g:" opt; do
  case ${opt} in
    h)
      usage
      exit 0
      ;;
    a)
      BUILD_ARGS+=" --build-arg ${OPTARG}"
      ;;
    b)
      BUILD_CONTEXT="${OPTARG}"
      ;;
    f)
      DOCKERFILE="${OPTARG}"
      ;;
    n)
      IMAGE_NAME="${OPTARG}"
      TAG_OPTION="-t"
      ;;
    u)
      BUILD_ARGS+=" --build-arg UID=${OPTARG}"
      ;;
    g)
      BUILD_ARGS+=" --build-arg GID=${OPTARG}"
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
done

cd "${SCRIPT_DIR}"

set -x
docker build ${TAG_OPTION} ${IMAGE_NAME} ${BUILD_ARGS} -f "${DOCKERFILE}" "${BUILD_CONTEXT}"
