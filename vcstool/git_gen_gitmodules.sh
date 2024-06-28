#!/bin/bash

# Description:
#   Script to generate `.gitmodules` file from `vcstool` repositories file.
#   See for details:
#     https://github.com/dirk-thomas/vcstool
#     https://github.com/aaronplusone/vcstool/tree/feature-sparse-checkouts

# Usage:
#   git_gen_gitmodules.sh [<flags>] [//] [<dir> <input-file-name-pattern> [<output-file-name-prefix>]]
#
#   <flags>:
#     --ignore-type:
#       Ignore `type` field and generate for all repositories.
#
#     --default-input-file-name-prefix <default-input-file-name-prefix>:
#       Default input file name prefix to convert to default output file name
#       prefix.
#       If not defined, then `.externals` is used by default.
#
#     --exclude-dirs <dirs-list>:
#       List of directories to exclude from the search, where `<dirs-list>`
#       is a string evaluatable to the shell array.
#       If not defined, then `".git" ".log" "_externals" "_out"` is used by
#       default.
#
#     -u
#     --gen-submodule-name-from-url
#       Generate submodule name from `url` field instead of `repositories` key
#       values, but use the key value for the `url` field reduction.
#
#     --allow-fetch-recursion-on-sparsed-submodules
#       By default a sparse checkouted submodule has the
#       `fetchRecurseSubmodules = false` option in the output file.
#       This option avoids it.
#
#     --allow-update-on-sparsed-submodules
#       By default a sparse checkouted submodule has the `update = none` option
#       in the output file.
#       This option avoids it.
#
#     -f:
#       Force overwrite output file.
#
#     -a:
#       Append to output file name from `<output-file-name-prefix>` as complete
#       name (not prefix).
#
#     -t:
#       Append next found files except the first found file (tail files).
#
#   //:
#     Separator to stop parse flags.
#
#   <dir>
#     Directory to start search from using `find` tool.
#
#   <input-file-name-pattern>:
#     Path pattern for the `find` tool to find `vcstool` repository file(s).
#     If not defined, then `<default-input-file-name-prefix>*` is used as by
#     default from the `<dir>` or current directory.
#     `<default-input-file-name-prefix>` is used as a trim.
#
#   <output-file-name-prefix>:
#     Output file name prefix.
#     If not defined, then `.gitmodules` is used.
#
#   If input file name is equal to `<default-input-file-name-prefix>`, then
#   the `<output-file-name-prefix>` is used as the output complete file name.
#
#   If input file name begins by the `<default-input-file-name-prefix>`,
#   then the `<output-file-name-prefix>-<input-file-name-suffix>` is used,
#   where the `<input-file-name-suffix>` is the input file name without
#   `<default-input-file-name-prefix>` prefix.
#
#   In all other cases the output file name is
#   `<output-file-name-prefix>-<input-file-name>` is used.
#

# Examples:
#   >
#   cd myrepo/path
#   git_gen_gitmodules.sh . '.repos*'
#   >
#   find . -name '.gitmodules-repos*' -type f
#
#   >
#   cd myrepo/path
#   git_gen_gitmodules.sh . '.repos*' .gitmodules.
#   >
#   find . -name '.gitmodules.repos*' -type f
#
#   >
#   cd myrepo/path
#   git_gen_gitmodules.sh --default-input-file-name-prefix .repos // . '.repos*'
#   >
#   find . -name '.gitmodules*' -type f
#
#   >
#   cd myrepo/path
#   git_gen_gitmodules.sh . .externals-win7
#   >
#   find . -name .gitmodules-win7 -type f
#
#   >
#   cd myrepo/path
#   git_gen_gitmodules.sh -fa . '.externals-*'
#   >
#   find . -name .gitmodules -type f
#
#   >
#   cd myrepo/path
#   git_gen_gitmodules.sh -fatu
#   >
#   find . -name .gitmodules -type f
#

# Script both for execution and inclusion.
[[ -n "$BASH" ]] || return 0 || exit 0 # exit to avoid continue if the return can not be called

function evalcall()
{
  local IFS=$' \t'
  echo ">$*"
  eval "$@"
}

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

# NOTE:
#   Basically used together with forwarded local declaration, must not unset a variable if value is empty.
#
function tkl_declare()
{
  eval "$1=\"\$2\"" # can be defined externally as local
}

function yq_init()
{
  which yq > /dev/null || return $?

  local yq_help="$(yq --help)"

  # CAUTION:
  #   Array instead of string is required here for correct expansion!
  #
  if grep 'https://github.com/mikefarah/yq[/ ]' - <<< "$yq_help" >/dev/null; then
    YQ_CMDLINE_READ=(yq)
  elif grep 'https://github.com/kislyuk/yq[/ ]' - <<< "$yq_help" >/dev/null; then
    # CAUTION: jq must be installed too
    which jq > /dev/null || return $?
    YQ_CMDLINE_READ=(yq -cr)
  else
    YQ_CMDLINE_READ=(yq)
    echo "$0: error: \`yq\` implementation is not known." >&2
    return 255
  fi

  return 0
}

