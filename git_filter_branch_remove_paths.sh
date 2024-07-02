#!/bin/bash

# Usage:
#   git_filter_branch_remove_paths.sh [<flags>] [//] <path0> [... <pathN>] // [<cmdline>]

# Description:
#   Script to remove paths from all commits in a repository using
#   `git filter-branch` command.

#   <flags>:
#     --i0
#       Use `git update-index --index-info` to update entire index file.
#       By default.
#     --i1
#       Use `git update-index --remove` instead.
#     --i2
#       Use `git rm --cached` instead.
#     -f
#       Use `git rm -f` or `git update-index --force-remove` respectively
#       instead. Is not applicable for the `--i0`.
#     -r
#       Use `git rm -r` respectively instead. Is not applicable for the `--i0`
#       and `--i1`.
#     -S
#     --remove-submodules
#       Deinit and remove submodules using `.gitmodules` file using skip
#       filter from `--skip-submodule-*` option.
#       If all paths is removed, then remove the `.gitmodules` file too.
#       Has effect if `.gitmodules` is in path list.
#     -P
#     --skip-submodule-path-prefix
#       Skip submodule remove for path with prefix (no globbing).
#       Has no effect if `--remove-submodules` flag is not used.
#       Has no effect if `.gitmodules` is in path list.
#
#   //:
#     Separator to stop parse flags.
#
#   <path0> [... <pathN>]:
#     Source tree relative file paths to a file/directory to remove.
#
#   //:
#     Separator to stop parse path list.
#     NOTE:
#       The last separator `//` is required to distinguish path list from
#       `<cmdline>`.
#
#   <cmdline>:
#     The rest of command line passed to `git filter-branch` command.
#     NOTE:
#       You must explcitly pass `--prune-empty` flag if don't want the empty
#       commits to be left.

# NOTE:
#   All `--i*` flags does operate on the Git commit in the index
#   (`--index-filter`) instead of on a checkouted commit (`--tree-filter`).

# Examples:
#   >
#   cd myrepo/path
#   git_filter_branch_remove_paths.sh dir1/ file1 file2/ dir-or-file // -- dev ^t1 ^master
#
#   NOTE:
#     * `dir1`            - (dir) removed
#     * `dir1/dir2`       - (dir) removed
#     * `dir1/dir2/file1` - (file) removed
#     * `dir2/dir1`       - (dir) NOT removed
#     * `file1`           - (file) removed
#     * `dir2/file1`      - (file) NOT removed
#     * `file2`           - (file) NOT removed
#     * `dir-or-file`     - (file/dir) removed

# Examples:
#   # To update all commits in all heads to update first commit(s) in all
#   # ancestor branches.
#   >
#   cd myrepo/path
#   git_filter_branch_remove_paths.sh ... // -- --all
#
#   # To update all commits by tag `t1` to update first commit(s) in all
#   # ancestor branches.
#   >
#   cd myrepo/path
#   git_filter_branch_remove_paths.sh ... // -- t1
#
#   # To update single commit by a tag.
#   >
#   cd myrepo/path
#   git_filter_branch_remove_paths.sh ... // -- t1 --not t1^@
#
#   >
#   cd myrepo/path
#   git_filter_branch_remove_paths.sh ... // -- t1^!

# CAUTION:
#   In a generic case the `rev-list` parameter of the `git filter-branch`
#   command must be a set of commit ranges to rewrite a single commit or a set
#   of commits. This is required because a commit in the commits tree can has
#   multiple parent commits and to select a single commit with multiple parents
#   (merge commit) you must issue a range of commits for EACH PARENT to define
#   range in each parent branch.
#
#   In other words a single expression `<obj>~1..<ref>` does not guarantee a
#   selection of a single commit if `<ref>` points a commit with multiple
#   parents or has it on a way over other commits to the `<obj>`.
#   The same for the `<ref> --not <obj>^@` or `<obj>^@..<ref>` expression if
#   the path between `<ref>` and `<obj>` contains more than 1 commit. In that
#   particular case to select a single commit you must use multiple ranges.
#
#   If `<ref>` and `<obj>` points the same commit (range for a single), then
#   the `<ref> --not <obj>^@` or `<obj>^@..<ref>` or `<ref>^!` is enough to
#   always select a single commit in any tree.

# CAUTION:
#   If a file already exist in a being updated commit or in a commit
#   child/children and has changes, then the script does remove an existing
#   file including children commits changes. This means that the changes in
#   all child branches would be lost.
#
#   But if you want to remove a file in all commits before a commit, then you
#   have to limit the `rev-list` parameter by that commit.

# NOTE:
#   You must use `git_cleanup_filter_branch.sh` script to cleanup the
#   repository from intermediate references.

# Script both for execution and inclusion.
[[ -n "$BASH" ]] || return 0 || exit 0 # exit to avoid continue if the return can not be called

function call()
{
  local IFS=$' \t'
  echo ">$*"
  "$@"
}

