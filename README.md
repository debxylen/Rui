# Rui

A reactive-declarative UI framework for Roblox Luau.

**Overview**

Rui takes a declarative UI written in LuaXML[^1] and compiles it into Luau, with an adjacent runtime for reactivity and logics.

**Points**
- state-reactive UI
- simple declarative syntax
- in-studio edit mode execution previews
- a compiled, lightweight runtime
- standalone compiled outputs
- responsive layout engine
- scoped loops
- transition presets
- components and templating
- autocompilation

**Usage**

The [Rui Plugin](https://create.roblox.com/store/asset/124163949816589) is the intended convenient method of compiling and using Rui apps in-studio.

**Files**

* `lib/rui.luau`: public API
* `lib/core.luau`: compiler
* `lib/xml.luau`: XML parser
* `lib/runtime.luau`: runtime helpers
* `plugin/Rui.legacy.luau`: studio plugin
* `examples/`: some examples (TBD)
* `ARCHITECTURE.md`: compiler/runtime flow

**Example**

```xml
<Frame
  size="0.22,0.17"
  position="0.03,0.05"
  backgroundColor="15,19,29"
  cornerRadius="20"
  backgroundTransparency="0.08"
  direction="column"
  gap="8"
  padding="14"
>
  <TextLabel
    text="{ state.playerName }"
    size="1,0.4"
    textColor="255,255,255"
    textScaled="true"
    backgroundTransparency="1"
  />
  <TextLabel
    text="{ 'Level ' .. tostring(state.level) .. ' Explorer' }"
    size="1,0.4"
    textColor="173,187,216"
    textScaled="true"
    backgroundTransparency="1"
  />
</Frame>
```

**Licensing**

Rui is licensed under the [MPL v2.0](LICENSE).
Any modifications to the Rui library or plugin must be opensourced and shared under the same license.

However, usage of Rui in games is fully permissive without any copyleft.
If Rui helps you in your project though, consider mentioning it :)

[^1]: LuaXML is an experimental syntax for writing XML-style UI directly in Lua, in a way similar to JSX.
