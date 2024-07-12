#!/bin/bash

# Usage:
#   git_filter_branch_remove_paths.sh [<flags>]  // [<path0> [... <pathN>]] // [<cmdline>]
#   git_filter_branch_remove_paths.sh [<flags>] [//] <path0> [... <pathN>]  // [<cmdline>]

# Description:
#   Script to remove paths from commits in a repository using
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
#     -m
#     --remove-submodules
#       Remove submodule paths using `.gitmodules` file and the skip
#       filter from `--skip-submodule-*` option.
#       If all paths is removed, then remove the `.gitmodules` file too.
#       Has effect if `.gitmodules` is in path list, but the file does remove
#       only when all module paths is removed.
#       CAUTION:
#         The command line path list does remove unconditionally and so does
#         not affect the paths in the `.gitmodules` leaving them unchanged.
#         You must use this flag to reflect the changes into the file.
#     -P
#     --skip-submodule-path-prefix
#       Skip submodule remove for path with prefix (no globbing).
#       Has no effect if `--remove-submodules` flag is not used.
#       Has no effect if `.gitmodules` is in path list.
#     -i
#     --sync-gitignore-submodule-paths
#       Synchronize `.gitignore` for paths removed from `.gitmodules`.
#       Has no effect if `.gitignore` is in path list.
#       CAUTION:
#         Is supported a very limited lines format in the `.gitignore` file:
#           * Blank and comment lines does not restore to the previous.
#           * Leading and trailing white spaces in a line does trim before
#             check in the index.
#           * Paths with globbing, backslashes, ranges and exclusion pattern
#             does pass into `git ls-files` as is to detect indexed paths.
#         See details: https://git-scm.com/docs/gitignore#_pattern_format
#       CAUTION:
#         The command line path list does remove unconditionally and so does
#         not affect the paths in the `.gitignore` leaving them unchanged.
#         You must use this flag to reflect the changes into the file.
#     -p
#     --prune-empty
#       Generate replace references to prune the empty commits after they
#       become empty because of the `git filter-branch ...` command apply.
#       NOTE:
#         This has different behaviour versus the
#         `git filter-branch --prune-empty ...` as the latter prunes all the
#         empty commits including those which were empty before the rewrite.
#       CAUTION:
#         Does not generate replace references for the empty commits under the
#         most top reference(s) from the filtered range expression, so won't be
#         removed those last commits which is pointed by these.
#         This is by design because the prunning algorithm is based on
#         `git replace --graft` command and it requires to access a commit
#         above the commits filtered range to prune (bypass) the empty commit
#         in the filtered range.
#         To still remove such commits, you must execute the
#         `git filter-branch --prune-empty` command with at least the same
#         (or may be with the modificated one to select the rewrited range)
#         commits filter range expression manually after the script.
#     -z
#     --finalize
#       Finalizes changes and applies replace references just after the replace
#       references generation.
#       Executes `git filter-branch` command to apply replace references in
#       case of `--prune-empty` flag.
#       Has no effect if `--prune-empty` is not used.
#       Has no effect if nothing to finalize.
#
#   //:
#     Separator to stop parse flags.
#     NOTE:
#       Is required if the command line path list is empty.
#
#   <path0> [... <pathN>]:
#     Source tree relative file paths to a file/directory to remove.
#     CAUTION:
#       If a path is a module directory path, then the module record won't
#       be removed from the `.gitmodules` file.
#
#   //:
#     Separator to stop parse path list.
#     NOTE:
#       The last separator `//` is required to distinguish path list from
#       `<cmdline>`.
#
#   <cmdline>:
#     The rest of command line passed to `git filter-branch` command.

# CAUTION:
#   The `--prune-empty` flag will remove ALL the empty commits, including
#   those which were before the rewrite instead of those which become empty
#   because of the `git filter-branch ...` apply.

# NOTE:
#   All `--i*` flags does operate on the Git commit in the index
#   (`--index-filter`) instead of on a checkouted commit (`--tree-filter`).

