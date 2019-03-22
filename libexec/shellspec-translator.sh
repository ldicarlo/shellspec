#!/bin/sh
#shellcheck disable=SC2004,SC2016

set -eu

# shellcheck source=lib/general.sh
. "${SHELLSPEC_LIB:-./lib}/general.sh"
# shellcheck source=lib/libexec/translator.sh
. "${SHELLSPEC_LIB:-./lib}/libexec/translator.sh"

example_count=0 block_no=0 block_no_stack='' skip_id=0

ABORT=''
abort() { ABORT=$*; }

block_example_group() {
  if [ "$inside_of_example" ]; then
    abort "Describe/Context cannot be defined inside of Example"
    return 0
  fi

  increasese_id
  block_no=$(($block_no + 1))
  putsn "(" \
    "SHELLSPEC_BLOCK_NO=$block_no" \
    "SHELLSPEC_SPECFILE=\"$specfile\"" "SHELLSPEC_ID=$id" \
    "SHELLSPEC_LINENO_BEGIN=$lineno"
  putsn "shellspec_block${block_no}() { shellspec_example_group $1"
  putsn "}; shellspec_yield${block_no}() { :;"
  block_no_stack="$block_no_stack $block_no"
}

block_example() {
  if [ "$inside_of_example" ]; then
    abort "Example/Todo cannot be defined inside of Example"
    return 0
  fi

  increasese_id
  block_no=$(($block_no + 1)) example_count=$(($example_count + 1))
  putsn "(" \
    "SHELLSPEC_BLOCK_NO=$block_no" \
    "SHELLSPEC_SPECFILE=\"$specfile\"" "SHELLSPEC_ID=$id" \
    "SHELLSPEC_EXAMPLE_NO=$example_count" \
    "SHELLSPEC_LINENO_BEGIN=$lineno"
  putsn "shellspec_block${block_no}() { shellspec_example $1"
  putsn "}; shellspec_yield${block_no}() { :;"
  block_no_stack="$block_no_stack $block_no"
  inside_of_example="yes"
}

block_end() {
  if [ -z "$block_no_stack" ]; then
    abort "unexpected 'End'"
    return 0
  fi

  decrease_id
  if [ "$ABORT" ]; then
    putsn "}; SHELLSPEC_LINENO_END="
  else
    putsn "}; SHELLSPEC_LINENO_END=$lineno"
  fi
  putsn "shellspec_block${block_no_stack##* }) ${1# }"
  block_no_stack="${block_no_stack% *}"
  inside_of_example=""
}

x() { "$@"; skip; }

todo() {
  block_example "$1"
  block_end ""
}

statement() {
  if [ -z "$inside_of_example" ]; then
    abort "When/The/It cannot be defined outside of Example"
    return 0
  fi

  putsn "SHELLSPEC_SPECFILE=\"$specfile\" SHELLSPEC_LINENO=$lineno"
  putsn "shellspec_statement $1$2"
}

control() {
  case $1 in (before|after)
    if [ "$inside_of_example" ]; then
      abort "Before/After cannot be defined inside of Example"
      return 0
    fi
  esac
  putsn "shellspec_$1$2"
}

skip() {
  skip_id=$(($skip_id + 1))
  putsn "shellspec_skip ${skip_id}${1:-}"
}

data() {
  data_line=${2:-}
  trim data_line
  now=$(unixtime)
  delimiter="DATA${now}$$"

  putsn "shellspec_data() {"
  case $data_line in
    '' | '#'* | '|'*)
      case $1 in
        expand) putsn "shellspec_passthrough<<$delimiter $data_line" ;;
        raw)    putsn "shellspec_passthrough<<'$delimiter' $data_line" ;;
      esac
      while IFS= read -r line || [ "$line" ]; do
        lineno=$(($lineno + 1))
        trim line
        case $line in
          '#|'*) putsn "${line#??}" ;;
          '#'*) ;;
          End | End\ * ) break ;;
          *) abort "Data texts should begin with '#|'"
            break ;;
        esac
      done
      putsn "$delimiter"
      ;;
    "'"* | '"'*) putsn "  shellspec_putsn $data_line" ;;
    *) putsn "  $data_line" ;;
  esac
  putsn "}"
  putsn "SHELLSPEC_DATA=1"
}

