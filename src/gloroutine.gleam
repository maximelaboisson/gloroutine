import gleam/io
import gleam/option.{type Option, None, Some}

pub type CoroutineOutput(o) {
  CoroutineOutput(o)
  StopIteration(o)
}

pub type Coroutine(i, o) {
  Coroutine(
    yield: fn(CoroutineOutput(o), fn(Option(i), Coroutine(i, o)) -> Nil) -> Nil,
    resume: fn(Option(i), fn(CoroutineOutput(o), Coroutine(i, o)) -> Nil) -> Nil,
  )
}

pub fn build_yield_coroutine(outer_continuation) {
  Coroutine(
    resume: fn(_, _) { panic },
    yield: fn(
      output: CoroutineOutput(o),
      inner_continuation: fn(Option(i), Coroutine(i, o)) -> Nil,
    ) {
      let coroutine = build_resume_coroutine(inner_continuation)
      outer_continuation(output, coroutine)
    },
  )
}

pub fn build_resume_coroutine(outer_continnuation) {
  Coroutine(
    resume: fn(
      input: Option(i),
      inner_continuation: fn(CoroutineOutput(o), Coroutine(i, o)) -> Nil,
    ) {
      let coroutine = build_yield_coroutine(inner_continuation)
      outer_continnuation(input, coroutine)
    },
    yield: fn(_, _) { panic },
  )
}

pub fn new_coroutine(f: fn(Coroutine(i, o)) -> Nil) -> Coroutine(i, o) {
  Coroutine(
    resume: fn(
      _: Option(i),
      outer_continuation: fn(CoroutineOutput(o), Coroutine(i, o)) -> Nil,
    ) -> Nil {
      let coro =
        Coroutine(
          resume: fn(_, _) { panic },
          yield: fn(output: CoroutineOutput(o), continuation) {
            let coroutine = build_resume_coroutine(continuation)
            outer_continuation(output, coroutine)
          },
        )
      f(coro)
    },
    yield: fn(_, _) { panic },
  )
}

fn inner_on_each(
  inner_coro: Coroutine(i, o),
  outer_coro: Coroutine(i, o),
  f: fn(o) -> Nil,
  output: o,
) -> Nil {
  f(output)
  use input, outer_coro <- outer_coro.yield(CoroutineOutput(output))
  use output, inner_coro <- inner_coro.resume(input)
  case output {
    StopIteration(output_value) -> {
      f(output_value)
      outer_coro.yield(StopIteration(output_value), fn(_, _) { panic })
    }
    CoroutineOutput(output_value) ->
      inner_on_each(inner_coro, outer_coro, f, output_value)
  }
}

pub fn on_each(inner_coro: Coroutine(i, o), f: fn(o) -> Nil) -> Coroutine(i, o) {
  let body = fn(outer_coro: Coroutine(i, o)) {
    use output, inner_coro <- inner_coro.resume(None)
    case output {
      StopIteration(output_value) -> {
        f(output_value)
        outer_coro.yield(StopIteration(output_value), fn(_, _) { panic })
      }
      CoroutineOutput(output_value) ->
        inner_on_each(inner_coro, outer_coro, f, output_value)
    }
  }

  new_coroutine(body)
}
