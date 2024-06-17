import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor

const batch_size = 10

pub type Message(t) {
  Shutdown
  Enqueue(t)
  Dequeue(reply_with: Subject(List(t)))
}

fn list_actor_handler(
  message: Message(t),
  state: List(t),
) -> actor.Next(Message(t), List(t)) {
  case message {
    Shutdown -> actor.Stop(process.Normal)
    Enqueue(element) -> {
      actor.continue([element, ..state])
    }
    Dequeue(client) -> {
      state
      |> list.take(batch_size)
      |> list.reverse()
      |> fn(batch) { process.send(client, batch) }

      actor.continue(state |> list.drop(batch_size))
    }
  }
}

pub fn new() {
  let assert Ok(actor) = actor.start([], list_actor_handler)
  actor
}
