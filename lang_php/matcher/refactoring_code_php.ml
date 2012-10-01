(* Yoann Padioleau
 *
 * Copyright (C) 2012 Facebook
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * version 2.1 as published by the Free Software Foundation, with the
 * special exception on linking described in file license.txt.
 * 
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the file
 * license.txt for more details.
 *)
open Common

open Ast_php
module Ast = Ast_php
module V = Visitor_php
module PI = Parse_info
module R = Refactoring_code

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)

let tok_pos_equal_refactor_pos tok refactoring =
  Ast.line_of_info tok = refactoring.R.line &&
  Ast.col_of_info tok = refactoring.R.col

(*****************************************************************************)
(* Main entry point *)
(*****************************************************************************)

let refactor refactorings ast_with_tokens =
  refactorings +> List.iter (fun r ->
    let visitor = 
      match r.R.action with
      | R.AddReturnType str ->
          { V.default_visitor with
            V.kfunc_def = (fun (k, _) def ->
              let tok = Ast.info_of_name def.f_name in
              if tok_pos_equal_refactor_pos tok r then begin
                let tok_close_paren = 
                  let (a,b,c) = def.f_params in c
                in
                tok_close_paren.PI.transfo <- 
                  PI.AddAfter (PI.AddStr (": " ^ str));
              end;
              k def
            );
          }
      | R.AddTypeHintParameter str ->
          { V.default_visitor with
            V.kparameter = (fun (k, _) p ->
              let tok = Ast.info_of_dname p.p_name in
              if tok_pos_equal_refactor_pos tok r then begin
                tok.PI.transfo <- 
                  PI.AddBefore (PI.AddStr (str ^ " "));
              end;
              k p
            );
          }

      | R.AddTypeMember str ->
          { V.default_visitor with
            V.kclass_stmt = (fun (k, _) x ->
              match x with
              | ClassVariables (_cmodif, _typ_opt, xs, _tok) ->
                  (match xs with
                  | [Left (dname, affect_opt)] ->
                      let tok = Ast.info_of_dname dname in
                      if tok_pos_equal_refactor_pos tok r then begin
                        tok.PI.transfo <- 
                          PI.AddBefore (PI.AddStr (str ^ " "));
                      end;
                      k x
                  | xs ->
                      xs +> Ast.uncomma +> List.iter (fun (dname, _) ->
                      let tok = Ast.info_of_dname dname in
                      if tok_pos_equal_refactor_pos tok r then begin
                        failwith "TODO: need to split the members"
                      end;
                      );
                      k x
                  )
              | _ -> k x
            );
          }
    in
    let ast = Parse_php.program_of_program2 ast_with_tokens in
    (V.mk_visitor visitor) (Program ast)
  );
  Unparse_php.string_of_program2_using_transfo ast_with_tokens
