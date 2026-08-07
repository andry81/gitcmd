#!/usr/bin/env bash

# USAGE:
#   git_gen_commit_hash.sh [<flags>] [//] <object> [<hash-cmd> [<hash-cmd-line>]]

# Description:
#   Script to generate a commit hash from hash or reference.
#   Useful to recheck a commit consistency.

# <flags>:
#   -p
#     Include print parents for each commit.

# //:
#   Separator to stop parse flags.

# <object>:
#   A commit hash or reference.

# <hash-cmd>:
#   The hash command to execute for stdin pipe.
#   If not defined, then `sha1sum` is used.

# <hash-cmd-line>:
#   The hash command line for `<hash-cmd>` command.

# Examples:
#   >
#   cd myrepo/path
#   git_gen_commit_hash.sh master
#
#   >
#   cd myrepo/path
#   git_gen_commit_hash.sh master . -b
#
#   >
#   cd myrepo/path
#   git_gen_commit_hash.sh master git hash-object --stdin

# Script both for execution and inclusion.
[[ -n "$BASH" ]] || return 0 || exit 0 # exit to avoid continue if the return can not be called

function tkl_set_shopt_nocasematch()
{
  # CAUTION `OLD_SHOPT` variable must be declared and empty before the call!
  if ! declare -p OLD_SHOPT >/dev/null 2>&1 || [[ -n "$OLD_SHOPT" ]]; then
    return
  fi

  OLD_SHOPT="$(shopt -p nocasematch)" # read state before change

  if [[ "$OLD_SHOPT" != 'shopt -s nocasematch' ]]; then
    shopt -s nocasematch
  else
    OLD_SHOPT=''
  fi
}

function tkl_restore_shopt()
{
  if [[ -n "$OLD_SHOPT" ]]; then
    eval $OLD_SHOPT
  fi
  if [[ -n "${OLD_SHOPT+x}" ]]; then
    unset OLD_SHOPT
  fi
}

function path_distance_rel_to()
{
  local path0="$1"
  local path1="$2"
  local dist
  local relpath="$(realpath -m --relative-to="$path0" "$path1")"

  if [[ "$relpath" == ".." || "$relpath" == */.. ]]; then
    relpath="${relpath}/"
  fi

  while [[ "$relpath" == ../* ]]; do
    dist=$((dist + 1))
    relpath="${relpath#../}"
  done

  if [[ -n "$dist" ]]; then
    RETURN_VALUE=$dist
    return 0
  fi

  RETURN_VALUE=''

  return 1
}

# return nothing if different drives
function path_distance()
{
  path_distance_rel_to "$1" "$2"
  local dist0=$RETURN_VALUE

  path_distance_rel_to "$2" "$1"
  local dist1=$RETURN_VALUE

  if [[ -n "$dist0$dist1" ]]; then
    RETURN_VALUE=$(( dist0 + dist1 ))
    return 0
  fi

  RETURN_VALUE=''

  return 1
}

# Based on:
#   https://stackoverflow.com/questions/71928010/makefile-on-windows-is-there-a-way-to-force-make-to-use-the-mingw-find-exe/76393735#76393735
#
function detect_shell_userdir_file()
{
  local __var="$1"
  local __value="$2"
  local __is_found=0

  local IFS

  # NOTE:
  #   The `${path,,}` or `${path^^}` form has issues:
  #     1. Does not handle a unicode string case conversion correctly (unicode characters translation in words).
  #     2. Supported in Bash 4+.

  # detect a shell package executable behind directories from the `PATH` variable
  if [[ -n "${SHELL+x}" ]] && \
      which where >/dev/null 2>&1 && \
      which realpath >/dev/null 2>&1 && \
      which cygpath >/dev/null 2>&1; then
    __value="${__value//\\//}"

    local OLD_SHOPT
    tkl_set_shopt_nocasematch

    local __shell="$(realpath "$(cygpath -w "$SHELL")")"
    local __path
    local __paths=()
    local __dists=()

    local RETURN_VALUE

    IFS=$'\r\n'; for __path in `where "$__value" 2>/dev/null`; do # IFS - with trim trailing line feeds
      __path="$(cygpath -w "$(realpath "${__path//\\//}")")"
      __path="${__path//\\//}"

      # collect paths and distances to `SHELL` variable value
      path_distance "$__path" "$__shell"

      IFS=$' \t\r\n'
      __paths=("${__paths[@]}" "$__path")
      __dists=("${__dists[@]}" "$RETURN_VALUE")

      #echo "$RETURN_VALUE: $__path; $__shell"
    done

    local __index __mindist=65535 # max distance

    # return path with existed minimal distance
    for (( __index=0; __index < ${#__paths[@]}; __index++ )); do
      __dist="${__dists[__index]}"
      if [[ -n "$__dist" ]] && (( __dist < __mindist )); then
        __path="${__paths[__index]}"
        __mindist=$__dist

        if (( ! __mindist )); then
          break
        fi
      fi
    done

    __is_found=$(( __mindist < 65535 ))

    tkl_restore_shopt
  fi

  if (( __is_found )); then
    eval "$__var=\"\$__path\""
  else
    eval "$__var=\"\$__value\""
  fi
}

function git_gen_commit_hash()
{
  local IFS

  local flag="$1"

  local flag_print_parents=0

  while [[ "${flag:0:1}" == '-' ]]; do
    flag="${flag:1}"

    if [[ "${flag:0:1}" == '-' ]]; then
      echo "$0: error: invalid flag: \`$flag\`" >&2
      return 255
    fi

    while [[ -n "$flag" ]]; do
      if [[ "${flag//p/}" != "$flag" ]]; then
        flag_print_parents=1
        flag="${flag//p/}"
      else
        echo "$0: error: invalid flag: \`${flag:0:1}\`" >&2
        return 255
      fi
    done

    shift

    flag="$1"
  done

  if [[ "$1" == '//' ]]; then
    shift
  fi

  local obj="$1"
  local hashcmd="$2"
  local hashcmdline=("${@:3}")

  if [[ -z "$hashcmd" || "$hashcmd" == '.' ]]; then
    hashcmd=("sha1sum")
  fi

  detect_shell_userdir_file hashcmd "$hashcmd"

  local line

  local objtype parenthash
  local hashsum
  local hashvalue suffix

  objtype="$(git cat-file -t "$obj")"
  hashsum="$(echo -ne "$objtype $(git cat-file -s "$obj")\0$(git cat-file -p "$obj")\n" | $hashcmd "${hashcmdline[@]}")"

  IFS=$' \t' read -r hashvalue suffix <<< "$hashsum"

  echo "$hashvalue $(git rev-parse "$obj") $objtype $obj"

  if (( flag_print_parents )); then
    IFS=$'\r\n'; for line in `git rev-parse "$obj^@"`; do # IFS - with trim trailing line feeds
      IFS=$' \t' read -r parenthash suffix <<< "$line"

      objtype="$(git cat-file -t "$parenthash")"
      hashsum="$(echo -ne "$objtype $(git cat-file -s "$parenthash")\0$(git cat-file -p "$parenthash")\n" | $hashcmd "${hashcmdline[@]}")"

      IFS=$' \t' read -r hashvalue suffix <<< "$hashsum"

      echo "$hashvalue $parenthash $objtype"
    done
  fi
}

# shortcut
function git_gen_c_h()
{
  git_gen_commit_hash "$@"
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_gen_commit_hash "$@"
fi
