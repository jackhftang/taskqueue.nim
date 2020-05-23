# Taskqueue.nim

High precision and high performance task scheduler

## Installation

```
$ nimble install taskqueue
```

## API

see [here](https://jackhftang.github.io/taskqueue.nim/)

## Example

Measure the latency of scheduled tasks. 

```nim
import taskqueue
import algorithm
import sequtils
import sugar

proc main() = 
  # create a new task scheduler
  let q = newTaskQueue()
      
  # define T as referenced time
  let T = q.now()

  # schedler N tasks at M interval.
  # take N * M = 10 second to run
  let N = 10000
  let M = MILLI_SECOND

  var latencies = newSeqOfCap[float](N)
  for i in 1..N:
    capture i:
      let targetTime = T + i * M
      q.runAt targetTime:
        latencies.add (q.now() - targetTime).inMilliSecond 

  # scheduler to stop scheduler
  q.runAt T + (N+1) * M:
    q.stop()

  # run in tight loop
  q.exec()

  # display info
  latencies.sort()
  echo "Number of Triggers: ", latencies.len
  echo "Minimum Latency (ms): ", latencies[0]
  echo "25% Percentile (ms): ", latencies[N div 4]
  echo "50% Percentile (ms): ", latencies[N div 2]
  echo "75% Percentile (ms): ", latencies[3*N div 4]
  echo "95% Percentile (ms): ", latencies[95*N div 100]
  echo "99% Percentile (ms): ", latencies[99*N div 100]
  echo "Maximum Latency (ms): ", latencies[^1]
  echo "Average Latency (ms): ", latencies.foldl(a+b) / N.float

when isMainModule:
  main()
```

Compile and run

```
nim c -d:release -d:danger main.nim && sudo nice -n -20 ./main
```

One result on my unix machine which use `clock_gettime()` with `CLOCK_REALTIME`. 

```
Number of Triggers: 10000
Minimum Latency (ms): 0.000244140625
25% Percentile (ms): 0.000732421875
50% Percentile (ms): 0.000732421875
75% Percentile (ms): 0.0009765625
95% Percentile (ms): 0.001220703125
99% Percentile (ms): 0.001708984375
Maximum Latency (ms): 0.03125
Average Latency (ms): 0.000910693359375
```

## Usage

There are two ways to run a `taskQueue` currently (may use high resolution timer if os support in the future).

- `exec()` will run in a while loop. It is recommended to run in another thread. FYI, see my another [project](https://github.com/jackhftang/threadproxy.nim) =].

- `poll()` use *addTimer* in asyncdispatch. 

Example:

```nim
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
```

### External Clock

TaskQueue internal clock can be overriden by `now=`.

Example:

```
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
```

### Recurrent Task 

There are two variants for running recurrent tasks. They have the same signature, but the handling of resheduling the recurrence is subtly different. 

#### runEvery

`runEvery(startTime: Timestamp, interval: Timespan, action: CancelableAction)` 

`runEvery` schedules the first task at `startTime`. And every time after running the task, it re-schedules the task at `startTime` + n * `interval` in nearest future where n is a whole number.

System real time could be adjusted from time to time (e.g. NTP). The re-scheduled time is independent of system time. `runEvery` is immune to hardware clock drift. Common use case is like scheduling a task to run at 12:00pm sharp everyday. 

Rescheduling can be canceled by return a `true` in action.

Example:

```
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
```

#### runAround    

`runAround(startTime: Timestamp, interval: Timespan, action: CancelableAction)` 

`runAround` schedules the first task at `startTime`. And every time after running the task, it re-schedules the task at current time + `interval`. The scheduled time will drift with system real time. Common use case is like running a health check every seconds.

Example:

```nim
import taskqueue

proc main() =
  let q = newTaskQueue()

  let startTime = q.now() # run immediately

  const N = 1000
  var cnt = 0
  q.runAround startTime, MILLI_SECOND:
    # see how it drift away
    echo cnt, " ", (q.now() - startTime).inMilliSecond 
    cnt.inc

    # repeat N times and stop
    if cnt >= N: q.stop()

  q.exec()

when isMainModule:
  main()
```
