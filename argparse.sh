#!/bin/bash
#
# Copyright 2022 Jonathan Schultz
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
set -e

# help='Generic description.'
# args=(
# "-short:--long:variable:default:required:description:flags"
# )

######################## START OF ARGUMENT PARSING CODE ########################

argshort=()
arglong=()
argvar=()
argdefault=()
argdesc=()
argflags=()

argn=${#args[@]}
for ((argidx=0; argidx<argn; argidx++)) do
    argstring=${args[argidx]}
    IFS=':' read -r -a arg <<< "${argstring}"
    argshort+=("${arg[0]}")
    arglong+=("${arg[1]}")
    if [[ -n "${arg[2]}" ]]; then 
        argvar+=("${arg[2]}")
    else
        var=${arg[1]}
        if [[ "${var:0:2}" == "--" ]]; then
            var="${var:2}"
        fi
        argvar+=("${var//[^a-zA-Z_0-9]/_}")
    fi
    argdefault+=("${arg[3]}")
    argdesc+=("${arg[4]}")
    argflags+=("${arg[5]}")
done
while (( "$#" )); do
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo ${help} | fold --width=$(tput cols) --spaces
        echo "    -h, --help - Display this usage information" | fold --width=$(tput cols) --spaces
        for ((argidx=0; argidx<argn; argidx++)) do
            IFS=',' read -r -a flags <<< "${argflags[argidx]}"
            LINE="    "
            if [[ -n "${argshort[argidx]}" ]]; then
                LINE+="${argshort[argidx]}"
            fi
            if [[ -n "${arglong[argidx]}" ]]; then
                if [[ -n "${argshort[argidx]}" ]]; then
                    LINE+=", "
                fi
                LINE+="${arglong[argidx]}"
            fi
            if [[ -n "${argdefault[argidx]}" ]]; then
                LINE+=" (default: ${argdefault[argidx]})"
            fi
            if [[ "${flags[*]}" =~ "required" ]]; then
                LINE+=" (required)"
            fi
            if [[ "${flags[*]}" =~ "deprecated" ]]; then
                LINE+=" (deprecated)"
            fi
            if [[ -n "${argdesc[argidx]}" ]]; then
                LINE+=" - ${argdesc[argidx]}"
            fi
            echo "$LINE" | fold --width=$(tput cols) --spaces
        done
        exit 0
    fi
    
    for ((argidx=0; argidx<argn; argidx++)) do
        IFS=',' read -r -a flags <<< "${argflags[argidx]}"
        if [[ "${argshort[argidx]:0:1}" == "-" || "${arglong[argidx]:0:1}" == "-" ]]; then
            if [[ "$1" == "${argshort[argidx]}" || "$1" == "${arglong[argidx]}" ]]; then
                if  [[ ! "${flags[*]}" =~ "flag" ]]; then
                    if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
                        eval "${argvar[argidx]}=\"$2\""
                        shift 2
                    else
                        echo "Error: Value for '${arglong[argidx]}' is missing" >&2
                        exit 1
                    fi
                else
                    eval "${argvar[argidx]}='true'"
                    shift
                fi
                break
            fi
        # Positional argument
        elif [[ "${1:0:1}" != "-" && ! -n "${!argvar[argidx]}" ]]; then
            eval "${argvar[argidx]}=\"$1\""
            shift
            break
        fi
    done
    if [[ ${argidx} == ${argn} ]]; then
        echo "Error: Unrecognised argument: $1" >&2
        exit 1
    fi
done

for ((argidx=0; argidx<argn; argidx++)) do
    IFS=',' read -r -a flags <<< "${argflags[argidx]}"
    if [[ -n "${!argvar[argidx]}" ]]; then
        if [[ "${flags[*]}" =~ "deprecated" ]]; then
            echo "WARNING: Argument '${arglong[argidx]}' is deprecated" >&2
        fi
    else
        if [[ -n "${argdefault[argidx]}" ]]; then
            eval "${argvar[argidx]}=\"${argdefault[argidx]}\""
        elif [[ "${flags[*]}" =~ "required" ]]; then
            echo "Missing argument '${arglong[argidx]}'" >&2
            exit 1
        fi
    fi
done

COMMENTS_SEPARATOR=$'################################################################################\n'
COMMENTS=$COMMENTS_SEPARATOR
COMMENTS+="# $(basename $0)"
COMMENTS+=$'\n'
for ((argidx=0; argidx<argn; argidx++)) do
    IFS=',' read -r -a flags <<< "${argflags[argidx]}"

    if [[ ! "${flags[*]}" =~ "private" ]] && [[ -n "${!argvar[argidx]}" ]]; then
        PREFIX="#"
        if [[ "${flags[*]}" =~ "input" ]]; then
            PREFIX+="<   "
        elif [[ "${flags[*]}" =~ "output" ]]; then
            PREFIX+=">   "
        else
            PREFIX+="    "
        fi
        ARGSPEC="${arglong[argidx]:-${argshort[argidx]}} "
        if [ ${ARGSPEC:0:1} != "-" ]; then
            ARGSPEC=""
        fi
        if [[ ! "${flags[*]}" =~ "flag" ]]; then
            ARGVAR="\"${!argvar[argidx]}\""
        else
            ARGVAR=""
        fi
        LINE="${PREFIX}${ARGSPEC}${ARGVAR}"
        COMMENTS+="${LINE}"
        COMMENTS+=$'\n'
    fi
done

######################### END OF ARGUMENT PARSING CODE #########################

# echo "${COMMENTS}" > ${filename%.*}.log
