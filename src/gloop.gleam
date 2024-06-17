import aio.{type AIO, type Request, type Response, AIO, SQE}
import gleam/erlang/process.{type Subject}
import gleam/list
import gloroutine.{
  type Coroutine, type CoroutineInput, Complete, Resumed, Yielded,
}
import list_actor.{Dequeue, Enqueue}

import gleam/io

const batch_size = 10

pub type RunnableCoroutine {
  RunnableCoroutine(
    coro: Coroutine(Response, Request),
    next: CoroutineInput(Response),
  )
}

pub type Scheduler {
  Scheduler(aio: AIO, runnables: Subject(list_actor.Message(RunnableCoroutine)))
}

pub fn attach(
  scheduler: Scheduler,
  kind: aio.Kind,
  subsystem: aio.Subsystem,
) -> Scheduler {
  Scheduler(..scheduler, aio: aio.attach(scheduler.aio, kind, subsystem))
}

pub fn new() -> Scheduler {
  let runnables = list_actor.new()
  Scheduler(aio: aio.new(), runnables: runnables)
}

pub fn add(scheduler: Scheduler, runnable: RunnableCoroutine) {
  process.send(scheduler.runnables, Enqueue(runnable))
  scheduler
}

pub fn tick(scheduler: Scheduler, t: Int) {
  process.call(scheduler.aio.cq, Dequeue, 1000)
  |> list.each(fn(element) {
    io.debug(element)
    element.callback(Resumed(element.completion))
  })

  process.call(scheduler.runnables, Dequeue, 1000)
  |> list.take(batch_size)
  |> list.each(fn(runnable) {
    case runnable.coro.resume(runnable.next) {
      Yielded(yielded) -> {
        let sqe =
          SQE(submission: yielded, callback: fn(resumed) {
            io.debug(yielded)
            let continuation =
              RunnableCoroutine(coro: runnable.coro, next: resumed)
            process.send(scheduler.runnables, Enqueue(continuation))
            Nil
          })

        process.send(scheduler.aio.sq, Enqueue(sqe))
        Nil
      }
      Complete -> {
        Nil
      }
    }
  })

  aio.flush(scheduler.aio)
  scheduler
}
