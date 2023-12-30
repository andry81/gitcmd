#!/bin/bash

# Description:
#   Script to pull all branches from a remote.

# Usage:
#   git_pull_remotes.sh <remote> [// <pull-cmd-line>]
#
#   //:
#     Separator to stop parse flags or previous command line argument list.
#
#   <remote>:
#     Remote to pull from.
#
#   <pull-cmd-line>:
#     The rest of command line passed to each `git pull ...` command.

# NOTE:
#   You must use `GIT_SSH` variable to pass the path to plink agent if want to
#   use SSH key through the Putty.

# Script both for execution and inclusion.
if [[ -n "$BASH" ]]; then

function evalcall()
{
  local IFS=$' \t'
  echo ">$*"
  eval "$@"
}

function call()
{
  local IFS=$' \t'
  echo ">$*"
  "$@"
}

function git_pull_remote_all()
{
  local remote="$1"

  if [[ -z "$remote" ]]; then
    echo "$0: error: remote is empty"
    exit 255
  fi

  # WORKAROUND:
  #   The `git push` asks for username under the bash shell call from the Windows cmd.exe script.
  #
  [[ -n "${COMSPEC+x}" ]] && unset HOME

  shift

  local IFS
  local hash
  local ref
  local i
  local next_cmdline=0

  local refspecs=()

  # read remote branches

  i=0
  while IFS=$' \t\r\n' read -r hash ref; do
    refspecs[i++]="${ref#refs/heads/}:$ref"
  done < <(git ls-remote --heads "$remote")

  if [[ "$arg" == '//' ]]; then
    shift
  fi

  # read <pull-cmd-line>
  next_cmdline=0

  local num_args=${#@}
  local pull_cmdline

  for (( i=0; i < num_args; i++ )); do
    arg="$1"

    shift

    if [[ "${arg//[ \t]/}" == "$arg" ]]; then
      pull_cmdline="$pull_cmdline ${arg//\$/\\\$}"
    else
      pull_cmdline="$pull_cmdline \"${arg//\$/\\\$}\""
    fi
  done

  local refspec

  # CAUTION:
  #   Must use a single branch in a pull command to avoid the error:
  #   `fatal: Cannot fast-forward to multiple branches.`
  #
  for refspec in "${refspecs[@]}"; do
    evalcall git pull$pull_cmdline "'$remote'" -- "'$refspec'"
  done
}

# shortcut
function git_pu_r_a()
{
  git_pull_remote_all "$@"
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_pull_remote_all "$@"
fi

fi
