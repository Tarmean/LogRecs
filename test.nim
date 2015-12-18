proc newList(): ref seq[(int, int)] =
  newSeq[(int, int)]

proc test(a: ref seq[(int, int)]) =
  for entry in a[]:
    let (c, d) = entry
    echo c

proc go() =
  let 
     list = new seq[(int, int)]

  list[].add((1, 2))
  list[].add((3, 4))
  test(list)
