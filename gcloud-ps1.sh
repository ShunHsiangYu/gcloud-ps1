#!/usr/bin/env bash

# gcloud prompt helper for bash/zsh
# Displays current account and project

# Debug
[[ -n $DEBUG ]] && set -x

# Default values for the prompt
# Override these values in ~/.zshrc or ~/.bashrc
GCLOUD_PS1_BINARY="${GCLOUD_PS1_BINARY:-gcloud}"
GCLOUD_PS1_SYMBOL_ENABLE="${GCLOUD_PS1_SYMBOL_ENABLE:-true}"
GCLOUD_PS1_SYMBOL_DEFAULT=${GCLOUD_PS1_SYMBOL_DEFAULT:-$'\u26C5'}
GCLOUD_PS1_SYMBOL_PADDING="${GCLOUD_PS1_SYMBOL_PADDING:-true}"
GCLOUD_PS1_PJ_ENABLE="${GCLOUD_PS1_PJ_ENABLE:-true}"
GCLOUD_PS1_ACCOUNT_ENABLE="${GCLOUD_PS1_ACCOUNT_ENABLE:-true}"
GCLOUD_PS1_PREFIX="${GCLOUD_PS1_PREFIX-(}"
GCLOUD_PS1_SEPARATOR="${GCLOUD_PS1_SEPARATOR-|}"
GCLOUD_PS1_DIVIDER="${GCLOUD_PS1_DIVIDER-:}"
GCLOUD_PS1_SUFFIX="${GCLOUD_PS1_SUFFIX-)}"

GCLOUD_PS1_SYMBOL_COLOR="${GCLOUD_PS1_SYMBOL_COLOR-blue}"
GCLOUD_PS1_ACC_COLOR="${GCLOUD_PS1_ACC_COLOR-red}"
GCLOUD_PS1_PJ_COLOR="${GCLOUD_PS1_PJ_COLOR-cyan}"
GCLOUD_PS1_BG_COLOR="${GCLOUD_PS1_BG_COLOR}"

GCLOUD_PS1_DISABLE_PATH="${HOME}/.gcloud-ps1/disabled"
GCLOUD_PS1_LAST_TIME=0
GCLOUD_PS1_ACCOUNT_FUNCTION="${GCLOUD_PS1_ACCOUNT_FUNCTION}"
GCLOUD_PS1_PROJECT_FUNCTION="${GCLOUD_PS1_PROJECT_FUNCTION}"

# Determine our shell
if [ "${ZSH_VERSION-}" ]; then
  GCLOUD_PS1_SHELL="zsh"
elif [ "${BASH_VERSION-}" ]; then
  GCLOUD_PS1_SHELL="bash"
fi

_gcloud_ps1_init() {
  [[ -f "${GCLOUD_PS1_DISABLE_PATH}" ]] && GCLOUD_PS1_ENABLED=off

  case "${GCLOUD_PS1_SHELL}" in
    "zsh")
      _GCLOUD_PS1_OPEN_ESC="%{"
      _GCLOUD_PS1_CLOSE_ESC="%}"
      _GCLOUD_PS1_DEFAULT_BG="%k"
      _GCLOUD_PS1_DEFAULT_FG="%f"
      setopt PROMPT_SUBST
      autoload -U add-zsh-hook
      add-zsh-hook precmd _gcloud_ps1_update_cache
      zmodload -F zsh/stat b:zstat
      zmodload zsh/datetime
      ;;
    "bash")
      _GCLOUD_PS1_OPEN_ESC=$'\001'
      _GCLOUD_PS1_CLOSE_ESC=$'\002'
      _GCLOUD_PS1_DEFAULT_BG=$'\033[49m'
      _GCLOUD_PS1_DEFAULT_FG=$'\033[39m'
      [[ $PROMPT_COMMAND =~ _gcloud_ps1_update_cache ]] || PROMPT_COMMAND="_gcloud_ps1_update_cache;${PROMPT_COMMAND:-:}"
      ;;
  esac
}

