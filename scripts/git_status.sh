#!/usr/bin/env bash

# USAGE:
#   git_status.sh [<flags>] [//] [<dir> [<dir-path-pattern>...]] [// <cmdline>]

# Description:
#   Script to find repositories with uncommitted changes searched by the `find`
#   pattern. In addition the script makes different checks.

# <flags>:
#   -v
#     Verbose mode.
#     Prints worktrees list of a single worktree even if not added.
#
#   -n
#   --no-print-empty
#     Don't print empty output or with only empty lines (only line returns).
#
#     NOTE:
#       The print only a not empty output does result in the output buffering,
#       which means the result won't be printed until a command exit. So this
#       implies disable of a line-by-line piping.
#
#     NOTE:
#       You can mix `-v` and `-n`, in which case a verbose mode is used, but
#       the commands has contained an empty output does not print.
#
#   -C
#   --no-print-config
#     Don't print all config keys.
#     By default does print a not default `core` key values.
#     Multiple values is considered not default even if all or the last value
#     is default.
#     Boolean values other than `true`/`false` is considered not default even
#     if treated boolean by the Git or has a different case.
#
#   -W
#   --no-worktrees
#     Don't traverse worktrees from a working copy.
#     Has no effect on the `find` command, by default it skips all the
#     directories with a `.git` file (a worktree directory does contain it).
#
#     NOTE:
#       To keep look inside a worktree using the `find` command you have to
#       explicitly use the `--no-skip-worktrees` flag.
#
#   -w
#   --no-skip-worktrees
#     Don't skip traverse of worktree directories including nested worktrees.
#     Has effect on the `find` utility and enables to search for `.git` as a
#     file additionally to as a directory.
#
#   -S
#   --no-stashes
#     Don't traverse stashes.
#
#   --no-unmerged-conflicts
#     Don't check unmerged conflicts (`git diff --diff-filter=U ...`).
#     Details: https://stackoverflow.com/questions/3065650/whats-the-simplest-way-to-list-conflicted-files-in-git#
#
#   --no-diff-checks
#     Don't make diff checks (`git diff --check ...`).
#
#   -L
#   --no-conflicts
#     Excludes all conflicts.
#     Implies `--no-unmerged-conflicts`.
#
#   -h
#   --no-log-ahead-behind
#     Don't check unpushed (ahead) and unpulled (behind) commits in local
#     branches for all remotes using `git log` command.
#     By default traverse all remotes including those not yet pushed ignoring
#     upstream configuration.
#     Counts commits for each local branch and prints number of commits which
#     are ahead and behind to a remote counterpart.
#     Use `git log --oneline` to print ahead and behind commit details.
#     By default the output length is limited to 10 commits.
#
#   --no-warn-missed-branch-refs
#     Don't warn of missed branch references on the local or remote.
#
#   -N
#   --no-checks
#     Excludes all checks.
#     Implies `--no-print-config`, `--no-diff-checks`, `--no-log-ahead-behind`
#     flags.
#
#   -l
#   --no-colors
#     Print without colors.
#
#   -s
#   --status-only
#     Print status only.
#     Implies `--no-print-config`, `--no-stashes`, `--no-log-ahead-behind`,
#     `--no-conflicts`, `--no-checks` flags.
#
#     NOTE:
#       To exclude traverse of worktrees you have to explicitly use
#       `--no-worktrees` flag.
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

# call with accumulated temp buffering
function call_temp_buf()
{
  local IFS=$' \t'
  call_buf "$@" > "$temp_buf_file"
}

