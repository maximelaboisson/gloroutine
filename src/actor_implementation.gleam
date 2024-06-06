// import gleam/erlang/process.{type Subject}
// import gleam/io
// import gleam/option.{type Option, None, Some}
// import gleam/otp/actor
// import gleam/otp/task

// pub type CoroutineInput(i) {
//   CoroutineInput(i)
//   PrimeIteration
// }

// pub type CoroutineOutput(o) {
//   CoroutineOutput(o)
//   StopIteration
// }

// pub type Coroutine(i, o) {
//   Coroutine(
//     yield: fn(CoroutineOutput(o)) -> CoroutineInput(i),
//     resume: fn(CoroutineInput(i)) -> CoroutineOutput(o),
//   )
// }

// pub type Message(e) {
//   Shutdown
//   Send(element: e)
//   Receive(reply_with: Subject(Result(e, Nil)))
// }

// pub type UnaryChannelState(e) {
//   UnaryChannelState(
//     element: Option(e),
//     subject: Option(Subject(Result(e, Nil))),
//   )
// }

// fn unary_channel_handler(
//   message: Message(e),
//   state: UnaryChannelState(e),
// ) -> actor.Next(Message(e), UnaryChannelState(e)) {
//   case message {
//     Shutdown -> actor.Stop(process.Normal)
//     Send(element) -> {
//       case state.subject {
//         Some(client) -> {
//           process.send(client, Ok(element))
//           actor.continue(UnaryChannelState(element: None, subject: None))
//         }
//         None -> {
//           actor.continue(UnaryChannelState(
//             element: Some(element),
//             subject: None,
//           ))
//         }
//       }
//     }
//     Receive(client) ->
//       case state.element {
//         Some(element) -> {
//           process.send(client, Ok(element))
//           actor.continue(UnaryChannelState(element: None, subject: None))
//         }
//         None -> {
//           actor.continue(UnaryChannelState(element: None, subject: Some(client)))
//         }
//       }
//   }
// }

// pub fn new_coroutine(f: fn(Coroutine(i, o)) -> Nil) -> Coroutine(i, o) {
//   let assert Ok(output_channel) =
//     actor.start(
//       UnaryChannelState(element: None, subject: None),
//       unary_channel_handler,
//     )
//   let assert Ok(input_channel) =
//     actor.start(
//       UnaryChannelState(element: None, subject: None),
//       unary_channel_handler,
//     )

//   let coro =
//     Coroutine(
//       yield: fn(output: CoroutineOutput(o)) -> CoroutineInput(i) {
//         process.send(output_channel, Send(output))
//         let assert Ok(input) = process.call(input_channel, Receive, 100_000)
//         input
//       },
//       resume: fn(input: CoroutineInput(i)) -> CoroutineOutput(o) {
//         process.send(input_channel, Send(input))
//         let assert Ok(output) = process.call(output_channel, Receive, 100_000)
//         output
//       },
//     )

//   task.async(fn() {
//     // blocks the coro until first resume is sent
//     let assert Ok(_) = process.call(input_channel, Receive, 100_000)
//     f(coro)

//     // TODO: this should be tested for concurrency, not sure this actually is safe to shutdown directly
//     process.send(input_channel, Shutdown)
//     process.send(output_channel, Shutdown)
//   })

//   coro
// }

// pub fn filter(
//   inner_coro: Coroutine(i, o),
//   f: fn(o) -> Bool,
// ) -> Coroutine(i, Option(o)) {
//   inner_coro
//   |> map(fn(elem: o) {
//     case f(elem) {
//       True -> Some(elem)
//       False -> None
//     }
//   })
// }

// fn inner_map(
//   inner_coro: Coroutine(i, o),
//   outer_coro: Coroutine(i, p),
//   f: fn(CoroutineOutput(o)) -> CoroutineOutput(p),
//   output: CoroutineOutput(p),
// ) {
//   case outer_coro.yield(output) {
//     PrimeIteration -> panic
//     CoroutineInput(value) -> {
//       let value = inner_coro.resume(CoroutineInput(value))
//       inner_map(inner_coro, outer_coro, f, f(value))
//     }
//   }
// }

