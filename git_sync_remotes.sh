#!/bin/bash

# Description:
#   Script to synchronize one remote with other remotes in a working copy.

# Usage:
#   git_sync_remotes.sh <from-remote> [to-remote1 [to-remote2 [...to-remoteN]]] [: branch1 [branch2 [...branchN]]]
#
# <from-remote>:
#   Remote to pull from.
#
# <to-remote>:
#   Remote to push into.
#   If not defined, then `git remote` is used instead.
#
# <branch>:
#   Branch to pull from <from-remote> and push to all <to-remote>.
#   If not defined, then `git branch` is used instead.

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

function git_sync_remotes()
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
  local to_remotes=()
  local arg
  local i

  # read output remotes
  local num_args=${#@}

  for (( i=0; i < num_args; i++ )); do
    arg="$1"

    shift

    if [[ "$arg" == ':' ]]; then
      break
    fi

    to_remotes[i]="$arg"
  done

  if (( ! ${#to_remotes[@]} )); then
    local has_input_remote=0

    i=0
    while IFS=$'\r\n' read -r arg; do
      # if has, then move to the beginning
      if [[ "$arg" == "$remote" ]]; then
        has_input_remote=1
        continue
      fi

      to_remotes[i++]="$arg"
    done < <(git remote)

    if (( has_input_remote )); then
      to_remotes=("$remote" "${to_remotes[@]}")
    fi
  fi

  local branches=()

  # read output branches
  local num_args=${#@}

  for (( i=0; i < num_args; i++ )); do
    arg="$1"

    shift

    branches[i]="$arg"
  done

  if (( ! ${#branches[@]} )); then
    i=0
    while IFS=$'\r\n' read -r arg; do
      branches[i++]="${arg:2}"
    done < <(git branch --no-color)
  fi

  local refs_cmdline
  local branch

  for branch in "${branches[@]}"; do
    refs_cmdline="$refs_cmdline \"$branch\""
  done

  # pull at first to check on merged heads
  evalcall git pull --ff-only "\"$remote\"" -- $refs_cmdline || return

  local to_remote

  for to_remote in "${to_remotes[@]}"; do
    evalcall git push --tags "\"$to_remote\"" -- $refs_cmdline
  done
}

# shortcut
function git_sy_rs()
{
  git_sync_remotes "$@"
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_sync_remotes "$@"
fi

fi
