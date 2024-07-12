#!/bin/bash

# Description:
#   Script to complete the last operation and cleanup artefacts after using
#   `subgit import ...` command in the remote:
#   https://subgit.com/documentation/howto.html#import

# Usage:
#   git_cleanup_subgit_svn_import_remote.sh <remote>
#

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

function evalcallxargs()
{
  local IFS
  local CMDLINE

  while IFS=$'\r\n' read -r CMDLINE; do
    IFS=$' \t'
    evalcall "$@" $CMDLINE
  done
}

function git_cleanup_subgit_svn_import_remote()
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

  # based on: https://stackoverflow.com/questions/46229291/in-git-how-can-i-efficiently-delete-all-refs-matching-a-pattern/46229416#46229416
  evalcall "git for-each-ref --format='--delete \"$remote\" %(refname)' refs/notes/commits | evalcallxargs git push"
  evalcall "git for-each-ref --format='--delete \"$remote\" %(refname)' refs/svn/history | evalcallxargs git push"
  evalcall "git for-each-ref --format='--delete \"$remote\" %(refname)' refs/svn/map | evalcallxargs git push"
  evalcall "git for-each-ref --format='--delete \"$remote\" %(refname)' refs/svn/root | evalcallxargs git push"
}

# shortcut
function git_cl_sg_si_r()
{
  git_cleanup_subgit_svn_import_remote "$@"
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_cleanup_subgit_svn_import_remote "$@"
fi
