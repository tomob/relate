let value_max = 64
let payload_max = 256

let hex4 cp = Printf.sprintf "\\u%04x" cp

let is_printable cp = cp >= 0x20 && cp < 0x7f

let piece_buf buf cp in_quotes =
  if is_printable cp
     && (not in_quotes || (cp <> Char.code '\\' && cp <> Char.code '"'))
  then Buffer.add_char buf (Char.chr cp)
  else if cp >= 0x10000 then begin
    let cp' = cp - 0x10000 in
    Buffer.add_string buf (hex4 (0xD800 + (cp' lsr 10)));
    Buffer.add_string buf (hex4 (0xDC00 + (cp' land 0x3FF)))
  end
  else Buffer.add_string buf (hex4 cp)

(* escape renders s bounded to max bytes of output: an ASCII printable byte
   crosses, every other code point crosses as its \uXXXX escape (an astral
   code point as its UTF-16 surrogate pair, a byte that is not UTF-8 as
   \u00XX), and the escape for the value's own quote and backslash is added
   when in_quotes. A truncated input is marked, so an untrusted payload can
   never smuggle a line break or a byte sequence into an error message. *)
let escape ~in_quotes s max =
  let buf = Buffer.create 16 in
  let n = String.length s in
  let rec loop i =
    if i >= n then true
    else
      let b0 = Char.code (String.get s i) in
      let consumed, cp =
        if b0 < 0x80 then (1, b0)
        else
          let want = if b0 >= 0xF0 then 4 else if b0 >= 0xE0 then 3 else 2 in
          let rec decode j acc =
            if j >= want || j >= n - i then None
            else
              let b = Char.code (String.get s (i + j)) in
              if b land 0xC0 <> 0x80 then None
              else decode (j + 1) ((acc lsl 6) lor (b land 0x3F))
          in
          let base = if want = 4 then b0 land 0x07
            else if want = 3 then b0 land 0x0F
            else b0 land 0x1F in
          match decode 1 base with
          | Some cp when want = 4 && cp < 0x10000 -> (1, b0)
          | Some cp when want = 3 && cp < 0x800 -> (1, b0)
          | Some cp when want = 2 && cp < 0x80 -> (1, b0)
          | Some cp -> (want, cp)
          | None -> (1, b0)
      in
      let before = Buffer.length buf in
      piece_buf buf cp in_quotes;
      if Buffer.length buf > max then begin
        Buffer.truncate buf before;
        false
      end
      else if Buffer.length buf = max && i + consumed < n then false
      else loop (i + consumed)
  in
  let complete = loop 0 in
  if not complete then Buffer.add_string buf "...(truncated)";
  Buffer.contents buf

let quoted s = "\"" ^ escape ~in_quotes:true s value_max ^ "\""

let safe s = escape ~in_quotes:false s payload_max
