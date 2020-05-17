import unittest
import taskqueue

template testScoped(name: string, body: untyped): untyped =
  test `name`:
    proc w() =
      `body`
    w()

suite "taskqueue":

  testScoped "runAt() run at scheduled time":
    let startTime = initTimestamp(0)
    var t = startTime
    let q = newTaskQueue()
    q.now = proc(): Timestamp = t

    var history: seq[Timestamp]
    q.runAt startTime + 10*NANO_SECOND:
      history.add q.now()

    # initially empty
    q.process()
    check: history.len == 0
    # empty before scheduled time
    t = startTime + 9*NANO_SECOND
    q.process()
    check: history.len == 0
    # process at schedule time
    t = startTime + 10*NANO_SECOND 
    q.process()
    check: history == @[initTimestamp(10)]
    # no more task
    check: q.len == 0

  testScoped "runAt() run after scheduled time":
    let startTime = initTimestamp(0)
    var t = startTime
    let q = newTaskQueue()
    q.now = proc(): Timestamp = t

    var history: seq[Timestamp]
    q.runAt startTime + 10*NANO_SECOND:
      history.add q.now()

    # empty before scheduled time
    t = startTime + 9*NANO_SECOND
    q.process()
    check: history.len == 0
    # process after schedule time
    t = startTime + 11*NANO_SECOND 
    q.process()
    check: history == @[initTimestamp(11)]
    # no more task
    check: q.len == 0

  testScoped "runEvery()":
    let startTime = initTimestamp(0)
    var t = startTime
    let q = newTaskQueue()
    q.now = proc(): Timestamp = t

    var history: seq[Timestamp]
    q.runEvery startTime + 500*MILLI_SECOND, SECOND:
      history.add q.now()

    # empty before scheduled time
    t = startTime + 500*MILLI_SECOND - 1 
    q.process()
    check: history.len == 0

    # process at schedule time
    t = startTime + 500*MILLI_SECOND
    q.process()
    check: history == @[startTime + 500*MILLI_SECOND]

    # recurrent task
    check: q.len == 1
    t = startTime + 500*MILLI_SECOND + SECOND - 1
    q.process()
    check: history.len == 1
    t = startTime + 500*MILLI_SECOND + SECOND
    q.process()
    check: history == @[
      startTime + 500*MILLI_SECOND, 
      startTime + 500*MILLI_SECOND + SECOND
    ]
    check: q.len == 1
    

    
