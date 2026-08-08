#!/usr/bin/env bash

# USAGE:
#   git_pull.sh [<flags>] [//] [<dir> [<dir-path-pattern>...]] [// <cmdline>]

# Description:
#   Script to pull repositories searched by the `find` pattern.

# <flags>:
#   -v
#     Verbose mode.
#
#   -w
#   --no-skip-worktrees
#     Don't skip traverse of worktree directories including nested worktrees.
#     Has effect on the `find` utility and enables to search for `.git` as a
#     file additionally to as a directory.
#
#     NOTE:
#       By default the `find` command skips all the directories with a `.git`
#       file (a worktree directory does contain it).
#
#   -l
#   --no-colors
#     Print without colors.
#
#   --exclude-dirs <dirs-list>
#     List of directories to exclude from the search, where `<dirs-list>`
#     is a string evaluatable to the shell array.
#
#     If not defined, then the `DEFAULT_EXCLUDE_DIRS` and `USER_EXCLUDE_DIRS`
#     global variables is used.
#
#     If defined, then <dirs-list> is used instead of `DEFAULT_EXCLUDE_DIRS`
#     variable.
#
#     CAUTION:
#       To avoid use of the global `USER_EXCLUDE_DIRS` variable value you
#       may unset it or set it to anything before the call.
#       To avoid use of the global `DEFAULT_EXCLUDE_DIRS` variable value you
#       must set it to anything (can be empty) before the call.
#
#     If the `DEFAULT_EXCLUDE_DIRS` variable is not defined, then the builtin
#     default is used instead:
#
#       `"~*" ".git" ".svn" ".hg" ".log" ".temp" "_ext" "_externals" "ext" "externals" "_out" "out" "Output" "*.backup" "*.bak" "*.old" ".vs" "__pycache__"`
#
#     CAUTION:
#       In case of the parameter you have to quote or escape only the Unix file
#       globbing characters and a Unix shell special control characters:
#
#         `*`, `?`, `<`, `>`, `\`, `|`, `&`, `~`, `$`, `!`, `"`, `'`, ```, ...
#
#       In case of the variable you must quote or escape both the Windows AND
#       the Unix file globbing characters including a Unix shell special
#       control characters (depends on what subsystem or Shell is used):
#
#         `*`, `?`, `<`, `>`, `^`, `\`, `|`, `&`, `~`, `$`, `!`, `"`, `'`, ```, ...

# //:
#   Separator to stop parse flags.
#   NOTE:
#     Is required if <dir> is empty.

# <dir>:
#   The directory to start search from.
#   If empty, then `.` is used.

# <dir-path-pattern>...:
#   The directory path pattern list to search for.
#   The empty string, `.` and `*` has the same meaning and does search for all
#   repositories.

# //:
#   Separator to stop parse path list.
#   NOTE:
#     The last separator `//` is required before <cmdline>.

# <cmdline>:
#   The rest of command line passed to `git pull` command.
#   If empty, then `-s` is used.

# Examples:
#   >
#   git_pull.sh /home/git "*.git"
#
#   >
#   git_pull.sh --exclude-dirs '$MY_EXCLUDE_DIRS "*.suffix"'

# Script both for execution and inclusion.
[[ -n "$BASH" ]] || return 0 || exit 0 # exit to avoid continue if the return can not be called

function debug_echo()
{
  local last_error=$?
  local IFS=$' \t'

  echo "$@" >&2

  return $last_error
}

function call()
{
  local IFS=$' \t'

  if (( ! no_colors )); then
    echo -en "\e[1;33m"
  fi

  echo ">$*"

  if (( ! no_colors )); then
    echo -en "\e[0m"
  fi

  "$@"
}

