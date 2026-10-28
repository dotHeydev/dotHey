#!/usr/bin/env bash

physical() {
  (cd -P -- "$1" && pwd)
}

test_fs_resolve_follows_links_and_dot_segments() {
  local root
  root=$(physical "$SANDBOX")
  mkdir -p "$SANDBOX/a/b/c" "$SANDBOX/x/y"
  ln -s a/b "$SANDBOX/lb"
  ln -s ../x "$SANDBOX/a/b/c/up"
  ln -s lb "$SANDBOX/chain"
  core "cd '$SANDBOX'; dot::use framework.helpers.fs; framework.helpers.fs::resolve chain/./c//; framework.helpers.fs::resolve chain/c/up/../y; framework.helpers.fs::resolve missing/deep/../file"
  assert_success
  assert_equal "$OUTPUT" "$root/a/b/c
$root/a/b/y
$root/missing/file"
}

test_fs_resolve_detects_link_loops() {
  ln -s loop-a "$SANDBOX/loop-b"
  ln -s loop-b "$SANDBOX/loop-a"
  core "dot::use framework.helpers.fs; framework.helpers.fs::resolve '$SANDBOX/loop-a'"
  assert_failure
}

test_fs_relative_walks_up_and_down() {
  mkdir -p "$SANDBOX/a/b" "$SANDBOX/c"
  core "dot::use framework.helpers.fs; framework.helpers.fs::relative '$SANDBOX/c/file' '$SANDBOX/a/b'; framework.helpers.fs::relative '$SANDBOX/a' '$SANDBOX/a'; framework.helpers.fs::relative '$SANDBOX/a/b' '$SANDBOX'"
  assert_success
  assert_equal "$OUTPUT" "../../c/file
.
a/b"
}

test_fs_within_refuses_escapes() {
  ln -s / "$SANDBOX/root-link"
  core "dot::use framework.helpers.fs; framework.helpers.fs::within ../outside '$SANDBOX'"
  assert_failure
  core "dot::use framework.helpers.fs; framework.helpers.fs::within root-link/etc '$SANDBOX'"
  assert_failure
  core "dot::use framework.helpers.fs; framework.helpers.fs::within inside/file '$SANDBOX'"
  assert_success
  assert_equal "$OUTPUT" "$(physical "$SANDBOX")/inside/file"
}

test_text_slug_and_limit() {
  local limit=4
  core "dot::use framework.helpers.text; framework.helpers.text::slug '  Hello, World! '; printf '\n'; framework.helpers.text::slug 'abc def ghi' $limit"
  assert_success
  assert_equal "$OUTPUT" "hello-world
abc"
}

test_text_character_encodes_every_utf8_length() {
  local codepoint
  for codepoint in 65 233 8364 128512; do
    core "dot::use framework.helpers.text; framework.helpers.text::character $codepoint | od -An -tx1 | tr -d ' \n'"
    assert_success
    assert_equal "$OUTPUT" "$(LC_ALL=C.UTF-8 bash -c "printf '\\U%08x' $codepoint | xargs -0 printf '%b'" | od -An -tx1 | tr -d ' \n')"
  done
}

test_text_width_counts_wide_characters() {
  core "dot::use framework.helpers.text; framework.helpers.text::use_utf8_locale; framework.helpers.text::width \"\$(framework.helpers.text::character 128512)a\""
  assert_success
  assert_equal "$OUTPUT" "3"
}

test_kv_writes_reads_and_removes() {
  local file="$SANDBOX/settings.conf"
  printf '# comment\nexport FIRST="one"\nSECOND=two\n' > "$file"
  chmod 600 "$file"
  core "dot::use framework.helpers.kv; framework.helpers.kv::write '$file' SECOND changed; framework.helpers.kv::write '$file' THIRD three; framework.helpers.kv::remove '$file' FIRST; framework.helpers.kv::value '$file' SECOND; framework.helpers.kv::keys '$file'"
  assert_success
  assert_equal "$OUTPUT" "changed
SECOND
THIRD"
  assert_contains "$(cat "$file")" "# comment"
  assert_equal "$(ls -l "$file" | cut -c1-10)" "-rw-------"
}

