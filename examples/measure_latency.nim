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
  # It will takes N * M = 10 second to run
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