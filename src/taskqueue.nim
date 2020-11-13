import heapqueue
import timestamp
import asyncfutures
import asyncdispatch
import math

export timestamp

type
  NoTaskError* = object of CatchableError
    taskQueue: TaskQueue

  Action* = proc() {.gcsafe.}

  Task = object
    time: Timestamp
    action: Action

  TaskQueue* = ref object
    active: bool
    queue: HeapQueue[Task]
    now*: proc(): Timestamp {.gcsafe.}

proc `<`(a,b: Task): bool = a.time < b.time

proc isRunning*(q: TaskQueue): bool = q.active

proc newTaskQueue*(): TaskQueue =
  ## Create a new Task Scheduler
  TaskQueue(
    active: false,
    queue: initHeapQueue[Task](),
    now: proc(): Timestamp = initTimestamp()
  )

proc runAt(q: TaskQueue, task: Task) =
  q.queue.push task

proc runAt*(q: TaskQueue, time: Timestamp, action: Action) =
  ## Schedule a task to run at `time`
  q.runAt Task(time: time, action: action)


template runEvery*(q: TaskQueue, firstTime: Timestamp, interval: Timespan, body: untyped) =
  ## Process task at `firstTime` and then 
  ## schedule the next one at *t* = `firstTime` + i * `interval` 
  ## where i is the smallest *whole number* such that *t* is larger than current time.
  block:
    let action = proc(): bool {.gcsafe.} =
      `body`
    proc loop() {.gcsafe.} =
      if action(): return
      let d = q.now() - firstTime
      let n = floorDiv(d.i64, interval.i64)
      let target = firstTime + (n+1)*interval
      q.runAt(target, loop)
    q.runAt(firstTime, loop)

template runAround*(q: TaskQueue, firstTime: Timestamp, timespan: Timespan, body: untyped) =
  ## Process task at `firstTime` and then 
  ## schedule the next one `timespan` later than current time.
  block: 
    let action = proc(): bool {.gcsafe.} = 
      `body`
    proc loop() {.gcsafe.} =
      if action(): return
      q.runAt(q.now() + timespan, loop)
    q.runAt(firstTime, loop)

proc len*(q: TaskQueue): int = 
  ## Number of task on queue
  q.queue.len

proc nextTaskTime*(q: TaskQueue): Timestamp = 
  ## Get the executing time of the next task
  ## raise NoTaskError if q is empty
  if q.len == 0: 
    let err = newException(NoTaskError, "TaskQueue is empty")    
    err.taskQueue = q
    raise err
  result = q.queue[0].time

proc process*(q: TaskQueue, time: Timestamp) =
  ## Run all tasks that is scheduled on or before `time`.
  ## 
  ## Tasks will be processed in the order of scheduled time.
  ## In case two tasks are scheduled on the same time, 
  ## the order of processing is undefined.
  ##  
  ## This is useful to control task processing manually.
  
  while q.queue.len > 0 and q.queue[0].time <= time: 
    let task = q.queue.pop()
    task.action()

proc process*(q: TaskQueue) {.inline.} = 
  ## Equivalent to `q.process(q.now())`
  q.process(q.now())

proc stop*(q: TaskQueue) =
  ## Stop `poll()` or `exec()`
  q.active = false

proc poll*(q: TaskQueue, interval: int = 16): Future[void] =
  ## Run `process()` for every `interval` until `stop()`
  ## 
  ## Internally uses `addTimer` in `asyncdispatch`.
  var ret = newFuture[void]()
  result = ret

  proc loop(fd: AsyncFD): bool {.gcsafe.} =
    if q.active: 
      q.process()
      if q.active:
        addTimer(interval, true, loop)
      else:
        ret.complete()
    else:
      ret.complete()

  q.active = true
  addTimer(interval, true, loop)
    
proc exec*(q: TaskQueue) =
  ## Run `process()` in a while loop until `stop()` is called.
  ## 
  ## This procedure **blocks**, run in other thread if needed.
  q.active = true
  while q.active:
    q.process()

proc execRelaxed*(q: TaskQueue) =
  q.active = true
  while q.active:
    if q.queue.len > 0:
      q.process()
    else:
      cpuRelax()

# type CancelableAction* = proc(): bool {.gcsafe.}

# proc runEveryProc*(q: TaskQueue, firstTime: Timestamp, interval: Timespan, callback: CancelableAction) =
#   ## Callback version of `runEvery`
#   q.runEvery(firstTime, interval):
#     return callback()

# proc runAroundProc*(q: TaskQueue, firstTime: Timestamp, timespan: Timespan, callback: CancelableAction) =
#   ## Callback version of `runAroundProc`
#   # q.runAround(firstTime, timespan):
#   #   result = callback()
#   proc loop() {.gcsafe.} =
#     if callback(): return
#     q.runAt(q.now() + timespan, loop)
#   q.runAt(firstTime, loop)
