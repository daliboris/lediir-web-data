xquery version "3.1";

module namespace idx="http://teipublisher.com/index";

declare namespace array = "http://www.w3.org/2005/xpath-functions/array";
declare namespace map = "http://www.w3.org/2005/xpath-functions/map";



declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace dbk="http://docbook.org/ns/docbook";

declare namespace functx = "http://www.functx.com";


declare function functx:substring-before-last
  ( $arg as xs:string? , $delim as xs:string )  as xs:string {

   if (contains($arg, $delim))
   then replace($arg,
            concat('^(.*)', replace($delim, '\s', '\\s'),'.*'),
             '$1')
   else ''
 } ;

declare variable $idx:parentheses-todo := "remove"; (: "remove" | "move" | "keep" :)
declare variable $idx:payload-todo := false();

declare variable $idx:frequency-boost := map {
    'A' : 70,
    'B' : 60,
    'C' : 50,
    'D' : 40,
    'E' : 10,
    'R' : 1,
    'X' : 1
 };

declare variable $idx:sense-boost := map {
  1 : 5,
  2 : 4,
  3 : 1
 };

 declare variable $idx:equivalent-boost := map {
  1 : 5,
  2 : 4,
  3 : 3
 };

declare variable $idx:sense-uniqueness-max := 5;

 declare function idx:get-frequency-boost-number($frequency) {
    if(exists($frequency)) then 
        if (map:contains($idx:frequency-boost, $frequency)) then    
         map:get($idx:frequency-boost, $frequency)
          else 1
        else 1
 };

declare function idx:get-sense-uniqueness-boost($position as xs:integer, $sense-count as xs:integer) as xs:double {
    if($position = 1) then 
        $idx:sense-uniqueness-max
    else if($position ge $sense-count) then
        1
    else
        $idx:sense-uniqueness-max - (($idx:sense-uniqueness-max div $sense-count ) * ($position - 1))
};

declare function idx:get-equivalent-position-boost($position as xs:integer) as xs:double {
    if(map:contains($idx:equivalent-boost, $position)) then $idx:equivalent-boost?($position) else 1
 };

 declare function idx:get-sense-boost($position as xs:integer) as xs:double {
    if(map:contains($idx:sense-boost, $position)) then $idx:sense-boost?($position) else 1
 };
 
 declare function idx:get-sense-boost($position as xs:integer, $all-senses as xs:integer) as xs:double {
  let $result :=
    if(map:contains($idx:sense-boost, $position)) then $idx:sense-boost?($position) else 1
  return $result (: if($all-senses = 1) then $result * 5 else $result :)
 };

declare variable $idx:app-root :=
    let $rawPath := system:get-module-load-path()
    return
        (: strip the xmldb: part :)
        if (starts-with($rawPath, "xmldb:exist://")) then
            if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) then
                substring($rawPath, 36)
            else
                substring($rawPath, 15)
        else
            $rawPath
    ;
declare variable $idx:taxonomy-root := doc($idx:app-root || "/data/about/LeDIIR-FACS-about.xml");

declare variable $idx:taxonomies := 
    if(exists($idx:taxonomy-root)) then
    let $categories := $idx:taxonomy-root//tei:teiHeader//tei:taxonomy[@xml:id != 'LeDIIR.taxonomy']
    return map:merge( for $category in $categories//tei:category
        let $terms := map:merge(for $desc in $category/tei:catDesc return 
              map {
               $desc/@xml:lang/data() :
               map {
               "id" : $desc/tei:idno/data(),
               "term" : $desc/tei:term/data()
               }
               }
              )
        return map 
        { 
            $category/@xml:id/data() :
             $terms
        }
    )
    else map {}
  ;

declare variable $idx:parentheses-only := '\(([^()]+)\)';
declare variable $idx:parentheses-regex := "^\([^()]*\)$|^\([^()]*$|^[^()]*\)$";
declare variable $idx:tokenizer-regex := "\p{Po}?\s";


