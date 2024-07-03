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
#       Remove submodule paths using `.gitmodules` file and the skip
#       filter from `--skip-submodule-*` option.
#       If all paths is removed, then remove the `.gitmodules` file too.
#       Has effect if `.gitmodules` is in path list, but the file does remove
#       only when all module paths is removed.
#       CAUTION:
#         The command line path list does not affect module paths from the
#         `.gitmodules`.
#     -P
#     --skip-submodule-path-prefix
#       Skip submodule remove for path with prefix (no globbing).
#       Has no effect if `--remove-submodules` flag is not used.
#       Has no effect if `.gitmodules` is in path list.
#     -I
#     --sync-gitignore-submodule-paths
#       Synchronize `.gitignore` for paths removed from `.gitmodules`.
#       Has no effect if `.gitignore` is in path list.
#       CAUTION:
#         Is supported a very limited lines format in the `.gitignore` file:
#           * Blank and comment lines does not restore.
#           * Leading and trailing white spaces in a line does trim before
#             check in the index.
#           * Paths with globbing, backslashes, ranges and exclusion pattern
#             does pass into `git ls-files` as is to detect indexed paths.
#         See details: https://git-scm.com/docs/gitignore#_pattern_format
#       CAUTION:
#         The command line path list does not affect paths from the
#         `.gitignore`.
#
#   //:
#     Separator to stop parse flags.
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
  export flag_sync_gitignore_submodule_paths=0
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
        elif [[ "${flag:0:1}" == 'I' ]]; then
          flag_sync_gitignore_submodule_paths=1
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

  export has_gitignore_in_path_list=0

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
    # NOTE:
    #   Uncomment for debug breakpoint per each commit rewrite, to resume cd into repository root and create `.git-rewrite/!` subdirectory.
    #
    #trap "echo $'\n'"$PWD"; while [[ ! -d '../!' ]]; do sleep 1; done; rmdir '../!'; trap - RETURN" RETURN

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
    IFS=$'\r\n' read path < <(git ls-files ".gitmodules")

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

    # Update the index before `.gitignore` synchronization, but after `.gitmodules` read, because:
    #   1. `.gitignore` synchronization does rely on already removed paths from the index.
    #   2. The command line path list can contain a path to a module directory and we do not check the command line paths on duplication.
    #      Instead we remove all collected paths altogether to avoid the index update twice, because `git ls-files` accepts duplicated paths.
    #
    if (( ${#path_arr[@]} )); then
      _0FFCA2F7_exec_remove_ls_paths
      path_arr=()
    fi

    # synchronize `.gitignore` for paths removed from `.gitmodules`
    if (( flag_sync_gitignore_submodule_paths && ! has_gitignore_in_path_list )); then
      IFS=$'\r\n' read path < <(git ls-files ".gitignore")

      if [[ -n "$path" ]] && git checkout-index -- '.gitignore'; then
        # read commit blob file
        local tree parent

        while IFS=$'\r\n' read -r line; do # IFS - with trim trailing line feeds
          printf -v EOL "%02X" "\"${line: -1}"
          if [[ "$EOL" == '0D' ]]; then
            line="${line:0:-1}"
          fi
          line="${line//[$'\r\n']/}"

          IFS=$' \t' read -r key value <<< "$line"

          case "$key" in
            'tree')
               tree="$value"
               ;;
            'parent')
               parent="$value"
               break
               ;;
          esac
        done < '../../.git-rewrite/commit'

        # map parent commit hash to a rewrited parent commit hash
        if [[ -f "../../.git-rewrite/map/$parent" ]]; then
          IFS=$'\r\n' read parent < "../../.git-rewrite/map/$parent"
        fi

        #echo "commit: $tree $parent"

        # create second temporary directory to generate `.gitignore` from the previous commit
        local commit_parent_tmp_dir="../../.git-rewrite/filter-cache/$parent/tmp"
        local commit_parent_tree_dir="../../.git-rewrite/filter-cache/$parent/tree"

        mkdir -p "$commit_parent_tmp_dir"

        if git diff-index --cached -U -p "$parent" -- '.gitignore' > "$commit_parent_tmp_dir/.gitignore.patch"; then
          if [[ -s "$commit_parent_tmp_dir/.gitignore.patch" ]]; then
            mkdir "$commit_parent_tree_dir"

            patch -u -R -p1 -s -o "$PWD/$commit_parent_tree_dir/.gitignore" '.gitignore' "$commit_parent_tmp_dir/.gitignore.patch"

            # read first line return character in case of Windows text format
            IFS='' read -r LR < ".gitignore"
            printf -v EOL "%02X" "\"${LR: -1}"
            if [[ "$EOL" == '0D' ]]; then
              printf -v LR "%s\r" "${LR//[^$'\r\n']/}"
            else
              LR="${LR//[^$'\r\n']/}"
            fi

            # Find paths in the `.gitignore` of the parent commit which is not in the file of the index, then
            # add them to the `.gitignore` in the working tree if a path is not a part of the updated index.
            echo -n > "$commit_parent_tmp_dir/.gitignore.new"

            local parent_line raw_parent_line
            local removed_line_arr=()                   # array of removed lines (existed only in the parent)
            local to_insert_after_existed_line_arr=()   # upper bound (last) existed (in both files) lines per each removed line (to insert after)
            local to_insert_after_existed_line
            local is_line_found
            local i num_lines

            # collect lines from parent `.gitignore` been removed in the indexed `.gitignore`
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
                removed_line_arr=("${removed_line_arr[@]}" "$raw_parent_line") # not trimmed line
                to_insert_after_existed_line_arr=("${to_insert_after_existed_line_arr[@]}" "$to_insert_after_existed_line") # trimmed line
              else
                to_insert_after_existed_line="$line" # trimmed line
              fi
            done < "$commit_parent_tree_dir/.gitignore"

            # insert lines been removed from the parent `.gitignore` but without upper bound lines
            num_lines=${#removed_line_arr[@]}

            for (( i=0; i < num_lines; i++ )); do
              if [[ -n "${to_insert_after_existed_line_arr[i]}" ]]; then
                break
              fi

              parent_line="${removed_line_arr[i]}"
              path="$parent_line"

              # convert absolute path to relative
              if [[ "${path:0:1}" == '/' ]]; then
                path=".$path"
              fi

              # insert if not in the index
              IFS=$'\r\n' read path < <(git ls-files "$path")
              if [[ -z "$path" ]]; then
                echo "$parent_line$LR"
              fi
            done >> "$commit_parent_tmp_dir/.gitignore.new"

            # update arrays
            if (( i )); then
              removed_line_arr=("${removed_line_arr[@]:i}")
              to_insert_after_existed_line_arr=("${to_insert_after_existed_line_arr[@]:i}")
            fi

            local prev_line

            num_lines=${#removed_line_arr[@]} # no array resize after this point

            # Generate new `.gitignore` using indexed `.gitignore` and the lines been removed from the parent `.gitignore`.
            # NOTE:
            #   We have to use the indexed `.gitignore` as a base, because the lines in the indexed `.gitignore` can be moved or edited
            #   without addition or removement.
            #
            while IFS=$'\r\n' read -r line; do # IFS - with trim trailing line feeds
              printf -v EOL "%02X" "\"${line: -1}"
              if [[ "$EOL" == '0D' ]]; then
                line="${line:0:-1}"
              fi
              line="${line//[$'\r\n']/}"

              while [[ "${line: -1}" =~ [[:space:]] ]]; do line="${line:0:-1}"; done # trim trailing white spaces
              while [[ "${line:0:1}" =~ [[:space:]] ]]; do line="${line:1}"; done # trim leading white spaces

              if [[ -n "$prev_line" && "$prev_line" != "$line" ]]; then
                # insert lines been removed from the parent `.gitignore` with upper bound line equal to previous trimmed line
                for (( i=0; i < num_lines; i++ )); do
                  if [[ "${to_insert_after_existed_line_arr[i]}" != "$prev_line" ]]; then
                    continue
                  fi

                  parent_line="${removed_line_arr[i]}"
                  path="$parent_line"

                  # convert absolute path to relative
                  if [[ "${path:0:1}" == '/' ]]; then
                    path=".$path"
                  fi

                  # insert if not in the index
                  IFS=$'\r\n' read path < <(git ls-files "$path")
                  if [[ -z "$path" ]]; then
                    echo "$parent_line$LR"
                  fi

                  # update arrays without resize
                  to_insert_after_existed_line_arr[i]=''
                done >> "$commit_parent_tmp_dir/.gitignore.new"
              fi

              # unconditional insert
              echo "$line$LR" >> "$commit_parent_tmp_dir/.gitignore.new"

              prev_line="$line"
            done < '.gitignore'

            if cp -T "$commit_parent_tmp_dir/.gitignore.new" '.gitignore'; then
              git update-index -- '.gitignore'
            fi

            rm -f "$commit_parent_tmp_dir/.gitignore.new"

            rm -f "$commit_parent_tree_dir/.gitignore"
            rmdir "$commit_parent_tree_dir"
          fi
        fi

        rm -f "$commit_parent_tmp_dir/.gitignore.patch"
        rmdir "$commit_parent_tmp_dir"

        rm '.gitignore'
      fi
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
