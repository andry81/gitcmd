#!/usr/bin/env bash

# USAGE:
#   git_filter_repo_trim_parents.sh [<flags>] [// <cmdline>]

# Description:
#   Script to trim a commit parents does found using a date-time boundary.
#   The finalization part is using the `git filter-repo` command:
#   https://github.com/newren/git-filter-repo
#   https://github.com/newren/git-filter-repo/tree/HEAD/Documentation/git-filter-repo.txt

# <flags>:
#   --date-before <date-time>
#     Date with or without time to trim a commit before the date.
#
#     Format:
#       YYYY-MM-DDTHH-mm-ssZ
#
#     CAUTION:
#       You have to use complete format in case of a time part absence:
#         YYYY-MM-DDT00:00:00Z
#       Otherwise the commit would be returned as before the midnight of the
#       date or before the morning of the next day:
#         YYY-MM-DDT23:59:59Z + 1 second
#
#   -z
#   --finalize
#     Finalizes changes and applies replace references just after the replace
#     references generation.
#     Executes `git filter-repo` command to apply replace references.
#     Has no effect if nothing to finalize.

# //:
#   Separator to stop parse flags.

# <cmdline>:
#   The rest of command line passed to `git filter-repo` command.

# Examples:
#   >
#   cd myrepo/path
#   git_filter_repo_remove_paths.sh --date-before 2026-01-01T00:00:00Z // -f

# NOTE:
#   The implementation implies the `--partial` flag to avoid remove of the
#   origin remote.
#
#   See details in the documentation:
#
#     https://htmlpreview.github.io/?https://github.com/newren/git-filter-repo/blob/docs/html/git-filter-repo.html#INTERNALS
#
#   --partial
#
#     Do a partial history rewrite, resulting in the mixture of old and new
#     history. This implies a default of update-no-add for --replace-refs,
#     disables rewriting refs/remotes/origin/* to refs/heads/*, disables
#     removing of the origin remote, disables removing unexported refs,
#     disables expiring the reflog, and disables the automatic post-filter gc.
#     Also, this modifies --tag-rename and --refname-callback options such that
#     instead of replacing old refs with new refnames, it will instead create
#     new refs and keep the old ones around. Use with caution.

# CAUTION:
#   Only a single branch and a single revision (not range) request is
#   supported, due to a limitation of the underlying `git log` command.

# NOTE:
#   You must use `git_cleanup_filter_repo.sh` script to cleanup the
#   repository from intermediate references.
#
#   If `--finalize` flag is used, then to remove the replace references use
#   `git_cleanup_replace_refs.sh` script.

# Script both for execution and inclusion.
[[ -n "$BASH" ]] || return 0 || exit 0 # exit to avoid continue if the return can not be called

function call()
{
  local IFS=$' \t'
  echo ">$*"
  "$@"
}

function git_filter_repo_trim_parents()
{
  local IFS
  local flag="$1"

  local option_date_before
  local flag_finalize=0
  local skip_flag

  while [[ "${flag:0:1}" == '-' ]]; do
    flag="${flag:1}"
    skip_flag=0

    # long flags
    if [[ "$flag" == '-date-before' ]]; then
      option_date_before="$2"
      shift
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
        if [[ "${flag:0:1}" == 'z' ]]; then
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

  if [[ "$1" == '//' ]]; then
    shift
  fi

  local args=("$@")

  local hash

  IFS=$' \t' read hash _ <<< $(git log --after="$option_date_before" --reverse --oneline --max-count-oldest=1)

  call git replace --graft $hash || return

  if (( flag_finalize )); then
    echo
    echo "Finalizing: applying replace references..."

    call git filter-repo --partial "${args[@]}"
  fi
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_filter_repo_trim_parents "$@"
fi
