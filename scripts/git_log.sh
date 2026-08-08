#!/usr/bin/env bash

# USAGE:
#   git_log.sh <dir> <out-file>

# Description:
#   Script to print git commit messages with normalized ends.

# Script both for execution and inclusion.
[[ -n "$BASH" ]] || return 0 || exit 0 # exit to avoid continue if the return can not be called

function git_log()
{
  local dir="${1:-.}"
  local outfile="$2"

  if [[ -z "$outfile" ]]; then
    echo "$0: error: <out-file> is not defined."
    return 1
  fi

  if [[ -e "$outfile" ]]; then
    echo "$0: error: <out-file> file must not exist."
    return 2
  fi

  local last_error=0

  outfile="$(realpath -- "$outfile")"

  pushd "$dir" > /dev/null && {
    git log --format='%B%-C()%n' > "$outfile"
    last_error=$?
    popd > /dev/null
  }

  return $last_error
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_log "$@"
fi
