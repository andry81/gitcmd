#!/usr/bin/env bash

# USAGE:
#   git_filter_branch_trim_parents.sh [<flags>] [// <cmdline>]

# Description:
#   Script to trim a commit parents does found using a date-time boundary.
#   The finalization part is using the `git filter-branch` command.

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
#     Executes `git filter-branch` command to apply replace references.
#     Has no effect if nothing to finalize.

# //:
#   Separator to stop parse flags.

# <cmdline>:
#   The rest of command line passed to `git filter-branch` command.

# Examples:
#   >
#   cd myrepo/path
#   git_filter_branch_remove_paths.sh --date-before 2026-01-01T00:00:00Z

# CAUTION:
#   Only a single branch and a single revision (not range) request is
#   supported, due to a limitation of the underlying `git log` command.

# NOTE:
#   You must use `git_cleanup_filter_branch.sh` script to cleanup the
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

function git_filter_branch_trim_parents()
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

  if [[ -d '.git-filter-cache' ]]; then
    echo "$0: error: remove \`.git-filter-cache\` directory before continue." >&2
    return 2
  fi

  if [[ "$1" == '//' ]]; then
    shift
  fi

  local arg arg_index
  local args=("$@")
  local num_args=${#args[@]}

  local hash

  IFS=$' \t' read hash _ <<< $(git log --after="$option_date_before" --reverse --oneline --max-count-oldest=1)

  call git replace --graft $hash || return

  # suppress warning
  export FILTER_BRANCH_SQUELCH_WARNING=1

  if (( flag_finalize )); then
    echo
    echo "Finalizing: applying replace references..."

    # NOTE:
    #   Drop all arguments before the `--` argument.
    #   With the same filter range expression, all the references in the command line must be already moved.
    #
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
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_filter_branch_trim_parents "$@"
fi
