xquery version "3.1";

import module namespace xmldb="http://exist-db.org/xquery/xmldb";
import module namespace sm="http://exist-db.org/xquery/securitymanager";

(: The following external variables are set by the repo:deploy function :)

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

declare variable $owner := "redaktor";
declare variable $group := "tei";
declare variable $data := "data";
declare variable $data-path := "/data";
declare variable $collection-mode :="rwxrwxr-x";
declare variable $dictionaries := "dictionaries";
declare variable $dictionaries-path := $data-path || "/" || $dictionaries;
declare variable $about := "about";
declare variable $about-path := $data-path || "/" || $about;
declare variable $metadata := "metadata";
declare variable $metadata-path := $data-path || "/" || $metadata;
declare variable $feedback := "feedback";
declare variable $feedback-path := $data-path || "/" || $feedback;



xmldb:create-collection($target, $data),
sm:chmod(xs:anyURI($target || $data-path), $collection-mode),
sm:chown(xs:anyURI($target || $data-path), $owner),
sm:chgrp(xs:anyURI($target || $data-path), $group),
xmldb:create-collection($target || $data-path, $dictionaries),
sm:chmod(xs:anyURI($target || $dictionaries-path), $collection-mode),
sm:chown(xs:anyURI($target || $dictionaries-path), $owner),
sm:chgrp(xs:anyURI($target || $dictionaries-path), $group),
xmldb:create-collection($target || $data-path, $about),
sm:chmod(xs:anyURI($target || $about-path), $collection-mode),
sm:chown(xs:anyURI($target || $about-path), $owner),
sm:chgrp(xs:anyURI($target || $about-path), $group),
xmldb:create-collection($target || $data-path, $metadata),
sm:chmod(xs:anyURI($target || $metadata-path), $collection-mode),
sm:chown(xs:anyURI($target || $metadata-path), $owner),
sm:chgrp(xs:anyURI($target || $metadata-path), $group),
xmldb:create-collection($target || $data-path, $feedback),
sm:chmod(xs:anyURI($target || $feedback-path), $collection-mode),
sm:chown(xs:anyURI($target || $feedback-path), $owner),
sm:chgrp(xs:anyURI($target || $feedback-path), $group)