import gleam/erlang/process.{type Subject}
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/otp/task

pub type CoroutineInput(i) {
  Resumed(i)
  Prime
}

pub type CoroutineOutput(o) {
  Yielded(o)
  Complete
}

pub type Coroutine(i, o) {
  Coroutine(
    yield: fn(CoroutineOutput(o)) -> CoroutineInput(i),
    resume: fn(CoroutineInput(i)) -> CoroutineOutput(o),
  )
}

pub type Message(e) {
  Shutdown
  Send(element: e)
  Receive(reply_with: Subject(Result(e, Nil)))
}

pub type UnaryChannelState(e) {
  UnaryChannelState(
    element: Option(e),
    subject: Option(Subject(Result(e, Nil))),
  )
}

fn unary_channel_handler(
  message: Message(e),
  state: UnaryChannelState(e),
) -> actor.Next(Message(e), UnaryChannelState(e)) {
  case message {
    Shutdown -> actor.Stop(process.Normal)
    Send(element) -> {
      case state.subject {
        Some(client) -> {
          process.send(client, Ok(element))
          actor.continue(UnaryChannelState(element: None, subject: None))
        }
        None -> {
          actor.continue(UnaryChannelState(
            element: Some(element),
            subject: None,
          ))
        }
      }
    }
    Receive(client) ->
      case state.element {
        Some(element) -> {
          process.send(client, Ok(element))
          actor.continue(UnaryChannelState(element: None, subject: None))
        }
        None -> {
          actor.continue(UnaryChannelState(element: None, subject: Some(client)))
        }
      }
  }
}

pub fn new(f: fn(Coroutine(i, o)) -> Nil) -> Coroutine(i, o) {
  let assert Ok(output_channel) =
    actor.start(
      UnaryChannelState(element: None, subject: None),
      unary_channel_handler,
    )
  let assert Ok(input_channel) =
    actor.start(
      UnaryChannelState(element: None, subject: None),
      unary_channel_handler,
    )

  let coro =
    Coroutine(
      yield: fn(output: CoroutineOutput(o)) -> CoroutineInput(i) {
        process.send(output_channel, Send(output))
        let assert Ok(input) = process.call(input_channel, Receive, 100_000_000)
        input
      },
      resume: fn(input: CoroutineInput(i)) -> CoroutineOutput(o) {
        process.send(input_channel, Send(input))
        let assert Ok(output) =
          process.call(output_channel, Receive, 100_000_000)
        output
      },
    )

  task.async(fn() {
    // blocks the coroutine until it's primed
    let assert Ok(_) = process.call(input_channel, Receive, 100_000_000)

    f(coro)
    // TODO: this should be tested for concurrency, not sure this actually is safe to shutdown directly
    // process.send(input_channel, Shutdown)
    // process.send(output_channel, Shutdown)
  })

  coro
}

pub fn filter(
  inner_coro: Coroutine(i, o),
  f: fn(o) -> Bool,
) -> Coroutine(i, Option(o)) {
  inner_coro
  |> map(fn(elem: o) {
    case f(elem) {
      True -> Some(elem)
      False -> None
    }
  })
}

fn inner_map(
  inner_coro: Coroutine(i, o),
  outer_coro: Coroutine(i, p),
  f: fn(CoroutineOutput(o)) -> CoroutineOutput(p),
  output: CoroutineOutput(p),
) {
  case outer_coro.yield(output) {
    Prime -> panic
    Resumed(value) -> {
      let value = inner_coro.resume(Resumed(value))
      inner_map(inner_coro, outer_coro, f, f(value))
    }
  }
}

pub fn map(inner_coro: Coroutine(i, o), f: fn(o) -> p) -> Coroutine(i, p) {
  let body = fn(outer_coro: Coroutine(i, p)) -> Nil {
    let wrapped_f = fn(output: CoroutineOutput(o)) -> CoroutineOutput(p) {
      case output {
        Complete -> Complete
        Yielded(value) -> Yielded(f(value))
      }
    }
    let value = inner_coro.resume(Prime)
    inner_map(inner_coro, outer_coro, wrapped_f, wrapped_f(value))
  }

  new(body)
}

fn inner_on_each(
  inner_coro: Coroutine(i, o),
  outer_coro: Coroutine(i, o),
  f: fn(CoroutineOutput(o)) -> Nil,
  output: CoroutineOutput(o),
) {
  case outer_coro.yield(output) {
    Prime -> panic
    Resumed(value) -> {
      let output = inner_coro.resume(Resumed(value))
      f(output)
      inner_on_each(inner_coro, outer_coro, f, output)
    }
  }
}

pub fn on_each(inner_coro: Coroutine(i, o), f: fn(o) -> Nil) -> Coroutine(i, o) {
  let body = fn(outer_coro: Coroutine(i, o)) -> Nil {
    let input = inner_coro.resume(Prime)
    let safe_f = fn(output: CoroutineOutput(o)) {
      case output {
        Complete -> Nil
        Yielded(value) -> {
          f(value)
        }
      }
    }
    inner_on_each(inner_coro, outer_coro, safe_f, input)
  }

  new(body)
}

fn inner_take(
  inner_coro: Coroutine(i, o),
  outer_coro: Coroutine(i, o),
  resumed: CoroutineInput(i),
  remaining: Int,
) -> Nil {
  case remaining == 0 {
    True -> {
      outer_coro.yield(Complete)
      Nil
    }
    False -> {
      let yielded = inner_coro.resume(resumed)
      let resumed = outer_coro.yield(yielded)
      inner_take(inner_coro, outer_coro, resumed, remaining - 1)
      Nil
    }
  }
}

pub fn take(inner_coro: Coroutine(i, o), remaining: Int) -> Coroutine(i, o) {
  // TODO: validate number >= 1
  let body = fn(outer_coro: Coroutine(i, o)) -> Nil {
    case inner_coro.resume(Prime) {
      Complete -> {
        outer_coro.yield(Complete)
        Nil
      }
      Yielded(v) -> {
        let resumed = outer_coro.yield(Yielded(v))
        inner_take(inner_coro, outer_coro, resumed, remaining - 1)
        Nil
      }
    }
  }

  new(body)
}

fn inner_take_while(
  inner_coro: Coroutine(i, o),
  outer_coro: Coroutine(i, o),
  f: fn(o) -> Bool,
  output: o,
) {
  case f(output) {
    False -> {
      outer_coro.yield(Complete)
      Nil
    }
    True -> {
      let resumed = outer_coro.yield(Yielded(output))
      case inner_coro.resume(resumed) {
        Complete -> {
          outer_coro.yield(Complete)
          Nil
        }
        Yielded(yielded) -> {
          inner_take_while(inner_coro, outer_coro, f, yielded)
          Nil
        }
      }
    }
  }
}

pub fn take_while(
  inner_coro: Coroutine(i, o),
  f: fn(o) -> Bool,
) -> Coroutine(i, o) {
  let body = fn(outer_coro: Coroutine(i, o)) -> Nil {
    case inner_coro.resume(Prime) {
      Complete -> {
        outer_coro.yield(Complete)
        Nil
      }
      Yielded(yielded) -> {
        inner_take_while(inner_coro, outer_coro, f, yielded)
        Nil
      }
    }
  }

  new(body)
}
