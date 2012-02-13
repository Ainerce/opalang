/*
    Copyright © 2011 MLstate

    This file is part of OPA.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

/**
 * Engine for applying a rdf query to a rdf base.
 *
 * @author Anthonin Bonnefoy, 2011
 * @category api
 * @destination public
 */

/**
 * {1 About this module}
 *
 * This module contains a high-level interface for applying rdf query to
 * a rdf base.
 *
 * {1 Where should I start?}
 * You have to parse your sparql request beforehand with [QueryParser.try_parse(query)].
 * You can apply this query on a rdf base with [RdfEngine.apply_query(query, base)] which
 * returns a list of rows as a result.
 */



RdfEngine = {{

  @private RdfQuery = {{

    string_begin_with(beg:string,str:string):bool=
      match String.index(beg, str) with
        | {none} -> false
        | {~some} -> some == 0

    apply_prefix_to_where(prefix:list((string,string) ), list_rdf:list(Rdf.where_element) ): list(Rdf.where_element) =
      List.map( el ->
        match el with
        | { ~var } -> { ~var }
        | { ~value } ->
          match List.find( (key,_ ) -> string_begin_with(key, value), prefix ) with
          | {none} -> { ~value }
          | {some=(key,prefix)} -> { value = "<{String.replace(key, prefix, value)}>" }
        , list_rdf
      )

    /*
     *  Expand the prefix in values
     */
    compile_query(query:Rdf.query) : Rdf.query =
      { ~prefix; select=_; ~where } = query
      new_where = List.map((where_row -> apply_prefix_to_where(prefix, where_row)), where)
      { query with where = new_where }

  }}


  @private zip_where_rdf(where:list(Rdf.where_element), rdf_element:Rdf.element) =
    (resource, property, value) = rdf_element
    List.zip(where, [resource, property, value])

  @private apply_where_element_to_rdf_element(where_element : Rdf.where_element, elem:string,  env:stringmap(string)) : stringmap(string) =
    match where_element with
    | { value=_ } -> env
    | { ~var } -> match StringMap.get(var, env) with
      | { none } -> StringMap.add(var, elem, env)
      | { some=_ } -> env
      end

  @private apply_where_list_to_rdf_element(where : list(Rdf.where_element), rdf_element:Rdf.element, env:stringmap(string) ) : stringmap(string) =
    zipped_where = zip_where_rdf(where, rdf_element)
    List.foldl( (where_element, rdf_elem), acc ->
      apply_where_element_to_rdf_element(where_element, rdf_elem, acc)
    , zipped_where
    , env
    )

  @private where_match_rdf_element(where_element : Rdf.where_element, elem:string,  env:stringmap(string)):bool =
    match where_element with
    | { ~value } -> elem == value
    | { ~var } -> match StringMap.get(var, env) with
      | { none } -> true
      | { ~some } -> some == elem
      end

  @private where_match_rdf_tuples(where:list(Rdf.where_element), rdf_element : Rdf.element, env:stringmap(string) ) : bool =
    zipped_where = zip_where_rdf(where, rdf_element)
    check((where, str))=where_match_rdf_element(where, str, env)
    List.for_all(check , zipped_where)

  @private apply_where_clause_to_row(where:list(Rdf.where_element), rdf_element : Rdf.element, env:stringmap(string) ) : option(stringmap(string) ) =
    if where_match_rdf_tuples(where, rdf_element, env)
    then some(apply_where_list_to_rdf_element(where, rdf_element, env) )
    else {none}

  @private apply_where_clause_to_row_multiple_env(where:list(Rdf.where_element), rdf_element : Rdf.element, list_env:list(stringmap(string)) ) : list(stringmap(string) ) =
    List.filter_map(env -> apply_where_clause_to_row(where, rdf_element, env), list_env)

  @private apply_where_clause_to_base(where:list(Rdf.where_element), rdf_base : Rdf.base, list_env:list(stringmap(string)) ) : list(stringmap(string) ) =
    List.flatten(
      List.map(
        elem ->
          apply_where_clause_to_row_multiple_env(where, elem, list_env)
        , rdf_base
      )
   )

  @private apply_multiple_where_clauses(where_clauses:list(list(Rdf.where_element)), rdf_base : Rdf.base, list_env:list(stringmap(string)) ) : list(stringmap(string) ) =
    List.foldl(where, acc ->
      apply_where_clause_to_base(where, rdf_base, acc)
    , where_clauses
    , list_env
  )

  /**
   *  Extract presents variable in the environnement list
   */
  extract_head(res:list(stringmap(string))):list(string) =
    match List.head_opt(res) with
    | {none} -> []
    | {~some} -> StringMap.To.key_list(some)
  end

  /**
   * Apply the rdf query to the base and return the result as a list of rows
   */
  apply_query(query:Rdf.query, rdf_base:Rdf.base) : list(stringmap(string) ) =
    query = RdfQuery.compile_query(query)
    res = apply_multiple_where_clauses(query.where, rdf_base, [StringMap_empty])
    match query.select with
    | { all } -> res
    | { ~vars } ->
      existing_key = extract_head(res)
      to_remove = List.filter(el -> not(List.mem(el,vars)), existing_key )
      List.map( env -> List.foldl(el, acc -> StringMap.remove(el, acc) , to_remove , env), res)

}}
