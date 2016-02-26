#!/usr/bin/env bash
# BASH3 Boilerplate
#
# This file:
#
#  - Is a template to write better bash scripts
#  - Is delete-key friendly, in case you don't need e.g. command line option parsing
#
# More info:
#
#  - https://github.com/kvz/bash3boilerplate
#  - http://kvz.io/blog/2013/02/26/introducing-bash3boilerplate/
#
# Version: 2.0.0
#
# Authors:
#
#  - Kevin van Zonneveld (http://kvz.io)
#  - Izaak Beekman (https://izaakbeekman.com/)
#  - Alexander Rathai (Alexander.Rathai@gmail.com)
#
# Usage:
#
#  LOG_LEVEL=7 ./main.sh -f /tmp/x -d
#
# Licensed under MIT
# Copyright (c) 2013 Kevin van Zonneveld (http://kvz.io)


### Configuration
#####################################################################

# Exit on error. Append ||true if you expect an error.
# `set` is safer than relying on a shebang like `#!/bin/bash -e` because that is neutralized
# when someone runs your script as `bash yourscript.sh`
set -o errexit
set -o nounset

# Bash will remember & return the highest exitcode in a chain of pipes.
# This way you can catch the error in case mysqldump fails in `mysqldump |gzip`
set -o pipefail
# set -o xtrace

# Environment variables and their defaults
LOG_LEVEL="${LOG_LEVEL:-6}" # 7 = debug -> 0 = emergency
NO_COLOR="${NO_COLOR:-}"    # true = disable color. otherwise autodetected

# Commandline options. This defines the usage page, and is used to parse cli
# opts & defaults from. The parsing is unforgiving so be precise in your syntax
# - A short option must be preset for every long option; but every short option
#   need not have a long option
# - `--` is respected as the separator between options and arguments
read -r -d '' usage <<-'EOF' || true # exits non-zero when EOF encountered
  -f --file  [arg] Filename to process. Required.
  -o --ofp-prefix [arg] Open Fortran Parser installation path. Default="${PWD}"
  -v --versbose               Enable verbose mode, print script as it is executed
  -d --debug       Enables debug mode
  -h --help        This page
EOF

# Set magic variables for current file and its directory.
# BASH_SOURCE[0] is used so we can display the current file even if it is sourced by a parent script.
# If you need the script that was executed, consider using $0 instead.
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__os="Linux"
if [[ "${OSTYPE:-}" == "darwin"* ]]; then
  __os="OSX"
fi

### Functions
#####################################################################

function _fmt ()      {
  local color_debug="\x1b[35m"
  local color_info="\x1b[32m"
  local color_notice="\x1b[34m"
  local color_warning="\x1b[33m"
  local color_error="\x1b[31m"
  local color_critical="\x1b[1;31m"
  local color_alert="\x1b[1;33;41m"
  local color_emergency="\x1b[1;4;5;33;41m"
  local colorvar=color_$1

  local color="${!colorvar:-$color_error}"
  local color_reset="\x1b[0m"
  if [ "${NO_COLOR}" = "true" ] || [[ "${TERM:-}" != "xterm"* ]] || [ -t 1 ]; then
    # Don't use colors on pipes or non-recognized terminals
    color=""; color_reset=""
  fi
  echo -e "$(date -u +"%Y-%m-%d %H:%M:%S UTC") ${color}$(printf "[%9s]" ${1})${color_reset}";
}
function emergency () {                             echo "$(_fmt emergency) ${@}" 1>&2 || true; exit 1; }
function alert ()     { [ "${LOG_LEVEL}" -ge 1 ] && echo "$(_fmt alert) ${@}" 1>&2 || true; }
function critical ()  { [ "${LOG_LEVEL}" -ge 2 ] && echo "$(_fmt critical) ${@}" 1>&2 || true; }
function error ()     { [ "${LOG_LEVEL}" -ge 3 ] && echo "$(_fmt error) ${@}" 1>&2 || true; }
function warning ()   { [ "${LOG_LEVEL}" -ge 4 ] && echo "$(_fmt warning) ${@}" 1>&2 || true; }
function notice ()    { [ "${LOG_LEVEL}" -ge 5 ] && echo "$(_fmt notice) ${@}" 1>&2 || true; }
function info ()      { [ "${LOG_LEVEL}" -ge 6 ] && echo "$(_fmt info) ${@}" 1>&2 || true; }
function debug ()     { [ "${LOG_LEVEL}" -ge 7 ] && echo "$(_fmt debug) ${@}" 1>&2 || true; }

function help () {
  echo "" 1>&2
  echo " ${@}" 1>&2
  echo "" 1>&2
  echo "  ${usage}" 1>&2
  echo "" 1>&2
  exit 1
}

function cleanup_before_exit () {
  info "Cleaning up. Done"
}
trap cleanup_before_exit EXIT

install_binaries()
{
  if [ ! -f strategoxt-superbundle-0.17-macosx.tar.gz ]; then
    info "Downloading strategoxt-superbundle-0.17-macosx.tar.gz "
    wget http://ftp.strategoxt.org/pub/stratego/StrategoXT/strategoxt-0.17/macosx/strategoxt-superbundle-0.17-macosx.tar.gz
    [  -f strategoxt-superbundle-0.17-macosx.tar.gz ] || critical "StrategoXT superbundle download failed"
  fi 
  info "Uncompressing strategoxt-superbundle-0.17-macosx.tar.gz " 
  tar xf strategoxt-superbundle-0.17-macosx.tar.gz 
  [  -d opt ] || critical "Decompression of StrategoXT tar ball failed"
  pushd opt
  [ -d "$arg_o" ] || mkdir -p $arg_o
  if [ -d "$arg_o/aterm" ]; then
    warning "An aterm installation exists in the installation path $arg_o/aterm. Please remove it if you want to replace it."
  else
    mv aterm $arg_o
  fi
  if [ -d "$arg_o/sdf2-bundle" ]; then
    warning "An sdf2-bundle installation exists in the installation path $arg_o/sdf2-bundle.  Please remove it if you want to replace it."
  else
    mv sdf2-bundle $arg_o
  fi
  if [ -d "$arg_o/strategoxt" ]; then
    warning "A strategoxt installation exists in the installation path $arg_o/strategoxt.  Please remove it if you want to replace it."
  else
    mv strategoxt $arg_o
  fi
  popd
}


