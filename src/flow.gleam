import gleam/list
import gleam/option.{type Option, None, Some}
import gloroutine as c

pub type Flow(o) =
  c.Coroutine(Nil, o)

// fn inner_take(
//   inner_coro: Flow(o),
//   outer_coro: Flow(o),
//   number: Int,
// ) -> Option(o) {
//   case number == 0 {
//     True -> {
//       use _, _ <- outer_coro.yield(None)
//       None
//     }
//     False -> {
//       use output, inner_coro <- inner_coro.resume(Some(Nil))
//       use _, outer_coro <- outer_coro.yield(output)
//       inner_take(inner_coro, outer_coro, number - 1)
//     }
//   }
// }

// pub fn take(inner_coro: Flow(o), number: Int) -> Flow(o) {
//   // TODO: validate number >= 1
//   let body = fn(outer_coro: Flow(o)) -> Option(o) {
//     use value, inner_coro <- inner_coro.resume(None)
//     use _, outer_coro <- outer_coro.yield(value)
//     inner_take(inner_coro, outer_coro, number - 1)
//   }

//   c.new_coroutine(body)
// }
// pub fn new_flow(f: fn(Flow(o)) -> Nil) -> Flow(o) {
//   c.new_coroutine(f)
// }

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
  outer_coro: c.Coroutine(o, List(o)),
  acc: List(o),
  input: Option(Nil),
) {
  use input, inner_coro <- inner_coro.resume(input)
  case input {
    None -> {
      outer_coro.yield(Some(list.reverse(acc)), fn(_, _) { panic })
      Nil
    }
    Some(value) -> {
      inner_to_list(inner_coro, outer_coro, [value, ..acc], Some(Nil))
      Nil
    }
  }
}

pub fn to_list(inner_coro: Flow(o)) -> c.Coroutine(o, List(o)) {
  let body = fn(outer_coro: c.Coroutine(o, List(o))) {
    inner_to_list(inner_coro, outer_coro, [], None)
    Nil
  }

  c.new_coroutine(body)
}