function git_filter_branch_remove_paths()
{
  local flag="$1"

  local option_i=0
  local flag_f=0
  local flag_r=0
  export flag_remove_submodules=0
  local option_skip_submodule_path_prefix_arr=()
  local skip_flag

  while [[ "${flag:0:1}" == '-' ]]; do
    flag="${flag:1}"
    skip_flag=0

    # long flags
    if [[ "$flag" == '-i0' ]]; then
      skip_flag=1
    elif [[ "$flag" == '-i1' ]]; then
      option_i=1
      skip_flag=1
    elif [[ "$flag" == '-i2' ]]; then
      option_i=2
      skip_flag=1
    elif [[ "$flag" == '-remove-submodules' ]]; then
      flag_remove_submodules=1
      skip_flag=1
    elif [[ "$flag" == '-skip-submodule-path-prefix' ]]; then
      option_skip_submodule_path_prefix_arr[${#option_skip_submodule_path_prefix_arr[@]}]="$2"
      shift
      skip_flag=1
    elif [[ "${flag:0:1}" == '-' ]]; then
      echo "$0: error: invalid flag: \`$flag\`" >&2
      return 255
    fi

    # short flags
    if (( ! skip_flag )); then
      while [[ -n "$flag" ]]; do
        if [[ "${flag:0:1}" == 'f' ]]; then
          flag_f=1
        elif [[ "${flag:0:1}" == 'r' ]]; then
          flag_r=1
        elif [[ "${flag:0:1}" == 'S' ]]; then
          flag_remove_submodules=1
        elif [[ "${flag:0:1}" == 'P' ]]; then
          option_skip_submodule_path_prefix_arr[${#option_skip_submodule_path_prefix_arr[@]}]="$2"
          shift
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

  export rm_bare_flags=''

  # insert an option before instead of after
  case $option_i in
    0)
      if (( flag_f )); then
        echo "$0: error: flag is not applicable: \`f\`" >&2
        return 255
      fi
      if (( flag_r )); then
        echo "$0: error: flag is not applicable: \`r\`" >&2
        return 255
      fi
      ;;
    1)
      if (( flag_r )); then
        echo "$0: error: flag is not applicable: \`r\`" >&2
        return 255
      fi
      if (( ! flag_f )); then
        rm_bare_flags=" --remove$rm_bare_flags"
      else
        rm_bare_flags=" --force-remove$rm_bare_flags"
      fi
      ;;
    2)
      rm_bare_flags=" --cached$rm_bare_flags"
      if (( flag_f )); then
        rm_bare_flags=" -f$rm_bare_flags"
      fi
      if (( flag_r )); then
        rm_bare_flags=" -r$rm_bare_flags"
      fi
      ;;
  esac

  local arg
  local args=("$@")
  export path_list_cmdline=''
  local num_args=${#args[@]}
  local i
  local old_shopt

  case "$OSTYPE" in
    # case insensitive for Windows ONLY
    cygwin* | msys* | mingw*)
      old_shopt="$(shopt -p nocasematch)" # read state before change

      if [[ "$old_shopt" != 'shopt -s nocasematch' ]]; then
        shopt -s nocasematch
      else
        old_shopt=''
      fi
    ;;
  esac

  local has_cmdline_separator=0

  for (( i=0; i < num_args; i++ )); do
    arg="${args[i]}"

    if [[ "$arg" == '//' ]]; then
      has_cmdline_separator=1
      shift
      break
    fi

    if [[ -n "$arg" ]]; then
      if [[ ".gitmodules" != "$arg" ]]; then
        path_list_cmdline="$path_list_cmdline \"$arg\""
      else
        if (( ! flag_remove_submodules )); then
          path_list_cmdline="$path_list_cmdline \"$arg\""
        fi
      fi
    fi

    shift

    arg="$1"
  done

  if [[ -n "$old_shopt" ]]; then
    eval $old_shopt
  fi

  if (( ! has_cmdline_separator )); then
    echo "$0: error: missed cmdline separator: \`//\`" >&2
    return 255
  fi

  if [[ -z "$path_list_cmdline" ]] && (( ! flag_remove_submodules )); then
    echo "$0: error: path list is empty." >&2
    return 255
  fi

  # NOTE: inner functions must be unique

  case $option_i in
    0)
      function _0FFCA2F7_exec_remove_ls_paths()
      {
        local IFS mode hash stage path

        git ls-files -s "${path_arr[@]}" | {
          while IFS=$' \t' read mode hash stage path; do
            echo "0 0000000000000000000000000000000000000000	$path"
          done | git update-index --index-info
        }
      }
      ;;
    1)
      function _0FFCA2F7_exec_remove_ls_paths()
      {
        eval git update-index$rm_bare_flags \"\${path_arr[@]}\"
      }
      ;;
    2)
      function _0FFCA2F7_exec_remove_ls_paths()
      {
        eval git rm$rm_bare_flags \"\${path_arr[@]}\"
      }
      ;;
  esac

  export option_skip_submodule_paths_cmdline="\"${option_skip_submodule_path_prefix_arr[0]}\""

  for arg in "${option_skip_submodule_path_prefix_arr[@]:1}"; do
    option_skip_submodule_paths_cmdline="$option_skip_submodule_paths_cmdline \"$arg\""
  done

  function _0FFCA2F7_exec()
  {
    # init
    local path_arr
    local option_skip_submodule_path_prefix_arr

    eval path_arr=($path_list_cmdline)
    eval option_skip_submodule_path_prefix_arr=($option_skip_submodule_paths_cmdline)

    # remove requsted paths at first
    if (( ${#path_arr[@]} )); then
      _0FFCA2F7_exec_remove_ls_paths
      path_arr=()
    fi

    if (( ! flag_remove_submodules )); then
      return 0
    fi

    local IFS
    local path

    # checkout `.gitmodules`, filter and remove submodule paths
    IFS=$'\r\n' read path < <(git ls-files ".gitmodules")

    if [[ -z "$path" ]]; then
      return 0
    fi

    git checkout-index -- '.gitmodules' || return $?

    local is_external_path_filtered
    local external_path

    local num_submodule_remove_paths=0
    local num_submodule_paths=0

    local LR EOL line key value

    local filtered_lines filtered_section_lines
    local do_collect_prev_section

    # WORKAROUND:
    #   The EOL special workaround using `printf` is for the Bash issue behind
    #   the Msys and Git environment under Windows.
    #
    #   >uname -a
    #   MSYS_NT-6.3-9600 ... 3.4.9-be826601.x86_64 2023-09-07 12:36 UTC x86_64 Msys
    #
    #   >bash --version
    #   GNU bash, version 5.2.21(1)-release (x86_64-pc-msys)
    #
    #   >git --version
    #   git version 2.43.0.windows.1

    # read first line return character in case of Windows text format
    IFS='' read -r LR < ".gitmodules"
    printf -v EOL "%02X" "\"${LR: -1}"
    if [[ "$EOL" == '0D' ]]; then
      printf -v LR "%s\r" "${LR//[^$'\r\n']/}"
    else
      LR="${LR//[^$'\r\n']/}"
    fi

    do_collect_prev_section=1

    while IFS=$'\r\n' read -r line; do # IFS - with trim trailing line feeds
      printf -v EOL "%02X" "\"${line: -1}"
      if [[ "$EOL" == '0D' ]]; then
        line="${line:0:-1}"
      fi
      line="${line//[$'\r\n']/}"

      # collect already filtered lines
      if [[ "$line" =~ \s*\[.+\]\s* ]]; then
        if (( do_collect_prev_section )); then
          filtered_lines="$filtered_lines$filtered_section_lines"
        fi
        filtered_section_lines=''
        do_collect_prev_section=1
      fi

      filtered_section_lines="$filtered_section_lines$line$LR"$'\n'

      while [[ "${line: -1}" =~ [[:space:]] ]]; do line="${line:0:-1}"; done # trim trailing white spaces
      while [[ "${line:0:1}" =~ [[:space:]] ]]; do line="${line:1}"; done # trim leading white spaces

      IFS='=' read -r key value <<< "$line"

      while [[ "${key: -1}" =~ [[:space:]] ]]; do key="${key:0:-1}"; done # trim trailing white spaces
      while [[ "${value:0:1}" =~ [[:space:]] ]]; do value="${value:1}"; done # trim leading white spaces

      if [[ "$key" != 'path' ]]; then
        continue
      fi

      (( num_submodule_paths++ ))

      external_path="$value/"
      is_external_path_filtered=0

      for path in "${option_skip_submodule_path_prefix_arr[@]}"; do
        while [[ "${path: -1}" == '/' ]]; do path="${path:0:-1}"; done # trim trailing slashes
        if [[ "${external_path#$path/}" != "$external_path" ]]; then
          is_external_path_filtered=1
          break
        fi
      done

      if (( is_external_path_filtered )); then
        continue
      fi

      # reset the last collected section
      do_collect_prev_section=0

      path_arr=("${path_arr[@]}" "$value")

      (( num_submodule_remove_paths++ ))
    done < ".gitmodules"

    if (( do_collect_prev_section )); then
      filtered_lines="$filtered_lines$filtered_section_lines"
    fi

    # update `.gitmodules` and it's index, remove `.gitmodules` after all module paths
    if (( num_submodule_remove_paths == num_submodule_paths )); then
      path_arr=("${path_arr[@]}" '.gitmodules')
    else
      # trim last line return
      echo -n "${filtered_lines%$LR$'\n'}" > '.gitmodules'
      git update-index -- '.gitmodules'
    fi

    # cleanup working tree
    rm '.gitmodules'

    if (( ${#path_arr[@]} )); then
      _0FFCA2F7_exec_remove_ls_paths
      path_arr=()
    fi
  }

  # serialize all functions into exported variable
  export _0FFCA2F7_eval=''

  for func in _0FFCA2F7_exec _0FFCA2F7_exec_remove_ls_paths; do
    _0FFCA2F7_eval="$_0FFCA2F7_eval${_0FFCA2F7_eval:+$'\n\n'}function $(declare -f $func)"
  done

  call git filter-branch --index-filter 'eval "$_0FFCA2F7_eval"; _0FFCA2F7_exec' "$@"
}

# shortcut
function git_flb_rm_ps()
{
  git_filter_branch_remove_paths "$@"
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_filter_branch_remove_paths "$@"
fi
