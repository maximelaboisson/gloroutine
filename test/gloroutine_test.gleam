import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleeunit
import gleeunit/should

import gloroutine.{Complete, Yielded, on_each}
import sequence.{type Sequence, new_sequence, take, to_list}

pub fn main() {
  gleeunit.main()
}

pub fn fib(a: Int, b: Int, flow: Sequence(Int)) -> Nil {
  let new_b = a + b
  use _, flow <- flow.yield(Yielded(new_b))
  fib(b, new_b, flow)
}

pub fn fib_coro() {
  let f = fn(flow: Sequence(Int)) {
    use _, flow <- flow.yield(Yielded(0))
    use _, flow <- flow.yield(Yielded(1))
    fib(0, 1, flow)
    Nil
  }

  new_sequence(f)
}

pub fn fibonaci_happy_path_test() {
  let expected = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]

  let result_coro =
    fib_coro()
    |> on_each(fn(x) {
      io.debug(x)
      Nil
    })
    |> take(10)
    |> to_list()

  use output, _ <- result_coro.resume(None)
  let assert Complete(result) = output
  result |> should.equal(expected)
}
// pub fn foo_test() {
//   let coro =
//     fib_coro()
//     |> c.on_each(fn(x) {
//       io.debug(x)
//       Nil
//     })
//     |> flow.take(10)
//     |> flow.to_list()

//   let ok =
//     reset(coro, fn(value) {
//       io.debug("inside the cont")
//       value
//     })
//   io.debug(ok)
// }
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
