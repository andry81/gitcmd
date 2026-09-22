#!/usr/bin/env bash

# USAGE:
#   git_cd.sh [<path>]

# Description:
#   Script changes current directory to the root of a working copy beginning
#   the <path>.

# <path>
#   A path in a working copies tree.
#   Has no effect if is not in a working copy.
#
#   Builtin paths:
#     // - top level working copy root.
#     /  - current working copy root.
#
#   If <path> is empty, then `/` is used instead.

# Examples:
#   >
#   . git_cd.sh //

# Script both for execution and inclusion.
[[ -n "$BASH" ]] || return 0 || exit 0 # exit to avoid continue if the return can not be called

function git_cd()
{
  local path="${1:-/}"

  if [[ "$path" == '/' ]]; then
    local wcroot="$(git rev-parse --show-toplevel 2>/dev/null)"
    if [[ -n "$wcroot" ]]; then
      cd "$wcroot"
    fi
  elif [[ "$path" == '//' ]]; then
    local wcroot="$(git rev-parse --show-toplevel 2>/dev/null)"
    if [[ -n "$wcroot" ]]; then
      local wctoproot="$wcroot"
      while cd "$wcroot/.." 2>/dev/null; do
        wcroot="$(git rev-parse --show-toplevel 2>/dev/null)"
        if [[ -n "$wcroot" ]]; then
          wctoproot="$wcroot"
        else
          cd "$wctoproot"
          break
        fi
      done
    fi
  else
    pushd "$path" >/dev/null 2>&1 && {
      local wcroot="$(git rev-parse --show-toplevel 2>/dev/null)"
      popd >/dev/null 2>&1
      if [[ -n "$wcroot" ]]; then
        cd "$wcroot"
      fi
    }
  fi
}

# NOTE: script execution has no sense as would be run in a child process