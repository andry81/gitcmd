#!/bin/bash

# Description:
#   Script to update a file text from all commits in a repository
#   using `git filter-branch` command.
#   For search and replace functionality the `find` and `sed` utilities is
#   used.
#

# Usage:
#   git_filter_branch_update_file_text.sh [<flags>] [//] <dir> <file-name-pattern> <text-to-match> <text-to-replace> [<cmd-line>]
#
#   <flags>:
#     -E (POSIX)
#     -r
#       Use sed with extended regular expression.
#
#     --esc-sh-chars
#       Escape shell control characters:
#         ` -> \`
#         $ -> \$
#
#     --sed-expr-prefix <sed-expr-prefix>
#       Prefix of the while sed expression in the format:
#         <PREFIX>; <BEGIN>|<text-to-match>|<text-to-replace>|<END>
#       By default the whole file does load into pattern space using this
#       prefix:
#         `H;1h;\$!d;x`
#
#     --sed-expr-begin <sed-expr-begin>
#       Begin of the sed expression in the format:
#         <PREFIX>; <BEGIN>|<text-to-match>|<text-to-replace>|<END>
#       By default the substitution is used:
#         `s`
#
#     --sed-expr-end <sed-expr-end>
#       Begin of the sed expression in the format:
#         <PREFIX>; <BEGIN>|<text-to-match>|<text-to-replace>|<END>
#       By default the global match is used:
#         `g`
#
#   //:
#     Separator to stop parse flags.
#
#   <dir>:
#     Source tree relative directory, where to search the <file-name-pattern>.
#     Passes to `find` utility.
#
#   <file-name-pattern>:
#     Source tree relative file pattern to a file to update.
#     Passes to `find` utility.
#
#   <text-to-match>:
#     The `sed` text to match.
#
#   <text-to-replace>:
#     The `sed` text to replace.
#
#   <cmd-line>:
#     The rest of command line passed to `git filter-branch` command.

# Examples:
#   # To update all commits in all heads to update first commit(s) in all
#   # ancestor branches.
#   >
#   cd myrepo/path
#   git_filter_branch_update_file_text.sh . README.md '<p/>' '</p>' -- --all
#
#   # To update all commits by tag `t1` to update first commit(s) in all
#   # ancestor branches.
#   >
#   cd myrepo/path
#   git_filter_branch_update_file_text.sh . README.md '<p/>' '</p>' -- t1
#
#   # To update single commit by a tag (excluding all parents).
#   >
#   cd myrepo/path
#   git_filter_branch_update_file_text.sh . README.md '<p/>' '</p>' -- t1 --not t1^@
#
#   # To update master branch commits excluding tags.
#   >
#   cd myrepo/path
#   git_filter_branch_update_file_text.sh . README.md '<p/>' '</p>' -- master ^t1 ^t2
#
#   # Remove specific 2 line text block with mixed line returns.
#   >
#   cd myrepo/path
#   git_filter_branch_update_file_text.sh -E . changelog.txt '2023\.05\.23:(\r\n|\n|\r)[^\r\n]+(\r\n|\n|\r)' '' -- master ^t1 ^t2
#
#   # Remove empty lines after each `YYYY.MM.DD:` or `YYYY-MM-DD:` text lines.
#   >
#   cd myrepo/path
#   git_filter_branch_update_file_text.sh -E . changelog.txt '(\d\d\d\d[.-]\d\d[.-]\d\d:)(\r\n|\n|\r)[\r\n]*' '\1\2' -- master ^t1 ^t2
#
#   # Remove file UTF-8 BOM characters.
#   # Based on:
#   #   https://unix.stackexchange.com/questions/381230/how-can-i-remove-the-bom-from-a-utf-8-file/381263#381263
#   >
#   cd myrepo/path
#   git_filter_branch_update_file_text.sh -E --sed-expr-prefix '' --sed-expr-begin 1s --sed-expr-end '' . changelog.txt '^\xEF\xBB\xBF' '' -- master

# CAUTION:
#   Beware of line returns in Windows. Even if `sed` does not match the string,
#   it still can change the line returns of output lines. This brings an entire
#   file change without any match.
#
#   So to workaround this the binary mode is always used:
#     https://stackoverflow.com/questions/4652652/preserve-line-endings

