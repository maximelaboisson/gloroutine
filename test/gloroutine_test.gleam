import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleeunit
import gleeunit/should

import flow
import gloroutine as c

pub fn main() {
  gleeunit.main()
}

// pub fn inner_fib_coro(a: Int, b: Int, coro: flow.Flow(Int)) {
//   let new_b = a + b
//   use _, coro <- coro.yield(Some(new_b))
//   inner_fib_coro(b, new_b, coro)
// }

pub fn fib(a: Int, b: Int, flow: flow.Flow(Int)) -> Nil {
  let new_b = a + b
  use _, flow <- flow.yield(c.CoroutineOutput(new_b))
  fib(b, new_b, flow)
}

pub fn fib_coro() {
  let f = fn(flow: flow.Flow(Int)) {
    use _, flow <- flow.yield(c.CoroutineOutput(0))
    use _, flow <- flow.yield(c.CoroutineOutput(1))
    fib(0, 1, flow)
    Nil
  }

  flow.new_flow(f)
}

pub fn fibonaci_happy_path_test() {
  let expected = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]

  let result_coro =
    fib_coro()
    |> c.on_each(fn(x) {
      io.debug(x)
      Nil
    })
    |> flow.take(10)
    |> flow.to_list()

  use output, _ <- result_coro.resume(None)
  let assert c.StopIteration(result) = output
  result |> should.equal(expected)
}
// pub fn fibonaci_squared_happy_path_test() {
//   let transform = fn(x) { x * x }
//   let expected = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34] |> list.map(transform)
//   let result =
//     fib_coro()
//     |> c.take(10)
//     |> c.map(transform)
//     |> flow.to_list()

//   result |> should.equal(expected)
// }

// pub fn fibonaci_filter_happy_path_test() {
//   let expected = [0, 1, 1, 2, 3, 5, 8]
//   let result =
//     fib_coro()
//     |> c.take(10)
//     |> c.filter(fn(x) { x < 10 })
//     |> c.take_while(fn(x) {
//       case x {
//         None -> False
//         Some(_) -> True
//       }
//     })
//     |> c.map(fn(x) {
//       case x {
//         Some(value) -> value
//         None -> panic
//       }
//     })
//     |> flow.to_list()

//   result |> should.equal(expected)
// }