test_kv_never_executes_values() {
  local file="$SANDBOX/settings.conf"
  printf 'KEY=$(touch %s/pwned)\n' "$SANDBOX" > "$file"
  core "dot::use framework.helpers.kv; framework.helpers.kv::value '$file' KEY"
  assert_success
  assert_no_file "$SANDBOX/pwned"
}

test_settings_come_from_the_project_then_the_defaults() {
  core "dot::setting tasks.service"
  assert_success
  assert_equal "$OUTPUT" "file"
  sandbox::settings '"tasks": {"service": "github"}, "general": {"flag": false, "none": null}'
  printf 'DOT_TASKS_SERVICE=from-env-file\n' > "$SANDBOX/.env"
  core "DOT_TASKS_SERVICE=from-environment dot::setting tasks.service; dot::setting general.flag; dot::setting general.none unset; dot::setting general.missing ''; dot::setting tasks.githubRepo acme/repo"
  assert_success
  assert_equal "$OUTPUT" "github
false
unset

acme/repo"
  sandbox::settings '"tasks": {"service": ""}'
  core "dot::setting tasks.service"
  assert_failure
  assert_contains "$ERRORS" 'The setting tasks.service isn'"'"'t set yet.'
  core "dot::setting TASKS_SERVICE"
  assert_failure
  assert_contains "$ERRORS" '"TASKS_SERVICE" isn'"'"'t a valid setting path.'
}

# Adds members to the sandbox's dotdot defaults, e.g. '"flag": false' under general.
with_defaults() {
  core "dot::use framework.helpers.json framework.helpers.fs
    framework.helpers.json::set \"\$(cat '$DOTDOT/.core/dot.defaults.json')\" '.$1' '$2' | framework.helpers.fs::write '$DOTDOT/.core/dot.defaults.json'"
  assert_success "add the default $1"
}

test_env_references_read_the_env_file_cast_by_syntax() {
  sandbox::settings '"tasks": {"service": "@env:MY_SERVICE"}, "general": {"timezone": "@env:DOT_MY_ZONE", "flag": "@env:MY_FLAG", "count": "@env:MY_COUNT", "label": "@env:MY_LABEL", "none": "@env:MY_NULL", "map": "@env:MY_MAP"}, "plugins": {"unprefixedCommandOwners": "@env:MY_OWNERS"}'
  core "dot::setting tasks.service; dot::setting general.timezone unset"
  assert_equal "$OUTPUT" "file
unset" "a missing key falls back to the default"
  printf '# MY_SERVICE=commented\nMY_SERVICE=github\nDOT_MY_ZONE=UTC\nMY_FLAG=true\nMY_COUNT=12\nMY_LABEL="12"\nMY_NULL=null\nMY_MAP={"a": 1}\nMY_OWNERS=["one", "two"]\n' > "$SANDBOX/.env"
  core "MY_SERVICE=from-environment dot::setting tasks.service; dot::setting general.timezone; dot::setting general.flag; dot::setting general.count; dot::setting general.label; dot::setting general.none unset; dot::setting general.map; dot::setting plugins.unprefixedCommandOwners"
  assert_success
  assert_equal "$OUTPUT" 'github
UTC
true
12
12
unset
{"a":1}
["one","two"]'
  printf 'MY_OWNERS=one, two\n' > "$SANDBOX/.env"
  core "dot::setting plugins.unprefixedCommandOwners"
  assert_equal "$OUTPUT" "one, two" "text that is not JSON stays text"
}

