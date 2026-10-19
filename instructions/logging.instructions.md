---
applyTo: "**"
---

When logging errors or warnings with Serilog, include the exception when one is available. Use the exception-first overload, for example `Log.Error(ex, msg)` or `Log.Warning(ex, msg)`, rather than logging only its message.