function print_accum_temp_buf()
{
  if (( is_buf )); then
    echo "$(<"$temp_buf_file")" >> "$accum_buf_file"
  else
    echo "$(<"$temp_buf_file")"
  fi

  : > "$temp_buf_file" # trim the buffer
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

# NOTE:
#
#   * `tkl_*trim*`
#
#   Based on: https://github.com/dylanaraps/pure-bash-bible#trim-leading-and-trailing-white-space-from-string

function tkl_ltrim_char_cls()
{
  local str="$1"
  local char_class="$2"

  RETURN_VALUE="${str#"${str%%$char_class*}"}"
}

function tkl_rtrim_char_cls()
{
  local str="$1"
  local char_class="$2"

  RETURN_VALUE="${str%"${str##*$char_class}"}"
}

function tkl_trim_char_cls()
{
  tkl_ltrim_char_cls "$1" "$2"
  tkl_rtrim_char_cls "$RETURN_VALUE" "$2"
}

function tkl_ltrim_chars()
{
  tkl_ltrim_char_cls "$1" "[^$2]"
}

function tkl_rtrim_chars()
{
  tkl_rtrim_char_cls "$1" "[^$2]"
}

function tkl_trim_chars()
{
  tkl_trim_char_cls "$1" "[^$2]"
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

function git_status()
{
  local IFS

  local flag="$1"

  local flag_v=0
  local no_print_empty=0
  local no_print_config=0
  local no_worktrees=0
  local no_skip_worktrees=0 # NOTE: doesn't skip a directory with a `.git` file, not just only worktrees in a working copy
  local no_stashes=0
  local no_unmerged_conflicts=0
  local no_diff_checks=0
  local no_conflicts=0
  local no_log_ahead_behind=0
  local no_warn_missed_branch_refs=0
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
    elif [[ "$flag" == '-no-print-config' ]]; then
      no_print_config=1
      skip_flag=1
    elif [[ "$flag" == '-no-stashes' ]]; then
      no_stashes=1
      skip_flag=1
    elif [[ "$flag" == '-no-worktrees' ]]; then
      no_worktrees=1
      skip_flag=1
    elif [[ "$flag" == '-no-skip-worktrees' ]]; then
      no_skip_worktrees=1
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
    elif [[ "$flag" == '-no-log-ahead-behind' ]]; then
      no_log_ahead_behind=1
      skip_flag=1
    elif [[ "$flag" == '-no-warn-missed-branch-refs' ]]; then
      no_warn_missed_branch_refs=1
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
        elif [[ "${flag:0:1}" == 'C' ]]; then
          no_print_config=1
        elif [[ "${flag:0:1}" == 'W' ]]; then
          no_worktrees=1
        elif [[ "${flag:0:1}" == 'w' ]]; then
          no_skip_worktrees=1
        elif [[ "${flag:0:1}" == 'S' ]]; then
          no_stashes=1
        elif [[ "${flag:0:1}" == 'L' ]]; then
          no_conflicts=1
        elif [[ "${flag:0:1}" == 'h' ]]; then
          no_log_ahead_behind=1
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

  if (( status_only )); then
    no_print_config=1
    no_stashes=1
    no_conflicts=1
    no_checks=1
  fi

  if (( no_conflicts )); then
    no_unmerged_conflicts=1
  fi
  if (( no_checks )); then
    no_print_config=1
    no_diff_checks=1
  fi

  local git_bare_script_flags=(-c color.ui=no --no-pager)

  if (( ! no_colors )); then
    local git_bare_flags=(-c color.ui=always --no-pager)
    local git_diff_bare_flags=(--color=always)
  else
    local git_bare_flags=(-c color.ui=no --no-pager)
    local git_diff_bare_flags=(--color=never)
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

  local is_buf=0

  if (( no_print_empty )); then
    is_buf=1
  fi

  local temp_buf_file="$(mktemp /tmp/temp_buf.XXXXXX)"

  if (( is_buf )); then
    local has_accum_buf=0
    local accum_buf_file="$(mktemp /tmp/accum_buf.XXXXXX)"

    : > "$accum_buf_file" # trim the buffer

    function git_status_cleanup_impl()
    {
      rm "$accum_buf_file"
      rm "$temp_buf_file"
    }
  else
    function git_status_cleanup_impl()
    {
      rm "$temp_buf_file"
    }
  fi

  trap 'git_status_cleanup_impl; trap - RETURN' RETURN

  : > "$temp_buf_file" # trim the buffer

  local is_record_printed=0
  local has_recurse_records
  local git_worktree_list
  local git_worktree_recurse=0
  local git_bare_C_path=()

  function has_worktrees()
  {
    local IFS

    local git_worktree_path _
    local i=0

    while IFS=$' \t' read git_worktree_path _; do
      if (( i >= 2 )); then # skip first 2 lines
        return 0
      fi
      (( i++ ))
    done < "$1"

    return 1
  }

  function git_worktree_recurse_impl()
  {
    local IFS

    local git_worktree_path _
    local i=0

    if (( is_buf )); then
      if (( has_accum_buf )); then
        #echo ===
        echo "$(<"$accum_buf_file")"
        has_accum_buf=0
        is_record_printed=1
      fi

      : > "$accum_buf_file" # trim the buffer
    fi

    trap 'git_worktree_list=''; git_worktree_recurse=0; git_bare_C_path=(); trap - RETURN' RETURN

    git_worktree_recurse=1

    while IFS=$' \t' read git_worktree_path _; do
      if (( i >= 2 )); then # skip first 2 lines
        git_bare_C_path=(-C "$git_worktree_path")
        git_status_impl
      fi
      (( i++ ))
    done <<< "$git_worktree_list"
  }

  function git_log_ahead_behind_impl()
  {
    local IFS

    local remote remote_url branch
    local i j buf err_buf
    local eval_git_log_ahead_behind_cmd
    local revrange has_remote_branch_ref has_remote_branch
    local local_branch_arr=()
    local remote_arr=() remote_url_arr=()
    local has_local_branch has_local_branch_arr=()
    local is_remote_url_and_branch_printed print_remote_url_and_branch_spacer=0
    local print_git_log_ahead_behind_header is_git_log_ahead_behind_header_buf_printed

    function git_log_print_ahead_behind_header_impl()
    {
      print_git_log_ahead_behind_header=0
      is_git_log_ahead_behind_header_buf_printed=0

      if (( ! no_color )); then
        exec_auto_buf echo -en "\e[1;37m"
      fi

      exec_auto_buf echo -e "\nLog ahead/behind commits:\n"

      if (( ! no_color )); then
        exec_auto_buf echo -en "\e[0m"
      fi

      if (( ! is_buf )); then
        is_record_printed=1
      fi
    }

    git_log_print_ahead_behind_header_impl

    while IFS=$'\r\n' read remote; do
      remote_arr=("${remote_arr[@]}" "$remote")

      IFS=$'\r\n' read remote_url <<< "$(git remote get-url "$remote")"
      remote_url_arr=("${remote_url_arr[@]}" "$remote_url")
    done < <(git remote)

    while IFS=$'\r\n' read branch; do
      local_branch_arr=("${local_branch_arr[@]}" "$branch")

      git show-ref -q --verify "refs/heads/$branch"
      has_local_branch_arr=( "${has_local_branch_arr[@]}" $(( ! $? )) )
    done < <(git for-each-ref --format="%(refname:short)" refs/heads)

    for (( i=0; i < ${#remote_arr[@]}; i++ )); do
      remote="${remote_arr[i]}"
      remote_url="${remote_url_arr[i]}"

      for (( j=0; j < ${#local_branch_arr[@]}; j++ )); do
        branch="${local_branch_arr[j]}"
        has_local_branch=${has_local_branch_arr[j]}

        has_remote_branch_ref=''
        has_remote_branch=''

        is_remote_url_and_branch_printed=0

        for revrange in "refs/remotes/$remote/$branch..refs/heads/$branch" "refs/heads/$branch..refs/remotes/$remote/$branch"; do
          eval_git_log_ahead_behind_cmd="git ${git_bare_flags[*]} log -n 10 --graph --oneline --decorate $revrange"

          if (( print_git_log_ahead_behind_header && ! is_git_log_ahead_behind_header_buf_printed )); then
            git_log_print_ahead_behind_header_impl
          fi

          if (( ! is_remote_url_and_branch_printed )); then
            is_remote_url_and_branch_printed=1

            if (( print_remote_url_and_branch_spacer )); then
              exec_auto_buf echo
            fi

            print_remote_url_and_branch_spacer=1

            if (( ! no_color )); then
              exec_auto_buf echo -en "\e[1;36m"
            fi

            exec_auto_buf echo -n "$remote"

            if (( ! no_color )); then
              exec_auto_buf echo -en "\e[0m"
            fi

            exec_auto_buf echo -n " -> "

            if (( ! no_color )); then
              exec_auto_buf echo -en "\e[1;36m"
            fi

            exec_auto_buf echo -n "$remote_url"

            if (( ! no_color )); then
              exec_auto_buf echo -en "\e[0m"
            fi

            exec_auto_buf echo -n "@"

            if (( ! no_color )); then
              exec_auto_buf echo -en "\e[1;32m"
            fi

            exec_auto_buf echo "$branch"

            if (( ! no_color )); then
              exec_auto_buf echo -en "\e[0m"
            fi

            if (( ! is_buf )); then
              is_record_printed=1
            fi
          fi

          if (( ! no_color )); then
            exec_auto_buf echo -en "\e[0;33m"
          fi

          exec_auto_buf echo ">$eval_git_log_ahead_behind_cmd"

          if (( ! no_color )); then
            exec_auto_buf echo -en "\e[0m"
          fi

          if (( ! is_buf )); then
            is_record_printed=1
          fi

          if [[ -z "$has_remote_branch_ref" ]]; then
            git show-ref -q --verify "refs/remotes/$remote/$branch"; has_remote_branch_ref=$(( ! $? ))
          fi

          if [[ -z "$has_remote_branch" ]]; then
            err_buf="$(git ls-remote -q --exit-code --refs "$remote" "refs/heads/$branch" 2>&1 >/dev/null)"; has_remote_branch=$(( ! $? ))
          else
            err_buf=''
          fi

          if (( has_local_branch && has_remote_branch_ref && has_remote_branch )); then
            buf="$(eval $eval_git_log_ahead_behind_cmd)"
          elif (( ! no_warn_missed_branch_refs )); then
            buf=' '
            if (( ! has_local_branch )); then
              buf="$buf[NO LOCAL BRANCH]"
            fi
            if (( ! has_remote_branch_ref )); then
              buf="$buf[NO REMOTE BRANCH REF]"
            fi
            if (( ! has_remote_branch )); then
              buf="$buf[NO REMOTE BRANCH]"
            fi
            buf="$buf"$'\n'
          else
            buf=''
          fi

          # if not empty
          if [[ -n "$buf" ]]; then
            exec_auto_buf echo "$buf"
            accum_buf_status
          fi

          if [[ -n "$err_buf" ]]; then
            exec_auto_buf echo -n "$err_buf"
            accum_buf_status
          fi

          if (( is_buf )); then
            if (( has_accum_buf )); then
              #echo ===
              echo "$(<"$accum_buf_file")"
              has_accum_buf=0
              is_record_printed=1
              is_git_log_ahead_behind_header_buf_printed=1
            else
              is_remote_url_and_branch_printed=0
            fi

            : > "$accum_buf_file" # trim the buffer

            if (( ! is_git_log_ahead_behind_header_buf_printed )); then
              print_git_log_ahead_behind_header=1
            fi
          fi
        done
      done
    done
  }

  function git_status_impl()
  {
    local IFS

    if (( is_record_printed )); then
      echo -e "\n---\n"
    fi

    is_record_printed=0

    if (( no_worktrees || ! git_worktree_recurse )); then
      has_recurse_records=0

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
      fi
    else
      if (( ! no_color )); then
        exec_auto_buf echo -en "\e[0;36m"
      fi

      exec_auto_buf echo "$git_worktree_path (worktree)"

      if (( ! no_color )); then
        exec_auto_buf echo -en "\e[0m"
      fi

      if (( ! is_buf )); then
        is_record_printed=1
      fi

      :
    fi && {
      # print not default configuration
      if (( ! no_print_config )); then
        local git_config_type

        for git_config_type in local; do
          print_not_default_git_config_key_value_impl
        done

        if [[ -f '.git/config.worktree' ]]; then
          for git_config_type in worktree; do
            print_not_default_git_config_key_value_impl
          done
        fi
      fi

      # request, save and print worktrees
      if (( ! no_worktrees && ! git_worktree_recurse )); then
        if call_temp_buf git ${git_bare_flags[*]} worktree list; then
          # CAUTION: The `if` statement must has a complete form (together with the `else`), otherwise trailing `&&` would NOT work!
          if (( flag_v )); then
            :
          elif has_worktrees "$temp_buf_file"; then
            has_recurse_records=1
            :
          else
            ! : # instead of `false` call, faster
          fi && {
            git_worktree_list=$(<"$temp_buf_file")
            print_accum_temp_buf
            accum_buf_status
          }
        fi
      fi

      # print status
      call_auto_buf git ${git_bare_C_path[*]} ${git_bare_flags[*]} status "${args[@]}"
      accum_buf_status

      # print stashes
      if (( ! no_stashes && ! git_worktree_recurse )); then
        call_auto_buf git ${git_bare_C_path[*]} ${git_bare_flags[*]} stash list
        accum_buf_status
      fi

      # print unmerged conflicts
      if (( ! no_unmerged_conflicts )); then
        call_auto_buf git ${git_bare_C_path[*]} ${git_bare_flags[*]} diff ${git_diff_bare_flags[*]} --name-only --diff-filter=U --relative
        accum_buf_status
      fi

      # print diff checks
      if (( ! no_diff_checks )); then
        call_auto_buf git ${git_bare_C_path[*]} ${git_bare_flags[*]} diff ${git_diff_bare_flags[*]} --check
        accum_buf_status
      fi

      # print log ahead/behind
      if (( ! no_log_ahead_behind )); then
        git_log_ahead_behind_impl
      fi

      # traverse worktrees starting from the second
      if (( ! no_worktrees && ! git_worktree_recurse && ( flag_v || has_recurse_records ) )); then
        git_worktree_recurse_impl
      fi

      if (( ! git_worktree_recurse )); then
        if (( flag_v )); then
          call_auto_buf popd
        else
          popd > /dev/null
        fi
      fi
    }

    if (( is_buf )); then
      if (( has_accum_buf )); then
        #echo ===
        echo "$(<"$accum_buf_file")"
        has_accum_buf=0
        is_record_printed=1
      fi

      : > "$accum_buf_file" # trim the buffer
    fi
  }

  function git_config_globals_init_and_check_impl()
  {
    local IFS

    # CAUTION:
    #   All Git config keys does print in lower case in Windows.

    local SOURCE_FILE=${BASH_SOURCE[0]:-${0//\\//}}

    if [[ "${SOURCE_FILE:0:1}" == '/' || "${SOURCE_FILE:1:1}" == ':' ]]; then
      local SOURCE_DIR=${SOURCE_FILE%/*}
    elif [[ "${SOURCE_FILE/\//}" != "$SOURCE_FILE" && "${SOURCE_FILE%/*}" != '.' ]]; then
      local SOURCE_DIR=$PWD/${SOURCE_FILE%/*}
    else
      local SOURCE_DIR=$PWD
    fi

    local cfg_line
    local key_os_type key value

    known_config_default_key_prefixes=(core.)
    known_config_default_keys_os_type=()
    known_config_default_keys=()
    known_config_default_values=()

    while IFS=$'\r\n' read cfg_line; do
      IFS=$'\r\n' read -d '#' cfg_line <<< "$cfg_line"
      IFS='=' read key value <<< "$cfg_line"
      IFS=':' read key_os_type key <<< "$key"

      if [[ -n "$key_os_type" ]]; then
        tkl_trim_chars "$key_os_type" '[:space:]'
        key_os_type="$RETURN_VALUE"
      fi

      if [[ -n "$key" ]]; then
        tkl_trim_chars "$key" '[:space:]'
        key="$RETURN_VALUE"
      else
        key="$key_os_type"
        key_os_type=''
      fi

      if [[ -n "$value" ]]; then
        tkl_trim_chars "$value" '[:space:]'
        value="$RETURN_VALUE"
      fi

      if [[ -n "$key" ]]; then
        #echo "$key_os_type${key_os_type:+:}$key=$value"
        known_config_default_keys_os_type=("${known_config_default_keys_os_type[@]}" "$key_os_type")
        known_config_default_keys=("${known_config_default_keys[@]}" "$key")
        known_config_default_values=("${known_config_default_values[@]}" "$value")
      fi
    done < "$SOURCE_DIR/.impl/default_git_config.in"

    # detect sort utility
    detect_shell_userdir_file sortcmd "sort"

    if [[ "$sortcmd" != 'sort' ]]; then
      sortcmd="'${sortcmd//\'/\'\\\'\'}'"
    fi

    function print_not_default_git_config_key_value_impl()
    {
      local IFS

      local cfg_key cfg_value last_known_cfg_key last_filtered_cfg
      local known_cfg last_known_applied_key known_key_prefix
      local i buf
      local set_shopt_nocasematch
      local is_known_key

      local eval_git_config_system_cmd="git ${git_bare_script_flags[*]} config --$git_config_type --list | $sortcmd -s -t= -k1,1d"

      if (( ! no_color )); then
        exec_auto_buf echo -en "\e[0;33m"
      fi

      exec_auto_buf echo ">$eval_git_config_system_cmd"

      if (( ! no_color )); then
        exec_auto_buf echo -en "\e[0m"
      fi

      if (( ! is_buf )); then
        is_record_printed=1
      fi

      local OLD_SHOPT

      # always compare case insensitive in Windows
      if [[ "$os_type" == "WIN" ]]; then
        tkl_set_shopt_nocasematch
      fi

      while IFS=$'\r\n=' read cfg_key cfg_value; do
        # print duplicated known config keys unconditionally
        if [[ "$last_known_cfg_key" == "$cfg_key" ]]; then
          #echo "=$cfg_key=$cfg_value|$value|"
          buf="$buf$last_filtered_cfg$cfg_key=$cfg_value"$'\n'
          last_filtered_cfg=''
          continue
        fi

        last_known_cfg_key=''
        last_known_applied_key=''
        last_filtered_cfg=''

        for (( i=0; i < ${#known_config_default_keys[@]}; i++ )); do
          key_os_type="${known_config_default_keys_os_type[i]}"
          key="${known_config_default_keys[i]}"
          value="${known_config_default_values[i]}"

          if [[ "$last_known_applied_key" == "$key" ]]; then
            break
          fi

          if [[ "$cfg_key" == "$key" ]]; then
            last_known_cfg_key="$cfg_key"

            if [[ "$key_os_type" == "SKIP" ]]; then
              break
            fi

            if [[ -z "$key_os_type" || "$key_os_type" == "$os_type" ]]; then
              last_known_applied_key="$key"

              if [[ -n "$value" ]]; then
                if [[ -z "$cfg_value" ]]; then
                  #echo "=$cfg_key="
                  buf="$buf$cfg_key=$cfg_value"$'\n'
                else
                  # restore case sensitivity to compare key values
                  if [[ "$os_type" == "WIN" ]]; then
                    tkl_restore_shopt
                    set_shopt_nocasematch=1
                  else
                    set_shopt_nocasematch=0
                  fi

                  if [[ "$cfg_value" != "$value" ]]; then
                    #echo "=$cfg_key=$cfg_value|$value|"
                    buf="$buf$cfg_key=$cfg_value"$'\n'
                  else
                    last_filtered_cfg="$cfg_key=$cfg_value"$'\n' # would be printed if known cfg key is duplicated
                  fi

                  if (( set_shopt_nocasematch )); then
                    local OLD_SHOPT
                    tkl_set_shopt_nocasematch
                  fi
                fi
              else
                #echo "=$cfg_key=$cfg_value|$value|"
                buf="$buf$cfg_key=$cfg_value"$'\n'
              fi

              break
            fi
          fi
        done

        if [[ -z "$last_known_cfg_key" ]]; then
          is_known_key=1 # skip keys with unknown prefixes

          for known_key_prefix in "${known_config_default_key_prefixes[@]}"; do
            if [[ "$cfg_key" =~ ^${known_key_prefix//./\\.}[a-zA-Z0-9]+ ]]; then
              is_known_key=0
              break
            fi
          done

          # print not known keys as: `? key=value`
          if (( ! is_known_key )); then
            #echo "=? $cfg_key=$cfg_value"
            if (( ! no_color )); then
              buf="$buf\e[0;31m?\e[0m $cfg_key=$cfg_value"$'\n'
            else
              buf="$buf? $cfg_key=$cfg_value"$'\n'
            fi
          fi
        fi
      done <<< "$(eval $eval_git_config_system_cmd)"

      tkl_restore_shopt

      # if not empty
      if [[ -n "$buf" ]]; then
        if (( ! no_color )); then
          exec_auto_buf echo -en "$buf"
        else
          exec_auto_buf echo -n "$buf"
        fi
        accum_buf_status
      fi

      if (( is_buf )); then
        if (( has_accum_buf )); then
          #echo ===
          echo "$(<"$accum_buf_file")"
          has_accum_buf=0
          is_record_printed=1
        fi

        : > "$accum_buf_file" # trim the buffer
      fi
    }

    local git_config_type

    # print not default configuration

    for git_config_type in system global; do
      print_not_default_git_config_key_value_impl
    done
  }

  local OLD_SHOPT
  tkl_set_shopt_nocasematch

  local os_type

  # detect `os_type` as: UNIX|WIN|MAC
  case "$(uname -s)" in
    Linux*)   os_type=UNIX ;;
    Darwin*)  os_type=MAC ;;
    MINGW*)   os_type=WIN ;;
    MSYS*)    os_type=WIN ;;
    Cygwin*)  os_type=WIN ;;
    *)        os_type=UNIX ;; # unknown treated as UNIX
  esac

  tkl_restore_shopt

  if (( ! no_print_config )); then
    local known_config_default_key_prefixes
    local known_config_default_keys_os_type known_config_default_keys known_config_default_values
    local sortcmd
    git_config_globals_init_and_check_impl
  fi

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
    git_status_impl
  done

  if (( is_record_printed )); then
    echo -e "\n---\n"
  fi

  return 0
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_status "$@"
fi
