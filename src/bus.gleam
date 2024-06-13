import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/list
import gleam/otp/actor

const batch_size = 10

pub type Message(t) {
  Shutdown
  Enqueue(t)
  Dequeue(reply_with: Subject(List(t)))
}

pub type CQE(o) {
  CQE(completion: o, callback: fn(o) -> Nil)
}

pub type SQE(i, o) {
  SQE(submission: i, callback: fn(o) -> Nil)
}

fn completion_queue_handler(
  message: Message(CQE(o)),
  state: List(CQE(o)),
) -> actor.Next(Message(t), List(CQE(o))) {
  case message {
    Shutdown -> actor.Stop(process.Normal)
    Enqueue(element) -> {
      actor.continue([element, ..state])
    }
    Dequeue(client) -> {
      let batch = state |> list.take(batch_size) |> list.reverse()
      process.send(client, batch)
      actor.continue(state |> list.drop(batch_size))
    }
  }
}

fn submission_queue_handler(
  message: Message(SQE(i, o)),
  state: List(SQE(i, o)),
) -> actor.Next(Message(t), List(SQE(i, o))) {
  case message {
    Shutdown -> actor.Stop(process.Normal)
    Enqueue(element) -> {
      actor.continue([element, ..state])
    }
    Dequeue(client) -> {
      let batch = state |> list.take(batch_size) |> list.reverse()
      process.send(client, batch)
      actor.continue(state |> list.drop(batch_size))
    }
  }
}

pub fn new_completion_queue() {
  let assert Ok(q) = actor.start([], completion_queue_handler)
  q
}

pub fn new_submission_queue() {
  let assert Ok(q) = actor.start([], submission_queue_handler)
  q
}
