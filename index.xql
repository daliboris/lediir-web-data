xquery version "3.1";

module namespace idx="http://teipublisher.com/index";

declare namespace array = "http://www.w3.org/2005/xpath-functions/array";
declare namespace map = "http://www.w3.org/2005/xpath-functions/map";


declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace dbk="http://docbook.org/ns/docbook";

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
  ;

declare function idx:get-taxonomy($keys as xs:string*) {
    let $inner := function($vk, $vv) {$vv}
    let $values := function($k, $v) {
      concat($v("id"), ' ', $v("term"))
    }

    for $key in $keys
        let $id := substring($key, 2)
        let $taxonomy := $idx:taxonomies($id)
        return if(empty($taxonomy)) then () else map:for-each($taxonomy, $values)
};

(:~
 : Helper function called from collection.xconf to create index fields and facets.
 : This module needs to be loaded before collection.xconf starts indexing documents
 : and therefore should reside in the root of the app.
 :)
declare function idx:get-metadata($root as element(), $field as xs:string) {
    let $header := $root/tei:teiHeader
    return
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
            case "headword" return let $lemma := $root/tei:form[@type=('lemma', 'variant')] return ($lemma/tei:orth, $lemma/tei:pron, $root//tei:ref[@type='reversal'])
            case "object-language" return idx:get-object-language($root)
            case "target-language" return idx:get-target-language($root)
            case "definition" return $root//tei:sense//tei:def/normalize-space(.)
            case "example" return $root//tei:sense//tei:cit[@type='example']/tei:quote
            case "translation" return $root//tei:sense//tei:cit[@type='example']/tei:cit[@type='translation']/tei:quote
            case "partOfSpeech" return $root//tei:gram[@type='pos']
            case "partOfSpeechAll" return idx:get-pos($root)
            case "pronunciation" return $root/tei:form[@type=('lemma', 'variant')]/tei:pron
            case "complexForm" return $root/tei:entry[@type='complexForm']/tei:form//tei:orth/translate(., " ", "")
            case "reversal" return $root//tei:xr[@type='related' and @subtype='Reversals']/tei:ref[@xml:lang=('en', 'cs-CZ')]
            case "domain" return idx:get-domain($root)
            case "domainHierarchy" return idx:get-domain-hierarchy($root)
            case "style" return $root//tei:usg[@type='textType']
            case "styleAll" return idx:get-style($root)
            case "category-idno" return $root/tei:idno
            case "category-term" return $root/tei:term
            case "polysemy" return count($root[not(parent::tei:entry)]//tei:sense)
            case "frequency" return $root//tei:usg[@type='frequency']/@value/tokenize(., '-')[1] ! substring(., 2)
            case "complexFormType" return idx:get-complex-form-type($root)
            default return
                ()
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
        id($key,$root)
        /ancestor-or-self::tei:category/tei:catDesc[@xml:lang='en']/concat(tei:idno, ' ', tei:term)
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
    
    for $target in $targets
     (: let $category := id(substring($target, 2), root($entry))  :)
     let $category := id(substring($target, 2), $idx:taxonomy-root)
     let $description := $category/ancestor-or-self::tei:category[(parent::tei:category or parent::tei:taxonomy)]/tei:catDesc
    return
        ($description/tei:idno, $description/tei:term)
    
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