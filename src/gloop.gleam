import aio.{type AIO, AIO}
import bus
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/actor
import gloroutine.{type Coroutine, type CoroutineInput, Complete, Prime, Yielded}

pub type RunnableCoroutine(i, o) {
  RunnableCoroutine(coro: Coroutine(i, o), next: CoroutineInput(i))
}

pub type Scheduler(i, o) {
  Scheduler(
    aio: AIO(i, o),
    runnable: List(RunnableCoroutine(i, o)),
    suspended: List(RunnableCoroutine(i, o)),
  )
}

fn new_aio() {
  let cq = bus.new_completion_queue()
  AIO(cq: cq)
}

pub fn new_loop() -> Scheduler(i, o) {
  Scheduler(aio: new_aio(), runnable: [], suspended: [])
}

pub type Message(i, o) {
  Shutdown
  Add(RunnableCoroutine(i, o))
  Tick(t: Int)
}

const batch_size = 10

fn event_loop_handler(
  message: Message(i, o),
  state: Scheduler(i, o),
) -> actor.Next(Message(i, o), Scheduler(i, o)) {
  case message {
    Shutdown -> actor.Stop(process.Normal)
    Add(element) -> {
      actor.continue(Scheduler(..state, runnable: [element, ..state.runnable]))
    }
    Tick(t) -> {
      process.call(state.aio.cq, bus.Dequeue, 1000)
      |> list.each(fn(element) { element.callback(element.completion) })

      let sqes =
        state.runnable
        |> list.take(batch_size)
        |> list.reverse()
        |> list.map(fn(runnable) {
          let coro = runnable.coro
          let submission = coro.resume(runnable.next)

          io.debug(submission)

          case submission {
            Yielded(yielded) -> {
              Some(
                bus.SQE(submission: yielded, callback: fn(submission) {
                  io.debug(submission)
                }),
              )
            }
            Complete -> {
              None
            }
          }
          // wrap submission in an sqe fold over list and enqueu / flush it
        })

      // state.aio.flush(sqes)
      actor.continue(
        Scheduler(..state, runnable: state.runnable |> list.drop(batch_size)),
      )
    }
  }
}

pub fn new_event_loop() {
  let assert Ok(event_loop) = actor.start(new_loop(), event_loop_handler)
  event_loop
}
