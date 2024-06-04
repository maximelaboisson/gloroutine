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

pub fn fib(a: Int, b: Int, flow: flow.Flow(Int)) -> Int {
  let new_b = a + b
  flow.yield(c.CoroutineOutput(new_b))
  fib(b, new_b, flow)
}

pub fn fib_coro() {
  let f = fn(flow: flow.Flow(Int)) {
    flow.yield(c.CoroutineOutput(0))
    flow.yield(c.CoroutineOutput(1))
    fib(0, 1, flow)
    Nil
  }

  flow.new_flow(f)
}

pub fn fibonaci_happy_path_test() {
  let expected = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
  let result =
    fib_coro()
    |> c.take(10)
    |> flow.to_list()

  result |> should.equal(expected)
}

pub fn fibonaci_squared_happy_path_test() {
  let transform = fn(x) { x * x }
  let expected = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34] |> list.map(transform)
  let result =
    fib_coro()
    |> c.take(10)
    |> c.map(transform)
    |> flow.to_list()

  result |> should.equal(expected)
}

pub fn fibonaci_filter_happy_path_test() {
  let expected = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
  let result =
    fib_coro()
    |> c.take(10)
    |> flow.to_list()

  result |> should.equal(expected)
}