_gcloud_ps1_color_fg() {
  local GCLOUD_PS1_FG_CODE
  case "${1}" in
    black) GCLOUD_PS1_FG_CODE=0;;
    red) GCLOUD_PS1_FG_CODE=1;;
    green) GCLOUD_PS1_FG_CODE=2;;
    yellow) GCLOUD_PS1_FG_CODE=3;;
    blue) GCLOUD_PS1_FG_CODE=4;;
    magenta) GCLOUD_PS1_FG_CODE=5;;
    cyan) GCLOUD_PS1_FG_CODE=6;;
    white) GCLOUD_PS1_FG_CODE=7;;
    # 256
    [0-9]|[1-9][0-9]|[1][0-9][0-9]|[2][0-4][0-9]|[2][5][0-6]) GCLOUD_PS1_FG_CODE="${1}";;
    *) GCLOUD_PS1_FG_CODE=default
  esac

  if [[ "${GCLOUD_PS1_FG_CODE}" == "default" ]]; then
    GCLOUD_PS1_FG_CODE="${_GCLOUD_PS1_DEFAULT_FG}"
    return
  elif [[ "${GCLOUD_PS1_SHELL}" == "zsh" ]]; then
    GCLOUD_PS1_FG_CODE="%F{$GCLOUD_PS1_FG_CODE}"
  elif [[ "${GCLOUD_PS1_SHELL}" == "bash" ]]; then
    if tput setaf 1 &> /dev/null; then
      GCLOUD_PS1_FG_CODE="$(tput setaf ${GCLOUD_PS1_FG_CODE})"
    elif [[ $GCLOUD_PS1_FG_CODE -ge 0 ]] && [[ $GCLOUD_PS1_FG_CODE -le 256 ]]; then
      GCLOUD_PS1_FG_CODE="\033[38;5;${GCLOUD_PS1_FG_CODE}m"
    else
      GCLOUD_PS1_FG_CODE="${_GCLOUD_PS1_DEFAULT_FG}"
    fi
  fi
  echo ${_GCLOUD_PS1_OPEN_ESC}${GCLOUD_PS1_FG_CODE}${_GCLOUD_PS1_CLOSE_ESC}
}

_gcloud_ps1_color_bg() {
  local GCLOUD_PS1_BG_CODE
  case "${1}" in
    black) GCLOUD_PS1_BG_CODE=0;;
    red) GCLOUD_PS1_BG_CODE=1;;
    green) GCLOUD_PS1_BG_CODE=2;;
    yellow) GCLOUD_PS1_BG_CODE=3;;
    blue) GCLOUD_PS1_BG_CODE=4;;
    magenta) GCLOUD_PS1_BG_CODE=5;;
    cyan) GCLOUD_PS1_BG_CODE=6;;
    white) GCLOUD_PS1_BG_CODE=7;;
    # 256
    [0-9]|[1-9][0-9]|[1][0-9][0-9]|[2][0-4][0-9]|[2][5][0-6]) GCLOUD_PS1_BG_CODE="${1}";;
    *) GCLOUD_PS1_BG_CODE=$'\033[0m';;
  esac

  if [[ "${GCLOUD_PS1_BG_CODE}" == "default" ]]; then
    GCLOUD_PS1_FG_CODE="${_GCLOUD_PS1_DEFAULT_BG}"
    return
  elif [[ "${GCLOUD_PS1_SHELL}" == "zsh" ]]; then
    GCLOUD_PS1_BG_CODE="%K{$GCLOUD_PS1_BG_CODE}"
  elif [[ "${GCLOUD_PS1_SHELL}" == "bash" ]]; then
    if tput setaf 1 &> /dev/null; then
      GCLOUD_PS1_BG_CODE="$(tput setab ${GCLOUD_PS1_BG_CODE})"
    elif [[ $GCLOUD_PS1_BG_CODE -ge 0 ]] && [[ $GCLOUD_PS1_BG_CODE -le 256 ]]; then
      GCLOUD_PS1_BG_CODE="\033[48;5;${GCLOUD_PS1_BG_CODE}m"
    else
      GCLOUD_PS1_BG_CODE="${DEFAULT_BG}"
    fi
  fi
  echo ${OPEN_ESC}${GCLOUD_PS1_BG_CODE}${CLOSE_ESC}
}

_gcloud_ps1_binary_check() {
  command -v $1 >/dev/null
}

_gcloud_ps1_symbol() {
  [[ "${GCLOUD_PS1_SYMBOL_ENABLE}" == false ]] && return

  case "${GCLOUD_PS1_SHELL}" in
    bash)
      if ((BASH_VERSINFO[0] >= 4)) && [[ $'\u2388' != "\\u2388" ]]; then
        GCLOUD_PS1_SYMBOL="${GCLOUD_PS1_SYMBOL_DEFAULT}"
      else
        GCLOUD_PS1_SYMBOL=$'\xE2\x8E\x88'
      fi
      ;;
    zsh)
      GCLOUD_PS1_SYMBOL="${GCLOUD_PS1_SYMBOL_DEFAULT}"
  esac

  if [[ "${GCLOUD_PS1_SYMBOL_PADDING}" == true ]]; then
    echo "${GCLOUD_PS1_SYMBOL} "
  else
    echo "${GCLOUD_PS1_SYMBOL}"
  fi

}

