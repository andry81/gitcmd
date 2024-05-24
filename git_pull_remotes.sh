#!/bin/bash

# Description:
#   Script to pull either all or list of remotes with the fast-foward merge only.

# Usage:
#   git_pull_remotes.sh <default-remote> [from-remote1 [from-remote2 [...from-remoteN]]] [: branch1 [branch2 [...branchN]]] [// <fetch-cmd-line>]
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
#   <fetch-cmd-line>:
#     The rest of command line passed to each `git fetch ...` command.

# NOTE:
#   You must use `GIT_SSH` variable to pass the path to plink agent if want to
#   use SSH key through the Putty.

# Script both for execution and inclusion.
[[ -n "$BASH" ]] || return 0 || exit 0 # exit to avoid continue if the return can not be called

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
    echo "$0: error: default remote is empty" >&2
    return 255
  fi

  # WORKAROUND:
  #   The `git push` asks for username under the bash shell call from the Windows cmd.exe script.
  #
  [[ -n "${COMSPEC+x}" ]] && unset HOME

  shift

  local IFS
  local from_remotes=()
  local next_cmdline=0

  # read output remotes
  local num_args=${#@}

  for (( i=0; i < num_args; i++ )); do
    local arg="$1"

    if [[ "$arg" == ':' ]]; then
      break
    elif [[ "$arg" == '//' ]]; then
      next_cmdline=1
      break
    fi

    from_remotes[i]="$arg"

    shift
  done

  if (( ! ${#from_remotes[@]} )); then
    local has_default_remote=0
    local local_remote

    local i=0
    while IFS=$'\r\n' read -r local_remote; do
      # if has, then move to the beginning
      if [[ "$local_remote" == "$default_remote" ]]; then
        has_default_remote=1
        continue
      fi

      from_remotes[i++]="$local_remote"
    done < <(git remote)

    if (( has_default_remote )); then
      from_remotes=("$default_remote" "${from_remotes[@]}")
    fi
  fi

  local branches=()

  if (( ! next_cmdline )); then
    # read output branches
    if [[ "$arg" == ':' ]]; then
      shift
    fi

    local num_args=${#@}

    for (( i=0; i < num_args; i++ )); do
      local arg="$1"

      if [[ "$arg" == '//' ]]; then
        next_cmdline=1
        break
      fi

      branches[i]="$arg"

      shift
    done
  fi

  if (( ! ${#branches[@]} )); then
    local current_branch
    local local_branch

    local i=0
    while IFS=$'\r\n' read -r local_branch; do
      if [[ "${local_branch:0:1}" != '*' ]]; then
        branches[i++]="${local_branch:2}"
      else
        current_branch="${local_branch:2}"
      fi
    done < <(git branch --no-color)

    # current branch at first
    if [[ -n "$current_branch" ]]; then
      branches=("$current_branch" "${branches[@]}")
    fi
  fi

  if (( ! ${#branches[@]} )); then
    echo "$0: error: there is no branches" >&2
    return 128
  fi

  if [[ "$arg" == '//' ]]; then
    shift
  fi

  # CAUTION:
  #   We should not call the pull here directly, because it involves an evential merge with the current branch.
  #   On another hand we can not checkout each branch because might want to keep a working state with the current branch.
  #   To pull all branches and merge one remote with one local, we must use fetch command with the fast-forward merge or rebase.
  #   This will avoid accidental merge with the current branch and will kept the current branch as checked out.

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

  local from_remote
  local branch

  for from_remote in "${from_remotes[@]}"; do
    # CAUTION:
    #   Must use a single branch in a pull command to avoid the error:
    #   `fatal: Cannot fast-forward to multiple branches.`
    #
    for branch in "${branches[@]}"; do
      # fetch does use the fast-forward merge only
      evalcall git fetch$fetch_cmdline "'$from_remote'" -- "'refs/heads/$branch:$branch'"
      echo
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