### Parse commandline options
#####################################################################

# Translate usage string -> getopts arguments, and set $arg_<flag> defaults
while read line; do
  # fetch single character version of option string
  opt="$(echo "${line}" |awk '{print $1}' |sed -e 's#^-##')"

  # fetch long version if present
  long_opt="$(echo "${line}" |awk '/\-\-/ {print $2}' |sed -e 's#^--##')"
  long_opt_mangled="$(sed 's#-#_#g' <<< $long_opt)"

  # map long name back to short name
  varname="short_opt_${long_opt_mangled}"
  eval "${varname}=\"${opt}\""

  # check if option takes an argument
  varname="has_arg_${opt}"
  if ! echo "${line}" |egrep '\[.*\]' >/dev/null 2>&1; then
    init="0" # it's a flag. init with 0
    eval "${varname}=0"
  else
    opt="${opt}:" # add : if opt has arg
    init=""  # it has an arg. init with ""
    eval "${varname}=1"
  fi
  opts="${opts:-}${opt}"

  varname="arg_${opt:0:1}"
  if ! echo "${line}" |egrep '\. Default=' >/dev/null 2>&1; then
    eval "${varname}=\"${init}\""
  else
    match="$(echo "${line}" |sed 's#^.*Default=\(\)#\1#g')"
    eval "${varname}=\"${match}\""
  fi
done <<< "${usage}"

# Allow long options like --this
opts="${opts}-:"

# Reset in case getopts has been used previously in the shell.
OPTIND=1

# start parsing command line
set +o nounset # unexpected arguments will cause unbound variables
               # to be dereferenced
# Overwrite $arg_<flag> defaults with the actual CLI options
while getopts "${opts}" opt; do
  [ "${opt}" = "?" ] && help "Invalid use of script: ${@} "

  if [ "${opt}" = "-" ]; then
    # OPTARG is long-option-name or long-option=value
    if [[ "${OPTARG}" =~ .*=.* ]]; then
      # --key=value format
      long=${OPTARG/=*/}
      long_mangled="$(sed 's#-#_#g' <<< $long)"
      # Set opt to the short option corresponding to the long option
      eval "opt=\"\${short_opt_${long_mangled}}\""
      OPTARG=${OPTARG#*=}
    else
      # --key value format
      # Map long name to short version of option
      long_mangled="$(sed 's#-#_#g' <<< $OPTARG)"
      eval "opt=\"\${short_opt_${long_mangled}}\""
      # Only assign OPTARG if option takes an argument
      eval "OPTARG=\"\${@:OPTIND:\${has_arg_${opt}}}\""
      # shift over the argument if argument is expected
      ((OPTIND+=has_arg_${opt}))
    fi
    # we have set opt/OPTARG to the short value and the argument as OPTARG if it exists
  fi
  varname="arg_${opt:0:1}"
  default="${!varname}"

  value="${OPTARG}"
  if [ -z "${OPTARG}" ] && [ "${default}" = "0" ]; then
    value="1"
  fi

  eval "${varname}=\"${value}\""
  debug "cli arg ${varname} = ($default) -> ${!varname}"
done
set -o nounset # no more unbound variable references expected

shift $((OPTIND-1))

[ "${1:-}" = "--" ] && shift


### Switches (like -d for debugmode, -h for showing helppage)
#####################################################################

# debug mode
if [ "${arg_d}" = "1" ]; then
  set -o xtrace
  LOG_LEVEL="7"
fi

# verbose mode
if [ "${arg_v}" = "1" ]; then
  set -o verbose
fi

# help mode
if [ "${arg_h}" = "1" ]; then
  # Help exists with code 1
  help "Help using ${0}"
fi


### Validation (decide what's required for running your script and error out)
#####################################################################

[ -z "${LOG_LEVEL:-}" ] && emergency "Cannot continue without LOG_LEVEL. "

### Runtime
#####################################################################

info "__file: ${__file}"
info "__dir: ${__dir}"
info "__base: ${__base}"
info "__os: ${__os}"

info "arg_d: ${arg_d}"
info "arg_v: ${arg_v}"
info "arg_h: ${arg_h}"
info "arg_o: ${arg_o}"

install_binaries

# Download and uncompress the ofp-sdf tar ball
info "Downloading Open Fortran Parser (OFP) source tar ball: ofp-sdf.tar.bz2."
wget https://dl.dropboxusercontent.com/u/7038972/ofp-sdf.tar.bz2
[ -f ofp-sdf.tar.bz2 ] || critical "Download of OFP succeeded."
info "Uncompressing ofp-sdf."
tar xf ofp-sdf.tar.bz2 
[ -d "ofp-sdf" ] || critical "Uncompressing OFP source tar ball succeeded."
  
# Build OFP
info "Building parse table"
pushd ofp-sdf/fortran/syntax
make
popd
pushd ofp-sdf/fortran/trans
make
popd
