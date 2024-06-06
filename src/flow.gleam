import gleam/list
import gleam/option.{type Option, None, Some}
import gloroutine as c

pub type Flow(o) =
  c.Coroutine(Nil, o)

pub fn new_flow(f: fn(Flow(o)) -> Nil) -> Flow(o) {
  c.new_coroutine(f)
}

fn inner_take(inner_coro: Flow(o), outer_coro: Flow(o), number: Int) -> Nil {
  use output, inner_coro <- inner_coro.resume(Some(Nil))
  case output {
    c.StopIteration(output_value) ->
      outer_coro.yield(c.StopIteration(output_value), fn(_, _) { panic })
    c.CoroutineOutput(output_value) -> {
      case number == 1 {
        True -> {
          outer_coro.yield(c.StopIteration(output_value), fn(_, _) { panic })
        }
        False -> {
          use _, outer_coro <- outer_coro.yield(output)
          inner_take(inner_coro, outer_coro, number - 1)
        }
      }
    }
  }
}

pub fn take(inner_coro: Flow(o), number: Int) -> Flow(o) {
  // TODO: validate number >= 1
  let body = fn(outer_coro: Flow(o)) -> Nil {
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
  inner_coro: Flow(o),
  outer_coro: Flow(List(o)),
  acc: List(o),
) {
  use input, inner_coro <- inner_coro.resume(Some(Nil))
  case input {
    c.StopIteration(input_value) -> {
      outer_coro.yield(
        c.StopIteration(list.reverse([input_value, ..acc])),
        fn(_, _) { panic },
      )
    }
    c.CoroutineOutput(input_value) -> {
      inner_to_list(inner_coro, outer_coro, [input_value, ..acc])
    }
  }
}

pub fn to_list(inner_coro: Flow(o)) -> Flow(List(o)) {
  let body = fn(outer_coro: Flow(List(o))) {
    use input, inner_coro <- inner_coro.resume(None)
    case input {
      c.StopIteration(input_value) -> {
        outer_coro.yield(c.StopIteration([input_value]), fn(_, _) { panic })
      }
      c.CoroutineOutput(input_value) -> {
        inner_to_list(inner_coro, outer_coro, [input_value])
      }
    }
  }

  c.new_coroutine(body)
}
