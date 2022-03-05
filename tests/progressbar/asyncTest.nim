
import asyncdispatch # This is what provides us with async and the dispatcher
import times, strutils # This is to provide the timing output
 
let start = epochTime()
 
proc ticker() {.async.} =
  ## This simple procedure will echo out "tick" ten times with 100ms between
  ## each tick. We use it to visualise the time between other procedures.
  for i in 1..10:
    await sleepAsync(100)
    echo "tick ",
         i*100, "ms ",
         split($((epochTime() - start)*1000), '.')[0], "ms (real)"
 
proc delayedEcho(message: string, wait: int) {.async.} =
  ## Simply waits `wait` milliseconds before echoing `message`
  await sleepAsync(wait)
  echo message
 
let
  delayedEchoFuture = delayedEcho("Hello world", 550)
  tickerFuture = ticker()
 
waitFor tickerFuture and delayedEchoFuture
echo delayedEchoFuture.finished
