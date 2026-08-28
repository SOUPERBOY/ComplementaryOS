Lunr.js

A bit like Solr, but much smaller and not as bright.

Example

A very simple search index can be created using the following:

    var idx = lunr(function () {
      this.field('title')
      this.field('body')

      this.add({
        "title": "Twelfth-Night",
        "body": "If music be the food of love, play on: Give me excess of it…",
        "author": "William Shakespeare",
        "id": "1"
      })
    })

Then searching is as simple as:

    idx.search("love")

This returns a list of matching documents with a score of how closely
they match the search query as well as any associated metadata about the
match:

    [
      {
        "ref": "1",
        "score": 0.3535533905932737,
        "matchData": {
          "metadata": {
            "love": {
              "body": {}
            }
          }
        }
      }
    ]

API documentation is available, as well as a full working example.

Description

Lunr.js is a small, full-text search library for use in the browser. It
indexes JSON documents and provides a simple search interface for
retrieving documents that best match text queries.

Why

For web applications with all their data already sitting in the client,
it makes sense to be able to search that data on the client too. It
saves adding extra, compacted services on the server. A local search
index will be quicker, there is no network overhead, and will remain
available and usable even without a network connection.

Installation

Simply include the lunr.js source file in the page that you want to use
it. Lunr.js is supported in all modern browsers.

Alternatively an npm package is also available npm install lunr.

Browsers that do not support ES5 will require a JavaScript shim for Lunr
to work. You can either use Augment.js, ES5-Shim or any library that
patches old browsers to provide an ES5 compatible JavaScript
environment.

Features

-   Full text search support for 14 languages
-   Boost terms at query time or boost entire documents at index time
-   Scope searches to specific fields
-   Fuzzy term matching with wildcards or edit distance

Contributing

See the CONTRIBUTING.md file.
