(*
 * Copyright (c) 2013 Anil Madhavapeddy <anil@recoil.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *)

open Cmdliner

let default_env_prefix = "default"
let default_chunk_size = 80
type copts = { env_prefix : string; chunk_size : int }

let copts_sect = "COMMON OPTIONS"
let help_secs = [ 
  `S copts_sect; 
  `P "These options are common to all commands.";
  `S "MORE HELP";
  `P "Use `$(mname) $(i,COMMAND) --help' for help on a single command.";`Noblank;
]

let prefix env_prefix suffix =
  Printf.sprintf "XSECRET_%s_%s" env_prefix suffix

(* Chunk a whole file into [size] chunks after Base64 encoding it *)
let chunk_file file size =
  let buf = Buffer.create 1024 in
  let fin = open_in file in
  Buffer.add_channel buf fin (in_channel_length fin);
  let b64 = Base64.encode (Buffer.contents buf) in
  (* Chunk this string into [size] chunks to convert into env vars *)
  let chunks = (String.length b64 / size) + 1 in
  Array.init chunks 
    (fun i ->
       let off = i * size in
       let len = 
         if off + size > (String.length b64) then
           (String.length b64) - off
         else size in
       String.sub b64 off len)

let encrypt {env_prefix; chunk_size} ifile ofile =
  let chunks = chunk_file ifile chunk_size in
  if Sys.file_exists ofile then (
    Printf.eprintf "%s output file already exists. Delete it first.\n%!" ofile;
    exit 1);
  let fout = open_out ofile in
  Array.iteri (fun lnum v ->
      let k = prefix env_prefix (string_of_int lnum) in
      Printf.fprintf fout "%s=%s\n" k v;
    ) chunks;
  Printf.fprintf fout "%s=%d\n%!" (prefix env_prefix "num") (Array.length chunks);
  close_out fout;
  ignore(Sys.command (Printf.sprintf "cat %s" ofile));
  print_endline "Now run this to add it to your travis.yml:";
  Printf.printf "  cat %s | travis encrypt -ps --add\n\n%!" ofile;
  print_endline "You can decrypt it from within a Travis VM by:";
  Printf.printf "  travis-senv decrypt -p=%s\n\n" env_prefix

let decrypt {env_prefix} =
  let getenv e =
    try Sys.getenv (prefix env_prefix e)
    with Not_found ->
      Printf.eprintf "%s not set in environment\n%!" (prefix env_prefix e);
      exit 1
  in
  let buf = Buffer.create 1024 in
  let lnum = int_of_string (getenv "num") in
  for i = 0 to lnum - 1 do
    Buffer.add_string buf (getenv (string_of_int i))
  done;
  print_string (Base64.decode (Buffer.contents buf))

let copts env_prefix chunk_size =
  let env_prefix = match env_prefix with None -> default_env_prefix | Some p -> p in
  let chunk_size = match chunk_size with None -> default_chunk_size | Some c -> c in
  { env_prefix; chunk_size }

let copts_t = 
  let docs = copts_sect in 
  let env_prefix =
    let doc = "Environment prefix to distinguish this entry" in
    Arg.(value & opt (some string) None & info ["p";"prefix"] ~docs ~doc)
  in
  let chunk_size =
    let doc = "Max size of each key chunk (you shouldnt have to change this)" in
    Arg.(value & opt (some int) None & info ["c";"chunk-size"] ~docs ~doc)
  in
  Term.(pure copts $ env_prefix $ chunk_size)

let decrypt_cmd =
  let doc = "decrypt files from the environment variables" in 
  let man = 
    [`S "DESCRIPTION";
     `P "Decrypt file and write it to standard output."]
  in    
  Term.(pure decrypt $ copts_t),
  Term.info "decrypt" ~sdocs:copts_sect ~doc ~man

let encrypt_cmd =
  let doc = "generate encryption entries for a travis.yml" in  
  let input_file = Arg.(required & pos 0 (some string) None
                        & info [] ~docv:"INPUT_FILE" ~doc) in
  let output_file = Arg.(required & pos 1 (some string) None
                         & info [] ~docv:"OUTPUT_FILE" ~doc) in
  let man = 
    [`S "DESCRIPTION";
     `P "Generate encryption entries and run through the Travis encrypt command."]
  in    
  Term.(pure encrypt $ copts_t $ input_file $ output_file),
  Term.info "encrypt" ~sdocs:copts_sect ~doc ~man

let cmds = [encrypt_cmd; decrypt_cmd]

let default_cmd = 
  let doc = "Travis encryption utilities" in 
  let man = help_secs in
  Term.(ret (pure (fun _ -> `Help (`Pager, None)) $ copts_t)),
  Term.info "travis-senv" ~version:"1.0.0" ~sdocs:copts_sect ~doc ~man

let () = match Term.eval_choice default_cmd cmds with 
  | `Error _ -> exit 1 | _ -> exit 0
