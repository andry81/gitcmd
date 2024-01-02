#!/bin/bash

# Description:
#   Script to complete the last operation and cleanup artefacts after using
#   Git transcrypt extension:
#   https://github.com/elasticdog/transcrypt

# Usage:
#   git_cleanup_transcrypt_textconv.sh
#

# Script both for execution and inclusion.
if [[ -n "$BASH" ]]; then

function evalcall()
{
  local IFS=$' \t'
  echo ">$*"
  eval "$@"
}

function git_cleanup_transcrypt_textconv()
{
  # based on: https://stackoverflow.com/questions/46229291/in-git-how-can-i-efficiently-delete-all-refs-matching-a-pattern/46229416#46229416
  evalcall "git for-each-ref --format='delete %(refname)' refs/notes/textconv/crypt | git update-ref --stdin"
}

# shortcut
function git_cl_trscr_tc()
{
  git_cleanup_transcrypt_textconv "$@"
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_cleanup_transcrypt_textconv "$@"
fi

fi
