class_name PrologueProfileTrace
extends RefCounted
## Diagnostic-only; populated by timestamp inserts in the isolated profile export.
static var phase: String = "prologue"
static var rows: Array[Dictionary] = []
