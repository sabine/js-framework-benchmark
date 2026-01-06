(** js-framework-benchmark implementation for solid-ml
    
    This implements the standard benchmark operations:
    - Create 1,000 rows
    - Create 10,000 rows  
    - Append 1,000 rows
    - Update every 10th row
    - Clear rows
    - Swap rows (row 2 and row 999)
    - Select row
    - Remove row
*)

open Solid_ml_browser

(** {1 Data Generation} *)

let adjectives = [|
  "pretty"; "large"; "big"; "small"; "tall"; "short"; "long"; "handsome";
  "plain"; "quaint"; "clean"; "elegant"; "easy"; "angry"; "crazy"; "helpful";
  "mushy"; "odd"; "unsightly"; "adorable"; "important"; "inexpensive"; "cheap";
  "expensive"; "fancy"
|]

let colors = [|
  "red"; "yellow"; "blue"; "green"; "pink"; "brown"; "purple"; "brown";
  "white"; "black"; "orange"
|]

let nouns = [|
  "table"; "chair"; "house"; "bbq"; "desk"; "car"; "pony"; "cookie";
  "sandwich"; "burger"; "pizza"; "mouse"; "keyboard"
|]

let random max = 
  (Random.int 1000) mod max

let next_id = ref 1

type row_data = {
  id : int;
  mutable label : string;
}

let build_data count =
  Array.init count (fun _ ->
    let label = 
      adjectives.(random (Array.length adjectives)) ^ " " ^
      colors.(random (Array.length colors)) ^ " " ^
      nouns.(random (Array.length nouns))
    in
    let id = !next_id in
    incr next_id;
    { id; label }
  )

(** {1 DOM Helpers} *)

(* Row template for cloning *)
let row_template : Dom.element option ref = ref None

let get_row_template () =
  match !row_template with
  | Some t -> t
  | None ->
    let tr = Dom.create_element Dom.document "tr" in
    Dom.set_inner_html tr 
      "<td class='col-md-1'></td><td class='col-md-4'><a></a></td><td class='col-md-1'><a><span class='glyphicon glyphicon-remove' aria-hidden='true'></span></a></td><td class='col-md-6'></td>";
    row_template := Some tr;
    tr

(* Clone and populate a row *)
let create_row (data : row_data) =
  let template = get_row_template () in
  let tr = Dom.clone_node template true in
  (* Set data-id on tr for lookup *)
  Dom.set_attribute tr "data-id" (string_of_int data.id);
  (* Get child elements *)
  let children = Dom.get_child_nodes tr in
  (* TD 1: ID *)
  let td1 = Dom.element_of_node children.(0) in
  Dom.node_set_text_content (Dom.node_of_element td1) (string_of_int data.id);
  (* TD 2: Label *)
  let td2 = Dom.element_of_node children.(1) in
  let a = Dom.get_first_child td2 in
  (match a with
   | Some a_node -> Dom.node_set_text_content a_node data.label
   | None -> ());
  tr

(** {1 Application State} *)

let data : row_data array ref = ref [||]
let rows : Dom.element array ref = ref [||]
let selected_row : Dom.element option ref = ref None
let selected_id : int option ref = ref None

let get_tbody () =
  match Dom.get_element_by_id Dom.document "tbody" with
  | Some el -> el
  | None -> failwith "tbody not found"

let get_table () =
  match Dom.query_selector Dom.document "table" with
  | Some el -> el
  | None -> failwith "table not found"

(** Find row index by id *)
let find_idx id =
  let d = !data in
  let len = Array.length d in
  let rec loop i =
    if i >= len then None
    else if d.(i).id = id then Some i
    else loop (i + 1)
  in
  loop 0

(** Get parent row ID from click target *)
let get_parent_id (target : Dom.element) : int option =
  let rec find el =
    let tag = Dom.get_tag_name el in
    if tag = "TR" then
      match Dom.get_attribute el "data-id" with
      | Some id_str -> int_of_string_opt id_str
      | None -> None
    else
      match Dom.get_parent_element el with
      | Some parent -> find parent
      | None -> None
  in
  find target

(** Unselect current row *)
let unselect () =
  (match !selected_row with
   | Some row -> Dom.set_class_name row ""
   | None -> ());
  selected_row := None;
  selected_id := None

(** Select row by index *)
let select idx =
  unselect ();
  let r = !rows in
  if idx >= 0 && idx < Array.length r then begin
    let row = r.(idx) in
    Dom.set_class_name row "danger";
    selected_row := Some row;
    selected_id := Some (!data).(idx).id
  end

