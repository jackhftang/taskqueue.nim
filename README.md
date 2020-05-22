taskqueue

High precision and high performance task scheduler.

## Example

Measure the latency of scheduled tasks. 

```nim
# main.nim

import taskqueue
import algorithm
import sequtils
import sugar

proc main() = 
  # create a new task scheduler
  let q = newTaskQueue()
      
  # define T as referenced time
  let T = q.now()

  # schedler N tasks
  let N = 10000
  var latencies = newSeqOfCap[float](N)
  for i in 1..N:
    let targetTime = T + i * MILLI_SECOND
    capture targetTime:
      q.runAt targetTime:
        latencies.add q.now().inMilliSecond - targetTime.inMilliSecond 

  # scheduler to stop scheduler
  q.runAt T + (N+1) * MILLI_SECOND:
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

One result on my unix machine (`now()` internally use `clock_gettime()` with `CLOCK_REALTIME` on unix). 

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

## Patterns

### Lower CPU with timer

`exec()` run in a tight loop, which consume near 100% CPU. If a lower precision is acceptable, `poll()` can be used instead. 

```nim
import taskqueue
import asyncdispatch 

proc main() =
  let q = newTaskQueue()
  q.runAt q.now() + 3*SECOND:
    echo "do something and exit"
    q.stop()

  # call process periodically
  waitFor q.poll()

main()
```

### External Clock

Sometimes it is needed to synchronize with other source of time instead of system time. You can override it with `now=`.

```
import taskqueue
import asyncdispatch 

proc main() =
  # My global synchronized clock
  var myTime = initTimestamp()

  # synchronize logical time of two taskqueues
  let q1 = newTaskQueue()
  let q2 = newTaskQueue()
  q1.now = proc(): Timestamp = myTime 
  q2.now = proc(): Timestamp = myTime
  
  # schedule to trigger at *logically same* time 
  let target = myTime + 50*MILLI_SECOND
  echo "Target time is ", target
  q1.runAt target:
    echo "Current time is ", initTimestamp(), ". q1 see is ", q1.now()
  q2.runAt target:
    echo "Current time is ", initTimestamp(), ". q2 see is ", q2.now()

  while myTime < target + 50*MILLI_SECOND:
    myTime = initTimestamp()
    q1.process(myTime)
    q2.process(myTime)

main()
```

### Recurrant Task 

    
