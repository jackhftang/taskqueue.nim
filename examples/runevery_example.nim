import taskqueue

proc main() =
  let q = newTaskQueue()

  let startTime = q.now() # run immediately

  const N = 1000
  var cnt = 0
  q.runEvery startTime, MILLI_SECOND:
    # see how it drift away
    echo cnt, " ", (q.now() - startTime).inMilliSecond 
    cnt.inc

    # repeat N times and stop
    if cnt >= N: q.stop()

  q.exec()

when isMainModule:
  main()