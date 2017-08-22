#!/usr/bin/env bash

function main() {

  if [[ ! "$1" || "$1" == "-h" || "$1" == "--help" ]]; then cat <<HELP
Simple monorepo lifecycle/pipeline tool for running one or more commands on one
or more directories that have changes compared to a branch point.

Takes two arguments, <glob> <commands>. The commands are invoked from each
directory context matching the glob. Uses git's pathsepc for globs. The glob
must wrapped in quotes to keep Bash from expanding it.

Assumes integration branch is 'master' and uses 'git merge-base --fork-point' to
determine comparison for what directories have changed.

Usage:
  lolaus "./tests/* :(top,exclude)**requirements.txt" ls
  lolaus "**" pwd
  lolaus "*/*/package.json" npm test & lolaus "*/*/requirements.txt" python test.py

HELP
  return; fi

  local GLOB=$1
  local BRANCH_NAME=$(git symbolic-ref --short HEAD)
  local INTEGRATION=master
  local DIFF_POINT=$(git merge-base --fork-point $INTEGRATION $BRANCH_NAME)
  local GIT_DIFF=$(git diff --name-only $DIFF_POINT..$BRANCH_NAME -- $GLOB)
  local dirs=($(dirname $GIT_DIFF))

  # ditch glob from args
  shift

  # following output formatting from https://github.com/Kikobeats/eachdir/

  # For underlining headers.
  local underline
  local _underline
  underline="$(tput smul)"
  _underline="$(tput rmul)"


  local nops=()
  # Do stuff for each specified dir, in each dir. Non-dirs are ignored.
  for d in "${dirs[@]}"; do
    # Skip non-dirs.
    [[ ! -d "$d" ]] && continue
    # If the dir isn't /, strip the trailing /.
    [[ "$d" != "/" ]] && d="${d%/}"
    # Execute the command, grabbing all stdout and stderr.
    output="$( (cd "$d"; eval "$@") 2>&1 )"
    if [[ "$output" ]]; then
      # If the command had output, display a header and that output.
      echo -e "${underline}${d}${_underline}\n$output\n"
    else
      # Otherwise push it onto an array for later display.
      nops=("${nops[@]}" "$d")
    fi
  done

  # List any dirs that had no output.
  if [[ ${#nops[@]} -gt 0 ]]; then
    echo "${underline}no output from${_underline}"
    for d in "${nops[@]}"; do echo "$d"; done
  fi


}

main "$@"