test_env_references_resolve_inside_objects_and_lists() {
  sandbox::settings '"release": {"remotes": {"github": "@env:GITHUB_REMOTE", "other": "@env:MISSING"}, "exclude": ["@env:FIRST", "dot"]}'
  printf 'GITHUB_REMOTE=https://github.com/acme/repo.git\nFIRST=.dot/\n' > "$SANDBOX/.env"
  core "dot::setting release.remotes; dot::setting release.exclude"
  assert_success
  assert_equal "$(printf '%s' "$OUTPUT" | tr -d ' \n')" '{"github":"https://github.com/acme/repo.git","other":null}[".dot/","dot"]'
  printf 'GITHUB_REMOTE=https://github.com/acme/repo.git\nFIRST=DOT_GH_TOKEN\n' > "$SANDBOX/.env"
  sandbox::settings '"release": {"exclude": ["@env:DOT_GH_TOKEN"]}'
  core "dot::setting release.exclude"
  assert_failure
  assert_contains "$ERRORS" 'DOT_GH_TOKEN is reserved by dotdot; please pick another .env key for release.exclude[0].'
}

test_env_references_never_name_a_secret_or_a_json_only_setting() {
  local key
  printf 'DOT_GH_TOKEN=secret\nDOT_RELEASE_TOKEN_GITHUB=secret\nDOT_ACME_WIDGETS__KEY=secret\nMY_STATE=forged\n' > "$SANDBOX/.env"
  for key in DOT_GH_TOKEN DOT_RELEASE_TOKEN_GITHUB DOT_ACME_WIDGETS__KEY; do
    sandbox::settings "\"general\": {\"timezone\": \"@env:$key\"}"
    core "dot::setting general.timezone"
    assert_failure "$key must be refused"
    assert_contains "$ERRORS" "$key is reserved by dotdot; please pick another .env key for general.timezone."
    assert_not_contains "$OUTPUT$ERRORS" "secret"
  done
  sandbox::settings '"state": {"version": "@env:MY_STATE", "migrations": []}, "tasks": {}'
  core "dot::setting state.version ''"
  assert_failure
  assert_contains "$ERRORS" "state.version can't come from .env."
  sandbox::settings '"state": {"migrations": ["@env:MY_STATE"]}'
  core "dot::setting state.migrations '[]'"
  assert_failure
  assert_contains "$ERRORS" "state.migrations can't come from .env."
  with_defaults general.timezone '"@env:MY_STATE"'
  sandbox::settings
  core "dot::setting general.timezone"
  assert_failure
  assert_contains "$ERRORS" "only .dot/dot.json may."
  core "dot::save_setting general.timezone '\"@env:MY_STATE\"'"
  assert_failure
  assert_contains "$ERRORS" "by hand only"
}

test_a_broken_settings_file_stops_rather_than_falls_back() {
  printf '{"tasks": {"service": "github",}\n' > "$DOTDOT/dot.json"
  core "dot::setting tasks.service"
  assert_failure
  assert_contains "$ERRORS" ".dot/dot.json isn't valid JSON"
}

