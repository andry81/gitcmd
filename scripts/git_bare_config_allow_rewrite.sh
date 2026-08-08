#!/usr/bin/env bash

# USAGE:
#   git_bare_config_allow_rewrite.sh [<dir> [<dir-path-pattern>...]]

# Description:
#   Script to allow rewrite in a bare git repository or in a list of git bare
#   repositories searched by the `find` pattern.

# Examples:
#   >
#   git_bare_config_allow_rewrite.sh /home/git "*.git"

# Script both for execution and inclusion.
[[ -n "$BASH" ]] || return 0 || exit 0 # exit to avoid continue if the return can not be called

function call()
{
  local IFS=$' \t'
  echo ">$*"
  "$@"
}

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
  local relpath="$(realpath -m --relative-to="$path0" -- "$path1")"

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

    local __shell="$(realpath -- "$(cygpath -w -- "$SHELL")")"
    local __path
    local __paths=()
    local __dists=()

    local RETURN_VALUE

    IFS=$'\r\n'; for __path in `where "$__value" 2>/dev/null`; do # IFS - with trim trailing line feeds
      __path="$(cygpath -w -- "$(realpath -- "${__path//\\//}")")"
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

function git_bare_config_allow_rewrite()
{
  local IFS

  local dir="${1:-.}"

  shift

  local dir_path_pttn_arr=()

  while [[ -n "${1+x}" ]]; do
    dir_path_pttn_arr=("${dir_path_pttn_arr[@]}" "$1")
    shift
  done

  # 1. prefix all relative paths with '*/' to apply the include/exclude dirs at any level
  # 2. escape all `\`

  # build include dir
  local find_bare_include_filter
  local dir_path_pttn

  for (( i=0; i < ${#dir_path_pttn_arr[@]}; i++ )); do
    dir_path_pttn="${dir_path_pttn_arr[i]}"

    if [[ "$dir_path_pttn" == '*' || "$dir_path_pttn" == '.' ]]; then
      dir_path_pttn=''
    fi

    if [[ -n "$dir_path_pttn" ]]; then
      # convert to backend path
      dir_path_pttn="$(cygpath -u -- "$dir_path_pttn")"

      if [[ "${dir_path_pttn:0:1}" != "/" && "${dir_path_pttn:0:2}" != "./" && "${dir_path_pttn:0:3}" != "../" ]]; then
        find_bare_include_filter="$find_bare_include_filter${find_bare_include_filter+ -o} -path \"*/${dir_path_pttn//\\/\\\\}\""
      else
        find_bare_include_filter="$find_bare_include_filter${find_bare_include_filter+ -o} -path \"${dir_path_pttn//\\/\\\\}\""
      fi
    fi
  done

  if [[ -n "$find_bare_include_filter" ]]; then
    find_bare_include_filter=" \\($find_bare_include_filter \\)"
  fi

  local git_path

  # detect find utility
  local findcmd
  detect_shell_userdir_file findcmd "find"

  local eval_find_expr='"$findcmd" "$dir" -type d -iname ".git"'"$find_bare_include_filter"

  #echo "$eval_find_expr"

  IFS=$'\r\n'; for git_path in `eval $eval_find_expr`; do # IFS - with trim trailing line feeds
    git_path="${git_path%/.git}"
    call pushd "$git_path" && {
      [[ "$(git rev-parse --is-bare-repository)" != 'true' ]] || call git config receive.denynonfastforwards false
      call popd

      echo -e "\n---\n"
    }
  done

  return 0
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_bare_config_allow_rewrite "$@"
fi
