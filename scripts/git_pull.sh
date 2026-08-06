#!/usr/bin/env bash

# USAGE:
#   git_pull.sh [<flags>]  // [<dir> [<dir-name-pattern>]] // [<cmdline>]
#   git_pull.sh [<flags>] [//] <dir> [<dir-name-pattern>]  // [<cmdline>]

# Description:
#   Script to pull repositories searched by the `find` pattern.

# <flags>:
#   -v
#     Verbose mode.
#
#   -w
#   --no-skip-worktrees
#     Don't skip traverse a worktree directories including nested worktrees.
#
#     NOTE:
#       By default the `find` command skips all the directories with a `.git`
#       file (the worktree directory does contain it).
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

# <dir-name-pattern>:
#   The directory name pattern to search for.
#   If empty, then `.git` is used.

# //:
#   Separator to stop parse path list.
#   NOTE:
#     The last separator `//` is required to the script positional parameters
#     from `<cmdline>`.

# <cmdline>:
#   The rest of command line passed to `git pull` command.

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

  echo "$@"

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
    echo)
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
    echo)
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

    local path

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

function git_pull()
{
  local IFS
  local flag="$1"

  local flag_v=0
  local no_skip_worktrees=0 # note: doesn't skip any directory with a `.git` file, not just the worktree directory only
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
  local i

  if (( ! no_colors )); then
    git_bare_flags=(-c color.ui=always --no-pager)
  else
    git_bare_flags=(-c color.ui=no --no-pager)
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

  # build exclude dirs
  local find_bare_flags

  # 1. prefix all relative paths with '*/' to apply the exclude dirs at any level
  # 2. suffix all paths with '/*' to exclude the search after the exclude directory
  # 3. escape all `\`
  for (( i=0; i < ${#exclude_dirs_arr[@]}; i++ )); do
    if [[ "${exclude_dirs_arr[i]:0:1}" != "/" && "${exclude_dirs_arr[i]:0:2}" != "./" && "${exclude_dirs_arr[i]:0:3}" != "../" ]]; then
      if (( no_skip_worktrees )); then
        exclude_dirs_arr[i]="*/${exclude_dirs_arr[i]}/*"
      else
        exclude_dirs_arr[i]="*/${exclude_dirs_arr[i]}"
      fi
    fi
    exclude_dirs_arr="${exclude_dirs_arr//\\/\\\\}"
  done

  for (( i=0; i < ${#exclude_dirs_arr[@]}; i++ )); do
    find_bare_flags="$find_bare_flags -not \\( -path \"${exclude_dirs_arr[i]}\" -prune \\)"
  done

  local is_record_printed=0

  function git_pull_impl()
  {
    local IFS=$' \t'

    if (( is_record_printed )); then
      echo -e "\n---\n"
    fi

    is_record_printed=0

    if (( ! no_color )); then
      exec_auto_buf echo -en "\e[0;32m"
    fi

    exec_auto_buf realpath "$git_path"

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

  if [[ -n "$name_pttn" ]]; then
    detect_find

    # cygwin workaround
    SHELL_FIND="${SHELL_FIND//\\//}"

    local eval_find_expr

    if (( no_skip_worktrees )); then
      eval_find_expr='"$SHELL_FIND" "$dir" -type d -iname "$name_pttn"'"$find_bare_flags"
    else
      eval_find_expr='"$SHELL_FIND" "$dir" -type d -exec test -e "{}/.git" \;'"$find_bare_flags"' -prune -print | { while IFS=$'\''\r\n'\'' read -r path; do if [[ ! -f "$path/.git" ]]; then echo $path; fi; done }'
    fi

    #echo "$eval_find_expr"

    IFS=$'\r\n'; for git_path in `eval $eval_find_expr`; do # IFS - with trim trailing line feeds
      git_path="${git_path%/.git}"
      git_pull_impl
    done
  else
    git_path="$dir"
    git_pull_impl
  fi

  if (( is_record_printed )); then
    echo -e "\n---\n"
  fi

  return 0
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_pull "$@"
fi
