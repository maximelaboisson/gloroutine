import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/otp/task

pub type Coroutine(i, o) {
  Coroutine(
    yield: fn(Option(o)) -> Option(i),
    resume: fn(Option(i)) -> Option(o),
  )
}

pub type Message(e) {
  Shutdown
  Send(element: e)
  Receive(reply_with: Subject(Result(e, Nil)))
}

fn unary_channel_handler(
  message: Message(e),
  state: #(Option(e), Option(Subject(Result(e, Nil)))),
) -> actor.Next(Message(e), #(Option(e), Option(Subject(Result(e, Nil))))) {
  case message {
    Shutdown -> actor.Stop(process.Normal)
    Send(element) -> {
      case state {
        #(None, Some(client)) -> {
          process.send(client, Ok(element))
          actor.continue(#(None, None))
        }
        #(None, None) -> {
          actor.continue(#(Some(element), None))
        }
        _ -> {
          io.print("unary channel is full")
          panic
        }
      }
    }
    Receive(client) ->
      case state {
        #(Some(element), None) -> {
          process.send(client, Ok(element))
          actor.continue(#(None, None))
        }
        #(None, None) -> {
          actor.continue(#(None, Some(client)))
        }
        _ -> {
          io.print("unary channel already has a receiver")
          panic
        }
      }
  }
}

pub fn new_coroutine(f: fn(Coroutine(i, o)) -> Nil) -> Coroutine(i, o) {
  let assert Ok(output_channel) =
    actor.start(#(None, None), unary_channel_handler)
  let assert Ok(input_channel) =
    actor.start(#(None, None), unary_channel_handler)

  let coro =
    Coroutine(
      yield: fn(output: Option(o)) -> Option(i) {
        process.send(output_channel, Send(output))
        let assert Ok(input) = process.call(input_channel, Receive, 100_000)
        input
      },
      resume: fn(input: Option(i)) -> Option(o) {
        process.send(input_channel, Send(input))
        let assert Ok(output) = process.call(output_channel, Receive, 100_000)
        output
      },
    )

  task.async(fn() {
    // blocks the coro until first resume is sent
    let assert Ok(_) = process.call(input_channel, Receive, 100_000)
    f(coro)

    process.send(input_channel, Shutdown)
    process.send(output_channel, Shutdown)
  })

  coro
}

fn inner_collect(coro: Coroutine(Nil, o)) {
  case coro.resume(Some(Nil)) {
    None -> {
      Nil
    }
    Some(_) -> inner_collect(coro)
  }
}

pub fn collect(coro: Coroutine(Nil, o)) -> Nil {
  case coro.resume(None) {
    None -> Nil
    Some(_) -> inner_collect(coro)
  }
}

fn inner_to_list(coro: Coroutine(Nil, o), result: List(o)) -> List(o) {
  case coro.resume(Some(Nil)) {
    None -> {
      list.reverse(result)
    }
    Some(value) -> {
      inner_to_list(coro, [value, ..result])
    }
  }
}

pub fn to_list(coro: Coroutine(Nil, o)) -> List(o) {
  case coro.resume(None) {
    None -> []
    Some(value) -> inner_to_list(coro, [value])
  }
}

fn inner_map(
  inner_coro: Coroutine(i, o),
  outer_coro: Coroutine(i, p),
  f: fn(o) -> p,
  output: Option(p),
) {
  case outer_coro.yield(output) {
    None -> {
      outer_coro.yield(None)
      Nil
    }
    Some(value) -> {
      case inner_coro.resume(Some(value)) {
        None -> {
          outer_coro.yield(None)
          Nil
        }
        Some(v) -> {
          inner_map(inner_coro, outer_coro, f, Some(f(v)))
        }
      }
    }
  }
}

pub fn map(inner_coro: Coroutine(i, o), f: fn(o) -> p) -> Coroutine(i, p) {
  let body = fn(outer_coro: Coroutine(i, p)) -> Nil {
    case inner_coro.resume(None) {
      None -> {
        outer_coro.yield(None)
        Nil
      }
      Some(v) -> {
        inner_map(inner_coro, outer_coro, f, Some(f(v)))
        Nil
      }
    }
  }

  new_coroutine(body)
}

fn inner_on_each(
  inner_coro: Coroutine(i, o),
  outer_coro: Coroutine(i, o),
  f: fn(o) -> Nil,
  output: Option(o),
) {
  case outer_coro.yield(output) {
    None -> {
      outer_coro.yield(None)
      Nil
    }
    Some(value) -> {
      case inner_coro.resume(Some(value)) {
        None -> {
          outer_coro.yield(None)
          Nil
        }
        Some(v) -> {
          f(v)
          inner_on_each(inner_coro, outer_coro, f, Some(v))
        }
      }
    }
  }
}

pub fn on_each(inner_coro: Coroutine(i, o), f: fn(o) -> Nil) -> Coroutine(i, o) {
  let body = fn(outer_coro: Coroutine(i, o)) -> Nil {
    case inner_coro.resume(None) {
      None -> {
        outer_coro.yield(None)
        Nil
      }
      Some(v) -> {
        f(v)
        inner_on_each(inner_coro, outer_coro, f, Some(v))
        Nil
      }
    }
  }

  new_coroutine(body)
}

fn inner_take(
  inner_coro: Coroutine(i, o),
  outer_coro: Coroutine(i, o),
  input: Option(i),
  number: Int,
) {
  case number == 0 {
    True -> {
      outer_coro.yield(None)
      Nil
    }
    False -> {
      case inner_coro.resume(input) {
        None -> {
          outer_coro.yield(None)
          Nil
        }
        Some(v) -> {
          let input = outer_coro.yield(Some(v))
          inner_take(inner_coro, outer_coro, input, number - 1)
          Nil
        }
      }
      Nil
    }
  }
}

pub fn take(inner_coro: Coroutine(i, o), number: Int) -> Coroutine(i, o) {
  let body = fn(outer_coro: Coroutine(i, o)) -> Nil {
    case inner_coro.resume(None) {
      None -> {
        outer_coro.yield(None)
        Nil
      }
      Some(v) -> {
        let input = outer_coro.yield(Some(v))
        inner_take(inner_coro, outer_coro, input, number - 1)
        Nil
      }
    }
  }

  new_coroutine(body)
}
