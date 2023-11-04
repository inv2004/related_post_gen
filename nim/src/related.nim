import std/[hashes, monotimes, times, strformat]
import pkg/[jsony, xxhash]
import fixedtable

type
  Post = ref object
    `"_id"`: string
    title: string
    tags : seq[string]
    top5: array[5, tuple[idx: int, cnt: uint8]]

const
  input = "../posts.json"
  output = "../related_posts_nim.json"

let posts = input.readFile.fromJson(seq[Post])

func hash(x: string): Hash {.inline.} =
  cast[Hash](XXH3_64bits(x))

proc dumpHook(s: var string, p: Post) {.inline.} =
  s.add fmt"""{{"_id":"{p.`"_id"`}","tags":"""
  dumpHook(s, p.tags)
  s.add ""","related":["""
  for i, idx in p.top5:
    let r = posts[idx.idx]
    if i != 0:
      s.add ","
    s.add fmt"""{{"_id":"{r.`"_id"`}","title":"{r.title}","tags":"""
    dumpHook(s, r.tags)
    s.add '}'  
  s.add """]}"""

proc main() =
  let t0 = getMonotime()

  var tagMap = initTable[string, seq[int]](100)
  for i, post in posts:
    for tag in post.tags:
      tagMap.withValue(tag, val):
        val[].add i
      do:
        tagMap[tag] = @[i]

  for i, p in posts:
    var taggedPostCount = newSeq[uint8](posts.len)

    for tag in p.tags:
      for relatedIDX in tagMap[tag]:
        inc(taggedPostCount[relatedIDX])
    taggedPostCount[i] = 0

    for i, count in taggedPostCount:
      if count > p.top5[4].cnt:
        p.top5[4].idx = i
        p.top5[4].cnt = count
        for pos in countdown(3, 0):
          if count > p.top5[pos].cnt:
            p.top5[pos+1].idx = p.top5[pos].idx
            p.top5[pos].idx = i
            p.top5[pos+1].cnt = p.top5[pos].cnt
            p.top5[pos].cnt = count

  let time = (getMonotime() - t0).inMicroseconds / 1000
  echo "Processing time (w/o IO): ", time, "ms"
  output.writeFile(posts.toJson)

when isMainModule:
  main()
