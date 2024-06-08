import gleam/option.{type Option, None, Some}

pub type CoroutineOutput(o) {
  Yielded(o)
  Complete(o)
}

pub type Coroutine(i, o) {
  Coroutine(
    yield: fn(CoroutineOutput(o), fn(Option(i), Coroutine(i, o)) -> Nil) -> Nil,
    resume: fn(Option(i), fn(CoroutineOutput(o), Coroutine(i, o)) -> Nil) -> Nil,
  )
}

fn build_yield_coroutine(outer_continuation) {
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

fn build_resume_coroutine(outer_continnuation) {
  Coroutine(
    yield: fn(_, _) { panic },
    resume: fn(
      input: Option(i),
      inner_continuation: fn(CoroutineOutput(o), Coroutine(i, o)) -> Nil,
    ) {
      let coroutine = build_yield_coroutine(inner_continuation)
      outer_continnuation(input, coroutine)
    },
  )
}

pub fn new_coroutine(f: fn(Coroutine(i, o)) -> Nil) -> Coroutine(i, o) {
  Coroutine(
    yield: fn(_, _) { panic },
    resume: fn(
      _: Option(i),
      outer_continuation: fn(CoroutineOutput(o), Coroutine(i, o)) -> Nil,
    ) -> Nil {
      let coro = build_yield_coroutine(outer_continuation)
      f(coro)
    },
  )
}

fn inner_on_each(
  inner_coro: Coroutine(i, o),
  outer_coro: Coroutine(i, o),
  f: fn(o) -> Nil,
  output: o,
) -> Nil {
  f(output)
  use input, outer_coro <- outer_coro.yield(Yielded(output))
  use output, inner_coro <- inner_coro.resume(input)
  case output {
    Complete(output_value) -> {
      f(output_value)
      outer_coro.yield(Complete(output_value), fn(_, _) { panic })
    }
    Yielded(output_value) ->
      inner_on_each(inner_coro, outer_coro, f, output_value)
  }
}

pub fn on_each(inner_coro: Coroutine(i, o), f: fn(o) -> Nil) -> Coroutine(i, o) {
  let body = fn(outer_coro: Coroutine(i, o)) {
    use output, inner_coro <- inner_coro.resume(None)
    case output {
      Complete(output_value) -> {
        f(output_value)
        outer_coro.yield(Complete(output_value), fn(_, _) { panic })
      }
      Yielded(output_value) ->
        inner_on_each(inner_coro, outer_coro, f, output_value)
    }
  }

  new_coroutine(body)
}
