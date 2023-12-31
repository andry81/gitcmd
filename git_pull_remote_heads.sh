#!/bin/bash

# Description:
#   Script to pull all branches from a remote with the fast-foward merge only.

# Usage:
#   git_pull_remotes.sh <remote> [// <fetch-cmd-line>]
#
#   //:
#     Separator to stop parse flags or previous command line argument list.
#
#   <remote>:
#     Remote to pull from.
#
#   <fetch-cmd-line>:
#     The rest of command line passed to each `git fetch ...` command.

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

function git_pull_remote_heads()
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
  local next_cmdline=0

  local refspecs=()

  # read remote branches
  local branch
  local hash
  local ref
  local i=0

  while IFS=$' \t\r\n' read -r hash ref; do
    branch="${ref#refs/heads/}"
    refspecs[i++]="$ref:$branch"
  done < <(git ls-remote --heads "$remote")

  local arg="$1"

  if [[ "$arg" == '//' ]]; then
    shift
  fi

  # read <fetch-cmd-line>
  local next_cmdline=0

  local num_args=${#@}
  local fetch_cmdline

  for (( i=0; i < num_args; i++ )); do
    local arg="$1"

    if [[ "${arg//[$' \t']/}" == "$arg" ]]; then
      fetch_cmdline="$fetch_cmdline ${arg//\$/\\\$}"
    else
      fetch_cmdline="$fetch_cmdline \"${arg//\$/\\\$}\""
    fi

    shift
  done

  local refspec

  # CAUTION:
  #   Must use a single branch in a pull command to avoid the error:
  #   `fatal: Cannot fast-forward to multiple branches.`
  #
  for refspec in "${refspecs[@]}"; do
    # fetch does use the fast-forward merge only
    evalcall git fetch$fetch_cmdline "'$remote'" -- "'$refspec'"
  done
}

# shortcut
function git_pu_r_hs()
{
  git_pull_remote_heads "$@"
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_pull_remote_heads "$@"
fi

fi
