xquery version "3.1";

declare namespace idx="http://teipublisher.com/index";

declare namespace q = "http://teilex0/ns/xquery/query"; 
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace functx = "http://www.functx.com";
declare namespace exist = "http://exist.sourceforge.net/NS/exist";


declare variable $q:collection external := "/db/apps/lediir-data/data/dictionaries";
declare variable $q:query external := "cesty";
declare variable $q:field external := "definition";
declare variable $q:max-items external := 20;
declare variable $q:field-boost external := 1;


declare variable $idx:parentheses-todo := "keep"; (: "remove" | "move" | "keep" :)


declare variable $idx:frequency-boost := map {
    'A' : 50,
    'B' : 40,
    'C' : 30,
    'D' : 20,
    'E' : 10,
    'R' : 1,
    'X' : 1
 };

declare variable $idx:sense-boost := map {
  1 : 10,
  2 : 5,
  3 : 1
 };

 
declare function functx:add-attributes
        ( $elements as element()*,
        $attrNames as xs:QName*,
        $attrValues as xs:anyAtomicType* ) as element()* {
                for $element in $elements
                        return element { node-name($element)}
                { for $attrName at $seq in $attrNames
                        return if ($element/@*[node-name(.) = $attrName])
                                then ()
                                else attribute {$attrName}
                        {$attrValues[$seq]},
                        $element/@*,
                        $element/node() 
                }
};


let $maps-to-text := function($k, $v) {concat($k, ' ~ ', $v)}

let $text-in-parentheses := switch($idx:parentheses-todo)
        case "remove"
               return "odstraněn"
        case "move"
               return "přesunut na konec"
        default
               return "beze změn"

let $preprocessing := concat( "text v závorkách (kontextové poznámky) ", $text-in-parentheses, "; ")

let $preprocessing := $preprocessing || "posílení frekvence: " || string-join(map:for-each($idx:frequency-boost, $maps-to-text), " => ") || "; "
let $preprocessing := $preprocessing || "posílení čísla významu: " || string-join(map:for-each($idx:sense-boost, $maps-to-text), " => ")

let $query := <exist:query field="{$q:field}" query="{$q:query}" boost="{$q:field-boost}" sort="score * frequencyScore" preprocessing="{$preprocessing}" />


let $items := collection($q:collection)//tei:entry[
        ft:query(
                ., $q:field || ":" || $q:query || "^" || $q:field-boost, 
                map { "leading-wildcard": "yes", "filter-rewrite": "yes", "fields": ("frequencyScore")  }
        )]
let $items := for $item in $items 
let $frequencyScore := ft:field($item, "frequencyScore", "xs:integer")
let $score := ft:score($item) * $frequencyScore
order by ($score) descending
return  (<exist:score value="{$score}" 
                score="{ft:score($item)}" 
                frequencyScore="{$frequencyScore}" 
                ref="#{$item/@xml:id}" />, 
        util:expand($item)
)

return <body xmlns="http://www.tei-c.org/ns/1.0" xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:exist="http://exist.sourceforge.net/NS/exist">{($query, $items)}</body>