# NOTE:
#   Create `ENABLE_GIT_FILTER_REWRITE_DEBUG=1` environment variable to
#   breakpoint per each `_0FFCA2F7_exec` function execution.
#   To resume change directory into the repository root and create
#   `.git-filter-cache/!` subdirectory.
#

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
#
#   # To update all commits by branch `master` to update first commit(s) in all
#   # ancestor branches to remove `.gitmodules`, all modules paths,
#   # reflects changes into the `.gitignore`, generates replace references to
#   # prune the empty commits after the filter apply (not all empty commits,
#   # see details for the `-p` flag) and finalizes the result by applying the
#   # replace references.
#   >
#   cd myrepo/path
#   git_filter_branch_remove_paths.sh -mipz // // -- master

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
#   If a file already exists in a being updated commit or in a commit
#   child/children and has changes, then the script does remove an existing
#   file including children commits changes. This means that the changes in
#   all child branches would be lost.
#
#   But if you want to remove a file in all commits before a commit, then you
#   have to limit the `rev-list` parameter by that commit.

# NOTE:
#   You must use `git_cleanup_filter_branch.sh` script to cleanup the
#   repository from intermediate references.
#
#   If `--prune-empty` flag is used together with `--finalize` flag, then to
#   remove the replace references use `git_cleanup_replace_refs.sh` script.

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
  export flag_sync_gitignore_submodule_paths=0
  export flag_prune_empty=0
  export flag_finalize=0
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
    elif [[ "$flag" == '-sync-gitignore-submodule-paths' ]]; then
      flag_sync_gitignore_submodule_paths=1
      skip_flag=1
    elif [[ "$flag" == '-prune-empty' ]]; then
      flag_prune_empty=1
      skip_flag=1
    elif [[ "$flag" == '-finalize' ]]; then
      flag_finalize=1
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
        elif [[ "${flag:0:1}" == 'm' ]]; then
          flag_remove_submodules=1
        elif [[ "${flag:0:1}" == 'P' ]]; then
          option_skip_submodule_path_prefix_arr[${#option_skip_submodule_path_prefix_arr[@]}]="$2"
          shift
        elif [[ "${flag:0:1}" == 'i' ]]; then
          flag_sync_gitignore_submodule_paths=1
        elif [[ "${flag:0:1}" == 'p' ]]; then
          flag_prune_empty=1
        elif [[ "${flag:0:1}" == 'z' ]]; then
          flag_finalize=1
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

  if [[ ! -d '.git' ]]; then
    echo "$0: error: script must be run in a Working Copy root directory." >&2
    return 1
  fi

  if [[ -d '.git-filter-cache' ]]; then
    echo "$0: error: remove \`.git-filter-cache\` directory before continue." >&2
    return 2
  fi

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

  local arg arg_index
  local args=("$@")
  export path_list_cmdline=''
  local num_args=${#args[@]}
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

  export has_gitignore_in_path_list=0

  local has_cmdline_separator=0

  for (( arg_index=0; arg_index < num_args; arg_index++ )); do
    arg="${args[arg_index]}"

    if [[ "$arg" == '//' ]]; then
      has_cmdline_separator=1
      shift
      break
    fi

    if [[ -n "$arg" ]]; then
      if [[ ".gitmodules" != "$arg" ]]; then
        path_list_cmdline="$path_list_cmdline \"$arg\""
        if [[ ".gitignore" == "$arg" ]]; then
          has_gitignore_in_path_list=1
        fi
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

        git ls-files -sc "${path_arr[@]}" | {
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

  function _0FFCA2F7_cleanup()
  {
    rm -rf '.git-filter-cache'
  }

  trap "_0FFCA2F7_cleanup; trap - RETURN" RETURN
  trap "_0FFCA2F7_cleanup" SIGINT

  mkdir '.git-filter-cache'

  if (( flag_prune_empty )); then
    export empty_parent_commit_list_file='.git-filter-cache/empty_parent_commits' # format: <not-yet-rewritten-commit> <empty-rewritten-single-parent>
    echo -n > ".git-filter-cache/empty_parent_commits"
  fi

  function _0FFCA2F7_debugbreak()
  {
    while [[ ! -d '../../.git-filter-cache/!' ]]; do
      sleep 1;
    done

    # NOTE:
    #   The loop is required to avoid error: `rmdir: failed to remove '../../.git-filter-cache/!': Device or resource busy`
    #
    while [[ -d '../../.git-filter-cache/!' ]]; do
      rmdir '../../.git-filter-cache/!'
      sleep 1
    done
  }

  function _0FFCA2F7_exec_ENTER()
  {
    if (( ENABLE_GIT_FILTER_REWRITE_DEBUG )); then
      echo $'\n'"$PWD"
      _0FFCA2F7_debugbreak
    fi
  }

  function _0FFCA2F7_exec_RETURN()
  {
    # on last handler return
    if (( ${#_0FFCA2F7_exec_revs_arr[@]} == _0FFCA2F7_exec_index + 1 )); then
      # CAUTION:
      #   Can not be moved because `git filter-branch` command does use the file after the last handler call
      #
      cp -R '../../.git-rewrite/map' '../../.git-filter-cache'

      if (( ENABLE_GIT_FILTER_REWRITE_DEBUG )); then
        _0FFCA2F7_debugbreak
      fi
    fi
  }

  function _0FFCA2F7_exec()
  {
    if [[ ! -d '../../.git' || ! -d '../../.git-filter-cache' ]]; then
      echo $'\n'"$0: error: wrong current directory assumption." >&2
      return 255
    fi

    # copy revs file
    if [[ ! -f '../../.git-filter-cache/revs' ]]; then
      cp '../../.git-rewrite/revs' '../../.git-filter-cache'
    fi

    # must be global between calls
    if [[ -n "${_0FFCA2F7_exec_index+x}" ]]; then
      (( _0FFCA2F7_exec_index++ ))
    else
      _0FFCA2F7_exec_index=0
      _0FFCA2F7_exec_revs_arr=()
      local revs
      while IFS=$'\r\n' read -r revs; do # IFS - with trim trailing line feeds
        _0FFCA2F7_exec_revs_arr[${#_0FFCA2F7_exec_revs_arr[@]}]="$revs"
      done < '../../.git-filter-cache/revs'
    fi

    trap "_0FFCA2F7_exec_RETURN; trap - RETURN" RETURN

    _0FFCA2F7_exec_ENTER

    # init
    local path_arr
    eval path_arr=($path_list_cmdline)

    if (( ! flag_remove_submodules )); then
      if (( ${#path_arr[@]} )); then
        _0FFCA2F7_exec_remove_ls_paths
        path_arr=()
      fi

      return 0
    fi

    local IFS
    local path

    # checkout `.gitmodules`, filter and remove submodule paths
    IFS=$'\r\n' read path < <(git ls-files -c ".gitmodules") # IFS - with trim trailing line feeds

    if [[ -z "$path" ]]; then
      return 0
    fi

    git checkout-index -- '.gitmodules' || return $?

    local option_skip_submodule_path_prefix_arr
    eval option_skip_submodule_path_prefix_arr=($option_skip_submodule_paths_cmdline)

    local is_external_path_filtered
    local external_path

    local num_submodule_remove_paths=0
    local num_submodule_paths=0

    local LR EOL line key value

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

    local filtered_lines filtered_section_lines
    local do_collect_prev_section=1

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

    # update `.gitmodules` and the index, otherwise remove `.gitmodules` if all module paths is removed
    if (( num_submodule_remove_paths == num_submodule_paths )); then
      path_arr=("${path_arr[@]}" '.gitmodules')
    else
      # trim last line return
      echo -n "${filtered_lines%$LR$'\n'}" > '.gitmodules'
      git update-index -- '.gitmodules'
    fi

    # cleanup working tree
    rm '.gitmodules'

    # Update the index before `.gitignore` synchronization, but after `.gitmodules` read, because:
    #   1. `.gitignore` synchronization does rely on already removed paths from the index.
    #   2. The command line path list can contain a path to a module directory and we do not check the command line paths on duplication.
    #      Instead we remove all collected paths altogether to avoid the index update twice, because `git ls-files` accepts duplicated paths.
    #
    if (( ${#path_arr[@]} )); then
      _0FFCA2F7_exec_remove_ls_paths
      path_arr=()
    fi

    # NOTE:
    #   We will collect empty commits at the end, after the `.gitignore` update
    #
    local graft
    eval graft=(${_0FFCA2F7_exec_revs_arr[_0FFCA2F7_exec_index]})

    # NOTE:
    #   1. `.gitignore` can be synchronized ONLY when exists at least one parent commit.
    #   2. Empty commits can be counted as changed to empty ONLY when they are visited as parent commit to a being indexed commit
    #      and when the mapped commit (rewrited or cloned with applied changes) for this parent commit exists, otherwise there is nothing to graft with to prune (bypass) them
    #      (`git replace --graft <commit> <parents>...` requires `<parents>` to be already mapped).

    # update parents and collect emptied parent commits if `--prune-empty` is used
    local graft_index parent
    local num_grafts=${#graft[@]}
    local commit="${graft[0]}"

    for (( graft_index=num_grafts; --graft_index > 0; )); do
      parent="${graft[graft_index]}"

      # read mapped parent commit hash (rewrited or cloned with applied changes)
      if [[ -f "../../.git-rewrite/map/$parent" ]]; then
        IFS=$'\r\n' read -r parent < "../../.git-rewrite/map/$parent" # IFS - with trim trailing line feeds

        # We must collect only those empty commits which has been rewriten because of the filter apply.
        #
        # NOTE:
        #   The empty commits above the filtered range won't be collected here.
        #
        if (( flag_prune_empty )); then
          if git diff --quiet "$parent^!"; then
            echo "$commit $parent" >> "../../$empty_parent_commit_list_file"
          fi
        fi

        # update graft array
        graft[graft_index]="$parent"
      fi
    done

    # synchronize `.gitignore` for paths removed from `.gitmodules`
    if (( flag_sync_gitignore_submodule_paths && ! has_gitignore_in_path_list && ${#graft[@]} > 1 )); then
      local commit_path

      IFS=$'\r\n' read commit_path < <(git ls-files -c ".gitignore") # IFS - with trim trailing line feeds

      if [[ -n "$commit_path" ]] && git checkout-index -- '.gitignore'; then
        commit="${graft[0]}"

        # read first line return character in case of Windows text format
        IFS='' read -r LR < ".gitignore"
        printf -v EOL "%02X" "\"${LR: -1}"
        if [[ "$EOL" == '0D' ]]; then
          printf -v LR "%s\r" "${LR//[^$'\r\n']/}"
        else
          LR="${LR//[^$'\r\n']/}"
        fi

        # create temporary directory to rebuild and collect `.gitignore` from all parents
        local commit_tmp_dir="../../.git-filter-cache/commits/$commit"
        local has_parent_gitignore=0

        mkdir -p "$commit_tmp_dir"

        # NOTE:
        #   We have to collect the `.gitignore` differences in reverse parent order because
        #   the removed lines does insert immediately after the upper bound line.
        #
        for (( graft_index=num_grafts; --graft_index > 0; )); do
          parent="${graft[graft_index]}"

          if ! git show "$parent:.gitignore" 2>/dev/null > "$commit_tmp_dir/.gitignore"; then
            continue
          fi

          if (( ! has_parent_gitignore )); then
            # begin accumulation on first existed in a parent commit
            cp -T '.gitignore' "$commit_tmp_dir/.gitignore.accum"
            has_parent_gitignore=1
          fi

          # Finds paths in the `.gitignore` of a parent commit which is not in the indexed `.gitignore` and
          # not in the accumulated `.gitignore` initially copied from the index, then adds them to the accumulated `.gitignore`
          # per each parent commit by the upper bound line taken from the indexed `.gitignore` file if the path is not indexed.

          local line_index prev_line
          local parent_line raw_parent_line
          local removed_trimmed_line_arr=()           # array of removed trimmed lines (existed only in the parent)
          local removed_line_arr=()                   # array of removed not trimmed lines (existed only in the parent)
          local to_insert_after_existed_line_arr=()   # upper bound (last) existed (in both files) lines per each removed line (to insert after)
          local to_insert_after_existed_line
          local is_line_found
          local num_lines

          # collect lines from a parent commit `.gitignore` been removed in the indexed `.gitignore`
          while IFS=$'\r\n' read -r parent_line; do # IFS - with trim trailing line feeds
            printf -v EOL "%02X" "\"${parent_line: -1}"
            if [[ "$EOL" == '0D' ]]; then
              parent_line="${parent_line:0:-1}"
            fi
            parent_line="${parent_line//[$'\r\n']/}"

            # not trimmed line
            raw_parent_line="$parent_line"

            while [[ "${parent_line: -1}" =~ [[:space:]] ]]; do parent_line="${parent_line:0:-1}"; done # trim trailing white spaces
            while [[ "${parent_line:0:1}" =~ [[:space:]] ]]; do parent_line="${parent_line:1}"; done # trim leading white spaces

            # skip blank and comment lines in the parent `.gitignore`
            if [[ -z "$parent_line" || "${parent_line:0:1}" == '#' ]]; then
              continue
            fi

            is_line_found=0

            while IFS=$'\r\n' read -r line; do # IFS - with trim trailing line feeds
              printf -v EOL "%02X" "\"${line: -1}"
              if [[ "$EOL" == '0D' ]]; then
                line="${line:0:-1}"
              fi
              line="${line//[$'\r\n']/}"

              while [[ "${line: -1}" =~ [[:space:]] ]]; do line="${line:0:-1}"; done # trim trailing white spaces
              while [[ "${line:0:1}" =~ [[:space:]] ]]; do line="${line:1}"; done # trim leading white spaces

              if [[ "$line" == "$parent_line" ]]; then
                is_line_found=1
                break
              fi
            done < '.gitignore'

            if (( ! is_line_found )); then
              removed_trimmed_line_arr=("${removed_trimmed_line_arr[@]}" "$parent_line") # trimmed line
              removed_line_arr=("${removed_line_arr[@]}" "$raw_parent_line") # not trimmed line
              to_insert_after_existed_line_arr=("${to_insert_after_existed_line_arr[@]}" "$to_insert_after_existed_line") # trimmed line
            else
              to_insert_after_existed_line="$line" # trimmed line
            fi
          done < "$commit_tmp_dir/.gitignore"

          # remove lines already existed in the accumulated `.gitignore` in case of a merge commit
          if (( ${#graft[@]} > 2 )); then
            num_lines=${#removed_line_arr[@]}

            for (( line_index=0; line_index < num_lines; )); do
              is_line_found=0

              parent_line="${removed_trimmed_line_arr[line_index]}"  # trimmed line

              while IFS=$'\r\n' read -r line; do # IFS - with trim trailing line feeds
                printf -v EOL "%02X" "\"${line: -1}"
                if [[ "$EOL" == '0D' ]]; then
                  line="${line:0:-1}"
                fi
                line="${line//[$'\r\n']/}"

                while [[ "${line: -1}" =~ [[:space:]] ]]; do line="${line:0:-1}"; done # trim trailing white spaces
                while [[ "${line:0:1}" =~ [[:space:]] ]]; do line="${line:1}"; done # trim leading white spaces

                # skip blank and comment lines in the accumulated `.gitignore`
                if [[ -z "$line" || "${line:0:1}" == '#' ]]; then
                  continue
                fi

                if [[ "$parent_line" == "$line" ]]; then
                  is_line_found=1

                  # remove from list
                  if (( line_index )); then
                    removed_trimmed_line_arr=("${removed_trimmed_line_arr[@]:0:line_index-1}" "${removed_trimmed_line_arr[@]:line_index+1}")
                    removed_line_arr=("${removed_line_arr[@]:0:line_index-1}" "${removed_line_arr[@]:line_index+1}")
                    to_insert_after_existed_line_arr=("${to_insert_after_existed_line_arr[@]:0:line_index-1}" "${to_insert_after_existed_line_arr[@]:line_index+1}")
                  else
                    removed_trimmed_line_arr=("${removed_trimmed_line_arr[@]:line_index+1}")
                    removed_line_arr=("${removed_line_arr[@]:line_index+1}")
                    to_insert_after_existed_line_arr=("${to_insert_after_existed_line_arr[@]:line_index+1}")
                  fi

                  break
                fi
              done < "$commit_tmp_dir/.gitignore.accum"

              if (( ! is_line_found )); then
                (( line_index++ ))
              fi
            done
          fi

          # Generate new `.gitignore.new` using indexed `.gitignore` and the lines been removed from the parent `.gitignore`.
          #
          # NOTE:
          #   We have to use the indexed `.gitignore` as a base, because the lines in the indexed `.gitignore` can be moved or edited
          #   without addition or removement.
          #
          echo -n > "$commit_tmp_dir/.gitignore.new"

          # insert lines been removed from the parent `.gitignore` and without upper bound lines
          num_lines=${#removed_line_arr[@]}

          for (( line_index=0; line_index < num_lines; line_index++ )); do
            if [[ -n "${to_insert_after_existed_line_arr[line_index]}" ]]; then
              break
            fi

            parent_line="${removed_line_arr[line_index]}"
            path="$parent_line"

            # convert absolute path to relative
            if [[ "${path:0:1}" == '/' ]]; then
              path=".$path"
            fi

            # insert if not in the index
            IFS=$'\r\n' read path < <(git ls-files -c "$path") # IFS - with trim trailing line feeds
            if [[ -z "$path" ]]; then
              echo "$parent_line$LR"
            fi
          done >> "$commit_tmp_dir/.gitignore.new"

          # update arrays
          if (( line_index )); then
            removed_line_arr=("${removed_line_arr[@]:line_index}")
            to_insert_after_existed_line_arr=("${to_insert_after_existed_line_arr[@]:line_index}")
          fi

          # insert accumulated `.gitignore` lines and lines been removed from the parent `.gitignore` using upper bound lines to insert from
          num_lines=${#removed_line_arr[@]} # no array resize after this point

          local is_inserting=0

          while IFS=$'\r\n' read -r line; do # IFS - with trim trailing line feeds
            printf -v EOL "%02X" "\"${line: -1}"
            if [[ "$EOL" == '0D' ]]; then
              line="${line:0:-1}"
            fi
            line="${line//[$'\r\n']/}"

            while [[ "${line: -1}" =~ [[:space:]] ]]; do line="${line:0:-1}"; done # trim trailing white spaces
            while [[ "${line:0:1}" =~ [[:space:]] ]]; do line="${line:1}"; done # trim leading white spaces

            if [[ -n "$prev_line" && "$prev_line" != "$line" ]]; then
              # insert line with upper bound line equal to the previous trimmed line
              for (( line_index=0; line_index < num_lines; line_index++ )); do
                if [[ "${to_insert_after_existed_line_arr[line_index]}" != "$prev_line" ]]; then
                  if (( is_inserting )); then
                    break
                  fi
                  continue
                fi

                is_inserting=1

                parent_line="${removed_line_arr[line_index]}"
                path="$parent_line"

                # convert absolute path to relative
                if [[ "${path:0:1}" == '/' ]]; then
                  path=".$path"
                fi

                # insert if not in the index
                IFS=$'\r\n' read path < <(git ls-files -c "$path") # IFS - with trim trailing line feeds
                if [[ -z "$path" ]]; then
                  echo "$parent_line$LR"
                fi

                # update arrays without resize
                to_insert_after_existed_line_arr[line_index]=''
              done >> "$commit_tmp_dir/.gitignore.new"
            fi

            # unconditional insert
            echo "$line$LR" >> "$commit_tmp_dir/.gitignore.new"

            prev_line="$line"
          done < "$commit_tmp_dir/.gitignore.accum"

          # update accumulated changes
          cp -fT "$commit_tmp_dir/.gitignore.new" "$commit_tmp_dir/.gitignore.accum"
        done

        if (( has_parent_gitignore )); then
          mv -fT "$commit_tmp_dir/.gitignore.accum" '.gitignore'
          git update-index -- '.gitignore'
          rm "$commit_tmp_dir/.gitignore.new"
        else
          # remove `.gitignore` from the index
          path_arr=('.gitignore')
          _0FFCA2F7_exec_remove_ls_paths
          path_arr=()
        fi

        rm -f "$commit_tmp_dir/.gitignore"
        rmdir "$commit_tmp_dir"
        rm '.gitignore'
      fi
    fi
  }

  # serialize all functions into exported variable
  export _0FFCA2F7_eval=''

  for func in _0FFCA2F7_exec _0FFCA2F7_exec_ENTER _0FFCA2F7_debugbreak _0FFCA2F7_exec_RETURN _0FFCA2F7_exec_remove_ls_paths; do
    _0FFCA2F7_eval="$_0FFCA2F7_eval${_0FFCA2F7_eval:+$'\n\n'}function $(declare -f $func)"
  done

  # suppress warning
  export FILTER_BRANCH_SQUELCH_WARNING=1

  call git filter-branch --index-filter 'eval "$_0FFCA2F7_eval"; _0FFCA2F7_exec' "$@"

  # generate replace references to prune empty commits using `git replace --graft`
  if [[ -s "$empty_parent_commit_list_file" ]]; then
    if (( flag_prune_empty )); then
      echo
      echo 'Pruning empty commits...'

      local commit_order_arr=()
      local commit_regraft_parents_dict
      local commit_regraft_parents parent_regraft_parents
      local num_commits num_commit_regraft_parents
      local graft_index commit_parent parent_parent

      declare -A commit_regraft_parents_dict

      while IFS=$' \t\r\n' read -r commit parent; do # IFS - with trim trailing line feeds
        # get mapped commit
        if [[ -f ".git-filter-cache/map/$commit" ]]; then
          IFS=$'\r\n' read -r commit < ".git-filter-cache/map/$commit" # IFS - with trim trailing line feeds
        fi

        if [[ -z "${commit_regraft_parents_dict[$commit]+x}" ]]; then
          graft_index=0
          while IFS=$'\r\n' read commit_parent; do
            if (( graft_index )); then
              commit_regraft_parents_dict[$commit]="${commit_regraft_parents_dict[$commit]} $commit_parent"
            else
              commit_regraft_parents_dict[$commit]="$commit_parent"
            fi
            (( graft_index++ ))
          done < <(git rev-parse "$commit^@")
        fi

        commit_regraft_parents=(${commit_regraft_parents_dict[$commit]})

        if [[ -z "${commit_regraft_parents_dict[$parent]+x}" ]]; then
          graft_index=0
          while IFS=$'\r\n' read parent_parent; do
            if (( graft_index )); then
              commit_regraft_parents_dict[$parent]="${commit_regraft_parents_dict[$parent]} $parent_parent"
            else
              commit_regraft_parents_dict[$parent]="$parent_parent"
            fi
            (( graft_index++ ))
          done < <(git rev-parse "$parent^@")
        fi

        parent_regraft_parents=(${commit_regraft_parents_dict[$parent]})

        num_commit_regraft_parents="${#commit_regraft_parents[@]}"

        # find parent and replace to parents of parent
        for (( graft_index=0; graft_index < num_commit_regraft_parents; graft_index++ )); do
          if [[ "$parent" == "${commit_regraft_parents[graft_index]}" ]]; then
            if (( graft_index )); then
              commit_regraft_parents=("${commit_regraft_parents[@]:0:graft_index-1}" "${parent_regraft_parents[@]}" "${commit_regraft_parents[@]:graft_index+1}")
            else
              commit_regraft_parents=("${parent_regraft_parents[@]}" "${commit_regraft_parents[@]:graft_index+1}")
            fi
            # no need to recalculate `graft_index` if `break`
            break
          fi
        done

        # update regrafted commit
        commit_regraft_parents_dict[$commit]="${commit_regraft_parents[@]}"

        # order the unordered dictionary by visit sequence
        num_commits=${#commit_order_arr[@]}

        if (( num_commits )); then
          if [[ "${commit_order_arr[num_commits-1]}" != "$commit" ]]; then
            commit_order_arr[num_commits]="$commit"
          fi
        else
          commit_order_arr[num_commits]="$commit"
        fi
      done < "$empty_parent_commit_list_file"

      # regraft in visit order
      for commit in "${commit_order_arr[@]}"; do
        graft=(${commit_regraft_parents_dict[$commit]})
        echo "$commit -> ${graft[@]}"
        git replace --graft "$commit" "${graft[@]}"
      done
    fi

    if (( flag_finalize )); then
      if (( flag_prune_empty )); then
        echo
        echo "Finalizing: applying replace references..."

        # NOTE:
        #   Drop all arguments before the `--` argument.
        #   With the same filter range expression, all the references in the command line must be already moved.
        #
        args=("$@")
        num_args=${#args[@]}

        for (( arg_index=0; arg_index < num_args; arg_index++ )); do
          arg="${args[arg_index]}"

          if [[ "$arg" == '--' ]]; then
            args=("${args[@]:arg_index+1}")
            break
          fi
        done

        # NOTE:
        #   Use `-f` to avoid error: `Cannot create a new backup. A previous backup already exists in refs/original/`
        #
        call git filter-branch -f -- "${args[@]}"
      fi
    fi
  fi
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
