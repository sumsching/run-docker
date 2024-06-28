#!/bin/bash

function usage
{
  local script_name=$(basename $(readlink -f $0))
  echo "Run any command inside a Docker container of the specified image"
  echo "$0 [-hipnuwvVedEFoO] <image> [<command>]"
  echo "-h                                            Print this help"
  echo "-i                                            Run an interactive shell inside the container. No command necessary"
  echo "-p                                            Persistent. Do not destroy the container after use"
  echo "-n <name>                                     Specify name for the container"
  echo "-u <username>                                 Specify the user to select in the container and change working directory to /home/<username>/source"
  echo "                                              -w will have precedence for choosing the working directory"
  echo "-w <dir>                                      mountpoint inside the container for the main volume (default /root/source)"
  echo "-v <directory>                                Use a different directory as volume and working directory for command execution"
  echo "                                              The given command/path must be valid from *inside* the given volume"
  echo "-V <host_dir>:<container_dir>                 Mount the specified directory on the host to the <container_dir> path inside the container as an additional volume"
  echo "                                              Locations outside of the current directory must be specified as absolute paths."
  echo "                                              Tip: use 'readlink -f <relative path>' to still be able to specify a relative path"
  echo '                                              e.g.: -V $(readlink -f ../some_dir):/home/myuser/some_dir'
  echo "-e <FOO>=<bar>                                Set environment variables inside the container"
  echo "-d <device>[:<device in container>[:<mode>]]  Mount device into container. Optionally map to specific device in container."
  echo "                                              Optionally provide mode of device (r)ead, (w)rite, (m)knod"
  echo "                                              e.g.: -d /dev/ttyACM0:/dev/ttyACM0:rwm"
  echo "                                              or:   -d /dev/ttyACM0"
  echo "-C <capability>                               add capability to container"
  echo "-P                                            run container in privileged mode. Use at your own risk"
  echo "-o                                            write ${script_name} options into an env file. (default rund.env)"
  echo "-O <env file>                                 write ${script_name} options into <env file>"
  echo "                                              To use the env file, it must be specified with -F in each ${script_name}"
  echo "-F <env file>                                 read another env file for ${script_name} options"
  echo "                                              An alternative env file can be created with -O"
  echo "-E                                            do not use env file"
  echo 
  echo "example:"
  echo "$0 busybox ps -f"
  echo "$0 -V /opt/results:/home/builder/results build_env make -f Makefile.install"
  echo "   Above command would run 'make' inside a container created from the build_env Docker image. "
  echo "   If the Makefile.install is configured to put its results in /home/builder/results, they would be available on your host system under /opt/results"
}

function get_default_container_name
{
  if [ -z $1 ]
  then
    echo "usage: get_default_container_name <container-name before number> <number separator>" >&2
    return 1
  fi
  local container_name_stem=${1}
  local number_separator=${2:-_}
  local highest_container_number=$(docker ps -a --filter name=^${container_name_stem} --format '{{.Names}}' | sort -r | head -1)
  highest_container_number=${highest_container_number##*${number_separator}}
  local new_container_number=$((highest_container_number+1))
  echo "${container_name_stem}_${new_container_number}"
}

readonly DOCKER_WORKING_DIR_DEFAULT=/root/source
DOCKER_USER=""  #not defaulting to root to allow other default users of standard images like mysql
DOCKER_WORKING_DIR="${DOCKER_WORKING_DIR_DEFAULT}"
DOCKER_VOLUME="${PWD}"
ADDITIONAL_VOLUME_FLAGS=""
INTERACTIVE_FLAGS=""
COMMAND=""
DESTROY_FLAGS="--rm"  #destroy container after use
RUNTIME_ENVIRONMENT_VARIABLE_FLAGS=""
DEVICE_FLAGS=""
CAPABILITY_FLAGS=""
PRIVILEGED_FLAGS=""

USE_ENV=yes
ENV_FILE=rund.env
OUTPUT_ENV_FILE="${ENV_FILE}"
DO_OUTPUT_ENV_FILE=no
OUTPUT_ENVIRONMENT_VARIABLES=""
OUTPUT_ADDITIONAL_VOLUMES=""
OUTPUT_DEVICES=""
OUTPUT_CAPABILITIES=""
OUTPUT_COMMAND=""
INTERACTIVE_SHELL="/bin/sh"

OPTSTRING="hic:pn:v:V:e:d:u:w:C:PEF:oO:"

#enable other env file being sourced before option handling, so options are not overwritten by env file
while getopts "${OPTSTRING}" opt 2>/dev/null; do  #ignoring "illegal" options passed to getopts here
  case ${opt} in
    F)
      USE_ENV=yes
      ENV_FILE="${OPTARG}"
      ;;
    E)
      USE_ENV=no
      ;;
    *)
      #ignore all other options for now
      ;;
  esac