# NOTE:
#   The `git filter-repo` implementation does not support non exclusive file
#   filtering:
#     https://stackoverflow.com/questions/4110652/how-to-substitute-text-from-files-in-git-history/58252169#58252169
#
#     Using --path-glob (or --path) causes git filter-repo to only keep files
#     matching those specifications.
#
#   To workaround that you have to use the
#   `--replace-text-filename-callback` option which is a part of
#   `replace-text-limited-to-certain-files` branch implementation:
#     `Question: --replace-text only on certain files` :
#     https://github.com/newren/git-filter-repo/issues/74
#
#   But this one seems incomplete because of an exception throw:
#
#     `replace-text-limited-to-certain-files: TypeError: %d format: a real number is required, not bytes` :
#     https://github.com/newren/git-filter-repo/issues/468
#

# NOTE:
#   See all other details about rev-list caveats in the
#   `git_filter_branch_update_file.sh` file.

# NOTE:
#   You must use `git_cleanup_filter_branch.sh` script to cleanup the
#   repository from intermediate references.

# Script both for execution and inclusion.
if [[ -n "$BASH" ]]; then

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
      unset old_shopt
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

function git_filter_branch_update_file_text()
{
  local flag="$1"

  local option_esc_sh_chars=0

  # Based on: https://unix.stackexchange.com/questions/182153/sed-read-whole-file-into-pattern-space-without-failing-on-single-line-input/182154#182154
  #
  # NOTE:
  #   Reads portably whole file into pattern space.
  #
  local sed_expr_prefix='H;1h;\$!d;x' # for `find` escaped

  local sed_expr_begin='s'
  local sed_expr_end='g'

  local flag_E=0
  local flag_r=0
  local skip_flag

  local sed_bare_flags=' -i -b'

  while [[ "${flag:0:1}" == '-' ]]; do
    flag="${flag:1}"
    skip_flag=0

    if [[ "$flag" == '-esc-sh-chars' ]]; then
      option_esc_sh_chars=1
      skip_flag=1
    elif [[ "$flag" == '-sed-expr-prefix' ]]; then
      sed_expr_prefix="$2"
      shift
      skip_flag=1
    elif [[ "$flag" == '-sed-expr-begin' ]]; then
      sed_expr_begin="$2"
      shift
      skip_flag=1
    elif [[ "$flag" == '-sed-expr-end' ]]; then
      sed_expr_end="$2"
      shift
      skip_flag=1
    elif [[ "${flag:0:1}" == '-' ]]; then
      echo "$0: error: invalid flag: \`$flag\`" >&2
      return 255
    fi

    if (( ! skip_flag )); then
      if [[ "${flag//E/}" != "$flag" ]]; then
        flag_E=1
        sed_bare_flags="$sed_bare_flags -E"
      elif [[ "${flag//r/}" != "$flag" ]]; then
        flag_r=1
        sed_bare_flags="$sed_bare_flags -r"
      else
        echo "$0: error: invalid flag: \`${flag:0:1}\`" >&2
        return 255
      fi
    fi

    shift

    flag="$1"
  done

  if [[ "$1" == '//' ]]; then
    shift
  fi

  detect_find

  local dir="$1"
  local file_name_pttn="$2"
  local sed_text_to_match="$3"
  local sed_text_to_replace="$4"

  sed_expr_begin="${sed_expr_begin//\|/\\\|}"
  sed_expr_end="${sed_expr_end//\|/\\\|}"
  sed_text_to_match="${sed_text_to_match//\|/\\\|}"
  sed_text_to_replace="${sed_text_to_replace//\|/\\\|}"

  if (( option_esc_sh_chars )); then
    sed_expr_begin="${sed_expr_begin//\`/\\\`}"
    sed_expr_begin="${sed_expr_begin//\$/\\\$}"
    sed_expr_end="${sed_expr_end//\`/\\\`}"
    sed_expr_end="${sed_expr_end//\$/\\\$}"
    sed_text_to_match="${sed_text_to_match//\`/\\\`}"
    sed_text_to_match="${sed_text_to_match//\$/\\\$}"
    sed_text_to_replace="${sed_text_to_replace//\`/\\\`}"
    sed_text_to_replace="${sed_text_to_replace//\$/\\\$}"
  fi

  call git filter-branch --tree-filter "if [[ -e \"$dir\" ]]; then \"$SHELL_FIND\" \"$dir\" -name \"$file_name_pttn\" -type f -exec sed$sed_bare_flags -e \
    \"$sed_expr_prefix${sed_expr_prefix:+;}${sed_expr_prefix:+ }$sed_expr_begin|$sed_text_to_match|$sed_text_to_replace|$sed_expr_end\" \"{}\" \;; fi" "${@:5}"
}

# shortcut
function git_flb_up_f_t()
{
  git_filter_branch_update_file_text "$@"
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_filter_branch_update_file_text "$@"
fi

fi
