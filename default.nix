# Credit to https://github.com/inkpot-monkey/nix-parsec/tree/examples-lisp for creating the original lisp parser.

let
  nix-parsec =
    import (fetchTarball {
      url = "https://github.com/kanwren/nix-parsec/archive/refs/heads/master.tar.gz";
      sha256 = "sha256:0ca0yj5vb1mcdvzm1sjb2ygbxkc88fx3css8fraqx7668g8wcypw";
    });

  inherit (nix-parsec) lexer;
  inherit (nix-parsec) parsec;
  inherit (nix-parsec.parsec)
    skipWhile
    between
    string
    takeWhile1
    alt
    many
    skipThen
    ;
  inherit (builtins)
    match
    elemAt
    isList
    isString
    substring
    stringLength
    isAttrs
    concatStringsSep
    length
    head
    tail
    foldl'
    all
    ;
in
let
  # Cannot use '' here as it strips white space
  spaceChar = " ";

  # Skip until a root list node
  outsideList = skipWhile (c: c != ''('' && c != ";");

  comment = skipWhile (c: c != "\n");

  # Skip chars not essential to list comprehension
  listSpaces =
    skipWhile (c:
      c == spaceChar
      || c == "\t"
      || c == "\n"
      || c == "#");

  listLexeme = lexer.lexeme listSpaces;

  quotes = between (string ''"'') (string ''"'');
  parens = between (string ''('') (string '')'');

  # This accounts for the case where inside a quoted string will be a \"
  quotedIdentifier = ps:
    let
      str = elemAt ps 0;
      offset = elemAt ps 1;
      len = elemAt ps 2;
      strLen = stringLength str;
      # Search for the next offset that violates the predicate
      go = ix:
        if ix >= strLen || (substring ix 1 str) == ''"''
        then ix
        else if (substring ix 2 str) == ''\"''
        then go (ix + 2)
        else go (ix + 1);
      endIx = go offset;
      # The number of characters we found
      numChars = endIx - offset;
    in
    [ (substring offset numChars str) endIx (len - numChars) ];

  identifier =
    let validChar = c: match ''[a-zA-Z0-9+|:@_./<>=-]'' c != null;
    in listLexeme (takeWhile1 validChar);

  atom = alt identifier (quotes quotedIdentifier);
  list = parens (many (listLexeme (alt atom list)));

  sexpr = alt atom list;
  multiline_sexpr = many (skipThen (alt outsideList comment) sexpr);

  fromLisp = S: parsec.runParser multiline_sexpr S;
  importLisp = path: fromLisp (builtins.readFile path);

  # Convert parsed dune-project S-expr into idiomatic Nix values.
  #
  # This is probably missing a bunch of stuff. If you find yourself here,
  # please feel free to open a pull request to fix your issue.
  lispToDune = tokens:
    let
      isStringList = l: all isString l;

      # Get the inner list of tags from the lexed tags stanza.
      getTags = tags: elemAt tags 0;

      # Format the depends stanza attribute list.
      #
      # [ ">=" "cmdliner" ] becomes [ ">= cmdliner" ]
      mapDepends = deps: map
        (dep:
          if isString dep then
            { ${dep} = [ ]; }
          else if isList dep && length dep >= 1 && isString (head dep) then
            let
              depName = head dep;
              # Convert version constraints to a list of strings.
              constraints = map
                (c:
                  if isList c then
                    concatStringsSep " " (map (c': if isString c' then c' else toString c') c)
                  else
                    toString c)
                (tail dep);
            in
            { ${depName} = constraints; }
          else
            dep)
        deps;

      # Map the source stanza into something that is easier to use in Nix.
      mapSource = source:
        let
          source' = elemAt source 0;
          type = elemAt source' 0;
          owner_repo = builtins.split ''[./]'' (elemAt source' 1);
        in
        {
          inherit type;
          owner = elemAt owner_repo 0;
          repo = elemAt owner_repo 2;
        };
    in
    if length tokens >= 2 && isString (head tokens) then
      let
        key = head tokens;
        rest = tail tokens;
      in
      if key == "tags" then
        { ${key} = getTags rest; }
      else if key == "depends" then
        { ${key} = mapDepends rest; }
      else if key == "source" then
        { ${key} = mapSource rest; }
      else if key == "maintainers" || key == "authors" then
        { ${key} = rest; }
      else if length rest == 1 then
        { ${key} = head rest; }
      else if isString (head rest) then
        let
          subkey = head rest;
          vals = tail rest;
        in
        { ${key} = { ${subkey} = concatStringsSep "." vals; }; }
      else if isStringList rest then
        { ${key} = concatStringsSep "." rest; }
      else
        {
          ${key} = mergeAttrsList (map
            (rest:
              if isList rest then
                lispToDune rest
              else rest)
            rest);
        }
    else
      mergeAttrsList tokens;

  mergeAttrsList = list: foldl'
    (acc: maybe_attr:
      if isAttrs maybe_attr then
        acc // maybe_attr else acc)
    { }
    list;

  lispToDuneProject = parsed:
    if parsed.type == "success" then
      mergeAttrsList (map lispToDune parsed.value)
    else
      throw "failed to convert lisp tokens into dune-project atterset" parsed;

  importDuneProject = dune_project: lispToDuneProject (importLisp dune_project);
in
{
  inherit fromLisp importLisp importDuneProject;
}