(** Delete row by index *)
let delete idx =
  let d = !data in
  let r = !rows in
  if idx >= 0 && idx < Array.length d then begin
    (* Check if we're deleting the selected row *)
    let deleting_selected = !selected_id = Some d.(idx).id in
    (* Remove from DOM *)
    let row = r.(idx) in
    (match Dom.get_parent_element row with
     | Some parent -> Dom.remove_child parent (Dom.node_of_element row)
     | None -> ());
    (* Remove from arrays *)
    data := Array.concat [Array.sub d 0 idx; Array.sub d (idx + 1) (Array.length d - idx - 1)];
    rows := Array.concat [Array.sub r 0 idx; Array.sub r (idx + 1) (Array.length r - idx - 1)];
    (* Clear selection if we deleted the selected row *)
    if deleting_selected then unselect ()
  end

(** Remove all rows *)
let remove_all_rows () =
  let tbody = get_tbody () in
  Dom.node_set_text_content (Dom.node_of_element tbody) ""

(** Append rows to tbody *)
let append_rows new_data =
  let tbody = get_tbody () in
  let table = get_table () in
  let new_rows = Array.map create_row new_data in
  (* Optimization: remove tbody, add rows, re-add tbody *)
  let was_empty = Array.length !rows = 0 in
  if was_empty then
    Dom.remove_child table (Dom.node_of_element tbody);
  Array.iter (fun row ->
    Dom.append_child tbody (Dom.node_of_element row)
  ) new_rows;
  if was_empty then
    Dom.append_child table (Dom.node_of_element tbody);
  (* Update state *)
  data := Array.append !data new_data;
  rows := Array.append !rows new_rows

(** {1 Benchmark Operations} *)

let run () =
  remove_all_rows ();
  data := [||];
  rows := [||];
  unselect ();
  append_rows (build_data 1000)

let run_lots () =
  remove_all_rows ();
  data := [||];
  rows := [||];
  unselect ();
  append_rows (build_data 10000)

let add () =
  append_rows (build_data 1000)

let update () =
  let d = !data in
  let r = !rows in
  let len = Array.length d in
  let i = ref 0 in
  while !i < len do
    (* Update data *)
    d.(!i).label <- d.(!i).label ^ " !!!";
    (* Update DOM *)
    let row = r.(!i) in
    let children = Dom.get_child_nodes row in
    let td2 = Dom.element_of_node children.(1) in
    (match Dom.get_first_child td2 with
     | Some a_node -> Dom.node_set_text_content a_node d.(!i).label
     | None -> ());
    i := !i + 10
  done

let clear () =
  remove_all_rows ();
  data := [||];
  rows := [||];
  unselect ()

let swap_rows () =
  let d = !data in
  let r = !rows in
  if Array.length d > 998 then begin
    (* Swap in data *)
    let tmp_d = d.(1) in
    d.(1) <- d.(998);
    d.(998) <- tmp_d;
    (* Swap in rows array *)
    let tmp_r = r.(1) in
    r.(1) <- r.(998);
    r.(998) <- tmp_r;
    (* Swap in DOM: move row at index 1 before row at index 2 *)
    let tbody = get_tbody () in
    Dom.insert_before tbody (Dom.node_of_element r.(1)) (Some (Dom.node_of_element r.(2)));
    (* Move row at index 998 before its next sibling (or append if last) *)
    Dom.insert_before tbody (Dom.node_of_element r.(998)) (Dom.get_next_sibling r.(998))
  end

(** {1 Event Handling} *)

let handle_button_click (target : Dom.element) =
  let id = Dom.get_id target in
  match id with
  | "run" -> run ()
  | "runlots" -> run_lots ()
  | "add" -> add ()
  | "update" -> update ()
  | "clear" -> clear ()
  | "swaprows" -> swap_rows ()
  | _ -> ()

let handle_tbody_click target =
  (* Find which TD was clicked *)
  let rec find_td el =
    let tag = Dom.get_tag_name el in
    if tag = "TD" then Some el
    else match Dom.get_parent_element el with
      | Some parent -> find_td parent
      | None -> None
  in
  match find_td target with
  | None -> ()
  | Some td ->
    match Dom.get_parent_element td with
    | None -> ()
    | Some tr ->
      let children = Dom.get_child_nodes tr in
      (* Check if click was on label (td index 1) or delete (td index 2) *)
      let is_label_td = Array.length children > 1 && Dom.element_of_node children.(1) = td in
      let is_delete_td = Array.length children > 2 && Dom.element_of_node children.(2) = td in
      match get_parent_id target with
      | None -> ()
      | Some id ->
        if is_label_td then begin
          match find_idx id with
          | Some idx -> select idx
          | None -> ()
        end
        else if is_delete_td then begin
          match find_idx id with
          | Some idx -> delete idx
          | None -> ()
        end

(** {1 Initialization} *)

let () =
  Random.self_init ();
  
  (* Set up button click handlers via event delegation *)
  (match Dom.get_element_by_id Dom.document "main" with
   | Some main ->
     Dom.add_event_listener main "click" (fun evt ->
       let target = Dom.target evt in
       let tag = Dom.get_tag_name target in
       if tag = "BUTTON" then
         handle_button_click target
     )
   | None -> ());
  
  (* Set up tbody click handlers via event delegation *)
  (match Dom.get_element_by_id Dom.document "tbody" with
   | Some tbody ->
     Dom.add_event_listener tbody "click" (fun evt ->
       let target = Dom.target evt in
       handle_tbody_click target
     )
   | None -> ())
