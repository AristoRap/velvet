# velvet

> The rope between your terminal and your app.

Define prompts in YAML (or use the lib/DSL in Crystal). Collect clean, typed input. Emit JSON. Your app never writes argparse again.

---

## Install

```bash
git clone https://github.com/aristorap/velvet
cd velvet
shards install
shards build --release
# binary at bin/velvet
```

---

## Usage

```bash
# Generate a new YAML wizard from shorthand field specs
velvet new "Deploy config" app_name replicas:int frontend@one_of=vanilla,vue dry_run@confirm

# Interactive wizard
velvet run deploy_config.yml

# Non-interactive — parse flags against schema
velvet parse deploy_config.yml -- --environment staging --replicas 3 --dry-run

# Validate a wizard file
velvet validate deploy_config.yml

# Run the DSL deploy example
crystal run examples/dsl.deploy.cr
```

The new command writes a normalized <name>.yml file in the current directory.

Pipe into your app:

```bash
config=$(velvet run deploy.yml)
myapp <<< "$config"

# or
velvet run deploy.yml | myapp deploy
```

Your app just reads JSON from stdin — no argparse, no type coercion, no required-field checks.

---

## Generator field shorthand

Supported shorthand format:

```text
field   := id | id:cast | id@ui | id:cast@ui | id:cast@ui=val,val
cast    := str | string | int | float | bool
ui      := input | select | multi | confirm
values  := csv, valid only with select and multi
```

Examples:

```text
app_name
app_name:str
replicas:int
replicas:int@select=1,2,4,8
frontend@select=vanilla,vue
dry_run@confirm
tags@multi=cache,metrics
```

Defaults and implications:

- no :cast means string
- no @ui means input
- @confirm implies boolean semantics
- @select or @multi without =values is valid and produces an empty options list

Built-in UI aliases:

- @one_of is an alias for @select
- @any_of is an alias for @multi
- @multiselect is also accepted where @multi is used

Custom aliases can be registered from Crystal code while the API evolves:

```crystal
Velvet::Generator.set_ui_alias("pick", "select")
Velvet::Generator.set_ui_alias("many", "multi")
```

Reset aliases back to defaults:

```crystal
Velvet::Generator.reset_ui_aliases
```

DSL has matching user-facing aliases:

```crystal
w.input "replicas", "Number of replicas", cast: Velvet::Cast::Int
w.one_of "environment", "Environment", ["dev", "prod"]
w.multi "tags", "Tags", ["cache", "metrics"]
w.any_of "tags", "Tags", ["cache", "metrics"]
w.field "tags", "Tags", ui: "multiselect", options: ["cache", "metrics"]
```

---

## Wizard file

```yaml
name: "Deploy config"

fields:
  - id: environment
    type: select
    label: "Target environment"
    options: [dev, staging, production]
    default: dev

  - id: replicas
    type: input
    label: "Number of replicas"
    cast: int
    required: true
    validate:
      min: 1
      max: 20

  - id: dry_run
    type: confirm
    label: "Dry run?"
    default: false

  - id: tags
    type: multiselect
    label: "Feature flags"
    options: [cache, metrics, tracing]
    required: false
```

### Field types

| type          | description                              |
| ------------- | ---------------------------------------- |
| `input`       | free text, optionally cast and validated |
| `select`      | pick one from a list                     |
| `multiselect` | pick many                                |
| `confirm`     | yes/no boolean                           |

### Cast types

string (default), int, float, bool

For select and multiselect fields, cast is also supported and is applied in both run and parse flows.

### Validation

```yaml
validate:
  min: 1
  max: 100
  pattern: "^[a-z-]+$"
```

Validation rules are cast-aware and checked when loading YAML or building via DSL:

- `min` / `max` are only valid with `cast: int` or `cast: float`
- `pattern` is only valid with `cast: string` (or omitted cast, which defaults to string)

Invalid combinations are rejected as schema/config errors (exit code `2`) rather than being ignored.

Examples of invalid combinations:

```yaml
# invalid: numeric bounds on string
cast: string
validate:
  min: 1

# invalid: pattern on int
cast: int
validate:
  pattern: "^[0-9]+$"
```

---

## Output

Always clean JSON to stdout, errors to stderr.

```json
{
  "environment": "staging",
  "replicas": 3,
  "dry_run": false,
  "tags": ["cache", "metrics"]
}
```

Types are cast before emission — consumers always get typed values.

---

## Exit codes

| code  | meaning               |
| ----- | --------------------- |
| `0`   | success               |
| `1`   | validation error      |
| `2`   | config/schema error   |
| `130` | user aborted (Ctrl+C) |
