#!/bin/bash

# Description:
#   Script to complete the last operation and cleanup artefacts after using
#   `subgit import ...` command:
#   https://subgit.com/documentation/howto.html#import

# Usage:
#   git_cleanup_subgit_svn_import.sh
#

# Script both for execution and inclusion.
[[ -n "$BASH" ]] || return 0 || exit 0 # exit to avoid continue if the return can not be called

function evalcall()
{
  local IFS=$' \t'
  echo ">$*"
  eval "$@"
}

function git_cleanup_subgit_svn_import()
{
  # based on: https://stackoverflow.com/questions/46229291/in-git-how-can-i-efficiently-delete-all-refs-matching-a-pattern/46229416#46229416
  evalcall "git for-each-ref --format='delete %(refname)' refs/notes/commits | git update-ref --stdin"
  evalcall "git for-each-ref --format='delete %(refname)' refs/svn/history | git update-ref --stdin"
  evalcall "git for-each-ref --format='delete %(refname)' refs/svn/map | git update-ref --stdin"
  evalcall "git for-each-ref --format='delete %(refname)' refs/svn/root | git update-ref --stdin"
}

# shortcut
function git_cl_sg_si()
{
  git_cleanup_subgit_svn_import "$@"
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_cleanup_subgit_svn_import "$@"
fi