done
OPTIND=0  #allows second getopts call

######## handle variables from env file ###########
if [[ "${USE_ENV}" == "yes" && -f "${ENV_FILE}" ]]
then
  source "${ENV_FILE}"
  for var in ${RUNTIME_ENVIRONMENT_VARIABLES[@]}
  do
    RUNTIME_ENVIRONMENT_VARIABLE_FLAGS=+=" -e ${var}"
    RUNTIME_ENVIRONMENT_VARIABLES+=" ${var}"  #The output should include former env variables
  done
  for volume in ${ADDITIONAL_VOLUMES[@]}
  do
    ADDITIONAL_VOLUME_FLAGS=+=" -v ${volume}"
    OUTPUT_ADDITIONAL_VOLUMES+=" ${volume}"  #The output should include former env variables
  done
  for device in ${DEVICES[@]}
  do
      DEVICE_FLAGS+=" --device ${device}"
      OUTPUT_DEVICES+=" ${device}"  #The output should include former env variables
  done
  if [[ "${DO_INTERACTIVE}" == "yes" ]]
  then
    INTERACTIVE_FLAGS="-it"
  fi
  if [[ "${DO_NOT_DESTROY}" == "yes" ]]
  then
    DESTROY_FLAGS=""
  fi
  if [[ "${DO_PRIVILEGED}" == "yes" ]]
  then
    PRIVILEGED_FLAGS="--privileged"
  fi
fi

while getopts "${OPTSTRING}" opt ; do
  case ${opt} in
    h)
      usage
      exit 0
      ;;
    i) #run container interactively
      DO_INTERACTIVE=yes
      INTERACTIVE_FLAGS="-it"
      ;;
    c)
      COMMAND="${OPTARG}"
      ;;
    p) #persistent container. Do not destroy after use
      DO_NOT_DESTROY=yes
      DESTROY_FLAGS=""
      ;;
    n)
      CONTAINER_NAME="${OPTARG}"
      ;;
    v) #use a different volume as container internal working dir. Keep in mind that the given command (non-interactive use) must be valid *inside* the given directory
      DOCKER_VOLUME=$(readlink -f "${OPTARG}")
      ;;
    V) #enables access to files outside of the current directory
      ADDITIONAL_VOLUME_FLAGS+="-v ${OPTARG} "
      ADDITIONAL_VOLUMES+=" ${OPTARG}"
      ;;
    e)
      RUNTIME_ENVIRONMENT_VARIABLE_FLAGS+=" -e ${OPTARG}"
      RUNTIME_ENVIRONMENT_VARIABLES+=" ${OPTARG}"
      ;;
    d)
      DEVICE_FLAGS+="--device ${OPTARG} "
      OUTPUT_DEVICES+=" ${OPTARG}"
      ;;
    u)
      DOCKER_USER="${OPTARG}"
      DOCKER_USER_FLAGS="-u ${DOCKER_USER}"
      if [[ "${DOCKER_WORKING_DIR}" == "${DOCKER_WORKING_DIR_DEFAULT}" ]]  #only change working dir if it hasn't been set by -w already
      then
	    DOCKER_WORKING_DIR="/home/${DOCKER_USER}/source"
      fi
      ;;
    w)
      DOCKER_WORKING_DIR="${OPTARG}"
      ;;
    C)
      CAPABILITY_FLAGS=" --cap-add ${OPTARG}"
      OUTPUT_CAPABILITIES=" ${OPTARG}"
      ;;
    P)
      DO_PRIVILEGED=yes
      PRIVILEGED_FLAGS="--privileged"
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


shift $((OPTIND-1))

if [ ! -z "$1" ]  #accept DOCKER_IMAGE loaded from env file
then
  DOCKER_IMAGE="$1"
fi