test_env_files_read_as_dotenv_libraries_do() {
  local file="$SANDBOX/sample.env"
  printf 'A=plain # note\nB="kept # inside" # note\nexport C=\x27single\x27\nD=\nE=a#b\nF=first\nF=second\n# G=commented\n' > "$file"
  core "dot::use framework.helpers.kv; for key in A B C D E F; do printf '%s=[%s]\n' \"\$key\" \"\$(framework.helpers.kv::value '$file' \"\$key\")\"; done; framework.helpers.kv::value '$file' G || echo unset"
  assert_success
  assert_equal "$OUTPUT" "A=[plain]
B=[kept # inside]
C=[single]
D=[]
E=[a#b]
F=[first]
unset"
}

test_every_printed_line_masks_what_looks_like_a_secret() {
  local fake
  fake=$(fake_secret 9)
  core "dot::use framework.console.output
    framework.console.output::line 'clone with ghp_$fake'
    framework.console.output::error 'push failed: API_KEY=$fake'
    dot::raise 'request sent \"client_secret\": \"$fake\"'; exit 1"
  assert_failure
  assert_not_contains "$OUTPUT$ERRORS" "$fake"
  assert_contains "$OUTPUT" "clone with ghp_F4******"
  assert_contains "$ERRORS" "push failed: API_KEY=F4k3******"
  assert_contains "$ERRORS" '"client_secret": "F4k3******"'
}

test_json_keys_defined_twice_are_found_and_merged_in_place() {
  local document='{
  "other": {"k": 1, "k": 2},
  "links": {
    "@a": [
      "one"
    ],
    "@b": ["x"],
    "@a": ["two", "one"],
    "append": {"@c": ["1"]},
    "append": {"@d": ["2"]}
  }
}'
  core "dot::use framework.helpers.json; framework.helpers.json::duplicate_keys '$document'"
  assert_equal "$OUTPUT" "other	k
links	@a
links	append"
  core "dot::use framework.helpers.json; framework.helpers.json::merge_duplicates '$document' links"
  assert_success
  assert_equal "$OUTPUT" '{
  "other": {"k": 1, "k": 2},
  "links": {
    "@a": [
      "one",
      "two"
    ],
    "@b": ["x"],
    "append": {"@c":["1"],"@d":["2"]}
  }
}'
  core "dot::use framework.helpers.json; framework.helpers.json::merge_duplicates '{\"links\": {\"k\": \"a\", \"k\": \"b\"}}' links"
  assert_failure "two different texts can't be merged"
}