# call with buffering
function call_buf()
{
  local IFS=$' \t'
  local buf
  local last_error=0

  case "$1" in
    echo | realpath | cygpath)
      # do not skip
      ;;
    *)
      # skip all flags
      while [[ "${1:0:1}" == '-' ]]; do shift; done
      ;;
  esac

  # prevent execution in a subshell
  case "$1" in
    pushd | popd)
      "$@" > /dev/null
      last_error=$?
      #IFS=$'\r\n'
      buf="${DIRSTACK[0]} ${DIRSTACK[1]}"
      ;;
    echo)
      ;;
    *)
      buf=$("$@")
      last_error=$?
      ;;
  esac

  IFS=$' \t'

  case "$1" in
    echo)
      "$@"
      last_error=$?
      ;;
    *)
      # if has not line return characters
      if [[ "$buf" =~ [^\r\n]+ ]]; then
        if (( ! no_colors )); then
          echo -en "\e[1;33m"
        fi

        echo ">$*"

        if (( ! no_colors )); then
          echo -en "\e[0m"
        fi

        echo "$buf"
        last_error=0
      else
        last_error=1
      fi
      ;;
  esac

  return $last_error
}

# exec with buffering
function exec_buf()
{
  local IFS=$' \t'
  local buf
  local last_error=0

  case "$1" in
    echo | realpath | cygpath)
      # do not skip
      ;;
    *)
      # skip all flags
      while [[ "${1:0:1}" == '-' ]]; do shift; done
      ;;
  esac

  # prevent execution in a subshell
  case "$1" in
    pushd | popd)
      "$@" > /dev/null
      last_error=$?
      #IFS=$'\r\n'
      buf="${DIRSTACK[0]} ${DIRSTACK[1]}"
      ;;
    echo)
      ;;
    *)
      buf=$("$@")
      last_error=$?
      ;;
  esac

  IFS=$' \t'

  case "$1" in
    echo)
      "$@"
      last_error=$?
      ;;
    *)
      # if not empty
      if [[ -n "$buf" ]]; then
        echo "$buf"
      fi
      ;;
  esac

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
  if (( ! is_buf )); then
    return
  fi

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

  return $last_error
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