declare function idx:move-parentheses-to-end($input as xs:string) as xs:string {
    let $analysys := analyze-string($input, $idx:parentheses-only)
    return string-join(($analysys//fn:non-match, $analysys//fn:match), ' ')  => normalize-space()
};

declare function idx:remove-parentheses($text as xs:string) as xs:string {
  let $tokens := tokenize($text, $idx:tokenizer-regex)
  let $tokens := $tokens[not(matches(., $idx:parentheses-regex))]
  return string-join($tokens, " ")
};

declare function idx:process-parentheses($text as xs:string, $todo as xs:string) as xs:string {
if(contains($text, '(')) then
  switch($todo)
          case "remove"
              return idx:remove-parentheses($text)
          case "move"
              return idx:move-parentheses-to-end($text)
          default
              return $text
         else $text
};
declare function idx:process-parentheses($text as xs:string) as xs:string {
    idx:process-parentheses($text, $idx:parentheses-todo)
};

declare function idx:concatenate-emulated-text($text as xs:string, $previous as xs:string*) as xs:string* {

  let $before := functx:substring-before-last($text, " ")
  return
  if ($before = "") then
     ($previous,  $text)
  else
    idx:concatenate-emulated-text($before, ($previous, $text))
};

declare function idx:emulate-payload ($text as xs:string, $sense-boost as xs:integer, $frequency as xs:integer) as xs:string 
{ 
  let $clean := idx:process-parentheses($text)
  
  return if($idx:payload-todo) then
    let $emulated := idx:concatenate-emulated-text($clean, ())
    let $emulated := if($sense-boost <= 1) then $emulated
      else
        for $i in (1 to $sense-boost)
          return $emulated
    let $result := if($idx:parentheses-todo = "move" and $clean != $text)
       then ($emulated, idx:process-parentheses($text, "move"))
      else $emulated
    let $result := for $item in $result
      order by string-length($item)
      return $item 
  
    return string-join($result, "&#xa;")
  else
    $clean

 };

(:~
 : Helper function called from collection.xconf to create index fields and facets.
 : This module needs to be loaded before collection.xconf starts indexing documents
 : and therefore should reside in the root of the app.
 :)
declare function idx:get-metadata($root as element(), $field as xs:string) {
    let $header := $root/tei:teiHeader
    return if($root instance of element(tei:sense)) then
      idx:get-sense-metadata($root, $field)
    else if($root instance of element(tei:seg)) then
       idx:get-seg-metadata($root, $field)
     else if($root instance of element(tei:ref) and $root[@type="reversal"]) then
       idx:get-reversal-metadata($root, $field)
    (: do not index copy of the entry, only original entries shoud be found :)
    else if($root instance of element(tei:entry) and $root[@copyOf]) then
        ()
    else
    
        switch ($field)
            case "title" return
                string-join((
                    $header//tei:msDesc/tei:head, $header//tei:titleStmt/tei:title[@type = 'main'],
                    $header//tei:titleStmt/tei:title,
                    $root/dbk:info/dbk:title
                ), " - ")
            case "author" return (
                $header//tei:correspDesc/tei:correspAction/tei:persName,
                $header//tei:titleStmt/tei:author,
                $root/dbk:info/dbk:author
            )
            case "language" return
                head((
                    $header//tei:langUsage/tei:language[@role='objectLanguage']/@ident,
                    $root/@xml:lang,
                    $header/@xml:lang
                ))
            case "date" return head((
                $header//tei:correspDesc/tei:correspAction/tei:date/@when,
                $header//tei:sourceDesc/(tei:bibl|tei:biblFull)/tei:publicationStmt/tei:date,
                $header//tei:sourceDesc/(tei:bibl|tei:biblFull)/tei:date/@when,
                $header//tei:fileDesc/tei:editionStmt/tei:edition/tei:date,
                $header//tei:publicationStmt/tei:date
            ))
            case "title[@type=main|full]-content"         return string-join((
                                                               $header//tei:msDesc/tei:head,
                                                               $header//tei:titleStmt/(tei:title[@type = ('main', 'full')]|tei:title)[1]
                                                               ) ! normalize-space(), " - ")
            case "entry" return idx:get-entry-index($root)
            case "sortKey" return idx:get-sortKey($root) (: if($root/@sortKey)
              then $root/@sortKey
              else $root//tei:form[@type=('lemma', 'variant')][1]/tei:orth[1] :)
            case "sortKeyWithFrequency" return idx:get-sortKey-with-frequency($root)
            case "letter" return $root/ancestor-or-self::tei:div[@type='letter']/tei:head[@type='letter']/data()
            case "chapterId" return $root/ancestor-or-self::tei:div[1]/@xml:id
            case "chapter" return $root/ancestor-or-self::tei:div[@type='letter']/@n
            case "lemma" return $root/tei:form[@type=('lemma', 'variant')]/tei:orth
            case "headword" return idx:get-headword($root)
            case "object-language" return idx:get-object-language($root)
            case "target-language" return idx:get-target-language($root)
            case "definition" return idx:get-definition-index($root) (: $root//tei:sense//tei:def/normalize-space(.) :)
            case "example" return $root//tei:sense//tei:cit[@type='example']/tei:quote
            case "translation" return $root//tei:sense//tei:cit[@type='example']/tei:cit[@type='translation']/tei:quote
            case "partOfSpeech" return $root//tei:gram[@type='pos']
            case "partOfSpeechAll" return idx:get-pos($root)
            case "pronunciation" return $root/tei:form[@type=('lemma', 'variant')]/tei:pron
            case "complexForm" return $root/tei:entry[@type='complexForm']/tei:form//tei:orth/translate(., " ", "")
            case "reversal" return $root//tei:xr[@type='related' and @subtype='Reversals']/tei:ref[@xml:lang=('en', 'cs-CZ', 'cs')]
            case "reversal-en" return $root//tei:xr[@type='related' and @subtype='Reversals']/tei:ref[@xml:lang=('en')]
            case "reversal-cz" return $root//tei:xr[@type='related' and @subtype='Reversals']/tei:ref[@xml:lang=('cs-CZ', 'cs')]
            case "domain" return idx:get-domain($root)
            case "domainHierarchy" return idx:get-domain-hierarchy($root)
            case "style" return $root//tei:usg[@type='textType']
            case "styleAll" return idx:get-style($root)
            case "category-idno" return $root/tei:idno
            case "category-term" return $root/tei:term
            case "polysemy" return count($root[not(parent::tei:entry)]//tei:sense)
            case "frequencyScore" return idx:get-frequency-boost($root)
            case "frequency" return $root//tei:usg[@type='frequency']/@value/tokenize(., '-')[1] ! substring(., 2)
            case "complexFormType" return idx:get-complex-form-type($root)
            default return
                ()
};

declare function idx:get-headword($root as element()) {
let $lemma := $root/tei:form[@type=('lemma', 'variant')] 
return (
    $lemma/tei:orth, $lemma/tei:pron,
    $root/tei:sense/tei:def/tei:seg[@type='equivalent'], 
    $root//tei:ref[@type='reversal'])
};

declare function idx:get-reversal-metadata($root as element(), $field as xs:string) {
    let $entry := $root/ancestor::tei:entry[1]
    let $sense := $root/ancestor::tei:sense
    let $sense-position := count($sense/preceding-sibling::tei:sense) + 1
    let $sense-count := count($entry//tei:sense)

 return if($entry[@copyOf]) then
        ()
    else
      switch ($field)
          case "reversal"
              return $root/text()/normalize-space()[. != '']
          case "sensePositionBoost"
                return
                    idx:get-sense-boost($sense-position, $sense-count)
          case "senseUniquenessBoost"
              return idx:get-sense-uniqueness-boost($sense-position, $sense-count)
          case "language" 
                return $root/@xml:lang
          default 
              return ()
};

declare function idx:get-seg-metadata($root as element(), $field as xs:string) {

    
    let $entry := $root/ancestor::tei:entry[1]
    let $sense := $root/ancestor::tei:sense
    let $sense-position := count($sense/preceding-sibling::tei:sense) + 1
    let $sense-count := count($entry//tei:sense)

    return if($entry[@copyOf]) then
        ()
    else
      switch ($field)
          case "equivalent"
              return $root/text()/normalize-space()[. != '']
          case "equivalentPositionBoost"
              return idx:get-equivalent-position-boost(xs:integer($root/@n))
          case "corpusFrequencyBoost"
              return idx:get-frequency-boost($entry)
          case "sensePositionBoost"
                return
                    idx:get-sense-boost($sense-position, $sense-count)
          case "senseUniquenessBoost"
              return idx:get-sense-uniqueness-boost($sense-position, $sense-count)
          case "sortKey" 
                return idx:get-sortKey($entry)
          default 
              return ()
    
};

declare function idx:get-sense-metadata($root as element(), $field as xs:string) {
  let $entry := $root/ancestor::tei:entry
  let $sense-number := $root/count(preceding-sibling::tei:sense) + 1
  let $all-senses := count($entry//tei:sense)
  return
  switch ($field)
    case "definition" return idx:get-definition-index($root, 0)
    case "senseScore" return idx:get-sense-boost($sense-number, $all-senses)
    case "frequencyScore" return idx:get-frequency-boost($entry)
    default 
      return ()
};

declare function idx:get-definition-index($sense as element(), $position as xs:integer) {
  let $text := string-join($sense//tei:def/normalize-space(), " ")
  return if($text = "") then ()
    else
      let $sense-boost := idx:get-sense-boost($position)
      return idx:emulate-payload($text, $sense-boost, 1)
};

declare function idx:get-definition-index($entry as element()) { 
    
    for $sense at $i in $entry//tei:sense
        return idx:get-definition-index($sense, $i)
(:
        let $text := string-join($sense//tei:def/normalize-space(), " ")
        let $sense-boost := idx:get-sense-boost($i)
        return if($text = "") then ()
             else
                idx:emulate-payload($text, $sense-boost, 1)
:)
};

declare function idx:get-frequency-boost($entry as element()) { 
let $frequency := $entry/tei:usg[@type='frequency'][1]/@value/tokenize(., '-')[1] ! substring(., 2)
    let $frequency := idx:get-frequency-boost-number($frequency)
    return $frequency
};

declare function idx:get-entry-metadata($entry as element(), $field as xs:string) { 
    
        switch ($field)
            case "sortKey" return idx:get-sortKey($entry)
            default return ()
};

declare function idx:get-entry-index($entry as element()) as xs:string* { 
    let $elements := for $element in $entry/*[not(self::tei:entry)]//*[not(*)]
        return if($element[self::tei:pc] or $element[self::tei:lbl[@type='cross-rerefence']]) then () else $element
    for $element in $elements
        let $terminology := if ($element/@ana) then
            idx:get-values-from-terminology($entry, $element/@ana)
            else ()
        return ($terminology, $element/@expand/data(), $element/text())
};


declare function idx:get-sortKey ($entry as element()?) as xs:string {
    if (empty($entry)) then ()
    else
    if($entry/@sortKey)
              then $entry/@sortKey
              else $entry//tei:form[@type=('lemma', 'variant')][1]/tei:orth[1]
};
declare function idx:get-sortKey-with-frequency($entry as element()?) as xs:string {
    if (empty($entry)) then ()
    else
    let $frequency := idx:get-frequency($entry)
    let $frequency := if(empty($frequency) or $frequency = '') then "Z-" else $frequency || "-"
    return $frequency || idx:get-sortKey($entry)
};

declare function idx:get-frequency($entry as element()?) as xs:string? {
    $entry//tei:usg[@type='frequency']/@value/tokenize(., '-')[1] ! substring(., 2)
};
declare function idx:get-domain-hierarchy($entry as element()?) {
if(not(exists($idx:taxonomy-root))) 
then ()
else
if (empty($entry)) then ()
else
(: let $root := root($entry) :)
let $root := $idx:taxonomy-root
let $targets := $entry//tei:usg[@type='domain']
let $ids := if (empty($targets)) then ()
    else $targets/substring-after(@ana, '#')

return if (empty($ids))
            then ()
            else
            idx:get-hierarchical-descriptor($ids, $root)
};

(:~
 : Helper functions for hierarchical facets with several occurrences in a single document of the same vocabulary
 :)
declare function idx:get-hierarchical-descriptor($keys as xs:string*, $root as item()) {
  array:for-each (array {$keys}, function($key) {
        if(exists(id($key,$root))) then
        id($key,$root)
        /ancestor-or-self::tei:category/tei:catDesc[@xml:lang='en']/concat(tei:idno, ' ', tei:term)
        else ()
    })
};

declare function idx:get-domain($entry as element()?) {
    for $target in $entry//tei:usg[@type='domain']
    return $target/concat(tei:idno, ' ', tei:term)
    (:
    for $target in $entry//tei:usg[@type='domain']/@ana
    let $category := id(substring($target, 2), root($entry))
    return
       $category/ancestor-or-self::tei:category[(parent::tei:category or parent::tei:taxonomy)]/tei:catDesc[@xml:lang='en']/concat(tei:idno, ' ', tei:term)
    :)

};

declare function idx:get-complex-form-type($entry as element()?) {
    idx:get-values-from-terminology($entry, $entry//tei:entry[@type='complexForm'][contains(@ana, 'complexFormType')]/@ana)
    (:
    for $target in $entry//tei:ref[@type='entry'][contains(@ana, 'complexFormType')]/@ana
        let $category := id(substring($target, 2), root($entry))
    return $category/ancestor-or-self::tei:category[(parent::tei:category or parent::tei:taxonomy)]/tei:catDesc/(tei:idno | tei:term)
    :)
};


declare function idx:get-style($entry as element()?) {
    idx:get-values-from-terminology($entry, $entry//tei:usg[@type='textType']/@ana)
    (:
    for $target in $entry//tei:usg[@type='textType']/@ana
        let $category := id(substring($target, 2), root($entry))
    return $category/ancestor-or-self::tei:category[(parent::tei:category or parent::tei:taxonomy)]/tei:catDesc/(tei:idno | tei:term)
    :)
};

declare function idx:get-pos($entry as element()?) {
    idx:get-values-from-terminology($entry, $entry//tei:gram/@ana)
    (:
    let $category := id(substring($target, 2), root($entry))
    return
        $category/ancestor-or-self::tei:category[(parent::tei:category or parent::tei:taxonomy)]/tei:catDesc/(tei:idno | tei:term)
    :)
};

declare function idx:get-values-from-terminology($entry as element()?, $targets as item()*) {
    
    (: idx:get-taxonomy($targets) :)
    if(exists($idx:taxonomy-root))
        then    
        for $target in $targets
        (: let $category := id(substring($target, 2), root($entry))  :)
        let $category := id(substring($target, 2), $idx:taxonomy-root)
        let $description := if(exists($category)) then
            $category/ancestor-or-self::tei:category[(parent::tei:category or parent::tei:taxonomy)]/tei:catDesc
            else ()
        return if(exists($description)) then
            ($description/tei:idno, $description/tei:term)
            else ()

    else ()
};


declare function idx:get-object-language($entry as element()?) {
    for $target in $entry//tei:form[@type=('lemma', 'variant')]/tei:orth[@xml:lang]
    let $category := $target/@xml:lang
    return
        $category
};

declare function idx:get-target-language($entry as element()?) {
    for $target in $entry//(tei:def | tei:cit[@type='translation'])
    let $category := $target/@xml:lang
    return
        $category
};