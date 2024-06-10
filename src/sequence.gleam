import gleam/list
import gloroutine as c

pub type Sequence(o) =
  c.Coroutine(Nil, o)

pub fn new_sequence(f: fn(Sequence(o)) -> Nil) -> Sequence(o) {
  c.new_coroutine(f)
}

pub fn inner_to_list(
  inner_coro: Sequence(o),
  acc: List(o),
  resumed: c.CoroutineInput(Nil),
) -> List(o) {
  case inner_coro.resume(resumed) {
    c.Complete -> {
      list.reverse(acc)
    }
    c.Yielded(yielded) -> {
      inner_to_list(inner_coro, [yielded, ..acc], c.Resumed(Nil))
    }
  }
}

pub fn to_list(inner_coro: Sequence(o)) -> List(o) {
  inner_to_list(inner_coro, [], c.Prime)
}
