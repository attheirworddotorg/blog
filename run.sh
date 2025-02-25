#!/usr/bin/env bash

set -eu

###################
##### Imports #####
###################

# Check if running in build container or locally
# to import from correct path
if [ -d /build-support ]
then
    . ~/.bashrc
    . ~/.cargo/env
    BUILD_SUPPORT_ROOT="/build-support"
else
    BUILD_SUPPORT_ROOT="./build-support"
fi
. "${BUILD_SUPPORT_ROOT}/shell/run/config.sh"
. "${BUILD_SUPPORT_ROOT}/shell/common/log.sh"


###############################
##### Container Utilities #####
###############################

run-build-base() {
    ${CONTAINER_RUNTIME} build \
        --target "${BUILD_TARGET_STAGE}" \
        -t "${BUILD_IMAGE_URL}:${BUILD_IMAGE_TAG}" \
        -f build-support/docker/Dockerfile \
        --build-arg DOCKER_GID="${DOCKER_GID}" \
        --build-arg RUST_VERSION="${DEFAULT_RUST_VERSION}" \
        --build-arg UID="${USERID}" \
        --build-arg USERNAME="${USERNAME}" \
        "${@}" \
        .
}

run-push-base() {
    ${CONTAINER_RUNTIME} push \
        "${@}" \
        "${BUILD_IMAGE_URL}:${BUILD_IMAGE_TAG}"
}

run-in-container() {
    # If input device is not a TTY don't run with `-it` flags
    local INTERACTIVE_FLAGS="$(test -t 0 && echo '-it' || echo '')"
    # Expose ports on localhost for specific commands
    local PORT_FLAGS=""
    if [ "${COMMAND}" = "serve" ]
    then
        PORT_FLAGS="-p 127.0.0.1:1111:1111 -p 127.0.0.1:1024:1024"
    fi
    ${CONTAINER_RUNTIME} run \
		--rm \
         ${INTERACTIVE_FLAGS} \
         ${PORT_FLAGS} \
		-u ${USERNAME} \
        -v /var/run/docker.sock:/var/run/docker.sock \
		-v $(pwd):/project \
		-w /project \
		${BUILD_IMAGE_URL}:${BUILD_IMAGE_TAG} \
        --local "${@}"
}


#############################
##### Command Utilities #####
#############################

run-command() {
    local COMMAND="${1}"
    shift

    if [ ${RUNTIME_CONTEXT} = "container" ]
    then
        run-in-container "${COMMAND}" "${@}"
    elif [ ${RUNTIME_CONTEXT} = "local" ]
    then
        run-${COMMAND} "${@}"
    else
        error "Invalid value for RUNTIME_CONTEXT: ${RUNTIME_CONTEXT}"
        exit 1
    fi
}


####################
##### Commands #####
####################

run-build() {
    run-check

    echo "Building website"
    zola --root src build --output-dir public ${@}
}

run-check() {
    echo "Checking website"
    zola --root src check
}

run-clean() {
    echo "Cleaning build artifacts"
    rm -rf public
}

run-exec() {
    info "Running command: ${*}"
    ${@}
}

run-fmt() {
    echo "Formatting website - this is a noop"
}

run-fmt-check() {
    echo "Checking website formatting - this is a noop"
}

run-lint() {
    echo "Linting website - this is a noop"
}

run-publish() {
    echo "Publishing website - this is a noop"
}

run-serve() {
    echo "Running the Zola development server"
    zola --root src serve --drafts -i 0.0.0.0 ${@}
}

run-shell() {
    info "Entering shell"
    bash
}

run-test() {
    echo "Running website tests - this is a noop"
}

run-update-deps() {
    echo "Updating website dependencies - this is a noop"
}


################
##### Main #####
################

print-usage() {
    echo "usage: $(basename ${0}) [-h] [SUBCOMMAND]"
    echo
    echo "subcommands:"
    echo "build             build the site (default subcommand)"
    echo "build-base        build the build container image"
    echo "check             check the site without rendering it"
    echo "clean             remove build artifacts"
    echo "exec              execute arbitrary shell commands"
    echo "fmt               TODO"
    echo "lint              TODO"
    echo "publish           TODO"
    echo "push-base         push build container image to registry"
    echo "serve             run Zola development server"
    echo "shell             start Bash shell"
    echo "test              TODO"
    echo "update-deps       TODO"
    echo
    echo "optional arguments:"
    echo "-h, --help        show this help message and exit"
    echo "-l, --local       run command on host system instead of build container"
    echo "-c, --container   run command in build container"
    echo
}


while :
do
    case "${1:-}" in
        -c|--container)
            shift
            RUNTIME_CONTEXT="container"
        ;;
        -h|--help)
            print-usage
            exit 0
        ;;
        -l|--local)
            shift
            RUNTIME_CONTEXT="local"
        ;;
        *)
            break
        ;;
    esac
done

if [ -z "${1:-}" ]
then
    COMMAND="${DEFAULT_COMMAND}"
else
    COMMAND="${1}"
    shift
fi

# These commands should explicitly run locally
if ( \
    [ "${COMMAND}" = "build-base" ] \
    || [ "${COMMAND}" = "push-base" ] \
)
then
    RUNTIME_CONTEXT="local"
fi

run-command "${COMMAND}" "${@}"
