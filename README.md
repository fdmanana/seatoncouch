# seatoncouch

A templating utility for populating a CouchDB instance with data.


# template macros

Template macros are have the form:   #{macro_name(param1,param2,param3,...)}

Example document template:

<pre>
{
  "type": "#{pick(human,orc,elf,dwarf)}",
# comment, this will be ignored
  "category": "#{pick(warrior,assassin,thief,paladin,priest,wizard)}",
  "ratio": #{random_int(0, 1)}.#{random_int(0, 9)},
  "level": #{random_int(1, 20)},
# randomly generated base64 string with 5 to 50 characters
  "variable_length_string": "#{random_string(#{random_int(5, 50)})}",
  "integers": [
      #{random_int(0, 100000)}, #{random_int(0, 100000)},
      #{random_int(0, 100000)}, #{random_int(0, 100000)},
      #{random_int(0, 100000)}, #{random_int(0, 100000)}
  ],
  "nested": {
      "coords": [
          {
              "x": #{random_int(0, 200000)}.#{random_int(0, 100)},
              "y": #{random_int(0, 200000)}.#{random_int(0, 100)}
          },
          {
              "x": #{random_int(0, 200000)}.#{random_int(0, 100)},
              "y": #{random_int(0, 200000)}.#{random_int(0, 100)}
          }
      ],
      "string1": "#{random_string(23)}",
      "string2": "#{random_string(12)}",
      "string3": "#{random_string(18)}",
      "dict": {
          "#{random_string(8)}": #{random_int(0, 20000)},
          "#{random_string(8)}": #{random_int(0, 70)},
          "#{random_string(8)}": #{random_int(0, 200)},
          "#{random_string(8)}": #{random_int(0, 10000)}
      }
  }
  "_attachments": {
    "lorem.txt": {
      "content_type": "text/plain",
      "data": "#{file(lorem2.txt)}"
    },
    "#{if(#{random_int(1, 2)} == 1)}hello.md": {
      "content_type": "application/markdown",
      "data": "I will be base64 encoded, and have 50% of chances to be in a real document"
    }
  }
</pre>


# usage

<pre>
$ ./seatoncouch.rb --help

Usage:  seatoncouch.rb [OPTION]*

  Templating tool to populate a CouchDB instance with data.

Options:

  -h, --help                     Displays this help and exits.

      --debug                    Enable debug mode.

      --host                     Name or address of the CouchDB instance.
                                 Defaults to `localhost'

      --port                     Port of the CouchDB instance.
                                 Defaults to `5984'

      --dbs count                Number of DBs to create.
                                 Defaults to `1'

      --bulk-batch doc_count     When uploading documents to CouchDB, use
                                 the _bulk_docs API with doc_count documents
                                 for each POST request to db/_bulk_docs.
                                 By default the _bulk_docs API is not used.

      --docs count               Number of docs to create per DB.
                                 Defaults to `100'

      --revs-per-doc count       The number of revisions each document will
                                 have. Each revision will have exactly the
                                 same data.
                                 Defaults to `1'

      --conflicts-per-doc count  The number of conflicting revisions (leafs)
                                 to create for each inserted document.
                                 By default no conflicts version are created.
                                 Note: this option only works if the bulk batch
                                       option is used as well.

      --threads count            Number of threads to use for uploading
                                 documents and attachments to each DB.
                                 The document IDs range is partitionned
                                 evenly between the threads.
                                 Defaults to `1'

      --users count              Number of users to create.
                                 Defaults to `10'

      --db-start-id number       The ID to assign to the first created DB.
                                 Subsequent DBs will have an ID which is an
                                 increment of this initial ID.
                                 Defaults to `1'

      --db-prefix string         A string prefix to prepend to each DB name.
                                 Defaults to `testdb'

      --doc-start-id number      The ID to assign to the first created doc for
                                 each created DB.
                                 Subsequent docs will have an ID which is an
                                 increment of this initial ID.
                                 Defaults to `1'

      --user-start-id number     The ID to assign to the first created user.
                                 Subsequent users will have an ID which is an
                                 increment of this initial ID.
                                 Defaults to `1'

      --user-prefix string       A string prefix to prepend to each user name.
                                 Defaults to `user'

      --doc-tpl file             The template to use for each doc.
                                 Defaults to `default_doc.tpl'

      --sec-obj file             A file containing the JSON security object
                                 to add to each created DB.
                                 Defaults to none.

      --recreate-dbs             If a DB already exists, it is deleted and created.

      --times                    If specified, CouchDB's response time for each
                                 document and attachment PUT request will be reported
                                 as well as average response times.

      --http-basic-username      Username for HTTP Basic Authentication.

      --http-basic-password      Password for HTTP Basic Authentication.
</pre>