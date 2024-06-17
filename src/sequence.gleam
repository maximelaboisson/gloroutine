import gleam/list
import gloroutine.{
  type Coroutine, type CoroutineInput, Complete, Prime, Resumed, Yielded,
}

pub type Sequence(o) =
  Coroutine(Nil, o)

pub fn new_sequence(f: fn(Sequence(o)) -> Nil) -> Sequence(o) {
  gloroutine.new(f)
}

pub fn inner_to_list(
  inner_coro: Sequence(o),
  acc: List(o),
  resumed: CoroutineInput(Nil),
) -> List(o) {
  case inner_coro.resume(resumed) {
    Complete -> {
      list.reverse(acc)
    }
    Yielded(yielded) -> {
      inner_to_list(inner_coro, [yielded, ..acc], Resumed(Nil))
    }
  }
}

pub fn to_list(inner_coro: Sequence(o)) -> List(o) {
  inner_to_list(inner_coro, [], Prime)
}
