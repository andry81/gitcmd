#!/usr/bin/env bash

# Script can be ONLY included by "source" command.
[[ -n "$BASH" && (-z "$BASH_LINENO" || BASH_LINENO[0] -gt 0) && (-z "$GITCMD_PROJECT_ROOT_INIT0_DIR" || "$GITCMD_PROJECT_ROOT_INIT0_DIR" != "$GITCMD_PROJECT_ROOT") ]] || return 0 || exit 0 # exit to avoid continue if the return can not be called

(( SOURCE_TACKLELIB_BASH_TACKLELIB_SH )) || source bash_tacklelib || return 255 || exit 255 # exit to avoid continue if the return can not be called

tkl_cast_to_int NEST_LVL

[[ -z "${NO_GEN+x}" ]] || tkl_cast_to_int NO_GEN
[[ -z "${NO_LOG+x}" ]] || tkl_cast_to_int NO_LOG
[[ -z "${NO_LOG_OUTPUT+x}" ]] || tkl_cast_to_int NO_OUTPUT

[[ -n "$GITCMD_PROJECT_ROOT" ]] ||                  tkl_export_path -a -s GITCMD_PROJECT_ROOT                   "$BASH_SOURCE_DIR/.."
[[ -n "$GITCMD_PROJECT_EXTERNALS_ROOT" ]] ||        tkl_export_path -a -s GITCMD_PROJECT_EXTERNALS_ROOT         "$GITCMD_PROJECT_ROOT/_externals"

if [[ ! -d "$GITCMD_PROJECT_EXTERNALS_ROOT" ]]; then
  echo "$0: error: GITCMD_PROJECT_EXTERNALS_ROOT directory does not exist: \`$GITCMD_PROJECT_EXTERNALS_ROOT\`." >&2
  tkl_abort
fi

[[ -n "$PROJECT_OUTPUT_ROOT" ]] ||                  tkl_export_path -a -s PROJECT_OUTPUT_ROOT                   "$GITCMD_PROJECT_ROOT/_out"
[[ -n "$PROJECT_LOG_ROOT" ]] ||                     tkl_export_path -a -s PROJECT_LOG_ROOT                      "$GITCMD_PROJECT_ROOT/.log"

[[ -n "$GITCMD_PROJECT_INPUT_CONFIG_ROOT" ]] ||     tkl_export_path -a -s GITCMD_PROJECT_INPUT_CONFIG_ROOT      "$GITCMD_PROJECT_ROOT/_config"
[[ -n "$GITCMD_PROJECT_OUTPUT_CONFIG_ROOT" ]] ||    tkl_export_path -a -s GITCMD_PROJECT_OUTPUT_CONFIG_ROOT     "$PROJECT_OUTPUT_ROOT/config/tacklelib"

# retarget externals of an external project

# [[ -n "$BLABLA_PROJECT_EXTERNALS_ROOT" ]] ||        tkl_export_path -a -s BLABLA_PROJECT_EXTERNALS_ROOT         "$GITCMD_PROJECT_EXTERNALS_ROOT"
# ...

# config loader must be included before any external project init and has using only init variables (declared here and not by the config)

if (( ! SOURCE_TACKLELIB_TOOLS_LOAD_CONFIG_SH )); then # check inclusion guard
  tkl_include_or_abort "$GITCMD_PROJECT_EXTERNALS_ROOT/tacklelib/bash/tacklelib/tools/load_config.sh"
fi

if (( ! NO_GEN )); then
  [[ -e "$GITCMD_PROJECT_OUTPUT_CONFIG_ROOT" ]] || mkdir -p "$GITCMD_PROJECT_OUTPUT_CONFIG_ROOT" || tkl_abort
fi

[[ -n "$LOAD_CONFIG_VERBOSE" ]] || (( ! INIT_VERBOSE )) || tkl_export_path LOAD_CONFIG_VERBOSE 1

#if (( ! NO_GEN )); then
tkl_load_config_dir --no-load-user-config --expand-all-configs-tkl-vars -- "$GITCMD_PROJECT_INPUT_CONFIG_ROOT" "$GITCMD_PROJECT_OUTPUT_CONFIG_ROOT" || tkl_abort

# init external projects

if [[ -f "$GITCMD_PROJECT_EXTERNALS_ROOT/tacklelib/__init__/__init__.sh" ]]; then
  tkl_include_or_abort "$GITCMD_PROJECT_EXTERNALS_ROOT/tacklelib/__init__/__init__.sh"
fi

tkl_include_or_abort "$TACKLELIB_BASH_ROOT/tacklelib/buildlib.sh"

if (( ! NO_GEN )); then
  [[ -e "$PROJECT_OUTPUT_ROOT" ]] || mkdir -p "$PROJECT_OUTPUT_ROOT" || tkl_abort
  [[ -e "$PROJECT_LOG_ROOT" ]] || mkdir -p "$PROJECT_LOG_ROOT" || tkl_abort
fi

tkl_export_path GITCMD_PROJECT_ROOT_INIT0_DIR "$GITCMD_PROJECT_ROOT" # including guard

: # resets exit code to 0
