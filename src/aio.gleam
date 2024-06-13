import bus
import gleam/erlang/process.{type Subject}

pub type AIO(i, o) {
  AIO(cq: Subject(bus.Message(bus.CQE(o))))
}

pub type Request {
  StoreRequest(store: String, command: String)
}

pub type Response {
  StoreResponse(store: String, command: String)
}
