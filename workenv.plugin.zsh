#!/usr/bin/env zsh

## load defaults, read config
WENV_HOME="${WENV_HOME-${HOME}/.workenvs}"
WENV_CONFIG="${WENV_CONFIG-${WENV_HOME}/config}"
test -r "${WENV_CONFIG}" && source "${WENV_CONFIG}"
WENV_GLOBALS="${WENV_GLOBALS-true}"
WENV_AUTOCD="${WENV_AUTOCD-true}"
WENV_HIJACK_VIRTUALENV="${WENV_HIJACK_VIRTUALENV-false}"
WENV_SHORTCUTS="${WENV_SHORTCUTS-true}"

# create a workenv with an optional project directory
mkwenv () {
    local wenv_name=$1
    local wenv_proj=$2
    local wenv_dir="${WENV_HOME}/${wenv_name}"
    if test -z "${wenv_name}"; then
        echo "USAGE: $0 <wenv_name> [proj_dir]" >&2
        return 1
    fi
    if test -d "${wenv_dir}"; then
        echo "ERROR: Environment '${wenv_name}' already exists. Activate it with 'wenv ${wenv_name}'" >&2
        return 1
    fi
    if [ "${wenv_proj}" != "" ] && ! test -d "${wenv_proj}"; then
        echo "ERROR: Cannot associate project with ${wenv_proj}, it is not a directory" >&2
        return 1
    fi
    test -n "${WENV_TEMPLATE}" && git clone "${WENV_TEMPLATE}" "${wenv_dir}"
    mkdir -p "${WENV_HOME}/${wenv_name}/bin"
    touch "${wenv_dir}/activate" "${wenv_dir}/deactivate"
    [ "${wenv_proj}" != "" ] && echo "${wenv_proj}" > "${wenv_dir}/.project"
    wenv "${wenv_name}"
    return $?
}

# activate a workenv
wenv () {
    local wenv_name=$1
    local wenv_dir="${WENV_HOME}/${wenv_name}"
    if test -z "${wenv_name}"; then
        echo "USAGE: $0 <wenv_name>" >&2
        return 1
    fi
    if ! test -d "${wenv_dir}"; then
        echo "ERROR: Environment '${wenv_name}' does not exist. Create it with 'mkwenv ${wenv_name}'" >&2
        return 1
    fi
    if [ "${WENV_GLOBALS}" = "true" ]; then
        local wenv_global_src="${WENV_HOME}/activate"
        test -r "${wenv_global_src}" && source "${wenv_global_src}"
    fi
    export WORK_ENV="${wenv_dir}"
    test -r "${wenv_dir}/.project" && export WENV_PROJ="$(cat "${wenv_dir}/.project")"
    [ "${WENV_HIJACK_VIRTUALENV}" = "true" ] && export VIRTUAL_ENV="${wenv_dir}"
    alias cdworkenv="cd ${WORK_ENV}"
    [ "${WENV_SHORTCUTS}" = "true" ] && alias cdw=cdworkenv
    if test -d "${WENV_PROJ}"; then
        alias cdproject="cd ${WENV_PROJ}"
        [ "${WENV_SHORTCUTS}" = "true" ] && alias cdp=cdproject
        [ "${WENV_AUTOCD}" = "true" ] && cd "${WENV_PROJ}"
    fi
    export PATH="${wenv_dir}/bin:${PATH}"
    test -r "${wenv_dir}/preactivate" && source "${wenv_dir}/preactivate"
    test -r "${wenv_dir}/activate" && source "${wenv_dir}/activate"
    test -r "${wenv_dir}/postactivate" && source "${wenv_dir}/postactivate"
    alias deactivate=wenv_deactivate
    return 0
}

# remove a workenv, never a project directory
rmwenv () {
    local wenv_name=$1
    local wenv_dir="${WENV_HOME}/${wenv_name}"
    if test -z "${wenv_name}"; then
        echo "USAGE: $0 <wenv_name>" >&2
        return 1
    fi
    if ! test -d "${wenv_dir}"; then
        echo "ERROR: Environment '${wenv_name}' does not exist."
        return 1
    fi
    rm -rfv "${wenv_dir}"
}

# deactivate the current workenv, aliased to `deactivate` when available
wenv_deactivate () {
    test -r "${WORK_ENV}/predeactivate" && source "${WORK_ENV}/predeactivate"
    test -r "${WORK_ENV}/deactivate" && source "${WORK_ENV}/deactivate"
    test -r "${WORK_ENV}/postdeactivate" && source "${WORK_ENV}/postdeactivate"
    if [ "${WENV_GLOBALS}" = "true" ]; then
        local wenv_global_unsrc="${WENV_HOME}/deactivate"
        test -r "${wenv_global_unsrc}" && source "${wenv_global_unsrc}"
    fi
    unalias cdworkenv
    test -n "${WENV_PROJ}" && unalias cdproject
    if [ "${WENV_SHORTCUTS}" = "true" ]; then
        unalias cdw
        test -n "${WENV_PROJ}" && unalias cdp
    fi
    export PATH="${PATH##"${WORK_ENV}/bin:"}"
    unset WORK_ENV
    [ "${WENV_HIJACK_VIRTUALENV}" = "true" ] && unset VIRTUAL_ENV
    unset WENV_PROJ
    unalias deactivate
}

# setup function shortcuts
if [ "${WENV_SHORTCUTS}" = "true" ]; then
    alias mkwe=mkwenv
    alias we=wenv
    alias rmwe=rmwenv
fi
