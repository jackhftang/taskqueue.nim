import heapqueue
import timestamp
import asyncfutures
import asyncdispatch
import math

export timestamp

type
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

# proc newTask*(t: Timestamp, action: Action): Task = 
#   Task(time: t, action: action) 

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

# template runAt*(q: TaskQueue, time: untyped, body: untyped) =
#   ## Template version of runAt
#   runnableExamples:
#     import taskqueue
#     let q = newTaskQueue()
#     q.runAt q.now() + 3*SECOND:
#       echo "Some Task"
#   q.runAt Task(time: time, action: proc() {.gcsafe.} = `body`)

proc runEvery*(q: TaskQueue, firstTime: Timestamp, interval: int64, action: Action) =
  proc loop() {.gcsafe.} =
    action()
    let d = q.now() - firstTime
    let n = floorDiv(d, interval)
    let target = firstTime + (n+1)*interval
    q.runAt(target, loop)
  q.runAt(firstTime, loop)

# template runEvery*(q: TaskQueue, startTime: Timestamp, interval: untyped, body: untyped) =
#   q.runEvery(startTime, interval, proc() {.gcsafe.} = `body`)

proc len*(q: TaskQueue): int = 
  ## Number of task on queue
  q.queue.len

# proc `[]`*(q: TaskQueue, i: int): Task = q.queue[i]

proc process*(q: TaskQueue, time: Timestamp) =
  ## Run all tasks that is scheduled on or before `time`.
  ## 
  ## Tasks will be processed in the order of scheduled time.
  ## If in case two tasks are scheduled on the same time, 
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
  ## It uses `addTimer` in `asyncdispatch` internally. 
  ## Use this if `interval` precision is enough for your case.

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

  # q.active = true
  # while q.active:
  #   await sleepAsync(interval)
  #   if q.active: q.process()
    
proc exec*(q: TaskQueue) =
  ## Run `process()` in a tight loop until `stop()` is called.
  ## 
  ## This will consume near 100% cpu time. This is necessary to have high-precision scheduler.
  ## 
  ## This procedure blocks, run in other thread if you use asyncdispatch. 
  q.active = true
  while q.active:
    q.process()

  
    
    
  