text_begin() {
  now=$(unixtime)
  delimiter="DATA${now}$$"

  case $1 in
    expand) putsn "shellspec_passthrough<<$delimiter ${2}" ;;
    raw)    putsn "shellspec_passthrough<<'$delimiter' ${2}" ;;
  esac
  inside_of_text=1
}

text() {
  case $1 in ('#|'*) putsn "${1#??}"; return 0; esac
  text_end
  return 1
}

text_end() {
  putsn "$delimiter"
  inside_of_text=''
}

syntax_error() {
  putsn "shellspec_exit 2 \"Syntax error: ${*:-} in $specfile line $lineno\""
}

translate() {
  initialize_id
  lineno=0 inside_of_example='' inside_of_text=''
  while IFS= read -r line || [ "$line" ]; do
    lineno=$(($lineno + 1)) work=$line
    trim work

    [ "$inside_of_text" ] && text "$work" && continue

    dsl=${work%% *}
    case $dsl in
      Describe )   block_example_group "${work#$dsl}" ;;
      xDescribe) x block_example_group "${work#$dsl}" ;;
      Context  )   block_example_group "${work#$dsl}" ;;
      xContext ) x block_example_group "${work#$dsl}" ;;
      Example  )   block_example       "${work#$dsl}" ;;
      xExample ) x block_example       "${work#$dsl}" ;;
      Specify  )   block_example       "${work#$dsl}" ;;
      xSpecify ) x block_example       "${work#$dsl}" ;;
      End      )   block_end           "${work#$dsl}" ;;
      Todo     )   todo                "${work#$dsl}" ;;
      When     )   statement when      "${work#$dsl}" ;;
      The      )   statement the       "${work#$dsl}" ;;
      It       )   statement it        "${work#$dsl}" ;;
      Path     )   control path        "${work#$dsl}" ;;
      File     )   control path        "${work#$dsl}" ;;
      Dir      )   control path        "${work#$dsl}" ;;
      Before   )   control before      "${work#$dsl}" ;;
      After    )   control after       "${work#$dsl}" ;;
      Debug    )   control debug       "${work#$dsl}" ;;
      Pending  )   control pending     "${work#$dsl}" ;;
      Skip     )   skip                "${work#$dsl}" ;;
      Data     )   data expand         "${work#$dsl}" ;;
      Data:raw )   data raw            "${work#$dsl}" ;;
      %text    )   text_begin expand   "${work#$dsl}" ;;
      %text:raw)   text_begin raw      "${work#$dsl}" ;;
      *) putsn "$line" ;;
    esac
    if [ "$ABORT" ]; then break; fi
  done
}

is_specfile() {
  case $1 in (*_spec.sh) return 0; esac
  return 1
}

putsn ". \"\$SHELLSPEC_LIB/bootstrap.sh\""
putsn "shellspec_metadata"
each_file() {
  ! is_specfile "$1" && return 0
  specfile=$1
  escape_quote specfile
  putsn "SHELLSPEC_SPECFILE='$specfile'"

  putsn '('
  translate < "$specfile"
  [ "$ABORT" ] && syntax_error "$ABORT"
  if [ "$block_no_stack" ]; then
    [ "$ABORT" ] || syntax_error "unexpected end of file (expecting 'End')"
    while [ "$block_no_stack" ]; do
      putsn "shellspec_abort"
      block_end ""
    done
  fi
  putsn ')'
}
find_files each_file "$@"
putsn "SHELLSPEC_SPECFILE=\"\""
putsn "shellspec_end"
putsn "# example count: $example_count"

if [ "${SHELLSPEC_TRANS_LOG:-}" ]; then
  putsn "examples $example_count" >> "$SHELLSPEC_TRANS_LOG"
fi
