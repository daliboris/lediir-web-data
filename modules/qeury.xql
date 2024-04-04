xquery version "3.1";

declare namespace q = "http://teilex0/ns/xquery/query"; 

declare variable $q:collection external := "/db/apps/lediir-data/data/dictionaries";
declare variable $q:query external := "cesty";
declare variable $q:max-items external := 20;

let $name := "definition"

let $items := collection($q:collection)//tei:entry[
        ft:query(., $name || ":" || $q:query, 
        map { "leading-wildcard": "yes", "filter-rewrite": "yes", "fields": ($name) })
        ]
let $items := for $item in $items order by ft:score($item) descending
return $item

return $items