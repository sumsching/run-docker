#!/bin/bash

function usage
{
  local script_name=$(basename $(readlink -f $0))
  echo "$0 [-bfnuoEh] [-O <env file>] [-F <env file>] -n <image name>"
  echo "-a <ARG>=<VAL>    Specify build arg (Dockerfile variable) ARG and set it to value VAL. The Dockerfile must handle the variable for it to have an effect"
  echo "-b <directory>    Use <directory> as build context, containing files that are supposed to be used during building the image (default: ./)"
  echo "-f <Dockerfile>   Specify which Dockerfile to use (default: <build context>/Dockerfile)"
  echo "-n <image name>   (recommended) Specify name/tag of the resulting Docker image. If non is provided, the image will only be available by its image ID"
  echo "-u <id>           Specify Dockerfile variable UID and set it to <id>"
  echo "                  Meant to specify another user id for user in docker container. Useful to access volumes from inside the container"
  echo "-g <gid>          Specify Dockerfile variable GID and set it to <gid>"
  echo "                  Meant to use another group id for the user in the docker container."
  echo "                  The Dockerfile must handle the UID and GID for the variables (build args) to have an effect"
  echo "-o                write ${script_name} options into an env file. (default buildd.env)"
  echo "-O <env file>     write ${script_name} options into <env file>"
  echo "                  To use the env file, it must be specified with -F in each ${script_name}"
  echo "-F <env file>     read another env file for ${script_name} options"
  echo "                  An alternative env file can be created with -O"
  echo "-E                do not use env file"
  echo "-h                Print this help"
  echo
  echo "$0 -n custom_image"
  echo "$0"
  echo "$0 -n custom_image_with_proxy -f build/Dockerfile.with_proxy -b build -u 1001 -g 1001"
}

BUILD_CONTEXT=.
BUILD_ARGS=""
TAG_OPTION=""
USE_ENV=yes
ENV_FILE=buildd.env
DO_OUTPUT_ENV_FILE=no
OUTPUT_ENV_FILE="${ENV_FILE}"
OUTPUT_BUILD_ARGS=""

#enable other env file being sourced before option handling, so options are not overwritten by env file
while getopts "EF:" opt 2>/dev/null; do  #ignoring "illegal" options passed to getopts here
  case ${opt} in
    F)
      USE_ENV=yes
      ENV_FILE="${OPTARG}"
      ;;
    E)
      USE_ENV=no
      ;;
  esac
done
OPTIND=0  #allows second getopts call

######## handle variables from env file ###########
if [[ "${USE_ENV}" == "yes" && -f "${ENV_FILE}" ]]
then
  source "${ENV_FILE}"
  for arg in ${ADDITIONAL_BUILD_ARGS[@]}
  do
    BUILD_ARGS+=" --build-arg ${arg}"
    OUTPUT_BUILD_ARGS+=" ${arg}"  #The output should include former env variables
  done
  if [ ! -z "${DOCKER_IMAGE}" ]
  then
    TAG_OPTION="-t"
  fi
fi



while getopts "ha:b:f:n:u:g:EV:oO:" opt; do
  case ${opt} in
    h)
      usage
      exit 0
      ;;
    a)
      BUILD_ARGS+=" --build-arg ${OPTARG}"
      OUTPUT_BUILD_ARGS+=" ${OPTARG}"
      ;;
    b)
      BUILD_CONTEXT="${OPTARG}"
      ;;
    f)
      DOCKERFILE="${OPTARG}"
      ;;
    n)
      DOCKER_IMAGE="${OPTARG}"
      TAG_OPTION="-t"
      ;;
    u)
      BUILD_ARGS+=" --build-arg UID=${OPTARG}"
      OUTPUT_BUILD_ARGS+=" UID=${OPTARG}"
      ;;
    g)
      BUILD_ARGS+=" --build-arg GID=${OPTARG}"
      OUTPUT_BUILD_ARGS+=" GID=${OPTARG}"
      ;;
    E)
      #just ignore, because -E is handled in former getopts call
      ;;
    F)
      #just ignore, because -V is handled in former getopts call
      ;;
    o)
      DO_OUTPUT_ENV_FILE=yes
      ;;
    O)
      DO_OUTPUT_ENV_FILE=yes
      OUTPUT_ENV_FILE="${OPTARG}"
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
done
if [ -z "${DOCKERFILE}" ]
then
  DOCKERFILE=${BUILD_CONTEXT}/Dockerfile
fi

if [[ "${DO_OUTPUT_ENV_FILE}" == "yes" ]]
then
  if [[ "${OUTPUT_ENV_FILE}" == "-" ]]
  then
    echo "DOCKER_IMAGE=${DOCKER_IMAGE}"
    echo "DOCKERFILE=${DOCKERFILE}"
    echo "BUILD_CONTEXT=${BUILD_CONTEXT}"
    echo "ADDITIONAL_BUILD_ARGS=\"${OUTPUT_BUILD_ARGS[@]}\""
  else
    echo "DOCKER_IMAGE=${DOCKER_IMAGE}" > "${OUTPUT_ENV_FILE}"
    echo "DOCKERFILE=${DOCKERFILE}" >> "${OUTPUT_ENV_FILE}"
    echo "BUILD_CONTEXT=${BUILD_CONTEXT}" >> "${OUTPUT_ENV_FILE}"
    echo "ADDITIONAL_BUILD_ARGS=\"${OUTPUT_BUILD_ARGS[@]}\"" >> "${OUTPUT_ENV_FILE}"
  fi
fi

set -x
docker build ${TAG_OPTION} ${DOCKER_IMAGE} ${BUILD_ARGS} -f "${DOCKERFILE}" "${BUILD_CONTEXT}"
