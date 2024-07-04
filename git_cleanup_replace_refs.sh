#!/bin/bash

# Description:
#   Script to cleanup all `refs/replace` references:

# Usage:
#   git_cleanup_replace_refs.sh
#

# Script both for execution and inclusion.
[[ -n "$BASH" ]] || return 0 || exit 0 # exit to avoid continue if the return can not be called

function call()
{
  local IFS=$' \t'
  echo ">$*"
  "$@"
}

function evalcall()
{
  local IFS=$' \t'
  echo ">$*"
  eval "$@"
}

function git_cleanup_replace_refs()
{
  # print all refs
  call git show-ref || return 255
  echo ---

  # based on: https://stackoverflow.com/questions/46229291/in-git-how-can-i-efficiently-delete-all-refs-matching-a-pattern/46229416#46229416
  evalcall "git for-each-ref --format='delete %(refname)' refs/replace | git update-ref --stdin"
}

# shortcut
function git_cl_rp_rs()
{
  git_cleanup_replace_refs "$@"
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_cleanup_replace_refs "$@"
fi
