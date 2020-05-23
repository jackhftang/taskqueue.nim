import taskqueue

proc main() =
  # global logical clock
  var logicalTime = initTimestamp()

  # synchronize logical time of two taskqueues
  let q1 = newTaskQueue()
  let q2 = newTaskQueue()
  q1.now = proc(): Timestamp = logicalTime 
  q2.now = proc(): Timestamp = logicalTime
  
  # schedule to trigger at *logically same* time 
  let target = logicalTime + 50*MILLI_SECOND
  echo "Target time is ", target
  q1.runAt target:
    echo "q1: Current time is ", initTimestamp(), " Logical time is ", q1.now()
  q2.runAt target:
    echo "q2: Current time is ", initTimestamp(), " Logical time is ", q2.now()


  while logicalTime < target:
    logicalTime = initTimestamp()

    # process at logical time 
    q1.process(logicalTime)
    q2.process(logicalTime)


when isMainModule:
  main()