# comment lines start with a sharp (#)

{
  "type": "#{pick(human,orc,elf,dwarf)}",
  "category": "#{pick(warrior,assassin,thief,wizard)}",
  "ratio": #{random_int(0, 1)}.#{random_int(0, 9)},
  "level": #{random_int(1, 20)},
  "data1": "#{random_string(40)}",
  "data2": "#{random_string(50)}",
  "data3": "#{random_string(35)}",
  "integers": [
      #{random_int(0, 100000)}, #{random_int(0, 100000)},
      #{random_int(0, 100000)}, #{random_int(0, 100000)},
      #{random_int(0, 100000)}, #{random_int(0, 100000)},
      #{random_int(0, 100000)}, #{random_int(0, 100000)},
      #{random_int(0, 100000)}, #{random_int(0, 100000)},
      #{random_int(0, 100000)}, #{random_int(0, 100000)},
      #{random_int(0, 100000)}, #{random_int(0, 100000)}
  ],
  "nested": {
      "coords": [
          { "x": #{random_int(0, 200000)}.#{random_int(0, 100)}, "y": #{random_int(0, 200000)}.#{random_int(0, 100)} },
          { "x": #{random_int(0, 200000)}.#{random_int(0, 100)}, "y": #{random_int(0, 200000)}.#{random_int(0, 100)} },
          { "x": #{random_int(0, 200000)}.#{random_int(0, 100)}, "y": #{random_int(0, 200000)}.#{random_int(0, 100)} },
          { "x": #{random_int(0, 200000)}.#{random_int(0, 100)}, "y": #{random_int(0, 200000)}.#{random_int(0, 100)} },
          { "x": #{random_int(0, 200000)}.#{random_int(0, 100)}, "y": #{random_int(0, 200000)}.#{random_int(0, 100)} }
      ],
      "string1": "#{random_string(23)}",
      "string2": "#{random_string(12)}",
      "string3": "#{random_string(18)}",
      "dict": {
          "#{random_string(8)}": #{random_int(0, 20000)},
          "#{random_string(8)}": #{random_int(0, 70)},
          "#{random_string(8)}": #{random_int(0, 200)},
          "#{random_string(8)}": #{random_int(0, 300000)},
          "#{random_string(8)}": #{random_int(0, 200000)},
          "#{random_string(8)}": #{random_int(0, 9000)},
          "#{random_string(8)}": #{random_int(0, 10000)}
      },
      "values": [
          #{random_int(0, 100000)}, #{random_int(0, 100000)},
          #{random_int(0, 100000)}, #{random_int(0, 100000)},
          #{random_int(0, 100000)}, #{random_int(0, 100000)},
          #{random_int(0, 100000)}, #{random_int(0, 100000)},
          #{random_int(0, 100000)}, #{random_int(0, 100000)}
      ]
  }
#  "_attachments": {
#    "lorem.txt": {
#      "content_type": "text/plain",
#      "data": "#{file(lorem2.txt)}"
#    },
#    "lorem.txt.gz": {
#      "content_type": "application/gzip",
#      "data": "#{file(lorem2.txt.gz)}"
#    }
#  }
}
