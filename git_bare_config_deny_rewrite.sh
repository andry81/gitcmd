#!/bin/bash

# Description:
#   Script to deny rewrite in a bare git repository or in a list of git bare
#   repositories searched by the `find` pattern.

# Usage:
#   git_bare_config_deny_rewrite.sh <dir> [<dir-name-pattern>]

# Examples:
#   >
#   git_bare_config_deny_rewrite.sh /home/git "*.git"
#

# Script both for execution and inclusion.
[[ -n "$BASH" ]] || return 0 || exit 0 # exit to avoid continue if the return can not be called

function call()
{
  local IFS=$' \t'
  echo ">$*"
  "$@"
}

# Based on:
#   https://stackoverflow.com/questions/71928010/makefile-on-windows-is-there-a-way-to-force-make-to-use-the-mingw-find-exe/76393735#76393735
#
function detect_find()
{
  SHELL_FIND=find

  local IFS

  # NOTE:
  #   The `${path,,}` or `${path^^}` form has issues:
  #     1. Does not handle a unicode string case conversion correctly (unicode characters translation in words).
  #     2. Supported in Bash 4+.

  # detect `find.exe` in Windows behind `$SYSTEMROOT\System32\find.exe`
  if which where >/dev/null 2>&1; then
    local old_shopt="$(shopt -p nocasematch)" # read state before change
    if [[ "$old_shopt" != 'shopt -s nocasematch' ]]; then
      shopt -s nocasematch
    else
      unset old_shopt
    fi

    IFS=$'\r\n'; for path in `where find 2>/dev/null`; do # IFS - with trim trailing line feeds
      case "$path" in # with case insensitive comparison
        "$SYSTEMROOT"\\*) ;;
        "$WINDIR"\\*) ;;
        *)
          SHELL_FIND="$path"
          break
          ;;
      esac
    done

    if [[ -n "$old_shopt" ]]; then
      eval $old_shopt
    fi
  fi
}

function git_bare_config_deny_rewrite()
{
  local dir="$1"
  local name_pttn="$2"

  local git_path

  local IFS

  if [[ -n "$name_pttn" ]]; then
    detect_find

    IFS=$'\r\n'; for git_path in `\"$SHELL_FIND\" "$dir" -name "$name_pttn" -type d`; do # IFS - with trim trailing line feeds
      call pushd "$git_path" && {
        call git config receive.denynonfastforwards true
        call popd
      }
    done
  else
    call pushd "$dir" && {
      call git config receive.denynonfastforwards true
      call popd
    }
  fi

  return 0
}

# shortcut
function git_bc_de_rw()
{
  git_bare_config_deny_rewrite "$@"
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_bare_config_deny_rewrite "$@"
fi
