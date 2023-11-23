# LeDIIR Web Data

Projekt „Elektronická lexikální databáze indoíránských jazyků. Pilotní modul perština“, který je realizován s podporou Technologické agentury ČR ([TAČR](https://www.tacr.cz)) pod reg. č. [TL03000369](https://www.isvavai.cz/cep?ss=detail&n=0&h=TL03000369).

The project "Electronic lexical database of Indo-Iranian languages. Pilot module Persian", which is implemented with the support of the Technology Agency of the Czech Republic ([TAČR](https://www.tacr.cz)) under reg. no. [TL03000369](https://www.isvavai.cz/cep?ss=detail&n=0&h=TL03000369).

## Účel komponenty

**LeDIIR Web Data** slouží jako úložiště slovníkových data a metadat v databázi [eXist-db](https://exist-db.org). Jedná se o samostatný modul, který lze nainstalovat nezávisle na webové aplikaci [LeDIIR Web Application](https://github.com/daliboris/lediir-web-app/).

Struktura úložiště (podkolekce) v hlavní kolekci databáze eXist-db (obvykle `/db/apps/lediir-data/data`):

- `about`
  - obshauje metadata a textové informace o jednotlivých slovnících ve formátu [TEI](https://tei-c.org/release/doc/tei-p5-doc/en/html/index.html)
- `dictionaries`
  - obsahuje heslové stati jednotlivých slovníků v samostatných podkolekcích
- `feedback`
  - ukládá reakce uživatelů z webové aplikace (připomínky k jednotlivým heslovým statím)
- `medatata`
  - obshauje metadata o jednotlicých slovnících (počty hesel, rozčlenění do kapitol)

Slovníková data ve formátu [TEI Lex-0](https://bit.ly/tei-lex-0) se indexují pro fulltextové prohledávání a filtrování. Zpracovávají se následující součásti slovníku, popř. heslové stati:

### Pole (slouží k hledání)

- celá heslová stať (*entry*)
- klíč řazení hesla v kapitole (*sortKey*)
- klíč pro řazení hesla s přihlédnutím k jeho frekvenci v korpusech (*sortKeyWithFrequency*)
- písmeno (*letter*)
- identifikátor kapitoly (*chapterId*)
- označení kapitoly (písmene), (*chapter*)
- heslové slovo (*lemma*)
- základní charakteristiky hesla (heslové slovo, výslovnost, zpětné odkazy) (*headword*)
- významová definici (*definition*)
- doklad (v originálním jazyce) (*example*)
- překlad dokladu (*translation*)
- sémantický okruh (*domain*)
- zpětný odkaz (*reversal*)
- slovní druh (zkrácená i rozepsaná podoba, a to ve všech v podporovaných jazycích) (*partOfSpeechAll*)
- stylové označení významu (zkrácená i rozepsaná podoba, a to ve všech v podporovaných jazycích) (*styleAll*)
- výslovnost (*pronunciation*)
- tvar komplexního hesla (*complexForm*)

### Fasety (slouží k filtrování)

- slovník (*dictionary*)
- písmeno, označení kapitoly (*letter*)
- popisovaný jazyk (*objectLanguage*)
- jazyk popisu (*targetLanguage*)
- slovní druh (*partOfSpeech*)
- sémantický okruh (*domain*)
- sémantický okruh řazený hierarchicky (*domainHierarchy*)
- stylové označení významu (*style*)
- počet významů v heslové stati (*polysemy*)
- frekvenční zastoupení hesla v korpusu (*frequency*)
- typ komplexního hesla (*complexFormType*)

## Prerekvizity

### Vývojářské prostředí

- oXygen XML Editor
- [Visual Studio Code](https://code.visualstudio.com/download)
  - doplněk [existdb-vscode](https://marketplace.visualstudio.com/items?itemName=eXist-db.existdb-vscode); slouží k synchronizaci změn kódu v úložišti a na serveru eXist-db (pouze jednosměrně: souborový systém => databáze)
- [eXist-db](https://exist-db.org)
  - verze [6.0.2](https://github.com/eXist-db/exist/releases/tag/eXist-6.0.2)
  - balíček [atom-editor](https://github.com/eXist-db/atom-editor-support/releases/);  slouží k synchronizaci změn kódu v úložišti a na serveru eXist-db (viz doplněk _existdb-vscode_)
