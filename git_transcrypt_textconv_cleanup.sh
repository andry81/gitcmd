#!/bin/bash

# Description:
#   Script to complete the last operation and cleanup artefacts after using
#   Git transcrypt extension:
#   https://github.com/elasticdog/transcrypt

# Usage:
#   git_transcrypt_textconv_cleanup.sh
#

# Script both for execution and inclusion.
if [[ -n "$BASH" ]]; then

function evalcall()
{
  local IFS=$' \t'
  echo ">$*"
  eval "$@"
}

function git_transcrypt_cleanup()
{
  # based on: https://stackoverflow.com/questions/46229291/in-git-how-can-i-efficiently-delete-all-refs-matching-a-pattern/46229416#46229416
  evalcall "git for-each-ref --format='delete %(refname)' refs/notes/textconv/crypt | git update-ref --stdin"
}

# shortcut
function git_trcr_cl()
{
  git_transcrypt_cleanup "$@"
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_transcrypt_cleanup "$@"
fi

fi
