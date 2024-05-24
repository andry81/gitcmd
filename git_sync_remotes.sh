#!/bin/bash

# Description:
#   Script to synchronize one remote with other remotes using either all or list of remotes.
#   Before the push all branches does the current branch pull with the fast-forward merge only.

# Usage:
#   git_sync_remotes.sh <flags> [//] <from-remote> [to-remote1 [to-remote2 [...to-remoteN]]] [: branch1 [branch2 [...branchN]]] [// <push-cmd-line>]
#
#   //:
#     Separator to stop parse flags or previous command line argument list.
#
#   <flags>:
#     --current-branch:
#       Sync a current branch only.
#
#   <from-remote>:
#     Remote to pull from.
#
#   <to-remote>:
#     Remote to push into.
#     If not defined, then `git remote` is used instead.
#
#   <branch>:
#     Branch to pull from <from-remote> and push to all <to-remote>.
#     If not defined, then `git branch` is used instead.
#
#   <push-cmd-line>:
#     The rest of command line passed to each `git push ...` command.

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

function git_sync_remotes()
{
  local flag="$1"

  local flag_current_branch=0
  local skip_flag

  while [[ "${flag:0:1}" == '-' ]]; do
    flag="${flag:1}"
    skip_flag=0

    if [[ "$flag" == '-current-branch' ]]; then
      flag_current_branch=1
      skip_flag=1
    elif [[ "${flag:0:1}" == '-' ]]; then
      echo "$0: error: invalid flag: \`$flag\`" >&2
      return 255
    fi

    if (( ! skip_flag )); then
      #if [[ "${flag//f/}" != "$flag" ]]; then
      #  flag_f=1
      #else
      #  echo "$0: error: invalid flag: \`${flag:0:1}\`" >&2
      #  return 255
      #fi
      :
    fi

    shift

    flag="$1"
  done

  if [[ "$1" == '//' ]]; then
    shift
  fi

  local remote="$1"

  if [[ -z "$remote" ]]; then
    echo "$0: error: remote is empty" >&2
    return 255
  fi

  # WORKAROUND:
  #   The `git push` asks for username under the bash shell call from the Windows cmd.exe script.
  #
  [[ -n "${COMSPEC+x}" ]] && unset HOME

  shift

  local IFS
  local to_remotes=()
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

    to_remotes[i]="$arg"

    shift
  done

  if (( ! ${#to_remotes[@]} )); then
    local has_input_remote=0
    local local_remote

    local i=0
    while IFS=$'\r\n' read -r local_remote; do
      # if has, then move to the beginning
      if [[ "$local_remote" == "$remote" ]]; then
        has_input_remote=1
        continue
      fi

      to_remotes[i++]="$local_remote"
    done < <(git remote)

    if (( has_input_remote )); then
      to_remotes=("$remote" "${to_remotes[@]}")
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

      if (( ! flag_current_branch )); then
        branches[i]="$arg"
      fi

      shift
    done
  fi

  if (( flag_current_branch || ! ${#branches[@]} )); then
    local current_branch
    local local_branch

    local i=0
    while IFS=$'\r\n' read -r local_branch; do
      if [[ "${local_branch:0:1}" != '*' ]]; then
        if (( ! flag_current_branch )); then
          branches[i++]="${local_branch:2}"
        fi
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

  # read <push-cmd-line>
  local next_cmdline=0

  local num_args=${#@}
  local push_cmdline

  for (( i=0; i < num_args; i++ )); do
    local arg="$1"

    if [[ "${arg//[$' \t']/}" == "$arg" ]]; then
      push_cmdline="$push_cmdline ${arg//\$/\\\$}"
    else
      push_cmdline="$push_cmdline \"${arg//\$/\\\$}\""
    fi

    shift
  done

  local refs_cmdline
  local branch

  # CAUTION:
  #   Must use a single branch in a pull command to avoid the error:
  #   `fatal: Cannot fast-forward to multiple branches.`
  #
  for branch in "${branches[@]}"; do
    refs_cmdline="$refs_cmdline${refs_cmdline:+ }\"$branch\""

    # fetch does use the fast-forward merge only
    call git fetch "$remote" -- "refs/heads/$branch:$branch"
    echo
  done

  local to_remote

  for to_remote in "${to_remotes[@]}"; do
    # additionally this checks on merged heads
    evalcall git push$push_cmdline "'$to_remote'" -- $refs_cmdline
    echo
  done
}

# shortcut
function git_syn_rs()
{
  git_sync_remotes "$@"
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_sync_remotes "$@"
fi
