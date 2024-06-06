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

pub fn inner_fib_coro(a: Int, b: Int, coro: flow.Flow(Int)) {
  let new_b = a + b
  use _, coro <- coro.yield(Some(new_b))
  inner_fib_coro(b, new_b, coro)
}

pub fn fib_coro() {
  let f = fn(coro: flow.Flow(Int)) {
    use _, coro <- coro.yield(Some(0))
    use _, coro <- coro.yield(Some(1))
    inner_fib_coro(0, 1, coro)
  }

  c.new_coroutine(f)
}

pub fn fibonaci_happy_path_test() {
  let expected = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]

  let result_coro =
    fib_coro()
    |> c.on_each(fn(x) {
      io.debug(x)
      Nil
    })
    |> flow.to_list()
  // |> flow.take(10)
  // result |> should.equal(expected)
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
