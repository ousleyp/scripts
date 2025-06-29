#!/bin/zsh

setopt extended_glob

output_root="$HOME/imploded_assemblies"
mkdir -p "$output_root"

ai_comment_block='// This file contains a fully expanded version of an OpenShift documentation *assembly* written in AsciiDoc.
// It is not valid AsciiDoc for publishing, because it includes both the original `include::` statements
// and the full contents of the referenced *module* or *snippet* files placed immediately underneath each include.
// Includes that reference `_attributes/` files remain untouched, as attribute files are not inlined.
// The purpose of this imploded version is to expose the raw AsciiDoc used throughout the document
// so that AI tools can analyze document structure, content organization, and AsciiDoc conventions
// without needing to resolve external files.'

# Recursively inline modules and snippets
inline_file_recursively() {
  local file_path="$1"
  local file_dir="${file_path:h}"

  while IFS= read -r line || [[ -n "$line" ]]; do
    if echo "$line" | grep -q 'include::.*\.adoc'; then
      include_target="$(echo "$line" | sed -nE 's/.*include::([^\[]+\.adoc).*/\1/p')"
      resolved_path="$file_dir/$include_target"

      if [[ "$include_target" == */_attributes/* ]]; then
        echo "$line"
      elif [[ -f "$resolved_path" ]]; then
        echo "// BEGIN inlined: $include_target"
        inline_file_recursively "$resolved_path"
        echo "// END inlined: $include_target"
      else
        echo "// WARNING: could not resolve $include_target"
      fi
    else
      echo "$line"
    fi
  done < "$file_path"
}

implode_file() {
  local input_file="$1"
  local label="$2"

  local -a included_modules
  local -a included_snippets

  local temp_content temp_final
  temp_content=$(mktemp)
  temp_final=$(mktemp)

  # Metadata info
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  local git_branch
  git_branch="$(git -C "${input_file:h}" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  git_branch="${git_branch:-not-in-git}"

  local base_name="${input_file:t:r}"
  local output_file=""
  local counter=1
  while true; do
    output_file="$output_root/${base_name}_${git_branch}_v${counter}.adoc"
    [[ ! -e "$output_file" ]] && break
    ((counter++))
  done

  echo "// Imploded on: $timestamp" >> "$temp_content"
  echo "// Git branch:  $git_branch" >> "$temp_content"
  echo "" >> "$temp_content"

  while IFS= read -r line || [[ -n "$line" ]]; do
    echo "$line" >> "$temp_content"

    if echo "$line" | grep -q 'include::modules/.*\.adoc'; then
      module_path="$(echo "$line" | sed -nE 's/.*include::(modules\/[^\[]+\.adoc).*/\1/p')"
      [[ -n "$module_path" ]] && included_modules+="$module_path"
      resolved_path="${input_file:h}/$module_path"

      if [[ -f "$resolved_path" ]]; then
        echo "// BEGIN inlined: $module_path" >> "$temp_content"
        inline_file_recursively "$resolved_path" >> "$temp_content"
        echo "// END inlined: $module_path" >> "$temp_content"
      else
        echo "// WARNING: missing module $module_path" >> "$temp_content"
      fi

    elif echo "$line" | grep -q 'include::snippets/.*\.adoc'; then
      snippet_path="$(echo "$line" | sed -nE 's/.*include::(snippets\/[^\[]+\.adoc).*/\1/p')"
      [[ -n "$snippet_path" ]] && included_snippets+="$snippet_path"
      resolved_path="${input_file:h}/$snippet_path"

      if [[ -f "$resolved_path" ]]; then
        echo "// BEGIN inlined: $snippet_path" >> "$temp_content"
        inline_file_recursively "$resolved_path" >> "$temp_content"
        echo "// END inlined: $snippet_path" >> "$temp_content"
      else
        echo "// WARNING: missing snippet $snippet_path" >> "$temp_content"
      fi
    fi
  done < "$input_file"

  echo "$ai_comment_block" > "$temp_final"
  echo "" >> "$temp_final"
  cat "$temp_content" >> "$temp_final"

  mv "$temp_final" "$output_file"
  rm "$temp_content"

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Imploded:       $output_file"
  echo " Source:         $label"
  echo " Timestamp:      $timestamp"
  echo " Git branch:     $git_branch"
  echo " Modules:        ${#included_modules[@]}"
  for m in "${(@)included_modules}"; do echo "   • $m"; done
  echo " Snippets:       ${#included_snippets[@]}"
  for s in "${(@)included_snippets}"; do echo "   • $s"; done
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

# MAIN
if [[ "$#" -eq 0 ]]; then
  echo "Usage: $0 <assembly.adoc> [more_files...]"
  exit 1
fi

for arg in "$@"; do
  if [[ -f "$arg" && "$arg" == *.adoc ]]; then
    abs_path="$(cd "${arg:h}" && pwd)/${arg:t}"
    implode_file "$abs_path" "$arg"
  elif [[ -d "$arg" ]]; then
    echo "[INFO] Directory input not yet implemented in this version"
  else
    echo "Skipping unrecognized argument: $arg"
  fi
done
