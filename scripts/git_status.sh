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
#   -n
#   --no-print-empty
#     Don't print empty output or with only empty lines (only line returns).
#
#     NOTE:
#       The print only a not empty output results in the output buffering,
#       which means the result won't be printed until a command exit. So this
#       implies disable of the piping.
#
#   -S
#   --no-stashes
#     Don't print stashes.
#
#   --no-unmerged-conflicts
#     Don't print unmerged conflicts (`git diff --diff-filter=U ...`).
#     Details: https://stackoverflow.com/questions/3065650/whats-the-simplest-way-to-list-conflicted-files-in-git#
#
#   --no-diff-checks
#     Don't print diff checks (`git diff --check ...`).
#
#   -L
#   --no-conflicts
#     Excludes all conflicts.
#     Implies `--no-unmerged-conflicts`.
#
#   -N
#   --no-checks
#     Excludes all checks.
#     Implies `--no-diff-checks`.
#
#   -l
#   --no-colors
#     Print without colors.
#
#   -s
#   --status-only
#     Print status only.
#     Implies `--no-stashes`, `--no-conflicts`, `--no-checks` flags.
#
#   --exclude-dirs <dirs-list>
#     List of directories to exclude from the search, where `<dirs-list>`
#     is a string evaluatable to the shell array.
#
#     If not defined, then the `DEFAULT_EXCLUDE_DIRS` global variable is
#     used.
#     If the global variable is not defined:
#
#       `"~*" ".git" ".svn" ".hg" ".log" ".temp" "_ext" "_externals" "ext" "externals" "_out" "out" "Output" "*.backup" "*.bak" "*.old" ".vs" "__pycache__"`
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
#
#   >
#   # prints not empty status only
#   git_status.sh -sn

# NOTE:
#   By default the `CR` character is treated as a white space by the Git.
#   To avoid this you can declare the `CR` as not a white space in case of
#   `CRLF` sequence:
#
#     >
#     git config --system core.whitespace cr-at-eol

# Script both for execution and inclusion.
[[ -n "$BASH" ]] || return 0 || exit 0 # exit to avoid continue if the return can not be called

function debug_echo()
{
  local last_error=$?
  local IFS=$' \t'

  echo "$@"

  return $last_error
}

function call()
{
  local IFS=$' \t'
  echo ">$*"
  "$@"
}

# call with buffering
function call_buf()
{
  local IFS=$' \t'
  local buf
  local last_error

  # skip all flags
  while [[ "${1:0:1}" == '-' ]]; do shift; done

  # prevent execution in a subshell
  case "$1" in
    pushd | popd)
      "$@" > /dev/null
      last_error=$?
      #IFS=$'\r\n'
      buf="${DIRSTACK[0]} ${DIRSTACK[1]}"
      ;;
    *)
      buf=$("$@")
      last_error=$?
      ;;
  esac

  # if has not line return characters
  if [[ "$buf" =~ [^\r\n]+ ]]; then
    IFS=$' \t' echo ">$*"
    echo "$buf"
    last_error=0
  else
    last_error=1
  fi

  return $last_error
}

# exec with buffering
function exec_buf()
{
  local IFS=$' \t'
  local buf
  local last_error

  # skip all flags
  while [[ "${1:0:1}" == '-' ]]; do shift; done

  # prevent execution in a subshell
  case "$1" in
    pushd | popd)
      "$@" > /dev/null
      last_error=$?
      #IFS=$'\r\n'
      buf="${DIRSTACK[0]} ${DIRSTACK[1]}"
      ;;
    *)
      buf=$("$@")
      last_error=$?
      ;;
  esac

  # if not empty
  if [[ -n "$buf" ]]; then
    echo "$buf"
  fi

  return $last_error
}

# call with accumulated buffering
function call_accum_buf()
{
  local IFS=$' \t'
  call_buf "$@" >> "$accum_buf_file"
}

# exec with accumulated buffering
function exec_accum_buf()
{
  local IFS=$' \t'
  exec_buf "$@" >> "$accum_buf_file"
}

function call_auto_buf()
{
  if (( is_buf )); then
    call_accum_buf "$@"
  else
    call "$@"
  fi
}

function exec_auto_buf()
{
  if (( is_buf )); then
    exec_accum_buf "$@"
  else
    "$@"
  fi
}