test_path_patterns_read_the_same_everywhere() {
  local path pattern expected
  while IFS='|' read -r path pattern expected; do
    core "dot::use framework.helpers.fs; framework.helpers.fs::pattern_matches '$path' '$pattern' && echo yes || echo no"
    assert_equal "$OUTPUT" "$expected" "$path against $pattern"
  done <<'CASES'
docs|docs|yes
docs/a.md|docs|no
docs|docs/|yes
docs/a.md|docs/|yes
docsx|docs/|no
docs|docs/*|no
docs/a.md|docs/*|yes
docs/deep/a.md|docs/*|yes
@plugin:acme.w:x|@plugin:acme.w:*|yes
@plugin:acme.x:x|@plugin:acme.w:*|no
CASES
  core "dot::use framework.helpers.fs; for p in docs docs/ 'docs/*' 'do*'; do printf '%s %s\n' \"\$(framework.helpers.fs::pattern_kind \"\$p\")\" \"\$(framework.helpers.fs::pattern_path \"\$p\")\"; done"
  assert_equal "$OUTPUT" "path docs
folder docs
contents docs
start do"
}

test_settings_are_saved_in_place() {
  printf '{\n  "state": {"migrations": []},\n  "tasks": {"service": "file"}\n}\n' > "$DOTDOT/dot.json"
  core "dot::save_setting tasks.service '\"github\"' && dot::save_setting general.timezone '\"UTC\"' && dot::setting tasks.service"
  assert_success
  assert_equal "$OUTPUT" "github"
  assert_equal "$(cat "$DOTDOT/dot.json")" '{
  "state": {"migrations": []},
  "tasks": {"service": "github"},
  "general": {"timezone": "UTC"}
}'
}

test_secrets_come_only_from_the_env_file() {
  sandbox::settings '"gh": {"token": "from-json"}'
  core "DOT_GH_TOKEN=from-environment dot::secret DOT_GH_TOKEN || printf unset"
  assert_equal "$OUTPUT" "unset"
  printf '# DOT_GH_TOKEN=commented\nDOT_GH_TOKEN=from-env-file\n' > "$SANDBOX/.env"
  core "dot::secret DOT_GH_TOKEN"
  assert_equal "$OUTPUT" "from-env-file"
  core "dot::secret GH_TOKEN"
  assert_failure
  assert_contains "$ERRORS" "\"GH_TOKEN\" isn't a valid secret name."
}

test_secrets_are_saved_privately_and_only_while_git_ignores_them() {
  git -C "$SANDBOX" init -q
  core "export GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME='$SANDBOX/none'; dot::save_secret DOT_RELEASE_TOKEN_SAMPLE value"
  assert_failure
  assert_contains "$ERRORS" ".env isn't git-ignored"
  assert_no_file "$SANDBOX/.env"
  printf '.env\n' > "$SANDBOX/.gitignore"
  core "export GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME='$SANDBOX/none'; dot::save_secret DOT_RELEASE_TOKEN_SAMPLE 'a value' && dot::secret DOT_RELEASE_TOKEN_SAMPLE"
  assert_success
  assert_equal "$OUTPUT" "a value"
  assert_equal "$(ls -l "$SANDBOX/.env" | cut -c1-10)" "-rw-------"
}

test_frontmatter_update_touches_only_the_block() {
  local file="$SANDBOX/doc.md"
  printf -- '---\nstatus: draft\nmodified: then\n---\n\nstatus: prose stays\n' > "$file"
  core "dot::use framework.helpers.frontmatter; framework.helpers.frontmatter::update '$file' status accepted modified now; framework.helpers.frontmatter::field '$file' status; framework.helpers.frontmatter::body '$file'"
  assert_success
  assert_equal "$OUTPUT" "accepted
status: prose stays"
}

test_frontmatter_update_fails_on_missing_key() {
  local file="$SANDBOX/doc.md"
  printf -- '---\nstatus: draft\n---\n' > "$file"
  core "dot::use framework.helpers.frontmatter; framework.helpers.frontmatter::update '$file' modified now"
  assert_failure
  assert_equal "$(cat "$file")" "$(printf -- '---\nstatus: draft\n---')"
}

test_record_numbers_never_read_as_octal() {
  local directory="$SANDBOX/records"
  mkdir -p "$directory"
  : > "$directory/x008--a.md"
  : > "$directory/x009--b.md"
  core "dot::use framework.helpers.record; framework.helpers.record::next_number '$directory' x"
  assert_success
  assert_equal "$OUTPUT" "010"
}

test_the_timezone_setting_applies_once_dates_load() {
  sandbox::settings '"general": {"timezone": "Europe/Madrid"}'
  core 'unset TZ; printf "%s|" "${TZ-unset}"; dot::use framework.helpers.date; printf "%s" "${TZ-}"'
  assert_equal "$OUTPUT" "unset|Europe/Madrid"
  sandbox::settings '"general": {"timezone": "@env:MY_TIMEZONE"}'
  printf 'MY_TIMEZONE=Nowhere/Land\n' > "$SANDBOX/.env"
  core 'unset TZ; dot::use framework.helpers.date; printf "%s" "${TZ-unset}"'
  assert_equal "$OUTPUT" "unset"
  assert_contains "$ERRORS" "Unknown timezone \"Nowhere/Land\" in .dot/dot.json settings (general.timezone)"
}

json_document='{"model":{"name":"Opus \"4\" é 😀"},"n":12.5,"t":true,"f":false,"z":null,"items":[1,{"x":"y"},[2,3]],"empty":{},"deep":{"a":{"b":[{"c":"found"}]}},"esc":"a\\b\/c\td\u0001\u007f","dup":{"b":1,"a":2,"b":3},"nums":[1e2,-3e2,0.0000001,10e-1,0e5,-0.0,.5,1.,+1,1.000e-3,Infinity,nan],"bad":"x\udc00y","sp" : [ ] , "a b":{"c":[1,2,3]}}'

# What jq -rc '<path> // empty' prints, kept here so the reader is checked
# even where jq isn't installed.
test_json_reader_prints_what_jq_prints() {
  local path expected
  while IFS='|' read -r path expected; do
    core "dot::use framework.helpers.json; framework.helpers.json::read_values '$json_document' '$path'"
    assert_success "$path"
    assert_equal "$OUTPUT" "$expected"
  done <<'CASES'
.model.name|Opus "4" é 😀
.n|12.5
.t|true
.f|
.z|
.items[1].x|y
.items[2][1]|3
.items[-1]|[2,3]
.items[-4]|
.items|[1,{"x":"y"},[2,3]]
.empty|{}
.deep.a.b[0].c|found
.dup|{"b":3,"a":2}
.dup.b|3
.nums|[1E+2,-3E+2,1E-7,1.0,0E+5,-0.0,0.5,1,1,0.001000,1.7976931348623157e+308,null]
.bad|x�y
.sp|[]
."a b".c[-1]|3
.["a b"]["c"][0]|1
.missing|
.items[9]|
.model.name.x|
..|
[0]|
.a-b|
CASES
  core "dot::use framework.helpers.json; framework.helpers.json::read_values '{\"a\":1} {\"a\":2} [' .a | tr '\n' ' '"
  assert_equal "$OUTPUT" "1 2 "
  core "dot::use framework.helpers.json; printf '%s' \"\$(framework.helpers.json::read_values '{\"a\":\"x' .a)\$(framework.helpers.json::read_values \$'{\"a\":\"tab\\there\"}' .a)\$(framework.helpers.json::read_values '\"\\ud800\"' .)\""
  assert_equal "$OUTPUT" ""
}

test_json_reader_agrees_with_jq() {
  local path
  command -v jq >/dev/null || return 0
  for path in . .model.name .n .t .f .z '.items[1].x' '.items[-1]' .items .empty '.deep.a.b[0].c' .esc .dup .dup.b .nums .bad .sp '."a b".c[-1]' '.["a b"]["c"][0]' .missing '.items[9]' '.model.name.x'; do
    core "dot::use framework.helpers.json; framework.helpers.json::read_values '$json_document' '$path' | LC_ALL=C tr -d '[:cntrl:]'"
    assert_equal "$OUTPUT" "$(printf '%s' "$json_document" | jq -rc "$path // empty" | LC_ALL=C tr -d '[:cntrl:]')"
  done
}

test_json_writer_prints_what_jq_prints() {
  local text expected
  while IFS='|' read -r text expected; do
    printf '%b' "$text" > "$SANDBOX/text"
    core "dot::use framework.helpers.json; text=\$(cat '$SANDBOX/text'; printf .); framework.helpers.json::write_string \"\${text%.}\""
    assert_equal "$OUTPUT" "$expected"
    command -v jq >/dev/null || continue
    assert_equal "$OUTPUT" "$(jq -Rs . < "$SANDBOX/text")"
  done <<'CASES'
plain|"plain"
q"uo\\te|"q\"uo\\te"
line\nbreak\ttab|"line\nbreak\ttab"
ctl\001\037\177\b\f\r|"ctl\u0001\u001f\u007f\b\f\r"
é😀|"é😀"
x\0377y\0342\0202z|"x�y�z"
\0355\0240\0200|"�"
|""
CASES
}

test_json_set_and_delete_print_what_jq_prints() {
  local doc='{"a":{"b":[1,{"c":[]}],"e":{}},"s":"x"}'
  core "dot::use framework.helpers.json; framework.helpers.json::read '$doc' '.a.b[3]' set '{\"z\":[true]}'"
  assert_equal "$OUTPUT" '{
  "a": {
    "b": [
      1,
      {
        "c": []
      },
      null,
      {
        "z": [
          true
        ]
      }
    ],
    "e": {}
  },
  "s": "x"
}'
  core "dot::use framework.helpers.json; framework.helpers.json::read '$doc' '.a.b[0]' delete | tr -d ' \n'"
  assert_equal "$OUTPUT" '{"a":{"b":[{"c":[]}],"e":{}},"s":"x"}'
  core "dot::use framework.helpers.json; framework.helpers.json::read '$doc' '.s.x' set 1"
  assert_failure
  command -v jq >/dev/null || return 0
  for path in .a.b .x.y '.a.b[5]' .s; do
    core "dot::use framework.helpers.json; framework.helpers.json::read '$doc' '$path' set '[1]'"
    assert_equal "$OUTPUT" "$(printf '%s' "$doc" | jq "$path = [1]")"
    core "dot::use framework.helpers.json; framework.helpers.json::read '$doc' '$path' delete"
    assert_equal "$OUTPUT" "$(printf '%s' "$doc" | jq "del($path)")"
  done
}

test_json_keep_format_edits_only_the_member() {
  local doc='{
  "a":   [1,  2],
  "b": {"x": 1},
  "c": {}
}'
  core "dot::use framework.helpers.json; framework.helpers.json::set '$doc' .b.y '[3]' --keep-format"
  assert_equal "$OUTPUT" '{
  "a":   [1,  2],
  "b": {"x": 1, "y": [3]},
  "c": {}
}'
  core "dot::use framework.helpers.json; framework.helpers.json::set '$doc' .c.k 1 --keep-format"
  assert_equal "$OUTPUT" '{
  "a":   [1,  2],
  "b": {"x": 1},
  "c": {
    "k": 1
  }
}'
  core "dot::use framework.helpers.json; framework.helpers.json::delete '$doc' .b --keep-format"
  assert_equal "$OUTPUT" '{
  "a":   [1,  2],
  "c": {}
}'
  core "dot::use framework.helpers.json; framework.helpers.json::delete '$doc' .a --keep-format"
  assert_equal "$OUTPUT" '{
  "b": {"x": 1},
  "c": {}
}'
}

test_output_highlights_commands_paths_and_values_only_at_a_terminal() {
  core "dot::use framework.console.output; printf '%s\n' 'Run bash dot link:activate acme/widgets, then edit .dot/dot.json for \"x\".' | awk -f \"\$OUTPUT_HIGHLIGHTER\" | awk -v styled=1 -f \"\$OUTPUT_RENDERER\""
  assert_equal "$OUTPUT" $'Run \033[1mbash dot link:activate acme/widgets\033[0m, then edit \033[90m.dot/dot.json\033[0m for \033[3m"x"\033[0m.'
  core "dot::use framework.console.output; framework.console.output::line 'Run bash dot link.'"
  assert_equal "$OUTPUT" "Run bash dot link."
}

test_styles_nest_and_carry_across_lines() {
  core "dot::use framework.console.output; printf '%s\n' \"\$(framework.console.output::yellow \"warn \$(framework.console.output::path .dot/x) on\")\" | awk -v styled=1 -f \"\$OUTPUT_RENDERER\""
  assert_equal "$OUTPUT" $'\033[33mwarn \033[90m.dot/x\033[0m\033[33m on\033[0m'
  core "dot::use framework.console.output; printf '%s\n' \"\$(framework.console.output::note \"\$(printf 'one\ntwo')\")\" | awk -v styled=1 -f \"\$OUTPUT_RENDERER\""
  assert_equal "$OUTPUT" $'\033[94m\033[3mone\033[0m\n\033[94m\033[3mtwo\033[0m'
  core "dot::use framework.console.output; framework.console.output::warn \"kept \$(framework.console.output::command 'bash dot link')\""
  assert_equal "$ERRORS" "! kept bash dot link"
}

test_bright_brightens_the_colors_inside_it() {
  core "dot::use framework.console.output; printf '%s\n' \"\$(framework.console.output::bright \"\$(framework.console.output::red x) y\")\" | awk -v styled=1 -f \"\$OUTPUT_RENDERER\""
  assert_equal "$OUTPUT" $'\033[91mx\033[0m y'
}
