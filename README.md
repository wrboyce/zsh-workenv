# zsh-workenv

A set of simple shell functions for handling different working environments.

## installation

Simply `source` the `workenv.plugin.zsh` from your `zshrc`.

## usage

### creating a new working environment

`mkwenv <wenv_name> [wenv_project]`

The `mkwenv` function is used for creating new working environments and accepts
between one and two arguments.

`wenv_env` is required and specifies the name which will be used to reference
this working environment when activating/removing.

If `wenv_project` is specified it must be a directory and will be used as the
project folder for the new working environment.

### activating a working environment

`wenv <wenv_name>`

The `wenv` function activates an existing working environment and takes exactly
one argument, the name of the working directory to activate.

During activation the following scripts are sourced:

1. `${WENV_HOME}/activate` (see `${WENV_GLOBALS}`)
2. `${WORK_ENV}/preactivate`
3. `${WORK_ENV}/activate`
4. `${WORK_ENV}/postactivate`

After activation the following aliases and variables are available:

* `WORK_ENV` is set to the path of the current working environemnt
* `WENV_PROJ` is set to the current project directory (if configured)
* `cdworkenv` (shortcut: `cdw`) will change directory to the active working env
* `cdproject` (shortcut: `cdp`) will change directory into the project directory
* `deactivate` will tear down the currently active working environment

Additionally, `${PATH}` is prefixed with `${WORK_ENV}/bin`.

### removing a working directory

`rmwenv <wenv_name>`

The `rmwenv` function will remove a working environment and its configuration
files. Not that any related project folder will **not** be deleted.

## configuration

### `WENV_HOME`

Default: `${HOME}/.workenvs`

Specifies where configuration files and envionment files are stored.

### `WENV_CONFIG`

Default: `${WENV_HOME}/config`

Use this file to specify any custom configuration options.

### `WENV_GLOBALS`

Default: `true`

Determines if the `${WENV_HOME}/activate` and `${WENV_HOME}/deactivate` files
should be used.

### `WENV_AUTOCD`

Default: `true`

When true, activating a workenv with a project specified will automatically
change directory into the project directory.

### `WENV_HIJACK_VIRTUALENV`

Default: `false`

Use this option to automatically set `VIRTUAL_ENV` to the path of the working
environment when activated. This can be useful if your `PS1` is decorated with
the current virtual env name.

During deactivation the following scripts are sourced:

1. `${WORK_ENV}/predeactivate`
2. `${WORK_ENV}/deactivate`
3. `${WORK_ENV}/postdeactivate`
4. `${WENV_HOME}/deactivate` (see `${WENV_GLOBALS}`)

### `WENV_SHORTCUTS`

Default: `true`

Setup some default shortcuts when initialising a working environment:

* alias `mkwe` to `mkwenv`
* alias `we` to `wenv`
* alias `rmwe` to `rmwenv`

When activating a working environment with a project specified, `cdp` and `cdwe`
are aliased to `cdproject` and `cdworkenv` respectively.

### `WENV_TEMPLATE`

Default: `none`

Used by `mkwenv`, if set will be cloned into `${WENV_HOME}` as a basis for new
working environments.
