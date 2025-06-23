#!/usr/bin/env bash

output_root="$HOME/imploded_assemblies"
mkdir -p "$output_root"
suppress_output=false

declare -a args=()
for arg in "$@"; do
  case "$arg" in
    -q|--quiet) suppress_output=true ;;
    *) args+=("$arg") ;;
  esac
done

declare -A attributes
declare -a MODULE_LIST=()
declare -a ASSEMBLY_STACK=()

# Gather all attributes defined in a file
parse_defined_attributes() {
  local file="$1"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^:([a-zA-Z0-9_-]+):[[:space:]]+(.*)$ ]] &&
      attributes["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
  done < "$file"
}

# Gather all attributes used in a file
gather_used_attributes() {
  local file="$1"
  grep -oE '\{[a-zA-Z0-9_-]+\}' "$file" | tr -d '{}' | sort | uniq
}

# Parse only needed attributes from a file
parse_needed_attributes() {
  local file="$1"; shift
  local needed=("$@")
  for attr in "${needed[@]}"; do
    local val
    val=$(grep "^:$attr:" "$file" | cut -d':' -f3- | xargs)
    [[ -n "$val" ]] && attributes["$attr"]="$val"
  done
}

# Inline file recursively
inline_file_recursively() {
  local file_path="$1"
  local depth="$2"
  local file_dir="$(dirname "$file_path")"
  ASSEMBLY_STACK+=("$file_path")

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Handle ifeval blocks
    if [[ "$line" =~ ^ifeval::\[\"{parent-context}\"[[:space:]]*==[[:space:]]*\"$parent_context\" ]]; then
      # Match this include
      read -r include_line
      if [[ "$include_line" =~ include::([^\[]+)\[.* ]]; then
        target_line="${BASH_REMATCH[1]}"
        for attr in "${!attributes[@]}"; do
          target_line="${target_line//\{$attr\}/${attributes[$attr]}}"
        done
        local resolved_path="$file_dir/$target_line"
        MODULE_LIST+=("${ASSEMBLY_STACK[-1]}|$depth|$target_line")
        echo "$(printf '    %.0s' $(seq 1 $depth))// BEGIN conditional module: $target_line"
        inline_file_recursively "$resolved_path" "$depth"
        echo "$(printf '    %.0s' $(seq 1 $depth))// END conditional module: $target_line"
      fi
      # Skip to endif
      while IFS= read -r skip_line && [[ ! "$skip_line" =~ ^endif:: ]]; do :; done
      continue
    elif [[ "$line" =~ ^ifeval:: ]]; then
      # Skip entire conditional block
      while IFS= read -r skip_line && [[ ! "$skip_line" =~ ^endif:: ]]; do :; done
      continue
    fi

    # Handle includes
    if [[ "$line" =~ include::([^\[]+\.adoc) ]]; then
      local include_target="${BASH_REMATCH[1]}"
      for attr in "${!attributes[@]}"; do
        include_target="${include_target//\{$attr\}/${attributes[$attr]}}"
      done
      local resolved_path="$file_dir/$include_target"

      case "$include_target" in
        *common/id.adoc|*common/begin-nested-context.adoc|*common/end-nested-context.adoc)
          echo "$(printf '    %.0s' $(seq 1 $depth))$line"
          continue ;;
      esac

      if [[ "$(basename "$include_target")" == "common.adoc" ]]; then
        parse_defined_attributes "$resolved_path"
        echo "$(printf '    %.0s' $(seq 1 $depth))$line"
      elif [[ "$include_target" == */_attributes/* ]]; then
        echo "$(printf '    %.0s' $(seq 1 $depth))$line"
      elif [[ -f "$resolved_path" ]]; then
        if [[ "$include_target" == modules/* || "$include_target" == snippets/* ]]; then
          MODULE_LIST+=("${ASSEMBLY_STACK[-1]}|$depth|$include_target")
          echo "$(printf '    %.0s' $(seq 1 $depth))// BEGIN inlined: $include_target"
          inline_file_recursively "$resolved_path" "$depth"
          echo "$(printf '    %.0s' $(seq 1 $depth))// END inlined: $include_target"
        else
          MODULE_LIST+=("${ASSEMBLY_STACK[-1]}|$depth|NESTED $include_target")
          echo "$(printf '    %.0s' $(seq 1 $depth))// BEGIN inlined nested assembly: $include_target"
          inline_file_recursively "$resolved_path" $((depth+1))
          echo "$(printf '    %.0s' $(seq 1 $depth))// END inlined nested assembly: $include_target"
        fi
      else
        echo "$(printf '    %.0s' $(seq 1 $depth))// WARNING: could not resolve $include_target"
      fi
    else
      echo "$(printf '    %.0s' $(seq 1 $depth))$line"
    fi
  done < "$file_path"

  unset 'ASSEMBLY_STACK[-1]'
}

# Print module list
print_module_list() {
  if [[ ${#MODULE_LIST[@]} -eq 0 ]]; then
    echo "No modules found."
    return
  fi
  echo "Modules found:"
  declare -A seen
  for entry in "${MODULE_LIST[@]}"; do
    IFS='|' read -r parent depth target <<<"$entry"
    [[ -n "${seen[$parent-$target]}" ]] && continue
    seen[$parent-$target]=1
    if [[ "$target" == *common/* ]]; then continue; fi
    local indent="$(printf '    %.0s' $(seq 1 $depth))"
    if [[ "$target" == NESTED* ]]; then
      target="${target#NESTED }"
      echo "${indent}Nested assembly: $target"
    else
      echo "${indent}↳ $target"
    fi
  done
}

# Main
if [[ ${#args[@]} -eq 0 ]]; then
  echo "Usage: $0 [--quiet|-q] <assembly.adoc> [directories...]"
  exit 1
fi

for arg in "${args[@]}"; do
  if [[ -f "$arg" && "$arg" == *.adoc ]]; then
    used_attrs=$(gather_used_attributes "$arg")
    parse_defined_attributes "$arg"
    [[ -f common.adoc ]] && parse_defined_attributes "common.adoc"
    attributes_files=($(grep -oE 'include::attributes/[^[]+' "$arg" | cut -d':' -f2))
    for attr_file in "${attributes_files[@]}"; do
      [[ -f "$attr_file" ]] && parse_needed_attributes "$attr_file" $used_attrs
    done
    parent_context=$(grep '^:context:' "$arg" | cut -d':' -f3- | xargs)

    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    git_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo not-in-git)"
    base_name="$(basename "$arg" .adoc)"
    rel_path="${arg%/*}"
    output_subdir="$output_root/$rel_path"
    mkdir -p "$output_subdir"

    counter=1
    while true; do
      output_file="$output_subdir/${base_name}_${git_branch}_v${counter}.txt"
      [[ ! -e "$output_file" ]] && break
      ((counter++))
    done

    temp_content=$(mktemp)
    temp_final=$(mktemp)
    {
      echo "// Imploded on: $timestamp"
      echo "// Git branch: $git_branch"
      inline_file_recursively "$arg" 0
    } > "$temp_content"
    {
      echo "// Fully expanded assembly"
      echo ""
      cat "$temp_content"
    } > "$temp_final"
    mv "$temp_final" "$output_file"
    rm "$temp_content"

    if [[ "$suppress_output" == false ]]; then
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo " Imploded:       $output_file"
      echo " Source:         $arg"
      echo " Timestamp:      $timestamp"
      echo " Git branch:     $git_branch"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      print_module_list
    else
      if [[ "$quiet_header_shown" != true ]]; then
        echo "Generated files:"
        quiet_header_shown=true
      fi
      echo "$output_file"
    fi

    MODULE_LIST=()
  elif [[ -d "$arg" ]]; then
    mkdir -p "$output_root/$arg"
    find "$arg" -type f -name '*.adoc' | while read -r file; do
      "$0" "$file"
    done
  else
    echo "Skipping unrecognized argument: $arg"
  fi
done
