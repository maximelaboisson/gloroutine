import aio.{type Request, type Response}
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import gloop
import gloroutine.{
  type Coroutine, Prime, Yielded, filter, map, on_each, take, take_while,
}
import sequence.{type Sequence, new_sequence, to_list}

pub fn main() {
  gleeunit.main()
}

pub fn fib(a: Int, b: Int, flow: Sequence(Int)) -> Nil {
  let new_b = a + b
  flow.yield(Yielded(new_b))
  fib(b, new_b, flow)
}

pub fn fib_coro() {
  let f = fn(flow: Sequence(Int)) {
    flow.yield(Yielded(0))
    flow.yield(Yielded(1))
    fib(0, 1, flow)
    Nil
  }

  new_sequence(f)
}

pub fn fibonaci_happy_path_test() {
  let expected = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]

  let result =
    fib_coro()
    |> take(10)
    |> to_list()

  should.equal(result, expected)
}

pub fn fibonaci_squared_happy_path_test() {
  let transform = fn(x) { x * x }
  let expected = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34] |> list.map(transform)
  let result =
    fib_coro()
    |> take(10)
    |> map(transform)
    |> to_list()

  should.equal(result, expected)
}

pub fn fibonaci_filter_happy_path_test() {
  let expected = [0, 1, 1, 2, 3, 5, 8]
  let result =
    fib_coro()
    |> take(10)
    |> filter(fn(x) { x < 10 })
    |> take_while(fn(x) {
      case x {
        None -> False
        Some(_) -> True
      }
    })
    |> map(fn(x) {
      case x {
        Some(value) -> value
        None -> panic
      }
    })
    |> to_list()

  result |> should.equal(expected)
}

pub fn aio_coro() {
  let f = fn(flow: Coroutine(Response, Request)) {
    flow.yield(Yielded(aio.StoreRequest(store: "postgresql", command: "fetch")))
    flow.yield(Yielded(aio.StoreRequest(store: "sqlite", command: "fetch")))
    Nil
  }

  gloroutine.new_coroutine(f)
}

pub fn gloop_test() {
  let coro = aio_coro()
  let event_loop = gloop.new_event_loop()

  let runnable = gloop.RunnableCoroutine(coro, Prime)

  process.send(event_loop, gloop.Add(runnable))
  process.send(event_loop, gloop.Tick(1))

  process.send(event_loop, gloop.Add(runnable))
  process.send(event_loop, gloop.Tick(1))

  process.sleep_forever()
}
