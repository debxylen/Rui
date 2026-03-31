### core.luau

**generate_from_app**

* main entry point
* sets up actions + parser -> kicks off pipeline

**load_uiapp**

* resolves `@include(...)`
* aka inlines the fragments

**preprocess_luaxml**

* turns stuff into pure-xml
* shortcut: `"<>...</>"` -> `"<Fragment>...</Fragment>"`
* templates -> xml: `"{{ code }}"` -> `"<LuaBlock key=... />"`
* stores: `key` -> `code`

**xml_parser.fromstring**

* ofcourse, parses pure-xml into tree

**build**

* tree -> `{type, props, children}`
* `"text='hi'"` -> `props.Text = "hi"`

**compile_root**

* AST -> compiled entry
* `root AST` -> `(lines, root_vars)`
* uses compile_node but handles Fragment vs normal

**compile_node**

* core rui -> lua transpiler
* `obj` -> `lua lines + var name`
* * `{type="TextLabel", props={Text="hi"}}` -> `local TextLabel_1 = Instance.new(...)`
* for each child -> goto `compile_child`
* per-prop dispatch -> subcompilers

  **parse_props**

  * raw attrib -> structured props
  * `"visible='true'"` -> `.Visible = true`
  * for expr: `"{...}"` -> `{kind="expr", code=...}`

  **compile_prop**

  * direct: `props.Text = "hi"` -> `obj.Text = "hi"`
  * computed: goto `compile_computedprop`

  **compile_computedprop**

  * expr -> reactive binding
  * `"count+1"` -> `bindComputed(obj, "Text", fn, scope)`
  * goto `compile_func` (to generate fn)

  **compile_func**

  * expr -> function
  * `"count+1"` -> `function(_scope) return count+1 end`
  * injects: referenced `scope, locals, helpers`

  **compile_textbind**

  * template handling
  * `"Hello {name}"` -> `bindText(obj, template, {"name"})`

  **compile_visiblebind**

  * `{expr}` -> `bindComputed(obj, "Visible", fn)`

  **compile_rawprop**

  * fallback for unrecognized props, also injects warner abt it
  * `"__rawprop__foo"` -> `obj.foo = value`

  **compile_layout**

  * layout -> instances
  * `{direction="row"}` -> `UIListLayout.Horizontal`
  * `{padding=10}` -> `UIPadding with 10px`

  **compile_corner**

  * `cornerRadius=8` -> `UICorner(8)`
  * expr radius -> goto `compile_func`

  **compile_tween**

  * `{time=0.3}` -> `TweenInfo.new(...)`

  **compile_transition**

  * `{preset="fade"}` -> `setTransitionInfo(...)`

  **compile_events**

  * event binding
  * `"onClick='foo'"` -> `bindEvent(...)`
  * `"onClick={expr}"` -> `bindEventExpr(...)`
  * expr handler -> goto `compile_func`

  **compile_child**

  * recursive dispatch children
  * `Fragment` -> `compile_child` on each grandchild
  * `LuaBlock` -> `compile_block`
  * `normal` -> `compile_node` and `.Parent = ...`

**compile_block**

* `"{{ code }}"` -> selector funcs (dynamic frag mounts) + `fragmentFactories` (ui builders)
* `-> bindLuaBlock(parent, fn, factories, scope)`
* goto `compile_func` (build selector function)
* block helper locals are emitted if referenced

  **parse_scope**

  * `"-- @scope a b"` -> `{"a","b"}`
  * for frag-generating loops inside blocks

  **extract_fragmentcalls**

  * frag extraction
  * `"Fragment('<UI>')"` -> `__fragment('frag_0')`
  * `-> literals = {frag_0 -> "<UI>"}`
  * captured scope is appended later when `-- @scope ...` is present

  **extract_strliterals**

  * preserves strings
  * `"\"hi\""` -> `unchanged`

  **uses_identifier**

  * strips strings/comments and checks helper usage
  * helps in emitting only whats needed

  **compile_fragchilds**

  * frag -> nodes using `compile_node`
  * `"<TextLabel/>"` -> `(lines, {"TextLabel_1"})`

**append_footer**

* mounting stuff
* `root_vars` -> `Parent = PlayerGui/StarterGui`
* startergui when edit mode, playergui when runtime

### runtime.luau

**bindComputed**

* reactive props
* `obj, prop, fn, scope` -> `updates obj[prop]`
* evaluates `fn(scope)` -> assigns result
* re-runs when dependencies change

**bindEvent**

* static event binding
* `[obj, prop_name, signal_name, handler, scope]`
* connects `obj[signal_name]` -> calls handler

**bindEventExpr**

* dynamic event binding
* `[obj, prop_name, signal_name, fn, scope]`
* fn is precompiled (from `compile_func` in core)  
* connects event -> executes fn with scope

**bindLuaBlock**

* dynamic fragment system (runtime core)
* `[parent, selector_fn, fragmentFactories, scope]`

* goto `selector_fn(scope)` -> returns fragment key(s)
* goto `fragmentFactories[key]` -> builds UI

flow:

* selector decides -> `"frag_0"` or `{key, scope}`
* factory builds -> actual instances
* mounts to parent

**renderTemplate**

* text interpolation
* `[template, scope]` -> `string`
* `"Hello {name}"` -> `"Hello Bob"`

**bindText**

* reactive text binding
* `[obj, template, deps]`
* goto `renderTemplate`
* updates `.Text` when deps change

**setTweenInfo**

* assigns tween config
* `[obj, TweenInfo]` -> `stored config`
* used later by runtime animations

**setTransitionInfo**

* assigns transition config
* `[obj, preset, TweenInfo]` -> `stored config`

**invokeAction**

* action dispatcher
* `[action_name, scope, ...args]`
* looks up action -> executes with scope

**getById**

* lookup helper
* `id` -> `instance`
