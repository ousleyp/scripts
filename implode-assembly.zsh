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
      local include_target resolved_path
      include_target=$(echo "$line" | sed -nE 's/.*include::([^\[]+\.adoc).*/\1/p')
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
  local output_file="$2"
  local label="$3"

  local -a included_modules
  local -a included_snippets
  local comment_lines=$(echo "$ai_comment_block" | wc -l | tr -d ' ')

  local temp_content temp_final
  temp_content=$(mktemp)
  temp_final=$(mktemp)

  while IFS= read -r line || [[ -n "$line" ]]; do
    echo "$line" >> "$temp_content"

    if echo "$line" | grep -q 'include::modules/.*\.adoc'; then
      local module_path resolved_path
      module_path=$(echo "$line" | sed -nE 's/.*include::(modules\/[^[]+\.adoc).*/\1/p')
      [[ -n "$module_path" ]] && included_modules+=("$module_path")
      resolved_path="${input_file:h}/$module_path"

      if [[ -f "$resolved_path" ]]; then
        echo "// BEGIN inlined: $module_path" >> "$temp_content"
        inline_file_recursively "$resolved_path" >> "$temp_content"
        echo "// END inlined: $module_path" >> "$temp_content"
      else
        echo "// WARNING: missing module $module_path" >> "$temp_content"
      fi

    elif echo "$line" | grep -q 'include::snippets/.*\.adoc'; then
      local snippet_path resolved_path
      snippet_path=$(echo "$line" | sed -nE 's/.*include::(snippets\/[^[]+\.adoc).*/\1/p')
      [[ -n "$snippet_path" ]] && included_snippets+=("$snippet_path")
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

  # Prepend comment block
  echo "$ai_comment_block" > "$temp_final"
  echo "" >> "$temp_final"
  cat "$temp_content" >> "$temp_final"

  mv "$temp_final" "$output_file"
  rm "$temp_content"

  # Line count (excluding comment)
  local line_count=$(tail -n +$((comment_lines + 2)) "$output_file" | wc -l | tr -d ' ')

  # Pretty terminal output
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Imploded:       $output_file"
  echo " Source:         $label"
  echo " Modules:        ${#included_modules[@]}"
  for m in "${(@)included_modules}"; do echo "   • $m"; done
  echo " Snippets:       ${#included_snippets[@]}"
  for s in "${(@)included_snippets}"; do echo "   • $s"; done
  echo " Line count:     $line_count"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

# MAIN
for arg in "$@"; do
  if [[ -f "$arg" && "$arg" == *.adoc ]]; then
    local abs_path out_path
    abs_path="$(cd "${arg:h}" && pwd)/${arg:t}"
    out_path="$output_root/imploded-${arg:t}"
    implode_file "$abs_path" "$out_path" "$arg"
  elif [[ -d "$arg" ]]; then
    echo "[INFO] Directory input not yet implemented in this version"
  else
    echo "Skipping unrecognized argument: $arg"
  fi
done

