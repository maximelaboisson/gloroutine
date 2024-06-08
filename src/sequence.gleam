import gleam/list
import gleam/option.{type Option, None, Some}
import gloroutine as c

pub type Sequence(o) =
  c.Coroutine(Nil, o)

pub fn new_sequence(f: fn(Sequence(o)) -> Nil) -> Sequence(o) {
  c.new_coroutine(f)
}

fn inner_take(
  inner_coro: Sequence(o),
  outer_coro: Sequence(o),
  number: Int,
) -> Nil {
  use output, inner_coro <- inner_coro.resume(Some(Nil))
  case output {
    c.Complete(output_value) ->
      outer_coro.yield(c.Complete(output_value), fn(_, _) { panic })
    c.Yielded(output_value) -> {
      case number == 1 {
        True -> {
          outer_coro.yield(c.Complete(output_value), fn(_, _) { panic })
        }
        False -> {
          use _, outer_coro <- outer_coro.yield(output)
          inner_take(inner_coro, outer_coro, number - 1)
        }
      }
    }
  }
}

pub fn take(inner_coro: Sequence(o), number: Int) -> Sequence(o) {
  // TODO: validate number >= 1
  let body = fn(outer_coro: Sequence(o)) -> Nil {
    use value, inner_coro <- inner_coro.resume(None)
    use _, outer_coro <- outer_coro.yield(value)
    inner_take(inner_coro, outer_coro, number - 1)
  }

  c.new_coroutine(body)
}

// fn inner_collect(coro: Flow(o)) {
//   case coro.resume(c.CoroutineInput(Nil)) {
//     c.StopIteration -> {
//       Nil
//     }
//     c.CoroutineOutput(_) -> inner_collect(coro)
//   }
// }

// pub fn collect(coro: Flow(o)) -> Nil {
//   case coro.resume(c.PrimeIteration) {
//     c.StopIteration -> Nil
//     c.CoroutineOutput(_) -> inner_collect(coro)
//   }
// }

pub fn inner_to_list(
  inner_coro: Sequence(o),
  outer_coro: Sequence(List(o)),
  acc: List(o),
  input: Option(Nil),
) {
  use input, inner_coro <- inner_coro.resume(input)
  case input {
    c.Complete(input_value) -> {
      outer_coro.yield(c.Complete(list.reverse([input_value, ..acc])), fn(_, _) {
        panic
      })
    }
    c.Yielded(input_value) -> {
      inner_to_list(inner_coro, outer_coro, [input_value, ..acc], Some(Nil))
    }
  }
}

pub fn to_list(inner_coro: Sequence(o)) -> Sequence(List(o)) {
  let body = fn(outer_coro: Sequence(List(o))) {
    inner_to_list(inner_coro, outer_coro, [], None)
  }

  c.new_coroutine(body)
}
