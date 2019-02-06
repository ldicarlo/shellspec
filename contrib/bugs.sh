#!/bin/sh

# Bugs and compatibility check for shell

# This script is for development purposes.
# It provide as is, do not any support.
# It may change without notice.

# Example of use
#   contrib/bugs.sh
#   bash contrib/bugs.sh

affect() {      echo "[affect] $title"; }
no_problem()  { echo "[------] $title"; }

(
  title="01: set -e option is reset (posh)"
  set -eu
  foo() { eval 'return 0'; }
  foo
  case $- in
    *e*) no_problem ;;
    *) affect ;;
  esac
)

(
  title="02: double quoted string treated as a pattern (posh)"
  string="abc[d]"
  pattern="c[d]"
  case $string in
    *"$pattern"*) no_problem ;;
    *) affect ;;
  esac
)

(
  title="03: @: parameter not set (posh, ksh <= around 93s)"
  if (set -u; : "$@") 2>/dev/null; then no_problem; else affect; fi
)

return_true() { false; }
(
  title="04: function not overrite (ksh)"
  return_true() { true; }
  if return_true; then no_problem; else affect; fi
)

(
  title="05: exit not return exit code (zsh <= around 4.2.5)"
  foo() { (exit 123) &&:; }; foo
  if [ $? -eq 123 ]; then no_problem; else affect; fi
)

(
  title="06: abort if unset not the defined variable (bash <= around 2.05a, zsh <= around 4.2.5, ksh <= around 93s)"
  ok=$(
    set -e
    unset not_defined_variable
    echo 1
  )
  if [ "$ok" ]; then no_problem; else affect; fi
)

(
  title="07: limited arithmetic expansion (dash <= around 0.5.4, old ash)"
  i=0
  ok=$(eval 'i=$((i+1))' 2>/dev/null; echo 1)
  if [ "$ok" ]; then no_problem; else affect; fi
)

(
  title="08: Unsupported trap (posh: around 0.8.5)"
  if (trap '' INT) 2>/dev/null; then no_problem; else affect; fi
)

(
  title="09: different split by IFS (zsh, posh <= around 0.6.13)"
  [ "${ZSH_VERSION:-}" ] && emulate -R sh
  string="1,2,"
  IFS=','
  set -- $string
  if [ $# -eq 2 ]; then no_problem; else affect; fi
)

(
  title="10: variable reference in the same line (dash <= around 0.5.5)"
  i=1
  i=$(($i+1)) j=$i
  if [ "$j" -eq 2 ]; then no_problem; else affect; fi
)

(
  title="11: command time -p output LF at first (solaris)"
  command time -p printf '' 2>&1 | {
    IFS= read -r line
    if [ "$line" ]; then no_problem; else affect; fi
  }
)

echo Done