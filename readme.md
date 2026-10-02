
# Table of Contents

1.  [run-docker.sh](#run-docker)
2.  [build-docker.sh](#build-docker)
3.  [environment file handling](#env-file)


<a id="run-docker"></a>

# run-docker.sh

`run-docker.sh` is a prefix to run commands inside a specified docker container.
E.g. `run-docker.sh ubuntu whoami` will print the default user of the ubuntu docker image instead of your local user.
`run-docker.sh` uses a couple of defaults intended to ease the usage of docker containers in one's workflow.
E.g. the current working directory is mounted into the container by default and the container is removed by default.
Use `run-docker.sh -N` to perform a dry-run that only prints the `docker run` command if you are ever unsure what
command would be executed.
See `run-docker.sh -h` for a help of all available options.


<a id="build-docker"></a>

# build-docker.sh

`build-docker.sh` is a contemporary script to `run-docker.sh` that provides a similar interface but is concerned with
**building** docker images.
Its intended use case is to ease the docker image building process with easily supplied options without the need to
write a custom script for each docker image.
The environment file handling provides an easy way to reproduce past build commands.
See `build-docker.sh -h`  for a help of all available options.


<a id="env-file"></a>

# environment file handling

`run-docker.sh` and `build-docker.sh` are able to process environment files as an alternative to commandline options.
By default, an available `rund.env` or `buildd.env` will be processed by `run-docker.sh` and `build-docker.sh`
respectively if those files exist.
Alternatively, you can pass your own environment file for processing with `-F` or prevent environment file processing
with `-E`.
You can use `-o` or `-O <env file>` to create an env file with all commandline options written to the env file, so
you can replay your last command simply with `run-docker.sh` or `build-docker.sh` respectively.

