#!/usr/bin/env bash

# USAGE:
#   git_status.sh [<flags>]  // [<dir> [<dir-name-pattern>]] // [<cmdline>]
#   git_status.sh [<flags>] [//] <dir> [<dir-name-pattern>]  // [<cmdline>]

# Description:
#   Script to find repositories with uncommitted changes searched by the `find`
#   pattern.

# <flags>:
#   -v
#     Verbose mode.
#
#   --exclude-dirs <dirs-list>
#     List of directories to exclude from the search, where `<dirs-list>`
#     is a string evaluatable to the shell array.
#
#     If not defined, then the `DEFAULT_EXCLUDE_DIRS` global variable is
#     used.
#     If the global variable is not defined:
#
#       `"~*" ".git" ".svn" ".hg" ".log" ".temp" "_ext" "_externals" "ext" "_out" "out" "Output" "*.backup" "*.bak" "*.old" ".vs" "__pycache__"`
#
#     CAUTION:
#       In case of the parameter you have to quote or escape only the Unix file
#       globbing characters and a Unix shell special control characters:
#
#         `*`, `?`, `<`, `>`, `\`, `|`, `&`, `~`, `$`, `!`, `"`, `'`, ```, ...
#
#       In case of the `DEFAULT_EXCLUDE_DIRS` variable you must quote or
#       escape both the Windows AND the Unix file globbing characters
#       including a Unix shell special control characters (depends on what
#       subsystem or Shell is used):
#
#         `*`, `?`, `<`, `>`, `^`, `\`, `|`, `&`, `~`, `$`, `!`, `"`, `'`, ```, ...

# //:
#   Separator to stop parse flags.
#   NOTE:
#     Is required if <dir> is empty.

# <dir>:
#   The directory to start search from.
#   If empty, then `.` is used.

# <dir-name-pattern>:
#   The directory name pattern to search for.
#   If empty, then `.git` is used.

# //:
#   Separator to stop parse path list.
#   NOTE:
#     The last separator `//` is required to the script positional parameters
#     from `<cmdline>`.

# <cmdline>:
#   The rest of command line passed to `git status` command.
#   If empty, then `-s` is used.

# Examples:
#   >
#   git_status.sh /home/git "*.git"
#
#   >
#   git_status.sh --exclude-dirs '$MY_EXCLUDE_DIRS "*.suffix"'

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
      old_shopt=''
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

function git_status()
{
  local flag="$1"

  local flag_v=0
  local exclude_dirs

  local skip_flag

  while [[ "${flag:0:1}" == '-' ]]; do
    flag="${flag:1}"
    skip_flag=0

    # long flags
    if [[ "$flag" == '-exclude-dirs' ]]; then
      exclude_dirs="$2"
      skip_flag=1
      shift
    elif [[ "${flag:0:1}" == '-' ]]; then
      echo "$0: error: invalid flag: \`$flag\`" >&2
      return 255
    fi

    # short flags
    if (( ! skip_flag )); then
      while [[ -n "$flag" ]]; do
        if [[ "${flag:0:1}" == 'v' ]]; then
          flag_v=0
        else
          echo "$0: error: invalid flag: \`${flag:0:1}\`" >&2
          return 255
        fi
        flag="${flag:1}"
      done
    fi

    shift

    flag="$1"
  done

  if [[ "$1" == '//' ]]; then
    shift
  fi

  local dir="$1"
  local name_pttn="$2"

  shift 2

  if [[ -n "$1" && "$1" != '//' ]]; then
    echo "$0: error: missed cmdline separator: \`//\`" >&2
    return 255
  fi

  shift

  local args=("$@")

  local git_path

  local IFS
  local i

  if [[ -z "$dir" ]]; then
    dir=.
  fi
  if [[ -z "$name_pttn" ]]; then
    name_pttn=.git
  fi

  if [[ -z "${DEFAULT_EXCLUDE_DIRS+x}" ]]; then
    local DEFAULT_EXCLUDE_DIRS='"~*" ".git" ".svn" ".hg" ".log" ".temp" "_ext" "_externals" "ext" "_out" "out" "Output" "*.backup" "*.bak" "*.old" ".vs" "__pycache__"'
  fi

  if [[ -z "$exclude_dirs" ]]; then
    exclude_dirs="$DEFAULT_EXCLUDE_DIRS"
  fi

  if (( ! ${#args[@]} )); then
    args=(-s)
  # suppress empty string to avoid error: `fatal: empty string is not a valid pathspec. please use . instead if you meant to match all paths`
  elif [[ "${args[*]}" = "" ]]; then
    args=()
  fi

  dir="${dir%/.git}"

  local exclude_dirs_arr
  eval exclude_dirs_arr=($exclude_dirs) || {
    echo "$0: error: invalid parameter.
$0: info: exclude_dirs: \`$exclude_dirs\`" >&2
    return 255
  }

  # build exclude dirs
  local find_bare_flags

  # prefix all relative paths with '*/' to apply the exclude dirs at any level
  # suffix all paths with '/*' to exclude the search after the exclude directory
  for (( i=0; i < ${#exclude_dirs_arr[@]}; i++ )); do
    if [[ "${exclude_dirs_arr[i]:0:1}" != "/" && "${exclude_dirs_arr[i]:0:2}" != "./" && "${exclude_dirs_arr[i]:0:3}" != "../" ]]; then
      exclude_dirs_arr[i]="*/${exclude_dirs_arr[i]}/*"
    fi
  done

  for (( i=0; i < ${#exclude_dirs_arr[@]}; i++ )); do
    find_bare_flags="$find_bare_flags -not \\( -path \"${exclude_dirs_arr[i]}\" -prune \\)"
  done

  if [[ -n "$name_pttn" ]]; then
    detect_find

    # cygwin workaround
    SHELL_FIND="${SHELL_FIND//\\//}"

    IFS=$'\r\n'; for git_path in `eval \"\$SHELL_FIND\" \"\$dir\"$find_bare_flags -iname \"\$name_pttn\" -type d`; do # IFS - with trim trailing line feeds
      git_path="${git_path%/.git}"

      if (( flag_v )); then
        call pushd "$git_path" && {
          call git status "${args[@]}"
          call popd
        }
      else
        realpath "$git_path"
        pushd "$git_path" > /dev/null && {
          call git status "${args[@]}"
          popd > /dev/null
        }
      fi
      echo ---
    done
  else
    git_path="${git_path%/.git}"

    if (( flag_v )); then
      call pushd "$dir" && {
        call git status "${args[@]}"
        call popd
      }
    else
      realpath "$dir"
      pushd "$dir" > /dev/null && {
        call git status "${args[@]}"
        popd > /dev/null
      }
    fi
    echo ---
  fi

  return 0
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_status "$@"
fi
