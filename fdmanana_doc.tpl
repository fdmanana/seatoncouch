# comment lines start with a sharp (#)

{
  "_id": "doc#{doc_id_counter}",
  "name": "#{random_string(100)}",
  "address": "#{random_string(200)}",
  "age": #{random_int(1, 100)},
  "children": #{random_int(0, 10)},
  "bio": "#{random_string(10000)}"
}