_gcloud_ps1_split() {
  type setopt >/dev/null 2>&1 && setopt SH_WORD_SPLIT
  local IFS=$1
  echo $2
}

_gcloud_ps1_file_newer_than() {
  local mtime
  local file=$1
  local check_time=$2

  if [[ "${GCLOUD_PS1_SHELL}" == "zsh" ]]; then
    mtime=$(zstat +mtime "${file}")
  elif stat -c "%s" /dev/null &> /dev/null; then
    # GNU stat
    mtime=$(stat -L -c %Y "${file}")
  else
    # BSD stat
    mtime=$(stat -L -f %m "$file")
  fi

  [[ "${mtime}" -gt "${check_time}" ]]
}

_gcloud_ps1_update_cache() {
  local return_code=$?

  [[ "${GCLOUD_PS1_ENABLED}" == "off" ]] && return $return_code

  if ! _gcloud_ps1_binary_check "${GCLOUD_PS1_BINARY}"; then
    # No ability to fetch account/project; display N/A.
    GCLOUD_PS1_ACCOUNT="N/A"
    GCLOUD_PS1_PROJECT="N/A"
    return
  fi

  if _gcloud_ps1_file_newer_than "${HOME}/.config/gcloud/active_config" "${GCLOUD_PS1_LAST_TIME}"; then
    _gcloud_ps1_get_account_pj
    return
  fi

  return $return_code
}

_gcloud_ps1_get_account() {
  if [[ "${GCLOUD_PS1_ACCOUNT_ENABLE}" == true ]]; then
    GCLOUD_PS1_ACCOUNT="$(${GCLOUD_PS1_BINARY} config get-value account 2>/dev/null)"
    # Set project to 'N/A' if it is not defined
    GCLOUD_PS1_ACCOUNT="${GCLOUD_PS1_ACCOUNT:-N/A}"

    if [[ ! -z "${GCLOUD_PS1_ACCOUNT_FUNCTION}" ]]; then
      GCLOUD_PS1_ACCOUNT=$($GCLOUD_PS1_ACCOUNT_FUNCTION $GCLOUD_PS1_ACCOUNT)
    fi
  fi
}

_gcloud_ps1_get_pj() {
  if [[ "${GCLOUD_PS1_PJ_ENABLE}" == true ]]; then
    GCLOUD_PS1_PROJECT="$(${GCLOUD_PS1_BINARY} config get-value project 2>/dev/null)"
    # Set project to 'N/A' if it is not defined
    GCLOUD_PS1_PROJECT="${GCLOUD_PS1_PROJECT:-N/A}"

    if [[ ! -z "${GCLOUD_PS1_PROJECT_FUNCTION}" ]]; then
        GCLOUD_PS1_PROJECT=$($GCLOUD_PS1_PROJECT_FUNCTION $GCLOUD_PS1_PROJECT)
    fi
  fi
}

_gcloud_ps1_get_account_pj() {
  # Set the command time
  if [[ "${GCLOUD_PS1_SHELL}" == "bash" ]]; then
    if ((BASH_VERSINFO[0] >= 4 && BASH_VERSINFO[1] >= 2)); then
      GCLOUD_PS1_LAST_TIME=$(printf '%(%s)T')
    else
      GCLOUD_PS1_LAST_TIME=$(date +%s)
    fi
  elif [[ "${GCLOUD_PS1_SHELL}" == "zsh" ]]; then
    GCLOUD_PS1_LAST_TIME=$EPOCHSECONDS
  fi

  _gcloud_ps1_get_account
  _gcloud_ps1_get_pj
}

# Set gcloud-ps1 shell defaults
_gcloud_ps1_init

_gcloudon_usage() {
  cat <<"EOF"
Toggle gcloud-ps1 prompt on

Usage: gcloudon [-g | --global] [-h | --help]

With no arguments, turn off gcloud-ps1 status for this shell instance (default).

  -g --global  turn on gcloud-ps1 status globally
  -h --help    print this message
EOF
}

