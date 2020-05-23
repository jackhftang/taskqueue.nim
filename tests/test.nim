import unittest
import taskqueue
import asyncdispatch

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
    # define times
    let t0 = initTimestamp(0)
    let t1 = t0 + 500*MILLI_SECOND
    let t2 = t1 + SECOND
    let t3 = t2 + SECOND

    var t = t0
    let q = newTaskQueue()
    q.now = proc(): Timestamp = t

    var history: seq[Timestamp]
    q.runEvery t1, SECOND:
      history.add q.now()
      # 10ms process time
      t = t + 10*MILLI_SECOND 
      

    # before start time
    t = t1 - NANO_SECOND
    q.process()
    check: history.len == 0

    # at start time
    t = t1
    q.process()
    check: history == @[t1]
    check: q.len == 1

    # before 1st recurrent time
    t = t2 - NANO_SECOND
    q.process()
    check: history.len == 1

    # at 1st recurrent time
    t = t2
    q.process()
    check: history == @[t1, t2]
    check: q.len == 1

    # before 2nd recurrent time
    t = t3 - NANO_SECOND
    q.process()
    check: history == @[t1, t2]
    check: q.len == 1

    # at 2nd recurrent time
    t = t3
    q.process()
    check: history == @[t1, t2, t3]
    check: q.len == 1
  
  testScoped "runAround()":
    # define times
    let t0 = initTimestamp(0)
    let t1 = t0 + 500*MILLI_SECOND
    let t2 = t1 + SECOND
    let t3 = t2 + SECOND
    let pt = 10*MILLI_SECOND

    var t = t0
    let q = newTaskQueue()
    q.now = proc(): Timestamp = t

    var history: seq[Timestamp]
    q.runAround t1, SECOND:
      history.add q.now()
      t = t + pt

    # before startTime
    t = t1 - NANO_SECOND
    q.process()
    check: history.len == 0

    # at startTime
    t = t1
    q.process()
    check: history == @[t1]
    check: q.len == 1

    # before 1st recurrent time
    t = t2 + pt - NANO_SECOND
    q.process()
    check: history == @[t1]
    check: q.len == 1

    # at 1st recurrent time
    t = t2 + pt
    q.process()
    check: history == @[t1, t2+pt]
    check: q.len == 1

    # # before 2nd recurrent time
    t = t3 + 2*pt - NANO_SECOND
    q.process()
    check: history == @[t1, t2+pt]
    check: q.len == 1

    # at 2nd recurrent time
    t = t3 + 2*pt
    q.process()
    check: history == @[t1, t2+pt, t3+2*pt]
    check: q.len == 1

  testScoped "exec() and stop()":
    let q = newTaskQueue()
    var called = false
    q.runAt q.now() + 500*MICRO_SECOND:
      q.stop()
      called = true
    q.exec()
    assert called

  testScoped "poll() and stop()":
    let q = newTaskQueue()
    var called = false
    q.runAt q.now() + 500*MICRO_SECOND:
      q.stop()
      called = true
    waitFor q.poll()
    assert called


    
    
    