if [ -z "${COMMAND}" ]
then
  if [ ! -z "$2" ]  #accept DOCKER_IMAGE loaded from env file
  then
    COMMAND="${@:2}"
  else
    COMMAND="${INPUT_COMMAND}"  #only use command from env if no other command is provided
  fi
fi

if [[ "${DO_INTERACTIVE}" == "yes" ]]
then
  COMMAND="${INTERACTIVE_SHELL}" #interactive mode has precedence
fi

if [[ -z "${DOCKER_IMAGE// }" ||  -z "${COMMAND// }"  ]]  #remove spaces before checking if empty
then
  usage >&2
  exit 1
fi

if [ -z "${CONTAINER_NAME// }" ]
then
  CONTAINER_NAME=$(get_default_container_name ${DOCKER_IMAGE} "_")
fi
if [[ "${DO_OUTPUT_ENV_FILE}" == "yes" ]]
then
  #TODO replace with exec 1>OUTPUT_ENV_FILE
  if [[ "${OUTPUT_ENV_FILE}" == "-" ]]
  then
    echo "DOCKER_IMAGE=${DOCKER_IMAGE}"
    echo "DOCKER_USER=${DOCKER_USER}"
    echo "DOCKER_VOLUME=${DOCKER_VOLUME}"
    echo "DOCKER_WORKING_DIR=${DOCKER_WORKING_DIR}"
    echo "CONTAINER_NAME=${CONTAINER_NAME}"
    echo "ADDITIONAL_VOLUMES=\"${OUTPUT_ADDITIONAL_VOLUMES}\""
    echo "RUNTIME_ENVIRONMENT_VARIABLES=\"${OUTPUT_ENVIRONMENT_VARIABLES}\""
    echo "DEVICES=\"${OUTPUT_DEVICES}\""
    echo "DO_INTERACTIVE=${DO_INTERACTIVE}"
    echo "DO_NOT_DESTROY=${DO_NOT_DESTROY}"
    echo "DO_PRIVILEGED=${DO_PRIVILEGED}"
    echo "INPUT_COMMAND=\"${COMMAND}\""
  else
    echo "DOCKER_IMAGE=${DOCKER_IMAGE}" > "${OUTPUT_ENV_FILE}"
    echo "DOCKER_USER=${DOCKER_USER}" >> "${OUTPUT_ENV_FILE}"
    echo "DOCKER_VOLUME=${DOCKER_VOLUME}" >> "${OUTPUT_ENV_FILE}"
    echo "DOCKER_WORKING_DIR=${DOCKER_WORKING_DIR}" >> "${OUTPUT_ENV_FILE}"
    echo "CONTAINER_NAME=${CONTAINER_NAME}" >> "${OUTPUT_ENV_FILE}"
    echo "ADDITIONAL_VOLUMES=\"${OUTPUT_ADDITIONAL_VOLUMES}\"" >> "${OUTPUT_ENV_FILE}"
    echo "RUNTIME_ENVIRONMENT_VARIABLES=\"${OUTPUT_ENVIRONMENT_VARIABLES}\"" >> "${OUTPUT_ENV_FILE}"
    echo "DEVICES=\"${OUTPUT_DEVICES}\"" >> "${OUTPUT_ENV_FILE}"
    echo "DO_INTERACTIVE=${DO_INTERACTIVE}" >> "${OUTPUT_ENV_FILE}"
    echo "DO_NOT_DESTROY=${DO_NOT_DESTROY}" >> "${OUTPUT_ENV_FILE}"
    echo "DO_PRIVILEGED=${DO_PRIVILEGED}" >> "${OUTPUT_ENV_FILE}"
    echo "INPUT_COMMAND=\"${COMMAND}\"" >> "${OUTPUT_ENV_FILE}"
  fi
fi

set -x
docker run ${DESTROY_FLAGS} ${INTERACTIVE_FLAGS} ${DEVICE_FLAGS} ${RUNTIME_ENVIRONMENT_VARIABLE_FLAGS} ${DOCKER_USER_FLAGS} -v "${DOCKER_VOLUME}":"${DOCKER_WORKING_DIR}" ${ADDITIONAL_VOLUME_FLAGS} -w "${DOCKER_WORKING_DIR}" --name "${CONTAINER_NAME}" ${CAPABILITY_FLAGS} ${PRIVILEGED_FLAGS} ${INTERACTIVE_FLAGS} "${DOCKER_IMAGE}" ${SH_PREFIX} $COMMAND