function yq_is_null()
{
  (( ! ${#@} )) && return 255
  eval "[[ -z \"\$$1\" || \"\$$1\" == 'null' ]]" && return 0
  return 1
}

function yq_fix_null()
{
  local __var_name
  local __arg
  for __arg in "$@"; do
    __var_name="${__arg%%:*}"
    yq_is_null "$__var_name" && \
      if [[ "$__arg" != "$__var_name" ]]; then
        tkl_declare "$__var_name" "${__arg#*:}"
      else
        tkl_declare "$__var_name" ''
      fi
  done
}

function git_gen_gitmodules()
{
  local flag="$1"

  local flag_force=0
  local flag_append=0
  local flag_tail=0
  local flag_ignore_type=0
  local default_input_file_name_prefix
  local exclude_dirs
  local flag_gen_submodule_name_from_url=0
  local flag_allow_fetch_recursion_on_sparsed_submodules=0
  local flag_allow_update_on_sparsed_submodules=0
  local skip_flag

  while [[ "${flag:0:1}" == '-' ]]; do
    flag="${flag:1}"
    skip_flag=0

    # long flags with parameters
    if [[ "$flag" == '-ignore-type' ]]; then
      flag_ignore_type=1
      skip_flag=1
    elif [[ "$flag" == '-default-input-file-name-prefix' ]]; then
      default_input_file_name_prefix="$2"
      skip_flag=1
      shift
    elif [[ "$flag" == '-exclude-dirs' ]]; then
      exclude_dirs="$2"
      skip_flag=1
      shift
    elif [[ "$flag" == '-gen-submodule-name-from-url' ]]; then
      flag_gen_submodule_name_from_url=1
      skip_flag=1
    elif [[ "$flag" == '-allow-fetch-recursion-on-sparsed-submodules' ]]; then
      flag_allow_fetch_recursion_on_sparsed_submodules=1
      skip_flag=1
    elif [[ "$flag" == '-allow-update-on-sparsed-submodules' ]]; then
      flag_allow_update_on_sparsed_submodules=1
      skip_flag=1
    elif [[ "${flag:0:1}" == '-' ]]; then
      echo "$0: error: invalid flag: \`$flag\`" >&2
      return 255
    fi

    # short flags
    if (( ! skip_flag )); then
      while [[ -n "$flag" ]]; do
        if [[ "${flag//f/}" != "$flag" ]]; then
          flag_force=1
          flag="${flag//f/}"
        elif [[ "${flag//a/}" != "$flag" ]]; then
          flag_append=1
          flag="${flag//a/}"
        elif [[ "${flag//t/}" != "$flag" ]]; then
          flag_tail=1
          flag="${flag//t/}"
        elif [[ "${flag//u/}" != "$flag" ]]; then
          flag_gen_submodule_name_from_url=1
          flag="${flag//u/}"
        else
          echo "$0: error: invalid flag: \`${flag:0:1}\`" >&2
          return 255
        fi
      done
    fi

    shift

    flag="$1"
  done

  if [[ "$1" == '//' ]]; then
    shift
  fi

  if [[ -z "$default_input_file_name_prefix" ]]; then
    default_input_file_name_prefix='.externals'
  fi

  if [[ -z "$exclude_dirs" ]]; then
    exclude_dirs='".git" ".log" "_externals" "_out"'
  fi

  local dir="${1:-.}"
  local input_file_name_pattern="${2:-"$default_input_file_name_prefix*"}"
  local output_file_name_prefix="${3:-".gitmodules"}"

  local exclude_dits_arr
  eval exclude_dits_arr=($exclude_dirs)

  yq_init || return $?

  detect_find

  # cygwin workaround
  SHELL_FIND="${SHELL_FIND//\\//}"

  local IFS
  local input_file_name input_file_name_suffix output_file_name output_file_dir output_file_path
  local type url version subpaths_num
  local external_path submodule_name module_index
  local i LR

  # build exclude dirs
  local find_bare_flags

  # prefix all relative paths with './' to apply the exclude dirs
  for (( i=0; i < ${#exclude_dits_arr[@]}; i++ )); do
    if [[ "${exclude_dits_arr[i]:0:1}" != "/" && "${exclude_dits_arr[i]:0:2}" != "./" && "${exclude_dits_arr[i]:0:3}" != "../" ]]; then
      exclude_dits_arr[i]="./${exclude_dits_arr[i]}"
    fi
  done

  for (( i=0; i < ${#exclude_dits_arr[@]}; i++ )); do
    find_bare_flags="$find_bare_flags -not \\( -path \"${exclude_dits_arr[i]}\" -prune \\)"
  done

  local file_index=-1

  IFS=$'\r\n'; for input_file in `eval \"\$SHELL_FIND\" \"\$dir\"$find_bare_flags -iname \"\$input_file_name_pattern\" -type f`; do # IFS - with trim trailing line feeds
    (( file_index++ ))

    input_file_name="${input_file##*/}"
    output_file_dir="${input_file%/*}"

    if (( ! flag_append )); then
      if [[ "$input_file_name" == "$default_input_file_name_prefix" ]]; then
        output_file_name="$output_file_name_prefix"
      else
        input_file_name_suffix="${input_file_name#"$default_input_file_name_prefix"}"

        if [[ "$input_file_name_suffix" != "$input_file_name" ]]; then
          input_file_name_suffix="${input_file_name_suffix#"-"}"
          input_file_name_suffix="${input_file_name_suffix#"."}"
          output_file_name="$output_file_name_prefix-${input_file_name_suffix#"-"}"
        else
          input_file_name="${input_file_name#"-"}"
          input_file_name="${input_file_name#"."}"
          output_file_name="$output_file_name_prefix-$input_file_name"
        fi
      fi
    else
      output_file_name="$output_file_name_prefix"
    fi

    output_file_path="$output_file_dir/$output_file_name"

    if (( ! flag_force )) && [[ -f "$output_file_path" ]]; then
      echo "$0: error: output file already exists: \`${output_file_path#"./"}\`" >&2
      return 1
    fi

    # read first line return character in case of Windows text format
    IFS='' read -r LR < "$input_file"
    LR="${LR//[^$'\r\n']/}"

    module_index=-1

    # save stdout
    exec 5>&1

    if (( ! flag_append || flag_tail && ! file_index )); then
      echo "$output_file_dir: $input_file_name -> $output_file_name"
      exec 1> "$output_file_path"
    else
      echo "$output_file_dir: $input_file_name ->> $output_file_name"
      exec 1>> "$output_file_path"
      echo "$LR"
    fi

    IFS=$'\r\n'; for external_path in $("${YQ_CMDLINE_READ[@]}" '.repositories|to_entries[]|.key' "$input_file"); do # IFS - with trim trailing line feeds
      (( module_index++ ))

      # CAUTION:
      #   Prevent of invalid values spread if upstream user didn't properly commit completely correct yaml file or didn't commit at all.
      #
      yq_is_null external_path && break

      IFS=$'\r\n' read -r -d '' type url version <<< \
        $("${YQ_CMDLINE_READ[@]}" ".repositories[\"$external_path\"].type,.repositories[\"$external_path\"].url,.repositories[\"$external_path\"].version" "$input_file") 2>/dev/null

      # CAUTION:
      #   Prevent of invalid values spread.
      #
      yq_fix_null url && break
      yq_fix_null type version

      IFS=$'\r\n' read -r -d '' subpaths_num <<< \
        $("${YQ_CMDLINE_READ[@]}" "(.repositories[\"$external_path\"].subpaths|length)" "$input_file")

      # CAUTION:
      #   Prevent of invalid values spread.
      #
      yq_fix_null subpaths_num:0

      # remove trailing slashes
      while [[ "${external_path: -1}" == '/' ]]; do
        external_path="${external_path:0:-1}"
      done

      if (( ! flag_gen_submodule_name_from_url )); then
        submodule_name="${external_path#*/}"
        submodule_name="${submodule_name//\//--}"
      else
        submodule_name="$url"

        # remove trailing slashes
        while [[ "${submodule_name: -1}" == '/' ]]; do
          submodule_name="${submodule_name:0:-1}"
        done

        submodule_name="${submodule_name##*/}"

        if [[ "${external_path#*/}" != "$submodule_name" ]]; then
          # reduce prefix if not equal
          submodule_name="${submodule_name#*--}"
        fi
      fi

      if [[ "$type" != "git" ]] && (( ! flag_ignore_type )); then
        continue
      fi

      if (( module_index > 0 )); then
        echo "$LR"
      fi
      echo "[submodule \"$submodule_name\"]$LR"
      echo "  path = $external_path$LR"
      echo "  url = $url$LR"
      echo "  branch = $version$LR"
      if (( subpaths_num )); then
        if (( ! flag_allow_fetch_recursion_on_sparsed_submodules )); then
          echo "  fetchRecurseSubmodules = false$LR"
        fi
        if (( ! flag_allow_update_on_sparsed_submodules )); then
          echo "  update = none$LR"
        fi
      fi
    done

    # restore stdout
    exec 1>&5
  done

  return 0
}

# shortcut
function git_gen_gms()
{
  git_gen_gitmodules "$@"
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  git_gen_gitmodules "$@"
fi
