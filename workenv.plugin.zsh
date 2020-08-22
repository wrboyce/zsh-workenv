#!/usr/bin/env zsh

## load defaults, read config
WENV_HOME="${WENV_HOME-${HOME}/.workenvs}"
WENV_CONFIG="${WENV_CONFIG-${WENV_HOME}/config}"
test -r "${WENV_CONFIG}" && source "${WENV_CONFIG}"
WENV_GLOBALS="${WENV_GLOBALS-true}"
WENV_AUTOCD="${WENV_AUTOCD-auto}"  # always, auto, never
WENV_SHORTCUTS="${WENV_SHORTCUTS-true}"

prompt_workenv() {
    [ -z "${WENV_NAME}" ] && return
    p10k segment -f 37 -t "${WENV_NAME}" -i ""
}

# create a workenv with an optional project directory
mkwenv () {
    local template="${WENV_TEMPLATE}"
    while getopts t: opt; do
        case "${opt}" in
            t) template="${OPTARG}" ;;
            h)
                echo >&2 "Usage: $0 [-t template] name [project dir]"
                return 1
                ;;
        esac
    done
    shift $((OPTIND-1))

    local wenv_name="$1"
    local wenv_proj="$2"
    local wenv_dir="${WENV_HOME}/${wenv_name}"
    if test -z "${wenv_name}"; then
        echo >&2 "Usage: $0 [-t template] name [project dir]"
        return 1
    fi
    if test -d "${wenv_dir}"; then
        echo >&2 "ERROR: Environment '${wenv_name}' already exists. Activate it with 'wenv ${wenv_name}'"
        return 1
    fi
    if test -n "${wenv_proj}" && ! test -d "${wenv_proj}"; then
        echo >&2 "ERROR: Cannot associate project with ${wenv_proj}, it is not a directory"
        return 1
    fi

    # if a template is provided, start by cloning it
    test -n "${template}" && git clone "${template}" "${wenv_dir}"
    # create the base skeleton work env
    mkdir -p "${WENV_HOME}/${wenv_name}/{bin,functions}"
    touch "${wenv_dir}/activate" "${wenv_dir}/deactivate"
    # setup the project if provided
    test -n "${wenv_proj}" && echo "${wenv_proj}" > "${wenv_dir}/.project"

    # run the postmake hook if present
    WORK_ENV="${wenv_dir}"
    WENV_NAME="${wenv_name}"
    test -n "${wenv_dir}/postmake" && source "${wenv_dir}/postmake"

    # activate the new work env
    wenv "${wenv_name}"
    return $?
}

# activate a workenv
wenv () {
    local wenv_name="$1"
    local wenv_dir="${WENV_HOME}/${wenv_name}"
    if test -z "${wenv_name}"; then
        echo "USAGE: $0 <wenv_name>" >&2
        return 1
    fi
    if ! test -d "${wenv_dir}"; then
        echo "ERROR: Environment '${wenv_name}' does not exist. Create it with 'mkwenv ${wenv_name}'" >&2
        return 1
    fi

    # setup base environment variables
    export WORK_ENV="${wenv_dir}"
    export WENV_NAME="${wenv_name}"
    test -r "${wenv_dir}/.project" && export WENV_PROJ="$(cat "${wenv_dir}/.project")"
    # global activate, if using
    if [ "${WENV_GLOBALS}" = "true" ]; then
        local wenv_global_src="${WENV_HOME}/activate"
        test -r "${wenv_global_src}" && source "${wenv_global_src}"
    fi
    # setup aliases
    alias cdworkenv="cd ${WORK_ENV}"
    alias deactivate=wenv_deactivate
    [ "${WENV_SHORTCUTS}" = "true" ] && alias cdw=cdworkenv
    if test -d "${WENV_PROJ}"; then
        alias cdproject="cd ${WENV_PROJ}"
        [ "${WENV_SHORTCUTS}" = "true" ] && alias cdp=cdproject
        if [ "${WENV_AUTOCD}" = "always" ] || ([ "${WENV_AUTOCD}" = "auto" ] && [ "${PWD##${WENV_PROJ}}" = "${PWD}" ]); then
            cd "${WENV_PROJ}"
        fi
    fi
    # autoload env functions
    fpath+=("${WORK_ENV}"/functions)
    __functions=("${WORK_ENV}"/functions/*(N))
    (( ${#__functions[@]} )) && autoload -Uz "${__functions[@]:t}"
    # update PATH
    path=("${wenv_dir}/bin:${PATH}" "${path[@]}")
    # workenv activate script
    test -r "${wenv_dir}/activate" && source "${wenv_dir}/activate"
    return 0
}

# update active workenv from git template
wenv_update () {
    if test -z "${WORK_ENV}"; then
        echo "ERROR: Must be called from an active working environment" >&2
        return 1
    fi
    if ! test -d "${WORK_ENV}/.git"; then
        echo "ERROR: Current working environment has no template" >&2
        return 1
    fi

    git -C "${WORK_ENV}" pull origin master -q
    return $?
}

# remove a workenv, never a project directory
rmwenv () {
    local wenv_name="$1"
    local wenv_dir="${WENV_HOME}/${wenv_name}"
    if test -z "${wenv_name}"; then
        echo "USAGE: $0 <wenv_name>" >&2
        return 1
    fi
    if ! test -d "${wenv_dir}"; then
        echo "ERROR: Environment '${wenv_name}' does not exist."
        return 1
    fi
    if test -z "${WENV_HOME}"; then
        echo 'PANIC: `WENV_HOME` is not set, refusing to proceed.'
        return 1
    fi

    rm -rf "${wenv_dir}"
}

# deactivate the current workenv, aliased to `deactivate` when available
wenv_deactivate () {
    test -r "${WORK_ENV}/deactivate" && source "${WORK_ENV}/deactivate"
    if [ "${WENV_GLOBALS}" = "true" ]; then
        local wenv_global_unsrc="${WENV_HOME}/deactivate"
        test -r "${wenv_global_unsrc}" && source "${wenv_global_unsrc}"
    fi
    if test -n "${WENV_PROJ}"; then
        [ "${WENV_SHORTCUTS}" = "true" ] && unalias cdp
        unalias cdproject
    fi
    unalias cdworkenv
    unalias deactivate
    path=( "${(@)path:#"${WORK_ENV}"/*}" )
    # unload functions
    __functions=("${WORK_ENV}"/functions/*(N))
    (( ${#__functions[@]} )) && unset -f "${__functions[@]:t}" 2>/dev/null
    fpath=( "${(@)fpath:#"${WORK_ENV}"/*}" )
    unset WENV_NAME
    unset WENV_PROJ
    unset WORK_ENV
}

# `wenv` completion function, list all known envs
_wenv () {
    local envs=("${WENV_HOME}"/^_*(N))
    _values 'workenv' ${envs:t}
}
compdef _wenv wenv

# setup function shortcuts
if [ "${WENV_SHORTCUTS}" = "true" ]; then
    alias mkwe=mkwenv
    alias we=wenv
    compdef we=wenv
    alias rmwe=rmwenv
fi
