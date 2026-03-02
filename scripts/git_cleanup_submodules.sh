#!/usr/bin/env bash

# Description:
#   Script to cleanup all submodule cache and config after remove of
#   `.gitmodules` file.

# Usage:
#   git_cleanup_submodules.sh
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

function git_cleanup_submodules()
{
  # remove submodule cache using submodules directories recursively
  call git rm -r --cache "$@"
  echo ---

  # remove `active=.` section in the config
  call git config --remove-section submodule
  echo ---

  # remove all submodule sections in the config
  IFS=$' \t\r\n'; while read -r name _; do
    call git config --remove-section "${name%.*}"
  done < <(git config --local --get-regexp 'submodule\.[^.]+\.url')
  echo ---
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_cleanup_submodules "$@"
fi