function accum_buf_status()
{
  local last_error=$?

  if (( is_buf )); then
    if (( ! last_error )); then
      (( has_accum_buf |= 1 ))
    fi
  fi
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
  local no_print_empty=0
  local no_stashes=0
  local no_unmerged_conflicts=0
  local no_diff_checks=0
  local no_conflicts=0
  local no_checks=0
  local no_colors=0
  local status_only=0
  local exclude_dirs

  local skip_flag

  while [[ "${flag:0:1}" == '-' ]]; do
    flag="${flag:1}"
    skip_flag=0

    # long flags
    if [[ "$flag" == '-no-print-empty' ]]; then
      no_print_empty=1
      skip_flag=1
    elif [[ "$flag" == '-no-stashes' ]]; then
      no_stashes=1
      skip_flag=1
    elif [[ "$flag" == '-no-unmerged-conflicts' ]]; then
      no_unmerged_conflicts=1
      skip_flag=1
    elif [[ "$flag" == '-no-diff-checks' ]]; then
      no_diff_checks=1
      skip_flag=1
    elif [[ "$flag" == '-no-conflicts' ]]; then
      no_conflicts=1
      skip_flag=1
    elif [[ "$flag" == '-no-checks' ]]; then
      no_checks=1
      skip_flag=1
    elif [[ "$flag" == '-no-colors' ]]; then
      no_colors=1
      skip_flag=1
    elif [[ "$flag" == '-status-only' ]]; then
      status_only=1
      skip_flag=1
    elif [[ "$flag" == '-exclude-dirs' ]]; then
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
        if [[ "${flag:0:1}" == 'n' ]]; then
          no_print_empty=1
        elif [[ "${flag:0:1}" == 'S' ]]; then
          no_stashes=1
        elif [[ "${flag:0:1}" == 'L' ]]; then
          no_conflicts=1
        elif [[ "${flag:0:1}" == 'N' ]]; then
          no_checks=1
        elif [[ "${flag:0:1}" == 'l' ]]; then
          no_colors=1
        elif [[ "${flag:0:1}" == 's' ]]; then
          status_only=1
        elif [[ "${flag:0:1}" == 'v' ]]; then
          flag_v=1
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

  if (( status_only )); then
    no_stashes=1
    no_conflicts=1
    no_checks=1
  fi

  if (( no_conflicts )); then
    no_unmerged_conflicts=1
  fi
  if (( no_checks )); then
    no_diff_checks=1
  fi

  if (( ! no_colors )); then
    git_bare_flags=(-c color.ui=always --no-pager)
    git_diff_bare_flags=(--color=always)
  else
    git_bare_flags=(-c color.ui=no --no-pager)
    git_diff_bare_flags=(--color=never)
  fi

  if [[ -z "$dir" ]]; then
    dir=.
  fi
  if [[ -z "$name_pttn" ]]; then
    name_pttn=.git
  fi

  if [[ -z "${DEFAULT_EXCLUDE_DIRS+x}" ]]; then
    local DEFAULT_EXCLUDE_DIRS='"~*" ".git" ".svn" ".hg" ".log" ".temp" "_ext" "_externals" "ext" "externals" "_out" "out" "Output" "*.backup" "*.bak" "*.old" ".vs" "__pycache__"'
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

  local is_buf=0

  if (( no_print_empty )); then
    is_buf=1
  fi

  if (( is_buf )); then
    local has_accum_buf
    local accum_buf_file="$(mktemp /tmp/accum_buf.XXXXXX)"

    trap 'rm "$accum_buf_file"; trap - RETURN' RETURN
  fi

  function git_status_impl()
  {
    local IFS=$' \t'

    if (( is_buf )); then
      has_accum_buf=0
      : > "$accum_buf_file" # trim the buffer
    fi

    if (( flag_v )); then
      call_auto_buf pushd "$git_path"
    else
      exec_auto_buf realpath "$git_path"
      pushd "$git_path" > /dev/null
    fi && {
      # print status
      call_auto_buf git ${git_bare_flags[*]} status "${args[@]}"
      accum_buf_status

      # print stashes
      if (( ! no_stashes )); then
        call_auto_buf git ${git_bare_flags[*]} stash list
        accum_buf_status
      fi

      # print unmerged conflicts
      if (( ! no_unmerged_conflicts )); then
        call_auto_buf git ${git_bare_flags[*]} diff ${git_diff_bare_flags[*]} --name-only --diff-filter=U --relative
        accum_buf_status
      fi

      # print diff checks
      if (( ! no_diff_checks )); then
        call_auto_buf git ${git_bare_flags[*]} diff ${git_diff_bare_flags[*]} --check
        accum_buf_status
      fi

      if (( flag_v )); then
        call_auto_buf popd
      else
        popd > /dev/null
      fi
    }

    exec_auto_buf echo ---

    if (( has_accum_buf )); then
      cat "$accum_buf_file"
    fi
  }

  if [[ -n "$name_pttn" ]]; then
    detect_find

    # cygwin workaround
    SHELL_FIND="${SHELL_FIND//\\//}"

    IFS=$'\r\n'; for git_path in `eval \"\$SHELL_FIND\" \"\$dir\"$find_bare_flags -iname \"\$name_pttn\" -type d`; do # IFS - with trim trailing line feeds
      git_path="${git_path%/.git}"
      git_status_impl
    done
  else
    git_path="$dir"
    git_status_impl
  fi

  return 0
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_status "$@"
fi
