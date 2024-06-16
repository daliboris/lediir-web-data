xquery version "3.1";

module namespace upld="https://eldi.soc.cas.cz/api/upload";


import module namespace roaster="http://e-editiones.org/roaster";
import module namespace unzip="http://joewiz.org/ns/xquery/unzip" at "unzip.xql";
import module namespace config = "http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace idx = "http://teilex0/ns/xquery/index" at "report.xql";
import module namespace console="http://exist-db.org/xquery/console";


declare namespace errors = "http://e-editiones.org/roaster/errors";
declare namespace map = "http://www.w3.org/2005/xpath-functions/map";

declare variable $upld:NOT_FOUND := xs:QName("errors:NOT_FOUND_404");

declare variable $upld:channel := "upload";

declare option exist:serialize "method=xml media-type=application/xml";


declare function upld:upload($request as map(*)) {
    let $start-time as xs:time := util:system-time()
    return
    try {
        let $name := request:get-uploaded-file-name("file")
        let $data := request:get-uploaded-file-data("file")
        let $upload-result := upld:upload($request?parameters?collection, $name, $data)
        let $end-time as xs:time := util:system-time()
    (: let $log := console:log($upld:channel, "$name: " || $name) :)
    return
        (: roaster:response(201, map { 
                "uploaded": $upload:download-path || $file-name }) :)
        (: array { upld:upload($request?parameters?collection, $name, $data) } :)
        roaster:response(201,
        <result file-name="{$name}" start="{$start-time}" end="{$end-time}" duration="{seconds-from-duration($end-time - $start-time)}s">
            {$upload-result}
        </result>
        )
    }
    catch * {
        let $end-time as xs:time := util:system-time()
        (: roaster:response(400, map { "error": $err:description })         :)
        return
        roaster:response(400, <error start="{$start-time}" end="{$end-time}" duration="{seconds-from-duration($end-time - $start-time)}s">{ $err:description }</error>)
    }
        
};


declare %private function upld:upload($root, $paths, $payloads) {
    let $collectionPath := $config:data-root || "/" || $root
    let $result := for-each-pair($paths, $payloads, function($path, $data) {
        let $paths :=
            let $log := console:log($upld:channel, "$collectionPath: " || $collectionPath)
            return
                if (xmldb:collection-available($collectionPath)) then
                
                    if (ends-with($path, ".zip")) then
                        let $stored := xmldb:store($collectionPath, xmldb:encode($path), $data)
                        (: let $log := console:log($upld:channel, "$stored: " || $stored) :)
                        let $unzip := unzip:unzip($stored, true())
                        (: let $log := console:log($upld:channel, "$unzip: " || string-join($unzip//entry/@path, '; ')) :)
                        (: return $unzip//entry/@path :)
                        return $unzip
                    else
                    ()
                else
                    error($upld:NOT_FOUND, "Collection not found: " || $collectionPath)
        return
            $paths
            (:
            for $path in $paths 
                let $size := xmldb:size($collectionPath, $path)
                let $log := console:log($upld:channel, "$size: " || $path || " = " || $size)
            return
                map {
                    "name": $path,
                    "path": substring-after($path, $config:data-root || "/" || $root),
                    "type": xmldb:get-mime-type($path),
                    "size": xmldb:size($collectionPath, $path)
                }
                :)
    })
    return $result
};

declare function upld:clean($request as map(*)) {
    try {
        let $name := $request?parameters?collection
        let $main-collection := tokenize($name, "/")[last()] => lower-case()
        let $collectionPath := $config:data-root || "/" || $name
        return if($main-collection = ("dictionaries", "about", "feedback", "metadata")) then
            roaster:response(400,
            <result>{concat("Cannot delete main collection '", $main-collection, "'.")}</result>
            )
        else if($collectionPath = $config:data-root || "/") then
            roaster:response(400,
            <result>{concat("Cannot delete main collection '", $collectionPath, "'.")}</result>
            )
        else
            
            let $result := xmldb:remove($collectionPath)
            return roaster:response(200,
                <result>Collection {$name} deleted.</result>)

    }
    catch * {
        (: roaster:response(400, map { "error": $err:description })         :)
        roaster:response(400, <error>{ $err:description }</error>)
    }

};

declare function upld:report($request as map(*)) { 
    let $name := $request?parameters?collection
    (: return idx:get-collection-statistics() :)
    return idx:get-index-statistics()
};

(:
let $collection := request:get-parameter("collection", ())
let $pathParam := request:get-parameter("path", ())
let $name := request:get-uploaded-file-name("file[]")
let $path := ($pathParam, $name)[1]
let $data := request:get-uploaded-file-data("file[]")

return
    try {
        upld:upload($collection, $path, $data)
    } catch * {
        map {
            "name": $name,
            "error": $err:description
        }
    }
:)