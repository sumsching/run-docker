#!/bin/bash

function usage
{
  echo "Run any command inside a Docker container of the specified image"
  echo "$0 [-hipnvVed] <image> [<command>]"
  echo "-h                                            Print this help"
  echo "-i                                            Run an interactive shell inside the container. No command necessary"
  echo "-p                                            Persistent. Do not destroy the container after use"
  echo "-n <name>                                     Specify name for the container"
  echo "-v <directory>                                Use a different directory as volume and working directory for command execution"
  echo "                                              The given command/path must be valid from *inside* the given volume"
  echo "-V <host_dir>:<container_dir>                 Mount the specified directory on the host to the <container_dir> path inside the container as an additional volume"
  echo "                                              Locations outside of the current directory must be specified as absolute paths."
  echo "                                              Tip: use 'readlink -f <relative path>' to still be able to specify a relative path"
  echo '                                              e.g.: -V $(readlink -f ../WP_OTAP_TOOL):/home/c4builder/wp_otap_tool'
  echo "-e <FOO>=<bar>                                Set environment variables inside the container"
  echo "-d <device>[:<device in container>[:<mode>]]  Mount device into container. Optionally map to specific device in container."
  echo "                                              Optionally provide mode of device (r)ead, (w)rite, (m)knod"
  echo "                                              e.g.: -d /dev/ttyACM0:/dev/ttyACM0:rwm"
  echo "                                              or:   -d /dev/ttyACM0"
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
DOCKER_USER=root
DOCKER_WORKING_DIR="${DOCKER_WORKING_DIR_DEFAULT}"
DOCKER_VOLUME="${PWD}"
ADDITIONAL_VOLUME_FLAGS=""
INTERACTIVE_FLAGS=""
COMMAND=""
DESTROY_FLAGS="--rm"  #destroy container after use
RUNTIME_ENVIRONMENT_VARIABLES=""
DEVICE_FLAGS=""

while getopts "hipn:v:V:e:d:u:w:" opt ; do
  case ${opt} in
    h)
      usage
      exit 0
      ;;
    i) #run container interactively
      INTERACTIVE_FLAGS="-it"
      COMMAND="/bin/bash"
      ;;
    p) #persistent container. Do not destroy after use
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
      ;;
    e)
      RUNTIME_ENVIRONMENT_VARIABLES+=" -e ${OPTARG}"
      ;;
    d)
      DEVICE_FLAGS+="--device ${OPTARG} "
      ;;
    u)
      DOCKER_USER="${OPTARG}"
      if [[ "${DOCKER_WORKING_DIR}" != "${DOCKER_WORKING_DIR_DEFAULT}" ]]  #only change working dir if it hasn't been set by -w already
      then
	DOCKER_WORKING_DIR="/home/${DOCKER_USER}/source"
      fi
      ;;
    w)
      DOCKER_WORKING_DIR="${OPTARG}"
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
done


shift $((OPTIND-1))

readonly DOCKER_IMAGE="$1"


COMMAND+=" ${@:2}"  #if run interactively the command will simply be appended. Will not start interactively but will prevent an error in case both -i and a command is provided

if [ -z "${DOCKER_IMAGE// }" -o -z "${COMMAND// }" ]  #remove spaces before checking if empty
then
  usage >&2
  exit 1
fi
echo "${DOCKER_IMAGE}"
echo "${COMMAND}"

if [ -z "${CONTAINER_NAME// }" ]
then
  CONTAINER_NAME=$(get_default_container_name ${DOCKER_IMAGE} "_")
fi  


set -x
docker run ${DESTROY_FLAGS} ${INTERACTIVE_FLAGS} ${DEVICE_FLAGS} ${RUNTIME_ENVIRONMENT_VARIABLES} -v "${DOCKER_VOLUME}":"${DOCKER_WORKING_DIR}" ${ADDITIONAL_VOLUME_FLAGS} -w "${DOCKER_WORKING_DIR}" --name "${CONTAINER_NAME}" "${DOCKER_IMAGE}" $COMMAND
