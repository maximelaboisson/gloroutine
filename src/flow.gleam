import gleam/list
import gloroutine as c

pub type Flow(o) =
  c.Coroutine(Nil, o)

pub fn new_flow(f: fn(Flow(o)) -> Nil) -> Flow(o) {
  c.new_coroutine(f)
}

fn inner_collect(coro: Flow(o)) {
  case coro.resume(c.CoroutineInput(Nil)) {
    c.StopIteration -> {
      Nil
    }
    c.CoroutineOutput(_) -> inner_collect(coro)
  }
}

pub fn collect(coro: Flow(o)) -> Nil {
  case coro.resume(c.PrimeIteration) {
    c.StopIteration -> Nil
    c.CoroutineOutput(_) -> inner_collect(coro)
  }
}

fn inner_to_list(coro: Flow(o), result: List(o)) -> List(o) {
  case coro.resume(c.CoroutineInput(Nil)) {
    c.StopIteration -> {
      list.reverse(result)
    }
    c.CoroutineOutput(value) -> {
      inner_to_list(coro, [value, ..result])
    }
  }
}

pub fn to_list(coro: Flow(o)) -> List(o) {
  case coro.resume(c.PrimeIteration) {
    c.StopIteration -> []
    c.CoroutineOutput(value) -> inner_to_list(coro, [value])
  }
}