_gcloudoff_usage() {
  cat <<"EOF"
Toggle gcloud-ps1 prompt off

Usage: gcloudoff [-g | --global] [-h | --help]

With no arguments, turn off gcloud-ps1 status for this shell instance (default).

  -g --global turn off gcloud-ps1 status globally
  -h --help   print this message
EOF
}

gcloudon() {
  if [[ "${1}" == '-h' || "${1}" == '--help' ]]; then
    _GCLOUDon_usage
  elif [[ "${1}" == '-g' || "${1}" == '--global' ]]; then
    rm -f -- "${GCLOUD_PS1_DISABLE_PATH}"
  elif [[ "$#" -ne 0 ]]; then
    echo -e "error: unrecognized flag ${1}\\n"
    _gcloudon_usage
    return
  fi

  GCLOUD_PS1_ENABLED=on
}

gcloudoff() {
  if [[ "${1}" == '-h' || "${1}" == '--help' ]]; then
    _GCLOUDoff_usage
  elif [[ "${1}" == '-g' || "${1}" == '--global' ]]; then
    mkdir -p -- "$(dirname "${GCLOUD_PS1_DISABLE_PATH}")"
    touch -- "${GCLOUD_PS1_DISABLE_PATH}"
  elif [[ $# -ne 0 ]]; then
    echo "error: unrecognized flag ${1}" >&2
    _gcloudoff_usage
    return
  fi

  GCLOUD_PS1_ENABLED=off
}

# Build our prompt
gcloud_ps1() {
  [[ "${GCLOUD_PS1_ENABLED}" == "off" ]] && return
  # [[ -z "${GCLOUD_PS1_CONTEXT}" ]] && [[ "${GCLOUD_PS1_CONTEXT_ENABLE}" == true ]] && return

  local GCLOUD_PS1
  local GCLOUD_PS1_RESET_COLOR="${_GCLOUD_PS1_OPEN_ESC}${_GCLOUD_PS1_DEFAULT_FG}${_GCLOUD_PS1_CLOSE_ESC}"

  # Background Color
  [[ -n "${GCLOUD_PS1_BG_COLOR}" ]] && GCLOUD_PS1+="$(_gcloud_ps1_color_bg ${GCLOUD_PS1_BG_COLOR})"

  # Prefix
  [[ -n "${GCLOUD_PS1_PREFIX}" ]] && GCLOUD_PS1+="${GCLOUD_PS1_PREFIX}"

  # Symbol
  GCLOUD_PS1+="$(_gcloud_ps1_color_fg $GCLOUD_PS1_SYMBOL_COLOR)$(_gcloud_ps1_symbol)${GCLOUD_PS1_RESET_COLOR}"

  if [[ -n "${GCLOUD_PS1_SEPARATOR}" ]] && [[ "${GCLOUD_PS1_SYMBOL_ENABLE}" == true ]]; then
    GCLOUD_PS1+="${GCLOUD_PS1_SEPARATOR}"
  fi

  # Account
  if [[ "${GCLOUD_PS1_ACCOUNT_ENABLE}" == true ]]; then
    GCLOUD_PS1+="$(_gcloud_ps1_color_fg $GCLOUD_PS1_ACC_COLOR)${GCLOUD_PS1_ACCOUNT}${GCLOUD_PS1_RESET_COLOR}"
  fi

  # Project
  if [[ "${GCLOUD_PS1_PJ_ENABLE}" == true ]]; then
    if [[ -n "${GCLOUD_PS1_DIVIDER}" ]] && [[ "${GCLOUD_PS1_ACCOUNT_ENABLE}" == true ]]; then
      GCLOUD_PS1+="${GCLOUD_PS1_DIVIDER}"
    fi
    GCLOUD_PS1+="$(_gcloud_ps1_color_fg ${GCLOUD_PS1_PJ_COLOR})${GCLOUD_PS1_PROJECT}${GCLOUD_PS1_RESET_COLOR}"
  fi

  # Suffix
  [[ -n "${GCLOUD_PS1_SUFFIX}" ]] && GCLOUD_PS1+="${GCLOUD_PS1_SUFFIX}"

  # Close Background color if defined
  [[ -n "${GCLOUD_PS1_BG_COLOR}" ]] && GCLOUD_PS1+="${_GCLOUD_PS1_OPEN_ESC}${_GCLOUD_PS1_DEFAULT_BG}${_GCLOUD_PS1_CLOSE_ESC}"

  echo "${GCLOUD_PS1}"
}