// pub fn map(inner_coro: Coroutine(i, o), f: fn(o) -> p) -> Coroutine(i, p) {
//   let body = fn(outer_coro: Coroutine(i, p)) -> Nil {
//     let wrapped_f = fn(output: CoroutineOutput(o)) -> CoroutineOutput(p) {
//       case output {
//         StopIteration -> StopIteration
//         CoroutineOutput(value) -> CoroutineOutput(f(value))
//       }
//     }
//     let value = inner_coro.resume(PrimeIteration)
//     inner_map(inner_coro, outer_coro, wrapped_f, wrapped_f(value))
//   }

//   new_coroutine(body)
// }

// fn inner_on_each(
// inner_coro: Coroutine(i, o),
// outer_coro: Coroutine(i, o),
// f: fn(CoroutineOutput(o)) -> Nil,
// output: CoroutineOutput(o),
// ) {
//   case outer_coro.yield(output) {
//     PrimeIteration -> panic
//     CoroutineInput(value) -> {
//       let output = inner_coro.resume(CoroutineInput(value))
//       f(output)
//       inner_on_each(inner_coro, outer_coro, f, output)
//     }
//   }
// }

// pub fn on_each(inner_coro: Coroutine(i, o), f: fn(o) -> Nil) -> Coroutine(i, o) {
//   let body = fn(outer_coro: Coroutine(i, o)) -> Nil {
//     let input = inner_coro.resume(PrimeIteration)
//     let safe_f = fn(output: CoroutineOutput(o)) {
//       case output {
//         StopIteration -> Nil
//         CoroutineOutput(value) -> {
//           f(value)
//           Nil
//         }
//       }
//     }
//     inner_on_each(inner_coro, outer_coro, safe_f, input)
//   }

//   new_coroutine(body)
// }

// fn inner_take(
//   inner_coro: Coroutine(i, o),
//   outer_coro: Coroutine(i, o),
//   input: CoroutineInput(i),
//   number: Int,
// ) -> Nil {
//   case number == 0 {
//     True -> {
//       outer_coro.yield(StopIteration)
//       Nil
//     }
//     False -> {
//       let output = inner_coro.resume(input)
//       let input = outer_coro.yield(output)
//       inner_take(inner_coro, outer_coro, input, number - 1)
//     }
//   }
// }

// pub fn take(inner_coro: Coroutine(i, o), number: Int) -> Coroutine(i, o) {
//   // TODO: validate number >= 1
//   let body = fn(outer_coro: Coroutine(i, o)) -> Nil {
//     case inner_coro.resume(PrimeIteration) {
//       StopIteration -> {
//         outer_coro.yield(StopIteration)
//         Nil
//       }
//       CoroutineOutput(v) -> {
//         let input = outer_coro.yield(CoroutineOutput(v))
//         inner_take(inner_coro, outer_coro, input, number - 1)
//         Nil
//       }
//     }
//   }

//   new_coroutine(body)
// }

// fn inner_take_while(
//   inner_coro: Coroutine(i, o),
//   outer_coro: Coroutine(i, o),
//   f: fn(o) -> Bool,
//   output: o,
// ) {
//   case f(output) {
//     False -> {
//       outer_coro.yield(StopIteration)
//       Nil
//     }
//     True -> {
//       let input = outer_coro.yield(CoroutineOutput(output))
//       case inner_coro.resume(input) {
//         StopIteration -> {
//           outer_coro.yield(StopIteration)
//           Nil
//         }
//         CoroutineOutput(b) -> {
//           inner_take_while(inner_coro, outer_coro, f, b)
//           Nil
//         }
//       }
//     }
//   }
// }

// pub fn take_while(
//   inner_coro: Coroutine(i, o),
//   f: fn(o) -> Bool,
// ) -> Coroutine(i, o) {
//   let body = fn(outer_coro: Coroutine(i, o)) -> Nil {
//     case inner_coro.resume(PrimeIteration) {
//       StopIteration -> {
//         outer_coro.yield(StopIteration)
//         Nil
//       }
//       CoroutineOutput(v) -> {
//         inner_take_while(inner_coro, outer_coro, f, v)
//         Nil
//       }
//     }
//   }

//   new_coroutine(body)
// }
