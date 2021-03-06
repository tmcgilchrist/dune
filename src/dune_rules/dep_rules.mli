(** Get dependencies for a set of modules using either ocamldep or ocamlobjinfo *)

open! Dune_engine
open Import

val for_module :
     Compilation_context.t
  -> Module.t
  -> Module.t list Action_builder.t Ml_kind.Dict.t Memo.Build.t

val rules :
     Compilation_context.t
  -> modules:Modules.t
  -> Dep_graph.t Ml_kind.Dict.t Memo.Build.t