function git_pull()
{
  local IFS

  local flag="$1"

  local flag_v=0
  local no_skip_worktrees=0 # NOTE: doesn't skip a directory with a `.git` file, not just only worktrees in a working copy
  local no_colors=0
  local exclude_dirs

  local skip_flag

  while [[ "${flag:0:1}" == '-' ]]; do
    flag="${flag:1}"
    skip_flag=0

    # long flags
    if [[ "$flag" == '-no-skip-worktrees' ]]; then
      no_skip_worktrees=1
      skip_flag=1
    elif [[ "$flag" == '-no-colors' ]]; then
      no_colors=1
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
        if [[ "${flag:0:1}" == 'w' ]]; then
          no_skip_worktrees=1
        elif [[ "${flag:0:1}" == 'l' ]]; then
          no_colors=1
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

  local dir="${1:-.}"

  shift

  local dir_path_pttn_arr=()

  while [[ -n "${1+x}" && "$1" != '//' ]]; do
    dir_path_pttn_arr=("${dir_path_pttn_arr[@]}" "$1")
    shift
  done

  if [[ "$1" == '//' ]]; then
    shift
  fi

  local args=("$@")

  local git_path
  local i

  if (( ! no_colors )); then
    local git_bare_flags=(-c color.ui=always --no-pager)
  else
    local git_bare_flags=(-c color.ui=no --no-pager)
  fi

  if [[ -z "${DEFAULT_EXCLUDE_DIRS+x}" ]]; then
    local DEFAULT_EXCLUDE_DIRS='"~*" ".git" ".svn" ".hg" ".log" ".temp" "_ext" "_externals" "ext" "externals" "_out" "out" "Output" "*.backup" "*.bak" "*.old" ".vs" "__pycache__"'
  fi

  if [[ -z "$exclude_dirs" ]]; then
    exclude_dirs="$DEFAULT_EXCLUDE_DIRS"
  fi

  # suppress empty string to avoid error: `fatal: empty string is not a valid pathspec. please use . instead if you meant to match all paths`
  if [[ "${args[*]}" = "" ]]; then
    args=()
  fi

  dir="${dir%/.git}"

  local exclude_dirs_arr
  eval exclude_dirs_arr=($exclude_dirs $USER_EXCLUDE_DIRS) || {
    echo "$0: error: invalid parameter.
$0: info: exclude_dirs: \`$exclude_dirs\`" >&2
    return 255
  }

  # 1. prefix all relative paths with '*/' to apply the include/exclude dirs at any level
  # 2. suffix all paths with '/*' to exclude the search after the directory
  # 3. escape all `\`

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

      if [[ "${dir_path_pttn:0:1}" != '/' && "${dir_path_pttn:0:2}" != './' && "${dir_path_pttn:0:3}" != '../' ]]; then
        find_bare_include_filter="$find_bare_include_filter${find_bare_include_filter+ -o} -path \"*/${dir_path_pttn//\\/\\\\}\""
      else
        find_bare_include_filter="$find_bare_include_filter${find_bare_include_filter+ -o} -path \"${dir_path_pttn//\\/\\\\}\""
      fi
    fi
  done

  if [[ -n "$find_bare_include_filter" ]]; then
    find_bare_include_filter=" \\($find_bare_include_filter \\)"
  fi

  # build exclude dirs
  local find_bare_exclude_filter
  local find_bare_exclude_filter2

  for (( i=0; i < ${#exclude_dirs_arr[@]}; i++ )); do
    # convert to backend path
    exclude_dirs_arr[i]="$(cygpath -u -- "${exclude_dirs_arr[i]}")"

    if [[ "${exclude_dirs_arr[i]:0:1}" != "/" && "${exclude_dirs_arr[i]:0:2}" != "./" && "${exclude_dirs_arr[i]:0:3}" != "../" ]]; then
      exclude_dirs_arr[i]="*/${exclude_dirs_arr[i]}"
    fi
    exclude_dirs_arr="${exclude_dirs_arr//\\/\\\\}"
  done

  for (( i=0; i < ${#exclude_dirs_arr[@]}; i++ )); do
    find_bare_exclude_filter="$find_bare_exclude_filter -not \\( -path \"${exclude_dirs_arr[i]}/*\" -prune \\)"
    if (( ! no_skip_worktrees )); then
      find_bare_exclude_filter2="$find_bare_exclude_filter2 -not \\( -path \"${exclude_dirs_arr[i]}\" -prune \\)"
    fi
  done

  local is_record_printed=0

  function git_pull_impl()
  {
    local IFS

    if (( is_record_printed )); then
      echo -e "\n---\n"
    fi

    is_record_printed=0

    if (( ! no_color )); then
      exec_auto_buf echo -en "\e[0;32m"
    fi

    exec_auto_buf realpath -- "$git_path"

    if (( ! no_color )); then
      exec_auto_buf echo -en "\e[0m"
    fi

    if (( ! is_buf )); then
      is_record_printed=1
    fi

    if (( flag_v )); then
      call_auto_buf pushd "$git_path"
    else
      pushd "$git_path" > /dev/null
    fi && {
      # pull repo
      call git ${git_bare_flags[*]} pull ${git_pull_flags[*]} "${args[@]}"

      if (( flag_v )); then
        call_auto_buf popd
      else
        popd > /dev/null
      fi
    }
  }

  # detect find utility
  local findcmd
  detect_shell_userdir_file findcmd "find"

  local eval_find_expr

  if (( no_skip_worktrees )); then
    eval_find_expr='"$findcmd" "$dir" -type d -iname ".git"'"$find_bare_include_filter$find_bare_exclude_filter"
  else
    eval_find_expr='"$findcmd" "$dir" -type d'"$find_bare_include_filter$find_bare_exclude_filter"' -exec test -e "{}/.git" \;'"$find_bare_exclude_filter2"' -prune -print | { while IFS=$'\''\r\n'\'' read -r path; do if [[ ! -f "$path/.git" ]]; then echo $path; fi; done }'
  fi

  #echo "$eval_find_expr"

  IFS=$'\r\n'; for git_path in `eval $eval_find_expr`; do # IFS - with trim trailing line feeds
    git_path="${git_path%/.git}"
    git_pull_impl
  done

  if (( is_record_printed )); then
    echo -e "\n---\n"
  fi

  return 0
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_pull "$@"
fi
