# gloroutine
WIP coroutines for gleam, inspired by [resonate](https://github.com/resonatehq/resonate/blob/32bd3b7493a7defd09223bf7bf385a35b229e387/internal/kernel/scheduler/coroutine.go#L9)

[![Package Version](https://img.shields.io/hexpm/v/gloroutine)](https://hex.pm/packages/gloroutine)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gloroutine/)

```sh
gleam add gloroutine
```
```gleam
import gloroutine as c
import gleam/option.{type Option, None, Some}

pub fn fib(a: Int, b: Int, coro: c.Coroutine(Nil, Int)) -> Int {
  let new_b = a + b
  coro.yield(Some(new_b))
  fib(b, new_b, coro)
}

pub fn fib_coro() {
  let f = fn(coro: c.Coroutine(Nil, Int)) -> c.Coroutine(Nil, Int){
    coro.yield(Some(0))
    coro.yield(Some(1))
    fib(0, 1, coro)
    Nil
  }

  c.new_coroutine(f)
}

pub fn main() {
  let result =
  fib_coro()
  |> c.take(10)
  |> c.map(fn(x){ x * x })
  |> c.to_list()
}
```

Further documentation can be found at <https://hexdocs.pm/gloroutine>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
gleam shell # Run an Erlang shell
```
