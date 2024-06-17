import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/list
import gloroutine.{type CoroutineInput}
import list_actor

pub type StoreCommand {
  StoreCommand(param: String)
}

pub type Request {
  Request(kind: Kind, commands: List(StoreCommand))
}

pub type Response {
  Response(kind: Kind, response: String)
}

pub type CQE {
  CQE(completion: Response, callback: fn(CoroutineInput(Response)) -> Nil)
}

pub type SQE {
  SQE(submission: Request, callback: fn(CoroutineInput(Response)) -> Nil)
}

pub type Kind {
  Store
}

pub type Subsystem {
  Subsystem(handle: fn(Request) -> Response)
}

pub type AIO {
  AIO(
    cq: Subject(list_actor.Message(CQE)),
    sq: Subject(list_actor.Message(SQE)),
    subsystems: dict.Dict(Kind, Subsystem),
  )
}

pub fn attach(aio: AIO, kind: Kind, subsystem: Subsystem) {
  AIO(..aio, subsystems: dict.insert(aio.subsystems, kind, subsystem))
}

pub fn new() {
  let cq = list_actor.new()
  let sq = list_actor.new()
  AIO(cq: cq, sq: sq, subsystems: dict.new())
}

pub fn flush(aio: AIO) {
  process.call(aio.sq, list_actor.Dequeue, 1000)
  |> list.each(fn(sqe) {
    case sqe.submission.kind {
      Store -> {
        case aio.subsystems |> dict.get(Store) {
          Ok(subsystem) -> {
            let cqe =
              CQE(
                completion: subsystem.handle(sqe.submission),
                callback: sqe.callback,
              )

            process.send(aio.cq, list_actor.Enqueue(cqe))
          }
          Error(_) -> {
            io.println_error("No sub system of type `Store` found ")
            panic
          }
        }
      }
    }
  })
}
