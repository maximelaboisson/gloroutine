import gleam/option.{type Option, None, Some}

pub type Coroutine(i, o) {
  Coroutine(
    yield: fn(Option(o), fn(Option(i), Coroutine(i, o)) -> Nil) -> Nil,
    resume: fn(Option(i), fn(Option(o), Coroutine(i, o)) -> Nil) -> Nil,
  )
}

pub fn build_yield_coroutine(outer_continnuation) {
  Coroutine(
    resume: fn(_, _) { panic },
    yield: fn(
      ouput: Option(o),
      inner_continuation: fn(Option(i), Coroutine(i, o)) -> Nil,
    ) {
      let coroutine = build_resume_coroutine(inner_continuation)
      outer_continnuation(ouput, coroutine)
      Nil
    },
  )
}

pub fn build_resume_coroutine(outer_continnuation) {
  Coroutine(
    resume: fn(
      input: Option(i),
      inner_continuation: fn(Option(o), Coroutine(i, o)) -> Nil,
    ) {
      let coroutine = build_yield_coroutine(inner_continuation)
      outer_continnuation(input, coroutine)
      Nil
    },
    yield: fn(_, _) { panic },
  )
}

pub fn new_coroutine(f: fn(Coroutine(i, o)) -> Nil) -> Coroutine(i, o) {
  Coroutine(
    resume: fn(
      _: Option(i),
      outer_continuation: fn(Option(o), Coroutine(i, o)) -> Nil,
    ) -> Nil {
      let coro =
        Coroutine(
          resume: fn(_, _) { panic },
          yield: fn(ouput: Option(o), continuation) {
            let coroutine = build_resume_coroutine(continuation)
            outer_continuation(ouput, coroutine)
            Nil
          },
        )
      f(coro)
      Nil
    },
    yield: fn(_, _) { panic },
  )
}

fn inner_on_each(
  inner_coro: Coroutine(i, o),
  outer_coro: Coroutine(i, o),
  f: fn(o) -> Nil,
  output: Option(o),
) -> Nil {
  case output {
    None -> Nil
    Some(value) -> {
      f(value)
      use value, outer_coro <- outer_coro.yield(output)
      use output, inner_coro <- inner_coro.resume(value)
      inner_on_each(inner_coro, outer_coro, f, output)
      Nil
    }
  }
}

pub fn on_each(inner_coro: Coroutine(i, o), f: fn(o) -> Nil) -> Coroutine(i, o) {
  let body = fn(outer_coro: Coroutine(i, o)) {
    use input, inner_coro <- inner_coro.resume(None)
    case input {
      None -> Nil
      Some(value) -> {
        f(value)
        inner_on_each(inner_coro, outer_coro, f, input)
      }
    }
  }

  new_coroutine(body)
}
