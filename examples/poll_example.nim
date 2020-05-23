import taskqueue
import asyncdispatch 

proc main() =
  let q = newTaskQueue()

  # schedule to stop q 500ms later
  let startTime = q.now()
  q.runAt startTime + 500*MILLI_SECOND:
    let endTime = q.now()
    let diff = (endTime -  startTime).inMilliSecond
    echo "endTime - startTime = ", diff, "ms"
    q.stop()

  # call process periodically
  waitFor q.poll()

when isMainModule:
  main()