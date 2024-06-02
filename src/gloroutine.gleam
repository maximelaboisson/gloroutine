import gleam/io
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/otp/task

pub type Coroutine(i, o){
  Coroutine(
    yield: fn(o) -> i,
    resume: fn(i) -> o
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
          io.print("not normal - should panic here")
          actor.Stop(process.Normal)
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
          io.print("not normal - should panic here")
          actor.Stop(process.Normal)
        }
      }
  }
}


pub fn new_coroutine(f: fn(Coroutine(i, o)) -> Nil) -> Coroutine(i, o) {
  let assert Ok(output_channel) = actor.start(#(None, None), unary_channel_handler)
  let assert Ok(input_channel) = actor.start(#(None, None), unary_channel_handler)

  let coro = Coroutine(
    yield: fn(output: o) -> i {
      process.send(output_channel, Send(output))
      let assert Ok(input) = process.call(input_channel, Receive, 100000)
      input
    },
    resume: fn(input: i) -> o {
      process.send(input_channel, Send(input))
      let assert Ok(output) = process.call(output_channel, Receive, 100000)
      output
    },
  )
  
  task.async(fn(){
    let assert Ok(element) = process.call(input_channel, Receive, 100000)
    f(coro)
  })

  coro
}

pub fn first_test() {
  let f = fn(coro: Coroutine(String, String)) -> Nil {
    let first_resume = coro.yield("from yield 1")
    io.println(first_resume)

    let second_resume = coro.yield("from yield 2")
    io.println(second_resume)
  }

  let coro = new_coroutine(f)
  let first_yield = coro.resume("")
  io.println(first_yield)

  let second_yield = coro.resume("from resume 1")
  io.println(second_yield)

  let finalize = coro.resume("from resume 2")
  io.println(finalize)

  process.sleep(100000)
  Nil
}

pub fn fib(a: Int, b: Int, coro: Coroutine(Nil, Int)) -> Int {
    let new_b = a + b
    coro.yield(new_b)
    fib(b, new_b, coro)
}

pub fn fib_test() {
  let f = fn(coro: Coroutine(Nil, Int)) -> Nil {
    coro.yield(0)
    coro.yield(1)
    fib(0, 1, coro)
    Nil
  }

  let coro = new_coroutine(f)

  let first_yield = coro.resume(Nil)
  io.debug(first_yield)

  let second_yield = coro.resume(Nil)
  io.debug(second_yield)

  let third_yield = coro.resume(Nil)
  io.debug(third_yield)
  
  let fourth_yield = coro.resume(Nil)
  io.debug(fourth_yield)

  let fifth_yield = coro.resume(Nil)
  io.debug(fifth_yield)

  let sixth_yield = coro.resume(Nil)
  io.debug(sixth_yield)

  let seventh_yield = coro.resume(Nil)
  io.debug(seventh_yield)

  let eitght_yield = coro.resume(Nil)
  io.debug(eitght_yield)

  let ninth_yield = coro.resume(Nil)
  io.debug(ninth_yield)
}

pub fn main() {
  // first_test()
  fib_test()
}
