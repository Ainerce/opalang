(*
    Copyright © 2011, 2012 MLstate

    This file is part of Opa.

    Opa is free software: you can redistribute it and/or modify it under the
    terms of the GNU Affero General Public License, version 3, as published by
    the Free Software Foundation.

    Opa is distributed in the hope that it will be useful, but WITHOUT ANY
    WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
    FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for
    more details.

    You should have received a copy of the GNU Affero General Public License
    along with Opa. If not, see <http://www.gnu.org/licenses/>.
*)

(** Generate plugin files from JS given to the opa compiler. Mostly
    copied from bslregister.ml.

    @author Arthur Azevedo de Amorim
*)

module BR = BslRegisterLib
module BI = BslInterface
module BG = BslGeneration
module PH = PassHandler
module O = OpaEnv
module List = BaseList

let process env =
  let files =
    env.PH.options.O.client_plugin_files @
      env.PH.options.O.server_plugin_files in
  if not (List.is_empty files) then (
    let bsl_pref =
      File.chop_extension (
        Filename.basename env.PH.options.O.target
      ) in

    let options = {BG.default_opts with
      BG.
      (* Use minimal options for now *)
      files;
      bsl_pref;
      package_version = env.PH.options.O.package_version;
    } in

    BG.process options
  );

  (* HACK: The global BSL table is non-functional and is modified when
     compiling a plugin. These changes are inconsistent with the way
     regular plugins are loaded by the BslLoading pass. Thus, we must
     clear the table and load the plugin again later. *)
  BslLib.BSL.RegisterInterface.clear ();
  env
