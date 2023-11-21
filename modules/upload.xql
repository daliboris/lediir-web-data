xquery version "3.1";

module namespace capi="http://teipublisher.com/api/collection";


import module namespace unzip="http://joewiz.org/ns/xquery/unzip" at "unzip.xql";
import module namespace config = "http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace console="http://exist-db.org/xquery/console";

declare namespace errors = "http://e-editiones.org/roaster/errors";

declare variable $capi:NOT_FOUND := xs:QName("errors:NOT_FOUND_404");

declare option exist:serialize "method=json media-type=application/json";

(:
declare function capi:upload($request as map(*)) {
    let $name := request:get-uploaded-file-name("files[]")
    let $data := request:get-uploaded-file-data("files[]")
    return
        array { capi:upload($request?parameters?collection, $name, $data) }
};
:)

declare %private function capi:upload($root, $paths, $payloads) {
    for-each-pair($paths, $payloads, function($path, $data) {
        let $path :=
            let $collectionPath := $config:data-root || "/" || $root
            return
                if (xmldb:collection-available($collectionPath)) then
                
                    if (ends-with($path, ".zip")) then
                        let $stored := xmldb:store($collectionPath, xmldb:encode($path), $data)
                        let $log := console:log("$stored: " || $stored)
                        let $unzip := unzip:unzip($stored, true())
                        let $log := console:log($unzip)
                        return $unzip//entry/@path
                    else
                    ()
                else
                    error($capi:NOT_FOUND, "Collection not found: " || $collectionPath)
        return
            map {
                "name": $path,
                "path": substring-after($path, $config:data-root || "/" || $root),
                "type": xmldb:get-mime-type($path),
                "size": 93928
            }
    })
};


let $collection := request:get-parameter("collection", ())
let $pathParam := request:get-parameter("path", ())
let $name := request:get-uploaded-file-name("file[]")
let $path := ($pathParam, $name)[1]
let $data := request:get-uploaded-file-data("file[]")

return
    try {
        capi:upload($collection, $path, $data)
    } catch * {
        map {
            "name": $name,
            "error": $err:description
        }
    }