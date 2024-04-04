xquery version "3.1";

declare namespace q = "http://teilex0/ns/xquery/query"; 
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace functx = "http://www.functx.com";


declare variable $q:collection external := "/db/apps/lediir-data/data/dictionaries";
declare variable $q:query external := "cesty";
declare variable $q:field external := "definition";
declare variable $q:max-items external := 20;
declare variable $q:field-boost external := 1;

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
$element/node() }
};

let $query := <p xmlns="http://www.tei-c.org/ns/1.0">
Dotaz: {$q:field} = {$q:query}, boost = {$q:field-boost}
</p>

let $items := collection($q:collection)//tei:entry[
        ft:query(
                ., $q:field || ":" || $q:query || "^" || $q:field-boost, 
                map { "leading-wildcard": "yes", "filter-rewrite": "yes" }
        )]
let $items := for $item in $items 
order by ft:score($item) descending
return   util:expand($item) ! functx:add-attributes($item, (xs:QName("n")), ft:score($item))

return <body xmlns="http://www.tei-c.org/ns/1.0" xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:exist="http://exist.sourceforge.net/NS/exist">{($query, $items)}</body>