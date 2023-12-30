#!/bin/bash

# Description:
#   Script to pull either all or list of remotes.

# Usage:
#   git_pull_remotes.sh <default-remote> [from-remote1 [from-remote2 [...from-remoteN]]] [: branch1 [branch2 [...branchN]]] [// <pull-cmd-line>]
#
#   //:
#     Separator to stop parse flags or previous command line argument list.
#
#   <default-remote>:
#     Default remote to pull at first.
#
#   <from-remote>:
#     Remote to pull from.
#     If not defined, then `git remote` is used instead.
#
#   <branch>:
#     Branch to pull from <from-remote>.
#     If not defined, then `git branch` is used instead.
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

function git_pull_remotes()
{
  local default_remote="$1"

  if [[ -z "$default_remote" ]]; then
    echo "$0: error: default remote is empty"
    exit 255
  fi

  # WORKAROUND:
  #   The `git push` asks for username under the bash shell call from the Windows cmd.exe script.
  #
  [[ -n "${COMSPEC+x}" ]] && unset HOME

  shift

  local IFS
  local from_remotes=()
  local arg
  local i
  local next_cmdline=0

  # read output remotes
  local num_args=${#@}

  for (( i=0; i < num_args; i++ )); do
    arg="$1"

    shift

    if [[ "$arg" == ':' ]]; then
      break
    elif [[ "$arg" == '//' ]]; then
      next_cmdline=1
      break
    fi

    from_remotes[i]="$arg"
  done

  if (( ! ${#from_remotes[@]} )); then
    local has_default_remote=0

    i=0
    while IFS=$'\r\n' read -r arg; do
      # if has, then move to the beginning
      if [[ "$arg" == "$default_remote" ]]; then
        has_default_remote=1
        continue
      fi

      from_remotes[i++]="$arg"
    done < <(git remote)

    if (( has_default_remote )); then
      from_remotes=("$default_remote" "${from_remotes[@]}")
    fi
  fi

  local branches=()

  # read input branches
  local num_args=${#@}

  if (( ! next_cmdline )); then
    for (( i=0; i < num_args; i++ )); do
      arg="$1"

      shift

      if [[ "$arg" == '//' ]]; then
        next_cmdline=1
        break
      fi

      branches[i]="$arg"
    done
  fi

  if (( ! ${#branches[@]} )); then
    local current_branch
    i=0
    while IFS=$'\r\n' read -r arg; do
      if [[ "${arg:0:1}" != '*' ]]; then
        branches[i++]="${arg:2}"
      else
        current_branch="${arg:2}"
      fi
    done < <(git branch --no-color)

    # current branch at first
    if [[ -n "$current_branch" ]]; then
      branches=("$current_branch" "${branches[@]}")
    fi
  fi

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

  local from_remote
  local branch

  for from_remote in "${from_remotes[@]}"; do
    # CAUTION:
    #   Must use a single branch in a pull command to avoid the error:
    #   `fatal: Cannot fast-forward to multiple branches.`
    #
    for branch in "${branches[@]}"; do
      evalcall git pull$pull_cmdline "'$from_remote'" -- "'$branch'"
    done
  done
}

# shortcut
function git_pu_rs()
{
  git_pull_remotes "$@"
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_pull_remotes "$@"
fi

fi
